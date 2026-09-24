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
