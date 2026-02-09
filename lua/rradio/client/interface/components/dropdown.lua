do
    local PANEL = {}
    local Scale = rRadio.interface.scale
    local TEXT_FONT = "rRadio.Roboto5"
    local function paintArrow(dropdown, w, h)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        local arrowSize = Scale(8)
        local x, y = w - arrowSize - Scale(5), h / 2 - arrowSize / 2
        draw.NoTexture()
        surface.DrawPoly(dropdown:IsMenuOpen() and {
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
        })
    end

    local function styleOption(option)
        option:SetTextColor(rRadio.config.UI.TextColor)
        option:SetFont(TEXT_FONT)
        option.Paint = function(pnl, pw, ph) if pnl:IsHovered() then draw.RoundedBox(4, 2, 0, pw - 4, ph, rRadio.config.UI.ButtonHoverColor) end end
    end

    function PANEL:Init()
        self:SetTall(Scale(50))
        self:Dock(TOP)
        self:DockMargin(0, 0, 0, Scale(5))
        self.label = vgui.Create("DLabel", self)
        self.label:Dock(LEFT)
        self.label:DockMargin(Scale(10), 0, 0, 0)
        self.label:SetFont(TEXT_FONT)
        self.label:SetTextColor(rRadio.config.UI.TextColor)
        self.label:SetContentAlignment(4)
        self.dropdown = vgui.Create("DComboBox", self)
        self.dropdown:Dock(RIGHT)
        self.dropdown:SetWide(Scale(150))
        self.dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        self.dropdown:SetTextColor(rRadio.config.UI.TextColor)
        self.dropdown:SetFont(TEXT_FONT)
        self.dropdown:SetSortItems(false)
        if self.dropdown.DropButton then self.dropdown.DropButton.Paint = function() end end
        function self.dropdown:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            paintArrow(self, w, h)
            self:DrawTextEntryText(rRadio.config.UI.TextColor, rRadio.config.UI.ButtonHoverColor, rRadio.config.UI.TextColor)
        end

        function self.dropdown:OpenMenu()
            local parent = self:GetParent()
            if IsValid(self.Menu) then
                self.Menu:Remove()
                self.Menu = nil
            end

            local menu = DermaMenu()
            self.Menu = menu
            menu:SetMaxHeight(Scale(200))
            menu.Paint = function(_, mw, mh) draw.RoundedBox(6, 0, 0, mw, mh, rRadio.config.UI.SearchBoxColor) end
            if parent.onOpen then parent.onOpen() end
            for _, choice in ipairs(parent.choices or {}) do
                local option = menu:AddOption(choice.name, function()
                    self:ChooseOption(choice.name, choice.data)
                    if parent.onSelect then parent.onSelect(self, nil, choice.name, choice.data) end
                end)

                styleOption(option)
                option.OnCursorEntered = function() if parent.onHover then parent.onHover(choice.data) end end
            end

            local x, y = self:LocalToScreen(0, self:GetTall())
            menu:SetMinimumWidth(self:GetWide())
            menu:Open(x, y, false, self)
            menu.OnRemove = function() if parent.onClose then parent.onClose() end end
            if IsValid(menu.VBar) then rRadio.interface.StyleVBar(menu.VBar) end
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

        if current then self.dropdown:SetValue(current) end
    end

    function PANEL:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
    end

    vgui.Register("rRadioDropdown", PANEL, "DPanel")
end
