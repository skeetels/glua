-- Component initialized with an explicit shared service context.
return function(__slctx)
-- the observed Icons.Investors marker is eligible; sibling BuyRobux is never used.
function __slctx.Powers.read()
    local root=__slctx.g(__slctx.paths.powers);local out={}
    if not __slctx.visible(root) then return out end
    for _,tile in ipairs(root:GetChildren()) do
        local button=tile:FindFirstChild('Buy')
        local priceText=__slctx.childText(button,'Price')
        local price=__slctx.BN.parse(priceText)
        local title=__slctx.childText(tile,'Title')
        if tile.Name~='Manage' and __slctx.visible(tile) and button and button:IsA('GuiButton')
            and __slctx.attr(__slctx.at(button,'Icon'),'AssetName')=='Icons.Investors' and not __slctx.paid(button)
            and price and priceText:lower()~='max' and title~='???' then
            out[#out+1]={name=tile.Name,title=title~='' and title or tile.Name,
                path=__slctx.paths.powers..'/'..tile.Name,button=button,price=price,priceText=priceText,
                bonus=__slctx.childText(tile,'Bonus'),info=__slctx.childText(tile,'Description')..' '..__slctx.childText(tile,'Info'),
                available=__slctx.usable(button),observedAt=__slctx.now()}
        end
    end
    table.sort(out,function(a,b)
        if a.name=='UpgradeStack' or b.name=='UpgradeStack' then return a.name=='UpgradeStack' and b.name~='UpgradeStack' end
        if __slctx.BN.cmp(a.price,b.price)~=0 then return __slctx.BN.cmp(a.price,b.price)<0 end
        return a.name<b.name
    end)
    return out
end
function __slctx.Powers.proof(item)
    local tile=__slctx.g(item.path);if not tile or not tile.Parent then return false end
    local priceText=__slctx.txt(__slctx.at(tile,'Buy/Price'));local bonus=__slctx.childText(tile,'Bonus')
    if priceText:lower()=='max' and priceText~=item.priceText then return true end
    -- The live game can replace the NEXT price with ??? after buying a tier.
    -- The increased CURRENT bonus still proves progress; ??? alone never does.
    local function currentBonus(text)
        local clean=__slctx.Core.clean(text)
        return __slctx.Core.multiplier(clean) or tonumber(clean:match('^[xX+]?%s*(%d+%.?%d*)'))
    end
    local oldBonus,newBonus=currentBonus(item.bonus),currentBonus(bonus)
    if oldBonus and newBonus and newBonus>oldBonus then return true end
    local price=__slctx.BN.parse(priceText)
    return price~=nil and __slctx.BN.cmp(price,item.price)>0 and priceText~=item.priceText
        and (bonus~=item.bonus or item.bonus=='')
