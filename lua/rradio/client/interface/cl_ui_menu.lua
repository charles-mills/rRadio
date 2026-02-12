if SERVER then return end
local Scale = rRadio.cl.Scale
local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local icons = rRadio.cl.icons
local cvars = rRadio.cl.cvars
local RESIZE_HANDLE_SIZE = 12
local CORNER_RESIZE_SEGMENTS = 12
local cornerResizePolyCache = {}
local cornerResizePolyCacheSize = 0
local MAX_CORNER_RESIZE_POLY_CACHE = 128
local VIRTUAL_SCROLL_THRESHOLD = 120
local VIRTUAL_OVERSCAN_ROWS = 8
local INITIAL_RESULTS_LIMIT = 100
local LOAD_MORE_STEP = 100
local cornerResizeKeys = {
    tl = true,
    tr = true,
    bl = true,
    br = true
}

local function paintMainControl( w, h, fillColor )
    if rRadio.interface.DrawBorderedRoundedBox then
        rRadio.interface.DrawBorderedRoundedBox(
            rRadio.interface.GetControlCornerRadius(),
            0, 0, w, h, fillColor
        )
        return
    end

    draw.RoundedBox( 8, 0, 0, w, h, fillColor )
end

local function getSearchTextInset()
    return math.max( 10, Scale( 12 ) )
end

local function setSearchBoxVisible( searchBox, visible )
    if not IsValid( searchBox ) then return end
    if IsValid( searchBox.shell ) then
        searchBox.shell:SetVisible( visible )
    end

    searchBox:SetVisible( visible )
end

local function createTieredContainerPanel( parent )
    local panel = vgui.Create( "DPanel", parent )
    panel.Paint = function( _self, w, h )
        paintMainControl(
            w,
            h,
            rRadio.interface.GetSurfaceColor( "panel" )
                or rRadio.config.UI.HeaderColor
        )
    end
    return panel
end

local function configureTieredScrollPanel( scrollPanel, canvasRightPadding )
    if not IsValid( scrollPanel ) then return end
    scrollPanel:Dock( FILL )
    scrollPanel:DockMargin( Scale( 6 ), Scale( 6 ), Scale( 6 ), Scale( 6 ) )
    scrollPanel:SetPaintBackground( false )
    rRadio.interface.StyleVBar( scrollPanel:GetVBar() )
    local canvas = scrollPanel:GetCanvas()
    if IsValid( canvas ) and canvas.DockPadding then
        canvas:DockPadding( 0, 0, canvasRightPadding or 0, Scale( 6 ) )
    end
end

local function isCornerResizeKey( resizeKey )
    return cornerResizeKeys[resizeKey] == true
end

local function anyResizeHandleHovered( frame )
    if not frame.resizeHandles then return false end
    for _, panel in pairs( frame.resizeHandles ) do
        if IsValid( panel ) and panel:IsHovered() then return true end
    end
    return false
end

local function getCornerResizePolys( resizeKey, w, h )
    local cacheKey = resizeKey .. ":" .. tostring( w ) .. ":" .. tostring( h )
    if cornerResizePolyCache[cacheKey] then return cornerResizePolyCache[cacheKey] end
    local radius = math.max( 1, math.min( w, h ) - 1 )
    local cx, cy, startDeg, endDeg
    if resizeKey == "tl" then
        cx, cy, startDeg, endDeg = 0, 0, 0, 90
    elseif resizeKey == "tr" then
        cx, cy, startDeg, endDeg = w - 1, 0, 90, 180
    elseif resizeKey == "br" then
        cx, cy, startDeg, endDeg = w - 1, h - 1, 180, 270
    else
        cx, cy, startDeg, endDeg = 0, h - 1, 270, 360
    end

    local poly = {
        { x = cx, y = cy }
    }
    local step = ( endDeg - startDeg ) / CORNER_RESIZE_SEGMENTS
    for i = 0, CORNER_RESIZE_SEGMENTS do
        local a = math.rad( startDeg + step * i )
        poly[#poly + 1] = {
            x = cx + math.cos( a ) * radius,
            y = cy + math.sin( a ) * radius
        }
    end

    if cornerResizePolyCacheSize >= MAX_CORNER_RESIZE_POLY_CACHE then
        cornerResizePolyCache = {}
        cornerResizePolyCacheSize = 0
    end
    cornerResizePolyCache[cacheKey] = poly
    cornerResizePolyCacheSize = cornerResizePolyCacheSize + 1
    return poly
end

local function drawCornerResizeGrip( resizeKey, w, h, color )
    local poly = getCornerResizePolys( resizeKey, w, h )
    draw.NoTexture()
    surface.SetDrawColor( color )
    surface.DrawPoly( poly )
end

local function setButtonState( button, enabled )
    if not IsValid( button ) then return end
    button:SetVisible( enabled )
    button:SetEnabled( enabled )
end

local function syncBackButton( backButton )
    setButtonState( backButton, uiState.settingsMenuOpen
        or uiState.globalView
        or uiState.selectedCountry ~= nil and uiState.selectedCountry ~= "" )
end

local function addItems( panel, items )
    for _, item in ipairs( items or {} ) do
        if item.SetViewportPaintCulling then
            item:SetViewportPaintCulling( true, panel )
        end
        panel:Add( item )
    end
end

local function clearVirtualStationRows( stationListPanel )
    local state = stationListPanel and stationListPanel.virtualState
    if not state then return end
    for _, row in pairs( state.rows or {} ) do
        if IsValid( row ) then row:Remove() end
    end
    if IsValid( state.spacer ) then state.spacer:Remove() end
    stationListPanel.virtualState = nil
end

local function getHeaderIcon()
    if uiState.settingsMenuOpen then return icons.settings_b end
    if uiState.globalView then return icons.globe end
    if not uiState.selectedCountry then return icons.europe end
    if uiState.selectedCountry == "favorites" then return icons.star.EMPTY end
    return icons.radio
end

local function getHeaderText()
    if uiState.settingsMenuOpen then return rRadio.L( "Settings", "Settings" ) end
    if uiState.selectedCountry == "favorites" then return rRadio.L( "FavoriteStations", "Favorite Stations" ) end
    if uiState.selectedCountry then return rRadio.utils.FormatAndTranslateCountry( uiState.selectedCountry ) end
    return rRadio.L( "SelectCountry", "Select Country" )
end

local function getBaseFrameSize()
    return rRadio.interface.scale( rRadio.config.FrameSize.width ),
        rRadio.interface.scale( rRadio.config.FrameSize.height )
end

local function getScaledFrameSize()
    local width = Scale( rRadio.config.FrameSize.width ) * rRadio.interface.GetMenuWidthScale()
    local height = Scale( rRadio.config.FrameSize.height )
    return width, height
end

local function prepareList( stationListPanel, searchBox, resetSearch )
    clearVirtualStationRows( stationListPanel )
    stationListPanel:Clear()
    searchBox = searchBox or uiState.searchBox
    if not IsValid( searchBox ) then
        uiState.isSearching = false
        return ""
    end

    if resetSearch then searchBox:SetText( "" ) end
    return searchBox:GetText():lower()
