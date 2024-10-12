-- Client-side menu for rRadio

local RRADIO = RRADIO or {}
RRADIO.Menu = RRADIO.Menu or {}

-- Colors
RRADIO.Colors = {
    BG_LIGHT = Color(255, 255, 255),
    BG_DARK = Color(18, 18, 18),
    TEXT_LIGHT = Color(0, 0, 0),
    TEXT_DARK = Color(255, 255, 255),
    ACCENT = Color(0, 122, 255),
    BUTTON_LIGHT = Color(240, 240, 240),
    BUTTON_DARK = Color(30, 30, 30),
    BUTTON_HOVER_LIGHT = Color(230, 230, 230),
    BUTTON_HOVER_DARK = Color(40, 40, 40),
    DIVIDER_LIGHT = Color(200, 200, 200),
    DIVIDER_DARK = Color(50, 50, 50),
    SCROLL_BG_LIGHT = Color(245, 245, 247),
    SCROLL_BG_DARK = Color(28, 28, 30),
}

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

-- Create client-side ConVar for dark mode
local darkModeConVar = CreateClientConVar("rradio_dark_mode", "0", true, false, "Toggle dark mode for rRadio menu")

-- Replace the existing GetColors function with this one
local function GetColors()
    local isDarkMode = darkModeConVar:GetBool()
    return {
        bg = isDarkMode and RRADIO.Colors.BG_DARK or RRADIO.Colors.BG_LIGHT,
        text = isDarkMode and RRADIO.Colors.TEXT_DARK or RRADIO.Colors.TEXT_LIGHT,
        button = isDarkMode and RRADIO.Colors.BUTTON_DARK or RRADIO.Colors.BUTTON_LIGHT,
        buttonHover = isDarkMode and RRADIO.Colors.BUTTON_HOVER_DARK or RRADIO.Colors.BUTTON_HOVER_LIGHT,
        divider = isDarkMode and RRADIO.Colors.DIVIDER_DARK or RRADIO.Colors.DIVIDER_LIGHT,
        accent = RRADIO.Colors.ACCENT,
        scrollBg = isDarkMode and RRADIO.Colors.SCROLL_BG_DARK or RRADIO.Colors.SCROLL_BG_LIGHT
    }
end

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

local function formatCountryName(name)
    return name:gsub("_", " "):gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

