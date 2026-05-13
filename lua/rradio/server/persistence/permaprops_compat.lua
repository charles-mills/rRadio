rRadio = rRadio or {}
rRadio.persistence = rRadio.persistence or {}
rRadio.persistence.permapropsCompat = rRadio.persistence.permapropsCompat or {}

local compat = rRadio.persistence.permapropsCompat
local TOOL_MODE = "permaprops"
local wrappedTools = setmetatable( {}, { __mode = "k" } )
local initialized = false

local function isPermanentBoombox( entity )
    return rRadio.radio.stateStore.IsPermanent( entity )
end

local function chatPrint( player, message )
    if IsValid( player ) then player:ChatPrint( "[rRadio] " .. message ) end
end

local function getToolOwner( tool )
    if type( tool ) ~= "table" or not tool.GetOwner then return nil end

    local ok, owner = pcall( tool.GetOwner, tool )
    if not ok then return nil end

    return owner
end

local function hasPermaPropsPermission( player, permission )
    if not IsValid( player ) then return false end
    if not PermaProps or not PermaProps.HasPermission then return false end

    local ok, allowed = pcall( PermaProps.HasPermission, player, permission )
    return ok and allowed == true
end

local function canManagePermanence( player )
    return rRadio.radio.permissions.CanManageConfig( player ) == true
end

local function canSetPermanent( player )
    return hasPermaPropsPermission( player, "Save" )
        and canManagePermanence( player )
end

local function canDeletePermanent( player )
    return hasPermaPropsPermission( player, "Delete" )
        and canManagePermanence( player )
end

local function canUpdatePermanent( player )
    return hasPermaPropsPermission( player, "Update" )
        and canManagePermanence( player )
end

local function playPermaPropsEffect( entity )
    if not PermaProps or not PermaProps.SparksEffect then return end

    pcall( PermaProps.SparksEffect, entity )
end

local function setPermanentFromTool( tool, trace, permanent )
    local entity = trace and trace.Entity
    if not rRadio.util.IsBoombox( entity ) then return nil end

    local player = getToolOwner( tool )
    local permission = permanent and "Save" or "Delete"
    if not hasPermaPropsPermission( player, permission ) then return false end

    if not canManagePermanence( player ) then
        chatPrint( player, "You do not have permission to change permanence." )
        return false
    end

    if not permanent and not isPermanentBoombox( entity ) then
        chatPrint( player, "That boombox is not permanent." )
        return false
    end

    local wasPermanent = isPermanentBoombox( entity )
    local ok, reason = rRadio.persistence.service.SetPermanent( player, entity, permanent )
    if not ok then
        chatPrint( player, tostring( reason or "Could not update permanence." ) )
        return false
    end

    if permanent then
        playPermaPropsEffect( entity )
        chatPrint( player, wasPermanent and "Permanent boombox saved." or "Boombox set as permanent." )
        return true
    end

    chatPrint( player, "Permanent boombox deleted." )
    entity:Remove()
    return true
end

local function updatePermanentFromTool( tool, trace )
    local entity = trace and trace.Entity
    if not rRadio.util.IsBoombox( entity ) then return nil end

    local player = getToolOwner( tool )
    if not hasPermaPropsPermission( player, "Update" ) then return false end

    if not canManagePermanence( player ) then
        chatPrint( player, "You do not have permission to change permanence." )
        return false
    end

    if not isPermanentBoombox( entity ) then
        chatPrint( player, "That boombox is not permanent." )
        return false
    end

    if not rRadio.persistence.service.SavePermanentBoombox( entity ) then
        chatPrint( player, "Could not update permanent boombox." )
        return false
    end

    playPermaPropsEffect( entity )
    chatPrint( player, "Permanent boombox updated." )
    return true
end

function compat.CanUseTool( player, entity, button )
    if not rRadio.util.IsBoombox( entity ) then return nil end

    if button == 1 then return canSetPermanent( player ) end
    if button == 2 then return canDeletePermanent( player ) end
    if button == 3 then return canUpdatePermanent( player ) end

    return canSetPermanent( player ) or canDeletePermanent( player )
end

function compat.WrapTool( tool )
    if type( tool ) ~= "table" then return false end
    if wrappedTools[tool] or tool.rRadioPermaPropsCompatWrapped then return false end
    if type( tool.LeftClick ) ~= "function" or type( tool.RightClick ) ~= "function" then return false end
    if type( tool.Reload ) ~= "function" then return false end

    local originalLeftClick = tool.LeftClick
    local originalRightClick = tool.RightClick
    local originalReload = tool.Reload
    wrappedTools[tool] = true
    tool.rRadioPermaPropsCompatWrapped = true
    tool.rRadioPermaPropsCompatOriginalLeftClick = originalLeftClick
    tool.rRadioPermaPropsCompatOriginalRightClick = originalRightClick
    tool.rRadioPermaPropsCompatOriginalReload = originalReload

    function tool:LeftClick( trace )
        local handled = setPermanentFromTool( self, trace, true )
        if handled ~= nil then return handled end

        return originalLeftClick( self, trace )
    end

    function tool:RightClick( trace )
        local handled = setPermanentFromTool( self, trace, false )
        if handled ~= nil then return handled end

        return originalRightClick( self, trace )
    end

    function tool:Reload( trace )
        local handled = updatePermanentFromTool( self, trace )
        if handled ~= nil then return handled end

        return originalReload( self, trace )
    end

    return true
end

function compat.WrapRegisteredTool()
    local toolWeapon = weapons.GetStored( "gmod_tool" )
    local tool = toolWeapon and toolWeapon.Tool and toolWeapon.Tool[TOOL_MODE]
    if not tool then return false end

    return compat.WrapTool( tool )
end

local function wrapPlayerTool( ply )
    if not IsValid( ply ) or not ply.GetTool then return false end

    local tool = ply:GetTool( TOOL_MODE )
    if not tool then return false end

    return compat.WrapTool( tool )
end

local function wrapKnownTools()
    compat.WrapRegisteredTool()

    for _, ply in player.Iterator() do
        wrapPlayerTool( ply )
    end
end

function compat.Init()
    if initialized then return end
    initialized = true

    hook.Add( "PreRegisterTOOL", "rRadio_PermaPropsCompat_PreRegisterTool", function( tool, toolMode )
        if toolMode == TOOL_MODE then compat.WrapTool( tool ) end
    end )

    hook.Add( "CanTool", "rRadio_PermaPropsCompat_WrapActiveTool", function( _player, _trace, toolMode, tool )
        if toolMode == TOOL_MODE then compat.WrapTool( tool ) end
    end )

    hook.Add( "rRadio_PostServerLoad", "rRadio_PermaPropsCompat_WrapKnownTools", wrapKnownTools )

    wrapKnownTools()
    timer.Simple( 0, wrapKnownTools )
end

return compat
