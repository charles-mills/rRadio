if SERVER then return end
rRadio.cl.uiComponents = {}
local Scale = rRadio.cl.Scale
local uiState = rRadio.cl.uiState
local timing = rRadio.cl.timing
local icons = rRadio.cl.icons
local stationSearchListCache = {}
local function getCountrySearchList( country )
    local source = rRadio.cl.stationData[country] or {}
    local cached = stationSearchListCache[country]
    if cached and cached.source == source and cached.count == #source then return cached.list end
    local list = {}
    for _, st in ipairs( source ) do
        if st and st.name then
            st.nameLower = st.nameLower or string.lower( st.name )
            st.charMap = st.charMap or rRadio.interface.buildCharMap( st.name )
            list[#list + 1] = {
                station = st,
                searchText = st.name,
                searchTextLower = st.nameLower,
                charMap = st.charMap
            }
        end
    end

    stationSearchListCache[country] = {
        source = source,
        count = #source,
        list = list
    }
    return list
end

local function createButtonStar( parent, updateList, categoryTable, key, subKey )
    local star = vgui.Create( "rRadioStar", parent )
    star:SetPos( Scale( 8 ), ( Scale( 40 ) - Scale( 24 ) ) / 2 )
    if categoryTable then star:Bind( categoryTable, key, subKey ) end
    star:SetUpdateFunc( updateList )
    return star
end

local function setSelectedCountry( country, favoritesOpen )
    uiState.globalView = false
    uiState.lastView = nil
    uiState.selectedCountry = country
    uiState.favoritesMenuOpen = favoritesOpen and true or false
end

local function hasFavoriteStations()
    for _, stations in pairs( rRadio.interface.favoriteStations ) do
        for _, isFav in pairs( stations ) do
            if isFav then return true end
        end
    end
    return false
end

