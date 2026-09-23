-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.Strategy.new()
    return {phase='BOOT',reason='initial live state',evo=nil,spent=__slctx.BN.new(0),spentUnknown=true,
        cards={},buyQuote=nil,models={},upgradeWall=false,wall=nil,goal=nil,
        endPurchased=false,completionSeen=false,haloChecked=false,unknownSince=nil,
        bootTablet=true,bootEvolution=true,originInvestors=nil,rebuildEstimate=nil,
        menuReads={investors=0,evolution=0,halo=0,tablet=0,powers=0},lastDecision='',lastReset=nil,
        blocked={},powerPending=true,powerSkipped={},powerUsed=__slctx.BN.new(0),powerBase=nil,
        batchSelected=nil,batchUnavailable=false,powerBank=nil,powerQuotes={},priceModels={},
        fullPassCount=0,runWork={},runUpgradeSeconds=0,runUpgradeActions=0,failedTierHints={}}

end
function __slctx.Strategy.route()
    if not __slctx.S.route then __slctx.S.route=__slctx.Strategy.new() end
    return __slctx.S.route
end
function __slctx.Strategy.phase(name,reason)
    if name~='BUY' and __slctx.Driver.pressed and __slctx.Driver.pressed.kind=='buyHold' then __slctx.Virtual.release() end
    local r=__slctx.Strategy.route()
    if r.phase~=name then __slctx.log('PHASE',r.phase..' -> '..name..' | '..tostring(reason or '')) end
    r.phase=name;r.reason=reason or r.reason
    __slctx.status(name,r.reason)
