util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")
local MAX_ACTIVE_RADIOS = 100
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1
local DEBOUNCE_TIME = 10
local CLEANUP_PLAYER_THRESHOLD = 10
local CLEANUP_RADIO_THRESHOLD = 50
local RATE_LIMIT = {
    MESSAGES_PER_SECOND = 5,
    BURST_ALLOWANCE = 10,
    COOLDOWN_TIME = 1
}

local IsValid = IsValid
local CurTime = CurTime
local timer = timer
local net = net
local table = table
local math = math
local string = string
local TimerManager = {
    volume = {},
    station = {},
    retry = {},
    cleanup = function(entIndex)
        if not entIndex then return end
        local timerNames = {"VolumeUpdate_" .. entIndex, "StationUpdate_" .. entIndex, "NetworkQueue_" .. entIndex}
        for _, name in ipairs(timerNames) do
            if timer.Exists(name) then timer.Remove(name) end
        end

        TimerManager.volume[entIndex] = nil
        TimerManager.station[entIndex] = nil
        TimerManager.retry[entIndex] = nil
    end
}

local function SafeCleanupTimers(entity)
    if IsValid(entity) and TimerManager and TimerManager.cleanup then TimerManager.cleanup(entity:EntIndex()) end
end

local RadioManager = {
    active = {},
    count = 0,
    add = function(self, entity, stationName, url, volume)
        if not IsValid(entity) then return end
        if self.count >= MAX_ACTIVE_RADIOS then self:removeOldest() end
        local entIndex = entity:EntIndex()
        self.active[entIndex] = {
            entity = entity,
            stationName = stationName,
            url = url,
            volume = volume,
            timestamp = CurTime()
        }

        self.count = self.count + 1
    end,
    remove = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        if self.active[entIndex] then
            self.active[entIndex] = nil
            self.count = self.count - 1
        end
    end,
    removeOldest = function(self)
        local oldestTime = math.huge
        local oldestIndex = nil
        for entIndex, radio in pairs(self.active) do
            if radio.timestamp < oldestTime then
                oldestTime = radio.timestamp
                oldestIndex = entIndex
            end
        end

        if oldestIndex then self:remove(Entity(oldestIndex)) end
    end
}

local PlayerRetryAttempts = {}
local PlayerCooldowns = {}
BoomboxStatuses = BoomboxStatuses or {}
local SavePermanentBoombox, LoadPermanentBoomboxes
include("radio/server/sv_permanent.lua")
local utils = include("radio/shared/sh_utils.lua")
SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes
local LatestVolumeUpdates = {}
local VolumeUpdateTimers = {}
local volumeUpdateQueue = {}
local IsValid = IsValid
local CurTime = CurTime
local timer = timer
local net = net
local table = table
local string = string
local NetworkRateLimiter = {
    players = {},
    check = function(self, ply)
        local currentTime = CurTime()
        local data = self.players[ply] or {
            messages = 0,
            lastReset = currentTime,
            burstAllowance = RATE_LIMIT.BURST_ALLOWANCE
        }

        if currentTime - data.lastReset >= RATE_LIMIT.COOLDOWN_TIME then
            data.messages = 0
            data.lastReset = currentTime
            data.burstAllowance = RATE_LIMIT.BURST_ALLOWANCE
        end

        if data.messages >= RATE_LIMIT.MESSAGES_PER_SECOND then
            if data.burstAllowance <= 0 then return false end
            data.burstAllowance = data.burstAllowance - 1
        end

        data.messages = data.messages + 1
        self.players[ply] = data
        return true
    end,
    clear = function(self, ply) self.players[ply] = nil end
}

local Validator = {
    volume = function(vol) return type(vol) == "number" and vol >= 0 and vol <= 1 end,
    url = function(url) return type(url) == "string" and #url <= 500 end,
    stationName = function(name)
        if type(name) ~= "string" then return false end
        return #name <= 100 and #name > 0
    end
}

local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then return end
    if RadioManager.count >= MAX_ACTIVE_RADIOS then RadioManager:removeOldest() end
    RadioManager:add(entity, stationName, url, volume)
end

local function RemoveActiveRadio(entity)
    RadioManager:remove(entity)
end

