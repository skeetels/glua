-- Component initialized with an explicit shared service context.
return function(__slctx)
function __slctx.API.pause() __slctx.pause('PAUSED','Пауза. Уже отправленное действие может завершиться. F6 — продолжить.') end
function __slctx.API.start()
    if __slctx.S.unloaded or __slctx.S.running or __slctx.S.testing then return end
    if __slctx.S.actionPending or __slctx.S.resetChildPending or __slctx.S.resetSession then
        __slctx.status('PREVIOUS_CALLBACK_PENDING','Предыдущий обработчик ещё выполняется. Дождись его завершения перед новым запуском.')
        return
    end
    __slctx.S.testing=true
    local testEpoch=__slctx.S.epoch
    local direct=__slctx.CONFIG.DirectUpgrades and __slctx.CONFIG.DirectPurchases and __slctx.CONFIG.DirectPrestige
    local ok,passed,code=true,true,'DIRECT_INPUT_NOT_REQUIRED'
    if direct then
        __slctx.log('DIRECT_START','GUI input test deferred until a GUI action is needed')
    else
        __slctx.status('CHECKING_INPUT','Проверка ввода на отдельной тестовой кнопке. Покупки и сбросы не выполняются.')
        ok,passed,code=pcall(__slctx.selfTest)
    end
    __slctx.S.testing=false
    if __slctx.S.unloaded or __slctx.S.epoch~=testEpoch then return end
    if not ok then __slctx.pause('INPUT_TEST_ERROR','Ошибка проверки: '..tostring(passed));return end
    if not passed then
        if code=='INPUT_API_MISSING' then
            __slctx.pause(code,'Не найдены доступные API кнопок или виртуального ввода. Подробности в «Журнал».')
        else
            __slctx.pause(code or 'INPUT_API_TEST_FAILED','Тестовая кнопка не сработала ни через обработчики, ни через виртуальный ввод. Открой Roblox поверх других окон и смотри «Журнал».')
        end
        return
    end
    __slctx.S.running=true;__slctx.S.epoch=__slctx.S.epoch+1;__slctx.S.backgroundTried=false;__slctx.S.backgroundVerified=false;__slctx.S.focusPauseAt=nil;__slctx.S.lastRefresh=-math.huge;__slctx.S.lastPowers=-math.huge
    -- Keep confirmed input support but refresh gameplay context after a user pause.
    local old=(__slctx.previousCycleState and __slctx.previousCycleState.route) or __slctx.S.route
    local pausedAt=__slctx.S.manualPauseAt or (__slctx.previousCycleState and __slctx.previousCycleState.pausedAt)
    local pauseSeconds=pausedAt and math.max(0,__slctx.now()-pausedAt) or 0
    __slctx.previousCycleState=nil;__slctx.S.manualPauseAt=nil
    __slctx.S.route=__slctx.Strategy.new()
    if old then __slctx.S.route.spent=old.spent;__slctx.S.route.spentUnknown=old.spentUnknown;__slctx.S.route.models=old.models;__slctx.S.route.powerBase=old.powerBase;__slctx.S.route.powerUsed=old.powerUsed or __slctx.BN.new(0);__slctx.S.route.powerSkipped=old.powerSkipped or {};__slctx.S.route.blocked=old.blocked or {} end
    if old then
        for _,key in ipairs({'timings','rebuildEstimate','powerBank','powerUnresolved','powerQuotes','directEpoch','directResetUnresolved',
            'rebuildProfile','lastFullPass','failedTierHints','fullPassCount','powerPurchasePlan','capabilityPending',
            'recovery','rebuildLowerBound','previousHalo','savingsBudget','schema28','objectiveHistory','halo30','lastHaloEconomy32'}) do
            __slctx.S.route[key]=old[key]
        end
        __slctx.S.route.previousEvolution=old.evo and old.evo.index or old.previousEvolution
        if __slctx.S.route.recovery then __slctx.S.route.recovery.started=__slctx.S.route.recovery.started+pauseSeconds end
        if __slctx.S.route.savingsBudget then
            __slctx.S.route.savingsBudget.start=__slctx.S.route.savingsBudget.start+pauseSeconds
            __slctx.S.route.savingsBudget.deadline=__slctx.S.route.savingsBudget.deadline+pauseSeconds
        end
        -- Pauses make complete-cycle wall-time samples incomparable, so start those
        -- measurements afresh. Capital and verified purchase outcomes are retained.
    end
    if __slctx.S.route.halo30 then
        local h=__slctx.S.route.halo30;local oldBook=h.book
        h.book=__slctx.HaloPlan.newBook(oldBook.halo,oldBook.evolution,false)
        h.book.anchors=oldBook.anchors;h.book.byAnchor=oldBook.byAnchor;h.book.model=oldBook.model
        h.book.scaleRevision=oldBook.scaleRevision
        __slctx.HaloPlan.copyExtras(oldBook,h.book,__slctx.CONFIG);h.economy=nil
        h.mode='PREPARE';h.finish=nil;h.forecast=nil;h.incomeSnapshot=nil;h.lastPlan=-math.huge;h.haloRead=nil
        h.goalFinish=nil;h.goalForecast=nil;h.nextGoalRead=nil;h.nextGoalForecast=nil
        h.lastReview=__slctx.now();h.nextReview=nil;h.wall=nil;h.powerScan=nil;h.powerAttempt=nil;h.remainingKey=nil;h.lastQuoteSignature=nil
    end
    __slctx.S.route.cleanRun=false;__slctx.S.route.frontierTrace=nil;__slctx.S.route.rewardSamples={}
    __slctx.S.route.uiObservation=nil;__slctx.S.route.growthSamples={};__slctx.S.route.passiveRows={}
    __slctx.S.route.runSpent=__slctx.BN.new(0);__slctx.S.route.runServiceSeconds=0;__slctx.S.route.runMenuSeconds=0;__slctx.S.route.runBuyCount=0
    __slctx.S.lastCatalog=-math.huge;__slctx.S.catalogDirty=true;__slctx.S.incomeAttempts={};__slctx.S.nextIncomeAt=0;__slctx.S.upgradeVisited={} 
    __slctx.S.episode=nil;__slctx.S.goal=nil;__slctx.S.stallStart=nil;__slctx.S.rate:reset();__slctx.S.runStart=__slctx.now()
    if __slctx.S.cashFlow then __slctx.S.cashFlow:reset() end
    __slctx.S.lastError='';__slctx.status('STARTING','Запуск. Проверка интерфейса…');__slctx.log('START','single worker; automatic resets='..tostring(__slctx.S.resetEnabled))
