local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local Core = {}
Core.CurrentTarget = nil
Core.AimbotActive = false
Core.ScriptRemoved = false
Core.FOVCircle = Drawing.new("Circle")
Core.ESPCache = {}
Core.RenderConnection = nil
Core.ESPThread = nil
Core.Config = nil

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

function Core:Init(Config)
    self.Config = Config
    
    self.FOVCircle.Thickness = 1
    self.FOVCircle.Transparency = 0.5
    self.FOVCircle.Filled = false
    self.FOVCircle.Visible = false

    Players.PlayerRemoving:Connect(function(player)
        if self.ESPCache[player] then
            for _, obj in pairs(self.ESPCache[player].Drawings) do
                if typeof(obj) == "table" then for _, sub in pairs(obj) do pcall(function() sub:Remove() end) end
                else pcall(function() obj:Remove() end) end
            end
            if self.ESPCache[player].Highlight then self.ESPCache[player].Highlight:Destroy() end
            self.ESPCache[player] = nil
        end
    end)
end

function Core:IsVisible(part)
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

function Core:GetCharacterPart(character, partName)
    if not character then return nil end
    if partName == "Head" then return character:FindFirstChild("Head")
    elseif partName == "Chest" then return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    else return character:FindFirstChild("HumanoidRootPart") end
end

function Core:GetClosestPlayer()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest, closestDist = nil, self.Config.Aimbot.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local hum = player.Character.Humanoid
            if hum.Health > 0 then
                local part = self:GetCharacterPart(player.Character, self.Config.Aimbot.AimPart)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        if not self.Config.Aimbot.WallCheck or self:IsVisible(part) then
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

function Core:DoAimbot()
    if not self.Config.Aimbot.Enabled then return end
    
    if not self.CurrentTarget or not self.CurrentTarget.Character or not self.CurrentTarget.Character:FindFirstChild("Humanoid") or self.CurrentTarget.Character.Humanoid.Health <= 0 then
        self.CurrentTarget = self:GetClosestPlayer()
        return
    end

    local part = self:GetCharacterPart(self.CurrentTarget.Character, self.Config.Aimbot.AimPart)
    if not part then return end

    if self.Config.Aimbot.WallCheck and not self:IsVisible(part) then
        self.CurrentTarget = self:GetClosestPlayer()
        return
    end

    local targetPos = part.Position
    local currentPos = Camera.CFrame.Position
    local targetCFrame = CFrame.lookAt(currentPos, targetPos)
    local smoothAlpha = math.clamp(1 - self.Config.Aimbot.Smoothness, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothAlpha)
end

function Core:SetupPlayerCache(player)
    self.ESPCache[player] = { Drawings = {}, Highlight = nil }
    local c = self.ESPCache[player].Drawings
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
    self.ESPCache[player].Highlight = hl
end