end

local function filterGlobalList( rawList, filterText, searchStage, topK )
    if filterText == "" then return rawList, #rawList end
    local filtered, total = rRadio.interface.fuzzyFilter(
        filterText,
        rawList,
        function( item ) return item.searchText end,
        0,
        nil,
        searchStage,
        topK
    )
    return filtered, total or #filtered
end

local function createLoadMoreEntryButton( parent, entry )
    local btn = vgui.Create( "rRadioButton", parent )
    local label = rRadio.Lf(
        "LoadMoreProgress",
        {
            shown = entry.shown or 0,
            total = entry.total or 0
        },
        "Load More ({shown}/{total})"
    )
    btn:SetTextLabel( label )
    btn.DoClick = function()
        rRadio.interface.playSound( "ButtonPressMain" )
        if isfunction( entry.onClick ) then entry.onClick() end
    end
    return btn
end

local function addStationEntryButtons( parent, entries, updateCallback )
    for i = 1, #entries do
        local entry = entries[i]
        local btn
        if entry.kind == "load_more" then
            btn = createLoadMoreEntryButton( parent, entry )
        else
            if entry.countryKey then entry.station.countryKey = entry.countryKey end
            btn = rRadio.cl.uiComponents.createPlayableStationButton(
                parent, entry.station, entry.displayKey, updateCallback
            )
        end
        if btn.SetViewportPaintCulling then
            btn:SetViewportPaintCulling( true, parent )
        end
        parent:Add( btn )
    end
end

local function getResultsWindowKey( filterText )
    if uiState.globalView then return "global:" .. ( filterText or "" ) end
    if uiState.selectedCountry then return "country:" .. tostring( uiState.selectedCountry ) .. ":" .. ( filterText or "" ) end
    return nil
end

local function limitGlobalEntriesForWindow( stationListPanel, filtered, filteredTotal, filterText, refreshFn )
    local key = getResultsWindowKey( filterText )
    if not key then
        stationListPanel.resultsWindowState = nil
        return filtered
    end

    local total = filteredTotal or #filtered
    local state = stationListPanel.resultsWindowState
    local limit = total
    if total > INITIAL_RESULTS_LIMIT then
        if not state or state.key ~= key then
            state = {
                key = key,
                limit = math.min( INITIAL_RESULTS_LIMIT, total )
            }
            stationListPanel.resultsWindowState = state
        end
        local minimumWindow = math.min( INITIAL_RESULTS_LIMIT, total )
        if state.limit < minimumWindow then state.limit = minimumWindow end
        if state.limit > total then state.limit = total end

        limit = math.min( state.limit, total )
    else
        stationListPanel.resultsWindowState = {
            key = key,
            limit = total
        }
    end

    if limit >= total then return filtered end
    local out = {}
    for i = 1, limit do
        out[i] = filtered[i]
    end

    out[#out + 1] = {
        kind = "load_more",
        shown = limit,
        total = total,
        onClick = function()
            state.limit = math.min( total, state.limit + LOAD_MORE_STEP )
            local scroll = 0
            local vbar = stationListPanel:GetVBar()
            if IsValid( vbar ) then scroll = vbar:GetScroll() or 0 end
            refreshFn( {
                preserveScroll = true,
                scroll = scroll
            } )
        end
    }
    return out
end

local function getRequestedResultsLimit( stationListPanel, filterText )
    local key = getResultsWindowKey( filterText )
    if not key then return nil end
    local state = stationListPanel.resultsWindowState
    if not state or state.key ~= key then return INITIAL_RESULTS_LIMIT end
    local limit = tonumber( state.limit ) or INITIAL_RESULTS_LIMIT
    limit = math.floor( limit )
    return math.max( INITIAL_RESULTS_LIMIT, limit )
end

local function limitEntriesForWindow( stationListPanel, entries, filterText, refreshFn )
    local key = getResultsWindowKey( filterText )
    if not key then
        stationListPanel.resultsWindowState = nil
        return entries
    end

    local total = #entries
    if total <= INITIAL_RESULTS_LIMIT then
        stationListPanel.resultsWindowState = {
            key = key,
            limit = total
        }
        return entries
    end

    local state = stationListPanel.resultsWindowState
    if not state or state.key ~= key then
        state = {
            key = key,
            limit = math.min( INITIAL_RESULTS_LIMIT, total )
        }
        stationListPanel.resultsWindowState = state
    end
    local minimumWindow = math.min( INITIAL_RESULTS_LIMIT, total )
    if state.limit < minimumWindow then state.limit = minimumWindow end
    if state.limit > total then state.limit = total end

    local limit = math.min( state.limit, total )
    local out = {}
    for i = 1, limit do
        out[i] = entries[i]
    end

    if limit < total then
        out[#out + 1] = {
            kind = "load_more",
            shown = limit,
            total = total,
            onClick = function()
                state.limit = math.min( total, state.limit + LOAD_MORE_STEP )
                local scroll = 0
                local vbar = stationListPanel:GetVBar()
                if IsValid( vbar ) then scroll = vbar:GetScroll() or 0 end
                refreshFn( {
                    preserveScroll = true,
                    scroll = scroll
                } )
            end
        }
    end
    return out
end

local function updateVirtualStationRows( stationListPanel, state )
    if not IsValid( stationListPanel ) then return end
    local canvas = stationListPanel:GetCanvas()
    local vbar = stationListPanel:GetVBar()
    if not IsValid( canvas ) or not IsValid( vbar ) then return end
    if not IsValid( state.spacer ) then
        local spacer = vgui.Create( "DPanel", canvas )
        spacer:Dock( TOP )
        spacer:SetTall( 0 )
        spacer:SetMouseInputEnabled( false )
        spacer.Paint = nil
        state.spacer = spacer
    end
    local spacer = state.spacer
    local count = #state.entries
    local rowHeight = Scale( 40 )
    local rowGap = Scale( 5 )
    local rowStride = rowHeight + rowGap
    local topPad = Scale( 5 )
    local sidePad = Scale( 5 )
    local scroll = vbar:GetScroll()
    local viewHeight = stationListPanel:GetTall()
    local totalHeight = 0
    if count > 0 then totalHeight = topPad + rowHeight + ( count - 1 ) * rowStride end
    local targetCanvasTall = math.max( viewHeight, totalHeight )
    if state.canvasTall ~= targetCanvasTall then
        state.canvasTall = targetCanvasTall
        spacer:SetTall( targetCanvasTall )
        stationListPanel:InvalidateLayout( true )
    end
    if count == 0 then return end
    local first = math.max( 1, math.floor( scroll / rowStride ) + 1 - VIRTUAL_OVERSCAN_ROWS )
    local last = math.min( count, math.floor( ( scroll + viewHeight ) / rowStride ) + 1 + VIRTUAL_OVERSCAN_ROWS )

    for idx, row in pairs( state.rows ) do
        if idx < first or idx > last or not IsValid( row ) then
            if IsValid( row ) then row:Remove() end
            state.rows[idx] = nil
        end
    end

    local rowWidth = math.max( 0, canvas:GetWide() - sidePad * 2 )
    local noDock = NODOCK or 0
    for idx = first, last do
        local row = state.rows[idx]
        if not IsValid( row ) then
            local entry = state.entries[idx]
            if entry and entry.kind == "load_more" then
                row = createLoadMoreEntryButton( canvas, entry )
            else
                if entry and entry.countryKey then entry.station.countryKey = entry.countryKey end
                row = rRadio.cl.uiComponents.createPlayableStationButton(
                    canvas,
                    entry.station,
                    entry.displayKey,
                    state.updateCallback
                )
            end
            if row.SetViewportPaintCulling then
                row:SetViewportPaintCulling( true, stationListPanel )
            end
            row:Dock( noDock )
            row:DockMargin( 0, 0, 0, 0 )
            state.rows[idx] = row
        end

        row:SetPos( sidePad, topPad + ( idx - 1 ) * rowStride )
        row:SetSize( rowWidth, rowHeight )
    end
