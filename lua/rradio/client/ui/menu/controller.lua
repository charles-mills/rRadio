rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.controller = rRadio.client.ui.menu.controller or {}

local controller = rRadio.client.ui.menu.controller
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local actions = rRadio.client.ui.actions
local frameModule = rRadio.client.ui.menu.frame
local footer = rRadio.client.ui.menu.footer
local keyboard = rRadio.client.ui.menu.keyboard
local list = rRadio.client.ui.menu.list
local resize = rRadio.client.ui.menu.resize
local customStations = rRadio.client.ui.customStations
local vehicle = rRadio.client.ui.menu.vehicle
local viewModel = rRadio.client.ui.menu.viewModel
local views = viewModel.Views

local SEARCH_TIMER = "rRadio.MenuSearchDebounce"
local frameCloseInProgress = false
local callbacks
local initialized = false
local settingsRebuildQueued = false
local radioStateRefreshQueued = false
local themeConVar = GetConVar( "rammel_rradio_menu_theme" )
local goldThemeConVar = GetConVar( "rammel_rradio_gold_boombox_theme" )
local enabledConVar = GetConVar( "rammel_rradio_enabled" )


local function getCurrentThemeName()
    return rRadio.client.ui.themes.ResolveUserThemeName( themeConVar:GetString() )
end


local function isGoldThemeEnabled()
    return not goldThemeConVar or goldThemeConVar:GetBool()
end


local function shouldUseGoldTheme()
    return IsValid( state.currentEntity )
        and state.currentEntity:GetClass() == rRadio.constants.EntityClasses.GOLDEN_BOOMBOX
        and isGoldThemeEnabled()
end


local function applyEntityTheme()
    state.goldenThemeActive = shouldUseGoldTheme()

    if state.goldenThemeActive then
        rRadio.client.ui.themes.Apply( "gold", { allowExclusive = true } )
        return
    end

    rRadio.client.ui.themes.Apply( getCurrentThemeName() )
end


local function restoreTheme()
    if not state.goldenThemeActive then return end

    state.goldenThemeActive = false
    rRadio.client.ui.themes.Apply( getCurrentThemeName() )
end


local function clearPointerState()
    local dragState = state.dragState
    if dragState and IsValid( dragState.panel ) then dragState.panel:MouseCapture( false ) end

    state.dragState = nil
    state.resizeState = nil
end


local function closeExistingFrame()
    if IsValid( state.settingsFrame ) then
        state.settingsFrame:Remove()
        state.settingsFrame = nil
    end
    if IsValid( state.customStationsFrame ) then
        state.customStationsFrame:Remove()
        state.customStationsFrame = nil
    end
    if state.dialog then
        state.dialog:Remove()
        state.dialog = nil
    end

    local frame = state.frame
    if IsValid( frame ) then frameModule.RememberPosition( frame, true ) end

    state.frame = nil
    if IsValid( frame ) and not frameCloseInProgress then
        frameCloseInProgress = true
        frame:Close()
        frameCloseInProgress = false
    end
end


function controller.Close()
    timer.Remove( SEARCH_TIMER )

    closeExistingFrame()
    restoreTheme()
    state.currentEntity = nil
    state.frameEntity = nil
    state.settingsFrame = nil
    state.customStationsFrame = nil
    state.dialog = nil
    state.searchBox = nil
    state.searchShell = nil
    state.globalButton = nil
    state.stationListPanel = nil
    state.stationListContainer = nil
    state.stopButton = nil
    state.volumePanel = nil
    state.volumeIcon = nil
    state.volumeSlider = nil
    state.selectedCountry = nil
    state.selectedStationID = nil
    state.pendingStationID = nil
    state.lastView = nil
    state.settingsReturnView = nil
    state.customStationsReturnView = nil
    state.canSetBoomboxPublic = false
    state.serverSettingsExpanded = false
    state.viewMode = views.COUNTRIES
    state.searchText = ""
    keyboard.ResetSelection()
    state.headerPanel = nil
    clearPointerState()
    state.resizeHandles = nil
end


