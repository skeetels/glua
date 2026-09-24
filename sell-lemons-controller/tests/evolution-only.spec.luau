local function runCase(advanceCounters,changeBeforeDispatch)
    local fakeNow=0
    local envTable={}
    local player={UserId=7}
    local values={attrs={Evolution=0,Ascension=945,Rebirths=2,TotalRebirths=2757,TotalEvolves=1387,
        Cash=100,CashSpent='0',Investors='0',InvestorsSpent='0'}}
    function values:GetAttribute(k)return self.attrs[k]end
    local remote={Name='Evolve',calls=0}
    function remote:IsA(k)return k=='RemoteFunction'end
    function remote:InvokeServer(...)
        self.calls=self.calls+1
        assert(select('#',...)==1 and select(1,...)==nil,'ordinary Evolve sends one nil argument')
        if advanceCounters then
            values.attrs.Evolution=values.attrs.Evolution+1
            values.attrs.TotalEvolves=values.attrs.TotalEvolves+1
            values.attrs.Rebirths=0
            values.attrs.Cash='0'
        end
    end
    local function node(name,children,attrs)
        local o={Name=name,children=children or {},attrs=attrs or {}}
        function o:FindFirstChild(k)return self.children[k]end
        function o:GetAttribute(k)return self.attrs[k]end
        return o
    end
    local own=node('Tycoon7',{Owner={IsA=function(_,k)return k=='ObjectValue'end,Value=player},
        Values=node('Values',{Values=values}),Remotes=node('Remotes',{Evolve=remote})})
    local workspace={GetChildren=function()return {own}end}
    local services={Players={LocalPlayer=player},ReplicatedStorage={},Workspace=workspace}
    local game={PlaceId=79268393072444,PlaceVersion=6920,
        GetService=function(_,k)return services[k]end}
    local spawned=0
    local tasks={
        spawn=function(fn)
            spawned=spawned+1
            if spawned==1 then return fn end -- Hold the autonomous loop; drive tick explicitly.
            if changeBeforeDispatch then values.attrs.Evolution=values.attrs.Evolution+1 end
            fn()
        end,
        wait=function(seconds)fakeNow=fakeNow+(seconds or .05);return seconds or .05 end,
    }
    local logs={}
    local mockEnv=setmetatable({game=game,task=tasks,os={clock=function()return fakeNow end},
        getgenv=function()return envTable end,getscriptbytecode=function()return 'fixture'end,
        _G=envTable,print=function(s)logs[#logs+1]=s end}, {__index=getfenv()})
    local ctx={verifySchema=function()return true end}
    for _,module in ipairs({'../src/core/UpgradeMath','../src/core/PrestigeMath'})do
        local initialize=require(module)
        setfenv(initialize,mockEnv);initialize(ctx)
    end
    local start=require('../src/modes/EvolutionOnly')
    setfenv(start,mockEnv)
    local api=start(ctx)
    assert(api.active and spawned==1 and remote.calls==0,'startup must not send an action')
    return api,remote,values,envTable,logs
end

do
    local api,remote,values,env,logs=runCase(true)
    assert(api.tick() and remote.calls==1 and api.count==1,'ready evolution should send one request and confirm it')
    assert(values.attrs.Evolution==1 and values.attrs.TotalEvolves==1388 and values.attrs.Rebirths==0)
    assert(not api.tick() and remote.calls==1,'after the reset, no second request without fresh readiness')
    assert(env.SLEvolutionOnly==api and api.report():find('EVOLVE_RECEIPT',1,true))
    api.stop();assert(not api.active and not api.pending)
    print('PASS evolution-only confirms exactly one direct reset and then waits')
end
do
    local api,remote=runCase(false)
    assert(not api.tick() and remote.calls==1,'unconfirmed request must stop')
    assert(not api.active and api.pending and api.code=='UNRESOLVED')
    assert(not api.tick() and remote.calls==1,'unresolved reset must never be retried')
    print('PASS evolution-only never repeats an unresolved reset')
end
do
    local api,remote=runCase(true,true)
    assert(not api.tick() and remote.calls==0,'changed counters must prevent dispatch')
    assert(not api.active and not api.pending and api.code=='DISPATCH_FAILED')
    print('PASS evolution-only rechecks the reset epoch immediately before dispatch')
end
