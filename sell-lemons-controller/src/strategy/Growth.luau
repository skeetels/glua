-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.Strategy.boot()
    local r=__slctx.Strategy.route();r.buildWall=nil;r.buildQuote=nil
    if __slctx.CONFIG.DirectUpgrades then
        local state,why=__slctx.DirectUpgrades.state()
        if not state then __slctx.pause('DIRECT_STATE_UNAVAILABLE',tostring(why));return end
    end
    __slctx.Strategy.cancelResetIntent('BOOT_REVALIDATION')
    if not r.schema28 then
        r.rebuildProfile=nil;r.rebuildEstimate=nil;r.fullLayoutSeconds=nil;r.paritySeconds=nil
        r.frontierTrace=nil;r.cleanRun=false;r.schema28=true
        if r.recovery then
            r.recovery=nil;r.frontierRecovery=nil -- Old metric has no compatible source/trace identity.
        end
    end
    if r.powerUnresolved then
        local item=r.powerUnresolved.item
        if __slctx.manageTab('Powers') and __slctx.Powers.proof(item) then
            __slctx.Strategy.recordSpend(item.price);r.powerUnresolved=nil;r.powerSkipped[item.name]=nil
            __slctx.log('POWER_LATE_RECEIPT','observed on resume; original debit already reserved')
        else
            __slctx.pause('POWER_OUTCOME_UNRESOLVED','Прежняя трата не подтверждена. Повтор не отправлен; проверь баланс и F7.');return
        end
    end
    if not __slctx.ResetConfirm.dismissStale() then return end
    if r.bootEvolution then
        local evo,err=__slctx.Strategy.readEvolution()
        if not evo then __slctx.pause('EVOLUTION_INIT_FAILED',tostring(err));return end
        local halo
        if not r.cleanRun or r.lastReset=='halo' then halo=__slctx.Strategy.readHalo() end
        local changed=(r.previousEvolution~=nil and r.previousEvolution~=evo.index)
            or (halo and r.previousHalo~=nil and halo.amount~=r.previousHalo)
        if changed then
            r.powerBase=nil;r.powerUsed=__slctx.BN.new(0);r.powerBank=nil;r.spent=__slctx.BN.new(0);r.spentUnknown=true
            r.recovery=nil;r.rebuildProfile=nil;r.rebuildEstimate=nil;r.lastFullPass=nil
            r.powerQuotes={};r.models={};r.priceModels={};r.failedTierHints={}
            r.powerPurchasePlan=nil;r.capabilityPending=nil;r.baseProgress282=nil;r.buildWall=nil;r.buildQuote=nil
            __slctx.log('ATTACH_EPOCH_CHANGED','fresh evolution/Halo identity differs; old capital/work models discarded')
        end
        r.previousEvolution=evo.index
        if halo then r.previousHalo=halo.amount end
        r.bootEvolution=false
        if evo.ready and __slctx.S.resetEnabled and __slctx.CONFIG.AutoEvolution then
            r.reserveSince=__slctx.now();__slctx.Strategy.phase('EVOLVE_RESERVE','live evolution already ready at startup');return
        end
        __slctx.log('EVOLUTION_TARGET','E'..evo.index..' -> E'..(evo.index+1)..' | '..__slctx.BN.format(r.target)..' total investors (rounded table)')
    end
    if r.bootTablet then
        r.menuReads.tablet=r.menuReads.tablet+1
        local _,err=__slctx.ensureTablet()
        if not __slctx.live() then return end
        r.bootTablet=false
        if err then __slctx.log('TABLET_STATUS',err) end
    end
    __slctx.Strategy.phase(r.powerPending and __slctx.CONFIG.AutoInvestorPowers and 'POWERS' or 'BUY','initial growth preparation complete')
