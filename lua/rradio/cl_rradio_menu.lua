--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Implements the client-side menu interface for rRadio addon.
]]

local RRADIO = RRADIO or {}
RRADIO.Menu = RRADIO.Menu or {}

local GITHUB_BUTTON_FADE_TIME = 0.3
local githubButtonAlpha = 0
local titleClickCount = 0
local isTitleWobbling = false

local draw = draw
local surface = surface
local vgui = vgui
local ScrW = ScrW
local ScrH = ScrH
local IsValid = IsValid
local Color = Color

function SafeColor(color)
    return IsColor(color) and color or Color(255, 255, 255)
end

-- Localize global functions for performance
local SortIgnoringThe = rRadio.SortIgnoringThe or function(a, b)
    local PATTERN_STRIP = "^The%s+"
    local function stripThe(str)
        return str:gsub(PATTERN_STRIP, ""):lower()
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
    VOLUME = Material("hud/volume.png", "smooth mips"),
}

-- Sounds
RRADIO.Sounds = {
    CLICK = Sound("ui/buttonclick.wav"),
    OPEN = Sound("ui/buttonclickrelease.wav"),
    CLOSE = Sound("ui/buttonclickrelease.wav"),
    SLIDER = Sound("ui/slider.wav"),
    CELEBRATE = Sound("garrysmod/balloon_pop_cute.wav"),
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

RRADIO.GetFont = getFont

-- Helper function to draw icons with color overlay
local function DrawIconWithColor(icon, x, y, w, h, color)
    surface.SetDrawColor(color)
    surface.SetMaterial(icon)
    surface.DrawTexturedRect(x, y, w, h)
end

function RRADIO.Menu:Init()
    local w, h = ScrW() * 0.5, ScrH() * 0.7
    self:SetSize(w, h)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)

    -- Add blur effect
    self.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        Derma_DrawBackgroundBlur(self, 0)
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

    titleClickCount = 0 -- Reset the click count when the menu is opened
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

    self.Title = self.Header:Add("DButton")
    self.Title:SetText(rRadio.Config.MenuTitle)
    self.Title:SetFont(getFont(20, true))
    self.Title:SizeToContents()
    self.Title:SetTextColor(RRADIO.GetColors().text)
    self.Title:SetCursor("arrow")  -- Set default cursor
    self.Title.Paint = function(s, w, h)
        draw.SimpleText(s:GetText(), s:GetFont(), w/2, h/2, s:GetTextColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    self.Title.DoClick = function()
        if self.currentView == "countries" then
            titleClickCount = titleClickCount + 1
            if titleClickCount == 3 and not isTitleWobbling then
                self:WobbleTitle()
            end
        end
    end

    local function CreateIconButton(icon, clickFunction)
        local button = vgui.Create("DButton", self.Header)
        button:SetSize(buttonSize, buttonSize)
        button:SetText("")
        
        button.Paint = function(s, w, h)
            local colors = RRADIO.GetColors()
            local iconColor = colors.text
            if s:IsHovered() then
                iconColor = ColorAlpha(iconColor, 200)
            end
            DrawIconWithColor(icon, 0, 0, w, h, iconColor)
        end
        
        button.DoClick = function()
            surface.PlaySound(RRADIO.Sounds.CLICK)
            clickFunction()
        end
        
        return button
    end

    self.CloseButton = CreateIconButton(RRADIO.Icons.CLOSE, function()
        self:AlphaTo(0, 0.3, 0, function()
            self:Remove()
            titleClickCount = 0 -- Reset the click count when the menu is closed
            -- Remove the blur effect when the menu is closed
            if IsValid(self.BlurPanel) then
                self.BlurPanel:Remove()
            end
        end)
    end)

    self.SettingsButton = CreateIconButton(RRADIO.Icons.SETTINGS, function()
        self:OpenSettings()
    end)

    self.GitHubButton = CreateIconButton(RRADIO.Icons.GITHUB, function()
        gui.OpenURL("https://github.com/charles-mills/rRadio")
    end)
    self.GitHubButton:SetVisible(false)
    self.GitHubButton:SetAlpha(0)

    self.BackButton = CreateIconButton(RRADIO.Icons.BACK, function()
        if self.currentView == "settings" then
            self:CloseSettings()
        else
            self:LoadCountries()
        end
    end)
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
        self.GitHubButton:SetAlpha(githubButtonAlpha)  -- Set the alpha based on the githubButtonAlpha value
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
    local colors = RRADIO.GetColors()

    local function stopTuningAnimation()
        if self.TuningTimer then
            timer.Remove(self.TuningTimer)
            self.TuningTimer = nil
        end
        if self.TuningTimeoutTimer then
            timer.Remove(self.TuningTimeoutTimer)
            self.TuningTimeoutTimer = nil
        end
        self.TuningAnimation = nil
    end

    if IsValid(self.StationLabel) then
        if stationName then
            -- Change the text to "Tuning in..." first
            if stationName == "Tuning in" then
                self.StationLabel:SetText("Tuning in...")
            else
                self.StationLabel:SetText(stationName)
            end

            -- Then adjust the layout
            self.StationLabel:SetSize(self.StatusPanel:GetWide(), self.StatusPanel:GetTall() / 2)
            self.StationLabel:SetPos(0, 0)
            self.CountryLabel:SetVisible(true)

            if stationName == "Tuning in" then
                -- Start or continue the tuning animation
                if not self.TuningAnimation then
                    self.TuningAnimation = 0
                    self.TuningTimer = "rRadio_TuningAnimation_" .. tostring(self)
                    timer.Create(self.TuningTimer, 0.2, 0, function()
                        if not IsValid(self) or not self.TuningAnimation then
                            stopTuningAnimation()
                            return
                        end
                        self.TuningAnimation = (self.TuningAnimation + 1) % 3
                        if IsValid(self.StationLabel) then
                            self.StationLabel:SetText("Tuning in" .. string.rep(".", self.TuningAnimation + 1))
                        else
                            stopTuningAnimation()
                        end
                    end)

                    -- Create a timeout timer
                    self.TuningTimeoutTimer = "rRadio_TuningTimeout_" .. tostring(self)
                    timer.Create(self.TuningTimeoutTimer, 8, 1, function()
                        if IsValid(self) and IsValid(self.StationLabel) and self.TuningAnimation then
                            stopTuningAnimation()
                            surface.PlaySound("buttons/button10.wav")  -- Play an error sound
                            self.StationLabel:SetText("Station Outage")
                            timer.Simple(2, function()
                                if IsValid(self) and IsValid(self.StationLabel) then
                                    self:UpdateStatusPanel(nil, nil)
                                end
                            end)
                        end
                    end)
                end
            else
                -- Stop the tuning animation if it's running
                stopTuningAnimation()
            end
        else
            -- Stop the tuning animation if it's running
            stopTuningAnimation()
            
            self.StationLabel:SetText("Not Playing")
            self.StationLabel:SetSize(self.StatusPanel:GetWide(), self.StatusPanel:GetTall())
            self.StationLabel:SetPos(0, 0)
            self.CountryLabel:SetVisible(false)
        end
        self.StationLabel:SetTextColor(colors.text)
    end
    if IsValid(self.CountryLabel) then
        self.CountryLabel:SetText(countryName or "")
        self.CountryLabel:SetTextColor(colors.text)
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
    self.VolumeIcon:SetMaterial(RRADIO.Icons.VOLUME)
    
    self.VolumeIcon.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        DrawIconWithColor(RRADIO.Icons.VOLUME, 0, 0, w, h, colors.text)
    end

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
    
    local favoriteButton = vgui.Create("DButton", button)
    local iconSize = button:GetTall() * 0.6
    favoriteButton:SetSize(iconSize, iconSize)
    favoriteButton:Dock(LEFT)
    favoriteButton:DockMargin(5, (button:GetTall() - iconSize) / 2, 5, (button:GetTall() - iconSize) / 2)
    favoriteButton:SetText("")

    favoriteButton.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        local iconColor = colors.text
        if s:IsHovered() then
            iconColor = ColorAlpha(iconColor, 200)
        end
        DrawIconWithColor(isFavorite and RRADIO.Icons.STAR_FULL or RRADIO.Icons.STAR_EMPTY, 0, 0, w, h, iconColor)
    end

    favoriteButton.DoClick = function()
        onFavoriteToggle()
        isFavorite = not isFavorite
        surface.PlaySound(RRADIO.Sounds.CLICK)
    end
    
    local hoverAlpha = 0
    button.Paint = function(s, w, h)
        local colors = RRADIO.GetColors()
        local bgColor = ColorAlpha(s:IsHovered() and colors.buttonHover or colors.button, 255)
        draw.RoundedBox(5, 0, 0, w, h, bgColor)
        
        local textColor = ColorAlpha(colors.text, 255 - (hoverAlpha * 0.3)) -- Reduce the alpha change for text
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

    -- Update status panel colors
    if IsValid(self.StationLabel) then
        self.StationLabel:SetTextColor(SafeColor(colors.text))
    end
    if IsValid(self.CountryLabel) then
        self.CountryLabel:SetTextColor(SafeColor(colors.text))
    end

    for _, child in pairs(self.Content:GetCanvas():GetChildren()) do
        if IsValid(child) and child.Paint then
            child:InvalidateLayout(true)
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

    if IsValid(self.Title) then
        self.Title:SetTextColor(RRADIO.GetColors().text)
    end

    -- Invalidate layout for all header buttons
    if IsValid(self.CloseButton) then self.CloseButton:InvalidateLayout(true) end
    if IsValid(self.SettingsButton) then self.SettingsButton:InvalidateLayout(true) end
    if IsValid(self.BackButton) then self.BackButton:InvalidateLayout(true) end
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
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, stationInfo.name)
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
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, stationInfo.name)
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
    self.GitHubButton:SetVisible(true)  -- Show the GitHub button in settings
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

        DrawIconWithColor(RRADIO.Icons.DARK_MODE, 5, (h - iconSize) / 2, iconSize, iconSize, colors.text)
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
            self.GitHubButton:SetAlpha(githubButtonAlpha)
        else
            hook.Remove("Think", "rRadio_GitHubButtonFade")
        end
    end)
