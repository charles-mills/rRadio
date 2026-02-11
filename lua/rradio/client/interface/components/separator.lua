do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    function PANEL:Init()
        self:Dock( TOP )
        self:DockMargin( Scale( 5 ), Scale( 5 ), Scale( 5 ), Scale( 5 ) )
        self:SetTall( Scale( 2 ) )
        self:SetMouseInputEnabled( false )
    end

    function PANEL:Paint( w, h )
        draw.RoundedBox( 0, 0, 0, w, h, rRadio.config.UI.ButtonColor )
    end

    vgui.Register( "rRadioSeparator", PANEL, "DPanel" )
end