end

local function setVirtualStationRows( stationListPanel, entries, updateCallback, restoreScroll )
    stationListPanel.virtualState = {
        rows = {},
        entries = entries,
        updateCallback = updateCallback,
        canvasTall = nil,
        lastScroll = nil,
        lastTall = nil,
        lastCanvasWide = nil
    }
    local vbar = stationListPanel:GetVBar()
    if IsValid( vbar ) then vbar:SetScroll( math.max( 0, restoreScroll or 0 ) ) end
    updateVirtualStationRows( stationListPanel, stationListPanel.virtualState )
end

local function restoreScrollIfRequested( stationListPanel, opts )
    if not opts or not opts.preserveScroll then return end
    local scroll = math.max( 0, opts.scroll or 0 )
    timer.Simple( 0, function()
        if not IsValid( stationListPanel ) then return end
        local vbar = stationListPanel:GetVBar()
        if IsValid( vbar ) then vbar:SetScroll( scroll ) end
    end )
end

function rRadio.cl.populateList( stationListPanel, backButton, searchBox, resetSearch, opts )
    if not IsValid( stationListPanel ) then return end
    opts = opts or {}
    local searchStage = opts.searchStage or "fuzzy"
    if not IsValid( backButton ) and uiState.currentFrame then backButton = uiState.currentFrame.backButton end
    searchBox = searchBox or uiState.searchBox
    local function updateKeep( nextOpts )
        nextOpts = nextOpts or {}
        if nextOpts.searchStage == nil then nextOpts.searchStage = searchStage end
        rRadio.cl.populateList( stationListPanel, backButton, searchBox, false, nextOpts )
    end

    local function updateClear( nextOpts )
        nextOpts = nextOpts or {}
        if nextOpts.searchStage == nil then nextOpts.searchStage = searchStage end
        rRadio.cl.populateList( stationListPanel, backButton, searchBox, true, nextOpts )
    end

    local filterText = prepareList( stationListPanel, searchBox, resetSearch )
    if uiState.globalView then
        local rawList = rRadio.cl.globalSearchIndex or {}
        local requestedLimit = getRequestedResultsLimit( stationListPanel, filterText )
        local filtered, filteredTotal = filterGlobalList(
            rawList, filterText, searchStage, requestedLimit
        )
        local stationEntries = limitGlobalEntriesForWindow(
            stationListPanel, filtered, filteredTotal, filterText, updateKeep
        )
        if #stationEntries >= VIRTUAL_SCROLL_THRESHOLD then
            setVirtualStationRows(
                stationListPanel,
                stationEntries,
                updateKeep,
                opts.preserveScroll and opts.scroll or nil
            )
        else
            addStationEntryButtons( stationListPanel, stationEntries, updateKeep )
        end
        setButtonState( backButton, true )
        restoreScrollIfRequested( stationListPanel, opts )
        return
    end

    if not uiState.selectedCountry then
        addItems( stationListPanel, rRadio.cl.uiComponents.populateFavorites( stationListPanel, updateClear ) )
        addItems( stationListPanel, rRadio.cl.uiComponents.populateCountries(
            stationListPanel, filterText, updateClear, searchStage
        ) )
    else
        local stationEntries = rRadio.cl.uiComponents.collectStationEntries(
            uiState.selectedCountry,
            filterText,
            searchStage
        )
        stationEntries = limitEntriesForWindow( stationListPanel, stationEntries, filterText, updateKeep )
        if #stationEntries >= VIRTUAL_SCROLL_THRESHOLD then
            setVirtualStationRows(
                stationListPanel,
                stationEntries,
                updateKeep,
                opts.preserveScroll and opts.scroll or nil
            )
        else
            addStationEntryButtons( stationListPanel, stationEntries, updateKeep )
        end
    end

    restoreScrollIfRequested( stationListPanel, opts )
    syncBackButton( backButton )
end

function rRadio.cl.openSettingsMenu( parentFrame, backButton, selectedTheme )
    if IsValid( uiState.settingsFrame ) then uiState.settingsFrame:Remove() end
    uiState.settingsFrame = vgui.Create( "DPanel", parentFrame )
    uiState.settingsFrame:SetVisible( true )
    uiState.settingsFrame:SetSize(
        parentFrame:GetWide() - Scale( 20 ),
        parentFrame:GetTall() - Scale( 50 ) - Scale( 10 )
    )
    uiState.settingsFrame:SetPos( Scale( 10 ), Scale( 50 ) )
    uiState.settingsFrame.Paint = function( _self, w, h )
        local frameSurface = rRadio.interface.GetSurfaceColor( "frame" )
            or rRadio.config.UI.BackgroundColor
        local bodyHeight = h
        if IsValid( _self.footer ) then
            bodyHeight = math.max(
                Scale( 40 ),
                _self.footer:GetY()
            )
        end

        bodyHeight = math.Clamp( bodyHeight, 0, h )
        if bodyHeight >= h - 1 then
            draw.RoundedBox( 10, 0, 0, w, h, frameSurface )
            return
        end

        draw.RoundedBoxEx(
            10, 0, 0, w, bodyHeight,
            frameSurface,
            true, true, false, false
        )
    end

    rRadio.cl.settingsUI.buildFooter( uiState.settingsFrame )
    local contentPanel = createTieredContainerPanel( uiState.settingsFrame )
    uiState.settingsFrame.settingsContentPanel = contentPanel
    contentPanel:Dock( FILL )
    contentPanel:DockMargin( 0, Scale( 8 ), 0, Scale( 8 ) )

    local scrollPanel = vgui.Create( "DScrollPanel", contentPanel )
    uiState.settingsFrame.settingsScrollPanel = scrollPanel
    configureTieredScrollPanel( scrollPanel, Scale( 14 ) )
    rRadio.cl.settingsUI.addThemeSelector( scrollPanel, parentFrame, backButton, selectedTheme )
    rRadio.cl.settingsUI.addKeyBindSelector( scrollPanel )
    rRadio.cl.settingsUI.addMenuScaleOptions( scrollPanel, parentFrame )
    rRadio.cl.settingsUI.addAudioOptions( scrollPanel )
    rRadio.cl.settingsUI.addGeneralOptions( scrollPanel )
    rRadio.cl.settingsUI.addSuperadminOptions( scrollPanel, LocalPlayer().currentRadioEntity )
    if isfunction( uiState.settingsFrame.LayoutFooter ) then uiState.settingsFrame:LayoutFooter() end