-- Modify the CreateButton function
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
    favoriteButton.Paint = function(s, w, h)
        local colors = GetColors()
        surface.SetDrawColor(colors.text)
        surface.SetMaterial(isFavorite and RRADIO.Icons.STAR_FULL or RRADIO.Icons.STAR_EMPTY)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    favoriteButton.DoClick = function()
        onFavoriteToggle()
        isFavorite = not isFavorite
        surface.PlaySound(RRADIO.Sounds.CLICK)
    end
    
    button.Paint = function(s, w, h)
        local colors = GetColors()
        local radius = 4
        if isFirst and isLast then
            draw.RoundedBox(radius, 0, 0, w, h, s:IsHovered() and colors.buttonHover or colors.button)
        elseif isFirst then
            draw.RoundedBoxEx(radius, 0, 0, w, h, s:IsHovered() and colors.buttonHover or colors.button, true, true, false, false)
        elseif isLast then
            draw.RoundedBoxEx(radius, 0, 0, w, h, s:IsHovered() and colors.buttonHover or colors.button, false, false, true, true)
        else
            draw.RoundedBox(0, 0, 0, w, h, s:IsHovered() and colors.buttonHover or colors.button)
        end
        
        -- Draw the text centered, but slightly offset to the right to account for the favorite icon
        local textX = (w + iconSize) / 2
        local textY = h / 2
        draw.SimpleText(text, getFont(16, false), textX, textY, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    button.DoClick = function(s)
        surface.PlaySound(RRADIO.Sounds.CLICK)
        if s.OriginalDoClick then
            s:OriginalDoClick()
        end
    end

    return button
end

-- Modify the LoadCountries function to include favorites
function RRADIO.Menu:LoadCountries()
    self.Scroll:Clear()
    self.currentView = "countries"
    
    -- Update header
    self.BackButton:SetVisible(false)
    self.Title:SetText("rRadio")
    self.Title:SizeToContents()
    self.Title:Center()

    -- Clear the search bar
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
    
    table.sort(favoriteCountries, SortIgnoringThe)
    table.sort(sortedCountries, SortIgnoringThe)
    
    -- Add favorite countries first
    for i, country in ipairs(favoriteCountries) do
        local formattedCountry = formatCountryName(country)
        local button = self:CreateButton(formattedCountry, i == 1, i == #favoriteCountries and #sortedCountries == 0, true, function()
            rRadio.ToggleFavoriteCountry(country)
            self:LoadCountries()  -- Reload the list to update order
        end)
        button.OriginalDoClick = function()
            self:LoadStations(country)
        end
        button.OriginalCountry = country
    end
    
    -- Add non-favorite countries
    for i, country in ipairs(sortedCountries) do
        local formattedCountry = formatCountryName(country)
        local button = self:CreateButton(formattedCountry, #favoriteCountries == 0 and i == 1, i == #sortedCountries, false, function()
            rRadio.ToggleFavoriteCountry(country)
            self:LoadCountries()  -- Reload the list to update order
        end)
        button.OriginalDoClick = function()
            self:LoadStations(country)
        end
        button.OriginalCountry = country
    end
end

-- Modify the LoadStations function to include favorites
function RRADIO.Menu:LoadStations(country)
    self.Scroll:Clear()
    self.currentView = "stations"
    self.currentCountry = country

    -- Update header
    self.BackButton:SetVisible(true)
    local formattedCountry = formatCountryName(country)
    self.Title:SetText(formattedCountry)
    self.Title:SizeToContents()
    self.Title:Center()

    -- Clear the search bar
    if IsValid(self.SearchBar) then
        self.SearchBar:SetValue("")
    end

    local sortedStations = {}
    local favoriteStations = {}
    
    for i, station in ipairs(rRadio.Stations[country]) do
        if rRadio.IsStationFavorite(country, i) then
            table.insert(favoriteStations, {index = i, name = station.n})
        else
            table.insert(sortedStations, {index = i, name = station.n})
        end
    end
    
    table.sort(favoriteStations, function(a, b) return SortIgnoringThe(a.name, b.name) end)
    table.sort(sortedStations, function(a, b) return SortIgnoringThe(a.name, b.name) end)

    -- Add favorite stations first
    for i, stationInfo in ipairs(favoriteStations) do
        local button = self:CreateButton(stationInfo.name, i == 1, i == #favoriteStations and #sortedStations == 0, true, function()
            rRadio.ToggleFavoriteStation(country, stationInfo.index)
            self:LoadStations(country)  -- Reload the list to update order
        end)
        button.DoClick = function()
            surface.PlaySound(RRADIO.Sounds.CLICK)
            rRadio.PlayStation(self.BoomboxEntity, country, stationInfo.index)
        end
    end

    -- Add non-favorite stations
    for i, stationInfo in ipairs(sortedStations) do
        local button = self:CreateButton(stationInfo.name, #favoriteStations == 0 and i == 1, i == #sortedStations, false, function()
            rRadio.ToggleFavoriteStation(country, stationInfo.index)
            self:LoadStations(country)  -- Reload the list to update order
        end)
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
        local colors = GetColors()
        draw.RoundedBoxEx(8, 0, 0, w, h, colors.bg, true, true, false, false)
        surface.SetDrawColor(colors.divider)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local buttonSize = self:GetTall() * 0.05 -- Responsive button size

    self.BackButton = vgui.Create("DImageButton", self.Header)
    self.BackButton:SetSize(buttonSize, buttonSize)
    self.BackButton.Paint = function(s, w, h)
        local colors = GetColors()
        surface.SetDrawColor(colors.text)
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
        local colors = GetColors()
        surface.SetDrawColor(colors.text)
        surface.SetMaterial(RRADIO.Icons.DARK_MODE)
        surface.DrawTexturedRect(0, 0, w, h)
    end
    self.DarkModeButton.DoClick = function()
        darkModeConVar:SetBool(not darkModeConVar:GetBool())
        self:UpdateColors()
    end

    self.CloseButton = vgui.Create("DImageButton", self.Header)
    self.CloseButton:SetSize(buttonSize, buttonSize)
    self.CloseButton.Paint = function(s, w, h)
        local colors = GetColors()
        surface.SetDrawColor(colors.text)
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
        local colors = GetColors()
        draw.RoundedBox(8, 0, 0, w, h, colors.button)
        s:DrawTextEntryText(colors.text, s:GetHighlightColor(), s:GetCursorColor())
    end
    self.SearchBar.OnChange = function() self:PerformSearch() end
end

function RRADIO.Menu:CreateScrollPanel()
    self.ScrollBackground = self:Add("DPanel")
    self.ScrollBackground:Dock(FILL)
    self.ScrollBackground:DockMargin(20, 0, 20, 10)
    self.ScrollBackground.Paint = function(s, w, h)
        local colors = GetColors()
        draw.RoundedBox(8, 0, 0, w, h, colors.scrollBg)
    end

    self.Scroll = self.ScrollBackground:Add("DScrollPanel")
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(5, 5, 5, 5)  -- Add some padding inside the scroll background
    local scrollBar = self.Scroll:GetVBar()
    scrollBar:SetHideButtons(true)
    scrollBar.Paint = function() end
    scrollBar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, RRADIO.Colors.ACCENT)
    end
