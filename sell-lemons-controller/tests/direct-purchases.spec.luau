local initialize=require('../src/adapters/DirectPurchases')
local function fixture(mode)
    local c={};require('../src/config')(c);require('../src/core/Numeric')(c);c.BN=c.Core.BN
    require('../src/data/GameBalance')(c);require('../src/core/UpgradeMath')(c);require('../src/core/EconomyPlanner')(c)
    local time=0;local queue={};local calls={}
    local function object(name,attrs,children)
        local o={Name=name,attrs=attrs or {},children=children or {},ClassName='Configuration'}
        function o:GetAttribute(n)return self.attrs[n]end
        function o:FindFirstChild(n)return self.children[n]end
        function o:IsA(n)return self.ClassName==n end
        function o:IsDescendantOf(p)return self.Parent==p end
        return o
    end
    local values=object('Values',{Cash=9,Investors=40,Ascension=0,Evolution=2,BuyNextUses=10,Rebirths=1})
    local powers=object('Powers',{UpgradeStack=1},{Permanent=object('Permanent',{UpgradeStack=1,BuyNext=3})})
    local ledger=object('Purchases')
    for _,key in ipairs(c.GameBalance.PurchaseOrder)do ledger.attrs[key]=true end
    ledger.attrs.Juicer=nil;ledger.attrs.CupStand=nil
    local root=object('Values',{}, {Purchases=ledger});local own=object('Tycoon7')
    local nextItem=object('Juicer',{Enabled=true,DisplayName='Lime Juicer'});nextItem.Parent=own
    local second=object('Cup Stand',{Enabled=false});second.Parent=own
    local tagged={nextItem,second}
    local remote=object('Purchase');remote.ClassName='RemoteFunction';nextItem.children.Purchase=remote
    local remote2=object('Purchase');remote2.ClassName='RemoteFunction';second.children.Purchase=remote2
    local pRemote=object('UpgradePowerLevel');pRemote.ClassName='RemoteFunction';own.children.Remotes=object('Remotes',{}, {UpgradePowerLevel=pRemote})
    local function buy(target,key,isRemote,permanent)
        assert(isRemote==true and permanent==false,'ordinary Buy must not consume a forever purchase')
        calls[#calls+1]={'buy',key}
        if mode=='reject' or values.attrs.reject then error('server rejection')end
        if mode=='silent' then return end
        local cost=c.GameBalance.PurchasePrices[key];assert(values.attrs.Cash>=cost)
        values.attrs.Cash=c.UpgradeMath.sub(values.attrs.Cash,cost);ledger.attrs[key]=true
        if mode=='reset' then values.attrs.Evolution=3;ledger.attrs[key]=nil end
        second.attrs.Enabled=true
    end
    function remote:InvokeServer(...)buy(nextItem,'Juicer',...)end
    function remote2:InvokeServer(...)buy(second,'CupStand',...)end
    function pRemote:InvokeServer(name,n)
        assert(name=='UpgradeStack' and n==1);calls[#calls+1]={'power',name,n}
        if mode=='silent-power' then return end
        local nextLevel=powers.attrs[name]+powers.children.Permanent.attrs[name]+1
        local cost=math.log10(c.GameBalance.Powers[name].Prices[nextLevel]);assert(values.attrs.Investors>=cost)
        values.attrs.Investors=c.UpgradeMath.sub(values.attrs.Investors,cost);powers.attrs[name]=powers.attrs[name]+1
    end
    c.DirectUpgrades={state=function()
        return {own=own,root=root,values=values,powers=powers,cash=values.attrs.Cash,shift=0,
            epoch={Evolution=values.attrs.Evolution,Ascension=0,Rebirths=values.attrs.Rebirths,TotalRebirths=values.attrs.TotalRebirths,TotalEvolves=values.attrs.TotalEvolves}}
    end}
    c.S={running=true,epoch=1,counts={buy=0}}
    c.now=function()return time end;c.live=function(epoch)return c.S.running and (not epoch or epoch==c.S.epoch)end
    c.log=function()end;c.pause=function(code)c.S.running=false;c.S.code=code end
    local function gui()error('GUI or mouse accessed')end
    c.readBuy=gui;c.ensureStrip=gui;c.manageTab=gui;c.ensureTablet=gui;c.focusCandidate=gui
    c.Powers={read=gui,proof=gui};c.HaloRun={tryBuyHold=gui}
    local route={blocked={},powerBase=c.BN.new(1,40),powerUsed=c.BN.new(0)}
    c.S.route=route
    c.Strategy={route=function()return c.S.route end,safePurchase=gui,
        new=function()return {phase='BOOT',blocked={},cards={},models={},bootEvolution=true,bootTablet=true,powerUsed=c.BN.new(0)}end}
    c.Safety={proof=gui,key=function(q)return q.path end,commit=function(rec)c.S.counts.buy=c.S.counts.buy+1;rec.committed=true end}
    local env=setmetatable({game={GetService=function(_,name)assert(name=='CollectionService');return {GetTagged=function(_,tag)assert(tag=='Tycoon.Purchase');return tagged end}end},
        task={spawn=function(fn)queue[#queue+1]=fn end,wait=function(dt)
            time=time+dt;if mode=='timeout' then return end
            local pending=queue;queue={};for _,fn in ipairs(pending)do fn()end
        end}}, {__index=getfenv()})
    setfenv(initialize,env);initialize(c)
    return c,values,powers,ledger,calls,queue,nextItem,route
end
local c,v,p,l,calls=fixture('ok');local q=assert(c.readBuy())
assert(q.key=='Juicer' and q.name=='Lime Juicer' and q.cost and q.available and q.source=='directBuy')
assert(c.ensureStrip() and c.manageTab('Powers') and c.ensureTablet() and not c.S.tablet.owned and c.canUpgrade())
assert(not c.HaloRun.tryBuyHold(q));assert(c.Strategy.safePurchase(q) and c.S.counts.buy==1 and #calls==1)
assert(not c.Strategy.safePurchase(q) and #calls==1,'old Buy quote must not purchase next building')
local nextQuote=assert(c.readBuy());assert(nextQuote.key=='CupStand');assert(c.Strategy.safePurchase(nextQuote))
assert(c.buyComplete() and c.S.counts.buy==2)
print('PASS ordinary Buy uses verified order, localized name, exact price, non-permanent arguments and ledger receipts without GUI')
local c,v,p,l,calls=fixture('ok');local items=c.Powers.read();local item=items[1]
assert(item.name=='UpgradeStack' and item.level==2 and item.priceLog==33 and item.bonus=='+25')
assert(c.DirectPurchases.powerPurchase(item) and c.Powers.proof(item) and #calls==1)
assert(not c.DirectPurchases.powerPurchase(item) and #calls==1)
local expensive=c.Powers.read()[1];assert(expensive.level==3 and expensive.priceLog==63 and not expensive.available)
assert(not c.DirectPurchases.powerPurchase(expensive) and #calls==1)
print('PASS Powers merges permanent levels, spends investors once, verifies exact level and rejects unfunded next tier')
for _,mode in ipairs({'reject','silent','reset'})do
    local c,_,_,_,calls=fixture(mode);local q=assert(c.readBuy())
    assert(not c.Strategy.safePurchase(q) and c.S.counts.buy==0 and #calls==1 and not c.S.running)
    assert(not c.Strategy.safePurchase(q) and #calls==1)
end
local c,_,_,_,calls,queue=fixture('timeout');local q=assert(c.readBuy())
assert(not c.Strategy.safePurchase(q) and c.S.actionPending and #calls==0)
c.S.running=false
for _,fn in ipairs(queue)do fn()end
assert(#calls==0 and not c.S.actionPending)
print('PASS Buy rejection, silence, reset, pending timeout and late cancellation never authorize duplicate requests')
local c,v,p,l,calls,_,o,r=fixture('ok');p.children.Permanent.attrs.BuyNext=1;v.attrs.BuyNextUses=150
local q=assert(c.readBuy());assert(not q.available and not c.Strategy.safePurchase(q) and #calls==0)
p.children.Permanent.attrs.BuyNext=3;o.attrs.Special=true
local special=assert(c.readBuy(),'Special disables permanent buying; it does not disable an ordinary cash purchase')
assert(c.Strategy.safePurchase(special) and #calls==1 and l.attrs.Juicer==true)
local item=c.Powers.read()[1];r.powerUsed=c.BN.new(1,39)
assert(not c.DirectPurchases.powerPurchase(item) and #calls==1,'cumulative investor retention must survive repeated scans')
local c=fixture('silent-power');local item=c.Powers.read()[1]
assert(not c.DirectPurchases.powerPurchase(item) and not c.Powers.proof(item))
print('PASS special cash purchase succeeds; exhausted Buy uses, protected bank and missing receipts retain their guards')
local c,v,p,l,calls,_,o,r=fixture('ok')
assert(c.DirectPurchases.refreshEpoch());v.attrs.reject=true
assert(not c.Strategy.safePurchase(assert(c.readBuy())) and #calls==1 and next(r.blocked))
c.S.running=true
assert(c.DirectPurchases.refreshEpoch() and next(c.Strategy.route().blocked),'same-cycle error must remain blocked')
v.attrs.Cash=8;assert(c.DirectPurchases.refreshEpoch() and next(c.Strategy.route().blocked),'wallet drop alone is not reset evidence')
v.attrs.Evolution=nil
assert(not c.DirectPurchases.refreshEpoch() and next(c.Strategy.route().blocked),'missing counters cannot clear a block')
v.attrs.Evolution=3;c.S.actionPending={}
assert(not c.DirectPurchases.refreshEpoch() and next(c.Strategy.route().blocked),'pending requests keep their lock even after reset')
c.S.actionPending=nil;v.attrs.reject=nil
assert(c.DirectPurchases.refreshEpoch())
local fresh=c.Strategy.route()
assert(fresh~=r and fresh.phase=='BOOT' and not next(fresh.blocked) and c.S.counts.buy==0 and #calls==1)
assert(c.Strategy.safePurchase(assert(c.readBuy())) and #calls==2 and c.S.counts.buy==1,'new-cycle quote must remain usable after old disabled purchase')
local c,v,_,_,_,_,_,r=fixture('ok');assert(c.DirectPurchases.refreshEpoch())
local item=c.Powers.read()[1];r.powerUnresolved={item=item};r.powerUsed=c.BN.new(1,20)
v.attrs.Rebirths=2;assert(c.DirectPurchases.refreshEpoch())
local fresh=c.Strategy.route()
assert(fresh.powerBase==r.powerBase and fresh.powerUsed==r.powerUsed and not fresh.powerUnresolved,'rebirth must retain the investor budget, while retiring previous-cycle outcomes')
assert(c.DirectPurchases.refreshEpoch() and c.Strategy.route()==fresh,'same counter sample must not restart the route repeatedly')
print('PASS rejected Buy followed by external evolution resumes with fresh quotes; uncertain counters and pending requests retain blocks; rebirth preserves spending budget')