end

local function refreshScaledMenuContent( frame )
    if not IsValid( frame ) then return end
    if uiState.settingsMenuOpen then
        rRadio.cl.openSettingsMenu( frame, frame.backButton, GetConVar( "rammel_rradio_menu_theme" ):GetString() )
        return
    end

    if IsValid( frame.stationListPanel ) then
        rRadio.cl.populateList(
            frame.stationListPanel, frame.backButton,
            frame.searchBox, false
        )
    end
end

local function layoutResizeHandles( frame )
    if not frame.resizeHandles then return end
    local handleSize = Scale( RESIZE_HANDLE_SIZE )
    local sideThickness = math.max( Scale( 4 ), math.floor( handleSize * 0.45 ) )
    local sideLength = math.max( handleSize * 3, Scale( 72 ) )
    local w, h = frame:GetWide(), frame:GetTall()
    local sideY = math.floor( ( h - sideLength ) / 2 )
    local positions = {
        tl = {
            x = 0,
            y = 0,
            w = handleSize,
            h = handleSize
        },
        tr = {
            x = w - handleSize,
            y = 0,
            w = handleSize,
            h = handleSize
        },
        bl = {
            x = 0,
            y = h - handleSize,
            w = handleSize,
            h = handleSize
        },
        br = {
            x = w - handleSize,
            y = h - handleSize,
            w = handleSize,
            h = handleSize
        },
        l = {
            x = 0,
            y = sideY,
            w = sideThickness,
            h = sideLength
        },
        r = {
            x = w - sideThickness,
            y = sideY,
            w = sideThickness,
            h = sideLength
        }
    }

    for key, panel in pairs( frame.resizeHandles ) do
        local pos = positions[key]
        if IsValid( panel ) and pos then
            panel:SetSize( pos.w, pos.h )
            panel:SetPos( pos.x, pos.y )
        end
    end
end

local function updateSizedButtonFonts( frame )
    if IsValid( frame.globalButton ) then
        local text = rRadio.L( "Global", "GLOBAL" )
        frame.globalButton:SetText( text )
        frame.globalButton:SetFont(
            rRadio.interface.calculateFontSizeForGlobalButton(
                text, frame.globalButton:GetWide(),
                frame.globalButton:GetTall()
            )
        )
    end

    if IsValid( frame.stopButton ) then
        local text = rRadio.L( "StopRadio", "STOP" )
        frame.stopButton:SetText( text )
        frame.stopButton:SetFont(
            rRadio.interface.calculateFontSizeForStopButton(
                text, frame.stopButton:GetWide(),
                frame.stopButton:GetTall()
            )
        )
    end
end

local function layoutRadioFrame( frame )
    if not IsValid( frame ) then return end
    frame:SetSize( getScaledFrameSize() )
    local frameW, frameH = frame:GetWide(), frame:GetTall()
    local margin = Scale( 5 )
    local navButtonSize = Scale( 25 )
    local navTop = Scale( 7 )
    local navPadding = Scale( 5 )
    local navX = frameW - navButtonSize - Scale( 10 )
    local searchY = Scale( 50 )
    local searchX = Scale( 10 )
    local fullWidth = frameW - Scale( 20 )
    local globalWidth = Scale( 80 )
    local searchWidth = fullWidth - globalWidth - margin
    local listY = Scale( 90 )
    local listHeight = frameH - Scale( 200 )
    local stopY = frameH - Scale( 90 )
    local stopWidth = Scale( rRadio.config.FrameSize.width ) / 4
    local stopHeight = Scale( rRadio.config.FrameSize.width ) / 8
    if IsValid( frame.searchBox ) then
        if IsValid( frame.searchBox.shell ) then
            frame.searchBox.shell:SetPos( searchX, searchY )
            frame.searchBox.shell:SetSize( searchWidth, Scale( 30 ) )
            frame.searchBox:DockMargin( getSearchTextInset(), 0, Scale( 6 ), 0 )
        else
            frame.searchBox:SetPos( searchX, searchY )
            frame.searchBox:SetSize( searchWidth, Scale( 30 ) )
            if frame.searchBox.SetTextInset then
                frame.searchBox:SetTextInset( getSearchTextInset(), 0 )
            end
        end

        frame.searchBox:SetFont( "rRadio.Roboto5" )
    end

    if IsValid( frame.globalButton ) then
        frame.globalButton:SetPos( searchX + searchWidth + margin, searchY )
        frame.globalButton:SetSize( globalWidth, Scale( 30 ) )
    end

    if IsValid( frame.stationListContainer ) then
        frame.stationListContainer:SetPos( Scale( 10 ), listY )
        frame.stationListContainer:SetSize( frameW - Scale( 20 ), listHeight )
    end

    if IsValid( frame.stationListPanel ) then
        if frame.stationListPanel.DockMargin then
            frame.stationListPanel:DockMargin( Scale( 6 ), Scale( 6 ), Scale( 6 ), Scale( 6 ) )
        end

        rRadio.interface.StyleVBar( frame.stationListPanel:GetVBar() )
    end

    if IsValid( frame.closeButton ) then
        frame.closeButton:SetSize( navButtonSize, navButtonSize )
        frame.closeButton:SetPos( navX, navTop )
        navX = navX - navButtonSize - navPadding
    end

    if IsValid( frame.settingsButton ) then
        frame.settingsButton:SetSize( navButtonSize, navButtonSize )
        frame.settingsButton:SetPos( navX, navTop )
        navX = navX - navButtonSize - navPadding
    end

    if IsValid( frame.backButton ) then
        frame.backButton:SetSize( navButtonSize, navButtonSize )
        frame.backButton:SetPos( navX, navTop )
    end

    if IsValid( frame.stopButton ) then
        frame.stopButton:SetPos( Scale( 10 ), stopY )
        frame.stopButton:SetSize( stopWidth, stopHeight )
    end

    if IsValid( frame.volumePanel ) then
        frame.volumePanel:SetPos( Scale( 20 ) + stopWidth, stopY )
        frame.volumePanel:SetSize( frameW - Scale( 30 ) - stopWidth, stopHeight )
    end

    if IsValid( frame.volumeIcon ) and IsValid( frame.volumePanel ) then
        local iconSize = Scale( 50 )
        local iconPadding = Scale( 10 )
        frame.volumeIcon:SetSize( iconSize, iconSize )
        frame.volumeIcon:SetPos( iconPadding, ( frame.volumePanel:GetTall() - iconSize ) / 2 )
    end

    if IsValid( frame.volumeSlider ) and IsValid( frame.volumePanel ) then
        local iconPadding = Scale( 10 )
        local iconSize = Scale( 50 )
        local sliderLeft = iconPadding + iconSize + Scale( 3 )
        local sliderTop = Scale( 6 )
        local sliderRightPadding = Scale( 12 )
        local sliderHeight = math.max( Scale( 16 ), frame.volumePanel:GetTall() - sliderTop * 2 )
        local sliderWidth = math.max( Scale( 80 ), frame.volumePanel:GetWide() - sliderLeft - sliderRightPadding )
        frame.volumeSlider:SetPos( sliderLeft, sliderTop )
        frame.volumeSlider:SetSize( sliderWidth, sliderHeight )
        if IsValid( frame.volumeSlider.TextArea ) then frame.volumeSlider.TextArea:SetWide( 0 ) end
        if IsValid( frame.volumeSlider.Label ) then frame.volumeSlider.Label:SetWide( 0 ) end
        if IsValid( frame.volumeSlider.Slider ) and IsValid( frame.volumeSlider.Slider.Knob ) then
            local knobSize = math.max( Scale( 12 ), math.floor( frame.volumePanel:GetTall() * 0.48 ) )
            frame.volumeSlider.Slider.Knob:SetSize( knobSize, knobSize )
        end
    end

    if IsValid( uiState.settingsFrame ) then
        uiState.settingsFrame:SetSize( frameW - Scale( 20 ), frameH - Scale( 50 ) - Scale( 10 ) )
        uiState.settingsFrame:SetPos( Scale( 10 ), Scale( 50 ) )
        if isfunction( uiState.settingsFrame.LayoutFooter ) then uiState.settingsFrame:LayoutFooter() end
    end

    updateSizedButtonFonts( frame )
    layoutResizeHandles( frame )
