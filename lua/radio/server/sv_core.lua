-- rRadio Server Core
-- Enhanced logic, optimized performance, and accurate volume handling

include("radio/server/sv_permanent.lua")

-- Network strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")
util.AddNetworkString("MakeBoomboxPermanent")
util.AddNetworkString("RemoveBoomboxPermanent")
util.AddNetworkString("BoomboxPermanentConfirmation")
util.AddNetworkString("RadioConfigUpdate")

-- Server state
rRadio.serverState = rRadio.serverState or {
    ActiveRadios = {},
    EntityVolumes = {},
    PlayerCooldowns = {},
    PlayerRetryAttempts = {},
    VolumeUpdateQueue = {},
    LastStationChangeTimes = {}
}

-- Constants
local DEBOUNCE_TIME = 10
local MAX_ACTIVE_RADIOS = 100
local PLAYER_RADIO_LIMIT = 5
local GLOBAL_COOLDOWN = 1
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1
local STATION_CHANGE_COOLDOWN = 0.5
local lastGlobalAction = 0

-- File paths
local volumeFile = "rradio/server_entity_volumes.json"

-- Permanent boombox functions
local SavePermanentBoombox = _G.SavePermanentBoombox
local LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

-- Utility functions
local function ClampVolume(volume)
    local maxVolume = GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat() or 1.0
    return math.Clamp(tonumber(volume) or 0.5, 0, maxVolume)
end

local function GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return GetConVar("rammel_rradio_sv_gold_default_volume"):GetFloat() or 0.7
    elseif entityClass == "boombox" then
        return GetConVar("rammel_rradio_sv_boombox_default_volume"):GetFloat() or 0.5
    else
        return GetConVar("rammel_rradio_sv_vehicle_default_volume"):GetFloat() or 0.5
    end
end

local function InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    if not rRadio.serverState.EntityVolumes[entIndex] then
        rRadio.serverState.EntityVolumes[entIndex] = GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", rRadio.serverState.EntityVolumes[entIndex])
    end
end

local function LoadEntityVolumes()
    if file.Exists(volumeFile, "DATA") then
        local success, data = pcall(util.JSONToTable, file.Read(volumeFile, "DATA"))
        if success and data and type(data) == "table" then
            for entIndex, volume in pairs(data) do
                if type(entIndex) == "string" and type(volume) == "number" then
                    rRadio.serverState.EntityVolumes[tonumber(entIndex)] = ClampVolume(volume)
                end
            end
        else
            ErrorNoHalt("[rRadio] Failed to load server entity volumes: " .. tostring(data) .. "\n")
        end
    end
end

local function SaveEntityVolumes()
    local volumeTable = {}
    for entIndex, volume in pairs(rRadio.serverState.EntityVolumes) do
        if type(entIndex) == "number" and type(volume) == "number" then
            volumeTable[tostring(entIndex)] = volume
        end
    end
    local json = util.TableToJSON(volumeTable, true)
    if json then
        if file.Exists(volumeFile, "DATA") then
            file.Write(volumeFile .. ".bak", file.Read(volumeFile, "DATA"))
        end
        file.Write(volumeFile, json)
    else
        ErrorNoHalt("[rRadio] Failed to convert server entity volumes to JSON\n")
    end
end

local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    rRadio.serverState.EntityVolumes[entIndex] = ClampVolume(volume or rRadio.serverState.EntityVolumes[entIndex] or GetDefaultVolume(entity))
    entity:SetNWString("StationName", tostring(stationName or ""))
    entity:SetNWString("StationURL", tostring(url or ""))
    entity:SetNWFloat("Volume", rRadio.serverState.EntityVolumes[entIndex])
    rRadio.serverState.ActiveRadios[entIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = rRadio.serverState.EntityVolumes[entIndex],
        timestamp = CurTime()
    }
    if rRadio.utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = {
            stationStatus = "playing",
            stationName = stationName,
            url = url
        }
    end
    SaveEntityVolumes()
end

