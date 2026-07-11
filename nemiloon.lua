-- [[ ИМПОРТ ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

if not Drawing then
    warn("Drawing library not found!")
    return
end

-- [[ КОНФИГУРАЦИЯ ]]
local ConfigPath = "C:\\Xeno\\workspace\\NemiLon\\config.json"

local DefaultConfig = {
    GUI = {
        Open = false,
        Key = "M",
        ShowKeybinds = true
    },
    Aimbot = {
        Enabled = false,
        ToggleMode = false,
        Key = "MouseButton2",
        Smoothness = 0.2,
        FOV = 150,
        AimPart = "Head",
        WallCheck = true,
        ShowFOV = true,
        TargetIndicator = true
    },
    ESP = {
        Enabled = true,
        Box = true,
        BoxType = "Corner",
        Name = true,
        HealthBar = true,
        Distance = true,
        MaxDistance = 1000,
        Highlight = true,
        Arrows = true,
        ArrowSize = 20
    },
    Optimization = {
        ThrottleESP = false,
        ThrottleRate = 0.05,
        DisableDrawingOnFar = true
    },
    Colors = {
        Box = Color3.fromRGB(0, 255, 100),
        Corner = Color3.fromRGB(0, 255, 100),
        Name = Color3.fromRGB(255, 255, 255),
        HealthBar = Color3.fromRGB(0, 255, 0),
        Distance = Color3.fromRGB(200, 200, 200),
        FOV = Color3.fromRGB(255, 255, 255),
        Target = Color3.fromRGB(255, 0, 0),
        Arrow = Color3.fromRGB(255, 255, 255),
        Highlight = Color3.fromRGB(0, 255, 100)
    }
}

-- Загрузка конфига
local Config
if isfile and readfile and isfile(ConfigPath) then
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigPath))
    end)
    if success and type(result) == "table" then
        Config = result
        -- Мержим с дефолтом, чтобы не было nil ошибок при обновлении скрипта
        for cat, vars in pairs(DefaultConfig) do
            if not Config[cat] then Config[cat] = {} end
            for k, v in pairs(vars) do
                if Config[cat][k] == nil then Config[cat][k] = v end
            end
        end
    else
        Config = DefaultConfig
    end
else
    Config = DefaultConfig
end

local function SaveConfig()
    if writefile and makefolder then
        pcall(function()
            makefolder("C:\\Xeno\\workspace\\NemiLon")
            writefile(ConfigPath, HttpService:JSONEncode(Config))
        end)
    end
end

-- [[ ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ]]
local CurrentTarget = nil
local AimbotActive = false
local FOVCircle = Drawing.new("Circle")
local ESPCache = {}
local GUIObjects = {}
local ScriptRemoved = false
local RenderConnection = nil
local ESPThread = nil

-- [[ IMGUI STYLE THEME ]]
local UI = {
    WindowBg = Color3.fromRGB(20, 20, 20),
    ChildBg = Color3.fromRGB(28, 28, 28),
    Border = Color3.fromRGB(0, 0, 0),
    Text = Color3.fromRGB(225, 225, 225),
    TextDisabled = Color3.fromRGB(120, 120, 120),
    FrameBg = Color3.fromRGB(42, 42, 42),
    FrameBgHover = Color3.fromRGB(55, 55, 55),
    TitleBg = Color3.fromRGB(25, 25, 25),
    Accent = Color3.fromRGB(40, 120, 200),
    AccentHover = Color3.fromRGB(55, 135, 215),
    CheckMark = Color3.fromRGB(40, 120, 200),
    Separator = Color3.fromRGB(60, 60, 60)
}

-- [[ ФУНКЦИЯ УДАЛЕНИЯ СКРИПТА ]]
local function RemoveScript()
    ScriptRemoved = true
    if RenderConnection then RenderConnection:Disconnect() end
    if ESPThread then pcall(function() task.cancel(ESPThread) end) end

    if FOVCircle then FOVCircle:Remove() end
    for _, data in pairs(ESPCache) do
        for _, obj in pairs(data.Drawings) do
            if typeof(obj) == "table" then
                for _, subObj in pairs(obj) do pcall(function() subObj:Remove() end) end
            else
                pcall(function() obj:Remove() end)
            end
        end
        if data.Highlight then data.Highlight:Destroy() end
    end
    ESPCache = {}

    for _, obj in ipairs(GUIObjects) do
        pcall(function() obj:Destroy() end)
    end
    GUIObjects = {}

    print("✅ Script removed successfully!")
end

