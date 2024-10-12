--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Implements the client-side menu interface for rRadio addon.
]]

local RRADIO = RRADIO or {}
RRADIO.Menu = RRADIO.Menu or {}

RRADIO.GetFont = getFont

local GITHUB_BUTTON_FADE_TIME = 0.3
local githubButtonAlpha = 0

RRADIO.Sounds = RRADIO.Sounds or {}
RRADIO.Sounds.CLICK = Sound("ui/buttonclick.wav")

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

function RRADIO.Menu:Init()
    local w, h = ScrW() * 0.5, ScrH() * 0.7
    self:SetSize(w, h)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)

    self.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(10, 0, 0, w, h, colors.bg)
    end

    surface.PlaySound(RRADIO.Sounds.OPEN)

    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateContentArea()
    self:CreateFooter()

    self:LoadCountries()
    self:UpdateColors()

    -- Fade in animation
    self:SetAlpha(0)
    self:AlphaTo(255, 0.3, 0)

    -- Set initial GitHub button alpha to 0
    githubButtonAlpha = 0
end

function RRADIO.Menu:CreateHeader()
    self.Header = self:Add("DPanel")
    self.Header:Dock(TOP)
    self.Header:SetTall(self:GetTall() * 0.064)
    self.Header.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBoxEx(10, 0, 0, w, h, colors.header, true, true, false, false)
        surface.SetDrawColor(SafeColor(colors.divider))
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    local buttonSize = math.max(self:GetTall() * 0.04, 20)

    self.Title = vgui.Create("DLabel", self.Header)
    self.Title:SetText(rRadio.Config.MenuTitle)
    self.Title:SetFont(getFont(20, true))
    self.Title:SizeToContents()

    -- Create buttons without setting their position
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
        self:AlphaTo(0, 0.3, 0, function()
            self:Remove()
        end)
    end

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

    self.GitHubButton = vgui.Create("DImageButton", self.Header)
    self.GitHubButton:SetSize(buttonSize, buttonSize)
    self.GitHubButton:SetVisible(true)
    self.GitHubButton.Paint = function(s, w, h)
        if githubButtonAlpha > 0 then
            local colors = RRADIO.GetColors()
            surface.SetDrawColor(ColorAlpha(SafeColor(colors.text), githubButtonAlpha))
            surface.SetMaterial(RRADIO.Icons.GITHUB)
            surface.DrawTexturedRect(0, 0, w, h)
        end
        return true
    end
    self.GitHubButton.DoClick = function()
        if githubButtonAlpha > 200 then
            surface.PlaySound(RRADIO.Sounds.CLICK)
            gui.OpenURL("https://github.com/charles-mills/rRadio")
        end
    end
    self.GitHubButton.OnCursorEntered = function(s)
        if githubButtonAlpha > 0 then
            s:SetCursor("hand")
        end
    end
    self.GitHubButton.OnCursorExited = function(s)
        s:SetCursor("arrow")
    end

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
            self:CloseSettings()
        else
            self:LoadCountries()
        end
    end
    self.BackButton:SetVisible(false)
end

function RRADIO.Menu:PerformLayout(w, h)
    local margin = math.Round(w * 0.02)
    local buttonSize = math.max(h * 0.04, 20)
    local iconSpacing = buttonSize * 0.5

    -- Position the back button on the left if it exists
    if IsValid(self.BackButton) then
        self.BackButton:SetPos(margin, (self.Header:GetTall() - buttonSize) / 2)
    end

    -- Position buttons on the right
    local rightEdge = w - margin
    if IsValid(self.CloseButton) then
        self.CloseButton:SetPos(rightEdge - buttonSize, (self.Header:GetTall() - buttonSize) / 2)
        rightEdge = rightEdge - buttonSize - iconSpacing
    end

    if IsValid(self.SettingsButton) then
        self.SettingsButton:SetPos(rightEdge - buttonSize, (self.Header:GetTall() - buttonSize) / 2)
        rightEdge = rightEdge - buttonSize - iconSpacing
    end

    if IsValid(self.GitHubButton) then
        self.GitHubButton:SetPos(rightEdge - buttonSize, (self.Header:GetTall() - buttonSize) / 2)
    end

    -- Center the title
    if IsValid(self.Title) then
        self.Title:SetPos((w - self.Title:GetWide()) / 2, (self.Header:GetTall() - self.Title:GetTall()) / 2)
    end

    -- Call the base class PerformLayout
    self.BaseClass.PerformLayout(self, w, h)
end

