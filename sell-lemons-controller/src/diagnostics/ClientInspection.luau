-- Read client handlers as text. Never require them or invoke any game remote.
return function()
    local function log(s)print('[SL CLIENT] '..s)end
    log('START v1; client text only; no purchases or hooks')
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    local decode=type(env.decompile)=='function' and env.decompile or decompile
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
        if n:find('upgrade',1,true) then return 1 end
        if n:find('manage',1,true) then return 2 end
        if n=='clienttycoonincome' then return 3 end
        if n=='clienttycoon' then return 4 end
        if n:find('income',1,true) then return 5 end
        if n=='remotetable' then return 6 end
        if n:find('tycoon',1,true) then return 7 end
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
    local total=0
    for i,row in ipairs(candidates)do
        if i>10 or total>=48000 then log('SOURCE_LIMIT; remaining candidates not inspected');break end
        log('DECOMPILE '..i..' '..row.path);api.status='READING'
        local completed,resultOK,result
        task.spawn(function()resultOK,result=pcall(decode,row.object);completed=true end)
        local deadline=os.clock()+12
        while not completed and os.clock()<deadline do task.wait(.1)end
        if not completed then
            log('TIMEOUT '..row.path..'; stopping, no further decompile started')
            api.status='TIMEOUT';api.active=false;return api
        end
        if resultOK and type(result)=='string' then
            api.sources[row.path]=result
            local length=math.min(#result,12000,48000-total);total=total+length
            log('SOURCE '..i..' bytes='..#result..' shown='..length)
            local line=0
            for s in (result:sub(1,length)..'\n'):gmatch('(.-)\n')do
                line=line+1
                for offset=1,math.max(1,#s),300 do log(i..':'..line..' '..s:sub(offset,offset+299))end
            end
            if length<#result then log('SOURCE_TRUNCATED '..i)end
        else log('DECOMPILE_FAILED '..row.path..' '..tostring(result):sub(1,250))end
    end
    api.active=false;api.status='DONE';log('DONE; source is diagnostic evidence, not executed or automatically trusted')
    return api
end
