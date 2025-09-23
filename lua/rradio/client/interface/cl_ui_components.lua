if SERVER then return end

local Radio, Utils, Interface, Config = rRadio:Import("Radio", "utils", "!interface", "config", "!cl")

Radio.cl.uiComponents = {}

local Scale = Radio.cl.Scale
local uiState = Radio.cl.uiState
local timing = Radio.cl.timing
local icons = Radio.cl.icons

function Radio.cl.uiComponents.createPlayableStationButton(parent, station, displayText, updateList)
    local btn = vgui.Create("rRadioButton", parent)
    btn:SetTextLabel(displayText)

    local star = vgui.Create("rRadioStar", btn)
    star:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    star:Bind(Interface.favoriteStations, station.countryKey, station.name)
    star:SetUpdateFunc(updateList)
    btn:SetLeftChild(star)

    btn.DoClick = function()
        local now = CurTime()
        if now - timing.lastStationSelectTime < 2 then return end
        
        Interface.playSound("ButtonPressSecondary")
        
        local plyEnt = LocalPlayer().currentRadioEntity
        if not IsValid(plyEnt) then return end
        
        local vol = Radio.cl.getEntityVolume(plyEnt)

        net.Start("rRadio.PlayStation")
            net.WriteEntity(plyEnt)
            net.WriteString(Interface.TruncateChars(station.name, Config.MaxNameChars))
            net.WriteString(station.url)
            net.WriteFloat(vol)
        net.SendToServer()

        Radio.cl.requestedStations[plyEnt] = true
        Radio.cl.currentlyPlayingStations[plyEnt] = station
        timing.lastStationSelectTime = now
        
        if updateList then updateList() end
    end

    btn.Think = function(self)
        local ent = LocalPlayer().currentRadioEntity
        local on = IsValid(ent) and 
                  Radio.cl.currentlyPlayingStations[ent] and 
                  Radio.cl.currentlyPlayingStations[ent].name == station.name
        if on ~= self.playing then 
            self:SetPlaying(on) 
        end
    end

    return btn
end

function Radio.cl.uiComponents.populateFavorites(panel, updateList)
    local items = {}
    local hasFavorites = false
    
    for country, stations in pairs(Interface.favoriteStations) do
        for _, isFav in pairs(stations) do
            if isFav then 
                hasFavorites = true 
                break 
            end
        end
        if hasFavorites then break end
    end
    
    if not hasFavorites then return items end
    
    table.insert(items, vgui.Create("rRadioSeparator", panel))
    
    local favBtn = vgui.Create("DButton", panel)
    favBtn:Dock(TOP)
    favBtn:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
    favBtn:SetTall(Scale(40))
    favBtn:SetText(Config.Lang["FavoriteStations"] or "Favorite Stations")
    favBtn:SetFont("rRadio.Roboto5")
    favBtn:SetTextColor(Config.UI.TextColor)
    favBtn.lerp = 0
    
    favBtn.Think = function(self)
        local tgt = self:IsHovered() and 1 or 0
        self.lerp = math.Approach(self.lerp, tgt, FrameTime() * 10)
    end
    
    favBtn.Paint = function(self, w, h)
        local col = Interface.LerpColor(self.lerp, 
            Config.UI.ButtonColor, 
            Config.UI.ButtonHoverColor)
        draw.RoundedBox(8, 0, 0, w, h, col)
    end
    
    local headerIcon = vgui.Create("rRadioStar", favBtn)
    headerIcon:SetPos(Scale(10), (Scale(40) - Scale(24)) / 2)
    headerIcon:SetUpdateFunc(updateList)
    
    function headerIcon:Paint(w, h)
        surface.SetMaterial(icons.star.FULL)
        surface.SetDrawColor(Config.UI.TextColor)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    
    function headerIcon:DoClick()
        favBtn:DoClick()
    end
    
    favBtn.DoClick = function()
        Interface.playSound("ButtonPressMain")
        uiState.globalView = false
        uiState.lastView = nil
        uiState.selectedCountry = "favorites"
        uiState.favoritesMenuOpen = true
        updateList()
    end
    
    table.insert(items, favBtn)
    table.insert(items, vgui.Create("rRadioSeparator", panel))
    
    return items
end

