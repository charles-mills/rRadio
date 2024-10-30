--[[
    Radio Addon Server-Side Core Functionality
    Author: Charles Mills
    Description: This file contains the core server-side functionality for the Radio Addon.
                 It handles network communications, manages active radios, processes player
                 requests for playing and stopping stations, and coordinates with permanent
                 boombox functionality. It also includes utility functions for entity ownership
                 and permissions.
    Date: October 17, 2024
]]--

-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")

-- Active radios and saved boombox states
local ActiveRadios = {}

-- Table to track retry attempts per player
local PlayerRetryAttempts = {}

-- Table to track player cooldowns for net messages
local PlayerCooldowns = {}

-- Global table to store boombox statuses
BoomboxStatuses = BoomboxStatuses or {}
local SavePermanentBoombox, LoadPermanentBoomboxes

include("radio/server/sv_permanent.lua")
local utils = include("radio/shared/sh_utils.lua")

SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local LatestVolumeUpdates = {}
local VolumeUpdateTimers = {}
local DEBOUNCE_TIME = 10 -- 10 seconds debounce


local MAX_ACTIVE_RADIOS = 100  -- Maximum number of active radios allowed
local PLAYER_RADIO_LIMIT = 5   -- Maximum number of radios a single player can activate
local GLOBAL_COOLDOWN = 1      -- Global cooldown in seconds between radio actions
local lastGlobalAction = 0     -- Timestamp of the last global radio action

local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1  -- 100ms debounce time for volume updates
local volumeUpdateQueue = {}

local STATION_CHANGE_COOLDOWN = 0.5
local lastStationChangeTimes = {}

--[[
    Function: AddActiveRadio
    Adds a radio to the active radios list.
    Parameters:
    - entity: The entity representing the radio.
    - stationName: The name of the station.
    - url: The URL of the station.
    - volume: The volume level.
]]
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        return
    end

    -- Remove the oldest radio if the limit is reached
    if table.Count(ActiveRadios) >= MAX_ACTIVE_RADIOS then
        local oldestTime = math.huge
        local oldestRadio = nil
        for entIndex, radio in pairs(ActiveRadios) do
            if radio.timestamp < oldestTime then
                oldestTime = radio.timestamp
                oldestRadio = entIndex
            end
        end
        if oldestRadio then
            RemoveActiveRadio(Entity(oldestRadio))
        end
    end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume,
        timestamp = CurTime()
    }
end

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.
    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

--[[
    Function: SendActiveRadiosToPlayer
    Sends active radios to a specific player with limited retries.
    Parameters:
    - ply: The player to send active radios to.
]]
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        return
    end

    -- Initialize attempt count if not present
    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]

    if next(ActiveRadios) == nil then
        if attempt >= 3 then
            PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            return
        end

        -- Increment the attempt count
        PlayerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            end
        end)
        return
    end

    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(radio.entity)
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
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

--[[
    Function: UpdateVehicleStatus
    Description: Returns the actual vehicle entity, handling parent relationships
    @param vehicle (Entity): The vehicle to check
    @return (Entity): The actual vehicle entity or nil
]]
local function UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end
    
    -- Get the actual vehicle entity
    local veh = utils.GetVehicle(vehicle)
    if not veh then return end
    
    -- Set the networked value
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    
    return isSitAnywhere
end

-- Modify the PlayerEnteredVehicle hook
hook.Add("PlayerEnteredVehicle", "RadioVehicleHandling", function(ply, vehicle)
    -- Only process actual vehicles
    local veh = utils.GetVehicle(vehicle)
    if not veh then return end
    
    -- Update and check status
    if not UpdateVehicleStatus(vehicle) then
        net.Start("CarRadioMessage")
        net.Send(ply)
    end
end)

-- Add hook for new vehicles
hook.Add("OnEntityCreated", "InitializeVehicleStatus", function(ent)
    timer.Simple(0, function()
        if IsValid(ent) and utils.GetVehicle(ent) then
            UpdateVehicleStatus(ent)
        end
    end)
end)

--[[
    Function: IsLVSVehicle
    Checks if the given entity is an LVS vehicle or a seat in an LVS vehicle.
    Parameters:
    - entity: The entity to check.
    Returns:
    - The LVS vehicle entity if it's an LVS vehicle or seat, nil otherwise.
]]
local function IsLVSVehicle(entity)
    if not IsValid(entity) then return nil end

    local parent = entity:GetParent()
    if IsValid(parent) and (string.StartWith(parent:GetClass(), "lvs_") or string.StartWith(parent:GetClass(), "ses_")) then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") then
        return entity
    elseif string.StartWith(entity:GetClass(), "ses_") then
        return entity
    end

    return nil
end

local function GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

--[[
    Function: GetEntityOwner
    Gets the owner of an entity, using CPPI if available, otherwise falling back to other methods.
    Parameters:
    - entity: The entity to check ownership for.
    Returns:
    - The owner of the entity, or nil if no owner is found.
]]
local function GetEntityOwner(entity)
    if not IsValid(entity) then return nil end
    
    -- Try CPPI first
    if entity.CPPIGetOwner then
        return entity:CPPIGetOwner()
    end
    
    -- Fallback to NWEntity owner
    local nwOwner = entity:GetNWEntity("Owner")
    if IsValid(nwOwner) then
        return nwOwner
    end
    
    -- If all else fails, return nil
    return nil