local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then return end
    if not PlayerRetryAttempts[ply] then PlayerRetryAttempts[ply] = 1 end
    local attempt = PlayerRetryAttempts[ply]
    if next(RadioManager.active) == nil then
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

    for _, radio in pairs(RadioManager.active) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.stationName)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
            net.Send(ply)
        end
    end

    PlayerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply) timer.Simple(3, function() if IsValid(ply) then SendActiveRadiosToPlayer(ply) end end) end)
hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    if vehicle.playerdynseat then
        vehicle:SetNWBool("IsSitAnywhereSeat", true)
    else
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle) if IsValid(vehicle) then vehicle:SetNWBool("IsSitAnywhereSeat", false) end end)
hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    if vehicle.playerdynseat then return end
    net.Start("CarRadioMessage")
    net.Send(ply)
end)

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

local function GetEntityOwner(entity)
    if not IsValid(entity) then return nil end
    if entity.CPPIGetOwner then return entity:CPPIGetOwner() end
    local nwOwner = entity:GetNWEntity("Owner")
    if IsValid(nwOwner) then return nwOwner end
    return nil
end

local StationQueue = {
    queues = {},
    processing = {},
    add = function(self, entity, data)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        self.queues[entIndex] = self.queues[entIndex] or {}
        table.insert(self.queues[entIndex], {
            stationName = data.stationName,
            url = data.url,
            volume = data.volume,
            player = data.player,
            timestamp = CurTime()
        })

        self:process(entity)
    end,
    process = function(self, entity)
        local entIndex = entity:EntIndex()
        if self.processing[entIndex] then return end
        local queue = self.queues[entIndex]
        if not queue or #queue == 0 then return end
        self.processing[entIndex] = true
        local function processNext()
            local request = table.remove(queue, 1)
            if request and IsValid(entity) then
                if RadioManager.active[entIndex] then
                    net.Start("StopCarRadioStation")
                    net.WriteEntity(entity)
                    net.Broadcast()
                    RemoveActiveRadio(entity)
                end

                entity:SetNWString("StationName", request.stationName)
                entity:SetNWString("StationURL", request.url)
                entity:SetNWFloat("Volume", request.volume)
                entity:SetNWBool("IsPlaying", true)
                AddActiveRadio(entity, request.stationName, request.url, request.volume)
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(request.stationName)
                net.WriteString(request.url)
                net.WriteFloat(request.volume)
                net.Broadcast()
                if entity.IsPermanent and SavePermanentBoombox then timer.Simple(0.1, function() if IsValid(entity) then SavePermanentBoombox(entity) end end) end
            end

            self.processing[entIndex] = false
            if queue and #queue > 0 then self:process(entity) end
        end

        timer.Simple(0.1, processNext)
    end,
    clear = function(self, entity)
        if not IsValid(entity) then return end
        local entIndex = entity:EntIndex()
        self.queues[entIndex] = nil
        self.processing[entIndex] = nil
    end
}

net.Receive("PlayCarRadioStation", function(len, ply)
    if not NetworkRateLimiter:check(ply) then
        ply:ChatPrint("You are sending too many requests. Please wait a moment.")
        return
    end

    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()
    if not IsValid(entity) then return end
    if not Validator.stationName(stationName) or not Validator.url(stationURL) or not Validator.volume(volume) then
        ply:ChatPrint("Invalid station data provided.")
        return
    end

    StationQueue:add(entity, {
        stationName = stationName,
        url = stationURL,
        volume = volume,
        player = ply
    })
end)

