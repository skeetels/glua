-- Presentation only: all economic actions are delegated to the controller API.
return function(ctx)
    local palette={background=Color3.fromRGB(17,20,22),card=Color3.fromRGB(27,31,33),
        line=Color3.fromRGB(48,54,55),text=Color3.fromRGB(238,242,235),
        muted=Color3.fromRGB(157,169,161),accent=Color3.fromRGB(215,236,124)}
    local function round(o,r)
        local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,r or 10);c.Parent=o
    end
    local function label(parent,text,x,y,w,h,size,color)
        local o=Instance.new('TextLabel');o.BackgroundTransparency=1
        o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h)
        o.Font=Enum.Font.Gotham;o.TextSize=size or 13;o.TextColor3=color or palette.text
        o.TextXAlignment=Enum.TextXAlignment.Left;o.TextYAlignment=Enum.TextYAlignment.Top
        o.TextWrapped=true;o.Text=text;o.Parent=parent;return o
    end
    local function card(y,h)
        local o=Instance.new('Frame');o.Position=UDim2.fromOffset(18,y);o.Size=UDim2.fromOffset(484,h)
        o.BackgroundColor3=palette.card;o.BorderSizePixel=0;o.Parent=ctx.frame;round(o,10);return o
    end
    local function button(text,x,y,w)
        local o=Instance.new('TextButton');o.Position=UDim2.fromOffset(x,y)
        o.Size=UDim2.fromOffset(w,32);o.Text=text;o.Font=Enum.Font.GothamMedium
        o.TextSize=12;o.TextColor3=palette.text;o.BackgroundColor3=palette.card
        o.BorderSizePixel=0;o.AutoButtonColor=true;o.Parent=ctx.frame;round(o,8);return o
    end
    ctx.panel=Instance.new('ScreenGui');ctx.panel.Name='SLAutofarmPanel'
    ctx.panel.ResetOnSpawn=false;ctx.panel.DisplayOrder=1100;ctx.panel.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    ctx.frame=Instance.new('Frame');ctx.frame.Size=UDim2.fromOffset(520,640)
    ctx.frame.AnchorPoint=Vector2.new(0,0.5)
    ctx.frame.Position=UDim2.new(0,18,0.5,0);ctx.frame.BackgroundColor3=palette.background
    ctx.frame.BorderSizePixel=0;ctx.frame.Parent=ctx.panel;round(ctx.frame,14)
    local stroke=Instance.new('UIStroke');stroke.Color=palette.line;stroke.Parent=ctx.frame
    local scale=Instance.new('UIScale');scale.Parent=ctx.frame
    local function resize()
        local camera=workspace.CurrentCamera
        if camera then scale.Scale=math.min(1,math.max(0.4,(camera.ViewportSize.Y-32)/640),math.max(0.4,(camera.ViewportSize.X-36)/520)) end
    end
    resize()
    if workspace.CurrentCamera then
        ctx.S.connections[#ctx.S.connections+1]=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(resize)
    end
    label(ctx.frame,'SELL LEMONS',20,18,340,23,19,palette.accent)
    label(ctx.frame,'CONTROLLER  /  4.0 DEV',20,46,330,17,10,palette.muted)
    local hide=button('−',466,17,34)
    ctx.S.connections[#ctx.S.connections+1]=hide.Activated:Connect(function()
        ctx.S.panelVisibilityVersion=(ctx.S.panelVisibilityVersion or 0)+1;ctx.panel.Enabled=false
    end)
    ctx.statusLabel=label(card(76,64),ctx.S.status,12,11,460,46,12)
    ctx.economyLabel=label(card(150,64),'',12,11,460,46,12)
    local progress=card(224,181)
    label(progress,'МАРШРУТ И ПРОГРЕСС',12,10,450,16,10,palette.muted)
    local progressScroll=Instance.new('ScrollingFrame');progressScroll.BackgroundTransparency=1
    progressScroll.Position=UDim2.fromOffset(12,34);progressScroll.Size=UDim2.fromOffset(460,126)
    progressScroll.CanvasSize=UDim2.fromOffset(0,0);progressScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    progressScroll.ScrollBarThickness=2;progressScroll.BorderSizePixel=0;progressScroll.Parent=progress
    ctx.evolutionLabel=label(progressScroll,'',0,0,452,0,12,palette.accent)
    ctx.evolutionLabel.AutomaticSize=Enum.AutomaticSize.Y
    ctx.evolutionTrack=Instance.new('Frame');ctx.evolutionTrack.Size=UDim2.fromOffset(460,5)
    ctx.evolutionTrack.Position=UDim2.fromOffset(12,166);ctx.evolutionTrack.BackgroundColor3=palette.line
    ctx.evolutionTrack.BorderSizePixel=0;ctx.evolutionTrack.Parent=progress;round(ctx.evolutionTrack,3)
    ctx.evolutionFill=Instance.new('Frame');ctx.evolutionFill.Size=UDim2.fromScale(0,1)
    ctx.evolutionFill.BackgroundColor3=palette.accent;ctx.evolutionFill.BorderSizePixel=0
    ctx.evolutionFill.Parent=ctx.evolutionTrack;round(ctx.evolutionFill,3)
    ctx.routeLabel=label(card(415,100),'',12,9,460,83,11,palette.muted)
    ctx.countsLabel=label(ctx.frame,'',20,524,480,31,11,palette.muted)
    ctx.startButton=button('Запуск (F6)',18,560,153)
    ctx.startButton.BackgroundColor3=palette.accent;ctx.startButton.TextColor3=palette.background
    ctx.resetsButton=button('Сбросы: ВКЛ',183,560,153)
    ctx.logButton=button('Журнал',348,560,154)
    ctx.backgroundButton=button('Фон: ПРОБА',18,600,122)
    ctx.powerButton=button('Способности: ВКЛ',148,600,154)
    local idle=button('AFK: ВКЛ',310,600,96)
    ctx.closeButton=button('Закрыть',414,600,88)
    ctx.S.connections[#ctx.S.connections+1]=ctx.backgroundButton.Activated:Connect(function()
        ctx.CONFIG.BackgroundMode=ctx.CONFIG.BackgroundMode=='Probe' and 'Pause' or 'Probe'
        ctx.backgroundButton.Text=ctx.CONFIG.BackgroundMode=='Probe' and 'Фон: ПРОБА' or 'Фон: ПАУЗА'
        ctx.S.backgroundVerified=false;ctx.S.backgroundTried=false
    end)
    ctx.S.connections[#ctx.S.connections+1]=ctx.powerButton.Activated:Connect(function()
        ctx.CONFIG.AutoInvestorPowers=not ctx.CONFIG.AutoInvestorPowers
        ctx.powerButton.Text=ctx.CONFIG.AutoInvestorPowers and 'Способности: ВКЛ' or 'Способности: ВЫКЛ'
        if ctx.CONFIG.AutoInvestorPowers then ctx.Strategy.route().powerPending=true end
    end)
    ctx.S.connections[#ctx.S.connections+1]=idle.Activated:Connect(function()
        local current=ctx.API.antiIdle()
        local v=ctx.API.antiIdle(not current.enabled);idle.Text=v.enabled and 'AFK: ВКЛ' or 'AFK: ВЫКЛ'
    end)
    local dragging,origin,panelOrigin
    ctx.frame.Active=true
    ctx.S.connections[#ctx.S.connections+1]=ctx.frame.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1
            and input.Position.Y-ctx.frame.AbsolutePosition.Y<70*scale.Scale then
            dragging=true;origin=input.Position;panelOrigin=ctx.frame.Position
        end
    end)
    ctx.S.connections[#ctx.S.connections+1]=ctx.UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local d=input.Position-origin
            ctx.frame.Position=UDim2.new(panelOrigin.X.Scale,panelOrigin.X.Offset+d.X,panelOrigin.Y.Scale,panelOrigin.Y.Offset+d.Y)
        end
    end)
    ctx.S.connections[#ctx.S.connections+1]=ctx.UIS.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    ctx.exportFrame=nil
end
