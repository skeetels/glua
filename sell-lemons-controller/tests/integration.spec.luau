local mock=require('./mock-engine')()
local ctx={}
do local initialize=require('../src/config');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/Numeric');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/data/GameBalance');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/UpgradeMath');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/PrestigeMath');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/data/Catalogue');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/HaloPlanner');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/EconomyPlanner');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/ObservationStore');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/RecoveryPolicy');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/ClientContext');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/GuiAccess');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/VirtualInput');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Focus');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/SignalInput');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/Navigation');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/GuiState');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/ReplicatedState');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/StateObserver');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Transactions');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Confirmation');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/ResetTransaction');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/DirectUpgrades');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/RouteState');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/BatchSelection');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/InvestorPowers');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/Capital');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/UpgradeAllocation');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/Observations');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/ResetPlanning');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/Growth');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/strategy/HaloController');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/DirectPurchases');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/adapters/DirectPrestige');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/ui/Progress');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/ui/Panel');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Diagnostics');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/DataInspection');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Supervisor');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/AntiIdle');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/Lifecycle');setfenv(initialize,mock.env);initialize(ctx) end
assert(ctx.API and ctx.API.start and ctx.API.unload and ctx.API.report)
assert(ctx.Observer and ctx.Supervisor and ctx.AntiIdle)
assert(ctx.panel.Parent==mock.gui and ctx.panel.Name=='SLAutofarmPanel')
assert(ctx.Strategy.route().phase=='BOOT')
assert(#mock.tasks==3,'one economic worker, one read-only observer, one presentation worker')
ctx.Observer.poll()
local report=ctx.API.report()
assert(type(report)=='string' and report:find('Controller 4.0',1,true))
assert(type(ctx.API.inspectData())=='string')
assert(type(ctx.API.dataReport())=='string')
local observations=ctx.API.observations()
assert(observations.revision==0,'missing GUI data must stay unknown')
ctx.API.antiIdle(false);assert(ctx.API.antiIdle().enabled==false)
ctx.selfTest=function()error('direct startup must not require mouse APIs')end
ctx.API.start();assert(ctx.S.running and not ctx.S.testing)
ctx.API.pause();assert(not ctx.S.running)
ctx.API.start();assert(ctx.S.running,'F6 resume must work without another mouse test')
-- Real route boot + confirmed-reset cleanup, with the captured E4 balances.
local function node(name,attrs,children)
    local o={Name=name,attrs=attrs or {},children=children or {}}
    function o:GetAttribute(k)return self.attrs[k]end
    function o:GetAttributes()return table.clone(self.attrs)end
    function o:GetChildren()return {}end
    function o:FindFirstChild(k)return self.children[k]end
    return o
end
local values=node('Values',{Cash=131.97138537523728,Investors=38.96138888955707,CashSpent=130,InvestorsSpent=33,
    Evolution=3,Ascension=24,Rebirths=2,TotalRebirths=1109,TotalEvolves=164})
local root=node('Values',{}, {Purchases=node('Purchases')})
local own=node('Tycoon9');local powers=node('Powers',{}, {Permanent=node('Permanent',{BuyNext=3})})
local premium=mock.env.Instance.new('Configuration');premium.Name='Purchases';premium.Parent=mock.player
premium.GetAttribute=function(_,key)if key=='InvestorBoost' then return 2 end end
mock.services.CollectionService={GetTagged=function()return {}end}
ctx.DirectUpgrades.state=function()
    local epoch={};for _,k in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do epoch[k]=values.attrs[k]end
    return {own=own,root=root,values=values,powers=powers,levels=node('Upgrades'),cash=values.attrs.Cash,
        cap=1,shift=24*math.log10(3.33),epoch=epoch,stands={},time=ctx.now()}
end
ctx.DirectPrestige.verify=function()return true end
local ordinaryBN=ctx.UpgradeMath.bn
ctx.UpgradeMath.bn=function(value)
    if type(value)~='number' or value~=value or math.abs(value)==math.huge then return nil end
    return ordinaryBN(value)
end
ctx.HaloRun.boot();assert(ctx.S.running and ctx.Strategy.route().evo.index==3)
values.attrs.Evolution=4;values.attrs.TotalEvolves=165;values.attrs.Rebirths=0
values.attrs.Cash=57.460962165077184;values.attrs.Investors=3.9556394051741783
values.attrs.CashSpent=nil;values.attrs.InvestorsSpent=nil
ctx.Strategy.afterReset('evolve',{index=3})
assert(ctx.Strategy.route().phase=='BOOT' and ctx.Strategy.route().evo==nil)
ctx.HaloRun.boot()
assert(ctx.S.running and ctx.Strategy.route().evo.index==4,ctx.S.code..' '..ctx.S.status)
assert(ctx.Strategy.route().phase=='POWERS','post-evolution boot must resume power/Buy preparation')
assert(ctx.Strategy.route().spent.m==0 and not ctx.Strategy.route().spentUnknown)
assert(not ctx.S.actionPending and not ctx.S.resetSession,'no replacement reset is dispatched')
print('PASS confirmed E3 to E4 cleanup and actual BOOT resume to POWERS with absent spent balances')
local connections=ctx.S.connections
ctx.API.unload()
assert(ctx.S.unloaded and ctx.panel.destroyed)
for _,connection in ipairs(connections)do assert(not connection.Connected,'leaked event listener')end
ctx.API.unload()
print('PASS modular initialization, diagnostics and complete unload fixture')
