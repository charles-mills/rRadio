if rRadio.clCoreLoaded or SERVER then return end

rRadio.cl = rRadio.cl or {}

rRadio.cl.radioSources = {}
rRadio.cl.BoomboxStatuses = rRadio.cl.BoomboxStatuses or {}
rRadio.cl.connectedStations = rRadio.cl.connectedStations or {}
rRadio.cl.requestedStations = rRadio.cl.requestedStations or {}
rRadio.cl.playbackNonce = rRadio.cl.playbackNonce or {}

local entityVolumes = {}
local currentlyPlayingStations = {}

local allowedURLSet = {}
local StationData = {}

local MAX_CLIENT_STATIONS = 10
local currentFrame = nil
local settingsFrame = nil
local settingsMenuOpen = false
local openRadioMenu
local lastKeyPress = 0
local keyPressDelay = 0.2
local favoritesMenuOpen = false
local activeStationCount = 0
local selectedCountry = nil
local radioMenuOpen = false
local lastStationSelectTime = 0
local stationDataLoaded = false
local isSearching = false

local Scale = rRadio.utils.Scale
local IsValid, pairs, ipairs = IsValid, pairs, ipairs
local LocalPlayer, ents = LocalPlayer, ents

local playerVeh = nil

local icons = icons or {}

icons.volume = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}

icons.star = {
    FULL = Material("hud/star_full.png", "smooth"),
    EMPTY = Material("hud/star.png", "smooth")
}

local VOLUME_DEBOUNCE_TIMER = "rRadio.VolumeDebounce"
local pendingVolume, pendingEntity
local volumeDebounceActive = false

local UIRegistry = { stars = {}, stations = {} }
local starIdCounter, stationIdCounter = 0, 0

local function SendPendingVolume()
    if not IsValid(pendingEntity) then return end
    net.Start("rRadio.SetRadioVolume")
    net.WriteEntity(pendingEntity)
    net.WriteFloat(pendingVolume)
    net.SendToServer()
end

local function getFavoriteStatus(tbl, key, subKey)
    if subKey then
        return tbl[key] and tbl[key][subKey]
    else
        return tbl[key]
    end
end

local function SharedStarPaint(self, w, h)
    local entry = UIRegistry.stars[self.UIKey]
    if not entry then return end
    local mat = getFavoriteStatus(entry.catTable, entry.key, entry.subKey) and icons.star.FULL or icons.star.EMPTY
    surface.SetMaterial(mat)
    surface.SetDrawColor(rRadio.config.UI.TextColor)
    surface.DrawTexturedRect(0, 0, w, h)
end

local function SharedStarClick(self)
    local entry = UIRegistry.stars[self.UIKey]
    if not entry then return end
    if entry.subKey then
        rRadio.interface.toggleFavorite(entry.catTable, entry.key, entry.subKey)
    else
        rRadio.interface.toggleFavorite(entry.catTable, entry.key)
    end
    if entry.updateList then entry.updateList() end
end

