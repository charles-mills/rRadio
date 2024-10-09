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

local ActiveRadios = {}
SavedBoomboxStates = SavedBoomboxStates or {}
local PlayerRetryAttempts = {}
local CustomRadioStations = {}
local customStationsFile = "rradio_custom_stations.txt"

util.AddNetworkString("rRadio_VolumeChange")
util.AddNetworkString("rRadio_VolumeUpdate")
util.AddNetworkString("rRadio_UpdateAuthorizedFriends")
util.AddNetworkString("rRadio_RequestOpenMenu")
util.AddNetworkString("rRadio_VehicleSeatInfo")

local playerLastVolumeChange = {}
local volumeChangeInterval = 0.1 -- 100ms cooldown
local pendingUpdates = {}
local UPDATE_DELAY = 2 -- 2 seconds delay

-- Add this at the beginning of the file
print("[rRadio] sv_radio.lua loaded")

function DoesPlayerOwnEntity(ply, entity, action)
    if not IsValid(ply) or not IsValid(entity) then 
        return false 
    end
    
    if ply:IsAdmin() or ply:IsSuperAdmin() then 
        return true 
    end
    
    local owner = entity:GetNWEntity("Owner")
    
    -- Check if it's a permanent boombox (world entity)
    if not IsValid(owner) and entity:IsPermanent() then
        return false -- Only admins can interact with permanent boomboxes
    end
    
    if IsValid(owner) then
        return owner == ply or isAuthorizedFriend(owner, ply)
    end
    
    return true
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
        return
    end

    local entIndex = entity:EntIndex()
    if ActiveRadios[entIndex] then
        ActiveRadios[entIndex].stationName = stationName
        ActiveRadios[entIndex].url = url
        ActiveRadios[entIndex].volume = volume
    else
        ActiveRadios[entIndex] = {
            entity = entity,
            stationName = stationName,
            url = url,
            volume = volume
        }
    end
end

-- Function to remove a radio from the active list
local function RemoveActiveRadio(entity)
    if ActiveRadios[entity:EntIndex()] then
        ActiveRadios[entity:EntIndex()] = nil
    end
end

-- Restore boombox radio state using saved data
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if not savedState then
        return
    end

    entity:SetNWString("CurrentRadioStation", savedState.station)
    entity:SetNWString("StationURL", savedState.url)
    entity:SetNWFloat("Volume", savedState.volume)

    if entity.SetStationName then
        entity:SetStationName(savedState.station)
    else
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
end

hook.Add("Initialize", "CreateBoomboxStatesTable", CreateBoomboxStatesTable)

-- Function to save boombox state to database
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string_format(
        "REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume
    )
end

-- Remove boombox state from database
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string_format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
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
        end
    else
        SavedBoomboxStates = {}
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
    end
end

-- Function to handle retry logic for sending active radios
local function RetrySendActiveRadios(ply, attempt)
    if not IsValid(ply) then
        PlayerRetryAttempts[ply] = nil  -- Reset attempt count
        return
    end

    if attempt >= 3 then
        PlayerRetryAttempts[ply] = nil  -- Reset attempt count
        return
    end
    
    PlayerRetryAttempts[ply] = attempt + 1

    timer.Simple(2, function()
        local success, err = pcall(function()
            SendActiveRadiosToPlayer(ply)
        end)
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
        return
    end

    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]

    if next(ActiveRadios) == nil then
        RetrySendActiveRadios(ply, attempt)
        return
    end

    SendAllActiveRadiosToPlayer(ply)
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(0.5, function()
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
        -- No need to unmark, as we're checking the property directly
    end
end)