function Radio.cl.uiComponents.populateCountries(panel, filterText, updateList)
    local items            = {}
    local raw              = {}
    local customKey        = Config.CustomStationCategory or "Custom"
    local translateCustom  = (customKey == "Custom")

    local wantsHeader = Config.PrioritiseCustom
                     and filterText == ""
                     and Radio.cl.stationData[customKey]
                     and #Radio.cl.stationData[customKey] > 0

    if wantsHeader then
        local label = translateCustom
                      and Radio.LanguageManager:GetCustomTranslation()
                      or customKey

        local hdrBtn = vgui.Create("DButton", panel)
        hdrBtn:Dock(TOP)
        hdrBtn:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        hdrBtn:SetTall(Scale(40))
        hdrBtn:SetText(label)
        hdrBtn:SetFont("rRadio.Roboto5")
        hdrBtn:SetTextColor(Config.UI.TextColor)
        hdrBtn.lerp = 0

        hdrBtn.Think = function(self)
            self.lerp = math.Approach(self.lerp,
                                      self:IsHovered() and 1 or 0,
                                      FrameTime() * 10)
        end
        hdrBtn.Paint = function(self, w, h)
            local col = Interface.LerpColor(self.lerp,
                          Config.UI.ButtonColor,
                          Config.UI.ButtonHoverColor)
            draw.RoundedBox(8, 0, 0, w, h, col)
        end
        hdrBtn.DoClick = function()
            Interface.playSound("ButtonPressMain")
            uiState.globalView        = false
            uiState.lastView          = nil
            uiState.selectedCountry   = customKey
            uiState.favoritesMenuOpen = false
            updateList()
        end

        local icon = vgui.Create("DImage", hdrBtn)
        icon:SetPos(Scale(10), (Scale(40) - Scale(24)) / 2)
        icon:SetSize(Scale(24), Scale(24))
        icon:SetMaterial(icons.star.FULL)
        icon:SetImageColor(Config.UI.TextColor)
        icon:SetMouseInputEnabled(false)


        table.insert(items, hdrBtn)
        table.insert(items, vgui.Create("rRadioSeparator", panel))
    end

    for country, _ in pairs(Radio.cl.stationData) do
        if not (country == customKey and wantsHeader) then
            if not (country == customKey and #Radio.cl.stationData[country] == 0) then
                local formatted = country:gsub("_", " ")
                                         :gsub("(%a)([%w_']*)",
                                               function(f,r) return f:upper()..r:lower() end)

                local isCustom = (country == customKey)
                local trans = (isCustom and translateCustom)
                              and Radio.LanguageManager:GetCustomTranslation()
                              or Radio.LanguageManager:GetCountryTranslation(formatted)
                              or formatted

                table.insert(raw, {
                    original      = country,
                    translated    = trans,
                    isPrioritized = Interface.favoriteCountries[country]
                })
            end
        end
    end

    local countries = Interface.fuzzyFilter(
        filterText,
        raw,
        function(c) return c.translated end,
        0,
        function(c) return c.isPrioritized and 0.1 or 0 end
    )

    if not wantsHeader
       and Config.PrioritiseCustom
       and filterText == "" then
        for i, c in ipairs(countries) do
            if c.original == customKey then
                local entry = table.remove(countries, i)
                local idx = 1
                for j, d in ipairs(countries) do
                    if not d.isPrioritized then break end
                    idx = j + 1
                end
                table.insert(countries, idx, entry)
                break
            end
        end
    end

    for _, c in ipairs(countries) do
        local btn = vgui.Create("rRadioButton", panel)
        btn:SetTextLabel(c.translated)

        local star = vgui.Create("rRadioStar", btn)
        star:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
        star:Bind(Interface.favoriteCountries, c.original)
        star:SetUpdateFunc(updateList)
        btn:SetLeftChild(star)

        btn.DoClick = function()
            Interface.playSound("ButtonPressMain")
            uiState.globalView        = false
            uiState.lastView          = nil
            uiState.selectedCountry   = c.original
            updateList()
        end

        table.insert(items, btn)
    end

    return items
end

function Radio.cl.uiComponents.populateStations(panel, country, filterText, updateList, backButton, searchBox)
    local items = {}
    
    if country == "favorites" then
        local rawFav = {}
        for c, stations in pairs(Interface.favoriteStations) do
            if Radio.cl.stationData[c] then
                for _, st in ipairs(Radio.cl.stationData[c]) do
                    if stations[st.name] then
                        table.insert(rawFav, {
                            station = st,
                            country = c,
                            countryName = Utils.FormatAndTranslateCountry(c)
                        })
                    end
                end
            end
        end
        
        local favList = Interface.fuzzyFilter(filterText, rawFav,
            function(f) return f.countryName.." - "..f.station.name end, 0
        )
        
        local favLimit = uiState.isSearching and Radio.cl.MAX_SEARCH_RESULTS or #favList
        for i = 1, math.min(favLimit, #favList) do
            local f = favList[i]
            f.station.countryKey = f.country
            local btn = Radio.cl.uiComponents.createPlayableStationButton(panel, f.station,
                f.countryName.." - "..f.station.name, updateList)
            table.insert(items, btn)
        end
    else
        local rawList = {}
        for _, st in ipairs(Radio.cl.stationData[country] or {}) do
            if st and st.name then
                table.insert(rawList, {
                    station = st,
                    favorite = Interface.favoriteStations[country] and 
                              Interface.favoriteStations[country][st.name]
                })
            end
        end
        
        local sorted = Interface.fuzzyFilter(filterText, rawList,
            function(s) return s.station.name end, 0,
            function(s) return s.favorite and 0.1 or 0 end
        )
        
        local resultLimit = uiState.isSearching and Radio.cl.MAX_SEARCH_RESULTS or #sorted
        for i = 1, math.min(resultLimit, #sorted) do
            local d = sorted[i]
            d.station.countryKey = country
            local btn = Radio.cl.uiComponents.createPlayableStationButton(panel, d.station,
                d.station.name, updateList)
            table.insert(items, btn)
        end
    end
    
    if backButton then
        backButton:SetVisible(true)
        backButton:SetEnabled(true)
    end
    
    return items
end
