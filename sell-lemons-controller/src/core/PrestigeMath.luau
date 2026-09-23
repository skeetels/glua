-- TycoonRebirth / TycoonEvolution arithmetic in the game's log10 units.
return function(ctx)
    local P={};ctx.PrestigeMath=P;local M=ctx.UpgradeMath
    local CASH_FACTOR=math.log10(1.8e17);local POWER=.44
    -- nil is an explicit zero amount, never log10(1). Keep reset balances out
    -- of the non-finite conversion boundary used by the general upgrade math.
    local function normalized(v)if v==-math.huge then return nil end;return v end
    local function add(a,b)
        a,b=normalized(a),normalized(b)
        if a==nil then return b end;if b==nil then return a end
        return M.add(a,b)
    end
    function P.reward(cash,cashSpent,investors,investorsSpent)
        local earned=add(cash,cashSpent)
        if earned==nil then return nil end
        investors,investorsSpent=normalized(investors),normalized(investorsSpent)
        local capped=investors~=nil and investorsSpent~=nil and math.min(investorsSpent,investors+1) or nil
        local prior=add(investors,capped)
        if prior==nil then return (earned-CASH_FACTOR)*POWER end
        local ratio=earned-CASH_FACTOR-prior/POWER
        if ratio < -8 then return prior+math.log10(POWER)+ratio end
        return prior+M.sub(POWER*M.add(0,ratio),0)
    end
    function P.evolution(index,investors,investorsSpent,reward)
        local target=17.7+13.6*index
        local total=add(add(investors,investorsSpent),reward)
        if total==nil then return 0,nil,target,nil end
        local excess=total-target
        local progress=math.min(1,10^(excess/13.6))
        local bonus=excess>0 and math.log10(500*target)+2*math.log10(excess) or nil
        return progress,bonus,target,total
    end
end
