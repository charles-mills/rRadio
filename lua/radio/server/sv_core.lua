--[[
    Radio Addon Server-Side Core Functionality
    Author: Charles Mills
    Description: This file contains the core server-side functionality for the Radio Addon.
                 It handles network communications, manages active radios, processes player
                 requests for playing and stopping stations, and coordinates with permanent
                 boombox functionality. It also includes utility functions for entity ownership
                 and permissions.
    Date: November 3, 2024
]]--

local NETWORK_STRINGS = {
    "PlayCarRadioStation",
    "StopCarRadioStation",
    "OpenRadioMenu",
    "CarRadioMessage",
    "UpdateRadioStatus",
    "UpdateRadioVolume",
    "MakeBoomboxPermanent",
    "RemoveBoomboxPermanent",
    "BoomboxPermanentConfirmation",
    "RadioConfigUpdate",
    "RequestRadioMessage"
}

for _, str in ipairs(NETWORK_STRINGS) do
    util.AddNetworkString(str)
end

local GLOBAL_COOLDOWN = 0.1
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1
local STATION_UPDATE_DEBOUNCE_TIME = 2.0
local PERMANENT_SAVE_DELAY = 0.5
local STREAM_RETRY_DELAY = 0.2
local STATION_TUNING_DELAY = 2.0
local MAX_RETRY_ATTEMPTS = 3
local RETRY_COOLDOWN = 1.0
local CLEANUP_INTERVAL = 300 -- 5 minutes

local activeRadios = {}
local playerRetryAttempts = {}
local playerCooldowns = {}
local entityVolumes = {}
local volumeUpdateQueue = {}
BoomboxStatuses = BoomboxStatuses or {}

local utils = include("radio/shared/sh_utils.lua")
local resourceManager = include("radio/server/sv_resource_manager.lua")
include("radio/server/sv_permanent.lua")

local SavePermanentBoombox = _G.SavePermanentBoombox
local RemovePermanentBoombox = _G.RemovePermanentBoombox
local LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local function getDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end

    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return GetConVar("radio_golden_boombox_volume"):GetFloat()
    elseif entityClass == "boombox" then
        return GetConVar("radio_boombox_volume"):GetFloat()
    else
        return GetConVar("radio_vehicle_volume"):GetFloat()
    end
end

local function clampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = GetConVar("radio_max_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

local function initializeEntityVolume(entity)
    if not IsValid(entity) or not utils.canUseRadio(entity) then return end

    local entIndex = entity:EntIndex()
    if not entityVolumes[entIndex] then
        entityVolumes[entIndex] = getDefaultVolume(entity)
        entity:SetNWFloat("Volume", entityVolumes[entIndex])
    end
end

local function processVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) then return false end

    entity = utils.GetVehicle(entity) or entity
    if not utils.canUseRadio(entity) then return false end

    if utils.IsBoombox(entity) then
        if not utils.canInteractWithBoombox(ply, entity) then
            return false
        end
    elseif utils.GetVehicle(entity) then
        if not utils.isPlayerInVehicle(ply, entity) then
            return false
        end
    end

    volume = clampVolume(volume)
    local entIndex = entity:EntIndex()
    entityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)

    local inRangePlayers = {}
    local entityPos = entity:GetPos()
    local maxDistance

    if utils.IsBoombox(entity) then
        if entity:GetClass() == "golden_boombox" then
            maxDistance = GetConVar("radio_golden_boombox_max_distance"):GetFloat()
        else
            maxDistance = GetConVar("radio_boombox_max_distance"):GetFloat()
        end
    else
        maxDistance = GetConVar("radio_vehicle_max_distance"):GetFloat()
    end

    for _, player in ipairs(player.GetAll()) do
        if player:GetPos():DistToSqr(entityPos) <= (maxDistance * maxDistance) then
            table.insert(inRangePlayers, player)
        end
    end

    if #inRangePlayers > 0 then
        net.Start("UpdateRadioVolume")
            net.WriteEntity(entity)
            net.WriteFloat(volume)
        net.Send(inRangePlayers)
    end

    return true
end

