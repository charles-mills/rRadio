include("radio/server/sv_permanent.lua")

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

hook.Run("rRadio.PostServerLoad")

local ActiveRadios = {}
local PlayerCooldowns = {}
local EntityVolumes = {}
local VolumeUpdateQueue = {}
local BoomboxStatuses = {}

local SavePermanentBoombox = _G.SavePermanentBoombox
local LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local MAX_ACTIVE_RADIOS = 100
local PLAYER_RADIO_LIMIT = 5
local GLOBAL_COOLDOWN = 1
local VOLUME_UPDATE_DEBOUNCE = 0.1
local STATION_CHANGE_COOLDOWN = 0.5
local CLEANUP_INTERVAL = 300
local lastGlobalAction = 0

local function ClampVolume(volume)
    if not isnumber(volume) then return 0.5 end
    local maxVolume = GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

local function GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local class = entity:GetClass()
    local cvarMap = {
        golden_boombox = "rammel_rradio_sv_gold_default_volume",
        boombox = "rammel_rradio_sv_boombox_default_volume"
    }
    return GetConVar(cvarMap[class] or "rammel_rradio_sv_vehicle_default_volume"):GetFloat()
end

local function SetEntityVolume(entity, volume)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    volume = ClampVolume(volume)
    EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)
    if ActiveRadios[entIndex] then
        ActiveRadios[entIndex].volume = volume
    end
end

local function GetEntityVolume(entity)
    if not IsValid(entity) then return GetDefaultVolume(entity) end
    local entIndex = entity:EntIndex()
    return EntityVolumes[entIndex] or GetDefaultVolume(entity)
end

local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    volume = ClampVolume(volume or GetEntityVolume(entity))
    ActiveRadios[entIndex] = {
        entity = entity,
        stationName = stationName or "",
        url = url or "",
        volume = volume,
        timestamp = CurTime()
    }
    entity:SetNWString("StationName", stationName or "")
    entity:SetNWString("StationURL", url or "")
    entity:SetNWFloat("Volume", volume)
    if rRadio.utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = {
            stationStatus = "playing",
            stationName = stationName or "",
            url = url or ""
        }
    end
end

local function RemoveActiveRadio(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    ActiveRadios[entIndex] = nil
    BoomboxStatuses[entIndex] = nil
    EntityVolumes[entIndex] = nil
    VolumeUpdateQueue[entIndex] = nil
    timer.Remove("StationUpdate_" .. entIndex)
    timer.Remove("VolumeUpdate_" .. entIndex)
end

local function BroadcastPlay(entity, station, url, volume)
    net.Start("PlayCarRadioStation")
    net.WriteEntity(entity)
    net.WriteString(station)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.Broadcast()
end

local function BroadcastStop(entity)
    net.Start("StopCarRadioStation")
    net.WriteEntity(entity)
    net.Broadcast()
    net.Start("UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString("")
    net.WriteBool(false)
    net.WriteString("stopped")
    net.Broadcast()
end

local function ClearOldestActiveRadio()
    local oldestTime, oldestIdx = math.huge, nil
    for entIndex, radio in pairs(ActiveRadios) do
        if not IsValid(radio.entity) then
            RemoveActiveRadio(radio.entity or Entity(entIndex))
        elseif radio.timestamp < oldestTime then
            oldestTime, oldestIdx = entIndex
        end
    end
    if oldestIdx then
        local entity = Entity(oldestIdx)
        if IsValid(entity) then
            BroadcastStop(entity)
            RemoveActiveRadio(entity)
        end
    end
end

local function CountPlayerRadios(ply)
    if not IsValid(ply) then return 0 end
    local count = 0
    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) and rRadio.utils.getOwner(radio.entity) == ply then
            count = count + 1
        end
    end
    return count
end

local function GetVehicleEntity(entity)
    if not IsValid(entity) then return nil end
    if entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

local function ProcessVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) or not IsValid(ply) then return end
    entity = GetVehicleEntity(entity)
    local entIndex = entity:EntIndex()
    
    if rRadio.utils.IsBoombox(entity) then
        if not rRadio.utils.canInteractWithBoombox(ply, entity) then return end
    elseif entity:IsVehicle() then
        if rRadio.utils.isSitAnywhereSeat(entity) then return end
        local isInVehicle = entity:GetDriver() == ply
        for _, seat in ipairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == entity and seat:GetDriver() == ply then
                isInVehicle = true
                break
            end
        end
        if not isInVehicle then return end
    else
        return
    end
    
    SetEntityVolume(entity, volume)
    
    net.Start("UpdateRadioVolume")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.SendPAS(entity:GetPos())
