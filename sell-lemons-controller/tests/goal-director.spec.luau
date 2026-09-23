local function fixture()
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c);c.BN=c.Core.BN
    require('../src/core/HaloPlanner')(c);require('../src/core/EconomyPlanner')(c)
    local B=c.BN;local state={time=100,reads=0,resets=0,oldWork=0,ready=true,bonus=10}
    local r={phase='BOOT',evo={index=0},previousHalo=77,previousEvolution=0,blocked={},cards={},recovery={unfinished=true}}
    c.S={resetEnabled=true,counts={upgrade=0}}
    c.HaloCatalogue={};c.now=function()return state.time end;c.live=function()return true end
    c.cash=function()return B.new(100)end;c.log=function()end;c.status=function()end
    c.readBuy=function()return {id='cheap',cost=B.new(1),available=true,name='Walls'}end
    c.readEvolution=function()state.reads=state.reads+1;return {index=0,ready=state.ready,bonus=B.new(state.bonus),
        fresh=true,bonusVisible=true,bonusIsInvestors=true}end
    c.DirectPrestige={};c.DirectPurchases={remaining=function()return state.remaining end}
    c.doReset=function(k)assert(k=='evolve');state.resets=state.resets+1;return true end
    c.ResetConfirm={dismissStale=function()return true end}
    c.Strategy={route=function()return r end,rate=function()return B.new(10),'test','ui'end,
        phase=function(p)r.phase=p end,cancelResetIntent=function()end,
        validateResetIntent=function()return true end,receipt=function()end,afterReset=function()end,
        effectiveActionSeconds=function()return .1 end,
        readEvolution=c.readEvolution,readHalo=function()return {amount=77}end,
        resumeGrowth=function()r.phase='BUY'end}
    c.ensureTablet=function()state.oldWork=state.oldWork+1;error('tablet preparation ran before ready evolution')end
    c.canUpgrade=function()state.oldWork=state.oldWork+1;error('stand preparation ran before ready evolution')end
    require('../src/strategy/Growth')(c)
    require('../src/strategy/HaloController')(c)
    require('../src/strategy/GoalDirector')(c)
    c.HaloRun.plan=function()end
    return c,state,r,B
end
-- Actual BOOT entry must choose evolution before tablet/powers/stands, even with
-- an unfinished recovery and a funded local Buy. Default bonus threshold is zero.
for _,bonus in ipairs({0,10,264})do
    local c,s,r=fixture();s.bonus=bonus;r.bootTablet=true
    c.HaloRun.boot()
    assert(s.resets==1 and s.oldWork==0 and r.phase=='EVOLVE_RESERVE')
end
print('PASS actual BOOT skips tablet/powers/base and evolves with bonuses below 400 during recovery')
for _,phase in ipairs({'BUY','UPGRADE','REBUILD','POWERS','BOOST','CAPABILITY','WAIT_CASH','WAIT_GROWTH'})do
    local c,s,r=fixture();r.phase=phase
    assert(c.GoalDirector.tick(false) and s.resets==1)
end
print('PASS ready objective interrupts every growth phase independently of full-pass/review timers')
for _,pending in ipairs({'actionPending','resetSession','resetChildPending','buyHold'})do
    local c,s,r=fixture();r.phase='BUY';c.S[pending]={}
    assert(not c.GoalDirector.tick(false) and s.resets==0 and s.reads==0)
end
for _,key in ipairs({'powerUnresolved','blocked'})do
    local c,s,r=fixture();r.phase='BUY';r[key]={entry=true}
    assert(not c.GoalDirector.tick(false) and s.resets==0)
end
do
    local c,s,r=fixture();r.phase='BUY';c.S.resetEnabled=false
    assert(not c.GoalDirector.tick(false) and s.resets==0)
end
print('PASS pending operations, unresolved receipts and disabled resets cannot be bypassed')
do
    local c,s,r,B=fixture();s.remaining={count=440,cost=B.new(50),cash=B.new(100)}
    assert(c.GoalDirector.tick(true) and r.phase=='BUY' and s.resets==0)
    local hold,why=c.HaloRun.deferEvolution(true);assert(hold and why=='FINISH_CASH_FUNDED')
    s.time=s.time+1;s.remaining.count=0
    c.GoalDirector.tick(false);assert(r.phase=='HALO' and r.completionSeen and s.resets==0)
end
do
    local c,s,r=fixture();c.HaloRun.state().mode='FINISH';r.phase='BUY'
    assert(not c.GoalDirector.tick(false) and s.resets==0)
end
do
    local c,s,r=fixture();r.phase='BUY';c.readEvolution=function()return nil end
    assert(not c.GoalDirector.tick(false) and r.phase=='BUY' and s.resets==0)
end
print('PASS funded full remainder/confirmed finish outrank evolution; missing data leaves ordinary work runnable')
do
    local c,s,r,B=fixture();s.ready=false;r.cleanRun=true;r.runObservedAt=99
    c.DirectUpgrades={cards=function()return {{income=B.new(1000),periodSeconds=1}}end}
    local data={snapshot={epoch={Evolution=3}}};local inv={investors=B.new(100),perInvestor=.08}
    local rate,trace=c.GoalDirector.observe(data,inv)
    assert(rate and trace.complete and trace.epoch==3 and trace.kind=='direct-goal')
    assert(trace.points[1].age==1,'bootstrap work must be charged')
    -- Cash estimator switching and r.evo=nil before BOOT cannot trap this trace.
    r.evo=nil;c.Strategy.rate=function()return B.new(9999),'flow','flow'end
    s.time=s.time+1;c.GoalDirector.observe(data,inv)
    assert(#trace.points==2 and trace.points[2].rate.e==3)
    r.cleanRun=false;c.GoalDirector.observe(data,inv);assert(trace.invalid)
end
do
    local c,s,r=fixture();s.ready=false;r.phase='BUY'
    c.GoalDirector.forecast=function()return {worth=true}end
    assert(c.GoalDirector.validate({}))
    s.ready=true;assert(not c.GoalDirector.validate({}))
    s.ready=false;c.GoalDirector.forecast=function()return {worth=false}end
    assert(not c.GoalDirector.validate({}),'a formerly profitable shortcut must be reevaluated before sending')
end
print('PASS direct prefix survives estimator switching, invalidates partial cycles, and fresh execution comparison cancels obsolete resets')
