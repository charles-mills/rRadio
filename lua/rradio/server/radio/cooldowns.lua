rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.cooldowns = rRadio.radio.cooldowns or {}

local cooldowns = rRadio.radio.cooldowns
local playerCooldowns = setmetatable( {}, { __mode = "k" } )
local volumeCooldowns = setmetatable( {}, { __mode = "k" } )


function cooldowns.CanUseControl( player )
    if not IsValid( player ) then return true end

    local now = SysTime()
    local lastRequest = playerCooldowns[player] or 0
    if now - lastRequest < ( rRadio.config.ControlCooldown or 0.25 ) then return false end

    playerCooldowns[player] = now
    return true
end


function cooldowns.CanUseVolume( player, entity )
    if not IsValid( player ) then return true end

    local entityIndex = IsValid( entity ) and entity:EntIndex() or 0
    local playerVolumeCooldowns = volumeCooldowns[player]
    if not playerVolumeCooldowns then
        playerVolumeCooldowns = {}
        volumeCooldowns[player] = playerVolumeCooldowns
    end

    local now = SysTime()
    local lastRequest = playerVolumeCooldowns[entityIndex] or 0
    if now - lastRequest < ( rRadio.config.VolumeControlCooldown or 0.05 ) then return false end

    playerVolumeCooldowns[entityIndex] = now
    return true
end


function cooldowns.ClearPlayer( player )
    playerCooldowns[player] = nil
    volumeCooldowns[player] = nil
end


return cooldowns
