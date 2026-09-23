-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.HaloRun = {}
__slctx.S.evolutionDecisions=__slctx.previousCycleState and __slctx.previousCycleState.evolutionDecisions or {}
do
local index=__slctx.HaloPlan.index(__slctx.HaloCatalogue)
local function bnmin(a,b)if not a then return b end;if not b then return a end;return __slctx.BN.cmp(a,b)<0 and a or b end
local function isPending()return __slctx.S.actionPending or __slctx.S.resetChildPending or __slctx.S.resetSession or __slctx.S.buyHold end
local function fmt(v)return __slctx.BN.format(v)end
function __slctx.HaloRun.state()
    local r=__slctx.Strategy.route()
    if not r.halo30 or r.halo30.version~=__slctx.CONFIG.RuntimeControllerVersion then
        r.halo30={version=__slctx.CONFIG.RuntimeControllerVersion,mode='PREPARE',book=__slctx.HaloPlan.newBook(r.previousHalo,r.evo and r.evo.index,false),
            lastReview=__slctx.now(),lastBuy=__slctx.now(),lastUpgrade=__slctx.now(),lastPlan=-math.huge,lastModelRevision=-1,
            buysAtReview=r.runBuyCount or 0,upgradesAtReview=__slctx.S.counts.upgrade,calibration='unobserved'}
    end
    return r.halo30
end

function __slctx.HaloRun.cancelFinish(why)
    local h=__slctx.HaloRun.state()
    if h.mode=='FINISH' then
        __slctx.log('FINISH_ROUTE_INVALIDATED',why..'; retain construction and pass; no reset sent')
        __slctx.Strategy.route().lastDecision='FINISH_ROUTE_INVALIDATED'
        h.nextReview=__slctx.now();h.finishReviewPending=true
    end
    h.mode='PREPARE';h.finish=nil;h.forecast=nil;h.calibration=why
    h.planDirty=true
end

function __slctx.HaloRun.observeQuote(q)
    if not q or not q.cost then return end
    local h=__slctx.HaloRun.state();local book=h.book
    local signature=tostring(q.id)..'|'..__slctx.BN.format(q.cost)
    if h.lastQuoteSignature==signature and h.lastQuoteBookRevision==book.revision then return end
    h.lastQuoteSignature=signature;h.lastQuoteBookRevision=book.revision
    local row,why=__slctx.HaloPlan.observe(book,q,index,__slctx.CONFIG)
    h.quotedRow=row;h.quoteId=q.id;h.quoteReason=why
    if book.scaleFailure then __slctx.HaloRun.cancelFinish(book.scaleFailure) end
    -- Priced extra rows are included in the budget; they do not erase the whole forecast.
    if book.scaleRevision~=h.lastModelRevision then
        h.lastModelRevision=book.scaleRevision;h.planDirty=true
        local m=book.model;local key=m and 'calibrated' or tostring(book.modelReason or book.scaleFailure)
        if key~=h.lastScaleLogKey or __slctx.now()-(h.lastScaleLogAt or -math.huge)>=15 then
            h.lastScaleLogKey=key;h.lastScaleLogAt=__slctx.now()
            __slctx.log('CATALOGUE_SCALE',m and ('anchors='..m.samples..'; intercept='..m.a..'; slope='..m.b..'; residual='..m.error)
                or ('not ready: '..key..'; actual purchases continue'))
        end
    end
end
function __slctx.HaloRun.income()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local rate,source,kind=__slctx.Strategy.rate()
    local observedAt=__slctx.now()
    if not rate then
        local fresh=#(r.cards or {})>0;local earliest=__slctx.now()
        for _,c in ipairs(r.cards or {}) do
            if not c.observedAt or __slctx.now()-c.observedAt>__slctx.CONFIG.CatalogueSnapshotSeconds then fresh=false;break end
            earliest=math.min(earliest,c.observedAt)
        end
        if fresh then
            local partial,known,total=__slctx.Planner.sumRates(r.cards)
            if partial and partial.m>0 then
                rate=partial;source='lower bound from '..known..'/'..total..' source payout/period cards'
                kind='ui-lower-bound';observedAt=earliest
            end
        end
    end
    if rate and rate.m>0 then
        h.incomeSnapshot={rate=rate,source=source,kind=kind,at=observedAt,revision=r.economicRevision or 0}
    else
        local snap=h.incomeSnapshot
        if snap and snap.revision==(r.economicRevision or 0) and __slctx.now()-snap.at<=__slctx.CONFIG.CatalogueSnapshotSeconds then
            rate,source,kind=snap.rate,'frozen unchanged-state income snapshot',snap.kind
        end
    end
    if rate and rate.m>0 then return __slctx.BN.mul(rate,__slctx.CONFIG.CatalogueIncomeMargin),source,kind end
    return nil,source,kind
end

