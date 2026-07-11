local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local UI = {}

function UI:Init(Library, Config, Core)
    local Window = Library:CreateWindow("NemiLon Aim Assist", Vector2.new(600, 450), Enum.KeyCode.M)

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

    ConfigTab:Label("Visualizer")
    ConfigTab:Toggle("Show Keybind Visualizer", Config.GUI.ShowKeybinds, function(v) Config.GUI.ShowKeybinds = v; kbFrame.Visible = v end)

    ConfigTab:Label("Config Management")
    ConfigTab:Button("Save Config", function() Config.Save() end)
    ConfigTab:Button("Remove Script", function() Core:RemoveScript(Library) end)

    -- MAIN LOOPS
    Core.RenderConnection = RunService.RenderStepped:Connect(function()
        if Core.ScriptRemoved then return end

        if not Config.Aimbot.ToggleMode then
            Core.AimbotActive = Core:IsAimKeyDown()
        end

        if Core.AimbotActive and Config.Aimbot.Enabled then
            Core:DoAimbot()
        else
            Core.CurrentTarget = nil
        end

        Core.FOVCircle.Position = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y / 2)
        Core.FOVCircle.Radius = Config.Aimbot.FOV
        Core.FOVCircle.Color = Config.Colors.FOV
        Core.FOVCircle.Visible = Config.Aimbot.ShowFOV and Config.Aimbot.Enabled

        aimbotKb.Text = string.format("[ %s ] Aimbot: %s", Config.Aimbot.Key, Core.AimbotActive and "ON" or "OFF")
        aimbotKb.TextColor3 = Core.AimbotActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(120, 120, 120)

        if not Config.Optimization.ThrottleESP then
            Core:UpdateESP()
        end
    end)

    Core.ESPThread = task.spawn(function()
        while not Core.ScriptRemoved do
            if Config.Optimization.ThrottleESP then
                Core:UpdateESP()
                task.wait(Config.Optimization.ThrottleRate)
            else
                task.wait(1)
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp or Core.ScriptRemoved then return end
        if Config.Aimbot.ToggleMode then
            local triggered = false
            if input.UserInputType == Enum.UserInputType.MouseButton1 and Config.Aimbot.Key == "MouseButton1" then triggered = true end
            if input.UserInputType == Enum.UserInputType.MouseButton2 and Config.Aimbot.Key == "MouseButton2" then triggered = true end
            if input.KeyCode == Enum.KeyCode[Config.Aimbot.Key] then triggered = true end

            if triggered then Core.AimbotActive = not Core.AimbotActive end
        end
    end)
end

return UI