-- [[ РЭЙКАСТ ДЛЯ WALL CHECK ]]
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(part)
    if not part then return false end
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local result = Workspace:Raycast(origin, dir, RayParams)
    if result and result.Instance then
        if result.Instance:IsDescendantOf(part.Parent) then return true end
        return false
    end
    return true
end

local function GetCharacterPart(character, partName)
    if not character then return nil end
    if partName == "Head" then return character:FindFirstChild("Head")
    elseif partName == "Chest" then return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    else return character:FindFirstChild("HumanoidRootPart") end
end

local function GetClosestPlayer()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest, closestDist = nil, Config.Aimbot.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local hum = player.Character.Humanoid
            if hum.Health > 0 then
                local part = GetCharacterPart(player.Character, Config.Aimbot.AimPart)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        if not Config.Aimbot.WallCheck or IsVisible(part) then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closest = player
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- [[ АИМБОТ ]]
local function DoAimbot()
    if not Config.Aimbot.Enabled then return end
    
    if not CurrentTarget or not CurrentTarget.Character or not CurrentTarget.Character:FindFirstChild("Humanoid") or CurrentTarget.Character.Humanoid.Health <= 0 then
        CurrentTarget = GetClosestPlayer()
        return
    end

    local part = GetCharacterPart(CurrentTarget.Character, Config.Aimbot.AimPart)
    if not part then return end

    if Config.Aimbot.WallCheck and not IsVisible(part) then
        CurrentTarget = GetClosestPlayer()
        return
    end

    local targetPos = part.Position
    local currentPos = Camera.CFrame.Position
    local targetCFrame = CFrame.lookAt(currentPos, targetPos)
    local smoothAlpha = math.clamp(1 - Config.Aimbot.Smoothness, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothAlpha)
end

-- [[ ESP ЛОГИКА ]]
local function SetupPlayerCache(player)
    ESPCache[player] = { Drawings = {}, Highlight = nil }
    local c = ESPCache[player].Drawings
    c.Box = Drawing.new("Square")
    c.Name = Drawing.new("Text")
    c.Distance = Drawing.new("Text")
    c.HealthBg = Drawing.new("Square")
    c.HealthFill = Drawing.new("Square")
    c.Corners = {}
    for i=1, 8 do c.Corners[i] = Drawing.new("Line") end
    c.Arrows = {}
    for i=1, 3 do c.Arrows[i] = Drawing.new("Line") end

    local hl = Instance.new("Highlight")
    hl.Parent = CoreGui
    ESPCache[player].Highlight = hl
end

