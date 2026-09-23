-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.Strategy.diagnosticSample()
    if not __slctx.S.running or __slctx.now()<(__slctx.S.nextDiagnosticAt or 0) then return end
    __slctx.S.nextDiagnosticAt=__slctx.now()+__slctx.CONFIG.DiagnosticSeconds
    local r=__slctx.Strategy.route();local rate,source=__slctx.Strategy.rate();local goal=r.powerGoal
    local line=string.format('[%.2f] phase=%s E=%s batch=%s cash=%s rate=%s source=%s buy=%d upgrade=%d rebirth=%d decision=%s goalMissing=%s invAge=%s',
        __slctx.now()-__slctx.S.started,r.phase,tostring(r.evo and r.evo.index),tostring(r.batchSelected),__slctx.BN.format(__slctx.cash()),__slctx.BN.format(rate),source,
        __slctx.S.counts.buy,__slctx.S.counts.upgrade,__slctx.S.counts.rebirth,tostring(r.lastDecision),__slctx.BN.format(goal and goal.shortfall),
        tostring(r.latestInvestors and r.latestInvestors.time and math.floor(__slctx.now()-r.latestInvestors.time)))
    __slctx.S.snapshots=__slctx.S.snapshots or {};__slctx.S.snapshots[#__slctx.S.snapshots+1]=line
    if #__slctx.S.snapshots>__slctx.CONFIG.DiagnosticLines then table.remove(__slctx.S.snapshots,1) end
end
function __slctx.Strategy.profileTick()
    local time=__slctx.now();local old=__slctx.S.phaseClock
    if old and old.running then
        local dt=math.max(0,time-old.at);__slctx.S.phaseSeconds=__slctx.S.phaseSeconds or {}
        __slctx.S.phaseSeconds[old.phase]=(__slctx.S.phaseSeconds[old.phase] or 0)+dt
    end
    __slctx.S.phaseClock={at=time,phase=__slctx.S.route and __slctx.S.route.phase or 'BOOT',running=__slctx.S.running and not __slctx.S.focusPauseAt}
end
-- Navigation instrumentation preserves existing input/animation behavior.
do
    local depth=0
    local function metered(fn)
        return function(...)
            local start=__slctx.now();depth=depth+1
            local a,b,c=fn(...)
            depth=depth-1
            if depth==0 then
                local r=__slctx.Strategy.route();r.runMenuSeconds=(r.runMenuSeconds or 0)+math.max(0,__slctx.now()-start)
            end
            return a,b,c
        end
    end
    __slctx.navigate=metered(__slctx.navigate);__slctx.manageTab=metered(__slctx.manageTab);__slctx.ensureStrip=metered(__slctx.ensureStrip)
end
-- OBJECTIVE_RUNTIME_28_BEGIN
function __slctx.Strategy.investorBase()
    local r=__slctx.Strategy.route();local inv=r.latestInvestors or (__slctx.S.prestige and __slctx.S.prestige.inv)
    local bank=r.powerBank or (inv and inv.investors) or r.originInvestors
    if not bank or not inv or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    return __slctx.BN.add(__slctx.BN.new(1),__slctx.BN.mul(bank,inv.perInvestor))
end
function __slctx.Strategy.observePassiveCards()
    local r=__slctx.Strategy.route();local root=__slctx.g(__slctx.paths.cards)
    if not root then return end
    r.passiveRows=r.passiveRows or {};local total=__slctx.BN.new(0);local wanted,known=0,0;local allFresh=true
    local menuVisible=__slctx.visible(root);local time=__slctx.now()
    for _,row in ipairs(root:GetChildren())do
        local b=row:FindFirstChild('Upgrade')
        if b and b:IsA('GuiButton') and __slctx.prop(row,'Visible')~=false then
            local path=__slctx.paths.cards..'/'..row.Name
            local income=__slctx.childNumber(row,'Earns');local period=__slctx.txt(__slctx.at(row,'Progress/Label'))
            local name=__slctx.childText(row,'Title');local count=__slctx.childText(b,'Count')
            local signature=name..'|'..__slctx.childText(row,'Earns')..'|'..period..'|'..count
            local old=r.passiveRows[path]
            local stamp=menuVisible and time or old and old.signature~=signature and time or old and old.time
            r.passiveRows[path]={signature=signature,time=stamp}
            local rate=__slctx.Planner.sourceRate({income=income,period=period})
            wanted=wanted+1
            if rate then known=known+1;total=__slctx.BN.add(total,rate) end
            if not stamp or time-stamp>__slctx.CONFIG.IncomeFreshSeconds then allFresh=false end
        end
    end
    if known==wanted and wanted>0 and allFresh and total.m>0 then
        r.uiObservation={rate=total,time=time,kind='ui',quality='complete fresh payout/period observations'}
    end
end
function __slctx.Strategy.rate()
    local r=__slctx.Strategy.route();local time=__slctx.now()
    local flow=__slctx.S.cashFlow and __slctx.S.cashFlow:current(time)
    if flow then return flow,'cash delta + confirmed spending; UI estimate','flow' end
    local ui=r.uiObservation
    if ui and time-ui.time<=__slctx.CONFIG.IncomeFreshSeconds then return ui.rate,'fresh complete payout/period estimate','ui' end
    return nil,'fresh income unavailable; no fabricated total',nil
end
function __slctx.Strategy.captureGrowth(cards)
    local r=__slctx.Strategy.route();local time=__slctx.now()
    if __slctx.Strategy.captureLevelCurves33 and cards then __slctx.Strategy.captureLevelCurves33(cards) end
    if cards and #cards>0 and __slctx.visible(__slctx.g(__slctx.paths.cards)) then
        local sum,n,total=__slctx.Planner.sumRates(cards)
        if sum and n==total and total>0 then r.uiObservation={rate=sum,time=time,kind='ui'} end
    end
    __slctx.Strategy.observePassiveCards()
    local rate,source,kind=__slctx.Strategy.rate()
    if not rate then return end
    r.preResetRate={rate=rate,kind=kind,time=time,buys=r.runBuyCount or 0,upgrades=__slctx.S.counts.upgrade}
    if r.boostEffectPending and r.uiObservation then
        local p=r.boostEffectPending;local factor=p.beforeRate and __slctx.BN.number(__slctx.BN.div(r.uiObservation.rate,p.beforeRate))
        r.lastBoostEffect={name=p.name,expected=p.expected,observed=factor,at=time}
        __slctx.log('BOOST_EFFECT_UI',p.name..'; observed aggregate factor='..tostring(factor)..'; not isolated from other production changes')
        r.boostEffectPending=nil
    end
    local samples=r.growthSamples or {};r.growthSamples=samples
    if #samples==0 or time-samples[#samples].time>=0.5 then
        samples[#samples+1]={time=time,rate=rate,kind=kind}
        while #samples>64 or #samples>2 and time-samples[1].time>30 do table.remove(samples,1) end
    end
    __slctx.Strategy.observeRecovery(cards)
    __slctx.Strategy.captureFrontier(rate,kind)
end
function __slctx.Strategy.forwardGrowth()
    return __slctx.Planner.growthEstimate(__slctx.Strategy.route().growthSamples,__slctx.now(),20)
end
function __slctx.Strategy.captureFrontier(rate,kind)
    local r=__slctx.Strategy.route();local multiplier=__slctx.Strategy.investorBase();local amount=__slctx.cash()
    if not rate or not multiplier or not amount then return end
    local trace=r.frontierTrace
    if not trace then
        trace={points={},complete=r.cleanRun==true,started=r.buildStarted or r.runObservedAt or __slctx.now(),
            base=multiplier,kind=kind,epoch=r.evo and r.evo.index};r.frontierTrace=trace
    end
    if trace.kind~=kind or trace.epoch~=(r.evo and r.evo.index) then return end
    local points=trace.points;local time=__slctx.now()
    if #points>0 and time-points[#points].time<1 then return end
    local service=(r.runServiceSeconds or 0)+(r.runMenuSeconds or 0)
    points[#points+1]={time=time,age=math.max(0,time-trace.started),cash=amount,
        rate=__slctx.BN.mul(rate,__slctx.BN.div(trace.base,multiplier)),spent=r.runSpent or __slctx.BN.new(0),service=service}
    if #points>__slctx.CONFIG.FrontierTracePoints then
        -- Keep first/last and cumulative counters. Coalesced segments charge their full cost before output.
        local slim={points[1]};for i=3,#points,2 do slim[#slim+1]=points[i] end
        if slim[#slim]~=points[#points] then slim[#slim+1]=points[#points] end
        trace.points=slim
    end
end
function __slctx.Strategy.recordObjective(inv)
    local r=__slctx.Strategy.route();if not inv then return end
    local flow=__slctx.S.cashFlow;if not flow then return end
    local earned=flow:earned(__slctx.now(),__slctx.cash())
    local samples=r.rewardSamples or {};r.rewardSamples=samples
    local last=samples[#samples]
    if last and (last.segment~=flow.segment or __slctx.BN.cmp(inv.reward,last.reward)<0) then samples={};r.rewardSamples=samples end
    if earned and earned.m>0 and inv.reward.m>0 and (not last or __slctx.now()-last.time>=1) then
        samples[#samples+1]={time=__slctx.now(),earned=earned,reward=inv.reward,segment=flow.segment,
            total=__slctx.Planner.totalMinimum(inv,r.spent)}
        while #samples>12 do table.remove(samples,1) end
    end
    r.rewardCurve,r.rewardCurveReason=__slctx.Planner.fitRewardCurve(samples)
    if not r.cleanRun then r.rewardCurve=nil;r.rewardCurveReason='initial attachment/financial prefix incomplete' end
    r.totalMinimum=__slctx.Planner.totalMinimum(inv,r.spent)
end
function __slctx.Strategy.directGoalETA(inv)
    local r=__slctx.Strategy.route();local s=r.rewardSamples or {}
    if not r.target or #s<3 or not inv then return nil end
    local last=s[#s];local first=s[math.max(1,#s-3)]
    if not last.total or not first.total or __slctx.now()-last.time>35 then return nil end
    local gap=__slctx.BN.sub(r.target,last.total);if gap.m==0 then return 0 end
    local dt=last.time-first.time
    if dt<2 or __slctx.BN.cmp(last.total,first.total)<=0 then return nil end
    -- Local linear progress ETA is used ONLY as a near-target veto, never a reset authorization.
    if __slctx.BN.log(r.target)-__slctx.BN.log(last.total)>0.3 then return nil end
    return __slctx.BN.number(__slctx.BN.div(gap,__slctx.BN.div(__slctx.BN.sub(last.total,first.total),dt)))
end
function __slctx.Strategy.makeRecovery(inv)
    local r=__slctx.Strategy.route();local targets={};local time=__slctx.now()
    local flow=__slctx.S.cashFlow and __slctx.S.cashFlow:current(time)
    if flow then targets.flow=flow end
    local ui=r.uiObservation;if ui and time-ui.time<=__slctx.CONFIG.IncomeFreshSeconds then targets.ui=ui.rate end
    local prior=r.preResetRate
    if prior and prior.buys==(r.runBuyCount or 0) and prior.upgrades==__slctx.S.counts.upgrade and time-prior.time<=30 then
        targets[prior.kind]=targets[prior.kind] or prior.rate
    end
    local target=targets.flow or targets.ui
    if not target then return nil end
    local counts={}
    for _,c in ipairs(r.cards or {})do
        local n=__slctx.Core.count(c.count);if n then counts[c.path]={count=n,name=c.name} end
    end
    return {metric='dual-frontier-v28',targetRate=target,baseRate=target,targets=targets,
        started=__slctx.now()+__slctx.CONFIG.AfterResetWait,work={},upgradeSeconds=0,upgradeActions=0,
        frontierCounts=counts,frontierBuys=r.runBuyCount or 0,completePrefix=r.cleanRun==true,
        beforeMultiplier=__slctx.BN.add(__slctx.BN.new(1),__slctx.BN.mul(inv.investors,inv.perInvestor or 0))}
end
function __slctx.Strategy.observeRecovery(cards)
    local r=__slctx.Strategy.route();local rec=r.recovery
    if rec then
        local time=__slctx.now();local met=false;local source
        local flow=__slctx.S.cashFlow and __slctx.S.cashFlow:current(time)
        if flow and rec.targets and rec.targets.flow and __slctx.BN.cmp(flow,rec.targets.flow)>=0 then met=true;source='flow' end
        local ui=r.uiObservation
        if ui and time-ui.time<=__slctx.CONFIG.IncomeFreshSeconds and rec.targets and rec.targets.ui
            and __slctx.BN.cmp(ui.rate,rec.targets.ui)>=0 then met=true;source='ui' end
        if met then rec.metSince=rec.metSince or time else rec.metSince=nil end
        if rec.metSince and time-rec.metSince>=__slctx.CONFIG.RecoveryStableSeconds then
            local elapsed=math.max(0,time-rec.started)
            r.paritySeconds=elapsed;r.recovery=nil;r.rebuilding=false;r.rebuildLowerBound=nil
            r.fastBuildPending=nil;r.reviewUrgent=true
            __slctx.log('RECOVERY_PARITY','seconds='..string.format('%.2f',elapsed)..'; source='..source
                ..'; only former income restored; NOT multiplied in reset forecast')
        end
    end
    local frontier=r.frontierRecovery
    if frontier and not frontier.frontierDone and frontier.completePrefix and cards and #cards>0
        and (r.runBuyCount or 0)>=frontier.frontierBuys then
        local seen={};for _,c in ipairs(cards)do seen[c.path]=c end
        local complete=next(frontier.frontierCounts or {})~=nil
        for path,v in pairs(frontier.frontierCounts or {})do
            local c=seen[path]
            if not c or c.name~=v.name or (__slctx.Core.count(c.count) or -1)<v.count then complete=false;break end
        end
        if complete then
            frontier.frontierDone=true;r.fullLayoutSeconds=math.max(0,__slctx.now()-frontier.started)
            __slctx.log('RECOVERY_FULL_LAYOUT','same observed layout frontier restored in '..string.format('%.2f',r.fullLayoutSeconds)..'s')
        end
    end
end
-- CONSTRUCTION_RUNTIME_282_BEGIN

end
