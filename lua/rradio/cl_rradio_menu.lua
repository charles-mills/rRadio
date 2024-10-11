-- Client-side menu for rRadio

local PANEL = {}

-- Colors
local COLOR_BG = Color(245, 245, 247, 250)
local COLOR_TEXT = Color(29, 29, 31)
local COLOR_ACCENT = Color(0, 122, 255)
local COLOR_BUTTON = Color(255, 255, 255)
local COLOR_BUTTON_HOVER = Color(229, 229, 234)
local COLOR_DIVIDER = Color(209, 209, 214)

-- Font cache
local fontCache = {}

local function GetFont(size, weight)
    local fontName = "rRadio_SFPro_" .. size .. "_" .. (weight or "regular")
    
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = "SF Pro Display", -- This should match the name of your font file (without the extension)
            size = math.Round(ScrH() * (size / 1080)),
            weight = weight or 400,
            antialias = true,
        })
        fontCache[fontName] = true
    end
    
    return fontName
end

local function FormatCountryName(name)
    -- Capitalize the first letter of each word
    return name:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

function PANEL:Init()
    self:SetSize(ScrW() * 0.4, ScrH() * 0.7)
    self:Center()
    self:MakePopup()
    self:SetTitle("")
    self:SetDraggable(false)
    self:ShowCloseButton(false)

    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateScrollPanel()
    self:CreateControlPanel()

    self:LoadCountries()
end

function PANEL:CreateHeader()
    self.Header = self:Add("DPanel")
    self.Header:Dock(TOP)
    self.Header:SetTall(self:GetTall() * 0.08)
    self.Header.Paint = function(s, w, h)
        draw.RoundedBoxEx(8, 0, 0, w, h, COLOR_BG, true, true, false, false)
        surface.SetDrawColor(COLOR_DIVIDER)
        surface.DrawLine(0, h - 1, w, h - 1)
    end

    self.CloseButton = vgui.Create("DButton", self.Header)
    self.CloseButton:SetText("×")
    self.CloseButton:SetTextColor(COLOR_TEXT)
    self.CloseButton:SetFont(GetFont(24, 600))
    self.CloseButton.Paint = function() end
    self.CloseButton.DoClick = function() self:Remove() end

    self.Title = vgui.Create("DLabel", self.Header)
    self.Title:SetText("rRadio")
    self.Title:SetTextColor(COLOR_TEXT)
    self.Title:SetFont(GetFont(24, 600))
end

function PANEL:CreateSearchBar()
    self.SearchBar = self:Add("DTextEntry")
    self.SearchBar:Dock(TOP)
    self.SearchBar:SetTall(self:GetTall() * 0.06)
    self.SearchBar:DockMargin(20, 10, 20, 10)
    self.SearchBar:SetPlaceholderText("Search stations...")
    self.SearchBar:SetFont(GetFont(18))
    self.SearchBar:SetTextColor(COLOR_TEXT)
    self.SearchBar.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BUTTON)
        s:DrawTextEntryText(s:GetTextColor(), s:GetHighlightColor(), s:GetCursorColor())
    end
    self.SearchBar.OnChange = function() self:PerformSearch() end
end

function PANEL:CreateScrollPanel()
    self.Scroll = self:Add("DScrollPanel")
    self.Scroll:Dock(FILL)
    self.Scroll:DockMargin(20, 0, 20, 10)
    local scrollBar = self.Scroll:GetVBar()
    scrollBar:SetHideButtons(true)
    scrollBar.Paint = function() end
    scrollBar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, COLOR_ACCENT)
    end
end

function PANEL:CreateControlPanel()
    self.ControlPanel = self:Add("DPanel")
    self.ControlPanel:Dock(BOTTOM)
    self.ControlPanel:SetTall(self:GetTall() * 0.1)
    self.ControlPanel:DockMargin(20, 10, 20, 20)
    self.ControlPanel.Paint = function(s, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COLOR_BUTTON)
    end

    self.StopButton = self.ControlPanel:Add("DButton")
    self.StopButton:SetText("Stop")
    self.StopButton:SetTextColor(COLOR_ACCENT)
    self.StopButton:SetFont(GetFont(16, 600))
    self.StopButton.Paint = function() end
    self.StopButton.DoClick = function()
        rRadio.StopStation(self.BoomboxEntity)
    end

    self.VolumeSlider = self.ControlPanel:Add("DPanel")
    self.VolumeSlider:SetTall(4)
    self.VolumeSlider.Value = 1
    self.VolumeSlider.Paint = function(s, w, h)
        draw.RoundedBox(2, 0, 0, w, h, COLOR_DIVIDER)
        draw.RoundedBox(2, 0, 0, w * s.Value, h, COLOR_ACCENT)
    end
    self.VolumeSlider.OnMousePressed = function(s)
        s.Dragging = true
    end
    self.VolumeSlider.OnMouseReleased = function(s)
        s.Dragging = false
    end
    self.VolumeSlider.Think = function(s)
        if s.Dragging then
            local x, _ = s:CursorPos()
            s.Value = math.Clamp(x / s:GetWide(), 0, 1)
            rRadio.SetVolume(self.BoomboxEntity, s.Value)
        end
    end
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.CloseButton) then
        self.CloseButton:SetSize(40, 40)
        self.CloseButton:SetPos(w - 50, (self.Header:GetTall() - 40) / 2)
    end
    
    if IsValid(self.Title) then
        self.Title:SizeToContents()
        self.Title:SetPos(20, (self.Header:GetTall() - self.Title:GetTall()) / 2)
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

