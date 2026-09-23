local initialize=require('../src/adapters/DirectPrestige')
local function fixture(mode)
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c);c.BN=c.Core.BN
    require('../src/data/GameBalance')(c);require('../src/core/UpgradeMath')(c);require('../src/core/PrestigeMath')(c)
    local time=0;local queue={};local calls={};local events={}
    local function object(name,attrs,children)
        local o={Name=name,attrs=attrs or {},children=children or {}}
        function o:GetAttribute(k)return self.attrs[k]end
        function o:GetAttributes()return table.clone(self.attrs)end
        function o:FindFirstChild(k)return self.children[k]end
        function o:GetChildren()local t={};for _,v in pairs(self.children)do t[#t+1]=v end;return t end
        function o:IsA(k)return self.ClassName==k end
        return o
    end
    local v=object('Values',{Cash=40,CashSpent=39,Investors=8,InvestorsSpent=7,ExtraInvestorBoost=true,
        Ascension=24,Evolution=3,Rebirths=1,TotalRebirths=1108,TotalEvolves=164})
    local ledger=object('Purchases');local root=object('Values',{}, {Purchases=ledger})
    local own=object('Tycoon7');local premium=object('Purchases',{InvestorBoost=2})
    local player=object('LocalPlayer',{}, {Purchases=premium})
    local remote=object('Rebirth');remote.ClassName='RemoteFunction'
    own.children.Remotes=object('Remotes',{}, {Rebirth=remote})
    function remote:InvokeServer(...)
        assert(select('#',...)==1 and select(1,...)==nil,'ordinary rebirth must not request the paid/free product')
        calls[#calls+1]='rebirth'
        if mode=='reject' then error('denied')end
        if mode=='silent' then return end
        if mode=='evolve' then v.attrs.Evolution=v.attrs.Evolution+1;return end
        v.attrs.Rebirths=v.attrs.Rebirths+1;v.attrs.TotalRebirths=v.attrs.TotalRebirths+1
        v.attrs.Investors=c.UpgradeMath.add(v.attrs.Investors,c.PrestigeMath.reward(v.attrs.Cash,v.attrs.CashSpent,v.attrs.Investors,v.attrs.InvestorsSpent))
        v.attrs.Cash=0;v.attrs.CashSpent=nil
    end
    c.DirectUpgrades={state=function()
        local epoch={};for _,k in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do epoch[k]=v.attrs[k]end
        return {own=own,root=root,values=v,epoch=epoch}
    end}
    c.S={running=true,epoch=1,resetEnabled=true,counts={rebirth=0,evolve=0,halo=0}}
    c.env={};c.now=function()return time end;c.live=function(epoch)return c.S.running and (not epoch or epoch==c.S.epoch)end
    c.log=function(k)events[#events+1]=k end;c.pause=function(k)c.S.running=false;c.S.code=k end
    c.sleep=function(dt)time=time+dt;return c.S.running end;c.progress=function(k)c.S.counts[k]=c.S.counts[k]+1 end
    local r={};c.Strategy={route=function()return r end,rebirthBarrier=function(inv)
        return inv.ready and not r.disallow and not (r.evo and r.evo.ready),'POLICY_GATE'
    end,makeRecovery=function()return {}end,noteResetAbort=function(why)r.abort=why end,
        recordTiming=function()end,afterReset=function(kind,before)r.finished=kind;r.credited=before.afterInvestors end}
    local function gui()error('unexpected GUI access')end
    c.readInvestors=gui;c.readEvolution=gui;c.readHalo=gui;c.Strategy.peekResetInvestors=gui;c.step=function()events[#events+1]='step'end
    c.API={directReport=function()return 'base'end};c.navigate=function(key)calls[#calls+1]='navigate '..key;return true end
    c.doReset=function(kind)calls[#calls+1]='legacy '..kind;return true end
    c.DirectPurchases={refreshEpoch=function()end}
    local env=setmetatable({game={PlaceId=79268393072444,GetService=function(_,key)assert(key=='Players');return {LocalPlayer=player}end},
        task={spawn=function(fn)queue[#queue+1]=fn end,wait=function(dt)
            time=time+dt
            if mode=='timeout' then return end
            local pending=queue;queue={}
            if mode=='cancel' then c.S.running=false end
            if c.beforeJobs then c.beforeJobs()end
            for _,fn in ipairs(pending)do fn()end
        end}}, {__index=getfenv()})
    setfenv(initialize,env);initialize(c);c.DirectPrestige.verify=function()return true end
    c.DirectPrestige.verifyReset=function()return false,'FIXTURE_GUI_FALLBACK'end
    c.CONFIG.ResetTimeout=.15
    return c,v,premium,ledger,r,calls,events,queue
end
local c,v,p,l,r,calls=fixture('ok')
local inv=assert(c.readInvestors());assert(inv.perInvestor==.08 and inv.ready and inv.source=='replicated-prestige')
assert(c.BN.log(r.spent)==7 and not r.spentUnknown)
local oldReward=c.BN.log(inv.reward);v.attrs.Cash=41
assert(c.BN.log(c.readInvestors().reward)>oldReward,'hidden observations must resample current values')
assert(c.readEvolution().index==3 and c.readHalo().amount==24 and #calls==0)
assert(c.Strategy.peekResetInvestors().perInvestor==.08 and #calls==0)
for _,key in ipairs(c.GameBalance.PurchaseOrder)do l.attrs[key]=true end
assert(c.readHalo().ready);l.attrs[c.GameBalance.PurchaseOrder[1]]=nil;assert(not c.readHalo().ready)
assert(c.doReset('rebirth') and #calls==1 and calls[1]=='rebirth' and c.S.counts.rebirth==1 and r.finished=='rebirth' and r.credited)
assert(not c.S.actionPending and not r.directResetUnresolved)
print('PASS hidden prestige reads, fresh reward, premium bonus, completion gate and one ordinary rebirth with counter receipt')
for _,mode in ipairs({'reject','silent','evolve'})do
    local c,v,p,l,r,calls=fixture(mode)
    assert(not c.doReset('rebirth') and #calls==1 and c.S.counts.rebirth==0 and r.directResetUnresolved)
    c.S.running=true;assert(not c.doReset('rebirth') and #calls==1,'unknown rebirth must not repeat on resume')
    c.S.running=true;c.step();assert(not c.S.running,'unknown reset must also block ordinary worker actions')
end
local c,v,p,l,r,calls,events,queue=fixture('timeout')
assert(not c.doReset('rebirth') and c.S.actionPending and #calls==0)
c.S.running=false;for _,fn in ipairs(queue)do fn()end;assert(#calls==0 and not c.S.actionPending)
local c,v,p,l,r,calls=fixture('cancel');assert(not c.doReset('rebirth') and #calls==0)
print('PASS rejected, silent, different reset, timeout and pause preserve no-repeat and no-false-receipt rules')
local c,v,p,l,r,calls=fixture('ok');r.disallow=true;assert(not c.doReset('rebirth') and #calls==0)
r.disallow=nil;v.attrs.Cash=180;assert(not c.doReset('rebirth') and #calls==0,'fresh ready evolution must override stale rebirth intent')
v.attrs.Cash=40;v.attrs.TotalEvolves='invalid';assert(not c.readInvestors())
v.attrs.TotalEvolves=164;p.attrs.InvestorBoost='bad';assert(not c.readInvestors())
local c,v,p,l,r,calls=fixture('ok')
assert(c.doReset('evolve') and calls[1]=='navigate evolution' and calls[2]=='legacy evolve')
assert(c.doReset('halo') and calls[3]=='navigate halo' and calls[4]=='legacy halo')
assert(c.readInvestors(),'direct readers must be restored after GUI execution')
print('PASS current policy, fresh evolution, malformed state and retained GUI evolution/Halo dispatch')
do
    local c,_,_,_,r,calls=fixture('ok')
    c.HaloRun={deferEvolution=function(refresh)assert(refresh);return true,'CONTINUE_FUNDED_CONSTRUCTION'end}
    c.Strategy.phase=function(phase)r.phase=phase end
    assert(not c.doReset('evolve') and #calls==0 and r.phase=='BUY','protected route must veto before opening the evolution menu')
end
print('PASS direct prestige wrapper protects the current construction before any evolution GUI navigation')
local c,v=fixture('ok')
for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do v.attrs[key]=nil end
local initial=assert(c.DirectPrestige.snapshot())
assert(initial.snapshot.epoch.Rebirths==0 and initial.snapshot.epoch.TotalRebirths==0)
assert(c.readEvolution().index==0 and c.readHalo().amount==0,'legitimate absent zero counters must not stop initialization')
assert(c.DirectUpgrades.state().epoch.Rebirths==nil,'normalization must not weaken raw external-reset evidence')
print('PASS game-defined initial zero counters decode without changing the raw reset observations')
local c,v,p,l,r,calls=fixture('ok')
assert(c.readEvolution().index==3)
-- Captured E3 -> E4 state, including absent reset expense attributes.
v.attrs.Evolution=4;v.attrs.TotalEvolves=165;v.attrs.Rebirths=0;v.attrs.TotalRebirths=1109
v.attrs.Cash=57.460962165077184;v.attrs.Investors=3.9556394051741783
v.attrs.CashSpent='0';v.attrs.InvestorsSpent='0'
-- TycoonValues.GetHugeNumber decodes string "0" as Huge.zero. The older
-- report filters nonnumeric attributes, disguising this value as missing.
local originalBN=c.UpgradeMath.bn
c.UpgradeMath.bn=function(raw)
    if type(raw)~='number' or raw~=raw or math.abs(raw)==math.huge then return nil end
    return originalBN(raw)
end
local data,why=c.DirectPrestige.snapshot();assert(data,why)
local inv=assert(c.readInvestors());local evo=assert(c.readEvolution())
assert(evo.index==4 and not evo.ready and evo.bonus.m==0)
assert(inv.investorsSpent.m==0 and r.spent.m==0 and not r.spentUnknown)
assert(math.abs(c.BN.log(inv.investors)-3.9556394051741783)<1e-10)
assert(inv.reward.m>0 and #calls==0,'reading reset state must not send a replacement reset')
v.attrs.CashSpent=nil;v.attrs.InvestorsSpent=nil;assert(c.readInvestors().investorsSpent.m==0)
v.attrs.CashSpent=0;assert(c.readInvestors(),'log10 zero is one currency unit, not a missing balance')
v.attrs.CashSpent='invalid';assert(not c.readInvestors())
v.attrs.CashSpent=math.huge;assert(not c.readInvestors())
v.attrs.CashSpent=0/0;assert(not c.readInvestors())
print('PASS string and absent zero expense balances decode after evolution; fresh E4 is readable and malformed values still fail')
local function directFixture(kind,mode)
    local c,v,p,l,r,calls,events,queue=fixture(mode=='timeout' and 'timeout' or 'ok')
    c.DirectPrestige.verifyReset=function()return true end
    -- Actual captured 4.0.11 E5 -> E6; Halo27 -> 28.
    v.attrs.Evolution=kind=='evolve' and 5 or 6;v.attrs.Ascension=27
    v.attrs.Rebirths=kind=='evolve' and 2 or 3;v.attrs.TotalEvolves=kind=='evolve' and 185 or 186
    v.attrs.TotalRebirths=kind=='evolve' and 1148 or 1151
    v.attrs.Cash=217.35401899096746;v.attrs.CashSpent=217.44911656526986
    v.attrs.Investors=75.56765475958363;v.attrs.InvestorsSpent=63
    for _,key in ipairs(c.GameBalance.PurchaseOrder)do l.attrs[key]=true end
    c.HaloRun={deferEvolution=function()return r.hold,'CONTINUE_FUNDED_CONSTRUCTION'end}
    c.Strategy.phase=function(phase)r.phase=phase end
    local own=c.DirectPrestige.snapshot().snapshot.own
    local remote={IsA=function(_,class)return class=='RemoteFunction'end}
    own.children.Remotes.children[kind=='evolve' and 'Evolve' or 'Ascend']=remote
    function remote:InvokeServer(...)
        if kind=='evolve'then assert(select('#',...)==1 and select(1,...)==nil,'normal evolution must never use paid/free true')
        else assert(select('#',...)==0,'Ascend has no arguments')end
        calls[#calls+1]='direct '..kind
        if mode=='error'then error('server unavailable')end
        if mode=='silent'then return true end -- server return alone is not a receipt.
        if kind=='evolve'then
            v.attrs.Evolution=v.attrs.Evolution+1;v.attrs.TotalEvolves=v.attrs.TotalEvolves+1
        else v.attrs.Ascension=v.attrs.Ascension+1;v.attrs.Evolution=0 end
        v.attrs.Rebirths=0
        if mode=='wrong-lifetime'then v.attrs.TotalRebirths=v.attrs.TotalRebirths+1 end
        if mode=='wrong-count'then v.attrs.TotalEvolves=v.attrs.TotalEvolves+1 end
        if mode=='partial'then v.attrs.Rebirths=1 end
        if mode=='pause-after'then c.S.running=false end
        if mode=='late-replication'then v.attrs.Rebirths=1;c.beforeJobs=function()v.attrs.Rebirths=0 end end
        return true
    end
    return c,v,l,r,calls,queue
end
for _,kind in ipairs({'evolve','halo'})do
    for _,mode in ipairs({'ok','late-replication','pause-after'})do
        local c,v,l,r,calls=directFixture(kind,mode)
        assert(c.doReset(kind) and #calls==1 and calls[1]=='direct '..kind)
        assert(c.S.counts[kind]==1 and r.finished==kind and not c.S.actionPending and not r.directResetUnresolved)
        if mode=='pause-after'then assert(not c.S.running,'receipt cannot resume a user pause')end
    end
    for _,mode in ipairs({'silent','error','wrong-lifetime','wrong-count','partial'})do
        local c,v,l,r,calls=directFixture(kind,mode)
        assert(not c.doReset(kind) and #calls==1 and c.S.counts[kind]==0 and r.directResetUnresolved,kind..' '..mode)
        c.S.running=true;assert(not c.doReset(kind) and #calls==1,'unresolved reset cannot be repeated')
    end
    local c,v,l,r,calls,queue=directFixture(kind,'timeout')
    assert(not c.doReset(kind) and c.S.actionPending and #calls==0)
    for _,fn in ipairs(queue)do fn()end
    assert(#calls==0 and not c.S.actionPending,'expired unsent work cannot dispatch later even if still running')
    local c,v,l,r,calls=directFixture(kind,'ok')
    c.beforeJobs=function()c.S.running=false end
    assert(not c.doReset(kind) and #calls==0,'pause before dispatch must prevent network request')
    local c,v,l,r,calls=directFixture(kind,'ok')
    c.CONFIG[kind=='evolve' and 'AutoEvolution' or 'AutoHalo']=false
    assert(not c.doReset(kind) and #calls==0)
end
print('PASS ordinary direct Evolution/Halo arguments, real counter transitions, partial/late receipts, pause, timeout and no-repeat rules')
do
    local c,v,l,r,calls=directFixture('evolve','ok');r.hold=true
    assert(not c.doReset('evolve') and #calls==0 and r.phase=='BUY')
    local c,v,l,r,calls=directFixture('evolve','ok');c.beforeJobs=function()r.hold=true end
    assert(not c.doReset('evolve') and #calls==0,'fresh funded finish must veto even after reset selection')
    local c,v,l,r,calls=directFixture('evolve','ok');v.attrs.Cash=1;v.attrs.CashSpent=1;v.attrs.Investors=1;v.attrs.InvestorsSpent=1
    assert(not c.doReset('evolve') and #calls==0,'not-ready evolution is not sent')
    local c,v,l,r,calls=directFixture('halo','ok');l.attrs={}
    assert(not c.doReset('halo') and #calls==0,'unfinished base cannot send Ascend')
end
print('PASS ready gates and current-route protection apply to direct resets immediately before sending')

for _,stage in ipairs({'selection','ready-delay','dispatch'})do
    local c,v,l,r,calls=directFixture('evolve','ok')
    require('../src/core/HaloPlanner')(c);require('../src/core/EconomyPlanner')(c)
    c.HaloCatalogue={{id=1,name='The End',cost=c.BN.new(1,264)}}
    c.Strategy.effectiveActionSeconds=function()return .18 end
    c.Strategy.buildPermissionContext=function()return {known=true,sustained=false}end
    c.cash=function()return c.UpgradeMath.bn(v.attrs.Cash)end
    c.readBuy=function()return {id='directBuy:StaircasePlatform7',name='Eighth Tier',cost=c.BN.new(4.053,249),available=false}end
    v.attrs.Evolution=6;v.attrs.Ascension=35;v.attrs.Cash=245;v.attrs.CashSpent=244
    require('../src/strategy/HaloController')(c)
    c.HaloRun.plan=function()end -- Feed the observed forecast transitions, keep the real policy and dispatcher.
    local h=c.HaloRun.state()
    h.economy={known=true,certifiable=true,completeLedger=true,scenarioReady=false,catalogueRoute={time=c.BN.new(1000)}}
    local sleep=c.sleep
    local function beginTrial()
        h.economy.scenarioReady=true;h.economy.catalogueRoute.time=c.BN.new(13.32);h.economy.at=c.now()
        assert(c.HaloRun.deferEvolution(false))
        sleep(2.09);h.economy.scenarioReady=false;h.economy.at=c.now()
    end
    if stage=='selection'then beginTrial()
    elseif stage=='ready-delay'then c.sleep=function(dt)local ok=sleep(dt);beginTrial();return ok end
    else c.beforeJobs=beginTrial end
    assert(not c.doReset('evolve') and #calls==0 and c.S.counts.evolve==0,
        'real finish-trial policy must veto the direct evolution at '..stage)
    assert(c.S.running and not c.S.actionPending and not r.directResetUnresolved,'economic veto is not an error or unresolved reset')
end
print('PASS H35/E6 trial reversal vetoes real direct Evolution selection, ready delay and final dispatch without GUI or a request')
