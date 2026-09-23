-- Real quote allocation, power/stand adapters and adaptive director, with
-- deterministic replicated Roblox state. This is not a live-server speed test.
local function fixture(bank,cash,rate,tier)
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c);c.BN=c.Core.BN
    require('../src/data/GameBalance')(c);require('../src/core/UpgradeMath')(c);require('../src/core/PrestigeMath')(c)
    require('../src/core/EconomyPlanner')(c);require('../src/core/GoalPlanner')(c)
    local B,M=c.BN,c.UpgradeMath;local time=100;local queue={};local calls={};local player={}
    local function node(name,attrs,children,class)
        local o={Name=name,attrs=attrs or {},children=children or {},class=class}
        function o:GetAttribute(k)return self.attrs[k]end
        function o:GetAttributes()return self.attrs end
        function o:GetChildren()local a={};for _,v in pairs(self.children)do a[#a+1]=v end;return a end
        function o:FindFirstChild(k)return self.children[k]end
        function o:IsA(k)return self.class==k end
        function o:HasTag(k)return self.tag==k end
        function o:IsDescendantOf(root)local a=self.Parent;while a do if a==root then return true end;a=a.Parent end;return false end
        for _,ch in pairs(o.children)do ch.Parent=o end
        return o
    end
    local values=node('Values',{Cash=cash,Investors=bank,Ascension=0,Evolution=4,Rebirths=0,TotalRebirths=1,TotalEvolves=4})
    local levels=node('Upgrades');local powers=node('Powers',{UpgradeStack=tier or 0},{Permanent=node('Permanent')})
    local streams=node('Streams');local income=node('Income',{ValueMultiplier=rate,RateMultiplier=0},{Streams=streams})
    local root=node('Values',{}, {Values=values,Upgrades=levels,Powers=powers,Income=income,Purchases=node('Purchases')})
    local owner=node('Owner',nil,nil,'ObjectValue');owner.Value=player
    local remotes=node('Remotes');local own=node('Tycoon1',{}, {Values=root,Owner=owner,Remotes=remotes})
    local world=node('Workspace',{}, {Tycoon1=own});local stands={}
    for _,name in ipairs({'LemonStand','LemonDash'})do
        local source=node(name,{Enabled=true});source.tag='Tycoon.Purchasable';source.Parent=own
        local stand=node(name);stand.Parent=source;stands[#stands+1]=stand
        local stream=node(name,{Automatic=true,Count=1,Value=0,Interval=-1,ValueMultiplier=0,RateMultiplier=0})
        streams.children[name]=stream;stream.Parent=streams
        local remote=node('Upgrade',nil,nil,'RemoteFunction');stand.children.Upgrade=remote;remote.Parent=stand
        function remote:InvokeServer(n)
            calls[#calls+1]={kind='stand',name=name,units=n,tier=powers.attrs.UpgradeStack}
            local old=levels.attrs[name] or 0;local price=M.price(name,old,n,0)
            assert(price<values.attrs.Cash,'shared cash overdrawn')
            values.attrs.Cash=M.sub(values.attrs.Cash,price);values.attrs.CashSpent=c.PrestigeMath.add(values.attrs.CashSpent,price)
            levels.attrs[name]=old+n;stream.attrs.Count=old+n+1
        end
    end
    local pr=node('UpgradePowerLevel',nil,nil,'RemoteFunction');remotes.children.UpgradePowerLevel=pr;pr.Parent=remotes
    function pr:InvokeServer(name,n)
        assert(name=='UpgradeStack' and n==1)
        local level=powers.attrs.UpgradeStack;local price=math.log10(c.GameBalance.Powers.UpgradeStack.Prices[level+1])
        local old=values.attrs.Investors;assert(price<old)
        values.attrs.Investors=M.sub(old,price)
        values.attrs.InvestorsSpent=c.PrestigeMath.add(values.attrs.InvestorsSpent,price)
        local before=M.add(0,old+math.log10(.04));local after=M.add(0,values.attrs.Investors+math.log10(.04))
        income.attrs.ValueMultiplier=income.attrs.ValueMultiplier+after-before
        powers.attrs.UpgradeStack=level+1;calls[#calls+1]={kind='power',tier=level+1}
    end
    local r={phase='BUY',blocked={},spent=B.new(0),powerUsed=B.new(0),powerBase=M.bn(bank),cards={},evo={index=4}}
    local h={mode='PREPARE'}
    c.S={running=true,resetEnabled=true,epoch=1,counts={power=0,upgrade=0},upgradeVisited={}}
    c.env={};c.player=player;c.API={};c.paths={cards='NONE'}
    c.now=function()return time end;c.live=function()return c.S.running end;c.log=function()end;c.status=function()end
    c.pause=function(k)c.S.running=false;c.S.code=k end
    c.readCards=function()error('GUI')end;c.manageTab=function()error('GUI')end;c.focusCandidate=function()error('GUI')end
    c.cash=function()error('GUI')end;c.g=function()error('GUI')end;c.readPowers=function()error('GUI')end;c.Powers={}
    c.Strategy={route=function()return r end,phase=function(p)r.phase=p end,cancelResetIntent=function()end,
        actionSeconds=function()return .05 end,recordTiming=function()end,syncPowerBank=function()end,
        recordSpend=function(p)r.spent=B.add(r.spent,p)end,receipt=function()end}
    c.progress=function(k)c.S.counts[k]=(c.S.counts[k] or 0)+1 end
    c.HaloRun={state=function()return h end,plan=function()end,deferEvolution=function()return false end,
        selectEvolution=function()end,performReset=function()calls[#calls+1]={kind='rebirth'};return true end}
    c.Strategy.reserveEvolution=function()calls[#calls+1]={kind='evolve'};r.phase='EVOLVE_RESERVE'end
    local environment=setmetatable({game={PlaceId=79268393072444,GetService=function(_,name)
        return name=='Workspace' and world or name=='CollectionService' and {GetTagged=function()return stands end}end},
        task={spawn=function(fn)queue[#queue+1]=fn end,wait=function(dt)
            time=time+dt;local q=queue;queue={}
            -- Stand dispatch must queue both jobs before observing receipts.
            for _,fn in ipairs(q)do fn()end
        end}}, {__index=getfenv()})
    c.Safety={};require('../src/runtime/Transactions')(c)
    local init=require('../src/adapters/DirectUpgrades');setfenv(init,environment);init(c);c.DirectUpgrades.verified=true
    init=require('../src/adapters/DirectPurchases');setfenv(init,environment);init(c)
    c.DirectPrestige={snapshot=function()
        local d={snapshot=c.DirectUpgrades.state()}
        for _,k in ipairs({'Cash','CashSpent','Investors','InvestorsSpent'})do d[k]=values.attrs[k]end
        d.reward=c.PrestigeMath.reward(d.Cash,d.CashSpent,d.Investors,d.InvestorsSpent);return d
    end}
    c.readInvestors=function()
        local d=c.DirectPrestige.snapshot()
        return {investors=M.bn(d.Investors),reward=d.reward and M.bn(d.reward) or B.new(0),perInvestor=.04,
            ready=d.reward and d.reward>=0,time=time}
    end
    c.readEvolution=function()
        local d=c.DirectPrestige.snapshot();local progress=c.PrestigeMath.evolution(4,d.Investors,d.InvestorsSpent,d.reward)
        return {index=4,ready=progress>=1,time=time}
    end
    c.DirectPurchases.remaining=function()return h.remaining end
    require('../src/strategy/GoalDirector')(c)
    local function advance(dt)time=time+dt end
    return c,calls,values,powers,levels,r,h,advance,income
end
-- Affordable MAX with useful output: buy the chain, then upgrade both stands
-- in one parallel wave. No base, tablet, GUI or old full-pass routine exists here.
do
    local c,calls,v,p,l,r=fixture(64,170,160,0)
    local first=assert(c.GoalDirector.choose(c.readInvestors()))
    assert(first.choice=='POWER' and first.candidate.tier==4,first.choice..' '..tostring(first.candidate.tier))
    for _=1,4 do assert(c.GoalDirector.repeatStep() and c.S.running,c.S.code)end
    assert(p.attrs.UpgradeStack==4 and #calls==4)
    c.GoalDirector.repeatStep()
    assert(#calls==6 and calls[5].kind=='stand' and calls[6].kind=='stand')
    assert(calls[5].units>100 and calls[6].units>100)
    assert(c.S.counts.power==4 and c.S.counts.upgrade==2)
    assert(not c.S.actionPending and next(r.blocked)==nil)
end
print('PASS adaptive MAX chain then two parallel stand receipts before any rebirth, with investor debits and shared cash')
do
    local c,calls,v,p=fixture(40,100,108,2)
    local d=c.GoalDirector.choose(c.readInvestors())
    assert(d.choice=='POWER' and d.candidate.tier==3,d.choice..' tier='..tostring(d.candidate.tier))
    c.GoalDirector.repeatStep();c.GoalDirector.repeatStep()
    assert(p.attrs.UpgradeStack==3 and #calls==3)
    assert(calls[2].units==100 and calls[3].units==100)
end
print('PASS +100 is used when MAX is unaffordable; no forced +1 or full-base preparation')
do
    local c,calls,v=fixture(3,150,30,0)
    assert(c.GoalDirector.choose(c.readInvestors()).choice=='REBIRTH')
    c.GoalDirector.repeatStep();assert(#calls==1 and calls[1].kind=='rebirth')
end
print('PASS a large already-earned reward can skip unnecessary stand and power preparation')
do
    local c,calls,v=fixture(64,130,150,4)
    local d=c.GoalDirector.choose(c.readInvestors())
    assert(d.choice~='REBIRTH','tiny ready reward must not cause an immediate reset')
    c.GoalDirector.repeatStep();assert(#calls==0 or calls[1].kind=='stand')
end
print('PASS weak ready reward chooses stand growth or observation instead of rebirth spam')
do
    local c,calls,v,p,l,r,h,advance=fixture(64,220,160,0)
    c.GoalDirector.tick(false);assert(#calls==1 and calls[1].kind=='evolve')
    r.phase='BUY';h.nextGoalRead=nil;h.remaining={cost=c.BN.new(1),cash=c.BN.new(2),count=10}
    c.GoalDirector.tick(false);assert(#calls==1 and r.phase=='BUY')
end
print('PASS ready evolution and funded complete Halo bypass tactical spending and rebirth')





-- A stored positive decision is cancelled when the same fresh bank now has
-- productive preparation available. Readiness by itself must not reuse it.
do
    local c,calls,v,p,l,r,h,advance,income=fixture(3,150,30,0)
    local first=c.GoalDirector.choose(c.readInvestors());assert(first.choice=='REBIRTH')
    r.resetIntent={detail=first};assert(c.GoalDirector.validate(c.readInvestors()))
    v.attrs.Investors=64;v.attrs.Cash=170;income.attrs.ValueMultiplier=160
    assert(not c.GoalDirector.validate(c.readInvestors()),'new MAX opportunity must invalidate the old reset decision')
    assert(#calls==0)
end
-- A quote changing between planning and dispatch must not buy any power.
do
    local c,calls,v,p,l,r=fixture(64,170,160,0)
    local item
    for _,q in ipairs(c.DirectPurchases.powers())do if q.name=='UpgradeStack' then item=q end end
    v.attrs.Cash=220 -- evolution became ready before the dispatch validator.
    c.GoalDirector.power(item)
    assert(#calls==0 and not r.powerUnresolved and c.S.running)
end
-- Spending too much on Stack can destroy the gain even though it is affordable.
-- The normal five-percent policy remains on untargeted Powers; tactical Stack
-- uses a fresh economic comparison including its total investor debit.
do
    local c,calls,v,p,l,r=fixture(64,170,160,3)
    local item
    for _,q in ipairs(c.DirectPurchases.powers())do if q.name=='UpgradeStack' then item=q end end
    assert(not c.Planner.powerBudgetAllows(item.price,c.readInvestors().investors,r.powerUsed,r.powerBase,c.CONFIG))
    assert(c.GoalDirector.choose(c.readInvestors()).choice=='POWER')
    c.GoalDirector.repeatStep();assert(#calls==1 and calls[1].tier==4)
    c.CONFIG.AutoInvestorPowers=false;p.attrs.UpgradeStack=0
    local d=c.GoalDirector.choose(c.readInvestors());assert(d.choice~='POWER')
end
print('PASS final economic revalidation, newly ready evolution, useful MAX above the old 5% budget, and disabled power policy')
