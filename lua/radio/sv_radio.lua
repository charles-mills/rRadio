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

-- Table to store custom radio stations
local CustomRadioStations = {}

-- Function to add a custom radio station
local function AddCustomRadioStation(country, name, url)
    local formattedCountry = utils.formatCountryNameForComparison(country)
    if not CustomRadioStations[formattedCountry] then
        CustomRadioStations[formattedCountry] = {}
    end
    table.insert(CustomRadioStations[formattedCountry], {name = name, url = url})
    utils.DebugPrint("Added custom radio station: " .. country .. " - " .. name)
end

-- Function to remove a custom radio station
local function RemoveCustomRadioStation(country, name)
    local formattedCountry = utils.formatCountryNameForComparison(country)
    if CustomRadioStations[formattedCountry] then
        for i, station in ipairs(CustomRadioStations[formattedCountry]) do
            if station.name == name then
                table.remove(CustomRadioStations[formattedCountry], i)
                utils.DebugPrint("Removed custom radio station: " .. country .. " - " .. name)
                return true
            end
        end
    end
    return false
end

-- Function to send custom radio stations to a player
local function SendCustomRadioStationsToPlayer(ply)
    net.Start("rRadio_CustomStations")
    net.WriteTable(CustomRadioStations)
    net.Send(ply)
end

-- Hook to send custom radio stations when a player joins
hook.Add("PlayerInitialSpawn", "SendCustomRadioStations", function(ply)
    SendCustomRadioStationsToPlayer(ply)
end)

-- Console command to add a custom radio station
concommand.Add("rradio", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        local action = args[1]
        if action == "add" then
            if #args < 4 then
                print("Usage: rradio add <country> <name> <url>")
                return
            end
            local country = args[2]
            local name = args[3]
            local url = args[4]
            AddCustomRadioStation(country, name, url)
            -- Notify all players of the new station
            net.Start("rRadio_CustomStations")
            net.WriteTable(CustomRadioStations)
            net.Broadcast()
            print("Custom radio station added successfully: " .. country .. " - " .. name)
            if IsValid(ply) then
                ply:ChatPrint("Custom radio station added: " .. name)
            end
        elseif action == "remove" then
            if #args < 2 then
                print("Usage: rradio remove <url>")
                return
            end
            local url = args[2]
            local removed = false
            for country, stations in pairs(CustomRadioStations) do
                for i, station in ipairs(stations) do
                    if station.url == url then
                        table.remove(stations, i)
                        removed = true
                        break
                    end
                end
                if removed then break end
            end
            if removed then
                -- Notify all players of the removed station
                net.Start("rRadio_CustomStations")
                net.WriteTable(CustomRadioStations)
                net.Broadcast()
                print("Custom radio station removed successfully: " .. url)
                if IsValid(ply) then
                    ply:ChatPrint("Custom radio station removed: " .. url)
                end
            else
                print("Station not found: " .. url)
                if IsValid(ply) then
                    ply:ChatPrint("Station not found: " .. url)
                end
            end
        else
            print("Invalid action. Use 'add' or 'remove'.")
            if IsValid(ply) then
                ply:ChatPrint("Invalid action. Use 'add' or 'remove'.")
            end
        end
    else
        ply:ChatPrint("You must be an admin to use this command.")
    end
end)


-- Function to add a radio to the active list
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        utils.DebugPrint("Attempted to add a radio to an invalid entity.")
        return
    end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }

    utils.DebugPrint("Added active radio: Entity " .. tostring(entity:EntIndex()) .. ", Station: " .. stationName)
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
    if not savedState then
        utils.DebugPrint("No saved state found for PermaProps_ID: " .. permaID)
        return
    end

    entity:SetNWString("CurrentRadioStation", savedState.station)
    entity:SetNWString("StationURL", savedState.url)

    if entity.SetStationName then
        entity:SetStationName(savedState.station)
    else
        utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
    end

    if savedState.isPlaying then
        net.Start("rRadio_PlayRadioStation")
        net.WriteEntity(entity)
        net.WriteString(savedState.url)
        net.WriteFloat(savedState.volume)
        net.Broadcast()

        AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
        utils.DebugPrint("Restored and added active radio for PermaProps_ID: " .. permaID)
    else
        utils.DebugPrint("Station is not playing. Not broadcasting rRadio_PlayRadioStation.")
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
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume, country)
    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume, country) VALUES (%d, %s, %s, %d, %f, %s)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume, sql.SQLStr(country))
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

