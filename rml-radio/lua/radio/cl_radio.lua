include("radio/key_names.lua")
include("radio/config.lua")

surface.CreateFont("Roboto18", {
    font = "Roboto",
    size = ScreenScale(5), -- Use ScreenScale for dynamic font size
    weight = 500,
})

local selectedCountry = nil
local radioMenuOpen = false
local currentlyPlayingStation = nil
local driverVolume = Config.Volume -- This represents the volume set by the driver

local currentRadioStations = {}

local lastMessageTime = -math.huge -- Initialize to a value that ensures the first message shows immediately

local function PrintCarRadioMessage()
    if not GetConVar("car_radio_show_messages"):GetBool() then return end

    local currentTime = CurTime() -- Get the current time

    -- Check if enough time has passed since the last message was shown
    if (currentTime - lastMessageTime) < Config.MessageCooldown and lastMessageTime ~= -math.huge then
        return -- Exit if the cooldown period hasn't passed
    end

    lastMessageTime = currentTime -- Update the last message time

    local prefixColor = Color(0, 255, 128)  -- Aqua/Teal color for the prefix
    local keyColor = Color(255, 165, 0)  -- Orange color for the key
    local messageColor = Color(255, 255, 255)  -- White color for the rest of the message
    local keyName = GetKeyName(Config.OpenKey)

    local message = Config.Lang["PressKeyToOpen"]:gsub("{key}", keyName)

    chat.AddText(
        prefixColor, "[CAR RADIO] ",
        messageColor, message
    )
end

-- Listen for the net message from the server
net.Receive("CarRadioMessage", function()
    PrintCarRadioMessage()
end)

local function Scale(value)
    return value * (ScrW() / 2560)
end

-- Country translation table
local CountryTranslations = {
    en = {
        ["the_united_kingdom"] = "United Kingdom",
        ["the_united_states_of_america"] = "United States of America",
        -- Add other country translations
    },
    es = {
        ["the_united_kingdom"] = "Reino Unido",
        ["the_united_states_of_america"] = "Estados Unidos de América",
        -- Add other country translations
    },
    -- Add more languages here
}

-- Helper function to format and translate country names
local function formatCountryName(name)
    local lang = GetConVar("radio_language"):GetString() or "en"
    local translation = CountryTranslations[lang] and CountryTranslations[lang][name] or name
    -- Replace underscores with spaces and apply title case
    return translation:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
end

local function populateList(stationListPanel, backButton, searchBox, resetSearch)
    stationListPanel:Clear()

    if resetSearch then
        searchBox:SetText("")  -- Reset the search box text
    end

    local filterText = searchBox:GetText()  -- Get the current search box text

    if selectedCountry == nil then
        backButton:SetVisible(false) -- Hide the back button when viewing countries

        -- Collect and sort the countries
        local countries = {}
        for country, _ in pairs(Config.RadioStations) do
            local translatedCountry = formatCountryName(country)
            if filterText == "" or string.find(translatedCountry:lower(), filterText:lower(), 1, true) then
                table.insert(countries, { original = country, translated = translatedCountry })
            end
        end

        if Config.UKAndUSPrioritised then
            -- Custom sort: US and UK at the top, followed by alphabetical order
            table.sort(countries, function(a, b)
                local UK_OPTIONS = {"United Kingdom", "The United Kingdom", "the_united_kingdom"}
                local US_OPTIONS = {"United States", "The United States Of America", "the_united_states_of_america"}

                if table.HasValue(UK_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(UK_OPTIONS, b.original) then
                    return false
                elseif table.HasValue(US_OPTIONS, a.original) then
                    return true
                elseif table.HasValue(US_OPTIONS, b.original) then
                    return false 
                else
                    return a.translated < b.translated
                end
            end)
        else
            -- Default sort: Alphabetical order
            table.sort(countries, function(a, b) return a.translated < b.translated end)
        end

        -- Populate with sorted countries
        for _, country in ipairs(countries) do
            local countryButton = vgui.Create("DButton", stationListPanel)
            countryButton:Dock(TOP)
            countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            countryButton:SetTall(Scale(40))
            countryButton:SetText(country.translated)  -- Display the translated country name
            countryButton:SetFont("Roboto18")
            countryButton:SetTextColor(Config.UI.TextColor)

            countryButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end

            countryButton.DoClick = function()
                selectedCountry = country.original
                backButton:SetVisible(true) -- Show the back button when viewing radio stations
                populateList(stationListPanel, backButton, searchBox, true)
            end
        end
    else
        -- Populate with stations for the selected country
        for _, station in ipairs(Config.RadioStations[selectedCountry]) do
            if filterText == "" or string.find(station.name:lower(), filterText:lower(), 1, true) then
                local stationButton = vgui.Create("DButton", stationListPanel)
                stationButton:Dock(TOP)
                stationButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
                stationButton:SetTall(Scale(40))
                stationButton:SetText(station.name)
                stationButton:SetFont("Roboto18")
                stationButton:SetTextColor(Config.UI.TextColor)

                stationButton.Paint = function(self, w, h)
                    if station == currentlyPlayingStation then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.PlayingButtonColor)
                    else
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                        if self:IsHovered() then
                            draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                        end
                    end
                end

                stationButton.DoClick = function()
                    if currentlyPlayingStation then
                        net.Start("StopCarRadioStation")
                        net.SendToServer()
                    end

                    net.Start("PlayCarRadioStation")
                    net.WriteString(station.url)
                    net.WriteFloat(driverVolume) -- Send the volume setting with the station URL
                    net.SendToServer()

                    currentlyPlayingStation = station
                    populateList(stationListPanel, backButton, searchBox, false)
                end
            end
        end
    end