local function RemoveActiveRadio(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    rRadio.serverState.ActiveRadios[entIndex] = nil
    if rRadio.utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = nil
    end
end

local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end
    local attempts = (rRadio.serverState.PlayerRetryAttempts[ply] or 0) + 1
    rRadio.serverState.PlayerRetryAttempts[ply] = attempts

    if table.IsEmpty(rRadio.serverState.ActiveRadios) then
        if attempts >= 3 then
            rRadio.serverState.PlayerRetryAttempts[ply] = nil
            return
        end
        timer.Simple(5, function()
            if IsValid(ply) then SendActiveRadiosToPlayer(ply) end
        end)
        return
    end

    for entIndex, radio in pairs(rRadio.serverState.ActiveRadios) do
        local entity = Entity(entIndex)
        if IsValid(entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(radio.stationName or "")
            net.WriteString(radio.url or "")
            net.WriteFloat(radio.volume or 0.5)
            net.Send(ply)
        end
    end
    rRadio.serverState.PlayerRetryAttempts[ply] = nil
end

local function UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return false end
    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh then return false end
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    return isSitAnywhere
end

local function IsLVSVehicle(entity)
    if not IsValid(entity) then return nil end
    local parent = entity:GetParent()
    if IsValid(parent) and (string.StartWith(parent:GetClass(), "lvs_") or string.StartWith(parent:GetClass(), "ses_")) then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") or string.StartWith(entity:GetClass(), "ses_") then
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

local function canControlRadio(ply, entity)
    if not IsValid(ply) or not IsValid(entity) then return false end
    if hook.Run("rRadio.PrePlayStation", ply, entity) == false then return false end
    if not rRadio.utils.canUseRadio(entity) then return false end

    if rRadio.utils.IsBoombox(entity) then
        return rRadio.utils.canInteractWithBoombox(ply, entity)
    elseif rRadio.utils.GetVehicle(entity) then
        local vehicle = rRadio.utils.GetVehicle(entity)
        if rRadio.utils.isSitAnywhereSeat(vehicle) then return false end
        if rRadio.config.DriverPlayOnly and vehicle:GetDriver() ~= ply then return false end
        local isInVehicle = false
        for _, seat in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == vehicle and seat:GetDriver() == ply then
                isInVehicle = true
                break
            end
        end
        return isInVehicle or vehicle:GetDriver() == ply
    end
    return false
end

local function ClearOldestActiveRadio()
    local oldestTime, oldestIdx = math.huge, nil
    for entIdx, data in pairs(rRadio.serverState.ActiveRadios) do
        local ent = data.entity or Entity(entIdx)
        if not IsValid(ent) then
            rRadio.serverState.ActiveRadios[entIdx] = nil
        elseif data.timestamp and data.timestamp < oldestTime then
            oldestTime, oldestIdx = data.timestamp, entIdx
        end
    end
    if oldestIdx then
        local oldEnt = Entity(oldestIdx)
        if IsValid(oldEnt) then
            net.Start("StopCarRadioStation")
            net.WriteEntity(oldEnt)
            net.Broadcast()
        end
        RemoveActiveRadio(oldEnt)
    end
end

local function CountPlayerRadios(ply)
    local cnt = 0
    for _, data in pairs(rRadio.serverState.ActiveRadios) do
        if IsValid(data.entity) and rRadio.utils.getOwner(data.entity) == ply then
            cnt = cnt + 1
        end
    end
    return cnt
end

local function BroadcastPlay(ent, station, url, volume)
    net.Start("PlayCarRadioStation")
    net.WriteEntity(ent)
    net.WriteString(tostring(station))
    net.WriteString(tostring(url))
    net.WriteFloat(volume)
    net.Broadcast()
end

local function BroadcastStop(ent)
    net.Start("StopCarRadioStation")
    net.WriteEntity(ent)
    net.Broadcast()
end

local function BroadcastStatus(ent, stationName, isPlaying, status)
    net.Start("UpdateRadioStatus")
    net.WriteEntity(ent)
    net.WriteString(tostring(stationName or ""))
    net.WriteBool(isPlaying or false)
    net.WriteString(tostring(status or "stopped"))
    net.Broadcast()
end

local function ProcessVolumeUpdate(entity, volume, ply)
    if not canControlRadio(ply, entity) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] You do not have permission to adjust this radio.") end
        return
    end
    local entIndex = entity:EntIndex()
    volume = ClampVolume(volume)
    rRadio.serverState.EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)
    net.Start("UpdateRadioVolume")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.SendPAS(entity:GetPos())
    SaveEntityVolumes()
