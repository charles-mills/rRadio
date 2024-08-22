include("hud/cl_draw.lua")
include("hud/cl_hide.lua")

hook.Add("HUDPaint", "DrawCustomHUD", DrawCustomHUD)
