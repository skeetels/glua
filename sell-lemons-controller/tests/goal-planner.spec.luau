local c={};require('../src/config')(c);require('../src/core/Numeric')(c)
require('../src/core/UpgradeMath')(c);require('../src/core/PrestigeMath')(c)
require('../src/core/EconomyPlanner')(c);require('../src/core/GoalPlanner')(c)
-- Production loads core modules before ClientContext creates the convenience
-- alias. Setting it before GoalPlanner initialization concealed a nil capture.
assert(c.BN==nil and c.Core.BN)
c.BN=c.Core.BN
local B=c.BN;local P=c.PrestigeMath;local G=c.GoalPlanner;local M=c.UpgradeMath
local function near(a,b)assert(math.abs(a-b)<1e-7,tostring(a)..' vs '..tostring(b))end
-- Independent inverse calculation at ordinary magnitudes, then extreme log units.
for _,x in ipairs({{nil,nil},{8,9},{8,20},{17,16}})do
    local i,j=x[1] and 10^x[1] or 0,x[2] and 10^x[2] or 0
    local target=10^17.7;local prior=i+math.min(j,10*i)
    local expected=target<=i+j and -math.huge or math.log10(1.8e17*((prior+target-i-j)^(1/.44)-prior^(1/.44)))
    local actual=P.evolutionCash(0,x[1],x[2],0)
    if expected==-math.huge then assert(actual==expected)else near(actual,expected)end
end
for _,index in ipairs({0,3,7,77,1000})do
    for _,minimum in ipairs({0,400})do
        local x=P.evolutionCash(index,nil,nil,minimum)
        local pct,bonus,_,total=P.evolution(index,nil,nil,P.reward(x,nil,nil,nil))
        assert(pct>=1-1e-10 and x<math.huge)
        if minimum>0 then near(bonus,math.log10(minimum))end
        assert(total>=17.7+13.6*index-1e-8)
    end
end
assert(P.evolutionCash(-1,nil,nil)==nil)
print('PASS exact evolution production thresholds, spent cap, zero banks and log balances beyond floating-point amounts')

local trace={complete=true,base=B.new(1),kind='ui',epoch=3,points={
    {age=2,time=98,cash=B.new(1e12),rate=B.new(10),spent=B.new(0),service=0},
    {age=100,time=100,cash=B.new(0),rate=B.new(100),spent=B.new(1e9),service=80},
}}
local short=G.prefix(trace,B.new(1),B.new(20),c.CONFIG)
near(short.seconds,4);assert(short.points==1 and short.totalPoints==2)
-- Buying a productive prefix is permitted, but its price and input time are paid.
local paid=table.clone(trace);paid.points={trace.points[1],{age=10,time=100,rate=B.new(100),spent=B.new(20),service=1}}
local p=G.prefix(paid,B.new(1),B.new(1000),c.CONFIG)
near(p.seconds,2+3+(1000-30)/100);assert(p.points==2)
trace.invalid=true;assert(G.prefix(trace,B.new(1),B.new(20),c.CONFIG)==nil);trace.invalid=nil
print('PASS next-goal replay stops before expensive old-base work and never inherits the old wallet for free')

local data={snapshot={epoch={Evolution=3}},Cash=17.2552725051033+57/.44}
data.reward=P.reward(data.Cash,nil,nil,nil)
local inv={investors=B.new(0),reward=M.bn(data.reward),ready=true,perInvestor=.08}
local fast={complete=true,base=B.new(1),kind='ui',epoch=3,points={
    {age=.7,time=100,cash=B.new(0),rate=B.new(1,135),spent=B.new(0),service=0},
    {age=50,time=100,cash=B.new(1,150),rate=B.new(1,140),spent=B.new(1,151),service=49},
}}
local d=assert(G.compare(data,inv,B.new(1,140),'ui',fast,0,0,3,c.CONFIG,100))
assert(d.worth and d.reset<4 and d.points==1 and d.direct>1000)
-- The very same investor gain is insufficient if continuing already finishes sooner.
local d2=assert(G.compare(data,inv,B.new(1,160),'ui',fast,0,0,3,c.CONFIG,100))
assert(not d2.worth and d2.direct<.01)
fast.complete=false;assert(G.compare(data,inv,B.new(1,140),'ui',fast,0,0,3,c.CONFIG,100)==nil)
fast.complete=true;assert(G.compare(data,inv,B.new(1,140),'cash',fast,0,0,3,c.CONFIG,100)==nil)
assert(G.compare(data,inv,B.new(1,140),'ui',fast,0,0,3,c.CONFIG,110)==nil)
data.Cash=200;data.reward=P.reward(200,nil,nil,nil)
local none,why=G.compare(data,inv,B.new(1,140),'ui',fast,0,0,3,c.CONFIG,100)
assert(not none and why=='EVOLUTION_READY')
print('PASS strong permanent-income start chooses short rebirth prefix; same gain with near-ready evolution continues; stale/partial evidence cannot authorize reset')

do
    local state={time=100,invTime=100,ready=true,bank=B.new(0),reward=B.new(200),perInvestor=.08,
        used=B.new(0),spent=B.new(0),cash=B.new(100),recovery=true,epoch=2,policy='same'}
    local intent={at=99,expiresAt=105,state=table.clone(state),spend=B.new(0),detail={authorization='next-evolution-prefix'}}
    assert(c.Planner.validateResetIntent(intent,state,c.CONFIG),'goal proof may beat the old recovery before 400 investors')
    intent.detail.authorization='observed-construction-wall-332'
    assert(not c.Planner.validateResetIntent(intent,state,c.CONFIG),'ordinary recovery protection remains')
    intent.detail.authorization='next-evolution-prefix'
    for _,change in ipairs({{evoReady=true},{unresolved=true},{epoch=3},{time=106},{reward=B.new(10)},{cash=B.new(1)},{policy='changed'},{endReached=true}})do
        local bad=table.clone(state);for k,v in pairs(change)do bad[k]=v end
        assert(not c.Planner.validateResetIntent(intent,bad,c.CONFIG),'goal proof cannot bypass ordinary lease state guards')
    end
end
print('PASS new goal authorization bypasses only old full-recovery/reserve requirements; all epoch/receipt/readiness/lease guards remain')
