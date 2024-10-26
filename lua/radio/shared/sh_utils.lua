utils = utils or {}
utils.debug_mode = false
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
end

function utils.getOwner(ent)
    if not IsValid(ent) then return nil end
    return ent:GetNWEntity("Owner")
end

function utils.canInteractWithBoombox(ply, boombox)
    if not IsValid(ply) or not IsValid(boombox) then return false end
    if ply:IsSuperAdmin() then return true end
    local owner = utils.getOwner(boombox)
    return IsValid(owner) and owner == ply
end

function utils.getVehicleEntity(entity)
    if not IsValid(entity) then return nil end
    if entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

function utils.isValidRadioEntity(entity, player)
    if not IsValid(entity) then return false end
    if entity:GetClass() == "boombox" then return player and utils.canInteractWithBoombox(player, entity) or true end
    return entity:IsVehicle() and not utils.isSitAnywhereSeat(entity)
end

function utils.getEntityConfig(entity)
    if not IsValid(entity) then return nil end
    if entity:GetClass() == "boombox" then return Config.Boombox end
    return Config.VehicleRadio
end

function utils.updateEntityStatus(entity, status, stationName)
    if not IsValid(entity) then return end
    entity:SetNWString("Status", status)
    entity:SetNWString("StationName", stationName or "")
    entity:SetNWBool("IsPlaying", status == "playing" or status == "tuning")
end
return utils