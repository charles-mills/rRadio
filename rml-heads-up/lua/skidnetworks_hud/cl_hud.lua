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

-- Function to create or update the player's avatar image on the HUD
local function UpdateAvatar(ply, avatarX, avatarY, avatarSize)
    if not IsValid(avatar) then
        avatar = vgui.Create("AvatarImage")
    end

    avatar:SetSize(avatarSize, avatarSize)
    avatar:SetPos(avatarX + 2, avatarY + 2)
    avatar:SetPlayer(ply, 64)
end

-- Function to draw player information (nickname, job, money, tokens)
local function DrawPlayerInfo(ply, infoX, infoY, scaleH)
    skidnetworks.DrawTextShadow(ply:Nick(), "Trebuchet24", infoX, infoY, Color(240, 240, 240), TEXT_ALIGN_LEFT)
    skidnetworks.DrawTextShadow(ply:getDarkRPVar("job"), "Trebuchet18", infoX, infoY + 20 * scaleH, Color(150, 150, 150), TEXT_ALIGN_LEFT)

    local money = DarkRP.formatMoney(ply:getDarkRPVar("money"))
    local formattedMoney = string.sub(money, 2) -- Remove the dollar sign
    skidnetworks.DrawTextShadow("£" .. formattedMoney, "Trebuchet18", infoX, infoY + 35 * scaleH, Color(100, 255, 100), TEXT_ALIGN_LEFT)

    skidnetworks.DrawTextShadow("Tokens: " .. playerTokens, "Trebuchet18", infoX, infoY + 50 * scaleH, Color(255, 215, 0), TEXT_ALIGN_LEFT)  -- Gold color for tokens
end

-- Function to draw the health and armor bars
local function DrawHealthArmorBars(ply, healthBarX, healthBarY, barWidth, barHeight, scaleH)
    -- Health Bar
    draw.RoundedBox(0, healthBarX, healthBarY, barWidth, barHeight, Color(40, 40, 40, 255))
    local healthRatio = math.Clamp(ply:Health() / 100, 0, 1)
    draw.RoundedBox(0, healthBarX, healthBarY, barWidth * healthRatio, barHeight, Color(200, 30, 30, 250))
    draw.SimpleText(ply:Health() .. "%", "Trebuchet18", healthBarX + barWidth - 4 * scaleH, healthBarY + barHeight / 2, Color(240, 240, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Armor Bar
    local armorBarY = healthBarY + barHeight + 8 * scaleH
    draw.RoundedBox(0, healthBarX, armorBarY, barWidth, barHeight, Color(40, 40, 40, 255))
    local armorRatio = math.Clamp(ply:Armor() / 100, 0, 1)
    draw.RoundedBox(0, healthBarX, armorBarY, barWidth * armorRatio, barHeight, Color(60, 120, 255, 250))
    draw.SimpleText(ply:Armor() .. "%", "Trebuchet18", healthBarX + barWidth - 4 * scaleH, armorBarY + barHeight / 2, Color(240, 240, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

-- Function to draw the server name box
local function DrawServerNameBox(x, y, boxW, scaleH)
    local serverBoxH = 20 * scaleH
    local serverBoxY = y - serverBoxH + 4 * scaleH
    local serverBoxX = x + 4 * scaleH
    
    -- Draw the server name box (now part of the combined shadow box)
    draw.RoundedBox(0, serverBoxX, serverBoxY, boxW, serverBoxH, Color(12, 12, 12, 236))

    -- Draw server name with a slight outline for better readability
    draw.SimpleTextOutlined("Skid Networks | PoliceRP", "Trebuchet18", x + boxW / 2, serverBoxY + serverBoxH / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 255))
end

-- Function to draw the entire HUD
local function DrawHUD()
    if debugMode then
        print("HUD has been drawn")  -- Debugging output
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Screen dimensions and scaling
    local scrW, scrH = ScrW(), ScrH()
    local scaleW, scaleH = scrW / 1920, scrH / 1080
    local boxW, boxH = 225 * scaleW, 130 * scaleH
    local serverBoxH = 20 * scaleH
    local totalBoxH = boxH + serverBoxH + 4 * scaleH  -- Combined height for the shadow
    local x, y = 10 * scaleW, scrH - boxH - 10 * scaleH
    draw.RoundedBox(0, x + 228 * scaleW, y + 6 * scaleH - serverBoxH, scaleW * 5, totalBoxH - 2 * scaleH, Color(0, 0, 0, 150)) -- Right shadow
    draw.RoundedBox(0, x + 8 * scaleW, y + 153 * scaleH - serverBoxH, boxW - scaleW * 5, scaleH * 5, Color(0, 0, 0, 150)) -- Bottom shadow

    -- Draw the main HUD box
    draw.RoundedBox(0, x + 4 * scaleW, y + 4 * scaleH, boxW, boxH, Color(18, 18, 18))

    -- Update or create the avatar
    local avatarX, avatarY = x + 16 * scaleW, y + 16 * scaleH
    UpdateAvatar(ply, avatarX, avatarY, 60 * scaleH)

    -- Draw player information
    DrawPlayerInfo(ply, avatarX + 60 * scaleH + 8 * scaleW, avatarY, scaleH)

    -- Draw health and armor bars
    DrawHealthArmorBars(ply, avatarX, y + 85 * scaleH, 200 * scaleW, 15 * scaleH, scaleH)

    -- Draw server name box above the main box, aligned with it
    DrawServerNameBox(x, y, boxW, scaleH)
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