local function UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not ESPCache[player] then SetupPlayerCache(player) end
            local data = ESPCache[player]
            local visible = false
            local hlVisible = false

            local char = player.Character
            if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
                local root = char.HumanoidRootPart
                local head = char.Head
                local hum = char.Humanoid
                local dist = (Camera.CFrame.Position - root.Position).Magnitude

                if dist <= Config.ESP.MaxDistance then
                    -- HIGHLIGHT LOGIC
                    if Config.ESP.Highlight then
                        hlVisible = true
                        data.Highlight.Adornee = char
                        local isTarget = (Config.Aimbot.TargetIndicator and player == CurrentTarget and AimbotActive)
                        data.Highlight.FillColor = isTarget and Config.Colors.Target or Config.Colors.Highlight
                        data.Highlight.OutlineColor = isTarget and Config.Colors.Target or Color3.fromRGB(255,255,255)
                        data.Highlight.FillTransparency = 0.5
                        data.Highlight.OutlineTransparency = 0
                    end

                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        if not Config.Optimization.DisableDrawingOnFar or dist < Config.ESP.MaxDistance * 0.7 then
                            visible = true
                            local screenHead = Camera:WorldToViewportPoint(head.Position)
                            local height = math.abs(screenPos.Y - screenHead.Y) * 2.2
                            local width = height * 0.6
                            local topLeft = Vector2.new(screenPos.X - width / 2, screenPos.Y - height)
                            
                            local isTarget = (Config.Aimbot.TargetIndicator and player == CurrentTarget and AimbotActive)
                            local boxColor = isTarget and Config.Colors.Target or Config.Colors.Box

                            -- BOX
                            if Config.ESP.Box then
                                if Config.ESP.BoxType == "Full" then
                                    data.Drawings.Box.Visible = true
                                    data.Drawings.Box.Size = Vector2.new(width, height)
                                    data.Drawings.Box.Position = topLeft
                                    data.Drawings.Box.Color = boxColor
                                    data.Drawings.Box.Thickness = 1
                                    data.Drawings.Box.Filled = false
                                    for _, l in ipairs(data.Drawings.Corners) do l.Visible = false end
                                else
                                    data.Drawings.Box.Visible = false
                                    local cs = math.min(width, height) * 0.3
                                    local c = isTarget and Config.Colors.Target or Config.Colors.Corner
                                    local ls = data.Drawings.Corners
                                    ls[1].Visible=true; ls[1].From=Vector2.new(topLeft.X, topLeft.Y+cs); ls[1].To=topLeft; ls[1].Color=c
                                    ls[2].Visible=true; ls[2].From=topLeft; ls[2].To=Vector2.new(topLeft.X+cs, topLeft.Y); ls[2].Color=c
                                    ls[3].Visible=true; ls[3].From=Vector2.new(topLeft.X+width-cs, topLeft.Y); ls[3].To=Vector2.new(topLeft.X+width, topLeft.Y); ls[3].Color=c
                                    ls[4].Visible=true; ls[4].From=Vector2.new(topLeft.X+width, topLeft.Y); ls[4].To=Vector2.new(topLeft.X+width, topLeft.Y+cs); ls[4].Color=c
                                    ls[5].Visible=true; ls[5].From=Vector2.new(topLeft.X, topLeft.Y+height-cs); ls[5].To=Vector2.new(topLeft.X, topLeft.Y+height); ls[5].Color=c
                                    ls[6].Visible=true; ls[6].From=Vector2.new(topLeft.X, topLeft.Y+height); ls[6].To=Vector2.new(topLeft.X+cs, topLeft.Y+height); ls[6].Color=c
                                    ls[7].Visible=true; ls[7].From=Vector2.new(topLeft.X+width-cs, topLeft.Y+height); ls[7].To=Vector2.new(topLeft.X+width, topLeft.Y+height); ls[7].Color=c
                                    ls[8].Visible=true; ls[8].From=Vector2.new(topLeft.X+width, topLeft.Y+height-cs); ls[8].To=Vector2.new(topLeft.X+width, topLeft.Y+height); ls[8].Color=c
                                end
                            else data.Drawings.Box.Visible = false; for _, l in ipairs(data.Drawings.Corners) do l.Visible = false end end

                            if Config.ESP.Name then
                                data.Drawings.Name.Visible=true; data.Drawings.Name.Text=player.Name; data.Drawings.Name.Position=Vector2.new(screenPos.X, topLeft.Y-18); data.Drawings.Name.Center=true; data.Drawings.Name.Color=Config.Colors.Name; data.Drawings.Name.Outline=true; data.Drawings.Name.Size=13
                            else data.Drawings.Name.Visible = false end

                            if Config.ESP.Distance then
                                data.Drawings.Distance.Visible=true; data.Drawings.Distance.Text="["..math.floor(dist).."m]"; data.Drawings.Distance.Position=Vector2.new(screenPos.X, topLeft.Y+height+2); data.Drawings.Distance.Center=true; data.Drawings.Distance.Color=Config.Colors.Distance; data.Drawings.Distance.Outline=true; data.Drawings.Distance.Size=13
                            else data.Drawings.Distance.Visible = false end

                            if Config.ESP.HealthBar then
                                local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                                data.Drawings.HealthBg.Visible=true; data.Drawings.HealthBg.Size=Vector2.new(2, height); data.Drawings.HealthBg.Position=Vector2.new(topLeft.X-5, topLeft.Y); data.Drawings.HealthBg.Color=Color3.fromRGB(0,0,0); data.Drawings.HealthBg.Filled=true
                                data.Drawings.HealthFill.Visible=true; data.Drawings.HealthFill.Size=Vector2.new(2, height*hp); data.Drawings.HealthFill.Position=Vector2.new(topLeft.X-5, topLeft.Y+(height-height*hp)); data.Drawings.HealthFill.Color=Color3.fromRGB(255*(1-hp), 255*hp, 0); data.Drawings.HealthFill.Filled=true
                            else data.Drawings.HealthBg.Visible=false; data.Drawings.HealthFill.Visible=false end
                        end
                    else
                        -- OFF-SCREEN ARROWS
                        if Config.ESP.Arrows then
                            local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                            local dir = (Vector2.new(screenPos.X, screenPos.Y) - center)
                            -- Отключаем стрелку, если цель прямо по центру за спиной
                            if dir.Magnitude > 10 then 
                                visible = true
                                local angle = math.atan2(dir.Y, dir.X)
                                local radius = math.min(Camera.ViewportSize.X, Camera.ViewportSize.Y) / 3
                                local arrowPos = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
                                local size = Config.ESP.ArrowSize
                                local p1 = arrowPos + Vector2.new(math.cos(angle + math.rad(150)), math.sin(angle + math.rad(150))) * size
                                local p2 = arrowPos + Vector2.new(math.cos(angle - math.rad(150)), math.sin(angle - math.rad(150))) * size
                                
                                data.Drawings.Arrows[1].Visible=true; data.Drawings.Arrows[1].From=arrowPos; data.Drawings.Arrows[1].To=p1; data.Drawings.Arrows[1].Color=Config.Colors.Arrow; data.Drawings.Arrows[1].Thickness=2
                                data.Drawings.Arrows[2].Visible=true; data.Drawings.Arrows[2].From=arrowPos; data.Drawings.Arrows[2].To=p2; data.Drawings.Arrows[2].Color=Config.Colors.Arrow; data.Drawings.Arrows[2].Thickness=2
                                data.Drawings.Arrows[3].Visible=true; data.Drawings.Arrows[3].From=p1; data.Drawings.Arrows[3].To=p2; data.Drawings.Arrows[3].Color=Config.Colors.Arrow; data.Drawings.Arrows[3].Thickness=2
                                
                                data.Drawings.Box.Visible=false; for _, l in ipairs(data.Drawings.Corners) do l.Visible=false end
                                data.Drawings.Name.Visible=false; data.Drawings.Distance.Visible=false; data.Drawings.HealthBg.Visible=false; data.Drawings.HealthFill.Visible=false
                            end
                        end
                    end
                end
            end

            if not visible then
                data.Drawings.Box.Visible=false; for _, l in ipairs(data.Drawings.Corners) do l.Visible=false end
                data.Drawings.Name.Visible=false; data.Drawings.Distance.Visible=false; data.Drawings.HealthBg.Visible=false; data.Drawings.HealthFill.Visible=false
                for _, l in ipairs(data.Drawings.Arrows) do l.Visible = false end
            end
            if not hlVisible then data.Highlight.Adornee = nil end
        end
    end
