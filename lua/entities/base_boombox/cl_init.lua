--[[ 
    rRadio Addon for Garry's Mod - Client Boombox Script
    Description: Manages client-side boombox functionalities and UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

include("shared.lua")
include("misc/config.lua")
include("misc/utils.lua")
local LanguageManager = include("localisation/language_manager.lua")

-- Cache frequently used functions for performance
local IsValid = IsValid
local LocalPlayer = LocalPlayer
local math_Clamp = math.Clamp
local math_sin = math.sin
local draw_SimpleText = draw.SimpleText
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawLine = surface.DrawLine

-- -------------------------------
-- 1. Utility Functions
-- -------------------------------

-- Function to scale UI elements based on screen resolution
local function ResponsiveScale(value)
    local baseWidth, baseHeight = 2560, 1440
    local scaleFactor = math.min(ScrW() / baseWidth, ScrH() / baseHeight)
    return math.Round(value * scaleFactor)
end

-- -------------------------------
-- 2. UI Constants and Variables
-- -------------------------------

local panelWidth = ResponsiveScale(335)
local panelHeight = ResponsiveScale(100)
local cornerRadius = ResponsiveScale(8)
local animationDuration = 0.3
local panelAlpha = 0
local targetPanelAlpha = 0

-- -------------------------------
-- 3. Font Creation
-- -------------------------------

surface.CreateFont("BoomboxTitleFont", {
    font = "Roboto",
    size = ResponsiveScale(24),
    weight = 700,
})

surface.CreateFont("BoomboxTextFont", {
    font = "Roboto",
    size = ResponsiveScale(16),
    weight = 500,
})

-- -------------------------------
-- 4. Drawing Functions
-- -------------------------------

-- Function to draw a rounded box
local function DrawRoundedBox(x, y, w, h, radius, color)
    draw.RoundedBox(radius, x, y, w, h, color)
end

-- Function to draw an outlined rounded box
local function DrawOutlinedRoundedBox(x, y, w, h, radius, color, outlineColor, outlineWidth)
    draw.RoundedBox(radius, x, y, w, h, outlineColor)
    draw.RoundedBox(radius, x + outlineWidth, y + outlineWidth, w - outlineWidth * 2, h - outlineWidth * 2, color)
end

-- Function to get the display name for the boombox owner
local function getDisplayName(entity)
    if not IsValid(entity) then return "Invalid Entity" end
    
    local owner = entity:GetNWEntity("Owner")
    if IsValid(owner) then return owner:Nick() end
    
    local ownerName = entity:GetNWString("OwnerName", "Unknown")
    return ownerName == "Unknown" and "Boombox" or ownerName
end

-- Function to draw the boombox information panel
local function DrawBoomboxPanel(ent, x, y)
    local panelColor = Color(30, 30, 30, panelAlpha)
    local outlineColor = Color(60, 60, 60, panelAlpha)
    local textColor = Color(255, 255, 255, panelAlpha)
    local subTextColor = Color(200, 200, 200, panelAlpha)

    local ownerName = getDisplayName(ent)
    local stationName = ent:GetStationName() ~= "" and ent:GetStationName() or Config.Lang["NoStationPlaying"]
    local country = ent:GetNWString("Country", Config.Lang["Unknown"])

    if (country ~= Config.Lang["Unknown"]) then
        country = utils.formatCountryNameForDisplay(country)
    end

    DrawOutlinedRoundedBox(x, y, panelWidth, panelHeight, cornerRadius, panelColor, outlineColor, 2)

    -- Title (Player's name or "Boombox")
    local titleText = ownerName == "Boombox" and ownerName or string.format(Config.Lang["PlayersBoombox"], ownerName)
    draw_SimpleText(titleText, "BoomboxTitleFont", x + panelWidth/2, y + ResponsiveScale(15), textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- Separator
    surface_SetDrawColor(outlineColor)
    surface_DrawLine(x + ResponsiveScale(10), y + ResponsiveScale(45), x + panelWidth - ResponsiveScale(10), y + ResponsiveScale(45))

    -- Station info
    local stationText = Config.Lang["Station"] .. ": " .. stationName
    local countryText = Config.Lang["Country"] .. ": " .. country
    draw_SimpleText(stationText, "BoomboxTextFont", x + ResponsiveScale(10), y + ResponsiveScale(55), subTextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw_SimpleText(countryText, "BoomboxTextFont", x + ResponsiveScale(10), y + ResponsiveScale(75), subTextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Playing indicator
    if ent:GetStationName() ~= "" then
        local indicatorSize = ResponsiveScale(16)
        local indicatorX = x + panelWidth - ResponsiveScale(30)
        local indicatorY = y + ResponsiveScale(20)
        local pulseSize = math_sin(CurTime() * 5) * ResponsiveScale(4)
        draw.RoundedBox(indicatorSize / 2, indicatorX - pulseSize / 2, indicatorY - pulseSize / 2, indicatorSize + pulseSize, indicatorSize + pulseSize, Color(0, 255, 0, panelAlpha * 0.5))
        draw.RoundedBox(indicatorSize / 2, indicatorX, indicatorY, indicatorSize, indicatorSize, Color(0, 255, 0, panelAlpha))
    end
end

-- -------------------------------
-- 5. Animation Functions
-- -------------------------------

-- Function to update the panel's alpha for smooth fade in/out
local function UpdatePanelAlpha()
    if panelAlpha ~= targetPanelAlpha then
        panelAlpha = Lerp(0.1, panelAlpha, targetPanelAlpha)
        if math.abs(panelAlpha - targetPanelAlpha) < 0.1 then
            panelAlpha = targetPanelAlpha
        end
    end
end

-- Create a timer to update the panel alpha
timer.Create("BoomboxPanelAlphaUpdate", 0.03, 0, UpdatePanelAlpha)

-- -------------------------------
-- 6. Entity Drawing
-- -------------------------------

-- Main drawing function for the boombox entity
function ENT:Draw()
    self:DrawModel()

    if not GetConVar("radio_show_boombox_text"):GetBool() then return end

    local pos = self:GetPos()
    local myPos = LocalPlayer():GetPos()
    local dist = pos:Distance(myPos)
    if dist > 600 then return end

    local ang = self:GetAngles()
    local upOffset = self:OBBMaxs().z + ResponsiveScale(6)
    local backwardOffset = ResponsiveScale(3)
    local panelPos = pos + ang:Up() * upOffset + ang:Forward() * backwardOffset

    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    local fadeDistance = 400
    local fadeAlpha = math_Clamp((fadeDistance - dist) / fadeDistance, 0, 1)
    targetPanelAlpha = fadeAlpha * 255

    cam.Start3D2D(panelPos, ang, 0.1)
        DrawBoomboxPanel(self, -panelWidth / 2, -panelHeight / 2)
    cam.End3D2D()
end

-- -------------------------------
-- 7. Network Receivers
-- -------------------------------

-- Network receiver for updating radio status
net.Receive("rRadio_UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local country = net.ReadString()

    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
        entity:SetStationName(stationName)
        entity:SetNWString("Country", country)
    end
end)