net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    if not IsValid(entity) then return end
    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    if entityClass == "boombox" then
        if not utils.canInteractWithBoombox(ply, entity) then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        entity:SetNWString("StationName", "")
        entity:SetNWString("StationURL", "")
        entity:SetNWBool("IsPlaying", false)
        entity:SetNWString("Status", "stopped")
        RemoveActiveRadio(entity)
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
        if timer.Exists("StationUpdate_" .. entIndex) then timer.Remove("StationUpdate_" .. entIndex) end
        timer.Create("StationUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function() if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then SavePermanentBoombox(entity) end end)
    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity
        RemoveActiveRadio(radioEntity)
        net.Start("StopCarRadioStation")
        net.WriteEntity(radioEntity)
        net.Broadcast()
        net.Start("UpdateRadioStatus")
        net.WriteEntity(radioEntity)
        net.WriteString("")
        net.WriteBool(false)
        net.Broadcast()
    else
        return
    end
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    if not NetworkRateLimiter:check(ply) then
        ply:ChatPrint("You are sending too many volume requests. Please wait a moment.")
        return
    end

    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)
    local volume = net.ReadFloat()
    if not IsValid(entity) then return end
    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local radioEntity = lvsVehicle or entity
    local entIndex = radioEntity:EntIndex()
    if (entityClass == "boombox") and not utils.canInteractWithBoombox(ply, radioEntity) then
        ply:ChatPrint("You do not have permission to control this boombox's volume.")
        return
    end

    if entity:IsVehicle() and entity:GetDriver() ~= ply then
        ply:ChatPrint("You must be in the vehicle to control its radio volume.")
        return
    end

    if not Validator.volume(volume) then
        ply:ChatPrint("Invalid volume level.")
        return
    end

    volumeUpdateQueue[entIndex] = {
        entity = radioEntity,
        volume = volume,
        player = ply,
        entityClass = entityClass
    }

    if not timer.Exists("VolumeUpdate_" .. entIndex) then
        timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
            local updateData = volumeUpdateQueue[entIndex]
            if updateData then
                local updateEntity = updateData.entity
                local updateVolume = updateData.volume
                if IsValid(updateEntity) then
                    updateEntity:SetNWFloat("Volume", updateVolume)
                    net.Start("UpdateRadioVolume")
                    net.WriteEntity(updateEntity)
                    net.WriteFloat(updateVolume)
                    net.Broadcast()
                    if RadioManager.active[entIndex] then RadioManager.active[entIndex].volume = updateVolume end
                    if updateEntity.IsPermanent and SavePermanentBoombox and (updateData.entityClass == "boombox") then SavePermanentBoombox(updateEntity) end
                end

                volumeUpdateQueue[entIndex] = nil
            end
        end)
    end
end)

hook.Add("EntityRemoved", "CleanupVolumeUpdateTimers", function(entity)
    local entIndex = entity:EntIndex()
    if timer.Exists("VolumeUpdate_" .. entIndex) then timer.Remove("VolumeUpdate_" .. entIndex) end
    volumeUpdateQueue[entIndex] = nil
end)

hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity
    if RadioManager.active[mainEntity:EntIndex()] then RemoveActiveRadio(mainEntity) end
end)

local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

local function AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ent.CPPISetOwner then ent:CPPISetOwner(ply) end
    ent:SetNWEntity("Owner", ply)
end

hook.Add("InitPostEntity", "SetupBoomboxHooks", function() timer.Simple(1, function() if IsDarkRP() then hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price) if IsValid(ent) and (ent:GetClass() == "boombox") then AssignOwner(ply, ent) end end) end end) end)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox") then return utils.canInteractWithBoombox(ply, ent) end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent) if IsValid(ent) and (ent:GetClass() == "boombox") then return utils.canInteractWithBoombox(ply, ent) end end)
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function() timer.Simple(0.5, function() if LoadPermanentBoomboxes then LoadPermanentBoomboxes() end end) end)
hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity) SafeCleanupTimers(entity) end)
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

hook.Add("EntityRemoved", "CleanupRadioTimers", function(entity) if IsValid(entity) then TimerManager.cleanup(entity:EntIndex()) end end)
_G.AddActiveRadio = AddActiveRadio
hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function() if not _G.AddActiveRadio then _G.AddActiveRadio = AddActiveRadio end end)
local function CleanupInactiveRadios()
    local playerCount = #player.GetAll()
    if playerCount <= CLEANUP_PLAYER_THRESHOLD and RadioManager.count <= CLEANUP_RADIO_THRESHOLD then return end
    local currentTime = CurTime()
    for entIndex, radio in pairs(RadioManager.active) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then RemoveActiveRadio(Entity(entIndex)) end
    end
end

local function GetCleanupInterval()
    local playerCount = #player.GetAll()
    return playerCount > CLEANUP_PLAYER_THRESHOLD and 300 or 600
end

timer.Create("CleanupInactiveRadios", GetCleanupInterval(), 0, function()
    CleanupInactiveRadios()
    timer.Adjust("CleanupInactiveRadios", GetCleanupInterval())
end)

