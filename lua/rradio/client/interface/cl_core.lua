if rRadio.clCoreLoaded or SERVER then return end

rRadio.cl = rRadio.cl or {}
rRadio.cl.radioSources = rRadio.cl.radioSources or {}
rRadio.cl.BoomboxStatuses = rRadio.cl.BoomboxStatuses or {}

local allowedURLSet = {}
local StationData = {}
local entityVolumes = entityVolumes or {}
local MAX_CLIENT_STATIONS = 8
local currentFrame = nil
local settingsMenuOpen = false
local favoritesMenuOpen = false
local radioMenuOpen = false
local selectedCountry = nil
local lastKeyPress = 0
local keyPressDelay = 0.15
local lastStationSelectTime = 0
local currentlyPlayingStations = {}
local stationDataLoaded = false
local isSearching = false

local Scale = rRadio.utils.Scale

local VOLUME_ICONS = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}

local STAR_FULL = Material("hud/star_full.png", "smooth")
local STAR_EMPTY = Material("hud/star.png", "smooth")

local VOLUME_DEBOUNCE_TIMER = "rRadio.VolumeDebounce"
local pendingVolume, pendingEntity

local function isFav(tbl, key, subKey)
    return subKey and tbl[key] and tbl[key][subKey] or tbl[key]
end

local function makeStarIcon(parent, catTable, key, subKey, updateList)
    local icon = vgui.Create("DImageButton", parent)
    icon:SetSize(Scale(20), Scale(20))
    icon:SetPos(Scale(10), (Scale(36) - Scale(20)) / 2)
    icon.Paint = function(self, w, h)
        surface.SetMaterial(isFav(catTable, key, subKey) and STAR_FULL or STAR_EMPTY)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    icon.DoClick = function()
        rRadio.interface.toggleFavorite(catTable, subKey and key, subKey)
        if updateList then updateList() end
    end
    return icon
end

