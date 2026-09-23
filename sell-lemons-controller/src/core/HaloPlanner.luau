-- Component initialized with an explicit shared service context.
return function(__slctx)
-- HALO_PLANNER_30_BEGIN
-- Full catalogue completion is the objective. All forecasts are MODEL estimates.
-- The wiki supplies neither the unlock graph nor Halo's price formula. Do not invent either.
__slctx.HaloPlan = {}
do
local B=__slctx.Core.BN
local function cp(v)return v and B.new(v.m,v.e)end
local function pow(x)
    if type(x)~='number' or x~=x or math.abs(x)>1e7 then return nil end
    local e=math.floor(x);return B.new(10^(x-e),e)
end
function __slctx.HaloPlan.key(s)
    s=__slctx.Core.clean(s):lower()
    -- A whitelist from the observed evolution names; not arbitrary fuzzy matching.
    for _,v in ipairs({'abyssalime','voidlemon','nullfruit','grapefruit','tangerine','orange','purity','pomelo','lime'})do
        s=s:gsub('%f[%a]'..v,'lemon')
    end
    local k=(s:gsub('%s*%b()',''):gsub('[^%w]',''))
    -- Explicit compatibility alias: provided row says 'Pather Border (2)',
    -- whereas the user's v6916 log says 'Path Border'. Preserve the source row.
    if k=='patherborder' then k='pathborder' end
    return k
end
function __slctx.HaloPlan.effect(info)
    local s=__slctx.Core.clean(info):lower():gsub(',','')
    local mult=__slctx.Core.multiplier(s)
    if not mult or mult<=1 then return nil end
    if s:find('global',1,true) then return {mult=mult,global=true} end
    local target=s:match('[%d%.]+%s*x%s+(.+)%s+cash') or s:match('[%d%.]+%s*x%s+(.+)%s+speed')
        or s:match('x[%d%.]+%s+(.+)%s+cash') or s:match('x[%d%.]+%s+(.+)%s+speed')
    if target then
        local k=__slctx.HaloPlan.key(target)
        local sources={lemonstand=true,lemondash=true,lemondepot=true,lemontrading=true,lemonlabs=true,lemonrobotics=true,lemonrepublic=true,lemonx=true}
        if sources[k] then return {mult=mult,target=k} end
    end
    return nil -- For example "100,000x Lemon cash" has an unspecified source.
