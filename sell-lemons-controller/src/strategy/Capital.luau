-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.Strategy.syncPowerBank(bank)
    local r=__slctx.Strategy.route()
    if not bank then return false,'BANK_UNKNOWN' end
    if not r.powerBase then
        r.powerBase=__slctx.BN.new(bank.m,bank.e);r.powerUsed=__slctx.BN.new(0);r.powerBank=__slctx.BN.new(bank.m,bank.e)
        __slctx.log('CAPITAL_BASELINE','observed bank='..__slctx.BN.format(bank)..'; previous spend before attachment unknown')
        return true
    end
    if r.powerUnresolved then return false,'UNRESOLVED_POWER_DEBIT' end
    local used=r.powerUsed or __slctx.BN.new(0)
    local accounted=__slctx.BN.sub(r.powerBase,used)
    if __slctx.BN.cmp(bank,__slctx.BN.mul(accounted,1.001))>0 and __slctx.BN.cmp(__slctx.BN.sub(bank,accounted),__slctx.BN.new(.5))>0 then
        local c=r.capitalCreditProbe
        local same=c and c.epoch==__slctx.S.epoch and c.evolution==(r.evo and r.evo.index)
            and math.abs(__slctx.BN.log(bank)-__slctx.BN.log(c.bank))<.00005
        if same and __slctx.now()-c.at+1e-6>=__slctx.CONFIG.CapitalCreditStableSeconds then
            local added=__slctx.BN.sub(bank,accounted)
            r.powerBase=__slctx.BN.add(r.powerBase,added);r.powerBank=__slctx.BN.new(bank.m,bank.e)
            r.capitalCreditProbe=nil;r.externalCapitalRevision=(r.externalCapitalRevision or 0)+1
            __slctx.log('CAPITAL_OBSERVED_CREDIT','two consistent visible bank reads; new capital='..__slctx.BN.format(added)
                ..'; prior spending retained='..__slctx.BN.format(used)..'; not counted as a scripted rebirth')
            return true,'OBSERVED_CAPITAL_CREDIT'
        end
        if not same then r.capitalCreditProbe={bank=__slctx.BN.new(bank.m,bank.e),at=__slctx.now(),epoch=__slctx.S.epoch,evolution=r.evo and r.evo.index} end
        r.powerBank=__slctx.BN.new(bank.m,bank.e)
        return false,'BANK_CREDIT_NEEDS_SECOND_OBSERVATION'
    end
    r.capitalCreditProbe=nil
    if r.powerBank and __slctx.BN.cmp(bank,__slctx.BN.mul(r.powerBank,.999))<0 then
        local debit=__slctx.BN.sub(r.powerBank,bank)
        r.powerUsed=__slctx.BN.add(used,debit)
        __slctx.log('CAPITAL_DEBIT_RECONCILED','unexplained debit reserved='..__slctx.BN.format(debit))
    end
    r.powerBank=__slctx.BN.new(bank.m,bank.e)
    return true
end
function __slctx.Strategy.bootstrapSpend(amount)
    local r=__slctx.Strategy.route()
    if r.powerBase then
        r.powerBase=__slctx.BN.sub(r.powerBase,amount)
        r.powerBank=r.powerBank and __slctx.BN.sub(r.powerBank,amount) or nil
        __slctx.log('CAPITAL_BOOTSTRAP','mandatory tablet excluded before calculating optional-power retention')
    end
end
function __slctx.Strategy.creditRebirth(before,after)
    local r=__slctx.Strategy.route()
    if not before or not after then return end
    if not r.powerBase then __slctx.Strategy.syncPowerBank(before) end
    local credit=__slctx.BN.sub(after,before)
    r.powerBase=__slctx.BN.add(r.powerBase,credit);r.powerBank=after
    -- U is deliberately not reset. Small repeated rebirths do not repeatedly spend 5%.
    __slctx.log('CAPITAL_CREDIT','credited='..__slctx.BN.format(credit)..'; gross='..__slctx.BN.format(r.powerBase)..'; spent='..__slctx.BN.format(r.powerUsed))
end
function __slctx.Strategy.largestBatch()
    local r=__slctx.Strategy.route()
    if r.maxObserved or r.batchSelected=='max' then return 'max' end
    local n=type(r.batchSelected)=='number' and r.batchSelected or nil
    for _,v in ipairs(r.availableBatches or {}) do if not n or v>n then n=v end end
    return n
end
function __slctx.Strategy.updatePowerGoal(inv)
    local r=__slctx.Strategy.route();r.powerGoal=nil
    if not __slctx.CONFIG.AutoInvestorPowers or not inv or not r.powerBase then return nil end
    for _,item in ipairs(r.powerQuotes or {}) do
        if item.name=='UpgradeStack' and not r.powerSkipped[item.name] then
            local plan=__slctx.Planner.powerPlan(item,inv,r.powerUsed,r.powerBase,__slctx.Strategy.largestBatch(),__slctx.CONFIG)
            if plan and not (r.failedTierHints or {})[plan.currentBatch] then
                r.powerGoal=plan;return plan
            end
        end
    end
    return nil
end
function __slctx.Strategy.capturePowerQuotes()
    local r=__slctx.Strategy.route();r.powerQuotes=__slctx.Powers.read();r.powerQuoteAt=__slctx.now()
    return r.powerQuotes
end
function __slctx.Strategy.refreshPowerQuote()
    if __slctx.S.actionPending or __slctx.S.resetChildPending or __slctx.S.resetSession then return false end
    local ok,why=__slctx.manageTab('Powers')
    if not ok then __slctx.log('POWER_GOAL_REFRESH_FAILED',tostring(why));return false end
    __slctx.Strategy.route().menuReads.powers=__slctx.Strategy.route().menuReads.powers+1
    __slctx.Strategy.capturePowerQuotes();return true
