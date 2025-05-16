rRadio.utils = rRadio.utils or {}

rRadio.utils.VehicleClasses = {
  ["prop_vehicle_prisoner_pod"] = true,
  ["prop_vehicle_jeep"] = true,
  ["prop_vehicle_airboat"] = true,
  ["gmod_sent_vehicle_fphysics_base"] = true,
  ["drs_car_r5"] = true,
}

rRadio.utils.SitAnywhereSeats = {
  ["Seat_Airboat"] = true,
  ["Chair_Office2"] = true,
  ["Chair_Plastic"] = true,
  ["Seat_Jeep"] = true,
  ["Chair_Office1"] = true,
  ["Chair_Wood"] = true,
}

function rRadio.utils.Scale(val) return val * (ScrW() / 2560) end

function rRadio.utils.GetVehicle(ent)
  if not IsValid(ent) then return end
  local parent = ent:GetParent()
  ent = IsValid(parent) and parent or ent
  if rRadio.utils.SitAnywhereSeats[ent:GetClass()] then return end

  local class = ent:GetClass()
  if rRadio.utils.VehicleClasses[class] or ent:IsVehicle() then
    return ent
  end
  for _, prefix in ipairs(rRadio.config.VehicleClassOverides or {}) do
    if string.StartWith(class, prefix) then
      return ent
    end
  end
end

function rRadio.utils.isSitAnywhereSeat(vehicle)
  if not IsValid(vehicle) then return false end
  if rRadio.utils.SitAnywhereSeats[vehicle:GetClass()] then
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

function rRadio.utils.getOwner(ent)
  if not IsValid(ent) then return nil end
  return ent:GetNWEntity("Owner")
end

function rRadio.utils.canInteractWithBoombox(ply, boombox)
  -- rRadio.DevPrint("Checking if player can interact with boombox")

  if not IsValid(ply) or not IsValid(boombox) then return false end
  local owner = rRadio.utils.getOwner(boombox)

  -- rRadio.DevPrint("Owner is valid, checking if player is owner")

  if owner == ply then
    -- rRadio.DevPrint("Player is owner - granting permission")
    return true
  end

  -- rRadio.DevPrint("Player is valid, checking CAMI")
  if CAMI.PlayerHasAccess(ply, "rradio.UseAll") then
    -- rRadio.DevPrint("Player has rradio.UseAll")
    return true
  end

  return false
end

function rRadio.utils.GetEntityConfig(entity)
  if not IsValid(entity) then return nil end
  local entityClass = entity:GetClass()
  if entityClass == "rammel_boombox_gold" then
    return rRadio.config.GoldenBoombox
  elseif entityClass == "rammel_boombox" then
    return rRadio.config.Boombox
  elseif rRadio.utils.GetVehicle(entity) then
    return rRadio.config.VehicleRadio
  end
  return nil
end

function rRadio.utils.setRadioStatus(entity, status, stationName, isPlaying, updateNameOnly)
  if not IsValid(entity) then return end

  local entIndex = entity:EntIndex()

  if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
    timer.Remove("UpdateBoomboxStatus_" .. entIndex)
  end

  stationName = stationName or ""
  if isPlaying == nil then
    isPlaying = (status == rRadio.status.PLAYING or status == rRadio.status.TUNING)
  end

  local statuses = SERVER and rRadio.sv.BoomboxStatuses or rRadio.cl.BoomboxStatuses or {}
  if not statuses[entIndex] then
    statuses[entIndex] = {}
  end

  if not updateNameOnly then
    entity:SetNWInt("Status", status)
    entity:SetNWBool("IsPlaying", isPlaying)
    statuses[entIndex].stationStatus = status
  end

  entity:SetNWString("StationName", stationName)
  statuses[entIndex].stationName = stationName
  if SERVER then
    net.Start("rRadio.UpdateRadioStatus")
    net.WriteEntity(entity)
    net.WriteString(stationName)
    net.WriteBool(isPlaying)
    net.WriteUInt(status or rRadio.status.STOPPED, 2)
    net.Broadcast()
  end
end

function rRadio.utils.clearRadioStatus(entity)
  if not IsValid(entity) then return end

  local entIndex = entity:EntIndex()

  if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
    timer.Remove("UpdateBoomboxStatus_" .. entIndex)
  end

  rRadio.utils.setRadioStatus(entity, rRadio.status.STOPPED, "", false)
end

function rRadio.utils.IsBoombox(entity)
  if not IsValid(entity) then return false end
  local class = entity:GetClass()
  return class == "rammel_boombox" or class == "rammel_boombox_gold"
end

function rRadio.utils.canUseRadio(entity)
  if not IsValid(entity) then return false end
  if rRadio.utils.IsBoombox(entity) then return true end

  local vehicle = rRadio.utils.GetVehicle(entity)

  if not vehicle then return false end
  if rRadio.utils.isSitAnywhereSeat(vehicle) then return false end
  return true
end

function rRadio.utils.PrintVehicleClassInfo(ent)
  if not IsValid(ent) then
    rRadio.DevPrint("[Radio Utils] Invalid entity passed to PrintVehicleClassInfo.")
    return
  end

  local entClass = ent:GetClass()
  rRadio.DevPrint("[Radio Utils] Entity Class: ", entClass)

  local parent = ent:GetParent()
  if IsValid(parent) then
    local parentClass = parent:GetClass()
    rRadio.DevPrint("[Radio Utils] Parent Class: ", parentClass)
  else
    rRadio.DevPrint("[Radio Utils] Entity has no valid parent.")
  end
end

function rRadio.utils.FormatAndTranslateCountry(rawKey)
  local formatted = rawKey
    :gsub("_"," ")
    :gsub("(%a)([%w_']*)", function(f,r) return f:upper()..r:lower() end)
  return rRadio.LanguageManager:GetCountryTranslation(formatted)
end
  
return rRadio.utils