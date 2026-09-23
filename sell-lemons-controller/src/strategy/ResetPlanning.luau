-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.Strategy.baseProgress()
    local r=__slctx.Strategy.route();local epoch=r.evo and r.evo.index
    local b=r.baseProgress282
    if not b or b.version~=282 or (b.epoch~=nil and epoch~=nil and b.epoch~=epoch) then
        b={version=282,epoch=epoch,depth=0,high=0,comparable=false,repeated=0};r.baseProgress282=b
    end
    if b.epoch==nil and epoch~=nil then b.epoch=epoch end
    return b
end
function __slctx.Strategy.baseQuoteKey(q)
    if not q then return nil end
    return tostring(q.id or q.name)..'|'..tostring(q.info or '')
end
function __slctx.Strategy.observeBuildQuote(q)
    if not q then return false end
    local r=__slctx.Strategy.route();local key=__slctx.Strategy.baseQuoteKey(q)
    local at=q.observedAt
    if not at or __slctx.now()-at>__slctx.CONFIG.BuildQuoteFreshSeconds or at>__slctx.now() then return false end
    if r.buildWall and r.buildWall.key~=key then r.buildWall=nil end
    r.buildQuote={key=key,id=q.id,cost=q.cost,at=at,serial=r.runBuyCount or 0}
    return q.cost~=nil
end
function __slctx.Strategy.recordBasePurchase(c)
    local r=__slctx.Strategy.route();local b=__slctx.Strategy.baseProgress()
    b.depth=b.depth+1;b.lastSignature=__slctx.Strategy.baseQuoteKey(c);b.lastBuyAt=__slctx.now()
    if b.comparable then
        if b.depth<=b.high then b.repeated=b.repeated+1 else b.high=b.depth end
        if b.debt and b.depth>=b.debt then
            __slctx.log('BUILD_FRONTIER_RESTORED','confirmed base purchases='..b.depth..'; prior frontier='..b.debt)
            b.debt=nil
        end
    end
    r.buildWall=nil;r.buildQuote=nil
end
function __slctx.Strategy.resetBaseProgress(kind)
    local r=__slctx.Strategy.route();local b=__slctx.Strategy.baseProgress()
    if kind=='rebirth' then
        __slctx.log('BUILD_RESET_POSITION','depth='..b.depth..'; known prefix='..tostring(b.comparable)
            ..'; high='..b.high..'; repeated buys='..b.repeated)
        local high=b.comparable and math.max(b.high,b.depth) or 0
        r.baseProgress282={version=282,epoch=b.epoch,depth=0,high=high,comparable=true,
            debt=high>0 and high or nil,repeated=b.repeated}
    else r.baseProgress282={version=282,depth=0,high=0,comparable=true,repeated=0} end
    r.buildWall=nil;r.buildQuote=nil
end
function __slctx.Strategy.recordBuildSweep(cards)
    local r=__slctx.Strategy.route();local p=r.pass
    if not p or not p.finished or not p.complete or p.quickBuild then return end
    local q=r.buyQuote;local key=__slctx.Strategy.baseQuoteKey(q)
    if not q or not q.cost or p.buildQuoteKey~=key or p.buildBuySerial~=(r.runBuyCount or 0) then return end
    -- Coverage means the same stand identities, not just the same count.
    if #cards~=#p.order then return end
    local seen={};for _,item in ipairs(p.order) do seen[item.path]=true end
    for _,c in ipairs(cards) do if not seen[c.path] then return end;seen[c.path]=nil end
    if next(seen) then return end
    local amount=__slctx.cash();if not amount or __slctx.BN.cmp(amount,q.cost)>=0 then r.buildWall=nil;return end
    local w=r.buildWall
    if not w or w.key~=key or w.serial~=p.buildBuySerial then
        w={key=key,serial=p.buildBuySerial,started=p.started,passes=0,weak=0};r.buildWall=w
    end
    if w.pass==p.id then return end
    local after,_,kind=__slctx.Strategy.rate();local growth=nil
    if after and p.buildRate and kind==p.buildRateKind then growth=__slctx.BN.number(__slctx.BN.div(after,p.buildRate)) end
    if p.rateKnown and p.beforeRate and p.afterRate then growth=__slctx.BN.number(__slctx.BN.div(p.afterRate,p.beforeRate)) end
    local weak=p.purchases==0 or growth and growth<=1+__slctx.CONFIG.BuildWallWeakGain
    w.passes=w.passes+1;w.weak=weak and w.weak+1 or 0;w.pass=p.id;w.finished=__slctx.now();w.gain=growth
    __slctx.log('BUILD_WALL_EVIDENCE','pass='..p.id..'; weak='..w.weak..'; purchases='..p.purchases
        ..'; income factor='..tostring(growth)..'; same next BUY='..tostring(q.name))
