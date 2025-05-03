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

local ActiveRadios        = ActiveRadios or {}
local PlayerRetryAttempts = PlayerRetryAttempts or {}
local PlayerCooldowns     = PlayerCooldowns or {}
local volumeUpdateQueue   = volumeUpdateQueue or {}
local EntityVolumes       = EntityVolumes or {}
BoomboxStatuses     = BoomboxStatuses or {}

local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0
local InactiveTimeout       = rRadio.config.InactiveTimeout
local CleanupInterval       = rRadio.config.CleanupInterval
local VolumeUpdateDebounce  = rRadio.config.VolumeUpdateDebounce
local StationUpdateDebounce = rRadio.config.StationUpdateDebounce

local function BroadcastStop(ent)
    net.Start("StopCarRadioStation")
    net.WriteEntity(ent)
    net.Broadcast()
end

local function ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = GetConVar("rammel_rradio_sv_vehicle_volume_limit"):GetFloat()
    return math.Clamp(volume, 0, maxVolume)
end

local function GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return GetConVar("rammel_rradio_sv_gold_default_volume"):GetFloat()
    elseif entityClass == "boombox" then
        return GetConVar("rammel_rradio_sv_boombox_default_volume"):GetFloat()
    else
        return GetConVar("rammel_rradio_sv_vehicle_default_volume"):GetFloat()
    end
end

local function InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    if not EntityVolumes[entIndex] then
        EntityVolumes[entIndex] = GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", EntityVolumes[entIndex])
    end
end

local function AddActiveRadio(entity, stationName, url, volume)
    local entIndex = entity:EntIndex()
    EntityVolumes[entIndex] = EntityVolumes[entIndex] or volume or GetDefaultVolume(entity)
    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", EntityVolumes[entIndex])
    ActiveRadios[entIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = EntityVolumes[entIndex],
        timestamp = SysTime()
    }
    if rRadio.utils.IsBoombox(entity) then
        BoomboxStatuses[entIndex] = {
            stationStatus = "playing",
            stationName = stationName,
            url = url
        }
    end
end

local function RemoveActiveRadio(entity)
    local idx = entity:EntIndex()
    rRadio.DevPrint("[rRADIO] Removing ActiveRadio entry idx="..idx)
    ActiveRadios[idx] = nil
end

local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        return
    end
    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end
    local attempt = PlayerRetryAttempts[ply]
    if next(ActiveRadios) == nil then
        if attempt >= 3 then
            PlayerRetryAttempts[ply] = nil
            return
        end
        PlayerRetryAttempts[ply] = attempt + 1
        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                PlayerRetryAttempts[ply] = nil
            end
        end)
        return
    end
    for entIndex, radio in pairs(ActiveRadios) do
        local entity = Entity(entIndex)
        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(radio.stationName)
        net.WriteString(radio.url)
        net.WriteFloat(radio.volume)
        net.Send(ply)
    end
    PlayerRetryAttempts[ply] = nil
end

local function UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end
    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh then return end
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    return isSitAnywhere
end

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

local function GetEntityOwner(entity)
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

local function ClearOldestActiveRadio()
    local oldestTime, oldestIdx = math.huge, nil
    for entIdx, data in pairs(ActiveRadios) do
        local ent = data.entity or Entity(entIdx)
        if not IsValid(ent) then
            rRadio.DevPrint("[rRADIO] Purging invalid ActiveRadio entry idx="..entIdx)
            ActiveRadios[entIdx] = nil
        elseif data.timestamp then
            if data.timestamp < oldestTime then
                oldestTime, oldestIdx = data.timestamp, entIdx
            end
        else
            rRadio.DevPrint("[rRADIO] Entry idx="..entIdx.." missing timestamp, treating as oldest")
            oldestTime, oldestIdx = 0, entIdx
        end
    end
    if oldestIdx then
        rRadio.DevPrint("[rRADIO] Clearing oldest ActiveRadio idx="..oldestIdx.." timestamp="..oldestTime)
        local oldEnt = Entity(oldestIdx)
        if IsValid(oldEnt) then BroadcastStop(oldEnt) end
        RemoveActiveRadio(oldEnt)
    end
