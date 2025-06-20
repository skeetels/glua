print("[ChaosRaid] Серверный скрипт успешно загружен.")

-- Основная таблица и настройки ChaosRaid
ChaosRaid = ChaosRaid or {}
ChaosRaid.PHASE_HACK = 1
ChaosRaid.PHASE_ESCAPE = 2

-- Конфигурация целей и точек телепортации (пример заполнения)
ChaosRaid.ServerCoords = {
    Vector(-10842.984375, -5028.040527, -10584.201172),
    Vector(-10653.181641, -5521.907715, -10585.047852),
    Vector(-10549.229492, -5689.946777, -10583.992188),  -- Замените на реальные координаты целей
}
ChaosRaid.TeleportLocations = {
    Vector(0, 0, 0)  -- Замените на реальные точки телепортации
}

-- Прочие настройки
ChaosRaid.TargetModel = "models/props_lab/reciever01b.mdl"  -- модель объекта цели
ChaosRaid.HackPhaseTime = 600   -- время на фазу взлома (секунд)
ChaosRaid.EscapePhaseTime = 300 -- время на фазу побега (секунд)
ChaosRaid.HackDuration = 15     -- длительность взлома одной цели (секунд)
ChaosRaid.RewardMoney = 10000   -- денежная награда каждому игроку (DarkRP деньги)
ChaosRaid.RewardXP = 0          -- награда опытом (если используется система опыта)
ChaosRaid.ChaosTeams = {11, 12, 13, 14}       -- команда (job) игроков хаоса (заменить на нужную)

-- Внутренние переменные состояния
ChaosRaid.Active = ChaosRaid.Active or false
ChaosRaid.Phase = ChaosRaid.Phase or 0
ChaosRaid.Targets = {}
ChaosRaid.EligibleIDs = {}
ChaosRaid.CompletedTargets = 0

-- Удаляем старые хуки/таймеры/команды при перезагрузке скрипта, чтобы не было дубликатов
if timer.Exists("ChaosRaidTimer") then timer.Remove("ChaosRaidTimer") end
hook.Remove("PlayerUse", "ChaosRaidUse")
hook.Remove("OnPlayerChangedTeam", "ChaosRaidTeamChange")
if concommand.GetTable()["chaosraid_start"] then concommand.Remove("chaosraid_start") end

-- Регистрация сетевых сообщений
util.AddNetworkString("ChaosRaid_Start")
util.AddNetworkString("ChaosRaid_UpdateStatus")
util.AddNetworkString("ChaosRaid_Phase")
util.AddNetworkString("ChaosRaid_Time")
util.AddNetworkString("ChaosRaid_End")

