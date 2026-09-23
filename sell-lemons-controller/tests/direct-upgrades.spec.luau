local initNumeric=require('../src/core/Numeric')
local initBalance=require('../src/data/GameBalance')
local initMath=require('../src/core/UpgradeMath')
local initDirect=require('../src/adapters/DirectUpgrades')
local initPlanner=require('../src/core/EconomyPlanner')
local initTransactions=require('../src/runtime/Transactions')
local initPurchases=require('../src/adapters/DirectPurchases')
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
    local joint=mode:sub(1,5)=='joint'
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
    local values=object('Values',{Cash=mode=='poor' and -math.huge or mode=='zero-string' and '0' or 8,Ascension=0,Evolution=5})
    local powers=object('Powers',{UpgradeStack=4},{Permanent=object('Permanent'),Selected=object('Selected')})
    if mode=='power-change' or mode=='before-power-change' then powers.attrs.UpgradeStack=0 end
    if mode=='selected-one' then powers.attrs.UpgradeStack=1;powers.children.Selected.attrs.UpgradeStack=0 end
    local streams=object('Streams')
    local income=object('Income',{ValueMultiplier=0,RateMultiplier=0},{Streams=streams})
    local inversion=object('InversionCards',mode=='inversion' and {UnknownCard=1} or {})
    local rootValues=object('Values',{}, {Values=values,Upgrades=levels,Powers=powers,Income=income,InversionCards=inversion})
    if mode=='missing-inversion' or mode=='inversion-not-replicated' then rootValues.children.InversionCards=nil end
    if mode=='inversion-not-replicated' then values.attrs.Inversion=1 end
    local owner=object('Owner');owner.ClassName='ObjectValue';owner.Value=player
    local own=object('Tycoon7',{}, {Values=rootValues,Owner=owner});local world=object('Workspace',{}, {Tycoon7=own})
    local purchasables={};local ledger
    if joint then
        values.attrs.Cash=mode=='joint-buy-only' and 99 or 100;powers.children.Permanent.attrs.BuyNext=3
        c.GameBalance.PurchasePrices.Juicer=99
        ledger=object('Purchases');ledger.Parent=rootValues;rootValues.children.Purchases=ledger
        for _,key in ipairs(c.GameBalance.PurchaseOrder)do ledger.attrs[key]=true end
        ledger.attrs.Juicer=nil
        local buy=object('Juicer',{Enabled=true});buy.Parent=own;purchasables[1]=buy
        local remote=object('Purchase');remote.ClassName='RemoteFunction';remote.Parent=buy;buy.children.Purchase=remote
        function remote:InvokeServer(isRemote,permanent)
            assert(isRemote==true and permanent==false)
            calls[#calls+1]={name='buy',n=1}
            if mode=='joint-reject-buy' then error('Buy rejected')end
            assert(values.attrs.Cash>=99,'construction reservation was spent on upgrades')
            values.attrs.Cash=c.UpgradeMath.sub(values.attrs.Cash,99);paid[#paid+1]=99
            ledger.attrs.Juicer=true
        end
    end
    local tagged={}
    for _,name in ipairs({'LemonStand','LemonDash'})do
        local purchase=object(name,{Enabled=true});purchase.tag='Tycoon.Purchasable';purchase.Parent=own
        local stand=object(name);stand.Parent=purchase
        local remote=object('Upgrade');remote.ClassName='RemoteFunction';remote.Parent=stand;stand.children.Upgrade=remote
        local stream=object(name,{Automatic=true,Count=1,Value=c.GameBalance.EarnerIncomes[name],Interval=0,ValueMultiplier=0,RateMultiplier=0})
        stream.Parent=streams;streams.children[name]=stream
        function remote:InvokeServer(n)
            assert(#calls<(joint and 3 or 2) and n>=1 and n%1==0);calls[#calls+1]={name=name,n=n}
            if mode=='reject' or mode=='joint-reject-stand' and name=='LemonDash' then error('rejected')end
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
        if name=='CollectionService' then return {GetTagged=function(_,tag)return tag=='Tycoon.Purchase' and purchasables or tagged end}end
        error('unexpected service '..name)
    end},task={spawn=function(fn)queue[#queue+1]=fn end,wait=function(dt)
        time=time+dt
        if mode=='timeout' then return end
        local pending=queue;queue={}
        local expected=(mode=='joint-buy-only' or mode=='joint-finish') and 1 or joint and 3 or 2
        assert(#pending==0 or #pending==expected,'all parallel requests must be queued before waiting')
        if mode=='before-power-change' then powers.attrs.UpgradeStack=1 end
        if mode=='joint-reverse' then
            for i=#pending,1,-1 do pending[i]()end
        else for _,fn in ipairs(pending)do fn()end end
        if mode=='power-change' then powers.attrs.UpgradeStack=1 end
    end}}, {__index=getfenv()})
    c.env={};c.CONFIG={DirectUpgrades=true,DirectPurchases=joint};c.player=player;c.S={epoch=1,running=true,counts={upgrade=0,buy=0},upgradeVisited={}}
    c.now=function()return time end;c.live=function(epoch)return c.S.running and (not epoch or epoch==c.S.epoch)end
    c.log=function(k,v)logs[#logs+1]=k..' '..v end
    c.pause=function(code)c.S.running=false;c.S.code=code end
    c.readCards=function()error('GUI cards accessed')end;c.manageTab=function()error('GUI navigation attempted')end
    c.focusCandidate=function()error('GUI focus attempted')end;c.cash=function()error('GUI cash accessed')end
    c.API={};c.paths={cards='GUI'};local route={blocked={},pass={purchases=0,levels=0}}
    c.Strategy={route=function()return route end,receipt=function(q)assert(q.source=='direct' or q.source=='directBuy');end,recordTiming=function()end}
    c.Safety={};initTransactions(c)
    c.g=function()error('receipt must not inspect GUI')end
    c.progress=function(kind)c.S.counts[kind]=c.S.counts[kind]+1 end
    setfenv(initDirect,env);initDirect(c);c.DirectUpgrades.verified=true
    if joint then
        c.Powers={};c.HaloRun={state=function()return {mode='PREPARE'}end}
        c.Strategy.safePurchase=function(q)
            if route.blocked[c.Safety.key(q)]then return false end
            return c.DirectUpgrades.purchase(q)
        end
        setfenv(initPurchases,env);initPurchases(c)
    end
    return c,values,levels,calls,logs,queue,powers,own
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
local c,values,_,calls=fixture('zero-string');local s=assert(c.DirectUpgrades.state())
assert(s.cash==-math.huge and c.cash().m==0)
assert(#c.DirectUpgrades.allocate(s,c.DirectUpgrades.cards(s))==0 and #calls==0)
values.attrs.Cash=0;assert(c.DirectUpgrades.state().cash==0 and c.cash().m==1)
print('PASS replicated string zero cash differs from numeric log10 zero and never authorizes unfunded upgrades')
do
    local c,_,levels,calls=fixture('power-change');local D=c.DirectUpgrades
    local s=assert(D.state());assert(s.cap==1)
    local rows=D.allocate(s,D.cards(s));local ok,records=D.dispatch(rows,s)
    assert(ok and #calls==2 and c.S.running and c.now()<1)
    assert(D.state().cap==5 and not D.same(s,D.state()) and D.sameCycle(s,D.state()))
    assert(levels.attrs.LemonStand==1 and levels.attrs.LemonDash==1 and c.S.counts.upgrade==2)
    assert(not next(c.Strategy.route().blocked) and c.Strategy.route().pass.purchases==2)
    c.Safety.commit(records[1],true);assert(c.S.counts.upgrade==2,'receipt committed twice')
end
print('PASS report regression: +1 receipts remain valid when UpgradeStack becomes +5 during the parallel response')
do
    local c,_,_,calls=fixture('before-power-change');local D=c.DirectUpgrades
    local s=assert(D.state());local rows=D.allocate(s,D.cards(s))
    assert(not D.dispatch(rows,s))
    assert(#calls==0 and c.S.running and c.now()<1 and not c.S.actionPending and not next(c.Strategy.route().blocked))
end
print('PASS a tier change before dispatch replans immediately without sending, waiting eight seconds or pausing')
do
    local c,_,levels,calls=fixture('selected-one');local D=c.DirectUpgrades
    local s=assert(D.state());assert(s.cap==5 and s.selectedStack==0)
    local rows=D.allocate(s,D.cards(s));assert(D.dispatch(rows,s))
    assert(#calls==2 and calls[1].n==5 and calls[2].n==5)
    assert(levels.attrs.LemonStand==5 and levels.attrs.LemonDash==5)
end
print('PASS purchased +5 used in parallel despite GUI +1 selection; shared wallet and owned tier remain enforced')
for _,spec in ipairs({{2,25},{3,100},{4,math.huge}})do
    local c,values,levels,calls,_,_,powers=fixture('selected-one');local D=c.DirectUpgrades
    values.attrs.Cash=200
    powers.attrs.UpgradeStack=spec[1]-1;powers.children.Permanent.attrs.UpgradeStack=1
    local s=assert(D.state());assert(s.cap==spec[2] and s.selectedStack==0)
    local rows=D.allocate(s,D.cards(s));assert(D.dispatch(rows,s) and #calls==2)
    for _,call in ipairs(calls)do
        assert(spec[2]==math.huge and call.n>100 or call.n==spec[2])
        assert(levels.attrs[call.name]==call.n)
    end
end
print('PASS +25, +100 and MAX owned tiers, including permanent levels, all ignore the stale GUI +1 selector')
do
    local c,values,levels,calls,_,_,_,own=fixture('silent');local D=c.DirectUpgrades
    local s=assert(D.state());local rows=D.allocate(s,D.cards(s));local ok,records=D.dispatch(rows,s)
    assert(not ok and #calls==2 and c.S.counts.upgrade==0)
    local rec=records[1];levels.attrs[rec.c.key]=rec.c.level+rec.c.units
    assert(c.Safety.proof(rec),'late exact replicated receipt was ignored')
    c.Safety.commit(rec,true);c.Safety.commit(rec,true)
    assert(c.S.counts.upgrade==1 and not c.Strategy.route().blocked[c.Safety.key(rec.c)])
    assert(#calls==2,'receipt reconciliation sent a duplicate')
    local other=records[2];levels.attrs[other.c.key]=other.c.level+other.c.units-1
    assert(not c.Safety.proof(other))
    levels.attrs[other.c.key]=other.c.level+other.c.units;values.attrs.Evolution=6
    assert(not c.Safety.proof(other),'reset must invalidate a late receipt')
    values.attrs.Evolution=5;own.children.Owner.Value={};assert(not c.Safety.proof(other),'ownership changed')
end
print('PASS late receipt resolves exactly once from replicated levels; partial progress, reset and changed owner stay unresolved')
do
    local c=fixture('ok');require('../src/strategy/ResetPlanning')(c)
    c.CONFIG.InitialFullLayoutSeconds=150;c.CONFIG.InitialMenuTripSeconds=3;c.CONFIG.DirectPurchases=true
    local r=c.Strategy.route();r.runBuyCount=200;r.cards={}
    for i=1,7 do r.cards[i]={path='direct/'..i,count='500',source='direct'}end
    c.Strategy.largestBatch=function()return 1 end
    c.Strategy.actionSeconds=function()return .14 end
    local seconds,why=c.Strategy.rebuildInputSeconds()
    assert(seconds==150 and why:find('parallel',1,true),'parallel inputs were charged seven times')
    r.cards[1].count='1001'
    local one=c.Strategy.rebuildInputSeconds();assert(math.abs(one-168.14)<.00001)
    local five=c.Strategy.rebuildInputSeconds({canBuyAfter=true,nextBatch=5});assert(five==150)
    for _,q in ipairs(r.cards)do q.source=nil end
    local gui=c.Strategy.rebuildInputSeconds();assert(gui>550,'serial GUI cost must remain serial')
end
print('PASS rebuild estimate charges concurrent upgrade rounds once and preserves financing allowance; GUI remains serial')
for _,mode in ipairs({'joint','joint-reverse'})do
    local c,values,levels,calls=fixture(mode)
    assert(c.Strategy.safePurchase(assert(c.readBuy())))
    assert(#calls==3 and c.S.counts.buy==1 and c.S.counts.upgrade==2 and c.S.running and not c.S.actionPending)
    assert(levels.attrs.LemonStand>100 and levels.attrs.LemonDash>100 and values.attrs.Cash<100)
    assert(not next(c.Strategy.route().blocked))
end
print('PASS real Buy and upgrade adapters dispatch construction plus all stands before waiting; one wallet stays funded in either response order')
for _,mode in ipairs({'joint-reject-buy','joint-reject-stand'})do
    local c,_,_,calls=fixture(mode);c.Strategy.safePurchase(assert(c.readBuy()))
    assert(#calls==3 and not c.S.running and not c.S.actionPending)
    assert(c.S.counts.buy==(mode=='joint-reject-buy' and 0 or 1))
    assert(c.S.counts.upgrade==(mode=='joint-reject-buy' and 2 or 1))
    local blocked=c.Strategy.route().blocked;local count=0;for _ in pairs(blocked)do count=count+1 end
    assert(count==1,'successful parallel peers must not be blocked')
    for _,v in pairs(blocked)do
        assert(not c.Safety.proof(v.receipt))
        assert(not c.Strategy.safePurchase(v.c) and #calls==3,'unresolved request was repeated')
    end
end
print('PASS joint wave records successful peers independently, keeps the failed outcome blocked and never resubmits it')
for _,mode in ipairs({'joint-buy-only','joint-finish'})do
    local c,_,_,calls=fixture(mode)
    if mode=='joint-finish' then c.HaloRun.state=function()return {mode='FINISH',remaining={cost=c.BN.new(1,100)}}end end
    assert(c.Strategy.safePurchase(assert(c.readBuy())))
    assert(#calls==1 and calls[1].name=='buy' and c.S.counts.buy==1 and c.S.counts.upgrade==0 and c.S.running)
end
print('PASS construction-only wallet and funded FINISH reservation cannot be consumed by concurrent upgrades')
do
    local c=fixture('joint');require('../src/strategy/Growth')(c)
    assert(c.Strategy.safePurchase(assert(c.readBuy())))
    local r=c.Strategy.route()
    assert(r.timings.buy.count==1 and r.timings.upgrade.count==1 and r.runUpgradeActions==1)
    assert(r.runServiceSeconds==r.timings.buy.total,'overlapping response time was charged twice')
end
print('PASS shared build/upgrade wall time is charged once while both action latency measurements are retained')