end
function __slctx.Strategy.buildPermissionContext(q,eta)
    local r=__slctx.Strategy.route();local p=r.pass;local key=__slctx.Strategy.baseQuoteKey(q);local quote=r.buildQuote
    local known=q and q.cost and quote and quote.key==key and quote.serial==(r.runBuyCount or 0)
        and quote.at<=__slctx.now() and __slctx.now()-quote.at<=__slctx.CONFIG.BuildQuoteFreshSeconds
    local w=r.buildWall
    local wall=known and w and p and p.complete and p.finished and not p.quickBuild
        and w.key==key and w.serial==(r.runBuyCount or 0) and w.pass==p.id
    local b=__slctx.Strategy.baseProgress()
    return {known=known==true,wall=wall~=nil and wall~=false,
        sustained=wall and w.weak>=2 and __slctx.now()-w.started>=__slctx.CONFIG.BuildWallConfirmSeconds or false,
        debt=b.comparable and b.debt~=nil and b.depth<b.debt or false,
        soon=eta and eta>0 and eta<math.huge and eta<=__slctx.CONFIG.BuildShortWaitSeconds
            and __slctx.Strategy.savingsRemaining(q,false)>0 or false}
end
-- CONSTRUCTION_RUNTIME_282_END
function __slctx.Strategy.rebuildInputSeconds(goal)
    local r=__slctx.Strategy.route();local work={};local sources=0
    local direct=__slctx.CONFIG.DirectUpgrades==true
    for _,c in ipairs(r.cards or {}) do
        local count=__slctx.Core.count(c.count)
        if not count then return __slctx.CONFIG.InitialFullLayoutSeconds,'incomplete layout; initial allowance' end
        work[c.path]=math.max(0,count-(c.source=='direct' and 0 or 1));sources=sources+1
        direct=direct and c.source=='direct'
    end
    local batch=goal and goal.canBuyAfter and goal.nextBatch or __slctx.Strategy.largestBatch()
    local clicks=__slctx.Planner.workClicks(work,batch)
    if sources==0 or not clicks then return __slctx.CONFIG.InitialFullLayoutSeconds,'unobserved layout/batch; initial allowance' end
    if direct then
        -- The measured upgrade latency is for a complete parallel batch.
        -- Sum only serial GUI actions; direct stands share each response round.
        clicks=0
        for _,levels in pairs(work)do
            clicks=math.max(clicks,levels>0 and (batch=='max' and 1 or math.ceil(levels/batch)) or 0)
        end
    end
    local buys=math.max(r.runBuyCount or 0,__slctx.Strategy.baseProgress().depth or 0)
    local input=buys*__slctx.Strategy.actionSeconds('buy')+clicks*__slctx.Strategy.actionSeconds('upgrade')
        +(direct and __slctx.CONFIG.DirectPurchases and 0 or (4+sources)*(r.menuTripSeconds or __slctx.CONFIG.InitialMenuTripSeconds))
    return math.max(__slctx.CONFIG.InitialFullLayoutSeconds,input),
        (direct and 'current parallel layout rounds' or 'current observed layout inputs')..'; unmeasured financing allowance'
