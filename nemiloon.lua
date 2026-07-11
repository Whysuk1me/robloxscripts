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

-- [[ ЗАГРУЗКА GUI БИБЛИОТЕКИ DEPTHSO (ОРИГИНАЛЬНЫЙ РЕПОЗИТОРИЙ) ]]
local Library
local success, err = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Depthso/Roblox-ImGui/main/ImGui.lua"))()
end)

if not success or type(Library) ~= "table" then
    warn("Failed to load Depthso ImGui Library. Error: " .. tostring(err))
    warn("Library returned: " .. tostring(Library))
    return
end

-- [[ КОНФИГУРАЦИЯ ]]
local ConfigPath = "C:\\Xeno\\workspace\\NemiLon\\config.json"

local DefaultConfig = {
    GUI = {
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
local ScriptRemoved = false
local RenderConnection = nil
local ESPThread = nil

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

    if Library and Library.Unload then
        Library:Unload()
    end

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

-- [[ СОЗДАНИЕ GUI DEPTHSO ]]
-- Совместимость с разными версиями либы (CreateWindow / Window)
local Window
if Library.CreateWindow then
    Window = Library:CreateWindow("NemiLon Aim Assist", Vector2.new(600, 450), Enum.KeyCode.M)
elseif Library.Window then
    Window = Library:Window("NemiLon Aim Assist", Vector2.new(600, 450), Enum.KeyCode.M)
else
    warn("Depthso ImGui Error: Cannot find CreateWindow or Window method.")
    return
end

local AimbotTab = Window:Tab("Aimbot")
local VisualsTab = Window:Tab("Visuals")
local OptimizationTab = Window:Tab("Optimization")
local ConfigTab = Window:Tab("Config")

-- AIMBOT TAB
AimbotTab:Toggle("Enable Aimbot", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
AimbotTab:Toggle("Toggle Mode", Config.Aimbot.ToggleMode, function(v) Config.Aimbot.ToggleMode = v end)
AimbotTab:Toggle("Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
AimbotTab:Toggle("Target Indicator", Config.Aimbot.TargetIndicator, function(v) Config.Aimbot.TargetIndicator = v end)
AimbotTab:Toggle("Show FOV Circle", Config.Aimbot.ShowFOV, function(v) Config.Aimbot.ShowFOV = v end)
AimbotTab:Dropdown("Aim Key", {"MouseButton1", "MouseButton2", "Q", "E", "R", "F", "Shift", "Ctrl", "Alt", "C", "V"}, Config.Aimbot.Key, function(v) Config.Aimbot.Key = v end)
AimbotTab:Dropdown("Aim Part", {"Head", "Chest", "HumanoidRootPart"}, Config.Aimbot.AimPart, function(v) Config.Aimbot.AimPart = v end)
AimbotTab:Slider("Smoothness", 0, 0.99, 0.01, Config.Aimbot.Smoothness, function(v) Config.Aimbot.Smoothness = v end)
AimbotTab:Slider("FOV Radius", 50, 500, 5, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)

-- VISUALS TAB
VisualsTab:Label("ESP Settings")
VisualsTab:Toggle("Enable ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
VisualsTab:Toggle("Show Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
VisualsTab:Dropdown("Box Type", {"Full", "Corner"}, Config.ESP.BoxType, function(v) Config.ESP.BoxType = v end)
VisualsTab:Toggle("Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
VisualsTab:Toggle("Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
VisualsTab:Toggle("Health Bar", Config.ESP.HealthBar, function(v) Config.ESP.HealthBar = v end)
VisualsTab:Slider("Max Distance", 100, 3000, 50, Config.ESP.MaxDistance, function(v) Config.ESP.MaxDistance = v end)

VisualsTab:Label("Render Features")
VisualsTab:Toggle("Highlight (Chams)", Config.ESP.Highlight, function(v) Config.ESP.Highlight = v end)
VisualsTab:Toggle("Off-Screen Arrows", Config.ESP.Arrows, function(v) Config.ESP.Arrows = v end)
VisualsTab:Slider("Arrow Size", 5, 50, 1, Config.ESP.ArrowSize, function(v) Config.ESP.ArrowSize = v end)

VisualsTab:Label("Colors")
VisualsTab:ColorPicker("Box/Corner", Config.Colors.Box, function(v) Config.Colors.Box=v; Config.Colors.Corner=v end)
VisualsTab:ColorPicker("Name", Config.Colors.Name, function(v) Config.Colors.Name = v end)
VisualsTab:ColorPicker("Health", Config.Colors.HealthBar, function(v) Config.Colors.HealthBar = v end)
VisualsTab:ColorPicker("Distance", Config.Colors.Distance, function(v) Config.Colors.Distance = v end)
VisualsTab:ColorPicker("FOV Circle", Config.Colors.FOV, function(v) Config.Colors.FOV = v end)
VisualsTab:ColorPicker("Target Indicator", Config.Colors.Target, function(v) Config.Colors.Target = v end)
VisualsTab:ColorPicker("Highlight", Config.Colors.Highlight, function(v) Config.Colors.Highlight = v end)
VisualsTab:ColorPicker("Arrows", Config.Colors.Arrow, function(v) Config.Colors.Arrow = v end)

-- OPTIMIZATION TAB
OptimizationTab:Label("Performance Tuning")
OptimizationTab:Toggle("Throttle ESP Update", Config.Optimization.ThrottleESP, function(v) Config.Optimization.ThrottleESP = v end)
OptimizationTab:Slider("Throttle Rate (sec)", 0.01, 0.2, 0.01, Config.Optimization.ThrottleRate, function(v) Config.Optimization.ThrottleRate = v end)
OptimizationTab:Toggle("Disable Drawing When Far", Config.Optimization.DisableDrawingOnFar, function(v) Config.Optimization.DisableDrawingOnFar = v end)

-- CONFIG TAB
ConfigTab:Label("Visualizer")
ConfigTab:Toggle("Show Keybind Visualizer", Config.GUI.ShowKeybinds, function(v) Config.GUI.ShowKeybinds = v; kbFrame.Visible = v end)

ConfigTab:Label("Config Management")
ConfigTab:Button("Save Config", SaveConfig)
ConfigTab:Button("Remove Script", RemoveScript)

-- [[ KEYBIND VISUALIZER ]]
local kbFrame = Instance.new("Frame")
kbFrame.Size = UDim2.new(0, 180, 0, 60)
kbFrame.Position = UDim2.new(0, 20, 1, -80)
kbFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
kbFrame.BorderSizePixel = 1
kbFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
kbFrame.Visible = Config.GUI.ShowKeybinds
kbFrame.Parent = CoreGui

local kbCorner = Instance.new("UICorner", kbFrame)
kbCorner.CornerRadius = UDim.new(0, 2)

local kbTitle = Instance.new("TextLabel", kbFrame)
kbTitle.Size = UDim2.new(1, 0, 0, 20)
kbTitle.BackgroundTransparency = 1
kbTitle.Text = "Keybinds"
kbTitle.TextColor3 = Color3.fromRGB(225, 225, 225)
kbTitle.Font = Enum.Font.SourceSansBold
kbTitle.TextSize = 14

local aimbotKb = Instance.new("TextLabel", kbFrame)
aimbotKb.Size = UDim2.new(1, -10, 0, 20)
aimbotKb.Position = UDim2.new(0, 5, 0, 25)
aimbotKb.BackgroundTransparency = 1
aimbotKb.TextXAlignment = Enum.TextXAlignment.Left
aimbotKb.TextColor3 = Color3.fromRGB(120, 120, 120)
aimbotKb.Font = Enum.Font.SourceSans
aimbotKb.TextSize = 13

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

    -- Keybind Vis Update
    aimbotKb.Text = string.format("[ %s ] Aimbot: %s", Config.Aimbot.Key, AimbotActive and "ON" or "OFF")
    aimbotKb.TextColor3 = AimbotActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(120, 120, 120)

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
            task.wait(1)
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

print("✅ NemiLon Script loaded with Depthso ImGui. Press M to open GUI.")
