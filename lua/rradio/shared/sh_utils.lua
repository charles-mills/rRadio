rRadio.utils = rRadio.utils or {}
local VEHICLE_CLASSES = {
    ["prop_vehicle_prisoner_pod"] = true,
    ["prop_vehicle_jeep"] = true,
    ["prop_vehicle_airboat"] = true,
    ["gmod_sent_vehicle_fphysics_base"] = true,
    ["drs_car_r5"] = true
}

local SIT_ANYWHERE_SEATS = {
    ["Seat_Airboat"] = true,
    ["Chair_Office2"] = true,
    ["Chair_Plastic"] = true,
    ["Seat_Jeep"] = true,
    ["Chair_Office1"] = true,
    ["Chair_Wood"] = true
}

local BOOMBOX_CLASS = "rammel_boombox"
local GOLDEN_BOOMBOX_CLASS = "rammel_boombox_gold"
local TIMER_PREFIX = "rRadio_UpdateStatus_"
function rRadio.utils.GetVehicle(entity)
    if not IsValid(entity) then return nil end
    local parent = entity:GetParent()
    local targetEntity = IsValid(parent) and parent or entity
    if SIT_ANYWHERE_SEATS[targetEntity:GetClass()] then return nil end
    if rRadio.utils.IsVehicleClass(targetEntity) then return targetEntity end
    return nil
end

function rRadio.utils.IsVehicleClass(entity)
    if not IsValid(entity) then return false end
    local class = entity:GetClass()
    if VEHICLE_CLASSES[class] or entity:IsVehicle() then return true end
    return rRadio.utils.CheckVehicleOverrides(class)
end

function rRadio.utils.CheckVehicleOverrides(className)
    local overrides = rRadio.config.VehicleClassOverides or {}
    for _, prefix in ipairs(overrides) do
        if string.StartWith(className, prefix) then return true end
    end
    return false
end

function rRadio.utils.IsSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    if SIT_ANYWHERE_SEATS[vehicle:GetClass()] then return true end
    local nwValue = vehicle:GetNWBool("IsSitAnywhereSeat", nil)
    if nwValue ~= nil then return nwValue end
    if SERVER then return vehicle.playerdynseat or false end
    return false
end

function rRadio.utils.GetEntityConfig(entity)
    if not IsValid(entity) then return nil end
    local entityClass = entity:GetClass()
    if entityClass == GOLDEN_BOOMBOX_CLASS then
        return rRadio.config.GoldenBoombox
    elseif entityClass == BOOMBOX_CLASS then
        return rRadio.config.Boombox
    else
        return rRadio.config.VehicleRadio
    end
end

function rRadio.utils.GetOwner(entity)
    if not IsValid(entity) then return nil end
    return entity:GetNWEntity("Owner")
end

function rRadio.utils.CanInteractWithBoombox(ply, boombox)
    if not IsValid(ply) or not IsValid(boombox) then return false end
    local owner = rRadio.utils.GetOwner(boombox)
    if owner == ply then return true end
    if CAMI and CAMI.PlayerHasAccess(ply, "rradio.UseAll") then return true end
    return false
end

function rRadio.utils.SetRadioStatus(entity, status, stationName, isPlaying, updateNameOnly)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    rRadio.utils.RemoveStatusTimer(entIndex)
    stationName = stationName or ""
    if isPlaying == nil then isPlaying = status == rRadio.status.PLAYING or status == rRadio.status.TUNING end
    rRadio.utils.UpdateStatusStorage(entIndex, status, stationName, updateNameOnly)
    if not updateNameOnly then
        entity:SetNWInt("Status", status)
        entity:SetNWBool("IsPlaying", isPlaying)
    end

    entity:SetNWString("StationName", stationName)
    if SERVER then rRadio.utils.BroadcastRadioStatus(entity, stationName, isPlaying, status) end
end

function rRadio.utils.UpdateStatusStorage(entIndex, status, stationName, updateNameOnly)
    local statuses
    if SERVER then
        rRadio.sv = rRadio.sv or {}
        rRadio.sv.BoomboxStatuses = rRadio.sv.BoomboxStatuses or {}
        statuses = rRadio.sv.BoomboxStatuses
    else
        rRadio.cl = rRadio.cl or {}
        statuses = rRadio.cl.boomboxStatuses or {}
        rRadio.cl.boomboxStatuses = statuses
    end

    if not statuses[entIndex] then statuses[entIndex] = {} end
    if not updateNameOnly then statuses[entIndex].stationStatus = status end
    statuses[entIndex].stationName = stationName
end

function rRadio.utils.BroadcastRadioStatus(entity, stationName, isPlaying, status)
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString(stationName)
    net.WriteBool(isPlaying)
    net.WriteUInt(status or rRadio.status.STOPPED, 2)
    net.Broadcast()
end

function rRadio.utils.ClearRadioStatus(entity)
    if not IsValid(entity) then return end
    local entIndex = entity:EntIndex()
    rRadio.utils.RemoveStatusTimer(entIndex)
    rRadio.utils.SetRadioStatus(entity, rRadio.status.STOPPED, "", false)
end

function rRadio.utils.RemoveStatusTimer(entIndex)
    local timerName = TIMER_PREFIX .. entIndex
    if timer.Exists(timerName) then timer.Remove(timerName) end
end

function rRadio.utils.IsBoombox(entity)
    if not IsValid(entity) then return false end
    local class = entity:GetClass()
    return class == BOOMBOX_CLASS or class == GOLDEN_BOOMBOX_CLASS
end

function rRadio.utils.CanUseRadio(entity)
    if not IsValid(entity) then return false end
    if rRadio.utils.IsBoombox(entity) then return true end
    local vehicle = rRadio.utils.GetVehicle(entity)
    if not vehicle then return false end
    if rRadio.utils.IsSitAnywhereSeat(vehicle) then return false end
    return true
end

function rRadio.utils.PrintVehicleClassInfo(entity)
    if not IsValid(entity) then
        rRadio.logger.DebugScope("utils", "Invalid entity passed to PrintVehicleClassInfo.")
        return
    end

    local entityClass = entity:GetClass()
    rRadio.logger.DebugScope("utils", "Entity Class:", entityClass)
    local parent = entity:GetParent()
    if IsValid(parent) then
        local parentClass = parent:GetClass()
        rRadio.logger.DebugScope("utils", "Parent Class:", parentClass)
    else
        rRadio.logger.DebugScope("utils", "Entity has no valid parent.")
    end
end

function rRadio.utils.FormatAndTranslateCountry(rawKey)
    if rRadio.utils.IsCustomCategory(rawKey) then return rRadio.LanguageManager:GetCustomTranslation() end
    local formatted = rRadio.utils.FormatCountryKey(rawKey)
    return rRadio.LanguageManager:GetCountryTranslation(formatted) or formatted
end

function rRadio.utils.IsCustomCategory(rawKey)
    return rRadio.config.CustomStationCategory == "Custom" and rawKey == "Custom"
end

function rRadio.utils.FormatCountryKey(rawKey)
    return rawKey:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end)
end
return rRadio.utils
