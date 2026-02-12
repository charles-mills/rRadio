do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    function PANEL:Init()
        self.label = ""
        self.leftChild = nil
        self.playing = false
        self.hoverColour = rRadio.interface.GetSurfaceColor( "card_hover" ) or rRadio.config.UI.ButtonHoverColor
        self.lerp = 0
        self:SetTall( Scale( 40 ) )
        self:SetText( "" )
        self:Dock( TOP )
        self:DockMargin( Scale( 5 ), Scale( 5 ), Scale( 5 ), 0 )
    end

    function PANEL:SetTextLabel( t )
        self.label = t or ""
    end

    function PANEL:SetLeftChild( p )
        self.leftChild = p
    end

    function PANEL:SetPlaying( b )
        self.playing = b and true or false
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and not self.playing and 1 or 0
        self.lerp = rRadio.interface.ApproachLerp( self.lerp, tgt, 10 )
    end

    function PANEL:Paint( w, h )
        local base = self.playing and rRadio.config.UI.PlayingButtonColor
            or rRadio.interface.GetSurfaceColor( "card" )
            or rRadio.config.UI.ButtonColor
        local bg = self.playing and base
            or rRadio.interface.LerpColor( self.lerp, base, self.hoverColour )
        local border = rRadio.interface.GetControlBorderColor
            and rRadio.interface.GetControlBorderColor()
            or rRadio.config.UI.Border
        if self.errorFlash then
            local pulse = math.sin( CurTime() * 6 ) * 0.5 + 0.5
            bg = rRadio.interface.LerpColor( pulse, bg, rRadio.config.UI.Error or Color( 248, 81, 73 ) )
            border = rRadio.interface.LerpColor(
                pulse,
                border,
                rRadio.config.UI.Error or Color( 248, 81, 73 )
            )
        elseif not self.playing and self.lerp > 0.001 then
            border = rRadio.interface.LerpColor( self.lerp, border, self.hoverColour )
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
        surface.SetFont( "rRadio.Roboto5" )
        local leftPad = self.leftChild and self.leftChild:GetWide() + Scale( 16 ) or Scale( 8 )
        local rightPad = Scale( 8 )
        local avail = w - leftPad - rightPad
        local txt = rRadio.interface.TruncateText( self.label, "rRadio.Roboto5", avail )
        local tw = surface.GetTextSize( txt )
        local x = math.Clamp( w * 0.5, leftPad + tw * 0.5, w - rightPad - tw * 0.5 )
        draw.SimpleText(
            txt, "rRadio.Roboto5", x, h / 2,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    vgui.Register( "rRadioButton", PANEL, "DButton" )
end
