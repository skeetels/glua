-- Component initialized with an explicit shared service context.
return function(__slctx)
-- MACRO_RUNTIME_BEGIN
function __slctx.Strategy.effectiveActionSeconds(kind)
    local r=__slctx.Strategy.route();local c=r.cadence and r.cadence[kind]
    return math.max(__slctx.Strategy.actionSeconds(kind),c and c.ewma or 0,__slctx.CONFIG.RequestedClickInterval)
end

function __slctx.Strategy.planCurrent(cards,allowBuy)
    local r=__slctx.Strategy.route();local p=r.pass;local eligible={}
    if p then for i=p.index,#p.order do eligible[p.order[i].path]=true end
    else for _,c in ipairs(cards)do eligible[c.path]=true end end
    local q=allowBuy and r.buyQuote or nil
    local result=__slctx.Planner.macroPlan(cards,__slctx.cash(),__slctx.Strategy.rate(),q,r.models,r.priceModels,
        {upgrade=__slctx.Strategy.effectiveActionSeconds('upgrade'),buy=__slctx.Strategy.effectiveActionSeconds('buy'),
            switch=r.menuTripSeconds or __slctx.CONFIG.InitialMenuTripSeconds},__slctx.CONFIG,eligible)
    result.at=__slctx.now();r.macroPlan=result
    return result
end
function __slctx.Strategy.maybeBreakthrough(cards)
    local r=__slctx.Strategy.route();local p=r.pass
    if not __slctx.CONFIG.BreakthroughBuys or not p or p.finished or p.boostUsed or r.evo and r.evo.ready then return false end
    if __slctx.now()<(p.nextBoostCheck or 0) then return false end
    p.nextBoostCheck=__slctx.now()+1
    local q=__slctx.readBuy()
    if not q or not q.cost or not __slctx.Planner.globalMultiplier(q) then return false end
    r.buyQuote=q
    if (r.unverifiedBoosts or {})[q.id] then return false end
    local amount=__slctx.cash()
    if not amount or __slctx.BN.cmp(amount,q.cost)<0 or (q.multiplier or 0)<__slctx.CONFIG.BreakthroughMinimumMultiplier then return false end
    local result=__slctx.Strategy.planCurrent(cards,true)
    if result.known and result.first and result.first.kind=='buy'
        and result.improvement>=__slctx.CONFIG.BreakthroughMinimumAdvantage then
        r.boostQuote=q;r.boostStarted=__slctx.now()
        __slctx.log('BREAKTHROUGH_PLAN',q.name..'; declared global x'..tostring(q.multiplier)
            ..'; rollout horizon='..result.horizon..'; modeled cash advantage='..string.format('%.3f',result.improvement)
            ..'; resume pass='..p.id..' index='..p.index)
        __slctx.Strategy.phase('BOOST','существенный глобальный множитель; затем тот же проход стендов')
        return true
    end
    return false
end
function __slctx.Strategy.buyBreakthrough()
    local r=__slctx.Strategy.route();local q=r.boostQuote;local p=r.pass
    if not q or not p or p.finished then r.boostQuote=nil;__slctx.Strategy.phase('UPGRADE','нет сохранённого ускорителя');return end
    local fresh,why=__slctx.focusCandidate(q)
    if fresh and __slctx.affordable(fresh,__slctx.cash()) then
        local beforeRate=__slctx.Planner.sumRates(r.cards)
        local done,receipt=__slctx.Strategy.safePurchase(fresh)
        if done then
            r.boostEffectPending={id=fresh.id,name=fresh.name,expected=__slctx.Planner.globalMultiplier(fresh),beforeRate=beforeRate}
            p.boostUsed=true
            if p.budget then p.budget=__slctx.BN.sub(p.budget,(receipt and receipt.c or fresh).cost) end
            r.menuTripSeconds=r.menuTripSeconds or __slctx.CONFIG.InitialMenuTripSeconds
            __slctx.log('BREAKTHROUGH_BOUGHT',fresh.name..'; pass='..p.id..' retained; budget debited; no BUY burst')
        elseif next(r.blocked or {}) then __slctx.Strategy.stopForBlocked();return end
    else __slctx.log('BREAKTHROUGH_CHANGED',tostring(why or 'price/availability changed; no purchase inferred')) end
    r.boostQuote=nil
    __slctx.Strategy.phase('UPGRADE','возвращаюсь к оставшимся стендам, не начинаю проход заново')
end
function __slctx.Strategy.reviewStandAllocation(cards,c)
    local r=__slctx.Strategy.route();local p=r.pass
    if not __slctx.CONFIG.AdaptiveStandAllocation or not p or not p.entered then return false end
    local wall=r.buildWall;local q=r.buyQuote
    local stalled=not p.quickBuild and not r.recovery and wall and q and wall.key==__slctx.Strategy.baseQuoteKey(q)
        and wall.serial==(r.runBuyCount or 0) and wall.weak>=2
        and __slctx.now()-wall.started>=__slctx.CONFIG.BuildWallConfirmSeconds
    if stalled then
        -- The old 12-per-stand minimum restarted on every pass. One weak +1
        -- per pass could therefore drain cash forever without any ROI review.
        local plan=__slctx.Strategy.planCurrent(cards,true)
        local first=plan.first
        if plan.known and plan.complete and (not first or first.kind=='buy'
            or first.kind=='upgrade' and first.path~=c.path) then
            __slctx.log('STALLED_UPGRADE_HELD',c.name..'; preferred='..tostring(first and first.name or 'keep cash')..'; pass='..p.id)
            __slctx.Strategy.advanceStand('сохраняю деньги для более выгодного действия')
            return true
        end
    end
    if c.maxMode then return false end
    local bought=(p.purchases or 0)-(p.standStartPurchases or 0)
    if bought<__slctx.CONFIG.AllocationMinimumPurchases or bought<(p.nextAllocationPurchase or 0) then return false end
    if __slctx.now()<(p.nextAllocationAt or 0) then return false end
    p.nextAllocationAt=__slctx.now()+1;p.nextAllocationPurchase=bought+__slctx.CONFIG.AllocationMinimumPurchases
    local priceModel=r.priceModels and r.priceModels[c.path]
    if not priceModel or priceModel.samples<2 then return false end
    local result=__slctx.Strategy.planCurrent(cards,false)
    if not result.known then return false end
    local first=result.first
    if not first and not result.complete then return false end
    if not first or first.kind=='upgrade' and first.path~=c.path then
        __slctx.log('ALLOCATION_RELEASE',c.name..'; purchases on this visit='..bought
            ..'; next='..tostring(first and first.name or 'hold / reset review')
            ..'; horizon='..result.horizon..'; price slope is local, hidden milestones unknown')
        __slctx.Strategy.advanceStand('remaining capital reserved: another modeled route has higher return')
        return true
    end
    p.nextAllocationPurchase=bought+math.max(__slctx.CONFIG.AllocationMinimumPurchases,first.clicks or 1)
    return false
end


end
