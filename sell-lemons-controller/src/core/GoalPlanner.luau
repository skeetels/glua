-- Compare time to the NEXT evolution, not time to rebuild an entire old base.
return function(ctx)
    -- Numeric is initialized before all core planners; ctx.BN is a later
    -- ClientContext alias and must not be captured during core initialization.
    local G={};ctx.GoalPlanner=G;local B=ctx.Core.BN;local P=ctx.PrestigeMath;local M=ctx.UpgradeMath
    function G.prefix(trace,factor,needed,config)
        if not trace or not trace.complete or trace.invalid or not trace.points or #trace.points==0
            or not factor or factor.m<=0 or not needed then return nil,'NO_CLEAN_PREFIX' end
        local first=trace.points[1]
        if not first.rate or first.rate.m<=0 or not first.age or first.age<0 then return nil,'NO_BOOTSTRAP_RATE' end
        -- Charge the observed time needed to reach the first measured layout.
        -- Start with zero cash/output: no free pre-reset wallet or full-base income.
        local time=first.age;local money=B.new(0);local earned=B.new(0)
        local rate=B.mul(first.rate,factor)
        local best=time+ctx.Core.eta(earned,needed,rate);local used=1
        for i=2,#trace.points do
            local a,b=trace.points[i-1],trace.points[i]
            if not b.rate or b.rate.m<=0 or not a.spent or not b.spent
                or not a.service or not b.service or b.service<a.service or B.cmp(b.spent,a.spent)<0 then
                return nil,'PREFIX_DISCONTINUITY'
            end
            local price=B.sub(b.spent,a.spent)
            local wait=ctx.Core.eta(money,price,rate)
            local elapsed=wait+math.max(.01,b.service-a.service)
            -- Reaching the goal before the next upgrade/purchase needs no purchase.
            if time+elapsed>=best or time+elapsed>(config.MaximumReplaySeconds or 86400) then break end
            local output=B.mul(rate,elapsed)
            money=B.sub(B.add(money,output),price);earned=B.add(earned,output);time=time+elapsed
            rate=B.mul(b.rate,factor)
            local eta=time+ctx.Core.eta(earned,needed,rate)
            if eta<best then best=eta;used=i end
        end
        if best==math.huge or best~=best then return nil,'UNBOUNDED_GOAL' end
        return {seconds=best,points=used,totalPoints=#trace.points,bootstrap=first.age}
    end
    -- A short receding-horizon comparison. Reward uses cumulative production,
    -- so paying cash for stands must NOT subtract that cash from earned output.
    -- Investor spending, unlike cash spending, reduces the income multiplier.
    -- This is a local throughput estimate, not a promise of a complete Halo run.
    function G.tactical(data,inv,candidates,age,setup,config)
        if not inv.perInvestor or inv.perInvestor<=0 then return nil,'INVESTOR_BONUS_UNKNOWN' end
        local old=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
        local earned=P.add(data.Cash,data.CashSpent)
        local best,goal;local options={}
        for _,c in ipairs(candidates)do
            local option={kind=c.kind,tier=c.tier,units=c.units,spend=c.spend,score=0,rate=c.rate,seconds=c.seconds}
            options[#options+1]=option
            local bank=M.sub(data.Investors or -math.huge,c.spend or -math.huge)
            local spent=P.add(data.InvestorsSpent,c.spend~=-math.huge and c.spend or nil)
            local target=P.evolutionCash(data.snapshot.epoch.Evolution,bank,spent,config.EvolutionMinimumBank)
            if target then
                local needed=B.sub(M.bn(target),earned and M.bn(earned) or B.new(0))
                local eta=c.seconds+ctx.Core.eta(B.new(0),needed,c.rate)+(needed.m>0 and c.period or 0)
                option.evolution=eta
                if not goal or eta<goal.seconds then goal={candidate=c,seconds=eta}end
            end
            for _,wait in ipairs({0,.25,.5,1,2,4,8,16,32})do
                -- The first payout is charged even if an RPC acknowledges fast.
                local production
                if wait>0 then production=B.log(B.mul(c.rate,wait))end
                local future=P.add(earned,production)
                local reward=P.reward(future,nil,bank,spent)
                if reward and reward>=0 then
                    local after=P.add(bank,reward)
                    local multiplier=B.add(B.new(1),B.mul(M.bn(after),inv.perInvestor))
                    local improvement=B.log(multiplier)-B.log(old)
                    local seconds=math.max(.05,age+c.seconds+wait+(wait>0 and c.period or 0)+setup)
                    local score=improvement/seconds
                    if score>option.score then option.score=score;option.wait=wait end
                    if score>0 and (not best or score>best.score*(1+1e-6)) then
                        best={candidate=c,wait=wait,score=score,reward=M.bn(reward),gain=improvement,
                            seconds=seconds,authorization='adaptive-stand-rebirth',target='next evolution'}
                    end
                end
            end
        end
        -- Near an evolution, actually finishing it beats another reset cycle.
        -- The repeated-cycle estimate is only a comparison heuristic: ready
        -- evolution and funded/protected Halo routes are checked by the director.
        local distance=math.max(0,17.7+13.6*data.snapshot.epoch.Evolution-B.log(old)+math.log10(inv.perInvestor))
        if config.AutoEvolution and goal and goal.seconds<math.huge and (not best or goal.seconds<=setup+distance/best.score)then
            return {choice=goal.candidate.kind=='NONE' and 'WAIT_EVOLUTION' or goal.candidate.kind,
                candidate=goal.candidate,direct=goal.seconds,options=options,reason='current production reaches evolution sooner'}
        end
        if best then
            best.choice=best.candidate.kind~='NONE' and best.candidate.kind or best.wait==0 and 'REBIRTH' or 'WAIT_REWARD'
            best.reason='compare net investor multiplier gained per cycle second, including preparation and payout'
            best.options=options
            return best
        end
        return nil,'NO_USEFUL_TACTICAL_ACTION'
    end
    function G.compare(data,inv,rate,kind,trace,growth,span,setup,config,time)
        if not data or not inv or not inv.ready or not rate or rate.m<=0 or not inv.perInvestor then return nil,'GOAL_DATA_UNAVAILABLE' end
        local index=data.snapshot.epoch.Evolution
        local before=P.evolutionCash(index,data.Investors,data.InvestorsSpent,config.EvolutionMinimumBank)
        local earned=P.add(data.Cash,data.CashSpent)
        if before==nil then return nil,'GOAL_FORMULA_UNAVAILABLE' end
        if before==-math.huge or earned and earned>=before then return nil,'EVOLUTION_READY' end
        if not trace or trace.kind~=kind or trace.epoch~=index or not trace.base then return nil,'NO_COMPARABLE_PREFIX' end
        local last=trace.points and trace.points[#trace.points]
        if not last or not last.time or time-last.time>config.IncomeFreshSeconds or last.time>time then return nil,'PREFIX_STALE' end
        local gain=ctx.Planner.netInvestorGain(inv,B.new(0))
        if not gain or gain<=1 then return nil,'NO_RESET_GAIN' end
        local bank=P.add(data.Investors,data.reward)
        local after=P.evolutionCash(index,bank,data.InvestorsSpent,config.EvolutionMinimumBank)
        if after==nil then return nil,'GOAL_FORMULA_UNAVAILABLE' end
        local multiplier=B.add(B.new(1),B.mul(M.bn(bank),inv.perInvestor))
        local factor=B.mul(B.div(multiplier,trace.base),config.GoalReplayIncomeConfidence)
        local prefix,why=G.prefix(trace,factor,M.bn(after),config)
        if not prefix then return nil,why end
        local needed=B.sub(M.bn(before),earned and M.bn(earned) or B.new(0))
        -- Give continuation credit for observed growth, for a bounded horizon.
        local direct=ctx.Planner.productionETA(needed,rate,growth,math.min(span or 0,config.GoalForecastGrowthSeconds))
        local reset=setup+prefix.seconds
        local advantage=math.max(config.GoalAdvantageSeconds,reset*config.RouteResetMargin)
        return {authorization='next-evolution-prefix',target='evolution '..tostring(index),
            direct=direct,reset=reset,cost=reset,saved=direct-reset,worth=direct>reset+advantage,
            points=prefix.points,totalPoints=prefix.totalPoints,rate=rate,kind=kind,gain=gain,
            restoreQuality='same-evolution observed prefix; exact prestige formula; discounted replay income',
            goal={mode='exact next-evolution ETA',continueETA=direct,resetETA=reset}}
    end
end
