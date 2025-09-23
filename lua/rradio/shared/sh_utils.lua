local Radio = rRadio
Radio.utils = Radio.utils or {}
Radio.LanguageManager = Radio.LanguageManager or {}
local Utils = Radio.utils
local Config = Radio.config
local Server = Radio.sv
local DevPrint = Radio.DevPrint
local LanguageManager = Radio.LanguageManager

if not LanguageManager.GetCountryTranslation then
    function LanguageManager:GetCountryTranslation(key)
        return key
    end
end

if not LanguageManager.GetCustomTranslation then
    function LanguageManager:GetCustomTranslation()
        return Config and (Config.CustomStationCategory or "Custom") or "Custom"
    end
end

-- Constants
local RADIO_STATUS = {
    STOPPED = 0,
    PLAYING = 1,
    TUNING = 2
}

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

-- Timer prefix for consistency
local TIMER_PREFIX = "rRadio_UpdateStatus_"


-- Vehicle Detection Functions

function Utils.GetVehicle( entity )
    if not IsValid( entity ) then return nil end
    
    local parent = entity:GetParent()
    local targetEntity = IsValid( parent ) and parent or entity
    
    -- Early return for sit anywhere seats
    if SIT_ANYWHERE_SEATS[targetEntity:GetClass()] then
        return nil
    end
    
    -- Check if it's a recognized vehicle
    if Utils.IsVehicleClass( targetEntity ) then
        return targetEntity
    end
    
    return nil
end


function Utils.IsVehicleClass( entity )
    if not IsValid( entity ) then return false end
    
    local class = entity:GetClass()
    
    -- Check standard vehicle classes
    if VEHICLE_CLASSES[class] or entity:IsVehicle() then
        return true
    end
    
    -- Check config overrides
    return Utils.CheckVehicleOverrides( class )
end


function Utils.CheckVehicleOverrides( className )
    local overrides = Config.VehicleClassOverides or {}
    
    for _, prefix in ipairs( overrides ) do
        if string.StartWith( className, prefix ) then
            return true
        end
    end
    
    return false
end


function Utils.IsSitAnywhereSeat( vehicle )
    if not IsValid( vehicle ) then return false end
    
    -- Check class first
    if SIT_ANYWHERE_SEATS[vehicle:GetClass()] then
        return true
    end
    
    -- Check networked value
    local nwValue = vehicle:GetNWBool( "IsSitAnywhereSeat", nil )
    if nwValue ~= nil then
        return nwValue
    end
    
    -- Server-side check
    if SERVER then
        return vehicle.playerdynseat or false
    end
    
    return false
end


-- Configuration Functions

function Utils.GetEntityConfig( entity )
    if not IsValid( entity ) then return nil end
    
    local entityClass = entity:GetClass()
    
    if entityClass == GOLDEN_BOOMBOX_CLASS then
        return Config.GoldenBoombox
    elseif entityClass == BOOMBOX_CLASS then
        return Config.Boombox
    else
        return Config.VehicleRadio
    end
end


-- Ownership and Permission Functions

function Utils.GetOwner( entity )
    if not IsValid( entity ) then return nil end
    return entity:GetNWEntity( "Owner" )
end


function Utils.CanInteractWithBoombox( ply, boombox )
    if not IsValid( ply ) or not IsValid( boombox ) then return false end
    
    local owner = Utils.GetOwner( boombox )
    
    -- Owner always has permission
    if owner == ply then
        return true
    end
    
    -- Check CAMI permissions
    if CAMI and CAMI.PlayerHasAccess( ply, "rradio.UseAll" ) then
        return true
    end
    
    return false
end


-- Radio Status Management Functions

