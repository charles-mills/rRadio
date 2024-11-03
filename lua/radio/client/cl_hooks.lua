--[[
    Radio Addon Client-Side Hooks
    Author: Charles Mills
    Description: Implements hooks for stream and state management
    Date: October 31, 2024
]]--

local Events = include("radio/shared/sh_events.lua")
local utils = include("radio/shared/sh_utils.lua")
local StreamManager = include("radio/client/cl_stream_manager.lua")
local StateManager = include("radio/client/cl_state_manager.lua")
local Debug = RadioDebug

-- Initialize managers
StateManager:Initialize()

-- Add timing constants
local TIMING = {
    STREAM_UPDATE = 0.1,    -- 100ms for stream position updates
    VALIDITY_CHECK = 0.5,   -- 500ms for validity checks
    UI_UPDATE = 0.1,        -- 100ms for UI updates
    ANIMATION_UPDATE = 0.03 -- 30ms for smooth animations
}

local lastUpdates = {
    stream = 0,
    validity = 0,
    ui = 0,
    animation = 0
}

-- Add near the top with other local functions:

local function UpdateStreamVolume(stream, distanceSqr, isPlayerInCar, entity)
    if not IsValid(stream) or not IsValid(entity) then return end

    local entityConfig = utils.GetEntityConfig(entity)
    if not entityConfig then return end

    -- Early distance check
    local maxDist = entityConfig.MaxHearingDistance()
    if distanceSqr > (maxDist * maxDist) then
        stream:SetVolume(0)
        return
    end

    -- Get the user-set volume
    local userVolume = math.Clamp(
        entity:GetNWFloat("Volume", entityConfig.Volume()),
        0,
        Config.MaxVolume()
    )

    if userVolume <= 0.02 then
        stream:SetVolume(0)
        return
    end

    -- Check mute state
    local entIndex = entity:EntIndex()
    if MuteManager and MuteManager:IsMuted(entIndex) then
        stream:SetVolume(0)
        return
    end

    -- If player is in the vehicle, use full user-set volume and disable 3D
    if isPlayerInCar then
        stream:Set3DEnabled(false)
        stream:SetVolume(userVolume)
        return
    end

    -- Enable 3D audio for external listeners
    stream:Set3DEnabled(true)
    local minDist = entityConfig.MinVolumeDistance()
    
    -- Configure 3D sound properties
    stream:Set3DCone(180, 360, 0.8)
    stream:Set3DFadeDistance(minDist, maxDist)
    stream:SetPlaybackRate(1.0)
    
    -- Calculate volume falloff
    local finalVolume = userVolume
    if distanceSqr > minDist * minDist then
        local dist = math.sqrt(distanceSqr)
        local falloff = 1 - math.pow((dist - minDist) / (maxDist - minDist), 0.75)
        finalVolume = userVolume * math.Clamp(falloff, 0, 1)
    end

    stream:SetVolume(finalVolume)
end

-- Consolidated Think hook
local function RadioSystemThink()
    local currentTime = CurTime()

    -- Stream position and volume updates
    if (currentTime - lastUpdates.stream) >= TIMING.STREAM_UPDATE then
        lastUpdates.stream = currentTime
        
        local ply = LocalPlayer()
        local plyPos = ply:GetPos()
        
        for entIndex, streamData in pairs(StreamManager._streams) do
            -- Skip streams that are still initializing
            if streamData.state == StreamManager.States.INITIALIZING then
                Debug:Log("Skipping initialization-state stream:", entIndex)
                continue
            end

            -- Skip streams that are connecting
            if streamData.state == StreamManager.States.CONNECTING then
                Debug:Log("Skipping connecting-state stream:", entIndex)
                continue
            end

            local entity = streamData.entity
            local stream = streamData.stream

            -- Only validate streams that should be playing
            if streamData.state == StreamManager.States.PLAYING then
                if not IsValid(stream) then
                    Debug:Log("Stream validation failed for playing stream", entIndex)
                    Debug:Log("- Stream exists:", stream ~= nil)
                    Debug:Log("- Stream state:", stream and stream:GetState() or "nil")
                    StreamManager:QueueCleanup(entIndex, "invalid_stream")
                    continue
                end

                -- Update position and volume only for valid playing streams
                stream:SetPos(entity:GetPos())
                
                -- Calculate distance and player state
                local distanceSqr = plyPos:DistToSqr(entity:GetPos())
                local isPlayerInCar = false
                
                if entity:IsVehicle() then
                    local vehicle = utils.GetVehicle(entity)
                    if IsValid(vehicle) then
                        isPlayerInCar = (vehicle:GetDriver() == ply)
                    end
                end
                
                -- Update volume
                UpdateStreamVolume(stream, distanceSqr, isPlayerInCar, entity)
            end
        end
    end

    -- Validity cache updates
    if (currentTime - lastUpdates.validity) >= TIMING.VALIDITY_CHECK then
        lastUpdates.validity = currentTime
        StreamManager:UpdateValidityCache()
    end

    -- UI reference tracking
    if (currentTime - lastUpdates.ui) >= TIMING.UI_UPDATE then
        lastUpdates.ui = currentTime
        if UIReferenceTracker then
            UIReferenceTracker:Update()
        end
    end

    -- Animation updates
    if (currentTime - lastUpdates.animation) >= TIMING.ANIMATION_UPDATE then
        lastUpdates.animation = currentTime
        if Misc and Misc.Animations then
            Misc.Animations:Think()
        end
    end
