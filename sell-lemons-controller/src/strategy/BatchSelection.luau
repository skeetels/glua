-- Component initialized with an explicit shared service context.
return function(__slctx)
-- within this pass, only while the stand's level/income/period still match.
function __slctx.Strategy.cacheBatch(mode,cards)
    if type(mode)~='number' then return end
    local r=__slctx.Strategy.route();r.batchQuotes=r.batchQuotes or {}
    for _,c in ipairs(cards or __slctx.readCards()) do
        if __slctx.Core.count(c.count) and __slctx.Core.count(c.stack)==mode and not c.maxMode then
            local entry=r.batchQuotes[c.path]
            if not entry or entry.count~=c.count or entry.name~=c.name or entry.period~=c.period
                or not entry.income or not c.income or __slctx.BN.cmp(entry.income,c.income)~=0 then
                entry={count=c.count,name=c.name,period=c.period,income=c.income,prices={}}
                r.batchQuotes[c.path]=entry
            end
            -- ??? may become a numeric quote as cash arrives; never cache it as infinity.
            entry.prices[mode]=c.cost
        end
    end
end
function __slctx.Strategy.cachedBatch(c,budget,ceiling)
    local r=__slctx.Strategy.route();local entry=(r.batchQuotes or {})[c.path]
    local valid=entry and entry.count==c.count and entry.name==c.name and entry.period==c.period
        and entry.income and c.income and __slctx.BN.cmp(entry.income,c.income)==0
    -- Fixed batches contain this same first level. If it is unaffordable,
    -- probing additional levels cannot help during this stand's fixed budget.
    if valid and entry.prices[1] and __slctx.BN.cmp(budget,entry.prices[1])<0 then return 0 end
    for _,n in ipairs(r.availableBatches or __slctx.CONFIG.UpgradeBatches) do
        if not ceiling or n<ceiling then
            local price=valid and entry.prices[n]
            -- An unobserved mode must still be inspected, never guessed from a formula.
            if not price or __slctx.BN.cmp(budget,price)>=0 then return n end
        end
    end
    return 0
end
function __slctx.Strategy.selectBatch(target,visit)
    if __slctx.CONFIG.DirectUpgrades and __slctx.DirectUpgrades then
        local current=__slctx.Strategy.currentBatch();return current==target,'DIRECT_COUNTS_COMPUTED_PER_STAND'
    end
    local b=__slctx.g(__slctx.paths.manage..'/StackButton');local seen={}
    for _=1,8 do
        local current=__slctx.Strategy.currentBatch()
        if current then
            __slctx.Strategy.rememberBatch(current)
            __slctx.Strategy.cacheBatch(current)
            if visit and current==1 then
                for _,c in ipairs(__slctx.readCards()) do
                    if c.path==visit.path and c.cost and __slctx.BN.cmp(visit.budget,c.cost)<0 then
                        return true,'BATCH_BUDGET_EXHAUSTED'
                    end
                end
            end
            if current==target then return true end
            if seen[current] then return false,'BATCH_NOT_UNLOCKED' end
            seen[current]=true
        end
        if not __slctx.usable(b) then return false,'STACK_BUTTON_UNAVAILABLE' end
        if not current then return false,'STACK_LABEL_TRANSITION' end
        local previous,stableAt=nil,nil
        local ok,err=__slctx.Driver.navigate(b,function()
            local value=__slctx.Strategy.currentBatch()
            if not value or value==current then previous=nil;stableAt=nil;return false end
            if value~=previous then previous=value;stableAt=__slctx.now() end
            -- Live testing showed that faster cycling can drop the next click.
            return __slctx.now()-stableAt>=0.10
        end,{once=true})
        if not __slctx.live() or not ok then return false,err or 'PAUSED' end
    end
    return false,'STACK_CYCLE_LIMIT'
end
function __slctx.Strategy.stackPrepare()
    if __slctx.CONFIG.DirectUpgrades and __slctx.DirectUpgrades then
        local s=__slctx.DirectUpgrades.state();if not s then return false end
        local r=__slctx.Strategy.route();r.batchSelected=s.cap==math.huge and 'max' or s.cap;r.maxUnavailable=s.cap~=math.huge
        return true
    end
    local r=__slctx.Strategy.route();local current=__slctx.Strategy.currentBatch()
    if current=='max' then r.maxUnavailable=nil;r.maxObserved=true;r.preferredReviewBatch='max' end
    local desired=r.preferredReviewBatch or (r.maxUnavailable and (r.availableBatches or __slctx.CONFIG.UpgradeBatches)[1] or 'max')
    if current==desired and (type(current)=='number' or current=='max') then
        r.batchSelected=current;r.batchVerified=true;r.preferredReviewBatch=nil;return true
    end
    local p=r.pass;local item=p and p.order[p.index]
    local visit=item and p.budget and {path=item.path,budget=p.budget} or nil
    local ok,why=__slctx.Strategy.selectBatch(desired,desired~='max' and visit or nil)
    if not ok and why=='BATCH_NOT_UNLOCKED' then
        if desired=='max' then r.maxUnavailable=true end
        desired=(r.availableBatches or {})[1]
        if desired then ok,why=__slctx.Strategy.selectBatch(desired) end
    end
    current=__slctx.Strategy.currentBatch()
    if not ok and desired=='max' and type(current)=='number' and __slctx.live() and not __slctx.S.actionPending then
        -- A single unlocked mode can have a visible selector that does not change.
        -- Its real per-card quotes remain usable; power/reset events reopen discovery.
        r.maxUnavailable=true;__slctx.Strategy.rememberBatch(current);ok=true
    end
    if ok or type(current)=='number' and not __slctx.usable(__slctx.g(__slctx.paths.manage..'/StackButton')) then
        r.batchSelected=current;r.batchVerified=true;r.preferredReviewBatch=nil
        __slctx.Strategy.rememberBatch(current)
        __slctx.log('BATCH_SELECTED',tostring(current)..'; verified economic batch mode');return true
    end
    r.batchVerified=false;__slctx.log('BATCH_RETRY',tostring(why));return false
end
-- Cash and investor currencies are never interchanged. Only a direct Buy child with

end