end
function __slctx.Strategy.growBuy()
    local r=__slctx.Strategy.route()
    if r.endPurchased and not r.haloChecked then __slctx.Strategy.phase('HALO','The End purchased');return end
    local ok,err=__slctx.ensureStrip()
    if not ok then __slctx.pause('BUY_MENU_NOT_READY',tostring(err));return end
    local q=__slctx.readBuy()
    local name=__slctx.t(__slctx.paths.buy..'/Purchase');local price=__slctx.t(__slctx.paths.buy..'/PurchasePrice');local info=__slctx.t(__slctx.paths.buy..'/PurchaseInfo')
    if __slctx.buyComplete() then
        r.completionSeen=true;r.buyQuote=nil
        __slctx.Strategy.phase('HALO','explicit end-of-catalog marker');return
    end
    if not q or (not q.cost and q.parseReason~='hidden_large') then
        r.unknownSince=r.unknownSince or __slctx.now()
        if __slctx.now()-r.unknownSince>=__slctx.CONFIG.UIUnavailableTimeout then
            __slctx.pause('BUY_QUOTE_UNKNOWN','Следующая покупка не распознана. Исчезновение BUY не считается полной прокачкой; rebirth не отправлен.')
        end
        return
    end
    if r.completionSeen or r.endPurchased then
        __slctx.log('COMPLETION_CLEARED','fresh nonterminal BUY: '..tostring(q.name))
        r.completionSeen=false;r.endPurchased=false;r.haloChecked=false
    end
    r.buyQuote=q;__slctx.Strategy.quotes();__slctx.Strategy.observeBuildQuote(q)
    local amount=__slctx.cash()
    if not amount then __slctx.pause('CASH_UNKNOWN','Баланс не распознан.');return end
    -- Read/validate the NEXT BUY before deciding whether to interrupt its chain.
    if not __slctx.Planner.isTerminalName(q.name) then
        if __slctx.Strategy.maybeFastBuild() then return end
        if __slctx.Strategy.maybeBuyReview() then return end
    end
    if q.cost and __slctx.BN.cmp(amount,q.cost)>=0 then
        if (r.blocked or {})[__slctx.Safety.key(q)] then
            if r.upgradeWall then __slctx.Strategy.stopForBlocked() else __slctx.Strategy.phase('UPGRADE','BUY deferred; try other income upgrades') end
            return
        end
        if not q.available then
            r.unknownSince=r.unknownSince or __slctx.now()
            if __slctx.now()-r.unknownSince>__slctx.CONFIG.UIUnavailableTimeout then
                __slctx.pause('BUY_FUNDED_BUT_LOCKED','На '..q.name..' хватает денег, но BUY выключена. Не считаю это нехваткой денег.')
            end
            return
        end
        __slctx.status('BUY_RUN','Покупаю до финансового предела: '..q.name)
        __slctx.Strategy.safePurchase(q);return
    end
    r.unknownSince=nil
    if r.upgradeWall then __slctx.Strategy.enterWall()
    else
        r.stackRestorePending=r.stackReduced;r.batchSelected=nil;r.batchUnavailable=false
        __slctx.Strategy.phase('UPGRADE','next BUY is unaffordable; raise source income')
    end
end
-- A pass freezes stand identities/order, never their cash quotes.
-- ECONOMIC_RUNTIME_BEGIN
function __slctx.Strategy.recordTiming(kind,seconds,overlapped)
    if not seconds or seconds<=0 or seconds~=seconds then return end
    local r=__slctx.Strategy.route();r.timings=r.timings or {}
    r.cadence=r.cadence or {};local prev=r.lastReceiptTiming
    if prev and prev.kind==kind and __slctx.now()-prev.time>0 and __slctx.now()-prev.time<1 then
        local dt=__slctx.now()-prev.time;local c=r.cadence[kind] or {count=0,total=0}
        c.count=c.count+1;c.total=c.total+dt;c.ewma=c.ewma and c.ewma*.8+dt*.2 or dt;r.cadence[kind]=c
    end
    r.lastReceiptTiming={kind=kind,time=__slctx.now()}
    local t=r.timings[kind] or {count=0,total=0}
    t.count=t.count+1;t.total=t.total+seconds
    t.ewma=t.ewma and t.ewma*0.7+seconds*0.3 or seconds
    t.maximum=math.max(t.maximum or 0,seconds);r.timings[kind]=t
    if (kind=='buy' or kind=='upgrade') and not overlapped then r.runServiceSeconds=(r.runServiceSeconds or 0)+seconds end
    if kind=='upgrade' then
        r.runUpgradeSeconds=(r.runUpgradeSeconds or 0)+seconds;r.runUpgradeActions=(r.runUpgradeActions or 0)+1
        if r.pass and not r.pass.finished then r.pass.upgradeSeconds=(r.pass.upgradeSeconds or 0)+seconds end
        if r.recovery then
            r.recovery.upgradeSeconds=(r.recovery.upgradeSeconds or 0)+seconds
            r.recovery.upgradeActions=(r.recovery.upgradeActions or 0)+1
        end
    end
end

function __slctx.Strategy.actionSeconds(kind)
    local t=(__slctx.Strategy.route().timings or {})[kind]
    return math.max(0.001,t and t.ewma or (kind=='power' and 1.5 or __slctx.CONFIG.UpgradeActionEstimate))
