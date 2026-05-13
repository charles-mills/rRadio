rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.vehicle = rRadio.client.ui.menu.vehicle or {}

local vehicle = rRadio.client.ui.menu.vehicle
local state = rRadio.client.ui.state

local vehicleMenuKeyWasDown = false
local initialized = false
local MAX_ALIAS_DEPTH = 4
local enabledConVar = GetConVar( "rammel_rradio_enabled" )
local blockKillBindConVar = GetConVar( "rammel_rradio_block_vehicle_kill_bind" )
local menuKeyConVar = GetConVar( "rammel_rradio_menu_key" )


local function getConfiguredMenuKey()
    return menuKeyConVar:GetInt()
end


local function commandRunsKill( command, depth )
    command = tostring( command or "" )
    if command == "" then return false end

    depth = tonumber( depth ) or 0
    for segment in string.gmatch( command .. ";", "([^;]*);" ) do
        local firstToken = segment:match( "^%s*([^%s]+)" )
        if firstToken then
            if string.lower( firstToken ) == "kill" then return true end

            if depth < MAX_ALIAS_DEPTH and input.TranslateAlias then
                local translated = input.TranslateAlias( firstToken )
                if translated
                    and translated ~= ""
                    and translated ~= firstToken
                    and commandRunsKill( translated, depth + 1 )
                then
                    return true
                end
            end
        end
    end

    return false
end


local function hasFocusedTextInput()
    if IsValid( state.searchBox ) and state.searchBox.IsEditing and state.searchBox:IsEditing() then return true end

    local focusedPanel = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    if not IsValid( focusedPanel ) or not focusedPanel.GetClassName then return false end

    local className = focusedPanel:GetClassName()
    return className == "DTextEntry" or className == "DBinder"
end


local function shouldIgnoreMenuKey( player )
    if not IsValid( player ) then return true end
    if player:IsTyping() then return true end

    return hasFocusedTextInput()
end


local function canBypassDriverPlayOnly( player )
    if not IsValid( player ) then return false end
    if player:IsSuperAdmin() then return true end

    local privilegeIds = rRadio.privileges and rRadio.privileges.ID
    local useAllPrivilege = privilegeIds and privilegeIds.UseAll
    if not useAllPrivilege or not CAMI or not CAMI.PlayerHasAccess then return false end

    local ok, allowed = pcall( CAMI.PlayerHasAccess, player, useAllPrivilege, nil, nil, {
        Fallback = "superadmin"
    } )
    return ok and allowed == true
end


local function getPlayerVehicleRadio( player )
    local radioEntity = rRadio.vehicle.GetPlayerRadioHost( player )
    if not IsValid( radioEntity ) then return nil end
    if rRadio.config.DriverPlayOnly
        and rRadio.vehicle.GetDriver( radioEntity ) ~= player
        and not canBypassDriverPlayOnly( player )
    then
        return nil
    end

    return radioEntity
end


function vehicle.HandleMenuKeyPress( player, callbacks )
    if vehicleMenuKeyWasDown then return false end

    vehicleMenuKeyWasDown = true
    if shouldIgnoreMenuKey( player ) then return false end

    if IsValid( state.frame ) then
        callbacks.close()
        return true
    end

    if not enabledConVar:GetBool() then return false end

    local radioEntity = getPlayerVehicleRadio( player )
    if not IsValid( radioEntity ) then return false end

    callbacks.openForEntity( radioEntity )
    return true
end


local function isVehicleKillBindBlocked( player, bind, button )
    if not blockKillBindConVar:GetBool() then return false end
    if not enabledConVar:GetBool() then return false end
    if not IsValid( player ) or player ~= LocalPlayer() then return false end

    local menuKey = getConfiguredMenuKey()
    if button ~= menuKey then return false end

    local command = bind
    if ( not command or command == "" ) and input.LookupKeyBinding then
        command = input.LookupKeyBinding( button )
    end

    if not commandRunsKill( command ) then return false end

    return IsValid( getPlayerVehicleRadio( player ) )
end


function vehicle.Init( callbacks )
    if initialized then return end
    initialized = true

    -- PlayerButtonDown covers multiplayer, while Think covers singleplayer and focused keyboard panels.
    hook.Add( "PlayerButtonDown", "rRadio_Menu_ToggleVehicle", function( player, button )
        if not IsFirstTimePredicted() then return end
        if player ~= LocalPlayer() then return end

        local menuKey = getConfiguredMenuKey()
        if button ~= menuKey then return end

        vehicle.HandleMenuKeyPress( player, callbacks )
    end )

    hook.Add( "PlayerBindPress", "rRadio_Menu_BlockVehicleKillBind", function( player, bind, _pressed, button )
        if not isVehicleKillBindBlocked( player, bind, button ) then return end

        vehicle.HandleMenuKeyPress( player, callbacks )
        return true
    end )

    hook.Add( "Think", "rRadio_Menu_ToggleVehicleFallback", function()
        local menuKey = getConfiguredMenuKey()

        if IsValid( state.frame ) and state.currentEntity ~= nil and not IsValid( state.currentEntity ) then
            callbacks.close()
            return
        end

        local menuOpenForVehicle = IsValid( state.frame )
            and IsValid( state.currentEntity )
            and not rRadio.util.IsBoomboxClass( state.currentEntity:GetClass() )
        if menuOpenForVehicle then
            local player = LocalPlayer()
            local playerRadio = IsValid( player ) and rRadio.vehicle.GetPlayerRadioHost( player ) or nil
            if playerRadio ~= state.currentEntity then callbacks.close() end
        end

        local keyDown = input.IsKeyDown( menuKey )
        if keyDown and not vehicleMenuKeyWasDown then
            vehicle.HandleMenuKeyPress( LocalPlayer(), callbacks )
        end

        if not keyDown then vehicleMenuKeyWasDown = false end
    end )
end


return vehicle
