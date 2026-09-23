local start=require('../src/diagnostics/ActionCapture')
local function fixture(supported,broken)
    local env={};local logs={};local method;local delayed={};local forwarded=0
    local function object(class,name)
        local o={ClassName=class,Name=name,kind='Instance',children={}}
        function o:IsA(c)return self.ClassName==c end
        function o:GetChildren()return self.children end
        function o:FindFirstChild(n)for _,c in ipairs(self.children)do if c.Name==n then return c end end end
        function o:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
        function o:GetFullName()return self.Parent and self.Parent:GetFullName()..'.'..self.Name or self.Name end
        return o
    end
    local world=object('Workspace','Workspace');local player={}
    local root=object('Folder','Tycoon2');root.Parent=world;world.children={root}
    local owner=object('ObjectValue','Owner');owner.Value=player;owner.Parent=root;root.children={owner}
    local remote=object('RemoteFunction','Upgrade');remote.Parent=root
    local outsiders=object('RemoteFunction','Private');outsiders.Parent=world
    local original=function(self,...)
        if self.ClassName=='BindableFunction' then return self.OnInvoke(...)end
        forwarded=forwarded+1
        if self.fail then error('original failure',0)end
        if self.yield then return coroutine.yield(...)end
        return ...
    end
    local meta={__namecall=original};local apiGame={PlaceId=79268393072444,GetService=function(_,n)
        if n=='Players' then return {LocalPlayer=player}end;return world
    end}
    local runtime=setmetatable({game=apiGame,getgenv=function()return env end,typeof=function(v)
        return type(v)=='table' and v.kind or type(v)
    end,print=function(s)logs[#logs+1]=s end,
    task={delay=function(_,fn)delayed[#delayed+1]=fn end},
    Instance={new=function(class)
        local o=object(class,'Probe')
        function o:Invoke(...)method='Invoke';return meta.__namecall(self,...)end
        function o:Destroy()end
        return o
    end}}, {__index=getfenv()})
    if supported then
        runtime.getrawmetatable=function()return meta end
        runtime.getnamecallmethod=function()return method end
        runtime.hookmetamethod=function(_,_,fn)local old=meta.__namecall;meta.__namecall=fn;if broken then return nil end;return old end
    end
    setfenv(start,runtime)
    local api=start()
    local function invoke(target,...)method='InvokeServer';return meta.__namecall(target,...)end
    return {api=api,invoke=invoke,remote=remote,outsiders=outsiders,owner=owner,meta=meta,original=original,
        logs=logs,delayed=delayed,forwarded=function()return forwarded end}
end
local no=fixture(false)
assert(no.api.status=='UNSUPPORTED' and no.forwarded()==0)
local broken=fixture(true,true)
assert(broken.api.status=='HOOK_UNSUPPORTED' and broken.meta.__namecall==broken.original)
print('PASS absent or broken hook support sends no game request and restores original')
local f=fixture(true)
assert(f.api.active and f.forwarded()==0,'startup must not invoke game remotes')
local a,b,c=f.invoke(f.remote,'LemonStand',nil,100)
assert(a=='LemonStand' and b==nil and c==100 and f.forwarded()==1)
assert(f.api.calls==1 and f.api.records[1].argc==3 and f.api.records[1].args:find('nil',1,true))
print('PASS owned calls are observed once while nil arguments and return values are preserved')
f.invoke(f.outsiders,'private payload')
assert(f.api.calls==1 and f.forwarded()==2,'unrelated remote must forward without capture')
local cycle={token='not-to-log'};cycle.self=cycle
f.invoke(f.remote,cycle)
assert(f.api.records[2].args:find('<cycle>',1,true) and not f.api.records[2].args:find('not-to-log',1,true))
print('PASS unrelated calls excluded; cyclic payloads bounded and secret keys redacted')
f.remote.fail=true
local ok,err=pcall(f.invoke,f.remote,42)
assert(not ok and err=='original failure');f.remote.fail=nil
f.remote.yield=true
local thread=coroutine.create(function()return f.invoke(f.remote,'waiting',nil,7)end)
local resumed,x,y,z=coroutine.resume(thread)
assert(resumed and x=='waiting' and y==nil and z==7 and coroutine.status(thread)=='suspended')
local done,value=coroutine.resume(thread,'done');assert(done and value=='done')
f.remote.yield=nil
print('PASS original errors and yielding behavior are preserved')
local before=f.api.calls;f.owner.Value={};f.invoke(f.remote,'no longer owned')
assert(f.api.calls==before,'ownership loss must stop capture')
f.api.stop('test');assert(not f.api.active and f.meta.__namecall==f.original)
print('PASS ownership loss and explicit cleanup')
local t=fixture(true);t.delayed[1]()
assert(not t.api.active and t.meta.__namecall==t.original)
local chained=fixture(true);local replacement=function()return 'another tool'end
chained.meta.__namecall=replacement;chained.api.stop('chain test')
assert(chained.meta.__namecall==replacement,'cleanup must not overwrite another hook')
print('PASS timeout cleanup and preservation of later hooks')
