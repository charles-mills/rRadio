rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.state = rRadio.client.ui.state or {
    currentEntity = nil,
    frameEntity = nil,
    frame = nil,
    menuPosition = nil,
    settingsFrame = nil,
    customStationsFrame = nil,
    dialog = nil,
    viewMode = "countries",
    lastView = nil,
    settingsReturnView = nil,
    customStationsReturnView = nil,
    searchText = "",
    keyboardIndex = nil,
    keyboardEntryKey = nil,
    keyboardListKey = nil,
    selectedCountry = nil,
    selectedStationID = nil,
    pendingStationID = nil,
    stationLimit = 150,
    resizeState = nil,
    menuScale = 1,
    menuWidthScale = 1,
    goldenThemeActive = false,
    canSetBoomboxPublic = false,
    canManageCustomStations = false,
    canManageConfig = false,
    serverSettingsExpanded = false,
    customStationNotice = nil
}

return rRadio.client.ui.state