local VolumeManager = {
    queue = {},
    lastUpdates = {},
    DEBOUNCE_TIME = 0.1,

    init = function(self)
        if not self.initialized then
            self.queue = {}
            self.lastUpdates = {}
            self.initialized = true
        end
    end,

    queueUpdate = function(self, entity, volume, ply)
        if not IsValid(entity) or not IsValid(ply) then return false end

        local entIndex = entity:EntIndex()

        self.queue[entIndex] = {
            volume = volume,
            player = ply,
            timestamp = CurTime()
        }

        if not self.lastUpdates[entIndex] or 
           (CurTime() - self.lastUpdates[entIndex]) >= self.DEBOUNCE_TIME then
            self:processUpdate(entIndex)
        end

        return true
    end,

    processUpdate = function(self, entIndex)
        local data = self.queue[entIndex]
        if not data then return false end

        local entity = Entity(entIndex)
        if not IsValid(entity) or not IsValid(data.player) then
            self.queue[entIndex] = nil
            return false
        end

        local success = processVolumeUpdate(entity, data.volume, data.player)

        if success then
            self.lastUpdates[entIndex] = CurTime()
            self.queue[entIndex] = nil
        end

        return success
    end,

    cleanup = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()

        self.queue[entIndex] = nil
        self.lastUpdates[entIndex] = nil

        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
    end,

    cleanupPlayer = function(self, ply)
        if not IsValid(ply) then return end

        for entIndex, data in pairs(self.queue) do
            if data.player == ply then
                self.queue[entIndex] = nil
                self.lastUpdates[entIndex] = nil

                if timer.Exists("VolumeUpdate_" .. entIndex) then
                    timer.Remove("VolumeUpdate_" .. entIndex)
                end
            end
        end
    end
}

VolumeManager:init()

local TimerManager = {
    activeTimers = {},

    create = function(self, name, delay, repetitions, func)
        if not name or not delay or not func then return end

        self:remove(name)

        timer.Create(name, delay, repetitions or 1, function()
            if func() == false then
                self:remove(name)
            end
        end)

        self.activeTimers[name] = true
    end,

    remove = function(self, name)
        if timer.Exists(name) then
            timer.Remove(name)
        end
        self.activeTimers[name] = nil
    end,

    cleanup = function(self, pattern)
        for timerName in pairs(self.activeTimers) do
            if pattern and string.find(timerName, pattern) then
                self:remove(timerName)
            end
        end
    end
}

local function createSafeTimer(name, delay, reps, func)
    if not name or not delay or not reps or not func then
        ErrorNoHalt("[rRadio] CreateSafeTimer: Invalid parameters provided\n")
        return
    end

    if timer.Exists(name) then 
        timer.Remove(name) 
    end

    timer.Create(name, delay, reps, function()
        if not func() then 
            timer.Remove(name)
        end
    end)
end

local function removeActiveRadio(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    activeRadios[entIndex] = nil

    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end
end

local function cleanupEntity(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()

    TimerManager:cleanup("_" .. entIndex)
    VolumeManager:cleanup(entity)
    entityVolumes[entIndex] = nil

    if activeRadios[entIndex] then
        removeActiveRadio(entity)
    end

    if utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
        utils.clearRadioStatus(entity)
    end
end

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    cleanupEntity(entity)
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    playerRetryAttempts[ply] = nil
    playerCooldowns[ply] = nil
    VolumeManager:cleanupPlayer(ply)

    for _, ent in ipairs(ents.GetAll()) do
        if utils.getOwner(ent) == ply then
            cleanupEntity(ent)
        end
    end
end)

local function debugPrint(...)
    if GetConVar("radio_debug"):GetBool() then
        print("[rRadio Debug Server]", ...)
    end
end

local function startNewStream(entity, stationName, stationURL, volume)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()

    debugPrint("Starting new stream",
        "\nEntity:", entity,
        "\nStation:", stationName,
        "\nURL:", stationURL,
        "\nVolume:", volume,
        "\nIsPermanent:", entity:GetNWBool("IsPermanent"))

    local displayName = utils.truncateStationName(stationName)

    addActiveRadio(entity, displayName, stationURL, volume)
    debugPrint("Added to activeRadios:",
        "\nEntity:", entity,
        "\nStation:", displayName,
        "\nURL:", stationURL)

    net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(displayName)
        net.WriteString(stationURL)
        net.WriteFloat(volume)
    net.Broadcast()

    debugPrint("Broadcasted PlayCarRadioStation to clients")

    if utils.IsBoombox(entity) then
        utils.setRadioStatus(entity, "tuning", displayName)

        TimerManager:create("StationUpdate_" .. entIndex, STATION_TUNING_DELAY, 1, function()
            if IsValid(entity) then
                utils.setRadioStatus(entity, "playing", displayName)
                debugPrint("Updated boombox status to playing", entity, displayName)

                if entity:GetNWBool("IsPermanent") and SavePermanentBoombox then
                    timer.Simple(0.5, function()
                        if IsValid(entity) then
                            debugPrint("Saving permanent boombox state to database")
                            SavePermanentBoombox(entity)
                        end
                    end)
                end
            end
            return true
        end)
    end
end

local function addActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) or not utils.canUseRadio(entity) then return end

    local entIndex = entity:EntIndex()
    initializeEntityVolume(entity)

    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", entityVolumes[entIndex])

    activeRadios[entIndex] = {
        stationName = stationName,
        url = url,
        volume = entityVolumes[entIndex]
    }

    if utils.IsBoombox(entity) then
        utils.setRadioStatus(entity, "playing", stationName, true)
    end