end

local function InitializeHooks()
    hook.Add("Think", "RadioSystemThink", RadioSystemThink)

    -- Cleanup hooks
    hook.Add("EntityRemoved", "RadioEntityCleanup", function(entity)
        if IsValid(entity) then
            Debug:Log("Entity removed:", entity)
            StreamManager:CleanupStream(entity:EntIndex())
        end
    end)

    hook.Add("ShutDown", "RadioSystemCleanup", function()
        Debug:Log("System shutdown - cleaning up streams")
        for entIndex, _ in pairs(StreamManager._streams) do
            StreamManager:CleanupStream(entIndex)
        end
        StateManager:SaveFavorites()
    end)

    -- Vehicle state hooks
    hook.Add("VehicleChanged", "RadioVehicleStateUpdate", function(ply, old, new)
        if ply ~= LocalPlayer() then return end
        
        Debug:Log("Vehicle changed:", old, "->", new)
        
        if not new then
            ply.currentRadioEntity = nil
            StateManager:SetState("currentRadioEntity", nil)
            return
        end
        
        local actualVehicle = utils.GetVehicle(new)
        if actualVehicle then
            ply.currentRadioEntity = actualVehicle
            StateManager:SetState("currentRadioEntity", actualVehicle)
        end
    end)

    -- Player state hooks
    hook.Add("PlayerEnteredVehicle", "RadioVehicleEnter", function(ply, vehicle)
        if ply ~= LocalPlayer() then return end
        Debug:Log("Player entered vehicle:", vehicle)
        
        if utils.canUseRadio(vehicle) then
            StateManager:SetState("currentRadioEntity", vehicle)
        end
    end)

    hook.Add("PlayerLeaveVehicle", "RadioVehicleLeave", function(ply, vehicle)
        if ply ~= LocalPlayer() then return end
        Debug:Log("Player left vehicle:", vehicle)
        
        if StateManager:GetState("currentRadioEntity") == vehicle then
            StateManager:SetState("currentRadioEntity", nil)
        end
    end)
end

-- Initialize networking
local function InitializeNetworking()
    -- Station playback messages
    net.Receive("QueueStream", function()
        if not StateManager:GetState("streamsEnabled") then
            Debug:Log("Streams are disabled, ignoring QueueStream")
            return
        end
        
        local entity = net.ReadEntity()
        Debug:Log("QueueStream received")
        Debug:Log("- Entity:", entity)
        Debug:Log("- Entity valid:", IsValid(entity))
        Debug:Log("- Entity class:", entity and entity:GetClass() or "nil")
        
        if not IsValid(entity) then return end
        
        entity = utils.GetVehicle(entity) or entity
        if not IsValid(entity) then return end
        
        local stationName = net.ReadString()
        local url = net.ReadString()
        local volume = net.ReadFloat()
        
        Debug:Log("Received QueueStream:", entity, stationName)
        
        local entityConfig = utils.GetEntityConfig(entity)
        if not entityConfig then
            Debug:Error("No entity config found for", entity)
            return
        end
        
        StreamManager:CreateStream(entity, {
            name = stationName,
            url = url,
            volume = volume,
            minDist = entityConfig.MinVolumeDistance(),
            maxDist = entityConfig.MaxHearingDistance()
        })
    end)

    net.Receive("StopCarRadioStation", function()
        local entity = net.ReadEntity()
        if not IsValid(entity) then return end
        
        Debug:Log("Received StopCarRadioStation:", entity)
        
        entity = utils.GetVehicle(entity) or entity
        if not IsValid(entity) then return end
        
        StreamManager:CleanupStream(entity:EntIndex())
    end)

    -- Volume update messages
    net.Receive("UpdateRadioVolume", function()
        local entity = net.ReadEntity()
        local volume = net.ReadFloat()
        
        if not IsValid(entity) then return end
        
        Debug:Log("Received UpdateRadioVolume:", entity, volume)
        
        local entIndex = entity:EntIndex()
        local streamData = StreamManager._streams[entIndex]
        if streamData then
            streamData.data.volume = volume
            StreamManager:UpdateStreamVolume(entIndex)
        end
        
        StateManager:SetState("entityVolumes", {
            [entity] = volume
        })
    end)

    -- Config update messages
    net.Receive("RadioConfigUpdate", function()
        Debug:Log("Received RadioConfigUpdate")
        
        -- Update all active streams
        for entIndex, streamData in pairs(StreamManager._streams) do
            if StreamManager:IsValid(entIndex) then
                local entity = streamData.entity
                if IsValid(entity) then
                    local entityConfig = utils.GetEntityConfig(entity)
                    if entityConfig then
                        local volume = math.Clamp(
                            StateManager:GetState("entityVolumes")[entity] or entityConfig.Volume(),
                            0,
                            Config.MaxVolume()
                        )
                        StreamManager:UpdateStreamVolume(entIndex, volume)
                    end
                end
            end
        end
    end)
end

-- Initialize everything
hook.Add("InitPostEntity", "RadioSystemInitialize", function()
    Debug:Log("Initializing radio system")
    InitializeHooks()
    InitializeNetworking()
end)

hook.Add("OnReloaded", "RadioSystemReload", function()
    Debug:Log("Reloading radio system")
    InitializeHooks()
    InitializeNetworking()
end) 