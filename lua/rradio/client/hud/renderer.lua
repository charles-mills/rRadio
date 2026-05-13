rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.renderer = rRadio.client.hud.renderer or {}

local renderer = rRadio.client.hud.renderer
local layout = rRadio.client.hud.layout

local TEXT_BORDER = rRadio.client.hud.DETAIL_SCALE or 2

local lastR, lastG, lastB, lastA = -1, -1, -1, -1


local function snapPixel( value )
    return math.floor( value + 0.5 )
end


local function drawTextAt( text, x, y, color )
    surface.SetTextColor( color.r, color.g, color.b, color.a )
    surface.SetTextPos( x, y )
    surface.DrawText( text )
end


function renderer.BeginFrame()
    lastR, lastG, lastB, lastA = -1, -1, -1, -1
end


function renderer.BeginHud( hudState )
    cam.Start3D2D( hudState.position, hudState.angles, layout.HUD_SCALE )
end


function renderer.EndHud()
    cam.End3D2D()
end


function renderer.DrawRect( x, y, width, height, color )
    local drawX = snapPixel( x )
    local drawY = snapPixel( y )
    local drawWidth = snapPixel( x + width ) - drawX
    local drawHeight = snapPixel( y + height ) - drawY
    if drawWidth <= 0 or drawHeight <= 0 then return end
    if color.a <= 0 then return end

    if color.r ~= lastR or color.g ~= lastG or color.b ~= lastB or color.a ~= lastA then
        surface.SetDrawColor( color.r, color.g, color.b, color.a )
        lastR, lastG, lastB, lastA = color.r, color.g, color.b, color.a
    end

    surface.DrawRect( drawX, drawY, drawWidth, drawHeight )
end


function renderer.DrawOutlinedText( text, font, x, y, color, borderColor )
    local drawX = snapPixel( x )
    local drawY = snapPixel( y )

    surface.SetFont( font )

    if borderColor and borderColor.a > 0 then
        drawTextAt( text, drawX - TEXT_BORDER, drawY, borderColor )
        drawTextAt( text, drawX + TEXT_BORDER, drawY, borderColor )
        drawTextAt( text, drawX, drawY - TEXT_BORDER, borderColor )
        drawTextAt( text, drawX, drawY + TEXT_BORDER, borderColor )
        drawTextAt( text, drawX - TEXT_BORDER, drawY - TEXT_BORDER, borderColor )
        drawTextAt( text, drawX + TEXT_BORDER, drawY - TEXT_BORDER, borderColor )
        drawTextAt( text, drawX - TEXT_BORDER, drawY + TEXT_BORDER, borderColor )
        drawTextAt( text, drawX + TEXT_BORDER, drawY + TEXT_BORDER, borderColor )
    end

    drawTextAt( text, drawX, drawY, color )
end


return renderer