local function refreshRows()
    if not IsValid( state.stationListPanel ) then return end

    list.SetEntries(
        state.stationListPanel,
        viewModel.BuildEntries(),
        viewModel.GetListKey(),
        callbacks
    )
    keyboard.SyncSelection()
end


local function refreshOpenMenuTheme()
    if not IsValid( state.frame ) then return end

    style.RefreshPanelTheme( state.frame )
    if IsValid( state.settingsFrame ) then style.RefreshPanelTheme( state.settingsFrame ) end
    if IsValid( state.customStationsFrame ) then style.RefreshPanelTheme( state.customStationsFrame ) end
end


local function removeSettingsPanel()
    if IsValid( state.settingsFrame ) then state.settingsFrame:Remove() end
    state.settingsFrame = nil
end


local function removeCustomStationsPanel()
    if IsValid( state.customStationsFrame ) then state.customStationsFrame:Remove() end
    state.customStationsFrame = nil
end


local function refreshSettingsValues()
    if not IsValid( state.settingsFrame ) or not state.settingsFrame.RefreshValues then return false end

    state.settingsFrame:RefreshValues()
    return true
end


local function queueSettingsRebuild()
    if settingsRebuildQueued then return end

    settingsRebuildQueued = true
    timer.Simple( 0, function()
        settingsRebuildQueued = false
        if not IsValid( state.frame ) or state.viewMode ~= views.SETTINGS then return end

        controller.Refresh( { rebuildSettings = true } )
    end )
end


local function queueRadioStateRefresh( entity )
    if radioStateRefreshQueued then return end
    if not IsValid( state.frame ) then return end

    local currentRadio = rRadio.util.GetRadioEntity( state.currentEntity )
    local changedRadio = rRadio.util.GetRadioEntity( entity )
    if not IsValid( currentRadio ) or currentRadio ~= changedRadio then return end

    radioStateRefreshQueued = true
    timer.Simple( 0, function()
        radioStateRefreshQueued = false
        if not IsValid( state.frame ) then return end

        footer.RefreshVolume()
        if state.viewMode == views.SETTINGS then
            refreshSettingsValues()
            controller.Relayout()
            return
        end

        controller.Refresh()
    end )
end


local function buildSettingsPanel()
    removeSettingsPanel()

    state.settingsFrame = rRadio.client.ui.settings.Build( state.frame, state.currentEntity, {
        onRelayout = function()
            controller.Relayout()
        end,
        onSettingsRebuild = queueSettingsRebuild,
        onThemeChanged = function()
            applyEntityTheme()
        end
    } )

    controller.Relayout()
end


local function showSettingsPanel( rebuild )
    if rebuild or not IsValid( state.settingsFrame ) then
        buildSettingsPanel()
        return
    end

    state.settingsFrame:SetVisible( true )
    state.settingsFrame:MoveToFront()
    controller.Relayout()
end


local function buildCustomStationsPanel()
    removeCustomStationsPanel()

    state.customStationsFrame = customStations.Build( state.frame )
    controller.Relayout()
end


local function showCustomStationsPanel( rebuild )
    if rebuild or not IsValid( state.customStationsFrame ) then
        buildCustomStationsPanel()
        return
    end

    if state.customStationsFrame.Refresh then state.customStationsFrame:Refresh() end
    state.customStationsFrame:SetVisible( true )
    state.customStationsFrame:MoveToFront()
    controller.Relayout()
end


function controller.Refresh( options )
    if not IsValid( state.frame ) then return end

    if type( options ) ~= "table" then options = {} end
    if state.viewMode == views.CUSTOM_MANAGE and not state.canManageCustomStations then
        state.viewMode = views.COUNTRIES
        state.selectedCountry = nil
        state.customStationsReturnView = nil
    end

    if IsValid( state.globalButton ) then state.globalButton:SetText( rRadio.L( "Global", "GLOBAL" ) ) end
    if IsValid( state.stopButton ) then state.stopButton:SetText( rRadio.L( "StopRadio", "STOP" ) ) end
    if IsValid( state.searchBox ) then
        state.searchBox:SetPlaceholderText( rRadio.L( "SearchPlaceholder", "Search..." ) )
    end

    local settingsOpen = state.viewMode == views.SETTINGS
    local customStationsOpen = state.viewMode == views.CUSTOM_MANAGE
    local alternateOpen = settingsOpen or customStationsOpen
    frameModule.SetSearchVisible( not alternateOpen )
    frameModule.SetListVisible( not alternateOpen )
    frameModule.SetFooterVisible( not alternateOpen )
    frameModule.RefreshSettingsToggleButton()
    frameModule.RefreshBackButton()

    if settingsOpen then
        removeCustomStationsPanel()
        showSettingsPanel( options.rebuildSettings == true )
        if options.refreshSettingsValues == true then refreshSettingsValues() end
        return
    end

    removeSettingsPanel()

    if customStationsOpen then
        showCustomStationsPanel( options.rebuildCustomStations == true )
        return
    end

    removeCustomStationsPanel()

    refreshRows()