end

local function cleanupRadioMenu()
    if timer.Exists( "rRadio.SearchDebounce" ) then timer.Remove( "rRadio.SearchDebounce" ) end
    uiState.radioMenuOpen = false
    uiState.settingsMenuOpen = false
    uiState.favoritesMenuOpen = false
    uiState.selectedCountry = nil
    uiState.globalView = false
    uiState.lastView = nil
    if IsValid( uiState.settingsFrame ) then uiState.settingsFrame:Remove() end
    uiState.currentFrame = nil
    if uiState.goldThemeActive then
        rRadio.interface.loadSavedSettings()
        uiState.goldThemeActive = false
    end
end

local function getCornerScale( corner, state, mouseX, mouseY )
    local dx = mouseX - state.startMouseX
    local dy = mouseY - state.startMouseY
    local newWidth = state.startW
    local newHeight = state.startH
    if corner == "br" then
        newWidth = state.startW + dx
        newHeight = state.startH + dy
    elseif corner == "tr" then
        newWidth = state.startW + dx
        newHeight = state.startH - dy
    elseif corner == "bl" then
        newWidth = state.startW - dx
        newHeight = state.startH + dy
    elseif corner == "tl" then
        newWidth = state.startW - dx
        newHeight = state.startH - dy
    end

    local baseW, baseH = getBaseFrameSize()
    local scaleW = newWidth / ( baseW * state.startWidthScale )
    local scaleH = newHeight / baseH
    return rRadio.interface.ClampMenuScale( ( scaleW + scaleH ) * 0.5 )
end

local function getHorizontalWidthScale( resizeKey, state, mouseX )
    local dx = mouseX - state.startMouseX
    local newWidth = state.startW
    if resizeKey == "r" then
        newWidth = state.startW + dx
    elseif resizeKey == "l" then
        newWidth = state.startW - dx
    end

    local baseW = getBaseFrameSize()
    local baseWidthAtScale = baseW * state.startScale
    return rRadio.interface.ClampMenuWidthScale( newWidth / baseWidthAtScale )
end

local function setFramePositionForResize( frame, resizeKey, state )
    local newW, newH = frame:GetWide(), frame:GetTall()
    if resizeKey == "br" then
        frame:SetPos( state.startX, state.startY )
    elseif resizeKey == "tr" then
        frame:SetPos( state.startX, state.startY + state.startH - newH )
    elseif resizeKey == "bl" then
        frame:SetPos( state.startX + state.startW - newW, state.startY )
    elseif resizeKey == "tl" then
        frame:SetPos( state.startX + state.startW - newW, state.startY + state.startH - newH )
    elseif resizeKey == "l" then
        frame:SetPos( state.startX + state.startW - newW, state.startY )
    elseif resizeKey == "r" then
        frame:SetPos( state.startX, state.startY )
    end
end

local function beginMenuResize( frame, resizeKey, mode )
    if frame.resizeState then return end
    local startX, startY = frame:GetPos()
    frame.resizeState = {
        resizeKey = resizeKey,
        mode = mode or "uniform",
        startMouseX = gui.MouseX(),
        startMouseY = gui.MouseY(),
        startX = startX,
        startY = startY,
        startW = frame:GetWide(),
        startH = frame:GetTall(),
        startScale = rRadio.interface.GetMenuScale(),
        startWidthScale = rRadio.interface.GetMenuWidthScale()
    }

    frame:SetDraggable( false )
end

local function finishMenuResize( frame, persist )
    if not frame.resizeState then return end
    frame.resizeState = nil
    frame:SetDraggable( true )
    if persist then
        rRadio.interface.SetMenuScale( rRadio.interface.GetMenuScale(), true )
        rRadio.interface.SetMenuWidthScale( rRadio.interface.GetMenuWidthScale(), true )
    end

    refreshScaledMenuContent( frame )
end

local function createResizeHandle( frame, resizeKey, cursor, mode )
    local handle = vgui.Create( "DButton", frame )
    handle:SetText( "" )
    handle:SetCursor( cursor )
    handle:SetPaintBackground( false )
    handle.Paint = function( self, w, h )
        local active = frame.resizeState and frame.resizeState.resizeKey == resizeKey
        local hovered = self:IsHovered()
        local groupVisible = anyResizeHandleHovered( frame ) or frame.resizeState ~= nil
        local subtle = mode == "horizontal" or resizeKey == "tl" or resizeKey == "br"
        if not ( hovered or active or subtle or groupVisible ) then return end
        local alpha = ( hovered or active ) and 35 or groupVisible and 20 or 12
        local shade = ColorAlpha( rRadio.config.UI.ScrollbarGripColor, alpha )
        if mode == "horizontal" then
            draw.RoundedBox( 4, 0, 0, w, h, shade )
            return
        end

        if isCornerResizeKey( resizeKey ) then drawCornerResizeGrip( resizeKey, w, h, shade ) end
    end

    handle.OnMousePressed = function( _, code )
        if code ~= MOUSE_LEFT then return end
        beginMenuResize( frame, resizeKey, mode )
    end
    return handle
end

