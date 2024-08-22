-- Function to hide default and DarkRP HUD elements
hook.Add("HUDShouldDraw", "HideDefaultAndDarkRPHUD", function(name)
    -- List of default HUD elements to hide
    local hideHUDElements = {
        ["CHudHealth"] = true,
        ["CHudBattery"] = true,
        ["CHudAmmo"] = true,
        ["CHudSecondaryAmmo"] = true,
    }

    -- List of DarkRP-specific HUD elements to hide
    local hideDarkRPHudElements = {
        ["DarkRP_HUD"] = true,
        ["DarkRP_EntityDisplay"] = true,
        ["DarkRP_LocalPlayerHUD"] = true,
        ["DarkRP_Agenda"] = true,
        ["DarkRP_Hungermod"] = true,
        ["DarkRP_LockdownHUD"] = true,
    }

    -- If the name matches any element in the hide lists, return false to hide it
    if hideHUDElements[name] or hideDarkRPHudElements[name] then
        return false
    end

    -- Otherwise, allow other HUD elements (like your custom HUD) to be drawn
    return true
end)
