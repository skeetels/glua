-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.candidateFresh(c)
    if c.kind=='buy' then
        local current=__slctx.readBuy()
        return current and current.id==c.id and __slctx.usable(current.button),current
    end
    local row=__slctx.g(c.path)
    local b=row and row:FindFirstChild('Upgrade')
    local same=b and __slctx.childText(b,'Count')==c.count
    local currentCost=b and __slctx.childNumber(b,'Price')
    return same and __slctx.childText(b,'Stack')==(c.stackRaw or c.stack) and __slctx.visible(row) and __slctx.usable(b),{button=b,cost=currentCost}
end
function __slctx.affordable(c,amount)
    -- Planning uses a quote read in its own menu, not Visible on a currently hidden tab.
    -- Actual availability and price are checked again by buy() AFTER opening that menu.
    local ready=c.available
    if ready==nil then ready=__slctx.usable(c.button) end
    return c.cost and amount and __slctx.BN.cmp(amount,c.cost)>=0 and ready and not __slctx.paid(c.button)
end
function __slctx.focusCandidate(c)
    local ok,err
    if c.kind=='buy' then ok,err=__slctx.ensureStrip() else ok,err=__slctx.manageTab('Manage') end
    if not ok then return nil,err end
    if not __slctx.live() then return nil,'PAUSED' end
    if c.kind=='buy' then
        local current=__slctx.readBuy()
        if current and current.id==c.id then return current end
    else
        for _,current in ipairs(__slctx.readCards()) do
            if current.path==c.path and (current.id==c.id or c.maxMode and current.maxMode) then return current end
        end
    end
    return nil,'QUOTE_CHANGED_AFTER_NAVIGATION'
end
function __slctx.Safety.key(c) return c.kind..':'..tostring(c.path or c.id or c.name) end
function __slctx.Safety.batchAllowed(c)
    if c.kind~='upgrade' then return true end
    local n=__slctx.Core.count(c.stack)
    return n~=nil and n>=__slctx.CONFIG.MinimumUpgradeBatch and (c.maxMode or n<=__slctx.CONFIG.PreferredUpgradeBatch)
end
function __slctx.Safety.proof(rec)
    local c=rec.c
    if c.kind=='upgrade' then
        local row=__slctx.g(c.path);local b=row and row:FindFirstChild('Upgrade')
        if not row or not row.Parent then return false end
        local old,new=__slctx.Core.count(c.count),b and __slctx.Core.count(__slctx.childText(b,'Count'))
        if old~=nil and new~=nil and new>old then return true end
        if old~=nil and not c.maxMode then return false end
        if c.maxMode then
            local income=__slctx.childNumber(row,'Earns')
            return __slctx.childText(row,'Title')==c.name and c.income and income and __slctx.BN.cmp(income,c.income)>0
        end
        local cost=b and __slctx.childNumber(b,'Price')
        return c.cost and cost and __slctx.BN.cmp(cost,c.cost)>0
    end
    local q=__slctx.readBuy()
    local complete=__slctx.Planner.completionMarker(__slctx.t(__slctx.paths.buy..'/Purchase'),__slctx.t(__slctx.paths.buy..'/PurchasePrice'),__slctx.t(__slctx.paths.buy..'/PurchaseInfo'))
    if complete then return true end
    return q and q.name~='' and (q.cost~=nil or q.parseReason=='hidden_large')
        and (q.name..'|'..__slctx.childText(q.root,'PurchasePrice')..'|'..q.info)~=rec.signature
end
function __slctx.Safety.commit(rec,late)
    if rec.committed then return end
    rec.committed=true
    local c=rec.c;__slctx.Strategy.recordTiming(c.kind,rec.started and __slctx.now()-rec.started-((__slctx.S.focusPausedTotal or 0)-(rec.focusPauseBase or 0)))
    __slctx.progress(c.kind);__slctx.Strategy.receipt(c,rec.beforeRate)
    local r=__slctx.Strategy.route();r.blocked=r.blocked or {};r.blocked[__slctx.Safety.key(c)]=nil
    if c.kind=='upgrade' then __slctx.S.upgradeVisited[c.path]=__slctx.now() end
    if late then __slctx.log('LATE_RECEIPT','Observed after reopening; no duplicate click: '..c.path) end
    if __slctx.S.windowFocused==false then
        __slctx.S.backgroundReceipts=(__slctx.S.backgroundReceipts or 0)+1
        __slctx.log('BACKGROUND_PURCHASE_CONFIRMED',c.kind..' | '..c.name)
    end
