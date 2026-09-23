-- Independent arithmetic matching the inspected TycoonEarner/Huge functions.
return function(ctx)
    local M={};ctx.UpgradeMath=M;local prefixes={};local LOG2=math.log10(2)
    function M.add(a,b)
        if a<b then a,b=b,a end
        if b==-math.huge then return a end
        return a+math.log10(1+10^(b-a))
    end
    function M.sub(a,b)
        if a<=b then return -math.huge end
        if b==-math.huge then return a end
        return a+math.log10(1-10^(b-a))
    end
    function M.bn(value)
        if value==-math.huge then return ctx.BN.new(0)end
        if type(value)~='number' or value~=value or math.abs(value)==math.huge then return nil end
        local e=math.floor(value);return ctx.BN.new(10^(value-e),e)
    end
    function M.unit(name,level)
        local prices=assert(ctx.GameBalance.UpgradePrices[name],'Unknown stand')
        return prices[level] or prices[#prices]+LOG2*((level-#prices)^1.2)/ctx.GameBalance.UpgradePowerFactors[name][2]
    end
    local function cumulative(name,level)
        if level<=0 then return -math.huge end
        assert(level<=100000,'Upgrade level exceeds inspected calculation bound')
        local cache=prefixes[name] or {};prefixes[name]=cache
        local value=cache[#cache] or -math.huge
        for i=#cache+1,level do value=M.add(value,M.unit(name,i));cache[i]=value end
        return cache[level]
    end
    function M.price(name,level,count,shift)
        if count==0 then return -math.huge end
        return M.sub(cumulative(name,level+count)+shift,cumulative(name,level)+shift)
    end
    function M.affordable(name,level,limit,cash,shift)
        local low,high=0,math.min(limit,10000,100000-level)
        while low<high do
            local mid=math.ceil((low+high)/2)
            if M.price(name,level,mid,shift)<=cash-1e-9 then low=mid else high=mid-1 end
        end
        return low,M.price(name,level,low,shift)
    end
    function M.countMultiplier(name,count)
        if count<.5 then return -math.huge end
        local f=ctx.GameBalance.UpgradePowerFactors[name]
        return math.log10(1+(count-1)*f[1])+LOG2*(count-1)/f[2]
    end
end