end


function __slctx.Strategy.savingsRemaining(q,arm)
    local r=__slctx.Strategy.route()
    if not q then return 0 end
    if r.savingsBudget and r.savingsBudget.id~=q.id then r.savingsBudget=nil end
    if not r.savingsBudget and arm then
        r.savingsBudget={id=q.id,start=__slctx.now(),deadline=__slctx.now()+__slctx.CONFIG.MaxWaitSeconds}
    end
    local budget=r.savingsBudget
    return budget and math.max(0,budget.deadline-__slctx.now()) or __slctx.CONFIG.MaxWaitSeconds
end

function __slctx.Strategy.reserveGoal(q,rate,reason)
    local r=__slctx.Strategy.route()
    local eta=q and q.cost and __slctx.Core.eta(__slctx.cash(),q.cost,rate)
    if not eta or eta<=0 or eta==math.huge then return false end
    local remaining=__slctx.Strategy.savingsRemaining(q,false)
    if eta>remaining or remaining<=0 then return false end
    __slctx.Strategy.savingsRemaining(q,true)
    local budget=r.savingsBudget
    r.wall={start=budget.start,deadline=budget.deadline,expired={}}
    r.goal={id=q.id,candidate=q,deadline=budget.deadline,eta=eta,source='economic target ETA'}
    r.upgradeWall=true;r.waitSuggestion=nil
    __slctx.log('ECONOMIC_SAVE',q.name..' | ETA='..string.format('%.2f',eta)..'s | '..tostring(reason))
    __slctx.Strategy.phase('WAIT_CASH','Коплю на '..q.name..'; бюджет ожидания не продлевается')
    return true
end


function __slctx.Strategy.chooseNextStand(cards)
    local r=__slctx.Strategy.route();local p=r.pass;local bestIndex,bestScore=nil,nil
    local byPath={};for i=p.index,#p.order do byPath[p.order[i].path]=i end
    local selectedByMacro=false
    if __slctx.CONFIG.AdaptiveStandAllocation then
        local result=__slctx.Strategy.planCurrent(cards,false);local first=result.first
        if first and first.kind=='upgrade' and byPath[first.path] then
            bestIndex=byPath[first.path];selectedByMacro=true
            r.lastPlan={name=first.name,delta=first.delta,quality=first.quality..'; multi-action lookahead'}
        end
    end
    local rate=__slctx.Strategy.rate()
    for _,c in ipairs(cards) do
        if not selectedByMacro and __slctx.CONFIG.RankStandsByReturn and byPath[c.path] and not (r.blocked or {})[__slctx.Safety.key(c)] then
            -- No BUY target here: income investment is evaluated over the sweep,
            -- not vetoed just because the next base button became affordable.
            local plan=__slctx.Planner.upgradePlan(c,__slctx.cash(),rate,nil,r.models[c.path],__slctx.Strategy.actionSeconds('upgrade'))
            if plan and plan.known and (not bestScore or plan.score>bestScore) then
                bestScore=plan.score;bestIndex=byPath[c.path]
                r.lastPlan={name=c.name,delta=plan.delta,payback=plan.payback,quality=plan.quality}
            end
        end
    end
    if bestIndex and bestIndex~=p.index then p.order[p.index],p.order[bestIndex]=p.order[bestIndex],p.order[p.index] end
    p.decisionBatch=__slctx.Strategy.largestBatch() or __slctx.Strategy.currentBatch()
    return p.order[p.index]
end

-- ECONOMIC_RUNTIME_END