end

local function CountPlayerRadios(ply)
    local cnt = 0
    for _, data in pairs(ActiveRadios) do
        if IsValid(data.entity) and rRadio.utils.getOwner(data.entity) == ply then
            cnt = cnt + 1
        end
    end
    return cnt
end

local function BroadcastPlay(ent, st, url, vol)
    net.Start("PlayCarRadioStation") net.WriteEntity(ent)
    net.WriteString(st) net.WriteString(url) net.WriteFloat(vol)
    net.Broadcast()
end

local function ProcessVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) then return end
    entity = rRadio.utils.GetVehicle(entity) or entity
    local entIndex = entity:EntIndex()
    if rRadio.utils.IsBoombox(entity) then
        if not rRadio.utils.canInteractWithBoombox(ply, entity) then
            return
        end
    elseif rRadio.utils.GetVehicle(entity) then
        local vehicle = rRadio.utils.GetVehicle(entity)
        if rRadio.utils.isSitAnywhereSeat(vehicle) then return end
        local isInVehicle = false
        for _, seat in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == vehicle and seat:GetDriver() == ply then
                isInVehicle = true
                break
            end
        end
        if not isInVehicle and vehicle:GetDriver() ~= ply then
            return
        end
    else
        return
    end
    volume = ClampVolume(volume)
    EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)
    net.Start("UpdateRadioVolume")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.SendPAS(entity:GetPos())
end

local function CleanupInactiveRadios()
    local currentTime = SysTime()
    for entIndex, radio in pairs(ActiveRadios) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > InactiveTimeout() then
            RemoveActiveRadio(Entity(entIndex))
        end
    end
end

local function AddRadioCommand(name, helpText)
    concommand.Add("radio_set_" .. name, function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local value = tonumber(args[1])
        if not value then
            if IsValid(ply) then
                ply:ChatPrint("[rRADIO] Invalid value provided!")
            else
                print("[rRADIO] Invalid value provided!")
            end
            return
        end
        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)
            local message = string.format("[rRADIO] %s set to %.2f", name:gsub("_", " "), value)
            if IsValid(ply) then
                ply:ChatPrint(message)
            else
                print(message)
            end
        end
    end)
end

local commands = {
    "max_volume_limit",
    "message_cooldown",
    "boombox_volume",
    "boombox_max_distance",
    "boombox_min_distance",
    "golden_boombox_volume",
    "golden_boombox_max_distance",
    "golden_boombox_min_distance",
    "vehicle_volume",
    "vehicle_max_distance",
    "vehicle_min_distance"
}

for cmd, _ in pairs(commands) do
    AddRadioCommand(cmd)
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

concommand.Add("radio_help", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRADIO] You need to be a superadmin to use radio commands!")
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
        ply:ChatPrint("[rRADIO] Help information printed to console!")
    end
end)

