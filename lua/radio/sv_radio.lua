util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("ToggleFavoriteCountry")
util.AddNetworkString("SendFavoriteCountries")

local ActiveRadios = {}
local debug_mode = false  -- Set to true to enable debug statements
SavedBoomboxStates = SavedBoomboxStates or {}

local defaultFavorites = {"The_united_kingdom", "The_united_states_of_america"}
local playerFavorites = {}

-- Debug function to print messages if debug_mode is enabled
local function DebugPrint(msg)
    if debug_mode then
        print("[CarRadio Debug] " .. msg)
    end
end

-- Function to add a radio to the active list
local function AddActiveRadio(entity, stationName, url, volume)
    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }

    -- Print the contents of the ActiveRadios table
    DebugPrint("ActiveRadios:")
    for index, radio in pairs(ActiveRadios) do
        DebugPrint("Index: " .. index)
        DebugPrint("Entity: " .. tostring(radio.entity))
        DebugPrint("Station Name: " .. radio.stationName)
        DebugPrint("URL: " .. radio.url)
        DebugPrint("Volume: " .. radio.volume)
    end
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

-- Function to restore the radio station if needed
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        print("Warning: Could not find PermaProps_ID for entity " .. entity:EntIndex())
        return
    end

    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        local savedState = SavedBoomboxStates[permaID]

        if savedState then
            print("Restoring station: " .. savedState.station)
            entity:SetNWString("CurrentRadioStation", savedState.station)
            entity:SetNWString("StationURL", savedState.url)
            if entity.SetStationName then
                entity:SetStationName(savedState.station)
            else
                print("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
            end

            if savedState.isPlaying then
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
                net.Broadcast()
                AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
                print("Added active radio for PermaProps_ID: " .. permaID)
            else
                print("Station is not playing. Not broadcasting PlayCarRadioStation.")
            end
        end
    end
end

-- Hook into OnEntityCreated to restore the boombox radio state for PermaProps
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()  -- Increased delay to ensure the entity is fully initialized
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

-- Function to create the boombox_states table if it doesn't exist
hook.Add("Initialize", "CreateBoomboxStatesTable", function()
    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS boombox_states (
            permaID INTEGER PRIMARY KEY,
            station TEXT,
            url TEXT,
            isPlaying INTEGER,
            volume REAL
        )
    ]]

    local result = sql.Query(createTableQuery)
    if result == false then
        DebugPrint("Failed to create boombox_states table: " .. sql.LastError())
    else
        DebugPrint("Boombox_states table created or verified successfully")
    end
end)

-- Function to save a boombox state to the database
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume)
    local result = sql.Query(query)
    if result == false then
        DebugPrint("Failed to save boombox state: " .. sql.LastError())
    else
        DebugPrint("Saved boombox state to database: PermaID = " .. permaID .. ", Station = " .. stationName .. ", URL = " .. url)
    end
end

-- Function to remove a boombox state from the database
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    local result = sql.Query(query)
    if result == false then
        DebugPrint("Failed to remove boombox state: " .. sql.LastError())
    else
        DebugPrint("Removed boombox state from database: PermaID = " .. permaID)
    end
end

-- Function to load boombox states from the database into the SavedBoomboxStates table
local function LoadBoomboxStatesFromDatabase()
    local rows = sql.Query("SELECT * FROM boombox_states")
    if rows then
        for _, row in ipairs(rows) do
            local permaID = tonumber(row.permaID)
            SavedBoomboxStates[permaID] = {
                station = row.station,
                url = row.url,
                isPlaying = tonumber(row.isPlaying) == 1,
                volume = tonumber(row.volume)
            }
            DebugPrint("Loaded boombox state from database: PermaID = " .. permaID .. ", Station = " .. row.station .. " URL: " .. row.url)
        end
    else
        SavedBoomboxStates = {}
        DebugPrint("No saved boombox states found in the database.")
    end
end

-- Function to save player favorites to a file
local function SavePlayerFavorites(ply)
    local steamID = ply:SteamID()
    file.Write("radio_favorites/" .. steamID .. ".txt", util.TableToJSON(playerFavorites[steamID]))
end

-- Function to load player favorites from a file
local function LoadPlayerFavorites(ply)
    local steamID = ply:SteamID()
    if not playerFavorites[steamID] then
        -- Check if the file exists
        if file.Exists("radio_favorites/" .. steamID .. ".txt", "DATA") then
            local data = file.Read("radio_favorites/" .. steamID .. ".txt", "DATA")
            playerFavorites[steamID] = util.JSONToTable(data)
        else
            -- Initialize with default favorites if the file doesn't exist
            playerFavorites[steamID] = table.Copy(defaultFavorites)
            SavePlayerFavorites(ply)
        end
    end
end

-- Hook to load player favorites when they join
hook.Add("PlayerInitialSpawn", "LoadPlayerRadioFavorites", function(ply)
    LoadPlayerFavorites(ply)
    net.Start("SendFavoriteCountries")
    net.WriteTable(playerFavorites[ply:SteamID()])
    net.Send(ply)
end)

-- Network message handling for toggling favorite countries
net.Receive("ToggleFavoriteCountry", function(len, ply)
    local steamID = ply:SteamID()
    local country = net.ReadString()

    if not playerFavorites[steamID] then
        playerFavorites[steamID] = {}
    end

    if table.HasValue(playerFavorites[steamID], country) then
        -- Remove from favorites
        for i, favCountry in ipairs(playerFavorites[steamID]) do
            if favCountry == country then
                table.remove(playerFavorites[steamID], i)
                break
            end
        end
    else
        -- Add to favorites
        table.insert(playerFavorites[steamID], country)
    end

    SavePlayerFavorites(ply)

    -- Send the updated favorites back to the client
    net.Start("SendFavoriteCountries")
    net.WriteTable(playerFavorites[steamID])
    net.Send(ply)
end)

