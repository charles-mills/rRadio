do
    local PANEL = {}
    local Scale = rRadio.interface.scaleMenu
    local TEXT_FONT = "rRadio.Roboto5"
    local function getScaleKey()
        return math.floor( rRadio.interface.GetMenuScale() * 100 + 0.5 )
    end

    local function getOptionHeight()
        return math.max( Scale( 32 ), 26 )
    end

    local function paintArrow( dropdown, w, h )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        local arrowSize = Scale( 8 )
        local x, y = w - arrowSize - Scale( 5 ), h / 2 - arrowSize / 2
        draw.NoTexture()
        surface.DrawPoly( dropdown:IsMenuOpen() and {
            {
                x = x,
                y = y + arrowSize
            },
            {
                x = x + arrowSize,
                y = y + arrowSize
            },
            {
                x = x + arrowSize / 2,
                y = y
            }
        } or {
            {
                x = x,
                y = y
            },
            {
                x = x + arrowSize,
                y = y
            },
            {
                x = x + arrowSize / 2,
                y = y + arrowSize
            }
        } )
    end

    local function styleOption( option, index, count )
        option:SetTextColor( rRadio.config.UI.TextColor )
        option:SetFont( TEXT_FONT )
        local textInset = math.max( Scale( 10 ), 8 )
        local rowHeight = getOptionHeight()
        option:SetTall( rowHeight )
        if option.SetTextInset then option:SetTextInset( textInset, 0 ) end
        local basePerformLayout = option.PerformLayout
        option.PerformLayout = function( pnl, w, h )
            if basePerformLayout then basePerformLayout( pnl, w, h ) end
            if pnl:GetTall() ~= rowHeight then pnl:SetTall( rowHeight ) end
            if pnl.SetTextInset then pnl:SetTextInset( textInset, 0 ) end
        end

        option.Paint = function( pnl, pw, ph )
            local pad = math.max( 1, math.floor( Scale( 2 ) ) )
            local padY = math.max( 2, math.floor( Scale( 2 ) ) )
            local radius = math.max( 2, math.floor( Scale( 4 ) ) )
            if pnl:IsHovered() then
                draw.RoundedBox(
                    radius, pad, padY,
                    pw - pad * 2, ph - padY * 2,
                    rRadio.interface.GetSurfaceColor( "card_hover" )
                        or rRadio.config.UI.ButtonHoverColor
                )
            end

            if index < count then
                local dividerColor = ColorAlpha(
                    rRadio.config.UI.Border
                    or rRadio.config.UI.ScrollbarGripColor
                    or rRadio.config.UI.TextColor, 190
                )

                local dividerInset = math.max(
                    math.floor( Scale( 8 ) ), pad + 1
                )

                surface.SetDrawColor( dividerColor )
                surface.DrawRect(
                    dividerInset, ph - 1,
                    math.max( 1, pw - dividerInset * 2 ), 1
                )
            end
        end
    end

    function PANEL:ApplyScaleLayout()
        self:SetTall( Scale( 50 ) )
        self:DockMargin( 0, 0, 0, Scale( 5 ) )
        if IsValid( self.label ) then
            self.label:DockMargin( Scale( 10 ), 0, 0, 0 )
            self.label:SetFont( TEXT_FONT )
            self.label:SizeToContents()
        end

        if IsValid( self.dropdown ) then
            self.dropdown:SetWide( Scale( 150 ) )
            self.dropdown:DockMargin( 0, Scale( 5 ), Scale( 10 ), Scale( 5 ) )
            self.dropdown:SetFont( TEXT_FONT )
        end
    end

    function PANEL:Init()
        self:Dock( TOP )
        self._lastScaleKey = getScaleKey()
        self.label = vgui.Create( "DLabel", self )
        self.label:Dock( LEFT )
        self.label:SetFont( TEXT_FONT )
        self.label:SetTextColor( rRadio.config.UI.TextColor )
        self.label:SetContentAlignment( 4 )
        self.dropdown = vgui.Create( "DComboBox", self )
        self.dropdown:Dock( RIGHT )
        self.dropdown:SetTextColor( rRadio.config.UI.TextColor )
        self.dropdown:SetFont( TEXT_FONT )
        self.dropdown:SetSortItems( false )
        if self.dropdown.DropButton then
            self.dropdown.DropButton.Paint = function() end
        end

        function self.dropdown:Paint( w, h )
            rRadio.interface.DrawBorderedRoundedBox(
                6,
                0, 0, w, h,
                rRadio.interface.GetSurfaceColor( "panel" )
                    or rRadio.config.UI.SearchBoxColor
            )
            paintArrow( self, w, h )
            self:DrawTextEntryText(
                rRadio.config.UI.TextColor,
                rRadio.config.UI.ButtonHoverColor,
                rRadio.config.UI.TextColor
            )
        end

        function self.dropdown:OpenMenu()
            local parent = self:GetParent()
            if IsValid( self.Menu ) then
                self.Menu:Remove()
                self.Menu = nil
            end

            local menu = DermaMenu()
            self.Menu = menu
            menu:SetMaxHeight( Scale( 200 ) )
            menu.Paint = function( _, mw, mh )
                rRadio.interface.DrawBorderedRoundedBox(
                    6,
                    0, 0, mw, mh,
                    rRadio.interface.GetSurfaceColor( "panel" )
                        or rRadio.config.UI.SearchBoxColor
                )
            end

            if parent.onOpen then parent.onOpen() end
            local choices = parent.choices or {}
            local choiceCount = #choices
            for index, choice in ipairs( choices ) do
                local option = menu:AddOption( choice.name, function()
                    self:ChooseOption( choice.name, choice.data )
                    if parent.onSelect then
                        parent.onSelect(
                            self, nil, choice.name, choice.data
                        )
                    end
                end )

                styleOption( option, index, choiceCount )
                option.OnCursorEntered = function()
                    if parent.onHover then
                        parent.onHover( choice.data )
                    end
                end
            end

            local x, y = self:LocalToScreen( 0, self:GetTall() )
            menu:SetMinimumWidth( self:GetWide() )
            menu:Open( x, y, false, self )
            menu.OnRemove = function()
                if parent.onClose then parent.onClose() end
            end

            if IsValid( menu.VBar ) then
                rRadio.interface.StyleVBar( menu.VBar )
            end
        end

        self:ApplyScaleLayout()
    end

    function PANEL:Think()
        local scaleKey = getScaleKey()
        if self._lastScaleKey == scaleKey then return end
        self._lastScaleKey = scaleKey
        self:ApplyScaleLayout()
    end

    function PANEL:SetData( text, choices, current, onSelect, onHover, onOpen, onClose )
        self.choices = choices or {}
        self.onSelect = onSelect
        self.onHover = onHover
        self.onOpen = onOpen
        self.onClose = onClose
        self.label:SetText( text or "" )
        self.label:SizeToContents()
        self.dropdown:Clear()
        for _, choice in ipairs( self.choices ) do
            self.dropdown:AddChoice( choice.name, choice.data )
        end

        if current then self.dropdown:SetValue( current ) end
    end

    function PANEL:Paint( w, h )
        rRadio.interface.DrawBorderedRoundedBox(
            8,
            0, 0, w, h,
            rRadio.interface.GetSurfaceColor( "card" )
                or rRadio.config.UI.ButtonColor
        )
    end

    vgui.Register( "rRadioDropdown", PANEL, "DPanel" )
end
