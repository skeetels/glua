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