function RRADIO.Menu:CreateSearchBar()
    self.SearchBar = self:Add("DTextEntry")
    self.SearchBar:Dock(TOP)
    self.SearchBar:SetTall(math.max(self:GetTall() * 0.0462, 26))
    local margin = math.Round(self:GetWide() * 0.02)
    self.SearchBar:DockMargin(margin, margin / 2, margin, margin / 4)
    self.SearchBar:SetFont(getFont(15, false))
    self.SearchBar:SetPlaceholderText("Search...")
    self.SearchBar.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(h/2, 0, 0, w, h, colors.button)
        s:DrawTextEntryText(colors.text, colors.accent, colors.text)

        if s:GetText() == "" and not s:HasFocus() then
            draw.SimpleText(s:GetPlaceholderText(), s:GetFont(), 10, h/2, colors.text_placeholder, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    self.SearchBar.OnChange = function() self:PerformSearch() end
    
    self:UpdateSearchBarPlaceholder()
end

function RRADIO.Menu:UpdateStatusPanel(stationName, countryName)
    if IsValid(self.StationLabel) then
        if stationName then
            self.StationLabel:SetText(stationName)
            self.StationLabel:SetSize(self.StatusPanel:GetWide(), self.StatusPanel:GetTall() / 2)
            self.StationLabel:SetPos(0, 0)
            self.CountryLabel:SetVisible(true)
        else
            self.StationLabel:SetText("Not Playing")
            self.StationLabel:SetSize(self.StatusPanel:GetWide(), self.StatusPanel:GetTall())
            self.StationLabel:SetPos(0, 0)
            self.CountryLabel:SetVisible(false)
        end
    end
    if IsValid(self.CountryLabel) then
        self.CountryLabel:SetText(countryName or "")
    end
end

function RRADIO.Menu:CreateContentArea()
    self.ScrollBackground = self:Add("DPanel")
    self.ScrollBackground:Dock(FILL)
    local margin = math.Round(self:GetWide() * 0.02)
    self.ScrollBackground:DockMargin(margin, 0, margin, margin / 4)
    self.ScrollBackground.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(8, 0, 0, w, h, SafeColor(colors.scrollBg))
    end

    self.Content = self.ScrollBackground:Add("DScrollPanel")
    self.Content:Dock(FILL)
    self.Content:DockMargin(margin / 4, margin / 4, margin / 4, margin / 4)
    local scrollBar = self.Content:GetVBar()
    scrollBar:SetHideButtons(true)
    scrollBar.Paint = function() end
    scrollBar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, SafeColor(RRADIO.GetColors().accent))
    end
end

function RRADIO.Menu:CreateFooter()
    self.Footer = self:Add("DPanel")
    self.Footer:Dock(BOTTOM)
    self.Footer:SetTall(math.max(self:GetTall() * 0.09, 50))
    local margin = math.Round(self:GetWide() * 0.02)
    self.Footer:DockMargin(margin, margin / 4, margin, margin)
    self.Footer.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBoxEx(8, 0, 0, w, h, colors.footer, false, false, true, true)
    end

    local totalWidth = self:GetWide() - (2 * margin)
    local stopButtonWidth = totalWidth * 0.2
    local volumeControlWidth = totalWidth * 0.2
    local statusPanelWidth = totalWidth * 0.5
    local padding = totalWidth * 0.05

    -- Stop Button
    self.StopButton = self.Footer:Add("DButton")
    self.StopButton:SetText("STOP")
    self.StopButton:SetFont(getFont(18, true))
    self.StopButton:SetTextColor(RRADIO.GetColors().accent)
    self.StopButton:SetSize(stopButtonWidth, self.Footer:GetTall() - margin)
    self.StopButton:SetPos(0, margin / 2)
    self.StopButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and colors.buttonHover or colors.button)
    end
    self.StopButton.DoClick = function()
        surface.PlaySound(RRADIO.Sounds.CLICK)
        rRadio.StopStation(self.BoomboxEntity)
    end

    -- Boombox Status Panel
    self.StatusPanel = self.Footer:Add("DPanel")
    self.StatusPanel:SetSize(statusPanelWidth, self.Footer:GetTall() - margin)
    self.StatusPanel:SetPos(stopButtonWidth + padding, margin / 2)
    self.StatusPanel.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(5, 0, 0, w, h, colors.button)
    end

    local labelHeight = self.StatusPanel:GetTall() / 2

    self.StationLabel = self.StatusPanel:Add("DLabel")
    self.StationLabel:SetFont(getFont(16, true))
    self.StationLabel:SetTextColor(RRADIO.GetColors().text)
    self.StationLabel:SetSize(statusPanelWidth, self.StatusPanel:GetTall())
    self.StationLabel:SetPos(0, 0)
    self.StationLabel:SetContentAlignment(5)  -- Center alignment
    self.StationLabel:SetText("Not Playing")

    self.CountryLabel = self.StatusPanel:Add("DLabel")
    self.CountryLabel:SetFont(getFont(14, false))
    self.CountryLabel:SetTextColor(RRADIO.GetColors().text)
    self.CountryLabel:SetSize(statusPanelWidth, labelHeight)
    self.CountryLabel:SetPos(0, labelHeight)
    self.CountryLabel:SetContentAlignment(5)  -- Center alignment
    self.CountryLabel:SetText("")

    -- Volume Control Panel
    self.VolumeControlPanel = self.Footer:Add("DPanel")
    self.VolumeControlPanel:SetSize(volumeControlWidth, self.Footer:GetTall() - margin)
    self.VolumeControlPanel:SetPos(totalWidth - volumeControlWidth, margin / 2)
    self.VolumeControlPanel.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(5, 0, 0, w, h, colors.button)
    end

    self.VolumeIcon = self.VolumeControlPanel:Add("DImage")
    self.VolumeIcon:SetSize(24, 24)
    self.VolumeIcon:Dock(LEFT)
    self.VolumeIcon:DockMargin(margin / 2, 0, margin / 2, 0)
    self.VolumeIcon:SetImage("icon16/sound.png")

    self.VolumeSlider = self.VolumeControlPanel:Add("DSlider")
    self.VolumeSlider:Dock(FILL)
    self.VolumeSlider:SetLockY(0.5)
    self.VolumeSlider:SetSlideX(0.5)
    self.VolumeSlider.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(h/2, 0, h/2 - 2, w, 4, colors.divider)
        draw.RoundedBox(h/2, 0, h/2 - 2, w * s:GetSlideX(), 4, colors.accent)
    end
    self.VolumeSlider.Knob:SetSize(16, 16)
    self.VolumeSlider.Knob.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        draw.RoundedBox(w/2, 0, 0, w, h, colors.accent)
    end
    self.VolumeSlider.OnValueChanged = function(s, value)
        rRadio.SetVolume(self.BoomboxEntity, value)
    end
