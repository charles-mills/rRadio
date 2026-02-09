do
    local PANEL = {}
    local Scale = rRadio.interface.scale
    function PANEL:Init()
        self:SetFont("rRadio.Roboto5")
        self:SetTextColor(rRadio.config.UI.TextColor)
        self:SetContentAlignment(4)
        self:Dock(TOP)
        self:SetText("")
        self:SetMouseInputEnabled(false)
    end

    function PANEL:SetTextLabel(text)
        self:SetText(text or "")
        self:SizeToContents()
    end

    function PANEL:SetIsFirst(first)
        if first then
            self:DockMargin(0, Scale(5), 0, Scale(0))
        else
            self:DockMargin(0, Scale(10), 0, Scale(5))
        end
    end

    vgui.Register("rRadioHeader", PANEL, "DLabel")
end