end
function __slctx.Safety.describe(c)
    local b=c.kind=='upgrade' and __slctx.g(c.path..'/Upgrade') or __slctx.g(__slctx.paths.buy..'/Button')
    return c.name..' | count='..__slctx.childText(b,'Count')..' stack='..__slctx.childText(b,'Stack')
        ..' price='..__slctx.childText(b,'Price')..' cash='..__slctx.t(__slctx.paths.balance)
        ..' active='..tostring(__slctx.prop(b,'Active'))..' visible='..tostring(__slctx.visible(b))
        ..' Manage='..tostring(__slctx.visible(__slctx.g(__slctx.paths.manage)))..' focused='..tostring(__slctx.S.windowFocused)
end
function __slctx.Safety.refreshMax(c,expected)
    if not c.maxMode then return false end
    for _,fresh in ipairs(__slctx.readCards()) do
        if fresh.path==c.path then
            if not fresh.maxMode or fresh.name~=c.name or not __slctx.Safety.batchAllowed(fresh)
                or not __slctx.affordable(fresh,__slctx.cash()) then return false end
            -- Only quote fields may move before dispatch; progression itself invalidates the snapshot.
            if fresh.count~=c.count or c.income and fresh.income and __slctx.BN.cmp(c.income,fresh.income)~=0 then return false end
            c.stack=fresh.stack;c.stackRaw=fresh.stackRaw;c.cost=fresh.cost;c.priceText=fresh.priceText
            c.priceTextRaw=fresh.priceText
            if expected then expected.price=c.cost;expected.priceText=c.priceText end
            return true
        end
    end
    return false
end
function __slctx.buy(c)
    if not __slctx.live() then return false,'PAUSED' end
    local current,routeError=__slctx.focusCandidate(c)
    if not current then __slctx.S.catalogDirty=true;return false,routeError end
    c=current
    c.priceTextRaw=c.kind=='buy' and __slctx.childText(c.root,'PurchasePrice') or c.priceText
    if not __slctx.Safety.batchAllowed(c) then return false,'SMALL_BATCH_BLOCKED' end
    if not __slctx.affordable(c,__slctx.cash()) then __slctx.S.catalogDirty=true;return false,'QUOTE_UNAFFORDABLE' end
    local rec={c=c,started=__slctx.now(),focusPauseBase=__slctx.S.focusPausedTotal or 0,beforeRate=__slctx.Planner.sourceRate(c),beforeCash=__slctx.cash(),sent=false,
        signature=c.kind=='buy' and (__slctx.childText(c.root,'Purchase')..'|'..__slctx.childText(c.root,'PurchasePrice')..'|'..__slctx.childText(c.root,'PurchaseInfo')) or nil}
    local expected={name=c.name,priceText=c.priceText or __slctx.childText(c.root,'PurchasePrice'),currency='cash',price=c.cost,
        restore=c.kind=='buy' and 'buy' or 'manage'}
    expected.authorize=function()
        local amount=__slctx.cash()
        if not amount or not c.cost or __slctx.BN.cmp(amount,c.cost)<0 then return false end
        if c.kind=='buy' then return c.root and __slctx.childText(c.root,'Purchase')==c.name and __slctx.childText(c.root,'PurchasePrice')==c.priceTextRaw end
        local b=__slctx.g(c.path..'/Upgrade');local price=b and __slctx.childNumber(b,'Price')
        return b~=nil and not __slctx.paid(b) and price and __slctx.BN.cmp(price,c.cost)==0
            and __slctx.childText(b,'Count')==c.count and __slctx.childText(b,'Stack')==(c.stackRaw or c.stack) and __slctx.Safety.batchAllowed(c)
    end
    local fast=c.kind=='buy' and __slctx.CONFIG.AdaptiveBuyReceipts and (__slctx.S.buyReceiptStreak or 0)>=__slctx.CONFIG.BuyReceiptWarmup
    local stable=c.kind=='upgrade' and 0 or (fast and __slctx.CONFIG.FastBuyReceiptStableSeconds or __slctx.CONFIG.ReceiptStableSeconds)
    local ok,err=__slctx.ResetConfirm.perform(c.button,c.kind,function() return __slctx.Safety.proof(rec) end,
        {once=true,stableFor=stable,effectKey=c.kind=='buy' and function()
            local q=__slctx.readBuy();return q and (q.id..'|'..q.info) or (__slctx.Planner.completionMarker(__slctx.t(__slctx.paths.buy..'/Purchase'),__slctx.t(__slctx.paths.buy..'/PurchasePrice'),__slctx.t(__slctx.paths.buy..'/PurchaseInfo')) and 'COMPLETE') or nil
        end or nil,guard=function()
            if c.maxMode then return __slctx.Safety.refreshMax(c,expected) end
            local good,fresh=__slctx.candidateFresh(c);local amount=__slctx.cash()
            return good and __slctx.Safety.batchAllowed(c) and fresh.cost and amount and __slctx.BN.cmp(amount,fresh.cost)>=0
        end}, expected)
    if ok then
        if c.kind=='buy' then
            local session=__slctx.S.lastResetSession
            __slctx.S.buyReceiptStreak=(session and session.sawDialog) and 0 or (__slctx.S.buyReceiptStreak or 0)+1
        end
        __slctx.Safety.commit(rec);return true,nil,rec
    end
    if c.kind=='buy' then __slctx.S.buyReceiptStreak=0 end
    rec.sent=not tostring(err):find('BEFORE_CLICK',1,true)
    __slctx.S.catalogDirty=true
    return false,err,rec