end
function __slctx.HaloPlan.index(rows)
    local out={}
    for _,r in ipairs(rows)do
        r.key=__slctx.HaloPlan.key(r.name);r.effect=__slctx.HaloPlan.effect(r.info)
        out[r.key]=out[r.key] or {};out[r.key][#out[r.key]+1]=r
    end
    return out
end
function __slctx.HaloPlan.newBook(halo,evolution,complete)
    return {version=30,halo=halo,evolution=evolution,complete=complete==true,bought={},anchors={},byAnchor={},
        receipts={},revision=0,scaleRevision=0,unknown={},orderChecks=0,orderMisses=0}
end
function __slctx.HaloPlan.fitScale(anchors,config)
    if #anchors<(config.CatalogueMinimumAnchors or 5) then return nil,'need independent price anchors' end
    local sx,sy,lo,hi=0,0,math.huge,-math.huge
    for _,a in ipairs(anchors)do sx=sx+a.x;sy=sy+a.y;lo=math.min(lo,a.x);hi=math.max(hi,a.x) end
    local n=#anchors;local mx,my=sx/n,sy/n;local xx,xy=0,0
    for _,a in ipairs(anchors)do xx=xx+(a.x-mx)^2;xy=xy+(a.x-mx)*(a.y-my) end
    if hi-lo<(config.CatalogueMinimumSpan or 8) or xx<=0 then return nil,'price range too narrow' end
    local slope=xy/xx;local intercept=my-slope*mx
    if slope<.25 or slope>8 then return nil,'unsupported cost transform' end
    local residual=0
    for _,a in ipairs(anchors)do residual=math.max(residual,math.abs(a.y-intercept-slope*a.x)) end
    if residual>(config.CatalogueFitError or .025) then return nil,'catalogue and live prices disagree' end
    -- Includes table rounding plus an extrapolation uncertainty term. This is an
    -- empirical log-affine fit, not an asserted game formula or confidence proof.
    return {a=intercept,b=slope,error=residual,xmin=lo,xmax=hi,samples=n,
        slopeAllowance=math.max(.00002,2*residual/(hi-lo)),quality='empirical live-price log-affine fit'}
end
function __slctx.HaloPlan.price(row,model,upper,config)
    if not row or not model then return nil end
    local x=B.log(row.cost);local y=model.a+model.b*x
    if upper then
        local extrap=math.max(0,model.xmin-x,x-model.xmax)
        y=y+math.log(1+(config.CatalogueCostMargin or .15))/math.log(10)+2*model.error+model.slopeAllowance*extrap
    end
    return pow(y)
end
function __slctx.HaloPlan.identify(q,book,index,config)
    if not q or not q.name or not q.cost then return nil,'quote incomplete' end
    local candidates=index[__slctx.HaloPlan.key(q.name)] or {}
    local eligible={}
    for _,row in ipairs(candidates)do if not book.bought[row.id]then eligible[#eligible+1]=row end end
    if #eligible==1 then
        if #candidates==1 then return eligible[1],'unique name' end
        if book.model then
            local expected=__slctx.HaloPlan.price(eligible[1],book.model,false,config)
            if expected and math.abs(B.log(expected)-B.log(q.cost))<=math.max(.025,book.model.error*2+.006) then
                return eligible[1],'last unbought duplicate with matching price'
            end
        end
        return nil,'duplicate price not verified'
    end
    if book.model then
        local best,err,second
        for _,row in ipairs(eligible)do
            local expected=__slctx.HaloPlan.price(row,book.model,false,config)
            local e=expected and math.abs(B.log(expected)-B.log(q.cost)) or math.huge
            if not err or e<err then second=err;best=row;err=e elseif not second or e<second then second=e end
        end
        if best and err<math.max(.025,book.model.error*2+.006) and (not second or second-err>.02) then return best,'price-disambiguated' end
    end
    return nil,#candidates>0 and 'duplicate unresolved' or 'name absent from supplied catalogue'
end
function __slctx.HaloPlan.observe(book,q,index,config)
    local row,why=__slctx.HaloPlan.identify(q,book,index,config)
    if not row then
        book.lastMatchReason=why
        if why=='name absent from supplied catalogue' then book.unknown[__slctx.HaloPlan.key(q and q.name)]=true end
        return nil,why
    end
    book.unknown[__slctx.HaloPlan.key(q.name)]=nil
    local unique=#(index[row.key] or {})==1
    if unique then
        local y=B.log(q.cost);local a=book.byAnchor[row.id]
        if a and math.abs(a.y-y)>.02 then
            book.model=nil;book.anchors={};book.byAnchor={};book.scaleRevision=book.scaleRevision+1
            book.scaleFailure='same item price changed';a=nil
        end
        if not a then
            -- Test an independent incoming anchor BEFORE fitting it.
            local old=book.model
            if old then
                local err=math.abs(y-(old.a+old.b*B.log(row.cost)))
                if err>math.max(.025,old.error*3+.008) then book.scaleFailure='out-of-sample price mismatch' end
            end
            a={id=row.id,x=B.log(row.cost),y=y};book.anchors[#book.anchors+1]=a;book.byAnchor[row.id]=a
            local model,reason=__slctx.HaloPlan.fitScale(book.anchors,config)
            book.model=model;book.modelReason=reason;book.scaleRevision=book.scaleRevision+1
            if model then book.scaleFailure=nil end
        end
    elseif book.model then
        local expected=__slctx.HaloPlan.price(row,book.model,false,config)
        if expected and math.abs(B.log(expected)-B.log(q.cost))>.035 then
            book.scaleFailure='matched item price mismatch';book.model=nil;book.scaleRevision=book.scaleRevision+1
        end
    end
    book.lastMatchReason=why
    return row,why
end

function __slctx.HaloPlan.remaining(rows,book,config)
    local model,verified=__slctx.HaloPlan.priceModel(book,config)
    if not model then return nil,book.modelReason or book.scaleFailure or 'price model not calibrated' end
    local out,sum={},B.new(0)
    local certifiable=next(book.unknown or {})==nil
    for _,r in ipairs(rows)do if not book.bought[r.id]then
        local cost=__slctx.HaloPlan.price(r,model,true,config)
        if not cost then return nil,'invalid transformed price' end
        out[#out+1]={id=r.id,cost=cost,effect=r.effect,name=r.name};sum=B.add(sum,cost)
    end end
    local extras=0
    for _,r in pairs(book.extras or {})do if not book.bought[r.id]then
        local cost
        if r.observedHalo==book.halo then cost=B.mul(r.cost,1+(config.CatalogueCostMargin or .15))
        elseif r.baseCost then cost=__slctx.HaloPlan.price({cost=r.baseCost},model,true,config)end
        if cost then
            out[#out+1]={id=r.id,cost=cost,name=r.name,effect=nil,liveExtra=true}
            sum=B.add(sum,cost);extras=extras+1
        else certifiable=false end
    end end
    table.sort(out,function(a,b)local c=B.cmp(a.cost,b.cost);return c==0 and tostring(a.id)<tostring(b.id) or c<0 end)
    return {rows=out,cost=sum,count=#out,extras=extras,priceQuality=model.quality,model=model,
        modelVerified=verified,certifiable=certifiable,completeLedger=book.complete,
        budgetScope='supplied catalogue plus observed additional purchases; unknown ownership over-counted'}
end
function __slctx.HaloPlan.markBought(book,row,q,remaining)
    if not row or book.bought[row.id]then return false end
    if book.complete and remaining and remaining.rows[1]then
        book.orderChecks=book.orderChecks+1
        if remaining.rows[1].id~=row.id then book.orderMisses=book.orderMisses+1 end
    end
    book.bought[row.id]=true;book.revision=book.revision+1
    return true
end
function __slctx.HaloPlan.frontierRoute(remaining,row,quote)
    if not remaining or not row or not quote or not quote.cost then return remaining end
    local position
    for i,item in ipairs(remaining.rows)do if item.id==row.id then position=i;break end end
    if not position then return remaining end -- The last observed item may already be bought.
    local out=table.clone(remaining);out.rows={}
    local gate=table.clone(remaining.rows[position])
    if B.cmp(quote.cost,gate.cost)>0 then
        out.cost=B.add(B.sub(remaining.cost,gate.cost),quote.cost);gate.cost=cp(quote.cost)
    end
    out.rows[1]=gate;out.frontierId=gate.id
    for i,item in ipairs(remaining.rows)do if i~=position then out.rows[#out.rows+1]=item end end
    return out
end
function __slctx.HaloPlan.sourceModel(cards,totalRate,sourceRate)
    if not totalRate then return nil end
    local sources,sum,complete={},B.new(0),#(cards or {})>0
    for _,c in ipairs(cards or {}) do
        local value=sourceRate(c)
        if not value then complete=false else
            local key=__slctx.HaloPlan.key(c.name);sources[key]=value;sum=B.add(sum,value)
        end
    end
    if sum.m<=0 then return {other=cp(totalRate),sources={},complete=false} end
    if complete or B.cmp(sum,totalRate)>0 then
        local ratio=B.div(totalRate,sum)
        for key,value in pairs(sources) do sources[key]=B.mul(value,ratio) end
        return {other=B.new(0),sources=sources,complete=complete}
    end
    return {other=B.sub(totalRate,sum),sources=sources,complete=false}
end
function __slctx.HaloPlan.roll(remaining,money,rateModel,secondsPerBuy,useEffects,multiplier)
    if not remaining or not money then return nil end
    multiplier=multiplier or B.new(1)
    local other=rateModel and B.mul(rateModel.other,multiplier) or B.new(0);local source={};local rate=cp(other)
    for k,v in pairs(rateModel and rateModel.sources or {})do source[k]=B.mul(v,multiplier);rate=B.add(rate,source[k]) end
    local balance=cp(money);local time,waiting=B.new(0),B.new(0);local service=0
    for _,item in ipairs(remaining.rows)do
        if B.cmp(balance,item.cost)<0 then
            if rate.m<=0 then return nil end
            local wait=B.div(B.sub(item.cost,balance),rate)
            waiting=B.add(waiting,wait);time=B.add(time,wait);balance=cp(item.cost)
        end
        balance=B.sub(balance,item.cost)
        -- Old output during purchase/receipt latency; apply a boost only afterwards.
        local duration=item.serviceSeconds or secondsPerBuy
        balance=B.add(balance,B.mul(rate,duration))
        time=B.add(time,B.new(duration));service=service+duration
        local e=useEffects and item.effect
        if e then
            if e.global then
                other=B.mul(other,e.mult);for k,v in pairs(source)do source[k]=B.mul(v,e.mult) end
            elseif source[e.target] then source[e.target]=B.mul(source[e.target],e.mult) end
            rate=cp(other);for _,v in pairs(source)do rate=B.add(rate,v) end
        end
    end
    return {time=time,wait=waiting,service=service,cash=balance,rate=rate,
        quality=useEffects and (remaining.frontierId and 'observed gate first; later unlock order unknown'
            or 'catalogue price-order scenario; unlock order not guaranteed') or 'constant-income catalogue route'}
end
function __slctx.HaloPlan.passiveBound(remaining,money,rate,actionSeconds)
    if not remaining or not money then return nil end
    local gap=B.sub(remaining.cost,money)
    if gap.m>0 and (not rate or rate.m<=0)then return nil end
    -- Wait for ALL remaining costs first. Valid for any actual unlock order, under
    -- the calibrated price model and sustained observed income. Future buffs ignored.
    local wait=gap.m==0 and B.new(0) or B.div(gap,rate)
    return {time=B.add(wait,B.new(remaining.count*actionSeconds)),wait=wait,service=remaining.count*actionSeconds,
        funded=gap.m==0,quality='all remaining costs funded before construction; no future income boosts assumed'}
end

function __slctx.HaloPlan.finishDecision(book,remaining,bound,roll,config,allCount,actionSeconds)
    if not remaining or not bound then return false,'CATALOGUE_NOT_READY' end
    if remaining.modelVerified==false or remaining.certifiable==false then return false,'PRICE_MODEL_AWAITING_VERIFICATION' end
    if bound.funded then return true,'FINISH_CASH_FUNDED',bound end
    local allowedWait=__slctx.HaloPlan.finishAllowance(allCount,actionSeconds,config)
    if B.cmp(bound.wait,B.new(allowedWait))<=0 then return true,'FINISH_PASSIVE_BUDGET',bound end
    if config.AllowConditionalFinish==true and book.complete and book.orderChecks>=24 and book.orderMisses==0
        and roll and B.cmp(roll.wait,B.new(allowedWait*.5))<=0 then return true,'FINISH_CONDITIONAL_CATALOGUE_ROUTE',roll end
    return false,'PREPARE_MORE_CAPITAL',bound
end
function __slctx.HaloPlan.finishHealth(commit,time,remainingForecast,money,nextCost,rate,config)
    if not commit then return false,'FINISH_COMMIT_MISSING' end
    -- Cash can complete the route even when a rate sample is temporarily absent.
    if remainingForecast and remainingForecast.funded then return true end
    local left=(commit.deadline or commit.at)-time
    if left<=0 then return false,'FINISH_DEADLINE_EXCEEDED' end
    if remainingForecast and B.cmp(remainingForecast.time,B.new(left))>0 then
        return false,'FINISH_REMAINING_TIME_EXCEEDED'
    end
    if money and nextCost and B.cmp(money,nextCost)<0 then
        if not rate or rate.m<=0 then
            commit.missingRateSince=commit.missingRateSince or time
            if time-commit.missingRateSince>=(config.HaloFinishGraceSeconds or 4) then
                return false,'FINISH_INCOME_UNAVAILABLE'
            end
        else
            commit.missingRateSince=nil
            -- Use the actual current gate. A bonus behind it cannot pay this gap.
            local wait=B.div(B.sub(nextCost,money),rate)
            if B.cmp(wait,B.new(left))>0 then return false,'FINISH_NEXT_GATE_EXCEEDS_BUDGET' end
        end
    end
    return true
end
function __slctx.HaloPlan.replay(trace,gain,config)
    if not trace or not trace.complete or trace.invalid or not trace.points or #trace.points<2 then return nil end
    local B=__slctx.Core.BN;local first=trace.points[1]
    if not first.rate or first.rate.m<=0 then return nil end
    local time=B.new(math.max(0,first.age));local cash=cp(first.cash or B.new(0))
    for i=2,#trace.points do
        local a,b=trace.points[i-1],trace.points[i]
        if not a.rate or b.service<a.service or B.cmp(b.spent,a.spent)<0 then return nil end
        local rate=B.mul(a.rate,gain);local cost=B.sub(b.spent,a.spent)
        if B.cmp(cash,cost)<0 then
            if rate.m<=0 then return nil end
            local wait=B.div(B.sub(cost,cash),rate);time=B.add(time,wait);cash=cp(cost)
        end
        cash=B.sub(cash,cost)
        local service=math.max(.01,b.service-a.service)
        cash=B.add(cash,B.mul(rate,service));time=B.add(time,B.new(service))
    end
    return {time=time,cash=cash,quality='same-epoch observed prefix replay; income scaling is an assumption'}
end
function __slctx.HaloPlan.resetComparison(direct,after,setup,replay,config)
    if not direct or not after or not replay then return false,'NO_COMPARABLE_FINISH_FORECAST' end
    local t=B.add(B.add(B.new(setup),replay.time),after.time)
    local margin=math.max(0,config.RouteResetMargin or .25)
    local tested=B.add(B.mul(t,1+margin),B.new(config.GoalAdvantageSeconds or 3))
    local yes=B.cmp(tested,direct.time)<0
    return yes,yes and 'RESET_SHORTENS_CATALOGUE_ROUTE' or 'FINISH_WITHOUT_RESET_FASTER',
        {direct=direct.time,reset=t,replay=replay.time,setup=setup,quality=after.quality,margin=margin}
end
function __slctx.HaloPlan.requiredBank(remaining,money,rate,inv,seconds)
    if not remaining or not money or not rate or rate.m<=0 or not inv or not inv.investors or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    local requiredRate=B.div(B.sub(remaining.cost,money),math.max(1,seconds))
    local factor=B.div(requiredRate,rate)
    if B.cmp(factor,B.new(1))<=0 then return cp(inv.investors) end
    return B.div(B.sub(B.mul(B.add(B.new(1),B.mul(inv.investors,inv.perInvestor)),factor),B.new(1)),inv.perInvestor)
end


-- ECONOMIC_READINESS_32_BEGIN
function __slctx.HaloPlan.haloFactor(halo,config)
    if type(halo)~='number' or halo<0 or halo%1~=0 then return nil end
    local base=config.HaloPriceBase or 3.33
    if type(base)~='number' or base<=0 then return nil end
    return pow(halo*math.log(base)/math.log(10))
end
function __slctx.HaloPlan.priceModel(book,config)
    local factor=__slctx.HaloPlan.haloFactor(book.halo,config)
    local expected=factor and B.log(factor)
    local anchors=book.anchors or {};local error=0
    if #anchors<(config.HaloPriceMinimumAnchors or 3) and book.model and not book.scaleFailure then return book.model,true end
    if expected then
        for _,a in ipairs(anchors)do error=math.max(error,math.abs(a.y-a.x-expected))end
        if error<=(config.HaloPriceLogTolerance or .003) then
            local verified=#anchors>=(config.HaloPriceMinimumAnchors or 3)
            local model={a=expected,b=1,error=math.max(error,.0002),xmin=0,xmax=1e7,slopeAllowance=0,
                samples=#anchors,formula=true,formulaBase=config.HaloPriceBase or 3.33,
                verified=verified,halo=book.halo,
                quality=verified and 'C0*3.33^Halo; matched independent live prices'
                    or 'C0*3.33^Halo prior inferred from supplied H21/H22 logs; awaiting live checks'}
            return model,verified
        end
    end
    if book.model and not book.scaleFailure then
        -- The fitted alternative is retained when this game version does not match the prior.
        return book.model,true
    end
    return nil,false
end
function __slctx.HaloPlan.quoteExtraKey(q)
    if not q or not q.cost then return nil end
    return tostring(q.id or (__slctx.HaloPlan.key(q.name)..':'..B.format(q.cost)))
end
function __slctx.HaloPlan.observeExtra(book,q,config)
    local token=__slctx.HaloPlan.quoteExtraKey(q);if not token then return nil end
    book.extras=book.extras or {}
    local row=book.extras[token]
    local model,verified=__slctx.HaloPlan.priceModel(book,config)
    if not row and model and verified then
        local found,ambiguous
        for _,candidate in pairs(book.extras)do
            if not candidate.observedHere and not book.bought[candidate.id] and candidate.key==__slctx.HaloPlan.key(q.name) then
                local expected=candidate.observedHalo==book.halo and candidate.cost
                    or (candidate.baseCost and __slctx.HaloPlan.price({cost=candidate.baseCost},model,false,config))
                if expected and math.abs(B.log(expected)-B.log(q.cost))<=.003 then
                    if found then ambiguous=true end;found=candidate
                end
            end
        end
        if found and not ambiguous then
            row=found;row.cost=cp(q.cost);row.observedHalo=book.halo;row.observedHere=true
            book.revision=(book.revision or 0)+1
        end
    end
    if not row then
        local base=model and verified and pow((B.log(q.cost)-model.a)/model.b) or nil
        row={id='live:'..token,token=token,name=q.name,key=__slctx.HaloPlan.key(q.name),cost=cp(q.cost),
            observedHalo=book.halo,baseCost=base,liveExtra=true,observedHere=true,
            info=q.info or '',effect=nil}
        book.extras[token]=row;book.revision=(book.revision or 0)+1
    end
    -- Record a priced observation; do not guess that Office Desk is an alias of Office.
    book.unknown[__slctx.HaloPlan.key(q.name)]=nil
    return row
end
function __slctx.HaloPlan.copyExtras(old,new,config)
    new.extras={}
    for token,row in pairs(old.extras or {})do
        local base=row.baseCost
        if not base then
            local model,verified=__slctx.HaloPlan.priceModel(old,config)
            if model and verified and row.observedHalo==old.halo then base=pow((B.log(row.cost)-model.a)/model.b)end
        end
        if row.observedHalo==new.halo or base then
            new.extras[token]={id=row.id,token=token,name=row.name,key=row.key,cost=cp(row.cost),
                baseCost=cp(base),observedHalo=row.observedHalo,liveExtra=true,observedHere=false,info=row.info,effect=nil}
        end
    end
end
function __slctx.HaloPlan.finishAllowance(allCount,actionSeconds,config)
    local input=math.max(1,(allCount or 0)*math.max(.001,actionSeconds or .3))
    return math.min(config.FinishMaximumWaitSeconds or 60,
        math.max(config.FinishMinimumWaitSeconds or 8,input*(config.FinishWaitFraction or .35)))
end
function __slctx.HaloPlan.readiness(remaining,money,safeRate,waitSeconds,config)
    local v={known=remaining~=nil and money~=nil,rateKnown=safeRate~=nil,waitSeconds=waitSeconds,
        margin=config.CatalogueIncomeMargin or .75}
    if not v.known then return v end
    v.cost=remaining.cost;v.money=cp(money);v.gap=B.sub(v.cost,money)
    v.cashFunded=v.gap.m==0
    v.safeRate=safeRate;v.currentRate=safeRate and B.div(safeRate,v.margin)
    v.requiredSafeRate=B.div(v.gap,math.max(.001,waitSeconds))
    v.requiredRate=B.div(v.requiredSafeRate,v.margin)
    v.capacity=B.add(money,safeRate and B.mul(safeRate,waitSeconds) or B.new(0))
    v.ratio=v.cost.m==0 and B.new(1) or B.div(v.capacity,v.cost)
    v.fraction=math.max(0,math.min(1,B.number(v.ratio) or 0))
    if v.cashFunded then v.factor=B.new(1);v.decadesShort=0
    elseif safeRate and safeRate.m>0 then
        v.factor=B.div(v.requiredSafeRate,safeRate)
        v.decadesShort=math.max(0,B.log(v.factor))
    end
    -- Unmeasured income is unknown, not zero. An already funded cash balance is sufficient.
    v.financed=v.cashFunded or safeRate~=nil and B.cmp(v.capacity,v.cost)>=0
    v.modelVerified=remaining.modelVerified==true
    v.certifiable=remaining.certifiable~=false and v.modelVerified
    v.ready=v.financed and v.certifiable
    v.completeLedger=remaining.completeLedger
    return v
end
function __slctx.HaloPlan.rebirthReadiness(remaining,safeRate,inv,spend,waitSeconds,config)
    if not remaining or not safeRate or safeRate.m<=0 or not inv or not inv.investors or not inv.reward
        or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    spend=spend or B.new(0)
    local afterBank=B.sub(B.add(inv.investors,inv.reward),spend)
    local beforeMult=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
    local afterMult=B.add(B.new(1),B.mul(afterBank,inv.perInvestor))
    local factor=B.div(afterMult,beforeMult)
    local restoredRate=B.mul(safeRate,factor)
    -- No old wallet survives a reset. This scenario begins AFTER restoring the same
    -- observed layout; rebuilding time is shown by the independent route comparator.
    local v=__slctx.HaloPlan.readiness(remaining,B.new(0),restoredRate,waitSeconds,config)
    v.bank=afterBank;v.factorGain=factor;v.spend=spend;v.sameLayoutAssumption=true
    v.requiredBank=B.div(B.sub(B.mul(beforeMult,B.div(v.requiredSafeRate,safeRate)),B.new(1)),inv.perInvestor)
    v.quality='conditional after restoring current layout; NOT immediate post-reset income'
    return v
end
function __slctx.HaloPlan.readinessPercent(v)
    if not v or not v.known or not v.ratio then return 'не определена' end
    if v.fraction>=1 then return '100%' end
    local percent=B.mul(v.ratio,100);local n=B.number(percent)
    if n and n>=.01 then return string.format('%.2f%%',n) end
    if percent.m==0 then return '0%' end
    return B.format(percent)..'%'
end
-- ECONOMIC_READINESS_32_END

-- LEVEL_PROJECTION_33_BEGIN
-- Learn only from same-layout observations of one stand. No hard-coded level milestone.
function __slctx.HaloPlan.fitLevelCurve(points)
    if not points or #points<3 then return nil end
    local first,last=points[1],points[#points];local levels=last.n-first.n
    if levels<50 or not first.rate or not last.rate or first.rate.m<=0 or last.rate.m<=0 then return nil end
    if not first.batch or not last.batch or first.batch<=0 or last.batch<=0
        or not first.cost or not last.cost or first.cost.m<=0 or last.cost.m<=0 then return nil end
    local function logSeries(slope,n)
        local a=slope*n;local b=slope
        local x=a>16 and a or math.log(10^a-1)/math.log(10)
        local y=b>16 and b or math.log(10^b-1)/math.log(10)
        return x-y
    end
    local ratio=B.log(last.cost)-B.log(first.cost)
    local price
    if first.batch==last.batch then price=ratio/levels
    else
        -- C(n,k)=p0*q^n*(q^k-1)/(q-1); different MAX quantities are not comparable unit prices.
        if levels<first.batch then return nil end
        local lo,hi=1e-7,1
        local function predicted(x)return x*levels+logSeries(x,last.batch)-logSeries(x,first.batch)end
        if predicted(lo)>ratio or predicted(hi)<ratio then return nil end
        for _=1,32 do local mid=(lo+hi)*.5;if predicted(mid)<ratio then lo=mid else hi=mid end end
        price=(lo+hi)*.5
    end
    local growth=(B.log(last.rate)-B.log(first.rate))/levels
    if not price or price<=0 or price>1 or growth<=0 or growth>=price*1.5 then return nil end
    local pError,rError=0,0
    for _,v in ipairs(points) do
        if not v.cost or not v.rate or v.rate.m<=0 or v.cost.m<=0 or not v.batch or v.batch<=0 then return nil end
        local dx=v.n-first.n
        local predicted=B.log(first.cost)+price*dx+logSeries(price,v.batch)-logSeries(price,first.batch)
        pError=math.max(pError,math.abs(B.log(v.cost)-predicted))
        rError=math.max(rError,math.abs(B.log(v.rate)-B.log(first.rate)-growth*dx))
    end
    if pError>.04 or rError>1 then return nil end
    return {price=price+2*pError/levels,growth=math.max(0,growth-2*rError/levels),levels=levels,
        priceError=pError,incomeError=rError,samples=#points,n=last.n,quality='same-layout empirical level curve'}
end
function __slctx.HaloPlan.geometricCost(price,quotedBatch,units,slope,offset)
    if not price or not quotedBatch or quotedBatch<=0 or units<=0 or slope<=0 then return nil end
    local function logSeries(n)
        local x=slope*n;local d=slope
        local num=x>16 and x or math.log(10^x-1)/math.log(10)
        local den=d>16 and d or math.log(10^d-1)/math.log(10)
        return num-den
    end
    return pow(B.log(price)+slope*(offset or 0)+logSeries(units)-logSeries(quotedBatch))
end
function __slctx.HaloPlan.withLevelPlan(remaining,cards,curves,model,batch,upgradeSeconds,config,allowCatalogueEffects)
    if not remaining or not model or not curves then return nil end
    local out={rows={},cost=cp(remaining.cost),count=remaining.count,baseCount=remaining.count,
        modelVerified=remaining.modelVerified,certifiable=remaining.certifiable,
        completeLedger=remaining.completeLedger,hasLevels=false,levelNodes=0,levelActions=0}
    for _,r in ipairs(remaining.rows) do
        out.rows[#out.rows+1]={id=r.id,cost=r.cost,name=r.name,effect=allowCatalogueEffects and r.effect or nil}
    end
    for _,c in ipairs(cards or {}) do
        local key=__slctx.HaloPlan.key(c.name);local curve=curves[key];local quoted=__slctx.Core.count(c.stack)
        if curve and curve.growth>0 and c.cost and c.cost.m>0 and quoted and quoted>0 
            and model.sources[key] and model.sources[key].m>0 then
            local ceiling=B.mul(remaining.cost,config.TerminalLevelBudgetFraction or .01)
            local chunk=math.max(50,math.min(250,type(batch)=='number' and batch or 100))
            local offset=0;local allocated=B.new(0)
            local cap=math.min(config.LevelProjectionMaxUnits or 4000,curve.levels*(config.LevelExtrapolationFactor or 8))
            for _=1,(config.LevelNodesPerSource or 16) do
                if offset+chunk>cap then break end
                local cost=__slctx.HaloPlan.geometricCost(c.cost,quoted,chunk,curve.price,offset)
                if not cost or B.cmp(B.add(allocated,cost),ceiling)>0 then break end
                allocated=B.add(allocated,cost)
                local multiplier=pow(curve.growth*chunk)
                if not multiplier then break end
                local actions=batch=='max' and 1 or math.ceil(chunk/math.max(1,tonumber(batch) or 1))
                out.rows[#out.rows+1]={id='level:'..key..':'..offset,cost=cost,name=c.name..' +'..chunk,
                    effect={target=key,mult=multiplier},serviceSeconds=actions*upgradeSeconds,
                    levelNode=true,units=chunk,path=c.path}
                out.cost=B.add(out.cost,cost);out.count=out.count+1;out.levelNodes=out.levelNodes+1
                out.levelActions=out.levelActions+actions;out.hasLevels=true
                offset=offset+chunk
            end
        end
    end
    if not out.hasLevels then return nil end
    table.sort(out.rows,function(a,b)
        local cmp=B.cmp(a.cost,b.cost);return cmp==0 and tostring(a.id)<tostring(b.id) or cmp<0
    end)
    out.quality='catalogue plus paid empirical level packets; future level law is a local extrapolation'
    return out
end
function __slctx.HaloPlan.rebatchRoute(remaining,batch,upgradeSeconds)
    if not remaining or not remaining.hasLevels or not batch then return remaining end
    local out={};for k,v in pairs(remaining) do out[k]=v end
    out.rows={};out.levelActions=0
    for _,item in ipairs(remaining.rows) do
        local row={};for k,v in pairs(item) do row[k]=v end
        if row.levelNode then
            local actions=batch=='max' and 1 or math.ceil((row.units or 0)/math.max(1,tonumber(batch) or 1))
            row.serviceSeconds=actions*upgradeSeconds;out.levelActions=out.levelActions+actions
        end
        out.rows[#out.rows+1]=row
    end
    return out
end
-- LEVEL_PROJECTION_33_END

-- ROUTE_ECONOMY_33_BEGIN
-- Primary evidence for 42 and 7.77: game UI screenshots listed in SOURCES.md.
-- These are separate from the source's level/upgrade-dependent base production.
function __slctx.HaloPlan.fixedFactors(halo,evolution,investors,config,observedBonus)
    if type(halo)~='number' or halo<0 or halo%1~=0 or type(evolution)~='number' or evolution<0 or evolution%1~=0 or not investors then return nil end
    local bonus=observedBonus or config.ExpectedInvestorBonus or .08
    local speed=config.ExpectedTimeMultiplier or 16
    if speed<=0 or bonus<=0 then return nil end
    local v={time=B.new(speed),evolution=pow(evolution*math.log(config.EvolutionSpeedBase or 42)/math.log(10)),
        halo=pow(halo*math.log(config.HaloCashBase or 7.77)/math.log(10)),
        investors=B.add(B.new(1),B.mul(investors,bonus)),bonus=bonus,E=evolution,H=halo}
    v.total=B.mul(B.mul(v.time,v.evolution),B.mul(v.halo,v.investors))
    return v
end
function __slctx.HaloPlan.scaleRateModel(model,factor)
    if not model or not factor then return nil end
    local out={other=B.mul(model.other or B.new(0),factor),sources={},complete=model.complete}
    for key,rate in pairs(model.sources or {}) do out.sources[key]=B.mul(rate,factor) end
    return out
end
function __slctx.HaloPlan.totalRateModel(model)
    if not model then return nil end
    local rate=cp(model.other or B.new(0))
    for _,v in pairs(model.sources or {}) do rate=B.add(rate,v) end
    return rate
end
function __slctx.HaloPlan.routeReadiness(remaining,money,model,actionSeconds,allowance,config,useEffects)
    local rate=__slctx.HaloPlan.totalRateModel(model)
    local v=__slctx.HaloPlan.readiness(remaining,money,rate,allowance,config)
    v.basis='current income; future boosts unavailable'
    if not v.known or not rate or rate.m<=0 or not useEffects then return v end
    local direct=__slctx.HaloPlan.roll(remaining,money,model,actionSeconds,true)
    if not direct then return v end
    v.basis='remaining catalogue boosts in price-order scenario; current source levels'
    v.catalogueRoute=direct;v.projectedTerminalRate=direct.rate;v.routeScenario=true
    if v.cashFunded then return v end
    -- Invert an actual sequential cash flow: boosts start AFTER their paid action.
    -- The alternative of funding everything first remains the conservative bound.
    local hi=B.log(B.div(v.requiredSafeRate,rate))+.15
    local effectLog=0
    for _,row in ipairs(remaining.rows or {}) do
        if row.effect then effectLog=effectLog+B.log(type(row.effect.mult)=='table' and row.effect.mult or B.new(row.effect.mult)) end
    end
    local lo=hi-math.min(10000,effectLog+12)
    for _=1,(config.RouteIncomeSearchSteps or 16) do
        local mid=(lo+hi)*.5
        local tested=__slctx.HaloPlan.roll(remaining,money,__slctx.HaloPlan.scaleRateModel(model,pow(mid)),actionSeconds,true)
        if tested and B.cmp(tested.wait,B.new(allowance))<=0 then hi=mid else lo=mid end
    end
    local required=B.mul(rate,pow(hi))
    -- Never make a sequential scenario worse than the valid fund-all-first bound.
    if B.cmp(required,v.requiredSafeRate)>0 then required=v.requiredSafeRate end
    v.passiveRequiredRate=v.requiredRate
    v.requiredSafeRate=required;v.requiredRate=B.div(required,v.margin)
    v.factor=B.div(required,rate);v.decadesShort=math.max(0,B.log(v.factor))
    v.ratio=B.div(rate,required);v.fraction=math.max(0,math.min(1,B.number(v.ratio) or 0))
    v.capacity=B.mul(v.cost,v.ratio)
    -- Preserve readiness from the order-independent current-income bound.
    -- A complete ownership ledger does not establish the future unlock order.
    v.scenarioReady=B.cmp(direct.wait,B.new(allowance))<=0 and v.certifiable
    v.additionalWait=direct.wait
    return v
end
function __slctx.HaloPlan.factorReadiness(view,factors)
    if not view or not factors or not factors.total then return view end
    view.factors=factors
    if view.currentRate then view.sourceBaseRate=B.div(view.currentRate,factors.total) end
    if view.factor then
        view.requiredFactor=B.mul(factors.total,view.factor)
        local have=math.max(0,B.log(factors.total))
        local need=math.max(have,B.log(view.requiredFactor))
        view.logFraction=need>0 and math.max(0,math.min(.999,have/need)) or 0
    end
    if view.ready then view.logFraction=1 end
    return view
end
function __slctx.HaloPlan.resetStatusView(kind,started,time,confirmedClicks,modal,animation,changed)
    local age=math.max(0,time-started)
    if changed then return 'RESET_RECEIPT','Результат '..kind..' подтверждён; обновляю состояние.' end
    if (confirmedClicks or 0)==0 then
        return 'RESET_CONFIRM_WAIT','Сброс '..kind..': ожидаю доступное подтверждение ('..string.format('%.1f',age)..' с).'
    end
    if modal then return 'RESET_CONFIRM_WAIT','Подтверждение '..kind..' отправлено; проверяю диалог ('..string.format('%.1f',age)..' с).' end
    return animation and 'RESET_ANIMATION' or 'RESET_RESULT_WAIT',
        'Подтверждение '..kind..' отправлено. '..(animation and 'Идёт анимация игры' or 'Жду обновление счётчика')
        ..' · '..string.format('%.1f',age)..' с. Повторный сброс не отправляется.'
end
-- ROUTE_ECONOMY_33_END

-- HALO_FLOW_PLANNER_31_BEGIN
function __slctx.HaloPlan.powerToken(bank,batch,epoch)
    return table.concat({B.format(bank),tostring(batch),tostring(epoch)},'|')
end
function __slctx.HaloPlan.bootstrapGain(inv,spend,config)
    if not inv or not inv.investors or not inv.reward or not inv.perInvestor or inv.perInvestor<=0 then return nil end
    local before=B.add(B.new(1),B.mul(inv.investors,inv.perInvestor))
    local after=B.add(B.new(1),B.mul(B.sub(B.add(inv.investors,inv.reward),spend or B.new(0)),inv.perInvestor))
    local raw=B.div(after,before)
    if not raw or B.cmp(raw,B.new(1))<=0 then return nil end
    -- Discount the incremental gain, then compare actual saved wait against the
    -- reset/rebuild cost. A fixed income multiple cannot decide that tradeoff.
    local confidence=math.max(0,math.min(1,config.BootstrapGainConfidence or .60))
    local discounted=B.add(B.new(1),B.mul(B.sub(raw,B.new(1)),confidence))
    if B.cmp(discounted,B.new(1))<=0 then return nil end
    return discounted,raw
end
function __slctx.HaloPlan.bootstrapComparison(q,money,rate,inv,spend,rebuildSeconds,config)
    -- Calibration failure must not require a previous scripted reset to obtain one.
    -- This is an explicit LOCAL bridge-to-next-block model, not a complete Halo ETA.
    if not q or not q.cost or not money or not rate or rate.m<=0 or B.cmp(money,q.cost)>=0 then return false end
    local discounted,raw=__slctx.HaloPlan.bootstrapGain(inv,spend,config)
    if not discounted then return false end
    local direct=B.div(B.sub(q.cost,money),rate)
    local after=B.add(B.new(rebuildSeconds),B.div(q.cost,B.mul(rate,discounted)))
    local required=B.add(B.mul(after,1+(config.RouteResetMargin or .25)),B.new(config.GoalAdvantageSeconds or 3))
    return B.cmp(required,direct)<0,{direct=direct,reset=after,gain=raw,discountedGain=discounted,
        quality='bootstrap to observed funding block; full catalogue forecast unavailable',cost=rebuildSeconds,
        directCatalogueTime=nil,resetCatalogueTime=nil,bootstrap=true,localBridge=true,
        authorization='bootstrap-observed-block-31',parityTimeNeverAmplified=true}
end
function __slctx.HaloPlan.progressView(book,rows,remaining,money,rate,waitSeconds,endReached)
    local known=0
    for _,row in ipairs(rows) do if book.bought[row.id] then known=known+1 end end
    local coverage
    if remaining and money then
        local capacity=B.add(money,rate and B.mul(rate,math.max(0,waitSeconds or 0)) or B.new(0))
        if remaining.cost.m==0 then coverage=1
        else coverage=math.min(1,B.number(B.div(capacity,remaining.cost)) or 0) end
    end
    return {known=known,total=#rows,fraction=endReached and 1 or math.min(.999,known/math.max(1,#rows)),
        coverage=coverage,lowerBound=not book.complete,endReached=endReached==true}
end

local observeKnown32=__slctx.HaloPlan.observe
function __slctx.HaloPlan.observe(book,q,index,config)
    local row,why=observeKnown32(book,q,index,config)
    if not row and why=='name absent from supplied catalogue' and q and q.cost then
        return __slctx.HaloPlan.observeExtra(book,q,config),'additional live cost; no guessed catalogue alias'
    end
    local model,verified=__slctx.HaloPlan.priceModel(book,config)
    if model and model.formula and verified then
        book.model=model;book.scaleFailure=nil
    end
    return row,why
end

-- HALO_FLOW_PLANNER_31_END
end
-- HALO_PLANNER_30_END


end
