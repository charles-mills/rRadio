--[[ 
    rRadio Addon for Garry's Mod - Client Boombox Script
    Description: Manages client-side boombox functionalities and UI.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

include("shared.lua")
include("misc/config.lua")

local function ResponsiveScale(value)
    local baseWidth = 2560
    local baseHeight = 1440
    local scaleFactorW = ScrW() / baseWidth
    local scaleFactorH = ScrH() / baseHeight
    local scaleFactor = math.min(scaleFactorW, scaleFactorH)
    return math.Round(value * scaleFactor)
end

local panelWidth = ResponsiveScale(335)
local panelHeight = ResponsiveScale(100)
local cornerRadius = ResponsiveScale(8)
local animationDuration = 0.3
local panelAlpha = 0
local targetPanelAlpha = 0

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

local function DrawRoundedBox(x, y, w, h, radius, color)
    draw.RoundedBox(radius, x, y, w, h, color)
end

local function DrawOutlinedRoundedBox(x, y, w, h, radius, color, outlineColor, outlineWidth)
    draw.RoundedBox(radius, x, y, w, h, outlineColor)
    draw.RoundedBox(radius, x + outlineWidth, y + outlineWidth, w - outlineWidth * 2, h - outlineWidth * 2, color)
end

local function DrawBoomboxPanel(ent, x, y)
    local owner = ent:GetNWEntity("Owner")
    local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
    local stationName = ent:GetStationName() ~= "" and ent:GetStationName() or "No station playing"
    local country = "Unknown" -- You'll need to implement a way to get the country of origin for the station

    DrawOutlinedRoundedBox(x, y, panelWidth, panelHeight, cornerRadius, Color(30, 30, 30, panelAlpha), Color(60, 60, 60, panelAlpha), 2)

    -- Title (Player's name)
    draw.SimpleText(ownerName .. "'s Boombox", "BoomboxTitleFont", x + panelWidth/2, y + ResponsiveScale(15), Color(255, 255, 255, panelAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- Separator
    surface.SetDrawColor(Color(60, 60, 60, panelAlpha))
    surface.DrawLine(x + ResponsiveScale(10), y + ResponsiveScale(45), x + panelWidth - ResponsiveScale(10), y + ResponsiveScale(45))

    -- Station info
    draw.SimpleText("Station: " .. stationName, "BoomboxTextFont", x + ResponsiveScale(10), y + ResponsiveScale(55), Color(200, 200, 200, panelAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("Country: " .. country, "BoomboxTextFont", x + ResponsiveScale(10), y + ResponsiveScale(75), Color(200, 200, 200, panelAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Playing indicator (increased size)
    if ent:GetStationName() ~= "" then
        local indicatorSize = ResponsiveScale(16)  -- Increased from 8 to 16
        local indicatorX = x + panelWidth - ResponsiveScale(30)  -- Adjusted position
        local indicatorY = y + ResponsiveScale(20)  -- Adjusted position
        local pulseSize = math.sin(CurTime() * 5) * ResponsiveScale(4)  -- Increased pulse size
        draw.RoundedBox(indicatorSize / 2, indicatorX - pulseSize / 2, indicatorY - pulseSize / 2, indicatorSize + pulseSize, indicatorSize + pulseSize, Color(0, 255, 0, panelAlpha * 0.5))
        draw.RoundedBox(indicatorSize / 2, indicatorX, indicatorY, indicatorSize, indicatorSize, Color(0, 255, 0, panelAlpha))
    end
end

function ENT:Draw()
    self:DrawModel()

    if GetConVar("radio_show_boombox_text"):GetBool() then
        local pos = self:GetPos()
        local ang = self:GetAngles()
        local myPos = LocalPlayer():GetPos()

        local dist = pos:Distance(myPos)
        if dist > 600 then return end

        -- Calculate the position above and in front of the boombox
        local upOffset = self:OBBMaxs().z + ResponsiveScale(6)
        local backwardOffset = ResponsiveScale(3)
        local panelPos = pos + ang:Up() * upOffset + ang:Forward() * backwardOffset

        -- Flip the angle so it's visible from the front (maybe fix the model at some point)
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(panelPos, ang, 0.1)
            local fadeDistance = 400
            local fadeAlpha = math.Clamp((fadeDistance - dist) / fadeDistance, 0, 1)
            targetPanelAlpha = fadeAlpha * 255

            panelAlpha = Lerp(FrameTime() / animationDuration, panelAlpha, targetPanelAlpha)
            
            DrawBoomboxPanel(self, -panelWidth / 2, -panelHeight / 2) -- Center the panel
        cam.End3D2D()
    end
end

net.Receive("rRadio_UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()

    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
        entity:SetStationName(stationName)
    end
end)