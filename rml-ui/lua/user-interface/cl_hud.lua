-- Function to draw the custom HUD
include("user-interface/config.lua")

local function drawCustomHUD()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    local elements = HUDConfig.elements

    -- Background
    surface.SetDrawColor(HUDConfig.backgroundColor)
    surface.DrawRect(elements.background.x, elements.background.y, elements.background.width, elements.background.height)

    -- RP Name
    draw.SimpleText("" .. ply:getDarkRPVar("rpname"), "DermaDefaultBold", elements.rpName.x, elements.rpName.y, HUDConfig.textColor, TEXT_ALIGN_LEFT, 0)

    -- Money
    draw.SimpleText("Money: " .. HUDServerConfig.currency .. (ply:getDarkRPVar("money")), "DermaDefaultBold", elements.money.x, elements.money.y, HUDConfig.textColor, TEXT_ALIGN_LEFT, 0)

    -- Job
    draw.SimpleText("Job: " .. ply:getDarkRPVar("job"), "DermaDefaultBold", elements.rpName.x, elements.rpName.y + 30, HUDConfig.textColor, TEXT_ALIGN_LEFT, 0)

    -- Health Bar
    local healthWidth = math.Clamp(ply:Health() / ply:GetMaxHealth(), 0, 1) * elements.health.width
    surface.SetDrawColor(HUDConfig.healthColor)
    surface.DrawRect(elements.health.x, elements.health.y, healthWidth, elements.health.height)
    draw.SimpleText(ply:Health() .. "%", "DermaDefaultBold", elements.health.x + healthWidth + 5, elements.health.y, HUDConfig.textColor, TEXT_ALIGN_LEFT, 0)

    -- Armor Bar
    local armorWidth = math.Clamp(ply:Armor() / 100, 0, 1) * elements.armor.width
    surface.SetDrawColor(HUDConfig.armorColor)
    surface.DrawRect(elements.armor.x, elements.armor.y, armorWidth, elements.armor.height)
    draw.SimpleText(ply:Armor() .. "%", "DermaDefaultBold", elements.armor.x + armorWidth + 5, elements.armor.y, HUDConfig.textColor, TEXT_ALIGN_LEFT, 0)
end

-- Hook the function to HUDPaint
hook.Add("HUDPaint", "CustomHUD", drawCustomHUD)

-- Function to hide default HUD elements
local function hideDefaultHUD(name)
    local elements = {
        ["CHudHealth"] = true,
        ["CHudBattery"] = true,
        ["CHudAmmo"] = true,
        ["CHudSecondaryAmmo"] = true,
        ["DarkRP_HUD"] = true
    }

    if elements[name] then return false end
end

-- Hook the function to HUDShouldDraw
hook.Add("HUDShouldDraw", "HideDefaultHUD", hideDefaultHUD)
