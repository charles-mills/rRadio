--[[
    Radio Addon Server-Side Main Script
    Author: Charles Mills
    Description: This file contains the main server-side functionality for the Radio Addon.
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
local SavePermanentBoombox, RemovePermanentBoombox, LoadPermanentBoomboxes

include("radio/server/sv_permanent.lua")
local utils = include("radio/shared/sh_utils.lua")

SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local LatestVolumeUpdates = {}
local VolumeUpdateTimers = {}

local volumeUpdateTimers = {}
local stationUpdateTimers = {}
local DEBOUNCE_TIME = 10 -- 10 seconds debounce

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

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
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
    if IsValid(parent) and string.StartWith(parent:GetClass(), "lvs_") then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") then
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
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("PlayCarRadioStation", function(len, ply)
    local currentTime = CurTime()
    local lastRequestTime = PlayerCooldowns[ply] or 0
    if currentTime - lastRequestTime < 0.25 then -- 0.25 second cooldown
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

            -- Update the station immediately for client-side responsiveness
            entity:SetNWString("StationName", stationName)
            entity:SetNWString("StationURL", stationURL)
            entity:SetNWFloat("Volume", volume)

            AddActiveRadio(entity, stationName, stationURL, volume)

            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(stationName)
                net.WriteString(stationURL)
                net.WriteFloat(volume)
            net.Broadcast()

            net.Start("UpdateRadioStatus")
                net.WriteEntity(entity)
                net.WriteString(stationName)
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

        RemoveActiveRadio(entity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
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

        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
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

    if not IsValid(entity) then
        return
    end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local radioEntity = lvsVehicle or entity
    local entIndex = radioEntity:EntIndex()

    -- Update the volume immediately for client-side responsiveness
    if entityClass == "boombox" or entityClass == "golden_boombox" then
        if not utils.canInteractWithBoombox(ply, radioEntity) then
            ply:ChatPrint("You do not have permission to control this boombox's volume.")
            return
        end
        radioEntity:SetNWFloat("Volume", volume)
    elseif entity:IsVehicle() or lvsVehicle then
        if ActiveRadios[entIndex] then
            ActiveRadios[entIndex].volume = volume
            net.Start("UpdateRadioVolume")
                net.WriteEntity(radioEntity)
                net.WriteFloat(volume)
            net.Broadcast()
        end
    end

    -- Debounce the database update
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end

    timer.Create("VolumeUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function()
        if IsValid(radioEntity) and radioEntity.IsPermanent and SavePermanentBoombox then
            SavePermanentBoombox(radioEntity)
        end
    end)
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