-- Function to send a single active radio to a player
local function SendRadioToPlayer(ply, radio)
    if IsValid(radio.entity) then
        net.Start("rRadio_PlayRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
        net.Send(ply)
    else
        utils.DebugPrint("Invalid radio entity detected in SendRadioToPlayer.")
    end
end

-- Function to handle retry logic for sending active radios
local function RetrySendActiveRadios(ply, attempt)
    if not IsValid(ply) then
        utils.DebugPrint("Player " .. ply:Nick() .. " is no longer valid. Stopping retries.")
        PlayerRetryAttempts[ply] = nil  -- Reset attempt count
        return
    end

    if attempt >= 3 then
        utils.DebugPrint("No active radios found after " .. attempt .. " attempts for player " .. ply:Nick() .. ". Giving up.")
        PlayerRetryAttempts[ply] = nil  -- Reset attempt count
        return
    end

    utils.DebugPrint("No active radios found for player " .. ply:Nick() .. ". Retrying in 5 seconds. Attempt: " .. attempt)
    PlayerRetryAttempts[ply] = attempt + 1

    timer.Simple(5, function()
        local success, err = pcall(function()
            SendActiveRadiosToPlayer(ply)
        end)
        if not success then
            utils.DebugPrint("Error in SendActiveRadiosToPlayer: " .. tostring(err))
        end
    end)
end

-- Function to send all active radios to a player
local function SendAllActiveRadiosToPlayer(ply)
    for _, radio in pairs(ActiveRadios) do
        SendRadioToPlayer(ply, radio)
    end
    PlayerRetryAttempts[ply] = nil  -- Reset attempt count after successful send
end

-- Main function to send active radios to a specific player with limited retries
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        utils.DebugPrint("Invalid player object passed to SendActiveRadiosToPlayer.")
        return
    end

    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]
    utils.DebugPrint("Sending active radios to player: " .. ply:Nick() .. " | Attempt: " .. attempt)

    if next(ActiveRadios) == nil then
        RetrySendActiveRadios(ply, attempt)
        return
    end

    SendAllActiveRadiosToPlayer(ply)
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
    vehicle:SetNWBool("IsSitAnywhereSeat", vehicle.playerdynseat or false)
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(ply) and IsValid(vehicle) then
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerEnteredVehicle", "rRadio_ShowCarRadioMessageOnEnter", function(ply, vehicle, role)
    print("[rRadio] Player " .. ply:Nick() .. " entered vehicle " .. vehicle:GetClass())

    if not IsValid(ply) or not IsValid(vehicle) then
        return
    end

    if vehicle:GetNWBool("IsSitAnywhereSeat", false) then
        print("[rRadio] Sit anywhere seat detected. Not sending radio message.")
        return  -- Do not send the message if it's a sit anywhere seat
    end

    net.Start("rRadio_ShowCarRadioMessage")
    net.Send(ply)
end)

-- Function to handle playing radio station for boombox
local function HandleBoomboxPlayRadio(entity, stationName, url, volume, country)
    local permaID = entity.PermaProps_ID
    if permaID then
        SavedBoomboxStates[permaID] = {
            station = stationName,
            url = url,
            isPlaying = true,
            volume = volume,
            country = country or "Unknown"  -- Use "Unknown" if country is nil
        }
        SaveBoomboxStateToDatabase(permaID, stationName, url, true, volume, country or "Unknown")
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

    net.Start("rRadio_PlayRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.WriteString(country or "Unknown")  -- Use "Unknown" if country is nil
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.WriteString(country or "Unknown")  -- Use "Unknown" if country is nil
    net.Broadcast()
end

-- Function to handle playing radio station for vehicle
local function HandleVehiclePlayRadio(entity, stationName, url, volume, country)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then
        mainVehicle = entity
    end

    if ActiveRadios[mainVehicle:EntIndex()] then
        net.Start("rRadio_StopRadioStation")
            net.WriteEntity(mainVehicle)
        net.Broadcast()
        RemoveActiveRadio(mainVehicle)
    end

    AddActiveRadio(mainVehicle, stationName, url, volume)

    net.Start("rRadio_PlayRadioStation")
        net.WriteEntity(mainVehicle)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.WriteString(country or "Unknown")  -- Use "Unknown" if country is nil
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
        net.WriteString(country or "Unknown")  -- Use "Unknown" if country is nil
    net.Broadcast()
end

-- Main function to handle rRadio_PlayRadioStation network message
net.Receive("rRadio_PlayRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)
    local country = net.ReadString()  -- Read the country

    if not IsValid(entity) then
        utils.DebugPrint("Invalid entity received in rRadio_PlayRadioStation.")
        return
    end

    utils.DebugPrint("rRadio_PlayRadioStation received: Entity " .. entity:EntIndex())

    if utils.isBoombox(entity) then
        HandleBoomboxPlayRadio(entity, stationName, url, volume, country)
    elseif entity:IsVehicle() then
        HandleVehiclePlayRadio(entity, stationName, url, volume, country)
    end
end)

-- Function to stop a boombox radio station
local function StopBoomboxRadio(entity)
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

    net.Start("rRadio_StopRadioStation")
        net.WriteEntity(entity)
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString("")
    net.Broadcast()
end

-- Function to stop a vehicle radio station
local function StopVehicleRadio(entity)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then
        mainVehicle = entity
    end

    RemoveActiveRadio(mainVehicle)

    net.Start("rRadio_StopRadioStation")
        net.WriteEntity(mainVehicle)
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString("")
    net.Broadcast()
end

-- Main function to handle rRadio_StopRadioStation network message
net.Receive("rRadio_StopRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if utils.isBoombox(entity) then
        StopBoomboxRadio(entity)
    elseif entity:IsVehicle() then
        StopVehicleRadio(entity)
    end
end)

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    if not IsValid(entity) then return end

    local mainVehicle = entity:GetParent() or entity

    if ActiveRadios[mainVehicle:EntIndex()] then
        RemoveActiveRadio(mainVehicle)
    end
end)

