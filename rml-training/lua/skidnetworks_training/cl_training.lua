include("skidnetworks_training/config.lua")

local function OpenTrainingMenu()
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 200)
    frame:Center()
    frame:SetTitle(AutoTrainingConfig.FrameTitle)
    frame:MakePopup()

    local label = vgui.Create("DLabel", frame)
    label:SetText(AutoTrainingConfig.WelcomeMessage)
    label:Dock(TOP)
    label:DockMargin(10, 10, 10, 10)
    label:SetWrap(true)
    label:SetAutoStretchVertical(true)

    local startButton = vgui.Create("DButton", frame)
    startButton:SetText(AutoTrainingConfig.GuideButtonText)
    startButton:Dock(BOTTOM)
    startButton:DockMargin(10, 10, 10, 10)
    startButton.DoClick = function()
        AutoTrainingConfig.ArrowVisible = true
        frame:Close()
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
