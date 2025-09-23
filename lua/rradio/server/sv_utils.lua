local Radio = rRadio
local Status = Radio.status
Radio.sv = Radio.sv or {}
local Server = Radio.sv

local utils = {}
Server.utils = utils

local Config = Radio.config
local DevPrint = Radio.DevPrint
local SharedUtils = Radio.utils

-- Validation functions
function utils.IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

function utils.CanControlRadio(entity, player)
    if not IsValid(entity) or not IsValid(player) then return false end

    if SharedUtils.IsBoombox(entity) then
        return SharedUtils.CanInteractWithBoombox(player, entity)
    end

    local vehicle = SharedUtils.GetVehicle(entity)
    if IsValid(vehicle) then
        if not Config.DriverPlayOnly or vehicle:GetDriver() == player then
            return true
        end
    end

    return false
end

function utils.GetVehicleEntity(entity)
    if not IsValid(entity) then return entity end
    if not entity:IsVehicle() then return entity end
    
    local parent = entity:GetParent()
    return IsValid(parent) and parent or entity
end

function utils.UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end
    
    local veh = SharedUtils.GetVehicle(vehicle)
    if not veh then return end
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    return isSitAnywhere
end

-- Utility functions
function utils.AssignOwner(player, entity)
    if not IsValid(player) or not IsValid(entity) then return end
    
    if entity.CPPISetOwner then
        entity:CPPISetOwner(player)
    end
    entity:SetNWEntity("Owner", player)
end

function utils.CountPlayerRadios(player)
    local playerRadioTable = Server.PlayerRadios[player]
    local count = 0
    if playerRadioTable then 
        for _ in pairs(playerRadioTable) do 
            count = count + 1 
        end 
    end
    return count
end

function utils.CountActiveRadios()
    return Server.ActiveRadiosCount or 0
end

function utils.ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = Config.MaxVolume
    return math.Clamp(volume, 0, maxVolume)
end

function utils.GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    
    local class = entity:GetClass()
    if class == "rammel_boombox_gold" then
        return Config.GoldenBoombox.Volume
    elseif class == "rammel_boombox" then
        return Config.Boombox.Volume
    else
        return Config.VehicleRadio.Volume
    end
end

-- Broadcasting functions
function utils.BroadcastPlay(entity, stationName, url, volume)
    net.Start("rRadio.PlayStation") 
    net.WriteEntity(entity)
    net.WriteString(stationName) 
    net.WriteString(url) 
    net.WriteFloat(volume)
    net.Broadcast()
end

function utils.BroadcastStop(entity)
    net.Start("rRadio.StopStation")
    net.WriteEntity(entity)
    net.Broadcast()
end

local function SendRadioToPlayer(player, entityIndex, radioData)
    local entity = Entity(entityIndex)
    DevPrint("[sv-permanent] Sending radio info for entity " .. entityIndex .. " to " .. player:Nick())
    DevPrint("[sv-permanent] Radio station name: " .. radioData.stationName .. " URL: " .. radioData.url)

    net.Start("rRadio.PlayStation")
    net.WriteEntity(entity)
    net.WriteString(radioData.stationName)
    net.WriteString(radioData.url)
    net.WriteFloat(radioData.volume)
    net.Send(player)
end

local function HandleRetryLogic(player, retryFunction)
    if not Server.PlayerRetryAttempts[player] then
        Server.PlayerRetryAttempts[player] = 1
        DevPrint("[sv-permanent] SendActiveRadiosToPlayer: First attempt for " .. player:Nick())
    end

    local attempt = Server.PlayerRetryAttempts[player]
    
    if attempt >= 3 then
        DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Max attempts reached for " .. player:Nick())
        Server.PlayerRetryAttempts[player] = nil
        return false
    end
    
    Server.PlayerRetryAttempts[player] = attempt + 1
    timer.Simple(5, function()
        if IsValid(player) then
            DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Retrying for " .. player:Nick())
            retryFunction(player)
        else
            DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Player no longer valid during retry")
            Server.PlayerRetryAttempts[player] = nil
        end
    end)
    return true
end

function utils.SendActiveRadiosToPlayer(player)
    if not IsValid(player) then
        DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Invalid player")
        return
    end

    local activeRadios = Server.ActiveRadios
    if next(activeRadios) == nil then
        DevPrint("[sv-permanent] SendActiveRadiosToPlayer: No active radios found, attempt " .. (Server.PlayerRetryAttempts[player] or 1))
        HandleRetryLogic(player, utils.SendActiveRadiosToPlayer)
        return
    end

    DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Sending " .. (utils.CountActiveRadios() or 0) .. " active radios to " .. player:Nick())

    for entityIndex, radioData in pairs(activeRadios) do
        SendRadioToPlayer(player, entityIndex, radioData)
    end

    DevPrint("[sv-permanent] SendActiveRadiosToPlayer: Completed for " .. player:Nick())
    Server.PlayerRetryAttempts[player] = nil
end