local PermissionCache = {
    cache = {},
    timeout = 5,
    check = function(self, ply, entity)
        local entIndex = entity:EntIndex()
        local steamID = ply:SteamID()
        local key = steamID .. "_" .. entIndex
        local cached = self.cache[key]
        if cached and cached.time > CurTime() - self.timeout then return cached.result end
        local result = utils.canInteractWithBoombox(ply, entity)
        self.cache[key] = {
            result = result,
            time = CurTime()
        }
        return result
    end,
    clear = function(self, ply)
        local steamID = ply:SteamID()
        for key in pairs(self.cache) do
            if key:StartWith(steamID) then self.cache[key] = nil end
        end
    end
}

hook.Add("PlayerDisconnected", "ClearPermissionCache", function(ply) PermissionCache:clear(ply) end)
local RadioState = {
    STOPPED = "stopped",
    TUNING = "tuning",
    PLAYING = "playing",
    ERROR = "error",
    BUFFERING = "buffering"
}

local RadioStateMachine = {
    states = {},
    transition = function(self, entity, newState, data)
        if not IsValid(entity) then return false end
        local entIndex = entity:EntIndex()
        local currentState = self.states[entIndex] or RadioState.STOPPED
        local isValidTransition = self:validateTransition(currentState, newState)
        if not isValidTransition then return false end
        self.states[entIndex] = newState
        entity:SetNWString("Status", newState)
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(data and data.stationName or "")
        net.WriteBool(newState == RadioState.PLAYING)
        net.WriteString(newState)
        net.Broadcast()
        return true
    end,
    validateTransition = function(self, currentState, newState)
        local validTransitions = {
            [RadioState.STOPPED] = {
                [RadioState.TUNING] = true
            },
            [RadioState.TUNING] = {
                [RadioState.PLAYING] = true,
                [RadioState.ERROR] = true
            },
            [RadioState.PLAYING] = {
                [RadioState.STOPPED] = true,
                [RadioState.BUFFERING] = true,
                [RadioState.ERROR] = true
            },
            [RadioState.BUFFERING] = {
                [RadioState.PLAYING] = true,
                [RadioState.ERROR] = true
            },
            [RadioState.ERROR] = {
                [RadioState.STOPPED] = true,
                [RadioState.TUNING] = true
            }
        }
        return validTransitions[currentState] and validTransitions[currentState][newState]
    end,
    getCurrentState = function(self, entity) return self.states[entity:EntIndex()] or RadioState.STOPPED end,
    cleanup = function(self, entity) self.states[entity:EntIndex()] = nil end
}

local function CleanupDisconnectedPlayer(ply)
    NetworkRateLimiter:clear(ply)
    PermissionCache:clear(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    local steamID = ply:SteamID()
    for entIndex, radio in pairs(RadioManager.active) do
        if IsValid(radio.entity) then
            local owner = GetEntityOwner(radio.entity)
            if IsValid(owner) and owner:SteamID() == steamID then
                RemoveActiveRadio(radio.entity)
                StationQueue:clear(radio.entity)
                RadioStateMachine:cleanup(radio.entity)
            end
        end
    end
end

hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", CleanupDisconnectedPlayer)
local EntityPool = {
    pool = {},
    maxPoolSize = 50,
    initialize = function(self) self.pool = {} end,
    acquire = function(self, entityType)
        local pooled = self.pool[entityType] and table.remove(self.pool[entityType])
        if pooled and IsValid(pooled) then
            pooled:Spawn()
            return pooled
        end

        local ent = ents.Create(entityType)
        if IsValid(ent) then ent:Spawn() end
        return ent
    end,
    release = function(self, entity)
        if not IsValid(entity) then return end
        local entityType = entity:GetClass()
        self.pool[entityType] = self.pool[entityType] or {}
        if #self.pool[entityType] < self.maxPoolSize then
            entity:SetNoDraw(true)
            entity:SetNotSolid(true)
            table.insert(self.pool[entityType], entity)
        else
            entity:Remove()
        end
    end,
    cleanup = function(self)
        for _, typePool in pairs(self.pool) do
            for _, entity in ipairs(typePool) do
                if IsValid(entity) then entity:Remove() end
            end
        end

        self.pool = {}
    end
}

hook.Add("InitPostEntity", "InitializeEntityPool", function() EntityPool:initialize() end)
hook.Add("ShutDown", "CleanupEntityPool", function() EntityPool:cleanup() end)
hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity) SafeCleanupTimers(entity) end)
_G.StationQueue = StationQueue
_G.RadioManager = RadioManager