-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.ResetConfirm = nil -- shared with navigation; implementation follows the purchase adapters.
__slctx.menuRoutes={
    {key='manage',path=__slctx.paths.manage,close=__slctx.paths.manage..'/Close/Button'},
    {key='investors',path=__slctx.paths.investors,close=__slctx.paths.investors..'/Close'},
    {key='evolution',path=__slctx.paths.evolution,close=__slctx.paths.evolution..'/Close'},
    {key='halo',path=__slctx.paths.halo,close=__slctx.paths.halo..'/Close'},
    {key='reactor',path='Rebirth/ReactorMenu',close='Rebirth/ReactorMenu/Close'},
}
function __slctx.closeGameMenus(except)
    for _,route in ipairs(__slctx.menuRoutes) do
        local root=__slctx.g(route.path)
        if route.key~=except and __slctx.visible(root) then
            local close=__slctx.g(route.close)
            if not __slctx.usable(close) then return false,'MENU_CLOSE_UNAVAILABLE: '..route.close end
            __slctx.log('CLOSE_MENU',route.path)
            local ok,why=__slctx.Driver.navigate(close,function()
                return not __slctx.visible(__slctx.g(route.path))
            end,{once=true})
            if not ok then return false,'MENU_CLOSE_FAILED: '..route.path..' | '..tostring(why) end
            -- A logical Visible attribute can change before the hide animation has finished.
            local hide=tonumber(__slctx.attr(root,'HideTime')) or 0.4
            if not __slctx.sleep(math.max(__slctx.CONFIG.MenuSettle,hide+0.08)) then return false,'PAUSED' end
        end
    end
    return true
end
function __slctx.navigate(key)
    if __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,why=__slctx.ResetConfirm.beforeNavigation();if not ready then return false,why end
    end
    local closed,why=__slctx.closeGameMenus(key)
    if not closed then return false,why end
    if __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,reason=__slctx.ResetConfirm.beforeNavigation();if not ready then return false,reason end
    end
    local root=__slctx.g(__slctx.paths[key])
    if __slctx.visible(root) then return true end
    local opener=__slctx.g(__slctx.openers[key])
    if not __slctx.usable(opener) and __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,reason=__slctx.ResetConfirm.beforeNavigation(true);if not ready then return false,reason end
    end
    if not __slctx.usable(opener) then return false,'MENU_OPENER_UNAVAILABLE: '..key end
    local ok,err=__slctx.Driver.navigate(opener,function() return __slctx.visible(__slctx.g(__slctx.paths[key])) end)
    if not ok then return false,err end
    return __slctx.sleep(__slctx.CONFIG.MenuSettle)
end
function __slctx.ensureStrip()
    -- The BuyNext panel can be collapsed OR covered by Manage. These are separate states.
    if __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,why=__slctx.ResetConfirm.beforeNavigation();if not ready then return false,why end
    end
    local closed,why=__slctx.closeGameMenus(nil)
    if not closed then return false,why end
    if __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,reason=__slctx.ResetConfirm.beforeNavigation();if not ready then return false,reason end
    end
    local root=__slctx.g(__slctx.paths.buy)
    if __slctx.visible(root) then return true end
    local b=__slctx.g('HUD/Powers/Toggle')
    if not __slctx.usable(b) and __slctx.ResetConfirm and __slctx.ResetConfirm.beforeNavigation then
        local ready,reason=__slctx.ResetConfirm.beforeNavigation(true);if not ready then return false,reason end
    end
    if not __slctx.usable(b) then return false,'BUY_STRIP_LOCKED' end
    __slctx.log('OPEN_BUY_STRIP','HUD/Powers/Toggle')
    local ok,err=__slctx.Driver.navigate(b,function() return __slctx.visible(__slctx.g(__slctx.paths.buy)) end,{once=true})
    if not ok then return false,err end
    if not __slctx.sleep(__slctx.CONFIG.MenuSettle) then return false,'PAUSED' end
    return true
end
function __slctx.manageTab(name)
    local ok,err=__slctx.navigate('manage');if not ok then return false,err end
    local root=__slctx.g('Manage/ManageMenu/Body/Frame/'..name)
    if __slctx.visible(root) then return true end
    local b=__slctx.g(__slctx.paths.tabs..name)
    if not __slctx.usable(b) then return false,'TAB_LOCKED: '..name end
    local success,e=__slctx.Driver.navigate(b,function()
        return __slctx.visible(__slctx.g('Manage/ManageMenu/Body/Frame/'..name)) end)
    if not success then return false,e end
    return __slctx.sleep(__slctx.CONFIG.MenuSettle)
end

end