end


local function queueSearchRefresh()
    state.searchText = viewModel.GetSearchText()
    local delay = rRadio.config.SearchDebounceSeconds or 0.1
    timer.Create( SEARCH_TIMER, delay, 1, controller.Refresh )
end


local function selectCountry( countryKey )
    style.PlaySound( "ButtonPressMain" )
    state.viewMode = views.COUNTRY
    state.selectedCountry = countryKey
    viewModel.ClearSearch()
    controller.Refresh()
end


local function openFavorites()
    style.PlaySound( "ButtonPressMain" )
    state.viewMode = views.FAVORITES
    state.selectedCountry = nil
    viewModel.ClearSearch()
    controller.Refresh()
end


local function openRecents()
    style.PlaySound( "ButtonPressMain" )
    state.viewMode = views.RECENTS
    state.selectedCountry = nil
    viewModel.ClearSearch()
    controller.Refresh()
end


local function toggleGlobalView()
    style.PlaySound( "ButtonPressMain" )

    if state.viewMode ~= views.GLOBAL then
        state.lastView = viewModel.SaveView()
        state.viewMode = views.GLOBAL
        state.selectedCountry = nil
        viewModel.ClearSearch()
    else
        viewModel.RestoreView( state.lastView )
        state.lastView = nil
    end

    controller.Refresh()
end


local function returnToMainView()
    if state.viewMode == views.SETTINGS then
        if IsValid( state.settingsFrame ) then
            state.settingsFrame:Remove()
            state.settingsFrame = nil
        end

        viewModel.RestoreView( state.settingsReturnView )
        state.settingsReturnView = nil
    elseif state.viewMode == views.CUSTOM_MANAGE then
        if IsValid( state.customStationsFrame ) then
            state.customStationsFrame:Remove()
            state.customStationsFrame = nil
        end

        viewModel.RestoreView( state.customStationsReturnView )
        state.customStationsReturnView = nil
    end

    controller.Refresh()
end


local function goBack()
    if state.viewMode == views.SETTINGS or state.viewMode == views.CUSTOM_MANAGE then
        returnToMainView()
        return
    elseif state.viewMode == views.GLOBAL and state.lastView then
        viewModel.RestoreView( state.lastView )
        state.lastView = nil
    else
        state.viewMode = views.COUNTRIES
        state.selectedCountry = nil
        viewModel.ClearSearch()
    end

    controller.Refresh()
end


local function openCustomStationManager()
    if not state.canManageCustomStations then return end

    style.PlaySound( "ButtonPressMain" )
    state.customStationsReturnView = viewModel.SaveView()
    state.viewMode = views.CUSTOM_MANAGE
    viewModel.ClearSearch()
    controller.Refresh()
end


local function toggleSettings()
    if state.viewMode == views.SETTINGS then
        returnToMainView()
        return
    end

    state.settingsReturnView = viewModel.SaveView()
    state.viewMode = views.SETTINGS
    controller.Refresh()
end


local function stopRadio()
    style.PlaySound( "ButtonPressSecondary" )
    actions.Stop()
end


local function playStation( stationID )
    style.PlaySound( "ButtonPressSecondary" )
    return actions.PlayStation( stationID )
end


local function toggleStationFavourite( stationID )
    actions.ToggleFavouriteStation( stationID )
    if state.viewMode == views.FAVORITES or state.viewMode == views.COUNTRY then controller.Refresh() end
