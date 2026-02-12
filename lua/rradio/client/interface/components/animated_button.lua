do
    local PANEL = {}
    local HOVER_SPEED = 10
    local function paintButtonFrame( w, h, fillColor )
        if rRadio.interface.DrawBorderedRoundedBox then
            rRadio.interface.DrawBorderedRoundedBox(
                rRadio.interface.GetControlCornerRadius(),
                0, 0, w, h, fillColor
            )
            return
        end

        draw.RoundedBox( 8, 0, 0, w, h, fillColor )
    end
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
        self.lerp = math.Approach( self.lerp, tgt, FrameTime() * HOVER_SPEED )
    end

    function PANEL:Paint( w, h )
        local col = rRadio.interface.LerpColor( self.lerp, self.baseColor, self.hoverColor )
        paintButtonFrame( w, h, col )
    end

    vgui.Register( "rRadioAnimatedButton", PANEL, "DButton" )
end
