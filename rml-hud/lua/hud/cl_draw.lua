include("config/config.lua")
include("hud/cl_util.lua")
-- Cache screen dimensions
local screenW, screenH = ScrW(), ScrH()

-- Recalculate screen dimensions if resolution changes
hook.Add("OnScreenSizeChanged", "HUD_RecalculateScreenSize", function()
    screenW, screenH = ScrW(), ScrH()
end)


-- Create fonts for the HUD
surface.CreateFont("HUD_ServerName", {
    font = HUDConfig.Font,
    size = scaledFontSize(HUDConfig.ServerNameFontSize),
    weight = 1000,
    antialias = true
})

surface.CreateFont("HUD_Info", {
    font = HUDConfig.Font,
    size = scaledFontSize(HUDConfig.InfoFontSize),
    weight = 700,
    antialias = true
})

-- Function to draw player information
local function DrawPlayerInfo(ply, x, y)
    local name = ply:Nick()
    draw.SimpleText(name, "HUD_Info", x, y, HUDConfig.TextColor)
    y = y + HUDConfig.InfoFontSize

    if isDarkRP then
        local job = ply:getDarkRPVar("job") or "Unemployed"
        local money = ply:getDarkRPVar("money") or 0
        local tokens = 0 -- Placeholder for tokens

        draw.SimpleText(job, "HUD_Info", x, y, HUDConfig.TextColor)
        y = y + HUDConfig.InfoFontSize
        draw.SimpleText(HUDConfig.currency .. money, "HUD_Info", x, y, HUDConfig.TextColor)
        y = y + HUDConfig.InfoFontSize
        draw.SimpleText("Tokens: " .. tokens, "HUD_Info", x, y, HUDConfig.TextColor)
        y = y + HUDConfig.InfoFontSize
    end

    return y + 15
end

-- Generic function to draw bars (health, armor, etc.)
local function DrawBar(ply, x, y, value, maxValue, barWidth, barHeight, barColor)
    local width = math.Clamp(value / maxValue, 0, 1) * barWidth

    -- Draw the bar background
    draw.RoundedBox(0, x, y, barWidth, barHeight, HUDConfig.BackgroundColor)

    -- Draw the bar fill
    draw.RoundedBox(0, x, y, width, barHeight, barColor)

    -- Draw the value within the bar
    draw.SimpleText(value, "HUD_Info", x + barWidth / 2, y + barHeight / 2, HUDConfig.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    return y + barHeight + HUDConfig.BarPadding
end

-- Main function to draw the entire HUD
function DrawCustomHUD()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    -- Adjust the x position with right padding
    local x = HUDConfig.MarginX + HUDConfig.PaddingRight
    local y = HUDConfig.MarginY
    local screenHeight = ScrH()

    -- Draw player info
    y = DrawPlayerInfo(ply, x, y)

    -- Draw health bar
    y = DrawBar(ply, x, y, ply:Health(), 100, HUDConfig.HealthBarWidth, HUDConfig.HealthBarHeight, HUDConfig.HealthBarColor)

    -- Draw armor bar
    y = DrawBar(ply, x, y, ply:Armor(), 100, HUDConfig.ArmorBarWidth, HUDConfig.ArmorBarHeight, HUDConfig.ArmorBarColor)
end

-- Function to draw the health bar
local function DrawHealthBar(ply, x, y)
    local health = ply:Health()
    
    -- Draw the health bar background
    draw.RoundedBox(0, x, y, HUDConfig.HealthBarWidth, HUDConfig.HealthBarHeight, HUDConfig.BackgroundColor)
    
    -- Draw the health bar fill
    draw.RoundedBox(0, x, y, math.Clamp(health / 100, 0, 1) * HUDConfig.HealthBarWidth, HUDConfig.HealthBarHeight, HUDConfig.HealthBarColor)
    
    -- Draw the health value within the bar
    draw.SimpleText(health, "HUD_Info", x + HUDConfig.HealthBarWidth / 2, y + HUDConfig.HealthBarHeight / 2, HUDConfig.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    return y + HUDConfig.HealthBarHeight + HUDConfig.BarPadding
end

-- Function to draw the armor bar
local function DrawArmorBar(ply, x, y)
    local armor = ply:Armor()

    -- Draw the armor bar background
    draw.RoundedBox(0, x, y, HUDConfig.ArmorBarWidth, HUDConfig.ArmorBarHeight, HUDConfig.BackgroundColor)
    
    -- Draw the armor bar fill
    draw.RoundedBox(0, x, y, math.Clamp(armor / 100, 0, 1) * HUDConfig.ArmorBarWidth, HUDConfig.ArmorBarHeight, HUDConfig.ArmorBarColor)
    
    -- Draw the armor value within the bar
    draw.SimpleText(armor, "HUD_Info", x + HUDConfig.ArmorBarWidth / 2, y + HUDConfig.ArmorBarHeight / 2, HUDConfig.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    return y + HUDConfig.ArmorBarHeight
end

-- Main function to draw the entire HUD
function DrawCustomHUD()
    local ply = LocalPlayer()
    if not ply:Alive() then return end

    -- Adjust the x position with right padding
    local x = HUDConfig.MarginX + HUDConfig.PaddingRight
    local screenHeight = ScrH()

    -- Calculate the height of the entire HUD
    local totalHeight = HUDConfig.ServerNameFontSize + 15 + (HUDConfig.InfoFontSize * (isDarkRP and 4 or 1)) + (HUDConfig.HealthBarHeight + HUDConfig.ArmorBarHeight) + HUDConfig.BarPadding * 2 + 35
    local y = screenHeight - HUDConfig.MarginY - totalHeight

    -- Draw the background box with a rainbow border
    local boxWidth = HUDConfig.HealthBarWidth + 2 * HUDConfig.MarginX
    DrawRainbowBorder(x - HUDConfig.MarginX, y - 10, boxWidth, totalHeight, 5)  -- 5 is the border thickness
    draw.RoundedBox(0, x - HUDConfig.MarginX, y - 10, boxWidth, totalHeight, HUDConfig.BackgroundBoxColor)

    -- Draw server name
    draw.SimpleText(HUDConfig.ServerName, "HUD_ServerName", x, y, HUDConfig.TextColor)
    y = y + HUDConfig.ServerNameFontSize + 15

    -- Draw player information
    y = DrawPlayerInfo(ply, x, y)

    -- Draw health bar
    y = DrawHealthBar(ply, x, y)

    -- Draw armor bar
    DrawArmorBar(ply, x, y)
end