end

-- [[ ОЧИСТКА ПРИ ВЫХОДЕ ]]
Players.PlayerRemoving:Connect(function(player)
    if ESPCache[player] then
        for _, obj in pairs(ESPCache[player].Drawings) do
            if typeof(obj) == "table" then for _, sub in pairs(obj) do pcall(function() sub:Remove() end) end
            else pcall(function() obj:Remove() end) end
        end
        if ESPCache[player].Highlight then ESPCache[player].Highlight:Destroy() end
        ESPCache[player] = nil
    end
end)

-- [[ IMGUI GUI LIBRARY ]]
local TooltipText = ""
local CurrentTooltip = nil

local function CreateElement(parent, type, props)
    local el = Instance.new(type)
    for k, v in pairs(props) do el[k] = v end
    el.Parent = parent
    table.insert(GUIObjects, el)
    return el
end

local function MakeDraggable(topFrame, frame)
    local dragging, dragInput, dragStart, startPos
    topFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    topFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function BindTooltip(btn, text)
    btn.MouseEnter:Connect(function() TooltipText = text end)
    btn.MouseLeave:Connect(function() TooltipText = "" end)
end

local function CreateCheckbox(parent, text, state, callback, tooltip)
    local container = CreateElement(parent, "Frame", {Size=UDim2.new(1,-20,0,20), BackgroundTransparency=1})
    local btn = CreateElement(container, "TextButton", {Size=UDim2.new(0,16,0,16), Position=UDim2.new(0,0,0,2), BackgroundColor3=UI.FrameBg, BorderSizePixel=1, BorderColor3=UI.Border, Text="", AutoButtonColor=false})
    local label = CreateElement(container, "TextLabel", {Size=UDim2.new(1,-24,0,20), Position=UDim2.new(0,22,0,0), BackgroundTransparency=1, Text=text, TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSans, TextSize=14})
    
    local function update()
        if state then btn.BackgroundColor3 = UI.Accent; btn.Text = "X"; btn.TextColor3 = Color3.fromRGB(255,255,255); btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 12
        else btn.BackgroundColor3 = UI.FrameBg; btn.Text = "" end
    end
    update()
    btn.MouseButton1Click:Connect(function() state = not state; update(); if callback then callback(state) end end)
    btn.MouseEnter:Connect(function() if not state then btn.BackgroundColor3 = UI.FrameBgHover end end)
    btn.MouseLeave:Connect(function() if not state then btn.BackgroundColor3 = UI.FrameBg end end)
    if tooltip then BindTooltip(label, tooltip); BindTooltip(btn, tooltip) end
    return container
