-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.Driver={fire=nil,connections=nil,connectionMode=nil,host='unknown',present=false,virtualProfiles={}}
-- VIRTUAL_DRIVER_BEGIN
-- Engine-local input only. No OS pointer APIs, native mouse wrappers, or remotes.
-- Success is an observed click on an isolated GUI button, never a successful pcall.
__slctx.Virtual={}
function __slctx.ancestorOf(o,root)
    for _=1,80 do
        if o==root then return true end
        o=__slctx.prop(o,'Parent');if not o then break end
    end
    return false
end
function __slctx.screenStyle(button)
    local p=button
    for _=1,80 do
        if not p then break end
        if p:IsA('ScreenGui') then
            local ignore=__slctx.prop(p,'IgnoreGuiInset')==true
            local insets=__slctx.prop(p,'ScreenInsets')
            return {ignore=ignore,insets=insets,key=tostring(ignore)..'/'..tostring(insets)}
        end
        p=__slctx.prop(p,'Parent')
    end
    return {ignore=false,key='false/nil'}
end
function __slctx.currentInset()
    local ok,service=pcall(game.GetService,game,'GuiService')
    if ok then
        local valid,p=pcall(service.GetGuiInset,service)
        if valid and p then return p.X,p.Y end
    end
    return 0,0
end
function __slctx.topTargetAt(button,x,y)
    -- PlayerGui hit tests alone cannot see Roblox's own menus/purchase dialogs.
    -- Fail closed when the overlay query is unavailable; do not click through a prompt.
    local okService,service=pcall(game.GetService,game,'GuiService')
    if okService and __slctx.prop(service,'MenuIsOpen')==true then return false,'ROBLOX_MENU_OPEN' end
    local okCore,coreGui=pcall(game.GetService,game,'CoreGui')
    if not okCore or not coreGui then return false,'CORE_GUI_HIT_TEST_UNAVAILABLE' end
    local okHits,coreHits=pcall(function() return coreGui:GetGuiObjectsAtPosition(x,y) end)
    if not okHits or type(coreHits)~='table' then return false,'CORE_GUI_HIT_TEST_UNAVAILABLE' end
    for _,o in ipairs(coreHits) do
        if o:IsA('GuiButton') or __slctx.prop(o,'Active')==true then return false,'CORE_GUI_OVERLAY: '..tostring(__slctx.prop(o,'Name')) end
    end
    local ok,objects=pcall(__slctx.gui.GetGuiObjectsAtPosition,__slctx.gui,x,y)
    if not ok or type(objects)~='table' then return false,'HIT_TEST_UNAVAILABLE' end
    for _,o in ipairs(objects) do
        if __slctx.ancestorOf(o,button) then return true end
        if o:IsA('GuiButton') or __slctx.prop(o,'Active')==true then
            return false,'COVERED_BY: '..tostring(__slctx.prop(o,'Name'))
        end
    end
    return false,'TARGET_NOT_AT_CLICK_POINT'
end
function __slctx.Virtual.release()
    local p=__slctx.Driver.pressed
    if not p then return true end
    local ok,err
    for _=1,2 do
        ok,err=pcall(function() p.vim:SendMouseButtonEvent(p.x,p.y,0,false,game,0) end)
        if ok then __slctx.Driver.pressed=nil;__slctx.Driver.releaseBlocked=nil;return true end
    end
    __slctx.Driver.releaseBlocked=true
    __slctx.log('VIRTUAL_RELEASE_ERROR',tostring(err)..'; further game input blocked')
    return false,err
end
__slctx.S.releaseInput=__slctx.Virtual.release
function __slctx.Virtual.runHeld(vim,x,y,body)
    if __slctx.Driver.pressed or __slctx.Driver.releaseBlocked then return false,'INPUT_ALREADY_PRESSED' end
    local pressed={vim=vim,x=x,y=y,kind='buyHold',epoch=__slctx.S.epoch}
    __slctx.Driver.pressed=pressed
    local down,downError=pcall(function() vim:SendMouseButtonEvent(x,y,0,true,game,0) end)
    local ok,result=false,downError
    if down then ok,result=pcall(body,pressed) end
    local released,releaseError=__slctx.Virtual.release()
    if not released then return false,'RELEASE_FAILED: '..tostring(releaseError) end
    if not down or not ok then return false,tostring(result) end
    return true,result