end

local function CleanupInactiveRadios()
    local currentTime = CurTime()
    for entIndex, radio in pairs(rRadio.serverState.ActiveRadios) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then
            RemoveActiveRadio(Entity(entIndex))
        end
    end
end

local radioCommands = {
    max_volume_limit = {
        desc = "Sets the maximum volume limit for all radio entities (0.0-1.0)",
        example = "0.8",
        cvar = "rammel_rradio_sv_vehicle_volume_limit"
    },
    message_cooldown = {
        desc = "Sets the cooldown time in seconds for radio messages",
        example = "2",
        cvar = "radio_message_cooldown"
    },
    boombox_volume = {
        desc = "Sets the default volume for regular boomboxes",
        example = "0.7",
        cvar = "rammel_rradio_sv_boombox_default_volume"
    },
    boombox_max_distance = {
        desc = "Sets the maximum hearing distance for boomboxes",
        example = "1000",
        cvar = "radio_boombox_max_distance"
    },
    boombox_min_distance = {
        desc = "Sets the distance at which boombox volume starts to drop off",
        example = "500",
        cvar = "radio_boombox_min_distance"
    },
    golden_boombox_volume = {
        desc = "Sets the default volume for golden boomboxes",
        example = "1.0",
        cvar = "rammel_rradio_sv_gold_default_volume"
    },
    golden_boombox_max_distance = {
        desc = "Sets the maximum hearing distance for golden boomboxes",
        example = "350000",
        cvar = "radio_golden_boombox_max_distance"
    },
    golden_boombox_min_distance = {
        desc = "Sets the distance at which golden boombox volume starts to drop off",
        example = "250000",
        cvar = "radio_golden_boombox_min_distance"
    },
    vehicle_volume = {
        desc = "Sets the default volume for vehicle radios",
        example = "0.8",
        cvar = "rammel_rradio_sv_vehicle_default_volume"
    },
    vehicle_max_distance = {
        desc = "Sets the maximum hearing distance for vehicle radios",
        example = "800",
        cvar = "radio_vehicle_max_distance"
    },
    vehicle_min_distance = {
        desc = "Sets the distance at which vehicle radio volume starts to drop off",
        example = "500",
        cvar = "radio_vehicle_min_distance"
    }
}