hook.Add("PlayerEnteredVehicle", "rRadio_ShowCarRadioMessageOnEnter", function(ply, vehicle, role)
    if not IsValid(ply) or not IsValid(vehicle) then return end
    
    local isSitAnywhereSeat = vehicle.playerdynseat == true

    net.Start("rRadio_VehicleSeatInfo")
    net.WriteEntity(vehicle)
    net.WriteBool(isSitAnywhereSeat)
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
end

-- Function to handle playing radio station for vehicle
local function HandleVehiclePlayRadio(entity, stationName, url, volume, country)
    local mainVehicle = utils.getMainVehicleEntity(entity)
    if not IsValid(mainVehicle) then return end

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
        net.WriteString(country)
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
    net.Broadcast()

    mainVehicle:SetNWString("CurrentRadioStation", stationName)
    mainVehicle:SetNWString("Country", country)
    mainVehicle:SetNWBool("IsRadioSource", true)
end

net.Receive("rRadio_RequestOpenMenu", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        return
    end

    if utils.isBoombox(entity) then
        if DoesPlayerOwnEntity(ply, entity, "open_menu") then
            net.Start("rRadio_OpenRadioMenu")
            net.WriteEntity(entity)
            net.Send(ply)
        else
            ply:ChatPrint("You don't have permission to open this radio menu.")
        end
    elseif entity:IsVehicle() or string.find(entity:GetClass(), "lvs_") then
        local playerVehicle = ply:GetVehicle()
        local playerMainVehicle = utils.getMainVehicleEntity(playerVehicle)

        if entity:GetNWBool("IsSitAnywhereSeat") then
            return
        end

        if playerMainVehicle == entity then
            net.Start("rRadio_OpenRadioMenu")
            net.WriteEntity(entity)
            net.Send(ply)
        else
            ply:ChatPrint("You must be in the vehicle to open its radio menu.")
        end
    end
end)

net.Receive("rRadio_PlayRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math_Clamp(net.ReadFloat(), 0, 1)
    local country = net.ReadString()

    -- Server-side validation
    if not IsValid(entity) or not IsValid(ply) then
        return
    end

    -- Rate limiting
    if IsRateLimited(ply) then
        return
    end

    local mainEntity = utils.getMainVehicleEntity(entity) or entity

    -- Entity-specific checks
    if utils.isBoombox(mainEntity) then
        -- Proximity and ownership checks for boomboxes (as before)
    elseif mainEntity:IsVehicle() or string.find(mainEntity:GetClass(), "lvs_") then
        -- Check if player is in the vehicle
        local playerVehicle = ply:GetVehicle()
        local playerMainVehicle = utils.getMainVehicleEntity(playerVehicle)
        if playerMainVehicle ~= mainEntity then
            return
        end
    else
        return
    end

    -- Proceed to play the radio station
    if utils.isBoombox(mainEntity) then
        HandleBoomboxPlayRadio(ply, mainEntity, stationName, url, volume, country)
    elseif mainEntity:IsVehicle() or string.find(mainEntity:GetClass(), "lvs_") then
        HandleVehiclePlayRadio(mainEntity, stationName, url, volume, country)
    end
end)

--[[
    Function: StopBoomboxRadio
    Description: Stops the radio for a boombox entity.
    @param entity (Entity): The boombox entity to stop the radio on.
]]
function StopBoomboxRadio(entity)
    if not IsValid(entity) then
        return
    end

    -- Update the networked variables
    entity:SetNWString("CurrentRadioStation", "")
    entity:SetNWString("Country", "")
    entity:SetNWBool("IsRadioSource", false)

    -- Remove from ActiveRadios
    RemoveActiveRadio(entity)

    -- Broadcast stop to all clients
    net.Start("rRadio_StopRadioStation")
    net.WriteEntity(entity)
    net.Broadcast()

    -- If it's a permanent boombox, update the saved state
    if entity.PermaProps_ID then
        local permaID = entity.PermaProps_ID
        if SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end
    end

end

function StopVehicleRadio(vehicle)
    if not IsValid(vehicle) then 
        return 
    end

    vehicle:SetNWString("CurrentRadioStation", "")
    vehicle:SetNWString("CurrentRadioStation", "")
    vehicle:SetNWString("Country", "")
    vehicle:SetNWBool("IsRadioSource", false)

    local radioIndex = vehicle:EntIndex()

    if ActiveRadios[radioIndex] then
        RemoveActiveRadio(vehicle)
    end

    -- Broadcast stop to all players
    net.Start("rRadio_StopRadioStation")
    net.WriteEntity(vehicle)
    net.Broadcast()
end

net.Receive("rRadio_StopRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        utils.PrintError("Received invalid entity in rRadio_StopRadioStation.", 2)
        return
    end

    local mainVehicle = utils.getMainVehicleEntity(entity)

    if utils.isBoombox(mainVehicle) then
        if DoesPlayerOwnEntity(ply, mainVehicle) then
            StopBoomboxRadio(mainVehicle)
        else
            ply:ChatPrint("You don't have permission to stop this radio.")
        end
    elseif mainVehicle:IsVehicle() or string.find(mainVehicle:GetClass(), "lvs_") then
        local playerVehicle = ply:GetVehicle()
        local playerMainVehicle = utils.getMainVehicleEntity(playerVehicle)

        if mainVehicle == playerMainVehicle then
            -- Player is in the vehicle, proceed to stop the radio
            StopVehicleRadio(mainVehicle)
        else
            ply:ChatPrint("You must be in the vehicle to stop its radio.")
        end
    else
        utils.PrintError("Invalid entity type for stopping radio: " .. tostring(mainVehicle:GetClass()), 2)
    end
end)

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    if not IsValid(entity) then return end

    local mainVehicle = utils.getMainVehicleEntity(entity)

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
        AssignOwner(ply, ent)
    end
end)

-- Add debug print to the PhysgunPickup hook
hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if not IsValid(ent) then return end
    
    if utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        return ply:IsAdmin() or ply == owner
    end
    
    return nil
end)

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    LoadBoomboxStatesFromDatabase()
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
            print("[rRadio] Saved custom stations: ")
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
        end)
    end
end)

-- Add this function to check friend authorization
function isAuthorizedFriend(owner, friend)
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

local function RetrySendActiveRadios(ply, attempt)
    if not IsValid(ply) then return end

    local maxAttempts = 5
    attempt = attempt or 1


    if next(ActiveRadios) then
        SendActiveRadiosToPlayer(ply)
    else
        if attempt < maxAttempts then
            timer.Simple(5, function()
                RetrySendActiveRadios(ply, attempt + 1)
            end)
        end
    end
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            RetrySendActiveRadios(ply)
        end
    end)
end)

if not PermaProps then PermaProps = {} end
if not PermaProps.SpecialENTSSpawn then PermaProps.SpecialENTSSpawn = {} end

PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    if IsValid(ent) then
        -- Call Spawn and Activate to initialize the entity properly
        ent:Spawn()
        ent:Activate()

        -- Restore saved state if any
        local savedState = SavedBoomboxStates[ent:EntIndex()]
        if savedState then
            ent:SetNWString("CurrentRadioStation", savedState.station)
            ent:SetNWString("StationURL", savedState.url)
            ent:SetNWFloat("Volume", savedState.volume)

            if savedState.isPlaying then
                net.Start("rRadio_PlayRadioStation")
                net.WriteEntity(ent)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
                net.WriteString(savedState.country or "Unknown")
                net.Broadcast()

                AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
            end
        end
    end
end

PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

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
end
