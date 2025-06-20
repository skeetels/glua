-- Настройка основных цветов, соответствующих EdgeHUD (с запасными значениями при отсутствии EdgeHUD)
local COLORS = EdgeHUD and EdgeHUD.Colors or {}
local BlackTrans = COLORS["Black"] or Color(50, 50, 50, 180)         -- чёрный полупрозрачный фон
local GrayTrans = Color(80, 80, 80, 200)                             -- серый полупрозрачный (напр. для ховеров)
local White = COLORS["White"] or Color(255, 255, 255, 255)           -- белый
local WhiteOutline = Color(255, 255, 255, 100)                       -- белый для рамки (прозрачность 100)
local WhiteCorners = Color(255, 255, 255, 180)                       -- белый для углов (прозрачность 180)
local Gray = COLORS["Gray"] or Color(200, 200, 200, 255)             -- серый для незаполненных колец
local raidPanel
local lblTitle
local lblHackStatus
local lblTimer
local ringPanels = {}
local timerRingPanel
local raidTotalTime, raidEndTime, raidTimerActive

-- Функция отрисовки угловых "скобок" по стилю EdgeHUD
local function DrawEdges(x, y, w, h, edgeSize, edgeWidth)
    -- верхний левый угол
    surface.DrawRect(x, y, edgeSize, edgeWidth)
    surface.DrawRect(x, y + edgeWidth, edgeWidth, edgeSize - edgeWidth)
    -- верхний правый угол
    local x2 = x + w
    surface.DrawRect(x2 - edgeSize, y, edgeSize, edgeWidth)
    surface.DrawRect(x2 - edgeWidth, y + edgeWidth, edgeWidth, edgeSize - edgeWidth)
    -- нижний правый угол
    local y2 = y + h
    surface.DrawRect(x2 - edgeSize, y2 - edgeWidth, edgeSize, edgeWidth)
    surface.DrawRect(x2 - edgeWidth, y2 - edgeSize, edgeWidth, edgeSize - edgeWidth)
    -- нижний левый угол
    surface.DrawRect(x, y2 - edgeWidth, edgeSize, edgeWidth)
    surface.DrawRect(x, y2 - edgeSize, edgeWidth, edgeSize - edgeWidth)
end

-- Настройка длительностей анимаций (в секундах)
local OPEN_HORIZ_DUR1 = 0.4   -- длительность горизонтального раскрытия (первый этап)
local OPEN_VERT_DUR   = 0.3   -- длительность вертикального раскрытия (второй этап)
local OPEN_HORIZ_DUR2 = 0.4   -- длительность финального горизонтального раскрытия (третий этап)
local HOLD_DUR        = 2.0   -- время показа сообщения
local FADE_TEXT_DUR   = 0.2   -- длительность появления/исчезновения текста
local CLOSE_HORIZ_DUR1= 0.3   -- длительность горизонтального схлопывания (первый этап закрытия)
local CLOSE_VERT_DUR  = 0.2   -- длительность вертикального схлопывания (второй этап закрытия)
local CLOSE_HORIZ_DUR2= 0.3   -- длительность финального схлопывания в точку

-- Функции для плавного замедления/ускорения (квадратичные ease-in/out)
local function EaseOutQuad(t) return 1 - (1 - t) ^ 2 end  -- быстро в начале, замедляясь к концу
local function EaseInQuad(t) return t ^ 2 end             -- медленно в начале, ускоряясь к концу

-- Переменные для управления анимацией сообщения
local msgActive = false        -- флаг, что анимация сообщения сейчас проигрывается
local msgText = ""
local msgStage = 0            -- текущий этап анимации (0 = не запущено)
local msgStartTime = 0        -- время начала текущего этапа
local msgTextAlpha = 0        -- прозрачность текста
local msgWidth, msgHeight = 0, 0  -- целевые размеры прямоугольника сообщения
local msgCurW, msgCurH = 0, 0     -- текущие размеры (в процессе анимации)
local msgInitialW = 0         -- промежуточная ширина полоски на первом этапе (точка -> полоска)

