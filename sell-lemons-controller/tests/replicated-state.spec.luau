local init=require('../src/runtime/ReplicatedState')
local function obj(name,attrs,kids)
    local o={Name=name,attrs=attrs or {},kids=kids or {}}
    function o:GetChildren()return self.kids end
    function o:FindFirstChild(n)for _,v in ipairs(self.kids)do if v.Name==n then return v end end end
    function o:GetAttributes()return self.attrs end
    for _,v in ipairs(o.kids)do v.Parent=o end
    return o
end
local player={};local owner=obj('Owner');owner.Value=player
local values=obj('Values',{Cash=208.3515191634644,Investors=65.63493889154753,CashSpent=206.81176404136997,
    InvestorsSpent=63,Evolution=5,Ascension=23,Rebirths=5,TotalRebirths=1099,TotalEvolves=161})
local levels=obj('Upgrades',{LemonStand=3025,LemonDash=2380,LemonDepot=1726,LemonLabs=1052,
    LemonTrading=3495,LemonRobotics=1666,LemonRepublic=988,LemonX=458})
local root=obj('Tycoon2',{}, {owner,obj('Values',{}, {values,levels})})
local world=obj('Workspace',{}, {root})
local clock=0;local visible=true;local bankVisible=false;local cashLog=values.attrs.Cash
local ctx={player=player,S={},paths={investors='Investors'},API={},log=function()end,now=function()return clock end,
    prop=function(o,k)return o and o[k]end,g=function(path)return path end,
    visible=function()return bankVisible end,t=function(path)
        return path:find('What',1,true) and 'investors' or '4.314584e65'
    end}
require('../src/core/Numeric')(ctx);ctx.BN=ctx.Core.BN
ctx.cash=function()
    if visible then local e=math.floor(cashLog);return ctx.BN.new(10^(cashLog-e),e)end
end
setfenv(init,setmetatable({game={GetService=function()return world end}},{__index=getfenv()}));init(ctx)
local function sample()clock=clock+0.3;return ctx.API.dataSnapshot()end
local a=sample()
assert(a.raw.Cash==208.3515191634644 and a.amounts.Cash==nil,'encoded 208 must not be spent as 208 dollars')
assert(a.counters.Evolution==5 and a.counters.Ascension==23 and a.upgrades.LemonStand==3025)
sample();local b=sample()
assert(b.encodings.Cash=='log10' and math.abs(ctx.BN.log(b.amounts.Cash)-values.attrs.Cash)<1e-10)
assert(b.amounts.Investors==nil and b.amounts.CashSpent==nil,'field encodings must not be borrowed')
print('PASS actual log fixture stays unknown until independent visible calibration')
visible=false;values.attrs.Cash=1000.75
local hidden=ctx.cash()
assert(hidden and hidden.e==1000 and math.abs(hidden.m-10^0.75)<1e-10,'large decoded amounts must not overflow')
levels.attrs.LemonStand=3026
assert(sample().upgrades.LemonStand==3026,'hidden upgrades must remain live')
print('PASS hidden values refresh and exponents beyond floating point range are retained')
bankVisible=true;sample();sample();local bank=sample()
assert(bank.encodings.Investors=='log10' and bank.amounts.Investors.e==65)
assert(bank.amounts.InvestorsSpent==nil)
print('PASS bank has independent calibration; spending remains unverified')
local invalidations=0;ctx.Observer={store={invalidate=function()invalidations=invalidations+1 end}}
bankVisible=false;values.attrs.Rebirths=6
local afterReset=sample()
assert(afterReset.amounts.Cash==nil and afterReset.amounts.Investors==nil and invalidations==1)
print('PASS reset counters invalidate encodings and stale GUI cache')
values.attrs.Cash=0
assert(ctx.cash()==nil,'unknown log zero sentinel must not become one dollar')
print('PASS unknown zero sentinel has no inferred amount')
visible=true;values.attrs.Cash=100;cashLog=2
sample();sample();local linear=sample()
assert(linear.encodings.Cash=='linear' and ctx.BN.number(linear.amounts.Cash)==100)
cashLog=10
assert(sample().amounts.Cash==nil,'visible mismatch must revoke cached encoding')
print('PASS independently matching linear encoding and mismatch revocation')
owner.Value={};visible=false
assert(ctx.API.dataSnapshot()==nil and ctx.cash()==nil,'ownership loss must clear all values')
assert(ctx.Data.root==nil and next(ctx.Data.modes)==nil)
print('PASS ownership loss clears binding and cached calibration')
owner.Value=player;values.GetAttributes=function()error('destroyed')end
assert(ctx.API.dataSnapshot().raw.Cash==nil and ctx.cash()==nil)
print('PASS missing attributes never reuse a previous bank or cash balance')
