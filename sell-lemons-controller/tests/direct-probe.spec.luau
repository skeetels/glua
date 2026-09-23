local probe=require('../src/diagnostics/DirectUpgradeProbe')
local function fixture(mode)
    local env={};local logs={};local queue={};local time=0;local calls=0;local spawned=0
    local player={};local owner={Value=player,IsA=function(_,name)return name=='ObjectValue'end}
    local attributes={Cash=mode=='poor' and -.5 or 2,Evolution=5};local level={LemonStand=10,LemonDash=20}
    local values={GetAttribute=function(_,n)return attributes[n]end}
    local levels={GetAttribute=function(_,n)return level[n]end}
    local data={FindFirstChild=function(_,n)return n=='Values' and values or n=='Upgrades' and levels end}
    local own={Name='Tycoon3',FindFirstChild=function(_,n)return n=='Owner' and owner or n=='Values' and data end}
    local world={GetChildren=function()return {own}end}
    local class={};local objects={}
    for _,name in ipairs({'LemonStand','LemonDash'})do
        local remote={IsA=function(_,n)return n=='RemoteFunction'end,InvokeServer=function(_,count)
            assert(count==1);assert(spawned==2,'all requests must be scheduled before waiting for results')
            calls=calls+1
            if mode=='reject' then error('server rejected')end
            if mode~='silent' then level[name]=level[name]+1 end
            if mode=='reset' then attributes.Evolution=6 end
        end}
        local instance={isInstance=true,IsDescendantOf=function(_,r)return r==own end,FindFirstChild=function(_,n)return n=='Upgrade' and remote end}
        objects[#objects+1]={Name=name,Instance=instance,IsEnabled=function()return true end,
            GetUpgradeLevel=function()return level[name]end,GetUpgradePrice=function(_,a,count)
                assert(a==nil and count==1);return 0,1
            end}
    end
    class.getAll=function()return objects end
    local huge={zero=-math.huge,toHuge=math.log10,toNumber=function(n)return 10^n end,
        add=function(a,b)if a==-math.huge then return b end;return math.max(a,b)+math.log10(1+10^-math.abs(a-b))end}
    local rs={Modules={Tycoon={Entity={Client={ClientTycoonEarner=class}}},Huge=huge}}
    local runtime=setmetatable({game={PlaceId=79268393072444,GetService=function(_,n)
        return n=='Players' and {LocalPlayer=player} or n=='Workspace' and world or rs
    end},getgenv=function()return env end,require=function(module)return module end,
    typeof=function(v)return type(v)=='table' and v.isInstance and 'Instance' or type(v)end,
    print=function(s)logs[#logs+1]=s end,os={clock=function()return time end},
    task={spawn=function(fn)spawned=spawned+1;queue[#queue+1]=fn end,wait=function(dt)
        time=time+(dt or .1);local pending=queue;queue={};for _,fn in ipairs(pending)do fn()end
    end}}, {__index=getfenv()})
    if mode=='pending' then env.SLAutofarm={pause=function()end,unload=function()error('must not unload pending callback')end,callbackPending=function()return true end}end
    setfenv(probe,runtime);local api=probe()
    return api,table.concat(logs,'\n'),calls,level
end
local api,logs,calls,level=fixture('ok')
assert(calls==2 and level.LemonStand==11 and level.LemonDash==21 and not api.active)
assert(logs:find('RECEIPT LemonStand 10->11 confirmed=true',1,true))
assert(logs:find('RECEIPT LemonDash 20->21 confirmed=true',1,true))
local _,poor,count=fixture('poor');assert(count==0 and poor:find('NO_AFFORDABLE_ENABLED_STAND',1,true))
local _,pending,count=fixture('pending');assert(count==0 and pending:find('CONTROLLER_CALLBACK_PENDING',1,true))
local _,silent,count=fixture('silent');assert(count==2 and not silent:find('confirmed=true',1,true))
local _,reject,count=fixture('reject');assert(count==2 and not reject:find('confirmed=true',1,true))
local _,reset,count=fixture('reset');assert(count==1 and reset:find('Reset changed',1,true))
print('PASS 6 direct upgrade probe groups: parallel schedule, budget, pending exclusion, receipts, rejection and reset guard')
