-- Client-side menu for rRadio

local RRADIO = RRADIO or {}
RRADIO.Menu = RRADIO.Menu or {}

RRADIO.GetFont = getFont

function SafeColor(color)
    return IsColor(color) and color or Color(255, 255, 255)
end

-- Localize global functions for performance
local SortIgnoringThe = rRadio.SortIgnoringThe or function(a, b)
    local function stripThe(str)
        return str:gsub("^The%s+", ""):lower()
    end
    return stripThe(a) < stripThe(b)
end

-- Icons
RRADIO.Icons = {
    BACK = Material("hud/back.png", "smooth mips"),
    SETTINGS = Material("hud/settings.png", "smooth mips"),
    CLOSE = Material("hud/close.png", "smooth mips"),
    STAR_EMPTY = Material("hud/star.png", "smooth mips"),
    STAR_FULL = Material("hud/star_full.png", "smooth mips"),
    DARK_MODE = Material("hud/dark_mode.png", "smooth mips"),
    GITHUB = Material("hud/github.png", "smooth mips"),
}

-- Sounds
RRADIO.Sounds = {
    CLICK = Sound("ui/buttonclick.wav"),
    OPEN = Sound("ui/buttonclickrelease.wav"),
    CLOSE = Sound("ui/buttonclickrelease.wav"),
    SLIDER = Sound("ui/slider.wav"),
}

-- Font cache
local fontCache = {}

-- New helper function for scaled font sizes
local function getScaledFontSize(baseSize)
    local scaleFactor = math.min(ScrW() / 1920, ScrH() / 1080) * 1.5
    return math.Round(baseSize * scaleFactor)
end

-- Updated font cache function
local function getFont(size, isHeading)
    local scaledSize = getScaledFontSize(size)
    local fontName = "rRadio_Roboto_" .. scaledSize .. "_" .. (isHeading and "Black" or "Regular")
    
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = isHeading and "Roboto Black" or "Roboto Bold",
            size = scaledSize,
            weight = isHeading and 900 or 400,
            antialias = true,
        })
        fontCache[fontName] = true
    end
    
    return fontName
end

function RRADIO.Menu:UpdateSearchBarPlaceholder()
    local placeholder = self.currentView == "countries" and "Search countries..." or "Search stations..."
    if IsValid(self.SearchBar) then
        self.SearchBar:SetPlaceholderText(placeholder)
    end
end

