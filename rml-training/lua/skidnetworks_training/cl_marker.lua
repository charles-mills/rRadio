-- Load the training messages from the separate file
include("config.lua")

local pdLocation = Vector(-9059, 10436, 64)  -- PD Entrance coords, update if needed
local arrowMaterial = Material(AutoTrainingConfig.ArrowMaterial) -- Using a default icon for now
local arrowSize = 64
local arrowVisible = false

-- Function to calculate the screen position of the PD location
local function CalculateMarkerPosition()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil, nil end

    -- Ensure pdLocation is correct
    if not pdLocation then return nil, nil end

    local screenPos = pdLocation:ToScreen()

    -- Check if the screen position is off-screen
    local x, y = screenPos.x, screenPos.y
    if x < 0 or x > ScrW() or y < 0 or y > ScrH() then
        return nil, nil
    end

    return x, y
end

-- Function to draw the marker on the player's screen
local function DrawMarker()
    if not arrowVisible then return end

    local x, y = CalculateMarkerPosition()
    if not x or not y then return end

    -- Draw the marker
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(arrowMaterial)
    surface.DrawTexturedRectRotated(x, y, arrowSize, arrowSize, 0)
end

hook.Add("HUDPaint", "DrawTrainingMarker", DrawMarker)

-- Menu for the training system
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
        arrowVisible = true
        frame:Close()
    end
end

-- Hook to display the menu when the player first spawns
hook.Add("InitPostEntity", "ShowTrainingMenu", function()
    timer.Simple(2, function()
        OpenTrainingMenu()
    end)
end)

-- Console command to open the training menu manually
concommand.Add("open_training_menu", function()
    OpenTrainingMenu()
end)
