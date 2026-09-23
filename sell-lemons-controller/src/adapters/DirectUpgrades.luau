-- Direct stand upgrades. Prices come from verified literals and current replicated state.
-- Game modules are never required. Other purchase/reset adapters remain separate.
return function(ctx)
    local D={};ctx.DirectUpgrades=D;local M=ctx.UpgradeMath
    local counterKeys={'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'}
    local function child(o,n)return o and o:FindFirstChild(n)end
    local function attr(o,n)return o and o:GetAttribute(n)end
    local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
    local function number(n)return type(n)=='number' and n==n and n<math.huge end
    local function adler(bytes)
        local a,b=1,0
        for i=1,#bytes do a=(a+bytes:byte(i))%65521;b=(b+a)%65521 end
        return b*65536+a
    end
    function D.verify()
        if D.verified~=nil then return D.verified,D.reason end
        D.verified=false
        local reader=type(ctx.env.getscriptbytecode)=='function' and ctx.env.getscriptbytecode or getscriptbytecode
        if type(reader)~='function' then D.reason='BYTECODE_IDENTITY_UNAVAILABLE';return false,D.reason end
        local rs=game:GetService('ReplicatedStorage')
        for _,spec in ipairs({
            {'Balance',340421,914084511},{'Config',19699,154165715},
            {'Modules.Huge',8091,539421471},
            {'Modules.Tycoon.Component.TycoonValues',1214,285065225},
            {'Modules.Tycoon.Entity.TycoonEarner',5781,1426949448},
            {'Modules.Tycoon.Entity.Client.ClientTycoonEarner',9539,1200172661},
            {'Modules.Tycoon.Component.TycoonIncome',7049,3274092081},
            {'Modules.Tycoon.Component.TycoonPowers',3681,2346706770},
            {'Core.InstanceTable',13745,871009961},
            {'Modules.Tycoon.Component.TycoonInversion',4321,2891158939},
            {'Modules.Tycoon.Component.TycoonAscension',3824,2161590675},
            {'Modules.Tycoon.Component.Client.ClientTycoonPowers',1499,4053663912},
            {'Modules.Tycoon.Entity.Client.ClientTycoonPurchase',9384,2072785969},
            {'Modules.Tycoon.Entity.TycoonPurchase',3004,2893670776},
            {'Modules.Tycoon.Component.TycoonPurchases',2551,2335596492},
            {'Modules.UI.Layers.HUD.UIPowerBuyNext',4310,3175981909},
        })do
            local object=rs;for part in spec[1]:gmatch('[^.]+')do object=child(object,part)end
            local ok,bytes=pcall(reader,object)
            if not ok or type(bytes)~='string' or #bytes~=spec[2] or adler(bytes)~=spec[3] then
                D.reason='GAME_DATA_CHANGED '..spec[1];return false,D.reason
            end
        end
        D.verified=true;ctx.log('DIRECT_SCHEMA_VERIFIED','current game bytecode matches inspected price, income and upgrade signatures')
        return true
    end
    local function enabled(instance,root)
        local p=instance.Parent
        while p and p~=root do
            if p:HasTag('Tycoon.Purchasable') then return attr(p,'Enabled')==true end
            p=p.Parent
        end
        return false
    end
    function D.state()
        local valid,why=D.verify();if not valid then return nil,why end
        local world=game:GetService('Workspace');local own
        for _,root in ipairs(world:GetChildren())do
            if root.Name:match('^Tycoon%d+$') and attr(root,'Disabled')~=true then
                local owner=child(root,'Owner')
                if owner and owner:IsA('ObjectValue') and owner.Value==ctx.player then own=root;break end
            end
        end
        if not own then return nil,'OWNED_BASE_UNAVAILABLE' end
        local root=child(own,'Values');local values=child(root,'Values');local levels=child(root,'Upgrades');local powers=child(root,'Powers')
        if not values or not levels or not powers then return nil,'REPLICATED_TABLES_UNAVAILABLE' end
        local cash=attr(values,'Cash');local asc=attr(values,'Ascension') or 0
        if cash=='0' then cash=-math.huge end -- TycoonValues.GetHugeNumber zero sentinel
        if not number(cash) or not integer(asc) then return nil,'CASH_OR_ASCENSION_UNAVAILABLE' end
        local inversion=child(root,'InversionCards')
        -- InstanceTable.new(name, root, true) uses a detached empty Configuration
        -- until one is replicated. Main-world accounts with no inversion have no folder.
        if not inversion then
            if game.PlaceId~=79268393072444 or (attr(values,'Inversion') or 0)~=0 then return nil,'INVERSION_PRICE_STATE_UNAVAILABLE' end
        else
            for _,count in pairs(inversion:GetAttributes())do
                if count~=0 then return nil,'INVERSION_CARD_PRICING_NOT_VERIFIED' end
            end
            if #inversion:GetChildren()>0 then return nil,'INVERSION_CARD_SCHEMA_UNKNOWN' end
        end
        local level=(attr(powers,'UpgradeStack') or 0)+(attr(child(powers,'Permanent'),'UpgradeStack') or 0)
        local selected=attr(child(powers,'Selected'),'UpgradeStack')
        if not integer(level) or level>4 or selected~=nil and not integer(selected) then return nil,'STACK_LEVEL_UNKNOWN' end
        if selected~=nil then level=math.min(selected,level)end
        local cap=({[0]=1,5,25,100,math.huge})[level]
        local s={own=own,root=root,values=values,levels=levels,powers=powers,cash=cash,cap=cap,shift=asc*math.log10(3.33),epoch={},stands={},time=ctx.now()}
        for _,key in ipairs(counterKeys)do s.epoch[key]=attr(values,key)end
        local seen={}
        for _,instance in ipairs(game:GetService('CollectionService'):GetTagged('Tycoon.Earner'))do
            if instance:IsDescendantOf(own) and enabled(instance,own) then
                local name=instance.Name:gsub('[^%w]','');local n=attr(levels,name) or 0;local remote=child(instance,'Upgrade')
                if not ctx.GameBalance.UpgradePrices[name] or not integer(n) or n>=100000 or seen[name]
                    or not remote or not remote:IsA('RemoteFunction') then return nil,'STAND_SCHEMA_UNKNOWN '..name end
                seen[name]=true;s.stands[#s.stands+1]={name=name,level=n,instance=instance,remote=remote}
            end
        end
        table.sort(s.stands,function(a,b)return a.name<b.name end)
        if #s.stands>8 then return nil,'STAND_COUNT_CHANGED' end
        return s
    end
    function D.same(a,b)
        if not b or a.own~=b.own or a.values~=b.values or a.levels~=b.levels or a.cap~=b.cap or a.shift~=b.shift then return false end
        for _,key in ipairs(counterKeys)do if a.epoch[key]~=b.epoch[key] then return false end end
        return true
    end
    local function earnings(s,stand)
        local income=child(s.root,'Income');local stream=child(child(income,'Streams'),stand.name)
        if not stream or attr(stream,'Automatic')~=true then return nil,nil end
        local count=attr(stream,'Count');local value=attr(stream,'Value');local interval=attr(stream,'Interval')
        local globalValue=attr(income,'ValueMultiplier');local globalRate=attr(income,'RateMultiplier')
        local valueMult=attr(stream,'ValueMultiplier');local rateMult=attr(stream,'RateMultiplier')
        for _,n in ipairs({count,value,interval,globalValue,globalRate,valueMult,rateMult})do if not number(n)then return nil,nil end end
        if not number(count) or not number(value) or not number(interval) or not number(globalValue)
            or not number(globalRate) or not number(valueMult) or not number(rateMult) then return nil,nil end
        if count~=stand.level+1 then return nil,nil end -- Allow the replicated stream to catch up after a level receipt.
        local payout=value+M.countMultiplier(stand.name,count)+valueMult+globalValue
            +(attr(stream,'TempValueMultiplier') or 0)+(attr(income,'TempValueMultiplier') or 0)
        local period=interval-rateMult-globalRate-(attr(stream,'TempRateMultiplier') or 0)-(attr(income,'TempRateMultiplier') or 0)
        local seconds=10^period
        if seconds<=0 or seconds==math.huge then return nil,nil end
        return M.bn(payout),seconds
    end
    function D.quote(s,stand,count)
        local raw=M.price(stand.name,stand.level,count,s.shift);local income,seconds=earnings(s,stand)
        return {id='direct:'..stand.name..':'..stand.level,kind='upgrade',source='direct',key=stand.name,name=stand.instance.Name,
            path='direct/'..stand.name,count=tostring(stand.level),stack='+'..count,stackRaw='+'..count,
            units=count,cost=M.bn(raw),priceLog=raw,priceText=ctx.BN.format(M.bn(raw)),level=stand.level,
            maxMode=s.cap==math.huge,available=count>0 and raw<=s.cash,observedAt=s.time,order=0,
            income=income,periodSeconds=seconds,period=seconds and tostring(seconds) or '',snapshot=s,stand=stand}
    end
    function D.cards(s)
        local out={}
        for _,stand in ipairs(s.stands)do
            local n=M.affordable(stand.name,stand.level,s.cap,s.cash,s.shift)
            out[#out+1]=D.quote(s,stand,n)
        end
        return out
    end
    function D.allocate(s,rows)
        local reservations={};local total=-math.huge
        -- Initial equal shares preserve complete stand coverage. Remaining cash
        -- expands the strongest observed marginal return; unknown income stays last.
        local share=s.cash-math.log10(math.max(1,#rows))
        for _,row in ipairs(rows)do
            local n,p=M.affordable(row.key,row.level,s.cap,share,s.shift)
            reservations[#reservations+1]={row=row,n=n,price=p};total=M.add(total,p)
        end
        table.sort(reservations,function(a,b)
            local function score(x)
                local rate=ctx.Planner.sourceRate(x.row)
                if not rate or rate.m<=0 then return -math.huge end
                local n=x.row.level+1
                local delta=M.sub(M.countMultiplier(x.row.key,n+1),M.countMultiplier(x.row.key,n))
                return ctx.BN.log(rate)+delta-M.countMultiplier(x.row.key,n)-M.price(x.row.key,x.row.level,1,s.shift)
            end
            local av,bv=score(a),score(b);return av==bv and a.row.key<b.row.key or av>bv
        end)
        for _,entry in ipairs(reservations)do
            local others=-math.huge
            for _,other in ipairs(reservations)do if other~=entry then others=M.add(others,other.price)end end
            local budget=M.sub(s.cash,others)
            entry.n,entry.price=M.affordable(entry.row.key,entry.row.level,s.cap,budget,s.shift)
        end
        local out={};total=-math.huge
        for _,entry in ipairs(reservations)do
            if entry.n>0 then out[#out+1]=D.quote(s,entry.row.stand,entry.n);total=M.add(total,entry.price)end
        end
        assert(total<=s.cash,'DIRECT_SHARED_BUDGET_EXCEEDED')
        return out,total
    end
    function D.dispatch(rows,s)
        if #rows==0 then return true,{}end
        if not ctx.live() or ctx.S.actionPending or ctx.S.resetChildPending or ctx.S.resetSession then return false,'ACTION_PENDING' end
        local fresh,why=D.state();if not D.same(s,fresh) then return false,why or 'STATE_CHANGED' end
        local sum=-math.huge;local seen={}
        for _,c in ipairs(rows)do
            if seen[c.key] or not integer(c.units) or c.units<1 or c.units>s.cap or (attr(fresh.levels,c.key) or 0)~=c.level
                or not c.stand.instance:IsDescendantOf(fresh.own) or not enabled(c.stand.instance,fresh.own)
                or child(c.stand.instance,'Upgrade')~=c.stand.remote
                or M.price(c.key,c.level,c.units,fresh.shift)~=c.priceLog then return false,'QUOTE_CHANGED' end
            seen[c.key]=true;sum=M.add(sum,c.priceLog)
        end
        if sum>fresh.cash-1e-9 then return false,'QUOTE_UNAFFORDABLE'end
        local batch={pending=#rows,records={},started=ctx.now(),epoch=ctx.S.epoch};ctx.S.actionPending=batch
        D.batch=batch
        for _,c in ipairs(rows)do batch.records[#batch.records+1]={c=c,started=batch.started,sent=false}end
        ctx.log('DIRECT_BATCH_SENT','stands='..#rows..'; combined='..ctx.BN.format(M.bn(sum))..'; parallel Upgrade requests; no GUI')
        for _,rec in ipairs(batch.records)do
            task.spawn(function()
                local ok,err=pcall(function()
                    local current=D.state();assert(D.same(s,current),'STATE_CHANGED')
                    assert(ctx.live(batch.epoch),'PAUSED_BEFORE_DISPATCH')
                    assert((attr(current.levels,rec.c.key) or 0)==rec.c.level,'LEVEL_CHANGED')
                    assert(enabled(rec.c.stand.instance,current.own),'STAND_DISABLED')
                    rec.sent=true;rec.c.stand.remote:InvokeServer(rec.c.units)
                end)
                rec.returned=true;rec.ok=ok;rec.error=not ok and tostring(err) or nil;batch.pending=batch.pending-1
                if batch.waitEnded and batch.pending==0 and ctx.S.actionPending==batch then ctx.S.actionPending=nil end
            end)
        end
        repeat
            local current=D.state();local confirmed=0
            for _,rec in ipairs(batch.records)do
                if rec.returned and rec.ok and D.same(s,current) and (attr(current.levels,rec.c.key) or 0)==rec.c.level+rec.c.units then
                    rec.proved=true;confirmed=confirmed+1
                end
            end
            if batch.pending==0 and confirmed==#rows then break end
            task.wait(.05);ctx.S.actionYieldSerial=(ctx.S.actionYieldSerial or 0)+1
        until ctx.now()-batch.started>=8
        batch.waitEnded=true
        if batch.pending==0 and ctx.S.actionPending==batch then ctx.S.actionPending=nil end
        local all=true;local route=ctx.Strategy.route();route.blocked=route.blocked or {}
        local final=D.state()
        for _,rec in ipairs(batch.records)do
            local c=rec.c
            rec.proved=rec.proved and D.same(s,final) and (attr(final.levels,c.key) or 0)==c.level+c.units
            if rec.proved then
                ctx.progress('upgrade');ctx.Strategy.receipt(c,nil)
                if route.pass and not route.pass.finished then
                    route.pass.purchases=route.pass.purchases+1;route.pass.levels=route.pass.levels+c.units
                end
                ctx.log('DIRECT_UPGRADE_RECEIPT',c.key..' '..c.level..'->'..(c.level+c.units)..'; +'..c.units)
            elseif rec.sent then
                all=false;route.blocked[ctx.Safety.key(c)]={c=c,receipt=rec,reason='DIRECT_OUTCOME_UNRESOLVED'}
                ctx.log('DIRECT_UPGRADE_UNRESOLVED',c.key..'; no repeat; '..tostring(rec.error or 'replicated level did not confirm'))
            else all=false end
        end
        if #rows>0 then ctx.Strategy.recordTiming('upgrade',math.max(.001,ctx.now()-batch.started))end
        if not all then ctx.pause('DIRECT_BATCH_UNRESOLVED','Прямые улучшения не полностью подтверждены; повторов нет. Подробности в журнале.')end
        return all,batch.records
    end
    function D.purchase(c)
        local s,why=D.state();if not s then ctx.pause('DIRECT_STATE_UNAVAILABLE',why);return false end
        local all,records=D.dispatch({c},s)
        return all,all and records[1] or nil
    end
    function D.grow()
        local s,why=D.state()
        if not s then ctx.pause('DIRECT_STATE_UNAVAILABLE',tostring(why));return end
        local cards=D.cards(s);local r=ctx.Strategy.route();r.cards=cards;ctx.Strategy.quotes()
        if not r.pass or r.pass.finished then ctx.Strategy.beginPass(cards);r.pass.direct=true end
        local p=r.pass
        if not p.direct then ctx.pause('DIRECT_PASS_MODE_CHANGED','Перезапусти фарм для нового режима прохода.');return end
        if ctx.Strategy.stopForBlocked() then return end
        ctx.Strategy.captureGrowth(cards)
        if ctx.Strategy.maybeCapabilityReview(cards) then return end
        local pending={};local present={};for _,c in ipairs(cards)do present[c.path]=c end
        for i=p.index,#p.order do
            local c=present[p.order[i].path]
            if not c then ctx.pause('DIRECT_STAND_UNAVAILABLE',p.order[i].name..'; проход сохранён');return end
            pending[#pending+1]=c
        end
        local quotes=D.allocate(s,pending)
        local ok=D.dispatch(quotes,s)
        if not ok then return end
        p.index=#p.order+1
        local after,err=D.state();if not D.same(s,after) then ctx.pause('DIRECT_STATE_CHANGED',tostring(err or 'Состояние изменилось'));return end
        ctx.Strategy.finishPass(D.cards(after))
    end
    local guiCards=ctx.readCards
    local guiManage=ctx.manageTab;local guiFocus=ctx.focusCandidate;local guiCash=ctx.cash
    function ctx.manageTab(name,...)
        if name=='Manage' and ctx.CONFIG.DirectUpgrades then
            local s,why=D.state();return s~=nil,why
        end
        return guiManage(name,...)
    end
    function ctx.focusCandidate(c)
        if c.source~='direct' then return guiFocus(c)end
        local s,why=D.state();if not s then return nil,why end
        for _,stand in ipairs(s.stands)do
            if stand.name==c.key and stand.level==c.level and c.units<=s.cap then return D.quote(s,stand,c.units)end
        end
        return nil,'QUOTE_CHANGED_AFTER_NAVIGATION'
    end
    function ctx.cash()
        if not ctx.CONFIG.DirectUpgrades then return guiCash()end
        local ok,s=pcall(D.state)
        if ok and s then return M.bn(s.cash)end
        return guiCash()
    end
    function ctx.readCards()
        if not ctx.CONFIG.DirectUpgrades then return guiCards()end
        local ok,s,why=pcall(D.state)
        if not ok then return {},tostring(s)end
        return s and D.cards(s) or {},why
    end
    function ctx.API.directReport()
        local ok,s,why=pcall(D.state)
        if not ok or not s then return '[SL HEADLESS] unavailable: '..tostring(ok and why or s)end
        local out={'[SL HEADLESS] '..s.own.Name..'; cashLog='..s.cash..'; cap='..s.cap..'; priceShift='..s.shift}
        for _,c in ipairs(D.cards(s))do out[#out+1]=c.key..' level='..c.level..' count='..c.units..' costLog='..c.priceLog..' income='..ctx.BN.format(c.income)..' period='..c.period end
        return table.concat(out,'\n')
    end
end
