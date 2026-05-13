rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.style = rRadio.client.ui.style or {}

local style = rRadio.client.ui.style
local fonts = rRadio.client.fonts
local BASE_WIDTH = 2560
local CONTROL_RADIUS = 8
local BORDER_WIDTH = 1
local SOFT_DIVIDER_ALPHA = 55
local SOFT_RESIZE_ALPHA = 65
local CURSOR_BUTTON = "hand"
local CURSOR_TEXT = "beam"
local CURSOR_VERTICAL_GRIP = "sizens"
local CURSOR_HORIZONTAL_GRIP = "sizewe"
local scaleFontKey
local menuScaleConVar = GetConVar( "rammel_rradio_menu_scale" )
local menuWidthScaleConVar = GetConVar( "rammel_rradio_menu_width_scale" )
local softBordersConVar = GetConVar( "rammel_rradio_menu_soft_borders" )

style.Materials = {
    bookmark = Material( "hud/bookmark.png", "smooth" ),
    clock = Material( "hud/clock.png", "smooth" ),
    close = Material( "hud/close.png", "smooth" ),
    globe = Material( "hud/globe.png", "smooth" ),
    radio = Material( "hud/radio.png", "smooth" ),
    returnIcon = Material( "hud/return.png", "smooth" ),
    settings = Material( "hud/settings.png", "smooth" ),
    settingsBold = Material( "hud/settings_b.png", "smooth" ),
    star = Material( "hud/star.png", "smooth" ),
    starFull = Material( "hud/star_full.png", "smooth" ),
    writing = Material( "hud/writing.png", "smooth" ),
    volumeMute = Material( "hud/vol_mute.png", "smooth" ),
    volumeDown = Material( "hud/vol_down.png", "smooth" ),
    volumeUp = Material( "hud/vol_up.png", "smooth" )
}

function style.GetMenuScale()
    local state = rRadio.client.ui.state
    local stateScale = tonumber( state.menuScale )
    if stateScale then return stateScale end

    local config = rRadio.config.MenuScale
    local minimum = tonumber( config.Min ) or 0.75
    local maximum = tonumber( config.Max ) or 2
    local value = menuScaleConVar:GetFloat()

    return math.Round( math.Clamp( value, minimum, maximum ), 2 )
end

function style.GetMenuWidthScale()
    local state = rRadio.client.ui.state
    local stateScale = tonumber( state.menuWidthScale )
    if stateScale then return stateScale end

    local config = rRadio.config.MenuScale
    local minimum = tonumber( config.WidthMin ) or tonumber( config.Min ) or 0.75
    local maximum = tonumber( config.WidthMax ) or tonumber( config.Max ) or 2
    local value = menuWidthScaleConVar:GetFloat()

    return math.Round( math.Clamp( value, minimum, maximum ), 2 )
end

function style.SetMenuScale( value, persist )
    local config = rRadio.config.MenuScale
    local minimum = tonumber( config.Min ) or 0.75
    local maximum = tonumber( config.Max ) or 2
    local clamped = math.Round( math.Clamp( tonumber( value ) or 1, minimum, maximum ), 2 )

    rRadio.client.ui.state.menuScale = clamped
    style.RefreshFonts()
    if persist then RunConsoleCommand( "rammel_rradio_menu_scale", string.format( "%.2f", clamped ) ) end

    return clamped
end

function style.SetMenuWidthScale( value, persist )
    local config = rRadio.config.MenuScale
    local minimum = tonumber( config.WidthMin ) or tonumber( config.Min ) or 0.75
    local maximum = tonumber( config.WidthMax ) or tonumber( config.Max ) or 2
    local clamped = math.Round( math.Clamp( tonumber( value ) or 1, minimum, maximum ), 2 )

    rRadio.client.ui.state.menuWidthScale = clamped
    if persist then RunConsoleCommand( "rammel_rradio_menu_width_scale", string.format( "%.2f", clamped ) ) end

    return clamped
end

function style.SyncScaleFromConVars()
    local state = rRadio.client.ui.state

    state.menuScale = nil
    state.menuWidthScale = nil
    state.menuScale = style.GetMenuScale()
    state.menuWidthScale = style.GetMenuWidthScale()
    scaleFontKey = nil
end

function style.ScreenScale( value )
    return math.floor( value * ( ScrW() / BASE_WIDTH ) + 0.5 )