end
function __slctx.sendPair(vim,x,y)
    if __slctx.Driver.pressed then return false,'INPUT_ALREADY_PRESSED' end
    __slctx.Driver.pressed={vim=vim,x=x,y=y}
    local ok,err=pcall(function() vim:SendMouseButtonEvent(x,y,0,true,game,0) end)
    if ok and __slctx.CONFIG.ClickHoldSeconds>0 then task.wait(__slctx.CONFIG.ClickHoldSeconds) end
    -- Always send the release, even when the worker was paused after mouse-down.
    local released,releaseErr=__slctx.Virtual.release()
    if not ok then return false,tostring(err) end
    if not released then return false,'RELEASE_FAILED: '..tostring(releaseErr) end
    return true
end
function __slctx.Virtual.restorePlayerList()
    local service=__slctx.Driver.hiddenPlayerList
    __slctx.Driver.hiddenPlayerList=nil
    if service then pcall(service.SetCoreGuiEnabled,service,Enum.CoreGuiType.PlayerList,true) end
end
function __slctx.Virtual.dispose()
    local released=__slctx.Virtual.release()
    __slctx.Virtual.restorePlayerList()
    if not released then return false end
    if __slctx.Driver.virtualOwned and __slctx.Driver.virtual then pcall(__slctx.Driver.virtual.Destroy,__slctx.Driver.virtual) end
    __slctx.Driver.virtual=nil;__slctx.Driver.virtualOwned=false;__slctx.Driver.virtualProfiles={}
    if __slctx.Driver.probeScreen then pcall(__slctx.Driver.probeScreen.Destroy,__slctx.Driver.probeScreen);__slctx.Driver.probeScreen=nil end
    return true
