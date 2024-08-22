
-- Cache screen dimensions
local screenW, screenH = ScrW(), ScrH()

-- Recalculate screen dimensions if resolution changes
hook.Add("OnScreenSizeChanged", "HUD_RecalculateScreenSize", function()
    screenW, screenH = ScrW(), ScrH()
end)


if CLIENT then
    include("config/config.lua")
    include("hud/cl_hud.lua")
end