end

function style.Scale( value )
    return math.floor( value * ( ScrW() / BASE_WIDTH ) * style.GetMenuScale() + 0.5 )
end

function style.GetFrameSize()
    local frameSize = rRadio.config.FrameSize
    local width = style.Scale( frameSize.width or 600 ) * style.GetMenuWidthScale()
    local height = style.Scale( frameSize.height or 800 )

    return math.max( style.Scale( 420 ), width ), math.max( style.Scale( 560 ), height )
end

function style.GetSurfaceColor( tier )
    local colors = rRadio.config.UI
    if tier == "frame" then return colors.SurfaceFrameColor or colors.BackgroundColor end
    if tier == "panel" then return colors.SurfacePanelColor or colors.PanelColor end
    if tier == "card" then return colors.SurfaceCardColor or colors.CardColor or colors.PanelColor end
    if tier == "cardHover" then return colors.SurfaceCardHoverColor or colors.Highlight end
    if tier == "control" then
        return colors.SurfaceControlColor
            or colors.SearchBoxColor
            or colors.ButtonColor
            or colors.SurfacePanelColor
            or colors.PanelColor
    end
    if tier == "controlHover" then
        return colors.SurfaceControlHoverColor
            or colors.ButtonHoverColor
            or colors.SurfaceCardHoverColor
            or colors.Highlight
    end

    return colors.PanelColor or colors.BackgroundColor
end

function style.GetBorderColor()
    local colors = rRadio.config.UI
    return colors.Border or colors.ScrollbarGripColor or colors.TextColor
end

function style.GetSliderTrackColor()
    local colors = rRadio.config.UI
    return colors.SliderTrackColor or colors.SurfaceFrameColor or colors.ScrollbarColor or colors.BackgroundColor
end

function style.GetFooterSurfaceColor()
    local colors = rRadio.config.UI
    return colors.FooterSurfaceColor
        or colors.FooterControlColor
        or colors.CloseButtonColor
        or style.GetSurfaceColor( "control" )
end

function style.GetFooterSurfaceHoverColor()
    local colors = rRadio.config.UI
    return colors.FooterSurfaceHoverColor
        or colors.FooterControlHoverColor
        or colors.CloseButtonHoverColor
        or colors.FooterSurfaceColor
        or colors.FooterControlColor
        or style.GetSurfaceColor( "controlHover" )
end

function style.GetKnobColor()
    local colors = rRadio.config.UI
    return colors.KnobColor or colors.TextColor
end

function style.GetKnobHoverColor()
    local colors = rRadio.config.UI
    return colors.KnobHoverColor or colors.AccentPrimary or colors.TextColor
end

function style.GetKnobBorderColor()
    local colors = rRadio.config.UI
    return colors.KnobBorderColor or colors.AccentPrimary or style.GetBorderColor()
end

function style.GetDividerColor()
    local colors = rRadio.config.UI
    return colors.DividerColor or colors.Border or colors.ButtonColor or colors.TextColor
end

function style.GetResizeGripColor()
    local colors = rRadio.config.UI
    return colors.ResizeGripColor
        or colors.AccentSecondary
        or colors.ScrollbarGripColor
        or colors.TextColor
end

local function drawRoundedSurface( radius, x, y, width, height, fillColor, borderColor, borderWidth )
    local realRadius = math.max( 0, math.floor( tonumber( radius ) or CONTROL_RADIUS ) )
    local boxWidth = math.max( 0, width or 0 )
    local boxHeight = math.max( 0, height or 0 )
    local resolvedFill = fillColor or style.GetSurfaceColor( "card" )

    if not borderColor then
        draw.RoundedBox( realRadius, x, y, boxWidth, boxHeight, resolvedFill )
        return
    end

    local realBorder = math.max( 1, math.floor( tonumber( borderWidth ) or BORDER_WIDTH ) )
    draw.RoundedBox( realRadius, x, y, boxWidth, boxHeight, borderColor )
    if boxWidth <= realBorder * 2 or boxHeight <= realBorder * 2 then return end

    draw.RoundedBox(
        math.max( 0, realRadius - realBorder ),
        x + realBorder,
        y + realBorder,
        boxWidth - realBorder * 2,
        boxHeight - realBorder * 2,
        resolvedFill
    )
