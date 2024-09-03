util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("ToggleFavoriteCountry")

local ActiveRadios = {}
local debug_mode = false  -- Set to true to enable debug statements
SavedBoomboxStates = SavedBoomboxStates or {}

CreateConVar("rradio_allow_custom_urls", "1", FCVAR_ARCHIVE, "Allow clients to play custom URLs. 1 = Allowed, 0 = Not Allowed")

local function CanPlayCustomURLs()
    return GetConVar("rradio_allow_custom_urls"):GetBool()
end

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
    DebugPrint("Added active radio: Entity " .. tostring(entity:EntIndex()) .. ", Station: " .. stationName)
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
    DebugPrint("Removed active radio: Entity " .. tostring(entity:EntIndex()))
end

-- Restore boombox radio state using saved data
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        DebugPrint("Warning: Could not find PermaProps_ID for entity " .. entity:EntIndex())
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        entity:SetNWString("CurrentRadioStation", savedState.station)
        entity:SetNWString("StationURL", savedState.url)

        if entity.SetStationName then
            entity:SetStationName(savedState.station)
        else
            DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(savedState.url)
            net.WriteFloat(savedState.volume)
            net.Broadcast()
            AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
            DebugPrint("Restored and added active radio for PermaProps_ID: " .. permaID)
        else
            DebugPrint("Station is not playing. Not broadcasting PlayCarRadioStation.")
        end
    end
end

-- Hook to restore boombox radio state on entity creation
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

-- Create boombox_states table if not exists
local function CreateBoomboxStatesTable()
    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS boombox_states (
            permaID INTEGER PRIMARY KEY,
            station TEXT,
            url TEXT,
            isPlaying INTEGER,
            volume REAL
        )
    ]]
    if sql.Query(createTableQuery) == false then
        DebugPrint("Failed to create boombox_states table: " .. sql.LastError())
    else
        DebugPrint("Boombox_states table created or verified successfully")
    end
end

hook.Add("Initialize", "CreateBoomboxStatesTable", CreateBoomboxStatesTable)

-- Save boombox state to database
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume)
    if sql.Query(query) == false then
        DebugPrint("Failed to save boombox state: " .. sql.LastError())
    else
        DebugPrint("Saved boombox state to database: PermaID = " .. permaID)
    end
end

-- Remove boombox state from database
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    if sql.Query(query) == false then
        DebugPrint("Failed to remove boombox state: " .. sql.LastError())
    else
        DebugPrint("Removed boombox state from database: PermaID = " .. permaID)
    end
end

-- Load boombox states from the database into SavedBoomboxStates table
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
            DebugPrint("Loaded boombox state from database: PermaID = " .. permaID)
        end
    else
        SavedBoomboxStates = {}
        DebugPrint("No saved boombox states found in the database.")
    end
end

-- Send active radios to a specific player
local function SendActiveRadiosToPlayer(ply)
    DebugPrint("Sending active radios to player: " .. ply:Nick())
    if next(ActiveRadios) == nil then
        DebugPrint("No active radios found. Retrying in 5 seconds.")
        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            end
        end)
        return
    end

    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
            net.Send(ply)
        else
            DebugPrint("Invalid radio entity detected in SendActiveRadiosToPlayer.")
        end
    end
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
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

net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)

    if not IsValid(entity) then 
        DebugPrint("Invalid entity received in PlayCarRadioStation.")
        return 
    end

    DebugPrint("PlayCarRadioStation received: Entity " .. entity:EntIndex())

    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        local permaID = entity.PermaProps_ID
        if permaID then
            SavedBoomboxStates[permaID] = {
                station = stationName,
                url = url,
                isPlaying = true,
                volume = volume
            }
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

        AddActiveRadio(entity, stationName, url, volume)

        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()

    elseif entity:IsVehicle() then
        AddActiveRadio(entity, stationName, url, volume)

        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()
    end
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if entity:GetClass() == "golden_boombox" or entity:GetClass() == "boombox" then
        local permaID = entity.PermaProps_ID
        if permaID and SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end

        if entity.SetStationName then
            entity:SetStationName("")
        else
            DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

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

hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    if ActiveRadios[entity:EntIndex()] then
        RemoveActiveRadio(entity)
    end
end)

if not PermaProps then PermaProps = {} end
PermaProps.SpecialENTSSpawn = PermaProps.SpecialENTSSpawn or {}

-- Add handling for boombox entities via a PermaProps hook
PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    local permaID = ent.PermaProps_ID
    if not permaID then return end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        ent:SetNWString("CurrentRadioStation", savedState.station)
        ent:SetNWString("StationURL", savedState.url)

        if ent.SetStationName then
            ent:SetStationName(savedState.station)
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(ent)
            net.WriteString(savedState.url)
            net.WriteFloat(savedState.volume)
            net.Broadcast()

            AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
        end
    end
end

-- Add handling for golden_boombox entities
PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

-- Similar entries can be added for other custom radio entities if needed

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()

    -- Existing boombox states will be restored by PermaProps.SpecialENTSSpawn functions when they are spawned
    DebugPrint("Finished restoring active radios")
end)

-- Clear all boombox states from the database
concommand.Add("rradio_remove_all", function(ply, cmd, args)
    if not ply or ply:IsAdmin() then
        local result = sql.Query("DELETE FROM boombox_states")
        if result == false then
            print("[CarRadio] Failed to clear boombox states: " .. sql.LastError())
        else
            print("[CarRadio] All boombox states cleared successfully.")
            SavedBoomboxStates = {}
            ActiveRadios = {}
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)