local function MakePlayableStationButton(parent, station, displayText, updateList, backButton, searchBox, resetSearch)
    local btn = rRadio.interface.MakeStationButton(parent)
    btn:SetTall(Scale(36))
    btn.Paint = function(self, w, h)
        local entity = LocalPlayer().currentRadioEntity
        local isPlaying = IsValid(entity) and currentlyPlayingStations[entity] and currentlyPlayingStations[entity].name == station.name
        local bgColor = isPlaying and rRadio.config.UI.PlayingButtonColor or (self:IsHovered() and rRadio.config.UI.ButtonHoverColor or rRadio.config.UI.ButtonColor)
        draw.RoundedBox(6, 0, 0, w, h, bgColor)
        surface.SetFont("rRadio.Roboto4")
        local regionLeft = Scale(40)
        local rightMargin = Scale(10)
        local availWidth = w - regionLeft - rightMargin
        local outputText = rRadio.interface.TruncateText(displayText, "rRadio.Roboto4", availWidth)
        draw.SimpleText(outputText, "rRadio.Roboto4", regionLeft, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    makeStarIcon(btn, rRadio.interface.favoriteStations, station.country, station.name, updateList)
    btn.DoClick = function()
        local currentTime = CurTime()
        if currentTime - lastStationSelectTime < 1.5 then return end
        surface.PlaySound("buttons/button17.wav")
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then return end
        if currentlyPlayingStations[entity] then
            net.Start("rRadio.StopStation") net.WriteEntity(entity) net.SendToServer()
        end
        local entityConfig = rRadio.interface.getEntityConfig(entity)
        local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
        net.Start("rRadio.PlayStation")
        net.WriteEntity(entity)
        net.WriteString(station.name)
        net.WriteString(station.url)
        net.WriteFloat(volume)
        net.SendToServer()
        currentlyPlayingStations[entity] = station
        lastStationSelectTime = currentTime
        updateList()
    end
    return btn
end

local function LoadStationData()
    if stationDataLoaded then return end
    StationData = {}
    local files = file.Find("rradio/client/data/stationpacks/*.lua", "LUA")
    for _, f in ipairs(files) do
        local data = include("rradio/client/data/stationpacks/" .. f)
        if data then
            for country, stations in pairs(data) do
                local baseCountry = country:gsub("_(%d+)$", "")
                StationData[baseCountry] = StationData[baseCountry] or {}
                for _, station in ipairs(stations) do
                    table.insert(StationData[baseCountry], {name = station.n, url = station.u, country = baseCountry})
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
        local favBtn = vgui.Create("DButton", panel)
        favBtn:Dock(TOP)
        favBtn:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
        favBtn:SetTall(Scale(36))
        favBtn:SetText(rRadio.config.Lang["FavoriteStations"] or "Favorite Stations")
        favBtn:SetFont("rRadio.Roboto4")
        favBtn:SetTextColor(rRadio.config.UI.TextColor)
        favBtn.Paint = function(self, w, h)
            local bg = self:IsHovered() and rRadio.config.UI.ButtonHoverColor or rRadio.config.UI.ButtonColor
            draw.RoundedBox(6, 0, 0, w, h, bg)
            surface.SetMaterial(STAR_FULL)
            surface.SetDrawColor(rRadio.config.UI.TextColor)
            surface.DrawTexturedRect(Scale(10), h/2-Scale(10), Scale(20), Scale(20))
        end
        favBtn.DoClick = function()
            surface.PlaySound("buttons/button3.wav")
            selectedCountry = "favorites"
            favoritesMenuOpen = true
            updateList()
        end
        table.insert(items, favBtn)
    end
    return items
end

local function populateCountries(panel, filterText, updateList)
    local items = {}
    local raw = {}
    for country, _ in pairs(StationData) do
        local formatted = country:gsub("_", " "):gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)
        local trans = rRadio.LanguageManager:GetCountryTranslation(formatted) or formatted
        raw[#raw + 1] = { original = country, translated = trans, isPrioritized = rRadio.interface.favoriteCountries[country] }
    end
    table.sort(raw, function(a, b) return a.translated < b.translated end)
    local countries = rRadio.interface.fuzzyFilter(filterText, raw, function(c) return c.translated end, 0, function(c) return c.isPrioritized and 0.1 or 0 end)
    for _, c in ipairs(countries) do
        local btn = rRadio.interface.MakeStationButton(panel)
        btn:SetTall(Scale(36))
        btn.Paint = function(self, w, h)
            local bg = self:IsHovered() and rRadio.config.UI.ButtonHoverColor or rRadio.config.UI.ButtonColor
            draw.RoundedBox(6, 0, 0, w, h, bg)
            surface.SetFont("rRadio.Roboto4")
            local left, right = Scale(40), Scale(10)
            local avail = w - left - right
            local txt = rRadio.interface.TruncateText(c.translated, "rRadio.Roboto4", avail)
            draw.SimpleText(txt, "rRadio.Roboto4", left, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
                        rawFav[#rawFav + 1] = { station = st, country = c, countryName = rRadio.utils.FormatAndTranslateCountry(c) }
                    end
                end
            end
        end
        local favList = rRadio.interface.fuzzyFilter(filterText, rawFav, function(f) return f.countryName .. " - " .. f.station.name end, 0)
        for _, f in ipairs(favList) do
            local btn = MakePlayableStationButton(panel, f.station, f.countryName .. " - " .. f.station.name, updateList, backButton, searchBox, false)
            table.insert(items, btn)
        end
    else
        local rawList = {}
        for _, st in ipairs(StationData[country] or {}) do
            if st and st.name then
                rawList[#rawList + 1] = { station = st, favorite = rRadio.interface.favoriteStations[country] and rRadio.interface.favoriteStations[country][st.name] }
            end
        end
        local sorted = rRadio.interface.fuzzyFilter(filterText, rawList, function(s) return s.station.name end, 0, function(s) return s.favorite and 0.1 or 0 end)
        for _, d in ipairs(sorted) do
            local btn = MakePlayableStationButton(panel, d.station, d.station.name, updateList, backButton, searchBox, false)
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
    local settingsFrame = vgui.Create("DPanel", parentFrame)
    settingsFrame:SetSize(parentFrame:GetWide() - Scale(20), parentFrame:GetTall() - Scale(50))
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
        header:DockMargin(0, isFirst and Scale(5) or Scale(10), 0, Scale(5))
        header:SetContentAlignment(4)
    end

    local function addDropdown(text, choices, currentValue, onSelect)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(40))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        end
        local label = vgui.Create("DLabel", container)
        label:SetText(text)
        label:SetFont("rRadio.Roboto4")
        label:SetTextColor(rRadio.config.UI.TextColor)
        label:Dock(LEFT)
        label:DockMargin(Scale(10), 0, 0, 0)
        label:SetContentAlignment(4)
        label:SizeToContents()
        local dropdown = vgui.Create("DComboBox", container)
        dropdown:Dock(RIGHT)
        dropdown:SetWide(Scale(140))
        dropdown:DockMargin(0, Scale(5), Scale(10), Scale(5))
        dropdown:SetValue(currentValue)
        dropdown:SetTextColor(rRadio.config.UI.TextColor)
        dropdown:SetFont("rRadio.Roboto4")
        dropdown:SetSortItems(false)
        dropdown.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
            surface.SetDrawColor(rRadio.config.UI.TextColor)
            local arrowSize = Scale(8)
            local x, y = w - arrowSize - Scale(5), h / 2 - arrowSize / 2
            draw.NoTexture()
            surface.DrawPoly(self:IsMenuOpen() and
                {{x = x, y = y + arrowSize}, {x = x + arrowSize, y = y + arrowSize}, {x = x + arrowSize / 2, y = y}} or
                {{x = x, y = y}, {x = x + arrowSize, y = y}, {x = x + arrowSize / 2, y = y + arrowSize}})
            self:DrawTextEntryText(rRadio.config.UI.TextColor, rRadio.config.UI.ButtonHoverColor, rRadio.config.UI.TextColor)
        end
        dropdown.OpenMenu = function(self)
            if IsValid(self.Menu) then self.Menu:Remove() end
            local menu = DermaMenu()
            self.Menu = menu
            menu:SetMaxHeight(Scale(180))
            menu.Paint = function(pnl, w, h) draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor) end
            for _, choice in ipairs(choices) do
                local option = menu:AddOption(choice.name, function()
                    self:ChooseOption(choice.name, choice.data)
                    if onSelect then onSelect(self, _, choice.name, choice.data) end
                end)
                option:SetTextColor(rRadio.config.UI.TextColor)
                option:SetFont("rRadio.Roboto4")
                option.Paint = function(pnl, w, h)
                    if pnl:IsHovered() then draw.RoundedBox(4, 2, 0, w - 4, h, rRadio.config.UI.ButtonHoverColor) end
                end
            end
            local x, y = self:LocalToScreen(0, self:GetTall())
            menu:SetMinimumWidth(self:GetWide())
            menu:Open(x, y, false, self)
            if IsValid(menu.VBar) then rRadio.interface.StyleVBar(menu.VBar) end
        end
        for _, choice in ipairs(choices) do dropdown:AddChoice(choice.name, choice.data) end
        return dropdown
    end

    local function addCheckbox(text, convar, initialValue, onChangeCallback)
        local container = vgui.Create("DPanel", scrollPanel)
        container:Dock(TOP)
        container:SetTall(Scale(36))
        container:DockMargin(0, 0, 0, Scale(5))
        container.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.ButtonColor) end
        local checkbox = vgui.Create("DCheckBox", container)
        checkbox:SetPos(Scale(10), (container:GetTall() - Scale(18)) / 2)
        checkbox:SetSize(Scale(18), Scale(18))
        checkbox:SetChecked(initialValue ~= nil and initialValue or convar and GetConVar(convar):GetBool())
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
        label:SetFont("rRadio.Roboto4")
        label:SizeToContents()
        label:SetPos(Scale(36), (container:GetTall() - label:GetTall()) / 2)
        checkbox.OnChange = function(self, value)
            if convar then RunConsoleCommand(convar, value and "1" or "0") end
            if onChangeCallback then onChangeCallback(self, value) end
        end
        return checkbox
    end

    addHeader(rRadio.config.Lang["ThemeSelection"] or "Theme Selection", true)
    local themeChoices = {}
    for themeName, _ in pairs(rRadio.themes or {}) do
        local displayName = rRadio.config.Lang[themeName] or themeName:gsub("^%l", string.upper)
        table.insert(themeChoices, {name = displayName, data = themeName})
    end
    local currentTheme = GetConVar("rammel_rradio_menu_theme"):GetString()
    local currentThemeName = rRadio.config.Lang[currentTheme] or currentTheme:gsub("^%l", string.upper)
    addDropdown(rRadio.config.Lang["SelectTheme"] or "Select Theme", themeChoices, currentThemeName, function(self, _, _, themeKey)
        local key = themeKey:lower()
        if rRadio.themes and rRadio.themes[key] then
            RunConsoleCommand("rammel_rradio_menu_theme", key)
            rRadio.config.UI = rRadio.themes[key]
            parentFrame:Close()
            openRadioMenu(true, {delay=true})
        end
    end)

    addHeader(rRadio.config.Lang["KeyBinds"] or "Key Binds")
    local keyChoices = {}
    for keyCode, keyName in pairs(rRadio.keyCodeMapping or {{name = "K", data = KEY_K}}) do
        table.insert(keyChoices, {name = keyName, data = keyCode})
    end
    table.sort(keyChoices, function(a, b) return a.name < b.name end)
    local currentKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local currentKeyName = (rRadio.keyCodeMapping and rRadio.keyCodeMapping[currentKey]) or "K"
    addDropdown(rRadio.config.Lang["SelectKey"] or "Select Key", keyChoices, currentKeyName, function(_, _, _, data)
        RunConsoleCommand("rammel_rradio_menu_key", data)
    end)

    addHeader(rRadio.config.Lang["GeneralOptions"] or "General Options")
    addCheckbox(rRadio.config.Lang["ShowCarMessages"] or "Show Car Radio Animation", "rammel_rradio_vehicle_animation", nil)
    addCheckbox(rRadio.config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD", "rammel_rradio_boombox_hud", nil)

    if LocalPlayer():IsSuperAdmin() then
        local currentEntity = LocalPlayer().currentRadioEntity
        if rRadio.utils.IsBoombox(currentEntity) then
            addHeader(rRadio.config.Lang["SuperadminSettings"] or "Superadmin Settings")
            local permanentCheckbox = addCheckbox(rRadio.config.Lang["MakeBoomboxPermanent"] or "Make Boombox Permanent", nil, currentEntity:GetNWBool("IsPermanent", false), function(self, value)
                if not IsValid(currentEntity) then self:SetChecked(false) return end
                net.Start(value and "rRadio.SetPersistent" or "rRadio.RemovePersistent")
                net.WriteEntity(currentEntity)
                net.SendToServer()
            end)
            net.Receive("rRadio.SendPersistentConfirmation", function()
                local message = net.ReadString()
                chat.AddText(Color(0, 255, 0), "[Boombox] ", Color(255, 255, 255), message)
                permanentCheckbox:SetChecked(string.find(message, "marked as permanent") and true or string.find(message, "permanence has been removed") and false)
            end)
        end
    end

    local footer = vgui.Create("DPanel", settingsFrame)
    footer:SetSize(settingsFrame:GetWide(), Scale(50))
    footer:SetPos(0, settingsFrame:GetTall() - Scale(50))
    footer.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.ButtonColor)
        draw.SimpleText("rRadio by Rammel v" .. rRadio.config.RadioVersion, "rRadio.Roboto4", w - Scale(10), h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    rRadio.interface.MakeIconButton(footer, "hud/github.png", "https://github.com/charles-mills/rRadio", Scale(10))
    rRadio.interface.MakeIconButton(footer, "hud/steam.png", "https://steamcommunity.com/id/rammel", Scale(40))
    rRadio.interface.MakeIconButton(footer, "hud/discord.png", "https://discordapp.com/users/1265373956685299836", Scale(70))
end

local function openRadioMenu(openSettings, opts)
    opts = opts or {}
    settingsMenuOpen = openSettings == true
    favoritesMenuOpen = false
    selectedCountry = nil
    if opts.delay and IsValid(LocalPlayer()) and LocalPlayer().currentRadioEntity then
        timer.Simple(0.1, function() openRadioMenu(openSettings, {}) end)
        return
    end
    if not GetConVar("rammel_rradio_enabled"):GetBool() or radioMenuOpen then return end
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    if not IsValid(entity) or not rRadio.utils.canUseRadio(entity) then
        if IsValid(entity) then chat.AddText(Color(255, 0, 0), "[rRADIO] This seat cannot use the radio.") end
        return
    end
    if hook.Run("rRadio.CanOpenMenu", ply, entity) == false then return end
    radioMenuOpen = true
    local frame = vgui.Create("DFrame")
    currentFrame = frame
    frame:SetTitle("")
    frame:SetSize(Scale(400), Scale(500))
    frame:Center()
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function()
        radioMenuOpen = false
        settingsMenuOpen = false
        favoritesMenuOpen = false
        selectedCountry = nil
        if IsValid(settingsFrame) then settingsFrame:Remove() end
        currentFrame = nil
    end
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.BackgroundColor)
        draw.RoundedBoxEx(8, 0, 0, w, Scale(40), rRadio.config.UI.HeaderColor, true, true, false, false)
        local headerText = settingsMenuOpen and (rRadio.config.Lang["Settings"] or "Settings") or
                          selectedCountry == "favorites" and (rRadio.config.Lang["FavoriteStations"] or "Favorite Stations") or
                          selectedCountry and rRadio.utils.FormatAndTranslateCountry(selectedCountry) or
                          (rRadio.config.Lang["SelectCountry"] or "Select Country")
        surface.SetMaterial(Material("hud/radio.png"))
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        surface.DrawTexturedRect(Scale(10), Scale(7), Scale(26), Scale(26))
        draw.SimpleText(headerText, "rRadio.Roboto6", Scale(40), Scale(20), rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(50))
    searchBox:SetSize(frame:GetWide() - Scale(20), Scale(30))
    searchBox:SetFont("rRadio.Roboto4")
    searchBox:SetPlaceholderText(rRadio.config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetTextColor(rRadio.config.UI.TextColor)
    searchBox:SetDrawBackground(false)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.SearchBoxColor)
        self:DrawTextEntryText(rRadio.config.UI.TextColor, Color(120, 120, 120), rRadio.config.UI.TextColor)
        if self:GetText() == "" then
            draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    searchBox:SetVisible(not settingsMenuOpen)
    searchBox.OnValueChanged = function(self)
        timer.Create("rRadio.SearchDebounce", 0.15, 1, function()
            if IsValid(frame) then populateList(stationListPanel, backButton, searchBox, false) end
        end)
    end
    searchBox.OnGetFocus = function() isSearching = true end
    searchBox.OnLoseFocus = function() isSearching = false end

    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(5), Scale(90))
    stationListPanel:SetSize(frame:GetWide() - Scale(10), frame:GetTall() - Scale(180))
    stationListPanel:SetVisible(not settingsMenuOpen)
    rRadio.interface.StyleVBar(stationListPanel:GetVBar())

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), frame:GetTall() - Scale(70))
    stopButton:SetSize(frame:GetWide() / 3, Scale(36))
    stopButton:SetText(rRadio.config.Lang["StopRadio"] or "STOP")
    stopButton:SetFont("rRadio.Roboto4")
    stopButton:SetTextColor(rRadio.config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and rRadio.config.UI.CloseButtonHoverColor or rRadio.config.UI.CloseButtonColor)
    end
    stopButton.DoClick = function()
        surface.PlaySound("buttons/button6.wav")
        local entity = LocalPlayer().currentRadioEntity
        if IsValid(entity) then
            net.Start("rRadio.StopStation")
            net.WriteEntity(entity)
            net.SendToServer()
            currentlyPlayingStations[entity] = nil
            populateList(stationListPanel, backButton, searchBox, false)
        end
    end

    local volumePanel = vgui.Create("DPanel", frame)
    volumePanel:SetPos(Scale(20) + frame:GetWide() / 3, frame:GetTall() - Scale(70))
    volumePanel:SetSize(frame:GetWide() - Scale(30) - frame:GetWide() / 3, Scale(36))
    volumePanel.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, rRadio.config.UI.CloseButtonColor) end

    local volumeIcon = vgui.Create("DImage", volumePanel)
    volumeIcon:SetPos(Scale(8), (volumePanel:GetTall() - Scale(24)) / 2)
    volumeIcon:SetSize(Scale(24), Scale(24))
    volumeIcon.Paint = function(self, w, h)
        surface.SetDrawColor(rRadio.config.UI.TextColor)
        local mat = self:GetMaterial()
        if mat then surface.SetMaterial(mat) surface.DrawTexturedRect(0, 0, w, h) end
    end

    local function updateVolumeIcon(volumeIcon, value)
        if not IsValid(volumeIcon) then return end
        local maxVol = rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0
        value = math.min(type(value) == "function" and value() or value, maxVol)
        volumeIcon:SetMaterial(value < 0.01 and VOLUME_ICONS.MUTE or value <= 0.65 and VOLUME_ICONS.LOW or VOLUME_ICONS.HIGH)
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume = IsValid(entity) and entity:GetNWFloat("Volume", (rRadio.interface.getEntityConfig(entity) or {}).Volume and (rRadio.interface.getEntityConfig(entity).Volume() or 0.5) or 0.5) or 0.5
    entityVolumes[entity] = currentVolume
    updateVolumeIcon(volumeIcon, currentVolume)

    local volumeSlider = vgui.Create("DNumSlider", volumePanel)
    volumeSlider:SetPos(Scale(40), Scale(5))
    volumeSlider:SetSize(volumePanel:GetWide() - Scale(50), volumePanel:GetTall() - Scale(10))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0)
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)
    volumeSlider.Slider.Paint = function(self, w, h) draw.RoundedBox(6, 0, h / 2 - 3, w, 12, rRadio.config.UI.TextColor) end
    volumeSlider.Slider.Knob.Paint = function(self, w, h) draw.RoundedBox(10, 0, Scale(-2), w * 1.5, h * 1.5, rRadio.config.UI.BackgroundColor) end
    volumeSlider.TextArea:SetVisible(false)
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then return end
        entity = rRadio.utils.IsBoombox(entity) and entity or rRadio.utils.GetVehicle(entity)
        local maxVol = rRadio.config.MaxVolume and rRadio.config.MaxVolume() or 1.0
        value = math.min(value, maxVol)
        entityVolumes[entity] = value
        if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:SetVolume(value)
        end
        updateVolumeIcon(volumeIcon, value)
        pendingVolume = value
        pendingEntity = entity
        timer.Create(VOLUME_DEBOUNCE_TIMER, 0.08, 1, function()
            if IsValid(pendingEntity) then
                net.Start("rRadio.SetRadioVolume")
                net.WriteEntity(pendingEntity)
                net.WriteFloat(pendingVolume)
                net.SendToServer()
            end
        end)
    end

    local closeButton = rRadio.interface.MakeNavButton(frame, frame:GetWide() - Scale(30), Scale(7), Scale(24), "hud/close.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        frame:Close()
    end)
    local settingsButton = rRadio.interface.MakeNavButton(frame, closeButton:GetX() - Scale(28), Scale(7), Scale(24), "hud/settings.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        settingsMenuOpen = true
        openSettingsMenu(currentFrame, backButton)
        backButton:SetVisible(true)
        backButton:SetEnabled(true)
        searchBox:SetVisible(false)
        stationListPanel:SetVisible(false)
    end)
    local backButton = rRadio.interface.MakeNavButton(frame, settingsButton:GetX() - Scale(28), Scale(7), Scale(24), "hud/return.png", function()
        surface.PlaySound("buttons/lightswitch2.wav")
        if settingsMenuOpen then
            settingsMenuOpen = false
            if IsValid(settingsFrame) then settingsFrame:Remove() end
            searchBox:SetVisible(true)
            stationListPanel:SetVisible(true)
            stationDataLoaded = false
            LoadStationData()
            populateList(stationListPanel, backButton, searchBox, true)
        elseif selectedCountry or favoritesMenuOpen then
            selectedCountry = nil
            favoritesMenuOpen = false
            populateList(stationListPanel, backButton, searchBox, true)
        end
        backButton:SetVisible(selectedCountry ~= nil or settingsMenuOpen)
        backButton:SetEnabled(selectedCountry ~= nil or settingsMenuOpen)
    end)
    backButton:SetVisible(settingsMenuOpen or selectedCountry)
    backButton:SetEnabled(settingsMenuOpen or selectedCountry)

    if not settingsMenuOpen then populateList(stationListPanel, backButton, searchBox, true) else openSettingsMenu(currentFrame, backButton) end
    searchBox.OnChange = function(self) populateList(stationListPanel, backButton, searchBox, false) end
