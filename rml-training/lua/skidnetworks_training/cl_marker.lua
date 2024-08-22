-- Load the training messages from the separate file
include("skidnetworks_training/config.lua")

local pdLocation = AutoTrainingConfig.PDLocation  -- Use the PD location from the config
local arrowMaterial = Material(AutoTrainingConfig.ArrowMaterial)
local arrowSize = AutoTrainingConfig.ArrowSize
local removeDistance = AutoTrainingConfig.RemoveDistance or 200  -- Distance within which the icon will disappear
local markerEnabled = false  -- Initially, the marker is disabled
local hasPlayedSound = false  -- Flag to ensure the sound is played only once

-- Function to calculate the screen position of the PD location
local function CalculateMarkerPosition()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil, nil end

    local plyPos = ply:GetPos()
    local distance = plyPos:Distance(pdLocation)

    print("Distance to PD:", distance)

    -- Check if the player is within the removeDistance
    if distance <= removeDistance then
        print("You have arrived at the PD!")  -- Print a message in the chat
        if not hasPlayedSound then
            surface.PlaySound(AutoTrainingConfig.ArrivalSound)
            hasPlayedSound = true  -- Ensure the sound only plays once
        end
        markerEnabled = false
        return nil, nil
    end

    local screenPos = pdLocation:ToScreen()
    return screenPos.x, screenPos.y
end

-- Function to draw the marker on the player's screen
local function DrawMarker()
    if not markerEnabled then return end  -- Only draw if the marker is enabled

    local x, y = CalculateMarkerPosition()

    -- If x or y is nil, don't draw the marker
    if not x or not y then return end

    -- Draw the marker
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(arrowMaterial)
    surface.DrawTexturedRectRotated(x, y, arrowSize, arrowSize, 0)
end

hook.Add("HUDPaint", "DrawTrainingMarker", DrawMarker)

-- Function to enable the marker
local function EnableMarker()
    markerEnabled = true
    hasPlayedSound = false  -- Reset the sound flag when the marker is enabled
end

-- Console command to enable the marker
concommand.Add("enable_training_marker", function()
    EnableMarker()
end)
