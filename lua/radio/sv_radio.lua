--[[ 
    rRadio Addon for Garry's Mod - Server-Side Script
    Description: Manages car and boombox radio functionalities, including network communications, database interactions, and entity management.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

include("misc/utils.lua")
include("misc/config.lua")
include("entities/base_boombox/init.lua")

-- Cache frequently used functions
local IsValid, pairs, ipairs = IsValid, pairs, ipairs
local table_insert, table_remove = table.insert, table.remove
local string_format, string_find = string.format, string.find
local util_TableToJSON, util_JSONToTable = util.TableToJSON, util.JSONToTable
local math_Clamp = math.Clamp

local ConsolidatedStations = {}

local ActiveRadios = {}
SavedBoomboxStates = SavedBoomboxStates or {}
local PlayerRetryAttempts = {}
local CustomRadioStations = {}
local customStationsFile = "rradio_custom_stations.txt"

-- Add these near the top of the file with other network strings
util.AddNetworkString("rRadio_VolumeChange")
util.AddNetworkString("rRadio_VolumeUpdate")
util.AddNetworkString("rRadio_UpdateAuthorizedFriends")

-- Add these variables for rate limiting
local playerLastVolumeChange = {}
local volumeChangeInterval = 0.1 -- 100ms cooldown

-- Add these variables at the top of the file
local pendingUpdates = {}
local UPDATE_DELAY = 2 -- 2 seconds delay

local function DebugPrint(msg)
    utils.DebugPrint("[rRADIO SERVER] " .. msg)
end

-- Modify the DoesPlayerOwnEntity function to use the isAuthorizedFriend from init.lua
local function DoesPlayerOwnEntity(ply, entity)
    if not IsValid(ply) or not IsValid(entity) then 
        utils.DebugPrint("Invalid player or entity in DoesPlayerOwnEntity")
        return false 
    end
    
    if ply:IsAdmin() or ply:IsSuperAdmin() then 
        utils.DebugPrint("Player " .. ply:Nick() .. " is admin, granting access")
        return true 
    end
    
    local owner
    if entity.CPPIGetOwner then
        owner = entity:CPPIGetOwner()
    else
        owner = entity:GetNWEntity("Owner")
    end
    
    if owner == ply then
        utils.DebugPrint("Player " .. ply:Nick() .. " is the owner of the entity")
        return true
    end
    
    if IsValid(owner) then
        -- Use the isAuthorizedFriend function from init.lua
        local isAuthorized = isAuthorizedFriend(owner, ply)
        utils.DebugPrint("Player " .. ply:Nick() .. " authorization result: " .. tostring(isAuthorized))
        return isAuthorized
    else
        utils.DebugPrint("Invalid owner for entity, denying access")
        return false
    end
end

-- Function to check if a player is near an entity
local function IsPlayerNearEntity(ply, entity, maxDistance)
    if not IsValid(ply) or not IsValid(entity) then return false end
    return ply:GetPos():DistToSqr(entity:GetPos()) <= (maxDistance * maxDistance)
end

local playerLastActionTime = {}
local RATE_LIMIT_DELAY = 0.5 -- Reduced from 1 second to 0.5 seconds

-- Function to check and update rate limit
local function IsRateLimited(ply)
    local currentTime = CurTime()
    if not playerLastActionTime[ply] or (currentTime - playerLastActionTime[ply] > RATE_LIMIT_DELAY) then
        playerLastActionTime[ply] = currentTime
        return false
    end
    utils.DebugPrint("Rate limit exceeded for player: " .. ply:Nick())
    return true
end

-- Function to save custom stations to file
local function SaveCustomStations()
    file.Write(customStationsFile, util_TableToJSON(CustomRadioStations, true))
end

-- Function to load custom stations from file
local function LoadCustomStations()
    if file.Exists(customStationsFile, "DATA") then
        CustomRadioStations = util_JSONToTable(file.Read(customStationsFile, "DATA")) or {}
    else
        CustomRadioStations = {}
    end
end

-- Load custom stations when the script initializes
LoadCustomStations()

-- Function to add a custom radio station
local function AddCustomRadioStation(country, name, url)
    local formattedCountry = utils.formatCountryNameForComparison(country)
    CustomRadioStations[formattedCountry] = CustomRadioStations[formattedCountry] or {}
    table_insert(CustomRadioStations[formattedCountry], {name = name, url = url})
    SaveCustomStations()
    utils.DebugPrint("Added custom radio station: " .. country .. " - " .. name)
    
    net.Start("rRadio_CustomStations")
    net.WriteTable(CustomRadioStations)
    net.Broadcast()
end

-- Function to remove a custom radio station
local function RemoveCustomRadioStation(country, name)
    local formattedCountry = utils.formatCountryNameForComparison(country)
    if CustomRadioStations[formattedCountry] then
        for i, station in ipairs(CustomRadioStations[formattedCountry]) do
            if station.name == name then
                table_remove(CustomRadioStations[formattedCountry], i)
                SaveCustomStations()
                utils.DebugPrint("Removed custom radio station: " .. country .. " - " .. name)
                
                net.Start("rRadio_CustomStations")
                net.WriteTable(CustomRadioStations)
                net.Broadcast()
                
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
hook.Add("PlayerInitialSpawn", "SendCustomRadioStations", SendCustomRadioStationsToPlayer)

-- Console command to add a custom radio station
concommand.Add("rradio", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        local action = args[1]
        if action == "add" then
            if #args < 4 then
                print("Usage: rradio add <country> <name> <url>")
                return
            end
            local country, name, url = args[2], args[3], args[4]
            AddCustomRadioStation(country, name, url)
            print("Custom radio station added successfully: " .. country .. " - " .. name)
            if IsValid(ply) then
                ply:ChatPrint("Custom radio station added: " .. name)
            end
        elseif action == "remove" then
            if #args < 3 then
                print("Usage: rradio remove <country> <name>")
                return
            end
            local country, name = args[2], args[3]
            if RemoveCustomRadioStation(country, name) then
                print("Custom radio station removed successfully: " .. country .. " - " .. name)
                if IsValid(ply) then
                    ply:ChatPrint("Custom radio station removed: " .. name)
                end
            else
                print("Station not found: " .. country .. " - " .. name)
                if IsValid(ply) then
                    ply:ChatPrint("Station not found: " .. name)
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
    entity:SetNWFloat("Volume", savedState.volume)

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
        net.WriteString(savedState.country or "Unknown")
        net.Broadcast()

        AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
    else
        net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(savedState.station)
        net.WriteString(savedState.country or "Unknown")
        net.Broadcast()
    end

    -- Set up the Use function for the permanent boombox
    if entity.SetupUse then
        entity:SetupUse()
        utils.DebugPrint("[CarRadio Debug] Set up Use function for permanent boombox: " .. entity:EntIndex())
    else
        utils.DebugPrint("[CarRadio Debug] SetupUse function not found for permanent boombox: " .. entity:EntIndex())
    end
end

local function IsPlayerAuthorized(ply, owner)
    return ply:IsAdmin() or ply:IsSuperAdmin() or ply == owner or utils.isAuthorizedFriend(owner, ply)
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

-- Function to save boombox state to database
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string_format(
        "REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume
    )
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to save boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Saved boombox state to database: PermaID = " .. permaID)
    end
end

-- Remove boombox state from database
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string_format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to remove boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Removed boombox state from database: PermaID = " .. permaID)
    end
end

-- Function to load boombox states from the database
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
    if not IsValid(ply) or not IsValid(vehicle) then return end
    if vehicle:GetNWBool("IsSitAnywhereSeat", false) then return end
    net.Start("rRadio_ShowCarRadioMessage")
    net.Send(ply)
end)

-- Function to handle playing radio station for boombox
local function HandleBoomboxPlayRadio(ply, entity, stationName, url, volume, country)
    if not IsValid(entity) then return end

    entity:SetNWString("CurrentRadioStation", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", volume)
    entity:SetNWString("Country", country)
    entity:SetNWBool("IsRadioSource", true)

    AddActiveRadio(entity, stationName, url, volume)

    -- Broadcast to all players
    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.WriteString(country)
    net.Broadcast()

    -- Save state if it's a permanent boombox
    if entity.PermaProps_ID then
        SaveBoomboxStateToDatabase(entity.PermaProps_ID, stationName, url, true, volume)
    end

    utils.DebugPrint("Started radio for boombox: " .. entity:EntIndex())
end
-- Function to handle playing radio station for vehicle
local function HandleVehiclePlayRadio(entity, stationName, url, volume)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then mainVehicle = entity end

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
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
    net.Broadcast()
end

-- Function to check if a player is in a vehicle
local function IsPlayerInVehicle(ply, vehicle)
    if not IsValid(ply) or not IsValid(vehicle) then return false end
    return ply:GetVehicle() == vehicle
end

-- Main function to handle rRadio_PlayRadioStation network message
net.Receive("rRadio_PlayRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math_Clamp(net.ReadFloat(), 0, 1)
    local country = net.ReadString()

    -- Server-side validation
    if not IsValid(entity) or not IsValid(ply) then
        DebugPrint("Invalid entity or player in rRadio_PlayRadioStation.")
        return
    end

    -- Rate limiting
    if IsRateLimited(ply) then
        DebugPrint("Rate limit exceeded for player: " .. ply:Nick())
        return
    end

    -- Entity-specific checks
    if utils.isBoombox(entity) then
        -- Proximity check for boomboxes
        if not IsPlayerNearEntity(ply, entity, 300) then -- 300 units max distance
            DebugPrint("Player too far from boombox: " .. ply:Nick())
            return
        end
        -- Entity ownership check for boomboxes
        if not DoesPlayerOwnEntity(ply, entity) then
            DebugPrint("Player doesn't have permission to use the boombox: " .. ply:Nick())
            net.Start("rRadio_NoPermission")
            net.Send(ply)
            return
        end
    elseif entity:IsVehicle() then
        -- Check if player is in the vehicle
        if not IsPlayerInVehicle(ply, entity) then
            DebugPrint("Player is not in the vehicle: " .. ply:Nick())
            return
        end
    else
        DebugPrint("Invalid entity type for radio: " .. tostring(entity))
        return
    end

    DebugPrint("Player " .. ply:Nick() .. " is playing station " .. stationName .. " on entity " .. entity:GetClass())

    -- If all checks pass, proceed with playing the radio station
    if utils.isBoombox(entity) then
        HandleBoomboxPlayRadio(ply, entity, stationName, url, volume, country)
    elseif entity:IsVehicle() then
        HandleVehiclePlayRadio(entity, stationName, url, volume, country)
    end
end)

-- Modify the StopBoomboxRadio function
local function StopBoomboxRadio(entity)
    if not IsValid(entity) then return end

    local permaID = entity.PermaProps_ID
    if permaID and SavedBoomboxStates[permaID] then
        SavedBoomboxStates[permaID].isPlaying = false
        SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
    end

    entity:SetNWString("CurrentRadioStation", "")
    entity:SetNWString("Country", "")
    entity:SetNWBool("IsRadioSource", false)

    RemoveActiveRadio(entity)

    -- Broadcast stop to all players
    net.Start("rRadio_StopRadioStation")
    net.WriteEntity(entity)
    net.Broadcast()

    utils.DebugPrint("Stopped radio for boombox: " .. entity:EntIndex())
end

-- Modify the existing network receiver for stopping radio stations
net.Receive("rRadio_StopRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        utils.PrintError("Received invalid entity in rRadio_StopRadioStation.", 2)
        return
    end

    if DoesPlayerOwnEntity(ply, entity) then
        StopBoomboxRadio(entity)
    else
        ply:ChatPrint("You don't have permission to stop this radio.")
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

-- Add debug print to the DarkRP hook
hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
    if IsValid(ent) and utils.isBoombox(ent) then
        DebugPrint("DarkRP: Player " .. ply:Nick() .. " bought a boombox.")
        AssignOwner(ply, ent)
    end
end)

-- Add debug print to the PhysgunPickup hook
hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if not IsValid(ent) then return end
    
    if utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        DebugPrint("PhysgunPickup: Player " .. ply:Nick() .. " attempting to pick up boombox owned by " .. (IsValid(owner) and owner:Nick() or "Unknown"))
        return ply:IsAdmin() or ply == owner
    end
    
    return nil
end)

-- Ensure PermaProps and SpecialENTSSpawn table are initialized
if not PermaProps then PermaProps = {} end
if not PermaProps.SpecialENTSSpawn then PermaProps.SpecialENTSSpawn = {} end

-- Add handling for boombox entities via a PermaProps hook
PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    if IsValid(ent) then
        local permaID = ent.PermaProps_ID
        if not permaID then
            utils.DebugPrint("[CarRadio Debug] Warning: Could not find PermaProps_ID for entity " .. ent:EntIndex())
            return
        end

        -- Set up the Use function
        if ent.SetupUse then
            ent:SetupUse()
            utils.DebugPrint("[CarRadio Debug] Set up Use function for PermaProps boombox: " .. ent:EntIndex())
        else
            utils.DebugPrint("[CarRadio Debug] SetupUse function not found for PermaProps boombox: " .. ent:EntIndex())
        end

        -- Restore saved state
        local savedState = SavedBoomboxStates[permaID]
        if savedState then
            ent:SetNWString("CurrentRadioStation", savedState.station)
            ent:SetNWString("StationURL", savedState.url)
            ent:SetNWFloat("Volume", savedState.volume)

            if ent.SetStationName then
                ent:SetStationName(savedState.station)
            end

            if savedState.isPlaying then
                net.Start("rRadio_PlayRadioStation")
                net.WriteEntity(ent)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
                net.WriteString(savedState.country or "Unknown")
                net.Broadcast()

                AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
            end
        else
            utils.DebugPrint("[CarRadio Debug] No saved state found for PermaProps_ID: " .. permaID)
        end

        -- Ensure the entity is recognized as a radio source
        ent:SetNWBool("IsRadioSource", true)

        -- Explicitly set the owner to nil to ensure it remains a world entity
        ent:SetNWEntity("Owner", nil)
        utils.DebugPrint("[CarRadio Debug] Set owner for permanent boombox to nil (world entity)")
    end
end

-- Add handling for golden_boombox entities
PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    utils.DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()
    utils.DebugPrint("Finished restoring active radios")
end)

-- Clear all boombox states from the database
concommand.Add("rradio_remove_all", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        if sql.Query("DELETE FROM boombox_states") ~= false then
            print("[rRadio] All boombox states cleared successfully.")
            SavedBoomboxStates = {}
            ActiveRadios = {}
        else
            print("[rRadio] Failed to clear boombox states: " .. sql.LastError())
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)

-- Command to list all saved custom stations
concommand.Add("rradio_list_custom_stations", function(ply, cmd, args)
    if not IsValid(ply) or ply:IsAdmin() then
        if next(CustomRadioStations) then
            print("[rRadio] Saved custom stations:")
            for country, stations in pairs(CustomRadioStations) do
                print("Country: " .. country)
                for i, station in ipairs(stations) do
                    print(string.format("  %d. Station: %s, URL: %s", i, station.name, station.url))
                end
            end
        else
            print("[rRadio] No saved custom stations found.")
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)

-- Modify the network receiver for updating authorized friends
net.Receive("rRadio_UpdateAuthorizedFriends", function(len, ply)
    local friendsData = net.ReadString()
    local steamID64 = ply:SteamID64()
    
    -- Update the in-memory representation immediately
    pendingUpdates[steamID64] = friendsData
    
    -- Debounce the file write
    if not timer.Exists("rRadio_SaveFriends_" .. steamID64) then
        timer.Create("rRadio_SaveFriends_" .. steamID64, UPDATE_DELAY, 1, function()
            local filename = "rradio/client_friends/rradio_authorized_friends_" .. steamID64 .. ".txt"
            file.Write(filename, pendingUpdates[steamID64])
            pendingUpdates[steamID64] = nil
            DebugPrint("Saved friends list for " .. ply:Nick() .. " (SteamID: " .. ply:SteamID() .. ")")
        end)
    end
    
    DebugPrint("Received updated friends list for " .. ply:Nick() .. " (SteamID: " .. ply:SteamID() .. ")")
end)

-- Add this function to check friend authorization
local function isAuthorizedFriend(owner, friend)
    if not IsValid(owner) or not IsValid(friend) then return false end
    
    local ownerSteamID64 = owner:SteamID64()
    local friendSteamID = friend:SteamID()
    
    -- Check pending updates first
    if pendingUpdates[ownerSteamID64] then
        local friendsList = util.JSONToTable(pendingUpdates[ownerSteamID64]) or {}
        for _, f in ipairs(friendsList) do
            if f.steamid == friendSteamID then
                return true
            end
        end
    end
    
    -- If not in pending updates, check the file
    local filename = "rradio/client_friends/rradio_authorized_friends_" .. ownerSteamID64 .. ".txt"
    if file.Exists(filename, "DATA") then
        local friendsList = util.JSONToTable(file.Read(filename, "DATA")) or {}
        for _, f in ipairs(friendsList) do
            if f.steamid == friendSteamID then
                return true
            end
        end
    end
    
    return false
end

-- Update the DoesPlayerOwnEntity function to use isAuthorizedFriend
local function DoesPlayerOwnEntity(ply, entity)
    if not IsValid(ply) or not IsValid(entity) then 
        utils.DebugPrint("Invalid player or entity in DoesPlayerOwnEntity")
        return false 
    end
    
    if ply:IsAdmin() or ply:IsSuperAdmin() then 
        utils.DebugPrint("Player " .. ply:Nick() .. " is admin, granting access")
        return true 
    end
    
    local owner
    if entity.CPPIGetOwner then
        owner = entity:CPPIGetOwner()
    else
        owner = entity:GetNWEntity("Owner")
    end
    
    if owner == ply then
        utils.DebugPrint("Player " .. ply:Nick() .. " is the owner of the entity")
        return true
    end
    
    if IsValid(owner) then
        -- Use the isAuthorizedFriend function from init.lua
        local isAuthorized = isAuthorizedFriend(owner, ply)
        utils.DebugPrint("Player " .. ply:Nick() .. " authorization result: " .. tostring(isAuthorized))
        return isAuthorized
    else
        utils.DebugPrint("Invalid owner for entity, denying access")
        return false
    end
end

hook.Add("CanTool", "RestrictBoomboxRemoval", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if ply:IsAdmin() or ply:IsSuperAdmin() or ply == owner then
            return true
        else
            ply:ChatPrint("You do not have permission to remove this boombox.")
            return false
        end
    end
end)

-- Add this hook to ensure the Use function is set up for all boomboxes, including permanent ones
hook.Add("OnEntityCreated", "SetupBoomboxUse", function(ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        timer.Simple(0, function()
            if IsValid(ent) then
                if ent.SetupUse then
                    ent:SetupUse()
                    utils.DebugPrint("[CarRadio Debug] Set up Use function for boombox: " .. ent:EntIndex())
                else
                    utils.DebugPrint("[CarRadio Debug] SetupUse function not found for boombox: " .. ent:EntIndex())
                end
            end
        end)
    end
end)

-- Add this function near the top of the file, after other function definitions
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end

    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) then
            net.Start("rRadio_PlayRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
            net.WriteString(radio.country or "Unknown")
            net.Send(ply)
        end
    end
end

-- Modify the existing RetrySendActiveRadios function
local function RetrySendActiveRadios(ply, attempt)
    if not IsValid(ply) then return end

    local maxAttempts = 5
    attempt = attempt or 1

    utils.DebugPrint("Sending active radios to player: " .. ply:Nick() .. " | Attempt: " .. attempt)

    if next(ActiveRadios) then
        SendActiveRadiosToPlayer(ply)
    else
        utils.DebugPrint("No active radios found for player " .. ply:Nick() .. ". Retrying in 5 seconds. Attempt: " .. attempt)
        if attempt < maxAttempts then
            timer.Simple(5, function()
                RetrySendActiveRadios(ply, attempt + 1)
            end)
        else
            utils.DebugPrint("Max attempts reached. Failed to send active radios to player " .. ply:Nick())
        end
    end
end

-- Make sure this hook is present and correctly defined
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            RetrySendActiveRadios(ply)
        end
    end)
end)

