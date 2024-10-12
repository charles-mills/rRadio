-- Client-side menu for rRadio

local RRADIO = RRADIO or {}
RRADIO.Menu = RRADIO.Menu or {}

local function SafeColor(color)
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
    DARK_MODE = Material("hud/dark_mode.png", "smooth mips"),
    CLOSE = Material("hud/close.png", "smooth mips"),
    STAR_EMPTY = Material("hud/star.png", "smooth mips"),
    STAR_FULL = Material("hud/star_full.png", "smooth mips"),
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

local function getFont(size, isHeading)
    local fontName = "rRadio_Roboto_" .. size .. "_" .. (isHeading and "Black" or "Regular")
    
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = isHeading and "Roboto Black" or "Roboto Bold",
            size = math.Round(ScrH() * (size / 1080)),
            weight = isHeading and 900 or 400,
            antialias = true,
        })
        fontCache[fontName] = true
    end
    
    return fontName
end

local function rRadio.FormatCountryName(name)
    return name:gsub("_", " "):gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

-- Optimized CreateButton function
function RRADIO.Menu:CreateButton(text, isFirst, isLast, isFavorite, onFavoriteToggle)
    local button = self.Scroll:Add("DButton")
    button:Dock(TOP)
    button:SetTall(self:GetTall() * 0.08)
    button:DockMargin(5, isFirst and 5 or 0, 5, isLast and 5 or 0)
    button:SetText("")
    button:SetFont(getFont(16, false))
    
    local favoriteButton = vgui.Create("DImageButton", button)
    local iconSize = button:GetTall() * 0.4
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
        draw.SimpleText(text, getFont(16, false), textX, textY, SafeColor(colors.text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
    self.Title:SetText("rRadio")
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
end

function RRADIO.Menu:CreateStationButtons(stationList, country, isFavorite)
    for i, stationInfo in ipairs(stationList) do
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
    end
end

function RRADIO.Menu:Init()
    self:SetSize(ScrW() * 0.4, ScrH() * 0.7)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)

    surface.PlaySound(RRADIO.Sounds.OPEN)  -- Play sound when menu opens

    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateScrollPanel()
    self:CreateControlPanel()

    self:LoadCountries()
    self:UpdateColors()  -- Initial color update
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

    local buttonSize = self:GetTall() * 0.05 -- Responsive button size

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
        self:LoadCountries()
    end
    self.BackButton:SetVisible(false)

    self.Title = vgui.Create("DLabel", self.Header)
    self.Title:SetText("rRadio")
    self.Title:SetFont(getFont(24, true))  -- Use Roboto Black for the title

    self.DarkModeButton = vgui.Create("DImageButton", self.Header)
    self.DarkModeButton:SetSize(buttonSize, buttonSize)
    self.DarkModeButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        surface.SetDrawColor(SafeColor(colors.text))
        surface.SetMaterial(RRADIO.Icons.DARK_MODE)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.DarkModeButton.DoClick = function()
        RRADIO.ToggleDarkMode()
        self:UpdateColors()
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
    self.SearchBar:SetTall(self:GetTall() * 0.06)
    self.SearchBar:DockMargin(20, 10, 20, 10)
    self.SearchBar:SetPlaceholderText("Search stations...")
    self.SearchBar:SetFont(getFont(18, false))  -- Use Roboto Regular for the search bar
    self.SearchBar.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.button))
        s:DrawTextEntryText(SafeColor(colors.text), s:GetHighlightColor(), s:GetCursorColor())
    end
    self.SearchBar.OnChange = function() self:PerformSearch() end
end

function RRADIO.Menu:CreateScrollPanel()
    self.ScrollBackground = self:Add("DPanel")
    self.ScrollBackground:Dock(FILL)
    self.ScrollBackground:DockMargin(20, 0, 20, 10)
    self.ScrollBackground.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.scrollBg))
    end

    self.Scroll = self.ScrollBackground:Add("DScrollPanel")
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(5, 5, 5, 5)  -- Add some padding inside the scroll background
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
    self.ControlPanel:SetTall(self:GetTall() * 0.1)
    self.ControlPanel:DockMargin(20, 10, 20, 20)
    self.ControlPanel.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.button))
    end

    self.StopButton = self.ControlPanel:Add("DButton")
    self.StopButton:SetText("Stop")
    self.StopButton:SetTextColor(SafeColor(RRADIO.GetColors().accent))  -- Keep accent color for stop button
    self.StopButton:SetFont(getFont(16, true))  -- Use Roboto Black for the stop button
    self.StopButton.Paint = function() end
    self.StopButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        rRadio.StopStation(self.BoomboxEntity)
    end
    self.StopButton.OnCursorEntered = function()
        surface.PlaySound(SOUND_HOVER)
    end

    self.VolumeSlider = self.ControlPanel:Add("DPanel")
    self.VolumeSlider:SetTall(4)
    self.VolumeSlider.Value = 1
    self.VolumeSlider.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(2, 0, 0, w, h, SafeColor(colors.divider))
        draw.RoundedBox(2, 0, 0, w * s.Value, h, SafeColor(colors.accent))
    end
    self.VolumeSlider.OnMousePressed = function(s)
        s.Dragging = true
        surface.PlaySound(RRADIO.Sounds.SLIDER)
    end
    self.VolumeSlider.OnMouseReleased = function(s)
        s.Dragging = false
        surface.PlaySound(RRADIO.Sounds.SLIDER)
    end
    self.VolumeSlider.Think = function(s)
        if s.Dragging then
            local x, _ = s:CursorPos()
            s.Value = math.Clamp(x / s:GetWide(), 0, 1)
            rRadio.SetVolume(self.BoomboxEntity, s.Value)
        end
    end
end

function RRADIO.Menu:PerformLayout(w, h)
    local buttonSize = self:GetTall() * 0.05
    local padding = buttonSize * 0.5

    if IsValid(self.BackButton) then
        self.BackButton:SetPos(padding, (self.Header:GetTall() - buttonSize) / 2)
    end

    if IsValid(self.Title) then
        self.Title:SizeToContents()
        self.Title:Center()
    end

    if IsValid(self.DarkModeButton) then
        self.DarkModeButton:SetPos(w - buttonSize * 2 - padding * 2, (self.Header:GetTall() - buttonSize) / 2)
    end

    if IsValid(self.CloseButton) then
        self.CloseButton:SetPos(w - buttonSize - padding, (self.Header:GetTall() - buttonSize) / 2)
    end
    
    if IsValid(self.StopButton) then
        self.StopButton:SizeToContents()
        self.StopButton:SetPos(10, (self.ControlPanel:GetTall() - self.StopButton:GetTall()) / 2)
    end
    
    if IsValid(self.VolumeSlider) then
        local sliderWidth = w - 80  -- Adjusted width
        self.VolumeSlider:SetPos(70, (self.ControlPanel:GetTall() - self.VolumeSlider:GetTall()) / 2)
        self.VolumeSlider:SetSize(sliderWidth, 4)
    end
end

-- Implement debouncing for search
local searchDebounceTimer = nil
function RRADIO.Menu:PerformSearch()
    if searchDebounceTimer then
        timer.Remove(searchDebounceTimer)
    end
    
    searchDebounceTimer = "rRadio_Search_" .. CurTime()
    timer.Create(searchDebounceTimer, 0.3, 1, function()
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