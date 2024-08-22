include("hud/cl_draw.lua")
include("hud/cl_hide.lua")

isDarkRP = false
gamemodeChecked = false

-- Try to get the DarkRP variable, if there is an error, set isDarkRP to false, otherwise to true
-- This prevents any errors when playing single-player and not on DarkRP
local success, _ = pcall(function()
	isDarkRP = DarkRP ~= nil
end)

hook.Add("HUDPaint", "DrawCustomHUD", DrawCustomHUD)
-- Include necessary HUD files
include("hud/cl_draw.lua")
include("hud/cl_hide.lua")

-- Configuration variables
local isDarkRP = false
local gamemodeChecked = false

-- Function to check if the current gamemode is DarkRP
local function CheckDarkRPGamemode()
    local success, err = pcall(function()
        isDarkRP = DarkRP ~= nil
    end)
    if not success then
        isDarkRP = false
        print("Error checking DarkRP gamemode: " .. err)
    end
end

-- Check if the gamemode is DarkRP
CheckDarkRPGamemode()

-- Hook to draw the custom HUD
hook.Add("HUDPaint", "DrawCustomHUD", DrawCustomHUD)