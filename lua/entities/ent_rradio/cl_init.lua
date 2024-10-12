include("shared.lua")
include("rradio/cl_rradio_colors.lua")

local GetFont = rRadio.GetFont or function(size, bold)
    local fontName = "rRadio_Font_" .. size .. (bold and "_Bold" or "")
    if not _G[fontName] then
        surface.CreateFont(fontName, {
            font = bold and "Roboto Bold" or "Roboto",
            size = size,
            weight = bold and 700 or 400,
            antialias = true,
        })
        _G[fontName] = true
    end
    return fontName
end

local MAX_DIST = 500^2
local FADE_START = 400^2

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos()
    local myPos = LocalPlayer():GetPos()
    local distSqr = pos:DistToSqr(myPos)

    if distSqr > MAX_DIST then return end

    local ang = self:GetAngles()
    local forward = ang:Forward()
    local toPlayer = (myPos - pos):GetNormalized()
    local dotProduct = forward:Dot(toPlayer)

    if dotProduct > 0 then return end

    local alpha = 1
    if distSqr > FADE_START then
        alpha = 1 - (math.sqrt(distSqr) - math.sqrt(FADE_START)) / (math.sqrt(MAX_DIST) - math.sqrt(FADE_START))
    end
    alpha = alpha * math.max(0, -dotProduct)

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
    draw.RoundedBox(8, -w/2, -h/2, w, h, ColorAlpha(colors.bg, alpha * 255))

    -- Playing status indicator
    local isPlaying = self:GetNWString("CurrentStation", "") ~= ""
    draw.RoundedBox(4, -w/2 + 10, -h/2 + 10, 8, 8, ColorAlpha(isPlaying and colors.accent or colors.divider, alpha * 255))

    -- Owner name
    local owner = self:GetOwner()
    local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
    draw.SimpleText(ownerName, GetFont(18, true), -w/2 + 25, -h/2 + 10, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Station info
    local stationKey = self:GetNWString("CurrentStationKey", "")
    local stationIndex = self:GetNWInt("CurrentStationIndex", 0)
    local stationName = "Not playing"
    local countryName = ""

    if stationKey ~= "" and stationIndex > 0 and rRadio.Stations[stationKey] and rRadio.Stations[stationKey][stationIndex] then
        stationName = rRadio.Stations[stationKey][stationIndex].n
        countryName = string.gsub(stationKey, "_", " ")
    end

    draw.SimpleText(stationName, GetFont(16), -w/2 + 10, -h/2 + 40, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(countryName, GetFont(14), -w/2 + 10, -h/2 + 60, ColorAlpha(colors.text, alpha * 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    -- Volume indicator
    local volume = self:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
    draw.RoundedBox(4, -w/2 + 10, h/2 - 20, w - 20, 8, ColorAlpha(colors.divider, alpha * 255))
    draw.RoundedBox(4, -w/2 + 10, h/2 - 20, (w - 20) * volume, 8, ColorAlpha(colors.accent, alpha * 255))
end

net.Receive("rRadio_UpdateColorScheme", function()
    hook.Run("rRadio_ColorSchemeChanged")
end)