-- Add this near the end of the file
if PermaProps then
    PermaProps.SpecialENTSSpawn = PermaProps.SpecialENTSSpawn or {}
    PermaProps.SpecialENTSSpawn["boombox"] = function(ent)
        if IsValid(ent) then
            if ent.SetupUse then
                ent:SetupUse()
                utils.DebugPrint("[CarRadio Debug] Set up Use function for PermaProps boombox: " .. ent:EntIndex())
            else
                utils.DebugPrint("[CarRadio Debug] SetupUse function not found for PermaProps boombox: " .. ent:EntIndex())
            end
            RestoreBoomboxRadio(ent)
        end
    end
    PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]
end

local function LoadConsolidatedStations()
    local files = file.Find("lua/radio/stations/data_*.lua", "GAME")
    for _, filename in ipairs(files) do
        local stations = include("radio/stations/" .. filename)
        for country, countryStations in pairs(stations) do
            local baseName = string.match(country, "(.+)_%d+$") or country
            if not ConsolidatedStations[baseName] then
                ConsolidatedStations[baseName] = {}
            end
            for _, station in ipairs(countryStations) do
                table.insert(ConsolidatedStations[baseName], {name = station.n, url = station.u})
            end
        end
    end
end

LoadConsolidatedStations()

-- Add this function to handle volume changes
local function HandleVolumeChange(ply, entity, volume)
    if not IsValid(entity) then return end

    -- Check if the player has permission to change the volume
    if not DoesPlayerOwnEntity(ply, entity) then
        ply:ChatPrint("You don't have permission to change this radio's volume.")
        return
    end

    -- Rate limiting
    local currentTime = CurTime()
    if playerLastVolumeChange[ply] and currentTime - playerLastVolumeChange[ply] < volumeChangeInterval then
        return
    end
    playerLastVolumeChange[ply] = currentTime

    -- Update the volume for the entity
    entity:SetNWFloat("RadioVolume", volume)

    -- If it's a boombox, update the saved state
    if utils.isBoombox(entity) and entity.PermaProps_ID then
        local permaID = entity.PermaProps_ID
        if SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].volume = volume
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, SavedBoomboxStates[permaID].isPlaying, volume)
        end
    end

    -- Broadcast the volume change to all clients
    net.Start("rRadio_VolumeUpdate")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.Broadcast()
end

-- Add this network receiver
net.Receive("rRadio_VolumeChange", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    HandleVolumeChange(ply, entity, volume)
end)

-- Modify the HandleBoomboxPlayRadio function
local function HandleBoomboxPlayRadio(ply, entity, stationName, url, volume, country)
    if not IsValid(entity) then return end

    entity:SetNWString("CurrentRadioStation", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", volume)
    entity:SetNWString("Country", country)
    entity:SetNWBool("IsRadioSource", true)

    AddActiveRadio(entity, stationName, url, volume)

    -- Broadcast to all players
    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.WriteString(country)
    net.Broadcast()

    -- Save state if it's a permanent boombox
    if entity.PermaProps_ID then
        SaveBoomboxStateToDatabase(entity.PermaProps_ID, stationName, url, true, volume)
    end

    utils.DebugPrint("Started radio for boombox: " .. entity:EntIndex())
end

-- Modify the HandleVehiclePlayRadio function
local function HandleVehiclePlayRadio(entity, stationName, url, volume)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then mainVehicle = entity end

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
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
    net.Broadcast()
end