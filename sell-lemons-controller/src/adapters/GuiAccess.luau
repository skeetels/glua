-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.now() return os.clock() end
function __slctx.at(root,path)
    for name in path:gmatch('[^/]+') do
        if not root then return nil end
        root=root:FindFirstChild(name)
    end
    return root
end
function __slctx.g(path) return __slctx.at(__slctx.gui,path) end
function __slctx.attr(o,k)
    if not o then return nil end
    local ok,v=pcall(o.GetAttribute,o,k); if ok then return v end
end
function __slctx.prop(o,k)
    if not o then return nil end
    local ok,v=pcall(function() return o[k] end); if ok then return v end
end
function __slctx.txt(o) return __slctx.Core.clean(__slctx.prop(o,'Text')) end
function __slctx.t(path) return __slctx.txt(__slctx.g(path)) end
function __slctx.visible(o)
    if not o or not o.Parent then return false end
    local n=0
    while o and o~=__slctx.gui do
        n=n+1; if n>80 then return false end
        if o:IsA('GuiObject') and not o.Visible then return false end
        if o:IsA('LayerCollector') and not o.Enabled then return false end
        if o:IsA('GuiObject') and __slctx.attr(o,'Visible')==false then return false end
        o=o.Parent
    end
    return o==__slctx.gui
end
function __slctx.usable(o)
    return o and o:IsA('GuiButton') and __slctx.visible(o) and __slctx.prop(o,'Active')==true
        and __slctx.prop(o,'Interactable')~=false
end
function __slctx.log(code,message)
    local line=string.format('[%07.2f] %s | %s',__slctx.now()-__slctx.S.started,code,tostring(message or ''))
    __slctx.S.logs[#__slctx.S.logs+1]=line
    if #__slctx.S.logs>__slctx.CONFIG.LogLines then table.remove(__slctx.S.logs,1) end
    local noise=code:match('^TRY_') or code:match('^CONFIRMED_') or code=='BACKGROUND_PURCHASE_CONFIRMED'
    if not noise then
        __slctx.S.events=__slctx.S.events or {};__slctx.S.events[#__slctx.S.events+1]=line
        if #__slctx.S.events>__slctx.CONFIG.EventLogLines then table.remove(__slctx.S.events,1) end
    end
    if __slctx.CONFIG.ConsoleTransactionLogs==false and noise then return end
    -- Short console records; the complete log is available on the panel.
    for start=1,#line,400 do print('[SL Farm] '..line:sub(start,start+399)) end
end
function __slctx.status(code,message)
    __slctx.S.code,__slctx.S.status=code,message
end
function __slctx.pause(code,message)
    if __slctx.S.releaseInput then __slctx.S.releaseInput() end
    if __slctx.S.running then __slctx.S.manualPauseAt=__slctx.now() end
    __slctx.S.running=false;__slctx.S.epoch=__slctx.S.epoch+1;__slctx.S.lastError=message or code
    if __slctx.S.resetSession then
        __slctx.S.resetSession.active=false;__slctx.S.resetSession.outcome=code;__slctx.S.resetSession=nil
    end
    __slctx.status(code,message or code);__slctx.log(code,message)
end
function __slctx.live(epoch) return not __slctx.S.unloaded and __slctx.S.running and (not epoch or epoch==__slctx.S.epoch) end
function __slctx.sleep(sec,epoch)
    if __slctx.Focus.await and not __slctx.Focus.await(epoch) then return false end
    local finish=__slctx.now()+sec
    repeat
        if not __slctx.live(epoch) then return false end
        task.wait(math.min(0.08,math.max(0.01,finish-__slctx.now())))
    until __slctx.now()>=finish
    return __slctx.live(epoch)
end
function __slctx.cash()
    local label=__slctx.g('HUD/Balance/Main/Cash')
    if not __slctx.visible(label) then return nil end
    return __slctx.BN.parse(__slctx.txt(label))
end
function __slctx.updateRate()
    __slctx.S.cashFlow=__slctx.S.cashFlow or __slctx.Core.newCashFlow()
    if not __slctx.S.actionPending and not __slctx.S.resetChildPending and not __slctx.S.resetSession then __slctx.S.cashFlow:sample(__slctx.now(),__slctx.cash()) end
    if __slctx.now()-__slctx.S.lastSpend<0.05 then return end
    __slctx.S.rate:add(__slctx.now(),__slctx.cash())
end
function __slctx.progress(kind)
    if kind=='rebirth' or kind=='evolve' or kind=='halo' then
        __slctx.S.buyReceiptStreak=0
        if __slctx.S.cashFlow then __slctx.S.cashFlow:reset() end
        __slctx.Strategy.route().growthSamples={}
    end
    __slctx.S.lastSpend=__slctx.now();__slctx.S.rate:reset();__slctx.S.episode=nil;__slctx.S.goal=nil;__slctx.S.stallStart=nil;__slctx.S.catalogDirty=true
    if __slctx.S.counts[kind] then __slctx.S.counts[kind]=__slctx.S.counts[kind]+1 end
    __slctx.S.lastKind=kind
end
function __slctx.paid(o)
    if not o then return true end
    local name=o.Name:lower()
    if name:find('robux',1,true) or name=='boost' or name=='double' or name=='prompt' then return true end
    for _,v in ipairs(o:GetDescendants()) do
        if tostring(__slctx.attr(v,'AssetName') or ''):lower():find('robux',1,true) then return true end
    end
    return false
end
function __slctx.childText(o,name) return __slctx.txt(o and o:FindFirstChild(name)) end
function __slctx.childNumber(o,name) return __slctx.BN.parse(__slctx.childText(o,name)) end
__slctx.paths={
    manage='Manage/ManageMenu', tabs='Manage/ManageMenu/Body/Tabs/Container/',
    cards='Manage/ManageMenu/Body/Frame/Manage', powers='Manage/ManageMenu/Body/Frame/Powers',
    investors='Rebirth/InvestorsMenu', evolution='Rebirth/EvolutionMenu', halo='Rebirth/AscensionMenu',
    buy='HUD/Powers/BuyNext', balance='HUD/Balance/Main/Cash'}
__slctx.openers={manage='HUD/Balance/Buttons/ManageButton',
    investors='Rebirth/Sidebar/Container/Investors',evolution='Rebirth/Sidebar/Container/Evolution',
    halo='Rebirth/Sidebar/Container/Ascension'}

-- No click is counted as a purchase merely because a signal invocation returned.
-- Local compatibility probe only: it never calls a game's purchase/reset button.

end
