-- Optional idle-input service with lifecycle cleanup. Does not disable game listeners.
return function(ctx)
    local service={enabled=true,status='WAITING_FOR_IDLE',attempts=0,lastAttempt=-math.huge}
    ctx.AntiIdle=service
    function ctx.API.antiIdle(enabled)
        if enabled~=nil then service.enabled=enabled==true end
        return {enabled=service.enabled,status=service.status,attempts=service.attempts}
    end
    local ok,virtualUser=pcall(game.GetService,game,'VirtualUser')
    if not ok or not virtualUser then service.status='API_UNAVAILABLE';return end
    local connection=ctx.player.Idled:Connect(function()
        if ctx.S.unloaded or not service.enabled or ctx.now()-service.lastAttempt<30 then return end
        -- Keep idle activity away from economic input / confirmation transactions.
        if ctx.S.actionPending or ctx.S.resetChildPending or ctx.S.resetSession or ctx.Driver.pressed then
            service.status='DEFERRED_DURING_TRANSACTION';return
        end
        local camera=workspace.CurrentCamera
        if not camera then service.status='CAMERA_UNAVAILABLE';return end
        local cameraFrame=camera.CFrame
        service.lastAttempt=ctx.now();service.attempts=service.attempts+1
        service.pending=true
        local success=pcall(function()
            virtualUser:CaptureController()
            virtualUser:Button2Down(Vector2.new(0,0),cameraFrame)
        end)
        task.delay(0.1,function()
            local released=pcall(function()
                virtualUser:Button2Up(Vector2.new(0,0),cameraFrame)
            end)
            service.status=success and released and 'INPUT_SENT_UNVERIFIED' or 'INPUT_API_FAILED'
            service.pending=false
        end)
    end)
    ctx.S.connections[#ctx.S.connections+1]=connection
end
