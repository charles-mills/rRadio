include("cl_weapon_hud.lua")

local avatar
local playerTokens = 0  -- Initialize token count
local debugMode = false  -- Toggle this to true for debugging

-- Receive and update the token count
net.Receive("UpdateTokens", function()
    playerTokens = net.ReadInt(32)
    if debugMode then
        print("Token value received by client:", playerTokens)
    end
end)

-- Function to create the player's avatar image on the HUD
local function CreateAvatar(ply, avatarX, avatarY, avatarSize)
    avatar = vgui.Create("AvatarImage")
    avatar:SetSize(avatarSize, avatarSize)
    avatar:SetPos(avatarX + 2, avatarY + 2)
    avatar:SetPlayer(ply, 64)
end

-- Function to draw the HUD
local function DrawHUD()
    if debugMode then
        print("HUD has been drawn")  -- Debug
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Dynamic scaling and positioning
    local scrW, scrH = ScrW(), ScrH()
    local scaleW = scrW / 1920
    local scaleH = scrH / 1080
    local boxW, boxH = 225 * scaleW, 130 * scaleH  -- Adjusted height to accommodate tokens
    local borderThickness = 4 * scaleW
    local x, y = 10 * scaleW, scrH - boxH - 10 * scaleH
    local padding = 8 * scaleW
    local avatarSize = 60 * scaleH
    local avatarX = x + padding + borderThickness
    local avatarY = y + padding + borderThickness

    -- Draw Background
    draw.RoundedBox(0, x + borderThickness, y + borderThickness, boxW, boxH, Color(18, 18, 18))

    -- Create and position the avatar if it hasn't been created yet
    if not IsValid(avatar) then
        CreateAvatar(ply, avatarX, avatarY, avatarSize)
    else
        avatar:SetPos(avatarX + 2, avatarY + 2)
        avatar:SetSize(avatarSize, avatarSize)
    end

    -- Player Info
    local infoX = avatarX + avatarSize + padding
    local infoY = avatarY
    skidnetworks.DrawTextShadow(ply:Nick(), "Trebuchet24", infoX, infoY, Color(240, 240, 240), TEXT_ALIGN_LEFT)
    skidnetworks.DrawTextShadow(ply:getDarkRPVar("job"), "Trebuchet18", infoX, infoY + 20 * scaleH, Color(150, 150, 150), TEXT_ALIGN_LEFT)

    -- Money Display
    local money = DarkRP.formatMoney(ply:getDarkRPVar("money"))
    local formattedMoney = string.sub(money, 2) -- Remove the dollar sign
    local moneyX = infoX
    local moneyY = infoY + 35 * scaleH
    skidnetworks.DrawTextShadow("£" .. formattedMoney, "Trebuchet18", moneyX, moneyY, Color(100, 255, 100), TEXT_ALIGN_LEFT)

    -- Token Display
    local tokenX = infoX
    local tokenY = moneyY + 15 * scaleH
    skidnetworks.DrawTextShadow("Tokens: " .. playerTokens, "Trebuchet18", tokenX, tokenY, Color(255, 215, 0), TEXT_ALIGN_LEFT)  -- Gold color for tokens

    -- Health and Armor Bars
    local barWidth = 200 * scaleW
    local barHeight = 15 * scaleH
    local healthBarX = avatarX
    local healthBarY = tokenY + 20 * scaleH
    local armorBarX = healthBarX
    local armorBarY = healthBarY + barHeight + padding

    -- Health Bar
    draw.RoundedBox(0, healthBarX, healthBarY, barWidth, barHeight, Color(40, 40, 40, 255))
    local healthRatio = math.Clamp(ply:Health() / 100, 0, 1)
    draw.RoundedBox(0, healthBarX, healthBarY, barWidth * healthRatio, barHeight, Color(200, 30, 30, 250))
    draw.SimpleText(ply:Health() .. "%", "Trebuchet18", healthBarX + barWidth - padding, healthBarY + barHeight / 2, Color(240, 240, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Armor Bar
    draw.RoundedBox(0, armorBarX, armorBarY, barWidth, barHeight, Color(40, 40, 40, 255))
    local armorRatio = math.Clamp(ply:Armor() / 100, 0, 1)
    draw.RoundedBox(0, armorBarX, armorBarY, barWidth * armorRatio, barHeight, Color(60, 120, 255, 250))
    draw.SimpleText(ply:Armor() .. "%", "Trebuchet18", armorBarX + barWidth - padding, armorBarY + barHeight / 2, Color(240, 240, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Server Name Display Box
    local serverBoxW = boxW
    local serverBoxH = 20 * scaleH
    local serverBoxX = x + borderThickness
    local serverBoxY = y - serverBoxH + 5 * scaleH
    draw.RoundedBox(0, serverBoxX, serverBoxY, serverBoxW, serverBoxH, Color(18, 18, 18))
    draw.SimpleText("Skid Networks | PoliceRP", "Trebuchet18", serverBoxX + serverBoxW / 2, serverBoxY + serverBoxH / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "SkidNetworks_HUD", DrawHUD)

-- Hide Default DarkRP HUD
local hideElements = {
    ["DarkRP_HUD"] = true,
    ["DarkRP_EntityDisplay"] = true,
    ["DarkRP_ZombieInfo"] = true,
    ["DarkRP_LocalPlayerHUD"] = true,
    ["DarkRP_Hungermod"] = true,
}

hook.Add("HUDShouldDraw", "HideDefaultDarkRPHUD", function(name)
    if hideElements[name] then return false end
end)
