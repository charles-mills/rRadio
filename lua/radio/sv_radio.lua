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

-- Add radio to active list and log details if in debug mode
local function AddActiveRadio(entity, stationName, url, volume)
    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }
    DebugPrint("Active Radios Updated: " .. table.Count(ActiveRadios) .. " active radios")
end

-- Remove radio from active list
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
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

-- Save player favorites to a file
local function SavePlayerFavorites(ply)
    local steamID = ply:SteamID()
    file.Write("radio_favorites/" .. steamID .. ".txt", util.TableToJSON(playerFavorites[steamID]))
end

-- Load player favorites from a file
local function LoadPlayerFavorites(ply)
    local steamID = ply:SteamID()
    if not playerFavorites[steamID] then
        if file.Exists("radio_favorites/" .. steamID .. ".txt", "DATA") then
            local data = file.Read("radio_favorites/" .. steamID .. ".txt", "DATA")
            playerFavorites[steamID] = util.JSONToTable(data)
        else
            playerFavorites[steamID] = table.Copy(defaultFavorites)
            SavePlayerFavorites(ply)
        end
    end
end

hook.Add("PlayerInitialSpawn", "LoadPlayerRadioFavorites", function(ply)
    LoadPlayerFavorites(ply)
    net.Start("SendFavoriteCountries")
    net.WriteTable(playerFavorites[ply:SteamID()])
    net.Send(ply)
end)

-- Toggle favorite country and save the player's favorites
net.Receive("ToggleFavoriteCountry", function(len, ply)
    local steamID = ply:SteamID()
    local country = net.ReadString()

    playerFavorites[steamID] = playerFavorites[steamID] or {}

    if table.HasValue(playerFavorites[steamID], country) then
        table.RemoveByValue(playerFavorites[steamID], country)
    else
        table.insert(playerFavorites[steamID], country)
    end

    SavePlayerFavorites(ply)
    net.Start("SendFavoriteCountries")
    net.WriteTable(playerFavorites[steamID])
    net.Send(ply)
end)

-- Send active radios to a specific player
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

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()

    for permaID, savedState in pairs(SavedBoomboxStates) do
        if savedState.isPlaying then
            for _, entity in pairs(ents.GetAll()) do
                if entity.PermaProps_ID == permaID then
                    AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
                    break
                end
            end
        end
    end
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
