--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Utility functions for client-side operations in rRadio addon.
]]

local RRADIO = RRADIO or {}

function RRADIO.SafeColor(color)
    return IsColor(color) and color or Color(255, 255, 255)
end

function RRADIO.SortIgnoringThe(a, b)
    local function stripThe(str)
        return str:gsub("^The%s+", ""):lower()
    end
    return stripThe(a) < stripThe(b)
end

function RRADIO.GetScaledFontSize(baseSize)
    local scaleFactor = math.min(ScrW() / 1920, ScrH() / 1080) * 1.5
    return math.Round(baseSize * scaleFactor)
end

local fontCache = {}
function RRADIO.GetFont(size, isHeading)
    local scaledSize = RRADIO.GetScaledFontSize(size)
    local fontName = "rRadio_Roboto_" .. scaledSize .. "_" .. (isHeading and "Black" or "Regular")
    
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = isHeading and "Roboto Black" or "Roboto Bold",
            size = scaledSize,
            weight = isHeading and 900 or 400,
            antialias = true,
        })
        fontCache[fontName] = true
    end
    
    return fontName
end

return RRADIO