-- Optimized CreateButton function
function RRADIO.Menu:CreateButton(text, isFirst, isLast, isFavorite, onFavoriteToggle)
    local button = self.Scroll:Add("DButton")
    button:Dock(TOP)
    button:SetTall(self:GetTall() * 0.06)
    button:DockMargin(5, isFirst and 5 or 0, 5, isLast and 5 or 0)
    button:SetText("")
    button:SetFont(getFont(14, false))
    
    local favoriteButton = vgui.Create("DImageButton", button)
    local iconSize = button:GetTall() * 0.6
    favoriteButton:SetSize(iconSize, iconSize)
    favoriteButton:Dock(LEFT)
    favoriteButton:DockMargin(5, (button:GetTall() - iconSize) / 2, 5, (button:GetTall() - iconSize) / 2)
    
    local colors = RRADIO.GetColors()
    favoriteButton.Paint = function(s, w, h)
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(isFavorite and RRADIO.Icons.STAR_FULL or RRADIO.Icons.STAR_EMPTY)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    favoriteButton.DoClick = function()
        onFavoriteToggle()
        isFavorite = not isFavorite
        surface.PlaySound(RRADIO.Sounds.CLICK)
    end
    
    button.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        local radius = 4
        draw.RoundedBox(radius, 0, 0, w, h, SafeColor(s:IsHovered() and colors.buttonHover or colors.button))
        
        local textX = (w + iconSize) / 2
        local textY = h / 2
        draw.SimpleText(text, getFont(14, false), textX, textY, SafeColor(colors.text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    button.DoClick = function(s)
        surface.PlaySound(RRADIO.Sounds.CLICK)
        if s.OriginalDoClick then
            s:OriginalDoClick()
        end
    end

    return button
end

-- Optimized LoadCountries function
function RRADIO.Menu:LoadCountries()
    self.Scroll:Clear()
    self.currentView = "countries"
    
    self.BackButton:SetVisible(false)
    self.GitHubButton:SetVisible(false) -- Hide GitHub button when not in settings
    self.Title:SetText(rRadio.Config.MenuTitle)
    self.Title:SizeToContents()
    self.Title:Center()

    if IsValid(self.SearchBar) then
        self.SearchBar:SetValue("")
    end
    
    local sortedCountries = {}
    local favoriteCountries = {}
    
    for country in pairs(rRadio.Stations) do
        if rRadio.IsCountryFavorite(country) then
            table.insert(favoriteCountries, country)
        else
            table.insert(sortedCountries, country)
        end
    end
    
    table.sort(favoriteCountries, function(a, b) return SortIgnoringThe(rRadio.FormatCountryName(a), rRadio.FormatCountryName(b)) end)
    table.sort(sortedCountries, function(a, b) return SortIgnoringThe(rRadio.FormatCountryName(a), rRadio.FormatCountryName(b)) end)
    
    self:CreateCountryButtons(favoriteCountries, true)
    self:CreateCountryButtons(sortedCountries, false)
    
    self:UpdateSearchBarPlaceholder()
end

-- New helper function to create country buttons
function RRADIO.Menu:CreateCountryButtons(countries, isFavorite)
    for i, country in ipairs(countries) do
        local formattedCountry = rRadio.FormatCountryName(country)
        local button = self:CreateButton(formattedCountry, i == 1 and (isFavorite or #countries == 0), i == #countries and not isFavorite, isFavorite, function()
            rRadio.ToggleFavoriteCountry(country)
            self:LoadCountries()
        end)
        button.OriginalDoClick = function()
            self:LoadStations(country)
        end
        button.OriginalCountry = country
    end
end

-- Optimized LoadStations function
function RRADIO.Menu:LoadStations(country)
    self.Scroll:Clear()
    self.currentView = "stations"
    self.currentCountry = country

    self.BackButton:SetVisible(true)
    local formattedCountry = rRadio.FormatCountryName(country)
    self.Title:SetText(formattedCountry)
    self.Title:SizeToContents()
    self.Title:Center()

    if IsValid(self.SearchBar) then
        self.SearchBar:SetValue("")
    end

    local favoriteStations = rRadio.GetFavoriteStations(country)
    local sortedStations = {}
    local favoriteStationsList = {}
    
    for i, station in ipairs(rRadio.Stations[country]) do
        if favoriteStations[station.n] then
            table.insert(favoriteStationsList, {index = i, name = station.n})
        else
            table.insert(sortedStations, {index = i, name = station.n})
        end
    end
    
    table.sort(favoriteStationsList, function(a, b) return SortIgnoringThe(a.name, b.name) end)
    table.sort(sortedStations, function(a, b) return SortIgnoringThe(a.name, b.name) end)

    self:CreateStationButtons(favoriteStationsList, country, true)
    self:CreateStationButtons(sortedStations, country, false)
    
    self:UpdateSearchBarPlaceholder()
end

function RRADIO.Menu:CreateStationButtons(stationList, country, isFavorite)
    local addedStations = {}
    for i, stationInfo in ipairs(stationList) do
        if not addedStations[stationInfo.name] then
            local button = self:CreateButton(
                stationInfo.name, 
                i == 1 and (#stationList == 1 or not isFavorite), 
                i == #stationList, 
                isFavorite, 
                function()
                    rRadio.ToggleFavoriteStation(country, stationInfo.name)
                    self:LoadStations(country)
                end
            )
            button.DoClick = function()
                surface.PlaySound(RRADIO.Sounds.CLICK)
                rRadio.PlayStation(self.BoomboxEntity, country, stationInfo.index)
            end
            addedStations[stationInfo.name] = true
        end
    end
end

function RRADIO.Menu:Init()
    local w = math.Clamp(ScrW() * 0.525, 450, 900)
    local h = math.Clamp(ScrH() * 1.05, 600, 1200)
    self:SetSize(w, h)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)

    surface.PlaySound(RRADIO.Sounds.OPEN)

    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateScrollPanel()
    self:CreateControlPanel()

    self:LoadCountries()
    self:UpdateColors()
end

function RRADIO.Menu:CreateHeader()
    self.Header = self:Add("DPanel")
    self.Header:Dock(TOP)
    self.Header:SetTall(self:GetTall() * 0.08)
    self.Header.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBoxEx(8, 0, 0, w, h, SafeColor(colors.bg), true, true, false, false)
        surface.SetDrawColor(SafeColor(colors.divider))
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local margin = math.Round(self:GetWide() * 0.02)
    local buttonSize = math.max(self:GetTall() * 0.04, 20)

    self.BackButton = vgui.Create("DImageButton", self.Header)
    self.BackButton:SetSize(buttonSize, buttonSize)
    self.BackButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(RRADIO.Icons.BACK)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.BackButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        if self.currentView == "settings" then
            self:LoadCountries()
        else
            self:LoadCountries()
        end
    end
    self.BackButton:SetVisible(false)

    self.Title = vgui.Create("DLabel", self.Header)
    self.Title:SetText(rRadio.Config.MenuTitle)
    self.Title:SetFont(getFont(20, true))

    -- Add GitHub button
    self.GitHubButton = vgui.Create("DImageButton", self.Header)
    self.GitHubButton:SetSize(buttonSize, buttonSize)
    self.GitHubButton:SetVisible(false) -- Initially hidden
    self.GitHubButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(RRADIO.Icons.GITHUB)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.GitHubButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        gui.OpenURL("https://github.com/charles-mills/rRadio")
    end

    -- Settings button (existing code)
    self.SettingsButton = vgui.Create("DImageButton", self.Header)
    self.SettingsButton:SetSize(buttonSize, buttonSize)
    self.SettingsButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(RRADIO.Icons.SETTINGS)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.SettingsButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        self:OpenSettings()
    end

    self.CloseButton = vgui.Create("DImageButton", self.Header)
    self.CloseButton:SetSize(buttonSize, buttonSize)
    self.CloseButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(RRADIO.Icons.CLOSE)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.CloseButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLOSE)
        self:Remove()
    end
end

function RRADIO.Menu:CreateSearchBar()
    self.SearchBar = self:Add("DTextEntry")
    self.SearchBar:Dock(TOP)
    self.SearchBar:SetTall(math.max(self:GetTall() * 0.0462, 26))
    local margin = math.Round(self:GetWide() * 0.02)
    self.SearchBar:DockMargin(margin, margin, margin, margin)
    self.SearchBar:SetFont(getFont(15, false))
    self.SearchBar.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(7, 0, 0, w, h, SafeColor(colors.button))
        s:DrawTextEntryText(SafeColor(colors.text), s:GetHighlightColor(), s:GetCursorColor())
        
        -- Draw placeholder text with appropriate color
        if s:GetText() == "" and s:GetPlaceholderText() ~= "" then
            draw.SimpleText(s:GetPlaceholderText(), s:GetFont(), 5, h/2, SafeColor(colors.text_placeholder), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    self.SearchBar.OnChange = function() self:PerformSearch() end
    
    self:UpdateSearchBarPlaceholder()
end

function RRADIO.Menu:CreateScrollPanel()
    self.ScrollBackground = self:Add("DPanel")
    self.ScrollBackground:Dock(FILL)
    local margin = math.Round(self:GetWide() * 0.02)
    self.ScrollBackground:DockMargin(margin, margin, margin, margin)
    self.ScrollBackground.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.scrollBg))
    end

    self.Scroll = self.ScrollBackground:Add("DScrollPanel")
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(margin / 4, margin / 4, margin / 4, margin / 4)
    local scrollBar = self.Scroll:GetVBar()
    scrollBar:SetHideButtons(true)
    scrollBar.Paint = function() end
    scrollBar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, SafeColor(RRADIO.GetColors().accent))
    end