end

hook.Add("Think", "rRadio.OpenCarRadioMenu", function()
    local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local ply = LocalPlayer()
    local currentTime = CurTime()
    if not (input.IsKeyDown(openKey) and not ply:IsTyping() and currentTime - lastKeyPress > keyPressDelay) then return end
    lastKeyPress = currentTime
    if radioMenuOpen and not isSearching then
        surface.PlaySound("buttons/lightswitch2.wav")
        currentFrame:Close()
        return
    end
    local vehicle = ply:GetVehicle()
    if IsValid(vehicle) then
        local mainVehicle = rRadio.utils.GetVehicle(vehicle)
        if IsValid(mainVehicle) and hook.Run("rRadio.CanOpenMenu", ply, mainVehicle) ~= false and (not rRadio.config.DriverPlayOnly or mainVehicle:GetDriver() == ply) and not rRadio.utils.isSitAnywhereSeat(mainVehicle) then
            ply.currentRadioEntity = mainVehicle
            openRadioMenu()
        end
    end
end)

net.Receive("rRadio.UpdateRadioStatus", function()
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local isPlaying = net.ReadBool()
    local status = net.ReadString()
    if IsValid(entity) then
        rRadio.cl.BoomboxStatuses[entity:EntIndex()] = { stationStatus = status, stationName = stationName }
        entity:SetNWString("Status", status)
        entity:SetNWString("StationName", stationName)
        entity:SetNWBool("IsPlaying", isPlaying)
        currentlyPlayingStations[entity] = status == "playing" and {name = stationName} or nil
    end
end)

