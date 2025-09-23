local Radio = rRadio
local Interface = Radio.interface
local Config = Radio.config

do
    local PANEL = {}

    function PANEL:Init()
        self:SetText("")
        self:SetFont("rRadio.Roboto5")
        self.textColor  = Config.UI.TextColor
        self.baseColor  = Config.UI.ButtonColor
        self.hoverColor = Config.UI.ButtonHoverColor
        self.lerp       = 0
    end

    function PANEL:SetColors(text, base, hover)
        if text then self:SetTextColor(text) end
        if base then self.baseColor = base end
        if hover then self.hoverColor = hover end
    end

    function PANEL:Think()
        local tgt = self:IsHovered() and 1 or 0
        self.lerp = math.Approach(self.lerp, tgt, FrameTime() * 10)
    end

    function PANEL:Paint(w, h)
        local col = Interface.LerpColor(self.lerp, self.baseColor, self.hoverColor)
        draw.RoundedBox(8, 0, 0, w, h, col)
    end

    vgui.Register("rRadioAnimatedButton", PANEL, "DButton")
end
