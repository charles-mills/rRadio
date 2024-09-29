-- RadioAddonServer Module
local RadioAddonServer = {}

-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("ToggleFavoriteCountry")

-- Constants and Configurations
local DEBUG_MODE = CreateConVar("car_radio_debug_mode", "0", FCVAR_ARCHIVE, "Enable debug mode for Car Radio")
local ENTITY_CHECK_DELAY = 0.5
local PLAYER_SPAWN_DELAY = 3
local ACTIVE_RADIO_RETRY_DELAY = 5
local SQL_TABLE_NAME = "boombox_states"

-- Local Variables
local ActiveRadios = {}
local SavedBoomboxStates = {}

-- Utility Functions
local function DebugPrint(msg)
    if DEBUG_MODE:GetBool() then
        print("[CarRadio Debug] " .. msg)
    end
end

-- Database Functions
local function ExecuteSQL(query)
    local result = sql.Query(query)
    if result == false then
        DebugPrint("SQL Error: " .. sql.LastError())
    end
    return result
end

local function CreateBoomboxStatesTable()
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS ]] .. SQL_TABLE_NAME .. [[ (
            permaID INTEGER PRIMARY KEY,
            station TEXT,
            url TEXT,
            isPlaying INTEGER,
            volume REAL
        )
    ]])
end

local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format(
        "REPLACE INTO %s (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        SQL_TABLE_NAME,
        permaID,
        sql.SQLStr(stationName),
        sql.SQLStr(url),
        isPlaying and 1 or 0,
        volume
    )
    ExecuteSQL(query)
end

local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM %s WHERE permaID = %d", SQL_TABLE_NAME, permaID)
    ExecuteSQL(query)
end

local function LoadBoomboxStatesFromDatabase()
    local rows = ExecuteSQL("SELECT * FROM " .. SQL_TABLE_NAME)
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

-- Active Radio Management
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        DebugPrint("Attempted to add a radio to an invalid entity.")
        return
    end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }

    DebugPrint("Added active radio: Entity " .. entity:EntIndex() .. ", Station: " .. stationName)
end

local function RemoveActiveRadio(entity)
    local entIndex = entity:EntIndex()
    if ActiveRadios[entIndex] then
        ActiveRadios[entIndex] = nil
        DebugPrint("Removed active radio: Entity " .. entIndex)
    end
end

-- Restore Boombox State
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

-- Hooks and Network Handlers
hook.Add("Initialize", "RadioAddon_CreateBoomboxStatesTable", CreateBoomboxStatesTable)

hook.Add("Initialize", "RadioAddon_LoadBoomboxStatesOnStartup", function()
    DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()
    DebugPrint("Finished restoring active radios")
end)

hook.Add("OnEntityCreated", "RadioAddon_RestoreBoomboxRadio", function(entity)
    timer.Simple(ENTITY_CHECK_DELAY, function()
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

hook.Add("PlayerInitialSpawn", "RadioAddon_SendActiveRadiosOnJoin", function(ply)
    timer.Simple(PLAYER_SPAWN_DELAY, function()
        if IsValid(ply) then
            RadioAddonServer.SendActiveRadiosToPlayer(ply)
        end
    end)
end)

function RadioAddonServer.SendActiveRadiosToPlayer(ply)
    DebugPrint("Sending active radios to player: " .. ply:Nick())
    if not next(ActiveRadios) then
        DebugPrint("No active radios found. Retrying in " .. ACTIVE_RADIO_RETRY_DELAY .. " seconds.")
        timer.Simple(ACTIVE_RADIO_RETRY_DELAY, function()
            if IsValid(ply) then
                RadioAddonServer.SendActiveRadiosToPlayer(ply)
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

hook.Add("PlayerEnteredVehicle", "RadioAddon_CarRadioMessageOnEnter", function(ply)
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

    -- Additional validation can be added here

    DebugPrint("PlayCarRadioStation received: Entity " .. entity:EntIndex())

    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
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
        local mainVehicle = entity:GetParent() or entity

        if ActiveRadios[mainVehicle:EntIndex()] then
            net.Start("StopCarRadioStation")
            net.WriteEntity(mainVehicle)
            net.Broadcast()
            RemoveActiveRadio(mainVehicle)
        end

        AddActiveRadio(mainVehicle, stationName, url, volume)

        net.Start("PlayCarRadioStation")
        net.WriteEntity(mainVehicle)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
        net.Broadcast()
    end
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        DebugPrint("Invalid entity received in StopCarRadioStation.")
        return
    end

    DebugPrint("StopCarRadioStation received: Entity " .. entity:EntIndex())

    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
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
        local mainVehicle = entity:GetParent() or entity

        RemoveActiveRadio(mainVehicle)

        net.Start("StopCarRadioStation")
        net.WriteEntity(mainVehicle)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString("")
        net.Broadcast()
    end
end)

hook.Add("EntityRemoved", "RadioAddon_CleanupActiveRadioOnEntityRemove", function(entity)
    local entIndex = entity:EntIndex()
    if ActiveRadios[entIndex] then
        RemoveActiveRadio(entity)
    end
end)

-- Ownership and Permissions
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

local function AssignOwner(ply, ent)
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end
    ent:SetNWEntity("Owner", ply)
end

hook.Add("InitPostEntity", "RadioAddon_SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            print("[CarRadio] DarkRP or DerivedRP detected. Setting up CPPI-based ownership hooks.")

            hook.Add("playerBoughtCustomEntity", "RadioAddon_AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent)
                if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
                    AssignOwner(ply, ent)
                end
            end)
        else
            print("[CarRadio] Non-DarkRP gamemode detected. Using sandbox-compatible ownership hooks.")
        end
    end)
end)

hook.Add("CanTool", "RadioAddon_AllowBoomboxToolgun", function(ply, tr)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true
        end
    end
end)

hook.Add("PhysgunPickup", "RadioAddon_AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true
        end
    end
end)

-- PermaProps Integration
if not PermaProps then PermaProps = {} end
PermaProps.SpecialENTSSpawn = PermaProps.SpecialENTSSpawn or {}

PermaProps.SpecialENTSSpawn["boombox"] = function(ent)
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

PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

-- Console Commands
concommand.Add("rradio_remove_all", function(ply)
    if not IsValid(ply) or ply:IsAdmin() then
        local result = sql.Query("DELETE FROM " .. SQL_TABLE_NAME)
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

return RadioAddonServer