local function AddRadioCommand(name)
    local cmdInfo = radioCommands[name]
    if not cmdInfo then return end

    concommand.Add("radio_set_" .. name, function(ply, _, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            if IsValid(ply) then ply:ChatPrint("[rRADIO] You need superadmin privileges.") end
            return
        end

        if not args[1] or args[1] == "help" then
            local msg = string.format("[rRADIO] %s\nUsage: radio_set_%s <value>\nExample: radio_set_%s %s",
                cmdInfo.desc, name, name, cmdInfo.example)
            if IsValid(ply) then
                ply:PrintMessage(HUD_PRINTCONSOLE, msg)
                ply:ChatPrint("[rRADIO] Command help printed to console!")
            else
                print(msg)
            end
            return
        end

        local value = tonumber(args[1])
        if not value then
            local msg = "[rRADIO] Invalid value provided! Use 'help' for usage information."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end

        local cvar = GetConVar(cmdInfo.cvar)
        if cvar then
            cvar:SetFloat(value)
            local msg = string.format("[rRADIO] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        end
    end)
end

concommand.Add("radio_help", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] You need superadmin privileges.") end
        return
    end

    local function printMessage(msg)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end

    printMessage("\n=== Radio Configuration Commands ===\n")
    printMessage("General Commands:")
    printMessage("  radio_help - Shows this help message")
    printMessage("  radio_reload_config - Reloads all radio configuration values")
    printMessage("\nConfiguration Commands:")
    for cmd, info in SortedPairs(radioCommands) do
        printMessage(string.format("  radio_set_%s <value>", cmd))
        printMessage(string.format("    Description: %s", info.desc))
        printMessage(string.format("    Example: radio_set_%s %s\n", cmd, info.example))
    end

    printMessage("Current Values:")
    for cmd, info in SortedPairs(radioCommands) do
        local cvar = GetConVar(info.cvar)
        if cvar then
            printMessage(string.format("  %s: %.2f", cmd, cvar:GetFloat()))
        end
    end

    printMessage("\nNote: All commands require superadmin privileges.")
    if IsValid(ply) then ply:ChatPrint("[rRADIO] Help information printed to console!") end
end)

for cmd in pairs(radioCommands) do
    AddRadioCommand(cmd)
end

local function CleanupEntityData(entIndex)
    timer.Remove("VolumeUpdate_" .. entIndex)
    timer.Remove("StationUpdate_" .. entIndex)
    rRadio.serverState.VolumeUpdateQueue[entIndex] = nil
end

local function IsDarkRP()
    return DarkRP and DarkRP.getPhrase
end

local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ent.CPPISetOwner then ent:CPPISetOwner(ply) end
    ent:SetNWEntity("Owner", ply)
end

net.Receive("PlayCarRadioStation", function(_, ply)
    local now = CurTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] System busy. Try again shortly.") end
        return
    end
    lastGlobalAction = now

    local ent = GetVehicleEntity(net.ReadEntity())
    local station = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(ent) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] Invalid radio entity.") end
        return
    end

    if not canControlRadio(ply, ent) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] You do not have permission to control this radio.") end
        return
    end

    if now - (rRadio.serverState.PlayerCooldowns[ply] or 0) < STATION_CHANGE_COOLDOWN then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] Changing stations too quickly.") end
        return
    end
    rRadio.serverState.PlayerCooldowns[ply] = now

    if table.Count(rRadio.serverState.ActiveRadios) >= MAX_ACTIVE_RADIOS then
        ClearOldestActiveRadio()
    end

    if CountPlayerRadios(ply) >= PLAYER_RADIO_LIMIT then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] Maximum active radios reached.") end
        return
    end

    local entIndex = ent:EntIndex()
    if rRadio.utils.IsBoombox(ent) then
        rRadio.utils.setRadioStatus(ent, "tuning", station)
        BoomboxStatuses[entIndex] = BoomboxStatuses[entIndex] or {}
        BoomboxStatuses[entIndex].url = stationURL
    end

    if rRadio.serverState.ActiveRadios[entIndex] then
        BroadcastStop(ent)
        RemoveActiveRadio(ent)
    end

    AddActiveRadio(ent, station, stationURL, volume)
    BroadcastPlay(ent, station, stationURL, rRadio.serverState.EntityVolumes[entIndex])
    BroadcastStatus(ent, station, true, "playing")

    if ent.IsPermanent and SavePermanentBoombox then
        SavePermanentBoombox(ent)
    end

    timer.Create("StationUpdate_" .. entIndex, 2, 1, function()
        if IsValid(ent) then
            rRadio.utils.setRadioStatus(ent, "playing", station)
            BroadcastStatus(ent, station, true, "playing")
        end
    end)

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("StopCarRadioStation", function(_, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] Invalid radio entity.") end
        return
    end

    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end

    if not canControlRadio(ply, entity) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] You do not have permission to control this radio.") end
        return
    end

    local entIndex = entity:EntIndex()
    if rRadio.utils.IsBoombox(entity) then
        rRadio.utils.setRadioStatus(entity, "stopped")
        RemoveActiveRadio(entity)
        BroadcastStop(entity)
        BroadcastStatus(entity, "", false, "stopped")
        timer.Remove("StationUpdate_" .. entIndex)
        if entity.IsPermanent and SavePermanentBoombox then
            timer.Create("StationUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function()
                if IsValid(entity) then SavePermanentBoombox(entity) end
            end)
        end
    elseif entity:IsVehicle() or IsLVSVehicle(entity) then
        local radioEntity = IsLVSVehicle(entity) or entity
        RemoveActiveRadio(radioEntity)
        BroadcastStop(radioEntity)
        BroadcastStatus(radioEntity, "", false, "stopped")
        timer.Remove("StationUpdate_" .. entIndex)
    end

    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("UpdateRadioVolume", function(_, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    if not IsValid(entity) then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] Invalid radio entity.") end
        return
    end

    local entIndex = entity:EntIndex()
    rRadio.serverState.VolumeUpdateQueue[entIndex] = rRadio.serverState.VolumeUpdateQueue[entIndex] or {
        lastUpdate = 0,
        pendingVolume = nil,
        pendingPlayer = nil
    }
    local updateData = rRadio.serverState.VolumeUpdateQueue[entIndex]
    local currentTime = CurTime()
    updateData.pendingVolume = volume
    updateData.pendingPlayer = ply

    if currentTime - updateData.lastUpdate >= VOLUME_UPDATE_DEBOUNCE_TIME then
        ProcessVolumeUpdate(entity, volume, ply)
        updateData.lastUpdate = currentTime
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            if updateData.pendingVolume and IsValid(updateData.pendingPlayer) then
                ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
                updateData.lastUpdate = CurTime()
                updateData.pendingVolume = nil
                updateData.pendingPlayer = nil
            end
        end)
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
            LoadEntityVolumes()
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    if not ply:GetInfoNum("rammel_rradio_enabled", 1) == 1 then return end
    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh or rRadio.utils.isSitAnywhereSeat(vehicle) then return end
    if rRadio.config.DriverPlayOnly and veh:GetDriver() ~= ply then return end

    net.Start("CarRadioMessage")
    net.WriteEntity(vehicle)
    net.WriteBool(veh:GetDriver() == ply)
    net.Send(ply)