end

function __slctx.startIncome()
    if not __slctx.CONFIG.StartIncomeWhenIdle or not (__slctx.S.tablet and __slctx.S.tablet.owned) or __slctx.now()<(__slctx.S.nextIncomeAt or 0) then return false end
    local root=__slctx.g(__slctx.paths.cards);if not __slctx.visible(root) then return false end
    for _,row in ipairs(root:GetChildren()) do
        local key=__slctx.paths.cards..'/'..row.Name
        local previous=__slctx.S.incomeAttempts[key]
        local b=row:FindFirstChild('Progress')
        local hint=b and b:FindFirstChild('Hint')
        if (not previous or __slctx.now()>=previous.nextAt) and __slctx.usable(b) and __slctx.visible(hint) and __slctx.txt(hint):upper()=='CLICK' then
            local attempt={nextAt=__slctx.now()+__slctx.CONFIG.IncomeRetrySeconds,observed=false}
            __slctx.S.incomeAttempts[key]=attempt;__slctx.S.nextIncomeAt=__slctx.now()+2
            local beforeLabel=__slctx.childText(b,'Label')
            local ok,err=__slctx.Driver.perform(b,'income',function()
                -- A transient Active=false on mouse-down is NOT evidence of production.
                if not __slctx.visible(row) then return false end
                local label=__slctx.childText(b,'Label')
                return (__slctx.prop(hint,'Visible')==false)
                    or (label~='' and label~=beforeLabel)
            end,{once=true,timeout=__slctx.CONFIG.IncomeAttemptTimeout,stableFor=0.2})
            attempt.nextAt=__slctx.now()+__slctx.CONFIG.IncomeRetrySeconds
            attempt.observed=ok==true
            attempt.reason=ok and 'production UI changed' or tostring(err)
            if not ok then __slctx.log('OPTIONAL_INCOME_SKIPPED',row.Name..' | '..tostring(err)..' | purchases stay enabled') end
            -- Production neither spends cash nor resets the waiting episode. A single
            -- unobserved optional click must not stop purchases or be counted as income.
            return true
        end
    end
    return false
end
-- Adaptive batches are selected by Strategy.stackPrepare, down to +1.

-- RESET_CONFIRMATION_BEGIN
-- Known Important/Alert/Main/Buttons verified in live v6916; Main/Sale is separate.
-- Only a newly visible, matching dialog in an armed reset/purchase transaction is eligible.

end
