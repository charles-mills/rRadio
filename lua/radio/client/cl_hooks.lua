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

-- Consolidated Think hook
local function RadioSystemThink()
    local currentTime = CurTime()

    -- Stream position and volume updates
    if (currentTime - lastUpdates.stream) >= TIMING.STREAM_UPDATE then
        lastUpdates.stream = currentTime
        
        for entIndex, streamData in pairs(StreamManager._streams) do
            if StreamManager:IsValid(entIndex) then
                StreamManager:UpdateStreamPosition(entIndex)
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
    net.Receive("PlayCarRadioStation", function()
        if not StateManager:GetState("streamsEnabled") then return end
        
        local entity = net.ReadEntity()
        if not IsValid(entity) then return end
        
        entity = utils.GetVehicle(entity) or entity
        if not IsValid(entity) then return end
        
        local stationName = net.ReadString()
        local url = net.ReadString()
        local volume = net.ReadFloat()
        
        Debug:Log("Received PlayCarRadioStation:", entity, stationName)
        
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