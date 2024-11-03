local Events = {
    -- Stream Events
    STREAM = {
        CREATED = "RadioStreamCreated",
        STARTED = "RadioStreamStarted",
        STOPPED = "RadioStreamStopped",
        ERROR = "RadioStreamError",
        RETRY = "RadioStreamRetry",
        CLEANUP = "RadioStreamCleanup",
        VOLUME_CHANGED = "RadioVolumeChanged",
        POSITION_UPDATED = "RadioPositionUpdated"
    },
    
    -- State Events
    STATE = {
        CHANGED = "RadioStateChanged",
        INITIALIZED = "RadioStateInitialized",
        RESET = "RadioStateReset",
        FAVORITES_CHANGED = "RadioFavoritesChanged",
        FAVORITES_LOADED = "RadioFavoritesLoaded",
        FAVORITES_SAVED = "RadioFavoritesSaved",
        SETTINGS_CHANGED = "RadioSettingsChanged"
    },
    
    -- UI Events
    UI = {
        MENU_OPENED = "RadioMenuOpened",
        MENU_CLOSED = "RadioMenuClosed",
        SETTINGS_OPENED = "RadioSettingsOpened",
        SETTINGS_CLOSED = "RadioSettingsClosed"
    },
    
    -- Entity Events
    ENTITY = {
        VOLUME_CHANGED = "RadioVolumeChanged",
        POSITION_UPDATED = "RadioPositionUpdated",
        REMOVED = "RadioEntityRemoved",
        MUTE_CHANGED = "RadioMuteChanged",
        STATUS_CHANGED = "RadioStatusChanged"
    }
}

return Events 