end

local function CleanupInactiveRadios()
    for entIndex, radio in pairs(ActiveRadios) do
        if not IsValid(radio.entity) or CurTime() - radio.timestamp > 3600 then
            RemoveActiveRadio(radio.entity or Entity(entIndex))
        end
    end
end

local function AddRadioCommand(name, desc, example)
    concommand.Add("radio_set_" .. name, function(ply, _, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            ply:ChatPrint("[rRADIO] Superadmin required!")
            return
        end
        if not args[1] or args[1] == "help" then
            local msg = string.format("[rRADIO] %s\nUsage: radio_set_%s <value>\nExample: radio_set_%s %s",
                desc, name, name, example)
            if IsValid(ply) then
                ply:PrintMessage(HUD_PRINTCONSOLE, msg)
                ply:ChatPrint("[rRADIO] Help printed to console!")
            else
                print(msg)
            end
            return
        end
        local value = tonumber(args[1])
        if not value then
            local msg = "[rRADIO] Invalid value! Use 'help' for usage."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)
            local msg = string.format("[rRADIO] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        end
    end)
end

local radioCommands = {
    max_volume_limit = { desc = "Maximum volume for all radios (0.0-1.0)", example = "0.8" },
    message_cooldown = { desc = "Cooldown for radio message animations (seconds)", example = "2" },
    boombox_volume = { desc = "Default volume for regular boomboxes", example = "0.7" },
    boombox_max_distance = { desc = "Maximum hearing distance for boomboxes", example = "1000" },
    boombox_min_distance = { desc = "Distance where boombox volume starts dropping", example = "500" },
    golden_boombox_volume = { desc = "Default volume for golden boomboxes", example = "1.0" },
    golden_boombox_max_distance = { desc = "Maximum hearing distance for golden boomboxes", example = "350000" },
    golden_boombox_min_distance = { desc = "Distance where golden boombox volume starts dropping", example = "250000" },
    vehicle_volume = { desc = "Default volume for vehicle radios", example = "0.8" },
    vehicle_max_distance = { desc = "Maximum hearing distance for vehicle radios", example = "800" },
    vehicle_min_distance = { desc = "Distance where vehicle radio volume starts dropping", example = "500" }
}

for name, info in pairs(radioCommands) do
    AddRadioCommand(name, info.desc, info.example)
end

concommand.Add("radio_help", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRADIO] Superadmin required!")
        return
    end
    local function printMsg(msg)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end
    printMsg("\n=== Radio Configuration Commands ===\n")
    printMsg("General Commands:")
    printMsg("  radio_help - Shows this help")
    printMsg("  radio_reload_config - Reloads radio config\n")
    printMsg("Configuration Commands:")
    for name, info in pairs(radioCommands) do
        printMsg(string.format("  radio_set_%s <value>", name))
        printMsg(string.format("    Description: %s", info.desc))
        printMsg(string.format("    Example: radio_set_%s %s\n", name, info.example))
    end
    printMsg("Current Values:")
    for name, _ in pairs(radioCommands) do
        local cvar = GetConVar("radio_" .. name)
        if cvar then printMsg(string.format("  %s: %.2f", name, cvar:GetFloat())) end
    end
    printMsg("\nNote: Superadmin privileges required.")
    if IsValid(ply) then ply:ChatPrint("[rRADIO] Help printed to console!") end
end)

