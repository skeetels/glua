-- Goal selection runs before work on the base, including BOOT and recovery.
-- Adapters still own state checks, the reset lease and actual receipts.
return function(ctx)
    local G={};ctx.GoalDirector=G
    local phases={BOOT=true,BUY=true,UPGRADE=true,REBUILD=true,POWERS=true,BOOST=true,
        CAPABILITY=true,CHECKPOINT=true,OBJECTIVE=true,WAIT_GROWTH=true,WAIT_CASH=true}
    function G.finish()
        if not ctx.CONFIG.GoalDirectedProgression or not ctx.CONFIG.DirectPurchases then return nil end
        local rem=ctx.DirectPurchases.remaining()
        if rem and rem.cash and rem.cost and ctx.BN.cmp(rem.cash,rem.cost)>=0 then return rem end
    end
    function G.note(choice,detail)
        local r=ctx.Strategy.route();local prior=r.goalDecision
        r.goalDecision={choice=choice,at=ctx.now(),detail=detail}
        if not prior or prior.choice~=choice or ctx.now()-(r.goalDecisionLoggedAt or 0)>=ctx.CONFIG.DiagnosticSeconds then
            r.goalDecisionLoggedAt=ctx.now()
            ctx.log('GOAL_ROUTE',choice..'; E='..tostring(r.evo and r.evo.index)
                ..'; continue='..tostring(detail and detail.direct)..'; rebirth='..tostring(detail and detail.reset)
                ..'; prefix='..tostring(detail and detail.points)..'/'..tostring(detail and detail.totalPoints))
        end
    end
    function G.forecast(inv)
        local r=ctx.Strategy.route();local data,why=ctx.DirectPrestige.snapshot()
        if not data then return nil,why end
        -- Read replicated payout/period fields before the first Manage/Buy pass.
        -- These already include permanent and donor bonuses; never apply them twice.
        local rate,trace=G.observe(data,inv)
        local growth,span=ctx.Planner.growthEstimate(r.goalGrowth,ctx.now(),20)
        local setup=ctx.Strategy.actionSeconds('rebirth')+ctx.CONFIG.AfterResetWait
        return ctx.GoalPlanner.compare(data,inv,rate,'direct-goal',trace,growth,span,setup,ctx.CONFIG,ctx.now())
    end
    function G.observe(data,inv)
        local r=ctx.Strategy.route();local B=ctx.BN
        if not ctx.DirectUpgrades or not ctx.DirectUpgrades.cards then return nil end
        local rate,n,total=ctx.Planner.sumRates(ctx.DirectUpgrades.cards(data.snapshot))
        if not rate or n~=total or total==0 or rate.m<=0 or not inv.perInvestor then return nil end
        local multiplier=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
        local trace=r.goalTrace;local time=ctx.now();local index=data.snapshot.epoch.Evolution
        -- A separate direct-rate trace cannot get stuck when the cash-flow
        -- estimator wakes up or the first BOOT observation has no evolution yet.
        if not trace or trace.epoch~=index then
            trace={points={},complete=r.cleanRun==true,base=multiplier,kind='direct-goal',epoch=index,
                started=r.buildStarted or r.runObservedAt or time};r.goalTrace=trace
        end
        if not r.cleanRun then trace.invalid=true end
        local points=trace.points
        if #points==0 or time-points[#points].time>=ctx.CONFIG.GoalReviewSeconds then
            points[#points+1]={time=time,age=math.max(0,time-trace.started),cash=ctx.cash(),
                rate=B.mul(rate,B.div(trace.base,multiplier)),spent=r.runSpent or B.new(0),
                service=(r.runServiceSeconds or 0)+(r.runMenuSeconds or 0)}
            if #points>ctx.CONFIG.FrontierTracePoints then
                local slim={points[1]};for i=3,#points,2 do slim[#slim+1]=points[i]end
                if slim[#slim]~=points[#points] then slim[#slim+1]=points[#points]end
                trace.points=slim
            end
            local samples=r.goalGrowth or {};r.goalGrowth=samples
            samples[#samples+1]={time=time,rate=rate,kind='direct-goal'}
            while #samples>64 do table.remove(samples,1)end
        end
        return rate,trace
    end
    function G.ownsRebirth()
        local h=ctx.HaloRun.state()
        return ctx.CONFIG.GoalDirectedProgression and ctx.CONFIG.AutoEvolution and h.goalForecast~=nil
            and ctx.now()-(h.goalForecastAt or -math.huge)<=ctx.CONFIG.IncomeFreshSeconds
    end
    function G.validate(inv)
        -- Recompute the exact goal and comparison immediately before dispatch.
        -- Receipt/epoch/bank/policy checks are still performed by the ordinary lease.
        local evo=ctx.readEvolution()
        if not evo then return false,'GOAL_DATA_UNAVAILABLE' end
        local r=ctx.Strategy.route();r.evo=evo;r.lastEvolutionRead=ctx.now()
        if evo.ready then return false,'EVOLUTION_TAKES_PRIORITY' end
        if G.finish() then return false,'FINISH_CASH_FUNDED' end
        local detail,why=G.forecast(inv)
        if not detail or not detail.worth then return false,why or 'NEXT_EVOLUTION_NO_LONGER_FASTER' end
        return true
    end
    function G.tick(boot)
        local r=ctx.Strategy.route();local h=ctx.HaloRun.state()
        if not ctx.CONFIG.GoalDirectedProgression or not ctx.CONFIG.DirectPrestige or not ctx.CONFIG.DirectPurchases
            or not ctx.S.resetEnabled or not ctx.live() or not phases[r.phase] or (r.phase=='BOOT' and not boot)
            or ctx.S.actionPending or ctx.S.resetSession or ctx.S.resetChildPending or ctx.S.buyHold
            or r.powerUnresolved or next(r.blocked or {}) then return false end
        if not boot and not h.goalFinish and ctx.now()<(h.nextGoalRead or 0) then return false end
        h.nextGoalRead=ctx.now()+ctx.CONFIG.GoalReviewSeconds
        local evo=ctx.readEvolution()
        if not evo then return false end -- Missing data never forces an idle/reset loop.
        r.evo=evo;r.lastEvolutionRead=ctx.now()
        ctx.S.prestige=ctx.S.prestige or {};ctx.S.prestige.evo=evo
        local rem=G.finish();h.goalFinish=rem
        if rem then
            ctx.Strategy.cancelResetIntent('FINISH_CASH_FUNDED')
            G.note('FINISH_CASH_FUNDED')
            if rem.count==0 then
                r.endPurchased=true;r.completionSeen=true
                ctx.Strategy.phase('HALO','все покупки подтверждены в состоянии базы')
            else ctx.Strategy.phase('BUY','деньги покрывают весь остаток базы; завершаю Halo')end
            return boot==true -- BOOT must not continue into its old tablet/power work.
        end
        if h.mode=='FINISH' then return false end
        if ctx.CONFIG.AutoEvolution and evo.ready then
            ctx.HaloRun.plan(false)
            if not ctx.HaloRun.deferEvolution(false) then
                ctx.Strategy.cancelResetIntent('EVOLUTION_TAKES_PRIORITY')
                G.note('EVOLVE_READY');ctx.HaloRun.selectEvolution()
                ctx.Strategy.reserveEvolution();return true
            end
            G.note('FINISH_ATTEMPT');return false
        end
        if not ctx.CONFIG.AutoEvolution or not ctx.CONFIG.AutoRebirth or ctx.now()<(h.nextGoalForecast or 0) then return false end
        h.nextGoalForecast=ctx.now()+ctx.CONFIG.GoalForecastSeconds
        local inv=ctx.HaloRun.checkedInvestors()
        if not inv or r.capitalCreditProbe then return false end
        local detail,why=G.forecast(inv)
        h.goalForecast=detail;h.goalForecastReason=why;h.goalForecastAt=ctx.now()
        if detail and detail.worth then
            -- Preserve the legacy final-route protections before the new shortcut.
            ctx.HaloRun.plan(false)
            if h.mode=='FINISH' or G.finish() then return false end
            G.note('REBIRTH_TO_EVOLUTION',detail)
            ctx.HaloRun.performReset(inv,nil,detail,{rate=detail.rate,plannedSpend=ctx.BN.new(0)})
            return true
        end
        G.note('GROW_TO_EVOLUTION',detail)
        return false
    end
end