function PANEL:LoadCountries()
    self.Scroll:Clear()
    self.currentView = "countries"
    for country, stations in pairs(rRadio.Stations) do
        local formattedCountry = FormatCountryName(country)
        local button = self:CreateButton(formattedCountry)
        button.DoClick = function()
            self:LoadStations(country)  -- Use original country name here
        end
        button.OriginalCountry = country  -- Store the original country name
    end
end

function PANEL:LoadStations(country)
    self.Scroll:Clear()
    self.currentView = "stations"
    self.currentCountry = country

    local backButton = self:CreateButton("← Back to Countries")
    backButton.DoClick = function()
        self:LoadCountries()
    end

    local formattedCountry = FormatCountryName(country)
    local countryLabel = self.Scroll:Add("DLabel")
    countryLabel:SetText(formattedCountry)
    countryLabel:SetFont(GetFont(20, 600))
    countryLabel:SetTextColor(COLOR_TEXT)
    countryLabel:Dock(TOP)
    countryLabel:DockMargin(0, 10, 0, 10)

    for i, station in ipairs(rRadio.Stations[country]) do
        local button = self:CreateButton(station.n)
        button.DoClick = function()
            rRadio.PlayStation(self.BoomboxEntity, country, i)
        end
    end
end

function PANEL:CreateButton(text)
    local button = self.Scroll:Add("DButton")
    button:Dock(TOP)
    button:SetTall(self:GetTall() * 0.08)
    button:DockMargin(0, 0, 0, 1)
    button:SetText(text)
    button:SetTextColor(COLOR_TEXT)
    button:SetFont(GetFont(16))
    button.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, s:IsHovered() and COLOR_BUTTON_HOVER or COLOR_BUTTON)
        surface.SetDrawColor(COLOR_DIVIDER)
        surface.DrawLine(0, h - 1, w, h - 1)
    end
    return button
end

function PANEL:PerformSearch()
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
            if string.find(country:lower(), query) then
                local formattedCountry = FormatCountryName(country)
                local button = self:CreateButton(formattedCountry)
                button.DoClick = function()
                    self:LoadStations(country)  -- Use original country name
                end
                button.OriginalCountry = country  -- Store the original country name
            end
        end
    else
        for i, station in ipairs(rRadio.Stations[self.currentCountry]) do
            if string.find(station.n:lower(), query) then
                local button = self:CreateButton(station.n)
                button.DoClick = function()
                    rRadio.PlayStation(self.BoomboxEntity, self.currentCountry, i)
                end
            end
        end
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(8, 0, 0, w, h, COLOR_BG)
end

function PANEL:SetBoomboxEntity(entity)
    self.BoomboxEntity = entity
    if IsValid(self.VolumeSlider) then
        local volume = entity:GetNWFloat("Volume", rRadio.Config.DefaultVolume)
        self.VolumeSlider.Value = volume
    end
end

vgui.Register("rRadioMenu", PANEL, "DFrame")

function rRadio.OpenMenu(entity)
    if IsValid(rRadio.Menu) then rRadio.Menu:Remove() end
    rRadio.Menu = vgui.Create("rRadioMenu")
    rRadio.Menu:SetBoomboxEntity(entity)
end

net.Receive("rRadio_OpenMenu", function()
    local entity = net.ReadEntity()
    if IsValid(entity) and entity:GetClass() == "ent_rradio" then
        rRadio.OpenMenu(entity)
    end
end)

concommand.Add("rradio_open", function(ply, cmd, args)
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) and tr.Entity:GetClass() == "ent_rradio" then
        rRadio.OpenMenu(tr.Entity)
    else
        ply:ChatPrint("You need to look at a rRadio boombox to open the menu.")
    end
end)

net.Receive("rRadio_UpdateBoombox", function()
    local boomboxEnt = net.ReadEntity()
    local stationKey = net.ReadString()
    local stationIndex = net.ReadUInt(16)
    local stationUrl = net.ReadString()

    if IsValid(boomboxEnt) and boomboxEnt:GetClass() == "ent_rradio" then
        boomboxEnt:SetNWString("CurrentStation", stationUrl)
    end
end)
