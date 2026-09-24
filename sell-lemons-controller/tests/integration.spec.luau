local mock=require('./mock-engine')()
local oldEvolutionStopped=false
mock.globals.SLEvolutionOnly={active=true,pending=false,stop=function()
    oldEvolutionStopped=true;mock.globals.SLEvolutionOnly.active=false
end}
local ctx={}
do local initialize=require('../src/config');setfenv(initialize,mock.env);initialize(ctx) end
ctx.CONFIG.RepeatRebirth=false;ctx.CONFIG.HaloSprint=false;ctx.CONFIG.AutoEvolution=true -- Exercise the older evolution route separately.
do local initialize=require('../src/core/Numeric');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/data/GameBalance');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/UpgradeMath');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/PrestigeMath');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/data/Catalogue');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/HaloPlanner');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/EconomyPlanner');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/GoalPlanner');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/ObservationStore');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/core/RecoveryPolicy');setfenv(initialize,mock.env);initialize(ctx) end
do local initialize=require('../src/runtime/ClientContext');setfenv(initialize,mock.env);initialize(ctx) end
assert(oldEvolutionStopped,'loading the main controller must stop evolution-only mode')
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
do local initialize=require('../src/runtime/ResetInspection');setfenv(initialize,mock.env);initialize(ctx) end
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
do local initialize=require('../src/strategy/GoalDirector');setfenv(initialize,mock.env);initialize(ctx) end
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
assert(report:find('RETAINED EVOLUTION / HALO SCANS',1,true),'F7 report must contain the retained automatic scans')
assert(ctx.API.exportCycleState().resetScans==ctx.S.resetScans,'reload export must retain the separate scan book')
ctx.HaloRun.noteEvolutionDecision('TEST_RETAINED_REASON',{id='test-gate',cost=ctx.BN.new(1)})
assert(ctx.API.report():find('TEST_RETAINED_REASON',1,true),'reset reasons must survive ordinary log rotation')
assert(ctx.API.exportCycleState().evolutionDecisions==ctx.S.evolutionDecisions,'reload export must retain the bounded decision journal')
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
values.attrs.CashSpent='0';values.attrs.InvestorsSpent='0'
ctx.Strategy.afterReset('evolve',{index=3})
assert(ctx.Strategy.route().phase=='BOOT' and ctx.Strategy.route().evo==nil)
ctx.HaloRun.boot()
assert(ctx.S.running and ctx.Strategy.route().evo.index==4,ctx.S.code..' '..ctx.S.status)
assert(ctx.Strategy.route().phase=='POWERS','post-evolution boot must resume power/Buy preparation')
assert(ctx.Strategy.route().spent.m==0 and not ctx.Strategy.route().spentUnknown)
assert(not ctx.S.actionPending and not ctx.S.resetSession,'no replacement reset is dispatched')
print('PASS confirmed E3 to E4 cleanup and actual BOOT resume to POWERS with string-zero spent balances')
-- Exercise the actual direct transaction -> afterReset wrappers -> BOOT chain.
ctx.DirectPrestige.verifyReset=function()return true end
local actualDeferEvolution=ctx.HaloRun.deferEvolution
ctx.HaloRun.deferEvolution=function()return false end -- policy itself has report-based regression fixtures.
ctx.sleep=function()return ctx.S.running end
mock.env.task.spawn=function(fn)fn();return fn end
ctx.navigate=function()error('direct reset attempted GUI navigation')end
own.children.Remotes=node('Remotes')
for _,kind in ipairs({'evolve','halo'})do
    values.attrs.Evolution=kind=='evolve' and 5 or 6;values.attrs.Ascension=27
    values.attrs.TotalEvolves=186;values.attrs.Rebirths=2;values.attrs.TotalRebirths=1151
    values.attrs.Cash=217.354;values.attrs.CashSpent=217.449
    values.attrs.Investors=75.567;values.attrs.InvestorsSpent=63
    for _,key in ipairs(ctx.GameBalance.PurchaseOrder)do root.children.Purchases.attrs[key]=true end
    local remote=node(kind=='evolve' and 'Evolve' or 'Ascend');remote.IsA=function(_,k)return k=='RemoteFunction'end
    own.children.Remotes.children[remote.Name]=remote
    function remote:InvokeServer()
        if kind=='evolve'then values.attrs.Evolution=6;values.attrs.TotalEvolves=187
        else values.attrs.Ascension=28;values.attrs.Evolution=0 end
        values.attrs.Rebirths=0;values.attrs.Cash=54;values.attrs.Investors=3
        values.attrs.CashSpent='0';values.attrs.InvestorsSpent='0';root.children.Purchases.attrs={}
    end
    assert(ctx.doReset(kind),ctx.S.code..' '..ctx.S.status)
    assert(ctx.Strategy.route().phase=='BOOT' and not ctx.S.actionPending)
    ctx.HaloRun.boot()
    assert(ctx.S.running and ctx.Strategy.route().phase=='POWERS',ctx.S.code..' '..ctx.S.status)
    assert(ctx.Strategy.route().evo.index==(kind=='evolve' and 6 or 0))
