rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.keyboard = rRadio.client.ui.menu.keyboard or {}

local keyboard = rRadio.client.ui.menu.keyboard
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local uiKeys = rRadio.client.ui.keys
local list = rRadio.client.ui.menu.list
local viewModel = rRadio.client.ui.menu.viewModel
local favourites = rRadio.client.stations.favourites
local views = viewModel.Views
local menuKeys = uiKeys.Menu

local keyDownState = {}
local keyRepeatAt = {}
local repeatIntervals = {}
local REPEAT_INITIAL_DELAY = 0.28
local REPEAT_FAST_INTERVAL = 0.045
local REPEAT_PAGE_INTERVAL = 0.14
local REPEAT_VOLUME_INTERVAL = 0.08
local menuKeyConVar = GetConVar( "rammel_rradio_menu_key" )


local function setRepeatKey( keyCode, interval )
    if keyCode then repeatIntervals[keyCode] = interval end
end


setRepeatKey( menuKeys.MoveUp, REPEAT_FAST_INTERVAL )
setRepeatKey( menuKeys.MoveDown, REPEAT_FAST_INTERVAL )
setRepeatKey( menuKeys.PageUp, REPEAT_PAGE_INTERVAL )
setRepeatKey( menuKeys.PageDown, REPEAT_PAGE_INTERVAL )
setRepeatKey( menuKeys.VolumeDown, REPEAT_VOLUME_INTERVAL )
setRepeatKey( menuKeys.VolumeUp, REPEAT_VOLUME_INTERVAL )


local function isModifierDown( leftKey, rightKey )
    return ( leftKey and input.IsKeyDown( leftKey ) ) or ( rightKey and input.IsKeyDown( rightKey ) )
end


local function isShiftDown()
    return isModifierDown( menuKeys.LeftShift, menuKeys.RightShift )
end


local function isControlDown()
    return isModifierDown( menuKeys.LeftControl, menuKeys.RightControl )
end


local function isAltDown()
    return isModifierDown( menuKeys.LeftAlt, menuKeys.RightAlt )
end


local function scheduleRepeat( keyCode )
    if repeatIntervals[keyCode] and not keyRepeatAt[keyCode] then
        keyRepeatAt[keyCode] = CurTime() + REPEAT_INITIAL_DELAY
    end
end


local function clearKeyState( keyCode )
    keyDownState[keyCode] = nil
    keyRepeatAt[keyCode] = nil
end


local function isTextInputPanel( panel )
    if not IsValid( panel ) or not panel.GetClassName then return false end

    local className = panel:GetClassName()
    return className == "DTextEntry" or className == "DBinder"
end


function keyboard.HasFocusedTextInput()
    if IsValid( state.searchBox ) and state.searchBox.IsEditing and state.searchBox:IsEditing() then return true end

    local focusedPanel = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    return isTextInputPanel( focusedPanel )
end


local function isStationBrowserVisible()
    if state.viewMode == views.SETTINGS or state.viewMode == views.CUSTOM_MANAGE then return false end

    return IsValid( state.stationListPanel ) and IsValid( state.stationListContainer )
        and state.stationListContainer:IsVisible()
end


local function getVirtualState()
    if not isStationBrowserVisible() then return nil end

    return state.stationListPanel.virtualState
end


local function findEntryIndex( entries, entryKey )
    if not entryKey then return nil end

    for index, entry in ipairs( entries ) do
        if viewModel.GetEntryKey( entry ) == entryKey then return index end
    end

    return nil
end