end

local function sendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end

    if not playerRetryAttempts[ply] then
        playerRetryAttempts[ply] = 1
    end

    debugPrint("Sending active radios to player:", ply)

    local attempt = playerRetryAttempts[ply]
    if table.IsEmpty(activeRadios) then
        if attempt >= 3 then
            playerRetryAttempts[ply] = nil
            return
        end

        playerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                sendActiveRadiosToPlayer(ply)
            else
                playerRetryAttempts[ply] = nil
            end
        end)
        return
    end

    for entIndex, radio in pairs(activeRadios) do
        local entity = Entity(entIndex)
        if IsValid(entity) then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
        end
    end

    playerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            sendActiveRadiosToPlayer(ply)
        end
    end)
end)

local function updateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end

    local veh = utils.GetVehicle(vehicle)
    if not veh then return end

    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)

    return isSitAnywhere
end

local function isLVSVehicle(entity)
    if not IsValid(entity) then return nil end

    local parent = entity:GetParent()
    if IsValid(parent) and (string.StartWith(parent:GetClass(), "lvs_") or string.StartWith(parent:GetClass(), "ses_")) then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") or string.StartWith(entity:GetClass(), "ses_") then
        return entity
    end

    return nil
end

local function getVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

local function getEntityOwner(entity)
    if not IsValid(entity) then return nil end

    if entity.CPPIGetOwner then
        return entity:CPPIGetOwner()
    end

    local nwOwner = entity:GetNWEntity("Owner")
    if IsValid(nwOwner) then
        return nwOwner
    end

    return nil
end

net.Receive("PlayCarRadioStation", function(len, ply)
    local currentTime = CurTime()
    if currentTime - (playerCooldowns[ply] or 0) < GLOBAL_COOLDOWN then
        return
    end
    playerCooldowns[ply] = currentTime

    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    local actualEntity = getVehicleEntity(entity)
    if not IsValid(actualEntity) then return end

    if utils.IsBoombox(actualEntity) and not utils.canInteractWithBoombox(ply, actualEntity) then
        return
    end

    local entIndex = actualEntity:EntIndex()

    resourceManager:RequestStream(ply, actualEntity, stationURL, function(success, error)
        if not success then
            ply:ChatPrint("[rRadio] " .. (error or "Failed to start stream"))
            return
        end

        if activeRadios[entIndex] then
            net.Start("StopCarRadioStation")
                net.WriteEntity(actualEntity)
            net.Broadcast()

            TimerManager:create("StartStream_" .. entIndex, STREAM_RETRY_DELAY, 1, function()
                startNewStream(actualEntity, stationName, stationURL, volume)
                return true
            end)
        else
            startNewStream(actualEntity, stationName, stationURL, volume)
        end
    end)
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) then return end

    local entityClass = entity:GetClass()
    local lvsVehicle = isLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        if not utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        utils.setRadioStatus(entity, "stopped")
        removeActiveRadio(entity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
            net.WriteBool(false)
            net.WriteString("stopped")
        net.Broadcast()

        local entIndex = entity:EntIndex()
        if timer.Exists("StationUpdate_" .. entIndex) then
            timer.Remove("StationUpdate_" .. entIndex)
        end

        if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
            timer.Create("SavePermanent_" .. entIndex, PERMANENT_SAVE_DELAY, 1, function()
                if IsValid(entity) then
                    SavePermanentBoombox(entity)
                end
            end)
        end

    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity

        removeActiveRadio(radioEntity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
            net.WriteBool(false)
        net.Broadcast()
    end
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()

    if not IsValid(entity) then return end

    entity = utils.GetVehicle(entity) or entity
    local entIndex = entity:EntIndex()

    volumeUpdateQueue[entIndex] = {
        lastUpdate = volumeUpdateQueue[entIndex] and volumeUpdateQueue[entIndex].lastUpdate or 0,
        pendingVolume = volume,
        pendingPlayer = ply
    }

    if CurTime() - (volumeUpdateQueue[entIndex].lastUpdate or 0) >= VOLUME_UPDATE_DEBOUNCE_TIME then
        processVolumeUpdate(entity, volume, ply)
        volumeUpdateQueue[entIndex].lastUpdate = CurTime()
        volumeUpdateQueue[entIndex].pendingVolume = nil
        volumeUpdateQueue[entIndex].pendingPlayer = nil
    else
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end

        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            if IsValid(entity) and IsValid(volumeUpdateQueue[entIndex].pendingPlayer) then
                processVolumeUpdate(entity, volumeUpdateQueue[entIndex].pendingVolume, volumeUpdateQueue[entIndex].pendingPlayer)
                volumeUpdateQueue[entIndex].lastUpdate = CurTime()
                volumeUpdateQueue[entIndex].pendingVolume = nil
                volumeUpdateQueue[entIndex].pendingPlayer = nil
            end
        end)
    end
end)

