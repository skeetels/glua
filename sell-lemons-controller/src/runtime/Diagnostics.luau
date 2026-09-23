-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.API.report()
    local report={'SELL LEMONS CONTROLLER 4.0.15 DEV','Place='..game.PlaceId..'; version='..game.PlaceVersion,
        'Status='..__slctx.S.code..' | '..__slctx.S.status,'Cash='..__slctx.t(__slctx.paths.balance),
        'Last error='..__slctx.S.lastError,'firesignal tested='..tostring(__slctx.Driver.fire~=nil),
        'getconnections tested='..tostring(__slctx.Driver.connections~=nil),
        'VirtualInput tested='..tostring(__slctx.Driver.virtual~=nil),
        'Window focused='..tostring(__slctx.S.windowFocused),
        'Input connection method='..tostring(__slctx.Driver.connectionMode),
        'Executor='..__slctx.Driver.host,
        'Tablet='..tostring(__slctx.S.tablet and __slctx.S.tablet.owned),
        'Rate estimate='..__slctx.BN.format(__slctx.Strategy.rate()),
        'Direct receipts verify replicated state; GUI observations and forecasts are labeled separately.',
        'Counts buy='..__slctx.S.counts.buy..'; upgrade='..__slctx.S.counts.upgrade..'; rebirth='..__slctx.S.counts.rebirth..'; evolve='..__slctx.S.counts.evolve..'; halo='..__slctx.S.counts.halo,
        'Poll='..__slctx.CONFIG.ConfirmationPollSeconds..'; scan='..__slctx.CONFIG.ConfirmScanSeconds..'; input='..__slctx.CONFIG.RequestedClickInterval}
    local r=__slctx.Strategy.route()
    report[#report+1]='--- RETAINED EVOLUTION DECISIONS ---'
    for _,line in ipairs(__slctx.S.evolutionDecisions or {})do report[#report+1]=line end
    if __slctx.API.dataReport then report[#report+1]=__slctx.API.dataReport() end
    report[#report+1]='PHASE='..r.phase..' | '..tostring(r.reason)
    report[#report+1]='Target E'..tostring(r.evo and r.evo.index+1)..'='..__slctx.BN.format(r.target)..'; total minimum='..__slctx.BN.format(r.totalMinimum)..'; historical spending unknown='..tostring(r.spentUnknown)
    report[#report+1]='Rebirth policy=observed funding block + bounded output after rebuild at sustained wall; funded construction protected; rebuild estimate='..tostring(r.rebuildEstimate)
    report[#report+1]='Gain='..tostring(r.gain)..'; wait deadline='..tostring(r.savingsBudget and r.savingsBudget.deadline or r.wall and r.wall.deadline)..'; last decision='..r.lastDecision
    report[#report+1]='Committed full sweep='..tostring(r.pass and r.pass.id)..'; next stand='..tostring(r.pass and r.pass.index)
        ..'; stands='..tostring(r.pass and #r.pass.order)..'; finished='..tostring(r.pass and r.pass.finished)
        ..'; stand position retained through reviews; profitable global boost can interrupt once'
    report[#report+1]='End purchase='..tostring(r.endPurchased)..'; complete marker='..tostring(r.completionSeen)
    for k,v in pairs(r.menuReads) do report[#report+1]='STRATEGIC_READ '..k..'='..v end
    report[#report+1]='Requested click interval='..__slctx.CONFIG.RequestedClickInterval..'; actual rate is not guaranteed'
    report[#report+1]='Catalog error='..tostring(__slctx.S.catalogError or '')
    report[#report+1]='BUY preview='..__slctx.t(__slctx.paths.buy..'/Purchase')..' | '..__slctx.t(__slctx.paths.buy..'/PurchasePrice')..' | '..__slctx.t(__slctx.paths.buy..'/PurchaseInfo')
    report[#report+1]='BuyNext visible='..tostring(__slctx.visible(__slctx.g(__slctx.paths.buy)))..'; Manage visible='..tostring(__slctx.visible(__slctx.g(__slctx.paths.manage)))
    for k,v in pairs(__slctx.S.incomeAttempts) do report[#report+1]='OPTIONAL_INCOME '..k..' observed='..tostring(v.observed)..' | '..tostring(v.reason) end
    for k,v in pairs(__slctx.S.profile) do report[#report+1]='PROFILE '..k..'='..v end
    for k,v in pairs(__slctx.S.signalCounts) do report[#report+1]='HANDLERS '..k..' '..v end
    for _,c in ipairs(__slctx.S.catalog) do
        report[#report+1]=string.format('CANDIDATE %s cost=%s quotedAvailable=%s activeNow=%s visibleNow=%s',c.id,__slctx.BN.format(c.cost),tostring(c.available),tostring(__slctx.prop(c.button,'Active')),tostring(__slctx.visible(c.button)))
    end
    local p=__slctx.S.prestige
    if p and p.evo then
        report[#report+1]=string.format('EVO index=%s progress=%s ready=%s bonusVisible=%s bonus=%s',
            tostring(p.evo.index),tostring(p.evo.pct),tostring(p.evo.ready),tostring(p.evo.bonusVisible),__slctx.BN.format(p.evo.bonus))
    end
    report[#report+1]='BULK='..tostring(r.batchSelected)..'; background='..tostring(__slctx.S.backgroundVerified)..'; background receipts='..tostring(__slctx.S.backgroundReceipts or 0)
    report[#report+1]='POWERS base='..__slctx.BN.format(r.powerBase)..' spent='..__slctx.BN.format(r.powerUsed)..' pending='..tostring(r.powerPending)
    for key,v in pairs(r.blocked or {}) do report[#report+1]='UNRESOLVED '..key..' | '..v.reason end
    report[#report+1]='CAPITAL_GROSS='..__slctx.BN.format(r.powerBase)..'; cumulative spent='..__slctx.BN.format(r.powerUsed)..'; last bank='..__slctx.BN.format(r.powerBank)
    local budget=__slctx.Planner.powerBudgetInfo(r.powerBank,r.powerUsed,r.powerBase,__slctx.CONFIG)
    report[#report+1]='CAPITAL_PROTECTED='..__slctx.BN.format(budget and budget.floor)..'; available optional budget='..__slctx.BN.format(budget and budget.available)
    local goal=r.powerGoal
    if goal then
        report[#report+1]='POWER_GOAL '..goal.title..'; required reward='..__slctx.BN.format(goal.requiredReward)..'; missing='..__slctx.BN.format(goal.shortfall)
            ..'; current batch='..tostring(goal.currentBatch)..'; expected next='..tostring(goal.nextBatch)..'; '..tostring(goal.quality)
    end
    local estimate=r.lastResetEstimate
    if estimate then report[#report+1]='RESET_ESTIMATE cost='..tostring(estimate.cost or estimate.cycle)
        ..'; discounted avoided input='..tostring(estimate.saved)..'; work='..tostring(estimate.workSource) end
    report[#report+1]='FULL_SWEEP_COUNT='..tostring(r.fullPassCount)..'; complete='..tostring(r.pass and r.pass.complete)
        ..'; fixed entry budget='..__slctx.BN.format(r.pass and r.pass.budget)..'; purchases='..tostring(r.pass and r.pass.purchases)
    report[#report+1]='ECONOMY enabled='..tostring(__slctx.CONFIG.EconomicPlanning)..'; wait budget='..__slctx.CONFIG.MaxWaitSeconds
        ..'; payback horizon='..__slctx.CONFIG.ResetPaybackHorizonSeconds..'; income source='..select(2,__slctx.Strategy.rate())
    local plan=r.lastPlan
    if plan then report[#report+1]='LAST_PLAN '..plan.name..'; delta/s='..__slctx.BN.format(plan.delta)
        ..'; estimated payback='..tostring(plan.payback)..'; '..plan.quality end
    for kind,timing in pairs(r.timings or {}) do
        report[#report+1]=string.format('TIMING %s count=%d average=%.3fs ewma=%.3fs maximum=%.3fs',kind,timing.count,timing.total/timing.count,timing.ewma,timing.maximum)
    end
    for kind,stat in pairs(r.cycleStats or {}) do
        report[#report+1]=string.format('FULL_CYCLE %s n=%d last=%.2fs best=%.2fs average=%.2fs',kind,stat.count,stat.last,stat.best,stat.total/stat.count)
    end
    report[#report+1]='RECOVERY target='..__slctx.BN.format(r.recovery and r.recovery.targetRate)
        ..'; lower bound='..tostring(r.rebuildLowerBound)..'; observed estimate='..tostring(r.rebuildEstimate)
    report[#report+1]='--- PROFILE / MODEL ---'
    for phase,seconds in pairs(__slctx.S.phaseSeconds or {}) do report[#report+1]=string.format('PHASE_TIME %s %.2fs',phase,seconds) end
    for kind,c in pairs(r.cadence or {}) do report[#report+1]=string.format('CADENCE %s n=%d mean=%.4fs ewma=%.4fs',kind,c.count,c.total/c.count,c.ewma) end
    for _,card in ipairs(r.cards or {}) do report[#report+1]='STAND_STATE '..card.name..'; count='..tostring(card.count)
        ..'; batch='..tostring(card.stack)..'; cost='..__slctx.BN.format(card.cost)..'; earns='..__slctx.BN.format(card.income)..'; period='..tostring(card.period) end
    local mr=r.macroPlan
    if mr then report[#report+1]='ROLLOUT known='..tostring(mr.known)..'; horizon='..tostring(mr.horizon)..'; depth='..tostring(mr.depth)
        ..'; nodes='..tostring(mr.expansions)..'; first='..tostring(mr.first and (mr.first.kind..':'..mr.first.name))..'; advantage='..tostring(mr.improvement) end
    if r.latestInvestors then report[#report+1]='INVESTORS_AGE_SECONDS='..tostring(math.max(0,__slctx.now()-r.latestInvestors.time)) end
    if __slctx.S.cashFlow then report[#report+1]='FLOW valid samples='..#__slctx.S.cashFlow.samples..'; rejected='..__slctx.S.cashFlow.rejected
        ..'; current='..__slctx.BN.format(__slctx.S.cashFlow:current(__slctx.now())) end
    if estimate then report[#report+1]='RESET_OUTPUT_LOG_ADVANTAGE='..tostring(estimate.logAdvantage)..'; horizon='..tostring(estimate.horizon)
        ..'; observed growth/s='..tostring(estimate.growthSpeed)..'; forecast span='..tostring(estimate.growthSpan) end
    local bp=__slctx.Strategy.baseProgress();local bw=r.buildWall
    report[#report+1]='BUILD_PROGRESS depth='..bp.depth..'; high='..bp.high..'; known prefix='..tostring(bp.comparable)
        ..'; restore debt='..tostring(bp.debt)..'; repeated confirmed buys='..bp.repeated
    report[#report+1]='BUILD_WALL pass='..tostring(bw and bw.pass)..'; weak='..tostring(bw and bw.weak)
        ..'; quote verified='..tostring(r.buildQuote and __slctx.now()-r.buildQuote.at<=__slctx.CONFIG.BuildQuoteFreshSeconds)
    local budget=r.savingsBudget
    report[#report+1]='BUILD_WAIT target='..tostring(budget and budget.id)..'; remaining seconds='
        ..tostring(budget and math.max(0,budget.deadline-__slctx.now()))..'; active='..tostring(r.phase=='WAIT_CASH')
    report[#report+1]='--- RESET EXECUTION 2.8.2 ---'
    local ri=r.resetIntent;local rx=r.lastResetExecution
    report[#report+1]='RESET_INTENT id='..tostring(ri and ri.id)..'; remaining='..tostring(ri and math.max(0,ri.expiresAt-__slctx.now()))
        ..'; validations='..tostring(ri and ri.validations)..'; economicRevision='..tostring(r.economicRevision or 0)
    report[#report+1]='RESET_EXECUTION stage='..tostring(rx and rx.stage)..'; reason='..tostring(rx and rx.reason)
        ..'; guard='..tostring(r.lastResetGuardReason)..'; no reset inferred from a planner recommendation'
    report[#report+1]='--- ADAPTER OBSERVATIONS ---'
    report[#report+1]='SCHEMA=28; restore metric=full observed frontier; parity is a separate lock only'
    report[#report+1]='PARITY_SECONDS='..tostring(r.paritySeconds)..'; FULL_LAYOUT_SECONDS='..tostring(r.fullLayoutSeconds)
    report[#report+1]='REWARD_CURVE='..tostring(r.rewardCurve and r.rewardCurve.quality or r.rewardCurveReason)
    if estimate and estimate.goal then
        local g=estimate.goal;report[#report+1]='GOAL_ETA continue='..tostring(g.continueETA)..'; reset='..tostring(g.resetETA)..'; mode='..g.mode
    end
    report[#report+1]='FRONTIER_REPLAY_POINTS='..tostring(r.frontierTrace and #r.frontierTrace.points or 0)..'; complete prefix='..tostring(r.cleanRun)
    report[#report+1]='POWERS_POLICY=UpgradeStack plus explicit OptionalPowerAllowlist; 5% is a ceiling, not a spending target'
    local bp=__slctx.S.buyProofProfile
    if bp and bp.count>0 then report[#report+1]=string.format('BUY_PROOF n=%d to-first-proof=%.4fs stable-wait=%.4fs streak=%d',bp.count,bp.toProof/bp.count,bp.stable/bp.count,__slctx.S.buyReceiptStreak or 0) end
    for _,v in ipairs(r.objectiveHistory or {})do report[#report+1]=string.format('OBJECTIVE_CYCLE E=%s kind=%s seconds=%.2f buys=%d rebirths=%d',tostring(v.evolution),v.kind,v.seconds,v.buys,v.rebirths) end
    report[#report+1]='--- ECONOMIC SNAPSHOTS (10s, bounded) ---'
    for _,line in ipairs(__slctx.S.snapshots or {}) do report[#report+1]=line end
    report[#report+1]='--- ROUTE / RECOVERY EVENTS ---'
    for _,line in ipairs(__slctx.S.events or {}) do report[#report+1]=line end
    local confirmation=__slctx.S.resetSession or __slctx.S.lastResetSession
    if confirmation then
        report[#report+1]='TRANSACTION_CONFIRM kind='..confirmation.kind..'; stages='..confirmation.stages
            ..'; attempts='..tostring(confirmation.attempts)..'; dialogSeen='..tostring(confirmation.sawDialog)
            ..'; modalObserved='..tostring(confirmation.observedModal)
            ..'; sent='..tostring(confirmation.sent)..'; active='..tostring(confirmation.active)
            ..'; outcome='..tostring(confirmation.outcome)..'; error='..tostring(confirmation.error)
        for _,line in ipairs(confirmation.notes) do report[#report+1]='CONFIRM_DETAIL '..line end
    end
    report[#report+1]='--- ACTION LOG ---' 
    for _,line in ipairs(__slctx.S.logs) do report[#report+1]=line end
    if __slctx.ResetInspection then report[#report+1]=__slctx.ResetInspection.report()end
    return table.concat(report,'\n')
end

-- HALO_REPORT_30_BEGIN
__slctx.previousReport30=__slctx.API.report
function __slctx.API.report()
    local base=__slctx.previousReport30();local h=__slctx.HaloRun.state();local f=h.forecast;local m=h.book.model
    local text,fraction,eta,progress=__slctx.HaloRun.progress()
    local economic=progress.economy or {}
    local out={ '--- HALO ROUTE ECONOMY 4.0.15 ---',
        'HALO_MODE='..h.mode..'; halo='..tostring(h.book.halo)..'; evolution='..tostring(h.book.evolution),
        'HALO_READINESS fraction='..tostring(fraction)..'; type=route-income-capacity; bar is explicitly logarithmic, NOT percent of elapsed time',
        'REQUIRED_INCOME='..__slctx.BN.format(economic.requiredRate)..'; CURRENT_INCOME='..__slctx.BN.format(economic.currentRate)
            ..'; WAIT_BUDGET_SECONDS='..tostring(economic.waitSeconds)..'; MODEL_VERIFIED='..tostring(economic.modelVerified),
        'READINESS_CAPACITY='..__slctx.BN.format(economic.capacity)..'; TARGET_COST='..__slctx.BN.format(economic.cost)
            ..'; LOG10_INCOME_SHORTFALL='..tostring(economic.decadesShort)..'; READY='..tostring(economic.ready),
        'REBIRTH_RESTORED_INCOME='..__slctx.BN.format(economic.rebirth and economic.rebirth.currentRate)
            ..'; REQUIRED_BANK_SAME_LAYOUT='..__slctx.BN.format(economic.rebirth and economic.rebirth.requiredBank)
            ..'; condition=same layout rebuilt; no instantaneous projected income',
        'NEXT_EVOLUTION='..tostring(economic.nextEvolution)..'; START_BANK='..__slctx.BN.format(economic.evolutionStartBank)
            ..'; COUNTERFACTUAL_INCOME_KNOWN='..tostring(h.economy and h.economy.evolutionForecastKnown or false)..'; comparable-layout only; no invented terminal evolution',
        'CATALOGUE_AUDIT confirmed='..progress.known..'/'..progress.total..'; lower bound='..tostring(progress.lowerBound)
            ..'; secondary audit only; additional real items tracked separately',
        'PRICE_MODEL='..tostring(m and m.quality or h.calibration)..'; anchors='..#h.book.anchors
            ..'; slope='..tostring(m and m.b)..'; intercept='..tostring(m and m.a)..'; error='..tostring(m and m.error),
        'CATALOGUE_REMAINING='..tostring(h.remaining and h.remaining.count)..'; COST_WITH_MARGIN='..__slctx.BN.format(h.remaining and h.remaining.cost),
        'FINISH_REASON='..tostring(h.finish and h.finish.reason)..'; PASSIVE_FINISH_SECONDS='..__slctx.BN.format(f and f.bound and f.bound.time),
        'INVESTOR_TARGET_CURRENT_LAYOUT='..__slctx.BN.format(h.requiredInvestors)..'; scenario, not a fixed game threshold',
        'POWER_CACHE key='..tostring(h.powerScan and h.powerScan.key)..'; extra scans='..tostring(h.powerScans or 0)
            ..'; unchanged scans skipped='..tostring(h.powerScanSkipped or 0)..'; negative cache is event-driven',
        'PLANNER_PROFILE calls='..tostring(h.planCalls or 0)..'; total='..tostring(h.planSeconds or 0)..'; max='..tostring(h.planMaxSeconds or 0)
            ..'; scheduled interval='..__slctx.CONFIG.CataloguePlanSeconds,
        'DONOR_CONFIG investor='..__slctx.CONFIG.ExpectedInvestorBonus..'; speed='..__slctx.CONFIG.ExpectedTimeMultiplier..'; NOT applied twice',
        'INCOME_BASIS=observed cash/second already includes current bonuses; x16 is metadata, never another income multiplier',
        'FAST_INPUT upgrade_extra_delay='..__slctx.CONFIG.RequestedClickInterval..'; receipt_poll='..__slctx.CONFIG.ConfirmationPollSeconds
            ..'; buy_hold_enabled='..tostring(__slctx.CONFIG.BuyHoldEnabled)..'; hold_fallback='..tostring(h.holdDisabled==true)
            ..'; observed_buy_count_is_lower_bound='..tostring((__slctx.S.buyHoldCountLowerBound or 0)>0),
        'FORECAST_LIMITS=source production is observed; known future catalogue boosts simulated in price order; optional future levels and unknown unlock dependencies not assumed free',
    }
    local priceModel,priceVerified=__slctx.HaloPlan.priceModel(h.book,__slctx.CONFIG)
    out[#out+1]='HALO_PRICE_RULE C0*'..__slctx.CONFIG.HaloPriceBase..'^H; factor='..__slctx.BN.format(__slctx.HaloPlan.haloFactor(h.book.halo,__slctx.CONFIG))
        ..'; using='..tostring(priceModel and priceModel.quality)..'; verified='..tostring(priceVerified)
    if h.economy and h.economy.factors then
        local e=h.economy;local k=e.factors
        out[#out+1]='FACTORS total='..__slctx.BN.format(k.total)..'; donor time='..__slctx.BN.format(k.time)..'; evolution='..__slctx.BN.format(k.evolution)
            ..'; halo cash='..__slctx.BN.format(k.halo)..'; investor cash='..__slctx.BN.format(k.investors)..'; source base='..__slctx.BN.format(e.sourceBaseRate)
        out[#out+1]='ROUTE_TARGET basis='..tostring(e.basis)..'; required multiplier='..__slctx.BN.format(e.requiredFactor)
            ..'; terminal income='..__slctx.BN.format(e.projectedTerminalRate)..'; paid level nodes='..tostring(e.levelNodes or 0)..'; log bar='..tostring(e.logFraction)
    end
    for key in pairs(h.book.unknown)do out[#out+1]='CATALOGUE_UNPRICED='..key end
    for _,row in pairs(h.book.extras or {})do out[#out+1]='CATALOGUE_LIVE_EXTRA '..row.name..'; cost='..__slctx.BN.format(row.cost)
        ..'; bought='..tostring(h.book.bought[row.id]==true)..'; not aliased to a wiki row' end
    if h.lastCompare then out[#out+1]='ROUTE_COMPARE direct='..__slctx.BN.format(h.lastCompare.direct)..'; reset='..__slctx.BN.format(h.lastCompare.reset)
        ..'; local bridge='..tostring(h.lastCompare.localBridge)..'; '..tostring(h.lastCompare.quality or h.lastCompare.restoreQuality) end
    if h.lastCompare and h.lastCompare.outputComparison then
        local d=h.lastCompare
        out[#out+1]='STALLED_RESET horizon='..tostring(d.horizon)..'; log_output_advantage='..tostring(d.logAdvantage)
            ..'; continuation_global_boost='..tostring(d.continuationBoost)..'; rebuild_seconds='..tostring(d.cost)
    end
    if h.lastCompare and h.lastCompare.authorization=='capability-work-331' then
        local d=h.lastCompare
        out[#out+1]='STACK_RESET saved_seconds='..tostring(d.saved)..'; reset_power_rebuild_seconds='..tostring(d.cost)
            ..'; old_clicks='..tostring(d.oldClicks)..'; new_clicks='..tostring(d.newClicks)..'; work='..tostring(d.workSource)
    end
    out[#out+1]=base
    return table.concat(out,'\n')
end
-- HALO_REPORT_30_END
function __slctx.API.copyLog()
    local report=__slctx.API.report()
    local copy=type(setclipboard)=='function' and setclipboard or (type(toclipboard)=='function' and toclipboard or nil)
    if copy then
        local ok,err=pcall(copy,report)
        if ok then __slctx.log('LOG_EXPORT','Журнал передан функции буфера обмена.');return end
        __slctx.log('CLIPBOARD_ERROR',err)
    end
    if __slctx.exportFrame then __slctx.exportFrame:Destroy() end
    __slctx.exportFrame=Instance.new('Frame');__slctx.exportFrame.Size=UDim2.fromOffset(640,390)
    __slctx.exportFrame.Position=UDim2.new(0.5,-320,0.5,-195);__slctx.exportFrame.BackgroundColor3=Color3.fromRGB(25,25,28)
    __slctx.exportFrame.Parent=__slctx.panel
    local box=Instance.new('TextBox');box.Size=UDim2.new(1,-20,1,-50);box.Position=UDim2.fromOffset(10,10)
    box.Text=report;box.ClearTextOnFocus=false;box.MultiLine=true;box.TextEditable=false;box.TextSize=12
    box.Font=Enum.Font.Code;box.TextXAlignment=Enum.TextXAlignment.Left;box.TextYAlignment=Enum.TextYAlignment.Top
    box.TextWrapped=false;box.Parent=__slctx.exportFrame
    local x=Instance.new('TextButton');x.Size=UDim2.fromOffset(200,26);x.Position=UDim2.new(0.5,-100,1,-32)
    x.Text='Закрыть журнал';x.Parent=__slctx.exportFrame
    __slctx.S.connections[#__slctx.S.connections+1]=x.Activated:Connect(function() __slctx.exportFrame:Destroy();__slctx.exportFrame=nil end)
end
function __slctx.API.exportCycleState()
    return {place=game.PlaceId,user=__slctx.player.UserId,route=__slctx.S.route,pausedAt=__slctx.S.manualPauseAt or __slctx.now(),resetScans=__slctx.S.resetScans,evolutionDecisions=__slctx.S.evolutionDecisions}
end
function __slctx.API.callbackPending() return __slctx.S.actionPending~=nil or __slctx.S.resetChildPending~=nil
    or __slctx.S.resetSession~=nil or __slctx.S.testing==true or (__slctx.S.route and __slctx.S.route.powerUnresolved~=nil) end

end
