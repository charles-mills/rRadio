utils = utils or {}
utils.debug_mode = false
utils.VehicleClasses = {
    ["prop_vehicle_prisoner_pod"] = true,
    ["prop_vehicle_jeep"] = true,
    ["prop_vehicle_airboat"] = true,
    ["gmod_sent_vehicle_fphysics_base"] = true,
    ["drs_car_r5"] = true
}
utils.SitAnywhereSeats = {
    ["Seat_Airboat"] = true,
    ["Chair_Office2"] = true,
    ["Chair_Plastic"] = true,
    ["Seat_Jeep"] = true,
    ["Chair_Office1"] = true,
    ["Chair_Wood"] = true
}
function utils.GetVehicle(ent)
    if not IsValid(ent) then
        return
    end
    local parent = ent:GetParent()
    ent = IsValid(parent) and parent or ent
    if utils.SitAnywhereSeats[ent:GetClass()] then
        return
    end
    if
        utils.VehicleClasses[ent:GetClass()] or ent:IsVehicle() or string.StartWith(ent:GetClass(), "lvs_") or
            string.StartWith(ent:GetClass(), "ses_")
     then
        return ent
    end
end
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then
        return false
    end
    if utils.SitAnywhereSeats[vehicle:GetClass()] then
        return true
    end
    local nwValue = vehicle:GetNWBool("IsSitAnywhereSeat", nil)
    if nwValue ~= nil then
        return nwValue
    end
    if SERVER then
        return vehicle.playerdynseat or false
    end
    return false
end
function utils.getOwner(ent)
    if not IsValid(ent) then
        return nil
    end
    return ent:GetNWEntity("Owner")
end
function utils.canInteractWithBoombox(ply, boombox)
    if not IsValid(ply) or not IsValid(boombox) then
        return false
    end
    if ply:IsSuperAdmin() then
        return true
    end
    local owner = utils.getOwner(boombox)
    return IsValid(owner) and owner == ply
end
function utils.GetEntityConfig(entity)
    if not IsValid(entity) then
        return nil
    end
    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif utils.GetVehicle(entity) then
        return Config.VehicleRadio
    end
    return nil
end
function utils.setRadioStatus(entity, status, stationName, isPlaying, updateNameOnly)
    if not IsValid(entity) then
        return
    end
    local entIndex = entity:EntIndex()
    if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
        timer.Remove("UpdateBoomboxStatus_" .. entIndex)
    end
    stationName = stationName or ""
    if isPlaying == nil then
        isPlaying = (status == "playing" or status == "tuning")
    end
    if not BoomboxStatuses[entIndex] then
        BoomboxStatuses[entIndex] = {}
    end
    if not updateNameOnly then
        entity:SetNWString("Status", status)
        entity:SetNWBool("IsPlaying", isPlaying)
        BoomboxStatuses[entIndex].stationStatus = status
    end
    entity:SetNWString("StationName", stationName)
    BoomboxStatuses[entIndex].stationName = stationName
    if SERVER then
        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.WriteBool(isPlaying)
        net.WriteString(updateNameOnly and BoomboxStatuses[entIndex].stationStatus or status)
        net.Broadcast()
    end
end
function utils.clearRadioStatus(entity)
    if not IsValid(entity) then
        return
    end
    local entIndex = entity:EntIndex()
    if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
        timer.Remove("UpdateBoomboxStatus_" .. entIndex)
    end
    utils.setRadioStatus(entity, "stopped", "", false)
end
function utils.IsBoombox(entity)
    if not IsValid(entity) then
        return false
    end
    local class = entity:GetClass()
    return class == "boombox" or class == "golden_boombox"
end
function utils.canUseRadio(entity)
    if not IsValid(entity) then
        return false
    end
    if utils.IsBoombox(entity) then
        return true
    end
    local vehicle = utils.GetVehicle(entity)
    if not vehicle then
        return false
    end
    if utils.isSitAnywhereSeat(vehicle) then
        return false
    end
    return true
end
return utils