end

function RRADIO.Menu:CreateButton(text, isFirst, isLast, isFavorite, onFavoriteToggle)
    local button = self.Content:Add("DButton")
    button:Dock(TOP)
    button:SetTall(50)
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
    
    local hoverAlpha = 0
    button.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        local bgColor = ColorAlpha(s:IsHovered() and colors.buttonHover or colors.button, 255 - hoverAlpha)
        draw.RoundedBox(5, 0, 0, w, h, bgColor)
        
        local textColor = ColorAlpha(colors.text, 255 - hoverAlpha)
        draw.SimpleText(text, s:GetFont(), w/2, h/2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if s:IsHovered() and hoverAlpha < 255 then
            hoverAlpha = math.Approach(hoverAlpha, 255, FrameTime() * 1000)
            s:InvalidateLayout()
        elseif not s:IsHovered() and hoverAlpha > 0 then
            hoverAlpha = math.Approach(hoverAlpha, 0, FrameTime() * 1000)
            s:InvalidateLayout()
        end
    end
    
    button.DoClick = function(s)
        surface.PlaySound(RRADIO.Sounds.CLICK)
        if s.OriginalDoClick then
            s:OriginalDoClick()
        end
    end

    return button
end

function RRADIO.Menu:UpdateColors()
    local colors = RRADIO.GetColors()
    self.Title:SetTextColor(SafeColor(colors.text))
    self.SearchBar:SetTextColor(SafeColor(colors.text))
    self.StopButton:SetTextColor(SafeColor(colors.accent))

    for _, child in pairs(self.Content:GetCanvas():GetChildren()) do
        if IsValid(child) and child.Paint then
            child:SetTextColor(SafeColor(colors.text))
        end
    end

    self:InvalidateLayout(true)
    self.SearchBar:InvalidateLayout(true)

    if self.currentView == "settings" then
        self:PopulateSettings()
    end

    if IsValid(self.GitHubButton) then
        self.GitHubButton:InvalidateLayout(true)
    end
end

function RRADIO.Menu:UpdateSearchBarPlaceholder()
    local placeholder = self.currentView == "countries" and "Search countries..." or "Search stations..."
    if IsValid(self.SearchBar) then
        self.SearchBar:SetPlaceholderText(placeholder)
    end
end

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

        self.Content:Clear()

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

function RRADIO.Menu:OpenSettings()
    self.currentView = "settings"
    self.Content:Clear()
    self.BackButton:SetVisible(true)
    self.Title:SetText("Settings")
    self.Title:SizeToContents()
    self.Title:Center()
    
    self:PopulateSettings()
    self:UpdateColors()
    self:UpdateLayoutForView()
    self:AnimateGitHubButton(true)
end

function RRADIO.Menu:PopulateSettings()
    self.Content:Clear()

    local darkModeToggle = self.Content:Add("DButton")
    darkModeToggle:Dock(TOP)
    darkModeToggle:SetTall(self.Content:GetTall() * 0.06)
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
end

function RRADIO.Menu:AnimateGitHubButton(fadeIn)
    local startAlpha = fadeIn and 0 or 255
    local endAlpha = fadeIn and 255 or 0
    local startTime = SysTime()

    hook.Add("Think", "rRadio_GitHubButtonFade", function()
        local progress = (SysTime() - startTime) / GITHUB_BUTTON_FADE_TIME
        if progress >= 1 then
            githubButtonAlpha = endAlpha
            hook.Remove("Think", "rRadio_GitHubButtonFade")
        else
            githubButtonAlpha = Lerp(progress, startAlpha, endAlpha)
        end
        if IsValid(self.GitHubButton) then
            self.GitHubButton:InvalidateLayout(true)
        else
            hook.Remove("Think", "rRadio_GitHubButtonFade")
        end
    end)
end

function RRADIO.Menu:CloseSettings()
    self:LoadCountries()
    self:AnimateGitHubButton(false)
    self:UpdateLayoutForView()
end

function RRADIO.Menu:UpdateLayoutForView()
    if self.currentView == "settings" then
        if IsValid(self.SearchBar) then
            self.SearchBar:SetVisible(false)
        end
        if IsValid(self.ScrollBackground) then
            self.ScrollBackground:DockMargin(
                self.ScrollBackground:GetDockMargin(),
                0,  -- Remove top margin
                self.ScrollBackground:GetDockMargin(),
                self.ScrollBackground:GetDockMargin()
            )
        end
    else
        if IsValid(self.SearchBar) then
            self.SearchBar:SetVisible(true)
        end
        if IsValid(self.ScrollBackground) then
            local margin = math.Round(self:GetWide() * 0.02)
            self.ScrollBackground:DockMargin(margin, margin, margin, margin)
        end
    end
    self:InvalidateLayout(true)
end

function RRADIO.Menu:LoadCountries()
    self.Content:Clear()
    self.currentView = "countries"
    
    if IsValid(self.BackButton) then
        self.BackButton:SetVisible(false)
    end
    
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
    self:UpdateLayoutForView()

    -- Only fade out GitHub button if we're coming from settings
    if self.currentView == "settings" then
        self:AnimateGitHubButton(false)
    end
end

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

function RRADIO.Menu:LoadStations(country)
    self.Content:Clear()
    self.currentView = "stations"
    self.currentCountry = country

    if IsValid(self.BackButton) then
        self.BackButton:SetVisible(true)
    end
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
    self:UpdateLayoutForView()
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

-- Add this new method to the RRADIO.Menu table
function RRADIO.Menu:UpdateCurrentStation(entity)
    if IsValid(entity) then
        local stationKey = entity:GetNWString("CurrentStationKey", "")
        local stationIndex = entity:GetNWInt("CurrentStationIndex", 0)
        local currentStation = entity:GetNWString("CurrentStation", "")
        
        if currentStation == "tuning" then
            self:UpdateStatusPanel("Tuning in...", rRadio.FormatCountryName(stationKey))
        elseif stationKey ~= "" and stationIndex > 0 and rRadio.Stations[stationKey] and rRadio.Stations[stationKey][stationIndex] then
            local stationName = rRadio.Stations[stationKey][stationIndex].n
            local countryName = rRadio.FormatCountryName(stationKey)
            self:UpdateStatusPanel(stationName, countryName)
        else
            self:UpdateStatusPanel(nil, nil)
        end
    else
        self:UpdateStatusPanel(nil, nil)
    end
end

-- Modify the rRadio.OpenMenu function
function rRadio.OpenMenu(entity)
    if IsValid(rRadio.Menu) then rRadio.Menu:Remove() end
    rRadio.Menu = vgui.Create("rRadioMenu")
    rRadio.Menu:SetBoomboxEntity(entity)
    rRadio.Menu:UpdateCurrentStation(entity)  -- Add this line
end

-- Modify the RRADIO.Menu:SetBoomboxEntity method
function RRADIO.Menu:SetBoomboxEntity(entity)
    self.BoomboxEntity = entity
    if IsValid(self.VolumeSlider) then
        local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
        self.VolumeSlider:SetSlideX(volume)
    end
    self:UpdateCurrentStation(entity)  -- Add this line
end

function RRADIO.IsDarkMode()
    return RRADIO.DarkModeConVar:GetBool()
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

net.Receive("rRadio_UpdateBoombox", function()
    local boomboxEnt = net.ReadEntity()
    if IsValid(rRadio.Menu) and IsValid(boomboxEnt) and rRadio.Menu.BoomboxEntity == boomboxEnt then
        rRadio.Menu:UpdateCurrentStation(boomboxEnt)
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