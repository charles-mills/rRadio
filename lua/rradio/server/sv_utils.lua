rRadio.sv = rRadio.sv or {}
rRadio.sv.utils = rRadio.sv.utils or {}

function rRadio.sv.utils.IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

function rRadio.sv.utils.AssignOwner(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return
    end
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end
    ent:SetNWEntity("Owner", ply)
end

function rRadio.sv.utils.GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

local function printMessage(msg)
    if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
end

function rRadio.sv.utils.CountPlayerRadios(ply)
    local tbl = rRadio.sv.PlayerRadios[ply]
    local cnt = 0
    if tbl then for _ in pairs(tbl) do cnt = cnt + 1 end end
    return cnt
end

function rRadio.sv.utils.UpdateVehicleStatus(vehicle)
    if not IsValid(vehicle) then return end
    local veh = rRadio.utils.GetVehicle(vehicle)
    if not veh then return end
    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
    return isSitAnywhere
end

function rRadio.sv.utils.AddActiveRadio(entity, stationName, url, volume)
    local entIndex = entity:EntIndex()
    rRadio.DevPrint("[rRADIO] Adding active radio for entity " .. entIndex)
    
    rRadio.sv.EntityVolumes[entIndex] = rRadio.sv.EntityVolumes[entIndex] or volume or rRadio.sv.utils.GetDefaultVolume(entity)
    entity:SetNWString("StationName", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", rRadio.sv.EntityVolumes[entIndex])
    
    rRadio.DevPrint("[rRADIO] Setting volume for entity " .. entIndex .. " to " .. tostring(rRadio.sv.EntityVolumes[entIndex]))
    
    rRadio.sv.ActiveRadios[entIndex] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = rRadio.sv.EntityVolumes[entIndex],
        timestamp = SysTime()
    }

    rRadio.sv.ActiveRadiosCount = (rRadio.sv.ActiveRadiosCount or 0) + 1
    local ply = rRadio.utils.getOwner(entity)
    if ply then
        rRadio.sv.PlayerRadios[ply] = rRadio.sv.PlayerRadios[ply] or {}
        rRadio.sv.PlayerRadios[ply][entIndex] = true
    end
    
    if rRadio.utils.IsBoombox(entity) then
        rRadio.DevPrint("[rRADIO] Entity " .. entIndex .. " is a boombox, updating status")
        rRadio.sv.BoomboxStatuses[entIndex] = {
            stationStatus = rRadio.status.PLAYING,
            stationName = stationName,
            url = url
        }
    end
    
    rRadio.DevPrint("[rRADIO] Successfully added entity " .. entIndex .. " to active radios")
end

function rRadio.sv.utils.BroadcastPlay(ent, st, url, vol)
    net.Start("rRadio.PlayStation") net.WriteEntity(ent)
    net.WriteString(st) net.WriteString(url) net.WriteFloat(vol)
    net.Broadcast()
end

function rRadio.sv.utils.SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Invalid player")
        return
    end

    if not rRadio.sv.PlayerRetryAttempts[ply] then
        rRadio.sv.PlayerRetryAttempts[ply] = 1
        rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: First attempt for " .. ply:Nick())
    end

    local attempt = rRadio.sv.PlayerRetryAttempts[ply]
    if next(rRadio.sv.ActiveRadios) == nil then
        rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: No active radios found, attempt " .. attempt)
        if attempt >= 3 then
            rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Max attempts reached for " .. ply:Nick())
            rRadio.sv.PlayerRetryAttempts[ply] = nil
            return
        end
        rRadio.sv.PlayerRetryAttempts[ply] = attempt + 1
        timer.Simple(5, function()
            if IsValid(ply) then
                rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Retrying for " .. ply:Nick())
                rRadio.sv.utils.SendActiveRadiosToPlayer(ply)
            else
                rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Player no longer valid during retry")
                rRadio.sv.PlayerRetryAttempts[ply] = nil
            end
        end)
        return
    end

    rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Sending " .. (rRadio.sv.utils.CountActiveRadios() or 0) .. " active radios to " .. ply:Nick())

    for entIndex, radio in pairs(rRadio.sv.ActiveRadios) do
        local entity = Entity(entIndex)
        rRadio.DevPrint("[rRADIO] Sending radio info for entity " .. entIndex .. " to " .. ply:Nick())
        rRadio.DevPrint("[rRADIO] Radio station name: " .. radio.stationName .. " URL: " .. radio.url)

        net.Start("rRadio.PlayStation")
        net.WriteEntity(entity)
        net.WriteString(radio.stationName)
        net.WriteString(radio.url)
        net.WriteFloat(radio.volume)
        net.Send(ply)
    end

    rRadio.DevPrint("[rRADIO] SendActiveRadiosToPlayer: Completed for " .. ply:Nick())
    rRadio.sv.PlayerRetryAttempts[ply] = nil
end

function rRadio.sv.utils.CleanupEntityData(entIndex)
    for _, timerPrefix in ipairs(rRadio.sv.RadioTimers) do
        local timerName = timerPrefix .. entIndex
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end

    for tableName in pairs(rRadio.sv.RadioDataTables) do
        if _G[tableName] and _G[tableName][entIndex] then
            _G[tableName][entIndex] = nil
        end
    end
    rRadio.sv.EntityVolumes[entIndex] = nil
end

function rRadio.sv.utils.CleanupInactiveRadios()
    local currentTime = SysTime()
    for entIndex, radio in pairs(rRadio.sv.ActiveRadios) do
        if not IsValid(radio.entity) or currentTime - radio.timestamp > rRadio.config.InactiveTimeout() then
            rRadio.sv.utils.RemoveActiveRadio(Entity(entIndex))
        end
    end
end

function rRadio.sv.utils.ClearOldestActiveRadio()
    local oldestTime, oldestIdx = math.huge, nil
    for entIdx, data in pairs(rRadio.sv.ActiveRadios) do
        local ent = data.entity or Entity(entIdx)
        if not IsValid(ent) then
            rRadio.DevPrint("[rRADIO] Purging invalid ActiveRadio entry idx="..entIdx)
            rRadio.sv.ActiveRadios[entIdx] = nil
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
        if IsValid(oldEnt) then rRadio.sv.utils.BroadcastStop(oldEnt) end
        rRadio.sv.utils.RemoveActiveRadio(oldEnt)
    end
end

function rRadio.sv.utils.ProcessVolumeUpdate(entity, volume, ply)
    if not IsValid(entity) then return end
    entity = rRadio.utils.GetVehicle(entity) or entity
    local entIndex = entity:EntIndex()
    if not rRadio.sv.utils.CanControlRadio(entity, ply) then return end
    volume = rRadio.sv.utils.ClampVolume(volume)
    rRadio.sv.EntityVolumes[entIndex] = volume
    entity:SetNWFloat("Volume", volume)
    net.Start("rRadio.SetRadioVolume")
    net.WriteEntity(entity)
    net.WriteFloat(volume)
    net.SendPAS(entity:GetPos())
end

function rRadio.sv.utils.InitializeEntityVolume(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    if not rRadio.sv.EntityVolumes[entIndex] then
        rRadio.sv.EntityVolumes[entIndex] = rRadio.sv.utils.GetDefaultVolume(entity)
        entity:SetNWFloat("Volume", rRadio.sv.EntityVolumes[entIndex])
    end
end

function rRadio.sv.utils.RemoveActiveRadio(entity)
    local idx = entity:EntIndex()
    rRadio.DevPrint("[rRADIO] Removing ActiveRadio entry idx="..idx)
    if rRadio.sv.ActiveRadios[idx] then

        local oldData = rRadio.sv.ActiveRadios[idx]
        local ply = rRadio.utils.getOwner(oldData.entity)
        if ply and rRadio.sv.PlayerRadios[ply] then
            rRadio.sv.PlayerRadios[ply][idx] = nil
        end

        rRadio.sv.ActiveRadiosCount = math.max((rRadio.sv.ActiveRadiosCount or 1) - 1, 0)
        rRadio.sv.ActiveRadios[idx] = nil
    end
end

function rRadio.sv.utils.BroadcastStop(ent)
    net.Start("rRadio.StopStation")
    net.WriteEntity(ent)
    net.Broadcast()
end

function rRadio.sv.utils.CanControlRadio(entity, ply)
    if not IsValid(entity) or not IsValid(ply) then return false end

    if rRadio.utils.IsBoombox(entity) then
        return rRadio.utils.canInteractWithBoombox(ply, entity)
    end

    local veh = rRadio.utils.GetVehicle(entity)
    if IsValid(veh) then
        if not rRadio.config.DriverPlayOnly or veh:GetDriver() == ply then
            return true
        end
    end

    return false
end

function rRadio.sv.utils.ClampVolume(volume)
    if type(volume) ~= "number" then return 0.5 end
    local maxVolume = rRadio.config.MaxVolume()
    return math.Clamp(volume, 0, maxVolume)
end

function rRadio.sv.utils.GetDefaultVolume(entity)
    if not IsValid(entity) then return 0.5 end
    local class = entity:GetClass()
    if class == "rammel_boombox_gold" then
        return GetConVar("rammel_rradio_sv_gold_default_volume"):GetFloat()
    elseif class == "rammel_boombox" then
        return GetConVar("rammel_rradio_sv_boombox_default_volume"):GetFloat()
    else
        return GetConVar("rammel_rradio_sv_vehicle_default_volume"):GetFloat()
    end
end

function rRadio.sv.utils.CountActiveRadios()
    return rRadio.sv.ActiveRadiosCount or 0
end