end

local function CreateSlider(parent, text, min, max, step, default, callback, tooltip)
    local container = CreateElement(parent, "Frame", {Size=UDim2.new(1,-20,0,35), BackgroundTransparency=1})
    local valTxt = string.format("%.2f", default)
    CreateElement(container, "TextLabel", {Size=UDim2.new(1,-100,0,15), BackgroundTransparency=1, Text=text, TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSans, TextSize=14})
    CreateElement(container, "TextLabel", {Size=UDim2.new(0,100,0,15), Position=UDim2.new(1,-100,0,0), BackgroundTransparency=1, Text=valTxt, TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Right, Font=Enum.Font.SourceSans, TextSize=14})
    
    local track = CreateElement(container, "Frame", {Size=UDim2.new(1,0,0,6), Position=UDim2.new(0,0,0,20), BackgroundColor3=UI.FrameBg, BorderSizePixel=1, BorderColor3=UI.Border})
    local fill = CreateElement(track, "Frame", {Size=UDim2.new((default-min)/(max-min),0,1,0), BackgroundColor3=UI.Accent, BorderSizePixel=0})
    
    local dragging = false
    local function update(input)
        local pct = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = min + pct * (max - min)
        val = math.floor(val / step + 0.5) * step
        val = math.clamp(val, min, max)
        fill.Size = UDim2.new((val-min)/(max-min), 0, 1, 0)
        container.Children[2].Text = string.format("%.2f", val)
        if callback then callback(val) end
    end
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; update(input) end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end end)
    if tooltip then BindTooltip(container, tooltip) end
    return container
end

local function CreateDropdown(parent, text, options, default, callback, tooltip)
    local container = CreateElement(parent, "Frame", {Size=UDim2.new(1,-20,0,25), BackgroundTransparency=1})
    CreateElement(container, "TextLabel", {Size=UDim2.new(0,100,0,25), BackgroundTransparency=1, Text=text, TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSans, TextSize=14})
    local btn = CreateElement(container, "TextButton", {Size=UDim2.new(0,150,0,20), Position=UDim2.new(1,-150,0,2), BackgroundColor3=UI.FrameBg, BorderSizePixel=1, BorderColor3=UI.Border, Text=default, TextColor3=UI.Text, Font=Enum.Font.SourceSans, TextSize=14, AutoButtonColor=false})
    local idx = table.find(options, default) or 1
    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        btn.Text = options[idx]
        if callback then callback(options[idx]) end
    end)
    if tooltip then BindTooltip(container, tooltip) end
    return container
end