end
function __slctx.Powers.run()
    local r=__slctx.Strategy.route();local destination=r.powerReturn or 'BUY'
    if r.powerUnresolved then __slctx.pause('POWER_OUTCOME_UNRESOLVED','Результат прежней траты инвесторов не установлен; новые траты и сбросы остановлены.');return end
    if r.capitalCreditProbe then r.powerPending=false;__slctx.Strategy.phase(destination,'нужно второе наблюдение изменившегося банка');return end
    if not __slctx.CONFIG.AutoInvestorPowers then r.powerPending=false;r.powerReturn=nil;__slctx.Strategy.phase(destination,'optional powers disabled');return end
    if __slctx.S.resetEnabled and __slctx.CONFIG.AutoEvolution and r.evo and r.evo.ready then
        r.powerPending=false;r.powerReturn=nil;r.reserveSince=__slctx.now()
        __slctx.Strategy.phase('EVOLVE_RESERVE','evolution before optional powers');return
    end
    if __slctx.Strategy.largestBatch()=='max' and not next(__slctx.CONFIG.OptionalPowerAllowlist) then
        r.powerPending=false;r.powerReturn=nil;r.powerPurchasePlan=nil;r.capabilityPending=nil
        r.fastBuildPending=true
        if (r.runBuyCount or 0)==0 then r.buildStarted=__slctx.now() end
        __slctx.Strategy.phase(destination,'MAX уже подтверждён; необязательные Powers не покупаются');return
    end
    local inv,why=__slctx.Strategy.readInvestors()
    if not inv then __slctx.log('POWER_READ_SKIPPED',tostring(why));r.powerPending=false;__slctx.Strategy.phase(destination,'power balance unavailable');return end
    __slctx.Strategy.syncPowerBank(inv.investors)
    local remaining=inv.investors
    if __slctx.S.tablet and __slctx.S.tablet.owned and not __slctx.Strategy.largestBatch() then
        if __slctx.manageTab('Manage') then __slctx.Strategy.stackPrepare() end
    end
    local opened,err=__slctx.manageTab('Powers')
    if not opened then __slctx.log('POWER_MENU_SKIPPED',tostring(err));__slctx.Strategy.phase(destination,'power menu unavailable');return end
    r.menuReads.powers=r.menuReads.powers+1
    local target=r.powerPurchasePlan
    local any=false;local targetBought=false;local stackBought=false
    for _=1,__slctx.CONFIG.PowerPassLimit do
        if not __slctx.live() then return end
        if not __slctx.CONFIG.AutoInvestorPowers then break end
        local items=__slctx.Strategy.capturePowerQuotes();local chosen=nil
        local priority=nil
        for _,item in ipairs(items) do
            if item.name=='UpgradeStack' and __slctx.Planner.nextBatchHint(item,__slctx.Strategy.largestBatch(),__slctx.CONFIG.PowerNextBatchHints) then priority=item;break end
        end
        for _,item in ipairs(items) do
            local allowed=__slctx.Planner.powerRelevant(item,__slctx.CONFIG) and __slctx.Strategy.powerWorthBuying(nil) and __slctx.Planner.powerBudgetAllows(item.price,remaining,r.powerUsed,r.powerBase,__slctx.CONFIG)
            local matches=not target or (not targetBought and item.path==target.path
                and __slctx.BN.cmp(item.price,target.price)==0 and item.bonus==target.bonus)
                or (targetBought and __slctx.CONFIG.ChainStackPowers and item.name=='UpgradeStack')
            -- Don't spend the capability's reserved allowance on miscellaneous
            -- powers just because those happen to be cheaper.
            if priority and item.name~='UpgradeStack' then
                local budget=__slctx.Planner.powerBudgetInfo(remaining,r.powerUsed,r.powerBase,__slctx.CONFIG)
                allowed=allowed and budget and __slctx.BN.cmp(__slctx.BN.add(item.price,priority.price),budget.available)<=0
            end
            if allowed and matches and item.available and not r.powerSkipped[item.name] then chosen=item;break end
        end
        if not chosen then break end
        local item=chosen;local started=__slctx.now();local focusBase=__slctx.S.focusPausedTotal or 0
        __slctx.status('BUY_INVESTOR_POWER','Покупаю '..item.title..'; сохраняю общий защищённый банк 95%')
        local done,message=__slctx.ResetConfirm.perform(item.button,'power',function() return __slctx.Powers.proof(item) end,
            {once=true,stableFor=0.08,guard=function()
                if not __slctx.CONFIG.AutoInvestorPowers then return false end
                local tile=__slctx.g(item.path);local button=tile and tile:FindFirstChild('Buy')
                local price=button and __slctx.childNumber(button,'Price')
                return __slctx.visible(tile) and __slctx.usable(button) and not __slctx.paid(button) and price and __slctx.BN.cmp(price,item.price)==0
                    and __slctx.attr(__slctx.at(button,'Icon'),'AssetName')=='Icons.Investors'
                    and __slctx.Planner.powerBudgetAllows(price,remaining,r.powerUsed,r.powerBase,__slctx.CONFIG)
            end}, {name=item.title,aliases={item.name},priceText=item.priceText,price=item.price,currency='investors',restore='powers',
                authorize=function()
                    local button=__slctx.g(item.path..'/Buy');local price=button and __slctx.childNumber(button,'Price')
                    return __slctx.CONFIG.AutoInvestorPowers and button~=nil and not __slctx.paid(button) and price
                        and __slctx.BN.cmp(price,item.price)==0 and __slctx.attr(__slctx.at(button,'Icon'),'AssetName')=='Icons.Investors'
                        and __slctx.Planner.powerBudgetAllows(price,remaining,r.powerUsed,r.powerBase,__slctx.CONFIG)
                end})
        if not done and message=='STATE_CHANGED_BEFORE_CLICK' then
            __slctx.log('POWER_REPLAN','state changed before dispatch; no debit inferred')
            break
        end
        -- Reserve attempted spend even if the receipt is delayed. A pause/restart
        -- cannot turn an unknown result into fresh permission to spend again.
        remaining=__slctx.BN.sub(remaining,item.price);r.powerUsed=__slctx.BN.add(r.powerUsed,item.price);r.powerBank=remaining
        if not done and __slctx.live() and not __slctx.S.actionPending and not __slctx.S.resetChildPending and __slctx.sleep(__slctx.CONFIG.RecoverySettleSeconds) then
            local ok=__slctx.manageTab('Powers');done=ok and __slctx.Powers.proof(item)
        end
        if not done then
            r.powerUnresolved={item=item,reason=tostring(message)};r.powerSkipped[item.name]=tostring(message)
            if __slctx.live() then __slctx.pause('POWER_OUTCOME_UNRESOLVED','Не подтверждена трата на '..item.title..'. Повтор, rebirth и новые траты заблокированы; F7 — журнал.') end
            return
        end
        __slctx.Strategy.recordTiming('power',__slctx.now()-started-((__slctx.S.focusPausedTotal or 0)-focusBase))
        any=true;__slctx.S.counts.power=(__slctx.S.counts.power or 0)+1;__slctx.Strategy.recordSpend(item.price)
        if target then targetBought=true end
        if item.name=='UpgradeStack' then stackBought=true end
        __slctx.log('POWER_PURCHASED',item.name..'; spent total='..__slctx.BN.format(r.powerUsed)..'; protected gross='..__slctx.BN.format(r.powerBase))
        if target and not __slctx.CONFIG.ChainStackPowers then break end
        -- Each following tier still has a fresh real quote and the SAME cumulative budget.
    end
    __slctx.Strategy.capturePowerQuotes()
    if any then
        r.models={};r.priceModels={};r.batchQuotes={};__slctx.S.rate:reset()
        if __slctx.S.cashFlow then __slctx.S.cashFlow:reset() end
        r.batchSelected=nil;r.batchUnavailable=false;r.maxUnavailable=nil;r.maxObserved=nil
        r.availableBatches=nil;r.preferredReviewBatch=nil
        local actual=__slctx.Strategy.readInvestors()
        if actual then
            __slctx.Strategy.syncPowerBank(actual.investors)
            -- Parity targets remain the actual pre-reset rates; never multiply them.
        end
    end
    if target or stackBought then
        -- Validate the new selector, rather than inferring success from the
        -- power price rising. MAX discovery is reopened only after a real power.
        local actualBatch=nil
        if any and __slctx.manageTab('Manage') and __slctx.Strategy.stackPrepare() then actualBatch=__slctx.Strategy.currentBatch() end
        local expected=target and target.nextBatch
        local reached=actualBatch and (not expected or actualBatch=='max' or (type(expected)=='number' and type(actualBatch)=='number' and actualBatch>=expected))
        r.failedTierHints=r.failedTierHints or {}
        if not reached then
            if targetBought and target and target.currentBatch then r.failedTierHints[target.currentBatch]=true end
            __slctx.log('CAPABILITY_EFFECT_UNVERIFIED','expected='..tostring(target and target.nextBatch)..'; observed='..tostring(actualBatch)..'; same hint disabled')
        else
            r.rebuildEstimate=nil -- old batch timings are not a new-batch recovery measurement.
            __slctx.log('CAPABILITY_EFFECT_CONFIRMED','old='..tostring(target and target.currentBatch)..'; actual='..tostring(actualBatch))
        end
        r.capabilityPending=nil;r.powerPurchasePlan=nil
    end
    r.powerPending=false;r.powerReturn=nil;r.capabilityOnly=nil
    __slctx.Strategy.updatePowerGoal(r.latestInvestors)
    if (r.runBuyCount or 0)==0 then r.buildStarted=__slctx.now();r.frontierTrace=nil end
    r.fastBuildPending=true
    __slctx.Strategy.phase(destination,'полезные способности проверены; необязательные пропущены')
end
-- CYCLE_RUNTIME_BEGIN


end
