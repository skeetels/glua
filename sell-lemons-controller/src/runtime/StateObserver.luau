-- Passive GUI observations. No remote discovery or guessed hidden data schema.
return function(ctx)
    local store=ctx.ObservationStore.new(ctx.now)
    local observer={store=store, nextPoll=0, hits=0, refreshes=0, failures=0}
    ctx.Observer=observer
    local function identity(v)
        if type(v)=='table' and v.m then return tostring(v.m)..'e'..tostring(v.e) end
        return tostring(v)
    end
    local function signature(v,fields)
        local out={}
        for _,key in ipairs(fields) do out[#out+1]=identity(v[key]) end
        return table.concat(out,'|')
    end
    local fields={investors={'investors','reward','perInvestor'},
        evolution={'index','pct','bonus','bonusIsInvestors'},halo={'amount','objective'}}
    local function ownVisible(o,root)
        if not o or not o.Parent then return false end
        while o and o~=root do
            if o:IsA('GuiObject') and o.Visible==false then return false end
            o=o.Parent
        end
        return o==root
    end
    local function raw(key)
        local root=ctx.g(ctx.paths[key]);if not root then return end
        local b=ctx.paths[key]..'/Body/'
        local v
        if key=='investors' then
            if ctx.t(b..'Amount/What'):lower()~='investors' then return end
            local bank=ctx.BN.parse(ctx.t(b..'Amount/Quantity'))
            local reward=ctx.BN.parse(ctx.t(b..'Potential/Quantity'))
            if not bank or not reward then return end
            local bonus=ctx.t(b..'Bonus/Quantity')
            local percent=tonumber(bonus:match('%+?(%d+%.?%d*)%%'))
            v={investors=bank,reward=reward,perInvestor=percent and percent/100,
                bonusText=bonus,ready=ctx.usable(ctx.g(b..'Rebirth'))}
        elseif key=='evolution' then
            local index=tonumber(ctx.t(b..'Current/What'):lower():match('evolution%s+(%d+)'))
            if not index then return end
            local pct=ctx.Core.percent(ctx.t(b..'Progress'))
            local shown=ownVisible(ctx.g(b..'EvolveBonus/Quantity'),root)
            v={index=index,pct=pct,ready=ctx.usable(ctx.g(b..'Evolve')) and pct~=nil and pct>=99.99,
                bonusVisible=shown,bonus=shown and ctx.BN.parse(ctx.t(b..'EvolveBonus/Quantity')) or nil,
                bonusIsInvestors=ctx.attr(ctx.g(b..'EvolveBonus/Icon'),'AssetName')=='Icons.Investors',
                fruit=ctx.t(b..'Current/Label')}
        else
            if ctx.t(b..'Amount/What'):lower()~='halos' then return end
            local amount=ctx.Core.count(ctx.t(b..'Amount/Quantity'));if not amount then return end
            v={amount=amount,ready=ctx.usable(ctx.g(b..'Ascend')),objective=ctx.t(b..'Objective')}
        end
        local r=store:observe(key,v,signature(v,fields[key]),ctx.visible(root),'game-gui')
        v.time=r.observedAt;v.fresh=r.observedAt~=nil
        return v,r
    end
    function observer.poll()
        if ctx.S.unloaded or ctx.now()<observer.nextPoll then return end
        observer.nextPoll=ctx.now()+0.25
        if ctx.Data then ctx.Data.poll() end
        if ctx.S.resetSession or ctx.S.resetChildPending then return end
        for _,key in ipairs({'investors','evolution','halo'}) do
            local ok,v,r=pcall(raw,key)
            if not ok then observer.failures=observer.failures+1
            elseif v and r.changedAt and r.changedAt>(observer.lastHint or -math.huge) then
                local route=ctx.S.route
                if route and route.halo30 then route.halo30.progressReviewHint=true end
            end
        end
        observer.lastHint=ctx.now()
    end
    for key,name in pairs({investors='readInvestors',evolution='readEvolution',halo='readHalo'}) do
        local original=ctx[name]
        ctx[name]=function()
            raw(key)
            -- Reuse only an unchanged, recently visible reading. Hidden changes are hints.
            local value,_,record=store:read(key,1.25,true)
            if value and record.visible then
                observer.hits=observer.hits+1
                return value
            end
            observer.refreshes=observer.refreshes+1
            local result,err=original()
            if result then
                store:observe(key,result,signature(result,fields[key]),true,'verified-menu')
            end
            return result,err
        end
    end
    ctx.API.observations=function() observer.poll();return store:summary() end
    -- This read-only worker keeps observing while the economic worker awaits receipts.
    task.spawn(function()
        while not ctx.S.unloaded do
            local ok=pcall(observer.poll)
            if not ok then observer.failures=observer.failures+1 end
            task.wait(0.25)
        end
    end)
end