local function CreateColorPicker(parent, text, defaultColor, callback)
    local container = CreateElement(parent, "Frame", {Size=UDim2.new(1,-20,0,20), BackgroundTransparency=1})
    CreateElement(container, "TextLabel", {Size=UDim2.new(1,-30,0,20), BackgroundTransparency=1, Text=text, TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSans, TextSize=14})
    local btn = CreateElement(container, "TextButton", {Size=UDim2.new(0,20,0,20), Position=UDim2.new(1,-20,0,0), BackgroundColor3=defaultColor, BorderSizePixel=1, BorderColor3=UI.Border, Text="", AutoButtonColor=false})
    local colors = {Color3.fromRGB(255,0,0),Color3.fromRGB(0,255,0),Color3.fromRGB(0,0,255),Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,255),Color3.fromRGB(255,0,255),Color3.fromRGB(255,255,255),Color3.fromRGB(0,0,0)}
    local idx = table.find(colors, defaultColor) or 1
    btn.MouseButton1Click:Connect(function() idx=idx%#colors+1; btn.BackgroundColor3=colors[idx]; if callback then callback(colors[idx]) end end)
    return container
end

local function CreateSeparator(parent, text)
    local container = CreateElement(parent, "Frame", {Size=UDim2.new(1,-20,0,20), BackgroundTransparency=1})
    CreateElement(container, "TextLabel", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text=text, TextColor3=UI.TextDisabled, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSansBold, TextSize=13})
    CreateElement(container, "Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,18), BackgroundColor3=UI.Separator, BorderSizePixel=0})
    return container
end

local function CreateButton(parent, text, callback)
    local btn = CreateElement(parent, "TextButton", {Size=UDim2.new(1,-20,0,25), BackgroundColor3=UI.Accent, BorderSizePixel=1, BorderColor3=UI.Border, Text=text, TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.SourceSansBold, TextSize=14, AutoButtonColor=false})
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = UI.AccentHover end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = UI.Accent end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- [[ СБОРКА GUI ]]
local function CreateGUI()
    local screenGui = CreateElement(CoreGui, "ScreenGui", {Name="NemiLonImGui", ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    
    -- Tooltip
    CurrentTooltip = CreateElement(screenGui, "TextLabel", {Visible=false, ZIndex=100, BackgroundColor3=UI.WindowBg, TextColor3=UI.Text, Font=Enum.Font.SourceSans, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true})
    CreateElement(CurrentTooltip, "UIStroke", {Color=UI.Border, Thickness=1})
    
    -- Keybind Visualizer
    local kbFrame = CreateElement(screenGui, "Frame", {Size=UDim2.new(0,180,0,60), Position=UDim2.new(0,20,1,-80), BackgroundColor3=UI.WindowBg, BorderSizePixel=1, BorderColor3=UI.Border, Visible=Config.GUI.ShowKeybinds})
    CreateElement(kbFrame, "UICorner", {CornerRadius=UDim.new(0,2)})
    CreateElement(kbFrame, "TextLabel", {Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Text="Keybinds", TextColor3=UI.Text, Font=Enum.Font.SourceSansBold, TextSize=14})
    local aimbotKb = CreateElement(kbFrame, "TextLabel", {Size=UDim2.new(1,-10,0,20), Position=UDim2.new(0,5,0,25), BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left, TextColor3=UI.TextDisabled, Font=Enum.Font.SourceSans, TextSize=13})

    -- Main Window
    local mainFrame = CreateElement(screenGui, "Frame", {Size=UDim2.new(0,500,0,450), Position=UDim2.new(0.5,-250,0.5,-225), BackgroundColor3=UI.WindowBg, BorderSizePixel=1, BorderColor3=UI.Border, Visible=false, Active=true})
    CreateElement(mainFrame, "UICorner", {CornerRadius=UDim.new(0,2)})
    
    local header = CreateElement(mainFrame, "Frame", {Size=UDim2.new(1,0,0,25), BackgroundColor3=UI.TitleBg, BorderSizePixel=0})
    CreateElement(header, "UICorner", {CornerRadius=UDim.new(0,2)})
    CreateElement(header, "Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,0), BackgroundColor3=UI.Border, BorderSizePixel=0}) -- Header bottom border
    
    local title = CreateElement(header, "TextLabel", {Size=UDim2.new(1,-30,1,0), Position=UDim2.new(0,10,0,0), BackgroundTransparency=1, Text="NemiLon Aim Assist [ImGui]", TextColor3=UI.Text, TextXAlignment=Enum.TextXAlignment.Left, Font=Enum.Font.SourceSansBold, TextSize=14})
    local closeBtn = CreateElement(header, "TextButton", {Size=UDim2.new(0,25,0,25), Position=UDim2.new(1,-25,0,0), BackgroundColor3=UI.TitleBg, Text="X", TextColor3=UI.Text, Font=Enum.Font.SourceSansBold, TextSize=12, AutoButtonColor=false})
    closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible=false end)
    
    MakeDraggable(header, mainFrame)

    local tabContainer = CreateElement(mainFrame, "Frame", {Size=UDim2.new(0,100,1,-25), Position=UDim2.new(0,0,0,25), BackgroundColor3=UI.ChildBg, BorderSizePixel=0})
    CreateElement(tabContainer, "Frame", {Size=UDim2.new(0,1,1,0), Position=UDim2.new(1,-1,0,0), BackgroundColor3=UI.Border, BorderSizePixel=0}) -- Tab right border
    local tabList = CreateElement(tabContainer, "UIListLayout", {Padding=UDim.new(0,0)})

    local contentArea = CreateElement(mainFrame, "Frame", {Size=UDim2.new(1,-100,1,-25), Position=UDim2.new(0,100,0,25), BackgroundColor3=UI.WindowBg, BorderSizePixel=0})
    local tabs = {"Aimbot", "Visuals", "Optimization", "Config"}
    local frames = {}
    local buttons = {}

    for i, name in ipairs(tabs) do
        local btn = CreateElement(tabContainer, "TextButton", {Size=UDim2.new(1,0,0,30), BackgroundColor3=i==1 and UI.FrameBg or UI.ChildBg, BorderSizePixel=0, Text=name, TextColor3=UI.Text, Font=Enum.Font.SourceSans, TextSize=14, AutoButtonColor=false})
        buttons[name] = btn
        
        local frame = CreateElement(contentArea, "ScrollingFrame", {Size=UDim2.new(1,-20,1,-20), Position=UDim2.new(0,10,0,10), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=6, ScrollBarImageColor3=UI.FrameBg, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, Visible=i==1})
        CreateElement(frame, "UIListLayout", {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
        frames[name] = frame

        btn.MouseButton1Click:Connect(function()
            for n, f in pairs(frames) do f.Visible = (n == name) end
            for n, b in pairs(buttons) do b.BackgroundColor3 = (n == name) and UI.FrameBg or UI.ChildBg end
        end)
    end

    -- AIMBOT TAB
    local af = frames["Aimbot"]
    CreateCheckbox(af, "Enable Aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled=v end, "Включить наведение")
    CreateCheckbox(af, "Toggle Mode", Config.Aimbot.ToggleMode, function(v) Config.Aimbot.ToggleMode=v end, "Удерживать или переключать")
    CreateCheckbox(af, "Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck=v end, "Не целиться сквозь стены")
    CreateCheckbox(af, "Target Indicator", Config.Aimbot.TargetIndicator, function(v) Config.Aimbot.TargetIndicator=v end, "Подсвечивать текущую цель")
    CreateCheckbox(af, "Show FOV Circle", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV=v end, "Рисовать круг радиуса")
    CreateDropdown(af, "Aim Key", {"MouseButton1","MouseButton2","Q","E","R","F","Shift","Ctrl","Alt","C","V"}, Config.Aimbot.Key, function(v) Config.Aimbot.Key=v end)
    CreateDropdown(af, "Aim Part", {"Head","Chest","HumanoidRootPart"}, Config.Aimbot.AimPart, function(v) Config.Aimbot.AimPart=v end)
    CreateSlider(af, "Smoothness", 0, 0.99, 0.01, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness=v end)
    CreateSlider(af, "FOV Radius", 50, 500, 5, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV=v end)

    -- VISUALS TAB
    local vf = frames["Visuals"]
    CreateSeparator(vf, "ESP")
    CreateCheckbox(vf, "Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled=v end)
    CreateCheckbox(vf, "Show Box", Config.ESP.Box, function(v) Config.ESP.Box=v end)
    CreateDropdown(vf, "Box Type", {"Full","Corner"}, Config.ESP.BoxType, function(v) Config.ESP.BoxType=v end)
    CreateCheckbox(vf, "Name", Config.ESP.Name, function(v) Config.ESP.Name=v end)
    CreateCheckbox(vf, "Distance", Config.ESP.Distance, function(v) Config.ESP.Distance=v end)
    CreateCheckbox(vf, "Health Bar", Config.ESP.HealthBar, function(v) Config.ESP.HealthBar=v end)
    CreateSlider(vf, "Max Distance", 100, 3000, 50, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance=v end)
    
    CreateSeparator(vf, "Render Features")
    CreateCheckbox(vf, "Highlight (Chams)", Config.ESP.Highlight, function(v) Config.ESP.Highlight=v end, "Подсветка моделей сквозь стены")
    CreateCheckbox(vf, "Off-Screen Arrows", Config.ESP.Arrows, function(v) Config.ESP.Arrows=v end, "Стрелки к врагам вне экрана")
    CreateSlider(vf, "Arrow Size", 5, 50, 1, Config.ESP.ArrowSize, function(v) Config.ESP.ArrowSize=v end)

    CreateSeparator(vf, "Colors")
    CreateColorPicker(vf, "Box/Corner", Config.Colors.Box, function(v) Config.Colors.Box=v; Config.Colors.Corner=v end)
    CreateColorPicker(vf, "Name", Config.Colors.Name, function(v) Config.Colors.Name=v end)
    CreateColorPicker(vf, "Health", Config.Colors.HealthBar, function(v) Config.Colors.HealthBar=v end)
    CreateColorPicker(vf, "Distance", Config.Colors.Distance, function(v) Config.Colors.Distance=v end)
    CreateColorPicker(vf, "FOV Circle", Config.Colors.FOV, function(v) Config.Colors.FOV=v end)
    CreateColorPicker(vf, "Target Indicator", Config.Colors.Target, function(v) Config.Colors.Target=v end)
    CreateColorPicker(vf, "Highlight", Config.Colors.Highlight, function(v) Config.Colors.Highlight=v end)
    CreateColorPicker(vf, "Arrows", Config.Colors.Arrow, function(v) Config.Colors.Arrow=v end)

    -- OPTIMIZATION TAB
    local of = frames["Optimization"]
    CreateSeparator(of, "Performance")
    CreateCheckbox(of, "Throttle ESP Update", Config.Optimization.ThrottleESP, function(v) Config.Optimization.ThrottleESP=v end, "Обновлять ESP в отельном потоке (повышает ФПС)")
    CreateSlider(of, "Throttle Rate (sec)", 0.01, 0.2, 0.01, Config.Optimization.ThrottleRate, function(v) Config.Optimization.ThrottleRate=v end, "Задержка обновления ESP")
    CreateCheckbox(of, "Disable Drawing When Far", Config.Optimization.DisableDrawingOnFar, function(v) Config.Optimization.DisableDrawingOnFar=v end, "Не рисовать 2D ESP на дальних дистанциях (оставляет Highlight)")
    
    -- CONFIG TAB
    local cf = frames["Config"]
    CreateSeparator(cf, "Settings")
    CreateCheckbox(cf, "Show Keybind Visualizer", Config.GUI.ShowKeybinds, function(v) Config.GUI.ShowKeybinds=v; kbFrame.Visible=v end)
    CreateDropdown(cf, "GUI Toggle Key", {"M","N","B","V","C","Insert","Delete","F1","F2"}, Config.GUI.Key, function(v) Config.GUI.Key=v end)
    
    CreateSeparator(cf, "Config Management")
    CreateButton(cf, "Save Config", SaveConfig)
    CreateButton(cf, "Remove Script", RemoveScript)

    -- Tooltip Update Loop
    RunService.RenderStepped:Connect(function()
        if TooltipText ~= "" then
            CurrentTooltip.Text = TooltipText
            CurrentTooltip.Size = UDim2.new(0, TextService:GetTextSize(TooltipText, 13, Enum.Font.SourceSans, Vector2.new(250, 100)).X + 10, 0, TextService:GetTextSize(TooltipText, 13, Enum.Font.SourceSans, Vector2.new(250, 100)).Y + 6)
            CurrentTooltip.Position = UDim2.new(0, Mouse.X + 15, 0, Mouse.Y + 15)
            CurrentTooltip.Visible = true
        else
            CurrentTooltip.Visible = false
        end
        
        -- Keybind Vis Update
        aimbotKb.Text = string.format("[ %s ] Aimbot: %s", Config.Aimbot.Key, AimbotActive and "ON" or "OFF")
        aimbotKb.TextColor3 = AimbotActive and Color3.fromRGB(0, 255, 0) or UI.TextDisabled
    end)

    -- GUI Toggle
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or ScriptRemoved then return end
        local keyEnum = Enum.KeyCode[Config.GUI.Key]
        if keyEnum and input.KeyCode == keyEnum then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)
end

-- [[ ИНИЦИАЛИЗАЦИЯ FOV ]]
FOVCircle.Thickness = 1
FOVCircle.Transparency = 0.5
FOVCircle.Filled = false
FOVCircle.Visible = false

-- [[ ОБРАБОТКА КЛАВИШ АИМБОТА ]]
local function IsAimKeyDown()
    if Config.Aimbot.Key == "MouseButton1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif Config.Aimbot.Key == "MouseButton2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    else return UserInputService:IsKeyDown(Enum.KeyCode[Config.Aimbot.Key]) end
end

CreateGUI()

-- [[ ОСНОВНЫЕ ЦИКЛЫ ]]
RenderConnection = RunService.RenderStepped:Connect(function()
    if ScriptRemoved then return end

    if not Config.Aimbot.ToggleMode then
        AimbotActive = IsAimKeyDown()
    end

    if AimbotActive and Config.Aimbot.Enabled then
        DoAimbot()
    else
        CurrentTarget = nil
    end

    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Color = Config.Colors.FOV
    FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled

    if not Config.Optimization.ThrottleESP then
        UpdateESP()
    end
end)

-- Throttled ESP Loop
ESPThread = task.spawn(function()
    while not ScriptRemoved do
        if Config.Optimization.ThrottleESP then
            UpdateESP()
            task.wait(Config.Optimization.ThrottleRate)
        else
            task.wait(1) -- Sleep if not throttled to save cpu
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or ScriptRemoved then return end
    if Config.Aimbot.ToggleMode then
        local triggered = false
        if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.Aimbot.Key == "MouseButton1" then triggered = true end
        if input.UserInputType == Enum.UserInputType.MouseButton2 and Config.Aimbot.Key == "MouseButton2" then triggered = true end
        if input.KeyCode == Enum.KeyCode[Config.Aimbot.Key] then triggered = true end

        if triggered then AimbotActive = not AimbotActive end
    end
end)

print("✅ NemiLon Script loaded. Press " .. Config.GUI.Key .. " to open GUI.")
