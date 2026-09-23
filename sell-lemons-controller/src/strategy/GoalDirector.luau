-- Goal selection runs before work on the base, including BOOT and recovery.
-- Adapters still own state checks, the reset lease and actual receipts.
return function(ctx)
    local G={};ctx.GoalDirector=G
    local phases={BOOT=true,BUY=true,UPGRADE=true,REBUILD=true,POWERS=true,BOOST=true,
        CAPABILITY=true,CHECKPOINT=true,OBJECTIVE=true,WAIT_GROWTH=true,WAIT_CASH=true,REBIRTH_LOOP=true}
    function G.repeating()
        return ctx.CONFIG.RepeatRebirth and ctx.CONFIG.GoalDirectedProgression and ctx.CONFIG.DirectPrestige
            and ctx.CONFIG.DirectPurchases and ctx.CONFIG.DirectUpgrades and ctx.CONFIG.AutoRebirth and ctx.S.resetEnabled
    end
    function G.repeatIntent()
        local intent=ctx.Strategy.route().resetIntent
        return intent and intent.detail and intent.detail.authorization=='adaptive-stand-rebirth'
    end
    function G.settleSeconds()
        return G.repeating() and ctx.CONFIG.RepeatRebirthSettleSeconds or ctx.CONFIG.AfterResetWait
    end
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
                ..'; prefix='..tostring(detail and detail.points)..'/'..tostring(detail and detail.totalPoints)
                ..'; reward='..ctx.BN.format(detail and detail.reward)
                ..'; stack='..tostring(detail and detail.candidate and detail.candidate.tier)
                ..'; units='..tostring(detail and detail.candidate and detail.candidate.units)
                ..'; net log gain/s='..tostring(detail and detail.score)..'; wait='..tostring(detail and detail.wait))
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
        return G.repeating() or ctx.CONFIG.GoalDirectedProgression and ctx.CONFIG.AutoEvolution and h.goalForecast~=nil
            and ctx.now()-(h.goalForecastAt or -math.huge)<=ctx.CONFIG.IncomeFreshSeconds
    end
    function G.repeatReady(inv)
        local B=ctx.BN
        if not G.repeating() then return false,'REPEAT_REBIRTH_DISABLED' end
        if not inv or not inv.time or ctx.now()-inv.time>ctx.CONFIG.IncomeFreshSeconds or inv.time>ctx.now() then
            return false,'REBIRTH_DATA_UNAVAILABLE'
        end
        if not inv.ready or not inv.reward or inv.reward.m<=0 or not inv.investors then return false,'WAIT_REBIRTH_REWARD' end
        -- Readiness is necessary, not sufficient: G.choose and dispatch validation
        -- must also prefer rebirth over stand preparation and continued income.
        if B.cmp(B.add(inv.investors,inv.reward),inv.investors)<=0 then return false,'WAIT_REBIRTH_REWARD' end
        return true,'FRESH_REBIRTH_REWARD'
    end
    function G.choose(inv)
        local data,why=ctx.DirectPrestige.snapshot()
        if not data then return nil,why end
        local s=data.snapshot;local D=ctx.DirectUpgrades;local M=ctx.UpgradeMath;local B=ctx.BN
        local cards=D.cards(s);local rate,n,total=ctx.Planner.sumRates(cards)
        if not rate or rate.m<=0 or n~=total or total==0 then return nil,'WAIT_STAND_INCOME' end
        local period=0
        for _,c in ipairs(cards)do period=math.max(period,c.periodSeconds or 0)end
        local candidates={{kind='NONE',rate=rate,seconds=0,period=period,spend=-math.huge}}
        local oldMultiplier=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
        local cumulative=-math.huge
        for tier=s.stackLevel,4 do
            if tier>s.stackLevel then
                if not ctx.CONFIG.AutoInvestorPowers then break end
                cumulative=M.add(cumulative,math.log10(ctx.GameBalance.Powers.UpgradeStack.Prices[tier]))
                if cumulative>(data.Investors or -math.huge)-1e-9 then break end
            end
            local virtual=table.clone(s);virtual.cap=({[0]=1,5,25,100,math.huge})[tier]
            -- Allocate one parallel wave against ONE shared cash wallet.
            local rows=D.allocate(virtual,cards)
            if #rows>0 then
                local byName={};for _,q in ipairs(rows)do byName[q.key]=q end
                local afterRate=B.new(0);local units=0
                for _,c in ipairs(cards)do
                    local q=byName[c.key];local added=q and q.units or 0;units=units+added
                    local factor=M.countMultiplier(c.key,c.level+1+added)-M.countMultiplier(c.key,c.level+1)
                    afterRate=B.add(afterRate,B.mul(ctx.Planner.sourceRate(c),M.bn(factor)))
                end
                local bank=B.sub(inv.investors,M.bn(cumulative))
                local multiplier=B.add(B.new(1),B.mul(bank,inv.perInvestor))
                afterRate=B.mul(afterRate,B.div(multiplier,oldMultiplier))
                candidates[#candidates+1]={kind=tier>s.stackLevel and 'POWER' or 'STANDS',tier=tier,rows=rows,
                    rate=afterRate,spend=cumulative,period=period,units=units,snapshot=s,
                    seconds=math.max(.05,ctx.Strategy.actionSeconds('upgrade'))
                        +(tier-s.stackLevel)*math.max(.05,ctx.Strategy.actionSeconds('power'))}
            end
        end
        local r=ctx.Strategy.route()
        r.tacticalStarted=r.tacticalStarted or ctx.now()
        local age=math.max(0,ctx.now()-r.tacticalStarted)
        local setup=math.max(.05,ctx.Strategy.actionSeconds('rebirth'))+G.settleSeconds()
        local decision,reason=ctx.GoalPlanner.tactical(data,inv,candidates,age,setup,ctx.CONFIG)
        if decision then decision.rate=rate;decision.cost=setup;decision.restoreQuality='short-horizon observed stand economy' end
        return decision,reason
    end
    function G.power(item)
        local r=ctx.Strategy.route();local started=ctx.now()
        local wallet=ctx.DirectPurchases.wallet();if not wallet then return end
        ctx.Strategy.syncPowerBank(wallet.investors)
        local done,message=ctx.DirectPurchases.powerPurchase(item,function()
            if not G.repeating() or G.finish() then return false end
            local evo=ctx.readEvolution();if not evo or evo.ready then return false end
            local inv=ctx.readInvestors();if not inv then return false end
            local d=G.choose(inv)
            return d and d.choice=='POWER' and d.candidate.snapshot.stackLevel==item.level
        end)
        if not done and message=='STATE_CHANGED_BEFORE_CLICK' then return end
        -- Sent but unconfirmed power requests retain the normal debit/receipt lock.
        r.powerUsed=ctx.BN.add(r.powerUsed or ctx.BN.new(0),item.price)
        r.powerBank=ctx.BN.sub(wallet.investors,item.price)
        if not done then
            r.powerUnresolved={item=item,reason=tostring(message)}
            ctx.pause('POWER_OUTCOME_UNRESOLVED','Не подтверждён UpgradeStack; повтор заблокирован.');return
        end
        ctx.Strategy.recordTiming('power',ctx.now()-started)
        ctx.S.counts.power=(ctx.S.counts.power or 0)+1;ctx.Strategy.recordSpend(item.price)
        r.batchSelected=nil;r.maxUnavailable=nil;r.maxObserved=nil;r.availableBatches=nil
        r.models={};r.priceModels={};r.batchQuotes={}
        ctx.log('TACTICAL_STACK_RECEIPT','UpgradeStack tier '..tostring(item.level+1)..'; verified; reevaluate next tier')
    end
    function G.repeatStep()
        local r=ctx.Strategy.route();local inv=ctx.readInvestors()
        if inv then r.latestInvestors=inv end
        local d,why
        if inv and inv.time and ctx.now()-inv.time<=ctx.CONFIG.IncomeFreshSeconds then d,why=G.choose(inv)end
        if not d then
            G.note(why or 'REBIRTH_DATA_WAIT')
            -- Missing income never authorizes a blind rebirth or stops ordinary
            -- available upgrades. The direct adapters retain their own guards.
            return false
        end
        G.note(d.choice,d)
        if d.choice=='REBIRTH' then
            local yes=G.repeatReady(inv)
            if yes then
                r.evolutionCheckTotal=ctx.Planner.totalMinimum(inv,r.spent)
                ctx.HaloRun.performReset(inv,nil,d,{rate=d.rate,plannedSpend=ctx.BN.new(0)})
            end
        elseif d.choice=='POWER' then
            for _,item in ipairs(ctx.DirectPurchases.powers())do
                if item.name=='UpgradeStack' and item.available then G.power(item);break end
            end
        elseif d.choice=='STANDS' then
            ctx.DirectUpgrades.dispatch(d.candidate.rows,d.candidate.snapshot)
        else
            ctx.status(d.choice,d.choice=='WAIT_EVOLUTION' and 'Доход ведёт к эволюции; сброс сейчас медленнее.'
                or 'Награда ещё растёт выгоднее сброса; проверяю стенды и UpgradeStack.')
        end
        if ctx.live() and not (r.endPurchased or r.completionSeen) and r.phase~='EVOLVE_RESERVE' then
            ctx.Strategy.phase('REBIRTH_LOOP','выбор: UpgradeStack, стенды, выгодный rebirth или эволюция')
        end
        return true
    end
    function G.validate(inv)
        -- Recompute the exact goal and comparison immediately before dispatch.
        -- Receipt/epoch/bank/policy checks are still performed by the ordinary lease.
        local evo=ctx.readEvolution()
        if not evo then return false,'GOAL_DATA_UNAVAILABLE' end
        local r=ctx.Strategy.route();r.evo=evo;r.lastEvolutionRead=ctx.now()
        if evo.ready then return false,'EVOLUTION_TAKES_PRIORITY' end
        if G.finish() then return false,'FINISH_CASH_FUNDED' end
        if G.repeatIntent() then
            local ready,why=G.repeatReady(inv);if not ready then return false,why end
            local d,reason=G.choose(inv)
            return d~=nil and d.choice=='REBIRTH',reason or 'PREPARATION_OR_WAIT_NOW_BETTER'
        end
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
        if not boot and not h.goalFinish and ctx.now()<(h.nextGoalRead or 0) then
            return G.repeating() and h.mode~='FINISH' and not h.repeatFinishAttempt
        end
        h.nextGoalRead=ctx.now()+ctx.CONFIG.GoalReviewSeconds
        local evo=ctx.readEvolution()
        if not evo then
            if G.repeating() then ctx.status('REBIRTH_DATA_WAIT','Жду свежие данные этапа; базу не строю.');return true end
            return false
        end
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
        h.repeatFinishAttempt=nil
        if ctx.CONFIG.AutoEvolution and evo.ready then
            ctx.HaloRun.plan(false)
            if not ctx.HaloRun.deferEvolution(false) then
                ctx.Strategy.cancelResetIntent('EVOLUTION_TAKES_PRIORITY')
                G.note('EVOLVE_READY');ctx.HaloRun.selectEvolution()
                ctx.Strategy.reserveEvolution();return true
            end
            h.repeatFinishAttempt=true;G.note('FINISH_ATTEMPT');return false
        end
        if G.repeating() then return G.repeatStep() end
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