-- Function to send active radios to a specific player
local function SendActiveRadiosToPlayer(ply)
    DebugPrint("Sending active radios to player: " .. ply:Nick())
    if next(ActiveRadios) == nil then
        DebugPrint("No active radios found. Retrying in 5 seconds.")
        timer.Simple(5, function()
            SendActiveRadiosToPlayer(ply)
        end)
        return
    end

    for _, radio in pairs(ActiveRadios) do
        -- Check if the entity is valid before sending
        DebugPrint("Checking radio entity validity in SendActiveRadiosToPlayer.")
        if IsValid(radio.entity) then
            DebugPrint("Sending active radio: Entity " .. tostring(radio.entity:EntIndex()) .. ", Station: " .. tostring(radio.stationName) .. ", URL: " .. tostring(radio.url) .. ", Volume: " .. tostring(radio.volume))

            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)  -- Send the correct URL
            net.WriteFloat(radio.volume) -- Send the actual volume
            net.Send(ply)
        else
            DebugPrint("Invalid radio entity detected in SendActiveRadiosToPlayer.")
        end
    end
end

-- Hook to send active radios when a player initially joins
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    -- Add a short delay to ensure entities are fully loaded on the client
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
            DebugPrint("I'm sending you the active radios :)")
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    net.Start("CarRadioMessage")
    net.Send(ply)
end)

net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)  -- Ensure volume is clamped between 0 and 1

    if not IsValid(entity) then 
        DebugPrint("Invalid entity received in PlayCarRadioStation.")
        return 
    end

    DebugPrint("PlayCarRadioStation received. Entity: " .. entity:EntIndex() .. ", Station: " .. stationName .. ", URL: " .. url .. ", Volume: " .. volume)

    -- Check if the entity is a boombox or a vehicle
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        local permaID = entity.PermaProps_ID
        if permaID then
            -- Save the station, URL, and playing state using the PermaProps ID
            SavedBoomboxStates[permaID] = {
                station = stationName,
                url = url,               -- Save the URL here
                isPlaying = true,
                volume = volume
            }

            -- Save to database
            SaveBoomboxStateToDatabase(permaID, stationName, url, true, volume)
        end

        if entity.SetVolume then
            entity:SetVolume(volume)
        else
            DebugPrint("Warning: SetVolume function not found for entity: " .. entity:EntIndex())
        end

        if entity.SetStationName then
            entity:SetStationName(stationName)
        else
            DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        AddActiveRadio(entity, stationName, url, volume)  -- Save both station name and URL

        -- Broadcast the station play request to all clients
        DebugPrint("Broadcasting PlayCarRadioStation for entity: " .. entity:EntIndex())
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)  -- Broadcast the URL
        net.WriteFloat(volume)
        net.Broadcast()

        -- Update clients with the current station name
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()

    elseif entity:IsVehicle() then
        AddActiveRadio(entity, stationName, url, volume)  -- Save both station name and URL

        -- Broadcast the station play request to all clients without setting volume on the vehicle
        DebugPrint("Broadcasting PlayCarRadioStation for vehicle: " .. entity:EntIndex())
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)  -- Broadcast the URL
        net.WriteFloat(volume)
        net.Broadcast()

        -- Update clients with the current station name (if applicable for vehicles)
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()
    end
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    -- Check if the entity is a boombox or a vehicle
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        local permaID = entity.PermaProps_ID
        if permaID and SavedBoomboxStates[permaID] then
            -- Update the saved state to reflect that the station is not playing
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end

        if entity.SetStationName then
            entity:SetStationName("")
        else
            DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        RemoveActiveRadio(entity)

        -- Broadcast the stop request to all clients
        net.Start("StopCarRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        -- Update clients to clear the station name
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
        net.Broadcast()

    elseif entity:IsVehicle() then
        -- Handle vehicle-specific stop logic here
        RemoveActiveRadio(entity)

        -- Broadcast the stop request to all clients
        net.Start("StopCarRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
        net.Broadcast()
    end
end)

-- Hook to clean up active radios if an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    if ActiveRadios[entity:EntIndex()] then
        RemoveActiveRadio(entity)
    end
end)

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    DebugPrint("Attempting to load Boombox States from the database")
    
    LoadBoomboxStatesFromDatabase()

    DebugPrint("Boombox States Loaded")
    for permaID, savedState in pairs(SavedBoomboxStates) do
        if savedState.isPlaying then
            DebugPrint("Checking saved state for PermaProps_ID: " .. permaID)
            for _, entity in pairs(ents.GetAll()) do
                if entity.PermaProps_ID == permaID then
                    DebugPrint("Adding active radio for PermaProps_ID: " .. permaID)
                    AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
                    break
                end
            end
        end
    end
    DebugPrint("Finished restoring active radios")
end)

-- Console command to clear all boombox states from the database
concommand.Add("rradio_remove_all", function(ply, cmd, args)
    if not ply or ply:IsAdmin() then
        local result = sql.Query("DELETE FROM boombox_states")
        if result == false then
            print("[CarRadio] Failed to clear boombox states: " .. sql.LastError())
        else
            print("[CarRadio] All boombox states cleared successfully.")
            -- Clear the in-memory states as well
            SavedBoomboxStates = {}
            -- Clear ActiveRadios as well
            ActiveRadios = {}
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)