net.Receive("PlayCarRadioStation", function(_, ply)
    if not IsValid(ply) then return end
    local now = CurTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("[rRADIO] System busy, try again shortly.")
        return
    end
    lastGlobalAction = now
    if now - (PlayerCooldowns[ply] or 0) < STATION_CHANGE_COOLDOWN then
        ply:ChatPrint("[rRADIO] Changing stations too fast.")
        return
    end
    PlayerCooldowns[ply] = now
    local entity = GetVehicleEntity(net.ReadEntity())
    local station = net.ReadString()
    local url = net.ReadString()
    local volume = net.ReadFloat()
    if not IsValid(entity) or not station or not url or not isnumber(volume) then
        ply:ChatPrint("[rRADIO] Invalid radio data.")
        return
    end
    if hook.Run("rRadio.PrePlayStation", ply, entity, station, url, volume) == false then return end
    if not rRadio.utils.canUseRadio(entity) then
        ply:ChatPrint("[rRADIO] This seat cannot use the radio.")
        return
    end
    if table.Count(ActiveRadios) >= MAX_ACTIVE_RADIOS then ClearOldestActiveRadio() end
    if CountPlayerRadios(ply) >= PLAYER_RADIO_LIMIT then
        ply:ChatPrint("[rRADIO] Max active radios reached.")
        return
    end
    local entIndex = entity:EntIndex()
    if rRadio.utils.IsBoombox(entity) and not rRadio.utils.canInteractWithBoombox(ply, entity) then
        ply:ChatPrint("[rRADIO] No permission to control this boombox.")
        return
    end
    if ActiveRadios[entIndex] then
        BroadcastStop(entity)
        RemoveActiveRadio(entity)
    end
    SetEntityVolume(entity, volume)
    AddActiveRadio(entity, station, url, volume)
    BroadcastPlay(entity, station, url, volume)
    if rRadio.utils.IsBoombox(entity) then
        rRadio.utils.setRadioStatus(entity, "tuning", station)
        timer.Create("StationUpdate_" .. entIndex, 2, 1, function()
            if IsValid(entity) then rRadio.utils.setRadioStatus(entity, "playing", station) end
        end)
    end
    if entity.IsPermanent and SavePermanentBoombox then SavePermanentBoombox(entity) end
    hook.Run("rRadio.PostPlayStation", ply, entity, station, url, volume)
end)

