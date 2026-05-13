rRadio = rRadio or {}
rRadio.vehicle = rRadio.vehicle or {}

local vehicle = rRadio.vehicle

local MAX_PARENT_DEPTH = 6

local SEAT_ONLY_CLASSES = {
    prop_vehicle_prisoner_pod = true,
    Seat_Airboat = true,
    Seat_Jeep = true,
    Chair_Office1 = true,
    Chair_Office2 = true,
    Chair_Plastic = true,
    Chair_Wood = true
}

local ADDON_HOST_FLAGS = {
    "IsGlideVehicle",
    "LVS",
    "IsLVS",
    "IsScar",
    "IsScarVehicle",
    "IsSimfphyscar",
    "IsWACAircraft",
    "WAC"
}

local ADDON_HOST_BASES = {
    "gmod_sent_vehicle_fphysics_base",
    "lvs_base",
    "lvs_base_wheeldrive",
    "wac_hc_base"
}

local DRIVER_METHODS = {
    "GetDriver",
    "GetPilot"
}

local providers = {}

local function isBasedOn( className, baseClass )
    return scripted_ents
        and scripted_ents.IsBasedOn
        and scripted_ents.IsBasedOn( className, baseClass ) == true
end

local function flagIsTrue( entity, name )
    local value = entity[name]
    if value == true then return true end
    if type( value ) == "function" then return value( entity ) == true end

    return false
end

local function allowAnyVehicleEntity()
    return rRadio.config.AllowAnyVehicleEntityRadio == true
end

local function isInitializedVehicle( entity )
    if not entity:IsVehicle() then return false end

    return type( entity.IsValidVehicle ) ~= "function" or entity:IsValidVehicle()
end

local function isAddonHost( entity )
    if vehicle.IsSeatOnly( entity ) or vehicle.IsTransientSeat( entity ) then return false end

    for _, flag in ipairs( ADDON_HOST_FLAGS ) do
        if flagIsTrue( entity, flag ) then return true end
    end

    local className = entity:GetClass()
    for _, baseClass in ipairs( ADDON_HOST_BASES ) do
        if className == baseClass or isBasedOn( className, baseClass ) then return true end
    end

    return false
end

local function isNativeHost( entity )
    if vehicle.IsSeatOnly( entity ) then return false end

    return isInitializedVehicle( entity )
end

local function getProviderHost( entity, player )
    for _, provider in ipairs( providers ) do
        if provider.GetHost then
            local host = provider.GetHost( entity, player )
            if host == false then return false end
            if IsValid( host ) then return host end
        end

        if provider.IsHost and provider.IsHost( entity, player ) then return entity end
    end

    return nil
end

local function getDirectHost( entity, player )
    if isNativeHost( entity ) or isAddonHost( entity ) then return entity end

    return getProviderHost( entity, player )
end

local function getLinkedEntityHost( entity, player )
    local fieldHost = entity.vehicle
    if IsValid( fieldHost ) then
        local directHost = getDirectHost( fieldHost, player )
        if directHost ~= nil then return directHost end
    end

    local providerHost = getProviderHost( entity, player )
    if providerHost ~= nil then return providerHost end

    local cursor = entity
    for _ = 1, MAX_PARENT_DEPTH do
        local parent = cursor:GetParent()
        if not IsValid( parent ) or parent == cursor then return nil end

        local host = getDirectHost( parent, player )
        if host ~= nil then return host end

        cursor = parent
    end

    return nil
end

function vehicle.RegisterProvider( name, provider )
    if type( name ) ~= "string" or type( provider ) ~= "table" then return false end
    if type( provider.IsHost ) ~= "function" and type( provider.GetHost ) ~= "function" then return false end

    providers[#providers + 1] = {
        name = name,
        IsHost = provider.IsHost,
        GetHost = provider.GetHost,
        priority = tonumber( provider.priority ) or 0
    }

    table.sort( providers, function( left, right )
        return left.priority > right.priority
    end )

    return true
end

function vehicle.IsSeatOnly( entity )
    return IsValid( entity ) and SEAT_ONLY_CLASSES[entity:GetClass()] == true
end

function vehicle.IsTransientSeat( entity )
    if not IsValid( entity ) then return false end

    if SERVER and entity.playerdynseat == true then return true end
    if entity:GetNWBool( "playerdynseat", false ) then return true end
    if type( entity.IsSitAnywhereSeat ) == "function" then return entity:IsSitAnywhereSeat() == true end

    return false
end

function vehicle.ResolveRadioHost( entity, player )
    if not IsValid( entity ) then return nil, "Invalid vehicle." end

    local permissiveVehicleFallback = allowAnyVehicleEntity()
    if vehicle.IsTransientSeat( entity ) and not permissiveVehicleFallback then
        return nil, "This seat is not a real vehicle."
    end

    local host = getDirectHost( entity, player )
    if host == false then return nil, "This vehicle cannot use a radio." end
    if IsValid( host ) then return host end

    host = getLinkedEntityHost( entity, player )
    if host == false then return nil, "This vehicle cannot use a radio." end
    if IsValid( host ) and not vehicle.IsTransientSeat( host ) then return host end
    if permissiveVehicleFallback and isInitializedVehicle( entity ) then return entity end

    return nil, "This entity is not a real vehicle."
end

function vehicle.IsRadioHost( entity, player )
    return IsValid( vehicle.ResolveRadioHost( entity, player ) )
end

function vehicle.GetPlayerRadioHost( player )
    if not IsValid( player ) then return nil end

    local playerVehicle = player:GetVehicle()
    if not IsValid( playerVehicle ) then return nil end

    return vehicle.ResolveRadioHost( playerVehicle, player )
end

function vehicle.GetDriver( entity )
    entity = vehicle.ResolveRadioHost( entity ) or entity
    if not IsValid( entity ) then return nil end

    for _, methodName in ipairs( DRIVER_METHODS ) do
        if type( entity[methodName] ) == "function" then
            local driver = entity[methodName]( entity )
            if IsValid( driver ) then return driver end
        end
    end

    return nil
end

function vehicle.CanUseRadio( entity, player )
    return IsValid( vehicle.ResolveRadioHost( entity, player ) )
end

return vehicle
