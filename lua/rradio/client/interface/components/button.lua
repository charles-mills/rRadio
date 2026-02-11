do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    function PANEL:Init()
        self.label = ""
        self.leftChild = nil
        self.playing = false
        self.hoverColour = rRadio.config.UI.ButtonHoverColor
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

    function PANEL:SetHoverColour( c )
        if c then self.hoverColour = c end
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and not self.playing and 1 or 0
        self.lerp = math.Approach( self.lerp, tgt, FrameTime() * 10 )
    end

    function PANEL:Paint( w, h )
        local base = self.playing and rRadio.config.UI.PlayingButtonColor or rRadio.config.UI.ButtonColor
        local bg = self.playing and base or rRadio.interface.LerpColor( self.lerp, base, self.hoverColour )
        if self.errorFlash then
            local pulse = math.sin( CurTime() * 6 ) * 0.5 + 0.5
            bg = rRadio.interface.LerpColor( pulse, bg, rRadio.config.UI.Error or Color( 248, 81, 73 ) )
        end

        draw.RoundedBox( 8, 0, 0, w, h, bg )
        surface.SetFont( "rRadio.Roboto5" )
        local leftPad = self.leftChild and self.leftChild:GetWide() + Scale( 16 ) or Scale( 8 )
        local rightPad = Scale( 8 )
        local avail = w - leftPad - rightPad
        local txt = rRadio.interface.TruncateText( self.label, "rRadio.Roboto5", avail )
        local tw = surface.GetTextSize( txt )
        local x = math.Clamp( w * 0.5, leftPad + tw * 0.5, w - rightPad - tw * 0.5 )
        draw.SimpleText( txt, "rRadio.Roboto5", x, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end

    vgui.Register( "rRadioButton", PANEL, "DButton" )
end