end

local function colorWithAlpha( color, alpha )
    if not color then return nil end

    return ColorAlpha( color, alpha )
end

function style.IsSoftUIEnabled()
    return softBordersConVar:GetBool()
end

-- Surface roles are semantic: button = command surface, control = input chrome,
-- panel = containing shell, card = repeated content, state = active/error/focus.
function style.GetChromeBorderColor( role, fallbackColor )
    if fallbackColor == false then return nil end

    local borderColor = fallbackColor or style.GetBorderColor()
    if not borderColor then return nil end
    if not style.IsSoftUIEnabled() then return borderColor end

    if role == "panel" or role == "control" then return nil end
    if role == "divider" then return colorWithAlpha( borderColor, SOFT_DIVIDER_ALPHA ) end
    if role == "resize" then return colorWithAlpha( borderColor, SOFT_RESIZE_ALPHA ) end
    if role == "state" then return borderColor end

    return nil
end

function style.GetPlaybackStateColor( playbackState )
    local colors = rRadio.config.UI
    if playbackState == "pending" or playbackState == "tuning" then
        return colors.Loading or colors.AccentSecondary or colors.AccentPrimary or colors.TextColor
    end

    if playbackState == "queued" then
        return colors.Disabled or colors.Loading or colors.AccentSecondary or colors.TextColor
    end

    if playbackState == "playing" then
        return colors.AccentPrimary or colors.PlayingButtonColor or colors.TextColor
    end

    if playbackState == "error" then return colors.Error or colors.TextColor end

    return nil
end

function style.SetCursor( panel, cursor )
    if not IsValid( panel ) or not panel.SetCursor then return end

    panel:SetCursor( cursor )
end

function style.SetButtonCursor( panel )
    style.SetCursor( panel, CURSOR_BUTTON )
end

function style.SetTextCursor( panel )
    style.SetCursor( panel, CURSOR_TEXT )
end

function style.SetVerticalGripCursor( panel )
    style.SetCursor( panel, CURSOR_VERTICAL_GRIP )
end

function style.SetHorizontalGripCursor( panel )
    style.SetCursor( panel, CURSOR_HORIZONTAL_GRIP )
end

function style.DrawSurface( role, radius, x, y, width, height, fillColor, borderColor, borderWidth )
    if borderWidth == 0 or borderColor == false then
        drawRoundedSurface( radius, x, y, width, height, fillColor )
        return
    end

    local chromeBorderColor = style.GetChromeBorderColor( role, borderColor )
    drawRoundedSurface( radius, x, y, width, height, fillColor, chromeBorderColor, borderWidth )
end

function style.LerpColor( fraction, fromColor, toColor, output )
    output = output or Color( 0, 0, 0, 255 )
    fraction = math.Clamp( tonumber( fraction ) or 0, 0, 1 )
    output.r = Lerp( fraction, fromColor.r, toColor.r )
    output.g = Lerp( fraction, fromColor.g, toColor.g )
    output.b = Lerp( fraction, fromColor.b, toColor.b )
    output.a = Lerp( fraction, fromColor.a or 255, toColor.a or 255 )

    return output
end

function style.ApproachLerp( current, target, speed )
    local amount = FrameTime() * ( tonumber( speed ) or 10 )
    return Lerp( math.Clamp( amount, 0, 1 ), current or 0, target or 0 )
end

local function trimText( text, length )
    if utf8 and utf8.sub then return utf8.sub( text, 1, length ) end

    return string.sub( text, 1, length )
end

local function textLength( text )
    if utf8 and utf8.len then return utf8.len( text ) or #text end

    return #text
end

function style.TruncateText( text, font, maxWidth )
    text = tostring( text or "" )
    if maxWidth <= 0 then return "" end

    surface.SetFont( font )
    local width = surface.GetTextSize( text )
    if width <= maxWidth then return text end

    local ellipsis = "..."
    local low = 0
    local high = textLength( text )
    while low < high do
        local mid = math.ceil( ( low + high ) / 2 )
        local candidate = trimText( text, mid ) .. ellipsis
        if surface.GetTextSize( candidate ) <= maxWidth then
            low = mid
        else
            high = mid - 1
        end
    end

    return trimText( text, low ) .. ellipsis
end

