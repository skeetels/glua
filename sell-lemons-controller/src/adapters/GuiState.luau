-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.readInvestors()
    local ok,err=__slctx.navigate('investors');if not ok then return nil,err end
    local base=__slctx.paths.investors..'/Body/'
    if __slctx.t(base..'Amount/What'):lower()~='investors' then return nil,'UNSUPPORTED_WORLD_CURRENCY' end
    local inv=__slctx.BN.parse(__slctx.t(base..'Amount/Quantity'))
    local reward=__slctx.BN.parse(__slctx.t(base..'Potential/Quantity'))
    if not inv or not reward then return nil,'INVESTOR_NUMBER_UNRECOGNIZED' end
    local bonusText=__slctx.t(base..'Bonus/Quantity')
    local percent=tonumber(bonusText:match('%+?(%d+%.?%d*)%%'))
    return {investors=inv,reward=reward,perInvestor=percent and percent/100 or nil,
        bonusText=bonusText,ready=__slctx.usable(__slctx.g(base..'Rebirth')),time=__slctx.now()}
end
function __slctx.readEvolution()
    local ok,err=__slctx.navigate('evolution');if not ok then return nil,err end
    local base=__slctx.paths.evolution..'/Body/'
    local index=tonumber(__slctx.t(base..'Current/What'):lower():match('evolution%s+(%d+)'))
    local pct=__slctx.Core.percent(__slctx.t(base..'Progress'))
    local b=__slctx.g(base..'EvolveBonus/Quantity')
    local icon=__slctx.g(base..'EvolveBonus/Icon')
    local shown=__slctx.visible(b)
    local value=shown and __slctx.BN.parse(__slctx.txt(b)) or nil
    local ready=__slctx.usable(__slctx.g(base..'Evolve'))
    if not index then return nil,'EVOLUTION_INDEX_UNKNOWN' end
    local eta=nil -- Percentage progress is not assumed linear in investor count.
    return {index=index,pct=pct,ready=ready and pct~=nil and pct>=99.99,
        bonusVisible=shown,bonus=value,bonusIsInvestors=__slctx.attr(icon,'AssetName')=='Icons.Investors',
        fresh=true,time=__slctx.now(),eta=eta,fruit=__slctx.t(base..'Current/Label')}
end
function __slctx.readHalo()
    local ok,err=__slctx.navigate('halo');if not ok then return nil,err end
    local base=__slctx.paths.halo..'/Body/'
    if __slctx.t(base..'Amount/What'):lower()~='halos' then return nil,'INVERSION_NOT_IN_SCOPE' end
    local n=__slctx.Core.count(__slctx.t(base..'Amount/Quantity'))
    if not n then return nil,'HALO_NUMBER_UNKNOWN' end
    return {amount=n,ready=__slctx.usable(__slctx.g(base..'Ascend')),time=__slctx.now(),objective=__slctx.t(base..'Objective')}
end
-- ResetConfirm is forward-declared above navigation.
function __slctx.readTablet()
    local ok,err=__slctx.manageTab('Powers');if not ok then return nil,err end
    local tile=__slctx.g(__slctx.paths.powers..'/Manage')
    if not tile or not __slctx.visible(tile) then return nil,'TABLET_TILE_NOT_LOADED' end
    local bonus=__slctx.childText(tile,'Bonus'):lower()
    local priceText=__slctx.txt(__slctx.at(tile,'Buy/Price'))
    local price=__slctx.BN.parse(priceText)
    local owned=bonus=='owned' and priceText:lower()=='max'
    local b=tile:FindFirstChild('Buy')
    return {owned=owned,price=price,button=b,time=__slctx.now(),
        investorCurrency=__slctx.attr(__slctx.at(tile,'Buy/Icon'),'AssetName')=='Icons.Investors',bonus=bonus}
