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
    keyName = GetKeyName(Config.OpenKey)

    chat.AddText(
        prefixColor, "[CAR RADIO] ",
        messageColor, "Press ", 
        keyColor, keyName,
        messageColor, " to pick a station"
    )
end

-- Listen for the net message from the server
net.Receive("CarRadioMessage", function()
    PrintCarRadioMessage()
end)

local function Scale(value)
    return value * (ScrW() / 2560)
end

local function updateRadioVolume(station, distance)
    local maxVolume = GetConVar("radio_max_volume"):GetFloat() -- Get the player's max volume setting
    local effectiveVolume = math.min(driverVolume, maxVolume) -- Cap the volume by the client's max setting

    if distance <= Config.MinVolumeDistance then
        station:SetVolume(effectiveVolume)
    elseif distance <= Config.MaxHearingDistance then
        local adjustedVolume = effectiveVolume * (1 - (distance - Config.MinVolumeDistance) / (Config.MaxHearingDistance - Config.MinVolumeDistance))
        station:SetVolume(adjustedVolume)
    else
        station:SetVolume(0)
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
        draw.SimpleText(selectedCountry and "Select a Radio Station" or "Select a Country", "Roboto18", Scale(10), Scale(5), Config.UI.TextColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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

    -- Create a scrollable panel for the country or radio list
    local listPanel = vgui.Create("DScrollPanel", frame)
    listPanel:Dock(FILL)
    listPanel:DockMargin(Scale(10), Scale(10), Scale(10), Scale(10))

    -- Customize the scrollbar
    local sbar = listPanel:GetVBar()
    sbar:SetWide(Scale(8))
    function sbar:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnUp:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnDown:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarColor) end
    function sbar.btnGrip:Paint(w, h) draw.RoundedBox(8, 0, 0, w, h, Config.UI.ScrollbarGripColor) end

    -- Function to populate the list with countries or stations
    local function populateList()
        listPanel:Clear()

        if selectedCountry == nil then
            -- Populate with countries
            for country, _ in pairs(Config.RadioStations) do
                local countryButton = vgui.Create("DButton", listPanel)
                countryButton:Dock(TOP)
                countryButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
                countryButton:SetTall(Scale(40))
                countryButton:SetText(country)
                countryButton:SetFont("Roboto18")
                countryButton:SetTextColor(Config.UI.TextColor)

                countryButton.Paint = function(self, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                    if self:IsHovered() then
                        draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                    end
                end

                countryButton.DoClick = function()
                    selectedCountry = country
                    populateList()
                end
            end
        else
            -- Populate with stations for the selected country
            for _, station in ipairs(Config.RadioStations[selectedCountry]) do
                local stationButton = vgui.Create("DButton", listPanel)
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
                    populateList()
                end
            end

            -- Back button to return to the country selection
            local backButton = vgui.Create("DButton", listPanel)
            backButton:Dock(BOTTOM)
            backButton:DockMargin(Scale(5), Scale(5), Scale(5), 0)
            backButton:SetTall(Scale(40))
            backButton:SetText("Back to Country Selection")
            backButton:SetFont("Roboto18")
            backButton:SetTextColor(Config.UI.TextColor)
            backButton.Paint = function(self, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonColor)
                if self:IsHovered() then
                    draw.RoundedBox(8, 0, 0, w, h, Config.UI.ButtonHoverColor)
                end
            end
            backButton.DoClick = function()
                selectedCountry = nil
                populateList()
            end
        end
    end

    populateList()
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

                        -- Update the volume based on the client's max volume setting
                        local playerPos = LocalPlayer():GetPos()
                        local vehiclePos = vehicle:GetPos()
                        local distance = playerPos:Distance(vehiclePos)

                        updateRadioVolume(station, distance)
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