end
function __slctx.Strategy.powerWork(cards)
    local r=__slctx.Strategy.route();local p=r.pass;local work={}
    -- A fixed entry budget is a bounded obligation. Only a repeatedly observed
    -- local cost curve can extrapolate it; no unseen price ladder is invented.
    if p and not p.finished and p.entered and p.budget then
        local current=p.order[p.index]
        for _,c in ipairs(cards or r.cards or {}) do
            if current and c.path==current.path then
                local levels,why=__slctx.Planner.remainingBudgetWork(c,p.budget,(r.priceModels or {})[c.path])
                if levels and levels>0 then work[c.path]=levels;return work,why end
            end
        end
    end
    -- A completed sweep is a repeat-work scenario, not an assertion that the
    -- future game will require the same levels. The planner discounts its savings.
    if r.lastFullPass and r.lastFullPass.work then
        for path,levels in pairs(r.lastFullPass.work) do work[path]=levels end
        if next(work) then return work,'last complete sweep as discounted repeat-work scenario' end
    end
    return nil,'no measured remaining workload'
end


function __slctx.Strategy.capabilityReview()
    local r=__slctx.Strategy.route();local destination=r.reviewReturn or 'UPGRADE'
    local function resume(reason)
        __slctx.Strategy.cancelResetIntent(reason);r.lastDecision=reason
        r.capabilityOnly=nil;r.resetPowerPlan=nil;r.reviewReturn=nil
        r.capabilityBackoff=math.min(24,math.max(__slctx.CONFIG.CapabilityReviewSeconds,(r.capabilityBackoff or 6)*1.5))
        __slctx.Strategy.phase(destination,reason..'; прежний прогресс прохода сохранён')
    end
    if not __slctx.S.resetEnabled or not __slctx.CONFIG.AutoRebirth then resume('автосброс выключен');return end
    __slctx.Strategy.stampReview()
    if __slctx.Strategy.stopForBlocked() then return end
    r.buyQuote=nil
    if not __slctx.Strategy.refreshResetBuy() then resume('BUILD_QUOTE_NOT_VERIFIED');return end
    if r.completionSeen or r.endPurchased then
        r.capabilityOnly=nil;r.reviewReturn=nil;__slctx.Strategy.cancelResetIntent('HALO_TAKES_PRIORITY')
        __slctx.Strategy.phase('HALO','подтверждён конец базы');return
    end
    if destination=='BUY' then
        if __slctx.manageTab('Manage') then local cards=__slctx.Strategy.readCards();__slctx.Strategy.captureGrowth(cards);__slctx.Strategy.observeRecovery(cards) end
    end
    local inv,why=__slctx.Strategy.readInvestors()
    if not inv then __slctx.log('MACRO_REVIEW_UNAVAILABLE',tostring(why));resume('нет актуального баланса');return end
    local total=__slctx.Planner.totalMinimum(inv,r.spent);r.totalMinimum=total
    if __slctx.CONFIG.AutoEvolution and (not r.evo or __slctx.now()-(r.lastEvolutionRead or 0)>=30
        or __slctx.Planner.shouldInspectEvolution(r.evo.index,inv,r.spent,false,r.evo.ready)) then
        local evo=__slctx.Strategy.readEvolution();r.evolutionCheckTotal=total
        if not evo then resume('эволюция не прочитана');return end
        if evo.ready then r.capabilityOnly=nil;r.reviewReturn=nil;r.reserveSince=__slctx.now()
            __slctx.Strategy.phase('EVOLVE_RESERVE','эволюция важнее промежуточного сброса');return end
    end
    local goal=__slctx.Strategy.updatePowerGoal(inv)
    if goal and goal.canBuyNow and goal.nextBatch and __slctx.Strategy.powerWorthBuying(goal) then
        r.capabilityOnly=nil;r.powerReturn=destination;r.powerPurchasePlan=goal;r.reviewReturn=nil
        __slctx.Strategy.phase('POWERS','нужная пачка уже доступна без rebirth');return
    end
    local yes,reason,gain,detail=__slctx.Strategy.resetAllowed(inv)
    r.lastDecision=reason;r.gain=gain;r.lastResetEstimate=detail
    __slctx.log('MACRO_RESET_COMPARE',reason..'; net factor='..tostring(gain)..'; cost='..tostring(detail and (detail.cost or detail.cycle))
        ..'; log output advantage='..tostring(detail and detail.logAdvantage))
    __slctx.Strategy.logResetEstimate(detail,reason)
    if not yes then resume(reason);return end
    if reason=='RESET_FOR_UPGRADE_STACK' then
        if not __slctx.Strategy.refreshPowerQuote() then resume('цена способности не подтверждена');return end
        goal=__slctx.Strategy.updatePowerGoal(inv)
        yes,reason,gain,detail=__slctx.Strategy.resetAllowed(inv)
        __slctx.Strategy.logResetEstimate(detail,reason)
    if not yes then resume(reason);return end
    end
    r.resetPowerPlan=reason=='RESET_FOR_UPGRADE_STACK' and goal or nil
    r.capabilityBackoff=nil
    __slctx.doReset('rebirth')
    if r.phase=='CAPABILITY' and r.reason~='NEW_EVOLUTION_THRESHOLD' then resume('rebirth не отправлен') end
end
-- CYCLE_RUNTIME_END


end