end

function RRADIO.Menu:CloseSettings()
    self:LoadCountries()
    self:AnimateGitHubButton(false)
    timer.Simple(GITHUB_BUTTON_FADE_TIME, function()
        if IsValid(self.GitHubButton) then
            self.GitHubButton:SetVisible(false)
        end
    end)
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
    self:AnimateGitHubButton(false)
    self.GitHubButton:SetVisible(false)  -- Hide the GitHub button when loading countries
    titleClickCount = 0  -- Reset click count when loading countries
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
    titleClickCount = 0  -- Reset click count when loading stations
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
            rRadio.PlayStation(self.BoomboxEntity, country, stationInfo.name)
        end
    end
end

function RRADIO.Menu:UpdateCurrentStation(entity)
    if IsValid(entity) then
        local stationCountry = entity:GetNWString("CurrentStationCountry", "")
        local stationName = entity:GetNWString("CurrentStationName", "")
        local currentStatus = entity:GetNWString("CurrentStatus", "")
        
        if currentStatus == "tuning" then
            self:UpdateStatusPanel("Tuning in", rRadio.FormatCountryName(stationCountry))
        elseif currentStatus == "outage" then
            self:UpdateStatusPanel("Station Outage", rRadio.FormatCountryName(stationCountry))
            surface.PlaySound("buttons/button10.wav")
            timer.Simple(2, function()
                if IsValid(self) then
                    self:UpdateStatusPanel(nil, nil)
                end
            end)
        elseif currentStatus == "playing" and stationCountry ~= "" and stationName ~= "" then
            local countryName = rRadio.FormatCountryName(stationCountry)
            self:UpdateStatusPanel(stationName, countryName)
        else
            self:UpdateStatusPanel(nil, nil)
        end
    else
        self:UpdateStatusPanel(nil, nil)
    end
