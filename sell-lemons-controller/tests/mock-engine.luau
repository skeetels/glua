-- Minimal object/event fixture. It is not Roblox and proves no gameplay behavior.
local function signal()
    local out={handlers={}}
    function out:Connect(fn)
        local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end
        self.handlers[#self.handlers+1]=c;return c
    end
    function out:Fire(...)
        for _,c in ipairs(self.handlers) do if c.Connected then c.fn(...) end end
    end
    return out
end
local function instance(class)
    local props={ClassName=class,Name=class,Visible=true,Enabled=true,Active=true,Parent=nil,
        AbsolutePosition={X=0,Y=0},AbsoluteSize={X=100,Y=30},ViewportSize={X=1920,Y=1080}}
    local obj={children={},events={},destroyed=false}
    function obj:IsA(name)return name==class or name=='Instance' or name=='GuiObject' and class~='ScreenGui' or name=='GuiButton' and class=='TextButton' or name=='LayerCollector' and class=='ScreenGui' end
    function obj:FindFirstChild(name)for _,x in ipairs(self.children) do if x.Name==name then return x end end end
    function obj:WaitForChild(name)return self:FindFirstChild(name) end
    function obj:GetChildren()return self.children end
    function obj:GetDescendants()
        local out={};local function visit(n)for _,x in ipairs(n.children)do out[#out+1]=x;visit(x)end end
        visit(self);return out
    end
    function obj:GetAttribute()return nil end
    function obj:GetPropertyChangedSignal(name)
        self.events[name]=self.events[name] or signal();return self.events[name]
    end
    function obj:GetFullName()return self.Name end
    function obj:Destroy()self.destroyed=true;props.Parent=nil end
    setmetatable(obj,{__index=function(_,k)
        if k=='Activated' or k=='InputBegan' or k=='InputChanged' or k=='InputEnded' or k=='Idled'
            or k=='WindowFocused' or k=='WindowFocusReleased' then
            obj.events[k]=obj.events[k] or signal();return obj.events[k]
        end
        return props[k]
    end,__newindex=function(_,k,v)
        props[k]=v
        if k=='Parent' and v then v.children[#v.children+1]=obj end
        if obj.events[k] then obj.events[k]:Fire() end
    end})
    return obj
end
return function()
    local services={};local tasks={};local globals={};local logs={}
    local gui=instance('PlayerGui');local player=instance('Player');player.UserId=42;gui.Parent=player
    services.Players={LocalPlayer=player};services.UserInputService=instance('UserInputService')
    services.UserInputService.GetFocusedTextBox=function()return nil end
    services.VirtualUser={CaptureController=function()end,Button2Down=function()end,Button2Up=function()end}
    local engine={PlaceId=79268393072444,PlaceVersion=0,GetService=function(_,name)
        services[name]=services[name] or {};return services[name]
    end}
    local enum=setmetatable({},{__index=function(t,k)local n=setmetatable({},{__index=function(_,v)return k..'.'..v end});rawset(t,k,n);return n end})
    local env=setmetatable({game=engine,workspace={CurrentCamera=instance('Camera')},
        _G=globals,getgenv=function()return globals end,Instance={new=instance},Enum=enum,
        Color3={new=function(...)return {...}end,fromRGB=function(...)return {...}end},
        UDim={new=function(a,b)return {Scale=a,Offset=b}end},
        UDim2={new=function(a,b,c,d)return {X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end,
            fromOffset=function(x,y)return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end,
            fromScale=function(x,y)return {X={Scale=x,Offset=0},Y={Scale=y,Offset=0}}end},
        Vector2={new=function(x,y)return {X=x,Y=y}end},
        task={spawn=function(fn)tasks[#tasks+1]=fn;return fn end,delay=function(_,fn)tasks[#tasks+1]=fn end,
            wait=function()return .1 end,cancel=function()end},
        print=function(...)logs[#logs+1]={...}end,warn=function(...)logs[#logs+1]={...}end,
    },{__index=getfenv()})
    return {env=env,gui=gui,player=player,services=services,tasks=tasks,globals=globals,logs=logs}
end