end
function __slctx.Strategy.quotes()
    local r=__slctx.Strategy.route();local all={}
    if r.buyQuote then all[#all+1]=r.buyQuote end
    for _,c in ipairs(r.cards) do all[#all+1]=c end
    __slctx.S.catalog=all
    return all
end
function __slctx.Strategy.readCards()
    local r=__slctx.Strategy.route();r.cards=__slctx.readCards();__slctx.Strategy.quotes();return r.cards
end
function __slctx.Strategy.refreshResetBuy()
    local r=__slctx.Strategy.route()
    if r.buyQuote or r.completionSeen or r.endPurchased then return true end
    -- A confirmed BUY intentionally clears its quote. A timer can run before
    -- growBuy reads the NEXT item, even while stand quotes still exist.
    -- Refresh only the observation; never purchase to populate a cache.
    local why='BUY_NOT_OBSERVED'
    for attempt=1,3 do
        if not __slctx.live() then return false,'PAUSED' end
        if __slctx.S.actionPending or __slctx.S.resetChildPending or __slctx.S.resetSession then return false,'ACTION_PENDING' end
        local opened,err=__slctx.ensureStrip()
        if not __slctx.live() then return false,'PAUSED' end
        if opened then
            local q=__slctx.readBuy()
            if __slctx.Planner.completionMarker(__slctx.t(__slctx.paths.buy..'/Purchase'),__slctx.t(__slctx.paths.buy..'/PurchasePrice'),__slctx.t(__slctx.paths.buy..'/PurchaseInfo')) then
                r.completionSeen=true;__slctx.Strategy.quotes();return true
            end
            if q and (q.cost or q.parseReason=='hidden_large') then
                r.buyQuote=q;__slctx.Strategy.quotes();__slctx.Strategy.observeBuildQuote(q)
                __slctx.log('RESET_BUY_REFRESHED',q.name..' | cost='..__slctx.BN.format(q.cost)..' | attempt='..attempt)
                return true
            end
            why=q and ('BUY_PRICE_UNREADABLE: '..tostring(q.parseReason)) or 'BUY_NOT_OBSERVED'
        else why=tostring(err or 'BUY_MENU_NOT_READY') end
        __slctx.log('RESET_BUY_REFRESH_RETRY',attempt..'/3 | '..why)
        if attempt<3 and not __slctx.sleep(__slctx.CONFIG.RecoverySettleSeconds) then return false,'PAUSED' end
    end
    return false,why
end
function __slctx.Strategy.knownQuotes()
    local r=__slctx.Strategy.route()
    if next(r.blocked or {}) then return false,'UNRESOLVED_PURCHASE' end
    if not r.buyQuote and not r.completionSeen and not r.endPurchased then return false,'BUY_CACHE_EMPTY' end
    for _,c in ipairs(__slctx.Strategy.quotes()) do
        if not c.cost and c.parseReason~='owned' and c.parseReason~='hidden_large' then
            return false,'UNREADABLE_PRICE: '..tostring(c.name or c.id)..' | '..tostring(c.parseReason)
        end
    end
    return true
end
function __slctx.Strategy.affordableQuote()
    local amount=__slctx.cash()
    if not amount then return nil end
    for _,c in ipairs(__slctx.Strategy.quotes()) do
        -- Cached Active=false can mean "not enough money" at the earlier sample.
        -- A funded quote is routed back to its UI and verified there before clicking.
        if c.cost and __slctx.BN.cmp(amount,c.cost)>=0 and __slctx.Safety.batchAllowed(c)
            and not (__slctx.Strategy.route().blocked or {})[__slctx.Safety.key(c)] then return c end
    end
end
function __slctx.Strategy.resumeGrowth(c,reason)
    __slctx.Strategy.cancelResetIntent('RETURN_TO_GROWTH')
    local r=__slctx.Strategy.route();r.goal=nil;r.wall=nil;r.upgradeWall=false;r.unknownSince=nil
    __slctx.Strategy.phase(c and c.kind=='upgrade' and 'UPGRADE' or 'BUY',reason)
end
function __slctx.Strategy.recordSpend(amount)
    __slctx.Strategy.cancelResetIntent('INVESTOR_SPEND')
    __slctx.Strategy.route().economicRevision=(__slctx.Strategy.route().economicRevision or 0)+1
    local r=__slctx.Strategy.route()
    r.spent=__slctx.BN.add(r.spent,amount or __slctx.BN.new(0))
end
-- PROGRESS_REVIEW_BEGIN
function __slctx.Strategy.reviewDue() return nil end
function __slctx.Strategy.requestReview(reason)
    local p=__slctx.Strategy.route().pass
    if p and p.finished then __slctx.Strategy.phase('CHECKPOINT',reason) end
end
function __slctx.Strategy.resetReviewClock() end
-- PROGRESS_REVIEW_END
function __slctx.Strategy.receipt(c,beforeRate)
    __slctx.Strategy.cancelResetIntent('ECONOMIC_RECEIPT')
    __slctx.Strategy.route().economicRevision=(__slctx.Strategy.route().economicRevision or 0)+1
    __slctx.S.cashFlow=__slctx.S.cashFlow or __slctx.Core.newCashFlow();__slctx.S.cashFlow:spend(c.cost)
    -- BUY belongs to the same financial segment; retain its confirmed debit and history.
    local r=__slctx.Strategy.route();r.wall=nil;r.goal=nil;r.waitSuggestion=nil;r.unknownSince=nil;r.nearEvoWait=false;r.rewardRate=nil
    r.runSpent=__slctx.BN.add(r.runSpent or __slctx.BN.new(0),c.cost or __slctx.BN.new(0))
    if c.kind=='buy' then
        r.runBuyCount=(r.runBuyCount or 0)+1;r.epochBuys=(r.epochBuys or 0)+1
        __slctx.Strategy.recordBasePurchase(c)
        if c.newSource or __slctx.Planner.globalMultiplier(c) then r.buildMilestone=true end
    end
    r.majorDeclined=nil;r.growth=nil
    if c.kind=='upgrade' then
        r.upgradeSerial=(r.upgradeSerial or 0)+1;r.upgradeVisits=r.upgradeVisits or {}
        r.upgradeVisits[c.path]=r.upgradeSerial
    end
    if c.kind=='buy' then
        r.buyBurstCount=(r.buyBurstCount or 0)+1
        r.priceModels={};r.batchQuotes={};r.models={}
        r.upgradeWall=false;r.buyQuote=nil;r.savingsBudget=nil;r.waitSuggestion=nil
        if __slctx.Planner.isTerminalName(c.name) then
            r.endPurchased=true;r.haloChecked=false
            __slctx.log('END_PURCHASE_OBSERVED','The End receipt; live Ascend gate will be checked once')
        end
    else
        for _,after in ipairs(__slctx.readCards()) do
            if after.path==c.path then
                local learned=__slctx.Planner.learnUpgrade(r.models[c.path],c,after)
                if learned then r.models[c.path]=learned end
                r.priceModels=r.priceModels or {}
                r.priceModels[c.path]=__slctx.Planner.learnPrice(r.priceModels[c.path],c,after)
                local n0,n1=__slctx.Core.count(c.count),__slctx.Core.count(after.count)
                local units=n0 and n1 and math.max(0,n1-n0) or __slctx.Core.count(c.stack) or 0
                r.runWork=r.runWork or {};r.runWork[c.path]=(r.runWork[c.path] or 0)+units
                if r.pass and not r.pass.finished then
                    r.pass.work=r.pass.work or {};r.pass.work[c.path]=(r.pass.work[c.path] or 0)+units
                end
                if r.recovery then
                    r.recovery.work=r.recovery.work or {};r.recovery.work[c.path]=(r.recovery.work[c.path] or 0)+units
                end
                break
            end
        end
    end
end
function __slctx.Strategy.readInvestors(force)
    local r=__slctx.Strategy.route()
    if not force and r.latestInvestors and __slctx.now()-r.latestInvestors.time<1.5 then return r.latestInvestors end
    r.menuReads.investors=r.menuReads.investors+1
    local v,e=__slctx.readInvestors()
    if v then
        __slctx.S.prestige=__slctx.S.prestige or {};__slctx.S.prestige.inv=v
        r.originInvestors=r.originInvestors or v.investors
        r.latestInvestors=v
        if r.powerBase then __slctx.Strategy.syncPowerBank(v.investors) end
        __slctx.Strategy.recordObjective(v)
    end
    return v,e
end
function __slctx.Strategy.readEvolution()
    local r=__slctx.Strategy.route();r.menuReads.evolution=r.menuReads.evolution+1
    local v,e=__slctx.readEvolution()
    if v then
        r.evo=v;r.lastEvolutionRead=__slctx.now();__slctx.S.prestige=__slctx.S.prestige or {};__slctx.S.prestige.evo=v
        r.target,r.targetFruit=__slctx.Planner.target(v.index)
    end
    return v,e
end
function __slctx.Strategy.readHalo()
    local r=__slctx.Strategy.route();r.menuReads.halo=r.menuReads.halo+1
    local v,e=__slctx.readHalo()
    if v then __slctx.S.prestige=__slctx.S.prestige or {};__slctx.S.prestige.halo=v end
    return v,e
end
function __slctx.Strategy.afterReset(kind,before)
    __slctx.Strategy.resetBaseProgress(kind)
    __slctx.Strategy.cancelResetIntent('RESET_COMPLETED')
    __slctx.Strategy.route().economicRevision=(__slctx.Strategy.route().economicRevision or 0)+1
    local r=__slctx.Strategy.route()
    local retainedBatch=kind=='rebirth' and __slctx.Strategy.largestBatch() or nil
    local retainedQuotes=kind=='rebirth' and r.powerQuotes or nil
    local finishedObjective=r.evo and r.evo.index
    local epochClock=r.objectiveStarted
    if kind=='evolve' or kind=='halo' then
        r.objectiveHistory=r.objectiveHistory or {}
        if epochClock then
            r.objectiveHistory[#r.objectiveHistory+1]={kind=kind,evolution=finishedObjective,seconds=__slctx.now()-epochClock,
                buys=r.epochBuys or 0,rebirths=r.epochRebirths or 0}
            while #r.objectiveHistory>32 do table.remove(r.objectiveHistory,1) end
        end
        r.objectiveStarted=__slctx.now();r.epochBuys=0;r.epochRebirths=0
    else r.epochRebirths=(r.epochRebirths or 0)+1 end
    r.cycleStarts=r.cycleStarts or {};r.cycleStats=r.cycleStats or {}
    local start=r.cycleStarts[kind]
    if start then
        local dt=__slctx.now()-start
        local stat=r.cycleStats[kind] or {count=0,total=0,best=math.huge}
        stat.count=stat.count+1;stat.total=stat.total+dt;stat.last=dt;stat.best=math.min(stat.best,dt)
        r.cycleStats[kind]=stat
        __slctx.log('CYCLE_MEASURED',kind..' full interval='..string.format('%.2f',dt)..'s; first attached partial interval excluded')
    end
    r.cycleStarts[kind]=__slctx.now()
    -- A higher reset interrupts lower-tier cycles; never mix their partial intervals.
    if kind=='evolve' or kind=='halo' then r.cycleStarts.rebirth=nil;r.cycleStats.rebirth=nil end
    if kind=='halo' then r.cycleStarts.evolve=nil;r.cycleStats.evolve=nil end
    if kind=='rebirth' then
        -- Rebirth keeps powers and evolution; do not re-open either menu to rediscover them.
        local after=__slctx.BN.parse(__slctx.t(__slctx.paths.investors..'/Body/Amount/Quantity'))
        __slctx.Strategy.creditRebirth(before.investors,after)
        r.originInvestors=after;r.latestInvestors=nil
        r.powerPurchasePlan=r.resetPowerPlan;r.capabilityPending=r.resetPowerPlan;r.resetPowerPlan=nil
        if r.recovery then
            r.rebuildLowerBound=math.max(r.rebuildLowerBound or 0,__slctx.now()-r.recovery.started)
            __slctx.log('RECOVERY_CENSORED','Next reset before comparable income; unfinished recovery not counted as a fast sample')
        end
        r.recovery=r.nextRecovery;r.nextRecovery=nil
        r.lastReset=kind;r.rebuilding=true;r.bootTablet=not (__slctx.S.tablet and __slctx.S.tablet.owned)
        r.bootEvolution=false
    else
        r.spent=__slctx.BN.new(0);r.spentUnknown=false;r.originInvestors=nil;r.latestInvestors=nil
        r.evo=nil;r.target=nil;r.models={};r.bootEvolution=true;r.bootTablet=true
        r.powerBase=nil;r.powerUsed=__slctx.BN.new(0);r.powerBank=nil;r.powerUnresolved=nil
        r.powerPurchasePlan=nil;r.capabilityPending=nil;r.resetPowerPlan=nil
        r.previousEvolution=nil
        if kind=='halo' then r.previousHalo=nil end
        r.lastFullPass=nil;r.rebuildProfile=nil;r.fullPassCount=0;r.failedTierHints={}
        r.recovery=nil;r.nextRecovery=nil;r.rebuildEstimate=nil;r.rebuildLowerBound=nil
        __slctx.S.tablet=nil;__slctx.S.prestige=nil
        if kind=='halo' then
            r.endPurchased=false;r.completionSeen=false;r.haloChecked=false
            r.rebuildEstimate=nil
        end
        r.lastReset=kind
    end
    r.wall=nil;r.goal=nil;r.cards={};r.buyQuote=nil;r.upgradeWall=false;r.unknownSince=nil
    r.preferredStack=nil;r.stackReduced=false;r.stackRestorePending=false
    r.batchSelected=nil;r.batchUnavailable=false;r.blocked={}
    r.availableBatches=nil;r.batchVerified=nil;r.nextBatchProbe=nil;r.preferredReviewBatch=nil;r.batchRetrySince=nil
    r.growth=nil;r.stalledAt=nil;r.nextGrowthScan=nil;r.upgradeVisits={};r.upgradeSerial=0
    r.pass=nil;r.maxUnavailable=nil;r.savingsBudget=nil;r.waitSuggestion=nil;r.lastPlan=nil
    __slctx.Strategy.resetReviewClock();r.reviewFrom=nil;r.reviewReason=nil
    r.powerPending=true;r.powerSkipped={};r.powerQuotes={};r.powerGoal=nil
    r.priceModels={};r.maxObserved=nil;r.runWork={};r.runUpgradeSeconds=0;r.runUpgradeActions=0
    r.capabilityOnly=nil;r.capabilityBackoff=nil;r.buyBurstCount=0;r.powerReturn=nil;r.runObservedAt=__slctx.now()+__slctx.CONFIG.AfterResetWait
    r.growthSamples={};r.reviewReturn=nil;r.boostQuote=nil;r.macroPlan=nil;r.lastStrategicReview=__slctx.now()
    r.schema28=true;r.cleanRun=true;r.frontierRecovery=r.recovery
    r.frontierTrace=nil;r.runSpent=__slctx.BN.new(0);r.runServiceSeconds=0;r.runMenuSeconds=0;r.runBuyCount=0
    r.passiveRows={};r.uiObservation=nil;r.rewardSamples={};r.rewardCurve=nil
    r.buildStarted=__slctx.now()+__slctx.CONFIG.AfterResetWait;r.lastBuildAt=nil;r.lastBuildBuys=0;r.buildMilestone=nil
    r.fastBuildPending=true;r.objectiveReturn=nil;r.objectiveText=nil;r.objectiveUrgent=nil
    r.reviewSnapshot=nil;r.reviewUrgent=nil
    if retainedBatch then
        r.maxObserved=retainedBatch=='max' or nil
        r.availableBatches=type(retainedBatch)=='number' and {retainedBatch} or nil
        r.powerQuotes=retainedQuotes or {}
    end
    __slctx.S.catalog={};__slctx.S.catalogDirty=true;__slctx.S.incomeAttempts={};__slctx.S.nextIncomeAt=0;__slctx.S.upgradeVisited={}
    __slctx.Strategy.phase((r.bootEvolution or r.bootTablet) and 'BOOT' or (__slctx.CONFIG.AutoInvestorPowers and 'POWERS' or 'BUY'),'confirmed '..kind)
end
function __slctx.Strategy.enterWall()
    local r=__slctx.Strategy.route()
    if not r.wall then
        r.wall={start=__slctx.now(),deadline=__slctx.now()+__slctx.CONFIG.MaxWaitSeconds,expired={},inspected=false}
        __slctx.S.rate:reset();__slctx.S.rate:add(__slctx.now(),__slctx.cash())

        __slctx.log('GROWTH_WALL','BUY and upgrades exhausted; shared wait budget '..__slctx.CONFIG.MaxWaitSeconds..'s')
    end
    __slctx.Strategy.phase('MEASURE','estimate accumulation before reset decision')
end

function __slctx.Strategy.savings(onlyMajor)
    local r=__slctx.Strategy.route();if not r.wall then return nil end
    local rate,source=__slctx.Strategy.rate()
    local items=__slctx.Strategy.quotes()
    if onlyMajor then
        items={}
        for _,c in ipairs(__slctx.Strategy.quotes()) do
            if (c.multiplier or 0)>=__slctx.CONFIG.MajorMultiplier then items[#items+1]=c end
        end
    end
    local target,eta=__slctx.Planner.pickSavings(items,__slctx.cash(),rate,r.wall.deadline-__slctx.now(),__slctx.CONFIG.MajorMultiplier)
    if target and not r.wall.expired[target.id] then
        r.goal={id=target.id,candidate=target,deadline=r.wall.deadline,eta=eta,source=source}
        __slctx.log('RESERVE_CASH',target.name..' | ETA='..string.format('%.2f',eta)..' | '..source)
        __slctx.Strategy.phase('WAIT_CASH','protected next purchase; other spending disabled')
        return target
    end
end

function __slctx.Strategy.rebirthBarrier(inv)
    local r=__slctx.Strategy.route()
    if r.powerUnresolved or next(r.blocked or {}) then return false,'UNRESOLVED_PURCHASE' end
    -- Affordable minor levels do not veto a profitable reset. Fresh reset gates,
    -- pending receipts and evolution readiness remain authoritative.
    if __slctx.CONFIG.AutoEvolution and r.evo and r.evo.ready and not (r.resetIntent and r.resetIntent.preferRebirthToEvolution33) then return false,'EVOLUTION_TAKES_PRIORITY' end
    local total=__slctx.Planner.totalMinimum(inv,r.spent)
    local threshold=r.target and __slctx.BN.mul(r.target,0.999)
    if __slctx.CONFIG.AutoEvolution and threshold and total and __slctx.BN.cmp(total,threshold)>=0
        and (not r.evolutionCheckTotal or __slctx.BN.cmp(r.evolutionCheckTotal,threshold)<0) then
        return false,'NEW_EVOLUTION_THRESHOLD'
    end
    return __slctx.Strategy.validateResetIntent(inv)
end
function __slctx.Strategy.safePurchase(c)
    local r=__slctx.Strategy.route();r.blocked=r.blocked or {}
    local key=__slctx.Safety.key(c)
    if r.blocked[key] then return false end
    local previous=nil
    for attempt=1,__slctx.CONFIG.PurchaseAttempts do
        if not __slctx.live() then return false end
        if previous then
            __slctx.status('RECOVER_PURCHASE','Обновляю меню и результат: '..c.name..' ('..attempt..'/'..__slctx.CONFIG.PurchaseAttempts..')')
            if not __slctx.sleep(__slctx.CONFIG.RecoverySettleSeconds) then return false end
            local routed,why
            if c.kind=='upgrade' then routed,why=__slctx.manageTab('Manage') else routed,why=__slctx.ensureStrip() end
            if routed and __slctx.Safety.proof(previous) then __slctx.Safety.commit(previous,true);return true end
            if not routed then __slctx.log('RECOVERY_ROUTE',tostring(why)) end
            local fresh=__slctx.focusCandidate(c)
            if fresh then
                c=fresh
                if not __slctx.affordable(c,__slctx.cash()) then __slctx.log('RECOVERY_REPLAN','Quote no longer affordable; not a fatal error');return false end
            elseif routed then
                __slctx.log('RECOVERY_REPLAN','Quote changed without a reliable receipt; re-read next iteration');return false
            end
        end
        local done,err,rec=__slctx.buy(c)
        if done then return true,rec end
        if not __slctx.live() then return false end
        if __slctx.S.actionPending or tostring(err):find('CALLBACK_STILL_PENDING',1,true) then
            __slctx.pause('CALLBACK_PENDING','Обработчик ещё выполняется; повторная покупка не отправлена.');return false
        end
        if err=='QUOTE_UNAFFORDABLE' or err=='SMALL_BATCH_BLOCKED' or err=='QUOTE_CHANGED_AFTER_NAVIGATION' then
            __slctx.log('PURCHASE_REPLAN',tostring(err));return false
        end
        if c.maxMode and rec and rec.sent then
            r.blocked[key]={c=rec.c,receipt=rec,reason=tostring(err)}
            __slctx.log('MAX_RECEIPT_PENDING','MAX was dispatched once; no blind repeat: '..c.path)
            return false
        end
        if c.maxMode and tostring(err):find('BEFORE_CLICK',1,true) then return false end
        previous=rec or previous
        __slctx.log('PURCHASE_RETRY',attempt..'/'..__slctx.CONFIG.PurchaseAttempts..' | '..tostring(err)..' | '..__slctx.Safety.describe(c))
        if __slctx.S.windowFocused==false then __slctx.Focus.reject(tostring(err));if not __slctx.Focus.await() then return false end end
        if attempt==__slctx.CONFIG.PurchaseAttempts then
            r.blocked[key]={c=c,receipt=previous,reason=tostring(err)}
            __slctx.log('PURCHASE_DEFERRED','Other candidates remain usable; resets blocked until reconciled: '..__slctx.Safety.describe(c))
        end
    end
    return false
end
function __slctx.Strategy.reconcileBlocked()
    local r=__slctx.Strategy.route()
    for key,v in pairs(r.blocked or {}) do
        if v.receipt and __slctx.Safety.proof(v.receipt) then
            __slctx.Safety.commit(v.receipt,true);r.blocked[key]=nil
        end
    end
end
function __slctx.Strategy.stopForBlocked()
    local r=__slctx.Strategy.route()
    if r.powerUnresolved then
        __slctx.pause('POWER_OUTCOME_UNRESOLVED','Не определён результат траты инвесторов; сброс не используется как исправление.');return true
    end
    local key,v=next(r.blocked or {})
    if not key then return false end
    __slctx.pause('PURCHASE_RECOVERY_EXHAUSTED','После '..__slctx.CONFIG.PurchaseAttempts..' проверенных попыток не подтверждено: '
        ..v.c.name..'. Другие доступные покупки обработаны; rebirth не используется как исправление ошибки. F7 — журнал.')
    return true
end
function __slctx.Strategy.currentBatch()
    local button=__slctx.g(__slctx.paths.manage..'/StackButton')
    local label=__slctx.usable(button) and __slctx.Core.clean(__slctx.childText(button,'Stack')):lower() or ''
    -- UpgradeStack unlocks MAX and can select it immediately. In this mode
    -- each card advertises a different, balance-dependent quantity.
    -- This is a selector mode, never a numeric batch or a malformed quote.
    if label=='max' then return 'max' end
    local selected=__slctx.Core.count(label)
    local observed=nil
    for _,c in ipairs(__slctx.readCards()) do
        local n=__slctx.Core.count(c.stack)
        if not n then return nil end
        if observed and observed~=n then return nil end
        observed=n
    end
    if selected and observed and selected~=observed then return nil end
    return observed or selected
end
function __slctx.Strategy.rememberBatch(n)
    if type(n)~='number' or n<1 then return end
    local r=__slctx.Strategy.route();r.availableBatches=r.availableBatches or {}
    for _,v in ipairs(r.availableBatches) do if v==n then return end end
    r.availableBatches[#r.availableBatches+1]=n
    table.sort(r.availableBatches,function(a,b)return a>b end)
end
-- A selector change exposes quotes for ALL stands. Reuse those exact quotes

end