net.Receive("rRadio.PlayStation", function()
    if not GetConVar("rammel_rradio_enabled"):GetBool() then return end
    local entity = rRadio.interface.GetVehicleEntity(net.ReadEntity())
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()
    if rRadio.config.SecureStationLoad and not IsUrlAllowed(url) then return end
    local currentCount = rRadio.interface.updateStationCount()
    if not rRadio.cl.radioSources[entity] and currentCount >= MAX_CLIENT_STATIONS then return end
    if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
        rRadio.cl.radioSources[entity]:Stop()
        rRadio.cl.radioSources[entity] = nil
    end
    sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
        if IsValid(station) and IsValid(entity) then
            station:SetPos(entity:GetPos())
            station:SetVolume(volume)
            station:Play()
            rRadio.cl.radioSources[entity] = station
            local cfg = rRadio.interface.getEntityConfig(entity)
            if cfg then station:Set3DFadeDistance(cfg.MinVolumeDistance(), cfg.MaxHearingDistance()) end
        end
    end)
end)

net.Receive("rRadio.StopStation", function()
    local entity = rRadio.interface.GetVehicleEntity(net.ReadEntity())
    if IsValid(entity) then
        if rRadio.cl.radioSources[entity] and IsValid(rRadio.cl.radioSources[entity]) then
            rRadio.cl.radioSources[entity]:Stop()
            rRadio.cl.radioSources[entity] = nil
            entityVolumes[entity] = nil
        end
        if rRadio.utils.IsBoombox(entity) then rRadio.utils.clearRadioStatus(entity) end
    end
end)