local function addPlayableStation( items, panel, station, countryKey, displayText, updateList )
    station.countryKey = countryKey
    items[#items + 1] = rRadio.cl.uiComponents.createPlayableStationButton( panel, station, displayText, updateList )
end

function rRadio.cl.uiComponents.createPlayableStationButton( parent, station, displayText, updateList )
    local btn = vgui.Create( "rRadioButton", parent )
    btn:SetTextLabel( displayText )
    local star = createButtonStar(
        btn, updateList, rRadio.interface.favoriteStations,
        station.countryKey, station.name
    )
    btn:SetLeftChild( star )
    btn.DoClick = function()
        local now = CurTime()
        if now - timing.lastStationSelectTime < 2 then return end
        rRadio.interface.playSound( "ButtonPressSecondary" )
        local plyEnt = LocalPlayer().currentRadioEntity
        if not IsValid( plyEnt ) then return end
        local vol = rRadio.cl.getEntityVolume( plyEnt )
        net.Start( "rRadio.PlayStation" )
        net.WriteEntity( plyEnt )
        net.WriteString( rRadio.interface.TruncateChars( station.name, rRadio.config.MaxNameChars ) )
        net.WriteString( station.url )
        net.WriteFloat( vol )
        net.SendToServer()
        rRadio.cl.requestedStations[plyEnt] = true
        rRadio.cl.currentlyPlayingStations[plyEnt] = station
        timing.lastStationSelectTime = now
        if updateList then updateList() end
    end

    btn.Think = function( self )
        local ent = LocalPlayer().currentRadioEntity
        local playing = rRadio.cl.currentlyPlayingStations[ent]
        local on = IsValid( ent ) and playing
            and playing.name == station.name
        if on ~= self.playing then self:SetPlaying( on ) end
        local errData = IsValid( ent ) and rRadio.cl.errorTimestamps[ent]
        if errData and errData.stationName == station.name
            and CurTime() - errData.time < ( rRadio.config.ErrorDisplayDuration or 5 ) then
            self.errorFlash = true
        else
            self.errorFlash = false
        end
    end
    return btn
end

function rRadio.cl.uiComponents.populateFavorites( panel, updateList )
    local items = {}
    if not hasFavoriteStations() then return items end
    items[#items + 1] = vgui.Create( "rRadioSeparator", panel )
    local favBtn = vgui.Create( "rRadioButton", panel )
    favBtn:SetTextLabel( rRadio.L( "FavoriteStations", "Favorite Stations" ) )
    favBtn:DockMargin( Scale( 5 ), Scale( 5 ), Scale( 5 ), Scale( 5 ) )
    local headerIcon = createButtonStar( favBtn, updateList )
    headerIcon.Paint = function( _self, w, h )
        surface.SetMaterial( icons.star.FULL )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        surface.DrawTexturedRect( 0, 0, w, h )
    end

    headerIcon.DoClick = function() favBtn:DoClick() end
    favBtn:SetLeftChild( headerIcon )
    favBtn.DoClick = function()
        rRadio.interface.playSound( "ButtonPressMain" )
        setSelectedCountry( "favorites", true )
        updateList()
    end

    items[#items + 1] = favBtn
    items[#items + 1] = vgui.Create( "rRadioSeparator", panel )
    return items
end

function rRadio.cl.uiComponents.populateCountries( panel, filterText, updateList )
    local items = {}
    local raw = {}
    local customKey = rRadio.config.CustomStationCategory or "Custom"
    local translateCustom = customKey == "Custom"
    local customData = rRadio.cl.stationData[customKey]
    local wantsHeader = rRadio.config.PrioritiseCustom
        and filterText == "" and customData and #customData > 0
    if wantsHeader then
        local label = translateCustom and rRadio.LanguageManager:GetCustomTranslation() or customKey
        local hdrBtn = vgui.Create( "rRadioButton", panel )
        hdrBtn:SetTextLabel( label )
        hdrBtn:DockMargin( Scale( 5 ), Scale( 5 ), Scale( 5 ), Scale( 5 ) )
        local hdrIcon = vgui.Create( "DImage", hdrBtn )
        hdrIcon:SetPos( Scale( 10 ), ( Scale( 40 ) - Scale( 24 ) ) / 2 )
        hdrIcon:SetSize( Scale( 24 ), Scale( 24 ) )
        hdrIcon:SetMaterial( icons.star.FULL )
        hdrIcon:SetImageColor( rRadio.config.UI.TextColor )
        hdrIcon:SetMouseInputEnabled( false )
        hdrBtn:SetLeftChild( hdrIcon )
        hdrBtn.DoClick = function()
            rRadio.interface.playSound( "ButtonPressMain" )
            setSelectedCountry( customKey, false )
            updateList()
        end

        items[#items + 1] = hdrBtn
        items[#items + 1] = vgui.Create( "rRadioSeparator", panel )
    end

    for country, stations in pairs( rRadio.cl.stationData ) do
        local skipPrioritizedCustom = country == customKey and wantsHeader
        local skipEmptyCustom = country == customKey and #stations == 0
        if not skipPrioritizedCustom and not skipEmptyCustom then
            raw[#raw + 1] = {
                original = country,
                translated = rRadio.utils.FormatAndTranslateCountry( country ),
                isPrioritized = rRadio.interface.favoriteCountries[country]
            }
        end
    end

    local countries = rRadio.interface.fuzzyFilter(
        filterText, raw,
        function( c ) return c.translated end, 0,
        function( c ) return c.isPrioritized and 0.1 or 0 end
    )
    if not wantsHeader and rRadio.config.PrioritiseCustom and filterText == "" then
        for i, c in ipairs( countries ) do
            if c.original == customKey then
                local entry = table.remove( countries, i )
                local idx = 1
                for j, d in ipairs( countries ) do
                    if not d.isPrioritized then break end
                    idx = j + 1
                end

                table.insert( countries, idx, entry )
                break
            end
        end
    end

    for _, c in ipairs( countries ) do
        local btn = vgui.Create( "rRadioButton", panel )
        btn:SetTextLabel( c.translated )
        local star = createButtonStar( btn, updateList, rRadio.interface.favoriteCountries, c.original )
        btn:SetLeftChild( star )
        btn.DoClick = function()
            rRadio.interface.playSound( "ButtonPressMain" )
            setSelectedCountry( c.original, false )
            updateList()
        end

        items[#items + 1] = btn
    end
    return items
end

function rRadio.cl.uiComponents.populateStations( panel, country, filterText, updateList, backButton )
    local items = {}
    if country == "favorites" then
        local rawFav = {}
        for c, stations in pairs( rRadio.interface.favoriteStations ) do
            if rRadio.cl.stationData[c] then
                for _, st in ipairs( rRadio.cl.stationData[c] ) do
                    if stations[st.name] then
                        rawFav[#rawFav + 1] = {
                            station = st,
                            country = c,
                            countryName = rRadio.utils.FormatAndTranslateCountry( c )
                        }
                    end
                end
            end
        end

        local favList = rRadio.interface.fuzzyFilter(
            filterText, rawFav,
            function( f ) return f.countryName .. " - " .. f.station.name end,
            0
        )
        local favLimit = uiState.isSearching and rRadio.cl.MAX_SEARCH_RESULTS or #favList
        for i = 1, math.min( favLimit, #favList ) do
            local f = favList[i]
            local displayName = f.countryName .. " - " .. f.station.name
            addPlayableStation(
                items, panel, f.station, f.country,
                displayName, updateList
            )
        end
    else
        local rawList = getCountrySearchList( country )
        local sorted = rRadio.interface.fuzzyFilter(
            filterText, rawList,
            function( s ) return s.searchText end, 0,
            function( s )
            local favorites = rRadio.interface.favoriteStations[country]
            return favorites and favorites[s.station.name] and 0.1 or 0
        end )

        local resultLimit = uiState.isSearching and rRadio.cl.MAX_SEARCH_RESULTS or #sorted
        for i = 1, math.min( resultLimit, #sorted ) do
            local d = sorted[i]
            addPlayableStation( items, panel, d.station, country, d.station.name, updateList )
        end
    end

    if backButton then
        backButton:SetVisible( true )
        backButton:SetEnabled( true )
    end
    return items
end