local function setSelection( index, ensureVisible )
    local virtualState = getVirtualState()
    local entries = virtualState and virtualState.entries
    local count = entries and #entries or 0
    if count <= 0 then
        state.keyboardIndex = nil
        state.keyboardEntryKey = nil
        state.keyboardListKey = virtualState and virtualState.listKey or nil
        if IsValid( state.stationListPanel ) then list.UpdateVisibleRows( state.stationListPanel ) end
        return false
    end

    index = math.Clamp( tonumber( index ) or 1, 1, count )
    state.keyboardIndex = index
    state.keyboardEntryKey = viewModel.GetEntryKey( entries[index] )
    state.keyboardListKey = virtualState.listKey

    if ensureVisible then
        list.EnsureIndexVisible( state.stationListPanel, index )
    else
        list.UpdateVisibleRows( state.stationListPanel )
    end

    return true
end


function keyboard.ResetSelection()
    state.keyboardIndex = nil
    state.keyboardEntryKey = nil
    state.keyboardListKey = nil
end


function keyboard.SyncSelection()
    local virtualState = getVirtualState()
    if not virtualState then
        keyboard.ResetSelection()
        return
    end

    local entries = virtualState.entries or {}
    if #entries <= 0 then
        setSelection( nil, false )
        return
    end

    local sameList = state.keyboardListKey == virtualState.listKey
    local index = sameList and findEntryIndex( entries, state.keyboardEntryKey ) or nil
    if not index then index = sameList and state.keyboardIndex or 1 end

    setSelection( index, false )
end


local function moveSelection( amount )
    local virtualState = getVirtualState()
    local entries = virtualState and virtualState.entries
    if not entries or #entries <= 0 then return false end

    local index = tonumber( state.keyboardIndex ) or 1
    return setSelection( index + amount, true )
end


local function getSelectedEntry()
    local virtualState = getVirtualState()
    local index = tonumber( state.keyboardIndex )
    if not virtualState or not index then return nil end

    return virtualState.entries[index]
end


local function activateEntry( callbacks )
    local entry = getSelectedEntry()
    if not entry then return false end

    if entry.kind == "country" and entry.country then
        callbacks.selectCountry( entry.country.key )
        return true
    end

    if entry.kind == "favorites" then
        callbacks.openFavorites()
        return true
    end

    if entry.kind == "recent" then
        callbacks.openRecents()
        return true
    end

    if entry.kind == "custom_manage" then
        callbacks.openCustomStationManager()
        return true
    end

    if entry.kind == "station" and entry.station then
        callbacks.playStation( entry.station.id )
        return true
    end

    return false
end


local function toggleSelectedFavourite( callbacks )
    local entry = getSelectedEntry()
    if not entry then return false end

    if entry.kind == "country" and entry.country then
        local countryKey = entry.country.key
        if countryKey == ( rRadio.config.CustomStationCategory or "Custom" ) then return false end

        style.PlaySound( "ButtonPressSecondary" )
        favourites.SetCountryFavourite( countryKey, not favourites.IsCountryFavourite( countryKey ) )
        callbacks.refresh()
        return true
    end

    if entry.kind == "station" and entry.station then
        style.PlaySound( "ButtonPressSecondary" )
        callbacks.toggleStationFavourite( entry.station.id )
        return true
    end

    return false
end


