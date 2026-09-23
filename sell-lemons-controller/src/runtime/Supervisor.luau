-- One economic worker. Independent observations can request a review, never a reset.
return function(ctx)
    local controller={retries=0,recoveries=0,reviews=0,steps=0}
    ctx.Supervisor=controller
    local oldPause=ctx.pause
    ctx.pause=function(code,message)
        local s=ctx.S
        local pending=s.actionPending or s.resetChildPending or s.resetSession or s.buyHold
            or ctx.Driver.releaseBlocked or ctx.Driver.pressed
        oldPause(code,message)
        if not pending then
            controller.pending=ctx.RecoveryPolicy.schedule(code,controller.retries,ctx.now())
            if controller.pending then
                controller.retries=controller.pending.attempt
                controller.pending.epoch=s.epoch
                ctx.log('RECOVERY_SCHEDULED',code..'; attempt '..controller.retries)
            end
        end
    end
    function controller.tick()
        ctx.Observer.poll()
        local pending=controller.pending
        if not pending or ctx.S.unloaded then return end
        if pending.epoch~=ctx.S.epoch then controller.pending=nil;return end
        if ctx.now()<pending.at then return end
        if ctx.S.actionPending or ctx.S.resetChildPending or ctx.S.resetSession or ctx.S.buyHold then return end
        controller.pending=nil
        -- Resume the retained route; API.start would discard partial-pass state.
        ctx.S.running=true;ctx.S.epoch=ctx.S.epoch+1
        controller.recoveries=controller.recoveries+1
        ctx.status('RECOVERING','Повторное чтение интерфейса; проход и учёт покупок сохранены.')
        ctx.log('RECOVERY_RESUME',pending.code)
    end
    local oldStep=ctx.step
    ctx.step=function()
        if ctx.AntiIdle and ctx.AntiIdle.pending then return end
        local s=ctx.S;local r=ctx.Strategy.route();local h=ctx.HaloRun.state()
        local age=ctx.now()-(h.lastReview or ctx.now())
        local pending=s.actionPending or s.resetChildPending or s.resetSession or s.buyHold
        local enabled=s.resetEnabled and (ctx.CONFIG.AutoRebirth or ctx.CONFIG.AutoEvolution)
        if not h.buyUnavailableReason and ctx.RecoveryPolicy.reviewDue(age,r.phase,h.mode,pending,r.recovery,enabled)
            and ctx.now()>=(controller.nextReview or 0) then
            controller.nextReview=ctx.now()+45;controller.reviews=controller.reviews+1
            ctx.HaloRun.requestReview(r.phase=='UPGRADE' and 'UPGRADE' or 'BUY')
            ctx.log('TIME_BOUND_REVIEW','45 seconds since previous review; retained pass')
        end
        local receiptTotal=s.counts.buy+s.counts.upgrade+s.counts.rebirth+s.counts.evolve+s.counts.halo
        if receiptTotal~=(controller.lastReceiptTotal or receiptTotal) then controller.retries=0 end
        controller.lastReceiptTotal=receiptTotal
        controller.steps=controller.steps+1
        oldStep()
    end
    local oldReset=ctx.Strategy.afterReset
    ctx.Strategy.afterReset=function(kind,before)
        ctx.Observer.store:invalidate('confirmed '..tostring(kind))
        controller.pending=nil;controller.retries=0
        return oldReset(kind,before)
    end
    local oldReport=ctx.API.report
    ctx.API.report=function()
        local ok,direct=pcall(ctx.API.directReport or function()return ''end)
        return oldReport()..'\n\nController 4.0 / observations='..ctx.Observer.store.revision
            ..' / refreshes='..ctx.Observer.refreshes..' / cache hits='..ctx.Observer.hits
            ..' / recovery resumes='..controller.recoveries..' / timed reviews='..controller.reviews
            ..'\nTransport: direct stands='..tostring(ctx.CONFIG.DirectUpgrades)..'; direct Powers/Buy='..tostring(ctx.CONFIG.DirectPurchases)
            ..'; direct prestige='..tostring(ctx.CONFIG.DirectPrestige)..'; evolution/Halo execution retains GUI.'
            ..'\n'..(ok and direct or 'Direct report failed: '..tostring(direct))
    end
end