end)

hook.Add("CanTool", "rRadio.AllowBoomboxToolgun", function(ply, tr)
    local ent = tr.Entity
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        return rRadio.utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("PhysgunPickup", "rRadio.AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
        return rRadio.utils.canInteractWithBoombox(ply, ent)
    end
end)

hook.Add("InitPostEntity", "rRadio.initalizePostEntity", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, _, ent)
                if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)

    timer.Simple(0.5, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        end
    end)

    _G.AddActiveRadio = AddActiveRadio
    LoadEntityVolumes()
end)

timer.Create("CleanupInactiveRadios", 300, 0, CleanupInactiveRadios)

hook.Add("OnEntityCreated", "rRadio.InitializeRadio", function(entity)
    timer.Simple(0, function()
        if IsValid(entity) and (rRadio.utils.IsBoombox(entity) or rRadio.utils.GetVehicle(entity)) then
            InitializeEntityVolume(entity)
        end
    end)
    timer.Simple(0, function()
        if IsValid(entity) and rRadio.utils.GetVehicle(entity) then
            UpdateVehicleStatus(entity)
        end
    end)
end)

hook.Add("EntityRemoved", "rRadio.CleanupEntityRemoved", function(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    CleanupEntityData(entIndex)
    RemoveActiveRadio(entity)
    rRadio.serverState.EntityVolumes[entIndex] = nil
    SaveEntityVolumes()
end)

hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    rRadio.serverState.PlayerRetryAttempts[ply] = nil
    rRadio.serverState.PlayerCooldowns[ply] = nil
    for entIndex, data in pairs(rRadio.serverState.VolumeUpdateQueue) do
        if data.pendingPlayer == ply then
            CleanupEntityData(entIndex)
        end
    end
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        if IsValid(ply) then ply:ChatPrint("[rRADIO] You need superadmin privileges.") end
        return
    end
    game.ReloadConVars()
    local msg = "[rRADIO] Configuration reloaded!"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
