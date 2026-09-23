local initNumeric=require('../src/core/Numeric')
local initBalance=require('../src/data/GameBalance')
local initMath=require('../src/core/UpgradeMath')
local initDirect=require('../src/adapters/DirectUpgrades')
local initPlanner=require('../src/core/EconomyPlanner')
local function base()
    local ctx={};initNumeric(ctx);ctx.BN=ctx.Core.BN;initBalance(ctx);initMath(ctx);initPlanner(ctx);return ctx
end
local ctx=base();local M=ctx.UpgradeMath
assert(#ctx.GameBalance.UpgradePrices.LemonStand==3768)
assert(math.abs(M.price('LemonStand',0,1,0)-.7075701761)<1e-12)
local direct=0
for i=1,100 do direct=direct+10^ctx.GameBalance.UpgradePrices.LemonStand[i]end
assert(math.abs(M.price('LemonStand',0,100,0)-math.log10(direct))<1e-10)
assert(math.abs(M.price('LemonStand',0,100,23*math.log10(3.33))-math.log10(direct*3.33^23))<1e-10)
local expected=ctx.GameBalance.UpgradePrices.LemonStand[3768]+math.log10(2)*10^1.2/12
assert(math.abs(M.unit('LemonStand',3778)-expected)<1e-10)
for _,cash in ipairs({-math.huge,0,2,10,200,350})do
    local n,p=M.affordable('LemonStand',0,math.huge,cash,0)
    assert(n==0 or p<cash)
    assert(n==10000 or M.price('LemonStand',0,n+1,0)>cash-1e-9)
end
assert(M.bn(350).e==350 and M.bn(-math.huge).m==0)
print('PASS exact literal prices, cumulative sum, Halo penalty, tail formula, affordable maximum and large exponents')

local function fixture(mode)
    local c=base();local time=0;local queue={};local calls={};local logs={};local paid={};local player={}
    local function object(name,attrs,children)
        local o={Name=name,attrs=attrs or {},children=children or {}}
        function o:FindFirstChild(n)return self.children[n]end
        function o:GetChildren()local out={};for _,v in pairs(self.children)do out[#out+1]=v end;return out end
        function o:GetAttributes()return self.attrs end
        function o:GetAttribute(n)return self.attrs[n]end
        function o:HasTag(tag)return self.tag==tag end
        function o:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
        function o:IsA(class)return self.ClassName==class end
        for _,v in pairs(o.children)do v.Parent=o end
        return o
    end
    local levels=object('Upgrades',{})
    local values=object('Values',{Cash=mode=='poor' and -math.huge or 8,Ascension=0,Evolution=5})
    local powers=object('Powers',{UpgradeStack=4},{Permanent=object('Permanent'),Selected=object('Selected')})
    local streams=object('Streams')
    local income=object('Income',{ValueMultiplier=0,RateMultiplier=0},{Streams=streams})
    local inversion=object('InversionCards',mode=='inversion' and {UnknownCard=1} or {})
    local rootValues=object('Values',{}, {Values=values,Upgrades=levels,Powers=powers,Income=income,InversionCards=inversion})
    if mode=='missing-inversion' or mode=='inversion-not-replicated' then rootValues.children.InversionCards=nil end
    if mode=='inversion-not-replicated' then values.attrs.Inversion=1 end
    local owner=object('Owner');owner.ClassName='ObjectValue';owner.Value=player
    local own=object('Tycoon7',{}, {Values=rootValues,Owner=owner});local world=object('Workspace',{}, {Tycoon7=own})
    local tagged={}
    for _,name in ipairs({'LemonStand','LemonDash'})do
        local purchase=object(name,{Enabled=true});purchase.tag='Tycoon.Purchasable';purchase.Parent=own
        local stand=object(name);stand.Parent=purchase
        local remote=object('Upgrade');remote.ClassName='RemoteFunction';remote.Parent=stand;stand.children.Upgrade=remote
        local stream=object(name,{Automatic=true,Count=1,Value=c.GameBalance.EarnerIncomes[name],Interval=0,ValueMultiplier=0,RateMultiplier=0})
        stream.Parent=streams;streams.children[name]=stream
        function remote:InvokeServer(n)
            assert(#calls<2 and n>=1 and n%1==0);calls[#calls+1]={name=name,n=n}
            if mode=='reject' then error('rejected')end
            if mode=='silent' then return end
            local cost=c.UpgradeMath.price(name,levels.attrs[name] or 0,n,0)
            assert(cost<=values.attrs.Cash,'shared cash was overcommitted')
            values.attrs.Cash=c.UpgradeMath.sub(values.attrs.Cash,cost);paid[#paid+1]=cost
            levels.attrs[name]=(levels.attrs[name] or 0)+n;stream.attrs.Count=levels.attrs[name]+1
            if mode=='reset' then values.attrs.Evolution=6 end
        end
        tagged[#tagged+1]=stand
    end
    local env=setmetatable({game={PlaceId=79268393072444,GetService=function(_,name)
        if name=='Workspace' then return world end
        if name=='CollectionService' then return {GetTagged=function()return tagged end}end
        error('unexpected service '..name)
    end},task={spawn=function(fn)queue[#queue+1]=fn end,wait=function(dt)
        time=time+dt
        if mode=='timeout' then return end
        local pending=queue;queue={}
        assert(#pending==0 or #pending==2,'parallel batch must be queued before waiting')
        for _,fn in ipairs(pending)do fn()end
    end}}, {__index=getfenv()})
    c.env={};c.CONFIG={DirectUpgrades=true};c.player=player;c.S={epoch=1,running=true,counts={upgrade=0}}
    c.now=function()return time end;c.live=function(epoch)return c.S.running and (not epoch or epoch==c.S.epoch)end
    c.log=function(k,v)logs[#logs+1]=k..' '..v end
    c.pause=function(code)c.S.running=false;c.S.code=code end
    c.readCards=function()error('GUI cards accessed')end;c.manageTab=function()error('GUI navigation attempted')end
    c.focusCandidate=function()error('GUI focus attempted')end;c.cash=function()error('GUI cash accessed')end
    c.API={};c.paths={cards='GUI'};local route={blocked={},pass={purchases=0,levels=0}}
    c.Strategy={route=function()return route end,receipt=function(q)assert(q.source=='direct');end,recordTiming=function()end}
    c.Safety={key=function(q)return q.path end};c.progress=function()c.S.counts.upgrade=c.S.counts.upgrade+1 end
    setfenv(initDirect,env);initDirect(c);c.DirectUpgrades.verified=true
    return c,values,levels,calls,logs,queue
end
local c,values,levels,calls=fixture('ok');local D=c.DirectUpgrades
local state=assert(D.state());local cards=D.cards(state)
assert(#cards==2 and c.Planner.sourceRate(cards[1]))
local batch,total=D.allocate(state,cards);assert(#batch==2 and total<state.cash)
assert(c.manageTab('Manage') and #c.readCards()==2)
local success=D.dispatch(batch,state)
assert(success and #calls==2 and c.S.counts.upgrade==2 and not c.S.actionPending)
assert((levels.attrs.LemonStand or 0)>1 and (levels.attrs.LemonDash or 0)>1)
print('PASS two funded multi-level stand requests, no GUI navigation, fresh income and exact receipts')
for _,mode in ipairs({'silent','reject','reset'})do
    local c,_,_,calls=fixture(mode);local s=assert(c.DirectUpgrades.state());local rows=c.DirectUpgrades.allocate(s,c.DirectUpgrades.cards(s))
    assert(not c.DirectUpgrades.dispatch(rows,s));assert(c.S.counts.upgrade==0 and not c.S.running)
    assert(#calls==(mode=='reset' and 1 or 2))
end
print('PASS silent responses, server rejection and reset never count as successful purchases')
local c=fixture('inversion');local s,why=c.DirectUpgrades.state();assert(not s and why=='INVERSION_CARD_PRICING_NOT_VERIFIED')
local c=fixture('poor');local s=assert(c.DirectUpgrades.state());local rows=c.DirectUpgrades.allocate(s,c.DirectUpgrades.cards(s));assert(#rows==0)
local c,_,_,calls,_,queue=fixture('timeout');local s=assert(c.DirectUpgrades.state());local rows=c.DirectUpgrades.allocate(s,c.DirectUpgrades.cards(s))
assert(not c.DirectUpgrades.dispatch(rows,s));assert(c.S.actionPending and #calls==0)
for _,fn in ipairs(queue)do fn()end
assert(not c.S.actionPending and #calls==0,'paused late callbacks must not submit new actions')
print('PASS unknown price modifier, empty wallet, timeout lock and cancellation before late dispatch')
local c,_,_,calls=fixture('missing-inversion');local s=assert(c.DirectUpgrades.state())
local rows=c.DirectUpgrades.allocate(s,c.DirectUpgrades.cards(s));assert(c.DirectUpgrades.dispatch(rows,s) and #calls==2)
local c=fixture('inversion-not-replicated');local s,why=c.DirectUpgrades.state()
assert(not s and why=='INVERSION_PRICE_STATE_UNAVAILABLE')
print('PASS real Main-world missing InversionCards folder; nonzero inversion still requires replicated pricing state')