function style.RefreshFonts()
    local key = math.floor( style.GetMenuScale() * 100 + 0.5 )
    if scaleFontKey == key then return end
    scaleFontKey = key

    surface.CreateFont( "rRadio.Inter4", {
        font = fonts.GetFace( 500 ),
        size = math.max( 10, fonts.ScaleSize( style.Scale( 16 ) ) ),
        weight = 500,
        antialias = true,
        extended = true
    } )

    surface.CreateFont( "rRadio.Inter5", {
        font = fonts.GetFace( 500 ),
        size = math.max( 11, fonts.ScaleSize( style.Scale( 18 ) ) ),
        weight = 500,
        antialias = true,
        extended = true
    } )

    surface.CreateFont( "rRadio.Inter8", {
        font = fonts.GetFace( 700 ),
        size = math.max( 13, fonts.ScaleSize( style.Scale( 26 ) ) ),
        weight = 700,
        antialias = true,
        extended = true
    } )
end

function style.StyleScrollBar( bar )
    style.SetVerticalGripCursor( bar.btnGrip )
    style.SetButtonCursor( bar.btnUp )
    style.SetButtonCursor( bar.btnDown )

    bar.Paint = function( _panel, width, height )
        style.DrawSurface(
            "control",
            8,
            0,
            0,
            width,
            height,
            rRadio.config.UI.ScrollbarColor,
            style.GetBorderColor()
        )
    end
    bar.btnGrip.Paint = function( _panel, width, height )
        style.DrawSurface(
            "button",
            8,
            0,
            0,
            width,
            height,
            rRadio.config.UI.ScrollbarGripColor,
            style.GetBorderColor()
        )
    end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
end

local function refreshPanelTheme( panel, visited )
    if not IsValid( panel ) or visited[panel] then return end
    visited[panel] = true

    local textColor = rRadio.config.UI.TextColor
    if panel.SetTextColor then panel:SetTextColor( textColor ) end
    if panel.SetCursorColor then panel:SetCursorColor( textColor ) end
    if panel.SetPlaceholderColor then panel:SetPlaceholderColor( ColorAlpha( textColor, 150 ) ) end
    if panel.SetHighlightColor then panel:SetHighlightColor( rRadio.config.UI.ButtonHoverColor ) end

    if panel.RefreshThemeColors then
        panel:RefreshThemeColors()
    elseif panel.SetColors then
        panel:SetColors(
            textColor,
            rRadio.config.UI.CloseButtonColor or rRadio.config.UI.ButtonColor,
            rRadio.config.UI.CloseButtonHoverColor or rRadio.config.UI.ButtonHoverColor
        )
    end

    if panel.VBar then style.StyleScrollBar( panel.VBar ) end
    if panel.InvalidateLayout then panel:InvalidateLayout( false ) end

    if panel.GetCanvas then refreshPanelTheme( panel:GetCanvas(), visited ) end
    if not panel.GetChildren then return end

    for _, child in ipairs( panel:GetChildren() ) do
        refreshPanelTheme( child, visited )
    end
end

function style.RefreshPanelTheme( root )
    refreshPanelTheme( root, {} )
end

local function suppressSliderChrome( slider )
    if slider.Label then
        slider.Label:SetVisible( false )
        slider.Label:SetWide( 0 )
    end

    if slider.TextArea then
        slider.TextArea:SetVisible( false )
        slider.TextArea:SetWide( 0 )
    end
end