hook.Add("Think", "rRadio.UpdateAllStations", function()
    for ent, station in pairs(rRadio.cl.radioSources) do
        if not IsValid(ent) or not IsValid(station) then
            if IsValid(station) then station:Stop() end
            rRadio.cl.radioSources[ent] = nil
        else
            local actual = ent:IsVehicle() and (ent:GetParent() or ent) or ent
            station:SetPos(actual:GetPos())
            local plyPos = LocalPlayer():GetPos()
            local entPos = actual:GetPos()
            local distSqr = plyPos:DistToSqr(entPos)
            local inCar = actual:IsVehicle() and (LocalPlayer():GetVehicle() == ent or table.HasValue(ents.FindByClass("prop_vehicle_prisoner_pod"), function(pod) return IsValid(pod) and pod:GetParent() == actual and pod:GetDriver() == LocalPlayer() end))
            rRadio.interface.updateRadioVolume(station, distSqr, inCar, actual)
        end
    end
end)

net.Receive("rRadio.OpenMenu", function()
    local ent = net.ReadEntity()
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        LocalPlayer().currentRadioEntity = ent
        if not radioMenuOpen then openRadioMenu() end
    end
end)

net.Receive("rRadio.PlayVehicleAnimation", function()
    rRadio.DevPrint("Received car radio message")
    timer.Simple(0, function() rRadio.interface.DisplayVehicleEnterAnimation(net.ReadEntity(), net.ReadBool()) end)
end)

