if SERVER then return end
rRadio.cl = rRadio.cl or {}
rRadio.cl.radioSources = rRadio.cl.radioSources or {}
rRadio.cl.boomboxStatuses = rRadio.cl.boomboxStatuses or rRadio.cl.BoomboxStatuses or {}
rRadio.cl.connectedStations = rRadio.cl.connectedStations or {}
rRadio.cl.requestedStations = rRadio.cl.requestedStations or {}
rRadio.cl.queuedStations = rRadio.cl.queuedStations or {}
rRadio.cl.playbackNonce = rRadio.cl.playbackNonce or {}
rRadio.cl.entityVolumes = rRadio.cl.entityVolumes or {}
rRadio.cl.currentlyPlayingStations = rRadio.cl.currentlyPlayingStations or {}
rRadio.cl.stationLastPos = rRadio.cl.stationLastPos or {}
rRadio.cl.errorTimestamps = rRadio.cl.errorTimestamps or {}
rRadio.cl.uiState = {
    currentFrame = nil,
    settingsFrame = nil,
    settingsMenuOpen = false,
    favoritesMenuOpen = false,
    radioMenuOpen = false,
    selectedCountry = nil,
    globalView = false,
    lastView = nil,
    isSearching = false,
    goldThemeActive = false,
    permanentCheckboxRef = nil
}

rRadio.cl.timing = {
    lastKeyPress = 0,
    keyPressDelay = 0.2,
    lastStationSelectTime = 0
}

rRadio.cl.performance = {
    lastPlayerPos = vector_origin,
    lastStationCount = 0,
    lastEnabled = nil,
    lastMaxVolume = nil,
    volumeChanged = false,
    playerVehicle = nil,
    activeStationCount = 0
}

function rRadio.cl.cleanupEntity( ent )
    if rRadio.cl.radioSources[ent] then
        if IsValid( rRadio.cl.radioSources[ent] ) then rRadio.cl.radioSources[ent]:Stop() end
        rRadio.cl.radioSources[ent] = nil
    end

    rRadio.cl.currentlyPlayingStations[ent] = nil
    rRadio.cl.queuedStations[ent] = nil
    rRadio.cl.stationLastPos[ent] = nil
    rRadio.cl.playbackNonce[ent] = nil
    rRadio.cl.errorTimestamps[ent] = nil
    rRadio.cl.entityVolumes[ent] = nil
    rRadio.cl.connectedStations[ent] = nil
    rRadio.cl.requestedStations[ent] = nil
    rRadio.cl.mutedBoomboxes[ent] = nil
    if IsValid( ent ) and rRadio.utils.IsBoombox( ent ) then
        local entIndex = ent:EntIndex()
        rRadio.cl.boomboxStatuses[entIndex] = nil
        rRadio.utils.ClearRadioStatus( ent )
        timer.Remove( "rRadio.ErrorClear_" .. entIndex )
        timer.Remove( "rRadio.TuningTimeout_" .. entIndex )
    end
end

rRadio.cl.pendingVolume = nil
rRadio.cl.pendingEntity = nil
rRadio.cl.MAX_SEARCH_RESULTS = 150
rRadio.cl.Scale = rRadio.interface.scaleMenu
rRadio.cl.cvars = {
    enabled = GetConVar( "rammel_rradio_enabled" ),
    maxVolume = GetConVar( "rammel_rradio_max_volume" ),
    menuKey = GetConVar( "rammel_rradio_menu_key" ),
    menuScale = GetConVar( "rammel_rradio_menu_scale" ),
    menuWidthScale = GetConVar( "rammel_rradio_menu_width_scale" )
}

rRadio.cl.menuScale = rRadio.cl.cvars.menuScale and rRadio.cl.cvars.menuScale:GetFloat() or 1
rRadio.cl.menuWidthScale = rRadio.cl.cvars.menuWidthScale and rRadio.cl.cvars.menuWidthScale:GetFloat() or 1
rRadio.cl.icons = {
    volume = {
        MUTE = Material( "hud/vol_mute.png", "smooth" ),
        LOW = Material( "hud/vol_down.png", "smooth" ),
        HIGH = Material( "hud/vol_up.png", "smooth" )
    },
    star = {
        FULL = Material( "hud/star_full.png", "smooth" ),
        EMPTY = Material( "hud/star.png", "smooth" )
    },
    radio = Material( "hud/radio.png", "smooth" ),
    settings = Material( "hud/settings.png", "smooth" ),
    settings_b = Material( "hud/settings_b.png", "smooth" ),
    globe = Material( "hud/globe.png", "smooth" ),
    europe = Material( "hud/europe.png", "smooth" )
}
