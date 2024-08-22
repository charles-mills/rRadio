include("shared.lua")

function ENT:Draw()
    self:DrawModel()

    local playerPos = LocalPlayer():GetPos()
    local npcPos = self:GetPos()

    -- Calculate the distance between the player and the NPC
    local distance = playerPos:Distance(npcPos)

    -- Calculate the alpha value based on distance (closer = more opaque)
    local alpha = math.Clamp(255 * (1 - distance / 500), 0, 255)  -- Fades out at 500 units away

    -- Use screen scale to ensure consistent size across resolutions
    local scrW, scrH = ScrW(), ScrH()
    local scale = math.Clamp(1 / (distance / 300), 0.05, 0.2)  -- Distance-based scaling
    local screenScale = math.min(scrW / 1920, scrH / 1080)  -- Scale based on screen resolution

    -- Position above the NPC's head
    local pos = npcPos + Vector(0, 0, 85)
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, scale)

        -- Dynamically scale the rectangle size and position
        local rectW, rectH = 125 * screenScale, 35 * screenScale  -- Scaled dimensions based on screen resolution
        local rectX, rectY = -rectW / 2, -rectH + 45 * screenScale  -- Centered above the NPC
        draw.RoundedBox(8, rectX, rectY, rectW, rectH, Color(18, 18, 18, alpha))  -- Use alpha for fading

        -- Dynamically scale the text with alpha for fading
        draw.SimpleText("Jerry", "Trebuchet24", 0, 10 * screenScale, Color(240, 240, 240, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Token Dealer", "Trebuchet18", 0, 30 * screenScale, Color(150, 150, 150, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    cam.End3D2D()
end


-- Function to convert numbers into their shortened values
local function shortenNumber(number)
    local suffixes = {"", "K", "M", "B", "T"} -- Add more suffixes as needed
    local suffixIndex = 1

    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end

    -- Check if the number is an integer after division
    if number % 1 == 0 then
        return string.format("%d%s", number, suffixes[suffixIndex])
    else
        return string.format("%.1f%s", number, suffixes[suffixIndex])
    end
end

-- Receive the menu opening command from the server
net.Receive("OpenTokenBuyerMenu", function()
    surface.PlaySound("buttons/button9.wav")

    local scrW, scrH = ScrW(), ScrH()
    local scaleW, scaleH = scrW / 1920, scrH / 1080

    local frameW, frameH = 500 * scaleW, 400 * scaleH  -- Increased height to accommodate the new button
    local padding = 15 * scaleW
    local buttonHeight = 50 * scaleH
    local buttonSpacing = 12 * scaleH

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        local boxColor = Color(18, 18, 18)
        draw.RoundedBoxEx(8, 0, 0, w, h, boxColor, true, true, false, false)

        -- Header Text
        draw.SimpleText("Jerry's Token Exchange", "Trebuchet24", w / 2, padding, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("Skid Networks", "Trebuchet18", w / 2, padding + 18 * scaleH, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetSize(30 * scaleW, 30 * scaleH)
    closeButton:SetPos(frameW - 45 * scaleW, padding)
    closeButton.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        frame:Close()
    end
    closeButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(200, 30, 30))
        draw.SimpleText("X", "Trebuchet18", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local weaponList = {
        {name = "Permanent MR96", class = "cw_mr96", cost = 10000},
        {name = "Permanent Makarov", class = "cw_makarov", cost = 12500},
    }

    local y = 70 * scaleH
    for _, weapon in ipairs(weaponList) do
        local button = vgui.Create("DButton", frame)
        button:SetText("")
        button:SetSize(frameW - 2 * padding, buttonHeight)
        button:SetPos(padding, y)

        button.Paint = function(self, w, h)
            local buttonColor = self:IsHovered() and Color(70, 70, 70) or Color(50, 50, 50)
            draw.RoundedBox(6, 0, 0, w, h, buttonColor)
            draw.SimpleText(weapon.name .. " - " .. shortenNumber(weapon.cost) .. " Tokens", "Trebuchet18", w / 2, h / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        button.DoClick = function()
            surface.PlaySound("buttons/combine_button_locked.wav")
            net.Start("BuyWeaponWithTokens")
            net.WriteString(weapon.class)
            net.WriteInt(weapon.cost, 32)
            net.SendToServer()
        end

        y = y + buttonHeight + buttonSpacing
    end

    -- Add the "Sell All Weapons" button at the bottom
    local sellButton = vgui.Create("DButton", frame)
    sellButton:SetText("")
    sellButton:SetSize(frameW - 2 * padding, buttonHeight)
    sellButton:SetPos(padding, frameH - buttonHeight - padding)

    sellButton.Paint = function(self, w, h)
        local buttonColor = self:IsHovered() and Color(70, 70, 70) or Color(50, 50, 50)
        draw.RoundedBox(6, 0, 0, w, h, buttonColor)
        draw.SimpleText("Want to start over? Click here to sell all weapons", "Trebuchet18", w / 2, h / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    sellButton.DoClick = function()
        surface.PlaySound("hl1/fvox/bell.wav")
        RunConsoleCommand("sell_all_weapons")
        frame:Close()
    end
end)