end

local function openRadioMenu()
    if radioMenuOpen then return end
    radioMenuOpen = true

    -- Create the main frame with dynamic size and positioning
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(Scale(Config.UI.FrameSize.width), Scale(Config.UI.FrameSize.height))
    frame:Center()
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.OnClose = function() radioMenuOpen = false end

    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.BackgroundColor)
        draw.RoundedBox(8, 0, 0, w, Scale(30), Config.UI.HeaderColor)
        draw.SimpleText(selectedCountry and formatCountryName(selectedCountry) or Config.Lang["SelectCountry"], "Roboto18", Scale(10), Scale(5), Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Create a search bar
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(Scale(10), Scale(40)) -- Position below the header
    searchBox:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(30))
    searchBox:SetFont("Roboto18")
    searchBox:SetPlaceholderText(Config.Lang["SearchPlaceholder"])
    searchBox:SetTextColor(Config.UI.TextColor)
    searchBox:SetDrawBackground(false)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.SearchBoxColor)
        self:DrawTextEntryText(Config.UI.TextColor, Color(120, 120, 120), Config.UI.TextColor)

        if self:GetText() == "" then
            draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), Scale(5), h / 2, Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Create a scrollable panel for the station list
    local stationListPanel = vgui.Create("DScrollPanel", frame)
    stationListPanel:SetPos(Scale(10), Scale(80)) -- Position below the search box
    stationListPanel:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(Config.UI.FrameSize.height) - Scale(190)) -- Explicitly set size

    -- Create a volume control slider
    local volumeSlider = vgui.Create("DNumSlider", frame)
    volumeSlider:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(100)) -- Position slider above the stop button
    volumeSlider:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(40))
    volumeSlider:SetText("")
    volumeSlider:SetMin(0)
    volumeSlider:SetMax(1)
    volumeSlider:SetDecimals(2)
    volumeSlider:SetValue(driverVolume)
    
    volumeSlider.Slider.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, h/2 - 2, w, 4, Config.UI.HeaderColor) -- Slider track
    end

    volumeSlider.Slider.Knob.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor) -- Slider handle
    end

    volumeSlider.TextArea:SetTextColor(Config.UI.TextColor)
    volumeSlider.TextArea:SetFont("Roboto18")
    volumeSlider.Label:SetVisible(false) -- Hide default label

    -- Volume control logic
    volumeSlider.OnValueChanged = function(_, value)
        driverVolume = value
        local vehicle = LocalPlayer():GetVehicle()
        if currentlyPlayingStation and IsValid(currentRadioStations[vehicle]) then
            -- Just update the volume of the existing stream
            currentRadioStations[vehicle]:SetVolume(driverVolume)
        end
    end

    -- Create the Stop Radio button
    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(Scale(10), Scale(Config.UI.FrameSize.height) - Scale(50)) -- Position at the bottom
    stopButton:SetSize(Scale(Config.UI.FrameSize.width) - Scale(20), Scale(40))
    stopButton:SetText(Config.Lang["StopRadio"])
    stopButton:SetFont("Roboto18")
    stopButton:SetTextColor(Config.UI.TextColor)
    stopButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonColor)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, Config.UI.CloseButtonHoverColor)
        end
    end

    stopButton.DoClick = function()
        net.Start("StopCarRadioStation")
        net.SendToServer()
        currentlyPlayingStation = nil
        populateList(stationListPanel, backButton, searchBox, false)
    end
    
    -- Back arrow to return to the country selection
    local backButton = vgui.Create("DButton", frame)
    backButton:SetSize(Scale(30), Scale(30)) -- Adjust size to fit the header
    backButton:SetPos(frame:GetWide() - Scale(79), 0) -- Position just to the left of the close button
    backButton:SetText("") -- No text, just the arrow

    backButton.Paint = function(self, w, h)
        draw.NoTexture()
        local arrowSize = Scale(15)
        local arrowOffset = Scale(8)
        local arrowColor = self:IsHovered() and Config.UI.ButtonHoverColor or Config.UI.TextColor

        surface.SetDrawColor(arrowColor)
        surface.DrawPoly({
            { x = arrowOffset, y = h / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 - arrowSize / 2 },
            { x = arrowOffset + arrowSize, y = h / 2 + arrowSize / 2 },
        })
    end

    backButton.DoClick = function()
        selectedCountry = nil
        backButton:SetVisible(false) -- Hide the back button when returning to the country selection
        populateList(stationListPanel, backButton, searchBox, true)
    end

    -- Custom close button with dynamic size and positioning
    local closeButton = vgui.Create("DButton", frame)
    closeButton:SetText("X")
    closeButton:SetFont("Roboto18")
    closeButton:SetTextColor(Config.UI.TextColor)
    closeButton:SetSize(Scale(40), Scale(30))
    closeButton:SetPos(frame:GetWide() - Scale(39), 0)
    closeButton.Paint = function(self, w, h)
        local cornerRadius = 8  -- Same corner radius as the frame
        draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonColor, false, true, false, false)
        if self:IsHovered() then
            draw.RoundedBoxEx(cornerRadius, 0, 0, w, h, Config.UI.CloseButtonHoverColor, false, true, false, false)
        end
    end
    closeButton.DoClick = function()
        frame:Close()
    end

    -- Customize the scrollbar for the station list
    local sbar = stationListPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    -- Populate the list with initial data
    populateList(stationListPanel, backButton, searchBox, true)

    -- Update the list dynamically as the user types in the search box
    searchBox.OnChange = function(self)
        populateList(stationListPanel, backButton, searchBox, false)
    end