function __slctx.Strategy.beginPass(cards)
    local r=__slctx.Strategy.route();r.passSerial=(r.passSerial or 0)+1
    r.runObservedAt=r.runObservedAt or __slctx.S.runStart or __slctx.now()
    local order={}
    for _,c in ipairs(cards) do order[#order+1]={path=c.path,name=c.name,order=c.order or 0} end
    table.sort(order,function(a,b) if a.order~=b.order then return a.order<b.order end;return a.path<b.path end)
    local rate,known,total=__slctx.Planner.sumRates(cards)
    r.batchQuotes={} -- New base purchases or powers cannot leave stale cached prices.
    r.pass={id=r.passSerial,order=order,index=1,started=__slctx.now(),economic=__slctx.CONFIG.EconomicPlanning,beforeRate=rate,
        beforeCards=cards,rateKnown=known==total and total>0,complete=false,purchases=0,levels=0,work={},upgradeSeconds=0}
    r.pass.direct=cards[1] and cards[1].source=='direct' or false
    r.pass.buildQuoteKey=__slctx.Strategy.baseQuoteKey(r.buyQuote);r.pass.buildBuySerial=r.runBuyCount or 0
    local observed,_,kind=__slctx.Strategy.rate();r.pass.buildRate=observed;r.pass.buildRateKind=kind
    r.upgradeWall=false
    __slctx.log('UPGRADE_PASS_START','pass='..r.pass.id..' stands='..#order..'; complete stand coverage; fixed entry budgets; no BUY affordability interruption')
    return r.pass
end
function __slctx.Strategy.advanceStand(reason)
    local p=__slctx.Strategy.route().pass;local item=p.order[p.index]
    __slctx.log('UPGRADE_PASS_STEP','pass='..p.id..' index='..p.index..'/'..#p.order..' stand='..tostring(item and item.name)..' '..reason)
    p.index=p.index+1;p.budget=nil;p.entered=nil;p.unreadySince=nil;p.retries=0
    p.standStartPurchases=nil;p.nextAllocationPurchase=nil;p.nextAllocationAt=nil
end
function __slctx.Strategy.finishPass(cards)
    local r=__slctx.Strategy.route();local p=r.pass
    local rate,known,total=__slctx.Planner.sumRates(cards)
    p.afterRate=rate;p.rateKnown=p.rateKnown and known==total and total==#p.order
    p.growthLogUpper=__slctx.Planner.growthBound(p.beforeCards,cards)
    p.beforeCards=nil
    p.complete=p.index>#p.order
    if not p.complete then error('FULL_PASS_INVARIANT: unfinished stand coverage cannot be a normal checkpoint') end
    p.duration=math.max(0.1,__slctx.now()-p.started);p.finished=true;p.finishedAt=__slctx.now()
    r.fullPassCount=(r.fullPassCount or 0)+1
    r.lastFullPass={duration=p.duration,work=p.work,upgradeActions=p.purchases,upgradeSeconds=p.upgradeSeconds}
    __slctx.Strategy.observeRecovery(cards)
    __slctx.Strategy.recordBuildSweep(cards)
    __slctx.log('UPGRADE_PASS_DONE',string.format('pass=%d stands=%d purchases=%d levels=%d seconds=%.2f rate=%s->%s known=%d/%d growthLogUpper=%s',
        p.id,#p.order,p.purchases,p.levels,p.duration,__slctx.BN.format(p.beforeRate),__slctx.BN.format(p.afterRate),known,total,tostring(p.growthLogUpper)))
    if not p.rateKnown then
        for _,c in ipairs(cards) do
            if not __slctx.Planner.sourceRate(c) then __slctx.log('PASS_RATE_UNKNOWN',c.name..' period='..string.format('%q',c.period or '')..' income='..__slctx.BN.format(c.income)) end
        end
    end
    if p.quickBuild then
        r.fastBuildPending=r.recovery~=nil
        __slctx.Strategy.phase('BUY','закончена ранняя MAX-прокачка; продолжаю базу');return
    end
    __slctx.Strategy.phase('CHECKPOINT','все стенды обработаны; сравниваю продолжение базы и следующий цикл')
end
function __slctx.Strategy.passRetry(message)
    local p=__slctx.Strategy.route().pass
    p.unreadySince=p.unreadySince or __slctx.now()
    if __slctx.now()-p.unreadySince>=__slctx.CONFIG.UIUnavailableTimeout then __slctx.pause('PASS_VIEW_NOT_READY',message)
    else __slctx.status('PASS_VIEW_RETRY',message);__slctx.sleep(0.15) end
end
function __slctx.Strategy.growUpgrades()
    if __slctx.CONFIG.DirectUpgrades and __slctx.DirectUpgrades then return __slctx.DirectUpgrades.grow()end
    local r=__slctx.Strategy.route()
    if not __slctx.canUpgrade() then
        r.cards={};if not r.pass or r.pass.finished then __slctx.Strategy.beginPass({}) end
        __slctx.Strategy.finishPass({});return
    end
    local ok,err=__slctx.manageTab('Manage')
    if not ok then __slctx.pause('UPGRADE_MENU_NOT_READY',tostring(err));return end
    local cards=__slctx.Strategy.readCards()
    if not r.pass or r.pass.finished then
        if #cards==0 then
            r.unknownSince=r.unknownSince or __slctx.now()
            if __slctx.now()-r.unknownSince>=__slctx.CONFIG.UIUnavailableTimeout then __slctx.pause('PASS_VIEW_NOT_READY','Карточки стендов не появились.')
            else __slctx.sleep(0.15) end
            return
        end
        if __slctx.CONFIG.EconomicPlanning then
            r.preferredReviewBatch=nil
            if not __slctx.Strategy.stackPrepare() then
                r.unknownSince=r.unknownSince or __slctx.now()
                if __slctx.now()-r.unknownSince>__slctx.CONFIG.UIUnavailableTimeout then __slctx.pause('BATCH_VIEW_NOT_READY','Не удалось выбрать доступную пачку.') end
                return
            end
            cards=__slctx.Strategy.readCards()
        end
        __slctx.Strategy.beginPass(cards)
    end
    local p=r.pass
    if p.index>#p.order then __slctx.Strategy.finishPass(cards);return end
    if __slctx.S.actionPending or __slctx.S.resetChildPending or __slctx.S.resetSession then return end
    __slctx.Strategy.captureGrowth(cards)
    __slctx.Strategy.observeRecovery(cards)
    if not p.quickBuild and __slctx.Strategy.maybeBreakthrough(cards) then return end
    if __slctx.Strategy.maybeCapabilityReview(cards) then return end
    if not p.entered then __slctx.Strategy.chooseNextStand(cards) end
    local item=p.order[p.index]
    local c
    for _,v in ipairs(cards) do if v.path==item.path then c=v;break end end
    if not c then __slctx.Strategy.passRetry('Жду карточку '..item.name..'; порядок прохода сохранён.');return end
    __slctx.Strategy.cacheBatch(__slctx.Strategy.currentBatch(),cards)
    if not p.entered then
        local amount=__slctx.cash();if not amount then __slctx.Strategy.passRetry('Жду баланс для '..item.name);return end
        p.budget=amount -- Fixed-batch fallback cannot chase newly arriving cash forever.
        local choice=p.decisionBatch or __slctx.Strategy.largestBatch() or (r.maxUnavailable and __slctx.Strategy.currentBatch() or 'max')
        if choice==0 then __slctx.Strategy.advanceStand('cached +1 exceeds current balance');return end
        r.preferredReviewBatch=choice
        if not __slctx.Strategy.stackPrepare() then __slctx.Strategy.passRetry('Выбираю MAX или максимальную открытую пачку.');return end
        p.entered=true;p.standStartPurchases=p.purchases;p.nextAllocationPurchase=nil;p.nextAllocationAt=nil
    end
    cards=__slctx.Strategy.readCards()
    c=nil
    for _,v in ipairs(cards) do if v.path==item.path then c=v;break end end
    if not c then __slctx.Strategy.passRetry('Жду карточку '..item.name..'; порядок прохода сохранён.');return end
    local amount=__slctx.cash();if not amount then __slctx.Strategy.passRetry('Жду обновление баланса.');return end
    local units=__slctx.Core.count(c.stack)
    -- Live MAX has no numeric quote when zero levels are affordable:
    -- its disabled button shows Stack="MAX" and a blank Price (v6916).
    -- This is a completed visit, not a missing/loading quote. Do not wait for income.
    local emptyMax=c.maxMode and not c.available and __slctx.Core.clean(c.priceText)==''
        and __slctx.Core.clean(c.stackRaw or c.stack):lower()=='max'
    if emptyMax or c.maxMode and units==0 then
        __slctx.Strategy.advanceStand('MAX=0; no affordable levels');return
    end
    if not c.cost and c.parseReason~='hidden_large' and c.parseReason~='owned' then
        __slctx.Strategy.passRetry('Жду цену '..c.name..' | price='..string.format('%q',c.priceText or '')
            ..' stack='..string.format('%q',c.stackRaw or c.stack or '')..' reason='..tostring(c.parseReason));return
    end
    if not units and c.cost then __slctx.Strategy.passRetry('Жду количество уровней '..c.name);return end
    local mode=__slctx.Strategy.currentBatch()
    if mode~='max' and type(mode)~='number' then __slctx.Strategy.passRetry('Жду размер пачки '..c.name);return end
    local budget=c.maxMode and amount or p.budget
    local funded=c.cost and __slctx.BN.cmp(amount,c.cost)>=0 and __slctx.BN.cmp(budget,c.cost)>=0
    if funded and not c.available then __slctx.Strategy.passRetry('Цена доступна, жду разблокировки '..c.name);return end
    if funded and __slctx.Safety.batchAllowed(c) then
        if __slctx.Strategy.reviewStandAllocation(cards,c) then return end
        __slctx.status('UPGRADE_PASS',string.format('Проход %d: %d/%d · %s · %s (+%d)',
            p.id,p.index,#p.order,c.name,c.maxMode and 'MAX' or tostring(mode),units or 0))
        local done,receipt=__slctx.Strategy.safePurchase(c)
        if done then
            local actual=receipt and receipt.c or c
            p.purchases=p.purchases+1;p.levels=p.levels+(__slctx.Core.count(actual.stack) or 0)
            p.budget=__slctx.BN.sub(p.budget,actual.cost);p.unreadySince=nil;p.retries=0
            if c.maxMode then __slctx.Strategy.advanceStand('verified MAX purchased +'..tostring(__slctx.Core.count(actual.stack) or '?')) end
        elseif not __slctx.live() then return
        elseif (r.blocked or {})[__slctx.Safety.key(c)] then __slctx.Strategy.stopForBlocked()
        else
            p.retries=(p.retries or 0)+1
            __slctx.Strategy.passRetry('Обновляю цену текущего стенда '..c.name)
        end
        return
    end
    if c.maxMode or c.parseReason=='owned' then __slctx.Strategy.advanceStand('no affordable MAX quote');return end
    local limit=__slctx.BN.cmp(amount,p.budget)<0 and amount or p.budget
    local n=__slctx.Strategy.cachedBatch(c,limit,mode)
    if n~=0 then
        if __slctx.Strategy.selectBatch(n,{path=c.path,budget=limit}) then r.batchSelected=__slctx.Strategy.currentBatch();return end
        __slctx.Strategy.passRetry('Переключаю меньшую пачку для '..c.name);return
    end
    __slctx.Strategy.advanceStand('entry budget exhausted; incoming cash belongs to next stand')
end
function __slctx.Strategy.nextCycle(reason,delay)
    __slctx.Strategy.cancelResetIntent('ROUTE_REPLANNED')
    local r=__slctx.Strategy.route();r.pass=nil;r.goal=nil;r.wall=nil;r.upgradeWall=false;r.unknownSince=nil
    r.cycleBeganAt=__slctx.now();r.nextGrowthScan=__slctx.now()+(delay or 0)
    __slctx.Strategy.phase((delay or 0)>0 and 'WAIT_GROWTH' or 'BUY',reason)
end
function __slctx.Strategy.waitGrowth()
    local r=__slctx.Strategy.route()
    if __slctx.now()>=(r.nextGrowthScan or 0) then __slctx.Strategy.nextCycle('new macro cycle: base burst, then a complete stand sweep')
    else __slctx.status('WAIT_GROWTH','Короткое ожидание следующего цикла; старые стенды не пересматриваются.') end
end
function __slctx.Strategy.resetAllowed(inv)
    local r=__slctx.Strategy.route()
    if r.resetIntent then return __slctx.Strategy.validateResetIntent(inv) end
    -- Refresh non-spending observations before taking a new snapshot. Do not reset
    -- the collector or navigate just to make its timestamp look new.
    __slctx.Strategy.sampleIncome()
    local q=__slctx.readBuy()
    if q then r.buyQuote=q;__slctx.Strategy.observeBuildQuote(q) end
    local context=__slctx.Strategy.resetContext(inv,r.capabilityOnly)
    local yes,reason,gain,detail=__slctx.Planner.rebirthDecision(inv,__slctx.CONFIG,context)
    if yes then __slctx.Strategy.rememberResetIntent(inv,context,reason,gain,detail) end
    return yes,reason,gain,detail
end
function __slctx.Strategy.checkpoint()
    local r=__slctx.Strategy.route();local p=r.pass
    r.lastStrategicReview=__slctx.now();r.reviewReturn=nil
    r.capabilityOnly=nil
    if not p or not p.finished or not p.complete then __slctx.Strategy.phase('UPGRADE','заканчиваю весь проход стендов');return end
    if __slctx.Strategy.stopForBlocked() then return end
    if r.endPurchased or r.completionSeen then __slctx.Strategy.phase('HALO','endgame completion');return end
    local opened,why=__slctx.ensureStrip()
    if not opened then __slctx.pause('BUY_MENU_NOT_READY',tostring(why));return end
    r.buyQuote=nil
    if not __slctx.Strategy.refreshResetBuy() then
        if __slctx.live() then __slctx.Strategy.nextCycle('следующий BUY не прочитан; сброс запрещён',0.5) end
        return
    end
    if r.completionSeen then __slctx.Strategy.phase('HALO','live completion marker');return end
    if not __slctx.S.resetEnabled or not (__slctx.CONFIG.AutoRebirth or __slctx.CONFIG.AutoEvolution) then
        __slctx.Strategy.nextCycle('полный проход завершён; автосбросы выключены',p.purchases==0 and 1 or 0);return
    end
    local inv,err=__slctx.Strategy.readInvestors()
    if not __slctx.live() then return end
    if not inv then __slctx.pause('INVESTORS_READ_FAILED',tostring(err));return end
    r.totalMinimum=__slctx.Planner.totalMinimum(inv,r.spent)
    local age=__slctx.now()-(r.lastEvolutionRead or -math.huge)
    local unknownDue=r.spentUnknown and age>=__slctx.CONFIG.UnknownEvolutionReviewSeconds
    if __slctx.CONFIG.AutoEvolution and (not r.evo or age>=30
        or __slctx.Planner.shouldInspectEvolution(r.evo.index,inv,r.spent,unknownDue,r.evo.ready)) then
        local evo,ee=__slctx.Strategy.readEvolution()
        if not __slctx.live() then return end
        if not evo then __slctx.pause('EVOLUTION_READ_FAILED',tostring(ee));return end
        r.evolutionCheckTotal=r.totalMinimum
        if evo.ready then r.reserveSince=__slctx.now();__slctx.Strategy.phase('EVOLVE_RESERVE','эволюция важнее обычного rebirth');return end
    end
    local goal=__slctx.Strategy.updatePowerGoal(inv)
    if goal and goal.canBuyNow and goal.nextBatch and __slctx.Strategy.powerWorthBuying(goal) then
        r.powerReturn='BUY';r.powerPurchasePlan=goal
        __slctx.Strategy.phase('POWERS','нужная пачка доступна без потери времени на rebirth');return
    end
    local permit,reason,gain,detail=__slctx.Strategy.resetAllowed(inv)
    if permit and reason=='RESET_FOR_UPGRADE_STACK' then
        if not __slctx.Strategy.refreshPowerQuote() then permit=false;reason='POWER_QUOTE_NOT_REVALIDATED'
        else
            goal=__slctx.Strategy.updatePowerGoal(inv)
            permit,reason,gain,detail=__slctx.Strategy.resetAllowed(inv)
        end
    end
    r.gain=gain;r.lastDecision=reason;r.lastResetEstimate=detail
    __slctx.Strategy.logResetEstimate(detail,reason)
    r.resetPowerPlan=permit and reason=='RESET_FOR_UPGRADE_STACK' and goal or nil
    __slctx.log('CYCLE_DECISION','full pass='..p.id..'; '..reason..'; net income factor='..tostring(gain)
        ..'; reset/rebuild='..tostring(detail and (detail.cycle or detail.cost))
        ..'; discounted input saved='..tostring(detail and detail.saved))
    if goal then
        __slctx.log('POWER_TARGET',goal.title..'; price='..__slctx.BN.format(goal.price)..'; required reward='..__slctx.BN.format(goal.requiredReward)
            ..'; missing='..__slctx.BN.format(goal.shortfall)..'; after spend bank='..__slctx.BN.format(goal.bankAfterPower)
            ..'; next batch='..tostring(goal.nextBatch)..'; '..tostring(goal.quality))
    end
    if permit and __slctx.CONFIG.AutoRebirth then __slctx.doReset('rebirth');return end
    r.resetPowerPlan=nil
    local amount=__slctx.cash();local q=r.buyQuote
    if q and q.cost and amount and __slctx.BN.cmp(amount,q.cost)>=0 then
        __slctx.Strategy.nextCycle('полный проход завершён; выкупаю доступную цепочку базы');return
    end
    if reason=='PROTECTED_MAJOR_TARGET' or reason=='BASE_SOON' or reason=='BUILD_TARGET_SOON' then
        if __slctx.Strategy.reserveGoal(q,__slctx.Strategy.rate(),reason) then return end
    end
    r.emptyPasses=p.purchases==0 and (r.emptyPasses or 0)+1 or 0
    __slctx.Strategy.nextCycle(reason,p.purchases==0 and math.min(12,2^math.min(3,r.emptyPasses)) or 0)
end
function __slctx.Strategy.waitCash()
    local r=__slctx.Strategy.route();local goal=r.goal
    if not goal then __slctx.Strategy.phase('CHECKPOINT','goal cleared');return end
    local c=goal.candidate;local amount=__slctx.cash()
    if amount and c.cost and __slctx.BN.cmp(amount,c.cost)>=0 then
        -- At the exact deadline, an affordable purchase wins over a reset.
        local fresh,why=__slctx.focusCandidate(c)
        if fresh and __slctx.affordable(fresh,__slctx.cash()) then
            if __slctx.Strategy.safePurchase(fresh) then
                r.upgradeWall=false;r.majorDeclined=nil
                __slctx.Strategy.phase(fresh.kind=='buy' and 'BUY' or 'UPGRADE','saved target purchased')
            end
            return
        end
        if why=='QUOTE_CHANGED_AFTER_NAVIGATION' then
            __slctx.Strategy.resumeGrowth(c,'reserved quote changed; replan');return
        end
        if not __slctx.live() then return end
    end
    if __slctx.now()>=goal.deadline then
        if r.wall then r.wall.expired[goal.id]=true end
        r.majorDeclined=true;r.goal=nil;r.waitSuggestion=nil
        __slctx.log('RESERVE_EXPIRED','Original deadline retained; no fresh 30s loop')
        -- A reserve opened before exhausting upgrades must return to growth, not reset.
        if not r.upgradeWall then __slctx.Strategy.phase('UPGRADE','reservation expired; finish upgrades')
        else __slctx.Strategy.phase('CHECKPOINT','reservation expired; compare rebirth gain') end
        return
    end
    __slctx.updateRate();local rate=__slctx.Strategy.rate();local eta=__slctx.Core.eta(amount,c.cost,rate)
    __slctx.status('WAIT_CASH',string.format('Коплю на %s; ETA %s с; окно %.1f с. Другие покупки остановлены.',
        c.name,eta and eta<1e6 and string.format('%.1f',eta) or '?',math.max(0,goal.deadline-__slctx.now())))
end
function __slctx.Strategy.waitInvestors()
    -- Legacy phase recovery: never remain in an investor-only polling loop.
    __slctx.Strategy.waitGrowth()
end
function __slctx.Strategy.reserveEvolution()
    local r=__slctx.Strategy.route()
    if not __slctx.S.resetEnabled then __slctx.Strategy.phase('WAIT_GROWTH','resets switched off');return end
    if not __slctx.CONFIG.AutoEvolution then __slctx.Strategy.phase('CHECKPOINT','auto-evolution disabled');return end
    local evo,err=__slctx.readEvolution() -- already visible: read fields only, no menu tour or fixed settle.
    if not evo then __slctx.pause('EVOLUTION_READ_FAILED',tostring(err));return end
    r.evo=evo;__slctx.S.prestige=__slctx.S.prestige or {};__slctx.S.prestige.evo=evo
    if not evo.ready then __slctx.Strategy.resumeGrowth(nil,'evolution readiness changed');return end
    local allowed,reason=__slctx.Core.evolutionGuard(evo,__slctx.CONFIG.TabletReserve)
    if allowed then __slctx.doReset('evolve');return end
    __slctx.status(reason,'Эволюция готова. Жду видимый стартовый запас '..__slctx.CONFIG.TabletReserve..' инвесторов; rebirth не делаю.')
    if __slctx.now()-(r.reserveSince or __slctx.now())>=__slctx.CONFIG.EvolutionReserveWaitSeconds then
        -- More growth can improve the preview. Do not convert this timeout into a rebirth.
        r.evolutionReserveRetryAt=__slctx.now()+4
        __slctx.Strategy.resumeGrowth(nil,'400-investor preview not reached; continue growing')
    end
end
function __slctx.Strategy.halo()
    local r=__slctx.Strategy.route()
    if not (r.endPurchased or r.completionSeen) then __slctx.Strategy.resumeGrowth(nil,'no completion evidence');return end
    if not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoHalo then
        __slctx.status('HALO_AVAILABLE_PATH','Конец цепочки покупок обнаружен. Автосбросы выключены.');return
    end
    local h,err
    if not r.haloChecked or not __slctx.visible(__slctx.g(__slctx.paths.halo)) then h,err=__slctx.Strategy.readHalo();r.haloChecked=true
    else h,err=__slctx.readHalo() end -- observe the open gate, never visit it throughout early growth.
    if not h then __slctx.pause('HALO_READ_FAILED',tostring(err));return end
    if h.ready then __slctx.doReset('halo');return end
    __slctx.status('HALO_GATE_WAIT','Покупка конца цепочки обнаружена, но Ascend ещё закрыт: '..tostring(h.objective)..'. Сброс не отправлен.')
end
-- HALO_RUNTIME_30_BEGIN
-- The controller below replaces the 2.x decision scheduler. GUI input, transaction
-- receipts, capital accounting and reset execution guards remain separate adapters.

end
