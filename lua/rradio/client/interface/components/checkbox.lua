do
    local PANEL = {}
    local Scale = rRadio.interface.scale

    function PANEL:Init()
        self:SetTall(Scale(40))
        self:Dock(TOP)
        self:DockMargin(0, 0, 0, Scale(5))

        self.checkbox = vgui.Create("DCheckBox", self)
        self.checkbox:SetPos(Scale(10), (self:GetTall() - Scale(20)) / 2)
        self.checkbox:SetSize(Scale(20), Scale(20))
        self.checkbox.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            if self.checkbox:GetChecked() then
                surface.SetDrawColor(rRadio.config.UI.TextColor)
                surface.DrawRect(Scale(4), Scale(4), w - Scale(8), h - Scale(8))
            end
        end

        self.label = vgui.Create("DLabel", self)
        self.label:SetPos(Scale(40), (self:GetTall() - Scale(20)) / 2)
        self.label:SetTextColor(rRadio.config.UI.TextColor)
        self.label:SetFont("rRadio.Roboto5")
    end

    function PANEL:Setup(text, convar, initial, onChange)
        self.label:SetText(text or "")
        self.label:SizeToContents()
        self.label:SetPos(Scale(40), (self:GetTall() - self.label:GetTall()) / 2)

        self.convar = convar
        self.onChange = onChange

        if initial ~= nil then
            self.checkbox:SetChecked(initial)
        elseif convar and convar ~= "" then
            self.checkbox:SetChecked(GetConVar(convar):GetBool())
        end

        self.checkbox.OnChange = function(_, val)
            if self.convar and self.convar ~= "" then
                RunConsoleCommand(self.convar, val and "1" or "0")
            end
            if self.onChange then
                self.onChange(self.checkbox, val)
            end
        end
    end

    function PANEL:GetChecked()
        return self.checkbox:GetChecked()
    end

    function PANEL:SetChecked(v)
        self.checkbox:SetChecked(v)
    end

    function PANEL:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
    end

    vgui.Register("rRadioCheckbox", PANEL, "DPanel")
end