end

function RRADIO.Menu:CreateControlPanel()
    self.ControlPanel = self:Add("DPanel")
    self.ControlPanel:Dock(BOTTOM)
    self.ControlPanel:SetTall(math.max(self:GetTall() * 0.09, 36))
    local margin = math.Round(self:GetWide() * 0.02)
    self.ControlPanel:DockMargin(margin, margin, margin, margin)
    self.ControlPanel.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.button))
    end

    -- Stop button
    self.StopButton = self.ControlPanel:Add("DButton")
    self.StopButton:SetText("")  -- Remove default text
    
    local stopButtonFont = "rRadio_StopButton"
    surface.CreateFont(stopButtonFont, {
        font = "Roboto Black",
        size = 18,
        weight = 900,
        antialias = true,
    })

    self.StopButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(4, 0, 0, w, h, SafeColor(s:IsHovered() and colors.buttonHover or colors.bg))
        
        local text = "STOP"
        local fontSize = 18
        surface.SetFont(stopButtonFont)
        local textWidth, textHeight = surface.GetTextSize(text)
        
        while (textWidth < w * 0.8 and textHeight < h * 0.8) do
            fontSize = fontSize + 1
            surface.CreateFont(stopButtonFont, {
                font = "Roboto Black",
                size = fontSize,
                weight = 900,
                antialias = true,
            })
            surface.SetFont(stopButtonFont)
            textWidth, textHeight = surface.GetTextSize(text)
        end

        draw.SimpleText(text, stopButtonFont, w/2, h/2, SafeColor(colors.accent), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    self.StopButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        rRadio.StopStation(self.BoomboxEntity)
    end
    self.StopButton.OnCursorEntered = function()
        surface.PlaySound(SOUND_HOVER)
    end

    -- Volume control panel
    self.VolumeControlPanel = self.ControlPanel:Add("DPanel")
    self.VolumeControlPanel.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(4, 0, 0, w, h, SafeColor(colors.bg))
    end

    -- Volume icon
    self.VolumeIcon = self.VolumeControlPanel:Add("DPanel")
    self.VolumeIcon:SetSize(36, 36)
    self.VolumeIcon.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.accent))
        surface.SetMaterial(Material("hud/volume.png", "smooth mips"))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    -- Volume slider
    self.VolumeSlider = self.VolumeControlPanel:Add("DPanel")
    self.VolumeSlider:SetTall(12)
    self.VolumeSlider.Value = 1
    self.VolumeSlider.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.divider))
        draw.RoundedBox(8, 0, 0, w * s.Value, h, SafeColor(colors.accent))
    end
    self.VolumeSlider.OnMousePressed = function(s)
        s.Dragging = true
        s:MouseCapture(true)
        surface.PlaySound(RRADIO.Sounds.SLIDER)
    end
    self.VolumeSlider.OnMouseReleased = function(s)
        s.Dragging = false
        s:MouseCapture(false)
        surface.PlaySound(RRADIO.Sounds.SLIDER)
    end
    self.VolumeSlider.Think = function(s)
        if s.Dragging then
            local x = s:ScreenToLocal(gui.MouseX(), 0)
            s.Value = math.Clamp(x / s:GetWide(), 0, 1)
            rRadio.SetVolume(self.BoomboxEntity, s.Value)
        end
    end
