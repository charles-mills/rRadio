do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    local HOVER_SPEED = 5
    function PANEL:Init()
        self.iconMaterial = nil
        self.callback = nil
        self.lerp = 0
        self.baseColour = Color( 0, 0, 0, 0 )
        self.hoverColour = rRadio.config.UI.ButtonHoverColor
        self:SetSize( Scale( 25 ), Scale( 25 ) )
        self:SetText( "" )
    end

    function PANEL:SetIcon( path )
        self.iconMaterial = Material( path )
    end

    function PANEL:SetCallback( fn )
        self.callback = fn
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and 1 or 0
        self.lerp = rRadio.interface.ApproachLerp(
            self.lerp, tgt, HOVER_SPEED
        )
    end

    function PANEL:DoClick()
        if isfunction( self.callback ) then self.callback() end
    end

    function PANEL:Paint( w, h )
        local c = rRadio.interface.LerpColor( self.lerp, self.baseColour, self.hoverColour )
        draw.RoundedBox( 8, 0, 0, w, h, c )
        if self.iconMaterial then
            surface.SetMaterial( self.iconMaterial )
            surface.SetDrawColor( ColorAlpha( rRadio.config.UI.TextColor, 255 * ( 0.5 + 0.5 * self.lerp ) ) )
            surface.DrawTexturedRect( 0, 0, w, h )
        end
    end

    vgui.Register( "rRadioNavButton", PANEL, "DButton" )
end
