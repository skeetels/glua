local mock=require('./mock-engine')()
local ctx={}
do local initialize=require('../src/config');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/Numeric');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/data/GameBalance');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/UpgradeMath');setfenv(initialize,mock.env);initialize(ctx) end
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
local connections=ctx.S.connections
ctx.API.unload()
assert(ctx.S.unloaded and ctx.panel.destroyed)
for _,connection in ipairs(connections)do assert(not connection.Connected,'leaked event listener')end
ctx.API.unload()
print('PASS modular initialization, diagnostics and complete unload fixture')