end

--[[
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("PlayCarRadioStation", function(len, ply)
    -- Global cooldown check
    local currentTime = CurTime()
    if currentTime - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("The radio system is busy. Please try again in a moment.")
        return
    end
    lastGlobalAction = currentTime

    -- Player-specific cooldown check
    local lastRequestTime = PlayerCooldowns[ply] or 0
    if currentTime - lastRequestTime < 0.25 then
        ply:ChatPrint("You are changing stations too quickly.")
        return
    end
    PlayerCooldowns[ply] = currentTime

    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then
        return
    end

    -- Entity-specific cooldown check
    local currentTime = CurTime()
    local lastChangeTime = lastStationChangeTimes[entity] or 0
    if currentTime - lastChangeTime < STATION_CHANGE_COOLDOWN then
        -- Instead of returning, just update the time without sending a message
        lastStationChangeTimes[entity] = currentTime
    else
        lastStationChangeTimes[entity] = currentTime
    end

    -- Stop the current station before playing a new one
    if ActiveRadios[entity:EntIndex()] then
        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()
        RemoveActiveRadio(entity)
    end

    -- Check total number of active radios
    if table.Count(ActiveRadios) >= MAX_ACTIVE_RADIOS then
        ply:ChatPrint("The maximum number of active radios has been reached. Please try again later.")
        return
    end

    -- Check player's personal radio limit
    local playerActiveRadios = 0
    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) and GetEntityOwner(radio.entity) == ply then
            playerActiveRadios = playerActiveRadios + 1
        end
    end
    if playerActiveRadios >= PLAYER_RADIO_LIMIT then
        ply:ChatPrint("You have reached your maximum number of active radios.")
        return
    end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local entIndex = entity:EntIndex()

    -- Cancel any existing station update timer for this entity
    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end

    -- Function to update the station
    local function updateStation()
        if entityClass == "golden_boombox" or entityClass == "boombox" then
            if not utils.canInteractWithBoombox(ply, entity) then
                ply:ChatPrint("You do not have permission to control this boombox.")
                return
            end

            -- Validate station name and URL
            if #stationName > 100 then
                ply:ChatPrint("Station name is too long.")
                return
            end

            if #stationURL > 500 then
                ply:ChatPrint("URL is too long.")
                return
            end

            -- Set the boombox status to "tuning" for all clients
            net.Start("UpdateRadioStatus")
                net.WriteEntity(entity)
                net.WriteString(stationName)
                net.WriteBool(true)  -- isPlaying = true
                net.WriteString("tuning")  -- Indicate tuning status
            net.Broadcast()

            -- Update the station immediately for client-side responsiveness
            entity:SetNWString("StationName", stationName)
            entity:SetNWString("StationURL", stationURL)
            entity:SetNWFloat("Volume", volume)
            entity:SetNWBool("IsPlaying", true)
            entity:SetNWString("Status", "tuning")

            AddActiveRadio(entity, stationName, stationURL, volume)

            -- Broadcast the play command to all clients
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(stationName)
                net.WriteString(stationURL)
                net.WriteFloat(volume)
            net.Broadcast()

            -- Save to database if permanent
            if entity.IsPermanent and SavePermanentBoombox then
                SavePermanentBoombox(entity)
            end
        elseif entity:IsVehicle() or lvsVehicle then
            local radioEntity = lvsVehicle or entity

            if ActiveRadios[radioEntity:EntIndex()] then
                net.Start("StopCarRadioStation")
                    net.WriteEntity(radioEntity)
                net.Broadcast()
                RemoveActiveRadio(radioEntity)
            end

            AddActiveRadio(radioEntity, stationName, stationURL, volume)

            net.Start("PlayCarRadioStation")
                net.WriteEntity(radioEntity)
                net.WriteString(stationName)
                net.WriteString(stationURL)
                net.WriteFloat(volume)
            net.Broadcast()

            net.Start("UpdateRadioStatus")
                net.WriteEntity(radioEntity)
                net.WriteString(stationName)
            net.Broadcast()
        else
            return
        end
    end

    -- Set a timer to update the station after a short delay
    timer.Create("StationUpdate_" .. entIndex, 0.25, 1, updateStation)
end)

--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)

    if not IsValid(entity) then
        return
    end

    -- Remove the cooldown check for stopping a station
    -- This allows players to stop a station without triggering the cooldown

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Check permissions for boomboxes
        if not utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        -- Update the station immediately for client-side responsiveness
        entity:SetNWString("StationName", "")
        entity:SetNWString("StationURL", "")
        entity:SetNWBool("IsPlaying", false)
        entity:SetNWString("Status", "stopped")

        RemoveActiveRadio(entity)

        -- Broadcast the stop command to all clients
        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        -- Update radio status for all clients
        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteString("stopped")
        net.Broadcast()

        -- Debounce the database update
        local entIndex = entity:EntIndex()
        if timer.Exists("StationUpdate_" .. entIndex) then
            timer.Remove("StationUpdate_" .. entIndex)
        end

        timer.Create("StationUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function()
            if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
                SavePermanentBoombox(entity)
            end
        end)

    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity

        RemoveActiveRadio(radioEntity)

        -- Broadcast the stop command to all clients
        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        -- Update radio status for all clients
        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
            net.WriteBool(false)
        net.Broadcast()
    else
        return
    end
