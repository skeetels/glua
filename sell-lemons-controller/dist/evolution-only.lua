-- Standalone evolution-only mode. No buys, upgrades, rebirths or Halo.
local context={}
local upgrade=(function()
-- Independent arithmetic matching the inspected TycoonEarner/Huge functions.
return function(ctx)
    local M={};ctx.UpgradeMath=M;local prefixes={};local LOG2=math.log10(2)
    function M.add(a,b)
        if a<b then a,b=b,a end
        if b==-math.huge then return a end
        return a+math.log10(1+10^(b-a))
    end
    function M.sub(a,b)
        if a<=b then return -math.huge end
        if b==-math.huge then return a end
        return a+math.log10(1-10^(b-a))
    end
    function M.bn(value)
        if value==-math.huge then return ctx.BN.new(0)end
        if type(value)~='number' or value~=value or math.abs(value)==math.huge then return nil end
        local e=math.floor(value);return ctx.BN.new(10^(value-e),e)
    end
    function M.unit(name,level)
        local prices=assert(ctx.GameBalance.UpgradePrices[name],'Unknown stand')
        return prices[level] or prices[#prices]+LOG2*((level-#prices)^1.2)/ctx.GameBalance.UpgradePowerFactors[name][2]
    end
    local function cumulative(name,level)
        if level<=0 then return -math.huge end
        assert(level<=100000,'Upgrade level exceeds inspected calculation bound')
        local cache=prefixes[name] or {};prefixes[name]=cache
        local value=cache[#cache] or -math.huge
        for i=#cache+1,level do value=M.add(value,M.unit(name,i));cache[i]=value end
        return cache[level]
    end
    function M.price(name,level,count,shift)
        if count==0 then return -math.huge end
        return M.sub(cumulative(name,level+count)+shift,cumulative(name,level)+shift)
    end
    function M.affordable(name,level,limit,cash,shift)
        local low,high=0,math.min(limit,10000,100000-level)
        while low<high do
            local mid=math.ceil((low+high)/2)
            if M.price(name,level,mid,shift)<=cash-1e-9 then low=mid else high=mid-1 end
        end
        return low,M.price(name,level,low,shift)
    end
    function M.countMultiplier(name,count)
        if count<.5 then return -math.huge end
        local f=ctx.GameBalance.UpgradePowerFactors[name]
        return math.log10(1+(count-1)*f[1])+LOG2*(count-1)/f[2]
    end
end

end)()
local prestige=(function()
-- TycoonRebirth / TycoonEvolution arithmetic in the game's log10 units.
return function(ctx)
    local P={};ctx.PrestigeMath=P;local M=ctx.UpgradeMath
    local CASH_FACTOR=math.log10(1.8e17);local POWER=.44
    -- nil is an explicit zero amount, never log10(1). Keep reset balances out
    -- of the non-finite conversion boundary used by the general upgrade math.
    local function normalized(v)if v==-math.huge then return nil end;return v end
    local function add(a,b)
        a,b=normalized(a),normalized(b)
        if a==nil then return b end;if b==nil then return a end
        return M.add(a,b)
    end
    function P.reward(cash,cashSpent,investors,investorsSpent)
        local earned=add(cash,cashSpent)
        if earned==nil then return nil end
        investors,investorsSpent=normalized(investors),normalized(investorsSpent)
        local capped=investors~=nil and investorsSpent~=nil and math.min(investorsSpent,investors+1) or nil
        local prior=add(investors,capped)
        if prior==nil then return (earned-CASH_FACTOR)*POWER end
        local ratio=earned-CASH_FACTOR-prior/POWER
        if ratio < -8 then return prior+math.log10(POWER)+ratio end
        return prior+M.sub(POWER*M.add(0,ratio),0)
    end
    function P.evolution(index,investors,investorsSpent,reward)
        local target=17.7+13.6*index
        local total=add(add(investors,investorsSpent),reward)
        if total==nil then return 0,nil,target,nil end
        local excess=total-target
        local progress=math.min(1,10^(excess/13.6))
        local bonus=excess>0 and math.log10(500*target)+2*math.log10(excess) or nil
        return progress,bonus,target,total
    end
    P.add=add
    -- Required cumulative cash production, using the verified game formula.
    -- Solve in log space: ordinary exponentiation overflows long before H77.
    -- -inf means the bank already meets the target, nil means invalid input.
    function P.evolutionCash(index,investors,investorsSpent,minimum)
        if type(index)~='number' or index<0 or index%1~=0 then return nil end
        local target=17.7+13.6*index
        target=target+math.sqrt(math.max(0,minimum or 0)/(500*target))
        local bank=add(investors,investorsSpent)
        if bank and bank>=target then return -math.huge end
        local function enough(earned)
            local total=add(bank,P.reward(earned,nil,investors,investorsSpent))
            return total and total>=target
        end
        local lo,hi=-1000,math.max(100,target/POWER+CASH_FACTOR+2)
        if not enough(hi) then return nil end
        for _=1,64 do
            local mid=(lo+hi)*.5
            if enough(mid) then hi=mid else lo=mid end
        end
        return hi
    end
end

end)()
local start=(function()
-- Standalone, headless evolution loop. No buys, upgrades, rebirths or Halo.
-- The caller supplies the verified PrestigeMath component; no game module is required.
return function(ctx)
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    if env.SLEvolutionOnly and (env.SLEvolutionOnly.active or env.SLEvolutionOnly.pending)then
        print('[SL EVOLUTION ONLY] already running or awaiting a reset receipt')
        return env.SLEvolutionOnly
    end
    local reader=type(env.getscriptbytecode)=='function' and env.getscriptbytecode or getscriptbytecode
    assert(type(reader)=='function','getscriptbytecode unavailable')
    local player=game:GetService('Players').LocalPlayer
    assert(player,'LocalPlayer unavailable')
    local rs=game:GetService('ReplicatedStorage')
    local workspace=game:GetService('Workspace')
    local function child(o,n)return o and o:FindFirstChild(n)end
    local function attr(o,n)return o and o:GetAttribute(n)end
    local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
    local function adler(bytes)
        local a,b=1,0
        for i=1,#bytes do a=(a+bytes:byte(i))%65521;b=(b+a)%65521 end
        return b*65536+a
    end
    local specs={
        {'Config',19699,282416287},
        {'Modules.Huge',8091,539421471},
        {'Modules.Tycoon.Component.TycoonValues',1214,285065225},
        {'Modules.Tycoon.Component.TycoonBalances',4280,537675623},
        {'Modules.Tycoon.Component.TycoonRebirth',6310,4193420756},
        {'Modules.Tycoon.Component.TycoonEvolution',6812,3704414728},
        {'Modules.Player.PremiumPurchases',2741,3733814504},
        {'Config.PlaceDifferences',128,3292598373},
        {'Modules.Service.PlaceDifferenceService',1131,2205924379},
        {'Modules.UI.Layers.Rebirth.UIEvolutionMenu',7634,4240708282},
        {'Modules.Tycoon.Component.Client.ClientTycoonEvolution',1229,3782527611},
        {'Core.RemoteRequest',4201,653841906},
    }
    if ctx.verifySchema then
        -- The offline fixture injects a schema verifier. The shipped bundle
        -- creates its private context without this field.
        assert(ctx.verifySchema(),'GAME_DATA_CHANGED fixture')
    else
        for _,spec in ipairs(specs)do
            local o=rs
            for part in spec[1]:gmatch('[^.]+')do o=child(o,part)end
            local ok,bytes=pcall(reader,o)
            local valid=ok and type(bytes)=='string' and #bytes==spec[2]
            if valid and spec[1]=='Config'then
                valid=bytes:sub(18,21)=='1.5.' and bytes:byte(22)>=48 and bytes:byte(22)<=57
                    and adler(bytes:sub(1,21)..bytes:sub(23,-25))==spec[3]
            elseif valid then valid=adler(bytes)==spec[3]end
            assert(valid,'GAME_DATA_CHANGED '..spec[1])
        end
    end
    local function amount(v)
        if v==nil or v=='0' or v==-math.huge then return nil end
        if type(v)~='number' or v~=v or math.abs(v)==math.huge then return false end
        return v
    end
    local function observe()
        local own
        for _,root in ipairs(workspace:GetChildren())do
            if root.Name:match('^Tycoon%d+$') and attr(root,'Disabled')~=true then
                local owner=child(root,'Owner')
                if owner and owner:IsA('ObjectValue') and owner.Value==player then own=root;break end
            end
        end
        if not own then return nil,'OWNED_BASE_UNAVAILABLE'end
        local root=child(own,'Values');local values=child(root,'Values')
        local remote=child(child(own,'Remotes'),'Evolve')
        if not values or not remote or not remote:IsA('RemoteFunction')then return nil,'EVOLVE_STATE_UNAVAILABLE'end
        local epoch={}
        for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do
            epoch[key]=attr(values,key) or 0
            if not integer(epoch[key])then return nil,'COUNTER_INVALID '..key end
        end
        local cash=amount(attr(values,'Cash'))
        local cashSpent=amount(attr(values,'CashSpent'))
        local investors=amount(attr(values,'Investors'))
        local investorsSpent=amount(attr(values,'InvestorsSpent'))
        if cash==false or cashSpent==false or investors==false or investorsSpent==false then
            return nil,'BALANCE_INVALID'
        end
        local reward=ctx.PrestigeMath.reward(cash,cashSpent,investors,investorsSpent)
        local progress,bonus,target,total=ctx.PrestigeMath.evolution(epoch.Evolution,investors,investorsSpent,reward)
        return {own=own,root=root,values=values,remote=remote,epoch=epoch,
            ready=progress>=1 and bonus~=nil and bonus>-math.huge,
            progress=progress,bonus=bonus,target=target,total=total}
    end
    local function same(a,b)
        if not b or a.own~=b.own or a.root~=b.root or a.values~=b.values or a.remote~=b.remote then return false end
        for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do
            if a.epoch[key]~=b.epoch[key]then return false end
        end
        return true
    end
    local function receipt(before,after)
        if not after or before.own~=after.own or before.root~=after.root or before.values~=after.values then return false end
        local a,b=before.epoch,after.epoch
        return b.Evolution==a.Evolution+1 and b.TotalEvolves==a.TotalEvolves+1
            and b.Ascension==a.Ascension and b.Rebirths==0 and b.TotalRebirths==a.TotalRebirths
    end
    local old=env.SLAutofarm
    if old and type(old.unload)=='function'then
        if type(old.callbackPending)=='function' and old.callbackPending()then
            error('Controller action is pending; cannot start evolution-only mode')
        end
        old.unload()
        task.wait(.25)
    end
    local api={active=true,pending=false,code='WAITING',count=0,logs={}}
    function api.log(code,detail)
        api.code=code
        local line='[SL EVOLUTION ONLY] '..code..' | '..tostring(detail or '')
        api.logs[#api.logs+1]=line
        if #api.logs>80 then table.remove(api.logs,1)end
        print(line)
    end
    function api.report()return table.concat(api.logs,'\n')end
    function api.stop()
        api.active=false
        api.log(api.pending and 'STOP_PENDING' or 'STOPPED','no further requests')
    end
    function api.tick()
        if not api.active or api.pending then return false end
        local before,why=observe()
        if not before then
            if api.code~='WAITING_STATE'then api.log('WAITING_STATE',why)end
            return false
        end
        if not before.ready then
            if api.lastEvolution~=before.epoch.Evolution or api.code~='WAITING_READY'then
                api.lastEvolution=before.epoch.Evolution
                api.log('WAITING_READY','E='..before.epoch.Evolution..'; progress='..math.floor(before.progress*100)..'%')
            end
            return false
        end
        -- A short second observation prevents a stale ready value from sending
        -- an ordinary reset after another actor has already evolved.
        task.wait(.15)
        local fresh=observe()
        if not api.active or not same(before,fresh) or not fresh.ready then return false end
        local record={sent=false,returned=false,ok=false,error=nil}
        api.pending=true
        task.spawn(function()
            record.ok,record.error=pcall(function()
                local current=observe()
                assert(api.active and same(fresh,current) and current.ready,'EVOLUTION_STATE_CHANGED')
                record.sent=true
                api.log('EVOLVE_SENT','E='..fresh.epoch.Evolution..'; ordinary request; no GUI')
                current.remote:InvokeServer(nil)
            end)
            record.returned=true
        end)
        local start=os.clock()
        repeat
            local after=observe()
            if record.returned and (not record.ok or receipt(fresh,after))then break end
            task.wait(.05)
        until os.clock()-start>=8
        local after=observe()
        if not record.returned or not record.ok or not receipt(fresh,after)then
            api.active=false
            if not record.sent then api.pending=false end
            api.log(record.sent and 'UNRESOLVED' or 'DISPATCH_FAILED',
                (record.sent and 'request sent once; no confirmed counter change: ' or 'request not sent: ')
                ..tostring(record.error))
            -- Leave pending true even if a timed-out request later returns: a
            -- second worker must not send the same reset again in this session.
            return false
        end
        api.pending=false;api.count=api.count+1
        api.lastEvolution=after.epoch.Evolution
        api.log('EVOLVE_RECEIPT','E='..fresh.epoch.Evolution..'->'..after.epoch.Evolution..'; count='..api.count)
        return true
    end
    env.SLEvolutionOnly=api
    _G.SLEvolutionOnly=api
    api.log('START','only evolution; game='..tostring(game.PlaceVersion)..'; stop via getgenv().SLEvolutionOnly.stop()')
    task.spawn(function()
        while api.active do
            local ok,err=xpcall(api.tick,function(e)return debug.traceback(tostring(e),2)end)
            if not ok then api.active=false;api.log('ERROR',err)end
            if api.active then task.wait(.25)end
        end
    end)
    return api
end

end)()
upgrade(context);prestige(context);return start(context)
