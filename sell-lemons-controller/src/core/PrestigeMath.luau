-- TycoonRebirth / TycoonEvolution arithmetic in the game's log10 units.
return function(ctx)
    local P={};ctx.PrestigeMath=P;local M=ctx.UpgradeMath
    local CASH_FACTOR=math.log10(1.8e17);local POWER=.44
    function P.reward(cash,cashSpent,investors,investorsSpent)
        local earned=M.add(cash,cashSpent)
        local prior=M.add(investors,math.min(investorsSpent,investors+1))
        if prior==-math.huge then return (earned-CASH_FACTOR)*POWER end
        local ratio=earned-CASH_FACTOR-prior/POWER
        if ratio < -8 then return prior+math.log10(POWER)+ratio end
        return prior+M.sub(POWER*M.add(0,ratio),0)
    end
    function P.evolution(index,investors,investorsSpent,reward)
        local target=17.7+13.6*index
        local total=M.add(M.add(investors,investorsSpent),reward)
        local excess=total-target
        local progress=math.min(1,10^(excess/13.6))
        local bonus=excess>0 and math.log10(500*target)+2*math.log10(excess) or -math.huge
        return progress,bonus,target,total
    end
end
