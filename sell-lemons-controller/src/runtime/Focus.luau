-- Component initialized with an explicit shared service context.
return function(__slctx)
-- Focus changes never simulate OS input, raise the game window, or bypass a permission check.
function __slctx.Focus.adjustTimers()
    if not __slctx.S.focusPauseAt then return end
    local dt=math.max(0,__slctx.now()-__slctx.S.focusPauseAt);__slctx.S.focusPauseAt=nil
    __slctx.S.focusPausedTotal=(__slctx.S.focusPausedTotal or 0)+dt
    local r=__slctx.S.route
    if r then
        if r.wall then r.wall.start=r.wall.start+dt;r.wall.deadline=r.wall.deadline+dt end
        if r.goal then r.goal.deadline=r.goal.deadline+dt end
        if r.savingsBudget then
            r.savingsBudget.start=r.savingsBudget.start+dt;r.savingsBudget.deadline=r.savingsBudget.deadline+dt
        end
        if r.recovery then r.recovery.started=r.recovery.started+dt end
        if r.cycleBeganAt then r.cycleBeganAt=r.cycleBeganAt+dt end
        if r.runObservedAt then r.runObservedAt=r.runObservedAt+dt end
        if r.pass and r.pass.lastCapabilityAt then r.pass.lastCapabilityAt=r.pass.lastCapabilityAt+dt end
        if r.reserveSince then r.reserveSince=r.reserveSince+dt end
        if r.pass and not r.pass.finished then r.pass.started=r.pass.started+dt end
        if r.buildWall then r.buildWall.started=r.buildWall.started+dt end
        for _,key in ipairs({'nextProgressReview','nextSmallReview','marginalSince'}) do
            if r[key] then r[key]=r[key]+dt end
        end
        r.unknownSince=nil
    end
    __slctx.S.rate:reset()
    if __slctx.S.cashFlow then __slctx.S.cashFlow:reset() end
    if r then
        r.growthSamples={};r.uiObservation=nil;r.rewardSamples={};r.rewardCurve=nil;r.frontierTrace=nil;r.cleanRun=false
        if r.recovery then r.recovery.metSince=nil end
    end
end
function __slctx.Focus.changed(focused)
    __slctx.S.windowFocused=focused
    if not focused then
        __slctx.S.backgroundVerified=false;__slctx.S.backgroundTried=false;__slctx.S.backgroundBlocked=false;__slctx.S.nextBackgroundProbe=0
        local direct=__slctx.CONFIG.DirectUpgrades and __slctx.CONFIG.DirectPurchases and __slctx.CONFIG.DirectPrestige
        if not direct then __slctx.S.focusPauseAt=__slctx.S.focusPauseAt or __slctx.now()end
        __slctx.Virtual.release()
        if __slctx.S.running then __slctx.log('FOCUS_AWAY',direct and 'Direct route continues; GUI actions retain focus checks' or 'Route retained; background probe or automatic focus wait') end
    else
        __slctx.S.backgroundVerified=false;__slctx.S.backgroundTried=false;__slctx.S.backgroundBlocked=false;__slctx.S.nextBackgroundProbe=0
        if __slctx.S.running then __slctx.log('FOCUS_RETURNED','Resume current route, not BOOT; revalidate next action') end
    end
end
function __slctx.Focus.reject(reason)
    if __slctx.S.windowFocused==false then
        __slctx.S.backgroundVerified=false;__slctx.S.backgroundTried=true;__slctx.S.backgroundBlocked=true
        __slctx.S.nextBackgroundProbe=__slctx.now()+__slctx.CONFIG.BackgroundRetrySeconds
        __slctx.S.focusPauseAt=__slctx.S.focusPauseAt or __slctx.now()
        __slctx.Virtual.release()
        __slctx.log('BACKGROUND_ACTION_UNCONFIRMED',reason)
    end
end
function __slctx.Focus.await(epoch)
    local started=__slctx.now()
    if not __slctx.live(epoch) then return false,0 end
    if not __slctx.Driver.virtual then return true,0 end
    if __slctx.S.windowFocused~=false then __slctx.Focus.adjustTimers();return true,0 end
    if not __slctx.S.backgroundVerified then __slctx.S.focusPauseAt=__slctx.S.focusPauseAt or __slctx.now()end
    while __slctx.live(epoch) and __slctx.S.windowFocused==false and not __slctx.S.backgroundVerified do
        if __slctx.CONFIG.BackgroundMode=='Probe' and (not __slctx.S.backgroundTried or __slctx.now()>=(__slctx.S.nextBackgroundProbe or 0)) and not __slctx.S.backgroundProbing then
            __slctx.S.backgroundTried=true;__slctx.S.backgroundProbing=true;__slctx.S.nextBackgroundProbe=__slctx.now()+__slctx.CONFIG.BackgroundRetrySeconds
            __slctx.status('BACKGROUND_PROBE','Проверяю виртуальный ввод без фокуса на собственной кнопке…')
            local style=__slctx.screenStyle(__slctx.g(__slctx.paths.buy..'/Button'))
            local success,profile,reason=pcall(__slctx.Virtual.probe,__slctx.Driver.virtual,style,__slctx.S.epoch,true)
            __slctx.S.backgroundProbing=false
            if success and profile and __slctx.S.windowFocused==false and __slctx.live(epoch) then
                __slctx.Driver.virtualProfiles[style.key]=profile;__slctx.S.backgroundVerified=true
                __slctx.log('BACKGROUND_PROBE_OK','Local unfocused click confirmed; game purchases still need receipts')
                __slctx.Focus.adjustTimers()
                break
            end
            __slctx.log('BACKGROUND_PROBE_UNCONFIRMED',tostring(success and reason or profile))
        end
        if __slctx.S.windowFocused~=false then break end
        __slctx.status('WAIT_WINDOW',__slctx.CONFIG.BackgroundMode=='Probe' and 'Клиент пока не принимает фоновый ввод. Повторная проверка каждые 5 с; маршрут сохранён.' or 'Фоновая работа выключена. Маршрут продолжится после возврата в игру.')
        task.wait(0.15)
    end
    if not __slctx.live(epoch) then return false,__slctx.now()-started end
    if __slctx.S.windowFocused~=false and not __slctx.CONFIG.AutoResumeOnFocus then
        __slctx.pause('FOCUS_PAUSED','Окно восстановлено. Нажми F6 для продолжения.');return false,__slctx.now()-started
    end
    __slctx.Focus.adjustTimers()
    return true,__slctx.now()-started
end


end