end

function RRADIO.Menu:PerformLayout(w, h)
    local margin = math.Round(w * 0.02)
    local buttonSize = math.max(h * 0.04, 20)

    if IsValid(self.BackButton) then
        self.BackButton:SetPos(margin, (self.Header:GetTall() - buttonSize) / 2)
    end

    if IsValid(self.Title) then
        self.Title:SizeToContents()
        self.Title:Center()
    end

    if IsValid(self.GitHubButton) then
        self.GitHubButton:SetPos(w - buttonSize * 3 - margin * 3, (self.Header:GetTall() - buttonSize) / 2)
    end

    if IsValid(self.SettingsButton) then
        self.SettingsButton:SetPos(w - buttonSize * 2 - margin * 2, (self.Header:GetTall() - buttonSize) / 2)
    end

    if IsValid(self.CloseButton) then
        self.CloseButton:SetPos(w - buttonSize - margin, (self.Header:GetTall() - buttonSize) / 2)
    end
    
    if IsValid(self.StopButton) and IsValid(self.VolumeControlPanel) then
        local aspectRatio = w / h
        local stopButtonWidth, volumeControlWidth

        if aspectRatio > 2 then
            -- Ultra-wide layout
            stopButtonWidth = w * 0.15
            volumeControlWidth = w * 0.80
        elseif aspectRatio < 1 then
            -- Vertical layout
            stopButtonWidth = w * 0.25
            volumeControlWidth = w * 0.64
        else
            -- Standard layout
            stopButtonWidth = w * 0.25
            volumeControlWidth = w * 0.64
        end

        local stopButtonHeight = self.ControlPanel:GetTall() - (margin * 2)

        -- Position and size the stop button
        self.StopButton:SetPos(margin, margin)
        self.StopButton:SetSize(stopButtonWidth, stopButtonHeight)

        -- Force the button to repaint to recalculate the font size
        self.StopButton:InvalidateLayout(true)

        -- Position and size the volume control panel
        self.VolumeControlPanel:SetPos(stopButtonWidth + (margin * 2), margin)
        self.VolumeControlPanel:SetSize(volumeControlWidth, stopButtonHeight)

        -- Position the volume icon and slider within the volume control panel
        local iconSize = math.max(18, stopButtonHeight * 0.6)  -- Reduced from 24 to 18
        local sliderHeight = math.max(10, stopButtonHeight * 0.5)  -- Reduced from 15 to 10, and from 0.6 to 0.5
        local innerMargin = math.max(8, stopButtonHeight * 0.2)  -- Reduced from 12 to 8, and from 0.3 to 0.2

        self.VolumeIcon:SetPos(innerMargin, (self.VolumeControlPanel:GetTall() - iconSize) / 2)
        self.VolumeIcon:SetSize(iconSize, iconSize)
        
        local sliderWidth = self.VolumeControlPanel:GetWide() - iconSize - (innerMargin * 3)
        self.VolumeSlider:SetPos(iconSize + (innerMargin * 2), (self.VolumeControlPanel:GetTall() - sliderHeight) / 2)
        self.VolumeSlider:SetSize(sliderWidth, sliderHeight)
    end
