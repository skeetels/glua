local probe=require('../src/diagnostics/DirectUpgradeProbe')
local function fixture(mode)
    local env={};local logs={};local queue={};local time=0;local calls=0;local spawned=0
    local player={};local owner={Value=player,IsA=function(_,name)return name=='ObjectValue'end}
    local attributes={Cash=2,Evolution=5};local level={LemonStand=10,LemonDash=20}
    if mode=='zero' then level={}end
    local values={GetAttribute=function(_,n)return attributes[n]end}
    local levels={GetAttribute=function(_,n)return level[n]end}
    local data={FindFirstChild=function(_,n)return n=='Values' and values or n=='Upgrades' and levels end}
    local own={Name='Tycoon3',FindFirstChild=function(_,n)return n=='Owner' and owner or n=='Values' and data end}
    local world={GetChildren=function()return {own}end};own.Parent=world
    local objects={}
    for _,name in ipairs({'LemonStand','LemonDash','Foreign','Unknown'})do
        local remote={IsA=function(_,n)return n=='RemoteFunction'end,InvokeServer=function(_,count)
            assert(count==1);assert(spawned==2,'both requests must be scheduled before waiting for responses')
            calls=calls+1
            if mode=='reject' then error('server rejected')end
            if mode~='silent' then level[name]=(level[name] or 0)+1 end
            if mode=='reset' then attributes.Evolution=6 end
            if mode=='newcounter' then attributes.TotalRebirths=1 end
            if mode=='owner' then owner.Value={}end
        end}
        local purchase={Parent=own,HasTag=function(_,tag)return tag=='Tycoon.Purchasable'end,
            GetAttribute=function(_,n)assert(n=='Enabled');return name~='Unknown'end}
        objects[#objects+1]={Name=name,Parent=purchase,IsDescendantOf=function(_,r)return r==own and name~='Foreign'end,
            FindFirstChild=function(_,n)return n=='Upgrade' and remote end,GetFullName=function()return 'Workspace.Tycoon3.'..name end}
    end
    if mode=='duplicate' then objects[#objects+1]=objects[1]end
    local runtime=setmetatable({game={PlaceId=79268393072444,GetService=function(_,n)
        if n=='Players' then return {LocalPlayer=player}end
        if n=='Workspace' then return world end
        assert(n=='CollectionService');return {GetTagged=function(_,tag)assert(tag=='Tycoon.Earner');return objects end}
    end},getgenv=function()return env end,require=function()error('Xeno cannot load Roblox modules')end,
    print=function(s)logs[#logs+1]=s end,os={clock=function()return time end},
    task={spawn=function(fn)spawned=spawned+1;queue[#queue+1]=fn end,wait=function(dt)
        time=time+(dt or .1)
        if mode~='timeout' then local pending=queue;queue={};for _,fn in ipairs(pending)do fn()end end
    end}}, {__index=getfenv()})
    if mode=='pending' then env.SLAutofarm={pause=function()end,unload=function()error('must not unload pending callback')end,callbackPending=function()return true end}end
    if mode=='previous' then env.SLDirectProbe={active=true}end
    setfenv(probe,runtime);local api=probe()
    return api,table.concat(logs,'\n'),calls,level,queue
end
local api,logs,calls,level=fixture('ok')
assert(calls==2 and level.LemonStand==11 and level.LemonDash==21 and not api.active)
assert(logs:find('RECEIPT LemonStand 10->11 confirmed=true',1,true))
assert(logs:find('RECEIPT LemonDash 20->21 confirmed=true',1,true))
assert(logs:find('SKIP Unknown',1,true) and not logs:find('STAND Foreign',1,true))
local _,zero,zeroCalls,zeroLevels=fixture('zero')
assert(zeroCalls==2 and zeroLevels.LemonStand==1 and zeroLevels.LemonDash==1)
assert(zero:find('RECEIPT LemonStand 0->1 confirmed=true',1,true),'absent attribute is initial zero, not an unavailable stand')
for _,mode in ipairs({'pending','previous','duplicate'})do local _,_,count=fixture(mode);assert(count==0,mode)end
for _,mode in ipairs({'silent','reject'})do
    local _,result,count=fixture(mode);assert(count==2 and not result:find('confirmed=true',1,true),mode)
end
for _,mode in ipairs({'reset','newcounter','owner'})do
    local _,result,count=fixture(mode);assert(count==1 and not result:find('confirmed=true',1,true),mode)
end
local pending,result,count,_,queue=fixture('timeout')
assert(count==0 and pending.active and pending.pending==2 and not result:find('confirmed=true',1,true))
for _,fn in ipairs(queue)do fn()end
assert(not pending.active and pending.pending==0,'late return clears exclusion, never resends')
print('PASS 11 direct probe groups: no require, parallel schedule, owned enabled identities, initial zero, exclusions, duplicates, receipts, rejection, reset, owner and timeout')
