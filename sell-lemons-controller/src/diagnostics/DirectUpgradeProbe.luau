-- One round of +1 upgrades on owned enabled earners. No mouse, windows or resets.
-- Signature recovered from ClientTycoonEarner.UpgradeAsync and RemoteRequest.
return function()
    local function log(s)print('[SL DIRECT] '..s)end
    assert(game.PlaceId==79268393072444,'Run in Sell Lemons')
    local env=type(getgenv)=='function' and getgenv() or _G
    if env.SLDirectProbe and env.SLDirectProbe.active then log('PREVIOUS_BATCH_PENDING');return end
    -- A probe must not compete with the economic worker, including a late callback.
    if env.SLAutofarm then
        local controller=env.SLAutofarm
        if type(controller.pause)~='function' or type(controller.callbackPending)~='function' or type(controller.unload)~='function' then
            log('CONTROLLER_STATE_UNKNOWN');return
        end
        controller.pause()
        if controller.callbackPending() then log('CONTROLLER_CALLBACK_PENDING');return end
        controller.unload()
    end
    local api={active=true};env.SLDirectProbe=api
    local function run()
        log('START: one +1 request per enabled owned stand; receipt requires replicated level change')
        local player=game:GetService('Players').LocalPlayer
        local rs=game:GetService('ReplicatedStorage');local world=game:GetService('Workspace');local own
        for _,root in ipairs(world:GetChildren())do
            local owner=root:FindFirstChild('Owner')
            if root.Name:match('^Tycoon%d+$') and owner and owner:IsA('ObjectValue') and owner.Value==player then own=root;break end
        end
        assert(own,'Owned base not found')
        local rootValues=assert(own:FindFirstChild('Values'),'Values missing')
        local values=assert(rootValues:FindFirstChild('Values'),'Values/Values missing')
        local levels=assert(rootValues:FindFirstChild('Upgrades'),'Values/Upgrades missing')
        log('REQUIRE ClientTycoonEarner')
        local class=require(rs.Modules.Tycoon.Entity.Client.ClientTycoonEarner)
        local huge=require(rs.Modules.Huge)
        assert(type(class)=='table' and type(class.getAll)=='function','Earner registry unavailable')
        assert(math.abs(huge.toHuge(10)-1)<1e-8 and math.abs(huge.toNumber(1)-10)<1e-8,'Huge encoding changed')
        local all=class:getAll();assert(type(all)=='table','Earner registry not a table')
        local cash=values:GetAttribute('Cash');assert(type(cash)=='number' and cash==cash,'Cash unavailable')
        local entries={};local names={};local budget=huge.zero
        for _,earner in pairs(all)do
            local instance=earner.Instance
            if typeof(instance)=='Instance' and instance:IsDescendantOf(own) and earner:IsEnabled() then
                local remote=instance:FindFirstChild('Upgrade')
                local name=earner.Name;local level=levels:GetAttribute(name) or 0
                if remote and remote:IsA('RemoteFunction') and not names[name] and earner:GetUpgradeLevel()==level then
                    local price,count=earner:GetUpgradePrice(nil,1)
                    assert(type(price)=='number' and price==price and count==1,'Unexpected +1 quote')
                    log('QUOTE '..name..' level='..level..' priceLog='..price..' cashLog='..cash)
                    local sum=huge.add(budget,price)
                    if sum<=cash and price<math.huge then
                        budget=sum;names[name]=true
                        entries[#entries+1]={name=name,level=level,price=price,remote=remote,earner=earner}
                    end
                end
            end
        end
        assert(#entries<=8,'Unexpected stand count')
        if #entries==0 then log('NO_AFFORDABLE_ENABLED_STAND');return end
        -- Validate the entire batch before dispatching any part of it.
        assert(own:FindFirstChild('Owner').Value==player,'Owner changed')
        assert(values:GetAttribute('Cash')>=budget,'Batch no longer funded')
        local epoch={};for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do epoch[key]=values:GetAttribute(key)end
        for _,entry in ipairs(entries)do
            local price,count=entry.earner:GetUpgradePrice(nil,1)
            assert(price==entry.price and count==1 and (levels:GetAttribute(entry.name) or 0)==entry.level,'Quote changed before dispatch')
        end
        log('DISPATCH stands='..#entries..' combinedPriceLog='..budget..'; parallel, no GUI input')
        local pending=#entries;api.pending=pending;local start=os.clock()
        for _,entry in ipairs(entries)do
            task.spawn(function()
                local ok,err=pcall(function()
                    assert(own:FindFirstChild('Owner').Value==player,'Owner changed')
                    for key,value in pairs(epoch)do assert(values:GetAttribute(key)==value,'Reset changed')end
                    entry.remote:InvokeServer(1)
                end)
                entry.returned=true;entry.ok=ok;entry.error=not ok and tostring(err) or nil
                pending=pending-1;api.pending=pending
                log('RETURN '..entry.name..' ok='..tostring(ok)..(entry.error and (' '..entry.error) or ''))
                if pending==0 and api.timedOut then api.active=false end
            end)
        end
        repeat
            local proved=0
            for _,entry in ipairs(entries)do
                local level=levels:GetAttribute(entry.name) or 0
                if entry.returned and entry.ok and level==entry.level+1 then proved=proved+1 end
            end
            if pending==0 and proved==#entries then break end
            task.wait(.1)
        until os.clock()-start>=8
        for _,entry in ipairs(entries)do
            local level=levels:GetAttribute(entry.name) or 0
            log('RECEIPT '..entry.name..' '..entry.level..'->'..level..' confirmed='..tostring(entry.returned and entry.ok and level==entry.level+1))
        end
        api.timedOut=pending>0;api.active=api.timedOut
        log('DONE pending='..pending..'; this probe will not repeat any request')
    end
    local ok,err=pcall(run)
    if not ok then log('ERROR '..tostring(err));api.active=(api.pending or 0)>0 end
    if not api.pending then api.active=false end
    return api
end
