rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.rows = rRadio.client.ui.menu.rows or {}

local rows = rRadio.client.ui.menu.rows
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local favourites = rRadio.client.stations.favourites


local function getLeftIconY()
    return ( style.Scale( 40 ) - style.Scale( 24 ) ) / 2
end

local function createRowIcon( parent, material )
    local icon = vgui.Create( "rRadioMenuRowIcon", parent )
    icon:SetPos( style.Scale( 8 ), getLeftIconY() )
    icon:SetIcon( material )

    return icon
end

local function createStar( parent, getter, onToggle )
    local star = vgui.Create( "rRadioMenuStar", parent )
    star:SetPos( style.Scale( 8 ), getLeftIconY() )
    star:SetFavouriteGetter( getter )
    star:SetToggleCallback( onToggle )

    return star
end

local function createButtonRow( parent, entry, icon, onClick )
    local button = vgui.Create( "rRadioMenuButton", parent )
    button:SetTextLabel( entry.label )
    button:SetPlaybackState( nil )
    if icon then button:SetLeftChild( createRowIcon( button, icon ) ) end
    button.DoClick = onClick

    return button
end

local function isCustomCountryKey( countryKey )
    return countryKey == ( rRadio.config.CustomStationCategory or "Custom" )
end


local function getPlaybackStateForPhase( phase )
    local phases = rRadio.client.audio.manager.Phases
    if phase == phases.ERROR then return "error" end
    if phase == phases.CONNECTING then return "tuning" end
    if phase == phases.QUEUED then return "queued" end
    if phase == phases.PLAYING or phase == phases.SILENT_READY then return "playing" end

    return nil
end


local function getStationPlaybackState( station )
    if state.pendingStationID == station.id then return "pending" end

    local entity = rRadio.util.GetRadioEntity( state.currentEntity )
    if not IsValid( entity ) then return nil end

    local manager = rRadio.client.audio.manager
    local presentation = manager.GetStationPresentationState( entity, station.id )
    if presentation then return getPlaybackStateForPhase( presentation.phase ) end

    local assignment = rRadio.client.radio.state.GetAssignment( entity )
    if not assignment or assignment.stationID ~= station.id then return nil end

    return "playing"
end


local function createCountryRow( parent, entry, callbacks )
    local countryKey = entry.country.key
    local onClick = function()
        callbacks.selectCountry( countryKey )
    end

    if isCustomCountryKey( countryKey ) then
        return createButtonRow( parent, entry, style.Materials.writing, onClick )
    end

    local button = createButtonRow( parent, entry, nil, onClick )
    local star = createStar(
        button,
        function()
            return favourites.IsCountryFavourite( countryKey )
        end,
        function()
            favourites.SetCountryFavourite( countryKey, not favourites.IsCountryFavourite( countryKey ) )
            callbacks.refresh()
        end
    )
    button:SetLeftChild( star )

    return button
end


local function createFavoritesRow( parent, entry, callbacks )
    return createButtonRow( parent, entry, style.Materials.bookmark, callbacks.openFavorites )
end


local function createRecentRow( parent, entry, callbacks )
    return createButtonRow( parent, entry, style.Materials.clock, callbacks.openRecents )
end


local function createCustomManageRow( parent, entry, callbacks )
    return createButtonRow( parent, entry, style.Materials.settings, callbacks.openCustomStationManager )
end


local function createStationRow( parent, entry, callbacks )
    local station = entry.station
    local button = createButtonRow( parent, entry, nil, function()
        callbacks.playStation( station.id )
    end )
    local star = createStar(
        button,
        function()
            return favourites.IsStationFavourite( station.id )
        end,
        function()
            callbacks.toggleStationFavourite( station.id )
        end
    )
    button:SetLeftChild( star )
    button.Think = function( panel )
        local playbackState = getStationPlaybackState( station )

        panel:SetPlaybackState( playbackState )
        panel:SetActive(
            playbackState == "pending"
                or playbackState == "tuning"
                or playbackState == "queued"
                or playbackState == "playing"
        )
        panel:SetError( playbackState == "error" )
        local target = ( panel:IsHovered() or panel.keyboardSelected ) and not panel.active and 1 or 0
        panel.lerp = style.ApproachLerp( panel.lerp, target, 10 )
    end

    return button
end


function rows.Create( parent, entry, callbacks )
    local row
    if entry.kind == "country" then
        row = createCountryRow( parent, entry, callbacks )
    elseif entry.kind == "favorites" then
        row = createFavoritesRow( parent, entry, callbacks )
    elseif entry.kind == "recent" then
        row = createRecentRow( parent, entry, callbacks )
    elseif entry.kind == "custom_manage" then
        row = createCustomManageRow( parent, entry, callbacks )
    else
        row = createStationRow( parent, entry, callbacks )
    end

    return row
end


return rows
