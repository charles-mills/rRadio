rRadio.utils = rRadio.utils or {}


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

function rRadio.utils.GetVehicle( entity )
    if not IsValid( entity ) then return nil end
    
    local parent = entity:GetParent()
    local targetEntity = IsValid( parent ) and parent or entity
    
    -- Early return for sit anywhere seats
    if SIT_ANYWHERE_SEATS[targetEntity:GetClass()] then
        return nil
    end
    
    -- Check if it's a recognized vehicle
    if rRadio.utils.IsVehicleClass( targetEntity ) then
        return targetEntity
    end
    
    return nil
end


function rRadio.utils.IsVehicleClass( entity )
    if not IsValid( entity ) then return false end
    
    local class = entity:GetClass()
    
    -- Check standard vehicle classes
    if VEHICLE_CLASSES[class] or entity:IsVehicle() then
        return true
    end
    
    -- Check config overrides
    return rRadio.utils.CheckVehicleOverrides( class )
end


function rRadio.utils.CheckVehicleOverrides( className )
    local overrides = rRadio.config.VehicleClassOverides or {}
    
    for _, prefix in ipairs( overrides ) do
        if string.StartWith( className, prefix ) then
            return true
        end
    end
    
    return false
end


function rRadio.utils.IsSitAnywhereSeat( vehicle )
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

function rRadio.utils.GetEntityConfig( entity )
    if not IsValid( entity ) then return nil end
    
    local entityClass = entity:GetClass()
    
    if entityClass == GOLDEN_BOOMBOX_CLASS then
        return rRadio.config.GoldenBoombox
    elseif entityClass == BOOMBOX_CLASS then
        return rRadio.config.Boombox
    else
        return rRadio.config.VehicleRadio
    end
end


-- Ownership and Permission Functions

function rRadio.utils.GetOwner( entity )
    if not IsValid( entity ) then return nil end
    return entity:GetNWEntity( "Owner" )
end


function rRadio.utils.CanInteractWithBoombox( ply, boombox )
    if not IsValid( ply ) or not IsValid( boombox ) then return false end
    
    local owner = rRadio.utils.GetOwner( boombox )
    
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

function rRadio.utils.SetRadioStatus( entity, status, stationName, isPlaying, updateNameOnly )
    if not IsValid( entity ) then return end
    
    local entIndex = entity:EntIndex()
    
    -- Clean up existing timer
    rRadio.utils.RemoveStatusTimer( entIndex )
    
    -- Set defaults
    stationName = stationName or ""
    if isPlaying == nil then
        isPlaying = ( status == RADIO_STATUS.PLAYING or status == RADIO_STATUS.TUNING )
    end
    
    -- Update status storage
    rRadio.utils.UpdateStatusStorage( entIndex, status, stationName, updateNameOnly )
    
    -- Update networked values
    if not updateNameOnly then
        entity:SetNWInt( "Status", status )
        entity:SetNWBool( "IsPlaying", isPlaying )
    end
    
    entity:SetNWString( "StationName", stationName )
    
    -- Broadcast changes on server
    if SERVER then
        rRadio.utils.BroadcastRadioStatus( entity, stationName, isPlaying, status )
    end
end


function rRadio.utils.UpdateStatusStorage( entIndex, status, stationName, updateNameOnly )
    local statuses = SERVER and rRadio.sv.BoomboxStatuses or rRadio.cl.BoomboxStatuses or {}
    
    if not statuses[entIndex] then
        statuses[entIndex] = {}
    end
    
    if not updateNameOnly then
        statuses[entIndex].stationStatus = status
    end
    
    statuses[entIndex].stationName = stationName
end


function rRadio.utils.BroadcastRadioStatus( entity, stationName, isPlaying, status )
    net.Start( "rRadio.UpdateRadioStatus" )
    net.WriteEntity( entity )
    net.WriteString( stationName )
    net.WriteBool( isPlaying )
    net.WriteUInt( status or RADIO_STATUS.STOPPED, 2 )
    net.Broadcast()
end


function rRadio.utils.ClearRadioStatus( entity )
    if not IsValid( entity ) then return end
    
    local entIndex = entity:EntIndex()
    rRadio.utils.RemoveStatusTimer( entIndex )
    
    rRadio.utils.SetRadioStatus( entity, RADIO_STATUS.STOPPED, "", false )
end


function rRadio.utils.RemoveStatusTimer( entIndex )
    local timerName = TIMER_PREFIX .. entIndex
    
    if timer.Exists( timerName ) then
        timer.Remove( timerName )
    end
end


-- Entity Type Checking Functions

function rRadio.utils.IsBoombox( entity )
    if not IsValid( entity ) then return false end
    
    local class = entity:GetClass()
    return class == BOOMBOX_CLASS or class == GOLDEN_BOOMBOX_CLASS
end


function rRadio.utils.CanUseRadio( entity )
    if not IsValid( entity ) then return false end
    
    -- Boomboxes can always use radio
    if rRadio.utils.IsBoombox( entity ) then return true end
    
    -- Check if it's a valid vehicle
    local vehicle = rRadio.utils.GetVehicle( entity )
    if not vehicle then return false end
    
    -- Sit anywhere seats cannot use radio
    if rRadio.utils.IsSitAnywhereSeat( vehicle ) then return false end
    
    return true
end


-- Debug Functions

function rRadio.utils.PrintVehicleClassInfo( entity )
    if not IsValid( entity ) then
        rRadio.DevPrint( "[Radio Utils] Invalid entity passed to PrintVehicleClassInfo." )
        return
    end
    
    local entityClass = entity:GetClass()
    rRadio.DevPrint( "[Radio Utils] Entity Class: ", entityClass )
    
    local parent = entity:GetParent()
    if IsValid( parent ) then
        local parentClass = parent:GetClass()
        rRadio.DevPrint( "[Radio Utils] Parent Class: ", parentClass )
    else
        rRadio.DevPrint( "[Radio Utils] Entity has no valid parent." )
    end
end


-- Localization Functions

function rRadio.utils.FormatAndTranslateCountry( rawKey )
    -- Handle custom category
    if rRadio.utils.IsCustomCategory( rawKey ) then
        return rRadio.LanguageManager:GetCustomTranslation()
    end
    
    -- Format the key
    local formatted = rRadio.utils.FormatCountryKey( rawKey )
    
    -- Get translation or return formatted version
    return rRadio.LanguageManager:GetCountryTranslation( formatted ) or formatted
end


function rRadio.utils.IsCustomCategory( rawKey )
    return rRadio.config.CustomStationCategory == "Custom" and rawKey == "Custom"
end


function rRadio.utils.FormatCountryKey( rawKey )
    return rawKey
        :gsub( "_", " " )
        :gsub( "(%a)([%w_']*)", function( first, rest )
            return first:upper() .. rest:lower()
        end )
end


-- Client-side Key Mapping
if CLIENT then
    local KEY_CODE_MAPPING = {
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
    
    
    function rRadio.GetKeyName( keyCode )
        return KEY_CODE_MAPPING[keyCode] or "the Open Key"
    end
end


return rRadio.utils