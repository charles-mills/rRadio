rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.properties = rRadio.client.ui.properties or {}

local radioProperties = rRadio.client.ui.properties
local manager = rRadio.client.audio.manager
local favourites = rRadio.client.stations.favourites
local recent = rRadio.client.stations.recent
local catalog = rRadio.client.stations.catalog
local radioState = rRadio.client.radio.state
local QUICK_PLAY_RECENT_LIMIT = 5

local function canManageBoomboxSettings( player )
    local uiState = rRadio.client.ui.state
    if uiState and uiState.canManageConfig == true then return true end

    return IsValid( player ) and player:IsSuperAdmin()
end

local function canShowBoomboxSettings( entity, player )
    return rRadio.util.IsBoombox( entity )
        and canManageBoomboxSettings( player )
end

local function hasUseAllAccess( player )
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

local function getBoomboxOwner( entity )
    if not IsValid( entity ) then return nil end

    if entity.Getowning_ent then
        local owner = entity:Getowning_ent()
        if IsValid( owner ) then return owner end
    end

    if entity.CPPIGetOwner then
        local ok, owner = pcall( entity.CPPIGetOwner, entity )
        if ok and IsValid( owner ) then return owner end
    end

    return nil
end

local function canControlBoombox( entity, player )
    if radioState.IsPublic( entity ) then return true end
    if hasUseAllAccess( player ) then return true end
    if radioState.IsPermanent( entity ) then return false end

    return getBoomboxOwner( entity ) == player
end

local function canControlVehicleRadio( entity, player )
    if hasUseAllAccess( player ) then return true end

    local vehicle = rRadio.vehicle.ResolveRadioHost( entity, player )
    if not IsValid( vehicle ) then return false end

    local playerVehicle = rRadio.vehicle.GetPlayerRadioHost( player )
    if playerVehicle ~= vehicle then return false end

    return not rRadio.config.DriverPlayOnly or rRadio.vehicle.GetDriver( vehicle ) == player
end

local function canControlRadio( entity, player )
    if not rRadio.util.CanUseRadio( entity, player ) then return false end
    if rRadio.util.IsBoombox( entity ) then return canControlBoombox( entity, player ) end

    return canControlVehicleRadio( entity, player )
end

local function getActiveStationID( entity )
    local stationID = radioState.GetStationID( entity )
    if stationID and stationID ~= "" then return stationID end

    return nil
end

local function getFavouriteStationID( entity )
    local stationID = getActiveStationID( entity )
    if not stationID then return nil end

    if not rRadio.client.stations.catalog.Get( stationID ) then return nil end

    return stationID
end

local function setActiveStationFavourite( entity, favourite )
    local stationID = getFavouriteStationID( entity )
    if not stationID then return false end

    return rRadio.client.ui.actions.SetFavouriteStation( stationID, favourite )
end

