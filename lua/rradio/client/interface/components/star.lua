do
    local PANEL     = {}
    local Scale     = rRadio.utils.Scale
    local FULL_MAT  = Material("hud/star_full.png",  "smooth")
    local EMPTY_MAT = Material("hud/star.png",       "smooth")

    function PANEL:Init()
        self:SetSize(Scale(24), Scale(24))
        self.catTable, self.key, self.subKey, self.updateFunc = nil, nil, nil, nil
        self:SetMouseInputEnabled(true)
    end

    function PANEL:Bind(catTable, key, subKey)
        self.catTable = catTable
        self.key      = key
        self.subKey   = subKey
    end
    function PANEL:SetUpdateFunc(fn) self.updateFunc = fn end

    local function isFavourite(pnl)
        if pnl.subKey then
            return pnl.catTable[pnl.key] and pnl.catTable[pnl.key][pnl.subKey]
        else
            return pnl.catTable[pnl.key]
        end
    end

    function PANEL:Paint(w,h)
        surface.SetMaterial(isFavourite(self) and FULL_MAT or EMPTY_MAT)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        surface.DrawTexturedRect(0,0,w,h)
    end

    function PANEL:DoClick()
        if not self.catTable then return end
        rRadio.interface.toggleFavorite(self.catTable, self.key, self.subKey)
        if isfunction(self.updateFunc) then self.updateFunc() end
    end

    vgui.Register("rRadioStar", PANEL, "DImageButton")
end