end

hook.Add("Think", "OpenCarRadioMenu", function()
    if input.IsKeyDown(Config.OpenKey) and not radioMenuOpen and IsValid(LocalPlayer():GetVehicle()) then
        openRadioMenu()
    end
end)

-- Play the radio station when received from the server
net.Receive("PlayCarRadioStation", function()
    local vehicle = net.ReadEntity()
    local url = net.ReadString()
    local driverVolume = net.ReadFloat() -- Receive the volume set by the driver

    if not IsValid(vehicle) then return end

    -- Stop the previous station if it exists
    if currentRadioStations[vehicle] and IsValid(currentRadioStations[vehicle]) then
        currentRadioStations[vehicle]:Stop()
    end

    -- Retry logic: Try up to Config.RetryAttempts to play the station
    local function tryPlayStation(attempt)
        sound.PlayURL(url, "3d mono", function(station, errorID, errorName)
            if IsValid(station) then
                station:SetPos(vehicle:GetPos())
                station:SetVolume(driverVolume)
                station:Play()
                currentRadioStations[vehicle] = station

                -- Update the station's position and volume to follow the vehicle
                hook.Add("Think", "UpdateRadioPosition_" .. vehicle:EntIndex(), function()
                    if IsValid(vehicle) and IsValid(station) then
                        -- Update the position of the sound to follow the vehicle
                        station:SetPos(vehicle:GetPos())
                
                        local playerPos = LocalPlayer():GetPos()
                        local vehiclePos = vehicle:GetPos()
                        local distance = playerPos:Distance(vehiclePos)
                
                        -- Check if the player is in the vehicle
                        local isPlayerInCar = LocalPlayer():GetVehicle() == vehicle
                
                        updateRadioVolume(station, distance, isPlayerInCar)
                    else
                        hook.Remove("Think", "UpdateRadioPosition_" .. vehicle:EntIndex())
                    end
                end)
                

                -- Add a hook to stop the radio when the vehicle is removed
                hook.Add("EntityRemoved", "StopRadioOnVehicleRemove_" .. vehicle:EntIndex(), function(ent)
                    if ent == vehicle then
                        if IsValid(currentRadioStations[vehicle]) then
                            currentRadioStations[vehicle]:Stop()
                        end
                        currentRadioStations[vehicle] = nil
                        hook.Remove("EntityRemoved", "StopRadioOnVehicleRemove_" .. vehicle:EntIndex())
                        hook.Remove("Think", "UpdateRadioPosition_" .. vehicle:EntIndex())
                    end
                end)
            else
                if attempt < Config.RetryAttempts then
                    print("Retrying to play radio station... attempt " .. attempt .. " Error: " .. errorName)
                    timer.Simple(Config.RetryDelay, function() -- Retry after delay
                        tryPlayStation(attempt + 1)
                    end)
                else
                    print("Failed to play radio station for vehicle:", vehicle, "Error:", errorName)
                end
            end
        end)
    end

    tryPlayStation(1) -- Start the first attempt
end)

-- Stop the radio station when received from the server
net.Receive("StopCarRadioStation", function()
    local vehicle = net.ReadEntity()

    if IsValid(vehicle) and IsValid(currentRadioStations[vehicle]) then
        currentRadioStations[vehicle]:Stop()
        currentRadioStations[vehicle] = nil
        local entIndex = vehicle:EntIndex()
        hook.Remove("EntityRemoved", "StopRadioOnVehicleRemove_" .. entIndex)
        hook.Remove("Think", "UpdateRadioPosition_" .. entIndex)
    end
end)
