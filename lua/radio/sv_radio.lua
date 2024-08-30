util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")

local ActiveRadios = {}
SavedBoomboxStates = SavedBoomboxStates or {}
local debug_mode = true  -- Set to true to enable debug statements

-- Debug function to print messages if debug_mode is enabled
local function DebugPrint(msg)
    if debug_mode then
        print("[CarRadio Debug] " .. msg)
    end
end

-- Ensure the table exists
local createTableQuery = "CREATE TABLE IF NOT EXISTS boombox_states (permaID INTEGER PRIMARY KEY, station TEXT, url TEXT, isPlaying INTEGER, volume REAL)"
local createResult = sql.Query(createTableQuery)
if createResult == false then
    DebugPrint("Failed to create boombox_states table: " .. sql.LastError())
else
    DebugPrint("Boombox_states table checked/created successfully")
end

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
            DebugPrint("Loaded boombox state from database: PermaID = " .. permaID .. ", Station = " .. row.station)
        end
    else
        SavedBoomboxStates = {}
        DebugPrint("No saved boombox states found in the database.")
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
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

-- Function to send active radios to a specific player
local function SendActiveRadiosToPlayer(ply)
    for _, radio in pairs(ActiveRadios) do
        -- Check if the entity is valid before sending
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)  -- Send the correct URL
            net.WriteFloat(radio.volume) -- Send the actual volume
            net.Send(ply)
        end
    end
end

-- Hook to send active radios when a player initially joins
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    -- Add a short delay to ensure entities are fully loaded on the client
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    net.Start("CarRadioMessage")
    net.Send(ply)
end)

-- net.Receive for playing the car radio station
net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)

    if not IsValid(entity) then return end

    -- Check if the entity is a PermaProp by checking for PermaProps_ID
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

    -- Handle both boomboxes and vehicles differently
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        -- Ensure the entity has the SetVolume and SetStationName methods before calling them
        if entity.SetVolume then
            entity:SetVolume(volume)
        else
            print("[CarRadio Debug] Warning: Entity " .. tostring(entity) .. " does not have a SetVolume method.")
        end
        
        if entity.SetStationName then
            entity:SetStationName(stationName)
        else
            print("[CarRadio Debug] Warning: Entity " .. tostring(entity) .. " does not have a SetStationName method.")
        end
    elseif entity:IsVehicle() then
        -- For vehicles, we don't set volume or station name, just add them to the active list
        print("[CarRadio Debug] Entity is a vehicle, no SetVolume or SetStationName needed.")
    else
        print("[CarRadio Debug] Entity is neither a recognized boombox nor a vehicle.")
    end

    -- Add the radio to the active list
    AddActiveRadio(entity, stationName, url, volume)

    -- Broadcast the station play request to all clients
    net.Start("PlayCarRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.Broadcast()

    -- Update clients with the current station name
    net.Start("UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString(stationName)
    net.Broadcast()
end)

-- net.Receive for stopping the car radio station
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    -- Check if the entity is a PermaProp by checking for PermaProps_ID
    local permaID = entity.PermaProps_ID

    -- Update the saved state to reflect that the station is not playing
    if permaID and SavedBoomboxStates and SavedBoomboxStates[permaID] then
        SavedBoomboxStates[permaID].isPlaying = false
        SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
    end

    -- Existing logic to stop the station
    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        entity:SetStationName("")
        RemoveActiveRadio(entity)

        net.Start("StopCarRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
        net.Broadcast()
    elseif entity:IsVehicle() then
        RemoveActiveRadio(entity)

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

-- Load boombox states from the database when the server starts
hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    LoadBoomboxStatesFromDatabase()
end)

-- Console command to clear all boombox states from the database
concommand.Add("rradio_remove_all", function(ply, cmd, args)
    if ply:IsAdmin() then
        local result = sql.Query("DELETE FROM boombox_states")
        if result == false then
            print("[CarRadio] Failed to clear boombox states: " .. sql.LastError())
        else
            print("[CarRadio] All boombox states cleared successfully.")
            -- Clear the in-memory states as well
            SavedBoomboxStates = {}
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)