end

-- Implement debouncing for search
local searchDebounceTimer = nil
function RRADIO.Menu:PerformSearch()
    if searchDebounceTimer then
        timer.Remove(searchDebounceTimer)
    end
    
    searchDebounceTimer = "rRadio_Search_" .. CurTime()
    timer.Create(searchDebounceTimer, 0.1, 1, function()
        local query = self.SearchBar:GetValue():lower()
        if query == "" then
            if self.currentView == "countries" then
                self:LoadCountries()
            else
                self:LoadStations(self.currentCountry)
            end
            return
        end

        self.Scroll:Clear()

        if self.currentView == "countries" then
            for country, _ in pairs(rRadio.Stations) do
                local formattedCountry = rRadio.FormatCountryName(country)
                if string.find(formattedCountry:lower(), query) then
                    local isFavorite = rRadio.IsCountryFavorite(country)
                    local button = self:CreateButton(formattedCountry, false, false, isFavorite, function()
                        rRadio.ToggleFavoriteCountry(country)
                        self:PerformSearch()  -- Refresh the search results
                    end)
                    button.OriginalDoClick = function()
                        self:LoadStations(country)
                    end
                    button.OriginalCountry = country
                end
            end
        else
            local favoriteStations = rRadio.GetFavoriteStations(self.currentCountry)
            local matchedStations = {}
            local matchedFavorites = {}
            
            for i, station in ipairs(rRadio.Stations[self.currentCountry]) do
                if string.find(station.n:lower(), query) then
                    if favoriteStations[station.n] then
                        table.insert(matchedFavorites, {index = i, name = station.n})
                    else
                        table.insert(matchedStations, {index = i, name = station.n})
                    end
                end
            end
            
            table.sort(matchedFavorites, function(a, b) return SortIgnoringThe(a.name, b.name) end)
            table.sort(matchedStations, function(a, b) return SortIgnoringThe(a.name, b.name) end)

            -- Add matched favorite stations first
            for _, stationInfo in ipairs(matchedFavorites) do
                local button = self:CreateButton(stationInfo.name, false, false, true, function()
                    rRadio.ToggleFavoriteStation(self.currentCountry, stationInfo.name)
                    self:PerformSearch()  -- Refresh the search results
                end)
                button.DoClick = function()
                    surface.PlaySound(RRADIO.Sounds.CLICK)
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, stationInfo.index)
                end
            end

            -- Add matched non-favorite stations
            for _, stationInfo in ipairs(matchedStations) do
                local button = self:CreateButton(stationInfo.name, false, false, false, function()
                    rRadio.ToggleFavoriteStation(self.currentCountry, stationInfo.name)
                    self:PerformSearch()  -- Refresh the search results
                end)
                button.DoClick = function()
                    surface.PlaySound(RRADIO.Sounds.CLICK)
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, stationInfo.index)
                end
            end
        end
    end)