end
print('PASS direct Evolution/Halo receipts run full cleanup and resume real BOOT to POWERS without menus')
-- Report 15e63d31, H82/E4: not-ready evolution and nonzero direct income enter
-- the rebirth comparison on the very first BOOT after injection. Earlier boot
-- fixtures had no stand income, so they returned before touching the calculator.
do
    local originalCards=ctx.DirectUpgrades.cards
    local originalCompare=ctx.GoalPlanner.compare
    local compared=0;local failure
    ctx.DirectUpgrades.cards=function()
        return {{source='direct',path='direct/LemonStand',key='LemonStand',name='Lemon Stand',
            income=ctx.BN.new(1.862,135),periodSeconds=1}}
    end
    ctx.GoalPlanner.compare=function(...)
        compared=compared+1
        local result,why=originalCompare(...);failure=why;return result,why
    end
    values.attrs.Cash=136.5247850360478;values.attrs.CashSpent='0'
    values.attrs.Investors=3.1329471383665064;values.attrs.InvestorsSpent='0'
    values.attrs.Evolution=4;values.attrs.Ascension=82;values.attrs.Rebirths=0
    values.attrs.TotalRebirths=1532;values.attrs.TotalEvolves=527;root.children.Purchases.attrs={}
    for _=1,2 do
        ctx.API.pause();ctx.API.start()
        assert(ctx.S.running and ctx.Strategy.route().phase=='BOOT')
        ctx.HaloRun.boot()
        assert(ctx.S.running and ctx.Strategy.route().phase=='POWERS',ctx.S.code..' '..ctx.S.status)
        assert(failure=='NO_CLEAN_PREFIX','partial attachment must continue work without inventing a reset route')
        assert(not ctx.S.actionPending and not ctx.S.resetSession)
    end
    assert(compared==2,'exercise actual goal comparison on both fresh startup and F6 resume')
    ctx.GoalPlanner.compare=originalCompare;ctx.DirectUpgrades.cards=originalCards