-- Utility function to detect DarkRP or DerivedRP gamemodes
local function IsDarkRP()
    return istable(DarkRP) and isfunction(DarkRP.getPhrase)
end

-- Assign ownership using CPPI (works for both DarkRP and Sandbox)
local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        utils.DebugPrint("Invalid player or entity passed to AssignOwner.")
        return
    end

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
            print("[rRadio] DarkRP or DerivedRP detected. Setting up CPPI-based ownership hooks.")

            -- Add the hook for playerBoughtCustomEntity in DarkRP or DerivedRP
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and utils.isBoombox(ent) then
                    AssignOwner(ply, ent)
                end
            end)
        else
            print("[rRadio] Non-DarkRP gamemode detected. Using sandbox-compatible ownership hooks.")
        end
    end, function(err)
        utils.DebugPrint("Error in SetupBoomboxHooks: " .. tostring(err))
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.isBoombox and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if IsValid(owner) and owner == ply then
            return true  -- Allow owner to use tools on the boombox
        end
    end
    return false
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if not IsValid(ent) or not utils.isBoombox(ent) then
        return false
    end

    local owner = ent:GetNWEntity("Owner")
    if owner == ply or ply:IsAdmin() then
        return true  -- Allow owner or admin to physgun the boombox
    end

    return false
end)

-- Ensure PermaProps and SpecialENTSSpawn table are initialized
if not PermaProps then PermaProps = {} end
if not PermaProps.SpecialENTSSpawn then PermaProps.SpecialENTSSpawn = {} end

-- Add handling for boombox entities via a PermaProps hook
PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    local permaID = ent.PermaProps_ID
    if not permaID then
        utils.DebugPrint("Warning: PermaProps_ID not found for entity " .. ent:EntIndex())
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        ent:SetNWString("CurrentRadioStation", savedState.station)
        ent:SetNWString("StationURL", savedState.url)

        if ent.SetStationName then
            ent:SetStationName(savedState.station)
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. ent:EntIndex())
        end

        if savedState.isPlaying then
            net.Start("rRadio_PlayRadioStation")
                net.WriteEntity(ent)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
            net.Broadcast()

            AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
        else
            utils.DebugPrint("Station is not playing. Not broadcasting rRadio_PlayRadioStation.")
        end
    else
        utils.DebugPrint("No saved state found for PermaProps_ID: " .. permaID)
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
        if sql then
            local result = sql.Query("DELETE FROM boombox_states")
            if result == false then
                print("[rRadio] Failed to clear boombox states: " .. sql.LastError())
            else
                print("[rRadio] All boombox states cleared successfully.")
                SavedBoomboxStates = {}
                ActiveRadios = {}
            end
        else
            utils.PrintError("[rRadio] SQL library is not available.", 2)
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)

-- Command to list all saved custom stations
concommand.Add("rradio_list_custom_stations", function(ply, cmd, args)
    if not ply or ply:IsAdmin() then
        -- Print the results
        if next(CustomRadioStations) then
            print("[rRadio] Saved custom stations:")
            local index = 1
            for country, stations in pairs(CustomRadioStations) do
                print("Country: " .. country)
                for _, station in ipairs(stations) do
                    print(string.format("  %d. Station: %s, URL: %s", index, station.name, station.url))
                    index = index + 1
                end
            end
        else
            print("[rRadio] No saved custom stations found.")
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)