end

function RRADIO.Menu:Paint(w, h)
    local colors = RRADIO.GetColors()
    draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.bg))
end

function RRADIO.Menu:SetBoomboxEntity(entity)
    self.BoomboxEntity = entity
    if IsValid(self.VolumeSlider) then
        local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
        self.VolumeSlider.Value = volume
    end
end

function RRADIO.IsDarkMode()
    return RRADIO.DarkModeConVar:GetBool()
end

function RRADIO.ToggleDarkMode()
    RRADIO.DarkModeConVar:SetBool(not RRADIO.DarkModeConVar:GetBool())
    hook.Run("rRadio_ColorSchemeChanged")
end

function RRADIO.Menu:UpdateColors()
    local colors = RRADIO.GetColors()
    self.Title:SetTextColor(SafeColor(colors.text))
    self.SearchBar:SetTextColor(SafeColor(colors.text))
    self.StopButton:SetTextColor(SafeColor(colors.accent))

    for _, child in pairs(self.Scroll:GetCanvas():GetChildren()) do
        if IsValid(child) and child.Paint then
            child:SetTextColor(SafeColor(colors.text))
        end
    end

    self:InvalidateLayout(true)
    self.SearchBar:InvalidateLayout(true)  -- Force the search bar to repaint

    if self.currentView == "settings" then
        self:PopulateSettings()
    end
end

RRADIO.DarkModeConVar = CreateClientConVar("rradio_dark_mode", "0", true, false, "Toggle dark mode for rRadio")

function RRADIO.GetColors()
    local isDarkMode = RRADIO.IsDarkMode()
    return {
        bg = isDarkMode and Color(18, 18, 18) or Color(255, 255, 255),
        text = isDarkMode and Color(255, 255, 255) or Color(0, 0, 0),
        button = isDarkMode and Color(30, 30, 30) or Color(240, 240, 240),
        buttonHover = isDarkMode and Color(40, 40, 40) or Color(230, 230, 230),
        accent = Color(0, 122, 255),
        text_placeholder = isDarkMode and Color(150, 150, 150) or Color(100, 100, 100),
        -- Add more colors as needed
    }