-- Функция для запуска анимации сообщения (центральное всплывающее сообщение)
local function ShowChaosMessage(text, onFinished)
    msgActive = true
    msgText = text or ""
    -- Вычисляем размеры текста и целевой прямоугольник
    surface.SetFont("ChaosRaidMsg")
    local textW, textH = surface.GetTextSize(msgText)
    local pad = ScrH() * 0.02  -- отступы внутри прямоугольника
    msgWidth = textW + pad * 2
    msgHeight = textH + pad * 2
    -- Начальные значения для анимации: начинаем с крошечной точки в центре
    msgCurW = 1
    msgCurH = 1
    msgInitialW = msgWidth * 0.2  -- ширина полоски на первом этапе (~20% от итоговой ширины)
    msgStage = 1
    msgStartTime = CurTime()
    msgTextAlpha = 0  -- текст невидим в начале
    -- Добавляем хук отрисовки на экран
    hook.Add("HUDPaint", "ChaosRaidMessageHUD", function()
        if not msgActive then return end
        local elapsed = CurTime() - msgStartTime
        if msgStage == 1 then
            -- Этап 1: точка расширяется в горизонтальную полоску
            local progress = math.min(elapsed / OPEN_HORIZ_DUR1, 1)
            local ease = EaseOutQuad(progress)
            msgCurW = Lerp(ease, 1, msgInitialW)
            msgCurH = 1  -- высота остаётся минимальной
            if progress >= 1 then
                -- переходим к этапу 2
                msgStage = 2
                msgStartTime = CurTime()
            end
        elseif msgStage == 2 then
            -- Этап 2: полоска расширяется вертикально до полной высоты
            local progress = math.min(elapsed / OPEN_VERT_DUR, 1)
            local ease = EaseOutQuad(progress)
            msgCurH = Lerp(ease, 1, msgHeight)
            msgCurW = msgInitialW  -- ширина остаётся фиксирована на этом этапе
            if progress >= 1 then
                -- переходим к этапу 3
                msgStage = 3
                msgStartTime = CurTime()
                msgTextAlpha = 0  -- подготовить текст для появления
            end
        elseif msgStage == 3 then
            -- Этап 3: расширение прямоугольника до полной ширины, одновременное появление текста и выдержка
            local progress = math.min(elapsed / OPEN_HORIZ_DUR2, 1)
            local ease = EaseOutQuad(progress)
            msgCurW = Lerp(ease, msgInitialW, msgWidth)
            msgCurH = msgHeight
            -- Плавное появление текста в начале этапа
            if elapsed <= FADE_TEXT_DUR then
                local alphaProgress = math.min(elapsed / FADE_TEXT_DUR, 1)
                msgTextAlpha = Lerp(alphaProgress, 0, 255)
            else
                msgTextAlpha = 255
            end
            -- Если прямоугольник дорос до полной ширины, переходим к паузе (удерживаем сообщение на экране)
            if progress >= 1 then
                msgStage = 4
                msgStartTime = CurTime()
            end
        elseif msgStage == 4 then
            -- Этап 4: пауза (удержание сообщения на экране заданное время HOLD_DUR)
            msgCurW = msgWidth
            msgCurH = msgHeight
            msgTextAlpha = 255
            if elapsed >= HOLD_DUR then
                -- Начинаем закрытие: сначала плавно гасим текст
                msgStage = 5
                msgStartTime = CurTime()
            end
        elseif msgStage == 5 then
            -- Этап 5: затухание (исчезновение) текста перед схлопыванием
            msgCurW = msgWidth
            msgCurH = msgHeight
            local progress = math.min(elapsed / FADE_TEXT_DUR, 1)
            msgTextAlpha = Lerp(progress, 255, 0)
            if progress >= 1 then
                -- После того как текст исчез, запускаем схлопывание прямоугольника
                msgStage = 6
                msgStartTime = CurTime()
            end
        elseif msgStage == 6 then
            -- Этап 6: горизонтальное схлопывание (прямоугольник сжимается по ширине до промежуточной ширины msgInitialW)
            local progress = math.min(elapsed / CLOSE_HORIZ_DUR1, 1)
            local ease = EaseInQuad(progress)
            msgCurW = Lerp(ease, msgWidth, msgInitialW)
            msgCurH = msgHeight
            if progress >= 1 then
                msgStage = 7
                msgStartTime = CurTime()
            end
        elseif msgStage == 7 then
            -- Этап 7: вертикальное схлопывание (уменьшение высоты до 1)
            local progress = math.min(elapsed / CLOSE_VERT_DUR, 1)
            local ease = EaseInQuad(progress)
            msgCurH = Lerp(ease, msgHeight, 1)
            msgCurW = msgInitialW  -- ширина остаётся на промежуточном уровне
            if progress >= 1 then
                msgStage = 8
                msgStartTime = CurTime()
            end
        elseif msgStage == 8 then
            -- Этап 8: окончательное схлопывание в точку (уменьшение ширины до 1)
            local progress = math.min(elapsed / CLOSE_HORIZ_DUR2, 1)
            local ease = EaseInQuad(progress)
            msgCurW = Lerp(ease, msgInitialW, 1)
            msgCurH = 1
            if progress >= 1 then
                -- Анимация завершена
                msgActive = false
                hook.Remove("HUDPaint", "ChaosRaidMessageHUD")
                msgStage = 0
                -- Если задан колбэк по завершении, вызываем его
                if onFinished then onFinished() end
                return  -- завершаем рисование последнего кадра
            end
        end

        -- Позиционирование прямоугольника по центру экрана
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        local rectX = centerX - msgCurW / 2
        local rectY = centerY - msgCurH / 2

        -- Рисуем фон прямоугольника, рамку и углы
        surface.SetDrawColor(BlackTrans)
        surface.DrawRect(rectX, rectY, msgCurW, msgCurH)
        surface.SetDrawColor(WhiteOutline)
        surface.DrawOutlinedRect(rectX, rectY, msgCurW, msgCurH)
        surface.SetDrawColor(WhiteCorners)
        -- Для крупного сообщения используем чуть более длинные/толстые углы
        DrawEdges(rectX, rectY, msgCurW, msgCurH, 16, 5)

        -- Рисуем текст внутри (по центру)
        if msgText ~= "" and msgCurW >= 1 and msgCurH >= 1 then
            surface.SetFont("ChaosRaidMsg")
            surface.SetTextColor(255, 255, 255, msgTextAlpha)
            local tw, th = surface.GetTextSize(msgText)
            surface.SetTextPos(centerX - tw/2, centerY - th/2)
            surface.DrawText(msgText)
        end
    end)
