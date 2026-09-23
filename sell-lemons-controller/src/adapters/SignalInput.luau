-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.driverCandidates(name,direct)
    local out,seen={},{}
    local function add(fn,source)
        if type(fn)=='function' and not seen[fn] then
            seen[fn]=true;out[#out+1]={fn=fn,source=source}
        end
    end
    add(direct,'global')
    add(__slctx.prop(__slctx.env,name),'captured env')
    if type(getgenv)=='function' then
        local ok,e=pcall(getgenv)
        if ok and type(e)=='table' then add(__slctx.prop(e,name),'getgenv') end
    end
    add(__slctx.prop(_G,name),'_G')
    if type(getfenv)=='function' then
        local ok,e=pcall(getfenv,0)
        if ok and type(e)=='table' then add(__slctx.prop(e,name),'getfenv(0)') end
    end
    return out
end
function __slctx.connectionCallable(c,mode)
    return __slctx.prop(c,'Enabled')~=false and __slctx.prop(c,'LuaConnection')~=false
        and __slctx.prop(c,'ForeignState')~=true and type(__slctx.prop(c,mode))=='function'
end
function __slctx.invokeConnection(c,mode,args)
    local fn=__slctx.prop(c,mode)
    if type(fn)~='function' then error('CONNECTION_METHOD_MISSING: '..tostring(mode),0) end
    if mode=='Function' then
        return fn(table.unpack(args,1,args.n))
    end
    return fn(c,table.unpack(args,1,args.n))
end
function __slctx.listConnections(signal)
    if not __slctx.Driver.connections or not signal then return nil end
    local ok,cs=pcall(__slctx.Driver.connections,signal)
    if not ok or type(cs)~='table' then return nil end
    local out={}
    for _,c in pairs(cs) do
        if __slctx.connectionCallable(c,__slctx.Driver.connectionMode) then out[#out+1]=c end
    end
    return out
end
function __slctx.signalCount(button,name)
    local cs=__slctx.listConnections(__slctx.prop(button,name))
    return cs and #cs or nil
end
function __slctx.fireEvent(signal,...)
    if not signal then return false,'SIGNAL_MISSING' end
    if __slctx.Driver.fire then
        local ok,value,err=pcall(__slctx.Driver.fire,signal,...)
        if not ok then return false,value end
        if value==false then return false,err or 'SIGNAL_CALL_RETURNED_FALSE' end
        return true
    end
    local cs=__slctx.listConnections(signal)
    if not cs or #cs==0 then return false,'NO_LUA_CONNECTIONS' end
    local args=table.pack(...)
    local any,errors=false,{}
    for _,c in ipairs(cs) do
        -- One pre-tested invocation method. Never try multiple methods on a real purchase.
        local ok,value,err=pcall(__slctx.invokeConnection,c,__slctx.Driver.connectionMode,args)
        -- GUI callback return values do not acknowledge a server transaction.
        any=ok or any
        if not ok then errors[#errors+1]=tostring(value) end
    end
    return any,table.concat(errors,'; ')
end
function __slctx.driverProbe(name,invoke,args,epoch)
    local screen=Instance.new('ScreenGui')
    screen.Name='SLAutofarmInputProbe';screen.Enabled=false;screen.Parent=__slctx.gui
    local b=Instance.new('TextButton')
    b.Name='Probe';b.Visible=false;b.Parent=screen
    local hits,matched=0,false
    local signal=b[name]
    local connection=signal:Connect(function(...)
        hits=hits+1
        local got=table.pack(...);matched=got.n==args.n
        for i=1,args.n do if got[i]~=args[i] then matched=false end end
    end)
    local result={done=false,ok=false}
    local worker=task.spawn(function()
        local ok,value,err=pcall(invoke,signal,args)
        result.ok=ok and value~=false
        result.error=not ok and tostring(value) or (value==false and tostring(err or 'returned false') or nil)
        result.done=true
    end)
    local deadline=__slctx.now()+1.25
    while not __slctx.S.unloaded and __slctx.S.epoch==epoch and __slctx.now()<deadline do
        if result.done and (not result.ok or hits>0) then break end
        -- Yield for Deferred events / asynchronous executor wrappers.
        task.wait(0.03)
    end
    local cancelled=__slctx.S.unloaded or __slctx.S.epoch~=epoch
    local passed=not cancelled and result.done and result.ok and hits==1 and matched
    local reason=passed and 'callback confirmed'
        or cancelled and 'cancelled'
        or not result.done and 'API call did not finish within 1.25s'
        or result.error
        or hits==0 and 'API returned but test callback did not run within 1.25s'
        or 'callback argument/count mismatch'
    if not result.done and type(worker)=='thread' and type(task.cancel)=='function' then
        pcall(task.cancel,worker)
    end
    pcall(connection.Disconnect,connection)
    pcall(b.Destroy,b);pcall(screen.Destroy,screen)
    return passed,reason
end
function __slctx.selfTest()
    __slctx.Virtual.dispose()
    __slctx.Driver.fire=nil;__slctx.Driver.connections=nil;__slctx.Driver.connectionMode=nil;__slctx.Driver.host='unknown'
    local epoch=__slctx.S.epoch
    local fires=__slctx.driverCandidates('firesignal',firesignal)
    local getters=__slctx.driverCandidates('getconnections',getconnections)
    __slctx.Driver.present=#fires+#getters>0
    __slctx.log('INPUT_APIS','firesignal candidates='..#fires..'; getconnections candidates='..#getters)
    local ids=__slctx.driverCandidates('identifyexecutor',identifyexecutor)
    if #ids==0 then ids=__slctx.driverCandidates('getexecutorname',getexecutorname) end
    if ids[1] then
        local ok,name,version=pcall(ids[1].fn)
        if ok then __slctx.Driver.host=tostring(name)..' '..tostring(version or '') end
    end
    __slctx.log('INPUT_HOST',__slctx.Driver.host)
    -- Missing callback APIs do not rule out a working engine-local input backend.
    local probeEvents={
        {name='MouseButton1Click',args=table.pack()},
        {name='Activated',args=table.pack(__slctx.S.lastInput,1)},
    }
    for _,candidate in ipairs(fires) do
        for _,ev in ipairs(probeEvents) do
            if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return false,'INPUT_TEST_CANCELLED' end
            local ok,reason=__slctx.driverProbe(ev.name,function(signal,args)
                return candidate.fn(signal,table.unpack(args,1,args.n))
            end,ev.args,epoch)
            __slctx.log('INPUT_TEST','firesignal/'..candidate.source..'/'..ev.name..': '..reason)
            if ok then __slctx.Driver.fire=candidate.fn;break end
        end
        if __slctx.Driver.fire then break end
    end
    for _,candidate in ipairs(getters) do
        for _,mode in ipairs({'Fire','Defer','Function'}) do
            if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return false,'INPUT_TEST_CANCELLED' end
            local ev=probeEvents[1]
            local ok,reason=__slctx.driverProbe(ev.name,function(signal,args)
                local cs=candidate.fn(signal)
                if type(cs)~='table' then return false,'getconnections returned '..type(cs)..', expected table' end
                local found=0
                for _,c in pairs(cs) do
                    if __slctx.connectionCallable(c,mode) then
                        found=found+1
                        __slctx.invokeConnection(c,mode,args)
                    end
                end
                if found==0 then return false,'no enabled local connection with '..mode end
                return true
            end,ev.args,epoch)
            __slctx.log('INPUT_TEST','getconnections/'..candidate.source..'/'..mode..': '..reason)
            if ok then __slctx.Driver.connections=candidate.fn;__slctx.Driver.connectionMode=mode;break end
        end
        if __slctx.Driver.connections then break end
    end
    if not __slctx.Driver.fire and not __slctx.Driver.connections and __slctx.CONFIG.EnableVirtualInput and not __slctx.S.unloaded and __slctx.S.epoch==epoch then
        __slctx.Virtual.check(epoch)
    end
    local passed=__slctx.Driver.fire~=nil or __slctx.Driver.connections~=nil or __slctx.Driver.virtual~=nil
    if not __slctx.Driver.present then return false,'INPUT_API_MISSING' end
    __slctx.log('INPUT_RESULT',passed and ('verified: '..(__slctx.Driver.virtual and 'VirtualInputManager' or __slctx.Driver.fire and 'firesignal' or 'getconnections.'..__slctx.Driver.connectionMode))
        or 'No tested input backend. Open Journal for exact errors.')
    return passed,passed and 'INPUT_READY' or 'INPUT_API_TEST_FAILED'
end

function __slctx.dispatch(button,mode,options)
    if options and options.guard and not options.guard() then return false,'STATE_CHANGED_BEFORE_CLICK' end
    if mode=='VirtualInput' then return __slctx.Virtual.click(button,options and options.guard) end
    local pos=__slctx.prop(button,'AbsolutePosition') or Vector2.new(0,0)
    local size=__slctx.prop(button,'AbsoluteSize') or Vector2.new(0,0)
    local x,y=pos.X+size.X/2,pos.Y+size.Y/2
    if mode=='Activated' then return __slctx.fireEvent(button.Activated,__slctx.S.lastInput,1) end
    if mode=='MouseButton1Click' then return __slctx.fireEvent(button.MouseButton1Click) end
    if mode=='MousePair' then
        local a,err=__slctx.fireEvent(button.MouseButton1Down,x,y)
        if __slctx.CONFIG.ClickHoldSeconds>0 then task.wait(__slctx.CONFIG.ClickHoldSeconds) end
        local b,err2=__slctx.fireEvent(button.MouseButton1Up,x,y)
        return a or b,err or err2
    end
    if mode=='InputPair' then
        -- Optional compatibility path for table-compatible custom UI handlers.
        -- This is NOT a real engine InputObject. Type-checking handlers may reject it.
        local changed=Instance.new('BindableEvent')
        local input={UserInputType=Enum.UserInputType.MouseButton1,
            UserInputState=Enum.UserInputState.Begin,KeyCode=Enum.KeyCode.Unknown,
            Position=Vector3.new(x,y,0),Delta=Vector3.new(0,0,0),Changed=changed.Event}
        input.GetPropertyChangedSignal=function() return changed.Event end
        local ok,err=__slctx.fireEvent(button.InputBegan,input)
        if __slctx.CONFIG.ClickHoldSeconds>0 then task.wait(__slctx.CONFIG.ClickHoldSeconds) end
        input.UserInputState=Enum.UserInputState.End
        changed:Fire('UserInputState')
        local ok2,err2=__slctx.fireEvent(button.InputEnded,input)
        task.delay(0.5,function() changed:Destroy() end)
        return ok or ok2,err or err2
    end
    return false,'INVALID_CLICK_MODE'
end
function __slctx.candidateModes(button,kind)
    local directUpgrade=kind=='upgrade' and __slctx.CONFIG.ClickMode=='Auto' and (__slctx.Driver.fire or __slctx.Driver.connections)
    if __slctx.Driver.virtual and not directUpgrade then return {'VirtualInput'} end
    if __slctx.CONFIG.ClickMode~='Auto' then return {__slctx.CONFIG.ClickMode} end
    local modes={}
    local function add(mode)
        if not mode then return end
        if directUpgrade and mode=='VirtualInput' then return end
        for _,m in ipairs(modes) do if m==mode then return end end
        local names=mode=='MousePair' and {'MouseButton1Down','MouseButton1Up'}
            or mode=='InputPair' and {'InputBegan','InputEnded'} or {mode}
        local known,found=true,0
        for _,name in ipairs(names) do
            local count=__slctx.signalCount(button,name)
            if count==nil then known=false else found=found+count end
        end
        if not known or found>0 then modes[#modes+1]=mode end
    end
    add(__slctx.S.profile[kind]);add(__slctx.S.profile.navigation)
    add('Activated');add('MouseButton1Click');add('MousePair')
    if __slctx.CONFIG.AllowInputPair then add('InputPair') end
    if #modes==0 and __slctx.Driver.virtual then modes[1]='VirtualInput' end
    return modes
end
function __slctx.signalSummary(button)
    local out={}
    for _,k in ipairs({'Activated','MouseButton1Click','MouseButton1Down','MouseButton1Up','InputBegan','InputEnded'}) do
        out[#out+1]=k..'='..tostring(__slctx.signalCount(button,k) or '?')
    end
    return table.concat(out,', ')
end
function __slctx.Driver.perform(button,kind,predicate,options)
    options=options or {}
    if __slctx.Driver.releaseBlocked then return false,'INPUT_RELEASE_UNRESOLVED' end
    if __slctx.Driver.pressed and __slctx.Driver.pressed.kind=='buyHold' then
        __slctx.Virtual.release();return false,'BUY_HOLD_RELEASE_RECONCILE'
    end
    if not __slctx.Focus.await() then return false,'PAUSED' end
    if not __slctx.live() then return false,'PAUSED' end
    if __slctx.S.actionPending or __slctx.S.resetChildPending then return false,'PREVIOUS_CALLBACK_PENDING' end
    if not __slctx.usable(button) or __slctx.paid(button) then return false,'BUTTON_UNAVAILABLE' end
    local modes=__slctx.candidateModes(button,kind)
    local epoch=__slctx.S.epoch
    if #modes==0 then return false,'NO_BUTTON_HANDLERS: '..__slctx.signalSummary(button) end
    if options.once then modes={modes[1]} end
    local summary=__slctx.Driver.virtual and 'virtual-input hit-test + observed GUI receipt' or __slctx.signalSummary(button)
    __slctx.S.signalCounts[kind]=summary
    for _,mode in ipairs(modes) do
        if not __slctx.live(epoch) then return false,'PAUSED' end
        if predicate() then return false,'STATE_CHANGED_BEFORE_CLICK' end
        if not __slctx.usable(button) or (options.guard and not options.guard()) then return false,'STATE_CHANGED_BEFORE_CLICK' end
        local result={done=false,ok=false}
        __slctx.S.actionPending=result
        local targetName=button:GetFullName()
        __slctx.Driver.buttonTimes=__slctx.Driver.buttonTimes or setmetatable({},{__mode='k'})
        local hint=tonumber(__slctx.attr(button,'MinimumRepeatDelay')) or 0
        hint=math.max(0,math.min(hint,1)) -- scheduling hint, not proof of a server rate limit.
        local due=math.max((__slctx.Driver.lastSentAt or -math.huge)+__slctx.CONFIG.RequestedClickInterval,
            (__slctx.Driver.buttonTimes[button] or -math.huge)+hint)
        if __slctx.now()<due then task.wait(due-__slctx.now()) end
        if not __slctx.live(epoch) then __slctx.S.actionPending=nil;return false,'PAUSED' end
        __slctx.Driver.lastSentAt=__slctx.now();__slctx.Driver.buttonTimes[button]=__slctx.now()
        __slctx.log('TRY_'..kind,string.format('%s | %s',mode,targetName))
        result.thread=task.spawn(function()
            local ok,inner,err=pcall(function()
                if options.onDispatch then options.onDispatch(button,mode) end
                return __slctx.dispatch(button,mode,options)
            end)
            result.ok=ok and inner~=false
            if not ok then result.err=inner else result.err=err end
            result.done=true
            if __slctx.S.actionPending==result then __slctx.S.actionPending=nil end
        end)
        local deadline=__slctx.now()+(options.timeout or (__slctx.S.windowFocused==false and __slctx.CONFIG.BackgroundActionTimeout or __slctx.CONFIG.ActionTimeout))
        local effectSince=nil;local effectKey=nil;local firstProofAt=nil;local operationStart=__slctx.now()
        local lastMaintenance=0
        repeat
            if not __slctx.live(epoch) then return false,'PAUSED_WITH_ACTION_IN_FLIGHT' end
            local awake,held=__slctx.Focus.await(epoch)
            deadline=deadline+(held or 0)
            if not awake then return false,'PAUSED_WITH_ACTION_IN_FLIGHT' end
            local ok,effect=pcall(predicate)
            if ok and effect and result.done and result.ok then
                firstProofAt=firstProofAt or __slctx.now()
                if options.effectKey then
                    local kOK,k=pcall(options.effectKey)
                    if not kOK or k==nil or k~=effectKey then effectSince=nil;effectKey=kOK and k or nil end
                end
                effectSince=effectSince or __slctx.now()
                if __slctx.now()-effectSince >= (options.stableFor or 0) then
                    __slctx.S.profile[kind]=mode
                    __slctx.log('CONFIRMED_'..kind,targetName)
                    if kind=='buy' then
                        __slctx.S.buyProofProfile=__slctx.S.buyProofProfile or {count=0,toProof=0,stable=0}
                        local z=__slctx.S.buyProofProfile;z.count=z.count+1;z.toProof=z.toProof+(firstProofAt-operationStart)
                        z.stable=z.stable+(__slctx.now()-firstProofAt)
                    end
                    return true,mode
                end
            else
                effectSince=nil
            end
            if options.maintenance and __slctx.now()-lastMaintenance>(options.maintenanceInterval or 0.5) then
                lastMaintenance=__slctx.now();options.maintenance()
            end
            if options.abortReason and result.done and not __slctx.S.resetChildPending then
                local reason=options.abortReason()
                if reason then return false,reason end
            end
            if options.extraDeadline then
                local okDeadline,extra=pcall(options.extraDeadline)
                if okDeadline and type(extra)=='number' then deadline=math.max(deadline,extra) end
            end
            if result.done and not result.ok then break end
            __slctx.S.actionYieldSerial=(__slctx.S.actionYieldSerial or 0)+1
            task.wait(__slctx.CONFIG.ConfirmationPollSeconds)
        until __slctx.now()>=deadline
        if result.err~=nil and result.err~=true then __slctx.log('HANDLER_MESSAGE',tostring(result.err)) end
        if not result.done then
            -- Never start a second economic action after an unknown callback result.
            -- Cancelling our suspended invocation stops resource leaks; it cannot undo
            -- a server request, so callers must still reconcile/pause.
            if result.thread and type(task.cancel)=='function' then pcall(task.cancel,result.thread) end
            result.done=true;result.ok=false
            if __slctx.S.actionPending==result then __slctx.S.actionPending=nil end
            return false,'CALLBACK_STILL_PENDING: '..targetName
        end
        if not result.ok then return false,tostring(result.err or 'DISPATCH_FAILED') end
        if options.once then break end
        -- Only non-reset actions have alternate-mode retries; each is re-validated.
    end
    return false,'NO_CONFIRMED_EFFECT: '..button:GetFullName()..' | '..summary
end

function __slctx.Driver.navigate(button,predicate,options)
    local lastError='NAVIGATION_NOT_CONFIRMED'
    for attempt=1,3 do
        if not __slctx.live() then return false,'PAUSED' end
        if __slctx.S.actionPending or __slctx.S.resetChildPending then return false,'PREVIOUS_CALLBACK_PENDING' end
        -- Menu visibility is the receipt. A delayed successful open/close must
        -- be accepted before retrying a toggle that could undo it.
        local checked,reached=pcall(predicate)
        if checked and reached then return true,'NAVIGATION_ALREADY_REACHED' end
        local ok,err=__slctx.Driver.perform(button,'navigation',predicate,options)
        if ok then return true,err end
        lastError=tostring(err)
        if not __slctx.live() or lastError:find('PENDING',1,true) or lastError:find('PAUSED',1,true) then return false,lastError end
        if attempt<3 then
            __slctx.log('NAVIGATION_RETRY',attempt..'/3 | '..lastError)
            if not __slctx.sleep(0.3) then return false,'PAUSED' end
        end
    end
    return false,lastError
end


end
