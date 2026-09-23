-- Component initialized with an explicit shared service context.
return function(__slctx)
__slctx.Core = (function()
-- CORE_BEGIN
-- Pure planning/numeric core. Lua 5.4 and Luau compatible.
local Core = {}
local BN = {}
Core.BN = BN
local function finite(n) return type(n) == 'number' and n == n and n > -math.huge and n < math.huge end
local log10 = math.log10 or function(n) return math.log(n) / math.log(10) end
function BN.new(m, e)
    e = e or 0
    if not finite(m) or not finite(e) or m < 0 then return nil end
    if m == 0 then return {m=0, e=0} end
    local k = math.floor(log10(m))
    m, e = m / 10^k, e + k
    if m >= 10 then m, e = m / 10, e + 1 end
    if m < 1 then m, e = m * 10, e - 1 end
    return {m=m, e=e}
end
function BN.cmp(a,b)
    assert(a and b, 'Cannot compare unknown numbers')
    if a.m == 0 or b.m == 0 then return a.m == b.m and 0 or (a.m == 0 and -1 or 1) end
    if a.e ~= b.e then return a.e < b.e and -1 or 1 end
    if a.m == b.m then return 0 end
    return a.m < b.m and -1 or 1
end
function BN.add(a,b)
    if not a or not b then return nil end
    if BN.cmp(a,b) < 0 then a,b = b,a end
    if b.m == 0 or a.e-b.e > 17 then return BN.new(a.m,a.e) end
    return BN.new(a.m+b.m*10^(b.e-a.e),a.e)
end
function BN.sub(a,b)
    if not a or not b then return nil end
    if BN.cmp(a,b) <= 0 then return BN.new(0) end
    if b.m == 0 or a.e-b.e > 17 then return BN.new(a.m,a.e) end
    return BN.new(a.m-b.m*10^(b.e-a.e),a.e)
end
function BN.mul(a,b)
    if type(b)=='number' then b=BN.new(b) end
    if not a or not b then return nil end
    return BN.new(a.m*b.m,a.e+b.e)
end
function BN.div(a,b)
    if type(b)=='number' then b=BN.new(b) end
    if not a or not b or b.m==0 then return nil end
    return BN.new(a.m/b.m,a.e-b.e)
end
function BN.number(a)
    if not a then return nil end
    if a.m==0 then return 0 end
    if a.e>300 then return math.huge end
    if a.e < -300 then return 0 end
    return a.m*10^a.e
end
function BN.log(a) return a and a.m>0 and (log10(a.m)+a.e) or -math.huge end
function BN.format(a)
    if not a then return '?' end
    if a.m==0 then return '0' end
    if a.e>=0 and a.e<6 then return string.format('%.4g',BN.number(a)) end
    return string.format('%.4g e%d',a.m,a.e)
end
local suffix = {['']=0,k=3,thousand=3,m=6,million=6,b=9,billion=9,t=12,trillion=12,
    sxg=183,centillion=303}
local low = {'million','billion','trillion','quadrillion','quintillion','sextillion',
    'septillion','octillion','nonillion','decillion','undecillion','duodecillion',
    'tredecillion','quattuordecillion','quindecillion','sexdecillion','septendecillion',
    'octodecillion','novemdecillion'}
for i,name in ipairs(low) do suffix[name]=3*(i+1) end
local tens = {[20]='vigintillion',[30]='trigintillion',[40]='quadragintillion',
    [50]='quinquagintillion',[60]='sexagintillion',[70]='septuagintillion',
    [80]='octogintillion',[90]='nonagintillion'}
local units = {{'un'},{'duo'},{'tre','tres'},{'quattuor'},{'quin','quinqua','quinque'},
    {'se','ses','sex'},{'septen','septem'},{'octo'},{'noven','novem'}}
for n,name in pairs(tens) do
    suffix[name]=3*(n+1)
    for u,variants in ipairs(units) do
        for _,p in ipairs(variants) do suffix[p..name]=3*(n+u+1) end
    end
end
suffix.sedecillion=51; suffix.septemdecillion=54; suffix.novendecillion=60
function Core.clean(text)
    return tostring(text or ''):gsub('<.->',''):gsub('\226\128\139',''):gsub('\194\160',' '):gsub('\226\128\175',' '):match('^%s*(.-)%s*$')
end
function BN.parse(text)
    local s=Core.clean(text):lower():gsub('^%$%s*',''):gsub('^%+%s*',''):gsub(',','')
    if s=='???' then return nil,'hidden_large' end
    if s=='' or s:find('?',1,true) then return nil,'unknown' end
    if s=='max' or s=='owned' then return nil,'owned' end
    if s=='free' then return BN.new(0),'ok' end
    local m,e=s:match('^(%d+%.?%d*)%s*e%+?(%-?%d+)$')
    if m then return BN.new(tonumber(m),tonumber(e)),'ok' end
    local num,tail=s:match('^(%d+%.?%d*)%s*([a-z]*)$')
    if not num then num,tail=s:match('^(%.%d+)%s*([a-z]*)$') end
    if not num or suffix[tail]==nil then return nil,'unknown suffix/format: '..s end
    local out=BN.new(tonumber(num),suffix[tail])
    return out,out and 'ok' or 'invalid number'
end
function Core.percent(text)
    local v=tonumber(Core.clean(text):match('^(%d+%.?%d*)%%$'))
    return v and v>=0 and v<math.huge and v or nil
end
function Core.count(text)
    return tonumber(Core.clean(text):gsub(',',''):match('^[xX%+]?%s*(%d+)$'))
end
function Core.multiplier(text)
    local s=Core.clean(text):lower():gsub('\195\151','x')
    s=s:gsub("'",'')
    local token=s:match('x%s*(%d[%d,.]*)') or s:match('(%d[%d,.]*)%s*x')
    return token and tonumber((token:gsub(',',''))) or nil
end
function Core.eta(cash,cost,rate)
    if not cash or not cost then return nil end
    if BN.cmp(cash,cost)>=0 then return 0 end
    if not rate or rate.m==0 then return math.huge end
    return BN.number(BN.div(BN.sub(cost,cash),rate))
end
function Core.evolutionGuard(evo,minimum)
    if not evo or not evo.fresh then return false,'EVOLUTION_DATA_STALE' end
    if not evo.ready then return false,'EVOLUTION_NOT_READY' end
    if not evo.bonusVisible or not evo.bonus or not evo.bonusIsInvestors then
        return false,'EVOLUTION_BONUS_UNKNOWN'
    end
    if BN.cmp(evo.bonus,BN.new(minimum or 400))<0 then return false,'WAIT_400_INVESTORS' end
    return true,'EVOLUTION_BUDGET_READY'
end
function Core.rebirthGuard(investors,reward,age,config)
    if not investors or not reward then return false,'INVESTORS_UNKNOWN' end
    if age<config.MinRunSeconds then return false,'RUN_TOO_YOUNG' end
    if investors.m==0 then
        return BN.cmp(reward,BN.new(config.TabletReserve))>=0,'FIRST_REBIRTH_WAIT_400'
    end
    if reward.m==0 then return false,'NO_REBIRTH_REWARD' end
    local ratio=BN.number(BN.div(reward,investors))
    return ratio>=config.MinInvestorGainRatio,'REWARD_RATIO_TOO_LOW'
end
function Core.newEpisode(now) return {start=now,deadline=now+30,expired={}} end
function Core.pickWait(candidates,cash,rate,now,episode,config,onlyMajor)
    local best,score
    if now>=episode.deadline then return nil end
    for _,c in ipairs(candidates) do
        local eta=Core.eta(cash,c.cost,rate)
        local major=(c.multiplier or 0)>=config.MajorMultiplier
        if not episode.expired[c.id] and (not onlyMajor or major) and eta and eta>0
            and eta<=episode.deadline-now then
            local s=(major and 1000000 or 0)+(c.newSource and 1000 or 0)-eta
            if not best or s>score then best,score=c,s end
        end
    end
    return best
end
function Core.newRateTracker()
    local r={points={},rate=nil}
    function r:reset() self.points={};self.rate=nil end
    function r:add(t,cash)
        if not cash then self:reset();return nil end
        local p=self.points[#self.points]
        if p and (t<=p.t or BN.cmp(cash,p.cash)<0) then self:reset() end
        self.points[#self.points+1]={t=t,cash=cash}
        while #self.points>2 and t-self.points[2].t>8 do table.remove(self.points,1) end
        local first=self.points[1]
        if t-first.t>=3 then self.rate=BN.div(BN.sub(cash,first.cash),t-first.t) end
        return self.rate
    end
    return r
end
-- CASH_FLOW_BEGIN
-- Transaction-compensated observations, retained across BUY. Currency stays in BN.
-- Rounded GUI values are estimates; an unexplained debit starts a NEW segment.
function Core.newCashFlow()
    local f={spent=BN.new(0),samples={},rate=nil,validAt=nil,rejected=0,segment=0,total=BN.new(0)}
    function f:reset()
        self.anchor=nil;self.spent=BN.new(0);self.samples={};self.rate=nil;self.validAt=nil
        self.segment=self.segment+1;self.total=BN.new(0);self.lastSampleAt=nil
    end
    function f:invalidateRate()
        self.samples={};self.rate=nil;self.validAt=nil
    end
    function f:spend(cost)
        if self.anchor and cost then self.spent=BN.add(self.spent,cost) end
    end
    function f:sample(time,amount)
        if not amount then return nil end
        if not self.anchor then self.anchor={time=time,cash=amount};self.spent=BN.new(0);return nil end
        local dt=time-self.anchor.time
        if dt<=0 then return self:current(time) end
        if dt>8 then self:reset();self.anchor={time=time,cash=amount};return nil end
        if dt<0.6 then return self:current(time) end
        local gross=BN.add(amount,self.spent)
        local scale=BN.cmp(gross,self.anchor.cash)>0 and gross or self.anchor.cash
        if BN.cmp(gross,self.anchor.cash)<0 then
            -- Do not publish an invented zero/negative income after a late debit.
            local debit=BN.sub(self.anchor.cash,gross)
            if BN.cmp(debit,BN.mul(scale,0.001))<=0 and dt<2 then return self:current(time) end
            self.rejected=self.rejected+1;self:reset();self.anchor={time=time,cash=amount};return nil
        end
        local delta=BN.sub(gross,self.anchor.cash)
        if delta.m==0 or BN.cmp(delta,BN.mul(scale,0.001))<0 then
            -- Keep the financial anchor: small real incomes may eventually become observable.
            if dt>=4 then
                self.total=BN.add(self.total,delta);self.anchor={time=time,cash=amount};self.spent=BN.new(0)
            end
            return self:current(time)
        end
        self.total=BN.add(self.total,delta);self.lastSampleAt=time
        self.samples[#self.samples+1]=BN.div(delta,dt)
        if #self.samples>3 then table.remove(self.samples,1) end
        if #self.samples>=2 then
            local sorted={};for i,v in ipairs(self.samples)do sorted[i]=v end
            table.sort(sorted,function(a,b)return BN.cmp(a,b)<0 end)
            self.rate=sorted[math.ceil(#sorted/2)];self.validAt=time
        end
        self.anchor={time=time,cash=amount};self.spent=BN.new(0)
        return self:current(time)
    end
    function f:current(time)
        if self.validAt and time-self.validAt<=2.5 then return self.rate end
        return nil
    end
    function f:earned(time,amount)
        if not self.anchor or not amount or time-self.anchor.time>8 then return nil end
        local gross=BN.add(amount,self.spent)
        if BN.cmp(gross,self.anchor.cash)<0 then return nil end
        return BN.add(self.total,BN.sub(gross,self.anchor.cash))
    end
    return f
end
-- CASH_FLOW_END

return Core

-- CORE_END
end)()


end