end


local function createCallbacks()
    callbacks = {
        refresh = controller.Refresh,
        relayout = controller.Relayout,
        selectCountry = selectCountry,
        openFavorites = openFavorites,
        openRecents = openRecents,
        toggleGlobal = toggleGlobalView,
        toggleSettings = toggleSettings,
        returnToMainView = returnToMainView,
        openCustomStationManager = openCustomStationManager,
        goBack = goBack,
        close = controller.Close,
        playStation = playStation,
        toggleStationFavourite = toggleStationFavourite,
        setVolume = actions.SetVolume,
        stop = stopRadio,
        rememberPosition = frameModule.RememberPosition,
        setPosition = frameModule.SetPosition,
        queueSearchRefresh = queueSearchRefresh,
        handleMenuKeyPress = function()
            vehicle.HandleMenuKeyPress( LocalPlayer(), callbacks )
        end,
        updateResize = function( frame )
            resize.Update( frame, callbacks )
        end,
        onFrameClose = function()
            frameCloseInProgress = true
            controller.Close()
            frameCloseInProgress = false
        end,
        openForEntity = function( entity )
            state.currentEntity = entity
            controller.Open()
        end
    }
end


function controller.Relayout( options )
    if not IsValid( state.frame ) then return end
    if type( options ) ~= "table" then options = {} end

    style.RefreshFonts()

    local frame = state.frame
    local oldX, oldY = frame:GetPos()
    local oldCenterX = oldX + frame:GetWide() * 0.5
    local oldCenterY = oldY + frame:GetTall() * 0.5
    local width, height = style.GetFrameSize()
    frame:SetSize( width, height )

    local persistPosition = options.persistPosition == true
    if options.preserveTopLeft then
        frameModule.SetPosition( frame, oldX, oldY, persistPosition )
    else
        frameModule.SetPosition( frame, oldCenterX - width * 0.5, oldCenterY - height * 0.5, persistPosition )
    end

    local margin = style.Scale( 10 )
    local gap = style.Scale( 5 )
    local navSize = style.Scale( 25 )
    local headerTop = style.Scale( 7 )
    local searchTop = style.Scale( 50 )
    local searchHeight = style.Scale( 30 )
    local globalWidth = style.Scale( 80 )
    local footerTop = height - style.Scale( 90 )
    local stopWidth = style.Scale( rRadio.config.FrameSize.width or 600 ) / 4
    local stopHeight = style.Scale( rRadio.config.FrameSize.width or 600 ) / 8
    local listTop = style.Scale( 90 )
    local listHeight = height - style.Scale( 190 )
    local navX = width - margin - navSize

    state.closeButton:SetPos( navX, headerTop )
    state.closeButton:SetSize( navSize, navSize )
    navX = navX - navSize - gap
    state.settingsButton:SetPos( navX, headerTop )
    state.settingsButton:SetSize( navSize, navSize )
    navX = navX - navSize - gap
    state.backButton:SetPos( navX, headerTop )
    state.backButton:SetSize( navSize, navSize )

    local searchWidth = width - margin * 2 - globalWidth - gap
    state.searchShell:SetPos( margin, searchTop )
    state.searchShell:SetSize( searchWidth, searchHeight )
    state.globalButton:SetPos( margin + searchWidth + gap, searchTop )
    state.globalButton:SetSize( globalWidth, searchHeight )
    state.globalButton:SetFont( style.GetButtonFillFont( state.globalButton:GetText(), globalWidth, searchHeight ) )

    state.stationListContainer:SetPos( margin, listTop )
    state.stationListContainer:SetSize( width - margin * 2, listHeight )
    if IsValid( state.stationListPanel ) then list.UpdateVisibleRows( state.stationListPanel ) end

    footer.Relayout( {
        width = width,
        height = height,
        margin = margin,
        footerTop = footerTop,
        stopWidth = stopWidth,
        stopHeight = stopHeight
    } )

    if IsValid( state.settingsFrame ) then
        state.settingsFrame:SetPos( margin, style.Scale( 50 ) )
        state.settingsFrame:SetSize( width - margin * 2, height - style.Scale( 60 ) )
    end

    if IsValid( state.customStationsFrame ) then
        state.customStationsFrame:SetPos( margin, style.Scale( 50 ) )
        state.customStationsFrame:SetSize( width - margin * 2, height - style.Scale( 60 ) )
    end

    frameModule.RelayoutHeader( width )
    resize.RelayoutHandles( frame )
