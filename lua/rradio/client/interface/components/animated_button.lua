do
    local PANEL = {}
    local HOVER_SPEED = 10
    function PANEL:Init()
        self:SetText( "" )
        self:SetFont( "rRadio.Roboto5" )
        self.baseColor = rRadio.config.UI.ButtonColor
        self.hoverColor = rRadio.config.UI.ButtonHoverColor
        self.lerp = 0
    end

    function PANEL:SetColors( text, base, hover )
        if text then self:SetTextColor( text ) end
        if base then self.baseColor = base end
        if hover then self.hoverColor = hover end
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and 1 or 0
        self.lerp = rRadio.interface.ApproachLerp(
            self.lerp, tgt, HOVER_SPEED
        )
    end

    function PANEL:Paint( w, h )
        local col = rRadio.interface.LerpColor( self.lerp, self.baseColor, self.hoverColor )
        rRadio.interface.DrawBorderedRoundedBox(
            rRadio.interface.GetControlCornerRadius(),
            0, 0, w, h, col
        )
    end

    vgui.Register( "rRadioAnimatedButton", PANEL, "DButton" )
end
