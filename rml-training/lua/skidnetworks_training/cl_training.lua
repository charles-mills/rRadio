include("skidnetworks_training/config.lua")

local function OpenTrainingMenu()
    local scrW, scrH = ScrW(), ScrH()
    local scaleW, scaleH = scrW / 1920, scrH / 1080
    local frameW, frameH = 500 * scaleW, 300 * scaleH

    -- Create the main frame for the training menu
    local frame = vgui.Create("DFrame")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    frame.Paint = function(self, w, h)
        -- Draw background and title
        draw.RoundedBox(8, 0, 0, w, h, AutoTrainingConfig.FrameColor)
        draw.SimpleText(AutoTrainingConfig.FrameTitle, "Trebuchet24", w / 2, 15 * scaleH, AutoTrainingConfig.TitleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        
        draw.SimpleText("Skid Networks", "Trebuchet48", w / 2, h / 2 - 120 * scaleH, AutoTrainingConfig.TitleColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Create the close button
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("")
    closeButton:SetSize(30 * scaleW, 30 * scaleH)
    closeButton:SetPos(frameW - 35 * scaleW, 5 * scaleH)
    closeButton.DoClick = function()
        frame:Close()
    end
    closeButton.Paint = function(self, w, h)
        local hoverColor = self:IsHovered() and AutoTrainingConfig.ButtonHoverColor or AutoTrainingConfig.ButtonColor
        draw.RoundedBox(4, 0, 0, w, h, hoverColor)
        draw.SimpleText("X", "Trebuchet18", w / 2, h / 2, AutoTrainingConfig.ButtonTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Create the label displaying the welcome message
    local label = vgui.Create("DLabel", frame)
    label:SetText(AutoTrainingConfig.WelcomeMessage)
    label:SetFont("Trebuchet18")
    label:SetColor(AutoTrainingConfig.TextColor)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:SetSize(frameW - 40 * scaleW, frameH - 100 * scaleH)
    label:SetPos(20 * scaleW, 60 * scaleH)

    -- Create the start button
    local startButton = vgui.Create("DButton", frame)
    startButton:SetText("")
    startButton:SetSize(200 * scaleW, 40 * scaleH)
    startButton:SetPos((frameW - startButton:GetWide()) / 2, frameH - 60 * scaleH)
    startButton.DoClick = function()
        RunConsoleCommand("enable_training_marker")  -- Enable the marker when the button is clicked
        frame:Close()
    end
    startButton.Paint = function(self, w, h)
        local hoverColor = self:IsHovered() and AutoTrainingConfig.ButtonHoverColor or AutoTrainingConfig.ButtonColor
        draw.RoundedBox(6, 0, 0, w, h, hoverColor)
        draw.SimpleText(AutoTrainingConfig.GuideButtonText, "Trebuchet18", w / 2, h / 2, AutoTrainingConfig.ButtonTextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Hook to display the menu when the player first spawns
hook.Add("InitPostEntity", "ShowTrainingMenu", function()
    timer.Simple(AutoTrainingConfig.InitialDelay, function()
        OpenTrainingMenu()
    end)
end)

-- Console command to open the training menu manually
concommand.Add("open_training_menu", function()
    OpenTrainingMenu()
end)
