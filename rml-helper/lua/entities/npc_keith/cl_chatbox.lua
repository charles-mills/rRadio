local currentDialogueBox  -- Variable to store the current dialogue box
local closeTimer  -- Variable to store the close timer

net.Receive("OpenChatBox", function()
    local scrW, scrH = ScrW(), ScrH()
    local scaleW = scrW / 1920
    local scaleH = scrH / 1080

    local frameW, frameH = 500 * scaleW, 250 * scaleH  -- Main chat box
    local padding = 15 * scaleW
    local buttonHeight = 50 * scaleH
    local buttonSpacing = 12 * scaleH

    -- Main Frame
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(frameW, frameH)
    frame:Center()
    frame:SetDraggable(false)
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(self, w, h)
        -- Background Box
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18))

        -- Header Text
        draw.SimpleText("Keith the Tour Guide", "Trebuchet24", w / 2, padding, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    -- Close Button
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetSize(30 * scaleW, 30 * scaleH)
    closeButton:SetPos(frameW - 45 * scaleW, padding)
    closeButton.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        frame:Close()
        if IsValid(currentDialogueBox) then
            currentDialogueBox:Close()  -- Close the dialogue box when the main frame is closed
            timer.Remove("DialogueCloseTimer")  -- Remove the timer when the main frame is closed
        end
    end
    closeButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(200, 30, 30))
        draw.SimpleText("X", "Trebuchet18", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Option Buttons
    local options = {
        {text = "What is this server?", response = "It's a platform to experiment with custom addons. The server will never be monetised nor will it leave a development stage, don't ban me from Riverside!"},
        {text = "How can I join the PD?", response = "There is an automated training system at the PD, located directly opposite the Mall and next to the court house, to your left."},
    }

    local y = 70 * scaleH
    for _, option in ipairs(options) do
        local button = vgui.Create("DButton", frame)
        button:SetText("")
        button:SetSize(frameW - 2 * padding, buttonHeight)
        button:SetPos(padding, y)

        button.Paint = function(self, w, h)
            local buttonColor = self:IsHovered() and Color(70, 70, 70) or Color(50, 50, 50)
            draw.RoundedBox(6, 0, 0, w, h, buttonColor)
            draw.SimpleText(option.text, "Trebuchet18", w / 2, h / 2, Color(240, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        button.DoClick = function()
            surface.PlaySound("buttons/button14.wav")
            CreateDialogueBox(frameW, option.response)  -- Create dialogue box below with response
        end

        y = y + buttonHeight + buttonSpacing
    end
end)

-- Function to create the dialogue box below the main chat box
function CreateDialogueBox(frameWidth, responseText)
    -- Close the existing dialogue box if it exists
    if IsValid(currentDialogueBox) then
        currentDialogueBox:Close()
    end

    -- Calculate required height based on the response text
    surface.SetFont("Trebuchet18")
    local textWidth, textHeight = surface.GetTextSize(responseText)
    local linesRequired = math.ceil(textWidth / (frameWidth - 30))
    local boxHeight = (textHeight * linesRequired) + 20

    -- Dialogue Frame
    currentDialogueBox = vgui.Create("DFrame")
    currentDialogueBox:SetTitle("")
    currentDialogueBox:SetSize(frameWidth, boxHeight)
    currentDialogueBox:CenterHorizontal()
    currentDialogueBox:SetPos(currentDialogueBox:GetPos(), ScrH() / 2 + 130 * (ScrH() / 1080))
    currentDialogueBox:SetDraggable(false)
    currentDialogueBox:ShowCloseButton(false)

    currentDialogueBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(50, 50, 50, 240))
    end

    -- Add a label to display the response text
    local responseLabel = vgui.Create("DLabel", currentDialogueBox)
    responseLabel:SetPos(15, 10)
    responseLabel:SetSize(frameWidth - 30, boxHeight - 20)
    responseLabel:SetFont("Trebuchet18")
    responseLabel:SetTextColor(Color(240, 240, 240))
    responseLabel:SetWrap(true)
    responseLabel:SetText(responseText)

    -- Reset and start the close timer
    if closeTimer then
        timer.Remove(closeTimer)
    end

    closeTimer = "DialogueCloseTimer"

    timer.Create(closeTimer, 10, 1, function()
        if IsValid(currentDialogueBox) then
            currentDialogueBox:Close()
        end
    end)
end
