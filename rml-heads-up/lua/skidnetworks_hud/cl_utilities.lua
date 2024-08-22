function DrawTextShadow(text, font, x, y, color, alignX, alignY, shadowDist, shadowColor)
    -- Ensure color and shadowColor are valid before using them
    color = color or Color(255, 255, 255)
    shadowColor = shadowColor or Color(0, 0, 0, 150)
    
    draw.SimpleText(text, font, x + (shadowDist or 2), y + (shadowDist or 2), shadowColor, alignX, alignY)
    draw.SimpleText(text, font, x, y, color, alignX, alignY)
end

local function GetRainbowColor(frequency)
    local r = math.sin(frequency * CurTime() + 0) * 127 + 128
    local g = math.sin(frequency * CurTime() + 2) * 127 + 128
    local b = math.sin(frequency * CurTime() + 4) * 127 + 128
    return Color(r, g, b)
end

local function ScaleW(width)
    return width * (ScrW() / 1920)
end

local function ScaleH(height)
    return height * (ScrH() / 1080)
end

local function DrawGradientBox(x, y, w, h, color1, color2)
    local gradient = surface.GetTextureID("gui/gradient")
    surface.SetDrawColor(color1)
    surface.SetTexture(gradient)
    surface.DrawTexturedRect(x, y, w, h)

    surface.SetDrawColor(color2)
    surface.SetTexture(gradient)
    surface.DrawTexturedRectRotated(x + w / 2, y + h / 2, w, h, 180)
end

local function DrawIcon(icon, x, y, w, h, color)
    surface.SetMaterial(Material(icon))
    surface.SetDrawColor(color)
    surface.DrawTexturedRect(x, y, w, h)
end

skidnetworks = skidnetworks or {}
skidnetworks.DrawTextShadow = DrawTextShadow
skidnetworks.GetRainbowColor = GetRainbowColor
skidnetworks.ScaleW = ScaleW
skidnetworks.ScaleH = ScaleH
skidnetworks.DrawGradientBox = DrawGradientBox
skidnetworks.DrawIcon = DrawIcon
