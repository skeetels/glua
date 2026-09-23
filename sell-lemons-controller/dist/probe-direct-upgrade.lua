-- Generated one-round direct upgrade probe, then read-only pricing inspection.
local probe=(function()
-- Bounded transport test, not an allocation strategy. No game module require.
-- The observed Upgrade remote takes one numeric count; the server decides affordability.
return function()
    local function log(s)print('[SL DIRECT] '..s)end
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    if env.SLDirectProbe and env.SLDirectProbe.active then log('PREVIOUS_BATCH_PENDING');return end
    if env.SLAutofarm then
        local controller=env.SLAutofarm
        if type(controller.pause)~='function' or type(controller.callbackPending)~='function' or type(controller.unload)~='function' then
            log('CONTROLLER_STATE_UNKNOWN');return
        end
        controller.pause()
        if controller.callbackPending() then log('CONTROLLER_CALLBACK_PENDING');return end
        controller.unload()
    end
    local api={active=true,pending=0};env.SLDirectProbe=api
    local function run()
        log('START v2: at most one +1 attempt per recorded owned stand; no module require, mouse or menus')
        local player=game:GetService('Players').LocalPlayer
        local world=game:GetService('Workspace');local own
        for _,root in ipairs(world:GetChildren())do
            local owner=root:FindFirstChild('Owner')
            if root.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==player then own=root;break end
        end
        assert(own,'Owned base not found')
        local rootValues=assert(own:FindFirstChild('Values'),'Values missing')
        local values=assert(rootValues:FindFirstChild('Values'),'Values/Values missing')
        local levels=assert(rootValues:FindFirstChild('Upgrades'),'Values/Upgrades missing')
        local epochKeys={'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'}
        local epoch={};for _,key in ipairs(epochKeys)do epoch[key]=values:GetAttribute(key)end
        local function validEpoch()
            local owner=own:FindFirstChild('Owner')
            if own.Parent~=world or not owner or owner.Value~=player then return false,'Owner changed' end
            if own:FindFirstChild('Values')~=rootValues or rootValues:FindFirstChild('Values')~=values
                or rootValues:FindFirstChild('Upgrades')~=levels then return false,'State container changed' end
            for _,key in ipairs(epochKeys)do if values:GetAttribute(key)~=epoch[key] then return false,'Reset changed' end end
            return true
        end
        local entries={};local names={}
        for _,instance in ipairs(game:GetService('CollectionService'):GetTagged('Tycoon.Earner'))do
            if instance:IsDescendantOf(own) then
                local name=instance.Name:gsub('[^%w]','')
                local remote=instance:FindFirstChild('Upgrade')
                local level=levels:GetAttribute(name)
                if remote and remote:IsA('RemoteFunction') and type(level)=='number' and level>=0 and level<math.huge and level%1==0 then
                    assert(not names[name],'Duplicate stand identity: '..name)
                    names[name]=true
                    entries[#entries+1]={name=name,level=level,remote=remote,instance=instance}
                    log('STAND '..name..' level='..level..' path='..instance:GetFullName())
                else log('SKIP '..name..' level='..tostring(level)..'; no recorded level or Upgrade RemoteFunction')end
            end
        end
        assert(#entries<=8,'Unexpected stand count')
        table.sort(entries,function(a,b)return a.name<b.name end)
        if #entries==0 then log('DONE no recorded owned stand found; no requests sent');return end
        local ok,reason=validEpoch();assert(ok,reason)
        log('DISPATCH stands='..#entries..'; one +1 attempt each; server validates funds; no retry')
        local start=os.clock();api.pending=#entries
        for _,entry in ipairs(entries)do
            task.spawn(function()
                local accepted,err=pcall(function()
                    local valid,why=validEpoch();assert(valid,why)
                    assert(entry.instance:IsDescendantOf(own) and entry.instance:FindFirstChild('Upgrade')==entry.remote,'Stand changed')
                    assert(levels:GetAttribute(entry.name)==entry.level,'Level changed before dispatch')
                    entry.remote:InvokeServer(1)
                end)
                entry.returned=true;entry.ok=accepted;entry.error=not accepted and tostring(err) or nil
                api.pending=api.pending-1
                log('RETURN '..entry.name..' ok='..tostring(accepted)..(entry.error and (' '..entry.error) or ''))
                if api.pending==0 and api.timedOut then api.active=false end
            end)
        end
        local function confirmed(entry)
            return validEpoch() and entry.instance:IsDescendantOf(own)
                and entry.returned==true and entry.ok==true and levels:GetAttribute(entry.name)==entry.level+1
        end
        repeat
            local proved=0
            for _,entry in ipairs(entries)do if confirmed(entry) then proved=proved+1 end end
            if api.pending==0 and proved==#entries then break end
            task.wait(.1)
        until os.clock()-start>=8
        for _,entry in ipairs(entries)do
            log('RECEIPT '..entry.name..' '..entry.level..'->'..tostring(levels:GetAttribute(entry.name))..' confirmed='..tostring(confirmed(entry)))
        end
        api.timedOut=api.pending>0
        log('DONE pending='..api.pending..'; this probe will not repeat any request')
    end
    local ok,err=pcall(run)
    if not ok then log('ERROR '..tostring(err))end
    api.active=api.pending>0
    return api
end

end)()
local result=probe()
local inspect=(function()
-- Read client handlers as text. Never require them or invoke any game remote.
return function()
    local function log(s)print('[SL CLIENT] '..s)end
    log('START v4; pricing dependencies; client text/bytecode only; no purchases or hooks')
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    local decode=type(env.decompile)=='function' and env.decompile or decompile
    local readBytes=type(env.getscriptbytecode)=='function' and env.getscriptbytecode or getscriptbytecode
    if type(decode)~='function' then log('UNSUPPORTED decompile');return end
    if type(env.SLClientInspection)=='table' and env.SLClientInspection.active then log('ALREADY_RUNNING');return end
    local api={active=true,sources={},status='SCANNING'};env.SLClientInspection=api
    local player=game:GetService('Players').LocalPlayer
    local world=game:GetService('Workspace');local own
    for _,root in ipairs(world:GetChildren())do
        local owner=root:FindFirstChild('Owner')
        if root.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==player then own=root;break end
    end
    if own then
        log('OWNED '..own:GetFullName())
        local values=own:FindFirstChild('Values');local upgrades=values and values:FindFirstChild('Upgrades')
        if upgrades then
            local keys={};for key in pairs(upgrades:GetAttributes())do keys[#keys+1]=key end;table.sort(keys)
            log('INTERNAL_STAND_KEYS '..table.concat(keys,', '))
        end
        local count=0
        for _,o in ipairs(own:GetDescendants())do
            if o:IsA('RemoteFunction') or o:IsA('RemoteEvent') then
                count=count+1;if count>80 then log('REMOTE_LIST_TRUNCATED');break end
                log('REMOTE '..o.ClassName..' '..o:GetFullName())
            end
        end
    end
    local function priority(name)
        local n=name:lower()
        -- Follow the dependencies found in UIManageTileEarner's captured bytecode.
        local selected={balance=0,config=1,huge=2,tycoonascension=3,tycooninversion=4,tycoonincome=5,tycoonpowers=6,tycoonpurchasable=7}
        if selected[n] then return selected[n] end
        if n:find('upgrade',1,true) then return 8 end
        if n:find('manage',1,true) then return 9 end
        if n=='clienttycoon' then return 10 end
        if n:find('income',1,true) then return 11 end
        if n:find('tycoon',1,true) then return 12 end
        return nil
    end
    local candidates={};local seen={}
    local function scan(root)
        if not root then return end
        for _,o in ipairs(root:GetDescendants())do
            if not seen[o] and (o:IsA('ModuleScript') or o:IsA('LocalScript')) then
                seen[o]=true;local rank=priority(o.Name)
                if rank then candidates[#candidates+1]={object=o,rank=rank,path=o:GetFullName()} end
            end
        end
    end
    scan(game:GetService('ReplicatedStorage'));scan(player:FindFirstChild('PlayerScripts'));scan(player:FindFirstChild('PlayerGui'))
    table.sort(candidates,function(a,b)return a.rank==b.rank and a.path<b.path or a.rank<b.rank end)
    for i,row in ipairs(candidates)do
        if i>60 then log('CANDIDATE_LIST_TRUNCATED');break end
        log('CANDIDATE '..i..' '..row.path)
    end
    local total=0;local unsupported=false;local byteTotal=0
    local function exportBytes(id,row)
        if row.rank>7 or type(readBytes)~='function' then return end
        local ok,data=pcall(readBytes,row.object)
        if not ok or type(data)~='string' then log('BYTECODE_FAILED '..row.path);return end
        if #data<4 or #data>65536 or byteTotal+#data>262144 then log('BYTECODE_LIMIT '..row.path..' bytes='..#data);return end
        byteTotal=byteTotal+#data
        local a,b=1,0
        for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end
        print('[SL BC] BEGIN '..id..' bytes='..#data..' adler='..(b*65536+a)..' path='..row.path)
        for offset=1,#data,192 do
            local hex=data:sub(offset,offset+191):gsub('.',function(ch)return string.format('%02x',ch:byte())end)
            print('[SL BC] PART '..id..' '..offset..' '..hex)
            if offset%3072==1 then task.wait()end
        end
        print('[SL BC] END '..id)
    end
    for i,row in ipairs(candidates)do
        if i>10 or total>=48000 then log('SOURCE_LIMIT; remaining candidates not inspected');break end
        log('DECOMPILE '..i..' '..row.path);api.status='READING'
        local completed,resultOK,result
        if unsupported then completed=true;resultOK=true;result='Bytecode version unsupported' else
            task.spawn(function()resultOK,result=pcall(decode,row.object);completed=true end)
        end
        local deadline=os.clock()+12
        while not completed and os.clock()<deadline do task.wait(.1)end
        if not completed then
            log('TIMEOUT '..row.path..'; stopping, no further decompile started')
            api.status='TIMEOUT';api.active=false;return api
        end
        if resultOK and type(result)=='string' then
            if result:find('Bytecode version',1,true) and (result:find('unhandled',1,true) or unsupported) then
                unsupported=true;log('DECOMPILER_VERSION_UNSUPPORTED '..row.path)
                exportBytes(i,row)
            else
            api.sources[row.path]=result
            local length=math.min(#result,12000,48000-total);total=total+length
            log('SOURCE '..i..' bytes='..#result..' shown='..length)
            local line=0
            for s in (result:sub(1,length)..'\n'):gmatch('(.-)\n')do
                line=line+1
                for offset=1,math.max(1,#s),300 do log(i..':'..line..' '..s:sub(offset,offset+299))end
            end
            if length<#result then log('SOURCE_TRUNCATED '..i)end
            end
        else log('DECOMPILE_FAILED '..row.path..' '..tostring(result):sub(1,250))end
    end
    api.active=false;api.status='DONE';log('DONE; source is diagnostic evidence, not executed or automatically trusted')
    return api
end

end)()
if result and not result.active then inspect() end
return result