local function cleanupVolumeData(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()

    if volumeUpdateQueue[entIndex] then
        if timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
        volumeUpdateQueue[entIndex] = nil
    end

    entityVolumes[entIndex] = nil
end

hook.Add("EntityRemoved", "RadioSystemCleanup", function(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()

    cleanupEntity(entity)
    cleanupVolumeData(entity)
end)

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
    playerRetryAttempts[ply] = nil
    playerCooldowns[ply] = nil
    VolumeManager:cleanupPlayer(ply)

    for _, ent in ipairs(ents.GetAll()) do
        if utils.getOwner(ent) == ply then
            cleanupEntity(ent)
        end
    end
end)

local function isDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

local function assignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end

    ent:SetNWEntity("Owner", ply)
end

hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if isDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and utils.IsBoombox(ent) then
                    assignOwner(ply, ent)
                end
            end)
        end
    end)
end)

hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.IsBoombox(ent) then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and utils.IsBoombox(ent) then
        return utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    playerRetryAttempts[ply] = nil
    playerCooldowns[ply] = nil
end)

local function cleanupInactiveRadios()
    local currentTime = CurTime()
    for entIndex, radio in pairs(activeRadios) do
        local entity = Entity(entIndex)
        if not IsValid(entity) or currentTime - (radio.timestamp or 0) > 3600 then
            removeActiveRadio(entity)
        end
    end
    return true
end

createSafeTimer("CleanupInactiveRadios", CLEANUP_INTERVAL, 0, cleanupInactiveRadios)

hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
    createSafeTimer("LoadPermanentBoomboxes", 0.5, 1, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        end
        return true
    end)
end)

hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
    createSafeTimer("InitVolume_" .. entity:EntIndex(), 0, 1, function()
        if IsValid(entity) and (utils.IsBoombox(entity) or utils.GetVehicle(entity)) then
            initializeEntityVolume(entity)
        end
        return true
    end)
end)

hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity

    if activeRadios[mainEntity:EntIndex()] then
        removeActiveRadio(mainEntity)
    end
end)

_G.AddActiveRadio = addActiveRadio

hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function()
    if not _G.AddActiveRadio then
        _G.AddActiveRadio = addActiveRadio
    end
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    game.ReloadConVars()

    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Configuration reloaded!")
    else
        print("[rRadio] Configuration reloaded!")
    end
end)

local function addRadioCommand(name, helpText)
    concommand.Add("radio_set_" .. name, function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end

        local value = tonumber(args[1])
        if not value then
            if IsValid(ply) then
                ply:ChatPrint("[rRadio] Invalid value provided!")
            else
                print("[rRadio] Invalid value provided!")
            end
            return
        end

        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)

            local message = string.format("[rRadio] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then
                ply:ChatPrint(message)
            else
                print(message)
            end
        end
    end)