net.Receive("StopCarRadioStation", function(_, ply)
    local entity = GetVehicleEntity(net.ReadEntity())
    if not IsValid(entity) or not IsValid(ply) then return end
    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end
    if rRadio.utils.IsBoombox(entity) then
        if not rRadio.utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("[rRADIO] No permission to control this boombox.")
            return
        end
        rRadio.utils.setRadioStatus(entity, "stopped")
        RemoveActiveRadio(entity)
        BroadcastStop(entity)
        if entity.IsPermanent and SavePermanentBoombox then
            timer.Simple(2, function()
                if IsValid(entity) then SavePermanentBoombox(entity) end
            end)
        end
    elseif entity:IsVehicle() then
        if rRadio.utils.isSitAnywhereSeat(entity) then return end
        local isInVehicle = entity:GetDriver() == ply
        for _, seat in ipairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == entity and seat:GetDriver() == ply then
                isInVehicle = true
                break
            end
        end
        if not isInVehicle then return end
        RemoveActiveRadio(entity)
        BroadcastStop(entity)
    end
    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("UpdateRadioVolume", function(_, ply)
    local entity = GetVehicleEntity(net.ReadEntity())
    local volume = net.ReadFloat()
    if not IsValid(entity) or not IsValid(ply) or not isnumber(volume) then return end
    local entIndex = entity:EntIndex()
    VolumeUpdateQueue[entIndex] = VolumeUpdateQueue[entIndex] or { lastUpdate = 0 }
    local queue = VolumeUpdateQueue[entIndex]
    queue.pending = queue.pending or {}
    queue.pending.volume = volume
    queue.pending.ply = ply
    local now = CurTime()
    if now - queue.lastUpdate >= VOLUME_UPDATE_DEBOUNCE then
        ProcessVolumeUpdate(entity, volume, ply)
        queue.lastUpdate = now
        queue.pending = nil
    elseif not timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE, 1, function()
            if queue.pending and IsValid(queue.pending.ply) and IsValid(entity) then
                ProcessVolumeUpdate(entity, queue.pending.volume, queue.pending.ply)
                queue.lastUpdate = CurTime()
                queue.pending = nil
            end
        end)
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        for entIndex, radio in pairs(ActiveRadios) do
            if IsValid(radio.entity) then
                net.Start("PlayCarRadioStation")
                net.WriteEntity(radio.entity)
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
                net.Send(ply)
            end
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    if not IsValid(ply) or ply:GetInfoNum("rammel_rradio_enabled", 1) ~= 1 then return end
    if rRadio.utils.isSitAnywhereSeat(vehicle) then return end
    local vehicle = GetVehicleEntity(vehicle)
    if not IsValid(vehicle) then return end
    if rRadio.config.DriverPlayOnly and vehicle:GetDriver() ~= ply then return end
    net.Start("CarRadioMessage")
    net.WriteEntity(vehicle)
    net.WriteBool(vehicle:GetDriver() == ply)
    net.Send(ply)
end)

hook.Add("CanTool", "rRadio.AllowBoomboxToolgun", function(ply, tr)
    local entity = tr.Entity
    if IsValid(entity) and rRadio.utils.IsBoombox(entity) then
        return rRadio.utils.canInteractWithBoombox(ply, entity)
    end
end)

hook.Add("PhysgunPickup", "rRadio.AllowBoomboxPhysgun", function(ply, entity)
    if IsValid(entity) and rRadio.utils.IsBoombox(entity) then
        return rRadio.utils.canInteractWithBoombox(ply, entity)
    end
end)

hook.Add("InitPostEntity", "rRadio.InitializePostEntity", function()
    if DarkRP and DarkRP.getPhrase then
        hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, _, entity)
            if IsValid(entity) and rRadio.utils.IsBoombox(entity) then
                if entity.CPPISetOwner then entity:CPPISetOwner(ply) end
                entity:SetNWEntity("Owner", ply)
            end
        end)
    end
    timer.Simple(0.5, function()
        if LoadPermanentBoomboxes then LoadPermanentBoomboxes() end
    end)
    _G.AddActiveRadio = AddActiveRadio
end)

timer.Create("CleanupInactiveRadios", CLEANUP_INTERVAL, 0, CleanupInactiveRadios)

hook.Add("OnEntityCreated", "rRadio.InitializeRadio", function(entity)
    timer.Simple(0, function()
        if not IsValid(entity) then return end
        if rRadio.utils.IsBoombox(entity) or rRadio.utils.GetVehicle(entity) then
            SetEntityVolume(entity, GetDefaultVolume(entity))
        end
        if rRadio.utils.GetVehicle(entity) then
            entity:SetNWBool("IsSitAnywhereSeat", rRadio.utils.isSitAnywhereSeat(entity))
        end
    end)
end)

hook.Add("EntityRemoved", "rRadio.CleanupEntityRemoved", function(entity)
    if IsValid(entity) then RemoveActiveRadio(entity) end
end)

hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    PlayerCooldowns[ply] = nil
    for entIndex, queue in pairs(VolumeUpdateQueue) do
        if queue.pending and queue.pending.ply == ply then
            queue.pending = nil
            timer.Remove("VolumeUpdate_" .. entIndex)
        end
    end
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRADIO] Superadmin required!")
        return
    end
    game.ReloadConVars()
    local msg = "[rRADIO] Configuration reloaded!"
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