local function getQuickPlayStations()
    local stations = {}

    for _, stationID in ipairs( recent.ListStationIDs() ) do
        local station = catalog.Get( stationID )
        if station then
            stations[#stations + 1] = station
            if #stations >= QUICK_PLAY_RECENT_LIMIT then break end
        end
    end

    return stations
end

local function hasQuickPlayStations()
    return #getQuickPlayStations() > 0
end

local function playQuickPlayStation( stationID, entity )
    rRadio.client.ui.style.PlaySound( "ButtonPressSecondary" )
    return rRadio.client.ui.actions.PlayStation( stationID, entity )
end

local function addQuickPlayMenuOptions( option, entity )
    local submenu = option:AddSubMenu()

    for _, station in ipairs( getQuickPlayStations() ) do
        local stationID = station.id
        local label = rRadio.net.protocol.LimitDisplayName( station.name, 64 )
        submenu:AddOption( label, function()
            playQuickPlayStation( stationID, entity )
        end )
    end
end

local function addEntityProperties()
    properties.Add( "rradio_quick_play_recents", {
        MenuLabel = rRadio.L( "QuickPlayRecents", "Quick Play Recents" ),
        Order = 9901,
        MenuIcon = "icon16/time.png",
        Filter = function( _self, entity, player )
            return canControlRadio( entity, player )
                and hasQuickPlayStations()
        end,
        MenuOpen = function( _self, option, entity )
            if not canControlRadio( entity, LocalPlayer() ) then return end

            addQuickPlayMenuOptions( option, entity )
        end,
        Action = function()
            return false
        end
    } )

    properties.Add( "rradio_favorite_station", {
        MenuLabel = rRadio.L( "FavoriteStation", "Favorite station" ),
        Order = 9902,
        MenuIcon = "icon16/heart_add.png",
        Filter = function( _self, entity, player )
            if not rRadio.util.CanUseRadio( entity, player ) then return false end

            local stationID = getFavouriteStationID( entity )

            return stationID ~= nil
                and not favourites.IsStationFavourite( stationID )
        end,
        Action = function( _self, entity )
            setActiveStationFavourite( entity, true )
        end
    } )

    properties.Add( "rradio_unfavorite_station", {
        MenuLabel = rRadio.L( "UnfavoriteStation", "Unfavorite station" ),
        Order = 9902,
        MenuIcon = "icon16/heart_delete.png",
        Filter = function( _self, entity, player )
            if not rRadio.util.CanUseRadio( entity, player ) then return false end

            local stationID = getFavouriteStationID( entity )

            return stationID ~= nil
                and favourites.IsStationFavourite( stationID )
        end,
        Action = function( _self, entity )
            setActiveStationFavourite( entity, false )
        end
    } )

    properties.Add( "rradio_copy_station_url", {
        MenuLabel = rRadio.L( "CopyStationToClipboard", "Copy station to clipboard" ),
        Order = 9903,
        MenuIcon = "icon16/page_copy.png",
        Filter = function( _self, entity, player )
            return SetClipboardText ~= nil
                and rRadio.util.CanUseRadio( entity, player )
                and radioState.GetStationURL( entity ) ~= nil
        end,
        Action = function( _self, entity )
            local url = radioState.GetStationURL( entity )
            if not url then return end

            SetClipboardText( url )
        end
    } )

    properties.Add( "rradio_public_boombox", {
        MenuLabel = rRadio.L( "MakeBoomboxPublic", "Make Boombox Public" ),
        Type = "toggle",
        Order = 9910,
        Filter = function( _self, entity, player )
            return canShowBoomboxSettings( entity, player )
        end,
        Checked = function( _self, entity )
            return radioState.IsPublic( entity )
        end,
        Action = function( _self, entity )
            rRadio.client.ui.actions.SetPublic( not radioState.IsPublic( entity ), entity )
        end
    } )

    properties.Add( "rradio_permanent_boombox", {
        MenuLabel = rRadio.L( "MakeBoomboxPermanent", "Make Boombox Permanent" ),
        Type = "toggle",
        Order = 9911,
        Filter = function( _self, entity, player )
            return canShowBoomboxSettings( entity, player )
        end,
        Checked = function( _self, entity )
            return radioState.IsPermanent( entity )
        end,
        Action = function( _self, entity )
            rRadio.client.ui.actions.SetPermanent( not radioState.IsPermanent( entity ), entity )
        end
    } )

    properties.Add( "rradio_mute", {
        MenuLabel = rRadio.L( "Mute", "Mute" ),
        Order = 9900,
        MenuIcon = "icon16/sound_mute.png",
        Filter = function( _self, entity, player )
            return rRadio.util.CanUseRadio( entity, player )
                and not manager.IsMuted( entity )
        end,
        Action = function( _self, entity )
            manager.SetMuted( entity, true )
        end
    } )

    properties.Add( "rradio_unmute", {
        MenuLabel = rRadio.L( "Unmute", "Unmute" ),
        Order = 9900,
        MenuIcon = "icon16/sound.png",
        Filter = function( _self, entity, player )
            return rRadio.util.CanUseRadio( entity, player )
                and manager.IsMuted( entity )
        end,
        Action = function( _self, entity )
            manager.SetMuted( entity, false )
        end
    } )
end

function radioProperties.Init()
    addEntityProperties()

    hook.Add( "rRadio_LanguageChanged", "rRadio_Properties_RefreshLanguage", addEntityProperties )
end

return radioProperties
