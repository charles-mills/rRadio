do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    function PANEL:Init()
        self.label = ""
        self.leftChild = nil
        self.playing = false
        self.hoverColour = rRadio.interface.GetSurfaceColor( "card_hover" ) or rRadio.config.UI.ButtonHoverColor
        self.lerp = 0
        self.bgLerpColor = Color( 0, 0, 0, 255 )
        self.borderLerpColor = Color( 0, 0, 0, 255 )
        self.errorBgLerpColor = Color( 0, 0, 0, 255 )
        self.errorBorderLerpColor = Color( 0, 0, 0, 255 )
        self:SetTall( Scale( 40 ) )
        self:SetText( "" )
        self:Dock( TOP )
        self:DockMargin( Scale( 5 ), Scale( 5 ), Scale( 5 ), 0 )
        self.cachedTruncateLabel = nil
        self.cachedTruncateAvail = nil
        self.cachedTruncateText = ""
        self.cachedTruncateWidth = 0
        self.enableViewportPaintCulling = false
        self.viewportCullParent = nil
    end

    function PANEL:SetTextLabel( t )
        self.label = t or ""
        self.cachedTruncateLabel = nil
    end

    function PANEL:SetLeftChild( p )
        self.leftChild = p
    end

    function PANEL:SetPlaying( b )
        self.playing = b and true or false
    end

    function PANEL:SetViewportPaintCulling( enabled, viewportPanel )
        self.enableViewportPaintCulling = enabled and true or false
        self.viewportCullParent = IsValid( viewportPanel ) and viewportPanel or nil
    end

    local function shouldSkipPaintForViewport( self )
        if not self.enableViewportPaintCulling then return false end
        local viewport = self.viewportCullParent
        if not IsValid( viewport ) then return false end
        local _, sy = self:LocalToScreen( 0, 0 )
        local _, vy = viewport:LocalToScreen( 0, 0 )
        local bottom = sy + self:GetTall()
        local viewBottom = vy + viewport:GetTall()
        return bottom < vy or sy > viewBottom
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and not self.playing and 1 or 0
        self.lerp = rRadio.interface.ApproachLerp( self.lerp, tgt, 10 )
    end

    function PANEL:Paint( w, h )
        if shouldSkipPaintForViewport( self ) then return end
        local base = self.playing and rRadio.config.UI.PlayingButtonColor
            or rRadio.interface.GetSurfaceColor( "card" )
            or rRadio.config.UI.ButtonColor
        local bg = self.playing and base
            or rRadio.interface.LerpColor( self.lerp, base, self.hoverColour, self.bgLerpColor )
        local border = rRadio.interface.GetControlBorderColor
            and rRadio.interface.GetControlBorderColor()
            or rRadio.config.UI.Border
        if self.errorFlash then
            local pulse = math.sin( CurTime() * 6 ) * 0.5 + 0.5
            bg = rRadio.interface.LerpColor(
                pulse,
                bg,
                rRadio.config.UI.Error or Color( 248, 81, 73 ),
                self.errorBgLerpColor
            )
            border = rRadio.interface.LerpColor(
                pulse,
                border,
                rRadio.config.UI.Error or Color( 248, 81, 73 ),
                self.errorBorderLerpColor
            )
        elseif not self.playing and self.lerp > 0.001 then
            border = rRadio.interface.LerpColor( self.lerp, border, self.hoverColour, self.borderLerpColor )
        end

        rRadio.interface.DrawBorderedRoundedBox(
            rRadio.interface.GetControlCornerRadius(),
            0, 0, w, h, bg, border
        )
        if not self.playing and self.lerp > 0.001 then
            local radius = rRadio.interface.GetControlCornerRadius
                and rRadio.interface.GetControlCornerRadius()
                or 8
            local overlay = ColorAlpha(
                rRadio.config.UI.Highlight or self.hoverColour,
                math.floor( 28 * self.lerp )
            )
            draw.RoundedBox(
                math.max( 0, radius - 1 ),
                1,
                1,
                math.max( 0, w - 2 ),
                math.max( 0, h - 2 ),
                overlay
            )
        end
        local leftPad = self.leftChild and self.leftChild:GetWide() + Scale( 16 ) or Scale( 8 )
        local rightPad = Scale( 8 )
        local avail = math.max( 0, math.floor( w - leftPad - rightPad + 0.5 ) )
        local txt
        local tw
        if self.cachedTruncateLabel ~= self.label or self.cachedTruncateAvail ~= avail then
            txt = rRadio.interface.TruncateText( self.label, "rRadio.Roboto5", avail )
            surface.SetFont( "rRadio.Roboto5" )
            tw = surface.GetTextSize( txt )
            self.cachedTruncateLabel = self.label
            self.cachedTruncateAvail = avail
            self.cachedTruncateText = txt
            self.cachedTruncateWidth = tw
        else
            txt = self.cachedTruncateText
            tw = self.cachedTruncateWidth
        end
        local x = math.Clamp( w * 0.5, leftPad + tw * 0.5, w - rightPad - tw * 0.5 )
        draw.SimpleText(
            txt, "rRadio.Roboto5", x, h / 2,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    vgui.Register( "rRadioButton", PANEL, "DButton" )
end
