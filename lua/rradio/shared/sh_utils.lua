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

  if rRadio.utils.VehicleClasses[ent:GetClass()] or ent:IsVehicle() or
    string.StartWith(ent:GetClass(), "lvs_") or
    string.StartWith(ent:GetClass(), "ses_") or
    string.StartWith(ent:GetClass(), "sw_") or
    string.StartWith(ent:GetClass(), "drs_")
  then return ent end
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
  rRadio.DevPrint("Checking if player can interact with boombox")

  if not IsValid(ply) or not IsValid(boombox) then return false end
  local owner = rRadio.utils.getOwner(boombox)

  rRadio.DevPrint("Owner is valid, checking if player is owner")

  if owner == ply then
    rRadio.DevPrint("Player is owner - granting permission")
    return true
  end

  if SERVER then
    rRadio.DevPrint("Player is valid, checking CAMI (server)")
    if CAMI.PlayerHasAccess(ply, "rradio.UseAll") then
      rRadio.DevPrint("Player has rradio.UseAll")
      return true
    end
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
    isPlaying = (status == "playing" or status == "tuning")
  end

  local statuses = SERVER and rRadio.sv.BoomboxStatuses or rRadio.cl.BoomboxStatuses or {}
  if not statuses[entIndex] then
    statuses[entIndex] = {}
  end

  if not updateNameOnly then
    entity:SetNWString("Status", status)
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
    local statusToSend = (updateNameOnly and statuses[entIndex].stationStatus or status)
    net.WriteString(statusToSend or "")
    net.Broadcast()
  end
end

function rRadio.utils.clearRadioStatus(entity)
  if not IsValid(entity) then return end

  local entIndex = entity:EntIndex()

  if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
    timer.Remove("UpdateBoomboxStatus_" .. entIndex)
  end

  rRadio.utils.setRadioStatus(entity, "stopped", "", false)
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

if CLIENT then
  rRadio.keyCodeMapping = {
    [KEY_A] = "A",
    [KEY_B] = "B",
    [KEY_C] = "C",
    [KEY_D] = "D",
    [KEY_E] = "E",
    [KEY_F] = "F",
    [KEY_G] = "G",
    [KEY_H] = "H",
    [KEY_I] = "I",
    [KEY_J] = "J",
    [KEY_K] = "K",
    [KEY_L] = "L",
    [KEY_M] = "M",
    [KEY_N] = "N",
    [KEY_O] = "O",
    [KEY_P] = "P",
    [KEY_Q] = "Q",
    [KEY_R] = "R",
    [KEY_S] = "S",
    [KEY_T] = "T",
    [KEY_U] = "U",
    [KEY_V] = "V",
    [KEY_W] = "W",
    [KEY_X] = "X",
    [KEY_Y] = "Y",
    [KEY_Z] = "Z",
    [KEY_0] = "0",
    [KEY_1] = "1",
    [KEY_2] = "2",
    [KEY_3] = "3",
    [KEY_4] = "4",
    [KEY_5] = "5",
    [KEY_6] = "6",
    [KEY_7] = "7",
    [KEY_8] = "8",
    [KEY_9] = "9",
    [KEY_PAD_0] = "Numpad 0",
    [KEY_PAD_1] = "Numpad 1",
    [KEY_PAD_2] = "Numpad 2",
    [KEY_PAD_3] = "Numpad 3",
    [KEY_PAD_4] = "Numpad 4",
    [KEY_PAD_5] = "Numpad 5",
    [KEY_PAD_6] = "Numpad 6",
    [KEY_PAD_7] = "Numpad 7",
    [KEY_PAD_8] = "Numpad 8",
    [KEY_PAD_9] = "Numpad 9",
    [KEY_PAD_DIVIDE] = "Numpad /",
    [KEY_PAD_MULTIPLY] = "Numpad *",
    [KEY_PAD_MINUS] = "Numpad -",
    [KEY_PAD_PLUS] = "Numpad +",
    [KEY_PAD_ENTER] = "Numpad Enter",
    [KEY_PAD_DECIMAL] = "Numpad .",
    [KEY_LSHIFT] = "Left Shift",
    [KEY_RSHIFT] = "Right Shift",
    [KEY_LALT] = "Left Alt",
    [KEY_RALT] = "Right Alt",
    [KEY_LCONTROL] = "Left Ctrl",
    [KEY_RCONTROL] = "Right Ctrl",
    [KEY_SPACE] = "Space",
    [KEY_ENTER] = "Enter",
    [KEY_BACKSPACE] = "Backspace",
    [KEY_TAB] = "Tab",
    [KEY_CAPSLOCK] = "Caps Lock",
    [KEY_ESCAPE] = "Escape",
    [KEY_SCROLLLOCK] = "Scroll Lock",
    [KEY_INSERT] = "Insert",
    [KEY_DELETE] = "Delete",
    [KEY_HOME] = "Home",
    [KEY_END] = "End",
    [KEY_PAGEUP] = "Page Up",
    [KEY_PAGEDOWN] = "Page Down",
    [KEY_BREAK] = "Break",
    [KEY_NUMLOCK] = "Num Lock",
    [KEY_SEMICOLON] = ";",
    [KEY_EQUAL] = "=",
    [KEY_MINUS] = "-",
    [KEY_COMMA] = ",",
    [KEY_PERIOD] = ".",
    [KEY_SLASH] = "/",
    [KEY_BACKSLASH] = "\\",
    [KEY_BACKQUOTE] = "`",
    [KEY_F1] = "F1",
    [KEY_F2] = "F2",
    [KEY_F3] = "F3",
    [KEY_F4] = "F4",
    [KEY_F5] = "F5",
    [KEY_F6] = "F6",
    [KEY_F7] = "F7",
    [KEY_F8] = "F8",
    [KEY_F9] = "F9",
    [KEY_F10] = "F10",
    [KEY_F11] = "F11",
    [KEY_F12] = "F12",
    [KEY_CAPSLOCKTOGGLE] = "Caps Lock Toggle",
    [KEY_NUMLOCKTOGGLE] = "Num Lock Toggle",
    [KEY_LAST] = "Last Key"
    }
    
  function rRadio.GetKeyName(keyCode)
      return rRadio.keyCodeMapping[keyCode] or "the Open Key"
  end
end
  
return rRadio.utils