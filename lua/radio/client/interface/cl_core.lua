if CLIENT then
    hook.Remove("Think",          "rRadio.OpenCarRadioMenu")
    hook.Remove("Think",          "rRadio.UpdateAllStations")
    hook.Remove("EntityRemoved",  "rRadio.CleanupRadioStationCount")
    hook.Remove("EntityRemoved",  "rRadio.BoomboxCleanup")
    hook.Remove("EntityRemoved",  "rRadio.ClearRadioEntity")
    hook.Remove("VehicleChanged", "rRadio.ClearRadioEntity")
    hook.Remove("InitPostEntity", "rRadio.ApplySettingsOnJoin")
    timer.Remove("ValidateStationCount")
end

BoomboxStatuses = BoomboxStatuses or {}
currentRadioSources = currentRadioSources or {}
local entityVolumes = entityVolumes or {}

local currentFrame = nil
local settingsMenuOpen = false
local openRadioMenu
local lastKeyPress = 0
local keyPressDelay = 0.2
local favoritesMenuOpen = false
local MAX_CLIENT_STATIONS = 10
local activeStationCount = 0
local selectedCountry = nil
local radioMenuOpen = false
local lastMessageTime = -math.huge
local lastStationSelectTime = 0
local currentlyPlayingStations = {}
local formattedCountryNames = {}
local stationDataLoaded = false
local isSearching = false

local VOLUME_ICONS = {
    MUTE = Material("hud/vol_mute.png", "smooth"),
    LOW = Material("hud/vol_down.png", "smooth"),
    HIGH = Material("hud/vol_up.png", "smooth")
}

local function Scale(value)
    return value * (ScrW() / 2560)
end

local function createFonts()
    surface.CreateFont(
        "Roboto18",
        {
            font = "Roboto",
            size = ScreenScale(5),
            weight = 500
        }
    )
    surface.CreateFont(
        "HeaderFont",
        {
            font = "Roboto",
            size = ScreenScale(8),
            weight = 700
        }
    )
end

createFonts()

local function toggleFavorite(list, key, subkey)
    if subkey then
        list[key] = list[key] or {}
        if list[key][subkey] then
            list[key][subkey] = nil
            if not next(list[key]) then
                list[key] = nil
            end
        else
            list[key][subkey] = true
        end
    else
        if list[key] then
            list[key] = nil
        else
            list[key] = true
        end
    end
    rRadio.interface.saveFavorites()
end

local function createStarIcon(parent, country, station, updateList)
    local starIcon = vgui.Create("DImageButton", parent)
    starIcon:SetSize(Scale(24), Scale(24))
    starIcon:SetPos(Scale(8), (Scale(40) - Scale(24)) / 2)
    local isFavorite =
        station and (rRadio.interface.favoriteStations[country] and rRadio.interface.favoriteStations[country][station.name]) or
        (not station and rRadio.interface.favoriteCountries[country])
    starIcon:SetImage(isFavorite and "hud/star_full.png" or "hud/star.png")
    starIcon.DoClick = function()
        if station then
            toggleFavorite(rRadio.interface.favoriteStations, country, station.name)
        else
            toggleFavorite(rRadio.interface.favoriteCountries, country)
        end
        local newIsFavorite =
            station and (rRadio.interface.favoriteStations[country] and rRadio.interface.favoriteStations[country][station.name]) or
            (not station and rRadio.interface.favoriteCountries[country])
        starIcon:SetImage(newIsFavorite and "hud/star_full.png" or "hud/star.png")
        if updateList then
            updateList()
        end
    end
    return starIcon
end

