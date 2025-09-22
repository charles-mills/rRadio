do
    local PANEL = {}
    local Scale = rRadio.interface.scale

    function PANEL:Init()
        self:SetTall(Scale(50))
        self:Dock(TOP)
        self:DockMargin(0, 0, 0, Scale(5))

        self.label = vgui.Create("DLabel", self)
        self.label:Dock(LEFT)
        self.label:DockMargin(Scale(10), 0, 0, 0)
        self.label:SetFont("rRadio.Roboto5")
        self.label:SetTextColor(rRadio.config.UI.TextColor)
        self.label:SetContentAlignment(4)

        self.dropdown = vgui.Create("DComboBox", self)
        self.dropdown:Dock(RIGHT)
        self.dropdown:SetWide(Scale(150))
        self.dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        self.dropdown:SetTextColor(rRadio.config.UI.TextColor)
        self.dropdown:SetFont("rRadio.Roboto5")
        self.dropdown:SetSortItems(false)

        if self.dropdown.DropButton then
            self.dropdown.DropButton.Paint = function() end
        end

        function self.dropdown:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)

            surface.SetDrawColor(rRadio.config.UI.TextColor)
            local arrowSize = Scale(8)
            local x = w - arrowSize - Scale(5)
            local y = h / 2 - arrowSize / 2
            draw.NoTexture()
            if self:IsMenuOpen() then
                surface.DrawPoly({
                    { x = x, y = y + arrowSize },
                    { x = x + arrowSize, y = y + arrowSize },
                    { x = x + arrowSize / 2, y = y }
                })
            else
                surface.DrawPoly({
                    { x = x, y = y },
                    { x = x + arrowSize, y = y },
                    { x = x + arrowSize / 2, y = y + arrowSize }
                })
            end
            self:DrawTextEntryText(
                rRadio.config.UI.TextColor,
                rRadio.config.UI.ButtonHoverColor,
                rRadio.config.UI.TextColor
            )
        end

        function self.dropdown:OpenMenu()
            if IsValid(self.Menu) then
                self.Menu:Remove()
                self.Menu = nil
            end

            local menu = DermaMenu()
            self.Menu = menu

            menu:SetMaxHeight(Scale(200))
            menu.Paint = function(pnl, w, h)
                draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            end

            if self:GetParent().onOpen then
                self:GetParent().onOpen()
            end

            for _, choice in ipairs(self:GetParent().choices or {}) do
                local option = menu:AddOption(choice.name, function()
                    self:ChooseOption(choice.name, choice.data)
                    if self:GetParent().onSelect then
                        self:GetParent().onSelect(self, _, choice.name, choice.data)
                    end
                end)
                option:SetTextColor(rRadio.config.UI.TextColor)
                option:SetFont("rRadio.Roboto5")
                option.Paint = function(pnl, pw, ph)
                    if pnl:IsHovered() then
                        draw.RoundedBox(4, 2, 0, pw - 4, ph, rRadio.config.UI.ButtonHoverColor)
                    end
                end
                option.OnCursorEntered = function()
                    if self:GetParent().onHover then
                        self:GetParent().onHover(choice.data)
                    end
                end
            end

            local x, y = self:LocalToScreen(0, self:GetTall())
            menu:SetMinimumWidth(self:GetWide())
            menu:Open(x, y, false, self)

            menu.OnRemove = function()
                if self:GetParent().onClose then
                    self:GetParent().onClose()
                end
            end

            if IsValid(menu.VBar) then
                rRadio.interface.StyleVBar(menu.VBar)
            end
        end
    end

    function PANEL:SetData(text, choices, current, onSelect, onHover, onOpen, onClose)
        self.choices = choices or {}
        self.onSelect = onSelect
        self.onHover = onHover
        self.onOpen = onOpen
        self.onClose = onClose
        self.label:SetText(text or "")
        self.label:SizeToContents()
        self.dropdown:Clear()
        for _, choice in ipairs(self.choices) do
            self.dropdown:AddChoice(choice.name, choice.data)
        end
        if current then
            self.dropdown:SetValue(current)
        end
    end

    function PANEL:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
    end

    vgui.Register("rRadioDropdown", PANEL, "DPanel")
end
