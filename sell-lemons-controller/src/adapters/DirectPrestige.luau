-- Replicated prestige observations and verified ordinary reset transactions.
return function(ctx)
    local P={};ctx.DirectPrestige=P;local D=ctx.DirectUpgrades;local M=ctx.UpgradeMath
    local function child(o,n)return o and o:FindFirstChild(n)end
    local function attr(o,n)return o and o:GetAttribute(n)end
    local function integer(v)return type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
    local function amount(value)
        if value==nil then return {m=0,e=0} end
        return M.bn(value)
    end
    function P.verify()
        if P.verified~=nil then return P.verified,P.reason end
        P.verified=false
        local reader=type(ctx.env.getscriptbytecode)=='function' and ctx.env.getscriptbytecode or getscriptbytecode
        if type(reader)~='function' then P.reason='BYTECODE_IDENTITY_UNAVAILABLE';return false,P.reason end
        local rs=game:GetService('ReplicatedStorage')
        for _,spec in ipairs({
            {'Modules.Tycoon.Component.TycoonBalances',4280,537675623},
            {'Modules.Tycoon.Component.TycoonValues',1214,285065225},
            {'Modules.Tycoon.Component.TycoonRebirth',6310,4193420756},
            {'Modules.Tycoon.Component.Client.ClientTycoonRebirth',1232,3294875325},
            {'Modules.Tycoon.Component.TycoonEvolution',6812,3704414728},
            {'Modules.Player.PremiumPurchases',2741,3733814504},
            {'Config.PlaceDifferences',128,3292598373},
            {'Modules.Service.PlaceDifferenceService',1131,2205924379},
        })do
            local o=rs;for part in spec[1]:gmatch('[^.]+')do o=child(o,part)end
            local ok,bytes=pcall(reader,o);local a,b=1,0
            if ok and type(bytes)=='string' and #bytes==spec[2]then
                for i=1,#bytes do a=(a+bytes:byte(i))%65521;b=(b+a)%65521 end
            else a,b=0,0 end
            if b*65536+a~=spec[3]then P.reason='PRESTIGE_DATA_CHANGED '..spec[1];return false,P.reason end
        end
        P.verified=true;ctx.log('DIRECT_PRESTIGE_VERIFIED','rebirth/evolution formulas and Main world overrides match inspected client')
        return true
    end
    function P.snapshot()
        local valid,why=P.verify();if not valid then return nil,why end
        if game.PlaceId~=79268393072444 then return nil,'UNSUPPORTED_PRESTIGE_WORLD' end
        local s,err=D.state();if not s then return nil,err end
        -- Verified GetRebirths/GetEvolution/GetAscension and lifetime getters
        -- return zero when the corresponding attribute is absent.
        s=table.clone(s);s.epoch=table.clone(s.epoch)
        for _,key in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do
            if s.epoch[key]==nil then s.epoch[key]=0 end
            if not integer(s.epoch[key])then return nil,'PRESTIGE_COUNTER_UNAVAILABLE '..key end
        end
        local data={snapshot=s}
        for _,key in ipairs({'Cash','CashSpent','Investors','InvestorsSpent'})do
            local raw=attr(s.values,key)
            if raw=='0' or raw==-math.huge then raw=nil end -- TycoonValues.GetHugeNumber
            -- GetHugeNumber defaults absent attributes to Huge.zero. Do not
            -- create -infinity and send it through the ordinary BN converter.
            if raw~=nil and not M.bn(raw)then
                return nil,'PRESTIGE_BALANCE_INVALID '..key..' type='..type(raw)..' value='..tostring(raw)
            end
            data[key]=raw
        end
        data.reward=ctx.PrestigeMath.reward(data.Cash,data.CashSpent,data.Investors,data.InvestorsSpent)
        return data
    end
    function P.wallet()
        local data=P.snapshot();return data and amount(data.Investors)
    end
    function P.investors()
        local data,why=P.snapshot();if not data then return nil,why end
        local purchases=child(game:GetService('Players').LocalPlayer,'Purchases')
        if not purchases then return nil,'INVESTOR_BOOST_STATE_UNAVAILABLE' end
        local boosts=attr(purchases,'InvestorBoost') or 0
        if not integer(boosts) or boosts>4 then return nil,'INVESTOR_BOOST_UNKNOWN' end
        local extra=attr(data.snapshot.values,'ExtraInvestorBoost')
        if extra~=nil and type(extra)~='boolean' then return nil,'INVESTOR_BOOST_UNKNOWN' end
        local bonus=.01*2^(boosts+(extra and 1 or 0))
        local r=ctx.Strategy.route();r.spent=amount(data.InvestorsSpent);r.spentUnknown=false
        return {investors=amount(data.Investors),reward=amount(data.reward),perInvestor=bonus,
            bonusText='+'..tostring(bonus*100)..'% cash',ready=data.reward~=nil and data.reward>=0,time=ctx.now(),
            source='replicated-prestige',snapshot=data.snapshot,investorsSpent=amount(data.InvestorsSpent)}
    end
    function P.evolution()
        local data,why=P.snapshot();if not data then return nil,why end
        local index=data.snapshot.epoch.Evolution
        local progress,bonus,target,total=ctx.PrestigeMath.evolution(index,data.Investors,data.InvestorsSpent,data.reward)
        local names={'Lemon','Orange','Lime','Grapefruit','Tangerine','Pomelo','Abyssalime','Nullfruit','Voidlemon','Purity'}
        local fruit=names[index+1] or ('Purity+'..tostring(index-9))
        return {index=index,pct=progress*100,ready=progress>=1,bonusVisible=progress>=1,bonus=amount(bonus),
            bonusIsInvestors=true,fresh=true,time=ctx.now(),fruit=fruit,source='replicated-prestige',
            snapshot=data.snapshot,targetLog=target,totalLog=total}
    end
    function P.halo()
        local data,why=P.snapshot();if not data then return nil,why end
        local ledger=child(data.snapshot.root,'Purchases');if not ledger then return nil,'PURCHASE_STATE_UNAVAILABLE' end
        local count=0;local bought=ledger:GetAttributes()
        for _,o in ipairs(ledger:GetChildren())do
            if o:IsA('BoolValue')then bought[o.Name]=o.Value end
        end
        for _,value in pairs(bought)do if value==true then count=count+1 end end
        local required=#ctx.GameBalance.PurchaseOrder
        return {amount=data.snapshot.epoch.Ascension,ready=count>=required,time=ctx.now(),
            objective=tostring(count)..'/'..required..' purchases',source='replicated-prestige',snapshot=data.snapshot}
    end
    local oldInvestors,oldEvolution,oldHalo=ctx.readInvestors,ctx.readEvolution,ctx.readHalo
    function ctx.readInvestors()if ctx.CONFIG.DirectPrestige then return P.investors()end;return oldInvestors()end
    function ctx.readEvolution()if ctx.CONFIG.DirectPrestige then return P.evolution()end;return oldEvolution()end
    function ctx.readHalo()if ctx.CONFIG.DirectPrestige then return P.halo()end;return oldHalo()end
    local oldPeek=ctx.Strategy.peekResetInvestors
    function ctx.Strategy.peekResetInvestors(...)
        if ctx.CONFIG.DirectPrestige then return P.investors()end
        return oldPeek(...)
    end
    local function sameCycle(a,b)
        if not b or a.own~=b.own or a.root~=b.root or a.values~=b.values then return false end
        for _,k in ipairs({'Evolution','Ascension','Rebirths','TotalRebirths','TotalEvolves'})do if a.epoch[k]~=b.epoch[k]then return false end end
        return true
    end
    -- Captured v6916 UI -> client component -> RemoteRequest chain. Validate
    -- these separately so an updated reset UI cannot disable ordinary upgrades.
    function P.verifyReset(kind)
        P.resetSchemas=P.resetSchemas or {}
        local cached=P.resetSchemas[kind];if cached then return cached.ok,cached.reason end
        local row={ok=false};P.resetSchemas[kind]=row
        local reader=type(ctx.env.getscriptbytecode)=='function' and ctx.env.getscriptbytecode or getscriptbytecode
        if type(reader)~='function'then row.reason='BYTECODE_IDENTITY_UNAVAILABLE';return false,row.reason end
        local specs=kind=='evolve' and {
            {'Modules.UI.Layers.Rebirth.UIEvolutionMenu',7634,4240708282},
            {'Modules.Tycoon.Component.Client.ClientTycoonEvolution',1229,3782527611},
        } or {
            {'Modules.UI.Layers.Rebirth.UIAscensionMenu',11995,1534588081},
            {'Modules.Tycoon.Component.Client.ClientTycoonAscension',1176,3761947570},
        }
        specs[#specs+1]={'Core.RemoteRequest',4201,653841906}
        for _,spec in ipairs(specs)do
            local o=game:GetService('ReplicatedStorage');for part in spec[1]:gmatch('[^.]+')do o=child(o,part)end
            local ok,bytes=pcall(reader,o);local a,b=1,0
            if ok and type(bytes)=='string' and #bytes==spec[2]then
                for i=1,#bytes do a=(a+bytes:byte(i))%65521;b=(b+a)%65521 end
            else a,b=0,0 end
            if b*65536+a~=spec[3]then row.reason='RESET_PROTOCOL_CHANGED '..spec[1];return false,row.reason end
        end
        row.ok=true;ctx.log('DIRECT_RESET_PROTOCOL_VERIFIED',kind..'; ordinary request; no GUI')
        return true
    end
    function P.resetProof(rec)
        local after=P.snapshot();local b=after and after.snapshot;local a=rec.before.snapshot
        if not b or a.own~=b.own or a.root~=b.root or a.values~=b.values then return false end
        local x,y=a.epoch,b.epoch
        if y.TotalRebirths~=x.TotalRebirths or y.Rebirths~=0 then return false end
        if rec.kind=='evolve'then
            return y.Ascension==x.Ascension and y.Evolution==x.Evolution+1 and y.TotalEvolves==x.TotalEvolves+1
        elseif rec.kind=='halo'then
            return y.Ascension==x.Ascension+1 and y.Evolution==0 and y.TotalEvolves==x.TotalEvolves
        end
        return false
    end
    function P.reset(kind)
        if kind~='evolve' and kind~='halo'then return false end
        local S=ctx.S;local r=ctx.Strategy.route();local option=kind=='evolve' and 'AutoEvolution' or 'AutoHalo'
        local function live()return ctx.live() and S.resetEnabled and ctx.CONFIG[option]end
        if not live() or S.actionPending or S.resetSession or S.resetChildPending or S.buyHold then return false end
        if r.directResetUnresolved then ctx.pause('DIRECT_RESET_UNRESOLVED','Прежний сброс ещё не подтверждён.');return false end
        local verified,why=P.verifyReset(kind);if not verified then ctx.Strategy.noteResetAbort(why);return false end
        if ctx.ResetInspection then pcall(ctx.ResetInspection.inspectSources,kind)end
        local function observe()if kind=='evolve'then return P.evolution()end;return P.halo()end
        local function allowed(before)
            if not before then return false,'RESET_DATA_UNAVAILABLE' end
            if kind=='halo'then return before.ready,'HALO_NOT_READY'end
            local ready,reason=ctx.Core.evolutionGuard(before,ctx.CONFIG.EvolutionMinimumBank)
            if not ready then return false,reason end
            if ctx.HaloRun and ctx.HaloRun.deferEvolution then
                local hold,reason=ctx.HaloRun.deferEvolution(true);if hold then return false,reason end
            end
            return true
        end
        local before=observe();local ready,reason=allowed(before)
        if not ready then ctx.Strategy.noteResetAbort(reason);return false end
        if kind=='evolve'then
            if not ctx.sleep(ctx.CONFIG.EvolutionReadyDelay)then return false end
            local fresh=observe()
            if not fresh or not sameCycle(before.snapshot,fresh.snapshot)then return false end
            before=fresh;ready,reason=allowed(before)
            if not ready then ctx.Strategy.noteResetAbort(reason);return false end
        end
        if not live() or S.actionPending or S.resetSession or S.resetChildPending or S.buyHold then return false end
        local name=kind=='evolve' and 'Evolve' or 'Ascend'
        local remote=child(child(before.snapshot.own,'Remotes'),name)
        if not remote or not remote:IsA('RemoteFunction')then ctx.pause('RESET_REMOTE_UNAVAILABLE',name..' отсутствует.');return false end
        local rec={kind=kind,before=before,epoch=S.epoch,started=ctx.now(),sent=false};S.actionPending=rec
        task.spawn(function()
            rec.ok,rec.error=pcall(function()
                local current=observe()
                assert(not rec.waitEnded and ctx.live(rec.epoch) and live(),'PAUSED_BEFORE_DISPATCH')
                assert(current and sameCycle(before.snapshot,current.snapshot),'PRESTIGE_STATE_CHANGED')
                local permitted,reason=allowed(current);assert(permitted,reason or 'RESET_INTENT_CHANGED')
                assert(child(child(current.snapshot.own,'Remotes'),name)==remote,'RESET_REMOTE_CHANGED')
                rec.sent=true;r.transactionStartedAt=ctx.now()
                if r.halo30 then r.halo30.resetInFlight=kind end
                r.lastResetExecution={stage='dispatched',reason=kind,at=ctx.now()}
                ctx.log('DIRECT_'..kind:upper()..'_SENT','ordinary request; no GUI')
                if ctx.ResetInspection then pcall(ctx.ResetInspection.direct,kind,'sent',rec)end
                if kind=='evolve'then remote:InvokeServer(nil)else remote:InvokeServer()end
            end)
            rec.returned=true
            if rec.waitEnded and S.actionPending==rec then S.actionPending=nil end
        end)
        repeat
            if rec.returned and (not rec.ok or P.resetProof(rec))then break end
            task.wait(.05);S.actionYieldSerial=(S.actionYieldSerial or 0)+1
        until ctx.now()-rec.started>=ctx.CONFIG.ResetTimeout
        rec.waitEnded=true
        if rec.returned and S.actionPending==rec then S.actionPending=nil end
        if not rec.sent then
            r.lastResetExecution={stage='not-dispatched',reason=kind,at=ctx.now()}
            ctx.Strategy.noteResetAbort(tostring(rec.error or 'NOT_DISPATCHED'));return false
        end
        if not rec.returned or not rec.ok or not P.resetProof(rec)then
            r.directResetUnresolved=rec
            r.lastResetExecution={stage='unresolved',reason=kind,at=ctx.now(),error=rec.error}
            ctx.pause('DIRECT_RESET_UNRESOLVED',name..' отправлен один раз; изменение счётчиков не подтверждено: '..tostring(rec.error))
            if ctx.ResetInspection then pcall(ctx.ResetInspection.direct,kind,'unresolved',rec)end
            return false
        end
        if r.halo30 then r.halo30.resetInFlight=nil end
        local duration=math.max(.01,ctx.now()-rec.started)
        r.lastResetExecution={stage='confirmed',reason=kind,at=ctx.now()};r.resetDuration=duration
        ctx.Strategy.recordTiming(kind,duration);ctx.Strategy.afterReset(kind,before)
        ctx.progress(kind);ctx.log('DIRECT_'..kind:upper()..'_RECEIPT','exact reset counters verified; no GUI')
        if ctx.ResetInspection then pcall(ctx.ResetInspection.direct,kind,'receipt',rec)end
        S.runStart=ctx.now();S.lastRefresh=-math.huge;S.lastPowers=-math.huge
        ctx.sleep(ctx.CONFIG.AfterResetWait);return true
    end
    function P.rebirthProof(rec)
        local after=P.snapshot();local b=after and after.snapshot;local a=rec.before.snapshot
        return b and a.own==b.own and a.root==b.root and a.values==b.values
            and a.epoch.Evolution==b.epoch.Evolution and a.epoch.Ascension==b.epoch.Ascension
            and a.epoch.TotalEvolves==b.epoch.TotalEvolves
            and b.epoch.Rebirths==a.epoch.Rebirths+1 and b.epoch.TotalRebirths==a.epoch.TotalRebirths+1
    end
    function P.rebirth()
        local S=ctx.S;local r=ctx.Strategy.route()
        if not ctx.live() or not S.resetEnabled or not ctx.CONFIG.AutoRebirth or S.actionPending or S.resetSession or S.resetChildPending or S.buyHold then return false end
        if r.directResetUnresolved then ctx.pause('DIRECT_RESET_UNRESOLVED','Прежний запрос rebirth не подтверждён; повтор не отправлен.');return false end
        local before,why=P.investors();if not before then ctx.Strategy.noteResetAbort(why);return false end
        local evolution=P.evolution();if not evolution or not sameCycle(before.snapshot,evolution.snapshot)then return false end
        r.evo=evolution
        local permitted,reason=ctx.Strategy.rebirthBarrier(before)
        if not permitted or not before.ready then ctx.Strategy.noteResetAbort(reason or 'REBIRTH_NOT_READY');return false end
        local recovery=ctx.Strategy.makeRecovery(before)
        local rec={kind='rebirth',before=before,epoch=S.epoch,started=ctx.now(),sent=false};S.actionPending=rec
        local remote=child(child(before.snapshot.own,'Remotes'),'Rebirth')
        if not remote or not remote:IsA('RemoteFunction')then S.actionPending=nil;ctx.pause('REBIRTH_REMOTE_UNAVAILABLE','Обработчик Rebirth отсутствует.');return false end
        task.spawn(function()
            rec.ok,rec.error=pcall(function()
                local current=P.investors()
                assert(ctx.live(rec.epoch) and S.resetEnabled and ctx.CONFIG.AutoRebirth,'PAUSED_BEFORE_DISPATCH')
                assert(current and sameCycle(before.snapshot,current.snapshot) and current.ready,'PRESTIGE_STATE_CHANGED')
                local evo=P.evolution();assert(evo and sameCycle(current.snapshot,evo.snapshot),'EVOLUTION_STATE_CHANGED');r.evo=evo
                local allowed=ctx.Strategy.rebirthBarrier(current);assert(allowed,'RESET_INTENT_CHANGED')
                rec.sent=true;ctx.log('DIRECT_REBIRTH_SENT','ordinary rebirth; no paid/free product; no GUI')
                remote:InvokeServer(nil) -- The normal confirmation passes nil, the product path passes true.
            end)
            rec.returned=true
            if rec.waitEnded and S.actionPending==rec then S.actionPending=nil end
        end)
        repeat
            if rec.returned and (not rec.ok or P.rebirthProof(rec))then break end
            task.wait(.05);S.actionYieldSerial=(S.actionYieldSerial or 0)+1
        until ctx.now()-rec.started>=ctx.CONFIG.ResetTimeout
        rec.waitEnded=true
        if rec.returned and S.actionPending==rec then S.actionPending=nil end
        if not rec.sent then ctx.Strategy.noteResetAbort(tostring(rec.error or 'NOT_DISPATCHED'));return false end
        if not rec.returned or not rec.ok or not P.rebirthProof(rec)then
            r.directResetUnresolved=rec;ctx.pause('DIRECT_RESET_UNRESOLVED','Rebirth отправлен один раз, результат не подтверждён: '..tostring(rec.error));return false
        end
        local duration=math.max(.01,ctx.now()-rec.started)
        r.lastResetExecution={stage='confirmed',reason='rebirth',at=ctx.now()};r.resetDuration=duration
        ctx.Strategy.recordTiming('rebirth',duration);r.nextRecovery=recovery
        if recovery then recovery.started=ctx.now()+ctx.CONFIG.AfterResetWait end
        before.afterInvestors=P.wallet();ctx.Strategy.afterReset('rebirth',before)
        ctx.progress('rebirth');ctx.log('DIRECT_REBIRTH_RECEIPT','both rebirth counters increased; no GUI')
        S.runStart=ctx.now();S.lastRefresh=-math.huge;S.lastPowers=-math.huge
        ctx.sleep(ctx.CONFIG.AfterResetWait);return true
    end
    local oldReset=ctx.doReset
    function ctx.doReset(kind)
        if kind=='evolve' and not ctx.CONFIG.AutoEvolution or kind=='halo' and not ctx.CONFIG.AutoHalo then return false end
        if kind=='evolve' and ctx.HaloRun and ctx.HaloRun.deferEvolution then
            local hold,reason=ctx.HaloRun.deferEvolution(true)
            if hold then
                ctx.log('EVOLUTION_DEFERRED',reason..'; reset menu not opened')
                ctx.Strategy.phase(reason=='HALO_COMPLETION_TAKES_PRIORITY' and 'HALO' or 'BUY','завершаю текущую базу; эволюция отложена');return false
            end
        end
        if not ctx.CONFIG.DirectPrestige then return oldReset(kind)end
        if kind=='rebirth' then return P.rebirth()end
        if kind~='evolve' and kind~='halo'then return false end
        local verified,reason=P.verifyReset(kind)
        if verified then return P.reset(kind)end
        ctx.log('DIRECT_RESET_GUI_FALLBACK',kind..'; '..tostring(reason))
        -- Preserve the previous guarded GUI path if protocol identity changed.
        local key=kind=='evolve' and 'evolution' or 'halo'
        local ok=ctx.navigate(key);if not ok then return false end
        local savedEvolution,savedHalo=ctx.readEvolution,ctx.readHalo
        ctx.readEvolution=oldEvolution;ctx.readHalo=oldHalo
        local good,result=pcall(oldReset,kind)
        ctx.readEvolution=savedEvolution;ctx.readHalo=savedHalo
        if not good then error(result)end
        return result
    end
    local oldStep=ctx.step
    function ctx.step()
        if ctx.CONFIG.DirectPrestige and ctx.Strategy.route().directResetUnresolved then
            if not ctx.S.actionPending then ctx.DirectPurchases.refreshEpoch()end
            if ctx.Strategy.route().directResetUnresolved then
                ctx.pause('DIRECT_RESET_UNRESOLVED','Прежний сброс ещё не подтверждён; новые действия остановлены.');return
            end
        end
        return oldStep()
    end
    if ctx.HaloRun then
        local boot=ctx.HaloRun.boot
        function ctx.HaloRun.boot()
            if ctx.CONFIG.DirectPrestige and P.closedBootEpoch~=ctx.S.epoch
                and not ctx.S.actionPending and not ctx.S.resetSession and not ctx.S.resetChildPending then
                P.closedBootEpoch=ctx.S.epoch
                local closed,why=ctx.closeGameMenus(nil)
                if not closed then ctx.log('OLD_MENU_CLOSE_FAILED',tostring(why))end
            end
            return boot()
        end
    end
    local oldReport=ctx.API.directReport
    function ctx.API.directReport()
        local rows={oldReport()};local inv,why=P.investors();local evo=P.evolution()
        rows[#rows+1]='[SL PRESTIGE] '..(inv and ('bank='..ctx.BN.format(inv.investors)..'; reward='..ctx.BN.format(inv.reward)..'; perInvestor='..inv.perInvestor) or tostring(why))
        if evo then rows[#rows+1]='[SL PRESTIGE] E='..evo.index..'; progress='..evo.pct..'; bonus='..ctx.BN.format(evo.bonus)..'; targetLog='..evo.targetLog end
        for _,kind in ipairs({'evolve','halo'})do
            local row=P.resetSchemas and P.resetSchemas[kind]
            rows[#rows+1]='[SL PRESTIGE TRANSPORT] '..kind..'='..(not ctx.CONFIG.DirectPrestige and 'GUI (disabled)'
                or not row and 'direct pending identity check' or row.ok and 'direct verified' or ('GUI fallback: '..tostring(row.reason)))
        end
        return table.concat(rows,'\n')
    end
end