-- ECONOMIC_VIEW_RUNTIME_32_BEGIN
function __slctx.HaloRun.economySnapshot(remaining,money,safeRate,action,model,useEffects)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    local allowance=__slctx.HaloPlan.finishAllowance(#__slctx.HaloCatalogue,action,__slctx.CONFIG)
    local v=__slctx.HaloPlan.routeReadiness(remaining,money,model or (safeRate and {other=safeRate,sources={}}),
        action,allowance,__slctx.CONFIG,useEffects)
    v.at=__slctx.now();v.evolution=r.evo and r.evo.index;v.halo=h.book.halo
    v.incomeSource=h.forecast and h.forecast.source
    local inv=r.latestInvestors
    v.investorAge=inv and inv.time and math.max(0,__slctx.now()-inv.time)
    if inv and inv.investors then
        local factors=__slctx.HaloPlan.fixedFactors(v.halo,v.evolution,inv.investors,__slctx.CONFIG,inv.perInvestor)
        __slctx.HaloPlan.factorReadiness(v,factors)
        if v.investorAge and v.investorAge<=__slctx.CONFIG.ReadinessInvestorMaxAge and safeRate and safeRate.m>0 and factors then
            local goal=r.powerGoal;local spend=__slctx.BN.new(0)
            if __slctx.CONFIG.AutoInvestorPowers and goal and goal.canBuyAfter and goal.nextBatch then spend=goal.price or spend end
            local afterBank=__slctx.BN.sub(__slctx.BN.add(inv.investors,inv.reward or __slctx.BN.new(0)),spend)
            local nextFactors=__slctx.HaloPlan.fixedFactors(v.halo,v.evolution,afterBank,__slctx.CONFIG,inv.perInvestor)
            local gain=__slctx.BN.div(nextFactors.total,factors.total)
            local nextModel=__slctx.HaloPlan.scaleRateModel(model or {other=safeRate,sources={}},gain)
            local projectedRemaining=remaining
            if spend.m>0 and goal and goal.nextBatch then
                projectedRemaining=__slctx.HaloPlan.rebatchRoute(remaining,goal.nextBatch,__slctx.Strategy.effectiveActionSeconds('upgrade'))
            end
            local projected=__slctx.HaloPlan.routeReadiness(projectedRemaining,__slctx.BN.new(0),nextModel,action,allowance,__slctx.CONFIG,useEffects)
            projected.bank=afterBank;projected.spend=spend;projected.factorGain=gain;projected.sameLayoutAssumption=true
            projected.quality='after rebuilding the current source levels, then remaining catalogue; not immediate income'
            local unit=factors.investors
            projected.requiredBank=projected.requiredSafeRate and __slctx.BN.div(__slctx.BN.sub(__slctx.BN.mul(unit,__slctx.BN.div(projected.requiredSafeRate,safeRate)),__slctx.BN.new(1)),inv.perInvestor)
            __slctx.HaloPlan.factorReadiness(projected,nextFactors);v.rebirth=projected
        end
    end
    local evo=r.evo;v.nextEvolution=evo and evo.index+1;v.evolutionReady=evo and evo.ready
    v.evolutionStartBank=evo and evo.bonusVisible and evo.bonusIsInvestors and evo.bonus or nil
    if v.evolutionStartBank and inv and v.factors and safeRate and safeRate.m>0 then
        local nextFactors=__slctx.HaloPlan.fixedFactors(v.halo,v.nextEvolution,v.evolutionStartBank,__slctx.CONFIG,inv.perInvestor)
        local ratio=__slctx.BN.div(nextFactors.total,v.factors.total)
        v.evolutionRestoredRate=__slctx.BN.mul(v.currentRate,ratio);v.evolutionFactor=ratio
        v.evolutionForecastKnown=true -- Algebraic comparable-layout scenario, not an instant starting rate.
    else v.evolutionForecastKnown=false end
    v.lastConfirmedFinish=r.lastHaloEconomy32;h.economy=v
    return v
end
-- ECONOMIC_VIEW_RUNTIME_32_END

function __slctx.HaloRun.plan(force)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if h.buyUnavailableReason then return nil end
    if h.resetInFlight or (__slctx.S.resetSession and __slctx.S.resetSession.isReset) then return h.forecast end
    if not force and __slctx.now()-h.lastPlan<__slctx.CONFIG.CataloguePlanSeconds then return h.forecast end
    h.lastPlan=__slctx.now();h.planDirty=false
    local computeStarted=__slctx.now()
    h.planCalls=(h.planCalls or 0)+1
    local rem,why
    local cacheKey=tostring(h.book.revision)..'/'..tostring(h.book.scaleRevision)
    if h.remainingKey==cacheKey then rem=h.remaining else
        rem,why=__slctx.HaloPlan.remaining(__slctx.HaloCatalogue,h.book,__slctx.CONFIG);h.remainingKey=rem and cacheKey or nil
    end
    h.remaining=rem;h.calibration=why or 'price model available'
    if not rem then
        if h.mode=='FINISH' then __slctx.HaloRun.cancelFinish('FINISH_PRICE_MODEL_UNAVAILABLE') end
        h.forecast=nil;h.requiredInvestors=nil
        __slctx.HaloRun.economySnapshot(nil,__slctx.cash(),nil,__slctx.Strategy.effectiveActionSeconds('buy'))
        return nil
    end
    local money=__slctx.cash();if not money then return nil end
    local rate,source,kind=__slctx.HaloRun.income()
    local dt=__slctx.Strategy.effectiveActionSeconds('buy')
    local sourceCards=r.cards
    for _,c in ipairs(sourceCards or {})do
        if not c.observedAt or __slctx.now()-c.observedAt>__slctx.CONFIG.CatalogueSnapshotSeconds then sourceCards={};break end
    end
    local rates=__slctx.HaloPlan.sourceModel(sourceCards,rate,__slctx.Planner.sourceRate)
    -- The ledger is exact only after an observed reset/start. On initial attachment,
    -- never reapply bonuses that might already be included in the observed income.
    local effects=__slctx.CONFIG.EnableCatalogueRouteProjection and h.book.complete and rem.modelVerified and rem.certifiable
    local bound=__slctx.HaloPlan.passiveBound(rem,money,rate,dt)
    local currentRow=r.buyQuote and r.buyQuote.id==h.quoteId and h.quotedRow or nil
    local routeRem=__slctx.HaloPlan.frontierRoute(rem,currentRow,r.buyQuote)
    local roll=__slctx.HaloPlan.roll(routeRem,money,rates,dt,effects)
    local routeEffects=effects;local levelRoute
    local expanded=__slctx.HaloPlan.withLevelPlan(routeRem,sourceCards,h.levelCurves,rates,__slctx.Strategy.largestBatch(),
        __slctx.Strategy.effectiveActionSeconds('upgrade'),__slctx.CONFIG,effects)
    if expanded then
        expanded=__slctx.HaloPlan.frontierRoute(expanded,currentRow,r.buyQuote)
        levelRoute=__slctx.HaloPlan.roll(expanded,money,rates,dt,true)
        if levelRoute and (not roll or __slctx.BN.cmp(levelRoute.time,roll.time)<0) then
            routeRem=expanded;routeEffects=true;roll=levelRoute
        end
    end
    local yes,reason,chosen=__slctx.HaloPlan.finishDecision(h.book,rem,bound,roll,__slctx.CONFIG,#__slctx.HaloCatalogue,dt)
    h.forecast={remaining=rem,routeRemaining=routeRem,routeEffects=routeEffects,hasLevelPlan=routeRem.hasLevels,bound=bound,roll=roll,rate=rate,rates=rates,rateKind=kind,source=source,time=__slctx.now(),action=dt}
    local inv=r.latestInvestors
    local economy=__slctx.HaloRun.economySnapshot(routeRem,money,rate,dt,rates,routeEffects)
    economy.levelNodes=routeRem.levelNodes or 0
    economy.levelProjection=routeRem.hasLevels==true
    -- Price-order cash flow remains useful as a scenario, never as an override
    -- of finishDecision's financing/conditional-route requirements.
    h.requiredInvestors=economy.rebirth and economy.rebirth.requiredBank or nil
    if h.mode=='FINISH' then
        local healthy,issue=__slctx.HaloPlan.finishHealth(h.finish,__slctx.now(),yes and chosen or nil,
            money,r.buyQuote and r.buyQuote.cost,rate,__slctx.CONFIG)
        if not yes or not healthy then
            __slctx.HaloRun.cancelFinish(not yes and reason or issue)
        end
    end
    if yes and h.mode~='FINISH' and (not h.finishReviewPending or chosen.funded)
        and not next(r.blocked or {}) and not r.powerUnresolved then
        __slctx.Strategy.cancelResetIntent('FINISH_ROUTE_SELECTED')
        r.lastDecision=reason;r.lastResetEstimate=nil
        h.finishReviewPending=nil
        h.mode='FINISH';h.finish={at=__slctx.now(),reason=reason,predicted=chosen.time,wait=chosen.wait,
            deadline=__slctx.now()+(__slctx.BN.number(chosen.time) or 0)+__slctx.CONFIG.HaloFinishGraceSeconds,
            conditional=reason=='FINISH_CONDITIONAL_CATALOGUE_ROUTE',income=rate,lastProgress=__slctx.now()}
        __slctx.log('FINISH_ROUTE_SELECTED',reason..'; remaining='..rem.count..'; remaining cost with margin='..fmt(rem.cost)
            ..'; modeled seconds='..fmt(chosen.time)..'; fixed budget seconds='..tostring(h.finish.deadline-h.finish.at)
            ..'; rebirth/evolution/optional powers suspended while forecast holds')
    end
    h.planSeconds=(h.planSeconds or 0)+math.max(0,__slctx.now()-computeStarted)
    h.planMaxSeconds=math.max(h.planMaxSeconds or 0,__slctx.now()-computeStarted)
    return h.forecast
end
function __slctx.HaloRun.observeReceipt(c)
    local h=__slctx.HaloRun.state()
    if c.kind=='buy' then
        local before=h.remaining
        local row=__slctx.HaloPlan.observe(h.book,c,index,__slctx.CONFIG)
        if row then __slctx.HaloPlan.markBought(h.book,row,c,before)
        else
            -- Keep every raw quote until independent anchors can disambiguate it.
            h.book.receipts[#h.book.receipts+1]={name=c.name,cost=__slctx.BN.new(c.cost.m,c.cost.e),id=c.id}
        end
        if h.book.model and #h.book.receipts>0 then
            local unresolved={}
            for _,q in ipairs(h.book.receipts)do
                local found=__slctx.HaloPlan.identify(q,h.book,index,__slctx.CONFIG)
                if found then h.book.bought[found.id]=true;h.book.revision=h.book.revision+1 else unresolved[#unresolved+1]=q end
            end
            h.book.receipts=unresolved
        end
        h.lastBuy=__slctx.now();h.wall=nil;h.planDirty=true;h.remainingKey=nil;h.buyStreak=(h.buyStreak or 0)+1
        if __slctx.Planner.isTerminalName(c.name) then
            h.economy=nil
            h.remaining={rows={},cost=__slctx.BN.new(0),count=0,completeLedger=h.book.complete,priceQuality='live terminal receipt'}
            h.requiredInvestors=nil
        end
        if h.finish then h.finish.lastProgress=__slctx.now();h.finish.stallSince=nil end
    else h.lastUpgrade=__slctx.now();h.planDirty=true;h.buyStreak=0 end
end
-- Extend receipts without changing their proof or the one-operation-at-a-time rule.
local previousReceipt=__slctx.Strategy.receipt
function __slctx.Strategy.receipt(c,beforeRate)
    previousReceipt(c,beforeRate)
    __slctx.HaloRun.observeReceipt(c)
end
local previousAfterReset=__slctx.Strategy.afterReset
function __slctx.Strategy.afterReset(kind,before)
    local h=__slctx.HaloRun.state();local oldBook=h.book
    local retainedLevelCurves=kind=='rebirth' and h.levelCurves or nil
    local lastSuccess=__slctx.Strategy.route().lastHaloEconomy32
    if kind=='halo' then
        lastSuccess={halo=oldBook.halo,evolution=oldBook.evolution,at=__slctx.now(),
            income=h.forecast and h.forecast.rate,quality='confirmed Ascend; rate is last observation, not an optimum threshold'}
    end
    previousAfterReset(kind,before)
    __slctx.Strategy.route().lastHaloEconomy32=lastSuccess
    local r=__slctx.Strategy.route()
    local newBook=__slctx.HaloPlan.newBook(r.previousHalo,r.evo and r.evo.index, true)
    __slctx.HaloPlan.copyExtras(oldBook,newBook,__slctx.CONFIG)
    if kind=='rebirth' then
        newBook.halo=oldBook.halo;newBook.evolution=oldBook.evolution
        newBook.anchors=oldBook.anchors;newBook.byAnchor=oldBook.byAnchor;newBook.model=oldBook.model
        newBook.scaleRevision=oldBook.scaleRevision
        newBook.orderChecks=oldBook.orderChecks;newBook.orderMisses=oldBook.orderMisses
    end
    r.halo30={version=__slctx.CONFIG.RuntimeControllerVersion,mode='PREPARE',book=newBook,lastReview=__slctx.now(),lastBuy=__slctx.now(),lastUpgrade=__slctx.now(),
        lastPlan=-math.huge,lastModelRevision=-1,buysAtReview=0,upgradesAtReview=__slctx.S.counts.upgrade,
        nextReview=__slctx.now()+__slctx.CONFIG.PreparationReviewMinimumSeconds,afterReset=true,levelCurves=retainedLevelCurves}
    -- Starting balances are observed; they do not impose a base-rebuild prerequisite.
end

-- ROUTE_RUNTIME_33_BEGIN
function __slctx.HaloRun.captureLevelCurves(cards)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    h.levelPoints=h.levelPoints or {};h.levelCurves=h.levelCurves or {}
    local epoch=tostring(h.book.halo)..'/'..tostring(r.evo and r.evo.index)
    for _,c in ipairs(cards or {}) do
        local key=__slctx.HaloPlan.key(c.name);local n=__slctx.Core.count(c.count);local batch=__slctx.Core.count(c.stack)
        local rate=__slctx.Planner.sourceRate(c)
        if n and batch and c.cost and rate then
            local group=h.levelPoints[key]
            local layout=tostring(r.runBuyCount or 0)..'/'..tostring(r.externalCapitalRevision or 0)
            if not group or group.epoch~=epoch or group.layout~=layout then
                group={epoch=epoch,layout=layout,batch=batch,points={}};h.levelPoints[key]=group
                h.levelCurves[key]=nil -- A different layout cannot inherit an old marginal-return curve.
            end
            local points=group.points;local last=points[#points]
            if not last or n>last.n then
                points[#points+1]={n=n,batch=batch,rate=rate,cost=c.cost}
                while #points>128 do table.remove(points,1) end
                local fit=__slctx.HaloPlan.fitLevelCurve(points)
                h.levelCurves[key]=fit -- Contradictory new samples invalidate the previous fit too.
            elseif last and n<last.n then h.levelPoints[key]=nil;h.levelCurves[key]=nil end
        end
    end
end
function __slctx.HaloRun.peekProgress()
    local h=__slctx.HaloRun.state();local r=__slctx.Strategy.route()
    if isPending() or h.mode=='FINISH' or __slctx.now()<(h.nextPassiveProgressRead or 0) then return end
    h.nextPassiveProgressRead=__slctx.now()+__slctx.CONFIG.PendingProgressReadSeconds
    if __slctx.CONFIG.DirectPrestige and __slctx.DirectPrestige then
        local inv=__slctx.readInvestors();local evo=__slctx.readEvolution()
        if inv then
            local goal=r.powerGoal
            if goal and goal.nextBatch and goal.currentBatch~='max' and goal.requiredReward
                and __slctx.BN.cmp(inv.reward,goal.requiredReward)>=0 then
                h.powerReviewHint={at=__slctx.now(),goalId=goal.id,reward=inv.reward}
            end
        end
        if evo then
            r.evo=evo;r.lastEvolutionRead=__slctx.now()
            __slctx.S.prestige=__slctx.S.prestige or {};__slctx.S.prestige.evo=evo
            if evo.ready then h.progressReviewHint=true end
        end
        return
    end
    local base=__slctx.paths.investors..'/Body/'
    local signature=__slctx.t(base..'Amount/Quantity')..'|'..__slctx.t(base..'Potential/Quantity')
    if h.passiveInvestorText~=nil and signature~=h.passiveInvestorText
        and __slctx.t(base..'Amount/What'):lower()=='investors' then
        local bank=__slctx.BN.parse(__slctx.t(base..'Amount/Quantity'));local reward=__slctx.BN.parse(__slctx.t(base..'Potential/Quantity'))
        if bank and reward then
            -- Hidden changed text is a wake-up hint, NEVER spending/reset authority.
            local total=__slctx.BN.add(__slctx.BN.add(bank,reward),r.spent or __slctx.BN.new(0))
            local threshold=r.target
            local goal=r.powerGoal
            local rewardEnough=goal and goal.nextBatch and goal.currentBatch~='max'
                and goal.requiredReward and __slctx.BN.cmp(reward,goal.requiredReward)>=0
            local evoEnough=threshold and __slctx.BN.cmp(total,__slctx.BN.mul(threshold,.999))>=0
            if rewardEnough then
                h.powerReviewHint={at=__slctx.now(),goalId=goal.id,reward=reward}
            end
            if evoEnough then h.progressReviewHint=true end
        end
    end
    h.passiveInvestorText=signature
end
function __slctx.HaloRun.noteEvolutionDecision(reason,q)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local v=h.economy;local trial=h.evolutionFinishTrial
    local line=string.format('[%.2f] ',__slctx.now())..reason..'; H='..tostring(h.book.halo)..'; E='..tostring(r.evo and r.evo.index)
        ..'; gate='..tostring(q and (q.key or q.id or q.name))..'; cost='..fmt(q and q.cost)..'; cash='..fmt(__slctx.cash())
        ..'; income='..fmt(v and v.currentRate)..'; scenarioReady='..tostring(v and v.scenarioReady)
        ..'; remaining='..tostring(h.remaining and h.remaining.count)..'; scenarioSeconds='..fmt(v and v.catalogueRoute and v.catalogueRoute.time)
        ..'; trialLeft='..tostring(trial and math.max(0,trial.deadline-__slctx.now()))
        ..'; negativeSamples='..tostring(trial and trial.negative and trial.negative.samples or 0)
        ..'; invalidReason='..tostring(trial and trial.invalidReason)
    local records=__slctx.S.evolutionDecisions;records[#records+1]=line
    while #records>24 do table.remove(records,1)end
    __slctx.log('EVOLUTION_DECISION',line)
end
function __slctx.HaloRun.deferEvolution(refresh)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if r.endPurchased or r.completionSeen then return true,'HALO_COMPLETION_TAKES_PRIORITY' end
    if __slctx.GoalDirector and __slctx.GoalDirector.finish() then return true,'FINISH_CASH_FUNDED' end
    if refresh then __slctx.HaloRun.plan(true)end
    if h.mode=='FINISH' then return true,'FINISH_ROUTE_PROTECTED' end
    local q=__slctx.readBuy and __slctx.readBuy();local money=__slctx.cash()
    -- The reset modal freezes the model, but a newly funded WHOLE remainder or
    -- the actual final button can still cancel evolution at confirmation.
    local rem=h.remaining
    if money and rem and rem.cost and rem.modelVerified and rem.certifiable~=false
        and __slctx.BN.cmp(money,rem.cost)>=0 then return true,'FINISH_CASH_FUNDED' end
    if money and q and q.cost and q.available and __slctx.Planner.isTerminalName(q.name or '')
        and __slctx.BN.cmp(money,q.cost)>=0 then return true,'FINAL_PURCHASE_FUNDED' end
    local v=h.economy;local trial=h.evolutionFinishTrial
    -- A cheap local purchase is not evidence of a short Halo route. In the H26/E2
    -- report even the price-order scenario with future boosts remained far short.
    -- Do not cancel an already selected evolution when that one purchase funds.
    local routeTooLong=v and v.known and v.certifiable and v.completeLedger
        and v.catalogueRoute and v.scenarioReady==false and not v.ready and not v.levelProjection
    -- A scenario can justify a bounded construction attempt, not an unconditional
    -- FINISH promise. Its original deadline never slides with minor upgrades.
    if not trial and v and v.scenarioReady and v.certifiable and not v.levelProjection and v.catalogueRoute then
        local seconds=__slctx.BN.number(v.catalogueRoute.time)
        if seconds and seconds>=0 and seconds<math.huge then
            local limit=__slctx.CONFIG.FinishMaximumWaitSeconds
                +#__slctx.HaloCatalogue*__slctx.Strategy.effectiveActionSeconds('buy')
            trial={started=__slctx.now(),deadline=__slctx.now()+math.min(seconds,limit)+__slctx.CONFIG.HaloFinishGraceSeconds}
            h.evolutionFinishTrial=trial
            __slctx.log('EVOLUTION_FINISH_TRIAL','continue current base; bounded scenario seconds='..(trial.deadline-trial.started)..'; no reset sent')
            __slctx.HaloRun.noteEvolutionDecision('TRIAL_STARTED',q)
        end
    end
    if trial and not trial.invalidated and __slctx.now()<trial.deadline then
        if routeTooLong then
            -- A newly exposed gate or a brief income dip can reverse a price-order
            -- scenario. Repeated checks of that ONE snapshot are not confirmation.
            local key=q and tostring(q.id or q.name)
            local negative=trial.negative
            if not negative or negative.key~=key then
                negative={key=key,since=__slctx.now(),samples=0};trial.negative=negative
                __slctx.HaloRun.noteEvolutionDecision('TRIAL_RECHECK',q)
            end
            local at=v.at
            if type(at)=='number' and at<=__slctx.now() and __slctx.now()-at<=__slctx.CONFIG.CataloguePlanSeconds*2
                and (not negative.lastAt or at-negative.lastAt>=__slctx.CONFIG.CataloguePlanSeconds) then
                negative.lastAt=at;negative.samples=negative.samples+1
            end
            local build=__slctx.Strategy.buildPermissionContext and __slctx.Strategy.buildPermissionContext(q,nil)
            local stalled=build and build.known and build.sustained and q and q.cost and money
                and __slctx.BN.cmp(money,q.cost)<0
            if stalled and negative.samples>=2
                and __slctx.now()-negative.since>=__slctx.CONFIG.EvolutionForecastConfirmSeconds then
                trial.invalidated=true;trial.invalidReason='SUSTAINED_BUILD_WALL_AND_NEGATIVE_FORECASTS'
                __slctx.HaloRun.noteEvolutionDecision('TRIAL_INVALIDATED',q)
                return false,'EVOLUTION_CURRENT_ROUTE_TOO_LONG'
            end
            return true,'FINISH_TRIAL_RECHECKING'
        end
        trial.negative=nil
        return true,'FINISH_SCENARIO_TRIAL_ACTIVE'
    end
    if trial and not trial.invalidated and __slctx.now()>=trial.deadline and not trial.expiryLogged then
        trial.expiryLogged=true;__slctx.HaloRun.noteEvolutionDecision('TRIAL_EXPIRED',q)
    end
    if routeTooLong then return false,'EVOLUTION_CURRENT_ROUTE_TOO_LONG' end
    if __slctx.CONFIG.GoalDirectedProgression and __slctx.CONFIG.DirectPrestige then
        return false,'EVOLUTION_READY_WITHOUT_PROVEN_FINISH'
    end
    if not q or not q.cost or not money then
        if __slctx.CONFIG.DirectPurchases and __slctx.readBuy then return true,'EVOLUTION_WAIT_CURRENT_BUY_DATA' end
        return false
    end
    -- When the full route is still unknown, allow one brief construction grace
    -- per cycle. New cheap buttons, receipts and tiny upgrades never renew it.
    local gate=h.evolutionBuyGate
    if not gate then
        gate={deadline=__slctx.now()+__slctx.CONFIG.BuildShortWaitSeconds};h.evolutionBuyGate=gate
    end
    if q.available and __slctx.BN.cmp(money,q.cost)>=0 and __slctx.now()<gate.deadline then
        return true,'CONTINUE_FUNDED_CONSTRUCTION'
    end
    local rate=__slctx.HaloRun.income();local eta=__slctx.Core.eta(money,q.cost,rate)
    if eta and eta>=0 and eta<=math.max(0,gate.deadline-__slctx.now()) and __slctx.now()<gate.deadline then
        return true,'CONTINUE_NEAR_FUNDED_CONSTRUCTION'
    end
    return false,'CURRENT_ROUTE_NOT_WITHIN_BOUNDED_FINISH'
end
function __slctx.HaloRun.routeEvolutionChoice(inv,evo,goal,yes,detail)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local v=h.economy
    if not evo or not evo.ready then return 'PREPARE' end
    if h.mode=='FINISH' then return 'FINISH' end
    if __slctx.HaloRun.deferEvolution(false) then return 'CONTINUE' end
    -- Avoid destroying a finish-capable bank solely because Evolve is lit up.
    -- The E-ready exception is narrow and carried by the final execution lease.
    local after=v and v.rebirth
    if yes and detail and after and after.ready and not v.levelProjection then
        detail.comparedEvolution=true;detail.finishAfterReset=true
        detail.evolutionIndex=evo.index;detail.evolutionBonus=evo.bonus
        detail.evolutionAlternativeRate=v.evolutionRestoredRate
        __slctx.log('RESET_VS_EVOLUTION','rebirth already reaches a modeled final route; E'..evo.index
            ..' bank='..__slctx.BN.format(inv.investors)..'; next E start='..__slctx.BN.format(evo.bonus))
        return 'REBIRTH'
    end
    return 'EVOLVE'
end
__slctx.Strategy.captureLevelCurves33=__slctx.HaloRun.captureLevelCurves
-- ROUTE_RUNTIME_33_END

-- FLOW_RUNTIME_31_BEGIN
function __slctx.HaloRun.stampReview()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    h.lastReview=__slctx.now();h.nextReview=__slctx.now()+__slctx.CONFIG.PreparationReviewMinimumSeconds
    h.buysAtReview=r.runBuyCount or 0;h.upgradesAtReview=__slctx.S.counts.upgrade
    h.reviewRate=__slctx.Strategy.rate();h.reviewCash=__slctx.cash()
    h.reviewPass=r.pass and r.pass.id;h.progressReviewHint=nil;h.powerReviewHint=nil
    h.finishReviewPending=nil
end
function __slctx.HaloRun.resume(destination,why)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    r.capabilityOnly=nil;r.reviewReturn=nil;r.resetPowerPlan=nil
    __slctx.Strategy.cancelResetIntent('CONTINUE_PREPARATION')
    __slctx.HaloRun.stampReview()
    if r.pass and not r.pass.finished then
        -- No r.pass=nil, no four-second wait, no trip through BUY that recreates the pass.
        __slctx.Strategy.phase(r.pass.quickBuild and 'REBUILD' or 'UPGRADE',why..'; сохранён проход '..r.pass.id..', стенд '..r.pass.index)
    else __slctx.Strategy.phase(destination=='UPGRADE' and 'BUY' or destination,why) end
end
function __slctx.HaloRun.checkedInvestors()
    local inv,why=__slctx.Strategy.readInvestors(true)
    if not inv then return nil,why end
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    __slctx.Strategy.syncPowerBank(inv.investors)
    if r.capitalCreditProbe then
        -- Same visible menu; no second tour through Manage/Powers/Investors.
        if not __slctx.sleep(__slctx.CONFIG.CapitalCreditStableSeconds) then return nil,'PAUSED' end
        local second=__slctx.Strategy.peekResetInvestors()
        if second then
            __slctx.Strategy.syncPowerBank(second.investors)
            inv=second;r.latestInvestors=second
        end
    end
    if r.capitalCreditProbe then return inv,'BANK_CREDIT_PENDING' end
    if (r.externalCapitalRevision or 0)~=(h.externalCapitalRevision or 0) then
        h.externalCapitalRevision=r.externalCapitalRevision or 0;h.powerScan=nil;h.powerAttempt=nil
        -- A user/manual action may have rebuilt the prefix. Invalidate counterfactual
        -- history; never label an observed balance increase a confirmed auto-rebirth.
        r.cleanRun=false;r.frontierTrace=nil;r.rewardCurve=nil
        local book=h.book;local q=r.buyQuote or __slctx.readBuy()
        local currentCash=__slctx.cash()
        local repeated=h.reviewCash and currentCash and h.reviewCash.m>0
            and __slctx.BN.cmp(currentCash,__slctx.BN.mul(h.reviewCash,.001))<0 or false
        for _,row in ipairs(q and index[__slctx.HaloPlan.key(q.name)] or {})do
            if book.bought[row.id] and book.model then
                local price=__slctx.HaloPlan.price(row,book.model,false,__slctx.CONFIG)
                if price and q.cost and math.abs(__slctx.BN.log(price)-__slctx.BN.log(q.cost))<.03 then repeated=true;break end
            end
        end
        if repeated then
            local replacement=__slctx.HaloPlan.newBook(book.halo,book.evolution,false)
            replacement.anchors=book.anchors;replacement.byAnchor=book.byAnchor;replacement.model=book.model
            replacement.scaleRevision=book.scaleRevision
            h.book=replacement;h.remainingKey=nil;h.lastQuoteSignature=nil
            r.pass=nil;h.wall=nil;h.mode='PREPARE';h.finish=nil
            __slctx.log('EXTERNAL_PROGRESS_RESYNC','stable bank increase and earlier catalogue quote; purchase ledger restarted as a lower bound')
        end
        h.planDirty=true
    end
    return inv
end
function __slctx.HaloRun.powerScanKey(inv)
    local r=__slctx.Strategy.route()
    return __slctx.HaloPlan.powerToken(inv and inv.investors or r.powerBank,__slctx.Strategy.largestBatch(),r.evo and r.evo.index)
        ..'/'..tostring(r.externalCapitalRevision or 0)..'/'..tostring(__slctx.S.counts.power or 0)
end
function __slctx.HaloRun.powerGoal(inv,force)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if not __slctx.CONFIG.AutoInvestorPowers or not __slctx.canUpgrade() or __slctx.Strategy.largestBatch()=='max' then return nil end
    local goal=__slctx.Strategy.updatePowerGoal(inv);local key=__slctx.HaloRun.powerScanKey(inv);local cache=h.powerScan
    local missingQuote=not goal and cache and not cache.failed and cache.at
        and __slctx.now()-cache.at>=__slctx.CONFIG.PowerScanRetrySeconds
    local retry=cache and cache.failed and __slctx.now()>=(cache.retryAt or 0) or missingQuote
    if force or not cache or cache.key~=key or retry then
        if not cache or cache.key~=key or not cache.failed or retry then
            local ok=__slctx.Strategy.refreshPowerQuote()
            h.powerScan={key=key,at=__slctx.now(),failed=not ok,retryAt=__slctx.now()+__slctx.CONFIG.PowerScanRetrySeconds}
            h.powerScans=(h.powerScans or 0)+1
            if ok then goal=__slctx.Strategy.updatePowerGoal(inv) end
            __slctx.log('POWER_SCAN_RESULT','key='..key..'; target='..tostring(goal and goal.title)
                ..(ok and (goal and '; quote cached until bank/batch/confirmed power changes' or '; next quote unknown; bounded retry scheduled') or '; failed observation; bounded retry scheduled'))
        end
    else h.powerScanSkipped=(h.powerScanSkipped or 0)+1 end
    return goal
end
function __slctx.HaloRun.powerActionKey(goal,inv)
    return __slctx.HaloRun.powerScanKey(inv)..'/'..tostring(goal and goal.path)..'/'..__slctx.BN.format(goal and goal.price)
end
function __slctx.HaloRun.powers()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local destination=r.powerReturn or h.returnPhase or 'BUY'
    local before=__slctx.S.counts.power or 0;local pass=r.pass
    local target=r.powerPurchasePlan;local key=__slctx.HaloRun.powerActionKey(target,r.latestInvestors)
    if h.powerAttempt==key and not r.powerUnresolved then
        r.powerPending=false;r.powerReturn=nil;r.powerPurchasePlan=nil
        __slctx.HaloRun.resume(destination,'POWERS: условия прежние, повторный пустой визит пропущен');return
    end
    h.powerAttempt=key
    __slctx.Powers.run()
    if not __slctx.live() or isPending() or r.powerUnresolved then return end
    h.powerScan={key=__slctx.HaloRun.powerScanKey(r.latestInvestors),at=__slctx.now(),failed=false}
    h.planDirty=true
    if (__slctx.S.counts.power or 0)>before and pass and r.pass==pass and not pass.finished then
        -- Investor spending changes throughput, not this stand's reserved cash budget.
        pass.decisionBatch=nil
        r.preferredReviewBatch=__slctx.Strategy.largestBatch()
        if __slctx.manageTab('Manage') then __slctx.Strategy.stackPrepare() end
    end
    if r.phase~='EVOLVE_RESERVE' and r.phase~='HALO' then __slctx.HaloRun.resume(destination,'способности обработаны; продолжаю покупки') end
end
function __slctx.HaloRun.bootstrapWorkSeconds(goal)
    local r=__slctx.Strategy.route();local clicks
    if goal and goal.nextBatch then clicks=__slctx.Planner.workClicks(r.runWork,goal.nextBatch) end
    local seconds=#__slctx.HaloCatalogue*__slctx.Strategy.effectiveActionSeconds('buy')
        +(clicks or 0)*__slctx.Strategy.effectiveActionSeconds('upgrade')+__slctx.CONFIG.InitialMenuTripSeconds*4
    return math.max(__slctx.CONFIG.InitialFullLayoutSeconds,seconds)
end
function __slctx.HaloRun.canBootstrap(goal)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local q=r.buyQuote;local amount=__slctx.cash()
    if not q or not q.cost or not amount or r.recovery then return false end
    local funded=__slctx.BN.cmp(amount,q.cost)>=0
    local completed=r.pass and r.pass.complete and r.pass.finished
    local tactical=goal and goal.canBuyAfter and goal.nextBatch and goal.currentBatch~='max'
        and __slctx.S.counts.upgrade-(h.upgradesAtReview or 0)>=__slctx.CONFIG.CapabilityReviewPurchases
    return ((completed and not funded) or tactical) and h.mode~='FINISH'
end
-- FLOW_RUNTIME_31_END

function __slctx.HaloRun.boot()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if r.powerUnresolved then
        local item=r.powerUnresolved.item
        if __slctx.manageTab('Powers') and __slctx.Powers.proof(item) then __slctx.Strategy.recordSpend(item.price);r.powerUnresolved=nil
        else __slctx.pause('POWER_OUTCOME_UNRESOLVED','Не подтверждена прежняя трата; повтор не отправлен.');return end
    end
    if not __slctx.ResetConfirm.dismissStale() then return end
    if r.bootEvolution or not r.evo then
        local evo,why=__slctx.Strategy.readEvolution();if not evo then if __slctx.live()then __slctx.pause('EVOLUTION_INIT_FAILED',tostring(why))end;return end
        local halo
        if not r.previousHalo or not h.haloRead or r.lastReset=='halo' then
            halo=__slctx.Strategy.readHalo();if not halo then if __slctx.live()then __slctx.pause('HALO_INIT_FAILED','Не удалось прочитать число Halo.')end;return end
        end
        local number=halo and halo.amount or r.previousHalo
        if h.book.halo~=nil and h.book.halo~=number or h.book.evolution~=nil and h.book.evolution~=evo.index then
            local priorBook=h.book
            h.book=__slctx.HaloPlan.newBook(number,evo.index,r.cleanRun==true)
            __slctx.HaloPlan.copyExtras(priorBook,h.book,__slctx.CONFIG)
            h.mode='PREPARE';h.finish=nil;h.economy=nil
            r.powerBase=nil;r.powerUsed=__slctx.BN.new(0);r.powerBank=nil;r.spent=__slctx.BN.new(0);r.spentUnknown=not r.cleanRun
        end
        h.book.halo=number;h.book.evolution=evo.index;h.haloRead=true
        r.previousHalo=number;r.previousEvolution=evo.index;r.bootEvolution=false
        __slctx.log('HALO_RUN_START','Halo='..tostring(number)..'; E='..evo.index..'; catalogue='..#__slctx.HaloCatalogue
            ..'; donor investor='..__slctx.CONFIG.ExpectedInvestorBonus..'; time x'..__slctx.CONFIG.ExpectedTimeMultiplier
            ..'; observed income already contains actual bonuses')
    end
    if __slctx.GoalDirector and __slctx.GoalDirector.tick(true) then return end
    if r.bootTablet then
        local _,why=__slctx.ensureTablet();r.bootTablet=false
        if not __slctx.live()then return end
        if why then __slctx.log('TABLET_STATUS',why) end
    end
    local inv,why=__slctx.HaloRun.checkedInvestors()
    if not inv then if __slctx.live()then __slctx.pause('INVESTORS_READ_FAILED',tostring(why))end;return end
    h.lastReview=__slctx.now();h.reviewCash=__slctx.cash();h.reviewRate=__slctx.Strategy.rate();h.reviewBank=inv.investors
    if inv.perInvestor and math.abs(inv.perInvestor-__slctx.CONFIG.ExpectedInvestorBonus)>.0001 then
        __slctx.log('DONOR_BONUS_OBSERVED','GUI='..tostring(inv.perInvestor)..'; using GUI, not multiplying donor bonus twice')
    end
    if __slctx.canUpgrade() then
        if __slctx.manageTab('Manage') then __slctx.Strategy.stackPrepare();local cards=__slctx.Strategy.readCards();__slctx.Strategy.captureGrowth(cards)end
        if __slctx.Strategy.largestBatch()~='max' and __slctx.CONFIG.AutoInvestorPowers then
            __slctx.Strategy.phase('POWERS','доступные способности в пределах 5%, затем подготовка к финалу');return
        end
    end
    __slctx.Strategy.phase('BUY','PREPARE: получаю актуальные цены; большой стартовый банк допустим')
end

function __slctx.HaloRun.reviewDue(q)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if h.mode=='FINISH' or not __slctx.S.resetEnabled or not (__slctx.CONFIG.AutoRebirth or __slctx.CONFIG.AutoEvolution) or r.recovery or isPending() then return false end
    if h.finishReviewPending then return true end
    if __slctx.now()<(h.nextReview or 0) then return false end
    local age=__slctx.now()-(h.lastReview or __slctx.now())
    if age<__slctx.CONFIG.PreparationReviewMinimumSeconds then return false end
    if h.progressReviewHint then return true end
    local purchases=__slctx.S.counts.upgrade-(h.upgradesAtReview or 0)
    local buys=(r.runBuyCount or 0)-(h.buysAtReview or 0)
    local goal=r.powerGoal
    local tactical=goal and (goal.canBuyNow or goal.canBuyAfter) and goal.nextBatch and goal.currentBatch~='max'
    local larger=goal and type(goal.currentBatch)=='number' and goal.currentBatch>0
        and (goal.nextBatch=='max' or type(goal.nextBatch)=='number' and goal.nextBatch>goal.currentBatch)
    local hint=h.powerReviewHint
    local freshHint=larger and hint and hint.goalId==goal.id and hint.at>=(h.lastReview or 0)
        and __slctx.now()-hint.at<=__slctx.CONFIG.PreparationReviewMinimumSeconds+2*__slctx.CONFIG.PendingProgressReadSeconds
        and goal.requiredReward and __slctx.BN.cmp(hint.reward,goal.requiredReward)>=0
    if r.pass and not r.pass.finished then
        -- A quote funding wall does NOT mean a stand pass is complete.
        -- At most one review per substantial new batch of work; return to this pass.
        -- A GUI reward change may outgrow the last review's canBuyAfter flag.
        -- After real work and the shared cooldown, refresh that specific larger
        -- tier instead of grinding another 32/96 inputs on an obsolete quote.
        if larger and purchases>=__slctx.CONFIG.AllocationMinimumPurchases and (tactical or freshHint) then return true end
        return purchases>=__slctx.CONFIG.PreparationReviewUpgradePurchases
            and age>=__slctx.CONFIG.PreparationNoChangeBackoffSeconds
    end
    local rate=__slctx.Strategy.rate()
    local changed=rate and h.reviewRate and __slctx.BN.log(rate)-__slctx.BN.log(h.reviewRate)>=__slctx.CONFIG.PreparationReviewGrowthDecades
    return (changed and buys>=__slctx.CONFIG.PreparationReviewBuys)
        or (age>=__slctx.CONFIG.PreparationWatchdogSeconds and (buys>=32 or purchases>=32))
end
function __slctx.HaloRun.requestReview(destination)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    h.returnPhase=destination;r.capabilityOnly=true;r.reviewReturn=destination
    __slctx.Strategy.phase('CAPABILITY','PREPARE: сравниваю рост сейчас и после перерождения')
end

function __slctx.HaloRun.resetForecast(inv,goal)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    __slctx.Strategy.sampleIncome()
    local f=__slctx.HaloRun.plan(true)
    if h.mode=='FINISH' then return false,'FINISH_ROUTE_LOCKED' end
    if not inv or not inv.ready or not inv.perInvestor or inv.perInvestor<=0 then return false,'INVESTOR_DATA_UNAVAILABLE' end
    local spend=goal and goal.canBuyAfter and goal.nextBatch and goal.price or __slctx.BN.new(0)
    local g=__slctx.Planner.netInvestorGain(inv,spend)
    if not g or g<=1 then return false,'NO_NET_RESET_GAIN_AFTER_SPENDING' end
    local rate=f and f.rate or __slctx.HaloRun.income()
    local setup=__slctx.Strategy.actionSeconds('rebirth')+__slctx.CONFIG.AfterResetWait
    if spend.m>0 then setup=setup+__slctx.Strategy.actionSeconds('power')+__slctx.CONFIG.InitialMenuTripSeconds end
    local context={rate=rate,plannedSpend=spend,powerGoal=goal}
    -- Share the armed, non-renewable construction wait with both comparisons.
    local localContext=__slctx.Strategy.resetContext(inv,false)
    -- A faster confirmed batch can repay a reset through avoided input work even
    -- while catalogue prices are uncalibrated or investor income grows modestly.
    -- Count remaining budget work, never already-completed clicks as future savings.
    if spend.m>0 and goal and goal.nextBatch and not r.recovery then
        local work,workSource=__slctx.Strategy.powerWork(r.cards)
        local q=r.buyQuote;local eta=q and q.cost and __slctx.Core.eta(__slctx.cash(),q.cost,rate)
        context.work=work;context.workSource=workSource
        context.actionSeconds=__slctx.Strategy.effectiveActionSeconds('upgrade')
        context.rebuildProfile=r.rebuildProfile
        context.rebuildSeconds=__slctx.HaloRun.bootstrapWorkSeconds(goal)
        context.resetSeconds=__slctx.Strategy.actionSeconds('rebirth')
        context.powerSeconds=__slctx.Strategy.actionSeconds('power')+__slctx.CONFIG.InitialMenuTripSeconds
        context.protectedMajor=localContext.protectedMajor
        local yes,reason,gain,detail=__slctx.Planner.capabilityResetDecision(inv,__slctx.CONFIG,context)
        if yes then
            detail.authorization='capability-work-331'
            detail.restoreQuality=detail.recoverySource..'; '..tostring(workSource)
            context.cycle=detail.cost
            __slctx.log('STACK_RESET_ESTIMATE','batch='..tostring(goal.currentBatch)..'->'..tostring(goal.nextBatch)
                ..'; discounted future input saved='..string.format('%.2f',detail.saved)
                ..'s; reset+power+rebuild='..string.format('%.2f',detail.cost)..'s; '..tostring(workSource))
            return true,reason,gain,detail,context
        end
    end
    -- Ordinary rebirth must repay itself on the CURRENT observed funding block.
    -- A remote catalogue ETA (the H23 report reached 8.676e95 seconds) is not
    -- an authorization: its constant-layout assumption ignores ongoing growth.
    localContext.plannedSpend=spend
    localContext.buyQuote=r.buyQuote;localContext.money=__slctx.cash()
    local yes,reason,detail=__slctx.Planner.observedBlockReset(inv,__slctx.CONFIG,localContext)
    if detail then context.cycle=detail.cost end
    return yes,reason,g,detail,context
end
function __slctx.HaloRun.performReset(inv,goal,detail,context)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if h.mode=='FINISH' or (r.evo and r.evo.ready and not (detail and detail.comparedEvolution and detail.finishAfterReset)) then return false end
    local reason=detail and detail.authorization=='repeat-ready-rebirth' and 'REPEAT_READY_REBIRTH'
        or detail and detail.authorization=='next-evolution-prefix' and 'REBIRTH_TO_EVOLUTION'
        or (goal and context.plannedSpend.m>0 and 'RESET_FOR_UPGRADE_STACK' or 'RESET_FOR_NET_PRODUCTION')
    r.lastDecision=reason
    r.capabilityOnly=true;r.resetPowerPlan=reason=='RESET_FOR_UPGRADE_STACK' and goal or nil
    __slctx.Strategy.rememberResetIntent(inv,context,reason,__slctx.Planner.netInvestorGain(inv,context.plannedSpend),detail)
    __slctx.log('HALO_ROUTE_COMPARE','decision='..reason..'; scope='..tostring(detail.authorization)
        ..'; target='..tostring(detail.target)..'; continue='..fmt(detail.direct)..'s; via reset='
        ..fmt(detail.reset)..'s; output_horizon='..tostring(detail.horizon)
        ..'; log_output_advantage='..tostring(detail.logAdvantage)..'; '..tostring(detail.restoreQuality))
    local done=__slctx.doReset('rebirth')
    if not done and __slctx.live()then
        __slctx.Strategy.cancelResetIntent('EXECUTION_NOT_COMPLETED');r.capabilityOnly=nil;r.resetPowerPlan=nil
        h.nextReview=__slctx.now()+__slctx.CONFIG.PreparationReviewMinimumSeconds
        __slctx.Strategy.phase(h.returnPhase or 'BUY','сброс не отправлен; возвращаюсь к сохранённому маршруту')
    end
    return done
end

function __slctx.HaloRun.selectEvolution()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local v=h.economy
    r.capabilityOnly=nil;r.reserveSince=__slctx.now();h.progressReviewHint=nil
    r.lastDecision='EVOLUTION_NO_SHORT_FINISH'
    __slctx.HaloRun.noteEvolutionDecision('EVOLUTION_SELECTED',r.buyQuote)
    __slctx.log('EVOLUTION_ROUTE_CHOICE','remaining='..tostring(h.remaining and h.remaining.count)
        ..'; currentScenarioReady='..tostring(v and v.scenarioReady)
        ..'; incomeGapLog10='..tostring(v and v.decadesShort)
        ..'; startBank='..fmt(r.evo and r.evo.bonus)..'; no fixed bonus target')
    __slctx.Strategy.phase('EVOLVE_RESERVE','готова эволюция; быстрый финал текущей базы не подтверждён')
end

function __slctx.HaloRun.review()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local destination=h.returnPhase or 'BUY'
    if isPending()then return end
    if h.mode=='FINISH' then r.capabilityOnly=nil;__slctx.Strategy.phase('BUY','FINISH: промежуточные сбросы запрещены');return end
    __slctx.HaloRun.income()
    r.buyQuote=nil
    if not __slctx.Strategy.refreshResetBuy()then
        if __slctx.live()then __slctx.HaloRun.resume(destination,'нет свежей цены; продолжаю прежний проход без сброса')end
        return
    end
    __slctx.HaloRun.observeQuote(r.buyQuote)
    if r.endPurchased or r.completionSeen then __slctx.Strategy.phase('HALO','подтверждён конец');return end
    local inv,why=__slctx.HaloRun.checkedInvestors()
    if not inv then if __slctx.live()then __slctx.pause('INVESTORS_READ_FAILED',tostring(why))end;return end
    if r.capitalCreditProbe then
        __slctx.HaloRun.resume(destination,'проверяется изменение банка; реальные денежные покупки продолжаются');return
    end
    __slctx.HaloRun.plan(true)
    if h.mode=='FINISH' then r.capabilityOnly=nil;__slctx.Strategy.phase('BUY','FINISH: ресурсы на остаток каталога обеспечены');return end
    local amount=__slctx.cash()
    if r.buyQuote and r.buyQuote.cost and amount and __slctx.BN.cmp(amount,r.buyQuote.cost)>=0 then h.wall=nil end
    local total=__slctx.Planner.totalMinimum(inv,r.spent)
    local due=__slctx.Planner.shouldInspectEvolution(r.evo and r.evo.index,inv,r.spent,false,r.evo and r.evo.ready)
    if __slctx.CONFIG.AutoEvolution and __slctx.S.resetEnabled and due then
        local evo=__slctx.Strategy.readEvolution();r.evolutionCheckTotal=total
        if not evo then if __slctx.live()then __slctx.pause('EVOLUTION_READ_FAILED','Не удалось проверить этап.')end;return end
        -- Decide after the same-state rebirth-to-final calculation below.
    end
    if r.evo and r.evo.ready then
        local hold,reason=__slctx.HaloRun.deferEvolution(false)
        if hold then
            __slctx.log('EVOLUTION_DEFERRED',reason..'; current construction retained')
            __slctx.HaloRun.resume('BUY','продолжаю текущую базу; эволюция отложена');return
        end
    end
    if __slctx.CONFIG.AutoRebirth and __slctx.S.resetEnabled and not (__slctx.GoalDirector and __slctx.GoalDirector.ownsRebirth()) and not (r.evo and r.evo.ready) and inv.investors.m==0 and inv.ready and __slctx.BN.cmp(inv.reward,__slctx.BN.new(__slctx.CONFIG.TabletReserve))>=0 then
        local ctx={rate=__slctx.Strategy.rate(),plannedSpend=__slctx.BN.new(0)}
        local d={cost=__slctx.CONFIG.InitialFullLayoutSeconds,authorization='first-bank-30',restoreQuality='first investor bank'}
        __slctx.HaloRun.performReset(inv,nil,d,ctx);return
    end
    local goal=__slctx.HaloRun.powerGoal(inv,false)
    if goal and goal.canBuyNow and not (r.evo and r.evo.ready) and __slctx.HaloRun.powerActionKey(goal,inv)~=h.powerAttempt then
        r.powerReturn=destination;r.powerPurchasePlan=goal;r.capabilityOnly=nil
        __slctx.Strategy.phase('POWERS','покупаю конкретную доступную пачку, затем возвращаюсь к проходу');return
    end
    if __slctx.CONFIG.AutoRebirth and __slctx.S.resetEnabled and not (__slctx.GoalDirector and __slctx.GoalDirector.ownsRebirth()) and inv.ready and not r.recovery and inv.perInvestor then
        local yes,reason,gain,detail,ctx=__slctx.HaloRun.resetForecast(inv,goal)
        r.gain=gain;r.lastDecision=reason;r.lastResetEstimate=detail;h.lastCompare=detail
        local choice=__slctx.HaloRun.routeEvolutionChoice(inv,r.evo,goal,yes,detail)
        if choice=='CONTINUE' or choice=='FINISH' then __slctx.HaloRun.resume('BUY','текущий маршрут сохранён перед эволюцией');return end
        if choice=='EVOLVE' then
            __slctx.HaloRun.selectEvolution();return
        end
        if yes then
            if ctx.plannedSpend.m>0 then
                -- Revalidate once for execution. Do not turn every negative review into a shop tour.
                if not __slctx.Strategy.refreshPowerQuote()then yes=false else
                    inv=__slctx.HaloRun.checkedInvestors();goal=inv and __slctx.Strategy.updatePowerGoal(inv)
                    if inv then
                        yes,reason,gain,detail,ctx=__slctx.HaloRun.resetForecast(inv,goal)
                        if __slctx.HaloRun.routeEvolutionChoice(inv,r.evo,goal,yes,detail)=='EVOLVE' then yes=false end
                    else yes=false end
                end
            end
            if yes then __slctx.HaloRun.performReset(inv,goal,detail,ctx);return end
        end
        __slctx.log('HALO_PREPARATION_DECISION',tostring(reason)..'; remaining='..fmt(h.remaining and h.remaining.cost)
            ..'; pass retained='..tostring(r.pass and r.pass.id)..'; investor target='..fmt(h.requiredInvestors))
        if reason=='BUILD_TARGET_SOON' or reason=='PROTECTED_MAJOR_TARGET' then
            -- Honor the promise: retain cash for this exact quote instead of
            -- spending it on +1 levels and repeatedly predicting the same ETA.
            if __slctx.Strategy.reserveGoal(r.buyQuote,__slctx.Strategy.rate(),reason)then
                r.capabilityOnly=nil;r.reviewReturn=nil;r.resetPowerPlan=nil
                return
            end
        end
    end
    if r.evo and r.evo.ready and __slctx.CONFIG.AutoEvolution and __slctx.S.resetEnabled then
        __slctx.HaloRun.selectEvolution();return
    end
    h.progressReviewHint=nil
    -- No idle delay for a missing mathematical model. Execute the retained work.
    if r.pass and not r.pass.finished then __slctx.HaloRun.resume('UPGRADE','PREPARE: продолжаю сохранённый проход');return end
    if h.wall and r.buyQuote and r.buyQuote.cost and amount and __slctx.BN.cmp(amount,r.buyQuote.cost)<0 then
        __slctx.HaloRun.stampReview();r.capabilityOnly=nil;r.reviewReturn=nil;r.resetPowerPlan=nil
        h.waitUntil=__slctx.now()+__slctx.CONFIG.PreparationIdleObservationSeconds;h.waitReturn='BUY'
        h.waitCost=r.buyQuote.cost;h.waitId=r.buyQuote.id
        __slctx.Strategy.phase('WAIT_GROWTH','проход завершён; короткое ожидание реального поступления денег');return
    end
    __slctx.HaloRun.resume('BUY','PREPARE: продолжаю строительство')
end
function __slctx.HaloRun.heldSignature(q)
    return q and (tostring(q.id)..'|'..tostring(q.info)..'|'..tostring(q.uses)) or nil
end
function __slctx.HaloRun.invalidateHeldAccounting()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    -- Native repeat may cross multiple server purchases between GUI samples.
    -- Only the starting real quote is a counted lower bound; never invent debits.
    h.book.complete=false;h.book.revision=h.book.revision+1
    h.incomeSnapshot=nil;h.forecast=nil;h.economy=nil;h.remainingKey=nil;h.requiredInvestors=nil
    h.lastPlan=-math.huge;h.planDirty=true
    -- Preserve the committed final run. Its existing real funding/stall checks
    -- decide whether it must stop; incomplete burst accounting is not a reset gate.
    h.holdAccountingUncertain=true
    r.cleanRun=false;r.buyCountLowerBound=true;r.frontierTrace=nil;r.rewardCurve=nil
    r.rewardSamples={};r.growthSamples={};r.uiObservation=nil;r.cards={}
    r.models={};r.priceModels={};r.batchQuotes={};r.buyQuote=nil
    if __slctx.S.cashFlow then __slctx.S.cashFlow:reset() end
    if __slctx.S.rate then __slctx.S.rate:reset() end
    __slctx.S.buyReceiptStreak=0;__slctx.S.lastSpend=__slctx.now();__slctx.S.catalogDirty=true
end
function __slctx.HaloRun.tryBuyHold(c)
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if not __slctx.CONFIG.BuyHoldEnabled or h.holdDisabled then return false end
    if __slctx.S.windowFocused==false then return false end
    if isPending() then return true end
    if __slctx.Driver.releaseBlocked then __slctx.pause('BUY_HOLD_RELEASE_UNRESOLVED','Mouse-up не подтверждён; новые действия остановлены.');return true end
    if not __slctx.Driver.virtual and not h.holdProbeAttempted then
        h.holdProbeAttempted=true
        __slctx.Virtual.check(__slctx.S.epoch)
    end
    if not __slctx.Driver.virtual then
        h.holdDisabled=true
        __slctx.log('BUY_HOLD_FALLBACK','native virtual input unavailable; using ordinary verified clicks, not a simulated hold')
        return false
    end
    local initial=__slctx.HaloRun.heldSignature(c);local started=__slctx.now();local epoch=__slctx.S.epoch
    local hold={epoch=epoch,started=started,dispatched=false,progressWhileDown=false}
    local rec={c=c,started=started,focusPauseBase=__slctx.S.focusPausedTotal or 0,beforeCash=__slctx.cash()}
    local expected={name=c.name,price=c.cost,priceText=__slctx.childText(c.root,'PurchasePrice'),currency='cash',restore='buy'}
    expected.authorize=function()
        local q=__slctx.readBuy();local amount=__slctx.cash()
        return q and __slctx.HaloRun.heldSignature(q)==initial and q.cost and amount and __slctx.BN.cmp(amount,q.cost)>=0
    end
    local session
    if __slctx.CONFIG.AutoConfirmPurchases then
        local why;session,why=__slctx.ResetConfirm.begin('buy',c.button,expected)
        if not session then __slctx.status('BUY_HOLD_NOT_READY',tostring(why));return true end
        session.changed=function()return __slctx.HaloRun.heldSignature(__slctx.readBuy())~=initial end
    end
    __slctx.S.buyHold=hold
    local final,completed,observed,stopReason
    local succeeded,failure=pcall(function()
        local ok,why=__slctx.Virtual.click(c.button,expected.authorize,function(pressed,profile)
            hold.dispatched=true;if session then session.sent=true end
            local last=initial;local lastChange=__slctx.now()
            local deadline=__slctx.now()+math.max(.1,math.min(5,__slctx.CONFIG.BuyHoldBurstSeconds or 2))
            while __slctx.live(epoch) and __slctx.Driver.pressed==pressed and __slctx.now()<deadline do
                if __slctx.S.windowFocused==false then return 'focus changed' end
                if __slctx.visible(__slctx.g('Important/Alert')) then return 'modal appeared' end
                if r.phase~='BUY' then return 'route changed' end
                local point=__slctx.Virtual.point(c.button,profile)
                if not point or math.abs(point.x-pressed.x)>1 or math.abs(point.y-pressed.y)>1 then return 'button covered or moved' end
                local q=__slctx.readBuy();local signature=__slctx.HaloRun.heldSignature(q)
                if signature and signature~=last then last=signature;lastChange=__slctx.now();hold.progressWhileDown=true end
                if __slctx.buyComplete() then return 'end observed' end
                local amount=__slctx.cash()
                if not q or q.button~=c.button or not q.cost or not amount then return 'quote unavailable' end
                if __slctx.BN.cmp(amount,q.cost)<0 then return 'funding wall' end
                if __slctx.now()-lastChange>=math.max(.1,__slctx.CONFIG.BuyHoldNoProgressSeconds or .75) then return 'no repeat observed' end
                __slctx.S.actionYieldSerial=(__slctx.S.actionYieldSerial or 0)+1
                task.wait(math.max(0,__slctx.CONFIG.BuyHoldPollSeconds or 0))
            end
            return __slctx.live(epoch) and 'burst boundary' or 'paused'
        end)
        stopReason=why
        if not ok then error('BUY_HOLD_INPUT: '..tostring(why)) end
        -- Mouse-up precedes confirmation, observation settling, and all navigation.
        local releasedAt=__slctx.now();local stableAt=__slctx.now();local last=nil
        local settleDeadline=__slctx.now()+(hold.progressWhileDown and math.max(.2,__slctx.CONFIG.RecoverySettleSeconds) or __slctx.CONFIG.ActionTimeout)
        repeat
            final=__slctx.readBuy()
            completed=__slctx.buyComplete()
            local signature=completed and 'COMPLETE' or __slctx.HaloRun.heldSignature(final)
            if signature~=last then last=signature;stableAt=__slctx.now() end
            observed=completed or signature~=nil and signature~=initial
            local modal=__slctx.visible(__slctx.g('Important/Alert'))
            if __slctx.live(epoch) and session and (modal or session.pending) then
                session.observedModal=true
                session.extraDeadline=session.extraDeadline or (__slctx.now()+__slctx.CONFIG.ConfirmWaitTimeout)
                __slctx.ResetConfirm.poll(session)
                if session.extraDeadline then settleDeadline=math.max(settleDeadline,session.extraDeadline) end
                modal=__slctx.visible(__slctx.g('Important/Alert')) or session.pending~=nil or __slctx.S.resetChildPending~=nil
            end
            if not __slctx.live(epoch) then break end
            if observed and not modal and __slctx.now()-releasedAt>=.15 and __slctx.now()-stableAt>=__slctx.CONFIG.ReceiptStableSeconds then break end
            if __slctx.now()>=settleDeadline then
                if modal then error('BUY_HOLD_MODAL_UNRESOLVED') end
                break
            end
            __slctx.S.actionYieldSerial=(__slctx.S.actionYieldSerial or 0)+1;task.wait(0)
        until false
    end)
    __slctx.S.buyHold=nil
    if session then __slctx.ResetConfirm.finish(session,succeeded and observed==true) end
    if hold.dispatched then
        if observed then __slctx.Safety.commit(rec);__slctx.S.buyHoldCountLowerBound=(__slctx.S.buyHoldCountLowerBound or 0)+1 end
        __slctx.HaloRun.invalidateHeldAccounting()
        final=__slctx.readBuy();r.buyQuote=final
        if completed then r.completionSeen=true end
    end
    if not succeeded then __slctx.pause('BUY_HOLD_STOPPED',tostring(failure));return true end
    if __slctx.live(epoch) and not hold.progressWhileDown then
        h.holdDisabled=true
        __slctx.log('BUY_HOLD_FALLBACK','no native repeat observed before mouse-up; reconciled first, ordinary clicks resume on next step')
    end
    __slctx.log('BUY_HOLD_RELEASED',tostring(stopReason)..'; observed progress='..tostring(observed)..'; purchase counts are lower bounds')
    return true
end
function __slctx.HaloRun.buy()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if r.endPurchased or r.completionSeen then __slctx.Strategy.phase('HALO','конец подтверждён');return end
    local ok,why=__slctx.ensureStrip();if not ok then if __slctx.live()then __slctx.pause('BUY_MENU_NOT_READY',tostring(why))end;return end
    local q,quoteReason=__slctx.readBuy()
    if __slctx.buyComplete()then
        r.completionSeen=true;__slctx.Strategy.phase('HALO','конец каталога подтверждён интерфейсом');return
    end
    if q and not q.cost and q.parseReason=='hidden_large' then
        -- The game's explicit hidden-price placeholder is not a loading error,
        -- a completed catalogue, or permission to substitute a predicted debit.
        r.buyQuote=q;h.wall={quote=q.id,at=__slctx.now(),hiddenPrice=true}
        if h.mode=='FINISH' then __slctx.HaloRun.cancelFinish('next real price is hidden; financing cannot be confirmed') end
        if __slctx.canUpgrade() then if r.pass and r.pass.finished then r.pass=nil end;__slctx.Strategy.phase('UPGRADE','цена скрыта игрой; усиливаю источники без выдуманной покупки')
        else __slctx.HaloRun.requestReview('BUY') end
        return
    end
    if not q or not q.cost then
        h.unknownSince=h.unknownSince or __slctx.now()
        if __slctx.CONFIG.DirectPurchases and __slctx.CONFIG.DirectUpgrades then
            local reason=tostring(quoteReason or 'BUY_PRICE_UNAVAILABLE')
            if h.buyUnavailableReason~=reason or __slctx.now()>=(h.nextBuyWarning or 0) then
                __slctx.log('BUY_DATA_WAIT',reason..'; available stand upgrades continue')
                h.nextBuyWarning=__slctx.now()+5
            end
            h.buyUnavailableReason=reason;r.buyQuote=nil;r.buildQuote=nil
            if h.mode=='FINISH' then __slctx.HaloRun.cancelFinish('BUY_DATA_UNAVAILABLE')end
            h.forecast=nil;h.economy=nil;h.requiredInvestors=nil
            __slctx.status('BUY_DATA_WAIT','Buy: '..reason..'; продолжаю доступные улучшения стендов.')
            if __slctx.canUpgrade() then
                if r.pass and r.pass.finished then r.pass=nil end
                __slctx.Strategy.phase('UPGRADE','данные Buy уточняются; стенды читаются независимо')
            else
                h.waitUntil=__slctx.now()+1;h.waitReturn='BUY';h.waitCost=nil
                __slctx.Strategy.phase('WAIT_GROWTH','ожидаю данные базы')
            end
            return
        end
        if __slctx.now()-h.unknownSince>__slctx.CONFIG.UIUnavailableTimeout then __slctx.pause('BUY_QUOTE_UNKNOWN','Цена BUY не прочитана: '..tostring(quoteReason or 'нет объекта покупки')..'. F7 — подробности.')end
        return
    end
    if h.buyUnavailableReason then
        __slctx.log('BUY_DATA_RECOVERED',q.name);h.buyUnavailableReason=nil;h.nextBuyWarning=nil;h.lastPlan=-math.huge
    end
    h.unknownSince=nil;r.buyQuote=q;__slctx.Strategy.observeBuildQuote(q);__slctx.HaloRun.observeQuote(q);__slctx.HaloRun.plan(false)
    local amount=__slctx.cash();if not amount then return end
    if h.mode=='FINISH' then
        local funded=h.remaining and __slctx.BN.cmp(amount,h.remaining.cost)>=0
        local healthy,issue=__slctx.HaloPlan.finishHealth(h.finish,__slctx.now(),funded and {funded=true} or nil,amount,q.cost,
            __slctx.HaloRun.income(),__slctx.CONFIG)
        if not healthy then __slctx.HaloRun.cancelFinish(issue) end
    end
    if h.finishReviewPending and __slctx.S.resetEnabled and (__slctx.CONFIG.AutoRebirth or __slctx.CONFIG.AutoEvolution) and not isPending() then
        __slctx.HaloRun.requestReview('BUY');return
    end
    if h.mode~='FINISH' and not __slctx.Planner.isTerminalName(q.name) then
        if __slctx.HaloRun.reviewDue(q)then __slctx.HaloRun.requestReview('BUY');return end
        if __slctx.Strategy.maybeFastBuild()then return end
    end
    if __slctx.BN.cmp(amount,q.cost)>=0 then
        if not q.available then
            h.lockedAt=h.lockedAt or __slctx.now()
            __slctx.status('BUY_FUNDED_WAIT_UI','Деньги есть, ожидаю доступную кнопку '..q.name)
            if __slctx.now()-h.lockedAt>__slctx.CONFIG.UIUnavailableTimeout then __slctx.pause('BUY_FUNDED_BUT_LOCKED',q.name..'; цена доступна, кнопка не разблокировалась')end
            return
        end
        h.lockedAt=nil
        __slctx.status(h.mode=='FINISH' and 'FINISH_BUY' or 'PREPARE_BUY',h.mode..' · '..q.name..' · остаток каталога '..tostring(h.remaining and h.remaining.count or '?'))
        if __slctx.HaloRun.tryBuyHold(q) then return end
        __slctx.Strategy.safePurchase(q)
        if next(r.blocked or {}) then
            __slctx.Strategy.reconcileBlocked()
            if next(r.blocked or {}) then __slctx.Strategy.stopForBlocked() end
        end
        return
    end
    if h.mode=='FINISH' then
        h.waitUntil=__slctx.now()+.25;h.waitReturn='BUY';h.waitCost=q.cost;h.waitId=q.id
        __slctx.status('FINISH_ACCUMULATE','FINISH · накопление на '..q.name..'; проверяю оставшийся бюджет времени')
        __slctx.Strategy.phase('WAIT_GROWTH','накопление в рамках финального бюджета');return
    end
    if not h.wall or h.wall.quote~=q.id then h.wall={quote=q.id,at=__slctx.now()} end
    if r.pass and r.pass.finished then r.pass=nil end
    if __slctx.canUpgrade() then __slctx.Strategy.phase('UPGRADE','PREPARE: оцениваю усиление базы перед следующим решением')
    else __slctx.HaloRun.requestReview('BUY')end
end

function __slctx.HaloRun.checkpoint()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if not r.pass or not r.pass.complete then __slctx.Strategy.phase('UPGRADE','заканчиваю текущий проход');return end
    if __slctx.Strategy.stopForBlocked()then return end
    if h.buyUnavailableReason then
        h.waitUntil=__slctx.now()+((r.pass.purchases or 0)>0 and .1 or 1)
        h.waitReturn='BUY';h.waitCost=nil
        __slctx.Strategy.phase('WAIT_GROWTH','проход стендов завершён; повторное чтение Buy');return
    end
    __slctx.HaloRun.plan(true)
    if h.mode=='FINISH'then __slctx.Strategy.phase('BUY','FINISH: бюджет сохранён для каталога');return end
    local p=r.pass
    local noNewWork=(p.purchases or 0)==0 and __slctx.S.counts.upgrade==(h.upgradesAtReview or -1)
        and (r.runBuyCount or 0)==(h.buysAtReview or -1)
    local reviewedAt=h.lastReview or 0
    local reviewAt=math.max(h.nextReview or 0,reviewedAt+__slctx.CONFIG.PreparationReviewMinimumSeconds)
    if noNewWork and not h.progressReviewHint then
        reviewAt=math.max(reviewAt,reviewedAt+__slctx.CONFIG.PreparationNoChangeBackoffSeconds)
    end
    if __slctx.now()<reviewAt then
        if __slctx.CONFIG.DirectUpgrades and (p.purchases or 0)>0 then
            __slctx.Strategy.phase('BUY','прямой проход подтверждён; следующая покупка без задержки меню');return
        end
        h.waitUntil=math.min(reviewAt,__slctx.now()+__slctx.CONFIG.PreparationIdleObservationSeconds)
        -- Keep the open Manage menu while an empty pass waits for income. A
        -- newly funded real BUY quote wakes this wait and is refreshed before input.
        h.waitReturn=noNewWork and 'UPGRADE' or 'BUY'
        h.waitCost=r.buyQuote and r.buyQuote.cost;h.waitId=r.buyQuote and r.buyQuote.id
        __slctx.Strategy.phase('WAIT_GROWTH','нет новых операций; пропускаю повторный обход меню');return
    end
    __slctx.HaloRun.requestReview('BUY')
end

function __slctx.HaloRun.wait()
    local h=__slctx.HaloRun.state();local amount=__slctx.cash()
    local funded=h.waitCost and amount and __slctx.BN.cmp(amount,h.waitCost)>=0
    if __slctx.now()>=(h.waitUntil or 0) or funded then
        h.waitCost=nil;h.waitId=nil
        __slctx.Strategy.phase(funded and 'BUY' or h.waitReturn or 'BUY',h.mode..': продолжаю выбранный маршрут')
    else __slctx.status('WAIT_INCOME','Жду поступление денег; Powers и инвесторы не перебираются') end
end
-- Legacy periodic economic reviews are not part of 3.0's scheduler.
function __slctx.Strategy.maybeBuyReview()return false end
function __slctx.Strategy.maybeCapabilityReview(cards)
    if __slctx.HaloRun.state().buyUnavailableReason then return false end
    if __slctx.HaloRun.reviewDue(__slctx.Strategy.route().buyQuote)then __slctx.HaloRun.requestReview('UPGRADE');return true end
    return false
end
function __slctx.Strategy.checkpoint()return __slctx.HaloRun.checkpoint()end
function __slctx.Strategy.capabilityReview()return __slctx.HaloRun.review()end
function __slctx.Strategy.growBuy()return __slctx.HaloRun.buy()end
function __slctx.Strategy.waitGrowth()return __slctx.HaloRun.wait()end
function __slctx.Strategy.maybeObjectiveReview()return false end
local previousValidate=__slctx.Strategy.validateResetIntent
function __slctx.Strategy.validateResetIntent(inv)
    if __slctx.GoalDirector and __slctx.GoalDirector.finish()then
        __slctx.Strategy.cancelResetIntent('FINISH_CASH_FUNDED');return false,'FINISH_CASH_FUNDED'
    end
    if __slctx.HaloRun.state().mode=='FINISH'then __slctx.Strategy.cancelResetIntent('FINISH_ROUTE_LOCKED');return false,'FINISH_ROUTE_LOCKED'end
    return previousValidate(inv)
end
function __slctx.HaloRun.objectiveWatch()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if h.mode=='FINISH' or not __slctx.CONFIG.AutoEvolution or not __slctx.S.resetEnabled or not r.evo then return false end
    if __slctx.now()<(r.evolutionReserveRetryAt or 0)or isPending()then return false end
    local nextBuy=__slctx.readBuy();local amount=__slctx.cash()
    if nextBuy and __slctx.Planner.isTerminalName(nextBuy.name) and nextBuy.cost and amount and __slctx.BN.cmp(amount,nextBuy.cost)>=0 then return false end
    local growthPhase=({BUY=true,UPGRADE=true,REBUILD=true,WAIT_GROWTH=true,WAIT_CASH=true,CHECKPOINT=true})[r.phase]
    if r.evo.ready and growthPhase and __slctx.now()>=(h.nextEvolutionReview or 0) then
        h.nextEvolutionReview=__slctx.now()+__slctx.CONFIG.EvolutionDecisionSeconds
        __slctx.HaloRun.plan(false)
        if not __slctx.HaloRun.deferEvolution(false) then
            __slctx.log('EVOLUTION_REVIEW_DUE','ready; no bounded final route; local purchases do not postpone review')
            __slctx.HaloRun.requestReview(r.phase);return true
        end
    end
    local direct=__slctx.CONFIG.DirectPrestige and __slctx.DirectPrestige
    local changed=direct and tostring(r.evo.pct) or __slctx.t(__slctx.paths.evolution..'/Body/Progress')
    local pct=direct and r.evo.pct or __slctx.Core.percent(changed)
    local near=pct and pct>=99.99 and changed~=h.lastObjectiveText
    h.lastObjectiveText=changed
    -- A low-frequency safety observation remains; it is NOT permission to rebirth.
    local watchdog=__slctx.now()-(r.lastEvolutionRead or __slctx.now())>=__slctx.CONFIG.CatalogueObjectiveWatchdogSeconds
    if (near or watchdog)and ({BUY=true,UPGRADE=true,REBUILD=true,WAIT_GROWTH=true,WAIT_CASH=true})[r.phase]then
        h.objectiveReturn=r.phase;__slctx.Strategy.phase('OBJECTIVE','проверка этапа по изменению прогресса/контрольному сроку');return true
    end
    return false
end
function __slctx.HaloRun.objective()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state();local dest=h.objectiveReturn or 'BUY'
    local evo=__slctx.Strategy.readEvolution();if not evo then if __slctx.live()then __slctx.pause('EVOLUTION_READ_FAILED','Не удалось прочитать этап.')end;return end
    __slctx.HaloRun.plan(true)
    if h.mode=='FINISH' then __slctx.Strategy.phase('BUY','FINISH защищён от промежуточной эволюции')
    elseif evo.ready then __slctx.HaloRun.requestReview(dest)
    else __slctx.Strategy.phase(dest,'возвращаюсь к прежнему действию')end
end


function __slctx.HaloRun.progress()
    local h=__slctx.HaloRun.state();local r=__slctx.Strategy.route();local f=h.forecast;local v=h.economy
    local audit=__slctx.HaloPlan.progressView(h.book,__slctx.HaloCatalogue,h.remaining,__slctx.cash(),f and f.rate,
        __slctx.CONFIG.FinishMaximumWaitSeconds,r.endPurchased or r.completionSeen)
    audit.economy=v
    local halo=h.book.halo
    local heading='Halo '..tostring(halo or '?')..' → '..tostring(halo and halo+1 or '?')..' · E'..tostring(r.evo and r.evo.index or '?')..' · '..h.mode
    local goal=r.goalDecision;local goalDetail=goal and goal.detail
    local names={EVOLVE_READY='перейти к следующей эволюции',REBIRTH_TO_EVOLUTION='rebirth для быстрой эволюции',
        GROW_TO_EVOLUTION='набрать следующую эволюцию',FINISH_CASH_FUNDED='завершить Halo',FINISH_ATTEMPT='проверить короткий финал',
        REPEAT_READY_REBIRTH='повторять rebirth без стройки',WAIT_REBIRTH_REWARD='ждать награду rebirth без стройки',REBIRTH_DATA_WAIT='дождаться данных rebirth'}
    if goal and names[goal.choice] then heading=heading..'\nЦель: '..names[goal.choice]end
    if h.resetInFlight or (__slctx.S.resetSession and __slctx.S.resetSession.isReset) then
        return heading..'\nСброс выполняется — предыдущий прогноз приостановлен.\n'..tostring(__slctx.S.status),0,
            'Жду подтверждённое новое состояние; старый доход не используется.',audit
    end
    if r.endPurchased or r.completionSeen then return heading..'\nThe End куплен. Проверяю Ascend.',1,'Финальный сброс, не промежуточный rebirth.',audit end
    if h.goalFinish then
        return heading..'\nДеньги покрывают '..tostring(h.goalFinish.count)..' оставшихся покупок.',1,
            'Стоимость проверена по состоянию базы; резерв сохраняется до финала.',audit
    end
    if __slctx.GoalDirector and __slctx.GoalDirector.repeating() and h.mode~='FINISH' and not h.repeatFinishAttempt then
        return heading..'\nПовторные rebirth без прокачки базы.',0,
            'Готовая эволюция — сразу. Награда rebirth: '..__slctx.BN.format(r.latestInvestors and r.latestInvestors.reward)
                ..'. Каждый сброс ждёт подтверждения.',audit
    end
    if not v or not v.known then return heading..'\nСчитываю фактический доход и цены; покупки продолжаются.',0,'Прогноз ещё не подтверждён; это не доля времени.',audit end
    local current=__slctx.BN.format(v.currentRate);local required=__slctx.BN.format(v.requiredRate)
    local mode=v.levelProjection and 'с расчётной платной прокачкой и бонусами' or (v.routeScenario and 'с оставшимися бонусами базы' or 'без ещё не подтверждённых бонусов')
    local gap=v.factor and ('Нужно усиление ×'..__slctx.BN.format(v.factor)) or 'доход уточняется'
    if h.mode=='FINISH' then gap='Остаток обеспечен по проверяемому бюджету; пересчитываю по ходу.'
    elseif v.scenarioReady then gap='С будущими бонусами финал возможен; порядок открытия не подтверждён.' end
    local trial=h.evolutionFinishTrial
    if h.mode~='FINISH' and trial and not trial.invalidated and __slctx.now()<trial.deadline then
        gap=(trial.negative and 'Перепроверяю прогноз; ' or 'Проверяю возможность завершения; ')
            ..'база продолжает развиваться, эволюция отложена.'
    end
    local text=heading..'\nДоход/с '..current..' → ≈ '..required..' ('..mode..')\n'..gap
    local bar=v.logFraction or v.fraction or 0
    if h.mode~='FINISH' then bar=math.min(.999,bar) end
    audit.lowerBound=not h.book.complete
    local bonus=v.factors and v.factors.bonus or __slctx.CONFIG.ExpectedInvestorBonus
    local details=(v.routeScenario and 'Сценарий с будущими бонусами (log): ' or 'Шкала силы (log): ')..string.format('%.1f%%',bar*100)
        ..' · доход уже включает x'..__slctx.CONFIG.ExpectedTimeMultiplier..' и текущие бонусы'
    if goalDetail and __slctx.GoalDirector and __slctx.GoalDirector.ownsRebirth() then
        details=details..'\nДо эволюции: сейчас ≈ '..__slctx.HaloRun.formatDuration((goalDetail.direct<math.huge and __slctx.BN.new(goalDetail.direct) or nil))
            ..'; через rebirth ≈ '..__slctx.HaloRun.formatDuration((goalDetail.reset<math.huge and __slctx.BN.new(goalDetail.reset) or nil))
            ..'. Оценка по наблюдаемому доходу.'
    elseif v.rebirth then
        details=details..'\nПосле rebirth и восстановления: '..__slctx.BN.format(v.rebirth.currentRate)..'/с'
            ..(v.rebirth.ready and ' — остаток обеспечен в модели восстановленной базы'
                or v.rebirth.scenarioReady and ' — финал возможен только в сценарии будущих бонусов' or ' — подготовка ещё нужна')
    end
    if v.evolutionStartBank then
        details=details..'\nE'..tostring(v.nextEvolution)..': старт '..__slctx.BN.format(v.evolutionStartBank)..' инвесторов; банк пересчитывается, не сохраняется.'
    end
    audit.logScale=true;audit.rawFundingFraction=v.fraction
    return text,math.max(0,math.min(1,bar)),details,audit
end
function __slctx.HaloRun.formatDuration(value)
    if not value then return 'не определена' end
    local n=__slctx.BN.number(value)
    if not n or n~=n or n==math.huge or n>86400*365 then return 'больше года; нужна подготовка' end
    if n<60 then return string.format('%.1f с',n) end
    if n<3600 then return string.format('%d мин %d с',math.floor(n/60),math.floor(n%60)) end
    if n<86400 then return string.format('%d ч %d мин',math.floor(n/3600),math.floor(n%3600/60)) end
    return string.format('%.1f дн',n/86400)
end

function __slctx.HaloRun.step()
    if not __slctx.live()then return end
    local direct=__slctx.CONFIG.DirectUpgrades and __slctx.CONFIG.DirectPurchases and __slctx.CONFIG.DirectPrestige
    if not direct and not __slctx.Focus.await()then return end
    if isPending()then return end
    local notice=__slctx.ResetConfirm.staircaseNotice();if notice then __slctx.ResetConfirm.dismissNotice(notice);return end
    __slctx.Strategy.sampleIncome();__slctx.HaloRun.peekProgress();__slctx.Strategy.diagnosticSample()
    local r=__slctx.Strategy.route();local h=__slctx.HaloRun.state()
    if r.endPurchased or r.completionSeen then __slctx.Strategy.phase('HALO','The End подтверждён; проверяю Ascend')end
    if __slctx.GoalDirector and __slctx.GoalDirector.tick(false) then return end
    if not (r.endPurchased or r.completionSeen) and __slctx.HaloRun.objectiveWatch()then return end
    if r.phase=='BOOT'then __slctx.HaloRun.boot()
    elseif r.phase=='BUY'then __slctx.HaloRun.buy()
    elseif r.phase=='UPGRADE'then
        __slctx.HaloRun.plan(false)
        if h.mode=='FINISH'then __slctx.Strategy.phase('BUY','FINISH: бюджет сохранён для полного каталога')else __slctx.Strategy.growUpgrades()end
    elseif r.phase=='CHECKPOINT'then __slctx.HaloRun.checkpoint()
    elseif r.phase=='CAPABILITY'then __slctx.HaloRun.review()
    elseif r.phase=='POWERS'then
        if h.mode=='FINISH'then __slctx.Strategy.phase('BUY','FINISH: необязательные траты выключены')else __slctx.HaloRun.powers()end
    elseif r.phase=='REBUILD'then __slctx.Strategy.fastBuild()
    elseif r.phase=='BOOST'then __slctx.Strategy.buyBreakthrough()
    elseif r.phase=='OBJECTIVE'then __slctx.HaloRun.objective()
    elseif r.phase=='EVOLVE_RESERVE'then
        if h.mode=='FINISH'then __slctx.Strategy.phase('BUY','FINISH: эволюция отложена')else __slctx.Strategy.reserveEvolution()end
    elseif r.phase=='HALO'then __slctx.Strategy.halo()
    elseif r.phase=='REBIRTH_LOOP'then
        if not (__slctx.GoalDirector and __slctx.GoalDirector.repeating())then __slctx.Strategy.phase('BOOT','режим повторных rebirth выключен')end
    elseif r.phase=='WAIT_GROWTH'then __slctx.HaloRun.wait()
    elseif r.phase=='WAIT_CASH'then __slctx.Strategy.waitCash()
    else __slctx.Strategy.phase('BUY','перехожу в новый контроллер PREPARE/FINISH')end
end
end
-- HALO_RUNTIME_30_END

function __slctx.step() return __slctx.HaloRun.step() end


end