end

function RRADIO.Menu:CreateControlPanel()
    self.ControlPanel = self:Add("DPanel")
    self.ControlPanel:Dock(BOTTOM)
    self.ControlPanel:SetTall(self:GetTall() * 0.1)
    self.ControlPanel:DockMargin(20, 10, 20, 20)
    self.ControlPanel.Paint = function(s, w, h)
        local colors = GetColors()
        draw.RoundedBox(8, 0, 0, w, h, colors.button)
    end

    self.StopButton = self.ControlPanel:Add("DButton")
    self.StopButton:SetText("Stop")
    self.StopButton:SetTextColor(RRADIO.Colors.ACCENT)  -- Keep accent color for stop button
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
        local colors = GetColors()
        draw.RoundedBox(2, 0, 0, w, h, colors.divider)
        draw.RoundedBox(2, 0, 0, w * s.Value, h, colors.accent)
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

function RRADIO.Menu:PerformSearch()
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
            local formattedCountry = formatCountryName(country)
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
        for i, station in ipairs(rRadio.Stations[self.currentCountry]) do
            if string.find(station.n:lower(), query) then
                local isFavorite = rRadio.IsStationFavorite(self.currentCountry, i)
                local button = self:CreateButton(station.n, false, false, isFavorite, function()
                    rRadio.ToggleFavoriteStation(self.currentCountry, i)
                    self:PerformSearch()  -- Refresh the search results
                end)
                button.DoClick = function()
                    surface.PlaySound(RRADIO.Sounds.CLICK)
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, i)
                end
            end
        end
    end
end

function RRADIO.Menu:Paint(w, h)
    local colors = GetColors()
    draw.RoundedBox(8, 0, 0, w, h, colors.bg)
end

function RRADIO.Menu:SetBoomboxEntity(entity)
    self.BoomboxEntity = entity
    if IsValid(self.VolumeSlider) then
        local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
        self.VolumeSlider.Value = volume
    end
end

function RRADIO.Menu:UpdateColors()
    local colors = GetColors()
    self.Title:SetTextColor(colors.text)
    self.SearchBar:SetTextColor(colors.text)
    self.StopButton:SetTextColor(RRADIO.Colors.ACCENT)

    for _, child in pairs(self.Scroll:GetCanvas():GetChildren()) do
        if IsValid(child) and child.Paint then
            child:SetTextColor(colors.text)
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