-- Volume operations
function utils.ProcessVolumeUpdate(entity, volume, player)
    if not IsValid(entity) or not IsValid(player) then return end
    
    entity = SharedUtils.GetVehicle(entity) or entity
    local entityIndex = entity:EntIndex()
    
    if not utils.CanControlRadio(entity, player) then return end
    
    volume = utils.ClampVolume(volume)
    Server.EntityVolumes[entityIndex] = volume
    entity:SetNWFloat("Volume", volume)
    
    net.Start("rRadio.SetRadioVolume")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.SendPAS(entity:GetPos())
end

function utils.InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    
    local entityIndex = entity:EntIndex()
    local entityVolumes = Server.EntityVolumes
    
    if not entityVolumes[entityIndex] then
        entityVolumes[entityIndex] = utils.GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", entityVolumes[entityIndex])
    end
end

-- Radio management functions
function utils.AddActiveRadio(entity, stationName, url, volume, owner)
    if not IsValid(entity) then return end
    
    local entityIndex = entity:EntIndex()
    DevPrint("[sv-permanent] Adding active radio for entity " .. entityIndex .. " owner=" .. (IsValid(owner) and owner:Nick() or "nil"))
    
    local entityVolumes = Server.EntityVolumes
    entityVolumes[entityIndex] = entityVolumes[entityIndex] or volume or utils.GetDefaultVolume(entity)
    
    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", entityVolumes[entityIndex])
    
    DevPrint("[sv-permanent] Setting volume for entity " .. entityIndex .. " to " .. tostring(entityVolumes[entityIndex]))

    local player = owner or SharedUtils.GetOwner(entity)
    
    Server.ActiveRadios[entityIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = entityVolumes[entityIndex],
        owner = player,
        timestamp = SysTime()
    }

    Server.ActiveRadiosCount = (Server.ActiveRadiosCount or 0) + 1

    if player then
        Server.PlayerRadios[player] = Server.PlayerRadios[player] or {}
        Server.PlayerRadios[player][entityIndex] = true
    end
    
    if SharedUtils.IsBoombox(entity) then
        DevPrint("[sv-permanent] Entity " .. entityIndex .. " is a boombox, updating status")
        Server.BoomboxStatuses[entityIndex] = {
            stationStatus = Status.PLAYING,
            stationName = stationName,
            url = url
        }
    end
    
    DevPrint("[sv-permanent] Successfully added entity " .. entityIndex .. " to active radios")
end

function utils.RemoveActiveRadio(entity)
    if not IsValid(entity) then return end
    
    local entityIndex = entity:EntIndex()
    DevPrint("[sv-permanent] Removing ActiveRadio entry idx=" .. entityIndex)
    
    local activeRadioData = Server.ActiveRadios[entityIndex]
    if activeRadioData then
        local player = activeRadioData.owner
        local playerRadios = Server.PlayerRadios

        if player and playerRadios[player] then
            playerRadios[player][entityIndex] = nil

            if not next(playerRadios[player]) then
                playerRadios[player] = nil
            end
        end

        Server.ActiveRadiosCount = math.max((Server.ActiveRadiosCount or 1) - 1, 0)
        Server.ActiveRadios[entityIndex] = nil
    end
end

-- Cleanup functions
function utils.CleanupEntityData(entityIndex)
    local radioTimers = Server.RadioTimers
    for timerNumber, timerPrefix in ipairs(radioTimers) do
        local timerName = timerPrefix .. entityIndex
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end

    local radioDataTables = Server.RadioDataTables
    for tableName in pairs(radioDataTables) do
        if _G[tableName] and _G[tableName][entityIndex] then
            _G[tableName][entityIndex] = nil
        end
    end
    Server.EntityVolumes[entityIndex] = nil
end

function utils.CleanupInactiveRadios()
    local currentTime = SysTime()
    local activeRadios = Server.ActiveRadios
    local inactiveTimeout = Config.InactiveTimeout
    
    for entityIndex, radioData in pairs(activeRadios) do
        local entity = radioData.entity
        if not IsValid(entity) or currentTime - radioData.timestamp > inactiveTimeout then
            utils.RemoveActiveRadio(entity)
        end
    end
end

function utils.ClearOldestActiveRadio()
    local oldestTime, oldestIndex = math.huge, nil
    local activeRadios = Server.ActiveRadios
    
    for entityIndex, radioData in pairs(activeRadios) do
        local entity = radioData.entity or Entity(entityIndex)
        if not IsValid(entity) then
            DevPrint("[sv-permanent] Purging invalid ActiveRadio entry idx=" .. entityIndex)
            activeRadios[entityIndex] = nil
        elseif radioData.timestamp then
            if radioData.timestamp < oldestTime then
                oldestTime, oldestIndex = radioData.timestamp, entityIndex
            end
        else
            DevPrint("[sv-permanent] Entry idx=" .. entityIndex .. " missing timestamp, treating as oldest")
            oldestTime, oldestIndex = 0, entityIndex
        end
    end
    
    if oldestIndex then
        DevPrint("[sv-permanent] Clearing oldest ActiveRadio idx=" .. oldestIndex .. " timestamp=" .. oldestTime)
        local oldEntity = Entity(oldestIndex)
        if IsValid(oldEntity) then 
            utils.BroadcastStop(oldEntity) 
        end
        utils.RemoveActiveRadio(oldEntity)
    end
end
