rRadio = rRadio or {}
rRadio.radio = rRadio.radio or {}
rRadio.radio.permissions = rRadio.radio.permissions or {}

local permissions = rRadio.radio.permissions
local privilegeIds = rRadio.privileges.ID

local function hasPrivilege( player, privilege )
    if not IsValid( player ) then return false end
    if player:IsSuperAdmin() then return true end
    if not privilege or not CAMI or not CAMI.PlayerHasAccess then return false end

    local ok, allowed = pcall( CAMI.PlayerHasAccess, player, privilege, nil, nil, {
        Fallback = "superadmin"
    } )
    return ok and allowed == true
end

local function isPermanentBoombox( entity )
    return rRadio.radio.stateStore.IsPermanent( entity )
end

local function isPublicBoombox( entity )
    return rRadio.radio.stateStore.IsPublic( entity )
end

function permissions.CanControl( player, entity )
    if not IsValid( player ) or not IsValid( entity ) then return false, "Invalid radio" end
    if player:IsSuperAdmin() then return true end

    if rRadio.util.IsBoomboxClass( entity:GetClass() ) then
        if isPublicBoombox( entity ) then return true end
        if hasPrivilege( player, privilegeIds.UseAll ) then return true end

        if isPermanentBoombox( entity ) then
            return false, "You do not have permission to control this permanent boombox."
        end

        local owner = rRadio.radio.stateStore.GetOwner( entity )
        if owner == player then return true end
        if not IsValid( owner ) then return false, "You do not have permission to control this ownerless boombox." end

        return false, "You do not have permission to control this boombox."
    end

    if hasPrivilege( player, privilegeIds.UseAll ) then return true end

    local vehicle = rRadio.vehicle.ResolveRadioHost( entity, player )
    if not IsValid( vehicle ) then return false, "This entity cannot use a radio." end

    local playerVehicle = rRadio.vehicle.GetPlayerRadioHost( player )
    if playerVehicle ~= vehicle then return false, "You must be in this vehicle to control its radio." end

    if rRadio.config.DriverPlayOnly and rRadio.vehicle.GetDriver( vehicle ) ~= player then
        return false, "Only the driver can control this radio."
    end

    return true
end

function permissions.CanModifyBoombox( player, entity )
    if not IsValid( player ) or not IsValid( entity ) then return false end
    if not rRadio.util.IsBoomboxClass( entity:GetClass() ) then return permissions.CanControl( player, entity ) end
    if hasPrivilege( player, privilegeIds.UseAll ) then return true end
    if isPermanentBoombox( entity ) then return false end

    return rRadio.radio.stateStore.GetOwner( entity ) == player
end

function permissions.CanSetBoomboxPublic( player, entity )
    if not IsValid( player ) or not IsValid( entity ) then
        return false, "Invalid boombox."
    end

    if not rRadio.util.IsBoomboxClass( entity:GetClass() ) then return false, "Invalid boombox." end
    if permissions.CanManageConfig( player ) then return true end

    return false, "You do not have permission to change boombox public access."
end

function permissions.CanOpenMenu( player, entity )
    local allowed, reason = permissions.CanControl( player, entity )
    if allowed then return true end

    if IsValid( entity ) and rRadio.util.IsBoomboxClass( entity:GetClass() ) then
        local canSetPublic = permissions.CanSetBoomboxPublic( player, entity )
        if canSetPublic then return true end
    end

    return false, reason
end

function permissions.CanManageCustomStations( player )
    if not IsValid( player ) then return true end

    return hasPrivilege( player, privilegeIds.ManageCustom )
end

function permissions.CanManageConfig( player )
    if not IsValid( player ) then return true end

    return hasPrivilege( player, privilegeIds.ManageConfig )
end

return permissions