end
function __slctx.Strategy.resetContext(inv,capabilityOnly)
    local r=__slctx.Strategy.route();local q=r.buyQuote;local amount=__slctx.cash();local rate,rateSource,rateKind=__slctx.Strategy.rate()
    local eta=q and q.cost and __slctx.Core.eta(amount,q.cost,rate) or math.huge
    -- BUILD_TARGET_SOON/PROTECTED_MAJOR_TARGET are bounded promises, not free
    -- queries that return MaxWaitSeconds forever without starting the clock.
    local short=eta and eta>0 and eta<math.huge and eta<=__slctx.CONFIG.BuildShortWaitSeconds
    local major=q and (q.multiplier or 0)>=__slctx.CONFIG.MajorMultiplier
        and eta and eta>0 and eta<math.huge and eta<=__slctx.CONFIG.MaxWaitSeconds
    local remaining=__slctx.Strategy.savingsRemaining(q,(short or major) and true or false)
    local goal=__slctx.Strategy.updatePowerGoal(inv);local planned=__slctx.BN.new(0);local powerSeconds=0
    -- Spend the selected quoted price, not an imaginary mandatory 5% debit.
    if __slctx.CONFIG.AutoInvestorPowers and goal and goal.canBuyAfter then
        planned=goal.price;powerSeconds=__slctx.Strategy.actionSeconds('power')+__slctx.CONFIG.InitialMenuTripSeconds
    end
    local growth,span=__slctx.Strategy.forwardGrowth();local work,workSource=__slctx.Strategy.powerWork(r.cards)
    local build=__slctx.Strategy.buildPermissionContext(q,eta)
    local after=__slctx.BN.sub(__slctx.BN.add(inv.investors,inv.reward),planned)
    local multiplier=inv.perInvestor and __slctx.BN.add(__slctx.BN.new(1),__slctx.BN.mul(after,inv.perInvestor))
    local trace=r.frontierTrace;local replay,why
    if multiplier and trace and trace.base and trace.kind==rateKind then replay,why=__slctx.Planner.replayFrontier(trace,__slctx.BN.div(multiplier,trace.base),__slctx.CONFIG) end
    if replay and trace.points[#trace.points] and __slctx.now()-trace.points[#trace.points].time>3 then replay=nil;why='frontier observation stale' end
    local reset=r.resetDuration or __slctx.CONFIG.InitialResetSeconds
    local setup=reset+__slctx.CONFIG.AfterResetWait+powerSeconds
    local input,inputSource=__slctx.Strategy.rebuildInputSeconds(goal)
    local restoreSeconds=replay and replay.seconds or math.max(__slctx.CONFIG.InitialFullLayoutSeconds,input)
    local flow=__slctx.S.cashFlow;local earned=flow and flow:earned(__slctx.now(),amount)
    local terminal=q and __slctx.Planner.isTerminalName(q.name)
    local directGoal=terminal and q.cost and __slctx.Core.eta(amount,q.cost,rate) or __slctx.Strategy.directGoalETA(inv)
    if terminal and directGoal and directGoal<math.huge then directGoal=directGoal+__slctx.Strategy.effectiveActionSeconds('buy') end
    local curve=not terminal and r.rewardCurve or nil
    if curve and (not flow or curve.segment~=flow.segment or __slctx.now()-curve.time>35) then curve=nil end
    return {pass=r.pass,capabilityOnly=capabilityOnly,powerGoal=goal,work=work,workSource=workSource,
        inv=inv,rate=rate,plannedSpend=planned,historicalSpent=r.spent,target=r.target,
        rewardCurve=curve,earned=earned,directGoalETA=directGoal,terminalTarget=terminal,
        buyFunded=q and q.cost and amount and __slctx.BN.cmp(amount,q.cost)>=0 or false,baseETA=eta,
        protectedMajor=q and (q.multiplier or 0)>=__slctx.CONFIG.MajorMultiplier and eta<=remaining and remaining>0,
        recoveryPending=r.recovery~=nil,restoreModel=replay,replayReason=why,setupSeconds=setup,
        fullLayoutInputSeconds=input,rebuildInputSource=inputSource,rebuildSeconds=restoreSeconds,resetSeconds=reset,powerSeconds=powerSeconds,
        actionSeconds=__slctx.Strategy.effectiveActionSeconds('upgrade'),futureGrowthSpeed=growth,growthObservationSeconds=span,
        cycle=setup+restoreSeconds,buildQuoteKnown=build.known,buildWallReady=build.wall,
        buildWallSustained=build.sustained,buildDebt=build.debt,buildSoon=build.soon,
        endReached=r.endPurchased or r.completionSeen}
end
function __slctx.Strategy.objectiveDue()
    local r=__slctx.Strategy.route()
    if not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoEvolution or not r.evo then return false end
    local time=__slctx.now()
    if time<(r.evolutionReserveRetryAt or 0) then return false end
    local base=__slctx.paths.evolution..'/Body/'
    local index=tonumber(__slctx.t(base..'Current/What'):lower():match('evolution%s+(%d+)'))
    local text=__slctx.t(base..'Progress');local pct=__slctx.Core.percent(text)
    if index==r.evo.index and pct and r.objectiveText~=nil and text~=r.objectiveText and pct>=99.99 then
        r.objectiveUrgent=true
    end
    r.objectiveText=text
    return r.evo.ready or (r.objectiveUrgent and time-(r.lastEvolutionRead or 0)>=1)
        or time-(r.lastEvolutionRead or r.runObservedAt or time)>=__slctx.CONFIG.EvolutionProbeSeconds
end
function __slctx.Strategy.maybeObjectiveReview()
    local r=__slctx.Strategy.route()
    if not ({BUY=true,UPGRADE=true,WAIT_GROWTH=true,WAIT_CASH=true,REBUILD=true})[r.phase] then return false end
    if r.endPurchased or r.completionSeen then return false end
    local q=__slctx.readBuy();local amount=__slctx.cash()
    if q and __slctx.Planner.isTerminalName(q.name) and q.cost and amount and __slctx.BN.cmp(amount,q.cost)>=0 then return false end
    if not __slctx.Strategy.objectiveDue() then return false end
    r.objectiveReturn=r.phase;__slctx.Strategy.phase('OBJECTIVE','проверяю только готовность эволюции; проход сохранён');return true
end
function __slctx.Strategy.objectiveReview()
    local r=__slctx.Strategy.route();local destination=r.objectiveReturn or 'BUY';r.objectiveReturn=nil;r.objectiveUrgent=nil
    if not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoEvolution then __slctx.Strategy.phase(destination,'проверка цели выключена');return end
    local evo,why=__slctx.Strategy.readEvolution()
    if not __slctx.live() then return end
    if not evo then __slctx.pause('EVOLUTION_READ_FAILED',tostring(why));return end
    if evo.ready then r.reserveSince=__slctx.now();__slctx.Strategy.phase('EVOLVE_RESERVE','доступна эволюция; промежуточный rebirth не нужен')
    else __slctx.Strategy.phase(destination,'эволюция пока закрыта; продолжаю прежнюю работу') end
end
function __slctx.Strategy.reviewSignal()
    local r=__slctx.Strategy.route();local rate=__slctx.Strategy.rate()
    local last=r.reviewSnapshot
    if not last then return true end
    if r.reviewUrgent then return true end
    if rate and last.rate and math.abs(__slctx.BN.log(rate)-__slctx.BN.log(last.rate))>=__slctx.CONFIG.ReviewIncomeDecades then return true end
    if __slctx.Strategy.largestBatch()~=last.batch then return true end
    local g=r.powerGoal
    if g and g.canBuyNow and (not last.goal or last.goal~=g.id) then return true end
    return false
end
function __slctx.Strategy.stampReview()
    local r=__slctx.Strategy.route()
    r.reviewSnapshot={rate=__slctx.Strategy.rate(),batch=__slctx.Strategy.largestBatch(),goal=r.powerGoal and r.powerGoal.id,
        buys=r.runBuyCount or 0};r.reviewUrgent=nil;r.lastStrategicReview=__slctx.now()
end
function __slctx.Strategy.maybeBuyReview()
    local r=__slctx.Strategy.route()
    if r.endPurchased or r.completionSeen or r.evo and r.evo.ready then return false end
    if not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoRebirth or not __slctx.CONFIG.MacroRebirthReviews then return false end
    -- Recovery observer and independent OBJECTIVE watchdog still operate while expensive rebirth reviews sleep.
    if r.recovery then return false end
    local q=r.buyQuote
    if not q or not q.cost or not r.buildQuote then return false end
    local targetModel=r.rewardCurve and r.frontierTrace and r.frontierTrace.complete and not r.frontierTrace.invalid
        and __slctx.S.cashFlow and r.rewardCurve.segment==__slctx.S.cashFlow.segment and __slctx.now()-r.rewardCurve.time<=35
    local goal=__slctx.Strategy.updatePowerGoal(r.latestInvestors)
    local stackGoal=goal and goal.nextBatch and goal.currentBatch~='max' and (goal.canBuyNow or goal.canBuyAfter)
    if not targetModel and not stackGoal then return false end
    local age=__slctx.now()-(r.lastStrategicReview or r.runObservedAt or __slctx.now())
    if age<__slctx.CONFIG.BuyBurstReviewSeconds then return false end
    if not __slctx.Strategy.reviewSignal() and age<__slctx.CONFIG.ReviewMaximumSeconds then return false end
    if (r.buyBurstCount or 0)<__slctx.CONFIG.ReviewMinimumBuys and not r.reviewUrgent then return false end
    r.capabilityOnly=true;r.reviewReturn='BUY';__slctx.Strategy.stampReview()
    __slctx.Strategy.phase('CAPABILITY','изменилось экономическое состояние; сравниваю пути к цели');return true
end
function __slctx.Strategy.maybeCapabilityReview(cards)
    local r=__slctx.Strategy.route();local p=r.pass
    if not __slctx.CONFIG.MacroRebirthReviews or not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoRebirth or not p or p.finished
        or r.powerUnresolved or r.capabilityPending or r.recovery or p.quickBuild then return false end
    local goal=__slctx.Strategy.updatePowerGoal(r.latestInvestors)
    local targetModel=r.rewardCurve and r.frontierTrace and r.frontierTrace.complete and not r.frontierTrace.invalid
    if not targetModel and not (goal and goal.nextBatch and goal.currentBatch~='max') then return false end
    local age=__slctx.now()-(r.lastStrategicReview or p.started)
    if (p.purchases or 0)-(p.lastCapabilityPurchases or 0)<__slctx.CONFIG.CapabilityReviewPurchases
        or age<__slctx.CONFIG.CapabilityReviewSeconds then return false end
    if not __slctx.Strategy.reviewSignal() and age<__slctx.CONFIG.ReviewMaximumSeconds then return false end
    p.lastCapabilityPurchases=p.purchases;p.lastCapabilityAt=__slctx.now();__slctx.Strategy.stampReview()
    r.capabilityOnly=true;r.reviewReturn='UPGRADE'
    __slctx.Strategy.phase('CAPABILITY','сравниваю полный путь после сброса; текущий бюджет сохранён');return true
end
function __slctx.Strategy.maybeFastBuild()
    local r=__slctx.Strategy.route()
    if not __slctx.CONFIG.FastMaxRecovery or not __slctx.canUpgrade() then return false end
    if __slctx.Strategy.largestBatch()~='max' or (r.pass and not r.pass.finished) then return false end
    if r.endPurchased or r.completionSeen or (r.buyQuote and __slctx.Planner.isTerminalName(r.buyQuote.name)) then return false end
    local recovering=r.recovery~=nil or r.fastBuildPending==true
    if not recovering and not __slctx.CONFIG.ProgressMaxBuild then return false end
    local buys=(r.runBuyCount or 0)-(r.lastBuildBuys or 0)
    local age=__slctx.now()-(r.lastBuildAt or r.buildStarted or r.runObservedAt or __slctx.now())
    local minimum=recovering and __slctx.CONFIG.FastBuildMinimumBuys or __slctx.CONFIG.ProgressBuildMinimumBuys
    local fallback=recovering and __slctx.CONFIG.FastBuildFallbackBuys or __slctx.CONFIG.ProgressBuildFallbackBuys
    if age<__slctx.CONFIG.FastBuildMinimumSeconds or buys<minimum then return false end
    if not r.buildMilestone and buys<fallback then return false end
    r.lastBuildAt=__slctx.now();r.lastBuildBuys=r.runBuyCount or 0;r.buildMilestone=nil
    r.buildPurpose=recovering and 'recovery' or 'forward construction'
    __slctx.Strategy.phase('REBUILD','MAX-проверка развития базы; не проверка rebirth');return true
end
function __slctx.Strategy.fastBuild()
    local r=__slctx.Strategy.route()
    if r.evo and r.evo.ready and __slctx.CONFIG.AutoEvolution and __slctx.S.resetEnabled and __slctx.now()>=(r.evolutionReserveRetryAt or 0) then
        r.reserveSince=__slctx.now();__slctx.Strategy.phase('EVOLVE_RESERVE','эволюция важнее восстановления');return
    end
    if not __slctx.canUpgrade() then __slctx.Strategy.phase('BUY','планшет ещё не открыт');return end
    if r.pass and not r.pass.finished and r.pass.quickBuild then __slctx.Strategy.growUpgrades();return end
    local ok,why=__slctx.manageTab('Manage')
    if not ok then if __slctx.live() then __slctx.pause('UPGRADE_MENU_NOT_READY',tostring(why)) end;return end
    if not __slctx.Strategy.stackPrepare() then __slctx.Strategy.phase('BUY','режим MAX пока не подтверждён');return end
    local cards=__slctx.Strategy.readCards();__slctx.Strategy.captureGrowth(cards)
    if __slctx.Strategy.currentBatch()~='max' then __slctx.Strategy.phase('BUY','нужен реально выбранный MAX');return end
    local rate=__slctx.Strategy.rate();local result=__slctx.Planner.macroPlan(cards,__slctx.cash(),rate,r.buyQuote,r.models,r.priceModels,
        {upgrade=__slctx.Strategy.effectiveActionSeconds('upgrade'),buy=__slctx.Strategy.effectiveActionSeconds('buy'),switch=__slctx.CONFIG.InitialMenuTripSeconds},__slctx.CONFIG)
    local unexplored=false
    for _,c in ipairs(cards)do
        if c.cost and c.available and __slctx.BN.cmp(__slctx.cash() or __slctx.BN.new(0),c.cost)>=0
            and not __slctx.Planner.projectUpgrade(c,r.models[c.path]) then unexplored=true;break end
    end
    if (result.known and result.first and result.first.kind=='upgrade') or unexplored then
        local p=__slctx.Strategy.beginPass(cards);p.quickBuild=true
        __slctx.log('FAST_MAX_REBUILD','purpose='..tostring(r.buildPurpose or 'recovery')..'; one complete bounded MAX pass; continue construction afterwards')
        __slctx.Strategy.growUpgrades()
    else
        r.lastBuildAt=__slctx.now()+__slctx.CONFIG.FastBuildEmptyBackoffSeconds
        __slctx.log('FAST_MAX_DEFERRED',result.why or 'quoted MAX does not beat continuing base')
        __slctx.Strategy.phase('BUY','пока полезнее продолжить базу; повторная проверка отложена')
    end
end
function __slctx.Strategy.sampleIncome()
    if __slctx.now()<(__slctx.S.nextRateSample or 0) then return end
    __slctx.S.nextRateSample=__slctx.now()+__slctx.CONFIG.IncomeSampleSeconds
    if __slctx.S.resetSession or __slctx.S.actionPending or __slctx.S.resetChildPending then return end
    __slctx.updateRate()
    if __slctx.S.cashFlow then
        local route=__slctx.Strategy.route()
        if route.flowSegment and route.flowSegment~=__slctx.S.cashFlow.segment and (route.runBuyCount or 0)>0 then
            route.cleanRun=false;route.rewardCurve=nil;route.rewardSamples={}
            if route.frontierTrace then route.frontierTrace.invalid=true end
        end
        route.flowSegment=__slctx.S.cashFlow.segment
    end
    if __slctx.now()>=(__slctx.S.nextEconomyObserve or 0) then
        __slctx.S.nextEconomyObserve=__slctx.now()+__slctx.CONFIG.PassiveObservationSeconds
        __slctx.Strategy.captureGrowth()
    end
end
function __slctx.Strategy.logResetEstimate(detail,reason)
    if not detail then return end
    local g=detail.goal
    __slctx.log('TARGET_ROUTE_COMPARE',tostring(reason)..'; mode='..tostring(g and g.mode or 'full-frontier fallback')
        ..'; continue ETA='..tostring(g and g.continueETA)..'; reset ETA='..tostring(g and g.resetETA)
        ..'; full frontier cost='..tostring(detail.cost)..'; '..tostring(detail.restoreQuality)
        ..'; parity time never multiplied='..tostring(detail.parityTimeNeverAmplified)
        ..'; construction permission='..tostring(detail.authorization))
end
function __slctx.Strategy.powerWorthBuying(goal)
    local r=__slctx.Strategy.route()
    if r.evo and r.evo.ready and __slctx.S.resetEnabled and __slctx.CONFIG.AutoEvolution then return false end
    local eta=__slctx.Strategy.directGoalETA(r.latestInvestors)
    if eta and eta<math.huge and eta<=__slctx.Strategy.actionSeconds('power')+__slctx.CONFIG.InitialMenuTripSeconds+__slctx.CONFIG.GoalAdvantageSeconds then return false end
    return not goal or goal.currentBatch~='max'
end
-- RESET_INTENT_RUNTIME_281_BEGIN
-- A positive economic decision owns a SHORT, NON-RENEWABLE planning lease.
-- Navigation is not economic progress. It must not invalidate a good decision just
-- by ageing the cash-flow samples. This is not permission to ignore changed state.
function __slctx.Strategy.resetPolicyKey()
    return table.concat({tostring(__slctx.S.resetEnabled),tostring(__slctx.CONFIG.AutoRebirth),tostring(__slctx.CONFIG.AutoEvolution),
        tostring(__slctx.CONFIG.AutoInvestorPowers),tostring(__slctx.CONFIG.CapabilityRebirth),tostring(__slctx.CONFIG.RepeatRebirth),
        tostring(__slctx.CONFIG.TabletReserve),tostring(__slctx.CONFIG.EvolutionMinimumBank),tostring(__slctx.CONFIG.GoalDirectedProgression),tostring(__slctx.CONFIG.PowerMaxEpochFraction),tostring(__slctx.CONFIG.ConstructionPolicy)},'|')
end
function __slctx.Strategy.resetReceiptKey()
    local out={}
    for _,kind in ipairs({'buy','upgrade','rebirth','evolve','halo','power','tablet'}) do
        out[#out+1]=tostring((__slctx.S.counts or {})[kind] or 0)
    end
    return table.concat(out,'|')
end
function __slctx.Strategy.cancelResetIntent(why)
    local r=__slctx.Strategy.route();local intent=r.resetIntent
    if intent then
        __slctx.log('RESET_INTENT_CANCELLED','id='..intent.id..'; reason='..tostring(why))
        r.resetIntent=nil
    end
end
function __slctx.Strategy.resetIntentState(inv)
    local r=__slctx.Strategy.route();local q=__slctx.readBuy() or r.buyQuote
    return {time=__slctx.now(),epoch=__slctx.S.epoch,evolution=r.evo and r.evo.index,halo=r.previousHalo,
        revision=r.economicRevision or 0,receipts=__slctx.Strategy.resetReceiptKey(),policy=__slctx.Strategy.resetPolicyKey(),
        flowSegment=__slctx.S.cashFlow and __slctx.S.cashFlow.segment,pass=r.pass,passIndex=r.pass and r.pass.index,
        capabilityOnly=r.capabilityOnly==true,batch=__slctx.Strategy.largestBatch(),
        bank=inv and inv.investors,reward=inv and inv.reward,perInvestor=inv and inv.perInvestor,
        ready=inv and inv.ready,invTime=inv and inv.time,
        gross=r.powerBase,used=r.powerUsed or __slctx.BN.new(0),spent=r.spent or __slctx.BN.new(0),
        cash=__slctx.cash(),buyId=q and q.id,goal=__slctx.Strategy.updatePowerGoal(inv),
        unresolved=r.powerUnresolved~=nil or next(r.blocked or {})~=nil,
        evoReady=__slctx.CONFIG.AutoEvolution and r.evo and r.evo.ready,
        recovery=r.recovery~=nil,endReached=r.endPurchased or r.completionSeen}
end
function __slctx.Strategy.rememberResetIntent(inv,context,reason,gain,detail)
    local r=__slctx.Strategy.route();local s=__slctx.Strategy.resetIntentState(inv)
    r.resetIntentSerial=(r.resetIntentSerial or 0)+1
    local intent={id=r.resetIntentSerial,at=__slctx.now(),expiresAt=__slctx.now()+__slctx.CONFIG.ResetIntentSeconds,
        state=s,reason=reason,gain=gain,detail=detail,rate=context.rate,
        preferRebirthToEvolution33=detail and detail.comparedEvolution==true and detail.finishAfterReset==true,
        spend=context.plannedSpend or __slctx.BN.new(0),validations=0}
    -- No references to mutable goal/amount tables in the authorization snapshot.
    for _,key in ipairs({'bank','reward','gross','used','spent','cash'}) do
        local b=s[key];if b then s[key]=__slctx.BN.new(b.m,b.e) end
    end
    if s.goal then
        local g=s.goal
        s.goal={path=g.path,name=g.name,price=g.price and __slctx.BN.new(g.price.m,g.price.e),bonus=g.bonus,
            currentBatch=g.currentBatch,nextBatch=g.nextBatch,canBuyAfter=g.canBuyAfter}
    end
    r.resetIntent=intent
    __slctx.log('RESET_INTENT_CREATED','id='..intent.id..'; '..reason..'; expires in '..__slctx.CONFIG.ResetIntentSeconds
        ..'s; economic samples frozen; bank/reward/quotes/gates remain checked')
end
function __slctx.Strategy.validateResetIntent(inv)
    local r=__slctx.Strategy.route();local intent=r.resetIntent
    if not intent then return false,'RESET_INTENT_MISSING' end
    local state=__slctx.Strategy.resetIntentState(inv)
    local ok,why=__slctx.Planner.validateResetIntent(intent,state,__slctx.CONFIG)
    local repeatReset=intent.detail and intent.detail.authorization=='adaptive-stand-rebirth'
    -- Newly discovered goal readiness/near-end progress overrides the old plan.
    if ok and __slctx.CONFIG.AutoEvolution and not repeatReset then
        local total=__slctx.Planner.totalMinimum(inv,r.spent)
        if r.target and total and __slctx.BN.cmp(total,__slctx.BN.mul(r.target,.999))>=0
            and (not r.evolutionCheckTotal or __slctx.BN.cmp(r.evolutionCheckTotal,__slctx.BN.mul(r.target,.999))<0) then
            ok=false;why='NEW_EVOLUTION_THRESHOLD'
        end
    end
    if ok then
        local q=__slctx.readBuy() or r.buyQuote
        if q and q.cost and state.cash then
            local eta=__slctx.Core.eta(state.cash,q.cost,intent.rate)
            if __slctx.Planner.isTerminalName(q.name) and eta and eta<=((intent.detail and intent.detail.cost) or __slctx.CONFIG.InitialFullLayoutSeconds) then
                ok=false;why='TERMINAL_TARGET_CLOSER'
            elseif not repeatReset and (q.multiplier or 0)>=__slctx.CONFIG.MajorMultiplier and eta and eta<=__slctx.Strategy.savingsRemaining(q,false) then
                ok=false;why='PROTECTED_MAJOR_TARGET'
            end
        end
    end
    if ok and intent.detail and (intent.detail.authorization=='confirmed construction wall'
        or intent.detail.authorization=='observed-construction-wall-332') then
        local q=__slctx.readBuy() or r.buyQuote
        if not q or not q.cost or not state.cash then ok=false;why='BUILD_QUOTE_NOT_VERIFIED'
        elseif __slctx.BN.cmp(state.cash,q.cost)>=0 then ok=false;why='BUILD_TARGET_FUNDED_DURING_NAVIGATION' end
    end
    if ok and intent.detail and (intent.detail.authorization=='next-evolution-prefix' or repeatReset) then
        if __slctx.GoalDirector then ok,why=__slctx.GoalDirector.validate(inv)
        else ok=false;why='GOAL_DIRECTOR_UNAVAILABLE' end
    end
    if not ok then __slctx.Strategy.cancelResetIntent(why);return false,why end
    intent.validations=intent.validations+1
    -- Reuse the decision, not a newly fabricated estimate from expired observations.
    return true,intent.reason,__slctx.Planner.netInvestorGain(inv,intent.spend),intent.detail
end
function __slctx.Strategy.noteResetAbort(why)
    local r=__slctx.Strategy.route()
    r.lastResetGuardReason=why;r.lastDecision=why
    r.lastResetExecution={stage='cancelled',reason=why,at=__slctx.now()}
    __slctx.Strategy.cancelResetIntent(why)
    __slctx.log('RESET_EXECUTION_ABORTED',tostring(why)..'; reset not counted as performed')
end
function __slctx.Strategy.peekResetInvestors(session,dialog)
    -- Before dispatch, the origin must be usable. After dispatch, a matching
    -- confirmation owns readiness; its modal may disable the origin button.
    if not __slctx.visible(__slctx.g(__slctx.paths.investors)) then return nil,'INVESTOR_MENU_NOT_VISIBLE' end
    local base=__slctx.paths.investors..'/Body/'
    if __slctx.t(base..'Amount/What'):lower()~='investors' then return nil,'UNSUPPORTED_WORLD_CURRENCY' end
    local bank=__slctx.BN.parse(__slctx.t(base..'Amount/Quantity'));local reward=__slctx.BN.parse(__slctx.t(base..'Potential/Quantity'))
    local percent=tonumber(__slctx.t(base..'Bonus/Quantity'):match('%+?(%d+%.?%d*)%%'))
    if not bank or not reward or not percent then return nil,'INVESTOR_NUMBER_UNRECOGNIZED' end
    local originReady=__slctx.usable(__slctx.g(base..'Rebirth'))
    local ready=originReady
    if session or dialog then
        if not session or not dialog or session~=__slctx.S.resetSession or session.kind~='rebirth'
            or not session.sent or not session.active or session.candidate~=dialog or dialog.notice
            or not __slctx.ResetConfirm.valid(session) then return nil,'RESET_CONFIRM_CONTEXT_CHANGED' end
        ready=__slctx.ResetConfirm.ready(dialog.button,dialog.root)
        if not ready then return nil,'RESET_CONFIRM_NOT_READY' end
        if not originReady and not session.originGateTransferred then
            session.originGateTransferred=true
            __slctx.log('REBIRTH_CONFIRM_GATE','matching ready dialog owns input; origin disabled; fresh economy guards retained')
        end
    end
    return {investors=bank,reward=reward,perInvestor=percent/100,ready=ready,time=__slctx.now()}
end
-- RESET_INTENT_RUNTIME_281_END

-- OBJECTIVE_RUNTIME_28_END

-- MACRO_RUNTIME_END



end
