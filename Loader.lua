-- [[ NemiLon Loader ]]
local BaseURL = "https://raw.githubusercontent.com/Whysuk1me/robloxscripts/imgui/"

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/RiseBlox/Depthso-Roblox-ImGui/main/ImGui.lua"))()

local ConfigModule = loadstring(game:HttpGet(BaseURL .. "Config.lua"))()
local CoreModule = loadstring(game:HttpGet(BaseURL .. "Core.lua"))()
local UIModule = loadstring(game:HttpGet(BaseURL .. "UI.lua"))()

CoreModule:Init(ConfigModule)
UIModule:Init(Library, ConfigModule, CoreModule)

print("NemiLon Modular Script loaded.")
