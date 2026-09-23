-- Reproduce H29/E1 from report 15055c7b: 135 weak passes, 83% evolution,
-- one nearby Public Citrus Works quote, and a 3.74e25 net rebirth gain.
local function fixture(stalled)
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c)
    require('../src/core/HaloPlanner')(c);require('../src/core/EconomyPlanner')(c)
    c.BN=c.Core.BN;local B=c.BN
    local s={time=594,money=B.new(1.146,84),rate=B.new(4.19,83),logs={},resets=0,buys=0,growth=.005}
    local q={id='directBuy:PublicCitrusWorks',name='Public Citrus Works',cost=B.new(1.557,84),
        info='',kind='buy',source='directBuy',available=false,observedAt=s.time}
    local inv={investors=B.new(42000),reward=B.new(1.58,30),perInvestor=.08,ready=true,time=s.time}
    local r={previousHalo=29,runBuyCount=215,spent=B.new(1000),blocked={},phase='CAPABILITY',
        evo={index=1,ready=false,pct=82.99},cards={},pass={id=555,finished=true,complete=true,purchases=0},
        target=B.new(1.995,31),timings={buy={ewma=.144},upgrade={ewma=.126},rebirth={ewma=.941}},
        runWork={},buildQuote=nil}
    for i,n in ipairs({1032,644,249,46,240,1415,1079})do r.cards[i]={source='direct',count=tostring(n),path='stand'..i}end
    c.S={counts={upgrade=3342},resetEnabled=true,epoch=1}
    c.HaloCatalogue={{id=1,name='The End',cost=B.new(6.795,260)}}
    c.Strategy={route=function()return r end,receipt=function()end,afterReset=function()end,
        validateResetIntent=function()return true end}
    c.now=function()return s.time end;c.cash=function()return s.money end;c.live=function()return true end
    c.log=function(k,v)s.logs[#s.logs+1]={k,v}end;c.status=function(k)s.status=k end
    c.readBuy=function()q.observedAt=s.time;return q end
    c.buyComplete=function()return false end;c.canUpgrade=function()return true end
    c.updateRate=function()end;c.paths={};c.t=function()return ''end
    c.doReset=function(kind)
        assert(kind=='rebirth')
        if s.beforeReset then s.beforeReset()end
        local allowed,why=c.Strategy.validateResetIntent(inv)
        if not allowed then s.denied=why;return false end
        s.resets=s.resets+1;return true
    end
    require('../src/strategy/Growth')(c);require('../src/strategy/ResetPlanning')(c)
    c.Strategy.phase=function(phase)r.phase=phase end
    c.Strategy.rate=function()return s.rate,'fixture','production'end
    c.Strategy.sampleIncome=function()end;c.Strategy.largestBatch=function()return 5 end
    c.Strategy.updatePowerGoal=function()return nil end;c.Strategy.powerWork=function()return {},'no pending work'end
    c.Strategy.effectiveActionSeconds=function()return .144 end
    c.Strategy.forwardGrowth=function()return s.growth,20 end
    c.Strategy.directGoalETA=function()return s.evoETA end
    c.Strategy.refreshResetBuy=function()r.buyQuote=c.readBuy();c.Strategy.observeBuildQuote(q);return true end
    require('../src/strategy/HaloController')(c)
    local h=c.HaloRun.state();h.wall={quote=q.id,at=510};h.returnPhase='BUY'
    h.remaining={cost=B.new(6.795,260),count=240}
    c.HaloRun.income=function()return s.rate end
    c.HaloRun.plan=function()return {rate=s.rate}end
    c.HaloRun.observeQuote=function()end
    c.HaloRun.checkedInvestors=function()inv.time=s.time;return inv end
    c.HaloRun.powerGoal=function()return nil end
    c.HaloRun.resume=function(phase)r.phase=phase end
    c.Planner.shouldInspectEvolution=function()return false end
    c.Strategy.refreshResetBuy()
    r.buildWall={key=c.Strategy.baseQuoteKey(q),serial=215,pass=555,weak=stalled and 135 or 1,
        started=stalled and 510 or s.time,finished=s.time}
    return c,s,r,h,q,inv,B
end
do
    local c,s,r,h,q,inv,B=fixture(true)
    local yes,why,_,detail=c.HaloRun.resetForecast(inv,nil)
    assert(yes and why=='RESET_REPAYS_STALLED_BUILD',tostring(why))
    assert(detail.outputComparison and detail.logAdvantage>0 and detail.horizon<math.huge)
    assert(r.savingsBudget and r.savingsBudget.deadline<=s.time,'existing wall age must not earn a fresh delay')
    c.HaloRun.review()
    assert(s.resets==1 and r.resetIntent and r.resetIntent.detail.outputComparison,'actual review must select and revalidate profitable rebirth')
end
print('PASS H29/E1 stalled Public Citrus Works selects bounded-output rebirth instead of permanent BUILD_TARGET_SOON')
do
    local c,s,r,h,q,inv,B=fixture(false)
    c.HaloRun.review()
    assert(s.resets==0 and r.phase=='WAIT_CASH' and r.goal,'near-buy decision must actually save rather than spend on stands')
    local deadline=r.goal.deadline
    for i=1,8 do
        s.time=s.time+1;r.pass.id=r.pass.id+1;r.buildWall.pass=r.pass.id
        c.Strategy.observeBuildQuote(c.readBuy());c.HaloRun.resetForecast(inv,nil)
        assert(r.savingsBudget.deadline==deadline,'new quotes and weak passes cannot renew the same deadline')
    end
    s.time=deadline;s.money=B.new(0);r.buildWall.weak=40
    c.Strategy.waitCash();assert(r.phase=='CHECKPOINT' and not r.goal)
    c.HaloRun.review();assert(s.resets==1,'expired reservation must release the economic comparison')
end
print('PASS a fresh nearby purchase gets one real saving phase, then an economic comparison without deadline renewal')
do
    local c,s,r,h,q,inv,B=fixture(false);c.HaloRun.review()
    local deadline=r.goal.deadline;s.time=deadline;s.money=q.cost;q.available=true
    c.focusCandidate=function()return q end;c.affordable=function()return true end
    c.Strategy.safePurchase=function(candidate)assert(candidate==q);s.buys=s.buys+1;return true end
    c.Strategy.waitCash();assert(s.buys==1 and s.resets==0 and r.phase=='BUY','funding on the deadline still buys first')
end
print('PASS a funded purchase wins at the exact saving deadline without a reset')
do
    for _,guard in ipairs({'funded','recovery','near-evolution','strong-growth'})do
        local c,s,r,h,q,inv,B=fixture(true)
        if guard=='funded'then s.money=q.cost
        elseif guard=='recovery'then r.recovery={}
        elseif guard=='near-evolution'then s.evoETA=1
        else s.growth=10 end
        local yes=c.HaloRun.resetForecast(inv,nil)
        assert(not yes,guard..' must not become a timer-only reset')
    end
    local c,s,r,h,q,inv,B=fixture(true);h.mode='FINISH'
    assert(not c.HaloRun.resetForecast(inv,nil))
    local c,s,r,h,q,inv,B=fixture(true);r.buildWall.key='different quote'
    assert(not c.HaloRun.resetForecast(inv,nil),'unrelated wall cannot consume a new target grace period')
end
print('PASS funded buys, recovery, close evolution, strong growth, FINISH and quote identity retain their guards')
do
    local c,s,r,h,q,inv,B=fixture(false)
    q.multiplier=c.CONFIG.MajorMultiplier;q.cost=B.add(s.money,B.mul(s.rate,12))
    c.HaloRun.review();assert(r.phase=='WAIT_CASH' and s.resets==0)
    local deadline=r.goal.deadline
    s.time=deadline+1;r.buildWall.weak=40
    c.Strategy.waitCash();c.HaloRun.review()
    assert(s.resets==1 and r.savingsBudget.deadline==deadline,'major target must use the same expiring wait')
    local c,s,r,h,q,inv,B=fixture(true)
    s.beforeReset=function()s.money=q.cost end
    c.HaloRun.review()
    assert(s.resets==0 and s.denied=='BUILD_TARGET_FUNDED_DURING_NAVIGATION','fresh funding must veto the selected rebirth at execution')
end
print('PASS major boost protection expires once and real reset-intent validation still catches fresh funding')
do
    local c,s,r,h,q,inv,B=fixture(false);c.HaloRun.review();assert(r.phase=='WAIT_CASH')
    r.evo.ready=true;r.evo.bonus=B.new(400)
    c.HaloRun.deferEvolution=function()return false end
    assert(c.HaloRun.objectiveWatch() and r.phase=='CAPABILITY','saving cannot hide a newly ready evolution')
end
print('PASS ready evolution interrupts a saving phase through the existing objective review')
