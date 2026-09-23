-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.Planner=(function()
-- PLANNER_BEGIN
-- Strategic policy. Pure Lua/Luau: no clicks, timers, filesystem or network access.
-- Reference data: Sell Lemons Wiki / Evolution (developer-attributed table).
-- https://sell-lemons-roblox.fandom.com/wiki/Evolution
-- Values below are published ROUNDED thresholds, not authoritative server constants.
local Planner = {}
Planner.requirements = {
    [1]={m=5.012,e=17,name='Orange'}, [2]={m=1.995,e=31,name='Lime'},
    [3]={m=7.943,e=44,name='Grapefruit'}, [4]={m=3.162,e=58,name='Tangerine'},
    [5]={m=1.259,e=72,name='Pomelo'}, [6]={m=5.012,e=85,name='Abyssalime'},
    [7]={m=1.995,e=99,name='Nullfruit'}, [8]={m=7.943,e=112,name='Voidlemon'},
    [9]={m=3.162,e=126,name='Purity'},
}
function Planner.target(index)
    local x=index and Planner.requirements[index+1]
    return x and __slctx.Core.BN.new(x.m,x.e) or nil, x and x.name or nil
end
function Planner.totalMinimum(inv,spent)
    -- Historical spending is unknown on attachment to an existing game session.
    -- This is explicitly a lower bound, never fabricated exact lifetime investors.
    if not inv or not inv.investors or not inv.reward then return nil end
    return __slctx.Core.BN.add(__slctx.Core.BN.add(inv.investors,inv.reward),spent or __slctx.Core.BN.new(0))
end
function Planner.shouldInspectEvolution(index,inv,spent,uncertainSpent,knownReady)
    local required=Planner.target(index)
    local total=Planner.totalMinimum(inv,spent)
    if knownReady then return true,'previously ready' end
    if not required then return true,'threshold not published; consult live UI at wall' end
    if not total then return false,'investors unknown' end
    -- The table is rounded. Looking a little early is safe; executing early is not.
    if __slctx.Core.BN.cmp(total,__slctx.Core.BN.mul(required,0.999))>=0 then return true,'investor target reached' end
    if uncertainSpent then return true,'historical spending unknown; checkpoint only' end
    return false,'below next evolution threshold'
end
function Planner.investorMultiplier(inv)
    if not inv or not inv.investors or not inv.reward then return nil end
    local b=inv.perInvestor
    if not b or b<=0 then return nil end
    local B=__slctx.Core.BN
    local before=B.add(B.new(1),B.mul(inv.investors,b))
    local after=B.add(B.new(1),B.mul(B.add(inv.investors,inv.reward),b))
    return B.number(B.div(after,before))
end

-- With unchanged production intervals, total growth cannot exceed the largest
-- per-source payout factor. An unchanged unparseable label is a fallback
-- estimate of that condition, not proof of the game's hidden timing.
function Planner.growthBound(before,after)
    if not before or not after or #before~=#after or #before==0 then return nil end
    local byPath={};for _,c in ipairs(before) do byPath[c.path]=c end
    local upper=0;local B=__slctx.Core.BN
    for _,c in ipairs(after) do
        local b=byPath[c.path]
        if not b or c.name~=b.name or not c.income or not b.income then return nil end
        local old,new=Planner.sourceRate(b),Planner.sourceRate(c)
        if not old or not new then
            if not c.period or c.period=='' or c.period~=b.period then return nil end
            old,new=b.income,c.income
        end
        if old.m==0 then
            if new.m>0 then return nil end
        elseif new.m>0 then upper=math.max(upper,(B.log(new)-B.log(old))*math.log(10)) end
        byPath[c.path]=nil
    end
    if next(byPath) then return nil end
    return upper
end

function Planner.period(text)
    local s=__slctx.Core.clean(text):lower():gsub('\194\181','u'):gsub('\206\188','u')
    local n,unit=s:match('^every%s+(%d+%.?%d*)%s*([%a]+)$')
    local units={s=1,sec=1,secs=1,second=1,seconds=1,ms=1e-3,us=1e-6,ns=1e-9,ps=1e-12,
        fs=1e-15,as=1e-18,zs=1e-21,ys=1e-24,m=60,min=60,mins=60,h=3600,hr=3600}
    n=tonumber(n)
    return n and n>0 and units[unit] and n*units[unit] or nil
end
function Planner.sourceRate(c)
    if c and c.income and c.income.m==0 then return __slctx.Core.BN.new(0) end
    local period=c.periodSeconds or Planner.period(c.period or '')
    return period and c.income and __slctx.Core.BN.div(c.income,period) or nil
end
function Planner.sumRates(cards)
    local result=__slctx.Core.BN.new(0);local known=0
    for _,c in ipairs(cards) do
        local r=Planner.sourceRate(c)
        if r then result=__slctx.Core.BN.add(result,r);known=known+1 end
    end
    return result.m>0 and result or nil,known,#cards
end
-- ECONOMIC_PLANNER_BEGIN
function Planner.logOnePlus(x)
    if not x or x<0 or x~=x then return nil end
    if x==math.huge then return math.huge end
    if x<1e-5 then return x-x*x/2+x*x*x/3 end
    return math.log(1+x)
end

function Planner.logGrowth(rate,delta)
    local B=__slctx.Core.BN
    if not rate or not delta or rate.m<=0 or delta.m<=0 then return 0 end
    local exponent=B.log(delta)-B.log(rate)
    if exponent>12 then return exponent*math.log(10)+Planner.logOnePlus(10^(-exponent)) end
    return Planner.logOnePlus(10^exponent)
end

function Planner.projectUpgrade(c,learned)
    local B=__slctx.Core.BN
    local rate=Planner.sourceRate(c)
    local count,units=__slctx.Core.count(c.count),__slctx.Core.count(c.stack)
    if not rate or rate.m<=0 or not count or count<=0 or not units or units<=0 then
        return nil,'unknown source rate/level count'
    end
    local relative=units/count
    local quality='local linear estimate; milestones unknown'
    -- Reuse only a nearby, repeatedly observed REGULAR count elasticity.
    -- A large one-off milestone is deliberately not projected onto the next purchase.
    if learned and learned.samples and learned.samples>=2 and learned.elasticity
        and learned.name==c.name and learned.period==c.period
        and learned.toCount and count>=learned.toCount and count<=learned.toCount*1.5
        and learned.elasticity>=0.5 and learned.elasticity<=1.5 then
        relative=math.exp(Planner.logOnePlus(units/count)*learned.elasticity)-1
        quality='nearby regular slope; milestone spikes excluded'
    end
    if relative<=0 or relative~=relative or relative==math.huge then return nil,'unbounded estimate' end
    return B.mul(rate,relative),quality
end

function Planner.learnUpgrade(previous,before,after)
    local B=__slctx.Core.BN
    local n0,n1=__slctx.Core.count(before.count),__slctx.Core.count(after.count)
    local r0,r1=Planner.sourceRate(before),Planner.sourceRate(after)
    if not n0 or not n1 or n0<=0 or n1<=n0 or not r0 or not r1 or r0.m<=0
        or B.cmp(r1,r0)<=0 then return nil end
    local denominator=Planner.logOnePlus((n1-n0)/n0)
    if not denominator or denominator<=0 then return nil end
    local exponent=(B.log(r1)-B.log(r0))*math.log(10)/denominator
    local regular=exponent>=0.5 and exponent<=1.5 and before.period==after.period
    local adjacent=regular and previous and previous.elasticity and previous.samples
        and previous.name==after.name and previous.period==after.period and previous.toCount==n0
        and math.abs(previous.elasticity-exponent)<=0.2
    return {name=after.name,period=after.period,fromCount=n0,toCount=n1,
        elasticity=regular and (adjacent and (previous.elasticity+exponent)*0.5 or exponent) or nil,
        samples=regular and (adjacent and previous.samples+1 or 1) or 0,
        milestone=not regular,observedRelative=B.number(B.div(r1,r0))-1}
end

function Planner.upgradeScore(c,learned)
    local B=__slctx.Core.BN
    if not c.cost then return nil end
    local delta=Planner.projectUpgrade(c,learned)
    if not delta or delta.m<=0 then return nil end
    if c.cost.m==0 then return math.huge end
    return B.log(delta)-B.log(c.cost)
end

function Planner.upgradePlan(c,amount,rate,target,learned,latency,scale)
    local B=__slctx.Core.BN
    if not c.cost or not amount or B.cmp(amount,c.cost)<0 or c.available==false then return nil end
    local delta,quality=Planner.projectUpgrade(c,learned)
    if not delta then return {candidate=c,known=false} end
    if scale then delta=B.mul(delta,scale) end
    local action=math.max(0.01,latency or 0.18)
    local opportunityCost=B.add(c.cost,rate and B.mul(rate,action) or B.new(0))
    local score=opportunityCost.m==0 and math.huge or B.log(delta)-B.log(opportunityCost)
    local result={candidate=c,known=true,delta=delta,quality=quality,score=score,action=action}
    if rate and rate.m>0 then
        local capitalTime=B.number(B.div(c.cost,rate))
        result.growthLog=Planner.logGrowth(rate,delta)
        result.growthSpeed=capitalTime==math.huge and 0 or result.growthLog/(action+capitalTime)
        result.payback=delta.m>0 and B.number(B.div(c.cost,delta)) or math.huge
        if target and target.cost then
            -- Pay at dispatch; old income during action, new income only afterwards.
            -- This is an expectation from UI rates, not a server timing guarantee.
            local balance=B.add(B.sub(amount,c.cost),B.mul(rate,action))
            result.directETA=__slctx.Core.eta(amount,target.cost,rate)
            result.afterETA=action+__slctx.Core.eta(balance,target.cost,B.add(rate,delta))
            result.savedSeconds=result.directETA-result.afterETA
        end
    end
    return result
end

function Planner.chooseUpgrade(cards,amount,rate,target,models,latency)
    local B=__slctx.Core.BN
    local total,known,count=Planner.sumRates(cards)
    -- Aggregate calibration is legal only for a complete income inventory.
    local scale=rate and total and known==count and count>0 and B.div(rate,total) or nil
    local result={allKnown=true,known=0,affordable=0,plans={},modelComplete=known==count and count>0}
    local best,unknown
    for _,c in ipairs(cards) do
        if c.available~=false and not c.cost then result.allKnown=false end
        local plan=Planner.upgradePlan(c,amount,rate,target,models and models[c.path],latency,scale)
        if plan then
            result.affordable=result.affordable+1;result.plans[#result.plans+1]=plan
            if plan.known then
                result.known=result.known+1
                local better=not best
                if best then
                    if plan.afterETA and best.afterETA and plan.afterETA<math.huge and best.afterETA<math.huge then
                        better=plan.afterETA<best.afterETA-1e-8
                            or math.abs(plan.afterETA-best.afterETA)<1e-8 and plan.score>best.score
                    else better=plan.score>best.score end
                end
                if better then best=plan end
            else result.allKnown=false;unknown=unknown or plan end
        end
    end
    result.best=best or unknown
    result.directETA=target and target.cost and __slctx.Core.eta(amount,target.cost,rate) or nil
    return result
end

function Planner.waitDominates(summary,remaining,config)
    local eta=summary and summary.directETA
    if not eta or eta<=0 or eta==math.huge or eta>remaining or remaining<=0 then return false end
    if not summary.allKnown then return false end
    local best=summary.best
    if not best then return true end
    if not best.known or not best.afterETA then return false end
    local margin=math.max(config.DecisionAdvantageSeconds or 0.25,eta*(config.DecisionRelativeMargin or 0.04))
    return best.afterETA>=eta-margin
end
-- ECONOMIC_PLANNER_END
function Planner.pickSavings(items,amount,rate,budget,majorMinimum)
    local best,bestScore,bestEta
    if budget<=0 then return nil end
    for _,c in ipairs(items) do
        local eta=c.cost and __slctx.Core.eta(amount,c.cost,rate)
        if eta and eta>0 and eta<=budget then
            -- This priority is not a claim that an individual x100,000 boost
            -- multiplies all business income. It is a target-preservation rule.
            local major=(c.multiplier or 0)>=majorMinimum
            local s=(major and 1e6 or 0)+(c.newSource and 1000 or 0)-eta
            if not best or s>bestScore then best,bestScore,bestEta=c,s,eta end
        end
    end
    return best,bestEta
end

function Planner.isTerminalName(name)
    return __slctx.Core.clean(name):lower()=='the end'
end
function Planner.completionMarker(name,price,info)
    -- Only explicit end-of-catalog text. A missing/hidden/disabled button is NOT completion.
    local markers={['(complete)']=true,['all purchased']=true,['all bought']=true,['everything purchased']=true,
        ['all upgrades purchased']=true,['nothing left to buy']=true,['tycoon complete']=true,
        ['no more purchases']=true,['all buttons purchased']=true}
    return markers[__slctx.Core.clean(name):lower()] or markers[__slctx.Core.clean(info):lower()] or false
end
function Planner.wallProgress(buyCount,upgradeCount,previous)
    return not previous or previous.buy~=buyCount or previous.upgrade~=upgradeCount
end
-- CYCLE_PLANNER_BEGIN
-- All amounts are observed-bank estimates. The game can round its labels.
-- Spending authorization is separate from an estimate of a useful reset.
function Planner.powerBudgetInfo(investors,used,gross,config)
    local B=__slctx.Core.BN;used=used or B.new(0)
    local f=config.PowerMaxEpochFraction or 0.05
    if not investors or not gross or f<=0 or f>=1 then return nil end
    local floor=B.mul(gross,1-f)
    local absolute=B.new(config.TabletReserve or 400)
    if B.cmp(floor,absolute)<0 then floor=absolute end
    local limit=B.sub(B.mul(gross,f),used)
    local available=B.sub(investors,floor)
    if B.cmp(available,limit)<0 then limit=available end
    return {available=limit,floor=floor,gross=gross,used=used,fraction=f}
end
function Planner.powerBudgetAllows(price,investors,used,gross,config)
    local B=__slctx.Core.BN;local budget=Planner.powerBudgetInfo(investors,used,gross,config)
    if not price or not budget then return false,'UNKNOWN_INVESTOR_BALANCE' end
    if B.cmp(price,investors)>0 then return false,'POWER_UNAFFORDABLE' end
    if B.cmp(B.add(used or B.new(0),price),B.mul(gross,budget.fraction))>0 then
        return false,'POWER_LIFETIME_BUDGET'
    end
    if B.cmp(B.sub(investors,price),budget.floor)<0 then return false,'POWER_PROTECTED_BANK' end
    return true,'POWER_WITHIN_CUMULATIVE_5_PERCENT'
end
function Planner.requiredPowerReward(price,investors,used,gross,config)
    local B=__slctx.Core.BN;local f=config.PowerMaxEpochFraction or 0.05
    if not price or not investors or not gross or f<=0 or f>=1 then return nil end
    -- U+P <= f(G+R); I+R-P >= (1-f)(G+R); I+R-P >= reserve.
    local a=B.sub(B.div(B.add(used or B.new(0),price),f),gross)
    local rhs=B.add(B.mul(gross,1-f),price)
    local b=B.div(B.sub(rhs,investors),f)
    local c=B.sub(B.add(price,B.new(config.TabletReserve or 400)),investors)
    if B.cmp(b,a)>0 then a=b end
    if B.cmp(c,a)>0 then a=c end
    return a
end
function Planner.netInvestorGain(inv,spend)
    local B=__slctx.Core.BN
    if not inv or not inv.investors or not inv.reward or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    local bank=B.add(inv.investors,inv.reward)
    if spend and B.cmp(spend,bank)>0 then return nil end
    bank=B.sub(bank,spend or B.new(0))
    local before=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
    local after=B.add(B.new(1),B.mul(bank,inv.perInvestor))
    return B.number(B.div(after,before)),bank
end
function Planner.nextBatchHint(item,current,hints)
    if not item or item.name~='UpgradeStack' then return nil,'not a verified throughput power' end
    if current=='max' then return nil,'MAX already observed' end
    -- Only explicit next/arrow text is a preview. A CURRENT +25 is not a NEXT +25.
    local text=__slctx.Core.clean((item.bonus or '')..' '..(item.info or '')):lower()
    local nextN=text:match('next%s*:?%s*%+?(%d+)') or text:match('%-%>%s*%+?(%d+)')
        or text:match('→%s*%+?(%d+)')
    if text:match('next%s*:?%s*max') or text:match('%-%>%s*max') or text:match('→%s*max') then
        return 'max','explicit GUI preview'
    end
    if nextN and tonumber(nextN)>(tonumber(current) or 0) then return tonumber(nextN),'explicit GUI preview' end
    local hint=hints and hints[tonumber(current)]
    if hint then return hint,'user-supplied tier hint; must verify after purchase' end
    return nil,'next throughput tier not observed'
end
function Planner.powerPlan(item,inv,used,gross,current,config)
    if not item or not item.price or not inv or not inv.investors or not inv.reward or not gross then return nil end
    local B=__slctx.Core.BN
    local afterBank=B.add(inv.investors,inv.reward);local afterGross=B.add(gross,inv.reward)
    local plan={name=item.name,title=item.title,path=item.path,price=item.price,bonus=item.bonus,
        currentBatch=current,quoteTime=item.observedAt}
    plan.id=tostring(item.path)..'|'..B.format(item.price)..'|'..tostring(item.bonus)
    plan.canBuyNow=Planner.powerBudgetAllows(item.price,inv.investors,used,gross,config)
    plan.canBuyAfter=Planner.powerBudgetAllows(item.price,afterBank,used,afterGross,config)
    plan.requiredReward=Planner.requiredPowerReward(item.price,inv.investors,used,gross,config)
    plan.shortfall=plan.requiredReward and B.sub(plan.requiredReward,inv.reward)
    plan.nextBatch,plan.quality=Planner.nextBatchHint(item,current,config.PowerNextBatchHints)
    plan.gainAfterPower,plan.bankAfterPower=Planner.netInvestorGain(inv,item.price)
    return plan
end
function Planner.learnPrice(previous,before,after)
    local B=__slctx.Core.BN
    if before.maxMode or after.maxMode or not before.cost or not after.cost or before.cost.m<=0 then return nil end
    local n=__slctx.Core.count(before.stack)
    if not n or n<1 or __slctx.Core.count(after.stack)~=n or before.name~=after.name then return nil end
    if (__slctx.Core.count(after.count) or -1)~=(__slctx.Core.count(before.count) or 0)+n then return nil end
    local q=B.number(B.div(after.cost,before.cost))
    if not q or q<1 or q>1e6 then return nil end
    local adjacent=previous and previous.batch==n and previous.toCount==__slctx.Core.count(before.count)
        and previous.name==before.name and math.abs(math.log(q/previous.ratio))<0.05
    return {ratio=q,batch=n,toCount=__slctx.Core.count(after.count),name=after.name,
        samples=adjacent and previous.samples+1 or 1,
        highRatio=adjacent and math.max(previous.highRatio or q,q) or q}
end
function Planner.remainingBudgetWork(card,budget,model)
    local B=__slctx.Core.BN
    if not model or model.samples<2 or not card.cost or card.cost.m<=0 or not budget
        or model.toCount~=__slctx.Core.count(card.count) or model.name~=card.name
        or model.batch~=__slctx.Core.count(card.stack) or B.cmp(budget,card.cost)<0 then return nil end
    -- Planning only: a steeper slope and a later savings haircut reduce overconfidence.
    -- Every REAL price is still read again; this curve never authorizes a purchase.
    local q=math.max(1.0000001,model.highRatio or model.ratio)
    local x=B.mul(B.div(budget,card.cost),q-1)
    local numerator=x.m==0 and 0 or (B.log(x)>12 and B.log(x)*math.log(10) or Planner.logOnePlus(B.number(x)))
    local batches=math.max(0,math.min(1000000,math.floor(numerator/math.log(q))))
    return batches*model.batch,'local price-curve estimate, not a game constant'
end
function Planner.workClicks(work,batch)
    if not work or (batch~='max' and (type(batch)~='number' or batch<1)) then return nil end
    local n=0
    for _,levels in pairs(work) do
        if type(levels)=='number' and levels>0 then n=n+(batch=='max' and 1 or math.ceil(levels/batch)) end
    end
    return n
end
function Planner.rebuildAfterBatch(profile,oldBatch,newBatch,latency,fallback)
    if not profile then return fallback or 60,'initial recovery estimate' end
    local duration=math.max(0,profile.duration or fallback or 60)
    local input=math.max(0,math.min(duration,profile.upgradeSeconds or 0))
    local oldClicks=profile.upgradeActions or Planner.workClicks(profile.work,oldBatch)
    local newClicks=Planner.workClicks(profile.work,newBatch)
    if not oldClicks or not newClicks or oldClicks<=0 then return duration,'measured recovery, no throughput decomposition' end
    -- Amdahl: accelerate only stand-input time, NOT base purchases, waits or navigation.
    local accelerated=input*math.min(1,newClicks/oldClicks)
    return duration-input+accelerated,(profile.quality or 'measured comparable recovery')..'; stand-input component only'
end
function Planner.capabilityResetDecision(inv,config,context)
    if config.CapabilityRebirth==false then return false,'CAPABILITY_RESETS_DISABLED' end
    local g=context and context.powerGoal
    if not g or g.name~='UpgradeStack' then return false,'NO_THROUGHPUT_GOAL' end
    if g.canBuyNow then return false,'POWER_BUY_WITHOUT_RESET' end
    if not inv or not inv.ready or not inv.reward or inv.reward.m==0 then return false,'REBIRTH_NOT_READY' end
    if not g.canBuyAfter then return false,'POWER_REWARD_SHORTFALL' end
    if context.protectedMajor then return false,'PROTECTED_MAJOR_TARGET' end
    if not g.nextBatch or not g.currentBatch or g.currentBatch=='max' then return false,'POWER_NEXT_BATCH_UNKNOWN' end
    local guaranteedGain=Planner.netInvestorGain(inv,context.plannedSpend or g.price)
    if not guaranteedGain or guaranteedGain<1 then return false,'POWER_WOULD_REDUCE_CURRENT_PRODUCTION' end
    local oldClicks=Planner.workClicks(context.work,g.currentBatch)
    local newClicks=Planner.workClicks(context.work,g.nextBatch)
    if not oldClicks or not newClicks or oldClicks<=newClicks then return false,'POWER_WORKLOAD_UNMEASURED' end
    local recovery,source=Planner.rebuildAfterBatch(context.rebuildProfile,g.currentBatch,g.nextBatch,
        context.actionSeconds,context.rebuildSeconds)
    local cost=(context.resetSeconds or 5)+(config.AfterResetWait or 2)+recovery+(context.powerSeconds or 1)
    local raw=(oldClicks-newClicks)*(context.actionSeconds or 0.18)
    local saved=raw*(config.PowerSavingsConfidence or 0.6)
    local detail={cost=cost,rawSaved=raw,saved=saved,oldClicks=oldClicks,newClicks=newClicks,
        recovery=recovery,recoverySource=source,workSource=context.workSource,goal=g}
    if saved>cost*(1+(config.ResetDecisionMargin or 0.08)) then
        return true,'RESET_FOR_UPGRADE_STACK',guaranteedGain,detail
    end
    return false,'POWER_RESET_NOT_REPAID_BY_INPUT_SAVINGS',g.gainAfterPower,detail
end


-- MACRO_PLANNER_BEGIN
-- Bounded multi-action planning on observed quotes and locally learned cost slopes.
-- This is a model, not a full game simulator. Unknown future BUY items are never generated.
function Planner.globalMultiplier(q)
    local s=__slctx.Core.clean(q and q.info):lower()
    local m=q and (q.multiplier or __slctx.Core.multiplier(s))
    if not m or m<=1 or m==math.huge then return nil end
    if s:find('global speed',1,true) or s:find('global cash',1,true) or s:find('global income',1,true)
        or s:find('global profit',1,true) or s:find('all income',1,true) then return m end
    return nil
end
local function macroPow(q,n)
    local x=math.log(q)/math.log(10)*n;local e=math.floor(x)
    return __slctx.Core.BN.new(10^(x-e),e)
end
function Planner.burstCost(price,ratio,n)
    local B=__slctx.Core.BN
    if not price or n<1 then return nil end
    if n==1 then return price end
    if not ratio or ratio<1 then return nil end
    if math.abs(ratio-1)<1e-8 then return B.mul(price,n) end
    return B.mul(price,B.div(B.sub(macroPow(ratio,n),B.new(1)),ratio-1))
end
function Planner.macroPlan(cards,amount,rate,q,models,priceModels,timing,config,eligible)
    local B=__slctx.Core.BN;local H=math.max(5,config.PlanningHorizonSeconds or 60)
    if not amount or not rate or rate.m<=0 then return {known=false,why='income unavailable'} end
    local raw,n,total=Planner.sumRates(cards)
    if total==0 then return {known=false,why='no source quotes'} end
    local inventoryComplete=raw~=nil and n==total
    local scale=inventoryComplete and B.div(rate,raw) or B.new(1)
    if not inventoryComplete and raw and B.cmp(raw,rate)>0 then scale=B.div(rate,raw) end
    local rows={};local covered=0;local wanted=0
    for _,c in ipairs(cards) do
        if not eligible or eligible[c.path] then
            wanted=wanted+1
            local count,units=__slctx.Core.count(c.count),__slctx.Core.count(c.stack)
            local sr=Planner.sourceRate(c)
            if c.cost and count and count>0 and units and units>0 and sr then
                local pm=priceModels and priceModels[c.path]
                local ratio=pm and pm.samples>=2 and pm.toCount==count and pm.batch==units
                    and pm.name==c.name and pm.ratio or nil
                local model=models and models[c.path]
                local elasticity=model and model.elasticity or 1
                rows[c.path]={path=c.path,name=c.name,cost=c.cost,count=count,units=units,
                    rate=B.mul(sr,scale),ratio=ratio,elasticity=math.max(.5,math.min(1.5,elasticity)),maxMode=c.maxMode}
                covered=covered+1
            end
        end
    end
    local root={cash=amount,rate=rate,rows=rows,time=0,tab='upgrade',usedBuy=false,depth=0}
    local function terminal(s)return B.add(s.cash,B.mul(s.rate,H-s.time)) end
    root.score=terminal(root)
    local beam={root};local best=root;local expansions=0
    local upgradeTime=math.max(.01,timing.upgrade or .08)
    local buyTime=math.max(.01,timing.buy or .3)
    local switchTime=math.max(0,timing.switch or 1.2)
    local function copy(s)
        local r={};for k,v in pairs(s)do r[k]=v end
        r.rows={};for k,v in pairs(s.rows)do r.rows[k]=v end
        return r
    end
    local function execute(s,price,latency,action,newRate,newRows)
        local wait=__slctx.Core.eta(s.cash,price,s.rate)
        if not wait or wait==math.huge or wait>(config.PlanningMaxLocalWaitSeconds or 4) then return nil end
        local dt=wait+latency
        if s.time+dt>=H then return nil end
        local v=copy(s)
        v.cash=B.sub(B.add(s.cash,B.mul(s.rate,dt)),price)
        v.time=s.time+dt;v.rate=newRate;v.rows=newRows or v.rows;v.depth=s.depth+1
        v.first=s.first or action;v.tab=action.kind
        v.score=terminal(v);expansions=expansions+1
        return v
    end
    for _=1,config.PlanningDepth or 4 do
        local nextBeam={}
        for _,s in ipairs(beam) do
            for path,row in pairs(s.rows) do
                if not row.exhausted then
                    for _,clicks in ipairs({1,4,16,64}) do
                        if clicks==1 or row.ratio and not row.maxMode then
                            local price=Planner.burstCost(row.cost,row.ratio,clicks)
                            local relative=(1+row.units*clicks/row.count)^row.elasticity-1
                            local delta=B.mul(row.rate,relative)
                            local latency=clicks*upgradeTime+(s.tab~='upgrade' and switchTime or 0)
                            if price then
                                local act={kind='upgrade',path=path,name=row.name,clicks=clicks,delta=delta,
                                    estimatedPrice=price,quality=row.ratio and 'observed local price slope' or 'single observed quote'}
                                local v=execute(s,price,latency,act,B.add(s.rate,delta))
                                if v then
                                    local nextRow={};for k,val in pairs(row)do nextRow[k]=val end
                                    nextRow.count=row.count+row.units*clicks;nextRow.rate=B.add(row.rate,delta)
                                    nextRow.cost=row.ratio and B.mul(row.cost,macroPow(row.ratio,clicks)) or row.cost
                                    nextRow.exhausted=row.maxMode or not row.ratio
                                    v.rows[path]=nextRow;nextBeam[#nextBeam+1]=v
                                    if B.cmp(v.score,best.score)>0 then best=v end
                                end
                            end
                        end
                    end
                end
            end
            local mult=not s.usedBuy and Planner.globalMultiplier(q)
            if mult and q.cost then
                local action={kind='buy',id=q.id,name=q.name,multiplier=mult,
                    quality='declared global GUI multiplier; next BUY unknown'}
                local newRows={}
                for path,row in pairs(s.rows)do
                    local nr={};for k,v in pairs(row)do nr[k]=v end
                    nr.rate=B.mul(row.rate,mult);newRows[path]=nr
                end
                local v=execute(s,q.cost,buyTime+(s.tab~='buy' and switchTime or 0),action,B.mul(s.rate,mult),newRows)
                if v then
                    v.usedBuy=true;nextBeam[#nextBeam+1]=v
                    if B.cmp(v.score,best.score)>0 then best=v end
                end
            end
        end
        if #nextBeam==0 then break end
        table.sort(nextBeam,function(a,b)
            local cmp=B.cmp(a.score,b.score)
            if cmp==0 then return a.time<b.time end
            return cmp>0
        end)
        beam={};for i=1,math.min(config.PlanningBeamWidth or 5,#nextBeam)do beam[i]=nextBeam[i] end
    end
    local ratio=B.number(B.div(best.score,root.score)) or 1
    return {known=true,complete=inventoryComplete and covered==wanted,first=best.first,horizon=H,expansions=expansions,
        balanceScore=best.score,baselineScore=root.score,improvement=ratio-1,
        terminalRate=best.rate,terminalTime=best.time,depth=best.depth,why=best.first and 'bounded rollout' or 'hold beats modeled purchases'}
end
function Planner.logNetGain(inv,spend)
    local B=__slctx.Core.BN
    if not inv or not inv.investors or not inv.reward or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    local after=B.sub(B.add(inv.investors,inv.reward),spend or B.new(0))
    return (B.log(B.add(B.new(1),B.mul(after,inv.perInvestor)))
        -B.log(B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))))*math.log(10)
end
local function macroLogAdd(a,b)
    if a<b then a,b=b,a end
    if b==-math.huge then return a end
    return a+math.log(1+math.exp(b-a))
end
function Planner.continuationLogOutput(horizon,growth,observedSpan)
    -- Extrapolate growth for no longer than its observed span, then hold output flat.
    -- This avoids assuming exponential growth lasts indefinitely.
    local s=math.min(horizon,math.max(0,observedSpan or 0));local g=math.max(0,growth or 0)
    if g<=1e-10 or s<=0 then return math.log(horizon) end
    local x=g*s
    local a=x>40 and x-math.log(g) or math.log((math.exp(x)-1)/g)
    local b=horizon>s and x+math.log(horizon-s) or -math.huge
    return macroLogAdd(a,b)
end

-- MACRO_PLANNER_END

-- OBJECTIVE_PLANNER_28_BEGIN
-- All counterfactuals are explicitly model estimates. Only adapters authorize actions.
function Planner.bnFromLog(x)
    if not x or x~=x or x==math.huge or x==-math.huge then return nil end
    local e=math.floor(x);return __slctx.Core.BN.new(10^(x-e),e)
end
function Planner.growthEstimate(samples,time,maxAge)
    local B=__slctx.Core.BN;local rows={}
    for _,s in ipairs(samples or {}) do
        if time-s.time<= (maxAge or 20) and s.rate and s.rate.m>0 then rows[#rows+1]=s end
    end
    if #rows<3 or time-rows[#rows].time>3 then return nil,0 end
    local last=rows[#rows];local first=rows[1]
    -- Never interpret switching estimator (cash flow vs UI) as economic growth.
    local same={};for _,s in ipairs(rows)do if s.kind==last.kind then same[#same+1]=s end end
    if #same<3 then return nil,0 end
    first=same[1];local dt=last.time-first.time
    if dt<2 then return nil,0 end
    -- Consecutive flat observations represent a wall, not continuing an old milestone spike.
    local tail=same[#same-2]
    if last.time-tail.time>=2 and math.abs(B.log(last.rate)-B.log(tail.rate))<0.005 then return 0,last.time-tail.time end
    return math.max(0,(B.log(last.rate)-B.log(first.rate))*math.log(10)/dt),dt
end
function Planner.fitRewardCurve(samples)
    -- Locally fit pending reward versus observed produced cash, NOT balance or percent.
    -- A missing financial segment, insufficient range or inconsistent fit invalidates it.
    local B=__slctx.Core.BN;if not samples or #samples<3 then return nil,'need three reward/output observations' end
    local rows={};local last=samples[#samples]
    for i=math.max(1,#samples-7),#samples do
        local s=samples[i]
        if s.segment==last.segment and s.earned and s.earned.m>0 and s.reward and s.reward.m>0 then
            rows[#rows+1]={x=B.log(s.earned),y=B.log(s.reward),time=s.time}
        end
    end
    if #rows<3 or rows[#rows].time-rows[1].time<2 then return nil,'insufficient aligned observations' end
    local sx,sy=0,0;local xmin,xmax=math.huge,-math.huge
    for _,p in ipairs(rows)do sx=sx+p.x;sy=sy+p.y;xmin=math.min(xmin,p.x);xmax=math.max(xmax,p.x) end
    if xmax-xmin<0.4 then return nil,'produced-cash range too small' end
    local mx,my=sx/#rows,sy/#rows;local xx,xy=0,0
    for _,p in ipairs(rows)do xx=xx+(p.x-mx)^2;xy=xy+(p.x-mx)*(p.y-my) end
    if xx<=0 then return nil,'degenerate fit' end
    local alpha=xy/xx;local intercept=my-alpha*mx
    if alpha<0.10 or alpha>2 then return nil,'unreliable empirical elasticity' end
    local residual=0
    for _,p in ipairs(rows)do residual=math.max(residual,math.abs(p.y-intercept-alpha*p.x)) end
    if residual>0.10 then return nil,'reward/output relationship changed' end
    return {alpha=alpha,intercept=intercept,xmin=xmin,xmax=xmax,error=residual,
        segment=last.segment,samples=#rows,time=last.time,quality='local reward/produced-cash fit, not game formula'}
end
function Planner.goalProduction(curve,reward,config)
    local B=__slctx.Core.BN
    if not reward then return nil end
    if reward.m==0 then return B.new(0) end
    if not curve then return nil end
    local x=(B.log(reward)-curve.intercept)/curve.alpha
    local distance=math.max(0,curve.xmin-x,x-curve.xmax)
    if distance>(config.RewardCurveExtrapolationDecades or 3) then return nil end
    -- Upper fitted requirement; uncertainty is charged to the proposed route.
    return Planner.bnFromLog(x),distance
end
function Planner.productionETA(needed,rate,growth,span)
    local B=__slctx.Core.BN
    if not needed then return nil end
    if needed.m==0 then return 0 end
    if not rate or rate.m<=0 then return math.huge end
    local unit=B.number(B.div(needed,rate));local g=math.max(0,growth or 0);local s=math.max(0,span or 0)
    if g<1e-9 or s<=0 then return unit end
    local logNeed=B.log(needed)-B.log(rate)
    local x=logNeed*math.log(10)+math.log(g)
    local logOne=x>35 and x or math.log(1+math.exp(x))
    local exponentialTime=logOne/g
    if exponentialTime<=s then return exponentialTime end
    local factor=Planner.bnFromLog(g*s/math.log(10))
    if not factor then return math.huge end
    local during=B.div(B.mul(rate,B.sub(factor,B.new(1))),g)
    return s+B.number(B.div(B.sub(needed,during),B.mul(rate,factor)))
end
function Planner.replayFrontier(trace,gain,config)
    -- Restore the OBSERVED layout frontier, never use parity time as amplified time.
    -- Segment costs are charged before their output. No unseen future BUY is generated.
    local B=__slctx.Core.BN
    if not trace or not trace.points or #trace.points<2 or not gain or gain.m<=0 then return nil,'frontier trace unavailable' end
    if not trace.complete or trace.invalid then return nil,'partial/inconsistent financial prefix' end
    local points=trace.points;local first=points[1]
    if not first.rate or first.rate.m<=0 then return nil,'missing bootstrap income' end
    local time=first.age;local money=first.cash;local produced=B.new(0)
    local path={{time=time,earned=produced}}
    for i=2,#points do
        local a,b=points[i-1],points[i]
        if not a.rate or not b.rate or b.service<a.service or B.cmp(b.spent,a.spent)<0 then return nil,'trace discontinuity' end
        local price=B.sub(b.spent,a.spent)
        local oldRate=B.mul(a.rate,gain)
        local input=math.max(0.01,b.service-a.service)
        local wait=__slctx.Core.eta(money,price,oldRate)
        if not wait or wait==math.huge then return nil,'unbounded replay wait' end
        local elapsed=wait+input
        local earn=B.mul(oldRate,elapsed)
        money=B.sub(B.add(money,earn),price);produced=B.add(produced,earn);time=time+elapsed
        path[#path+1]={time=time,earned=produced}
        if time>(config.MaximumReplaySeconds or 86400) then return nil,'replay exceeds bounded planning interval' end
    end
    return {seconds=time,finalRate=B.mul(points[#points].rate,gain),produced=produced,path=path,
        quality='same-evolution observed-frontier replay; quoted cost/income invariance assumption',
        bootstrap=first.age,samples=#points,confidence=0.8}
end
function Planner.goalResetComparison(context,restore,config)
    local B=__slctx.Core.BN;local curve=context.rewardCurve
    if not curve or not context.target or not context.inv or not context.earned then return nil end
    local inv=context.inv;local spent=context.historicalSpent or B.new(0)
    local neededReward=B.sub(context.target,B.add(inv.investors,spent))
    local before=Planner.goalProduction(curve,neededReward,config)
    local afterBank=B.sub(B.add(inv.investors,inv.reward),context.plannedSpend or B.new(0))
    local afterSpent=B.add(spent,context.plannedSpend or B.new(0))
    local after=Planner.goalProduction(curve,B.sub(context.target,B.add(afterBank,afterSpent)),config)
    if not before or not after then return nil end
    local continueETA=Planner.productionETA(B.sub(before,context.earned),context.rate,
        context.futureGrowthSpeed,math.min(context.growthObservationSeconds or 0,config.GoalForecastGrowthSeconds or 15))
    local setup=context.setupSeconds or 0
    local resetETA=setup+restore.seconds+Planner.productionETA(B.sub(after,restore.produced),restore.finalRate,0,0)
    if restore.path then
        for _,p in ipairs(restore.path)do
            if B.cmp(p.earned,after)>=0 then resetETA=setup+p.time;break end
        end
    end
    return {continueETA=continueETA,resetETA=resetETA,target=context.target,mode='next-evolution ETA',
        curveSamples=curve.samples,curveError=curve.error,restore=restore.seconds,
        uncertainty='local fitted reward curve; bounded extrapolation; live evolution gate remains authoritative'}
end
function Planner.productivityReset(inv,config,context,cost,spend)
    local B=__slctx.Core.BN;local gain=Planner.netInvestorGain(inv,spend)
    local logGain=Planner.logNetGain(inv,spend)
    if not logGain or logGain<=0 then return false,{why='nonpositive net income gain'} end
    local factor=Planner.bnFromLog(logGain/math.log(10))
    local restore=context.restoreModel
    local modeled=restore~=nil
    if not restore then
        -- Bootstrap scenario: measured input workload plus an explicit full-layout allowance.
        -- This cost is NOT borrowed from an economic-parity sample.
        local seconds=math.max(config.InitialFullLayoutSeconds or 150,context.fullLayoutInputSeconds or 0)
        local discounted=Planner.bnFromLog(logGain*(config.UnobservedResetGainConfidence or .6)/math.log(10))
        restore={seconds=seconds,finalRate=context.rate and B.mul(context.rate,discounted),produced=B.new(0),
            quality='unmeasured full-layout bootstrap scenario; gain discounted',confidence=.4}
    end
    local setup=context.setupSeconds or math.max(0,cost-(context.rebuildSeconds or 60))
    local fullCost=setup+restore.seconds
    local detail={cost=fullCost,cycle=fullCost,restoreQuality=restore.quality,frontierMeasured=modeled,
        netLogGain=logGain,parityTimeNeverAmplified=true}
    local goal=modeled and Planner.goalResetComparison(context,restore,config) or nil
    if goal and goal.continueETA and goal.resetETA and goal.continueETA<math.huge and goal.resetETA<math.huge then
        detail.goal=goal;detail.why='target route comparison'
        local margin=math.max(config.GoalAdvantageSeconds or 3,goal.continueETA*(config.ResetDecisionMargin or .08))
        return goal.resetETA+margin<goal.continueETA,detail
    end
    -- Even when the full target model is not calibrated, don't discard a close measured goal.
    if context.directGoalETA and context.directGoalETA<math.huge and context.directGoalETA<=fullCost then
        detail.why='next evolution closer than another full rebuild';detail.directGoalETA=context.directGoalETA
        return false,detail
    end
    local growth=context.futureGrowthSpeed
    if growth==nil then detail.why='future growth unobserved';return false,detail end
    local H=math.max(config.ResetEvaluationHorizonSeconds or 120,fullCost*2)
    local span=math.min(H,context.growthObservationSeconds or 20,config.GoalForecastGrowthSeconds or 15)
    local cont=Planner.continuationLogOutput(H,growth,span)
    local appliedLog=logGain
    if modeled and context.rate and restore.finalRate then
        appliedLog=(B.log(restore.finalRate)-B.log(context.rate))*math.log(10)
    elseif not modeled then appliedLog=logGain*(config.UnobservedResetGainConfidence or .6) end
    local reset=appliedLog+math.log(math.max(.001,H-fullCost))
    local margin=math.log(1+(config.ResetDecisionMargin or .08))
    detail.horizon=H;detail.continueLogOutput=cont;detail.resetLogOutput=reset;detail.logAdvantage=reset-cont
    detail.growthSpeed=growth;detail.growthSpan=span;detail.why='full-frontier fallback; next-target model not calibrated'
    return reset>cont+margin and appliedLog>growth*span+margin,detail
end
-- CONSTRUCTION_PLANNER_282_BEGIN
function Planner.observedBlockReset(inv,config,context)
    local B=__slctx.Core.BN
    if context.recoveryPending then return false,'REBUILD_BEFORE_NEXT_REBIRTH' end
    if context.endReached then return false,'HALO_TAKES_PRIORITY' end
    if context.protectedMajor then return false,'PROTECTED_MAJOR_TARGET' end
    local permitted,why=Planner.buildResetPermission(context,nil,false,config)
    if not permitted then return false,why end
    local q=context.buyQuote;local money=context.money;local rate=context.rate
    if not q or not q.cost or not money or not rate or rate.m<=0 then return false,'LOCAL_RESET_DATA_UNAVAILABLE' end
    if B.cmp(money,q.cost)>=0 then return false,'BUILD_CHAIN_FUNDED' end
    local growth=context.futureGrowthSpeed
    if growth==nil then return false,'NEED_FRESH_ECONOMIC_OBSERVATIONS' end
    local replay=context.restoreModel
    local rebuild=replay and replay.seconds or math.max(config.InitialFullLayoutSeconds or 150,
        context.fullLayoutInputSeconds or 0)
    local cost=(context.setupSeconds or 0)+rebuild
    if cost~=cost or cost<0 or cost==math.huge then return false,'REBUILD_COST_UNKNOWN' end
    local discounted=__slctx.HaloPlan.bootstrapGain(inv,context.plannedSpend,config)
    if not discounted then return false,'NO_NET_RESET_GAIN_AFTER_SPENDING' end
    -- Existing cash is retained by continuation, but lost by rebirth. Rebuild
    -- cash is conservatively zero; observed income already includes time boosts.
    local direct=Planner.productionETA(B.sub(q.cost,money),rate,growth,
        math.min(context.growthObservationSeconds or 0,config.GoalForecastGrowthSeconds or 15))
    local after=cost+B.number(B.div(q.cost,B.mul(rate,discounted)))
    if direct~=direct or after~=after or direct==math.huge or after==math.huge then
        return false,'LOCAL_RESET_ETA_UNBOUNDED'
    end
    local detail={cost=cost,direct=B.new(direct),reset=B.new(after),localBridge=true,
        authorization='observed-construction-wall-332',parityTimeNeverAmplified=true,
        restoreQuality=replay and replay.quality or context.rebuildInputSource or 'full-layout input allowance; not measured parity',
        target=q.name,discountedGain=discounted,growthSpeed=growth}
    -- Keep a nearby evolution, and honor a calibrated reward-to-evolution
    -- comparison when it says continuation gets there sooner.
    if context.directGoalETA and context.directGoalETA<=after then
        return false,'EVOLUTION_CLOSER_THAN_LOCAL_RESET',detail
    end
    local evo=replay and Planner.goalResetComparison(context,replay,config)
    if evo and evo.continueETA and evo.resetETA and evo.continueETA<math.huge then
        detail.goal=evo
        if evo.resetETA+math.max(config.GoalAdvantageSeconds or 3,
            evo.continueETA*(config.ResetDecisionMargin or .08))>=evo.continueETA then
            return false,'CONTINUE_TO_EVOLUTION_FASTER',detail
        end
    end
    local yes=after*(1+(config.RouteResetMargin or .25))+(config.GoalAdvantageSeconds or 3)<direct
    if yes then return true,'RESET_SHORTENS_OBSERVED_BLOCK',detail end
    -- A single nearby BUY is not the entire benefit of rebuilding with a much
    -- stronger bank. Only a sustained, measured wall may use the bounded output
    -- comparison. Funded BUY/recovery/debt/near-evolution guards above still apply.
    if context.buildWallSustained then
        local productive,forecast=Planner.productivityReset(inv,config,context,cost,context.plannedSpend)
        if forecast and forecast.continueLogOutput and forecast.resetLogOutput then
            -- Give continuation its already-quoted global boost for the WHOLE
            -- horizon, without charging its cost or wait: an optimistic bound.
            -- Unknown future catalogue items cannot authorize this reset.
            local boost=Planner.globalMultiplier(q) or 1
            local continueOutput=forecast.continueLogOutput+math.log(boost)
            local margin=math.log(1+(config.RouteResetMargin or .25))
            detail.horizon=forecast.horizon;detail.continueLogOutput=continueOutput
            detail.resetLogOutput=forecast.resetLogOutput
            detail.logAdvantage=forecast.resetLogOutput-continueOutput
            detail.continuationBoost=boost;detail.growthSpan=forecast.growthSpan
            detail.outputComparison=true
            if productive and forecast.resetLogOutput>continueOutput+margin then
                return true,'RESET_REPAYS_STALLED_BUILD',detail
            end
        end
    end
    return false,'CONTINUE_CURRENT_BLOCK_FASTER',detail
end
function Planner.buildResetPermission(context,detail,hasPower,config)
    -- Unknown future catalog items never become a fabricated completion ETA.
    if not context.buildQuoteKnown then return false,'BUILD_QUOTE_NOT_VERIFIED' end
    local goal=detail and detail.goal
    if goal and type(goal.continueETA)=='number' and goal.continueETA==goal.continueETA
        and type(goal.resetETA)=='number' and goal.resetETA==goal.resetETA
        and goal.continueETA>0 and goal.continueETA<math.huge and goal.resetETA>=0
        and goal.resetETA<math.huge then
        local margin=math.max(config.GoalAdvantageSeconds or 3,goal.continueETA*(config.ResetDecisionMargin or .08))
        if goal.resetETA+margin<goal.continueETA then return true,'target ETA' end
        return false,'CONTINUE_TO_EVOLUTION_FASTER'
    end
    -- Having enough investors for Stack is NOT proof that resetting to buy it helps.
    local saved=detail and detail.saved
    if hasPower and saved and saved==saved and saved>0 and saved<math.huge
        and detail.cost and saved>detail.cost*(1+(config.ResetDecisionMargin or .08))
        and not detail.directGoalETA then return true,'measured Stack input savings' end
    if context.buyFunded then return false,'BUILD_CHAIN_FUNDED' end
    if context.buildSoon then return false,'BUILD_TARGET_SOON' end
    -- Ordinary income fallback is legal only AFTER a complete, current stand pass
    -- against the same actually unaffordable next BUY. Quick MAX passes are not walls.
    if not context.buildWallReady then return false,'FINISH_BUILD_BEFORE_INCOME_RESET' end
    -- Do not repeatedly call restored income "new construction". A sustained,
    -- observed funding wall can release this lock; never an elapsed timer alone.
    if context.buildDebt and not context.buildWallSustained then return false,'RESTORE_BUILD_PROGRESS_FIRST' end
    return true,'confirmed construction wall'
end
-- CONSTRUCTION_PLANNER_282_END
function Planner.rebirthDecision(inv,config,context)
    context=context or {};local B=__slctx.Core.BN;local p=context.pass
    if not inv or not inv.investors or not inv.reward then return false,'INVESTORS_UNKNOWN' end
    if not inv.ready then return false,'REBIRTH_BUTTON_LOCKED' end
    if inv.reward.m==0 then return false,'NO_REBIRTH_REWARD' end
    local gain=Planner.netInvestorGain(inv,context.plannedSpend)
    if context.protectedMajor then return false,'PROTECTED_MAJOR_TARGET',gain end
    if context.endReached then return false,'HALO_TAKES_PRIORITY',gain end
    if not context.capabilityOnly and (not p or not p.finished or not p.complete) then return false,'PASS_NOT_FINISHED',gain end
    if not context.buildQuoteKnown then return false,'BUILD_QUOTE_NOT_VERIFIED',gain end
    if inv.investors.m==0 and not context.capabilityOnly then
        -- First-bank bootstrap retains its original reserve check, but not a funded BUY interruption.
        if context.buyFunded then return false,'BUILD_CHAIN_FUNDED',gain end
        return B.cmp(inv.reward,B.new(config.TabletReserve))>=0,'FIRST_REBIRTH_RESERVE',gain
    end
    local g=context.powerGoal
    if g and g.canBuyNow and g.nextBatch then return false,'POWER_BUY_WITHOUT_RESET',gain end
    if context.recoveryPending then return false,'REBUILD_BEFORE_NEXT_REBIRTH',gain end
    if not gain or gain<=1 then return false,'NO_NET_RESET_GAIN_AFTER_SPENDING',gain end
    local yes,detail=Planner.productivityReset(inv,config,context,context.cycle or 155,context.plannedSpend)
    local hasPower=g and g.canBuyAfter and g.nextBatch and g.currentBatch~='max'
        and config.CapabilityRebirth~=false and config.AutoInvestorPowers~=false
    -- Calculate actual input savings even when the income fallback voted yes.
    -- Otherwise any affordable Stack would turn an ordinary reset into an exception.
    if hasPower then
        local old=Planner.workClicks(context.work,g.currentBatch);local new=Planner.workClicks(context.work,g.nextBatch)
        local saved=old and new and math.max(0,old-new)*(context.actionSeconds or .08)*(config.PowerSavingsConfidence or .6)
        detail.saved=saved
        if not yes and not detail.goal and not detail.directGoalETA and saved and saved<math.huge
            and detail.cost and saved>detail.cost*(1+(config.ResetDecisionMargin or .08)) then yes=true end
    end
    if yes then
        local allowed,permission=Planner.buildResetPermission(context,detail,hasPower,config)
        detail.authorization=permission
        if not allowed then return false,permission,gain,detail end
        return true,hasPower and 'RESET_FOR_UPGRADE_STACK' or 'RESET_FOR_NET_PRODUCTION',gain,detail
    end
    if detail.goal then return false,'CONTINUE_TO_EVOLUTION_FASTER',gain,detail end
    if detail.directGoalETA then return false,'EVOLUTION_CLOSER_THAN_REBUILD',gain,detail end
    if context.buyFunded then return false,'BUILD_CHAIN_FUNDED',gain,detail end
    if context.buildSoon then return false,'BUILD_TARGET_SOON',gain,detail end
    if detail.why=='future growth unobserved' then return false,'NEED_FRESH_ECONOMIC_OBSERVATIONS',gain,detail end
    return false,'CONTINUATION_MODEL_WINS',gain,detail
end
function Planner.powerRelevant(item,config)
    if not item then return false,'missing power' end
    if item.name=='UpgradeStack' then return true,'stand throughput' end
    local allowed=config.OptionalPowerAllowlist or {}
    if allowed[item.name]==true then return true,'explicit optional-power allowlist' end
    return false,'no demonstrated contribution to this stationary Halo route'
end
-- RESET_INTENT_PLANNER_281_BEGIN
function Planner.validateResetIntent(intent,state,config)
    local B=__slctx.Core.BN;local old=intent and intent.state
    if not old or not state then return false,'RESET_INTENT_MISSING' end
    if state.time<intent.at or state.time>intent.expiresAt then return false,'RESET_INTENT_EXPIRED' end
    if state.unresolved then return false,'UNRESOLVED_PURCHASE' end
    if state.evoReady and not (intent.preferRebirthToEvolution33 and old.evoReady and old.evolution==state.evolution) then return false,'EVOLUTION_TAKES_PRIORITY' end
    if state.endReached then return false,'HALO_TAKES_PRIORITY' end
    if state.recovery then return false,'REBUILD_BEFORE_NEXT_REBIRTH' end
    if not state.ready then return false,'REBIRTH_BUTTON_LOCKED' end
    if not state.bank or not state.reward or state.reward.m<=0 then return false,'INVESTORS_UNKNOWN' end
    if not state.invTime or state.time-state.invTime>config.ResetIntentSeconds or state.invTime>state.time then
        return false,'RESET_INVESTORS_STALE'
    end
    for _,key in ipairs({'epoch','evolution','halo','revision','receipts','policy','flowSegment','pass','passIndex','capabilityOnly','batch','buyId'}) do
        if state[key]~=old[key] then return false,'RESET_STATE_CHANGED_'..key:upper() end
    end
    local function same(a,b)return a==nil and b==nil or a~=nil and b~=nil and B.cmp(a,b)==0 end
    for _,key in ipairs({'bank','gross','used','spent'}) do
        if not same(state[key],old[key]) then return false,'RESET_STATE_CHANGED_'..key:upper() end
    end
    if state.perInvestor~=old.perInvestor then return false,'RESET_STATE_CHANGED_INVESTOR_BONUS' end
    -- Rounded potential can move by its final digit; a materially smaller reward cannot reuse the plan.
    if B.cmp(state.reward,B.mul(old.reward,.999))<0 then return false,'RESET_REWARD_DECREASED' end
    if old.cash and (not state.cash or B.cmp(state.cash,B.mul(old.cash,.999))<0) then return false,'RESET_CASH_DECREASED' end
    local a,b=old.goal,state.goal
    if (a~=nil)~=(b~=nil) then return false,'RESET_POWER_QUOTE_CHANGED' end
    if a then
        if a.path~=b.path or a.name~=b.name or a.bonus~=b.bonus or not same(a.price,b.price)
            or a.currentBatch~=b.currentBatch or a.nextBatch~=b.nextBatch then return false,'RESET_POWER_QUOTE_CHANGED' end
        if intent.spend and intent.spend.m>0 then
            if not b.canBuyAfter or not state.gross then return false,'RESET_POWER_BUDGET_CHANGED' end
            local allowed=Planner.powerBudgetAllows(intent.spend,B.add(state.bank,state.reward),state.used,
                B.add(state.gross,state.reward),config)
            if not allowed then return false,'RESET_POWER_BUDGET_CHANGED' end
        end
    end
    if old.bank.m==0 then
        if B.cmp(state.reward,B.new(config.TabletReserve))<0 then return false,'FIRST_REBIRTH_RESERVE' end
    else
        local gain=Planner.netInvestorGain({investors=state.bank,reward=state.reward,perInvestor=state.perInvestor},intent.spend)
        if not gain or gain<=1 then return false,'NO_NET_RESET_GAIN_AFTER_SPENDING' end
    end
    return true,'UNCHANGED_RESET_INTENT'
end
-- RESET_INTENT_PLANNER_281_END

-- OBJECTIVE_PLANNER_28_END

-- CYCLE_PLANNER_END

return Planner

-- PLANNER_END
end)()

end
