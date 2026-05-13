rRadio = rRadio or {}
rRadio.util = rRadio.util or {}

local utilModule = rRadio.util
local constants = rRadio.constants

local BOOMBOX_CLASSES = {
    [constants.EntityClasses.BOOMBOX] = true,
    [constants.EntityClasses.GOLDEN_BOOMBOX] = true
}

function utilModule.IsBoomboxClass( class )
    return BOOMBOX_CLASSES[class] == true
end

local isBoomboxClass = utilModule.IsBoomboxClass

function utilModule.ClampVolume( volume )
    local maxVolume = tonumber( rRadio.config.MaxVolume ) or 1
    return math.Clamp( tonumber( volume ) or 0, 0, maxVolume )
end

function utilModule.IsBoombox( entity )
    if not IsValid( entity ) then return false end

    return isBoomboxClass( entity:GetClass() )
end

function utilModule.GetRadioEntity( entity, player )
    if not IsValid( entity ) then return nil end
    if isBoomboxClass( entity:GetClass() ) then return entity end

    return rRadio.vehicle.ResolveRadioHost( entity, player )
end

function utilModule.CanUseRadio( entity, player )
    if not IsValid( entity ) then return false end
    if isBoomboxClass( entity:GetClass() ) then return true end

    return rRadio.vehicle.CanUseRadio( entity, player )
end

function utilModule.GetEntityConfig( entity )
    if not IsValid( entity ) then return nil end
    if isBoomboxClass( entity:GetClass() ) then
        return rRadio.config[entity.ConfigKey]
    end

    return rRadio.config.VehicleRadio
end

function utilModule.FormatCountryKey( rawKey )
    local spaced = string.gsub( tostring( rawKey or "" ), "_", " " )

    local titled = string.gsub( spaced, "(%a)(%a*)", function( first, rest )
        return string.upper( first ) .. string.lower( rest )
    end )

    return titled
end

return utilModule
