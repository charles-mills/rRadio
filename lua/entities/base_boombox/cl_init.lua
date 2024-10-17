include("shared.lua")
include("radio/shared/sh_config.lua")

-- Global table to store boombox statuses
BoomboxStatuses = BoomboxStatuses or {}

-- Constants for HUD display
local FADE_START_DISTANCE = 300
local FADE_END_DISTANCE = 500
local ICON_SIZE = 40
local PADDING = 10
local ROTATION_SPEED = 1
local VIEW_ANGLE_THRESHOLD = math.cos(math.rad(80)) -- Visible within 160-degree cone

-- Cached values and materials
local iconMaterial = Material("materials/hud/volume.png", "smooth")
local mathSin, mathClamp = math.sin, math.Clamp

-- Pre-created color objects for efficiency
local textColor = Color(255, 255, 255)
local rainbowColor = Color(255, 255, 255)

-- Function to generate a rainbow color effect
local function GetRainbowColor(frequency)
    local time = CurTime() * frequency
    rainbowColor.r = mathSin(time) * 127 + 128
    rainbowColor.g = mathSin(time + 2) * 127 + 128
    rainbowColor.b = mathSin(time + 4) * 127 + 128
    return rainbowColor
end

local function ShouldRotateIcon(status)
    return status == "playing" or status == "tuning"
end

local rotationAngle = 0

-- Initialize entity variables
function ENT:Initialize()
    self:SetRenderBounds(self:OBBMins(), self:OBBMaxs())
    -- No need to initialize self.stationStatus or self.stationName since we're using BoomboxStatuses
end

-- Drawing the boombox HUD
function ENT:Draw()
    self:DrawModel()

    -- Check if HUD display is enabled
    if not GetConVar("boombox_show_text"):GetBool() then return end

    local playerPos = LocalPlayer():EyePos()
    local entPos = self:GetPos()
    local distance = playerPos:Distance(entPos)

    -- Early exit if player is too far
    if distance > FADE_END_DISTANCE then return end

    -- Calculate alpha for fading effect
    local alpha = 255
    if distance > FADE_START_DISTANCE then
        alpha = mathClamp(255 * (1 - (distance - FADE_START_DISTANCE) / (FADE_END_DISTANCE - FADE_START_DISTANCE)), 0, 255)
    end

    -- Calculate viewing angle to determine if HUD should be visible
    local boomboxForward = self:GetForward()
    local toPlayer = (playerPos - entPos):GetNormalized()
    local dotProduct = boomboxForward:Dot(toPlayer)

    if dotProduct < VIEW_ANGLE_THRESHOLD then
        return
    end

    -- Apply gradual fade based on viewing angle
    local angleFade = mathClamp((dotProduct - VIEW_ANGLE_THRESHOLD) / (1 - VIEW_ANGLE_THRESHOLD), 0.5, 1)
    alpha = alpha * angleFade

    if alpha <= 0 then return end

    -- Setup position and angle for 3D2D drawing
    local pos = entPos + self:GetUp() * 27
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), 90)

    -- Get the boombox status from the global table
    local statusData = BoomboxStatuses[self:EntIndex()]
    local stationStatus = "stopped"
    local stationName = ""

    if statusData then
        stationStatus = statusData.stationStatus or "stopped"
        stationName = statusData.stationName or ""
    end

    -- Determine the text to display based on the boombox's status
    local text = "PAUSED"
    textColor.r, textColor.g, textColor.b, textColor.a = 255, 255, 255, alpha

    if stationStatus == "tuning" then
        text = "Tuning in..."
        textColor.r, textColor.g, textColor.b = 255, 255, 255
    elseif stationStatus == "playing" and stationName ~= "" then
        text = stationName
        local tempColor = GetRainbowColor(1)
        textColor.r, textColor.g, textColor.b = tempColor.r, tempColor.g, tempColor.b
    else
        local interactText = Config.Lang and Config.Lang["Interact"] or "Press E to Interact"
        local owner = self:GetNWEntity("Owner")
        
        if LocalPlayer() == owner or LocalPlayer():IsSuperAdmin() then
            text = interactText
        end
    end

    -- Update rotation angle only if the boombox is playing or tuning
    if ShouldRotateIcon(stationStatus) then
        rotationAngle = (rotationAngle + ROTATION_SPEED) % 360
    end

    -- Calculate text size for positioning
    surface.SetFont("BoomboxFont")
    local textWidth, textHeight = surface.GetTextSize(text)
    local totalWidth = ICON_SIZE + PADDING + textWidth
    local totalHeight = math.max(ICON_SIZE, textHeight)

    -- Begin 3D2D drawing
    cam.Start3D2D(pos, ang, 0.1)
        -- Background box
        local bgWidth = totalWidth + PADDING * 2
        local bgHeight = totalHeight + PADDING * 2
        draw.RoundedBox(8, -bgWidth / 2, -bgHeight / 2, bgWidth, bgHeight, Color(0, 0, 0, alpha * 0.78))
        
        -- Rotating icon
        surface.SetMaterial(iconMaterial)
        surface.SetDrawColor(textColor.r, textColor.g, textColor.b, alpha)
        surface.DrawTexturedRectRotated(-totalWidth / 2 + ICON_SIZE / 2, 0, ICON_SIZE, ICON_SIZE, rotationAngle)
        
        -- Display text
        textColor.a = alpha -- Update text alpha
        draw.SimpleText(text, "BoomboxFont", -totalWidth / 2 + ICON_SIZE + PADDING, 0, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

-- Font creation for the boombox HUD
surface.CreateFont("BoomboxFont", {
    font = "Roboto",
    size = 50,
    weight = 700,
    antialias = true,
    shadow = true,
})
