rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.viewModel = rRadio.client.ui.menu.viewModel or {}

local viewModel = rRadio.client.ui.menu.viewModel
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local queries = rRadio.client.stations.queries

viewModel.Views = {
    COUNTRIES = "countries",
    COUNTRY = "country",
    FAVORITES = "favorites",
    RECENTS = "recents",
    GLOBAL = "global",
    SETTINGS = "settings",
    CUSTOM_MANAGE = "custom_manage"
}

local views = viewModel.Views


function viewModel.GetSearchText()
    if not IsValid( state.searchBox ) then return state.searchText or "" end

    return state.searchBox:GetText()
end


function viewModel.SetSearchText( text )
    state.searchText = text or ""
    if IsValid( state.searchBox ) then state.searchBox:SetText( state.searchText ) end
end


function viewModel.ClearSearch()
    viewModel.SetSearchText( "" )
end


function viewModel.SaveView()
    return {
        viewMode = state.viewMode,
        selectedCountry = state.selectedCountry,
        searchText = viewModel.GetSearchText()
    }
end


function viewModel.RestoreView( view )
    view = view or {}
    state.viewMode = view.viewMode or views.COUNTRIES
    state.selectedCountry = view.selectedCountry
    viewModel.SetSearchText( view.searchText or "" )
end


function viewModel.GetCountryLabel( country )
    local customKey = rRadio.config.CustomStationCategory or "Custom"
    if country.key == customKey and customKey == "Custom" then
        return rRadio.L( "Custom", "Custom Stations" )
    end

    return rRadio.client.ui.localisation.GetCountry( country.key, country.name )
end


function viewModel.CanNavigateBack()
    return state.viewMode == views.SETTINGS
        or state.viewMode == views.GLOBAL
        or state.viewMode == views.COUNTRY
        or state.viewMode == views.FAVORITES
        or state.viewMode == views.RECENTS
        or state.viewMode == views.CUSTOM_MANAGE
end


function viewModel.GetHeaderText()
    if state.viewMode == views.SETTINGS then return rRadio.L( "Settings", "Settings" ) end
    if state.viewMode == views.CUSTOM_MANAGE then
        return rRadio.L( "CustomStationManage", "Manage custom stations" )
    end
    if state.viewMode == views.GLOBAL then return rRadio.L( "Global", "Global" ) end
    if state.viewMode == views.FAVORITES then return rRadio.L( "FavoriteStations", "Favorite Stations" ) end
    if state.viewMode == views.RECENTS then return rRadio.L( "RecentStations", "Recent Stations" ) end
    if state.viewMode == views.COUNTRY and state.selectedCountry then
        local country = {
            key = state.selectedCountry,
            name = rRadio.util.FormatCountryKey( state.selectedCountry )
        }

        return viewModel.GetCountryLabel( country )
    end

    return rRadio.L( "SelectCountry", "Select a Country" )
end


function viewModel.GetHeaderIcon()
    if state.viewMode == views.SETTINGS then return style.Materials.settingsBold end
    if state.viewMode == views.CUSTOM_MANAGE then return style.Materials.writing end
    if state.viewMode == views.GLOBAL then return style.Materials.globe end
    if state.viewMode == views.FAVORITES then return style.Materials.bookmark end
    if state.viewMode == views.RECENTS then return style.Materials.clock end
    if state.viewMode == views.COUNTRY then
        local customKey = rRadio.config.CustomStationCategory or "Custom"
        if state.selectedCountry == customKey then return style.Materials.writing end

        return style.Materials.radio
    end

    return style.Materials.radio
end


local function isCustomCountryView()
    return state.viewMode == views.COUNTRY
        and state.selectedCountry == ( rRadio.config.CustomStationCategory or "Custom" )
end


local function prependCustomManageEntry( entries )
    if not isCustomCountryView() or not state.canManageCustomStations then return entries end

    local rows = {
        {
            kind = "custom_manage",
            label = rRadio.L( "CustomStationManage", "Manage custom stations" ),
            key = "custom_manage",
            dividerBelow = #entries > 0
        }
    }

    for _, entry in ipairs( entries ) do
        rows[#rows + 1] = entry
    end

    return rows
end


function viewModel.BuildEntries()
    local query = viewModel.GetSearchText()

    if state.viewMode == views.COUNTRIES then
        return queries.GetCountries( query )
    end

    if state.viewMode == views.COUNTRY and state.selectedCountry then
        return prependCustomManageEntry( queries.GetCountryStations( state.selectedCountry, query ) )
    end

    if state.viewMode == views.FAVORITES then
        return queries.GetFavouriteStations( query )
    end

    if state.viewMode == views.RECENTS then
        return queries.GetRecentStations( query )
    end

    if state.viewMode == views.GLOBAL then
        return queries.GetGlobalStations( query )
    end

    return {}
end


function viewModel.GetListKey()
    return table.concat( {
        state.viewMode or "",
        state.selectedCountry or "",
        state.canManageCustomStations and "1" or "0",
        string.lower( string.Trim( viewModel.GetSearchText() ) )
    }, "\n" )
end


function viewModel.GetEntryKey( entry )
    if entry.key then return entry.key end
    if entry.kind == "country" then return "country:" .. entry.country.key end
    if entry.kind == "station" then return "station:" .. entry.station.id end

    return entry.kind or "unknown"
end


function viewModel.EntriesMatch( oldEntries, newEntries )
    if oldEntries == newEntries then return true end
    if not oldEntries or #oldEntries ~= #newEntries then return false end

    for index, entry in ipairs( newEntries ) do
        if viewModel.GetEntryKey( oldEntries[index] ) ~= viewModel.GetEntryKey( entry ) then return false end
    end

    return true
end


return viewModel