end
function __slctx.Virtual.probe(vim,style,epoch,unfocusedProbe)
    if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return nil,'CANCELLED' end
    local screen,probe,shield,connection
    local function cleanup()
        if connection then pcall(connection.Disconnect,connection) end
        if screen then pcall(screen.Destroy,screen) end
        if __slctx.Driver.probeScreen==screen then __slctx.Driver.probeScreen=nil end
    end
    local ok,result,reason=pcall(function()
        screen=Instance.new('ScreenGui');__slctx.Driver.probeScreen=screen
        screen.Name='SLVirtualInputProbe';screen.ResetOnSpawn=false
        screen.IgnoreGuiInset=style.ignore
        if style.insets~=nil then pcall(function() screen.ScreenInsets=style.insets end) end
        screen.DisplayOrder=2147480000
        shield=Instance.new('Frame');shield.Name='Shield';shield.Active=true
        shield.Size=UDim2.new(1,0,1,0);shield.Position=UDim2.fromOffset(0,0)
        shield.BackgroundColor3=Color3.fromRGB(20,20,24);shield.BackgroundTransparency=0.12
        shield.ZIndex=1;shield.Parent=screen
        probe=Instance.new('TextButton');probe.Name='VirtualInputProbeButton';probe.Active=true
        probe.Size=UDim2.fromOffset(210,22);probe.Position=UDim2.new(0.5,-105,0.5,-11)
        probe.ZIndex=10;probe.Text='Проверка ввода — не нажимай';probe.TextSize=13
        probe.Parent=shield
        local hits,armed=0,false
        connection=probe.MouseButton1Click:Connect(function() if armed then hits=hits+1 end end)
        screen.Parent=__slctx.gui
        task.wait(0.10)
        if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return nil,'CANCELLED' end
        local pos,size=__slctx.prop(probe,'AbsolutePosition'),__slctx.prop(probe,'AbsoluteSize')
        if not pos or not size or size.X<5 or size.Y<5 then return nil,'PROBE_NOT_LAID_OUT' end
        local ix,iy=__slctx.currentInset()
        local offsets={{x=0,y=0}}
        if math.abs(ix)+math.abs(iy)>0 then
            offsets[#offsets+1]={x=ix,y=iy};offsets[#offsets+1]={x=-ix,y=-iy}
        end
        -- Query coordinates are calibrated independently of engine click coordinates.
        local centerX,centerY=pos.X+size.X/2,pos.Y+size.Y/2
        local query,queryError
        for _,d in ipairs(offsets) do
            local good,why=__slctx.topTargetAt(probe,centerX+d.x,centerY+d.y)
            if good then query=d;break end
            queryError=why
        end
        if not query then return nil,'PROBE_HIT_TEST_FAILED: '..tostring(queryError) end
        local last='NO_PROBE_CLICK'
        for _,d in ipairs(offsets) do
            if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return nil,'CANCELLED' end
            if unfocusedProbe and __slctx.S.windowFocused~=false then return nil,'FOCUS_RETURNED_DURING_PROBE' end
            if not unfocusedProbe and __slctx.S.windowFocused==false then return nil,'WINDOW_NOT_FOCUSED' end
            hits=0;armed=true
            local sent,err=__slctx.sendPair(vim,centerX+d.x,centerY+d.y)
            local untilTime=__slctx.now()+0.6
            while sent and hits==0 and __slctx.now()<untilTime and not __slctx.S.unloaded and __slctx.S.epoch==epoch do task.wait(0.03) end
            -- Observe deferred duplicate events before accepting this backend.
            if hits>0 then task.wait(__slctx.CONFIG.ConfirmationPollSeconds) end
            armed=false
            if __slctx.S.unloaded or __slctx.S.epoch~=epoch then return nil,'CANCELLED' end
            if sent and hits==1 and (not unfocusedProbe or __slctx.S.windowFocused==false) then
                return {dx=d.x,dy=d.y,qx=query.x,qy=query.y},'PROBE_CLICK_CONFIRMED'
            end
            last=not sent and tostring(err) or ('probe clicks='..hits)
            if not sent then break end -- Permission/type errors are not fixed by coordinates.
        end
        return nil,last
    end)
    cleanup()
    if not ok then return nil,tostring(result) end
    return result,reason
end
function __slctx.Virtual.check(epoch)
    if not __slctx.Virtual.dispose() then return false end
    __slctx.Driver.virtualProfiles={}
    local candidates,seen={},{}
    local function add(ok,vim,owned,source)
        if ok and vim and type(__slctx.prop(vim,'SendMouseButtonEvent'))=='function' and not seen[vim] then
            seen[vim]=true;candidates[#candidates+1]={vim=vim,owned=owned,source=source}
        elseif ok and owned and vim then pcall(vim.Destroy,vim) end
    end
    local ok,vim=pcall(game.GetService,game,'VirtualInputManager');add(ok,vim,false,'service')
    ok,vim=pcall(Instance.new,'VirtualInputManager');add(ok,vim,true,'instance')
    __slctx.Driver.present=__slctx.Driver.present or #candidates>0
    __slctx.log('VIRTUAL_INPUT_APIS','candidates='..#candidates..'; OS mouse wrappers disabled')
    local style=__slctx.screenStyle(__slctx.g('HUD/Powers/BuyNext/Button'))
    for i,c in ipairs(candidates) do
        local profile,why=__slctx.Virtual.probe(c.vim,style,epoch,__slctx.S.windowFocused==false)
        __slctx.log('VIRTUAL_INPUT_TEST',c.source..' | '..tostring(why))
        if profile then
            __slctx.Driver.virtual=c.vim;__slctx.Driver.virtualOwned=c.owned
            __slctx.Driver.virtualProfiles[style.key]=profile
            for j,other in ipairs(candidates) do if j~=i and other.owned then pcall(other.vim.Destroy,other.vim) end end
            __slctx.log('INPUT_BACKEND','VirtualInputManager; isolated click confirmed; full game cycle not verified')
            return true
        end
        if c.owned then pcall(c.vim.Destroy,c.vim) end
    end
    return false
end
function __slctx.scrollIntoView(button,epoch)
    local p=__slctx.prop(button,'Parent')
    for _=1,60 do
        if not p or p==__slctx.gui then break end
        if p:IsA('ScrollingFrame') then
            local bp,bs=__slctx.prop(button,'AbsolutePosition'),__slctx.prop(button,'AbsoluteSize')
            local pp,ps=__slctx.prop(p,'AbsolutePosition'),__slctx.prop(p,'AbsoluteWindowSize') or __slctx.prop(p,'AbsoluteSize')
            local canvas,cs=__slctx.prop(p,'CanvasPosition'),__slctx.prop(p,'AbsoluteCanvasSize')
            if bp and bs and pp and ps and canvas and cs then
                local dy=0
                if bp.Y<pp.Y+4 then dy=bp.Y-pp.Y-4
                elseif bp.Y+bs.Y>pp.Y+ps.Y-4 then dy=bp.Y+bs.Y-(pp.Y+ps.Y-4) end
                if dy~=0 then
                    p.CanvasPosition=Vector2.new(canvas.X,math.max(0,math.min(math.max(0,cs.Y-ps.Y),canvas.Y+dy)))
                    task.wait(0.08)
                    if not __slctx.live(epoch) then return false,'PAUSED' end
                end
            end
        end
        p=__slctx.prop(p,'Parent')
    end
    return true
end
function __slctx.Virtual.point(button,profile)
    local p,z=__slctx.prop(button,'AbsolutePosition'),__slctx.prop(button,'AbsoluteSize')
    if not p or not z or z.X<=2 or z.Y<=2 then return nil,'NO_BUTTON_RECTANGLE' end
    local l,t,r,b=p.X,p.Y,p.X+z.X,p.Y+z.Y
    local parent=__slctx.prop(button,'Parent')
    for _=1,80 do
        if not parent or parent==__slctx.gui then break end
        if parent:IsA('GuiObject') and __slctx.prop(parent,'ClipsDescendants')==true then
            local ap,as=__slctx.prop(parent,'AbsolutePosition'),__slctx.prop(parent,'AbsoluteSize')
            if ap and as then l=math.max(l,ap.X);t=math.max(t,ap.Y);r=math.min(r,ap.X+as.X);b=math.min(b,ap.Y+as.Y) end
        end
        parent=__slctx.prop(parent,'Parent')
    end
    if r-l<=3 or b-t<=3 then return nil,'BUTTON_CLIPPED' end
    -- Different text/icon children can cover parts of a button; use only verified hits.
    local lastWhy
    for _,f in ipairs({{0.5,0.5},{0.25,0.5},{0.75,0.5},{0.15,0.85},{0.85,0.85},{0.15,0.15},{0.85,0.15}}) do
        local px,py=l+(r-l)*f[1],t+(b-t)*f[2]
        local good,why=__slctx.topTargetAt(button,px+profile.qx,py+profile.qy)
        if good then return {x=px+profile.dx,y=py+profile.dy} end
        lastWhy=why
    end
    return nil,'BUTTON_COVERED_OR_OFFSCREEN: '..tostring(lastWhy)..'; close other overlays; F8 hides the farm panel'
end
function __slctx.Virtual.click(button,guard,holdBody)
    local epoch=__slctx.S.epoch
    if __slctx.Focus.await and not __slctx.Focus.await(epoch) then return false,'PAUSED' end
    if not __slctx.live(epoch) then return false,'PAUSED' end
    if __slctx.S.windowFocused==false and not __slctx.S.backgroundVerified then return false,'WINDOW_NOT_FOCUSED' end
    local focusOk,focus=pcall(__slctx.UIS.GetFocusedTextBox,__slctx.UIS)
    if focusOk and focus then return false,'TEXT_BOX_FOCUSED' end
    local ok,why=__slctx.scrollIntoView(button,epoch);if not ok then return false,why end
    local style=__slctx.screenStyle(button)
    local profile=__slctx.Driver.virtualProfiles[style.key]
    if not profile then
        profile,why=__slctx.Virtual.probe(__slctx.Driver.virtual,style,epoch,__slctx.S.windowFocused==false)
        if not profile then return false,'VIRTUAL_LAYOUT_PROBE_FAILED: '..tostring(why) end
        __slctx.Driver.virtualProfiles[style.key]=profile
    end
    -- Our own panel must not intercept the game button. Hide it only if their
    -- rectangles overlap, and restore it without changing the user's F8 choice.
    local own=__slctx.S.panel;local panelFrame=__slctx.S.panelFrame
    local hideOwn=false
    if own and panelFrame and __slctx.prop(own,'Enabled') then
        local a,az=__slctx.prop(button,'AbsolutePosition'),__slctx.prop(button,'AbsoluteSize')
        local b,bz=__slctx.prop(panelFrame,'AbsolutePosition'),__slctx.prop(panelFrame,'AbsoluteSize')
        hideOwn=a and az and b and bz and a.X<b.X+bz.X and a.X+az.X>b.X and a.Y<b.Y+bz.Y and a.Y+az.Y>b.Y
    end
    local visibilityVersion=__slctx.S.panelVisibilityVersion or 0
    local success,value,err=pcall(function()
        if hideOwn then own.Enabled=false;task.wait(0.03) end
        if not __slctx.live(epoch) or not __slctx.usable(button) or __slctx.paid(button) then return false,'STATE_CHANGED_BEFORE_CLICK' end
        if guard and not guard() then return false,'STATE_CHANGED_BEFORE_CLICK' end
        local point;point,why=__slctx.Virtual.point(button,profile)
        if not point and tostring(why):find('CORE_GUI_OVERLAY: PlayerEntryContentFrame',1,true) then
            -- Temporarily collapse only the observed player list, then hit-test again.
            -- A purchase prompt or any other remaining overlay still blocks input.
            local okService,service=pcall(game.GetService,game,'StarterGui')
            if okService then
                local okState,enabled=pcall(service.GetCoreGuiEnabled,service,Enum.CoreGuiType.PlayerList)
                if okState and enabled==true then
                    local hidden=pcall(service.SetCoreGuiEnabled,service,Enum.CoreGuiType.PlayerList,false)
                    if hidden then
                        __slctx.Driver.hiddenPlayerList=service;task.wait(0.1)
                        if not __slctx.live(epoch) or not __slctx.usable(button) or guard and not guard() then return false,'STATE_CHANGED_BEFORE_CLICK' end
                        point,why=__slctx.Virtual.point(button,profile)
                        if point then __slctx.log('PLAYER_LIST_OVERLAP_RESOLVED','verified game button exposed') end
                    end
                end
            end
        end
        local transitionDeadline=__slctx.now()+3
        while not point and tostring(why):find('COVERED_BY: BackSink',1,true) and __slctx.now()<transitionDeadline do
            -- Keep hit testing during the previous modal's closing animation.
            -- Never disable its input shield or send a click through it.
            task.wait(0.05)
            if not __slctx.live(epoch) or not __slctx.usable(button) or guard and not guard() then return false,'STATE_CHANGED_BEFORE_CLICK' end
            point,why=__slctx.Virtual.point(button,profile)
        end
        if not point then return false,why end
        if __slctx.CONFIG.VerboseClickPoints then __slctx.log('VIRTUAL_CLICK_POINT',string.format('x=%.1f y=%.1f; %s',point.x,point.y,style.key)) end
        if holdBody then
            return __slctx.Virtual.runHeld(__slctx.Driver.virtual,point.x,point.y,function(pressed)
                return holdBody(pressed,profile)
            end)
        end
        return __slctx.sendPair(__slctx.Driver.virtual,point.x,point.y)
    end)
    __slctx.Virtual.restorePlayerList()
    if hideOwn and not __slctx.S.unloaded and __slctx.prop(own,'Parent') and (__slctx.S.panelVisibilityVersion or 0)==visibilityVersion then
        own.Enabled=true
    end
    if not success then __slctx.Virtual.release();return false,tostring(value) end
    return value,err
end
-- VIRTUAL_DRIVER_END


end
