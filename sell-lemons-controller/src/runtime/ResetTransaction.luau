-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.doReset(kind)
    local resetClock=__slctx.now();local resetFocusBase=__slctx.S.focusPausedTotal or 0
    __slctx.Strategy.route().lastResetGuardReason=nil
    if not __slctx.S.resetEnabled or not __slctx.live() then return false end
    if not __slctx.confirmKinds[kind] then return false end
    if __slctx.S.resetSession or __slctx.S.resetChildPending or __slctx.S.actionPending then return false end
    local before,button,err
    local function evolutionAllowed()
        if kind~='evolve' or not __slctx.HaloRun or not __slctx.HaloRun.deferEvolution then return true end
        local hold,reason=__slctx.HaloRun.deferEvolution(true)
        if hold then __slctx.Strategy.route().lastResetGuardReason=reason end
        return not hold
    end
    if not evolutionAllowed()then __slctx.Strategy.phase('BUY','эволюция отложена: текущая база продолжает строиться');return false end
    if kind=='rebirth' then
        before,err=__slctx.readInvestors()
        if not before then __slctx.Strategy.noteResetAbort(err or 'INVESTORS_READ_FAILED');return false end
        local permitted,reason=__slctx.Strategy.rebirthBarrier(before)
        if not permitted then
            __slctx.Strategy.noteResetAbort(reason)
            if reason=='UNRESOLVED_PURCHASE' then __slctx.Strategy.stopForBlocked()
            elseif reason=='PASS_NOT_FINISHED' then __slctx.Strategy.phase('UPGRADE',reason)
            elseif reason=='NEW_EVOLUTION_THRESHOLD' then __slctx.Strategy.phase(__slctx.Strategy.route().capabilityOnly and 'CAPABILITY' or 'CHECKPOINT',reason)
            elseif reason=='EVOLUTION_TAKES_PRIORITY' then __slctx.Strategy.phase('EVOLVE_RESERVE',reason)
            elseif __slctx.Strategy.route().capabilityOnly then
                __slctx.Strategy.route().capabilityOnly=nil;__slctx.Strategy.route().resetPowerPlan=nil
                __slctx.Strategy.phase(__slctx.Strategy.route().reviewReturn or 'UPGRADE','macro guard changed; original route retained');__slctx.Strategy.route().reviewReturn=nil
            else __slctx.Strategy.nextCycle(reason) end
            return false
        end
        if not before.ready then return false end
        button=__slctx.g(__slctx.paths.investors..'/Body/Rebirth')
    elseif kind=='evolve' then
        before,err=__slctx.readEvolution()
        local permitted,why=__slctx.Core.evolutionGuard(before,__slctx.CONFIG.TabletReserve)
        if not permitted then __slctx.status(why,'Эволюция отложена: нужен видимый бонус не менее '..__slctx.CONFIG.TabletReserve..' инвесторов.');return false end
        if not __slctx.sleep(__slctx.CONFIG.EvolutionReadyDelay) then return false end
        before,err=__slctx.readEvolution()
        if not __slctx.Core.evolutionGuard(before,__slctx.CONFIG.TabletReserve) then return false end
        button=__slctx.g(__slctx.paths.evolution..'/Body/Evolve')
    else
        before,err=__slctx.readHalo()
        if not before or not before.ready then return false end
        button=__slctx.g(__slctx.paths.halo..'/Body/Ascend')
    end
    local preparedRecovery=kind=='rebirth' and __slctx.Strategy.makeRecovery(before) or nil
    __slctx.status('RESET_'..kind,'Выполнение '..kind..'; ожидание изменения прогресса…')
    local session,beginError=__slctx.ResetConfirm.begin(kind,button)
    if not session then __slctx.pause('RESET_CONFIRM_INIT_FAILED',tostring(beginError));return false end
    local lastOpen=__slctx.now()
    local function resetProgressChanged()
        if kind=='evolve' then
            local v=tonumber(__slctx.t(__slctx.paths.evolution..'/Body/Current/What'):lower():match('evolution%s+(%d+)'))
            return v and v>before.index
        elseif kind=='halo' then
            local v=__slctx.Core.count(__slctx.t(__slctx.paths.halo..'/Body/Amount/Quantity'))
            return v and v>before.amount
        end
        local v=__slctx.BN.parse(__slctx.t(__slctx.paths.investors..'/Body/Amount/Quantity'))
        return v and __slctx.BN.cmp(v,before.investors)>0
    end
    local function changed() return __slctx.S.resetChildPending==nil and resetProgressChanged() end
    session.changed=resetProgressChanged
    if kind=='rebirth' then
        session.expected={authorize=function(dialog)
            local current=__slctx.Strategy.peekResetInvestors(session,dialog)
            return current and __slctx.Strategy.rebirthBarrier(current)
        end}
    elseif kind=='evolve' then
        session.expected={authorize=evolutionAllowed}
    end
    session.before=before;session.observationOpens=0
    local pendingRoute=__slctx.Strategy.route()
    if pendingRoute.halo30 then pendingRoute.halo30.resetInFlight=kind end
    pendingRoute.transactionStartedAt=__slctx.now()
    local maintenance=function()
        if not __slctx.live(session.epoch) then return end
        -- The reset transaction owns input until it has a receipt. Confirmation is
        -- not another ordinary Driver.perform call: the originating callback may
        -- itself be yielding while it waits for the modal result.
        local modal=__slctx.ResetConfirm.poll(session)
        if not __slctx.live(session.epoch) then return end
        modal=modal or __slctx.ResetConfirm.modalVisible(session)
        local cinematic=__slctx.g('Cinematic')
        if cinematic then
            for _,o in ipairs(cinematic:GetChildren()) do
                if o.Name:lower():find('animation',1,true) and __slctx.visible(o) then modal=true;break end
            end
        end
        local key=kind=='evolve' and 'evolution' or (kind=='halo' and 'halo' or 'investors')
        local confirmationCount=session.attempts or 0
        local code,message=__slctx.HaloPlan.resetStatusView(kind,session.started or resetClock,__slctx.now(),confirmationCount,
            __slctx.ResetConfirm.modalVisible(session),modal and not __slctx.ResetConfirm.modalVisible(session),resetProgressChanged())
        __slctx.status(code,message)
        local observeDelay=(session.observationOpens or 0)==0 and __slctx.CONFIG.ResetObservationStartSeconds
            or math.max(__slctx.CONFIG.ResetObservationStartSeconds+8,__slctx.CONFIG.ResetTimeout*.60)
        local observeAllowed=__slctx.now()-resetClock>=observeDelay
            and (session.observationOpens or 0)<__slctx.CONFIG.ResetObservationOpenLimit
        if not modal and observeAllowed and not __slctx.S.resetChildPending and not __slctx.visible(__slctx.g(__slctx.paths[key])) and __slctx.now()-lastOpen>2 then
            lastOpen=__slctx.now()
            local opener=__slctx.g(__slctx.openers[key])
            if __slctx.usable(opener) then
                local modes=__slctx.candidateModes(opener,'navigation')
                if modes[1] then
                    local pending={done=false};__slctx.S.resetChildPending=pending
                    session.observationOpens=(session.observationOpens or 0)+1
                    task.spawn(function()
                        pcall(__slctx.dispatch,opener,modes[1],{guard=function()
                            return __slctx.live(session.epoch) and session.active and __slctx.S.resetEnabled
                                and not __slctx.ResetConfirm.modalVisible(session)
                        end})
                        pending.done=true
                        if __slctx.S.resetChildPending==pending then __slctx.S.resetChildPending=nil end
                    end)
                end
            end
        end
    end
    local ok,e=__slctx.Driver.perform(button,kind,changed,{once=true,timeout=__slctx.CONFIG.ResetTimeout,maintenance=maintenance,
        abortReason=function()return session.cancelledReason end,
        maintenanceInterval=__slctx.CONFIG.ConfirmPollSeconds,
        onDispatch=function()
            session.sent=true;__slctx.ResetConfirm.note(session,'RESET_ARMED',kind)
            local r=__slctx.Strategy.route();r.lastResetExecution={stage='dispatched',reason=kind,at=__slctx.now()}
            if kind=='rebirth' then __slctx.log('RESET_INTENT_DISPATCHED','id='..tostring(r.resetIntent and r.resetIntent.id)) end
        end,
        guard=function()
            if not __slctx.S.resetEnabled or not __slctx.live() then return false end
            if kind=='rebirth' then
                local current,why=__slctx.Strategy.peekResetInvestors()
                local allowed,reason
                if current then allowed,reason=__slctx.Strategy.rebirthBarrier(current) else allowed=false;reason=why end
                if not allowed then __slctx.Strategy.route().lastResetGuardReason=reason end
                return allowed
            end
            return evolutionAllowed()
        end})
    if not ok and not session.cancelledReason and __slctx.live() then __slctx.ResetConfirm.dump(session) end
    __slctx.ResetConfirm.finish(session,ok)
    if __slctx.Strategy.route().halo30 then __slctx.Strategy.route().halo30.resetInFlight=nil end
    if not ok then
        if kind=='evolve' and __slctx.Strategy.route().lastResetGuardReason then
            __slctx.log('EVOLUTION_DEFERRED',__slctx.Strategy.route().lastResetGuardReason..'; confirmation cancelled; no reset receipt')
            __slctx.Strategy.phase('BUY','продолжаю текущую базу вместо эволюции');return false
        end
        if kind=='rebirth' then __slctx.Strategy.noteResetAbort(__slctx.Strategy.route().lastResetGuardReason or e or 'RESET_FAILED') end
        if session.cancelledReason and kind=='rebirth' then
            __slctx.log('REBIRTH_CANCELLED',session.cancelledReason..'; no reset receipt; continue existing run')
            return false
        end
        if e=='STATE_CHANGED_BEFORE_CLICK' and kind=='rebirth' then
            if __slctx.Strategy.route().capabilityOnly then
                __slctx.Strategy.route().capabilityOnly=nil;__slctx.Strategy.route().resetPowerPlan=nil
                __slctx.Strategy.phase(__slctx.Strategy.route().reviewReturn or 'UPGRADE','reset not dispatched; original route retained');__slctx.Strategy.route().reviewReturn=nil;return false
            end
            local funded=__slctx.Strategy.affordableQuote()
            if funded then __slctx.Strategy.resumeGrowth(funded,'funded before reset dispatch') else __slctx.Strategy.phase('CHECKPOINT','reset guard changed') end
            return false
        end
        if __slctx.live() then __slctx.pause('RESET_NOT_CONFIRMED',e..' — повторный сброс не отправлен.') end
        return false
    end
    local resetRoute=__slctx.Strategy.route()
    resetRoute.lastResetExecution={stage='confirmed',reason=kind,at=__slctx.now()}
    local duration=math.max(0.01,__slctx.now()-resetClock-((__slctx.S.focusPausedTotal or 0)-resetFocusBase))
    resetRoute.resetDuration=resetRoute.resetDuration and (resetRoute.resetDuration+duration)*0.5 or duration
    __slctx.Strategy.recordTiming(kind,duration)
    if kind=='rebirth' then
        resetRoute.nextRecovery=preparedRecovery
        if preparedRecovery then preparedRecovery.started=__slctx.now()+__slctx.CONFIG.AfterResetWait end
    end
    __slctx.Strategy.afterReset(kind,before)
    __slctx.progress(kind);__slctx.S.runStart=__slctx.now();__slctx.S.lastRefresh=-math.huge;__slctx.S.lastPowers=-math.huge
    __slctx.status('RESET_SETTLE','Сброс подтверждён. Ожидание восстановления интерфейса…')
    __slctx.sleep(__slctx.CONFIG.AfterResetWait)
    return true
end
-- Growth plus bounded progress reviews. Minor receipts never postpone reset assessment.

end
