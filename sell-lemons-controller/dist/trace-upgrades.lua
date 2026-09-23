-- Generated passive action capture. Does not invoke game remotes.
local start=(function()
-- Standalone observer, deliberately not part of the farming controller.
-- Records existing outbound calls inside the owned tycoon; never replays them.
return function()
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    if env.SLActionCapture and env.SLActionCapture.stop then env.SLActionCapture.stop('replaced') end
    local function log(s)print('[SL ACTION] '..s)end
    local function cap(name,fallback)return type(env[name])=='function' and env[name] or fallback end
    local hook=cap('hookmetamethod',hookmetamethod)
    local methodName=cap('getnamecallmethod',getnamecallmethod)
    local rawMeta=cap('getrawmetatable',getrawmetatable)
    local makeClosure=cap('newcclosure',newcclosure)
    log('CAPABILITIES hookmetamethod='..tostring(type(hook)=='function')
        ..' getnamecallmethod='..tostring(type(methodName)=='function')
        ..' decompile='..tostring(type(cap('decompile',decompile))=='function')
        ..' getscriptbytecode='..tostring(type(cap('getscriptbytecode',getscriptbytecode))=='function'))
    local api={active=false,calls=0,changes=0,records={},status='INITIALIZING'}
    env.SLActionCapture=api
    local connections={};local old,wrapper,probe;local testHits=0;local sequence=0
    function api.stop(reason)
        api.active=false
        for _,c in ipairs(connections)do pcall(c.Disconnect,c)end
        connections={}
        -- Do not overwrite a different hook installed after this observer.
        local restored=false
        if old and type(rawMeta)=='function' then
            local ok,mt=pcall(rawMeta,game)
            if ok and type(mt)=='table' and mt.__namecall==wrapper then restored=pcall(hook,game,'__namecall',old) end
        end
        log('STOP reason='..tostring(reason or 'manual')..' calls='..api.calls..' level_changes='..api.changes
            ..' restored='..tostring(restored)..'; remaining observer layer, if any, is inactive passthrough')
    end
    if type(hook)~='function' or type(methodName)~='function' or type(rawMeta)~='function' then
        api.status='UNSUPPORTED';log('UNSUPPORTED: no usable capture API advertised; no game action was sent');return api
    end
    local metaOK,meta=pcall(rawMeta,game)
    if not metaOK or type(meta)~='table' or type(meta.__namecall)~='function' then
        api.status='HOOK_ORIGINAL_UNAVAILABLE';log(api.status);return api
    end
    old=meta.__namecall
    local player=game:GetService('Players').LocalPlayer
    local world=game:GetService('Workspace');local owned
    for _,root in ipairs(world:GetChildren())do
        local owner=root:FindFirstChild('Owner')
        if root.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==player then owned=root;break end
    end
    if not owned then api.status='NO_OWNED_TYCOON';log(api.status);return api end
    local function stillOwned()
        local owner=owned:FindFirstChild('Owner')
        return owned.Parent==world and owner and owner.Value==player
    end
    local function path(o)
        local ok,v=pcall(function()return o:GetFullName()end)
        return ok and v or '[unavailable instance]'
    end
    local function serialize(v,depth,seen,budget)
        budget.n=budget.n+1;if budget.n>80 then return '<node limit>' end
        local kind=typeof(v)
        if kind=='nil' then return 'nil' end
        if kind=='number' or kind=='boolean' then return tostring(v) end
        if kind=='string' then
            if #v>160 then return '<string length='..#v..' omitted>' end
            return string.format('%q',v)
        end
        if kind=='Instance' then return 'Instance('..string.format('%q',path(v))..')' end
        if kind~='table' then return '<'..kind..'>' end
        if seen[v] then return '<cycle>' end
        if depth>=4 then return '<depth limit>' end
        seen[v]=true;local parts={};local n=0
        -- next/raw reads avoid running arbitrary __pairs/__index callbacks.
        for k,value in next,v do
            n=n+1;if n>16 or budget.n>80 then parts[#parts+1]='<truncated>';break end
            local hidden=type(k)=='string' and (k:lower():find('token',1,true) or k:lower():find('password',1,true)
                or k:lower():find('secret',1,true) or k:lower():find('cookie',1,true))
            parts[#parts+1]='['..serialize(k,depth+1,seen,budget)..']='..(hidden and '<redacted>' or serialize(value,depth+1,seen,budget))
        end
        seen[v]=nil;return '{'..table.concat(parts,',')..'}'
    end
    local deadline=os.clock()+90
    local function record(remote,method,args)
        if not api.active or os.clock()>deadline or api.calls>=80 or not stillOwned() then return end
        if typeof(remote)~='Instance' or not remote:IsDescendantOf(owned) then return end
        if not (method=='InvokeServer' and remote:IsA('RemoteFunction')
            or method=='FireServer' and remote:IsA('RemoteEvent')) then return end
        api.calls=api.calls+1;sequence=sequence+1
        local values={};local budget={n=0}
        for i=1,math.min(args.n,16)do values[#values+1]=serialize(args[i],0,{},budget)end
        local entry={id=sequence,time=os.clock(),method=method,path=path(remote),argc=args.n,args=table.concat(values,' | ')}
        api.records[#api.records+1]=entry
        log('CALL '..entry.id..' '..method..' '..entry.path..' argc='..args.n..' (observation only)')
        for i=1,#entry.args,360 do log('ARGS '..entry.id..' '..entry.args:sub(i,i+359))end
    end
    local fn=function(self,...)
        local method=methodName()
        if self==probe and method=='Invoke' then testHits=testHits+1 end
        if api.active and (method=='InvokeServer' or method=='FireServer') then
            pcall(record,self,method,table.pack(...)) -- capture errors must not alter the game call
        end
        return old(self,...)
    end
    wrapper=fn
    if type(makeClosure)=='function' then
        local ok,result=pcall(makeClosure,fn)
        if not ok or type(result)~='function' then api.status='CLOSURE_UNSUPPORTED';log(api.status);return api end
        wrapper=result
    end
    local ok,result=pcall(hook,game,'__namecall',wrapper)
    if not ok or type(result)~='function' then
        api.status='HOOK_UNSUPPORTED';api.stop(api.status);return api
    end
    old=result
    probe=Instance.new('BindableFunction');probe.Name='SLActionCaptureLocalProbe'
    probe.OnInvoke=function(marker)return marker,nil,17 end
    local passed,a,b,c=pcall(function()return probe:Invoke('SL_CAPTURE_TEST')end)
    probe:Destroy();probe=nil
    if not passed or testHits~=1 or a~='SL_CAPTURE_TEST' or b~=nil or c~=17 then
        api.status='HOOK_TEST_FAILED';api.stop(api.status);return api
    end
    local folder=owned:FindFirstChild('Values')
    local upgrades=folder and folder:FindFirstChild('Upgrades')
    if upgrades then
        local previous=upgrades:GetAttributes()
        connections[#connections+1]=upgrades.AttributeChanged:Connect(function(name)
            if not api.active then return end
            if not stillOwned() then api.stop('ownership changed');return end
            local value=upgrades:GetAttribute(name)
            if type(value)=='number' and value~=previous[name] then
                api.changes=api.changes+1
                log('LEVEL '..name..' '..tostring(previous[name])..' -> '..tostring(value)..'; latest_call='..sequence..' (temporal association only)')
            end
            previous[name]=value
        end)
    end
    api.active=true;api.status='LISTENING'
    log('LISTENING '..path(owned)..'; 90 seconds. Local hook test passed; game-call coverage remains unverified. Click one ordinary stand upgrade.')
    task.delay(90,function()if env.SLActionCapture==api then api.status='FINISHED';api.stop('time limit')end end)
    return api
end

end)()
return start()