end

-- Настройка шрифтов интерфейса (Roboto используется из контента EdgeHUD/Mantle, с поддержкой кириллицы)
surface.CreateFont("ChaosRaidMsg", {
    font = "Roboto",
    size = ScrH() * 0.05,    -- крупный шрифт для центральных сообщений
    weight = 500,
    extended = true
})
surface.CreateFont("ChaosRaidTitle", {
    font = "Roboto",
    size = ScrH() * 0.03,    -- заголовок панели (Рейд Повстанцев Хаоса)
    weight = 800,
    extended = true
})
surface.CreateFont("ChaosRaidLabel", {
    font = "Roboto",
    size = ScrH() * 0.025,   -- обычный текст панели (статус "Серверы: X/3")
    weight = 500,
    extended = true
})
surface.CreateFont("ChaosRaidRingNum", {
    font = "Roboto",
    size = ScrH() * 0.022,   -- цифры внутри колец серверов
    weight = 500,
    extended = true
})
surface.CreateFont("ChaosRaidTimer", {
    font = "Roboto",
    size = ScrH() * 0.028,   -- текст таймера (мм:сс)
    weight = 600,
    extended = true
})

-- Количество серверов для взлома
local TOTAL_SERVERS = 1

-- Переменные интерфейса панели рейда
local raidPanel         -- главная панель (панель слева)
local lblTitle          -- надпись заголовка рейда
local lblHackStatus     -- надпись состояния взлома (0/3, 1/3, ...)
local ringPanels = {}   -- таблица панелей-прогресс колец серверов
local timerRingPanel    -- панель кольца таймера
local lblTimer          -- метка текста таймера внутри кольца