net.Receive("rRadio.SetConfigUpdate", function()
    for entity, source in pairs(rRadio.cl.radioSources) do
        if IsValid(entity) and IsValid(source) then
            source:SetVolume(rRadio.interface.ClampVolume(entityVolumes[entity] or (rRadio.interface.getEntityConfig(entity).Volume() or 0.5)))
        end
    end
end)

hook.Add("EntityRemoved", "rRadio.CleanupRadioStationCount", function(entity)
    if rRadio.cl.radioSources[entity] then
        if IsValid(rRadio.cl.radioSources[entity]) then rRadio.cl.radioSources[entity]:Stop() end
        rRadio.cl.radioSources[entity] = nil
    end
end)

if not timer.Exists("ValidateStationCount") then
    timer.Create("ValidateStationCount", 30, 0, function()
        local actualCount = 0
        for ent, source in pairs(rRadio.cl.radioSources) do
            if IsValid(ent) and IsValid(source) then actualCount = actualCount + 1 else rRadio.cl.radioSources[ent] = nil end
        end
    end)
end

hook.Add("ShutDown", "rRadio.CleanupValidateTimer", function()
    if timer.Exists("ValidateStationCount") then timer.Remove("ValidateStationCount") end
end)

rRadio.interface.loadFavorites()
hook.Add("EntityRemoved", "rRadio.BoomboxCleanup", function(ent)
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then rRadio.cl.BoomboxStatuses[ent:EntIndex()] = nil end
end)

hook.Add("VehicleChanged", "rRadio.ClearRadioEntity", function(ply, old, new)
    if ply == LocalPlayer() and not new then ply.currentRadioEntity = nil end
end)

hook.Add("EntityRemoved", "rRadio.ClearRadioEntity", function(ent)
    if ent == LocalPlayer().currentRadioEntity then LocalPlayer().currentRadioEntity = nil end
end)

hook.Add("InitPostEntity", "rRadio.ApplySettingsOnJoin", function()
    rRadio.addClConVars()
    rRadio.interface.loadSavedSettings()
end)

rRadio.clCoreLoaded = true
