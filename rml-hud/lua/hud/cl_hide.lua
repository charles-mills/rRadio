-- hud/cl_hide.lua

-- Hide default GMod HUD elements
local hideHUDElements = {
    ["CHudHealth"] = true,
    ["CHudBattery"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true
}

hook.Add("HUDShouldDraw", "HideDefaultHUD", function(name)
    if hideHUDElements[name] then
        return false
    end
end)

-- Hide DarkRP HUD elements by overriding DarkRP's HUD functions directly
hook.Add("HUDPaint", "HideDarkRPHud", function()
    if DarkRP then
        -- Disable DarkRP's HUD functions by returning false from the hook
        hook.Remove("HUDPaint", "DarkRP_HUD")
        hook.Remove("HUDPaint", "DarkRP_EntityDisplay")
        hook.Remove("HUDPaint", "DarkRP_LocalPlayerHUD")
        hook.Remove("HUDPaint", "DarkRP_Agenda")
        hook.Remove("HUDPaint", "DarkRP_Hungermod")
        hook.Remove("HUDPaint", "DarkRP_LockdownHUD")
    end
end)
