local function fixture()
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c)
    require('../src/core/HaloPlanner')(c);require('../src/core/EconomyPlanner')(c)
    local B=c.Core.BN;c.BN=B
    local state={time=100,money=B.new(1),rate=B.new(1),logs={},resets=0}
    c.CONFIG.CatalogueCostMargin=0
    c.HaloCatalogue={{id=1,name='Future global',cost=B.new(1),info='10x Global cash'},
        {id=2,name='The End',cost=B.new(40),info=''}}
    local r={previousHalo=0,cards={},blocked={},economicRevision=0,phase='BUY'}
    c.S={counts={upgrade=0},resetEnabled=true}
    c.buyComplete=function()return false end
    c.canUpgrade=function()return c.S.tablet and c.S.tablet.owned end
    c.now=function()return state.time end;c.cash=function()return state.money end
    c.log=function(code,message)state.logs[#state.logs+1]={code,message}end
    c.Strategy={route=function()return r end,rate=function()return state.rate end,
        effectiveActionSeconds=function()return .1 end,largestBatch=function()return 1 end,
        cancelResetIntent=function()end,phase=function(p)r.phase=p end,
        receipt=function()end,afterReset=function()end,validateResetIntent=function()return true end,
        maybeFastBuild=function()return false end,observeBuildQuote=function()end}
    c.doReset=function()state.resets=state.resets+1 end
    require('../src/strategy/HaloController')(c)
    local h=c.HaloRun.state();h.book.complete=true
    h.book.model={a=0,b=1,error=0,xmin=0,xmax=100,slopeAllowance=0,samples=5}
    return c,state,r,h,B
end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS '..name)end
test('price-order x10 scenario cannot override disabled conditional finish',function()
    local c,s,r,h,B=fixture();local f=c.HaloRun.plan(true)
    assert(B.number(f.roll.wait)<8 and B.number(f.bound.wait)>50,'scenario must reproduce conflicting forecasts')
    assert(h.mode=='PREPARE','optimistic scenario must not lock rebirth/evolution')
    assert(not h.economy.ready and h.economy.scenarioReady,'display must distinguish prediction from financing')
end)
test('x10 is paid before taking effect; an expensive prerequisite changes the result',function()
    local c,s,r,h,B=fixture()
    local boost={id=1,cost=B.new(1),effect={global=true,mult=10}}
    local gate={id=2,cost=B.new(40)}
    local model={other=B.new(1),sources={}}
    local optimistic=c.HaloPlan.roll({rows={boost,gate}},B.new(0),model,0,true)
    local actual=c.HaloPlan.roll({rows={gate,boost}},B.new(0),model,0,true)
    assert(math.abs(B.number(optimistic.wait)-5)<.001,'first boost costs one second at the old rate')
    assert(math.abs(B.number(actual.wait)-41)<.001,'unreachable x10 cannot finance its prerequisite')
    assert(B.number(optimistic.rate)==10 and B.number(actual.rate)==10)
end)
test('fully funded route finishes without an income observation',function()
    local c,s,r,h,B=fixture();s.money=B.new(100);s.rate=nil
    c.HaloRun.plan(true);assert(h.mode=='FINISH' and h.finish.reason=='FINISH_CASH_FUNDED')
end)
test('observed expensive gate precedes a cheaper but still locked global bonus',function()
    local c,s,r,h,B=fixture()
    r.buyQuote={id='live-gate',name='The End',cost=B.new(40)}
    h.quoteId=r.buyQuote.id;h.quotedRow=c.HaloCatalogue[2]
    local f=c.HaloRun.plan(true)
    assert(f.routeRemaining.rows[1].id==2 and B.number(f.roll.wait)>50)
    assert(not h.economy.scenarioReady and h.mode=='PREPARE')
    assert(f.remaining.rows[1].id==1,'scenario must not mutate price ledger or order evidence')
end)
test('stale finish is revoked when newly observed income disproves the budget',function()
    local c,s,r,h,B=fixture();s.rate=B.new(10);c.HaloRun.plan(true)
    assert(h.mode=='FINISH');s.rate=B.new(1);s.time=s.time+1
    c.HaloRun.plan(true)
    assert(h.mode=='PREPARE' and h.finishReviewPending and s.resets==0)
    c.HaloRun.plan(true);assert(h.mode=='PREPARE','same forecast must not immediately reacquire the lock')
end)
test('a receipt cannot renew the original route deadline',function()
    local c,s,r,h,B=fixture();s.rate=B.new(10);c.HaloRun.plan(true)
    local deadline=h.finish.deadline;assert(deadline and deadline>s.time)
    s.time=deadline-.1
    c.HaloRun.observeReceipt({kind='buy',id=1,name='Future global',cost=B.new(1)})
    assert(h.finish.deadline==deadline)
    c.HaloRun.plan(true);assert(h.mode=='PREPARE' and h.finishReviewPending)
end)
test('known huge tail opens a comparison immediately and retains the upgrade pass',function()
    local c,s,r,h,B=fixture();s.money=B.new(41);c.HaloRun.plan(true)
    s.money=B.new(0);s.rate=B.new(1);s.time=s.time+.1
    local pass={id='retained',finished=false};r.pass=pass
    c.ensureStrip=function()return true end;c.paths={buy='Buy'};c.t=function()return '' end
    c.readBuy=function()return {id=2,name='The End',cost=B.new(40),available=true}end
    c.status=function()end
    c.HaloRun.buy()
    assert(h.mode=='PREPARE' and r.phase=='CAPABILITY','actual next price must be checked even between plan ticks')
    assert(r.pass==pass and s.resets==0,'review is not authorization for a reset')
end)
test('funding all remaining purchases releases a rejected forecast without a needless reset',function()
    local c,s,r,h,B=fixture();h.finishReviewPending=true;s.money=B.new(100)
    c.HaloRun.plan(true);assert(h.mode=='FINISH' and not h.finishReviewPending and s.resets==0)
end)
test('uncertain rebirth scenario does not suppress a ready evolution',function()
    local c,s,r,h,B=fixture();c.HaloRun.plan(true)
    h.economy.scenarioReady=false;h.economy.rebirth={ready=false,scenarioReady=true}
    assert(c.HaloRun.routeEvolutionChoice({}, {ready=true,index=5},nil,true,{})=='EVOLVE')
end)
test('ready evolution does not interrupt funded construction after rebirth',function()
    local c,s,r,h,B=fixture()
    s.money=B.new(1,120);s.rate=B.new(1,119)
    local q={id='Walls',name='Walls',cost=B.new(6.913,59),available=true}
    c.readBuy=function()return q end
    r.evo={ready=true,index=6};r.runBuyCount=56;r.spent=B.new(0)
    r.frontierRecovery={completePrefix=true,frontierBuys=380,frontierDone=false}
    assert(c.HaloRun.routeEvolutionChoice({},r.evo,nil,false,{})=='CONTINUE')
    c.Strategy.refreshResetBuy=function()r.buyQuote=q;return true end
    c.HaloRun.observeQuote=function()end;c.HaloRun.plan=function()end
    c.HaloRun.checkedInvestors=function()return {investors=B.new(1,120),reward=B.new(1,121),ready=true,perInvestor=.08}end
    c.Planner.shouldInspectEvolution=function()return false end
    c.HaloRun.review()
    assert(r.phase=='BUY' and s.resets==0,'live ready-E/rebuilding/funded-Buy trigger must keep the current base')
end)
test('near Buy waits once; minor upgrades and rereads cannot extend the deadline',function()
    local c,s,r,h,B=fixture();s.money=B.new(0);s.rate=B.new(1)
    c.readBuy=function()return {id='last-gate',cost=B.new(4*c.CONFIG.CatalogueIncomeMargin),available=false}end
    assert(c.HaloRun.deferEvolution(false))
    local deadline=h.evolutionBuyGate.deadline;s.time=deadline+1
    s.rate=B.new(1e6);c.S.counts.upgrade=1000
    assert(not c.HaloRun.deferEvolution(false) and h.evolutionBuyGate.deadline==deadline)
    assert(c.HaloRun.routeEvolutionChoice({}, {ready=true,index=6},nil,false,{})=='EVOLVE')
end)
test('current finish scenario earns a bounded attempt rather than immediate evolution or a permanent finish claim',function()
    local c,s,r,h,B=fixture();s.money=B.new(0);s.rate=B.new(1)
    c.readBuy=function()return {id='expensive-gate',cost=B.new(1000),available=false}end
    h.economy={scenarioReady=true,certifiable=true,catalogueRoute={time=B.new(12)}}
    assert(c.HaloRun.routeEvolutionChoice({}, {ready=true,index=6},nil,false,{})=='CONTINUE')
    assert(h.mode=='PREPARE')
    local deadline=h.evolutionFinishTrial.deadline;s.time=deadline+1;c.S.counts.upgrade=500
    assert(not c.HaloRun.deferEvolution(false) and h.evolutionFinishTrial.deadline==deadline)
    assert(c.HaloRun.routeEvolutionChoice({}, {ready=true,index=6},nil,false,{})=='EVOLVE')
end)
test('funded final route and completed base always precede evolution; passive rebirth proof needs no hypothetical boosts',function()
    local c,s,r,h,B=fixture();s.money=B.new(100);c.HaloRun.plan(true)
    assert(c.HaloRun.deferEvolution(false) and h.mode=='FINISH')
    h.mode='PREPARE';r.endPurchased=true
    local hold,why=c.HaloRun.deferEvolution(false);assert(hold and why=='HALO_COMPLETION_TAKES_PRIORITY')
    r.endPurchased=false;s.money=B.new(0);s.rate=B.new(1)
    c.readBuy=function()return {id='wall',cost=B.new(1,100),available=false}end
    h.economy={rebirth={ready=true},levelProjection=false}
    local detail={};assert(c.HaloRun.routeEvolutionChoice({}, {ready=true,index=6},nil,true,detail)=='REBIRTH')
    assert(detail.finishAfterReset and detail.comparedEvolution)
end)
test('successful direct pass continues immediately; empty pass still waits and overdue review wins',function()
    local c,s,r,h=fixture();c.Strategy.stopForBlocked=function()return false end
    c.HaloRun.plan=function()end;h.lastReview=s.time;h.nextReview=s.time+10
    r.pass={complete=true,finished=true,purchases=4};r.phase='CHECKPOINT'
    c.HaloRun.checkpoint();assert(r.phase=='BUY' and not h.waitUntil,'successful direct pass must not add the old 0.75 second GUI delay')
    r.pass.purchases=0;c.HaloRun.checkpoint();assert(r.phase=='WAIT_GROWTH' and h.waitUntil>s.time)
    r.pass.purchases=4;s.time=s.time+40;c.HaloRun.checkpoint();assert(r.phase=='CAPABILITY','speedup must preserve due economic reviews')
end)
test('missing Buy quote keeps available stands running and returns to Buy after a bounded wait',function()
    local c,s,r,h,B=fixture();local reason='BUY_NOT_REPLICATED_OR_ENABLED'
    c.ensureStrip=function()return true end;c.readBuy=function()return nil,reason end
    c.canUpgrade=function()return true end;c.status=function()end
    c.pause=function()error('a missing Buy quote must not pause independent stand upgrades')end
    c.Strategy.stopForBlocked=function()return false end
    r.buyQuote={id='old',cost=B.new(1)};r.pass={finished=true,complete=true,purchases=2}
    c.HaloRun.buy();assert(r.phase=='UPGRADE' and r.buyQuote==nil and r.pass==nil)
    assert(h.buyUnavailableReason==reason and s.resets==0)
    s.time=s.time+c.CONFIG.UIUnavailableTimeout+1;c.HaloRun.buy();assert(r.phase=='UPGRADE')
    assert(c.HaloRun.plan(true)==nil and h.mode=='PREPARE','missing frontier cannot certify FINISH')
    assert(not c.Strategy.maybeCapabilityReview({}),'no reset review inferred from a missing Buy quote')
    r.pass={finished=true,complete=true,purchases=2};c.HaloRun.checkpoint()
    assert(r.phase=='WAIT_GROWTH' and h.waitReturn=='BUY' and h.waitUntil>s.time)
    s.time=h.waitUntil;c.HaloRun.wait();assert(r.phase=='BUY')
    c.readBuy=function()return {id=2,name='The End',cost=B.new(40),available=true}end
    c.HaloRun.plan=function()end;c.HaloRun.observeQuote=function()end
    c.HaloRun.buy();assert(not h.buyUnavailableReason and r.buyQuote.id==2)
end)
test('H26 E2 report: distant Halo beats a near or funded local purchase, regardless of bonus size',function()
    local c,s,r,h,B=fixture()
    -- User report b11c59c6: 101 remaining, price model verified, complete ledger;
    -- current 2.646e142/s, required 7.056e228/s even with future catalogue boosts.
    s.rate=B.new(2.646,142);s.money=B.new(10^(.31586651036656),142)
    local q={id='LemonTourism',name='Lime Tourism',cost=B.new(1.495,143),available=false}
    c.readBuy=function()return q end
    h.economy={known=true,certifiable=true,completeLedger=true,ready=false,scenarioReady=false,
        currentRate=s.rate,requiredRate=B.new(7.056,228),catalogueRoute={time=B.new(1,86)},
        rebirth={ready=false,scenarioReady=false},levelProjection=false}
    h.remaining={cost=B.new(1.84,259),count=101,modelVerified=true,certifiable=true}
    r.evo={ready=true,index=2,bonus=B.new(2.582,6)};r.runBuyCount=355;r.spent=B.new(0)
    assert(c.Core.eta(s.money,q.cost,s.rate)<c.CONFIG.BuildShortWaitSeconds)
    local held,reason=c.HaloRun.deferEvolution(false)
    assert(not held and reason=='EVOLUTION_CURRENT_ROUTE_TOO_LONG','a near local BUY must not suppress ready evolution with a distant full route')
    -- Recreate money arriving while the evolution confirmation is open.
    s.money=B.new(1.5,143);q.available=true;c.S.resetSession={isReset=true}
    assert(not c.HaloRun.deferEvolution(true),'one newly funded purchase must not cancel the confirmation')
    c.S.resetSession=nil
    for _,bonus in ipairs({B.new(400),B.new(2.582,6),B.new(1,18)})do
        r.evo.bonus=bonus
        assert(c.HaloRun.routeEvolutionChoice({},r.evo,nil,false,{})=='EVOLVE','no fixed investor-bonus target')
    end
    c.Strategy.refreshResetBuy=function()r.buyQuote=q;return true end
    c.HaloRun.observeQuote=function()end;c.HaloRun.plan=function()end
    c.HaloRun.checkedInvestors=function()return {investors=B.new(4.435,36),reward=B.new(4.214,55),ready=true,perInvestor=.08}end
    c.Planner.shouldInspectEvolution=function()return false end
    c.HaloRun.powerGoal=function()return nil end
    c.HaloRun.resetForecast=function()return false,'BUILD_TARGET_SOON',1,{},{} end
    c.HaloRun.review()
    assert(r.phase=='EVOLVE_RESERVE' and s.resets==0,'review selects evolution; execution still requires the normal reset guards')
end)

test('unknown-route construction grace is shared across changing quotes and funded buys',function()
    local c,s,r,h,B=fixture();s.money=B.new(10)
    local q={id='cheap-1',name='A wall',cost=B.new(1),available=true}
    c.readBuy=function()return q end
    assert(c.HaloRun.deferEvolution(false))
    local deadline=h.evolutionBuyGate.deadline
    for i=2,30 do
        s.time=s.time+1;q.id='cheap-'..i;c.S.counts.upgrade=i*100
        local hold=c.HaloRun.deferEvolution(false)
        assert(h.evolutionBuyGate.deadline==deadline)
        assert(hold==(s.time<deadline),'new buys must not restart the construction grace')
    end
end)

test('a disproved scenario loses its trial immediately without renewal',function()
    local c,s,r,h,B=fixture();s.money=B.new(0)
    c.readBuy=function()return {id='gate',name='Gate',cost=B.new(1,90),available=false}end
    h.economy={scenarioReady=true,certifiable=true,catalogueRoute={time=B.new(12)}}
    assert(c.HaloRun.deferEvolution(false));local deadline=h.evolutionFinishTrial.deadline
    h.economy.known=true;h.economy.completeLedger=true;h.economy.scenarioReady=false
    assert(not c.HaloRun.deferEvolution(false) and s.time<deadline)
    h.economy.scenarioReady=true
    assert(not c.HaloRun.deferEvolution(false) and h.evolutionFinishTrial.deadline==deadline)
end)

test('full funding at final confirmation still cancels evolution despite a frozen pessimistic model',function()
    local c,s,r,h,B=fixture();c.S.resetSession={isReset=true}
    h.economy={known=true,certifiable=true,completeLedger=true,scenarioReady=false,catalogueRoute={}}
    h.remaining={cost=B.new(1.84,259),modelVerified=true,certifiable=true}
    c.readBuy=function()return {name='Local wall',cost=B.new(1,143),available=true}end
    s.money=B.new(2,259)
    local hold,why=c.HaloRun.deferEvolution(true);assert(hold and why=='FINISH_CASH_FUNDED')
    s.money=B.new(1,143)
    c.readBuy=function()return {name='The End',cost=B.new(1,143),available=true}end
    hold,why=c.HaloRun.deferEvolution(true);assert(hold and why=='FINAL_PURCHASE_FUNDED')
end)

test('ready evolution has its own scheduler even with zero work, recovery or rebirth disabled',function()
    local c,s,r,h,B=fixture();r.evo={ready=true,index=2};r.phase='WAIT_GROWTH';r.recovery={}
    c.CONFIG.AutoRebirth=false
    c.readBuy=function()return {id='wall',name='Local wall',cost=B.new(1,100),available=false}end
    c.t=function()return ''end;c.paths={evolution='Evolution'}
    c.HaloRun.plan=function()end
    h.lastReview=s.time;h.nextReview=s.time+12;h.upgradesAtReview=0;h.buysAtReview=0
    assert(c.HaloRun.objectiveWatch() and r.phase=='CAPABILITY')
    r.phase='WAIT_GROWTH'
    assert(not c.HaloRun.objectiveWatch(),'same review cannot run every frame')
    s.time=s.time+c.CONFIG.EvolutionDecisionSeconds
    c.S.actionPending=true;assert(not c.HaloRun.objectiveWatch(),'pending receipt always owns the action')
    c.S.actionPending=nil;assert(c.HaloRun.objectiveWatch())
    r.phase='WAIT_GROWTH';h.mode='FINISH';s.time=s.time+c.CONFIG.EvolutionDecisionSeconds
    assert(not c.HaloRun.objectiveWatch() and s.resets==0)
end)
print('PASS '..n..' forecast and scheduling regression groups')