end

local radioCommands = {
    max_volume_limit = {
        desc = "Sets the maximum volume limit for all radio entities (0.0-1.0)",
        example = "0.8"
    },
    message_cooldown = {
        desc = "Sets the cooldown time in seconds for radio messages (the animation when entering a vehicle)",
        example = "2"
    },
    boombox_volume = {
        desc = "Sets the default volume for regular boomboxes",
        example = "0.7"
    },
    boombox_max_distance = {
        desc = "Sets the maximum hearing distance for boomboxes",
        example = "1000"
    },
    boombox_min_distance = {
        desc = "Sets the distance at which boombox volume starts to drop off",
        example = "500"
    },
    golden_boombox_volume = {
        desc = "Sets the default volume for golden boomboxes",
        example = "1.0"
    },
    golden_boombox_max_distance = {
        desc = "Sets the maximum hearing distance for golden boomboxes",
        example = "350000"
    },
    golden_boombox_min_distance = {
        desc = "Sets the distance at which golden boombox volume starts to drop off",
        example = "250000"
    },
    vehicle_volume = {
        desc = "Sets the default volume for vehicle radios",
        example = "0.8"
    },
    vehicle_max_distance = {
        desc = "Sets the maximum hearing distance for vehicle radios",
        example = "800"
    },
    vehicle_min_distance = {
        desc = "Sets the distance at which vehicle radio volume starts to drop off",
        example = "500"
    }
}

local function addRadioHelp(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[rRadio] You need to be a superadmin to use radio commands!")
        return 
    end

    local function printMessage(msg)
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, msg)
        else
            print(msg)
        end
    end

    printMessage("\n=== Radio Configuration Commands ===\n")
    printMessage("General Commands:")
    printMessage("  radio_help - Shows this help message")
    printMessage("  radio_reload_config - Reloads all radio configuration values")
    printMessage("\nConfiguration Commands:")

    for cmd, info in pairs(radioCommands) do
        printMessage(string.format("  radio_set_%s <value>", cmd))
        printMessage(string.format("    Description: %s", info.desc))
        printMessage(string.format("    Example: radio_set_%s %s\n", cmd, info.example))
    end

    printMessage("Current Values:")
    for cmd, _ in pairs(radioCommands) do
        local cvar = GetConVar("radio_" .. cmd)
        if cvar then
            printMessage(string.format("  %s: %.2f", cmd, cvar:GetFloat()))
        end
    end

    printMessage("\nNote: All commands require superadmin privileges.")

    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Help information printed to console!")
    end
end

concommand.Add("radio_help", addRadioHelp)

for name, _ in pairs(radioCommands) do
    addRadioCommand(name)
end

hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) then
            initializeEntityVolume(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupRadioVolume", function(entity)
    local entIndex = entity:EntIndex()
    entityVolumes[entIndex] = nil
end)

hook.Add("PlayerEnteredVehicle", "RadioVehicleHandling", function(ply, vehicle)
    local actualVehicle = utils.GetVehicle(vehicle)

    debugPrint("PlayerEnteredVehicle triggered:",
        "\nPlayer:", ply:Nick(),
        "\nVehicle Class:", vehicle:GetClass(),
        "\nActual Vehicle:", actualVehicle and actualVehicle:GetClass() or "none",
        "\nIs SitAnywhere:", utils.isSitAnywhereSeat(vehicle) and "yes" or "no",
        "\nCan Use Radio:", actualVehicle and utils.canUseRadio(actualVehicle) and "yes" or "no",
        "\nMessage Cooldown:", GetConVar("radio_message_cooldown"):GetFloat())

    if not actualVehicle then
        debugPrint("No actual vehicle found - skipping message")
        return
    end

    if utils.isSitAnywhereSeat(vehicle) then
        debugPrint("Skipping message - SitAnywhere seat detected")
        return
    end

    if not utils.canUseRadio(actualVehicle) then
        debugPrint("Skipping message - Vehicle cannot use radio")
        return
    end

    net.Start("CarRadioMessage")
        net.WriteEntity(actualVehicle)
        net.WriteBool(true)
    net.Send(ply)

    debugPrint("Sent CarRadioMessage to client for player:", ply:Nick())
end)
