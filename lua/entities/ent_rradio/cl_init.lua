--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Client-side initialization and rendering for the rRadio boombox entity.
]]

include("shared.lua")
include("rradio/cl_rradio_colors.lua")
include("rradio/sh_rradio_utils.lua")

local surface = surface
local draw = draw
local cam = cam
local math = math
local IsValid = IsValid
local ColorAlpha = ColorAlpha
local Vector = Vector

local fonts = {}
local function GetFont(size, bold)
    local key = size .. (bold and "b" or "")
    if not fonts[key] then
        local fontName = "rRadio_Font_" .. key
        surface.CreateFont(fontName, {
            font = bold and "Roboto Bold" or "Roboto",
            size = size * 1.75,
            weight = bold and 600 or 300,
            antialias = true,
            blursize = 0,
            scanlines = 0,
        })
        fonts[key] = fontName
    end
    return fonts[key]
end

local function PulseValue(min, max, speed)
    return min + (max - min) * (0.5 + math.sin(CurTime() * speed) * 0.5)
end

local MAX_DIST = 300
local FADE_START = 200
local MAX_DIST_SQR = MAX_DIST * MAX_DIST
local FADE_START_SQR = FADE_START * FADE_START

RRADIO.Icons.LOCKED = Material("hud/locked.png", "smooth mips")
RRADIO.Icons.UNLOCKED = Material("hud/unlocked.png", "smooth mips")

local function CalculateAlpha(distSqr, dotProduct)
    local alpha = 1
    if distSqr > FADE_START_SQR then
        alpha = 1 - (math.sqrt(distSqr) - FADE_START) / (MAX_DIST - FADE_START)
    end
    return alpha * math.max(0, -dotProduct)
end

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos()
    local myPos = LocalPlayer():GetPos()
    local distSqr = pos:DistToSqr(myPos)

    if distSqr > MAX_DIST_SQR then return end

    local ang = self:GetAngles()
    local forward = ang:Forward()
    local toPlayer = (myPos - pos):GetNormalized()
    local dotProduct = forward:Dot(toPlayer)

    if dotProduct > 0 then return end

    local alpha = CalculateAlpha(distSqr, dotProduct)

    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    pos = pos + Vector(0, 0, 23)

    cam.Start3D2D(pos, ang, 0.05)
        self:DrawHUD(alpha)
    cam.End3D2D()
end

function ENT:DrawHUD(alpha)
    local colors = RRADIO.GetColors()
    local w, h = 600, 200
    local halfW, halfH = w/2, h/2
    
    draw.RoundedBox(16, -halfW, -halfH, w, h, ColorAlpha(colors.bg, alpha * 255))

    -- Owner name
    local owner = self:GetNWEntity("Owner")
    local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
    draw.SimpleText(ownerName, GetFont(36, true), -halfW + 20, -halfH + 20, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Control indicator (Locked/Unlocked icon)
    local canControl = self:GetNWBool("CanControl", false)
    local iconSize = 32
    local iconMaterial = canControl and RRADIO.Icons.UNLOCKED or RRADIO.Icons.LOCKED
    local iconColor = ColorAlpha(colors.accent, alpha * 255)
    
    if iconMaterial then  -- Check if the material is valid before using it
        surface.SetDrawColor(iconColor)
        surface.SetMaterial(iconMaterial)
        surface.DrawTexturedRect(halfW - iconSize - 10, -halfH + 10, iconSize, iconSize)
    end

    -- Playing status indicator
    local isPlaying = self:GetNWString("CurrentStationURL", "") ~= ""
    local indicatorSize = isPlaying and PulseValue(14, 18, 4) or 16
    local indicatorX = halfW - iconSize - 30 - indicatorSize
    local indicatorY = -halfH + 10 + (iconSize - indicatorSize) / 2
    draw.RoundedBox(indicatorSize / 2, indicatorX, indicatorY, indicatorSize, indicatorSize, ColorAlpha(isPlaying and colors.accent or colors.divider, alpha * 255))

    -- Station info
    local stationName = self:GetNWString("CurrentStationName", "Not playing")
    local countryName = rRadio.FormatCountryName(self:GetNWString("CurrentStationCountry", ""))

    draw.SimpleText(stationName, GetFont(28), -halfW + 20, -halfH + 75, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(countryName, GetFont(28), -halfW + 20, -halfH + 120, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Volume indicator
    local volume = self:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
    local volumeWidth = w - 40
    draw.RoundedBox(8, -halfW + 20, halfH - 30, volumeWidth, 16, ColorAlpha(colors.divider, alpha * 255))
    draw.RoundedBox(8, -halfW + 20, halfH - 30, volumeWidth * volume, 16, ColorAlpha(colors.accent, alpha * 255))
end

net.Receive("rRadio_UpdateColorScheme", function()
    hook.Run("rRadio_ColorSchemeChanged")
end)
