-- Verified Powers and ordinary Buy actions; the controller still owns decisions.
return function(ctx)
    local A={};ctx.DirectPurchases=A;local D=ctx.DirectUpgrades;local M=ctx.UpgradeMath
    local function child(o,n)return o and o:FindFirstChild(n)end
    local function attr(o,n)return o and o:GetAttribute(n)end
    local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
    local function same(a,b)
        if not b or a.own~=b.own or a.values~=b.values or a.root~=b.root then return false end
        for _,k in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do if a.epoch[k]~=b.epoch[k]then return false end end
        return true
    end
    -- Only replicated reset counters establish a new cycle. A lower wallet or
    -- missing UI alone cannot resolve an unknown purchase in the current cycle.
    function A.laterReset(a,b)
        if not a or not b or a.own~=b.own or a.root~=b.root or a.values~=b.values then return nil end
        local x,y=a.epoch,b.epoch
        local function increased(k)return integer(x[k]) and integer(y[k]) and y[k]>x[k]end
        local function equal(k)return integer(x[k]) and x[k]==y[k]end
        if increased('Ascension')then return 'halo' end
        if not equal('Ascension')then return nil end
        if increased('TotalEvolves') or increased('Evolution')then return 'evolve' end
        if not equal('Evolution')then return nil end
        if increased('TotalRebirths') or increased('Rebirths')then return 'rebirth' end
    end
    function A.refreshEpoch()
        if ctx.S.actionPending or ctx.S.resetChildPending or ctx.S.resetSession or ctx.S.buyHold then return false,'ACTION_PENDING' end
        local s,why=D.state();if not s then return false,why end
        local r=ctx.Strategy.route();local prior=r.directEpoch
        if not prior then
            for _,v in pairs(r.blocked or {})do
                if v.c and A.laterReset(v.c.snapshot,s)then prior=v.c.snapshot;break end
            end
            local item=r.powerUnresolved and r.powerUnresolved.item
            if not prior and item and A.laterReset(item.snapshot,s)then prior=item.snapshot end
        end
        local kind=A.laterReset(prior,s)
        if kind then
            -- Build a clean observation route, without recording our own reset
            -- receipt or treating an obsolete purchase as successful.
            local fresh=ctx.Strategy.new();fresh.blocked={}
            for key,v in pairs(r.blocked or {})do
                if not A.laterReset(v.c and v.c.snapshot,s)then fresh.blocked[key]=v end
            end
            local item=r.powerUnresolved and r.powerUnresolved.item
            if item and not A.laterReset(item.snapshot,s)then fresh.powerUnresolved=r.powerUnresolved end
            if kind=='rebirth' then
                for _,key in ipairs({'spent','spentUnknown','powerBase','powerUsed','powerBank','powerSkipped'})do fresh[key]=r[key]end
            end
            fresh.cleanRun=false;fresh.reason='external '..kind;fresh.directEpoch=s
            ctx.S.route=fresh;A.map=nil
            ctx.S.tablet=nil;ctx.S.prestige=nil;ctx.S.catalog={};ctx.S.catalogDirty=true
            ctx.S.incomeAttempts={};ctx.S.nextIncomeAt=0;ctx.S.upgradeVisited={}
            if ctx.S.rate then ctx.S.rate:reset()end
            if ctx.S.cashFlow then ctx.S.cashFlow:reset()end
            if ctx.Observer then ctx.Observer.store:invalidate('external '..kind)end
            ctx.log('EXTERNAL_RESET_OBSERVED',kind..'; discarded old observations; no reset or purchase receipt credited')
        elseif prior and not same(prior,s)then
            return false,'RESET_STATE_TRANSITION'
        else r.directEpoch=s end
        return true
    end
    local oldStep=ctx.step
    if oldStep then
        function ctx.step()
            if ctx.CONFIG.DirectPurchases then
                local ready,why=A.refreshEpoch()
                if not ready then
                    if why~='ACTION_PENDING' then ctx.pause('DIRECT_STATE_UNAVAILABLE',tostring(why))end
                    return
                end
            end
            return oldStep()
        end
    end
    local oldReset=ctx.Strategy.afterReset
    if oldReset then
        function ctx.Strategy.afterReset(kind,before)
            oldReset(kind,before)
            ctx.Strategy.route().directEpoch=D.state()
            A.map=nil
        end
    end
    local function powerLevel(s,name)
        local temporary=attr(s.powers,name) or 0;local permanent=attr(child(s.powers,'Permanent'),name) or 0
        if not integer(temporary) or not integer(permanent) then return nil end
        return temporary+permanent,permanent
    end
    function A.wallet()
        local s,why=D.state();if not s then return nil,why end
        local raw=attr(s.values,'Investors')
        local bank=raw=='0' and {m=0,e=0} or M.bn(raw);if not bank then return nil,'INVESTORS_UNAVAILABLE' end
        return {investors=bank,time=ctx.now()},s
    end
    function A.powers()
        local wallet,s=A.wallet();if not wallet then return {} end
        local out={}
        for name,data in pairs(ctx.GameBalance.Powers)do
            local level,permanent=powerLevel(s,name)
            local price=level and data.Prices[level+1]
            if name~='Manage' and data.World=='Main' and price then
                local raw=math.log10(price)
                local bonus=name=='UpgradeStack' and ({[0]='+1','+5','+25','+100','max'})[level] or tostring(level)
                out[#out+1]={source='directPower',name=name,title=data.Title,path='directPower/'..name,
                    level=level,permanent=permanent,price=M.bn(raw),priceLog=raw,priceText=ctx.BN.format(M.bn(raw)),
                    bonus=bonus,info='',available=ctx.BN.cmp(M.bn(raw),wallet.investors)<=0,observedAt=ctx.now(),snapshot=s}
            end
        end
        table.sort(out,function(a,b)
            if a.name=='UpgradeStack' or b.name=='UpgradeStack' then return a.name=='UpgradeStack' and b.name~='UpgradeStack' end
            return a.priceLog==b.priceLog and a.name<b.name or a.priceLog<b.priceLog
        end)
        return out
    end
    function A.powerProof(item)
        local s=D.state();if not same(item.snapshot,s)then return false end
        local level,permanent=powerLevel(s,item.name)
        return permanent==item.permanent and level==item.level+1
    end
    local function purchased(s,key)
        local p=child(s.root,'Purchases');return p and attr(p,key)==true
    end
    local function purchaseMap(s)
        if A.mapOwner~=s.own or not A.map or ctx.now()-(A.mapAt or 0)>2 then
            local map={}
            for _,o in ipairs(game:GetService('CollectionService'):GetTagged('Tycoon.Purchase'))do
                if o:IsDescendantOf(s.own)then
                    local key=o.Name:gsub('[^%w]','')
                    if map[key] then return nil,'DUPLICATE_PURCHASE '..key end
                    map[key]=o
                end
            end
            A.map=map;A.mapOwner=s.own;A.mapAt=ctx.now()
        end
        return A.map
    end
    function A.buyQuote()
        local s,why=D.state();if not s then return nil,why end
        if not child(s.root,'Purchases') then return nil,'PURCHASE_STATE_UNAVAILABLE' end
        local map,err=purchaseMap(s);if not map then return nil,err end
        local all=true
        for index,key in ipairs(ctx.GameBalance.PurchaseOrder)do
            if not purchased(s,key) then
                all=false;local o=map[key]
                if o and o:IsDescendantOf(s.own) and attr(o,'Enabled')==true then
                    -- ClientTycoonPurchase.TryPurchaseAsync forces permanent=false
                    -- for Special. Ordinary cash purchases use the same remote.
                    local raw=ctx.GameBalance.PurchasePrices[key]
                    local remote=child(o,'Purchase')
                    if type(raw)~='number' or not remote or not remote:IsA('RemoteFunction') then return nil,'BUY_SCHEMA_UNKNOWN '..key end
                    local level=powerLevel(s,'BuyNext');local used=attr(s.values,'BuyNextUses') or 0
                    if not level or not integer(used) then return nil,'BUY_USES_UNKNOWN' end
                    local capacity=({[0]=0,150,250,math.huge})[math.min(3,level)]
                    local title=o:FindFirstChild('Title',true);local category=o:FindFirstChild('Category',true)
                    local name=title and title:IsA('TextLabel') and title.Text or attr(o,'DisplayName') or o.Name
                    local info=category and category:IsA('TextLabel') and category.Text or ''
                    raw=raw+s.shift
                    return {id='directBuy:'..key,source='directBuy',kind='buy',key=key,name=name,
                        path='directBuy/'..key,instance=o,remote=remote,cost=M.bn(raw),priceLog=raw,priceText=ctx.BN.format(M.bn(raw)),
                        info=info,multiplier=ctx.Core.multiplier(info),newSource=ctx.GameBalance.EarnerIncomes[key]~=nil,
                        available=raw<=s.cash and capacity>used,uses=tostring(capacity-used),observedAt=ctx.now(),snapshot=s,catalogueIndex=index}
                end
            end
        end
        return nil,all and 'COMPLETE' or 'BUY_NOT_REPLICATED_OR_ENABLED'
    end
    function A.buyProof(c)
        local s=D.state();return same(c.snapshot,s) and purchased(s,c.key)
    end
    -- Single request, bounded observation. A timeout keeps the pending lock until
    -- the actual call ends. Unknown outcomes are never retried automatically.
    local function execute(c,validate,invoke,proof)
        if not ctx.live() or ctx.S.actionPending or ctx.S.resetChildPending or ctx.S.resetSession then return false,'STATE_CHANGED_BEFORE_CLICK' end
        if not validate() then return false,'STATE_CHANGED_BEFORE_CLICK' end
        local rec={c=c,started=ctx.now(),epoch=ctx.S.epoch,sent=false};ctx.S.actionPending=rec
        task.spawn(function()
            rec.ok,rec.error=pcall(function()
                assert(ctx.live(rec.epoch) and validate(),'STATE_CHANGED_BEFORE_DISPATCH')
                rec.sent=true;invoke()
            end)
            rec.returned=true
            if rec.waitEnded and ctx.S.actionPending==rec then ctx.S.actionPending=nil end
        end)
        repeat
            if rec.returned and (not rec.ok or proof())then break end
            task.wait(.05);ctx.S.actionYieldSerial=(ctx.S.actionYieldSerial or 0)+1
        until ctx.now()-rec.started>=8
        rec.waitEnded=true
        if rec.returned and ctx.S.actionPending==rec then ctx.S.actionPending=nil end
        if not rec.sent then return false,'STATE_CHANGED_BEFORE_CLICK',rec end
        local done=rec.returned and rec.ok and proof()
        ctx.log(done and 'DIRECT_ACTION_RECEIPT' or 'DIRECT_ACTION_UNRESOLVED',c.source..' '..c.name..'; no GUI; '..tostring(rec.error or 'replicated state checked'))
        return done,done and nil or 'DIRECT_OUTCOME_UNRESOLVED',rec
    end
    function A.powerPurchase(item)
        local remote
        local function validate()
            local wallet,s=A.wallet();if not wallet or not same(item.snapshot,s)then return false end
            local level,permanent=powerLevel(s,item.name);local r=ctx.Strategy.route()
            remote=child(child(s.own,'Remotes'),'UpgradePowerLevel')
            return ctx.CONFIG.AutoInvestorPowers and level==item.level and permanent==item.permanent
                and remote and remote:IsA('RemoteFunction') and math.log10(ctx.GameBalance.Powers[item.name].Prices[level+1])==item.priceLog
                and ctx.Planner.powerBudgetAllows(item.price,wallet.investors,r.powerUsed,r.powerBase,ctx.CONFIG)
        end
        return execute(item,validate,function()remote:InvokeServer(item.name,1)end,function()return A.powerProof(item)end)
    end
    function A.buy(c)
        local function validate()
            local q=A.buyQuote()
            return q and same(c.snapshot,q.snapshot) and q.key==c.key and q.instance==c.instance and q.remote==c.remote
                and q.priceLog==c.priceLog and q.available
        end
        local done,why,rec=execute(c,validate,function()c.remote:InvokeServer(true,false)end,function()return A.buyProof(c)end)
        if done then ctx.Safety.commit(rec);return true,rec end
        if rec and rec.sent then
            local r=ctx.Strategy.route();r.blocked[ctx.Safety.key(c)]={c=c,receipt=rec,reason=why}
            ctx.pause('DIRECT_BUY_UNRESOLVED','Покупка отправлена один раз; ожидаю подтверждение в данных базы.')
        end
        return false,rec
    end
    local guiRead=ctx.readBuy;local guiStrip=ctx.ensureStrip;local guiManage=ctx.manageTab
    local guiPowerRead=ctx.Powers.read;local guiPowerProof=ctx.Powers.proof;local guiTablet=ctx.ensureTablet
    local oldPurchase=ctx.Strategy.safePurchase;local oldProof=ctx.Safety.proof;local oldFocus=ctx.focusCandidate;local oldHold=ctx.HaloRun.tryBuyHold
    function ctx.readBuy()if ctx.CONFIG.DirectPurchases then return A.buyQuote()end;return guiRead()end
    function ctx.ensureStrip()if ctx.CONFIG.DirectPurchases then local s,why=D.state();return s~=nil,why end;return guiStrip()end
    function ctx.manageTab(name,...)
        if name=='Powers' and ctx.CONFIG.DirectPurchases then local s,why=D.state();return s~=nil,why end
        return guiManage(name,...)
    end
    function ctx.Powers.read()if ctx.CONFIG.DirectPurchases then return A.powers()end;return guiPowerRead()end
    function ctx.Powers.proof(c)if c.source=='directPower' then return A.powerProof(c)end;return guiPowerProof(c)end
    function ctx.Powers.wallet()if ctx.CONFIG.DirectPurchases then return A.wallet()end;return ctx.Strategy.readInvestors()end
    function ctx.ensureTablet()
        if not ctx.CONFIG.DirectPurchases then return guiTablet()end
        local s,why=D.state();if not s then return false,why end
        ctx.S.tablet={owned=(powerLevel(s,'Manage') or 0)>0,time=ctx.now()}
        return true -- Direct upgrades do not require purchasing Manage.
    end
    function ctx.Strategy.safePurchase(c)
        if c.source=='directBuy' then
            if (ctx.Strategy.route().blocked or {})[ctx.Safety.key(c)]then return false end
            return A.buy(c)
        end
        return oldPurchase(c)
    end
    function ctx.Safety.proof(rec)if rec.c.source=='directBuy' then return A.buyProof(rec.c)end;return oldProof(rec)end
    function ctx.focusCandidate(c)
        if c.source=='directBuy' then local q=A.buyQuote();if q and q.key==c.key then return q end;return nil,'QUOTE_CHANGED' end
        return oldFocus(c)
    end
    function ctx.HaloRun.tryBuyHold(c)if c.source=='directBuy' then return false end;return oldHold(c)end
    function ctx.buyComplete()
        if ctx.CONFIG.DirectPurchases then local _,why=A.buyQuote();return why=='COMPLETE' end
        return ctx.Planner.completionMarker(ctx.t(ctx.paths.buy..'/Purchase'),ctx.t(ctx.paths.buy..'/PurchasePrice'),ctx.t(ctx.paths.buy..'/PurchaseInfo'))
    end
    function ctx.canUpgrade()return ctx.CONFIG.DirectUpgrades or ctx.S.tablet and ctx.S.tablet.owned end
    local upgradeReport=ctx.API and ctx.API.directReport
    if upgradeReport then
        function ctx.API.directReport()
            local out={upgradeReport()};local q,why=A.buyQuote()
            out[#out+1]='[SL HEADLESS BUY] '..(q and (q.key..'; costLog='..q.priceLog..'; available='..tostring(q.available)..'; uses='..q.uses) or tostring(why))
            for _,p in ipairs(A.powers())do
                out[#out+1]='[SL HEADLESS POWER] '..p.name..'; level='..p.level..'; nextPriceLog='..p.priceLog..'; funded='..tostring(p.available)
            end
            return table.concat(out,'\n')
        end
    end
end