end


function controller.Open()
    if not enabledConVar:GetBool() then return end
    if hook.Run( "rRadio_CanOpenMenu", LocalPlayer(), state.currentEntity ) == false then return end
    if state.dialog then
        state.dialog:Remove()
        state.dialog = nil
    end

    actions.SyncEntityState( state.currentEntity, "menu_open", {
        force = true,
        immediate = true
    } )

    if IsValid( state.frame ) and state.frameEntity == state.currentEntity then
        state.frame:MakePopup()
        return
    end

    if IsValid( state.frame ) then
        closeExistingFrame()
        restoreTheme()
    end

    style.SyncScaleFromConVars()
    applyEntityTheme()
    state.viewMode = views.COUNTRIES
    state.selectedCountry = nil
    state.searchText = ""
    keyboard.ResetSelection()
    state.lastView = nil
    state.settingsReturnView = nil
    state.customStationsReturnView = nil
    state.frame = frameModule.Create( callbacks )
    state.frameEntity = state.currentEntity

    footer.Create( state.frame, callbacks )
    resize.CreateHandles( state.frame )
    controller.Relayout()
    controller.Refresh()
    frameModule.QueueInitialCursorPlacement( state.frame )
end


function controller.Init()
    if initialized then return end
    initialized = true

    style.RefreshFonts()
    createCallbacks()

    hook.Add( "EntityRemoved", "rRadio_Menu_CloseRemovedEntity", function( entity )
        if state.currentEntity ~= entity then
            local currentRadio = rRadio.util.GetRadioEntity( state.currentEntity )
            local removedRadio = rRadio.util.GetRadioEntity( entity )
            if not IsValid( currentRadio ) or currentRadio ~= removedRadio then return end
        end

        controller.Close()
    end )

    vehicle.Init( callbacks )

    hook.Add( "rRadio_LanguageChanged", "rRadio_Menu_RefreshLanguage", function()
        controller.Refresh( { rebuildSettings = true } )
    end )

    hook.Add( "rRadio_ThemeChanged", "rRadio_Menu_RefreshTheme", function( _themeName, _theme, options )
        if not IsValid( state.frame ) then return end
        if state.goldenThemeActive
            and shouldUseGoldTheme()
            and not ( type( options ) == "table" and options.allowExclusive == true )
        then
            applyEntityTheme()
            return
        end

        if type( options ) == "table" and options.preview then
            refreshOpenMenuTheme()
            return
        end

        controller.Refresh( { rebuildSettings = true } )
    end )

    cvars.AddChangeCallback( "rammel_rradio_gold_boombox_theme", function()
        if not IsValid( state.frame ) then return end

        applyEntityTheme()
    end, "rRadio_Menu_GoldThemeChanged" )

    hook.Add( "rRadio_ConfigChanged", "rRadio_Menu_RefreshConfig", function( _id, options )
        if not IsValid( state.frame ) then return end

        if state.viewMode == views.SETTINGS then
            if type( options ) == "table" and options.permissionsChanged then
                controller.Refresh( { rebuildSettings = true } )
                return
            end

            refreshSettingsValues()
            controller.Relayout()
            return
        end

        controller.Refresh()
    end )

    hook.Add( "rRadio_ClientRadioStateChanged", "rRadio_Menu_RefreshRadioState", function( entity )
        queueRadioStateRefresh( entity )
    end )

    hook.Add( "OnScreenSizeChanged", "rRadio_Menu_ClampPosition", function()
        if not IsValid( state.frame ) then return end

        clearPointerState()
        controller.Relayout( { preserveTopLeft = true, persistPosition = true } )
    end )

    cvars.AddChangeCallback( "rammel_rradio_enabled", function( _name, _oldValue, newValue )
        if tonumber( newValue ) == 0 then controller.Close() end
    end, "rRadio_Menu_CloseWhenDisabled" )
end


return controller