end
print('PASS H82/E4 reported BOOT and F6 resume execute real goal comparison without nil arithmetic or an unauthorized reset')
-- Adaptive economically selected resets still use the full real lease, RPC,
-- receipt and cleanup chain. Exact stand/power allocation is exercised by
-- adaptive-route.spec; here funded upgrades are absent and the earned reward
-- strongly dominates the very slow current income.
do
    ctx.CONFIG.RepeatRebirth=true;ctx.HaloRun.deferEvolution=actualDeferEvolution
    ctx.UpgradeMath.bn=ordinaryBN
    local stateBefore=ctx.DirectUpgrades.state
    ctx.DirectUpgrades.state=function()local s=stateBefore();s.stackLevel=4;s.cap=math.huge;return s end
    ctx.DirectUpgrades.allocate=function()return {} end
    local calls={rebirth=0,evolve=0,buy=0};local sleeps={}
    local oldBuy=ctx.HaloRun.buy
    ctx.HaloRun.buy=function()calls.buy=calls.buy+1 end
    ctx.ensureTablet=function()error('repeat mode must not prepare tablet/base')end
    ctx.HaloRun.powers=function()error('repeat mode must not prepare Powers')end
    ctx.Strategy.growUpgrades=function()error('repeat mode must not wait for a stand pass')end
    ctx.GoalDirector.forecast=function()error('repeat mode must not require a replay forecast')end
    ctx.DirectUpgrades.cards=function()return {{source='direct',path='direct/LemonStand',key='LemonStand',
        name='Lemon Stand',level=0,income=ctx.BN.new(1,30),periodSeconds=1}}end
    ctx.sleep=function(seconds)sleeps[#sleeps+1]=seconds;return ctx.S.running end
    for _,kind in ipairs({'Rebirth','Evolve'})do
        local remote=node(kind);remote.IsA=function(_,k)return k=='RemoteFunction'end
        own.children.Remotes.children[kind]=remote
        function remote:InvokeServer(...)
            assert(select('#',...)==1 and select(1,...)==nil)
            if kind=='Rebirth'then
                local d=ctx.DirectPrestige.snapshot()
                values.attrs.Investors=ctx.PrestigeMath.add(d.Investors,d.reward)
                values.attrs.Rebirths=values.attrs.Rebirths+1
                values.attrs.TotalRebirths=values.attrs.TotalRebirths+1
                calls.rebirth=calls.rebirth+1
            else
                values.attrs.Evolution=values.attrs.Evolution+1
                values.attrs.TotalEvolves=values.attrs.TotalEvolves+1;values.attrs.Rebirths=0
                calls.evolve=calls.evolve+1
            end
            values.attrs.Cash=0;values.attrs.CashSpent='0'
        end
    end
    values.attrs.Cash=136.5247850360478;values.attrs.CashSpent='0'
    values.attrs.Investors=3.1329471383665064;values.attrs.InvestorsSpent='0'
    values.attrs.Evolution=4;values.attrs.Ascension=82;values.attrs.Rebirths=0
    values.attrs.TotalRebirths=1532;values.attrs.TotalEvolves=527;root.children.Purchases.attrs={}
    ctx.API.pause();ctx.API.start()
    ctx.Strategy.route().directEpoch=ctx.DirectUpgrades.state()
    assert(not ctx.Strategy.route().cleanRun,'first attachment has no complete trace')
    local before=ctx.S.counts.rebirth
    for i=1,3 do
        -- Permanent production has supplied a fresh normal reward after each reset.
        values.attrs.Cash=136.5247850360478+i
        ctx.step()
        assert(calls.rebirth==i and ctx.S.counts.rebirth==before+i,ctx.S.code..' '..ctx.S.status)
        assert(ctx.S.running and calls.buy==0 and ctx.Strategy.route().phase=='REBIRTH_LOOP')
        assert(not ctx.S.actionPending and not ctx.Strategy.route().directResetUnresolved)
        assert(sleeps[#sleeps]==ctx.CONFIG.RepeatRebirthSettleSeconds)
    end
    values.attrs.Cash=0
    ctx.step();ctx.step()
    assert(calls.rebirth==3 and calls.buy==0 and ctx.S.running,'no reward / throttle must wait without falling into Buy')
    assert(ctx.Strategy.route().phase=='REBIRTH_LOOP')
    -- Fresh ready evolution takes priority over the fourth rebirth.
    ctx.HaloRun.state().nextGoalRead=nil;values.attrs.Cash=200
    ctx.step()
    assert(calls.evolve==1 and calls.rebirth==3 and calls.buy==0,ctx.S.code..' '..ctx.S.status)
    -- A cash-funded full remainder switches to construction, without a reset.
    ctx.HaloRun.state().nextGoalRead=nil;values.attrs.Cash=400
    ctx.step();ctx.step()
    assert(calls.buy>0 and calls.evolve==1 and calls.rebirth==3,'funded Halo must end the rebirth loop')
    -- The new Halo sprint reads the replicated current-cycle Rebirths counter.
    -- Two actual RPC receipts are allowed; the third step enters Buy instead.
    ctx.CONFIG.AutoEvolution=false;ctx.CONFIG.HaloSprint=true
    values.attrs.Ascension=83;values.attrs.Evolution=0;values.attrs.Rebirths=0;values.attrs.TotalRebirths=1600
    values.attrs.Cash=136.5247850360478;values.attrs.CashSpent='0'
    values.attrs.Investors=3.1329471383665064;values.attrs.InvestorsSpent='0'
    ctx.API.pause();ctx.API.start()
    local beforeSprint=calls.rebirth;local beforeBuy=calls.buy;local beforeEvolve=calls.evolve
    for i=1,2 do
        values.attrs.Cash=136.5247850360478+i
        ctx.step()
        assert(calls.rebirth==beforeSprint+i and values.attrs.Rebirths==i,ctx.S.code..' '..ctx.S.status)
        assert(ctx.S.running and not ctx.S.actionPending)
    end
    values.attrs.Cash=136.5247850360478+3
    ctx.step();ctx.step()
    assert(calls.rebirth==beforeSprint+2 and calls.evolve==beforeEvolve and calls.buy>beforeBuy,
        'rebirth='..calls.rebirth..' buy='..calls.buy..' evolve='..calls.evolve..' phase='..ctx.Strategy.route().phase..' status='..ctx.S.code..' '..ctx.S.status)
    assert(ctx.Strategy.route().phase=='BUY')
    local oldRemaining=ctx.DirectPurchases.remaining
    ctx.DirectPurchases.remaining=function()return {cash=ctx.BN.new(60),cost=ctx.BN.new(50),count=10}end
    ctx.step();assert(ctx.HaloRun.state().goalFinish and ctx.Strategy.route().phase=='BUY',
        'funded whole-catalogue cash must remain reserved during parallel stand waves')
    ctx.DirectPurchases.remaining=oldRemaining
    local inv=ctx.readInvestors()
    assert(not ctx.Strategy.rebirthBarrier(inv),'the final reset lease must block a third rebirth')
    -- Reload/reattach in the same game cycle must honor the existing count.
    ctx.ensureTablet=function()return true end -- Headless ownership read on a new Halo cycle.\n    ctx.API.pause();ctx.API.start();ctx.step()
    assert(calls.rebirth==beforeSprint+2 and calls.buy>beforeBuy)
    assert(not ctx.doReset('evolve') and calls.evolve==beforeEvolve,'manual stale evolution phase cannot send an Evolve request')
    -- A verified new Halo starts another two-rebirth allowance.
    values.attrs.Ascension=84;values.attrs.Evolution=0;values.attrs.Rebirths=0
    values.attrs.Investors=3.1329471383665064;values.attrs.Cash=137;values.attrs.CashSpent='0'
    ctx.API.pause();ctx.API.start();ctx.step()
    assert(calls.rebirth==beforeSprint+3 and ctx.S.running,'new Halo counter must reopen the allowance')
    ctx.HaloRun.buy=oldBuy
end
print('PASS adaptive reset receipts and two-rebirth Halo sprint: quota, reload, no evolution, funded reservation and new-Halo restart')
local connections=ctx.S.connections
ctx.API.unload()
assert(ctx.S.unloaded and ctx.panel.destroyed)
for _,connection in ipairs(connections)do assert(not connection.Connected,'leaked event listener')end
ctx.API.unload()
print('PASS modular initialization, diagnostics and complete unload fixture')




