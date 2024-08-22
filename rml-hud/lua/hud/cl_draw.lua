include("config/config.lua")
include("hud/cl_util.lua")

surface.CreateFont("HUD_ServerName", {
    font = HUDConfig.Font,
    size = HUDConfig.ServerNameFontSize,
    weight = 1000,
    antialias = true
})

surface.CreateFont("HUD_Info", {
    font = HUDConfig.Font,
    size = HUDConfig.InfoFontSize,
    weight = 700,
    antialias = true
})

-- Check if DarkRP is available
local isDarkRP = DarkRP and DarkRP.getVar and true or false

local function DrawPlayerInfo(ply, x, y)
    local name = isDarkRP and ply:Nick() or ply:SteamName()
    
    draw.SimpleText("Name: " .. name, "HUD_Info", x, y, HUDConfig.TextColor)
    y = y + HUDConfig.InfoFontSize
    
    if isDarkRP then
        local job = ply:getDarkRPVar("job") or "Unemployed"
        local money = ply:getDarkRPVar("money") or 0
        draw.SimpleText("Job: " .. job, "HUD_Info", x, y, HUDConfig.TextColor)
        y = y + HUDConfig.InfoFontSize
        draw.SimpleText("Money: $" .. money, "HUD_Info", x, y, HUDConfig.TextColor)
        y = y + HUDConfig.InfoFontSize
    end

    return y + HUDConfig.InfoFontSize + 15
end

local function DrawHealthBar(ply, x, y)
    local health = ply:Health()
    DrawRoundedBoxWithText(HUDConfig.BarCornerRadius, x, y, HUDConfig.HealthBarWidth, HUDConfig.HealthBarHeight, HUDConfig.BackgroundColor, HUDConfig.TextColor, health, "HUD_Info")
    draw.RoundedBox(HUDConfig.BarCornerRadius, x, y, math.Clamp(health / 100, 0, 1) * HUDConfig.HealthBarWidth, HUDConfig.HealthBarHeight, HUDConfig.HealthBarColor)
    return y + HUDConfig.HealthBarHeight + HUDConfig.BarPadding
end

local function DrawArmorBar(ply, x, y)
    local armor = ply:Armor()
    DrawRoundedBoxWithText(HUDConfig.BarCornerRadius, x, y, HUDConfig.ArmorBarWidth, HUDConfig.ArmorBarHeight, HUDConfig.BackgroundColor, HUDConfig.TextColor, armor, "HUD_Info")
    draw.RoundedBox(HUDConfig.BarCornerRadius, x, y, math.Clamp(armor / 100, 0, 1) * HUDConfig.ArmorBarWidth, HUDConfig.ArmorBarHeight, HUDConfig.ArmorBarColor)
    return y + HUDConfig.ArmorBarHeight
end

function DrawCustomHUD()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    local x = HUDConfig.MarginX
    local screenHeight = ScrH()

    -- Calculate the height of the entire HUD
    local totalHeight = HUDConfig.ServerNameFontSize + 15 + (HUDConfig.InfoFontSize * (isDarkRP and 4 or 1)) + (HUDConfig.HealthBarHeight + HUDConfig.ArmorBarHeight) + HUDConfig.BarPadding * 2 + 35
    local y = screenHeight - HUDConfig.MarginY - totalHeight

    -- Draw the background box
    local boxWidth = HUDConfig.HealthBarWidth + 2 * HUDConfig.MarginX
    draw.RoundedBox(HUDConfig.BarCornerRadius, x - HUDConfig.MarginX, y - 10, boxWidth, totalHeight, HUDConfig.BackgroundBoxColor)

    -- Draw server name
    draw.SimpleText(HUDConfig.ServerName, "HUD_ServerName", x, y, HUDConfig.TextColor)
    y = y + HUDConfig.ServerNameFontSize + 15

    -- Draw player information
    y = DrawPlayerInfo(ply, x, y)

    -- Draw health bar
    y = DrawHealthBar(ply, x, y)

    -- Draw armor bar
    y = DrawArmorBar(ply, x, y)
end