local function SharedStationPaint(self, w, h)
    local entry = UIRegistry.stations[self.UIKey]
    if not entry then return end
    local entity = LocalPlayer().currentRadioEntity
    local isPlaying = IsValid(entity) and currentlyPlayingStations[entity] and currentlyPlayingStations[entity].name == entry.station.name
    draw.RoundedBox(8, 0, 0, w, h, isPlaying and rRadio.config.UI.PlayingButtonColor or rRadio.config.UI.ButtonColor)
    if not isPlaying and self:IsHovered() then
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonHoverColor)
    end
    local text = entry.displayText
    surface.SetFont("rRadio.Roboto5")
    local regionLeft = Scale(8 + 24 + 8)
    local rightMargin = Scale(8)
    local availWidth = w - regionLeft - rightMargin
    local outputText = rRadio.interface.TruncateText(text, "rRadio.Roboto5", availWidth)
    local textWidth = surface.GetTextSize(outputText)
    local x = w * 0.5
    if x - textWidth * 0.5 < regionLeft then x = regionLeft + textWidth * 0.5
    elseif x + textWidth * 0.5 > w - rightMargin then x = w - rightMargin - textWidth * 0.5 end
    draw.SimpleText(outputText, "rRadio.Roboto5", x, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function SharedStationClick(self)
    local entry = UIRegistry.stations[self.UIKey]
    if not entry then return end
    local currentTime = CurTime()
    if currentTime - lastStationSelectTime < 2 then return end
    surface.PlaySound("buttons/button17.wav")
    local entity = LocalPlayer().currentRadioEntity
    if not IsValid(entity) then return end
    if currentlyPlayingStations[entity] then
        net.Start("rRadio.StopStation") net.WriteEntity(entity) net.SendToServer()
    end
    local entityConfig = rRadio.interface.getEntityConfig(entity)
    local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
    if not IsValid(entity) then return end
    net.Start("rRadio.PlayStation")
    net.WriteEntity(entity)

    local stationName = rRadio.interface.TruncateChars(entry.station.name, rRadio.config.MAX_NAME_CHARS)

    net.WriteString(stationName)
    net.WriteString(entry.station.url)
    net.WriteFloat(volume)
    net.SendToServer()

    rRadio.cl.requestedStations[entity] = true
    currentlyPlayingStations[entity] = entry.station
    lastStationSelectTime = currentTime
    if entry.updateList then entry.updateList() end
end

local function makeStarIcon(parent, catTable, key, subKey, updateList)
    starIdCounter = starIdCounter + 1
    local id = "star" .. starIdCounter
    UIRegistry.stars[id] = { catTable = catTable, key = key, subKey = subKey, updateList = updateList }
    local icon = vgui.Create("DImageButton", parent)
    icon:SetSize(Scale(24), Scale(24))
    icon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    icon.UIKey = id
    icon.Paint = SharedStarPaint
    icon.DoClick = SharedStarClick
    return icon
end

local function MakePlayableStationButton(parent, station, displayText, updateList, backButton, searchBox, resetSearch)
    stationIdCounter = stationIdCounter + 1
    local id = "station" .. stationIdCounter
    UIRegistry.stations[id] = { station = station, displayText = displayText, updateList = updateList }
    local btn = rRadio.interface.MakeStationButton(parent)
    btn.UIKey = id
    btn.Paint = SharedStationPaint
    makeStarIcon(btn, rRadio.interface.favoriteStations, station.country, station.name, updateList)
    btn.DoClick = SharedStationClick
    return btn
end

local function LoadStationData()
    if stationDataLoaded then
        return
    end

    StationData = {}
    
    local files = file.Find("rradio/client/data/stationpacks/*.lua", "LUA")
    for _, f in ipairs(files) do
        local data = include("rradio/client/data/stationpacks/" .. f)
        if data then
            for country, stations in pairs(data) do
                local baseCountry = country:gsub("_(%d+)$", "")
                if not StationData[baseCountry] then
                    StationData[baseCountry] = {}
                end
                for _, station in ipairs(stations) do
                    table.insert(StationData[baseCountry], {name = station.n, url = station.u})
                    allowedURLSet[station.u] = true
                end
            end
        else
            print("[rRADIO] Error: Could not load station file " .. f)
        end
    end
    stationDataLoaded = true
end
LoadStationData()

net.Receive("rRadio.CustomStationsUpdate", function()
    local list = net.ReadTable()
    local cat = rRadio.config.CustomStationCategory or "Custom"
    StationData[cat] = {}
    for _, st in ipairs(list) do
        if type(st)=="table" and st.name and st.url then
            table.insert(StationData[cat], { name = st.name, url = st.url })
            allowedURLSet[st.url] = true
        end
    end
    if radioMenuOpen then openRadioMenu() end
end)

local function IsUrlAllowed(urlToCheck)
    return allowedURLSet[urlToCheck] == true
end

local function populateFavorites(panel, updateList)
    local items = {}
    local hasFavorites = false
    for country, stations in pairs(rRadio.interface.favoriteStations) do
        for _, isFav in pairs(stations) do
            if isFav then hasFavorites = true break end
        end
        if hasFavorites then break end
    end
    if hasFavorites then
        local topSep = vgui.Create("DPanel", panel)
        topSep:Dock(TOP)
        topSep:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        topSep:SetTall(Scale(2))
        topSep.Paint = function(self,w,h)
            draw.RoundedBox(0, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end
        table.insert(items, topSep)

        local favBtn = vgui.Create("DButton", panel)
        favBtn:Dock(TOP)
        favBtn:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        favBtn:SetTall(Scale(40))
        favBtn:SetText(rRadio.config.Lang["FavoriteStations"] or "Favorite Stations")
        favBtn:SetFont("rRadio.Roboto5")
        favBtn:SetTextColor(rRadio.config.UI.TextColor)
        favBtn.Paint = function(self,w,h)
            local bg = self:IsHovered() and rRadio.config.UI.ButtonHoverColor or rRadio.config.UI.ButtonColor
            draw.RoundedBox(8,0,0,w,h,bg)
            surface.SetMaterial(icons.star.FULL)
            surface.SetDrawColor(rRadio.config.UI.TextColor)
            surface.DrawTexturedRect(Scale(10), h/2-Scale(12), Scale(24),Scale(24))
        end
        favBtn.DoClick = function()
            surface.PlaySound("buttons/button3.wav")
            selectedCountry = "favorites"
            favoritesMenuOpen = true
            updateList()
        end
        table.insert(items, favBtn)

        local bottomSep = vgui.Create("DPanel", panel)
        bottomSep:Dock(TOP)
        bottomSep:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        bottomSep:SetTall(Scale(2))
        bottomSep.Paint = function(self,w,h)
            draw.RoundedBox(0, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end
        table.insert(items, bottomSep)
    end
    return items
end

local function populateCountries(panel, filterText, updateList)
    local items = {}
    local raw = {}
    local customKey = rRadio.config.CustomStationCategory or "Custom"
    for country,_ in pairs(StationData) do
        if not (country == customKey and (#StationData[country] == 0)) then
            local formatted = country:gsub("_"," "):gsub("(%a)([%w_']*)", function(f,r) return f:upper()..r:lower() end)
            local trans = rRadio.LanguageManager:GetCountryTranslation(formatted) or formatted
            raw[#raw+1] = { original=country, translated=trans, isPrioritized=rRadio.interface.favoriteCountries[country] }
        end
    end
    local countries = rRadio.interface.fuzzyFilter(filterText, raw,
        function(c) return c.translated end, 0,
        function(c) return c.isPrioritized and 0.1 or 0 end
    )

    if rRadio.config.PrioritiseCustom then
        for i, c in ipairs(countries) do
            if c.original == customKey then

                local customEntry = table.remove(countries, i)

                local insertAt = 1
                for j, d in ipairs(countries) do
                    if not d.isPrioritized then
                        insertAt = j
                        break
                    end
                    insertAt = j + 1
                end
                table.insert(countries, insertAt, customEntry)
                break
            end
        end
    end
    for _, c in ipairs(countries) do
        local btn = rRadio.interface.MakeStationButton(panel)
        btn.Paint = function(self,w,h)
            draw.RoundedBox(8,0,0,w,h,rRadio.config.UI.ButtonColor)
            if self:IsHovered() then draw.RoundedBox(8,0,0,w,h,rRadio.config.UI.ButtonHoverColor) end
            surface.SetFont("rRadio.Roboto5")
            local left, right = Scale(8+24+8), Scale(8)
            local avail = w-left-right
            local txt = rRadio.interface.TruncateText(c.translated, "rRadio.Roboto5", avail)
            local tw = surface.GetTextSize(txt)
            local x = math.Clamp(w*0.5, left+tw*0.5, w-right-tw*0.5)
            draw.SimpleText(txt, "rRadio.Roboto5", x, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        makeStarIcon(btn, rRadio.interface.favoriteCountries, c.original, nil, updateList)
        btn.DoClick = function()
            surface.PlaySound("buttons/button3.wav")
            selectedCountry = c.original
            updateList()
        end
        table.insert(items, btn)
    end
    return items
end

local function populateStations(panel, country, filterText, updateList, backButton, searchBox)
    local items = {}
    if country == "favorites" then
        local rawFav = {}
        for c, stations in pairs(rRadio.interface.favoriteStations) do
            if StationData[c] then
                for _, st in ipairs(StationData[c]) do
                    if stations[st.name] then
                        rawFav[#rawFav+1] = { station=st, country=c, countryName=rRadio.utils.FormatAndTranslateCountry(c) }
                    end
                end
            end
        end
        local favList = rRadio.interface.fuzzyFilter(filterText, rawFav,
            function(f) return f.countryName.." - "..f.station.name end, 0
        )
        for _, f in ipairs(favList) do
            local btn = MakePlayableStationButton(panel, f.station,
                f.countryName.." - "..f.station.name, updateList, backButton, searchBox, false)
            makeStarIcon(btn, rRadio.interface.favoriteStations, f.country, f.station.name, updateList)
            table.insert(items, btn)
        end
    else
        local rawList = {}
        for _, st in ipairs(StationData[country] or {}) do
            if st and st.name then
                rawList[#rawList+1] = { station=st, favorite=rRadio.interface.favoriteStations[country] and rRadio.interface.favoriteStations[country][st.name] }
            end
        end
        local sorted = rRadio.interface.fuzzyFilter(filterText, rawList,
            function(s) return s.station.name end, 0,
            function(s) return s.favorite and 0.1 or 0 end
        )
        for _, d in ipairs(sorted) do
            local btn = MakePlayableStationButton(panel, d.station,
                d.station.name, updateList, backButton, searchBox, false)
            makeStarIcon(btn, rRadio.interface.favoriteStations, country, d.station.name, updateList)
            table.insert(items, btn)
        end
    end
    if backButton then
        backButton:SetVisible(true)
        backButton:SetEnabled(true)
    end
    return items
end

local function append(dest, src)
    for _, v in ipairs(src) do table.insert(dest, v) end
end

local function addAll(panel, items)
    for _, v in ipairs(items) do panel:Add(v) end
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then return end
    stationListPanel:Clear()
    if resetSearch then searchBox:SetText("") end
    local filterText = searchBox:GetText():lower()
    local function update() populateList(stationListPanel, backButton, searchBox, false) end

    local items = {}
    if not selectedCountry then
        append(items, populateFavorites(stationListPanel, update))
        append(items, populateCountries(stationListPanel, filterText, update))
    else
        append(items, populateStations(stationListPanel, selectedCountry, filterText, update, backButton, searchBox))
    end
    addAll(stationListPanel, items)
    if backButton then
        backButton:SetVisible(selectedCountry ~= nil)
        backButton:SetEnabled(selectedCountry ~= nil)
    end
end

local function openSettingsMenu(parentFrame, backButton)
    settingsFrame = vgui.Create("DPanel", parentFrame)
    settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50) - Scale(10))
    settingsFrame:SetPos(Scale(10), Scale(50))
    settingsFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.BackgroundColor)
    end
    local scrollPanel = vgui.Create("DScrollPanel", settingsFrame)
    scrollPanel:Dock(FILL)
    scrollPanel:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
    rRadio.interface.StyleVBar(scrollPanel:GetVBar())
    local function addHeader(text, isFirst)
        local header = vgui.Create("DLabel", scrollPanel)
        header:SetText(text)
        header:SetFont("rRadio.Roboto5")
        header:SetTextColor(rRadio.config.UI.TextColor)
        header:Dock(TOP)
        if isFirst then
            header:DockMargin(0, Scale(5), 0, Scale(0))
        else
            header:DockMargin(0, Scale(10), 0, Scale(5))
        end
        header:SetContentAlignment(4)
    end
    local function addDropdown(text, choices, currentValue, onSelect)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(50))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end

        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetFont("rRadio.Roboto5")
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:Dock(LEFT)
        label:DockMargin(Scale(10), 0, 0, 0)
        label:SetContentAlignment(4)
        label:SizeToContents()

        local dropdown = vgui.Create("DComboBox", container)
        dropdown:Dock(RIGHT)
        dropdown:SetWide(Scale(150))
        dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        dropdown:SetValue(currentValue)
        dropdown:SetTextColor(rRadio.config.UI.TextColor)
        dropdown:SetFont("rRadio.Roboto5")
        dropdown:SetSortItems(false)

        dropdown.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)

            surface.SetDrawColor(rRadio.config.UI.TextColor)
            local arrowSize = Scale(8)
            local x = w - arrowSize - Scale(5)
            local y = h / 2 - arrowSize / 2
            if self:IsMenuOpen() then
                draw.NoTexture()
                surface.DrawPoly(
                    {
                        {x = x, y = y + arrowSize},
                        {x = x + arrowSize, y = y + arrowSize},
                        {x = x + arrowSize / 2, y = y}
                    }
                )
            else
                draw.NoTexture()
                surface.DrawPoly(
                    {
                        {x = x, y = y},
                        {x = x + arrowSize, y = y},
                        {x = x + arrowSize / 2, y = y + arrowSize}
                    }
                )
            end
            self:DrawTextEntryText(rRadio.config.UI.TextColor, rRadio.config.UI.ButtonHoverColor, rRadio.config.UI.TextColor)
        end

        local oldOpenMenu = dropdown.OpenMenu
        dropdown.OpenMenu = function(self)
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

            for _, choice in ipairs(choices) do
                local option =
                    menu:AddOption(
                    choice.name,
                    function()
                        self:ChooseOption(choice.name, choice.data)
                        if onSelect then
                            onSelect(self, _, choice.name, choice.data)
                        end
                    end
                )

                option:SetTextColor(rRadio.config.UI.TextColor)
                option:SetFont("rRadio.Roboto5")
                option.Paint = function(pnl, w, h)
                    if pnl:IsHovered() then
                        draw.RoundedBox(4, 2, 0, w - 4, h, rRadio.config.UI.ButtonHoverColor)
                    end
                end
            end

            local x, y = self:LocalToScreen(0, self:GetTall())
            menu:SetMinimumWidth(self:GetWide())
            menu:Open(x, y, false, self)

            if IsValid(menu.VBar) then
                rRadio.interface.StyleVBar(menu.VBar)
            end
        end

        for _, choice in ipairs(choices) do
            dropdown:AddChoice(choice.name, choice.data)
        end

        return dropdown
    end
    local function addCheckbox(text, convar, initialValue, onChangeCallback)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(40))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end
        local checkbox = vgui.Create("DCheckBox", container)
        checkbox:SetPos(Scale(10), (container:GetTall() - Scale(20)) / 2)
        checkbox:SetSize(Scale(20), Scale(20))

        if initialValue ~= nil then
            checkbox:SetChecked(initialValue)
        elseif convar and convar ~= "" then
            checkbox:SetChecked(GetConVar(convar):GetBool())
        end
        checkbox.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            if self:GetChecked() then
                surface.SetDrawColor(rRadio.config.UI.TextColor)
                surface.DrawRect(Scale(4), Scale(4), w - Scale(8), h - Scale(8))
            end
        end
        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:SetFont("rRadio.Roboto5")
        label:SizeToContents()
        label:SetPos(Scale(40), (container:GetTall() - label:GetTall()) / 2)
        checkbox.OnChange = function(self, value)
            if convar and convar ~= "" then
                RunConsoleCommand(convar, value and "1" or "0")
            end
            if onChangeCallback then
                onChangeCallback(self, value)
            end
        end
        return checkbox
    end
    addHeader(rRadio.config.Lang["ThemeSelection"] or "Theme Selection", true)
    local themeChoices = {}
    if rRadio.themes then
        for themeName, _ in pairs(rRadio.themes) do
            local displayName = rRadio.config.Lang[themeName] or themeName:gsub("^%l", string.upper)
            table.insert(themeChoices, {name = displayName, data = themeName})
        end
    end
    local currentTheme = GetConVar("rammel_rradio_menu_theme"):GetString()
    local currentThemeName = rRadio.config.Lang[currentTheme] or currentTheme:gsub("^%l", string.upper)
    addDropdown(
        rRadio.config.Lang["SelectTheme"] or "Select Theme",
        themeChoices,
        currentThemeName,
        function(self, _, _, themeKey)
            local key = themeKey:lower()
            if rRadio.themes and rRadio.themes[key] then
                RunConsoleCommand("rammel_rradio_menu_theme", key)
                rRadio.config.UI = rRadio.themes[key]
                parentFrame:Close()
                openRadioMenu(true, {delay=true})
            end
        end
    )

    addHeader(rRadio.config.Lang["KeyBinds"] or "Key Binds")

    do
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(50))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end

        local label = vgui.Create("DLabel", container)
        label:Dock(LEFT)
        label:DockMargin(Scale(10), 0, 0, 0)
        label:SetFont("rRadio.Roboto5")
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:SetText(rRadio.config.Lang["SelectKey"] or "Select Key")
        label:SizeToContents()
        label:SetContentAlignment(4)

        local binder = vgui.Create("DBinder", container)
        binder:Dock(RIGHT)
        binder:DockMargin(0, Scale(5), Scale(10), Scale(5))
        binder:SetWide(Scale(150))
        binder:SetConVar("rammel_rradio_menu_key")
        local curKey = GetConVar("rammel_rradio_menu_key"):GetInt()
        binder:SetValue(curKey)
        binder:SetText(rRadio.GetKeyName(curKey))
        binder:SetTextColor(rRadio.config.UI.TextColor)
        binder:SetFont("rRadio.Roboto5")
        binder.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            draw.SimpleText(self:GetText(), "rRadio.Roboto5", w/2, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        function binder:OnChange(code)
            DBinder.OnChange(self, code)
            RunConsoleCommand("rammel_rradio_menu_key", code)
            self:SetText(rRadio.GetKeyName(code))
        end
    end
    addHeader(rRadio.config.Lang["GeneralOptions"] or "General Options")
    addCheckbox(rRadio.config.Lang["ShowCarMessages"] or "Show Car Radio Animation",
                "rammel_rradio_vehicle_animation",
                GetConVar("rammel_rradio_vehicle_animation"):GetBool())
    addCheckbox(rRadio.config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD",
                "rammel_rradio_boombox_hud",
                GetConVar("rammel_rradio_boombox_hud"):GetBool())
    if LocalPlayer():IsSuperAdmin() then
        local currentEntity = LocalPlayer().currentRadioEntity
        if rRadio.utils.IsBoombox(currentEntity) then
            addHeader(rRadio.config.Lang["SuperadminSettings"] or "Superadmin Settings")
            local permanentCheckbox = addCheckbox(
                rRadio.config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent",
                nil,
                currentEntity:GetNWBool("IsPermanent", false),
                function(self, value)
                    if not IsValid(currentEntity) then
                        self:SetChecked(false)
                        return
                    end
                    if value then
                        net.Start("rRadio.SetPersistent")
                        net.WriteEntity(currentEntity)
                        net.SendToServer()
                    else
                        net.Start("rRadio.RemovePersistent")
                        net.WriteEntity(currentEntity)
                        net.SendToServer()
                    end
                end
            )
            net.Receive(
                "rRadio.SendPersistentConfirmation",
                function()
                    local message = net.ReadString()
                    chat.AddText(Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255), message)
                    if string.find(message, "marked as permanent") then
                        permanentCheckbox:SetChecked(true)
                    elseif string.find(message, "permanence has been removed") then
                        permanentCheckbox:SetChecked(false)
                    end
                end
            )
        end
    end
    local footerHeight = Scale(60)
    local footer = vgui.Create("DPanel", settingsFrame)
    footer:SetSize(settingsFrame:GetWide(), footerHeight)
    footer:SetPos(0, settingsFrame:GetTall() - footerHeight)
    footer:SetText("")
    footer.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        local gap = Scale(8)
        draw.SimpleText(
            "rRadio by Rammel",
            "Default",
            w - Scale(10),
            h / 2 - gap,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_RIGHT,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "v" .. rRadio.config.RadioVersion,
            "Default",
            w - Scale(10),
            h / 2 + gap,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_RIGHT,
            TEXT_ALIGN_CENTER
        )
    end

    rRadio.interface.MakeIconButton(footer, "hud/github.png", "https://github.com/charles-mills/rRadio", Scale(10))
    rRadio.interface.MakeIconButton(footer, "hud/steam.png", "https://steamcommunity.com/id/rammel", Scale(50))
    rRadio.interface.MakeIconButton(footer, "hud/discord.png", "https://discordapp.com/users/1265373956685299836", Scale(90))
end

openRadioMenu = function(openSettings, opts)
    opts = opts or {}
    settingsMenuOpen = openSettings == true
    favoritesMenuOpen = false
    selectedCountry = nil
    if opts.delay and IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
        timer.Simple(
            0.1,
            function()
                openRadioMenu(openSettings, {})
            end
        )
        return
    end

    if not GetConVar("rammel_rradio_enabled"):GetBool() then
        return
    end

    if radioMenuOpen then
        return
    end
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    if not IsValid(entity) then
        return
    end
    if not rRadio.utils.canUseRadio(entity) then
        chat.AddText(Color(255, 0, 0), "[rRADIO] This seat cannot use the radio.")
        return
    end

    local shouldOpen = hook.Run("rRadio.CanOpenMenu", ply, entity)
    if shouldOpen == false then return end
    
    radioMenuOpen = true
    local backButton
    local frame = vgui.Create("DFrame")
    currentFrame = frame
    frame:SetTitle("")
    frame:SetSize(Scale(rRadio.config.UI.FrameSize.width), Scale(rRadio.config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function()
        radioMenuOpen = false
        settingsMenuOpen = false
        favoritesMenuOpen = false
        selectedCountry = nil
        if IsValid(settingsFrame) then
            settingsFrame:Remove()
            settingsFrame = nil
        end
        currentFrame = nil
    end
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), rRadio.config.UI.HeaderColor, true, true, false, false)
        local headerHeight = Scale(40)
        local iconSize = Scale(25)
        local iconOffsetX = Scale(10)
        local iconOffsetY = headerHeight / 2 - iconSize / 2
        surface.SetMaterial(Material("hud/radio.png"))
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        surface.DrawTexturedRect(iconOffsetX, iconOffsetY, iconSize, iconSize)
        local headerText
        if settingsMenuOpen then
            headerText = rRadio.config.Lang["Settings"] or "Settings"
        elseif selectedCountry then
            if selectedCountry == "favorites" then
                headerText = rRadio.config.Lang["FavoriteStations"] or "Favorite Stations"
            else
                headerText = rRadio.utils.FormatAndTranslateCountry(selectedCountry)
            end
        else
            headerText = rRadio.config.Lang["SelectCountry"] or "Select Country"
        end
        draw.SimpleText(
            headerText,
            "rRadio.Roboto8",
            iconOffsetX + iconSize + Scale(5),
            headerHeight / 2 + Scale(2),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(Scale(rRadio.config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("rRadio.Roboto5")
    searchBox:SetPlaceholderText(rRadio.config.Lang and rRadio.config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetTextColor(rRadio.config.UI.TextColor)
    searchBox:SetDrawBackground(false)
    searchBox.OnValueChanged = function(self, txt)
        timer.Remove("rRadio.SearchDebounce")
        timer.Create("rRadio.SearchDebounce", 0.2, 1, function()
            if not IsValid(frame) then return end
            populateList(stationListPanel, backButton, searchBox, false)
        end)
    end
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
        self:DrawTextEntryText(rRadio.config.UI.TextColor, Color(120, 120, 120), rRadio.config.UI.TextColor)
        if self:GetText() == "" then
            draw.SimpleText(
                self:GetPlaceholderText(),
                self:GetFont(),
                Scale(5),
                h / 2,
                rRadio.config.UI.TextColor,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end
    end
    searchBox:SetVisible(not settingsMenuOpen)
    searchBox.OnGetFocus = function()
        isSearching = true
    end
    searchBox.OnLoseFocus = function()
        isSearching = false
    end
    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(
        Scale(rRadio.config.UI.FrameSize.width) - Scale(20),
        Scale(rRadio.config.UI.FrameSize.height) - Scale(200)
    )
    stationListPanel:SetVisible(not settingsMenuOpen)
    rRadio.interface.StyleVBar(stationListPanel:GetVBar())
    local stopButtonHeight = Scale(rRadio.config.UI.FrameSize.width) / 8
    local stopButtonWidth = Scale(rRadio.config.UI.FrameSize.width) / 4
    local stopButtonText = rRadio.config.Lang["StopRadio"] or "STOP"
    local stopButtonFont = rRadio.interface.calculateFontSizeForStopButton(stopButtonText, stopButtonWidth, stopButtonHeight)
    local buttonSize = Scale(25)
    local topMargin = Scale(7)
    local buttonPadding = Scale(5)
    local function createAnimatedButton(parent, x, y, w, h, text, textColor, bgColor, hoverColor, clickFunc)
        local button = vgui.Create("DButton", parent)
        button:SetPos(x, y)
        button:SetSize(w, h)
        button:SetText(text)
        button:SetFont("rRadio.Roboto5")
        button:SetTextColor(textColor)
        button.Paint = function(self, w, h)
            local bgColor = self:IsHovered() and hoverColor or bgColor
            draw.RoundedBox(8, 0, 0, w, h, bgColor)
        end
        button.DoClick = clickFunc
        return button
    end
    local closeButton = rRadio.interface.MakeNavButton(frame, frame:GetWide() - buttonSize - Scale(10), topMargin, buttonSize, "hud/close.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        frame:Close()
    end)
    local settingsButton = rRadio.interface.MakeNavButton(frame, closeButton:GetX() - buttonSize - buttonPadding, topMargin, buttonSize, "hud/settings.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        settingsMenuOpen = true
        openSettingsMenu(currentFrame, backButton)
        backButton:SetVisible(true)
        backButton:SetEnabled(true)
        searchBox:SetVisible(false)
        stationListPanel:SetVisible(false)
    end)
    backButton = rRadio.interface.MakeNavButton(frame, settingsButton:GetX() - buttonSize - buttonPadding, topMargin, buttonSize, "hud/return.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        if settingsMenuOpen then
            settingsMenuOpen = false
            if IsValid(settingsFrame) then
                settingsFrame:Remove()
                settingsFrame = nil
            end
            searchBox:SetVisible(true)
            stationListPanel:SetVisible(true)
            populateList(stationListPanel, backButton, searchBox, true)
        else
            selectedCountry = nil
            favoritesMenuOpen = false
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
            populateList(stationListPanel, backButton, searchBox, true)
        end
    end)
    backButton:SetVisible((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
    backButton:SetEnabled((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
    local stopButton = createAnimatedButton(
        frame,
        Scale(10),
        Scale(rRadio.config.UI.FrameSize.height) - Scale(90),
        stopButtonWidth,
        stopButtonHeight,
        stopButtonText,
        rRadio.config.UI.TextColor,
        rRadio.config.UI.CloseButtonColor,
        rRadio.config.UI.CloseButtonHoverColor,
        function()
            surface.PlaySound("buttons/button6.wav")
            local entity = LocalPlayer().currentRadioEntity
            if IsValid(entity) then
                net.Start("rRadio.StopStation")
                net.WriteEntity(entity)
                net.SendToServer()
                currentlyPlayingStations[entity] = nil
                populateList(stationListPanel, backButton, searchBox, false)
                if backButton then
                    backButton:SetVisible(selectedCountry ~= nil or settingsMenuOpen)
                    backButton:SetEnabled(selectedCountry ~= nil or settingsMenuOpen)
                end
            end
        end
    )
    stopButton:SetFont(stopButtonFont)
    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + stopButtonWidth, Scale(rRadio.config.UI.FrameSize.height) - Scale(90))
    volumePanel:SetSize(Scale(rRadio.config.UI.FrameSize.width) - Scale(30) - stopButtonWidth, stopButtonHeight)
    volumePanel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.CloseButtonColor)
    end
    local volumeIconSize = Scale(50)
    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(10), (volumePanel:GetTall() - volumeIconSize) / 2)
    volumeIcon:SetSize(volumeIconSize, volumeIconSize)
    volumeIcon:SetMaterial(icons.volume.HIGH)
    local function updateVolumeIcon(volumeIcon, value)
        if not IsValid(volumeIcon) then
            return
        end
        local iconMat
        if type(value) == "function" then
            value = value()
        end
        local maxVol = (rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0)
        value = math.min(value, maxVol)
        if value < 0.01 then
            iconMat = icons.volume.MUTE
        elseif value <= 0.65 then
            iconMat = icons.volume.LOW
        else
            iconMat = icons.volume.HIGH
        end
        if iconMat then
            volumeIcon:SetMaterial(iconMat)
        end
    end
    volumeIcon.Paint = function(self, w, h)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end
    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = 0.5
    if IsValid(entity) then
        local entityConfig = rRadio.interface.getEntityConfig(entity)
        local defaultVolume = (entityConfig and (type(entityConfig.Volume) == "function" and entityConfig.Volume() or entityConfig.Volume)) or 0.5
        currentVolume = entity:GetNWFloat("Volume", defaultVolume)
        entityVolumes[entity] = currentVolume
        local maxVol = (rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0)
        currentVolume = math.min(currentVolume, maxVol)
    end
    updateVolumeIcon(volumeIcon, currentVolume)
    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(-Scale(170), Scale(5))
    volumeSlider:SetSize(
        Scale(rRadio.config.UI.FrameSize.width) + Scale(120) - stopButtonWidth,
        volumePanel:GetTall() - Scale(20)
    )
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    local maxVol = (rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0)
    volumeSlider:SetMax(maxVol)
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, h / 2 - 4, w, 16, rRadio.config.UI.TextColor)
    end
    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, rRadio.config.UI.BackgroundColor)
    end
    volumeSlider.TextArea:SetVisible(false)
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then
            return
        end

        if not rRadio.utils.IsBoombox(entity) then
            entity = rRadio.utils.GetVehicle(entity)
        end

        local maxVol = (rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0)
        value = math.min(value, maxVol)
        entityVolumes[entity] = value
        if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:SetVolume(value)
        end
        updateVolumeIcon(volumeIcon, value)

        pendingVolume = value
        pendingEntity = entity
        if not volumeDebounceActive then
            volumeDebounceActive = true
            timer.Create(VOLUME_DEBOUNCE_TIMER, 0.1, 1, function()
                SendPendingVolume()
                volumeDebounceActive = false
            end)
        end
    end
    do
        local knob = volumeSlider.Slider
        local origRelease = knob.OnMouseReleased
        knob.OnMouseReleased = function(self, mcode)
            if origRelease then origRelease(self, mcode) end
            if timer.Exists(VOLUME_DEBOUNCE_TIMER) then
                timer.Remove(VOLUME_DEBOUNCE_TIMER)
                SendPendingVolume()
                volumeDebounceActive = false
            end
        end
    end
    if not settingsMenuOpen then
        populateList(stationListPanel, backButton, searchBox, true)
    else
        openSettingsMenu(currentFrame, backButton)
    end
    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end
end

hook.Add(
    "Think",
    "rRadio.OpenCarRadioMenu",
    function()
        local ply = LocalPlayer()
        local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()

        local currentTime = CurTime()

        if not (input.IsKeyDown(openKey) and not ply:IsTyping() and currentTime - lastKeyPress > keyPressDelay) then
            return
        end

        lastKeyPress = currentTime

        if radioMenuOpen and not isSearching then
            surface.PlaySound("buttons/lightswitch2.wav")
            currentFrame:Close()
            radioMenuOpen = false
            selectedCountry = nil
            settingsMenuOpen = false
            favoritesMenuOpen = false
            return
        end

        local vehicle = ply:GetVehicle()
        if IsValid(vehicle) then
            local mainVehicle = rRadio.utils.GetVehicle(vehicle)
            if IsValid(mainVehicle) then
                if hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) == false then return end
                if rRadio.config.DriverPlayOnly then
                    local isPlayerDriving = (mainVehicle:GetDriver() == ply)
                    if not isPlayerDriving then
                        return
                    end
                end

                if not rRadio.utils.isSitAnywhereSeat(mainVehicle) then
                    ply.currentRadioEntity = mainVehicle
                    openRadioMenu()
                end
            end
        end
    end
)

net.Receive(
    "rRadio.UpdateRadioStatus",
    function()
        local entity = net.ReadEntity()
        local stationName = net.ReadString()
        local isPlaying = net.ReadBool()
        local statusCode = net.ReadUInt(2)

        if statusCode == rRadio.status.TUNING and rRadio.cl.connectedStations[entity] then return end

        local status
        if statusCode == rRadio.status.STOPPED
           or statusCode == rRadio.status.TUNING
           or statusCode == rRadio.status.PLAYING then
            status = statusCode
        else
            status = rRadio.status.STOPPED
        end
        local displayStatus = status
        if status == rRadio.status.PLAYING and not rRadio.cl.connectedStations[entity] then
            displayStatus = rRadio.status.TUNING
        end
        if status == rRadio.status.STOPPED then
            rRadio.cl.connectedStations[entity] = nil
            rRadio.cl.requestedStations[entity] = nil
        end
        if IsValid(entity) then
            rRadio.cl.BoomboxStatuses[entity:EntIndex()] = {
                stationStatus = displayStatus,
                stationName = stationName
            }
            entity:SetNWInt("Status", statusCode)
            entity:SetNWString("StationName", stationName)
            entity:SetNWBool("IsPlaying", isPlaying)
            if displayStatus == rRadio.status.PLAYING then
                currentlyPlayingStations[entity] = {name = stationName}
            else
                currentlyPlayingStations[entity] = nil
            end
        end
    end
)
net.Receive(
    "rRadio.PlayStation",
    function()
        if not GetConVar("rammel_rradio_enabled"):GetBool() then
            return
        end

        local entity = net.ReadEntity()
        entity = rRadio.interface.GetVehicleEntity(entity)

        if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:Stop()
            rRadio.cl.radioSources[entity] = nil
            entityVolumes[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end

        if IsValid(entity) and rRadio.utils.IsBoombox(entity) then
            rRadio.utils.clearRadioStatus(entity)
        end

        local stationName = net.ReadString()
        local url = net.ReadString()
        local volume = net.ReadFloat()

        local nonce = (rRadio.cl.playbackNonce[entity] or 0) + 1
        rRadio.cl.playbackNonce[entity] = nonce

        rRadio.utils.setRadioStatus(entity, rRadio.status.TUNING, stationName)

        if rRadio.config.SecureStationLoad then
            if not (IsUrlAllowed(url) or (IsValid(entity) and entity:GetNWBool("IsPermanent"))) then
                return
            end
        end

        local currentCount = rRadio.interface.updateStationCount()
        if not rRadio.cl.radioSources[entity] and currentCount >= MAX_CLIENT_STATIONS then
            return
        end

        sound.PlayURL(
            url,
            "3d",
            function(station, errorID, errorName)
                if rRadio.cl.playbackNonce[entity] ~= nonce then
                    if IsValid(station) then station:Stop() end
                    return
                end
                if IsValid(station) and IsValid(entity) then
                    station:SetPos(entity:GetPos())
                    station:SetVolume(volume)
                    station:Play()
                    rRadio.cl.radioSources[entity] = station
                    activeStationCount = rRadio.interface.updateStationCount()

                    local cfg = rRadio.interface.getEntityConfig(entity)
                    if cfg then
                        station:Set3DFadeDistance(cfg.MinVolumeDistance(), cfg.MaxHearingDistance())
                    end
                    rRadio.cl.connectedStations[entity] = true
                    rRadio.utils.setRadioStatus(entity, rRadio.status.PLAYING, stationName)
                    rRadio.cl.requestedStations[entity] = nil
                else
                    rRadio.cl.connectedStations[entity] = nil
                    rRadio.utils.clearRadioStatus(entity)
                    if rRadio.cl.requestedStations[entity] then
                        LocalPlayer():ChatPrint("[rRadio] Station is inactive.")
                    end
                    rRadio.cl.requestedStations[entity] = nil
                end
            end
        )
end
)

net.Receive(
    "rRadio.StopStation",
    function()
        local entity = net.ReadEntity()
        if not IsValid(entity) then
            return
        end
        entity = rRadio.interface.GetVehicleEntity(entity)

        if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:Stop()
            rRadio.cl.radioSources[entity] = nil
            entityVolumes[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end

        if IsValid(entity) and rRadio.utils.IsBoombox(entity) then
            rRadio.utils.clearRadioStatus(entity)
        end
    end
)

local function UpdateAllStations()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local plyPos = ply:GetPos()
    playerVeh = rRadio.utils.GetVehicle(ply:GetVehicle())
    for ent, station in pairs(rRadio.cl.radioSources) do
        if not IsValid(ent) or not IsValid(station) then
            rRadio.cl.radioSources[ent] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        else
            local actual = rRadio.interface.GetVehicleEntity(ent)
            station:SetPos(actual:GetPos())
            local distSqr = plyPos:DistToSqr(actual:GetPos())
            local inCar = (playerVeh == actual)
            rRadio.interface.updateRadioVolume(station, distSqr, inCar, actual)
        end
    end
end

timer.Create("rRadio.UpdateStationsTimer", 0.2, 0, UpdateAllStations)

net.Receive(
    "rRadio.OpenMenu",
    function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then
            return
        end
        local ply = LocalPlayer()
        if rRadio.utils.IsBoombox(ent) then
            ply.currentRadioEntity = ent
            if not radioMenuOpen then
                openRadioMenu()
            end
        end
    end
)

net.Receive("rRadio.ListCustomStations", function()
    local count = net.ReadUInt(16)
    if count == 0 then
        MsgC(Color(255,255,255), "[rRadio] No custom stations found.\n")
        return
    end

    MsgC(Color(255,0,0),   "[rRadio] Custom stations:\n")
    for i = 1, count do
        local name = net.ReadString()
        local url  = net.ReadString()
        MsgC(Color(255,0,0), "["..i.."] ",
             Color(255,255,255), name..": "..url.."\n")
    end

    MsgC(Color(255,0,0), "\n!! ",
         Color(255,255,255), "Remove a Station: "..rRadio.config.CommandRemoveStation.." <Name> or <URL>\n")
    MsgC(Color(255,0,0), "!! ",
         Color(255,255,255), "Add a Station: "..rRadio.config.CommandAddStation.." <Name> <URL>\n")
end)

net.Receive(
    "rRadio.PlayVehicleAnimation",
    function()
        rRadio.DevPrint("Received car radio message")
        local veh = net.ReadEntity()
        local isDriver = net.ReadBool()
        timer.Simple(0, function()
            rRadio.interface.DisplayVehicleEnterAnimation(veh, isDriver)
        end)
    end
)
net.Receive(
    "rRadio.SetConfigUpdate",
    function()
        for entity, source in pairs(rRadio.cl.radioSources) do
            if IsValid(entity) and IsValid(source) then
                local volume = rRadio.interface.ClampVolume(entityVolumes[entity] or rRadio.interface.getEntityConfig(entity).Volume())
                source:SetVolume(volume)
            end
        end
    end
)
hook.Add(
    "EntityRemoved",
    "rRadio.CleanupRadioStationCount",
    function(entity)
        if rRadio.cl.radioSources[entity] then
            if IsValid(rRadio.cl.radioSources[entity]) then
                rRadio.cl.radioSources[entity]:Stop()
            end
            rRadio.cl.radioSources[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end
    end
)
if not timer.Exists("ValidateStationCount") then
    timer.Create(
        "ValidateStationCount",
        30,
        0,
        function()
            local actualCount = 0
            for ent, source in pairs(rRadio.cl.radioSources) do
                if IsValid(ent) and IsValid(source) then
                    actualCount = actualCount + 1
                else
                    rRadio.cl.radioSources[ent] = nil
                end
            end
            activeStationCount = actualCount
        end
    )
end
hook.Add("ShutDown", "rRadio.CleanupValidateTimer", function()
    if timer.Exists("ValidateStationCount") then
        timer.Remove("ValidateStationCount")
    end
end)

rRadio.interface.loadFavorites()
hook.Add(
    "EntityRemoved",
    "rRadio.BoomboxCleanup",
    function(ent)
        if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
            rRadio.cl.BoomboxStatuses[ent:EntIndex()] = nil
            rRadio.cl.connectedStations[ent] = nil
            rRadio.cl.requestedStations[ent] = nil
        end
    end
)
hook.Add(
    "VehicleChanged",
    "rRadio.ClearRadioEntity",
    function(ply, old, new)
        if ply ~= LocalPlayer() then
            return
        end
        if not new then
            ply.currentRadioEntity = nil
        end
    end
)
hook.Add(
    "EntityRemoved",
    "rRadio.ClearRadioEntity",
    function(ent)
        local ply = LocalPlayer()
        if ent == ply.currentRadioEntity then
            ply.currentRadioEntity = nil
        end
    end
)

hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.addClConVars()
    rRadio.interface.loadSavedSettings()
end)

rRadio.clCoreLoaded = true