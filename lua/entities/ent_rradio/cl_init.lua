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
            size = size,
            weight = bold and 700 or 400,
            antialias = true,
        })
        fonts[key] = fontName
    end
    return fonts[key]
end

local MAX_DIST = 500
local FADE_START = 400
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

    cam.Start3D2D(pos, ang, 0.1)
        self:DrawHUD(alpha)
    cam.End3D2D()
end

function ENT:DrawHUD(alpha)
    local colors = RRADIO.GetColors()
    local w, h = 300, 100
    local halfW, halfH = w/2, h/2
    
    draw.RoundedBox(8, -halfW, -halfH, w, h, ColorAlpha(colors.bg, alpha * 255))

    -- Playing status indicator
    local isPlaying = self:GetNWString("CurrentStation", "") ~= ""
    draw.RoundedBox(4, -halfW + 10, -halfH + 12, 8, 8, ColorAlpha(isPlaying and colors.accent or colors.divider, alpha * 255))

    -- Owner name
    local owner = self:GetNWEntity("Owner")
    local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
    draw.SimpleText(ownerName, GetFont(18, true), -halfW + 25, -halfH + 10, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Control indicator (Locked/Unlocked icon)
    local canControl = self:GetNWBool("CanControl", false)
    local iconSize = 16
    local iconMaterial = canControl and RRADIO.Icons.UNLOCKED or RRADIO.Icons.LOCKED
    local iconColor = ColorAlpha(colors.accent, alpha * 255)
    
    surface.SetDrawColor(iconColor)
    surface.SetMaterial(iconMaterial)
    surface.DrawTexturedRect(halfW - iconSize - 10, -halfH + 10, iconSize, iconSize)

    -- Station info
    local stationKey = self:GetNWString("CurrentStationKey", "")
    local stationIndex = self:GetNWInt("CurrentStationIndex", 0)
    local stationName = "Not playing"
    local countryName = ""

    if stationKey ~= "" and stationIndex > 0 and rRadio.Stations[stationKey] and rRadio.Stations[stationKey][stationIndex] then
        stationName = rRadio.Stations[stationKey][stationIndex].n
        countryName = rRadio.FormatCountryName(stationKey)
    end

    draw.SimpleText(stationName, GetFont(16), -halfW + 10, -halfH + 40, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(countryName, GetFont(14), -halfW + 10, -halfH + 60, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Volume indicator
    local volume = self:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
    local volumeWidth = w - 20
    draw.RoundedBox(4, -halfW + 10, halfH - 20, volumeWidth, 8, ColorAlpha(colors.divider, alpha * 255))
    draw.RoundedBox(4, -halfW + 10, halfH - 20, volumeWidth * volume, 8, ColorAlpha(colors.accent, alpha * 255))
end

net.Receive("rRadio_UpdateColorScheme", function()
    hook.Run("rRadio_ColorSchemeChanged")
end)