end

function RRADIO.Menu:SetBoomboxEntity(entity)
    self.BoomboxEntity = entity
    if IsValid(self.VolumeSlider) then
        local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
        self.VolumeSlider:SetSlideX(volume)
    end
    self:UpdateCurrentStation(entity)
end

function RRADIO.IsDarkMode()
    return RRADIO.DarkModeConVar:GetBool()
end

function RRADIO.Menu:WobbleTitle()
    if isTitleWobbling or not IsValid(self.Title) then return end
    isTitleWobbling = true
    
    local startTime = SysTime()
    local duration = 1 -- Duration of the wobble in seconds
    local wobbleFrequency = 10
    local wobbleAmplitude = 15
    
    local originalPaint = self.Title.Paint
    self.Title.Paint = function(s, w, h)
        local progress = (SysTime() - startTime) / duration
        if progress >= 1 then
            isTitleWobbling = false
            surface.PlaySound(RRADIO.Sounds.CELEBRATE)
            titleClickCount = 0
            s.Paint = originalPaint
            return
        end
        
        local wobbleOffset = math.sin(progress * math.pi * 2 * wobbleFrequency) * wobbleAmplitude * (1 - progress)
        
        draw.SimpleText(rRadio.Config.MenuTitle, s:GetFont(), w/2 + wobbleOffset, h/2, s:GetTextColor(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function RRADIO.Menu:OnRemove()
    -- Remove any timers or hooks associated with this menu
    if self.TuningTimer then
        timer.Remove(self.TuningTimer)
    end
    if self.TuningTimeoutTimer then
        timer.Remove(self.TuningTimeoutTimer)
    end
    hook.Remove("Think", "rRadio_GitHubButtonFade")
end

-- Register the panel
vgui.Register("rRadioMenu", RRADIO.Menu, "DFrame")

-- Public API
function rRadio.OpenMenu(entity)
    if IsValid(rRadio.Menu) then rRadio.Menu:Remove() end
    rRadio.Menu = vgui.Create("rRadioMenu")
    rRadio.Menu:SetBoomboxEntity(entity)
    rRadio.Menu:UpdateCurrentStation(entity)
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