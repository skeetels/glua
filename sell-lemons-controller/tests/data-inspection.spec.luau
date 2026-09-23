local initialize=require('../src/runtime/DataInspection')
local function object(class,name,attrs,children,value)
    local o={ClassName=class,Name=name,attributes=attrs or {},children=children or {},Value=value}
    function o:IsA(c)
        return c==class or c=='ValueBase' and (class=='StringValue' or class=='NumberValue' or class=='ObjectValue')
            or c=='LuaSourceContainer' and class=='ModuleScript'
    end
    function o:GetAttributes()return self.attributes end
    function o:GetChildren()return self.children end
    return o
end
local player=object('Player','Me',{}, {
    object('Folder','Settings',{EvolutionRevealed=true,AmbienceVolume=1}),
    object('Folder','leaderstats',{}, {object('StringValue','Cash',{}, {},'$3.339 undecillion')}),
    object('PlayerGui','PlayerGui',{Cash=999999}),
    object('Backpack','Backpack',{Cash=888888}),
})
player.UserId=42
local other=object('Player','Other');other.UserId=43
local module=object('ModuleScript','TycoonData',{Cash=666666},{object('NumberValue','Cash',{}, {},555555)})
local wallet=object('Folder','Economy',{Cash='4.2e30',InvestorBank=123,Evolution=5})
local storage=object('ReplicatedStorage','ReplicatedStorage',{}, {
    object('Folder','Shared',{}, {wallet,module}),
    object('Folder','Other',{Cash=777777}),
    object('Folder','43',{Cash=777777}),
})
local owned=object('Model','Tycoon7',{OwnerUserId=42,Investors=123})
local unresolved=object('Model','Tycoon8',{Cash=222222})
local notOwned=object('Model','Tycoon9',{OwnerUserId=43,Cash=333333})
local world=object('Workspace','Workspace',{}, {owned,unresolved,notOwned})
local players={GetPlayers=function()return {player,other}end}
local services={ReplicatedStorage=storage,Workspace=world,Players=players}
local env=setmetatable({game={GetService=function(_,name)return services[name]end}}, {__index=getfenv()})
setfenv(initialize,env)
local ctx={API={},player=player};initialize(ctx)
local report=ctx.API.inspectData()
assert(report:find('$3.339 undecillion',1,true),'formatted cash was lost')
assert(report:find('@EvolutionRevealed = true',1,true))
assert(not report:find('AmbienceVolume',1,true),'CamelCase false positive')
assert(report:find('ReplicatedStorage/Shared/Economy @InvestorBank = 123',1,true))
assert(report:find('Workspace/Tycoon7 @Investors = 123',1,true))
assert(report:find('Workspace/Tycoon8 owner=unresolved',1,true))
assert(report:find('Workspace/Tycoon9 owner=other',1,true))
for _,hidden in ipairs({'999999','888888','777777','666666','555555','222222','333333'}) do
    assert(not report:find(hidden,1,true),'excluded content leaked: '..hidden)
end
assert(report:find('TycoonData [ModuleScript] (name only; not required)',1,true))
print('PASS formatted cash, semantic names, shared data, ownership and excluded content')
wallet.attributes.Cash='5.1e30'
assert(ctx.API.inspectData():find('5.1e30',1,true),'second sample must read current attributes')
print('PASS live values are resampled without caching')
storage.children={}
for i=1,1200 do storage.children[i]=object('Folder','Node'..i,{Cash=i}) end
local bounded=ctx.API.inspectData()
assert(bounded:find('limited=true',1,true),'truncation must be explicit')
assert(#bounded<50000,'report must stay bounded')
print('PASS node/output limits are explicit')
storage.GetChildren=function()error('instance unavailable')end
assert(ctx.API.inspectData():find('[SL DATA v2] END examined=',1,true),'missing root must not abort remaining report')
print('PASS unavailable root tolerated')
