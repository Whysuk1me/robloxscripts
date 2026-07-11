local HttpService = game:GetService("HttpService")

local ConfigPath = "C:\\Xeno\\workspace\\NemiLon\\config.json"

local ConfigModule = {
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

function ConfigModule.Save()
    if writefile and makefolder then
        pcall(function()
            makefolder("C:\\Xeno\\workspace\\NemiLon")
            writefile(ConfigPath, HttpService:JSONEncode(ConfigModule))
        end)
    end
end

if isfile and readfile and isfile(ConfigPath) then
    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigPath))
    end)
    if success and type(result) == "table" then
        for cat, vars in pairs(ConfigModule) do
            if type(vars) == "table" and not result[cat] then result[cat] = {} end
            if type(vars) == "table" then
                for k, v in pairs(vars) do
                    if result[cat][k] == nil then result[cat][k] = v end
                end
            end
        end
        for k, v in pairs(result) do ConfigModule[k] = v end
    end
end

return ConfigModule
