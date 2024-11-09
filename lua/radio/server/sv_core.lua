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
local ActiveRadios = {}
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
local DEBOUNCE_TIME = 10
local MAX_ACTIVE_RADIOS = 100
local PLAYER_RADIO_LIMIT = 5
local GLOBAL_COOLDOWN = 1
local lastGlobalAction = 0
local VOLUME_UPDATE_DEBOUNCE_TIME = 0.1
local volumeUpdateQueue = {}
local STATION_CHANGE_COOLDOWN = 0.5
local lastStationChangeTimes = {}
local EntityVolumes = {}
local function ClampVolume(volume)
if type(volume) ~= "number" then return 0.5 end
local maxVolume = GetConVar("radio_max_volume_limit"):GetFloat()
return math.Clamp(volume, 0, maxVolume)
end
local function GetDefaultVolume(entity)
if not IsValid(entity) then return 0.5 end
local entityClass = entity:GetClass()
if entityClass == "golden_boombox" then
return GetConVar("radio_golden_boombox_volume"):GetFloat()
elseif entityClass == "boombox" then
return GetConVar("radio_boombox_volume"):GetFloat()
else
return GetConVar("radio_vehicle_volume"):GetFloat()
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
if not EntityVolumes[entIndex] then
EntityVolumes[entIndex] = volume or GetDefaultVolume(entity)
end
entity:SetNWString("StationName", stationName)
entity:SetNWString("StationURL", url)
entity:SetNWFloat("Volume", EntityVolumes[entIndex])
ActiveRadios[entIndex] = {
stationName = stationName,
url = url,
volume = EntityVolumes[entIndex]
}
if utils.IsBoombox(entity) then
BoomboxStatuses[entIndex] = {
stationStatus = "playing",
stationName = stationName,
url = url
}
end
end
local function RemoveActiveRadio(entity)
ActiveRadios[entity:EntIndex()] = nil
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
ActiveRadios[entIndex] = nil
end
PlayerRetryAttempts[ply] = nil
end
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
timer.Simple(5, function()
if IsValid(ply) then
SendActiveRadiosToPlayer(ply)
end
end)
end)
local function UpdateVehicleStatus(vehicle)
if not IsValid(vehicle) then return end
local veh = utils.GetVehicle(vehicle)
if not veh then return end
local isSitAnywhere = vehicle.playerdynseat or false
vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)
return isSitAnywhere
end
hook.Add("PlayerEnteredVehicle", "RadioVehicleHandling", function(ply, vehicle)
local veh = utils.GetVehicle(vehicle)
if not veh then return end
if utils.isSitAnywhereSeat(vehicle) then return end
if not UpdateVehicleStatus(vehicle) then
net.Start("CarRadioMessage")
net.Send(ply)
end
end)
hook.Add("OnEntityCreated", "InitializeVehicleStatus", function(ent)
timer.Simple(0, function()
if IsValid(ent) and utils.GetVehicle(ent) then
UpdateVehicleStatus(ent)
end
end)
end)
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
net.Receive("PlayCarRadioStation", function(len, ply)
local currentTime = CurTime()
if currentTime - lastGlobalAction < GLOBAL_COOLDOWN then
ply:ChatPrint("The radio system is busy. Please try again in a moment.")
return
end
lastGlobalAction = currentTime
local entity = net.ReadEntity()
local stationName = net.ReadString()
local stationURL = net.ReadString()
local volume = net.ReadFloat()
if not IsValid(entity) then return end
if not utils.canUseRadio(entity) then
ply:ChatPrint("[Radio] This seat cannot use the radio.")
return
end
entity = GetVehicleEntity(entity)
local entIndex = entity:EntIndex()
if utils.IsBoombox(entity) then
if not BoomboxStatuses[entIndex] then
BoomboxStatuses[entIndex] = {}
end
BoomboxStatuses[entIndex].url = stationURL
end
local lastRequestTime = PlayerCooldowns[ply] or 0
if currentTime - lastRequestTime < 0.25 then
ply:ChatPrint("You are changing stations too quickly.")
return
end
PlayerCooldowns[ply] = currentTime
if table.Count(ActiveRadios) >= MAX_ACTIVE_RADIOS then
local oldestTime = math.huge
local oldestRadio = nil
for entIndex, radio in pairs(ActiveRadios) do
if radio.timestamp < oldestTime then
oldestTime = radio.timestamp
oldestRadio = entIndex
end
end
if oldestRadio then
local oldEntity = Entity(oldestRadio)
if IsValid(oldEntity) then
net.Start("StopCarRadioStation")
net.WriteEntity(oldEntity)
net.Broadcast()
end
RemoveActiveRadio(oldEntity)
end
end
local playerActiveRadios = 0
for _, radio in pairs(ActiveRadios) do
if IsValid(radio.entity) and utils.getOwner(radio.entity) == ply then
playerActiveRadios = playerActiveRadios + 1
end
end
if playerActiveRadios >= PLAYER_RADIO_LIMIT then
ply:ChatPrint("You have reached your maximum number of active radios.")
return
end
if ActiveRadios[entIndex] then
net.Start("StopCarRadioStation")
net.WriteEntity(entity)
net.Broadcast()
RemoveActiveRadio(entity)
end
if utils.IsBoombox(entity) then
utils.setRadioStatus(entity, "tuning", stationName)
end
AddActiveRadio(entity, stationName, stationURL, volume)
net.Start("PlayCarRadioStation")
net.WriteEntity(entity)
net.WriteString(stationName)
net.WriteString(stationURL)
net.WriteFloat(volume)
net.Broadcast()
if entity.IsPermanent and SavePermanentBoombox then
SavePermanentBoombox(entity)
end
timer.Create("StationUpdate_" .. entIndex, 2, 1, function()
if IsValid(entity) then
utils.setRadioStatus(entity, "playing", stationName)
end
end)
end)
net.Receive("StopCarRadioStation", function(len, ply)
local entity = net.ReadEntity()
entity = GetVehicleEntity(entity)
if not IsValid(entity) then
return
end
local entityClass = entity:GetClass()
local lvsVehicle = IsLVSVehicle(entity)
if entityClass == "golden_boombox" or entityClass == "boombox" then
if not utils.canInteractWithBoombox(ply, entity) then
ply:ChatPrint("You do not have permission to control this boombox.")
return
end
utils.setRadioStatus(entity, "stopped")
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
if timer.Exists("StationUpdate_" .. entIndex) then
timer.Remove("StationUpdate_" .. entIndex)
end
timer.Create("StationUpdate_" .. entIndex, DEBOUNCE_TIME, 1, function()
if IsValid(entity) and entity.IsPermanent and SavePermanentBoombox then
SavePermanentBoombox(entity)
end
end)
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
local function ProcessVolumeUpdate(entity, volume, ply)
if not IsValid(entity) then return end
entity = utils.GetVehicle(entity) or entity
local entIndex = entity:EntIndex()
if utils.IsBoombox(entity) then
if not utils.canInteractWithBoombox(ply, entity) then
return
end
elseif utils.GetVehicle(entity) then
local vehicle = utils.GetVehicle(entity)
if utils.isSitAnywhereSeat(vehicle) then return end
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
net.Broadcast()
end
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
local currentTime = CurTime()
updateData.pendingVolume = volume
updateData.pendingPlayer = ply
if currentTime - updateData.lastUpdate >= VOLUME_UPDATE_DEBOUNCE_TIME then
ProcessVolumeUpdate(entity, volume, ply)
updateData.lastUpdate = currentTime
updateData.pendingVolume = nil
updateData.pendingPlayer = nil
else
if not timer.Exists("VolumeUpdate_" .. entIndex) then
timer.Create("VolumeUpdate_" .. entIndex, VOLUME_UPDATE_DEBOUNCE_TIME, 1, function()
if updateData.pendingVolume and IsValid(updateData.pendingPlayer) then
ProcessVolumeUpdate(entity, updateData.pendingVolume, updateData.pendingPlayer)
updateData.lastUpdate = CurTime()
updateData.pendingVolume = nil
updateData.pendingPlayer = nil
end
end)
end
end
end)
hook.Add("EntityRemoved", "CleanupVolumeUpdateTimers", function(entity)
local entIndex = entity:EntIndex()
if timer.Exists("VolumeUpdate_" .. entIndex) then
timer.Remove("VolumeUpdate_" .. entIndex)
end
volumeUpdateQueue[entIndex] = nil
end)
hook.Add("PlayerDisconnected", "CleanupPlayerVolumeUpdateData", function(ply)
for entIndex, updateData in pairs(volumeUpdateQueue) do
if updateData.player == ply then
if timer.Exists("VolumeUpdate_" .. entIndex) then
timer.Remove("VolumeUpdate_" .. entIndex)
end
volumeUpdateQueue[entIndex] = nil
end
end
end)
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
local mainEntity = entity:GetParent() or entity
if ActiveRadios[mainEntity:EntIndex()] then
RemoveActiveRadio(mainEntity)
end
end)
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
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
timer.Simple(1, function()
if IsDarkRP() then
hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
if IsValid(ent) and utils.IsBoombox(ent) then
AssignOwner(ply, ent)
end
end)
end
end)
end)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
local ent = tr.Entity
if IsValid(ent) and utils.IsBoombox(ent) then
return utils.canInteractWithBoombox(ply, ent)
end
end)
hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
if IsValid(ent) and utils.IsBoombox(ent) then
return utils.canInteractWithBoombox(ply, ent)
end
end)
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
PlayerRetryAttempts[ply] = nil
PlayerCooldowns[ply] = nil
end)
hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
timer.Simple(0.5, function()
if LoadPermanentBoomboxes then
LoadPermanentBoomboxes()
end
end)
end)
hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity)
local entIndex = entity:EntIndex()
LatestVolumeUpdates[entIndex] = nil
if VolumeUpdateTimers[entIndex] then
timer.Remove(VolumeUpdateTimers[entIndex])
VolumeUpdateTimers[entIndex] = nil
end
end)
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
hook.Add("EntityRemoved", "CleanupRadioTimers", function(entity)
local entIndex = entity:EntIndex()
if timer.Exists("VolumeUpdate_" .. entIndex) then
timer.Remove("VolumeUpdate_" .. entIndex)
end
if timer.Exists("StationUpdate_" .. entIndex) then
timer.Remove("StationUpdate_" .. entIndex)
end
end)
_G.AddActiveRadio = AddActiveRadio
hook.Add("InitPostEntity", "EnsureActiveRadioFunctionAvailable", function()
if not _G.AddActiveRadio then
_G.AddActiveRadio = AddActiveRadio
end
end)
local function CleanupInactiveRadios()
local currentTime = CurTime()
for entIndex, radio in pairs(ActiveRadios) do
if not IsValid(radio.entity) or currentTime - radio.timestamp > 3600 then
RemoveActiveRadio(Entity(entIndex))
end
end
end
timer.Create("CleanupInactiveRadios", 300, 0, CleanupInactiveRadios)
concommand.Add("radio_reload_config", function(ply)
if IsValid(ply) and not ply:IsSuperAdmin() then return end
game.ReloadConVars()
if IsValid(ply) then
ply:ChatPrint("[Radio] Configuration reloaded!")
else
print("[Radio] Configuration reloaded!")
end
end)
local function AddRadioCommand(name, helpText)
concommand.Add("radio_set_" .. name, function(ply, cmd, args)
if IsValid(ply) and not ply:IsSuperAdmin() then return end
local value = tonumber(args[1])
if not value then
if IsValid(ply) then
ply:ChatPrint("[Radio] Invalid value provided!")
else
print("[Radio] Invalid value provided!")
end
return
end
local cvar = GetConVar("radio_" .. name)
if cvar then
cvar:SetFloat(value)
local message = string.format("[Radio] %s set to %.2f", name:gsub("_", " "), value)
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
for _, cmd in ipairs(commands) do
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
ply:ChatPrint("[Radio] You need to be a superadmin to use radio commands!")
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
ply:ChatPrint("[Radio] Help information printed to console!")
end
end)
local function AddRadioCommand(name)
local cmdInfo = radioCommands[name]
if not cmdInfo then return end
concommand.Add("radio_set_" .. name, function(ply, cmd, args)
if IsValid(ply) and not ply:IsSuperAdmin() then
ply:ChatPrint("[Radio] You need to be a superadmin to use this command!")
return
end
if not args[1] or args[1] == "help" then
local msg = string.format("[Radio] %s\nUsage: %s <value>\nExample: %s %s",
cmdInfo.desc, cmd, cmd, cmdInfo.example)
if IsValid(ply) then
ply:PrintMessage(HUD_PRINTCONSOLE, msg)
ply:ChatPrint("[Radio] Command help printed to console!")
else
print(msg)
end
return
end
local value = tonumber(args[1])
if not value then
if IsValid(ply) then
ply:ChatPrint("[Radio] Invalid value provided! Use 'help' for usage information.")
else
print("[Radio] Invalid value provided! Use 'help' for usage information.")
end
return
end
local cvar = GetConVar("radio_" .. name)
if cvar then
cvar:SetFloat(value)
local message = string.format("[Radio] %s set to %.2f", name:gsub("_", " "), value)
if IsValid(ply) then
ply:ChatPrint(message)
else
print(message)
end
end
end)
end
for cmd, _ in pairs(radioCommands) do
AddRadioCommand(cmd)
end
hook.Add("OnEntityCreated", "InitializeRadioVolume", function(entity)
timer.Simple(0, function()
if IsValid(entity) and (utils.IsBoombox(entity) or utils.GetVehicle(entity)) then
InitializeEntityVolume(entity)
end
end)
end)
hook.Add("EntityRemoved", "CleanupRadioVolume", function(entity)
local entIndex = entity:EntIndex()
EntityVolumes[entIndex] = nil
end)
local RadioTimers = {
"VolumeUpdate_",
"StationUpdate_"
}
local RadioDataTables = {
LatestVolumeUpdates = true,
VolumeUpdateTimers = true,
volumeUpdateQueue = true
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
end
hook.Add("EntityRemoved", "CleanupRadioData", function(entity)
if IsValid(entity) then
CleanupEntityData(entity:EntIndex())
end
end)
hook.Add("PlayerDisconnected", "CleanupPlayerRadioData", function(ply)
for tableName in pairs(RadioDataTables) do
if _G[tableName] then
for entIndex, data in pairs(_G[tableName]) do
if data.ply == ply or data.pendingPlayer == ply then
CleanupEntityData(entIndex)
end
end
end
end
end)