end
function __slctx.API.unload()
    if __slctx.S.unloaded then return end
    __slctx.S.running=false;__slctx.S.unloaded=true;__slctx.S.epoch=__slctx.S.epoch+1
    if __slctx.ResetInspection then __slctx.ResetInspection.dispose()end
    if __slctx.S.resetSession then
        __slctx.S.resetSession.active=false;__slctx.S.resetSession.outcome='UNLOADED';__slctx.S.resetSession=nil
    end
    __slctx.Virtual.dispose()
    for _,c in ipairs(__slctx.S.connections) do pcall(c.Disconnect,c) end
    if __slctx.panel then __slctx.panel:Destroy() end
    __slctx.log('UNLOADED','Новые действия остановлены.')
end
function __slctx.API.toggle()
    if __slctx.now()-(__slctx.S.lastToggleAt or -math.huge)<0.6 then return end
    __slctx.S.lastToggleAt=__slctx.now()
    if __slctx.S.running or __slctx.S.testing then __slctx.API.pause() else __slctx.API.start() end
end
__slctx.S.connections[#__slctx.S.connections+1]=__slctx.startButton.Activated:Connect(function(input) __slctx.S.lastInput=input or __slctx.S.lastInput;__slctx.API.toggle() end)
__slctx.S.connections[#__slctx.S.connections+1]=__slctx.resetsButton.Activated:Connect(function()
    __slctx.S.resetEnabled=not __slctx.S.resetEnabled;__slctx.resetsButton.Text=__slctx.S.resetEnabled and 'Сбросы: ВКЛ' or 'Сбросы: ВЫКЛ'
    __slctx.log('RESET_SWITCH',tostring(__slctx.S.resetEnabled))
end)
__slctx.S.connections[#__slctx.S.connections+1]=__slctx.logButton.Activated:Connect(__slctx.API.copyLog)
__slctx.S.connections[#__slctx.S.connections+1]=__slctx.closeButton.Activated:Connect(__slctx.API.unload)
__slctx.S.connections[#__slctx.S.connections+1]=__slctx.UIS.InputBegan:Connect(function(input,processed)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then __slctx.S.lastInput=input end
    if processed or __slctx.UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F6 then __slctx.API.toggle() end
    if input.KeyCode==Enum.KeyCode.F7 then __slctx.API.copyLog() end
    if input.KeyCode==Enum.KeyCode.F8 then
        __slctx.S.panelVisibilityVersion=(__slctx.S.panelVisibilityVersion or 0)+1
        __slctx.panel.Enabled=not __slctx.panel.Enabled
    end
end)

for eventName,focused in pairs({WindowFocused=true,WindowFocusReleased=false}) do
    local event=__slctx.prop(__slctx.UIS,eventName)
    if event then
        local ok,connection=pcall(function() return event:Connect(function()
            __slctx.Focus.changed(focused)
        end) end)
        if ok then __slctx.S.connections[#__slctx.S.connections+1]=connection end
    end
end
__slctx.S.panel=__slctx.panel;__slctx.S.panelFrame=__slctx.frame;__slctx.S.panelVisibilityVersion=0
__slctx.panel.Parent=__slctx.gui
__slctx.log('LOADED','v4.0.20-dev; direct upgrades/Powers/Buy/Rebirth/Evolution/Halo; reset protocol identities verified before use; guarded GUI fallback if changed.')
if __slctx.CONFIG.DirectUpgrades then
    local ok,report=pcall(__slctx.API.directReport)
    if ok then for line in report:gmatch('[^\n]+')do print(line)end
    else __slctx.log('INITIAL_REPORT_ERROR',tostring(report))end
end
task.spawn(function()
    while not __slctx.S.unloaded do
        local yieldsBefore=__slctx.S.actionYieldSerial or 0
        local maintenanceOK,maintenanceError=pcall(function()
            __slctx.Supervisor.tick();__slctx.Strategy.profileTick()
        end)
        if not maintenanceOK then __slctx.pause('MAINTENANCE_ERROR',tostring(maintenanceError)) end
        if __slctx.S.running then
            __slctx.S.busy=true
            local ok,err=xpcall(__slctx.step,function(e) return debug.traceback(tostring(e),2) end)
            __slctx.S.busy=false
            if not ok then __slctx.pause('RUNTIME_ERROR',err) end
        end
        local phase=__slctx.S.route and __slctx.S.route.phase
        local fastPhase=phase=='BUY' or phase=='UPGRADE' or phase=='REBUILD' or (__slctx.CONFIG.DirectUpgrades and phase=='CHECKPOINT')
        -- Receipt polling has already yielded. Avoid paying for a second frame;
        -- a synchronous/no-action iteration still yields exactly as before.
        if not (__slctx.S.running and fastPhase and __slctx.CONFIG.RequestedClickInterval<=0
            and (__slctx.S.actionYieldSerial or 0)>yieldsBefore) then
            task.wait(__slctx.S.running and (fastPhase and __slctx.CONFIG.RequestedClickInterval or __slctx.CONFIG.IdleStepSeconds) or 0.25)
        end
    end
end)
task.spawn(function()
    while not __slctx.S.unloaded do
        __slctx.statusLabel.Text=__slctx.S.code..'\n'..__slctx.S.status
        local p=__slctx.S.prestige
        __slctx.economyLabel.Text='Баланс: '..__slctx.t(__slctx.paths.balance)..' | Доход/с ≈ '..__slctx.BN.format(__slctx.Strategy.rate())
            ..'\nЭволюция: '..tostring(p and p.evo and p.evo.index or '?')
            ..' | Halo: '..tostring(p and p.halo and p.halo.amount or '?')..' | Запас: '..__slctx.CONFIG.TabletReserve
        local route=__slctx.Strategy.route()
        local evolutionText,evolutionFraction,scenarioText=__slctx.HaloRun.progress()
        __slctx.evolutionLabel.Text=evolutionText;__slctx.evolutionFill.Size=UDim2.fromScale(evolutionFraction,1)
        __slctx.routeLabel.Text=scenarioText
        __slctx.countsLabel.Text=string.format('Подтверждено: покупок %d, улучшений %d\nRebirth %d | Evolution %d | Halo %d | Powers %d',
            __slctx.S.counts.buy,__slctx.S.counts.upgrade,__slctx.S.counts.rebirth,__slctx.S.counts.evolve,__slctx.S.counts.halo,__slctx.S.counts.power or 0)
        __slctx.startButton.Text=__slctx.S.testing and 'Отмена (F6)' or (__slctx.S.running and 'Пауза (F6)' or 'Запуск (F6)')
        task.wait(0.2)
    end
end)
return __slctx.API

end
