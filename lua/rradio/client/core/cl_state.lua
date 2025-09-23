if SERVER then return end

local Radio = rRadio
local Interface = Radio.interface

Radio.cl = Radio.cl or {}

Radio.cl.radioSources = Radio.cl.radioSources or {}
Radio.cl.boomboxStatuses = Radio.cl.boomboxStatuses or {}
Radio.cl.connectedStations = Radio.cl.connectedStations or {}
Radio.cl.requestedStations = Radio.cl.requestedStations or {}
Radio.cl.queuedStations = Radio.cl.queuedStations or {}
Radio.cl.playbackNonce = Radio.cl.playbackNonce or {}
Radio.cl.entityVolumes = Radio.cl.entityVolumes or {}
Radio.cl.currentlyPlayingStations = Radio.cl.currentlyPlayingStations or {}
Radio.cl.stationLastPos = Radio.cl.stationLastPos or {}

Radio.cl.uiState = {
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

Radio.cl.timing = {
    lastKeyPress = 0,
    keyPressDelay = 0.2,
    lastStationSelectTime = 0
}

Radio.cl.performance = {
    lastPlayerPos = vector_origin,
    lastStationCount = 0,
    lastEnabled = nil,
    lastMaxVolume = nil,
    volumeChanged = false,
    playerVehicle = nil,
    activeStationCount = 0
}

Radio.cl.pendingVolume = nil
Radio.cl.pendingEntity = nil

Radio.cl.MAX_SEARCH_RESULTS = 150
Radio.cl.Scale = Interface.scale

Radio.cl.cvars = {
    enabled = GetConVar("rammel_rradio_enabled"),
    maxVolume = GetConVar("rammel_rradio_max_volume"),
    menuKey = GetConVar("rammel_rradio_menu_key")
}

Radio.cl.icons = {
    volume = {
        MUTE = Material("hud/vol_mute.png", "smooth"),
        LOW = Material("hud/vol_down.png", "smooth"),
        HIGH = Material("hud/vol_up.png", "smooth")
    },
    star = {
        FULL = Material("hud/star_full.png", "smooth"),
        EMPTY = Material("hud/star.png", "smooth")
    },
    radio = Material("hud/radio.png", "smooth"),
    settings = Material("hud/settings.png", "smooth"),
    settings_b = Material("hud/settings_b.png", "smooth"),
    globe = Material("hud/globe.png", "smooth"),
    europe = Material("hud/europe.png", "smooth")
}