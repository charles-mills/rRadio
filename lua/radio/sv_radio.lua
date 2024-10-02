--[[ 
    rRadio Addon for Garry's Mod - Server-Side Script
    Description: Manages car and boombox radio functionalities, including network communications, database interactions, and entity management.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-02
]]

include("misc/utils.lua")
include("misc/config.lua")

for _, str in ipairs(NETWORK_STRINGS) do
    util.AddNetworkString(str)
end

local ActiveRadios = {}
SavedBoomboxStates = SavedBoomboxStates or {}

-- Table to track retry attempts per player
local PlayerRetryAttempts = {}

-- Function to add a radio to the active list
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        LogError("Attempted to add a radio to an invalid entity.")
        return
    end

    local entIndex = entity:EntIndex()
    ActiveRadios[entIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume or 1.0  -- Default volume to 1.0 if not provided
    }

    DebugPrint("Added active radio: Entity " .. entIndex .. ", Station: " .. stationName)
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    if ActiveRadios[entity:EntIndex()] then
        ActiveRadios[entity:EntIndex()] = nil
        utils.DebugPrint("Removed active radio: Entity " .. tostring(entity:EntIndex()))
    end
end

-- Restore boombox radio state using saved data
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        utils.DebugPrint("Warning: Could not find PermaProps_ID for entity " .. entity:EntIndex())
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        entity:SetNWString("CurrentRadioStation", savedState.station)
        entity:SetNWString("StationURL", savedState.url)

        if entity.SetStationName then
            entity:SetStationName(savedState.station)
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(savedState.url)
            net.WriteFloat(savedState.volume)
            net.Broadcast()
            AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
            utils.DebugPrint("Restored and added active radio for PermaProps_ID: " .. permaID)
        else
            utils.DebugPrint("Station is not playing. Not broadcasting PlayCarRadioStation.")
        end
    end
end

-- Hook to restore boombox radio state on entity creation
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()
        if IsValid(entity) and utils.isBoombox(entity) then
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
        utils.DebugPrint("Failed to create boombox_states table: " .. sql.LastError())
    else
        utils.DebugPrint("Boombox_states table created or verified successfully")
    end
end

hook.Add("Initialize", "CreateBoomboxStatesTable", CreateBoomboxStatesTable)

-- Save boombox state to database
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume)
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to save boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Saved boombox state to database: PermaID = " .. permaID)
    end
end

-- Remove boombox state from database
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to remove boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Removed boombox state from database: PermaID = " .. permaID)
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
            utils.DebugPrint("Loaded boombox state from database: PermaID = " .. permaID)
        end
    else
        SavedBoomboxStates = {}
        utils.DebugPrint("No saved boombox states found in the database.")
    end
end

-- Send active radios to a specific player with limited retries
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        utils.DebugPrint("Invalid player object passed to SendActiveRadiosToPlayer.")
        return
    end

    -- Initialize attempt count if not present
    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]
    utils.DebugPrint("Sending active radios to player: " .. ply:Nick() .. " | Attempt: " .. attempt)

    if next(ActiveRadios) == nil then
        if attempt >= 3 then
            utils.DebugPrint("No active radios found after " .. attempt .. " attempts for player " .. ply:Nick() .. ". Giving up.")
            PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            return
        end

        utils.DebugPrint("No active radios found for player " .. ply:Nick() .. ". Retrying in 5 seconds. Attempt: " .. attempt)

        -- Increment the attempt count
        PlayerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                utils.DebugPrint("Player " .. ply:Nick() .. " is no longer valid. Stopping retries.")
                PlayerRetryAttempts[ply] = nil  -- Reset attempt count
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
            utils.DebugPrint("Invalid radio entity detected in SendActiveRadiosToPlayer.")
        end
    end

    -- Reset attempt count after successful send
    PlayerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

-- Add the hooks to set the networked variable
hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    if vehicle.playerdynseat then
        vehicle:SetNWBool("IsSitAnywhereSeat", true)
    else
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    if vehicle.playerdynseat then
        return  -- Do not send the message if it's a sit anywhere seat
    end

    net.Start("CarRadioMessage")
    net.Send(ply)
end)

-- Handle PlayCarRadioStation for both vehicles and boomboxes
net.Receive("PlayCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)

    if not IsValid(entity) then
        utils.DebugPrint("Invalid entity received in PlayCarRadioStation.")
        return
    end

    utils.DebugPrint("PlayCarRadioStation received: Entity " .. entity:EntIndex())

    if utils.isBoombox(entity) then
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
            utils.DebugPrint("Warning: SetVolume function not found for entity: " .. entity:EntIndex())
        end

        if entity.SetStationName then
            entity:SetStationName(stationName)
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
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
        if not IsValid(mainVehicle) then
            mainVehicle = entity
        end

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

-- Handle StopCarRadioStation for both vehicles and boomboxes
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if utils.isBoombox(entity) then
        local permaID = entity.PermaProps_ID
        if permaID and SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end

        if entity.SetStationName then
            entity:SetStationName("")
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
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
        if not IsValid(mainVehicle) then
            mainVehicle = entity
        end

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

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then
        mainVehicle = entity
    end

    if ActiveRadios[mainVehicle:EntIndex()] then
        RemoveActiveRadio(mainVehicle)
    end
end)

-- Utility function to detect DarkRP or DerivedRP gamemodes
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

-- Assign ownership using CPPI (works for both DarkRP and Sandbox)
local function AssignOwner(ply, ent)
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)  -- Assign the owner using CPPI
    end

    -- Set the owner as a networked entity so the client can access it
    ent:SetNWEntity("Owner", ply)
end

-- Hook into InitPostEntity to ensure everything is initialized
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            print("[CarRadio] DarkRP or DerivedRP detected. Setting up CPPI-based ownership hooks.")

            -- Add the hook for playerBoughtCustomEntity in DarkRP or DerivedRP
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and utils.isBoombox(ent) then
                    AssignOwner(ply, ent)
                end
            end)
        else
            print("[CarRadio] Non-DarkRP gamemode detected. Using sandbox-compatible ownership hooks.")
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true  -- Allow owner to use tools on the boombox
        end
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true  -- Allow owner to physgun the boombox
        end
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
    utils.DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()

    -- Existing boombox states will be restored by PermaProps.SpecialENTSSpawn functions when they are spawned
    utils.DebugPrint("Finished restoring active radios")
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