-- Переменные для логики таймера
local raidTotalTime = 0    -- общее время выполнения рейда (секунды)
local raidEndTime = 0      -- время (CurTime) окончания рейда
local raidTimerActive = false

-- Функция обновления текста таймера (формат MM:SS)
local function UpdateTimerLabel()
    if not IsValid(lblTimer) or not raidTimerActive then return end
    local remaining = math.max(0, raidEndTime - CurTime())
    local seconds = math.ceil(remaining)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    local timeText = string.format("%02d:%02d", m, s)
    lblTimer:SetText(timeText)
    lblTimer:SizeToContents()  -- не обязательно, т.к. центрируем по панели
    -- Обновляем заполнение круга таймера
    if IsValid(timerRingPanel) then
        local frac = 0
        if raidTotalTime > 0 then frac = math.Clamp((raidTotalTime - remaining) / raidTotalTime, 0, 1) end
        timerRingPanel.progress = frac
        timerRingPanel:InvalidateLayout()  -- запросить перерисовку
    end
end

-- Создание пользовательской панели кольца с прогрессом
local PANEL = {}
function PANEL:Init()
    self.progress = 0  -- прогресс заполнения (0..1)
    self.radius = math.min(self:GetWide(), self:GetTall()) / 2
    self.thickness = ScrH() * 0.01  -- толщина кольца
    -- Предрассчитываем точки полного круга для заднего серого кольца (для оптимизации)
    self.fullCirclePoly = {}
    local cx, cy = self:GetWide() / 2, self:GetTall() / 2
    table.insert(self.fullCirclePoly, { x = cx, y = cy })  -- центр (для полного круга используем фан-контур)
    local segments = 360  -- используем 360 сегментов для приближённого круга
    for i = 0, segments do
        local ang = math.rad(i * (360 / segments))
        local px = cx + math.cos(ang) * self.radius
        local py = cy + math.sin(ang) * self.radius
        table.insert(self.fullCirclePoly, { x = px, y = py })
    end
    -- Предрассчитываем контур для внутреннего чёрного круга (для "стирания" центра)
    self.innerCirclePoly = {}
    table.insert(self.innerCirclePoly, { x = cx, y = cy })
    local innerR = self.radius - self.thickness
    for i = 0, segments do
        local ang = math.rad(i * (360 / segments))
        local px = cx + math.cos(ang) * innerR
        local py = cy + math.sin(ang) * innerR
        table.insert(self.innerCirclePoly, { x = px, y = py })
    end
end

function PANEL:Paint(w, h)
    local cx, cy = w / 2, h / 2
    local R = self.radius
    local r = R - self.thickness
    -- Рисуем серое кольцо (фон прогресса)
    surface.SetDrawColor(Gray)
    draw.NoTexture()
    surface.DrawPoly(self.fullCirclePoly)  -- серый полный круг
    -- Если есть прогресс, рисуем заполненный сегмент (белый)
    local frac = math.Clamp(self.progress, 0, 1)
    if frac > 0 then
        local angleSpan = 360 * frac
        -- Вычисляем количество сегментов для арки (высокое разрешение ~1000 точек на полный круг)
        local maxSegments = 1000
        local segCount = math.max(1, math.floor(maxSegments * frac))
        -- Строим полигон "вырезанного" сегмента (треугольный фан от центра)
        local wedgePoly = {}
        table.insert(wedgePoly, { x = cx, y = cy })
        for i = 0, segCount do
            local ang = math.rad(-90 + (angleSpan * i / segCount))
            local px = cx + math.cos(ang) * R
            local py = cy + math.sin(ang) * R
            table.insert(wedgePoly, { x = px, y = py })
        end
        surface.SetDrawColor(White)
        surface.DrawPoly(wedgePoly)
    end
    -- Рисуем внутренний чёрный круг, чтобы сделать отверстие (центр панели тоже чёрный фон)
    surface.SetDrawColor(BlackTrans.r, BlackTrans.g, BlackTrans.b, 255)  -- берём чёрный (поверх полностью, чтобы перекрыть белый внутри)
    surface.DrawPoly(self.innerCirclePoly)
end
vgui.Register("ChaosProgressRing", PANEL, "DPanel")

