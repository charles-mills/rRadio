-- Define the font for the UI
surface.CreateFont("rRadioFont", {
    font = "Arial",
    size = 24,
    weight = 700,
    antialias = true,
})

-- Function to open the radio UI
local function OpenRadioUI()
    -- Create the main frame
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(400, 700)
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)

    -- Background color and style
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 255))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("icons/radio_icon.png")) -- Custom icon for the radio
        surface.DrawTexturedRect(10, 5, 24, 24)
        draw.SimpleText("rRadio", "rRadioFont", 40, 5, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
    end

    -- Create a label for the "Select a Country" text
    local countryLabel = vgui.Create("DLabel", frame)
    countryLabel:SetText("Select a Country")
    countryLabel:SetFont("rRadioFont")
    countryLabel:SetTextColor(Color(255, 255, 255))
    countryLabel:SetPos(15, 50)
    countryLabel:SizeToContents()

    -- Create a list of countries (dummy list)
    local countryList = vgui.Create("DPanelList", frame)
    countryList:SetPos(15, 90)
    countryList:SetSize(370, 450)
    countryList:SetSpacing(5)
    countryList:EnableVerticalScrollbar(true)
    countryList.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(60, 60, 60, 255))
    end

    -- Example country entry
    for i = 1, 6 do
        local country = vgui.Create("DButton")
        country:SetText("Country " .. i)
        country:SetFont("rRadioFont")
        country:SetTextColor(Color(255, 255, 255))
        country.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 80, 80, 255))
        end
        countryList:AddItem(country)
    end

    -- Create the Radio station display
    local radioStation = vgui.Create("DLabel", frame)
    radioStation:SetText("BBC Radio 1")
    radioStation:SetFont("rRadioFont")
    radioStation:SetTextColor(Color(255, 255, 255))
    radioStation:SetPos(15, 550)
    radioStation:SizeToContents()

    local radioCountry = vgui.Create("DLabel", frame)
    radioCountry:SetText("United Kingdom")
    radioCountry:SetFont("rRadioFont")
    radioCountry:SetTextColor(Color(200, 200, 200))
    radioCountry:SetPos(15, 580)
    radioCountry:SizeToContents()

    -- Create the Stop button
    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetText("")
    stopButton:SetSize(100, 50)
    stopButton:SetPos(15, 620)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(255, 0, 0, 255))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material("icons/stop_icon.png")) -- Custom icon for the stop button
        surface.DrawTexturedRect(10, 10, 30, 30)
        draw.SimpleText("STOP", "rRadioFont", 45, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT)
    end
    stopButton.DoClick = function()
        -- Add functionality to stop the radio
        print("Radio Stopped")
    end

    -- Create a volume slider
    local volumeSlider = vgui.Create("DNumSlider", frame)
    volumeSlider:SetPos(150, 625)
    volumeSlider:SetSize(200, 50)
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(100)
    volumeSlider:SetValue(50)
    volumeSlider:SetDecimals(0)
    volumeSlider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60, 255))
    end
end

-- Bind the UI opening function to the "L" key
hook.Add("PlayerButtonDown", "OpenRadioUIKey", function(ply, button)
    print("Button Pressed: " .. button)
    if button == KEY_L then
        OpenRadioUI()
    end
end)