local function focusSearch( selectText )
    if not isStationBrowserVisible() or not IsValid( state.searchBox ) then return false end

    state.searchBox:RequestFocus()
    if state.searchBox.SetCaretPos then state.searchBox:SetCaretPos( #state.searchBox:GetText() ) end
    if selectText and state.searchBox.SelectAll then
        state.searchBox:SelectAll()
    elseif selectText and state.searchBox.SelectAllText then
        state.searchBox:SelectAllText( true )
    end

    return true
end


function keyboard.HandleSearchKeyCode( keyCode )
    if keyCode == menuKeys.Favourite and isControlDown() then return focusSearch( true ) end
    if keyCode == menuKeys.Search then return focusSearch( false ) end

    return false
end


local function returnOrBack( callbacks )
    if state.viewMode == views.SETTINGS or state.viewMode == views.CUSTOM_MANAGE then
        callbacks.returnToMainView()
        return true
    end

    if viewModel.CanNavigateBack() then
        callbacks.goBack()
        return true
    end

    return false
end


local function adjustVolume( amount )
    if not IsValid( state.volumePanel ) or not state.volumePanel:IsVisible() then return false end
    if not IsValid( state.volumeSlider ) then return false end

    local maximum = rRadio.config.MaxVolume or 1
    local currentVolume = 0
    if IsValid( state.currentEntity ) then
        currentVolume = rRadio.client.radio.state.GetVolume( state.currentEntity )
    else
        currentVolume = state.volumeSlider:GetValue()
    end

    state.volumeSlider:SetValue( math.Clamp( currentVolume + amount, 0, maximum ) )
    return true
end


function keyboard.HandleKeyCode( keyCode, callbacks )
    if not keyCode then return false end
    if not IsValid( state.frame ) then return false end
    keyDownState[keyCode] = true

    if keyCode == menuKeyConVar:GetInt() then
        callbacks.handleMenuKeyPress()
        return true
    end

    if keyboard.HasFocusedTextInput() then return false end

    if keyCode == menuKeys.MoveUp then
        scheduleRepeat( keyCode )
        return moveSelection( -1 )
    end
    if keyCode == menuKeys.MoveDown then
        scheduleRepeat( keyCode )
        return moveSelection( 1 )
    end
    if keyCode == menuKeys.PageUp then
        scheduleRepeat( keyCode )
        return moveSelection( -list.GetPageStep( state.stationListPanel ) )
    end
    if keyCode == menuKeys.PageDown then
        scheduleRepeat( keyCode )
        return moveSelection( list.GetPageStep( state.stationListPanel ) )
    end
    if keyCode == menuKeys.Home then return setSelection( 1, true ) end
    if keyCode == menuKeys.End then
        local virtualState = getVirtualState()
        return setSelection( virtualState and #virtualState.entries or 1, true )
    end

    if keyCode == menuKeys.Activate
        or keyCode == menuKeys.ActivatePad
        or keyCode == menuKeys.ActivateSpace then
        return activateEntry( callbacks )
    end
    if keyboard.HandleSearchKeyCode( keyCode ) then return true end
    if keyCode == menuKeys.Favourite then return toggleSelectedFavourite( callbacks ) end
    if keyCode == menuKeys.Global and isStationBrowserVisible() then
        callbacks.toggleGlobal()
        return true
    end
    if keyCode == menuKeys.Settings and state.viewMode ~= views.CUSTOM_MANAGE then
        callbacks.toggleSettings()
        return true
    end
    if keyCode == menuKeys.Back then return returnOrBack( callbacks ) end
    if keyCode == menuKeys.VolumeDown and isAltDown() then return returnOrBack( callbacks ) end
    if keyCode == menuKeys.VolumeDown then
        scheduleRepeat( keyCode )
        return adjustVolume( isShiftDown() and -0.1 or -0.05 )
    end
    if keyCode == menuKeys.VolumeUp then
        scheduleRepeat( keyCode )
        return adjustVolume( isShiftDown() and 0.1 or 0.05 )
    end

    return false
end


function keyboard.HandleKeyRelease( keyCode )
    if not keyCode then return end

    clearKeyState( keyCode )
end


function keyboard.UpdateHeldKeys( callbacks )
    if not IsValid( state.frame ) then
        keyDownState = {}
        keyRepeatAt = {}
        return
    end

    for keyCode in pairs( keyDownState ) do
        if not input.IsKeyDown( keyCode ) then
            clearKeyState( keyCode )
        elseif keyRepeatAt[keyCode] and CurTime() >= keyRepeatAt[keyCode] then
            if keyboard.HandleKeyCode( keyCode, callbacks ) then
                keyRepeatAt[keyCode] = CurTime() + repeatIntervals[keyCode]
            else
                keyRepeatAt[keyCode] = nil
            end
        end
    end
end


return keyboard