local function AddRadioCommand(name)
    local cmdInfo = radioCommands[name]
    if not cmdInfo then return end

    concommand.Add("radio_set_" .. name, function(ply, cmd, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            ply:ChatPrint("[rRADIO] You need to be a superadmin to use this command!")
            return
        end

        if not args[1] or args[1] == "help" then
            local msg = string.format("[rRADIO] %s\nUsage: %s <value>\nExample: %s %s",
                cmdInfo.desc, cmd, cmd, cmdInfo.example)
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
            if IsValid(ply) then
                ply:ChatPrint("[rRADIO] Invalid value provided! Use 'help' for usage information.")
            else
                print("[rRADIO] Invalid value provided! Use 'help' for usage information.")
            end
            return
        end

        local cvar = GetConVar("radio_" .. name)
        if cvar then
            cvar:SetFloat(value)
            ply:ChatPrint(string.format("[rRADIO] %s set to %.2f", name, value))
        end
    end)
end

for cmd, _ in pairs(radioCommands) do
    AddRadioCommand(cmd)
end

local RadioTimers = {
    "VolumeUpdate_",
    "StationUpdate_",
}

local RadioDataTables = {
    volumeUpdateQueue   = true,
}

local function CleanupEntityData(entIndex)
    for _, timerPrefix in ipairs(RadioTimers) do
        local timerName = timerPrefix .. entIndex
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end

    for tableName in pairs(RadioDataTables) do
        if _G[tableName] and _G[tableName][entIndex] then
            _G[tableName][entIndex] = nil
        end
    end
    EntityVolumes[entIndex] = nil
end

local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return
    end
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end
    ent:SetNWEntity("Owner", ply)
end

net.Receive("PlayCarRadioStation", function(len, ply)
    rRadio.DevPrint("[rRADIO] Server got PlayCarRadioStation from: " .. ply:Nick())
    for entIdx, data in pairs(ActiveRadios) do
        local ent = data.entity or Entity(entIdx)
        if not IsValid(ent) then
            rRadio.DevPrint("[rRADIO] Purging invalid ActiveRadio entry idx="..entIdx)
            ActiveRadios[entIdx] = nil
        end
    end

    local now = SysTime()
    if now - lastGlobalAction < GLOBAL_COOLDOWN then
        ply:ChatPrint("The radio system is busy. Please try again in a moment.")
        return
    end
    lastGlobalAction = now

    local ent       = GetVehicleEntity(net.ReadEntity())
    local station   = net.ReadString()
    local stationURL= net.ReadString()
    local volume    = net.ReadFloat()

    if not IsValid(ent) then return end

    if hook.Run("rRadio.PrePlayStation", ply, ent, station, stationURL, volume) == false then return end

    if not rRadio.utils.canUseRadio(ent) then
        ply:ChatPrint("[rRADIO] This seat cannot use the radio.")
        return
    end

    if now - (PlayerCooldowns[ply] or 0) < 0.25 then
        ply:ChatPrint("You are changing stations too quickly.")
        return
    end
    PlayerCooldowns[ply] = now

    if table.Count(ActiveRadios) >= 100 then
        ClearOldestActiveRadio()
    end

    if CountPlayerRadios(ply) >= 5 then
        ply:ChatPrint("You have reached your maximum number of active radios.")
        return
    end

    local idx = ent:EntIndex()

    if rRadio.utils.IsBoombox(ent) then
        rRadio.DevPrint("Checking permissions for PlayCarRadioStation")
        if not rRadio.utils.canInteractWithBoombox(ply, ent) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        rRadio.utils.setRadioStatus(ent, "tuning", station)
        BoomboxStatuses[idx] = BoomboxStatuses[idx] or {}
        BoomboxStatuses[idx].url = stationURL
    end

    if ActiveRadios[idx] then
        BroadcastStop(ent)
        RemoveActiveRadio(ent)
    end

    AddActiveRadio(ent, station, stationURL, volume)
    rRadio.DevPrint("[rRADIO] ActiveRadios now contains:")

    BroadcastPlay(ent, station, stationURL, volume)

    if ent.IsPermanent and SavePermanentBoombox then
        SavePermanentBoombox(ent)
    end

    timer.Create("StationUpdate_" .. idx, 2, 1, function()
        if IsValid(ent) then
            rRadio.utils.setRadioStatus(ent, "playing", station)
        end
    end)

    hook.Run("rRadio.PostPlayStation", ply, ent, station, stationURL, volume)
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if hook.Run("rRadio.PreStopStation", ply, entity) == false then return end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if rRadio.utils.IsBoombox(entity) then
        rRadio.DevPrint("Checking permissions for StopCarRadioStation")

        if not rRadio.utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end
        rRadio.utils.setRadioStatus(entity, "stopped")
        RemoveActiveRadio(entity)
        BroadcastStop(entity)
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
        timer.Create("StationUpdate_" .. entIndex, StationUpdateDebounce(), 1, function()
            if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
                SavePermanentBoombox(entity)
            end
        end)
    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity
        RemoveActiveRadio(radioEntity)
        BroadcastStop(radioEntity)
        net.Start("UpdateRadioStatus")
        net.WriteEntity(radioEntity)
        net.WriteString("")
        net.WriteBool(false)
        net.WriteString("stopped")
        net.Broadcast()
    else
        return
    end

    hook.Run("rRadio.PostStopStation", ply, entity)
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()
    local entIndex = IsValid(entity) and entity:EntIndex() or nil
    if not entIndex then return end
    if not volumeUpdateQueue[entIndex] then
        volumeUpdateQueue[entIndex] = {
            lastUpdate = 0,
            pendingVolume = nil,
            pendingPlayer = nil
        }
    end
    local updateData = volumeUpdateQueue[entIndex]
    local currentTime = SysTime()
    if currentTime - updateData.lastUpdate >= VolumeUpdateDebounce() then
        ProcessVolumeUpdate(entity, volume, ply)
        updateData.lastUpdate = currentTime
        updateData.pendingVolume = nil
        updateData.pendingPlayer = nil
    else
        if not timer.Exists("VolumeUpdate_" .. entIndex) then
            timer.Create("VolumeUpdate_" .. entIndex, VolumeUpdateDebounce(), 1, function()
                if updateData.pendingVolume and IsValid(updateData.pendingPlayer) then
                    ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
                    updateData.lastUpdate = SysTime()
                    updateData.pendingVolume = nil
                    updateData.pendingPlayer = nil
                end
            end)
        end
    end
end)

hook.Add("PlayerInitialSpawn", "rRadio.SendActiveRadiosOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

hook.Add("PlayerEnteredVehicle", "rRadio.RadioVehicleHandling", function(ply, vehicle)
    rRadio.DevPrint("Player entered a vehicle")

    if not ply:GetInfoNum("rammel_rradio_enabled", 1) == 1 then return end

    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh then return end
    rRadio.DevPrint("Vehicle is valid")
    if rRadio.utils.isSitAnywhereSeat(vehicle) then return end
    rRadio.DevPrint("Vehicle is not a sit anywhere seat")

    if rRadio.config.DriverPlayOnly and veh:GetDriver() ~= ply then
        rRadio.DevPrint("Skipping CarRadioMessage: not driver")
        return
    end

    net.Start("CarRadioMessage")
    net.WriteEntity(vehicle)
    net.WriteBool(vehicle:GetDriver() == ply)
    net.Send(ply)

    rRadio.DevPrint("Queued car radio animation")
end)

hook.Add("CanTool", "rRadio.AllowBoomboxToolgun", function(ply, tr, tool)
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
            hook.Add("playerBoughtCustomEntity", "rRadio.AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and rRadio.utils.IsBoombox(ent) then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)

    timer.Simple(0.5, function()
        if _G.LoadPermanentBoomboxes then
            _G.LoadPermanentBoomboxes()
        end
    end)

    if not _G.AddActiveRadio then
        _G.AddActiveRadio = AddActiveRadio
    end
end)

timer.Create("CleanupInactiveRadios", CleanupInterval(), 0, CleanupInactiveRadios)

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
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Remove("VolumeUpdate_" .. entIndex)
    end

    volumeUpdateQueue[entIndex] = nil

    if timer.Exists("StationUpdate_" .. entIndex) then
        timer.Remove("StationUpdate_" .. entIndex)
    end

    if IsValid(entity) then
        CleanupEntityData(entity:EntIndex())
    end

    local mainEntity = entity:GetParent() or entity
    if ActiveRadios[mainEntity:EntIndex()] then
        RemoveActiveRadio(mainEntity)
    end
end)

hook.Add("PlayerDisconnected", "rRadio.CleanupPlayerDisconnected", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil

    for entIndex, updateData in pairs(volumeUpdateQueue) do
        if updateData.pendingPlayer == ply then
            CleanupEntityData(entIndex)
        end
    end

    rRadio.DevPrint("Volume update queue cleared for player: " .. ply:Nick())

    for tableName in pairs(RadioDataTables) do
        if _G[tableName] then
            for entIndex, data in pairs(_G[tableName]) do
                if data.ply == ply or data.pendingPlayer == ply then
                    CleanupEntityData(entIndex)
                end
            end
        end
    end

    rRadio.DevPrint("Entity data cleaned up for player: " .. ply:Nick())
end)

concommand.Add("radio_reload_config", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    game.ReloadConVars()
    if IsValid(ply) then
        ply:ChatPrint("[rRADIO] Configuration reloaded!")
    else
        print("[rRADIO] Configuration reloaded!")
    end
end)