function Utils.SetRadioStatus( entity, status, stationName, isPlaying, updateNameOnly )
    if not IsValid( entity ) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up existing timer
    Utils.RemoveStatusTimer( entIndex )
    
    -- Set defaults
    stationName = stationName or ""
    if isPlaying == nil then
        isPlaying = ( status == RADIO_STATUS.PLAYING or status == RADIO_STATUS.TUNING )
    end
    
    -- Update status storage
    Utils.UpdateStatusStorage( entIndex, status, stationName, updateNameOnly )
    
    -- Update networked values
    if not updateNameOnly then
        entity:SetNWInt( "Status", status )
        entity:SetNWBool( "IsPlaying", isPlaying )
    end
    
    entity:SetNWString( "StationName", stationName )
    
    -- Broadcast changes on server
    if SERVER then
        Utils.BroadcastRadioStatus( entity, stationName, isPlaying, status )
    end
end


function Utils.UpdateStatusStorage( entIndex, status, stationName, updateNameOnly )
    local statuses = (SERVER and Server and Server.BoomboxStatuses) or (Radio.cl and Radio.cl.BoomboxStatuses) or {}
    
    if not statuses[entIndex] then
        statuses[entIndex] = {}
    end
    
    if not updateNameOnly then
        statuses[entIndex].stationStatus = status
    end
    
    statuses[entIndex].stationName = stationName
end


function Utils.BroadcastRadioStatus( entity, stationName, isPlaying, status )
    net.Start( "rRadio.UpdateRadioStatus" )
    net.WriteEntity( entity )
    net.WriteString( stationName )
    net.WriteBool( isPlaying )
    net.WriteUInt( status or RADIO_STATUS.STOPPED, 2 )
    net.Broadcast()
end


function Utils.ClearRadioStatus( entity )
    if not IsValid( entity ) then return end
    
    local entIndex = entity:EntIndex()
    Utils.RemoveStatusTimer( entIndex )
    
    Utils.SetRadioStatus( entity, RADIO_STATUS.STOPPED, "", false )
end


function Utils.RemoveStatusTimer( entIndex )
    local timerName = TIMER_PREFIX .. entIndex
    
    if timer.Exists( timerName ) then
        timer.Remove( timerName )
    end
end


-- Entity Type Checking Functions

function Utils.IsBoombox( entity )
    if not IsValid( entity ) then return false end
    
    local class = entity:GetClass()
    return class == BOOMBOX_CLASS or class == GOLDEN_BOOMBOX_CLASS
end


function Utils.CanUseRadio( entity )
    if not IsValid( entity ) then return false end
    
    -- Boomboxes can always use radio
    if Utils.IsBoombox( entity ) then return true end
    
    -- Check if it's a valid vehicle
    local vehicle = Utils.GetVehicle( entity )
    if not vehicle then return false end
    
    -- Sit anywhere seats cannot use radio
    if Utils.IsSitAnywhereSeat( vehicle ) then return false end
    
    return true
end


-- Debug Functions

function Utils.PrintVehicleClassInfo( entity )
    if not IsValid( entity ) then
        DevPrint( "[Radio Utils] Invalid entity passed to PrintVehicleClassInfo." )
        return
    end
    
    local entityClass = entity:GetClass()
    DevPrint( "[Radio Utils] Entity Class: ", entityClass )
    
    local parent = entity:GetParent()
    if IsValid( parent ) then
        local parentClass = parent:GetClass()
        DevPrint( "[Radio Utils] Parent Class: ", parentClass )
    else
        DevPrint( "[Radio Utils] Entity has no valid parent." )
    end
end


-- Localization Functions

function Utils.FormatAndTranslateCountry( rawKey )
    -- Handle custom category
    if Utils.IsCustomCategory( rawKey ) then
        return LanguageManager:GetCustomTranslation()
    end
    
    -- Format the key
    local formatted = Utils.FormatCountryKey( rawKey )
    
    -- Get translation or return formatted version
    return LanguageManager:GetCountryTranslation( formatted ) or formatted
end


function Utils.IsCustomCategory( rawKey )
    return Config.CustomStationCategory == "Custom" and rawKey == "Custom"
end


function Utils.FormatCountryKey( rawKey )
    return rawKey
        :gsub( "_", " " )
        :gsub( "(%a)([%w_']*)", function( first, rest )
            return first:upper() .. rest:lower()
        end )
end


return Utils