------------------------------------------------------------------
--  СОЗДАНИЕ ПАНЕЛИ РЕЙДА
------------------------------------------------------------------
-- Переменные для настраиваемого текста и параметров
local raidTitleText   = "Идёт рейд повстанцев"  -- заголовок (можно менять внешним кодом)
local totalServers    = 3                       -- всего серверов
local activeServers   = 0                       -- текущих активных серверов (для примера)

-- Функция для построения вершин дуги (кольцевого сегмента)
local function BuildArcVertices(cx, cy, radius, thickness, startAng, endAng, step)
    local vertices = {}
    local inner = {}
    local outer = {}
    -- Определяем шаг итерации по углу
    local angleStep = math.abs(step)
    if startAng > endAng then angleStep = -angleStep end
    -- Радиус внутренней окружности
    local innerRadius = radius - thickness
    -- Координаты точек внутренней дуги
    for ang = startAng, endAng, angleStep do
        local rad = math.rad(ang)
        table.insert(inner, { x = cx + math.cos(rad)*innerRadius, y = cy - math.sin(rad)*innerRadius })
    end
    -- Координаты точек внешней дуги
    for ang = startAng, endAng, angleStep do
        local rad = math.rad(ang)
        table.insert(outer, { x = cx + math.cos(rad)*radius, y = cy - math.sin(rad)*radius })
    end
    -- Соединяем точки в треугольники
    for i = 1, #inner * 2 do
        local p1 = outer[math.floor(i/2) + 1]
        local p3 = inner[math.floor((i+1)/2) + 1]
        local p2
        if i % 2 == 0 then 
            p2 = outer[math.floor((i+1)/2)]
        else 
            p2 = inner[math.floor((i+1)/2)] 
        end
        table.insert(vertices, { p1, p2, p3 })
    end
    return vertices
end

