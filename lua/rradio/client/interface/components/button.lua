do
    local PANEL   = {}
    local Scale   = rRadio.utils.Scale

    function PANEL:Init()
        self.label       = ""
        self.leftChild   = nil
        self.playing     = false
        self.hoverColour = rRadio.config.UI.ButtonHoverColor

        self:SetTall(Scale(40))
        self:SetText("")

        self:Dock(TOP)
        self:DockMargin(Scale(5), Scale(5), Scale(5), 0)
    end

    function PANEL:SetTextLabel(t)    self.label       = t or ""        end
    function PANEL:SetLeftChild(p)    self.leftChild   = p              end
    function PANEL:SetPlaying(b)      self.playing     = b and true or false end
    function PANEL:SetHoverColour(c)  if c then self.hoverColour = c end    end

    function PANEL:Paint(w,h)
        local bg = self.playing and rRadio.config.UI.PlayingButtonColor
                        or rRadio.config.UI.ButtonColor
        if self:IsHovered() and not self.playing then
            bg = self.hoverColour
        end
        draw.RoundedBox(8,0,0,w,h,bg)

        surface.SetFont("rRadio.Roboto5")

        local leftPad  = self.leftChild and (self.leftChild:GetWide() + Scale(16)) or Scale(8)
        local rightPad = Scale(8)
        local avail    = w - leftPad - rightPad

        local txt = rRadio.interface.TruncateText(self.label, "rRadio.Roboto5", avail)
        local tw  = surface.GetTextSize(txt)
        local x   = math.Clamp(w*0.5, leftPad + tw*0.5, w - rightPad - tw*0.5)

        draw.SimpleText(txt, "rRadio.Roboto5", x, h/2,
                        rRadio.config.UI.TextColor,
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    vgui.Register("rRadioButton", PANEL, "DButton")
end