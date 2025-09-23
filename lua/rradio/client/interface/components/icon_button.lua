local Radio = rRadio
local Interface = Radio.interface
local Config = Radio.config

do
    local PANEL = {}
    local Scale = Interface.scale

    function PANEL:Init()
        self.iconMat = nil
        self.url = nil
        self:SetSize(Scale(32), Scale(32))
        self:SetText("")
    end

    function PANEL:SetIcon(path)
        self.iconMat = Material(path)
    end

    function PANEL:SetURL(url)
        self.url = url
    end

    function PANEL:DoClick()
        if self.url then
            gui.OpenURL(self.url)
        end
    end

    function PANEL:Paint(w, h)
        if self.iconMat then
            surface.SetDrawColor(Config.UI.TextColor)
            surface.SetMaterial(self.iconMat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end

    vgui.Register("rRadioIconButton", PANEL, "DImageButton")
end