end)

--[[
    Network Receiver: UpdateRadioVolume
    Updates the volume of a boombox or vehicle radio with a debounce system.
    Parameters:
    - entity: The boombox or vehicle entity.
    - volume: The new volume level.
]]
net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local radioEntity = lvsVehicle or entity
    local entIndex = radioEntity:EntIndex()

    -- Check permissions for boomboxes
    if (entityClass == "boombox" or entityClass == "golden_boombox") and not utils.canInteractWithBoombox(ply, radioEntity) then
        ply:ChatPrint("You do not have permission to control this boombox's volume.")
        return
    end

    -- For vehicles, check if the player is in the vehicle
    if entity:IsVehicle() and entity:GetDriver() ~= ply then
        ply:ChatPrint("You must be in the vehicle to control its radio volume.")
        return
    end

    -- Queue the volume update
    volumeUpdateQueue[entIndex] = {
        entity = radioEntity,
        volume = volume,
        player = ply
    }

    -- If there's no timer running for this entity, create one
    if not timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            local updateData = volumeUpdateQueue[entIndex]
            if updateData then
                local updateEntity = updateData.entity
                local updateVolume = updateData.volume

                if IsValid(updateEntity) then
                    updateEntity:SetNWFloat("Volume", updateVolume)
                    
                    -- Broadcast the volume update to all clients
                    net.Start("UpdateRadioVolume")
                        net.WriteEntity(updateEntity)
                        net.WriteFloat(updateVolume)
                    net.Broadcast()

                    -- Update the ActiveRadios table if it exists for this entity
                    if ActiveRadios[entIndex] then
                        ActiveRadios[entIndex].volume = updateVolume
                    end

                    -- Save to database if permanent (for boomboxes)
                    if updateEntity.IsPermanent and SavePermanentBoombox and (entityClass == "boombox" or entityClass == "golden_boombox") then
                        SavePermanentBoombox(updateEntity)
                    end
                end

                -- Clear the queue for this entity
                volumeUpdateQueue[entIndex] = nil
            end
        end)
    end
end)

hook.Add("EntityRemoved", "CleanupVolumeUpdateTimers", function(entity)
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end
    volumeUpdateQueue[entIndex] = nil
end)

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity

    if ActiveRadios[mainEntity:EntIndex()] then
        RemoveActiveRadio(mainEntity)
    end
end)

--[[
    Function: IsDarkRP
    Utility function to detect if the gamemode is DarkRP or DerivedRP.
    Returns:
    - Boolean indicating if DarkRP is detected.
]]
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

--[[
    Function: AssignOwner
    Assigns ownership of an entity using CPPI.
    Parameters:
    - ply: The player to assign as the owner.
    - ent: The entity to assign ownership to.
]]
local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return
    end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)  -- Assign the owner using CPPI if available
    end

    -- Set the owner as a networked entity so the client can access it
    ent:SetNWEntity("Owner", ply)
end

-- Hook into InitPostEntity to ensure everything is initialized
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

-- Clean up player data on disconnect
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
    timer.Simple(0.5, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity)
    local entIndex = entity:EntIndex()
    LatestVolumeUpdates[entIndex] = nil
    if VolumeUpdateTimers[entIndex] then
        timer.Remove(VolumeUpdateTimers[entIndex])
        VolumeUpdateTimers[entIndex] = nil
    end
end)

hook.Add("PlayerDisconnected", "CleanupPlayerVolumeUpdateData", function(ply)
    for entIndex, updateData in pairs(LatestVolumeUpdates) do
        if updateData.ply == ply then
            LatestVolumeUpdates[entIndex] = nil
            if VolumeUpdateTimers[entIndex] then
                timer.Remove(VolumeUpdateTimers[entIndex])
                VolumeUpdateTimers[entIndex] = nil
            end
        end
    end
end)

hook.Add("EntityRemoved", "CleanupRadioTimers", function(entity)
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end
    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end
end)

_G.AddActiveRadio = AddActiveRadio

hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function()
    if not _G.AddActiveRadio then
        _G.AddActiveRadio = AddActiveRadio
    end
end)

local function CleanupInactiveRadios()
    local currentTime = CurTime()
    for entIndex, radio in pairs(ActiveRadios) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then  -- 1 hour inactivity
            RemoveActiveRadio(Entity(entIndex))
        end
    end
end

timer.Create("CleanupInactiveRadios", 300, 0, CleanupInactiveRadios)  -- Run every 5 minutes