end

function RRADIO.Menu:OpenSettings()
    self.currentView = "settings"
    self.Scroll:Clear()
    self.BackButton:SetVisible(true)
    self.GitHubButton:SetVisible(true) -- Show GitHub button in settings
    self.Title:SetText("Settings")
    self.Title:SizeToContents()
    self.Title:Center()
    
    self:PopulateSettings()
    self:UpdateColors()
    self:UpdateSearchBarPlaceholder()
end

function RRADIO.Menu:PopulateSettings()
    self.Scroll:Clear()  -- Clear existing settings before repopulating

    -- Dark Mode Toggle
    local darkModeToggle = self.Scroll:Add("DButton")
    darkModeToggle:Dock(TOP)
    darkModeToggle:SetTall(self.Scroll:GetTall() * 0.06)
    darkModeToggle:DockMargin(5, 5, 5, 0)
    darkModeToggle:SetText("")
    darkModeToggle:SetFont(getFont(14, false))

    local iconSize = darkModeToggle:GetTall() * 0.6
    local darkModeIcon = vgui.Create("DImage", darkModeToggle)
    darkModeIcon:SetSize(iconSize, iconSize)
    darkModeIcon:Dock(LEFT)
    darkModeIcon:DockMargin(5, (darkModeToggle:GetTall() - iconSize) / 2, 5, (darkModeToggle:GetTall() - iconSize) / 2)
    darkModeIcon:SetMaterial(RRADIO.Icons.DARK_MODE)

    darkModeToggle.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        local radius = 4
        draw.RoundedBox(radius, 0, 0, w, h, SafeColor(s:IsHovered() and colors.buttonHover or colors.button))
        
        local textX = (w + iconSize) / 2
        local textY = h / 2
        draw.SimpleText("Dark Mode", getFont(14, false), textX, textY, SafeColor(colors.text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Draw toggle indicator
        local toggleSize = h * 0.6
        local toggleX = w - toggleSize - 10
        local toggleY = (h - toggleSize) / 2
        local isDarkMode = RRADIO.IsDarkMode()
        draw.RoundedBox(toggleSize / 2, toggleX, toggleY, toggleSize, toggleSize, SafeColor(isDarkMode and colors.accent or colors.buttonHover))
        draw.RoundedBox(toggleSize / 2, isDarkMode and (toggleX + toggleSize / 2) or toggleX, toggleY, toggleSize / 2, toggleSize, SafeColor(colors.bg))
    end

    darkModeToggle.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        RRADIO.ToggleDarkMode()
        self:UpdateColors()
    end

    -- Add more settings here as needed
end

-- Register the panel
vgui.Register("rRadioMenu", RRADIO.Menu, "DFrame")

-- Public API
function rRadio.OpenMenu(entity)
    if IsValid(rRadio.Menu) then rRadio.Menu:Remove() end
    rRadio.Menu = vgui.Create("rRadioMenu")
    rRadio.Menu:SetBoomboxEntity(entity)
end

-- Networking
net.Receive("rRadio_OpenMenu", function()
    local entity = net.ReadEntity()
    if IsValid(entity) and entity:GetClass() == "ent_rradio" then
        rRadio.OpenMenu(entity)
    end
end)

-- Console command
concommand.Add("rradio_open", function(ply, cmd, args)
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_rradio" then
        rRadio.OpenMenu(tr.Entity)
    else
        ply:ChatPrint("You need to look at a rRadio boombox to open the menu.")
    end
end)

-- Hooks
hook.Add("rRadio_ColorSchemeChanged", "UpdateMenuColors", function()
    if IsValid(rRadio.Menu) then
        rRadio.Menu:UpdateColors()
    end
end)

return RRADIO.Menu