end
function __slctx.ensureTablet()
    local tablet,err=__slctx.readTablet()
    __slctx.S.lastPowers=__slctx.now();__slctx.S.tablet=tablet
    if not tablet then return false,err end
    if tablet.owned then return true end
    if not tablet.price or not tablet.investorCurrency then return false,'TABLET_PRICE_UNKNOWN' end
    local inv,ei=__slctx.readInvestors();if not inv then return false,ei end
    if __slctx.BN.cmp(inv.investors,tablet.price)<0 then return false,'TABLET_NEEDS_INVESTORS' end
    -- Refresh the tile after changing menus. Hidden Active flags are not reused.
    tablet,err=__slctx.readTablet();__slctx.S.tablet=tablet
    if not tablet then return false,err end
    if tablet.owned then return true end
    if not tablet.price or not tablet.investorCurrency then return false,'TABLET_PRICE_UNKNOWN' end
    if __slctx.BN.cmp(inv.investors,tablet.price)<0 then return false,'TABLET_NEEDS_INVESTORS' end
    if not __slctx.usable(tablet.button) then return false,'TABLET_PURCHASE_LOCKED' end
    local ok,e=__slctx.ResetConfirm.perform(tablet.button,'tablet',function()
        local tile=__slctx.g(__slctx.paths.powers..'/Manage')
        return tile~=nil and tile.Parent~=nil and __slctx.childText(tile,'Bonus'):lower()=='owned'
            and __slctx.txt(__slctx.at(tile,'Buy/Price')):lower()=='max'
    end,{guard=function()
        local tile=__slctx.g(__slctx.paths.powers..'/Manage')
        local price=tile and __slctx.BN.parse(__slctx.txt(__slctx.at(tile,'Buy/Price')))
        return __slctx.visible(tile) and price and __slctx.BN.cmp(inv.investors,price)>=0
            and __slctx.attr(__slctx.at(tile,'Buy/Icon'),'AssetName')=='Icons.Investors'
    end}, {name='Manage', aliases={'tablet'},priceText=__slctx.BN.format(tablet.price),price=tablet.price,currency='investors',restore='powers',
        authorize=function()
            local tile=__slctx.g(__slctx.paths.powers..'/Manage');local b=tile and tile:FindFirstChild('Buy')
            local price=b and __slctx.childNumber(b,'Price')
            return b~=nil and not __slctx.paid(b) and price and __slctx.BN.cmp(price,tablet.price)==0
                and __slctx.BN.cmp(inv.investors,price)>=0 and __slctx.attr(__slctx.at(b,'Icon'),'AssetName')=='Icons.Investors'
        end})
    if not ok then __slctx.pause('TABLET_FAILED',e);return false,e end
    __slctx.Strategy.recordSpend(tablet.price);__slctx.Strategy.bootstrapSpend(tablet.price)
    __slctx.S.tablet.owned=true;__slctx.progress('tablet');__slctx.S.lastRefresh=-math.huge
    return true
end
function __slctx.readBuy()
    local root=__slctx.g(__slctx.paths.buy)
    if not __slctx.visible(root) then return nil end
    local name=__slctx.childText(root,'Purchase')
    local price,reason=__slctx.childNumber(root,'PurchasePrice')
    local info=__slctx.childText(root,'PurchaseInfo')
    local uses=__slctx.childText(root,'UsesLeft')
    if name=='' then return nil end
    return {id='buy:'..name..':'..__slctx.childText(root,'PurchasePrice'),kind='buy',name=name,
        cost=price,parseReason=reason,info=info,multiplier=__slctx.Core.multiplier(info),
        newSource=info:lower():find('new income source',1,true)~=nil,
        button=root:FindFirstChild('Button'),root=root,path=__slctx.paths.buy,uses=uses,
        available=__slctx.usable(root:FindFirstChild('Button')),observedAt=__slctx.now()}
end
function __slctx.readCards()
    local root=__slctx.g(__slctx.paths.cards)
    if not __slctx.visible(root) then return {},'MANAGE_NOT_VISIBLE' end
    local out={}
    local maxMode=__slctx.usable(__slctx.g(__slctx.paths.manage..'/StackButton')) and __slctx.childText(__slctx.g(__slctx.paths.manage..'/StackButton'),'Stack'):lower()=='max'
    -- Match the verified card schema rather than a fixed list of business names.
    for _,row in ipairs(root:GetChildren()) do
        local upgrade=row:FindFirstChild('Upgrade')
        if upgrade and upgrade:IsA('GuiButton') and __slctx.visible(row) then
            local price,reason=__slctx.childNumber(upgrade,'Price')
            local count=__slctx.childText(upgrade,'Count')
            local stack=__slctx.childText(upgrade,'Stack')
            -- The base single upgrade omits its optional +N badge.
            -- Cost and actual count increase are still required for every click.
            if stack=='' then stack='+1' end
            out[#out+1]={id='upgrade:'..row.Name..':'..(count~='' and count or ('price='..__slctx.childText(upgrade,'Price'))),kind='upgrade',name=__slctx.childText(row,'Title'),
                cost=price,parseReason=reason,count=count,button=upgrade,root=row,
                path=__slctx.paths.cards..'/'..row.Name,stack=stack,stackRaw=__slctx.childText(upgrade,'Stack'),maxMode=maxMode,order=__slctx.prop(row,'LayoutOrder') or 0,
                income=__slctx.childNumber(row,'Earns'),period=__slctx.txt(__slctx.at(row,'Progress/Label')),info='',multiplier=nil,
                available=__slctx.usable(upgrade),observedAt=__slctx.now(),priceText=__slctx.childText(upgrade,'Price')}
        end
    end
    table.sort(out,function(a,b)
        if a.cost and b.cost then return __slctx.BN.cmp(a.cost,b.cost)<0 end
        return a.cost~=nil and b.cost==nil
    end)
    return out
end

end