function Core:UpdateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if not self.ESPCache[player] then self:SetupPlayerCache(player) end
            local data = self.ESPCache[player]
            local visible = false
            local hlVisible = false

            local char = player.Character
            if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") then
                local root = char.HumanoidRootPart
                local head = char.Head
                local hum = char.Humanoid
                local dist = (Camera.CFrame.Position - root.Position).Magnitude

                if dist <= self.Config.ESP.MaxDistance then
                    if self.Config.ESP.Highlight then
                        hlVisible = true
                        data.Highlight.Adornee = char
                        local isTarget = (self.Config.Aimbot.TargetIndicator and player == self.CurrentTarget and self.AimbotActive)
                        data.Highlight.FillColor = isTarget and self.Config.Colors.Target or self.Config.Colors.Highlight
                        data.Highlight.OutlineColor = isTarget and self.Config.Colors.Target or Color3.fromRGB(255,255,255)
                        data.Highlight.FillTransparency = 0.5
                        data.Highlight.OutlineTransparency = 0
                    end

                    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        if not self.Config.Optimization.DisableDrawingOnFar or dist < self.Config.ESP.MaxDistance * 0.7 then
                            visible = true
                            local screenHead = Camera:WorldToViewportPoint(head.Position)
                            local height = math.abs(screenPos.Y - screenHead.Y) * 2.2
                            local width = height * 0.6
                            local topLeft = Vector2.new(screenPos.X - width / 2, screenPos.Y - height)
                            
                            local isTarget = (self.Config.Aimbot.TargetIndicator and player == self.CurrentTarget and self.AimbotActive)
                            local boxColor = isTarget and self.Config.Colors.Target or self.Config.Colors.Box

                            if self.Config.ESP.Box then
                                if self.Config.ESP.BoxType == "Full" then
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
                                    local c = isTarget and self.Config.Colors.Target or self.Config.Colors.Corner
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

                            if self.Config.ESP.Name then
                                data.Drawings.Name.Visible=true; data.Drawings.Name.Text=player.Name; data.Drawings.Name.Position=Vector2.new(screenPos.X, topLeft.Y-18); data.Drawings.Name.Center=true; data.Drawings.Name.Color=self.Config.Colors.Name; data.Drawings.Name.Outline=true; data.Drawings.Name.Size=13
                            else data.Drawings.Name.Visible = false end

                            if self.Config.ESP.Distance then
                                data.Drawings.Distance.Visible=true; data.Drawings.Distance.Text="["..math.floor(dist).."m]"; data.Drawings.Distance.Position=Vector2.new(screenPos.X, topLeft.Y+height+2); data.Drawings.Distance.Center=true; data.Drawings.Distance.Color=self.Config.Colors.Distance; data.Drawings.Distance.Outline=true; data.Drawings.Distance.Size=13
                            else data.Drawings.Distance.Visible = false end

                            if self.Config.ESP.HealthBar then
                                local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                                data.Drawings.HealthBg.Visible=true; data.Drawings.HealthBg.Size=Vector2.new(2, height); data.Drawings.HealthBg.Position=Vector2.new(topLeft.X-5, topLeft.Y); data.Drawings.HealthBg.Color=Color3.fromRGB(0,0,0); data.Drawings.HealthBg.Filled=true
                                data.Drawings.HealthFill.Visible=true; data.Drawings.HealthFill.Size=Vector2.new(2, height*hp); data.Drawings.HealthFill.Position=Vector2.new(topLeft.X-5, topLeft.Y+(height-height*hp)); data.Drawings.HealthFill.Color=Color3.fromRGB(255*(1-hp), 255*hp, 0); data.Drawings.HealthFill.Filled=true
                            else data.Drawings.HealthBg.Visible=false; data.Drawings.HealthFill.Visible=false end
                        end
                    else
                        if self.Config.ESP.Arrows then
                            local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                            local dir = (Vector2.new(screenPos.X, screenPos.Y) - center)
                            if dir.Magnitude > 10 then 
                                visible = true
                                local angle = math.atan2(dir.Y, dir.X)
                                local radius = math.min(Camera.ViewportSize.X, Camera.ViewportSize.Y) / 3
                                local arrowPos = center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
                                local size = self.Config.ESP.ArrowSize
                                local p1 = arrowPos + Vector2.new(math.cos(angle + math.rad(150)), math.sin(angle + math.rad(150))) * size
                                local p2 = arrowPos + Vector2.new(math.cos(angle - math.rad(150)), math.sin(angle - math.rad(150))) * size
                                
                                data.Drawings.Arrows[1].Visible=true; data.Drawings.Arrows[1].From=arrowPos; data.Drawings.Arrows[1].To=p1; data.Drawings.Arrows[1].Color=self.Config.Colors.Arrow; data.Drawings.Arrows[1].Thickness=2
                                data.Drawings.Arrows[2].Visible=true; data.Drawings.Arrows[2].From=arrowPos; data.Drawings.Arrows[2].To=p2; data.Drawings.Arrows[2].Color=self.Config.Colors.Arrow; data.Drawings.Arrows[2].Thickness=2
                                data.Drawings.Arrows[3].Visible=true; data.Drawings.Arrows[3].From=p1; data.Drawings.Arrows[3].To=p2; data.Drawings.Arrows[3].Color=self.Config.Colors.Arrow; data.Drawings.Arrows[3].Thickness=2
                                
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

function Core:IsAimKeyDown()
    if self.Config.Aimbot.Key == "MouseButton1" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif self.Config.Aimbot.Key == "MouseButton2" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    else return UserInputService:IsKeyDown(Enum.KeyCode[self.Config.Aimbot.Key]) end
end

function Core:RemoveScript(Library)
    self.ScriptRemoved = true
    if self.RenderConnection then self.RenderConnection:Disconnect() end
    if self.ESPThread then pcall(function() task.cancel(self.ESPThread) end) end

    if self.FOVCircle then self.FOVCircle:Remove() end
    for _, data in pairs(self.ESPCache) do
        for _, obj in pairs(data.Drawings) do
            if typeof(obj) == "table" then
                for _, subObj in pairs(obj) do pcall(function() subObj:Remove() end) end
            else
                pcall(function() obj:Remove() end)
            end
        end
        if data.Highlight then data.Highlight:Destroy() end
    end
    self.ESPCache = {}

    if Library and Library.Unload then
        Library:Unload()
    end
    print("✅ Script removed successfully!")
end

return Core
