-- Only failures known to occur before an economic action can auto-resume.
return function(ctx)
    local recoverable={UPGRADE_MENU_NOT_READY=true,PASS_VIEW_NOT_READY=true,
        BATCH_VIEW_NOT_READY=true,INVESTORS_READ_FAILED=true,EVOLUTION_READ_FAILED=true}
    local Policy={}
    function Policy.schedule(code,attempt,now)
        if not recoverable[code] or attempt>=4 then return nil end
        return {attempt=attempt+1,at=now+math.min(8,2^attempt),code=code}
    end
    function Policy.reviewDue(age,phase,mode,pending,recovery,enabled)
        return enabled and not pending and not recovery and mode~='FINISH'
            and (phase=='BUY' or phase=='UPGRADE' or phase=='WAIT_GROWTH') and age>=45
    end
    ctx.RecoveryPolicy=Policy
end