-- Вспомогательная функция: получить список игроков команды хаоса
function ChaosRaid.GetChaosPlayers()
    local players = {}

    print("[ChaosRaid DEBUG] ChaosTeams table contents:")
    PrintTable(ChaosRaid.ChaosTeams)

    for _, ply in ipairs(player.GetAll()) do
        local teamID = ply:Team()
        local teamType = type(teamID)
        print("[ChaosRaid DEBUG] Player:", ply:Nick(), ", Team:", teamID, ", Type:", teamType)

        local found = false
        for k, v in pairs(ChaosRaid.ChaosTeams) do
            print("[ChaosRaid DEBUG] Checking team from table:", v, "Type:", type(v))
            if v == teamID then
                found = true
                break
            end
        end

        if IsValid(ply) and found then
            print("[ChaosRaid DEBUG] ^ This is a Chaos player!")
            table.insert(players, ply)
        end
    end

    print("[ChaosRaid DEBUG] Total Chaos players found:", #players)
    return players
end

-- Вспомогательная функция: отправить игроку текущее состояние рейда (для новых участников)
function ChaosRaid.SendFullState(ply)
    if not IsValid(ply) then return end
    net.Start("ChaosRaid_Start")
        net.WriteUInt(ChaosRaid.Phase, 2)
        net.WriteUInt(math.Clamp(ChaosRaid.TimeLeft or 0, 0, 65535), 16)
        local count = #ChaosRaid.Targets
        net.WriteUInt(count, 6)
        for i = 1, count do
            local t = ChaosRaid.Targets[i]
            local state = 0
            if t.hacked then
                state = 2
            elseif t.hacking then
                state = 1
            end
            net.WriteUInt(state, 2)
        end
    net.Send(ply)
end

-- Функция запуска рейда
function ChaosRaid.StartRaid(ply)
    if ChaosRaid.Active then
        print("[ChaosRaid] Не удалось запустить: рейд уже активен.")
        return
    end
    if not ChaosRaid.ServerCoords or #ChaosRaid.ServerCoords == 0 then
        print("[ChaosRaid] Ошибка: не заданы координаты целей в ChaosRaid.ServerCoords.")
        return
    end

    ChaosRaid.Active = true
    ChaosRaid.Phase = ChaosRaid.PHASE_HACK
    ChaosRaid.CompletedTargets = 0
    ChaosRaid.EligibleIDs = {}

    if timer.Exists("ChaosRaidStatusUpdater") then timer.Remove("ChaosRaidStatusUpdater") end
    timer.Create("ChaosRaidStatusUpdater", 1, 0, function()
        ChaosRaid.SendRaidStatus()
    end)

    -- Создаём объекты целей по заданным координатам
    ChaosRaid.Targets = {}
    for i, pos in ipairs(ChaosRaid.ServerCoords) do
        if not isvector(pos) then
            print("[ChaosRaid] Некорректная координата цели #" .. i)
        else
            local ent = ents.Create("prop_physics")
            if IsValid(ent) then
                ent:SetModel(ChaosRaid.TargetModel)
                ent:SetPos(pos)
                ent:Spawn()
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then phys:EnableMotion(false) end
                ent.IsChaosRaidTarget = true
                ent.TargetIndex = i
                ChaosRaid.Targets[i] = { ent = ent, hacked = false, hacking = false }
            else
                print("[ChaosRaid] Не удалось создать объект цели #" .. i)
            end
        end
    end

    -- Устанавливаем таймеры фазы взлома
    ChaosRaid.TimeLeft = ChaosRaid.HackPhaseTime or 0
    timer.Create("ChaosRaidTimer", 1, 0, function()
        if not ChaosRaid.Active then timer.Remove("ChaosRaidTimer") return end
        if ChaosRaid.TimeLeft > 0 then
            ChaosRaid.TimeLeft = ChaosRaid.TimeLeft - 1
        end

        -- Отправляем обновление таймера на клиент
        local t = math.Clamp(ChaosRaid.TimeLeft, 0, 65535)
        net.Start("ChaosRaid_Time")
            net.WriteUInt(t, 16)
        local recipients = ChaosRaid.GetChaosPlayers()
        if #recipients > 0 then net.Send(recipients) end

        -- Проверяем истечение времени для текущей фазы
        if ChaosRaid.Phase == ChaosRaid.PHASE_HACK then
            if ChaosRaid.TimeLeft <= 0 then
                print("[ChaosRaid] Время на взлом истекло. Рейд провален.")
                ChaosRaid.EndRaid(false)
            end
        elseif ChaosRaid.Phase == ChaosRaid.PHASE_ESCAPE then
            if ChaosRaid.TimeLeft <= 0 then
                print("[ChaosRaid] Время на побег истекло.")
                ChaosRaid.FailEscape()
                -- FailEscape вызовет EndRaid(false)
            end
        end
    end)

    print("[ChaosRaid] Рейд начался! Целей: " .. #ChaosRaid.Targets .. ", время на взлом: " .. ChaosRaid.TimeLeft .. " с.")

    -- ▼▼▼ ОТПРАВКА СЕТЕВОГО СООБЩЕНИЯ О НАЧАЛЕ РЕЙДА ▼▼▼
    -- Отправляем начальное состояние HUD всем игрокам команды хаоса
    net.Start("ChaosRaid_Start")
        net.WriteUInt(ChaosRaid.TimeLeft, 16) -- отправляем длительность рейда в секундах
    net.Broadcast()
    print("[ChaosRaid] Сообщение ChaosRaid_Start отправлено ВСЕМ клиентам!")
    -- ▲▲▲ КОНЕЦ ИСПРАВЛЕНИЯ ▲▲▲
end

-- Отправляет клиентам текущее состояние серверов и прогресс таймера
function ChaosRaid.SendRaidStatus()
    if not ChaosRaid.Active then print("[ChaosRaid DEBUG] Raid inactive!") return end

    net.Start("ChaosRaid_UpdateStatus")

    local timeLeft = math.Clamp(ChaosRaid.TimeLeft or 0, 0, 65535)
    local maxTime = (ChaosRaid.Phase == ChaosRaid.PHASE_HACK) and ChaosRaid.HackPhaseTime or ChaosRaid.EscapePhaseTime
    local timerProgress = 1 - (timeLeft / maxTime)
    net.WriteFloat(timerProgress)

    net.WriteUInt(ChaosRaid.CompletedTargets, 4)

    for i = 1, #ChaosRaid.Targets do
        local target = ChaosRaid.Targets[i]
        local status = 0
        if target.hacked then
            status = 1
        elseif target.hacking then
            status = 2
        end
        net.WriteUInt(status, 2)
    end

    local recipients = ChaosRaid.GetChaosPlayers()
    if #recipients > 0 then 
        net.Send(recipients) 
        print("[ChaosRaid DEBUG] UpdateStatus SENT to Chaos players!")
    else
        print("[ChaosRaid DEBUG] No Chaos players found!")
    end
end

-- Функция завершения рейда (success=true для успешного побега, false для провала)
function ChaosRaid.EndRaid(success)
    if not ChaosRaid.Active then return end
    success = success or false

    -- Удаляем таймеры взлома по каждой цели
    for i = 1, #ChaosRaid.Targets do
        timer.Remove("ChaosRaidHack" .. i)
    end
    -- Останавливаем основной таймер
    if timer.Exists("ChaosRaidTimer") then
        timer.Remove("ChaosRaidTimer")
    end
    -- Удаляем объекты целей
    for _, t in ipairs(ChaosRaid.Targets) do
        if IsValid(t.ent) then
            t.ent:Remove()
        end
    end

    if timer.Exists("ChaosRaidStatusUpdater") then
        timer.Remove("ChaosRaidStatusUpdater")
    end

    ChaosRaid.Active = false
    if success then
        print("[ChaosRaid] Рейд завершён успешно. Игроки скрылись с наградой.")
    else
        print("[ChaosRaid] Рейд завершён.")
    end

    -- Сообщаем клиентам о завершении (скрыть HUD)
    net.Start("ChaosRaid_End")
    net.Broadcast()
end

-- Функция провала побега (телепорт и штраф)
function ChaosRaid.FailEscape()
    local teleports = ChaosRaid.TeleportLocations or {}

    -- Проверка наличия точек телепортации
    if #teleports == 0 then
        print("[ChaosRaid] Ошибка: не заданы точки телепортации в ChaosRaid.TeleportLocations.")
        ChaosRaid.EndRaid(false)
        return
    end

    local chaosPlayers = ChaosRaid.GetChaosPlayers()
    for _, ply in ipairs(chaosPlayers) do
        if IsValid(ply) and ply:Alive() then -- проверка, жив ли игрок
            -- Телепортируем игрока в случайную точку из списка
            local loc = teleports[math.random(#teleports)]
            if isvector(loc) then
                ply:SetPos(loc)
                ply:SetLocalVelocity(Vector(0,0,0)) -- сброс скорости игрока, чтобы избежать повреждений при телепорте
            else
                print("[ChaosRaid] Некорректная точка телепортации, пропуск телепортации для " .. ply:Nick())
            end

            -- Снимаем награду (деньги), если игрок ранее получил награду
            local sid = ply:SteamID()
            if ChaosRaid.EligibleIDs and ChaosRaid.EligibleIDs[sid] then
                if ChaosRaid.RewardMoney and ChaosRaid.RewardMoney > 0 then
                    if DarkRP and ply.addMoney then
                        ply:addMoney(-ChaosRaid.RewardMoney)
                        print("[ChaosRaid] С игрока " .. ply:Nick() .. " списано $" .. ChaosRaid.RewardMoney .. ".")
                    else
                        print("[ChaosRaid] Ошибка: метод ply:addMoney недоступен для " .. ply:Nick())
                    end
                else
                    print("[ChaosRaid] Награда деньгами не задана или равна нулю.")
                end
                -- Опыт не отнимаем (если была интеграция, здесь можно указать обработку опыта)
            else
                print("[ChaosRaid] Игрок " .. ply:Nick() .. " не отмечен для награды, снятие денег пропущено.")
            end

            print("[ChaosRaid] Игрок " .. ply:Nick() .. " не успел сбежать и был телепортирован.")
        else
            print("[ChaosRaid] Игрок невалиден или мёртв, пропущена обработка.")
        end
    end

    -- Завершаем рейд как проваленный
    ChaosRaid.EndRaid(false)
end

-- Функция выдачи награды при начале фазы побега
function ChaosRaid.GiveRewards()
    for sid, _ in pairs(ChaosRaid.EligibleIDs) do
        local ply = player.GetBySteamID(sid)
        if IsValid(ply) and ply:Team() == ChaosRaid.ChaosTeams then
            local gotMoney = 1000
            local gotexp = 100
            if ChaosRaid.RewardMoney and ChaosRaid.RewardMoney > 0 then
                gotMoney = ChaosRaid.RewardMoney
                if ply.addMoney then
                    ply:addMoney(gotMoney)
                elseif DarkRP then
                    ply:addMoney(gotMoney)
                end
            end
            if ChaosRaid.RewardXP and ChaosRaid.RewardXP > 0 and ply.addXP then
                gotXP = ChaosRaid.RewardXP
                ply:addXP(gotXP)
            end
            if gotMoney > 0 or gotXP > 0 then
                local msg = "[ChaosRaid] " .. ply:Nick() .. " получил награду"
                if gotMoney > 0 then msg = msg .. " $" .. gotMoney end
                if gotexp > 0 then msg = msg .. " и " .. gotXP .. " XP" end
                msg = msg .. "."
                print(msg)
            end
        end
    end
end

-- Хук: использование объекта (взлом цели)
hook.Add("PlayerUse", "ChaosRaidUse", function(ply, ent)
    if not ChaosRaid.Active or ChaosRaid.Phase ~= ChaosRaid.PHASE_HACK then return end
    if not IsValid(ply) or not IsValid(ent) then return end
    if not ent.IsChaosRaidTarget then return end
    local idx = ent.TargetIndex
    if not idx or not ChaosRaid.Targets[idx] then return end
    local target = ChaosRaid.Targets[idx]
    if target.hacked or target.hacking then
        return false  -- цель уже взломана или взлом в процессе
    end
    if ply:Team() ~= ChaosRaid.ChaosTeams then
        return false  -- только команда хаоса может взламывать
    end

    -- Начинаем процесс взлома цели
    target.hacking = true
    net.Start("ChaosRaid_TargetStatus")
        net.WriteUInt(idx, 6)
        net.WriteUInt(1, 2)  -- статус "в процессе"
    local recipients = ChaosRaid.GetChaosPlayers()
    if #recipients > 0 then net.Send(recipients) end
    print("[ChaosRaid] Начат взлом цели #" .. idx .. " игроком " .. ply:Nick() .. ".")

    timer.Create("ChaosRaidHack" .. idx, ChaosRaid.HackDuration, 1, function()
        if not ChaosRaid.Active or not target.hacking then return end
        target.hacking = false
        target.hacked = true
        ChaosRaid.CompletedTargets = ChaosRaid.CompletedTargets + 1
        print("[ChaosRaid] Цель #" .. idx .. " взломана игроком " .. (IsValid(ply) and ply:Nick() or "неизвестно") .. ".")

        -- Если это первый успешно взломанный сервер, отмечаем участников для награды
        if ChaosRaid.CompletedTargets == 1 then
            for _, pl in ipairs(player.GetAll()) do
                if IsValid(pl) and pl:Team() == ChaosRaid.ChaosTeams then
                    ChaosRaid.EligibleIDs[pl:SteamID()] = true
                end
            end
        end

        -- Обновляем статус цели на клиенте
        net.Start("ChaosRaid_TargetStatus")
            net.WriteUInt(idx, 6)
            net.WriteUInt(2, 2)  -- статус "взломана"
        local recips = ChaosRaid.GetChaosPlayers()
        if #recips > 0 then net.Send(recips) end

        -- Проверяем, все ли цели взломаны
        if ChaosRaid.CompletedTargets >= #ChaosRaid.Targets then
            -- Переходим к фазе побега
            ChaosRaid.Phase = ChaosRaid.PHASE_ESCAPE
            ChaosRaid.TimeLeft = ChaosRaid.EscapePhaseTime or 0
            ChaosRaid.GiveRewards()
            print("[ChaosRaid] Все цели взломаны. Началась фаза побега! Времени на побег: " .. ChaosRaid.TimeLeft .. " с.")

            -- Уведомляем клиентов о фазе побега
            net.Start("ChaosRaid_Phase")
                net.WriteUInt(ChaosRaid.Phase, 2)
                net.WriteUInt(math.Clamp(ChaosRaid.TimeLeft, 0, 65535), 16)
            local rec = ChaosRaid.GetChaosPlayers()
            if #rec > 0 then net.Send(rec) end
        end
    end)
    return false
end)

-- Хук: отслеживание смены команды игрока (вступление/выход из команды хаоса)
hook.Add("OnPlayerChangedTeam", "ChaosRaidTeamChange", function(ply, oldTeam, newTeam)
    if not ChaosRaid.Active then return end
    if newTeam == ChaosRaid.ChaosTeam then
        -- Игрок вошёл в команду хаоса во время рейда: отправляем ему текущее состояние
        ChaosRaid.SendFullState(ply)
    elseif oldTeam == ChaosRaid.ChaosTeam and newTeam ~= ChaosRaid.ChaosTeam then
        -- Игрок покинул команду хаоса во время рейда: отключаем ему HUD
        net.Start("ChaosRaid_End")
        net.Send(ply)
    end
end)

-- Команда консоли для запуска рейда
concommand.Add("chaosraid_start", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    ChaosRaid.StartRaid(ply)
    print("[ChaosRaid SERVER] Отправлено сообщение ChaosRaid_Start клиентам")
end)

concommand.Add("test_chaosraid_net", function()
    net.Start("ChaosRaid_Start")
    net.Broadcast()
    print("[ChaosRaid SERVER] Тестовое сообщение ChaosRaid_Start отправлено!")
end)
