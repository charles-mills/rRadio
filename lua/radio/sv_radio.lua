--[[ 
    rRadio Addon for Garry's Mod - Server-Side Script
    Description: Manages car and boombox radio functionalities, including network communications, database interactions, and entity management.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

-- -------------------------------
-- 1. Includes and Initialization
-- -------------------------------
include("misc/utils.lua")
include("misc/config.lua")
include("entities/base_boombox/init.lua")

-- Cache frequently used functions
local IsValid, pairs, ipairs = IsValid, pairs, ipairs
local table_insert, table_remove = table.insert, table.remove
local string_format, string_find = string.format, string.find
local util_TableToJSON, util_JSONToTable = util.TableToJSON, util.JSONToTable
local math_Clamp = math.Clamp

-- -------------------------------
-- 2. Global Variables
-- -------------------------------
local ActiveRadios = {}
SavedBoomboxStates = SavedBoomboxStates or {}
local PlayerRetryAttempts = {}
local CustomRadioStations = {}
local customStationsFile = "rradio_custom_stations.txt"
local EntityVolumes = {}
local lastVolumeUpdateTime = {}
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1 -- 100ms debounce time

-- -------------------------------
-- 3. Utility Functions
-- -------------------------------
local function loadAuthorizedFriends(ply)
    if not IsValid(ply) then return {} end
    
    local steamID = ply:SteamID()
    local filename = "rradio_authorized_friends_" .. steamID .. ".txt"
    local friendsData = file.Read(filename, "DATA")
    
    return friendsData and util.JSONToTable(friendsData) or {}
end

local function isAuthorizedFriend(owner, player)
    if not IsValid(owner) or not IsValid(player) then return false end
    
    local ownerSteamID = owner:SteamID64()
    local playerSteamID = player:SteamID64()
    
    local filename = "rradio_authorized_friends_" .. ownerSteamID .. ".txt"
    local friendsData = file.Read(filename, "DATA")
    
    if friendsData then
        local authorizedFriends = util.JSONToTable(friendsData) or {}
        for _, friend in ipairs(authorizedFriends) do
            if friend.steamid == playerSteamID then
                return true
            end
        end
    end
    
    return false
end

local function IsPlayerNearEntity(ply, entity, maxDistance)
    if not IsValid(ply) or not IsValid(entity) then return false end
    return ply:GetPos():DistToSqr(entity:GetPos()) <= (maxDistance * maxDistance)
end

local function DoesPlayerOwnEntity(ply, entity)
    if not IsValid(ply) or not IsValid(entity) then return false end
    
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
    
    local owner = entity.CPPIGetOwner and entity:CPPIGetOwner() or entity:GetNWEntity("Owner")
    
    return owner == ply or isAuthorizedFriend(owner, ply)
end

-- -------------------------------
-- 4. Rate Limiting
-- -------------------------------
local playerLastActionTime = {}
local RATE_LIMIT_DELAY = 0.5

local function IsRateLimited(ply)
    local currentTime = CurTime()
    if not playerLastActionTime[ply] or (currentTime - playerLastActionTime[ply] > RATE_LIMIT_DELAY) then
        playerLastActionTime[ply] = currentTime
        return false
    end
    return true
end

-- -------------------------------
-- 5. Custom Radio Stations Management
-- -------------------------------
local function SaveCustomStations()
    file.Write(customStationsFile, util_TableToJSON(CustomRadioStations, true))
end

local function LoadCustomStations()
    if file.Exists(customStationsFile, "DATA") then
        CustomRadioStations = util_JSONToTable(file.Read(customStationsFile, "DATA")) or {}
    else
        CustomRadioStations = {}
    end
end

LoadCustomStations()

local function AddCustomRadioStation(country, name, url)
    local formattedCountry = utils.formatCountryNameForComparison(country)
    CustomRadioStations[formattedCountry] = CustomRadioStations[formattedCountry] or {}
    table_insert(CustomRadioStations[formattedCountry], {name = name, url = url})
    SaveCustomStations()
    
    net.Start("rRadio_CustomStations")
    net.WriteTable(CustomRadioStations)
    net.Broadcast()
end

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

local function SendCustomRadioStationsToPlayer(ply)
    net.Start("rRadio_CustomStations")
    net.WriteTable(CustomRadioStations)
    net.Send(ply)
end

hook.Add("PlayerInitialSpawn", "SendCustomRadioStations", SendCustomRadioStationsToPlayer)

-- -------------------------------
-- 6. Active Radio Management
-- -------------------------------
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then return end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }
end

local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

-- -------------------------------
-- 7. Boombox State Management
-- -------------------------------
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then return end

    local savedState = SavedBoomboxStates[permaID]
    if not savedState then return end

    entity:SetNWString("CurrentRadioStation", savedState.station)
    entity:SetNWString("StationURL", savedState.url)
    entity:SetNWFloat("Volume", savedState.volume)

    if entity.SetStationName then
        entity:SetStationName(savedState.station)
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

    if entity.SetupUse then
        entity:SetupUse()
    end
end

local function IsPlayerAuthorized(ply, owner)
    return ply:IsAdmin() or ply:IsSuperAdmin() or ply == owner or utils.isAuthorizedFriend(owner, ply)
end

hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()
        if IsValid(entity) and utils.isBoombox(entity) then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

-- -------------------------------
-- 8. Database Management
-- -------------------------------
local database = include("misc/database.lua")

hook.Add("Initialize", "CreateBoomboxStatesTable", database.CreateBoomboxStatesTable)

-- -------------------------------
-- 9. Network Communication
-- -------------------------------
local function SendRadioToPlayer(ply, radio)
    if IsValid(radio.entity) then
        net.Start("rRadio_PlayRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
        net.Send(ply)
    end
end

local function RetrySendActiveRadios(ply, attempt)
    if not IsValid(ply) then
        PlayerRetryAttempts[ply] = nil
        return
    end

    if attempt >= 3 then
        PlayerRetryAttempts[ply] = nil
        return
    end

    PlayerRetryAttempts[ply] = attempt + 1

    timer.Simple(5, function()
        pcall(function()
            SendActiveRadiosToPlayer(ply)
        end)
    end)
end

local function SendAllActiveRadiosToPlayer(ply)
    for _, radio in pairs(ActiveRadios) do
        SendRadioToPlayer(ply, radio)
    end
    PlayerRetryAttempts[ply] = nil
end

local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end

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
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

-- Add this new network receiver for global volume updates
net.Receive("rRadio_UpdateGlobalVolume", function(len, ply)
    local entity = net.ReadEntity()
    local newVolume = net.ReadFloat()
    
    if IsValid(entity) and (ply:IsAdmin() or DoesPlayerOwnEntity(ply, entity)) then
        local currentTime = CurTime()
        if not lastVolumeUpdateTime[entity] or (currentTime - lastVolumeUpdateTime[entity] > VOLUME_UPDATE_DEBOUNCE_TIME) then
            lastVolumeUpdateTime[entity] = currentTime
            
            EntityVolumes[entity] = newVolume
            
            -- Broadcast the new volume to all clients
            net.Start("rRadio_UpdateClientVolume")
            net.WriteEntity(entity)
            net.WriteFloat(newVolume)
            net.Broadcast()
        end
    end
end)

-- -------------------------------
-- 10. Vehicle-Specific Functionality
-- -------------------------------
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

-- -------------------------------
-- 11. Radio Playback Handling
-- -------------------------------
local function HandleBoomboxPlayRadio(ply, entity, stationName, url, volume, country)
    if not IsValid(entity) then return end

    local currentVolume = EntityVolumes[entity] or Config.Boombox.DefaultVolume
    
    entity:SetNWString("CurrentRadioStation", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", currentVolume)
    entity:SetNWString("Country", country)
    entity:SetNWBool("IsRadioSource", true)

    if entity.SetStationName then
        entity:SetStationName(stationName)
    end

    AddActiveRadio(entity, stationName, url, currentVolume)

    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(currentVolume)
    net.WriteString(country)
    net.Broadcast()

    if entity.PermaProps_ID then
        database.SaveBoomboxStateToDatabase(entity.PermaProps_ID, stationName, url, true, currentVolume)
    end
end

local function HandleVehiclePlayRadio(entity, stationName, url, volume)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then mainVehicle = entity end

    local currentVolume = EntityVolumes[mainVehicle] or Config.VehicleRadio.DefaultVolume

    if ActiveRadios[mainVehicle:EntIndex()] then
        net.Start("rRadio_StopRadioStation")
            net.WriteEntity(mainVehicle)
        net.Broadcast()
        RemoveActiveRadio(mainVehicle)
    end

    AddActiveRadio(mainVehicle, stationName, url, currentVolume)

    net.Start("rRadio_PlayRadioStation")
        net.WriteEntity(mainVehicle)
        net.WriteString(url)
        net.WriteFloat(currentVolume)
    net.Broadcast()

    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
    net.Broadcast()
end

local function IsPlayerInVehicle(ply, vehicle)
    if not IsValid(ply) or not IsValid(vehicle) then return false end
    return ply:GetVehicle() == vehicle
end

net.Receive("rRadio_PlayRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math_Clamp(net.ReadFloat(), 0, 1)
    local country = net.ReadString()

    if not IsValid(entity) or not IsValid(ply) then return end
    if IsRateLimited(ply) then return end

    if utils.isBoombox(entity) then
        if not IsPlayerNearEntity(ply, entity, 300) then return end
        local owner = entity:GetNWEntity("Owner")
        if not IsPlayerAuthorized(ply, owner) then return end
        HandleBoomboxPlayRadio(ply, entity, stationName, url, volume, country)
    elseif entity:IsVehicle() then
        if not IsPlayerInVehicle(ply, entity) then return end
        HandleVehiclePlayRadio(entity, stationName, url, volume, country)
    end
end)

local function StopBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if permaID and SavedBoomboxStates[permaID] then
        SavedBoomboxStates[permaID].isPlaying = false
        database.SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
    end

    if entity.SetStationName then
        entity:SetStationName("")
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

net.Receive("rRadio_StopRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end

    local entIndex = entity:EntIndex()
    if ActiveRadios[entIndex] then
        ActiveRadios[entIndex] = nil

        net.Start("rRadio_StopRadioStation")
        net.WriteEntity(entity)
        net.Broadcast()

        if utils.isBoombox(entity) and entity.PermaProps_ID then
            database.SaveBoomboxStateToDatabase(entity.PermaProps_ID, "", "", false, 0)
        end
    end
end)

-- -------------------------------
-- 12. Cleanup and Hooks
-- -------------------------------
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    if not IsValid(entity) then return end

    local mainVehicle = entity:GetParent() or entity

    if ActiveRadios[mainVehicle:EntIndex()] then
        RemoveActiveRadio(mainVehicle)
    end
end)

local function IsDarkRP()
    return istable(DarkRP) and isfunction(DarkRP.getPhrase)
end

local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end

    ent:SetNWEntity("Owner", ply)
end

hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
    if IsValid(ent) and utils.isBoombox(ent) then
        AssignOwner(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if not IsValid(ent) then return end
    
    if utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        return ply:IsAdmin() or ply == owner
    end
    
    return nil
end)

if not PermaProps then PermaProps = {} end
if not PermaProps.SpecialENTSSpawn then PermaProps.SpecialENTSSpawn = {} end

PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    if IsValid(ent) then
        local permaID = ent.PermaProps_ID
        if not permaID then return end

        if ent.SetupUse then
            ent:SetupUse()
        end

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
        end

        ent:SetNWBool("IsRadioSource", true)
        ent:SetNWEntity("Owner", nil)
    end
end

PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    database.LoadBoomboxStatesFromDatabase()
end)

-- -------------------------------
-- 13. Console Commands
-- -------------------------------
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

-- -------------------------------
-- 14. Network Receivers
-- -------------------------------
util.AddNetworkString("rRadio_UpdateAuthorizedFriends")

net.Receive("rRadio_UpdateAuthorizedFriends", function(len, ply)
    local friendsData = net.ReadString()
    local filename = "rradio_authorized_friends_" .. ply:SteamID64() .. ".txt"
    file.Write(filename, friendsData)
end)

-- -------------------------------
-- 15. Additional Hooks
-- -------------------------------
hook.Add("PlayerInitialSpawn", "LoadAuthorizedFriends", function(ply)
    ply.AuthorizedFriends = loadAuthorizedFriends(ply)
end)

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

hook.Add("OnEntityCreated", "SetupBoomboxUse", function(ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        timer.Simple(0, function()
            if IsValid(ent) and ent.SetupUse then
                ent:SetupUse()
            end
        end)
    end
end)

-- -------------------------------
-- 16. SitAnywhere Compatibility
-- -------------------------------
local function UpdateSitAnywhereSeatStatus(vehicle)
    if IsValid(vehicle) then
        local isSitAnywhere = vehicle.playerdynseat or false
        vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
        net.Start("rRadio_UpdateSitAnywhereSeat")
        net.WriteEntity(vehicle)
        net.WriteBool(isSitAnywhere)
        net.Broadcast()
    end
end

hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    timer.Simple(0.1, function()
        if IsValid(vehicle) then
            UpdateSitAnywhereSeatStatus(vehicle)
        end
    end)
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        UpdateSitAnywhereSeatStatus(vehicle)
    end
end)

hook.Add("OnEntityCreated", "UpdateSitAnywhereSeatOnSpawn", function(ent)
    if IsValid(ent) and ent:IsVehicle() then
        timer.Simple(0.1, function()
            if IsValid(ent) then
                UpdateSitAnywhereSeatStatus(ent)
            end
        end)
    end
end)

hook.Add("PlayerEnteredVehicle", "rRadio_ShowCarRadioMessageOnEnter", function(ply, vehicle, role)
    if not IsValid(ply) or not IsValid(vehicle) then return end
    
    timer.Simple(0.2, function()
        if not IsValid(ply) or not IsValid(vehicle) then return end
        
        local isSitAnywhere = vehicle:GetNWBool("IsSitAnywhereSeat", false)
        
        if not isSitAnywhere then
            net.Start("rRadio_ShowCarRadioMessage")
            net.Send(ply)
        end
    end)
end)