local function MakePlayableStationButton(parent, station, displayText, updateList, backButton, searchBox, resetSearch)
    local btn = rRadio.interface.MakeStationButton(parent)
    btn.Paint = function(self, w, h)
        local entity = LocalPlayer().currentRadioEntity
        local isPlaying = IsValid(entity) and currentlyPlayingStations[entity] and currentlyPlayingStations[entity].name == station.name
        draw.RoundedBox(8, 0, 0, w, h, isPlaying and rRadio.config.UI.PlayingButtonColor or rRadio.config.UI.ButtonColor)
        if not isPlaying and self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonHoverColor)
        end
        local text = displayText
        surface.SetFont("Roboto18")
        local regionLeft = Scale(8 + 24 + 8)
        local rightMargin = Scale(8)
        local availWidth = w - regionLeft - rightMargin
        local outputText = rRadio.interface.TruncateText(text, "Roboto18", availWidth)
        local textWidth = surface.GetTextSize(outputText)
        local x = w * 0.5
        if x - textWidth * 0.5 < regionLeft then x = regionLeft + textWidth * 0.5
        elseif x + textWidth * 0.5 > w - rightMargin then x = w - rightMargin - textWidth * 0.5 end
        draw.SimpleText(outputText, "Roboto18", x, h/2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = function()
        local currentTime = CurTime()
        if currentTime - lastStationSelectTime < 2 then return end
        surface.PlaySound("buttons/button17.wav")
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then return end
        if currentlyPlayingStations[entity] then
            net.Start("StopCarRadioStation") net.WriteEntity(entity) net.SendToServer()
        end
        local entityConfig = rRadio.interface.getEntityConfig(entity)
        local volume = entityVolumes[entity] or (entityConfig and entityConfig.Volume()) or 0.5
        timer.Simple(0, function()
            if not IsValid(entity) then return end
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(station.name)
            net.WriteString(station.url)
            net.WriteFloat(volume)
            net.SendToServer()
            currentlyPlayingStations[entity] = station
            lastStationSelectTime = currentTime
            updateList()
        end)
    end
    return btn
end

local StationData = {}
local function LoadStationData()
    if stationDataLoaded then
        return
    end
    StationData = {}
    local files = file.Find("radio/client/stations/*.lua", "LUA")
    for _, f in ipairs(files) do
        local data = include("radio/client/stations/" .. f)
        if data then
            for country, stations in pairs(data) do
                local baseCountry = country:gsub("_(%d+)$", "")
                if not StationData[baseCountry] then
                    StationData[baseCountry] = {}
                end
                for _, station in ipairs(stations) do
                    table.insert(StationData[baseCountry], {name = station.n, url = station.u})
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
    -- Only called if rRadio.config.SecureStationLoad is enabled

    if not StationData then
        return false
    end

    for countryCode, stationList in pairs(StationData) do
        for _, stationData in ipairs(stationList) do
            if stationData.url == urlToCheck then
                return true
            end
        end
    end
    local favorites = rRadio.interface.favoriteStations or {}
    for country, favData in pairs(favorites) do
        for stationName, isFavorite in pairs(favData) do
            if isFavorite and StationData[country] then
                for _, station in ipairs(StationData[country]) do
                    if station.name == stationName and station.url == urlToCheck then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    if not stationListPanel then
        return
    end
    stationListPanel:Clear()
    if resetSearch then
        searchBox:SetText("")
    end
    local filterText = searchBox:GetText():lower()
    local lang = rRadio.LanguageManager.currentLanguage
    local function updateList()
        populateList(stationListPanel, backButton, searchBox, false)
    end
    if selectedCountry == nil then
        local hasFavorites = false
        for country, stations in pairs(rRadio.interface.favoriteStations) do
            for stationName, isFavorite in pairs(stations) do
                if isFavorite then
                    hasFavorites = true
                    break
                end
            end
            if hasFavorites then
                break
            end
        end
        if hasFavorites then
            local topSeparator = vgui.Create("DPanel", stationListPanel)
            topSeparator:Dock(TOP)
            topSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            topSeparator:SetTall(Scale(2))
            topSeparator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, rRadio.config.UI.ButtonColor)
            end
            local favoritesButton = vgui.Create("DButton", stationListPanel)
            favoritesButton:Dock(TOP)
            favoritesButton:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            favoritesButton:SetTall(Scale(40))
            favoritesButton:SetText(rRadio.config.Lang["FavoriteStations"] or "Favorite Stations")
            favoritesButton:SetFont("Roboto18")
            favoritesButton:SetTextColor(rRadio.config.UI.TextColor)
            favoritesButton.Paint = function(self, w, h)
                local bgColor = self:IsHovered() and rRadio.config.UI.ButtonHoverColor or rRadio.config.UI.ButtonColor
                draw.RoundedBox(8, 0, 0, w, h, bgColor)
                surface.SetMaterial(Material("hud/star_full.png"))
                surface.SetDrawColor(rRadio.config.UI.TextColor)
                surface.DrawTexturedRect(Scale(10), h / 2 - Scale(12), Scale(24), Scale(24))
            end
            favoritesButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = "favorites"
                favoritesMenuOpen = true
                if backButton then
                    backButton:SetVisible(true)
                    backButton:SetEnabled(true)
                end
                populateList(stationListPanel, backButton, searchBox, true)
            end
            local bottomSeparator = vgui.Create("DPanel", stationListPanel)
            bottomSeparator:Dock(TOP)
            bottomSeparator:DockMargin(Scale(5), Scale(5), Scale(5), Scale(5))
            bottomSeparator:SetTall(Scale(2))
            bottomSeparator.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, rRadio.config.UI.ButtonColor)
            end
        end
        local countries = {}
        for country, _ in pairs(StationData) do
            local formattedCountry =
                country:gsub("_", " "):gsub(
                "(%a)([%w_']*)",
                function(first, rest)
                    return first:upper() .. rest:lower()
                end
            )

            local translatedCountry = rRadio.LanguageManager:GetCountryTranslation(formattedCountry) or formattedCountry
            if filterText == "" or translatedCountry:lower():find(filterText, 1, true) then
                table.insert(
                    countries,
                    {
                        original = country,
                        translated = translatedCountry,
                        isPrioritized = rRadio.interface.favoriteCountries[country]
                    }
                )
            end
        end
        table.sort(
            countries,
            function(a, b)
                if a.isPrioritized ~= b.isPrioritized then
                    return a.isPrioritized
                end
                return a.translated < b.translated
            end
        )
        for _, country in ipairs(countries) do
            local countryButton = rRadio.interface.MakeStationButton(stationListPanel, nil)
            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, rRadio.config.UI.ButtonHoverColor)
                end
                local text = country.translated
                surface.SetFont("Roboto18")
                local regionLeft = Scale(8 + 24 + 8)
                local rightMargin = Scale(8)
                local availWidth = w - regionLeft - rightMargin
                local outputText = rRadio.interface.TruncateText(text, "Roboto18", availWidth)
                local textWidth = surface.GetTextSize(outputText)
                local x = w * 0.5
                if x - textWidth * 0.5 < regionLeft then
                    x = regionLeft + textWidth * 0.5
                elseif x + textWidth * 0.5 > w - rightMargin then
                    x = w - rightMargin - textWidth * 0.5
                end
                draw.SimpleText(outputText, "Roboto18", x, h / 2, rRadio.config.UI.TextColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            createStarIcon(countryButton, country.original, nil, updateList)
            countryButton.DoClick = function()
                surface.PlaySound("buttons/button3.wav")
                selectedCountry = country.original
                if backButton then
                    backButton:SetVisible(true)
                end
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
        if backButton then
            backButton:SetVisible(false)
            backButton:SetEnabled(false)
        end
    elseif selectedCountry == "favorites" then
        local favoritesList = {}
        for country, stations in pairs(rRadio.interface.favoriteStations) do
            if StationData[country] then
                for _, station in ipairs(StationData[country]) do
                    if stations[station.name] and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                        local translatedName = rRadio.utils.FormatAndTranslateCountry(country)
                        table.insert(
                            favoritesList,
                            {
                                station = station,
                                country = country,
                                countryName = translatedName
                            }
                        )
                    end
                end
            end
        end
        table.sort(
            favoritesList,
            function(a, b)
                if a.countryName == b.countryName then
                    return a.station.name < b.station.name
                end
                return a.countryName < b.countryName
            end
        )
        for _, favorite in ipairs(favoritesList) do
            local stationButton = MakePlayableStationButton(
                stationListPanel,
                favorite.station,
                favorite.countryName .. " - " .. favorite.station.name,
                updateList,
                backButton,
                searchBox,
                false
            )
            createStarIcon(stationButton, favorite.country, favorite.station, updateList)
        end
    else
        local stations = StationData[selectedCountry] or {}
        local favoriteStationsList = {}
        for _, station in ipairs(stations) do
            if station and station.name and (filterText == "" or station.name:lower():find(filterText, 1, true)) then
                local isFavorite = rRadio.interface.favoriteStations[selectedCountry] and rRadio.interface.favoriteStations[selectedCountry][station.name]
                table.insert(favoriteStationsList, {station = station, favorite = isFavorite})
            end
        end
        table.sort(
            favoriteStationsList,
            function(a, b)
                if a.favorite ~= b.favorite then
                    return a.favorite
                end
                return (a.station.name or "") < (b.station.name or "")
            end
        )
        for _, stationData in ipairs(favoriteStationsList) do
            local station = stationData.station
            local stationButton = MakePlayableStationButton(
                stationListPanel,
                station,
                station.name,
                updateList,
                backButton,
                searchBox,
                false
            )
            createStarIcon(stationButton, selectedCountry, station, updateList)
        end
        if backButton then
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
        end
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
        header:SetFont("Roboto18")
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
        label:SetFont("Roboto18")
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
        dropdown:SetFont("Roboto18")
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
                option:SetFont("Roboto18")
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
        label:SetFont("Roboto18")
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
    local keyChoices = {}
    if rRadio.keyCodeMapping then
        for keyCode, keyName in pairs(rRadio.keyCodeMapping) do
            table.insert(keyChoices, {name = keyName, data = keyCode})
        end
        table.sort(
            keyChoices,
            function(a, b)
                return a.name < b.name
            end
        )
    else
        table.insert(keyChoices, {name = "K", data = KEY_K})
    end
    local currentKey = GetConVar("rammel_rradio_menu_key"):GetInt()
    local currentKeyName = (rRadio.keyCodeMapping and rRadio.keyCodeMapping[currentKey]) or "K"
    addDropdown(
        rRadio.config.Lang["SelectKey"] or "Select Key",
        keyChoices,
        currentKeyName,
        function(_, _, _, data)
            RunConsoleCommand("rammel_rradio_menu_key", data)
        end
    )
    addHeader(rRadio.config.Lang["GeneralOptions"] or "General Options")
    addCheckbox(rRadio.config.Lang["ShowCarMessages"] or "Show Car Radio Animation",
                "rammel_rradio_vehicle_animation",
                GetConVar("rammel_rradio_vehicle_animation"):GetBool())
    addCheckbox(rRadio.config.Lang["ShowBoomboxHUD"] or "Show Boombox HUD",
                "rammel_rradio_boombox_hud",
                GetConVar("rammel_rradio_boombox_hud"):GetBool())
    if LocalPlayer():IsSuperAdmin() then
        local currentEntity = LocalPlayer().currentRadioEntity
        local isBoombox =
            IsValid(currentEntity) and
            (currentEntity:GetClass() == "boombox" or currentEntity:GetClass() == "golden_boombox")
        if isBoombox then
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
                        net.Start("MakeBoomboxPermanent")
                        net.WriteEntity(currentEntity)
                        net.SendToServer()
                    else
                        net.Start("RemoveBoomboxPermanent")
                        net.WriteEntity(currentEntity)
                        net.SendToServer()
                    end
                end
            )
            net.Receive(
                "BoomboxPermanentConfirmation",
                function()
                    local message = net.ReadString()
                    chat.AddText(Color(0, 255, 0), "[Boombox] ", Color(255, 255, 255), message)
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
                openRadioMenu(openSettings)
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
            "HeaderFont",
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
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(rRadio.config.Lang and rRadio.config.Lang["SearchPlaceholder"] or "Search")
    searchBox:SetTextColor(rRadio.config.UI.TextColor)
    searchBox:SetDrawBackground(false)
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
    local function createAnimatedButton(parent, x, y, w, h, text, textColor, bgColor, hoverColor, clickFunc)
        local button = vgui.Create("DButton", parent)
        button:SetPos(x, y)
        button:SetSize(w, h)
        button:SetText(text)
        button:SetTextColor(textColor)
        button.bgColor = bgColor
        button.hoverColor = hoverColor
        button.lerp = 0
        button.Paint = function(self, w, h)
            local color = rRadio.interface.LerpColor(self.lerp, self.bgColor, self.hoverColor)
            draw.RoundedBox(8, 0, 0, w, h, color)
        end
        button.Think = function(self)
            if self:IsHovered() then
                self.lerp = math.Approach(self.lerp, 1, FrameTime() * 5)
            else
                self.lerp = math.Approach(self.lerp, 0, FrameTime() * 5)
            end
        end
        button.DoClick = clickFunc
        return button
    end
    local stopButton =
        createAnimatedButton(
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
                net.Start("StopCarRadioStation")
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
    volumeIcon:SetMaterial(VOLUME_ICONS.HIGH)
    local function updateVolumeIcon(volumeIcon, value)
        if not IsValid(volumeIcon) then
            return
        end
        local iconMat
        if type(value) == "function" then
            value = value()
        end
        if value < 0.01 then
            iconMat = VOLUME_ICONS.MUTE
        elseif value <= 0.65 then
            iconMat = VOLUME_ICONS.LOW
        else
            iconMat = VOLUME_ICONS.HIGH
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
        currentVolume = math.min(currentVolume, rRadio.config.MaxVolume())
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
    volumeSlider:SetMax(rRadio.config.MaxVolume())
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(currentVolume)
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, h / 2 - 4, w, 16, rRadio.config.UI.TextColor)
    end
    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, Scale(-2), w * 2, h * 2, rRadio.config.UI.BackgroundColor)
    end
    volumeSlider.TextArea:SetVisible(false)
    local lastServerUpdate = 0
    volumeSlider.OnValueChanged = function(_, value)
        local entity = LocalPlayer().currentRadioEntity
        if not IsValid(entity) then
            return
        end

        if rRadio.utils.IsBoombox(entity) then
            entity = entity
        else
            entity = rRadio.utils.GetVehicle(entity)
        end

        value = math.min(value, rRadio.config.MaxVolume())
        entityVolumes[entity] = value
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:SetVolume(value)
        end
        updateVolumeIcon(volumeIcon, value)
        local currentTime = CurTime()
        if currentTime - lastServerUpdate >= 0.1 then
            lastServerUpdate = currentTime
            net.Start("UpdateRadioVolume")
            net.WriteEntity(entity)
            net.WriteFloat(value)
            net.SendToServer()
        end
    end
    local buttonSize = Scale(25)
    local topMargin = Scale(7)
    local buttonPadding = Scale(5)
    local closeButton =
        createAnimatedButton(
        frame,
        frame:GetWide() - buttonSize - Scale(10),
        topMargin,
        buttonSize,
        buttonSize,
        "",
        rRadio.config.UI.TextColor,
        Color(0, 0, 0, 0),
        rRadio.config.UI.ButtonHoverColor,
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            frame:Close()
        end
    )
    closeButton.Paint = function(self, w, h)
        surface.SetMaterial(Material("hud/close.png"))
        surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
        surface.DrawTexturedRect(0, 0, w, h)
    end
    local settingsButton =
        createAnimatedButton(
        frame,
        closeButton:GetX() - buttonSize - buttonPadding,
        topMargin,
        buttonSize,
        buttonSize,
        "",
        rRadio.config.UI.TextColor,
        Color(0, 0, 0, 0),
        rRadio.config.UI.ButtonHoverColor,
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            settingsMenuOpen = true
            openSettingsMenu(currentFrame, backButton)
            backButton:SetVisible(true)
            backButton:SetEnabled(true)
            searchBox:SetVisible(false)
            stationListPanel:SetVisible(false)
        end
    )
    settingsButton.Paint = function(self, w, h)
        surface.SetMaterial(Material("hud/settings.png"))
        surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
        surface.DrawTexturedRect(0, 0, w, h)
    end
    backButton =
        createAnimatedButton(
        frame,
        settingsButton:GetX() - buttonSize - buttonPadding,
        topMargin,
        buttonSize,
        buttonSize,
        "",
        rRadio.config.UI.TextColor,
        Color(0, 0, 0, 0),
        rRadio.config.UI.ButtonHoverColor,
        function()
            surface.PlaySound("buttons/lightswitch2.wav")
            if settingsMenuOpen then
                settingsMenuOpen = false
                if IsValid(settingsFrame) then
                    settingsFrame:Remove()
                    settingsFrame = nil
                end
                searchBox:SetVisible(true)
                stationListPanel:SetVisible(true)
                stationDataLoaded = false
                LoadStationData()
                timer.Simple(
                    0,
                    function()
                        populateList(stationListPanel, backButton, searchBox, true)
                    end
                )
                backButton:SetVisible(selectedCountry ~= nil or favoritesMenuOpen)
                backButton:SetEnabled(selectedCountry ~= nil or favoritesMenuOpen)
            elseif selectedCountry or favoritesMenuOpen then
                selectedCountry = nil
                favoritesMenuOpen = false
                backButton:SetVisible(false)
                backButton:SetEnabled(false)
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    )
    backButton.Paint = function(self, w, h)
        if self:IsVisible() then
            surface.SetMaterial(Material("hud/return.png"))
            surface.SetDrawColor(ColorAlpha(rRadio.config.UI.TextColor, 255 * (0.5 + 0.5 * self.lerp)))
            surface.DrawTexturedRect(0, 0, w, h)
        end
    end
    backButton:SetVisible((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
    backButton:SetEnabled((selectedCountry ~= nil and selectedCountry ~= "") or settingsMenuOpen)
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
        local openKey = GetConVar("rammel_rradio_menu_key"):GetInt()
        local ply = LocalPlayer()
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
                if hook.Run("rRadioCanOpenMenu", ply, mainVehicle) == false then return end
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
    "UpdateRadioStatus",
    function()
        local entity = net.ReadEntity()
        local stationName = net.ReadString()
        local isPlaying = net.ReadBool()
        local status = net.ReadString()
        if IsValid(entity) then
            BoomboxStatuses[entity:EntIndex()] = {
                stationStatus = status,
                stationName = stationName
            }
            entity:SetNWString("Status", status)
            entity:SetNWString("StationName", stationName)
            entity:SetNWBool("IsPlaying", isPlaying)
            if status == "playing" then
                currentlyPlayingStations[entity] = {name = stationName}
            elseif status == "stopped" then
                currentlyPlayingStations[entity] = nil
            end
        end
    end
)
net.Receive(
    "PlayCarRadioStation",
    function()
        if not GetConVar("rammel_rradio_enabled"):GetBool() then
            return
        end

        local entity = net.ReadEntity()
        entity = rRadio.interface.GetVehicleEntity(entity)
        local stationName = net.ReadString()
        local url = net.ReadString()
        local volume = net.ReadFloat()

        if rRadio.config.SecureStationLoad then
            if not IsUrlAllowed(url) then
                return
            end
        end

        local currentCount = rRadio.interface.updateStationCount()
        if not currentRadioSources[entity] and currentCount >= MAX_CLIENT_STATIONS then
            return
        end
        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:Stop()
            currentRadioSources[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end
        sound.PlayURL(
            url,
            "3d mono",
            function(station, errorID, errorName)
                if IsValid(station) and IsValid(entity) then
                    station:SetPos(entity:GetPos())
                    station:SetVolume(volume)
                    station:Play()
                    currentRadioSources[entity] = station
                    activeStationCount = rRadio.interface.updateStationCount()

                    local cfg = rRadio.interface.getEntityConfig(entity)
                    if cfg then
                        station:Set3DFadeDistance(cfg.MinVolumeDistance(), cfg.MaxHearingDistance())
                    end
                end
            end
        )
    end
)

net.Receive(
    "StopCarRadioStation",
    function()
        local entity = net.ReadEntity()
        if not IsValid(entity) then
            return
        end
        entity = rRadio.interface.GetVehicleEntity(entity)

        if currentRadioSources[entity] and IsValid(currentRadioSources[entity]) then
            currentRadioSources[entity]:Stop()
            currentRadioSources[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end

        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            rRadio.utils.clearRadioStatus(entity)
        end
    end
)

hook.Add(
    "Think",
    "rRadio.UpdateAllStations",
    function()
        for ent, station in pairs(currentRadioSources) do
            if not IsValid(ent) or not IsValid(station) then
                if IsValid(station) then
                    station:Stop()
                end
                currentRadioSources[ent] = nil
                activeStationCount = rRadio.interface.updateStationCount()
            else
                local actual = ent
                if ent:IsVehicle() then
                    local parent = ent:GetParent()
                    if IsValid(parent) then actual = parent end
                end
                station:SetPos(actual:GetPos())
                local plyPos = LocalPlayer():GetPos()
                local entPos = actual:GetPos()
                local distSqr = plyPos:DistToSqr(entPos)
                local inCar = false
                if actual:IsVehicle() then
                    if LocalPlayer():GetVehicle() == ent then
                        inCar = true
                    else
                        for _, pod in ipairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
                            if IsValid(pod) and pod:GetParent() == actual and pod:GetDriver() == LocalPlayer() then
                                inCar = true; break
                            end
                        end
                    end
                end
                rRadio.interface.updateRadioVolume(station, distSqr, inCar, actual)
            end
        end
    end
)
net.Receive(
    "OpenRadioMenu",
    function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then
            return
        end
        local ply = LocalPlayer()
        if ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox" then
            ply.currentRadioEntity = ent
            if not radioMenuOpen then
                openRadioMenu()
            end
        end
    end
)
net.Receive(
    "CarRadioMessage",
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
    "RadioConfigUpdate",
    function()
        for entity, source in pairs(currentRadioSources) do
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
        if currentRadioSources[entity] then
            if IsValid(currentRadioSources[entity]) then
                currentRadioSources[entity]:Stop()
            end
            currentRadioSources[entity] = nil
            activeStationCount = rRadio.interface.updateStationCount()
        end
    end
)
timer.Create(
    "ValidateStationCount",
    30,
    0,
    function()
        local actualCount = 0
        for ent, source in pairs(currentRadioSources) do
            if IsValid(ent) and IsValid(source) then
                actualCount = actualCount + 1
            else
                currentRadioSources[ent] = nil
            end
        end
        activeStationCount = actualCount
    end
)
rRadio.interface.loadFavorites()
hook.Add(
    "EntityRemoved",
    "rRadio.BoomboxCleanup",
    function(ent)
        if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
            BoomboxStatuses[ent:EntIndex()] = nil
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