local function addResizeHandles( frame )
    frame.resizeHandles = {
        tl = createResizeHandle( frame, "tl", "sizenwse", "uniform" ),
        tr = createResizeHandle( frame, "tr", "sizenesw", "uniform" ),
        bl = createResizeHandle( frame, "bl", "sizenesw", "uniform" ),
        br = createResizeHandle( frame, "br", "sizenwse", "uniform" ),
        l = createResizeHandle( frame, "l", "sizewe", "horizontal" ),
        r = createResizeHandle( frame, "r", "sizewe", "horizontal" )
    }

    layoutResizeHandles( frame )
end

local function createRadioFrame()
    local frame = vgui.Create( "DFrame" )
    frame:SetTitle( "" )
    frame:SetSize( getScaledFrameSize() )
    frame:Center()
    frame:SetDraggable( true )
    frame:ShowCloseButton( false )
    frame:MakePopup()
    local oldThink = frame.Think
    local oldKeyPress = frame.OnKeyCodePressed
    frame.OnKeyCodePressed = function( self, code )
        local menuKey = cvars.menuKey:GetInt()
        if code == menuKey then
            if CurTime() - timing.lastKeyPress <= timing.keyPressDelay then return end
            rRadio.cl.toggleCarRadioMenu()
            timing.lastKeyPress = CurTime()
            return
        end

        if oldKeyPress then oldKeyPress( self, code ) end
    end

    frame.OnClose = function() cleanupRadioMenu() end
    frame.Think = function( self )
        if oldThink then oldThink( self ) end
        local state = self.resizeState
        if not state then return end
        if not input.IsMouseDown( MOUSE_LEFT ) then
            finishMenuResize( self, true )
            return
        end

        if state.mode == "horizontal" then
            local nextWidthScale = getHorizontalWidthScale( state.resizeKey, state, gui.MouseX() )
            if math.abs( nextWidthScale - state.startWidthScale ) < 0.001 then return end
            state.startWidthScale = nextWidthScale
            rRadio.interface.SetMenuWidthScale( nextWidthScale, false )
            layoutRadioFrame( self )
            setFramePositionForResize( self, state.resizeKey, state )
            return
        end

        local nextScale = getCornerScale( state.resizeKey, state, gui.MouseX(), gui.MouseY() )
        if math.abs( nextScale - state.startScale ) < 0.001 then return end
        state.startScale = nextScale
        rRadio.interface.SetMenuScale( nextScale, false )
        layoutRadioFrame( self )
        setFramePositionForResize( self, state.resizeKey, state )
    end

    frame.Paint = function( _self, w, h )
        draw.RoundedBox(
            8, 0, 0, w, h,
            rRadio.interface.GetSurfaceColor( "frame" )
                or rRadio.config.UI.BackgroundColor
        )
        draw.RoundedBoxEx(
            8, 0, 0, w, Scale( 40 ),
            rRadio.config.UI.HeaderColor,
            true, true, false, false
        )
        local headerHeight = Scale( 40 )
        local iconSize = Scale( 25 )
        local iconOffsetX = Scale( 10 )
        local iconOffsetY = headerHeight / 2 - iconSize / 2
        local icon = getHeaderIcon()
        surface.SetMaterial( icon )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        surface.DrawTexturedRect( iconOffsetX, iconOffsetY, iconSize, iconSize )
        draw.SimpleText(
            getHeaderText(), "rRadio.Roboto8",
            iconOffsetX + iconSize + Scale( 5 ),
            headerHeight / 2 + Scale( 2 ),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end
    return frame
end

local function createStationListPanel( frame )
    local container = createTieredContainerPanel( frame )
    container:SetPos( Scale( 10 ), Scale( 90 ) )
    container:SetSize( frame:GetWide() - Scale( 20 ), frame:GetTall() - Scale( 200 ) )
    container:SetVisible( not uiState.settingsMenuOpen )

    local panel = vgui.Create( "DScrollPanel", container )
    configureTieredScrollPanel( panel, 0 )
    local oldThink = panel.Think
    panel.Think = function( self )
        if oldThink then oldThink( self ) end
        local state = self.virtualState
        if not state then return end
        local canvas = self:GetCanvas()
        local vbar = self:GetVBar()
        if not IsValid( canvas ) or not IsValid( vbar ) then return end
        local scroll = vbar:GetScroll()
        local tall = self:GetTall()
        local canvasWide = canvas:GetWide()
        if scroll == state.lastScroll and tall == state.lastTall and canvasWide == state.lastCanvasWide then return end
        state.lastScroll = scroll
        state.lastTall = tall
        state.lastCanvasWide = canvasWide
        updateVirtualStationRows( self, state )
    end
    panel.container = container
    return panel
end

local function createSearchBox( parent, width, onChange )
    local shell = vgui.Create( "DPanel", parent )
    shell:SetPos( Scale( 10 ), Scale( 50 ) )
    shell:SetSize( width, Scale( 30 ) )
    shell.Paint = function( _self, w, h )
        paintMainControl( w, h, rRadio.config.UI.SearchBoxColor )
    end

    local searchBox = vgui.Create( "DTextEntry", shell )
    searchBox:Dock( FILL )
    searchBox:DockMargin( getSearchTextInset(), 0, Scale( 6 ), 0 )
    searchBox:SetFont( "rRadio.Roboto5" )
    searchBox:SetPlaceholderText( rRadio.L( "SearchPlaceholder", "Search" ) )
    searchBox:SetPaintBackground( false )
    searchBox:SetDrawBorder( false )
    searchBox:SetTextColor( rRadio.config.UI.TextColor )
    searchBox:SetCursorColor( rRadio.config.UI.TextColor )
    searchBox:SetHighlightColor( Color( 120, 120, 120 ) )
    searchBox:SetPlaceholderColor( ColorAlpha( rRadio.config.UI.TextColor, 150 ) )

    searchBox.OnGetFocus = function() uiState.isSearching = true end
    searchBox.OnLoseFocus = function() uiState.isSearching = false end
    searchBox.OnValueChange = function() onChange() end
    searchBox.OnChange = searchBox.OnValueChange
    searchBox.shell = shell
    return searchBox
end

local function createGlobalButton( parent, searchBox, width )
    local margin = Scale( 5 )
    local height = Scale( 30 )
    local text = rRadio.L( "Global", "GLOBAL" )
    local font = rRadio.interface.calculateFontSizeForGlobalButton( text, width, height )
    local btn = vgui.Create( "DButton", parent )
    local anchor = IsValid( searchBox.shell ) and searchBox.shell or searchBox
    btn:SetText( text )
    btn:SetFont( font )
    btn:SetTextColor( rRadio.config.UI.TextColor )
    btn:SetPos( anchor:GetX() + anchor:GetWide() + margin, anchor:GetY() )
    btn:SetSize( width, height )
    btn.lerp = 0
    btn.lerpColor = Color( 0, 0, 0, 255 )
    btn.Think = function( self )
        local tgt = ( self:IsHovered() or uiState.globalView ) and 1 or 0
        self.lerp = rRadio.interface.ApproachLerp( self.lerp, tgt, 10 )
    end

    btn.Paint = function( self, w, h )
        local col = rRadio.interface.LerpColor(
            self.lerp, rRadio.config.UI.ButtonColor,
            rRadio.config.UI.ButtonHoverColor,
            self.lerpColor
        )
        paintMainControl( w, h, col )
    end
    return btn
end

local function queueSearchRefresh( stationListPanel, searchBox )
    if not IsValid( stationListPanel ) then return end
    rRadio.cl.populateList(
        stationListPanel,
        nil,
        searchBox,
        false,
        {
            searchStage = "fast"
        }
    )
    local timerName = "rRadio.SearchDebounce"
    local delay = rRadio.config.SearchDebounceSeconds
    if timer.Exists( timerName ) then
        timer.Adjust( timerName, delay )
        return
    end

    timer.Create( timerName, delay, 1, function()
        if not IsValid( stationListPanel ) or not uiState.isSearching then return end
        rRadio.cl.populateList(
            stationListPanel,
            nil,
            searchBox,
            false,
            {
                searchStage = "fuzzy"
            }
        )
    end )
end

local function createSearchControls( frame, stationListPanel )
    local margin = Scale( 5 )
    local btnWidth = Scale( 80 )
    local fullWidth = frame:GetWide() - Scale( 20 )
    local searchBox
    searchBox = createSearchBox(
        frame, fullWidth - btnWidth - margin,
        function() queueSearchRefresh( stationListPanel, searchBox ) end
    )
    local globalBtn = createGlobalButton( frame, searchBox, btnWidth )
    setSearchBoxVisible( searchBox, not uiState.settingsMenuOpen )
    uiState.searchBox = searchBox
    return searchBox, globalBtn
end

local function createNavButton( parent, x, y, icon, callback )
    local btn = vgui.Create( "rRadioNavButton", parent )
    btn:SetPos( x, y )
    btn:SetIcon( icon )
    btn:SetCallback( callback )
    return btn
end

local function withMenuCloseSound( fn )
    return function( ... )
        rRadio.interface.playSound( "MenuClosed" )
        fn( ... )
    end
end

local function createNavigationButtons( frame, stationListPanel, searchBox )
    local buttons = {}
    local buttonSize = Scale( 25 )
    local topMargin = Scale( 7 )
    local buttonPadding = Scale( 5 )
    local xPos = frame:GetWide() - buttonSize - Scale( 10 )
    buttons.close = createNavButton(
        frame, xPos, topMargin, "hud/close.png",
        withMenuCloseSound( function() frame:Close() end )
    )
    xPos = xPos - buttonSize - buttonPadding
    buttons.settings = createNavButton( frame, xPos, topMargin, "hud/settings.png", withMenuCloseSound( function()
        uiState.settingsMenuOpen = true
        rRadio.cl.openSettingsMenu( frame, buttons.back, nil )
        setButtonState( buttons.back, true )
        setSearchBoxVisible( searchBox, false )
        stationListPanel:SetVisible( false )
        if IsValid( stationListPanel.container ) then stationListPanel.container:SetVisible( false ) end
    end ) )

    xPos = xPos - buttonSize - buttonPadding
    buttons.back = createNavButton( frame, xPos, topMargin, "hud/return.png", withMenuCloseSound( function()
        if uiState.settingsMenuOpen then
            uiState.settingsMenuOpen = false
            if IsValid( uiState.settingsFrame ) then
                uiState.settingsFrame:Remove()
                uiState.settingsFrame = nil
            end

            if IsValid( searchBox ) then setSearchBoxVisible( searchBox, true ) end
            stationListPanel:SetVisible( true )
            if IsValid( stationListPanel.container ) then stationListPanel.container:SetVisible( true ) end
        else
            uiState.globalView = false
            uiState.lastView = nil
            uiState.selectedCountry = nil
            uiState.favoritesMenuOpen = false
        end

        rRadio.cl.populateList( stationListPanel, buttons.back, searchBox, true )
    end ) )

    buttons.back:MoveToFront()
    buttons.settings:MoveToFront()
    buttons.close:MoveToFront()
    syncBackButton( buttons.back )
    return buttons
end

local function createStopButton( frame, stationListPanel, backButton, searchBox )
    local height = Scale( rRadio.config.FrameSize.width ) / 8
    local width = Scale( rRadio.config.FrameSize.width ) / 4
    local text = rRadio.L( "StopRadio", "STOP" )
    local font = rRadio.interface.calculateFontSizeForStopButton( text, width, height )
    local btn = vgui.Create( "rRadioAnimatedButton", frame )
    btn:SetPos( Scale( 10 ), frame:GetTall() - Scale( 90 ) )
    btn:SetSize( width, height )
    btn:SetText( text )
    btn:SetFont( font )
    btn:SetColors(
        rRadio.config.UI.TextColor,
        rRadio.config.UI.CloseButtonColor,
        rRadio.config.UI.CloseButtonHoverColor
    )
    btn.DoClick = function()
        rRadio.interface.playSound( "ButtonPressSecondary" )
        local entity = LocalPlayer().currentRadioEntity
        if IsValid( entity ) then
            net.Start( "rRadio.StopStation" )
            net.WriteEntity( entity )
            net.SendToServer()
            rRadio.cl.currentlyPlayingStations[entity] = nil
            rRadio.cl.populateList( stationListPanel, backButton, searchBox, false )
            syncBackButton( backButton )
        end
    end
    return btn
end

local function createVolumeControls( frame, stopButton )
    local stopButtonWidth = stopButton:GetWide()
    local stopButtonHeight = stopButton:GetTall()
    local panel = vgui.Create( "DPanel", frame )
    panel:SetPos( Scale( 20 ) + stopButtonWidth, frame:GetTall() - Scale( 90 ) )
    panel:SetSize( frame:GetWide() - Scale( 30 ) - stopButtonWidth, stopButtonHeight )
    panel.Paint = function( _self, w, h )
        paintMainControl( w, h, rRadio.config.UI.CloseButtonColor )
    end
    local iconSize = Scale( 50 )
    local icon = vgui.Create( "DImage", panel )
    icon:SetPos( Scale( 10 ), ( panel:GetTall() - iconSize ) / 2 )
    icon:SetSize( iconSize, iconSize )
    icon:SetMaterial( rRadio.interface.GetVolumeIcon( 1.0 ) )
    icon.Paint = function( self, w, h )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        local mat = self:GetMaterial()
        if mat then
            surface.SetMaterial( mat )
            surface.DrawTexturedRect( 0, 0, w, h )
        end
    end

    local entity = LocalPlayer().currentRadioEntity
    local currentVolume
    if IsValid( entity ) then
        local entityConfig = rRadio.utils.GetEntityConfig( entity )
        local defaultVolume = entityConfig and entityConfig.Volume or 0.5
        currentVolume = entity:GetNWFloat( "Volume", defaultVolume )
        rRadio.cl.entityVolumes[entity] = currentVolume
        currentVolume = math.min( currentVolume, rRadio.config.MaxVolume or 1.0 )
    else
        currentVolume = 0.5
    end

    rRadio.cl.updateVolumeIcon( icon, rRadio.interface.ClampVolume( currentVolume ) )
    local slider = vgui.Create( "DNumSlider", panel )
    slider:SetText( "" )
    slider:SetMin( 0 )
    slider:SetMax( rRadio.config.MaxVolume or 1.0 )
    slider:SetDecimals( 2 )
    slider:SetValue( currentVolume )
    slider.TextArea:SetVisible( false )
    slider.TextArea:SetWide( 0 )
    if IsValid( slider.Label ) then
        slider.Label:SetVisible( false )
        slider.Label:SetWide( 0 )
    end

    rRadio.interface.styleSliderPaint( slider, 0.26 )
    slider.OnValueChanged = function( _self, value )
        if not IsValid( entity ) then return end
        local ent = entity
        if not rRadio.utils.IsBoombox( ent ) then ent = rRadio.utils.GetVehicle( ent ) end
        if not IsValid( ent ) then return end
        local maxVol = rRadio.config.MaxVolume or 1.0
        value = math.min( value, maxVol )
        rRadio.cl.entityVolumes[ent] = value
        rRadio.interface.refreshVolume( ent )
        rRadio.cl.updateVolumeIcon( icon, rRadio.interface.ClampVolume( value ) )
        if rRadio.cl.performance then rRadio.cl.performance.volumeChanged = true end
        rRadio.cl.pendingVolume = value
        rRadio.cl.pendingEntity = ent
    end

    local origRelease = slider.Slider.OnMouseReleased
    slider.Slider.OnMouseReleased = function( _self, mcode )
        if origRelease then origRelease( _self, mcode ) end
        rRadio.cl.sendPendingVolume()
    end
    return panel, icon, slider
end

local function validateRadioMenuOpen()
    if not cvars.enabled:GetBool() or uiState.radioMenuOpen then return false end
    local ply = LocalPlayer()
    local entity = ply.currentRadioEntity
    if not IsValid( entity ) then return false end
    if not rRadio.utils.CanUseRadio( entity ) then
        chat.AddText( Color( 255, 0, 0 ), "[rRADIO] This seat cannot use the radio." )
        return false
    end

    local shouldOpen = hook.Run( "rRadio.CanOpenMenu", ply, entity )
    if shouldOpen == false then return false end
    return true
end

local function applyEntityTheme( entity )
    if not IsValid( entity ) then return end
    uiState.goldThemeActive = entity:GetClass() == "rammel_boombox_gold"
    if uiState.goldThemeActive then rRadio.interface.applyTheme( "gold" ) end
end

local function toggleGlobalView( searchBox )
    if not uiState.globalView then
        uiState.lastView = {
            selectedCountry = uiState.selectedCountry,
            favoritesMenuOpen = uiState.favoritesMenuOpen,
            searchText = searchBox:GetText()
        }

        uiState.globalView = true
        uiState.selectedCountry = rRadio.L( "Global", "global" )
        uiState.favoritesMenuOpen = false
        uiState.settingsMenuOpen = false
        searchBox:SetText( "" )
        return
    end

    if uiState.lastView then
        uiState.selectedCountry = uiState.lastView.selectedCountry
        uiState.favoritesMenuOpen = uiState.lastView.favoritesMenuOpen
        searchBox:SetText( uiState.lastView.searchText or "" )
    end

    uiState.globalView = false
    uiState.lastView = nil
end

function rRadio.cl.relayoutRadioMenu( refreshContent )
    local frame = uiState.currentFrame
    if not IsValid( frame ) then return end
    local frameX, frameY = frame:GetPos()
    local centerX = frameX + frame:GetWide() / 2
    local centerY = frameY + frame:GetTall() / 2
    layoutRadioFrame( frame )
    frame:SetPos( centerX - frame:GetWide() / 2, centerY - frame:GetTall() / 2 )
    if refreshContent then refreshScaledMenuContent( frame ) end
end

function rRadio.cl.openRadioMenu( openSettings, opts )
    opts = opts or {}
    if opts.delay and IsValid( LocalPlayer() ) and LocalPlayer().currentRadioEntity then
        timer.Simple( 0.1, function() rRadio.cl.openRadioMenu( openSettings, {} ) end )
        return
    end

    if not validateRadioMenuOpen() then return end
    rRadio.interface.SetMenuScale( cvars.menuScale and cvars.menuScale:GetFloat() or 1, false )
    rRadio.interface.SetMenuWidthScale( cvars.menuWidthScale and cvars.menuWidthScale:GetFloat() or 1, false )
    applyEntityTheme( LocalPlayer().currentRadioEntity )
    local frame = createRadioFrame()
    uiState.currentFrame = frame
    uiState.radioMenuOpen = true
    local stationListPanel = createStationListPanel( frame )
    local searchBox, globalBtn = createSearchControls( frame, stationListPanel )
    local buttons = createNavigationButtons( frame, stationListPanel, searchBox )
    globalBtn.DoClick = function()
        rRadio.interface.playSound( "ButtonPressMain" )
        toggleGlobalView( searchBox )
        rRadio.cl.populateList( stationListPanel, buttons.back, searchBox, true )
    end

    local stopButton = createStopButton( frame, stationListPanel, buttons.back, searchBox )
    local volumePanel, volumeIcon, volumeSlider = createVolumeControls( frame, stopButton )
    frame.closeButton = buttons.close
    frame.settingsButton = buttons.settings
    frame.backButton = buttons.back
    frame.stopButton = stopButton
    frame.stationListContainer = stationListPanel.container
    frame.stationListPanel = stationListPanel
    frame.searchBox = searchBox
    frame.globalButton = globalBtn
    frame.volumePanel = volumePanel
    frame.volumeIcon = volumeIcon
    frame.volumeSlider = volumeSlider
    addResizeHandles( frame )
    layoutRadioFrame( frame )
    if not uiState.settingsMenuOpen then
        rRadio.cl.populateList( stationListPanel, buttons.back, searchBox, true )
    else
        rRadio.cl.openSettingsMenu( frame, buttons.back, nil )
    end
end

function rRadio.cl.toggleCarRadioMenu()
    local ply = LocalPlayer()
    if uiState.radioMenuOpen then
        rRadio.interface.playSound( "MenuClosed" )
        uiState.currentFrame:Close()
        return
    end

    local vehicle = ply:GetVehicle()
    if not IsValid( vehicle ) then return end
    local mainVehicle = rRadio.utils.GetVehicle( vehicle )
    if not IsValid( mainVehicle ) then return end
    if hook.Run( "rRadio.CanOpenMenu", ply, mainVehicle ) == false then return end
    if rRadio.config.DriverPlayOnly then
        local isPlayerDriving = mainVehicle:GetDriver() == ply
        if not isPlayerDriving then return end
    end

    if not rRadio.utils.IsSitAnywhereSeat( mainVehicle ) then
        ply.currentRadioEntity = mainVehicle
        rRadio.cl.openRadioMenu()
    end
end
