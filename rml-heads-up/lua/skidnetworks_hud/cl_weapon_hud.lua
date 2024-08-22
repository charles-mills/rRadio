-- Define the fonts used in the weapon HUD
surface.CreateFont("Trebuchet32", {
    font = "Trebuchet MS",
    size = 32,
    weight = 500,
    antialias = true,
    shadow = true,
})

surface.CreateFont("Trebuchet24", {
    font = "Trebuchet MS",
    size = 24,
    weight = 500,
    antialias = true,
    shadow = true,
})

-- Hide default DarkRP HUD elements
local hideElements = {
    ["DarkRP_HUD"] = true,
    ["DarkRP_EntityDisplay"] = true,
    ["DarkRP_ZombieInfo"] = true,
    ["DarkRP_LocalPlayerHUD"] = true,
    ["DarkRP_Hungermod"] = true,
    ["CHudAmmo"] = true,
    ["CHudSecondaryAmmo"] = true,
}

hook.Add("HUDShouldDraw", "HideDefaultWeaponHUD", function(name)
    if hideElements[name] then
        return false
    end
end)

-- Hide CW2.0 Fire Mode HUD
hook.Add("CW20_FireModeHUDShouldDraw", "HideCW2FireModeHUD", function()
    return false
end)

-- Function to draw the custom weapon HUD
local function DrawWeaponHUD()
    local ply = LocalPlayer()
    if not IsValid(ply) or not IsValid(ply:GetActiveWeapon()) then return end

    local weapon = ply:GetActiveWeapon()
    if not weapon.CW20Weapon then return end  -- Ensure it's a CW2.0 weapon

    -- Screen resolution scaling
    local scrW, scrH = ScrW(), ScrH()
    local scaleW = scrW / 1920
    local scaleH = scrH / 1080

    -- Get ammo and magazine information
    local ammoInClip = weapon:Clip1()
    local ammoInReserve = ply:GetAmmoCount(weapon.Primary.Ammo)

    -- Get the weapon's fire mode
    local fireMode = weapon.FireModeDisplay or "Unknown"

    -- Construct the text to be displayed
    local ammoText = ammoInClip .. " / " .. ammoInReserve
    local modeText = "MODE: " .. fireMode

    -- Calculate text width
    surface.SetFont("Trebuchet32")
    local ammoTextWidth, ammoTextHeight = surface.GetTextSize(ammoText)

    surface.SetFont("Trebuchet24")
    local modeTextWidth, modeTextHeight = surface.GetTextSize(modeText)

    -- Determine the wider of the two text elements
    local maxTextWidth = math.max(ammoTextWidth, modeTextWidth)

    -- Calculate the box width dynamically, adding 10 scale units of padding
    local padding = 10 * scaleW
    local boxW = maxTextWidth + 2 * padding
    local boxH = 80 * scaleH  -- Height of the box is fixed
    local x = scrW - boxW - 20 * scaleW
    local y = scrH - boxH - 20 * scaleH

    -- Draw Background for Weapon HUD
    draw.RoundedBox(0, x, y, boxW, boxH, Color(18, 18, 18))

    -- Display ammo quantity and reserve with right alignment
    draw.SimpleText(ammoText, "Trebuchet32", x + boxW - padding, y + 5 * scaleH, Color(240, 240, 240), TEXT_ALIGN_RIGHT)

    -- Fire Mode Text with right alignment
    draw.SimpleText(modeText, "Trebuchet24", x + boxW - padding, y + 45 * scaleH, Color(240, 240, 240), TEXT_ALIGN_RIGHT)
end

hook.Add("HUDPaint", "DrawWeaponHUD", DrawWeaponHUD)