function style.StyleSlider( slider, trackRatio )
    slider:SetText( "" )
    suppressSliderChrome( slider )

    local baseSliderCursorMoved = slider.Slider.OnCursorMoved
    slider.Slider.OnCursorMoved = function( panel, x, y )
        if baseSliderCursorMoved then baseSliderCursorMoved( panel, x, y ) end
        local bandHalf = panel.Knob:GetTall() * 0.5
        local centerY = panel:GetTall() * 0.5
        panel:SetCursor( math.abs( y - centerY ) <= bandHalf and "hand" or "arrow" )
    end

    local basePerformLayout = slider.PerformLayout
    slider.PerformLayout = function( panel, width, height )
        if basePerformLayout then basePerformLayout( panel, width, height ) end
        suppressSliderChrome( panel )
    end

    slider.Slider.Paint = function( panel, width, height )
        local trackHeight = math.max( style.Scale( 4 ), math.floor( height * ( trackRatio or 0.25 ) ) )
        local y = math.floor( ( height - trackHeight ) / 2 )
        local knobInset = math.floor( panel.Knob:GetWide() * 0.5 )
        local trackWidth = math.max( style.Scale( 10 ), width - knobInset * 2 )
        local progress = math.Clamp( tonumber( panel:GetSlideX() ) or 0, 0, 1 )

        style.DrawSurface(
            "control",
            math.floor( trackHeight / 2 ),
            knobInset,
            y,
            trackWidth,
            trackHeight,
            style.GetSliderTrackColor(),
            ColorAlpha( style.GetBorderColor(), 200 )
        )
        draw.RoundedBox(
            math.floor( trackHeight / 2 ),
            knobInset + 1,
            y + 1,
            math.max( 0, trackWidth * progress - 2 ),
            math.max( 0, trackHeight - 2 ),
            rRadio.config.UI.AccentPrimary
        )
    end

    style.SetHorizontalGripCursor( slider.Slider.Knob )

    slider.Slider.Knob.Paint = function( panel, width, height )
        local active = panel:IsHovered() or panel.Depressed
        local fillColor = active and style.GetKnobHoverColor() or style.GetKnobColor()
        local borderColor = active and ( rRadio.config.UI.AccentPrimary or style.GetKnobBorderColor() )
            or style.GetKnobBorderColor()
        style.DrawSurface(
            "state",
            math.floor( math.min( width, height ) / 2 ),
            0,
            0,
            width,
            height,
            fillColor,
            borderColor
        )
    end
end

function style.SyncSliderKnob( slider, ratio )
    local knobSize = math.max( style.Scale( 12 ), math.floor( slider:GetTall() * ( ratio or 0.55 ) ) )
    if slider.Slider.Knob:GetWide() ~= knobSize or slider.Slider.Knob:GetTall() ~= knobSize then
        slider.Slider.Knob:SetSize( knobSize, knobSize )
    end
end

local scaledFontCache = {}

local function buildScaledFont( prefix, text, buttonWidth, buttonHeight )
    local key = prefix .. "_" .. text .. "_" .. math.floor( buttonHeight )
    if scaledFontCache[key] then return scaledFontCache[key] end

    local fontName = "rRadio.Scaled_" .. key
    local size = math.max( 10, fonts.ScaleSize( math.floor( buttonHeight * 0.7 ) ) )
    surface.CreateFont( fontName, {
        font = fonts.GetFace( 700 ),
        size = size,
        weight = 700,
        antialias = true,
        extended = true
    } )

    surface.SetFont( fontName )
    local textWidth = surface.GetTextSize( text )
    while textWidth > buttonWidth * 0.9 and size > 10 do
        size = size - 1
        surface.CreateFont( fontName, {
            font = fonts.GetFace( 700 ),
            size = size,
            weight = 700,
            antialias = true,
            extended = true
        } )

        surface.SetFont( fontName )
        textWidth = surface.GetTextSize( text )
    end

    scaledFontCache[key] = fontName
    return fontName
end

function style.GetButtonFillFont( text, buttonWidth, buttonHeight )
    return buildScaledFont( "Fill", text, buttonWidth, buttonHeight )
end

function style.ClearScaledFontCache()
    scaledFontCache = {}
end

hook.Add( "rRadio_LanguageChanged", "rRadio_UI_ClearScaledFontCache", style.ClearScaledFontCache )

cvars.AddChangeCallback( "rammel_rradio_menu_soft_borders", function( _name, _oldValue, newValue )
    hook.Run( "rRadio_SoftUIChanged", tobool( newValue ) )
end, "rRadio_UI_SoftUIChanged" )

function style.PlaySound( soundName )
    if not rRadio.config.EnableSoundEffects then return end
    local soundPath = rRadio.config.Sounds[soundName]
    if not soundPath then return end

    surface.PlaySound( soundPath )
end

function style.GetVolumeIcon( volume )
    volume = math.Clamp( tonumber( volume ) or 0, 0, rRadio.config.MaxVolume or 1 )
    if volume < 0.01 then return style.Materials.volumeMute end
    if volume <= 0.65 then return style.Materials.volumeDown end

    return style.Materials.volumeUp
end

style.SyncScaleFromConVars()
style.RefreshFonts()

return style
