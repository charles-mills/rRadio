rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.components = rRadio.client.ui.components or {}

local style = rRadio.client.ui.style
local PLAYBACK_RAIL_MIN_WIDTH = 2
local PLAYBACK_RAIL_WIDTH = 3
local PLAYBACK_RAIL_PADDING = 12
local PLAYBACK_RAIL_RIGHT_INSET = 7
local PLAYBACK_TEXT_GUTTER = 24
-- Star PNGs are 64px with 54px of visible alpha; size the max animation inside clipping.
local STAR_TEXTURE_SIZE = 64
local STAR_VISIBLE_WIDTH = 54
local STAR_HOVER_SCALE = 0.12
local STAR_CLICK_SCALE = 0.18
local STAR_MAX_SCALE = 1 + STAR_HOVER_SCALE + STAR_CLICK_SCALE
local STAR_DRAW_SCALE = STAR_TEXTURE_SIZE / ( STAR_VISIBLE_WIDTH * STAR_MAX_SCALE )

do
    local PANEL = {}

    function PANEL:Init()
        self.label = ""
        self.leftChild = nil
        self.active = false
        self.error = false
        self.keyboardSelected = false
        self.playbackState = nil
        self.lerp = 0
        self.bgColor = Color( 0, 0, 0, 255 )
        self.borderColor = Color( 0, 0, 0, 255 )
        self:SetText( "" )
        self:SetFont( "rRadio.Inter5" )
        self:SetTextColor( rRadio.config.UI.TextColor )
        self:SetTall( style.Scale( 40 ) )
        style.SetButtonCursor( self )
    end

    function PANEL:SetTextLabel( label )
        label = tostring( label or "" )
        if self.label == label then return end

        self.label = label
        self.cachedLabel = nil
    end

    function PANEL:SetLeftChild( panel )
        self.leftChild = panel
    end

    function PANEL:SetActive( active )
        self.active = active and true or false
    end

    function PANEL:SetError( errorState )
        self.error = errorState and true or false
    end

    function PANEL:SetPlaybackState( playbackState )
        self.playbackState = playbackState
    end

    function PANEL:SetKeyboardSelected( selected )
        self.keyboardSelected = selected and true or false
    end

    function PANEL:Think()
        local target = ( self:IsHovered() or self.keyboardSelected ) and not self.active and 1 or 0
        self.lerp = style.ApproachLerp( self.lerp, target, 10 )
    end

    function PANEL:GetPlaybackRailAlpha()
        if self.playbackState == "error" then return 170 + 85 * ( math.sin( CurTime() * 7 ) * 0.5 + 0.5 ) end
        if self.playbackState == "queued" then
            return 110 + 70 * ( math.sin( CurTime() * 2.5 ) * 0.5 + 0.5 )
        end

        if self.playbackState == "pending" or self.playbackState == "tuning" then
            return 130 + 100 * ( math.sin( CurTime() * 5 ) * 0.5 + 0.5 )
        end

        return 255
    end

    function PANEL:PaintPlaybackRail( width, height )
        local railColor = style.GetPlaybackStateColor( self.playbackState )
        if not railColor then return end

        local railWidth = math.max( PLAYBACK_RAIL_MIN_WIDTH, style.Scale( PLAYBACK_RAIL_WIDTH ) )
        local railHeight = math.max( railWidth, height - style.Scale( PLAYBACK_RAIL_PADDING ) )
        local railX = width - style.Scale( PLAYBACK_RAIL_RIGHT_INSET )
        local railY = math.floor( ( height - railHeight ) * 0.5 )
        local alpha = math.floor( self:GetPlaybackRailAlpha() )

        draw.RoundedBox(
            math.floor( railWidth * 0.5 ),
            railX,
            railY,
            railWidth,
            railHeight,
            ColorAlpha( railColor, alpha )
        )
    end

    function PANEL:Paint( width, height )
        local baseColor = self.active and rRadio.config.UI.PlayingButtonColor or style.GetSurfaceColor( "card" )
        local hoverColor = style.GetSurfaceColor( "cardHover" ) or rRadio.config.UI.ButtonHoverColor
        local fillColor = self.active and baseColor or style.LerpColor( self.lerp, baseColor, hoverColor, self.bgColor )
        local borderColor = style.GetBorderColor()
        local role = self.active and "state" or "button"

        if self.error then
            role = "state"
            local pulse = math.sin( CurTime() * 6 ) * 0.5 + 0.5
            fillColor = style.LerpColor( pulse, fillColor, rRadio.config.UI.Error, self.bgColor )
            borderColor = style.LerpColor( pulse, borderColor, rRadio.config.UI.Error, self.borderColor )
        elseif self.keyboardSelected then
            borderColor = rRadio.config.UI.AccentPrimary or borderColor
        elseif self.active and style.IsSoftUIEnabled() then
            borderColor = rRadio.config.UI.AccentPrimary or borderColor
        elseif self.lerp > 0.001 then
            borderColor = style.LerpColor( self.lerp, borderColor, hoverColor, self.borderColor )
        end

        style.DrawSurface( role, 8, 0, 0, width, height, fillColor, borderColor )
        self:PaintPlaybackRail( width, height )

        local leftPad = style.Scale( 8 )
        if IsValid( self.leftChild ) then leftPad = self.leftChild:GetWide() + style.Scale( 16 ) end

        local rightPad = self.playbackState and style.Scale( PLAYBACK_TEXT_GUTTER ) or style.Scale( 8 )
        local maxTextWidth = math.max( 0, width - leftPad - rightPad )
        if self.cachedLabel ~= self.label or self.cachedWidth ~= maxTextWidth then
            self.cachedText = style.TruncateText( self.label, "rRadio.Inter5", maxTextWidth )
            surface.SetFont( "rRadio.Inter5" )
            self.cachedTextWidth = surface.GetTextSize( self.cachedText )
            self.cachedLabel = self.label
            self.cachedWidth = maxTextWidth
        end

        local textX = math.Clamp(
            width * 0.5,
            leftPad + self.cachedTextWidth * 0.5,
            width - rightPad - self.cachedTextWidth * 0.5
        )
        draw.SimpleText(
            self.cachedText,
            "rRadio.Inter5",
            textX,
            height * 0.5,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    vgui.Register( "rRadioMenuButton", PANEL, "DButton" )
end

do
    local PANEL = {}

    function PANEL:Init()
        self.icon = nil
        self.callback = nil
        self.lerp = 0
        self.iconColor = Color( 0, 0, 0, 255 )
        self:SetText( "" )
        self:SetSize( style.Scale( 25 ), style.Scale( 25 ) )
        self:NoClipping( true )
        style.SetButtonCursor( self )
    end

    function PANEL:SetIcon( icon )
        self.icon = icon
    end

    function PANEL:SetCallback( callback )
        self.callback = callback
    end

    function PANEL:Think()
        self.lerp = style.ApproachLerp( self.lerp, self:IsHovered() and 1 or 0, 8 )
    end

    function PANEL:DoClick()
        style.PlaySound( "MenuClosed" )
        if type( self.callback ) == "function" then self.callback() end
    end

    function PANEL:Paint( width, height )
        if not self.icon then return end

        local iconColor = style.LerpColor(
            self.lerp,
            rRadio.config.UI.TextColor,
            rRadio.config.UI.AccentPrimary,
            self.iconColor
        )

        surface.SetMaterial( self.icon )
        surface.SetDrawColor( iconColor )
        surface.DrawTexturedRect( 0, 0, width, height )
    end

    vgui.Register( "rRadioMenuNavButton", PANEL, "DButton" )
end

do
    local PANEL = {}

    function PANEL:Init()
        self.icon = nil
        self:SetSize( style.Scale( 24 ), style.Scale( 24 ) )
        self:SetMouseInputEnabled( false )
    end

    function PANEL:SetIcon( icon )
        self.icon = icon
    end

    function PANEL:Paint( width, height )
        if not self.icon then return end

        surface.SetMaterial( self.icon )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        surface.DrawTexturedRect( 0, 0, width, height )
    end

    vgui.Register( "rRadioMenuRowIcon", PANEL, "DPanel" )
end

do
    local PANEL = {}

    function PANEL:Init()
        self.isFavourite = function()
            return false
        end
        self.onToggle = nil
        self.hoverLerp = 0
        self.clickLerp = 0
        self.tintColor = Color( 255, 255, 255, 255 )
        self:SetText( "" )
        self:SetSize( style.Scale( 24 ), style.Scale( 24 ) )
        self:SetMouseInputEnabled( true )
        self:NoClipping( false )
        style.SetButtonCursor( self )
    end

    function PANEL:SetFavouriteGetter( getter )
        self.isFavourite = getter
    end

    function PANEL:SetToggleCallback( callback )
        self.onToggle = callback
    end

    function PANEL:Think()
        self.hoverLerp = style.ApproachLerp( self.hoverLerp, self:IsHovered() and 1 or 0, 12 )
        self.clickLerp = style.ApproachLerp( self.clickLerp, 0, 6 )
    end

    function PANEL:Paint( width, height )
        local favourited = self.isFavourite()
        local hover = self.hoverLerp
        local colors = rRadio.config.UI
        local accent = colors.AccentPrimary or colors.Highlight or colors.TextColor
        local base = colors.TextColor

        local scale = 1 + STAR_HOVER_SCALE * hover + STAR_CLICK_SCALE * self.clickLerp
        local cx, cy = width * 0.5, height * 0.5
        local drawSize = math.min( width, height ) * STAR_DRAW_SCALE * scale
        local drawW, drawH = drawSize, drawSize

        style.LerpColor( hover, base, accent, self.tintColor )
        local r, g, b, a = self.tintColor.r, self.tintColor.g, self.tintColor.b, self.tintColor.a

        if favourited then
            surface.SetMaterial( style.Materials.starFull )
            surface.SetDrawColor( r, g, b, a )
            surface.DrawTexturedRectRotated( cx, cy, drawW, drawH, 0 )
        else
            -- Crossfade empty -> full while hovered, so hovering previews the favourited state.
            if hover < 1 then
                surface.SetMaterial( style.Materials.star )
                surface.SetDrawColor( r, g, b, a * ( 1 - hover ) )
                surface.DrawTexturedRectRotated( cx, cy, drawW, drawH, 0 )
            end
            if hover > 0 then
                surface.SetMaterial( style.Materials.starFull )
                surface.SetDrawColor( r, g, b, a * hover )
                surface.DrawTexturedRectRotated( cx, cy, drawW, drawH, 0 )
            end
        end
    end

    function PANEL:DoClick()
        style.PlaySound( "ButtonPressSecondary" )
        self.clickLerp = 1
        if type( self.onToggle ) == "function" then self.onToggle() end
    end

    vgui.Register( "rRadioMenuStar", PANEL, "DImageButton" )
end

do
    local PANEL = {}

    local function resolveColors( role )
        local colors = rRadio.config.UI
        local textColor = colors.TextColor

        if role == "footerSurface" then
            return textColor,
                style.GetFooterSurfaceColor(),
                style.GetFooterSurfaceHoverColor()
        end

        if role == "action" then
            return textColor,
                style.GetSurfaceColor( "controlHover" ) or style.GetSurfaceColor( "control" ) or colors.ButtonColor,
                colors.AccentSecondary or colors.AccentPrimary or style.GetSurfaceColor( "controlHover" )
        end

        return textColor,
            colors.CloseButtonColor or colors.ButtonColor,
            colors.CloseButtonHoverColor or colors.ButtonHoverColor
    end

    function PANEL:Init()
        self.colorRole = "close"
        self.baseColor = rRadio.config.UI.CloseButtonColor
        self.hoverColor = rRadio.config.UI.CloseButtonHoverColor
        self.lerp = 0
        self.lerpColor = Color( 0, 0, 0, 255 )
        self.borderLerpColor = Color( 0, 0, 0, 255 )
        self:SetFont( "rRadio.Inter5" )
        self:SetTextColor( rRadio.config.UI.TextColor )
        style.SetButtonCursor( self )
        self:RefreshThemeColors()
    end

    function PANEL:SetColors( textColor, baseColor, hoverColor, borderColor )
        if textColor then self:SetTextColor( textColor ) end
        if baseColor then self.baseColor = baseColor end
        if hoverColor then self.hoverColor = hoverColor end
        self.borderColor = borderColor
    end

    function PANEL:SetColorRole( role )
        self.colorRole = role or "close"
        self:RefreshThemeColors()
    end

    function PANEL:RefreshThemeColors()
        self:SetColors( resolveColors( self.colorRole ) )
    end

    function PANEL:Think()
        self.lerp = style.ApproachLerp( self.lerp, self:IsHovered() and 1 or 0, 10 )
    end

    function PANEL:Paint( width, height )
        local fillColor = style.LerpColor( self.lerp, self.baseColor, self.hoverColor, self.lerpColor )
        local borderColor = self.borderColor or style.GetBorderColor()
        if self.lerp > 0.001 and not self.borderColor then
            borderColor = style.LerpColor( self.lerp, borderColor, self.hoverColor, self.borderLerpColor )
        end

        style.DrawSurface( "button", 8, 0, 0, width, height, fillColor, borderColor )
    end

    vgui.Register( "rRadioMenuAnimatedButton", PANEL, "DButton" )
end

do
    local PANEL = {}

    function PANEL:Init()
        self:SetMouseInputEnabled( false )
        self:SetTall( style.Scale( 2 ) )
    end

    function PANEL:Paint( width, height )
        local dividerColor = style.GetChromeBorderColor( "divider", style.GetDividerColor() )
        if not dividerColor then return end

        surface.SetDrawColor( dividerColor )
        surface.DrawRect( 0, 0, width, height )
    end

    vgui.Register( "rRadioMenuSeparator", PANEL, "DPanel" )
end

do
    local PANEL = {}

    function PANEL:Init()
        self.label = ""
        self.first = false
        self:SetMouseInputEnabled( false )
        self:SetTall( style.Scale( 26 ) )
    end

    function PANEL:SetTextLabel( label )
        label = tostring( label or "" )
        if self.label == label then return end

        self.label = label
    end

    function PANEL:SetIsFirst( first )
        self.first = first and true or false
    end

    function PANEL:Paint( width, height )
        local x = style.Scale( 4 )
        local y = height * 0.5
        draw.SimpleText(
            self.label,
            "rRadio.Inter5",
            x,
            y,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        surface.SetFont( "rRadio.Inter5" )
        local textWidth = surface.GetTextSize( self.label )
        local dividerX = x + textWidth + style.Scale( 10 )
        local dividerWidth = width - dividerX - style.Scale( 4 )
        if dividerWidth <= 0 then return end

        local dividerColor = style.GetChromeBorderColor( "divider", style.GetDividerColor() )
            or ColorAlpha( rRadio.config.UI.TextColor, 45 )

        surface.SetDrawColor( dividerColor )
        surface.DrawRect( dividerX, math.floor( y ), dividerWidth, 1 )
    end

    vgui.Register( "rRadioMenuHeader", PANEL, "DPanel" )
end

return rRadio.client.ui.components