function CreateRaidHUDPanel()

    if raidPanel and IsValid(raidPanel) then 
        raidPanel:Remove() 
        raidPanel = nil
    end

    -- дальше твой код создания панели (без изменений):
    local colWhite        = Color(255, 255, 255, 255)
    local colGray         = Color(150, 150, 150, 255)
    local colBlackTrans   = Color(0, 0, 0, 180)
    local colWhiteOutline = Color(255, 255, 255, 100)
    local colWhiteCorners = Color(255, 255, 255, 180)
    if EdgeHUD and EdgeHUD.Colors then
        colWhite        = EdgeHUD.Colors["White"] or colWhite
        colGray         = EdgeHUD.Colors["Gray"] or colGray
        colBlackTrans   = EdgeHUD.Colors["Black_Transparent"] or colBlackTrans
        colWhiteOutline = EdgeHUD.Colors["White_Outline"] or colWhiteOutline
        colWhiteCorners = EdgeHUD.Colors["White_Corners"] or colWhiteCorners
    end

    local baseWidth, baseHeight = ScrW() * 0.2, ScrH() * 0.1
    local panelWidth  = baseWidth * 1.05
    local panelHeight = baseHeight * 1.35

    raidPanel = vgui.Create("DPanel")
    raidPanel:SetSize(panelWidth, panelHeight)
    raidPanel:ParentToHUD()

    local marginX = (EdgeHUD and EdgeHUD.Vars and EdgeHUD.Vars.ScreenMargin) or 10
    local marginY = ScrH() * 0.15
    raidPanel:SetPos(-panelWidth, marginY)

    raidPanel.Paint = function(self, w, h)
        surface.SetDrawColor(colBlackTrans)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colWhiteOutline)
        surface.DrawOutlinedRect(0, 0, w, h)
        if EdgeHUD and EdgeHUD.DrawEdges then
            surface.SetDrawColor(colWhiteCorners)
            EdgeHUD.DrawEdges(0, 0, w, h, 8, 2)
        end
    end

    -- === Заголовок рейда ===
    lblTitle = vgui.Create("DLabel", raidPanel)
    lblTitle:SetText(raidTitleText)
    lblTitle:SetFont("DermaDefaultBold")
    lblTitle:SetTextColor(colWhite)
    lblTitle:SizeToContents()
    local topPadding = panelHeight * 0.05
    lblTitle:SetPos(panelWidth/2 - lblTitle:GetWide()/2, topPadding)

    local leftPad = panelWidth * 0.05

    -- === Статус серверов ===
    local serverStatusText = string.format("Серверы: %d/%d", activeServers, totalServers)
    lblHackStatus = vgui.Create("DLabel", raidPanel)
    lblHackStatus:SetText(serverStatusText)
    lblHackStatus:SetFont("DermaDefault")
    lblHackStatus:SetTextColor(colWhite)
    lblHackStatus:SizeToContents()
    local gapY = panelHeight * 0.1
    local serversLineY = lblTitle:GetY() + lblTitle:GetTall() + gapY

    local ringSize = math.floor(panelHeight * 0.2)
    local ringThickness = math.max(2, math.floor(ringSize * 0.2))
    local serversLineHeight = math.max(lblHackStatus:GetTall(), ringSize)
    lblHackStatus:SetPos(leftPad, serversLineY + (serversLineHeight/2 - lblHackStatus:GetTall()/2))

    local ringSpacing = math.max(5, ringSize * 0.1)
    ringPanels = {}

    for i = 1, totalServers do
        local ring = vgui.Create("DPanel", raidPanel)
        ring:SetSize(ringSize, ringSize)
        ring.progress = 0
        if i == 1 then
            ring:SetPos(lblHackStatus:GetX() + lblHackStatus:GetWide() + ringSpacing, 
                        serversLineY + (serversLineHeight/2 - ringSize/2))
        else
            local prevRing = ringPanels[i-1]
            ring:SetPos(prevRing:GetX() + ringSize + ringSpacing, 
                        serversLineY + (serversLineHeight/2 - ringSize/2))
        end
        ring.Paint = function(self, w, h)
            local cx, cy = w/2, h/2
            draw.NoTexture()
            surface.SetDrawColor(colGray)
            local circleTris = BuildArcVertices(cx, cy, cx, ringThickness, 0, 360, 2)
            for _, tri in ipairs(circleTris) do surface.DrawPoly(tri) end
            local prog = self.progress or 0
            if prog >= 1 then
                surface.SetDrawColor(colWhite)
                for _, tri in ipairs(circleTris) do surface.DrawPoly(tri) end
            elseif prog > 0 then
                local endAngle = -90 + 360 * prog
                surface.SetDrawColor(colWhite)
                local arcTris = BuildArcVertices(cx, cy, cx, ringThickness, -90, endAngle, 2)
                for _, tri in ipairs(arcTris) do surface.DrawPoly(tri) end
            end
        end
        ringPanels[i] = ring
    end

    -- === Таймер рейда ===
    lblTimer = vgui.Create("DLabel", raidPanel)
    lblTimer:SetText("Таймер: 00:00")
    lblTimer:SetFont("DermaDefault")
    lblTimer:SetTextColor(colWhite)
    lblTimer:SizeToContents()
    local timerLineY = serversLineY + serversLineHeight + gapY
    local timerLineHeight = math.max(lblTimer:GetTall(), ringSize)
    lblTimer:SetPos(leftPad, timerLineY + (timerLineHeight/2 - lblTimer:GetTall()/2))

    timerRingPanel = vgui.Create("DPanel", raidPanel)
    timerRingPanel:SetSize(ringSize, ringSize)
    timerRingPanel.progress = 0
    timerRingPanel:SetPos(lblTimer:GetX() + lblTimer:GetWide() + ringSpacing, 
                          timerLineY + (timerLineHeight/2 - timerRingPanel:GetTall()/2))

    timerRingPanel.Paint = function(self, w, h)
        local cx, cy = w/2, h/2
        draw.NoTexture()
        surface.SetDrawColor(colGray)
        local circleTris = BuildArcVertices(cx, cy, cx, ringThickness, 0, 360, 2)
        for _, tri in ipairs(circleTris) do surface.DrawPoly(tri) end
        local prog = self.progress or 0
        if prog >= 1 then
            surface.SetDrawColor(colWhite)
            for _, tri in ipairs(circleTris) do surface.DrawPoly(tri) end
        elseif prog > 0 then
            local endAngle = -90 + 360 * prog
            surface.SetDrawColor(colWhite)
            local arcTris = BuildArcVertices(cx, cy, cx, ringThickness, -90, endAngle, 2)
            for _, tri in ipairs(arcTris) do surface.DrawPoly(tri) end
        end
    end

    raidPanel:MoveTo(marginX, marginY, 0.8, 0, 0.2)

    function raidPanel:Close()
        self:MoveTo(-panelWidth, marginY, 0.6, 0, 2, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    return raidPanel
end

-- Обработчики сетевых сообщений
net.Receive("ChaosRaid_Start", function()
    raidTotalTime = net.ReadUInt(16) or 0
    raidEndTime = CurTime() + raidTotalTime
    raidTimerActive = (raidTotalTime > 0)

    if IsValid(raidPanel) then
        raidPanel:Remove()
    end

    CreateRaidHUDPanel()

    ShowChaosMessage("Повстанцы Хаоса вторглись в комплекс", function()
        if IsValid(raidPanel) then
            local targetX, targetY = ScrW() * 0.01, select(2, raidPanel:GetPos())
            raidPanel:MoveTo(targetX, targetY, 1, 0, 1, function()
                if raidTimerActive then
                    timer.Create("ChaosRaidTimerTick", 1, 0, function()
                        if IsValid(lblTimer) and IsValid(timerRingPanel) then
                            local remaining = math.max(0, raidEndTime - CurTime())
                            local minutes = math.floor(remaining / 60)
                            local seconds = math.floor(remaining % 60)
                            lblTimer:SetText(string.format("Таймер: %02d:%02d", minutes, seconds))
                            lblTimer:SizeToContents()

                            timerRingPanel.progress = math.Clamp((raidTotalTime - remaining) / raidTotalTime, 0, 1)
                            timerRingPanel:InvalidateLayout()
                        else
                            timer.Remove("ChaosRaidTimerTick")
                        end
                    end)
                end
            end)
        end
    end)
end)

net.Receive("ChaosRaid_UpdateStatus", function()
    local timerProgress = net.ReadFloat()
    local completedTargets = net.ReadUInt(4)

    if IsValid(lblHackStatus) then
        lblHackStatus:SetText(string.format("Серверы: %d/3", completedTargets))
        lblHackStatus:SizeToContents()
    end

    for i = 1, 3 do
        local status = net.ReadUInt(2)
        if IsValid(ringPanels[i]) then
            ringPanels[i].progress = (status == 1 and 1 or (status == 2 and 0.5 or 0))
            ringPanels[i]:InvalidateLayout()
        end
    end

    if IsValid(timerRingPanel) then
        timerRingPanel.progress = timerProgress
        timerRingPanel:InvalidateLayout()
    end

    if IsValid(lblTimer) then
        local remaining = math.max(0, raidTotalTime - (raidTotalTime * timerProgress))
        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        lblTimer:SetText(string.format("Таймер: %02d:%02d", minutes, seconds))
        lblTimer:SizeToContents()
    end
end)

net.Receive("ChaosRaidEnd", function()
    local resultCode = net.ReadUInt(2) or 0

    -- Останавливаем таймер отсчёта времени
    if timer.Exists("ChaosRaidTimerTick") then
        timer.Remove("ChaosRaidTimerTick")
    end
    raidTimerActive = false

    -- Определяем итоговое сообщение
    local resultText = ""
    if resultCode == 0 then
        resultText = "Повстанцы Хаоса покинули комплекс"
    elseif resultCode == 1 then
        resultText = "Повстанцы Хаоса успешно взломали все серверы"
    elseif resultCode == 2 then
        resultText = "Повстанцы Хаоса провалили задание"
    else
        resultText = "Рейд завершён"
    end

    -- Проверяем и убираем панель
    if raidPanel and IsValid(raidPanel) then
        raidPanel:Close()  -- вызываем метод Close(), где прописана анимация
        raidPanel = nil  -- обнуляем после закрытия для избежания ошибок
    end

    -- После небольшой задержки, чтобы панель гарантированно исчезла, показываем сообщение
    timer.Simple(0.8, function()
        ShowChaosMessage(resultText)
    end)
end)
