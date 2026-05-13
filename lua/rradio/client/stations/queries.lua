rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.stations = rRadio.client.stations or {}
rRadio.client.stations.queries = rRadio.client.stations.queries or {}

local queries = rRadio.client.stations.queries
local catalog = rRadio.client.stations.catalog
local favourites = rRadio.client.stations.favourites
local recent = rRadio.client.stations.recent
local search = rRadio.client.stations.search

local QUERY_CACHE_LIMIT = 32

local emptyCache = {}
local queryCache = {}
local queryLinks = {}
local queryHead
local queryTail
local queryCount = 0
local countryLabelCache = {}
local languageVersion = 0
local observedCatalogVersion
local observedFavouritesVersion
local observedRecentVersion
local initialized = false


local function normalizeQuery( query )
    return string.lower( string.Trim( tostring( query or "" ) ) )
end


local function canManageCustomStations()
    return rRadio.client.ui.state.canManageCustomStations == true
end


local function buildCacheKey( parts )
    return table.concat( parts, "|" )
end


local function clearIfSourceVersionsChanged()
    local catalogVersion = catalog.GetVersion()
    local favouritesVersion = favourites.GetVersion()
    local recentVersion = recent.GetVersion()

    if not observedCatalogVersion or not observedFavouritesVersion or not observedRecentVersion then
        observedCatalogVersion = catalogVersion
        observedFavouritesVersion = favouritesVersion
        observedRecentVersion = recentVersion
        return
    end

    if catalogVersion == observedCatalogVersion
        and favouritesVersion == observedFavouritesVersion
        and recentVersion == observedRecentVersion then
        return
    end

    queries.Clear()
    observedCatalogVersion = catalogVersion
    observedFavouritesVersion = favouritesVersion
    observedRecentVersion = recentVersion
end


local function unlinkQueryKey( cacheKey )
    local link = queryLinks[cacheKey]
    if not link then return end

    if link.previous then
        queryLinks[link.previous].next = link.next
    else
        queryHead = link.next
    end

    if link.next then
        queryLinks[link.next].previous = link.previous
    else
        queryTail = link.previous
    end

    queryLinks[cacheKey] = nil
    queryCount = math.max( queryCount - 1, 0 )
end


local function touchQueryKey( cacheKey )
    if queryLinks[cacheKey] then unlinkQueryKey( cacheKey ) end

    queryLinks[cacheKey] = {
        previous = queryTail,
        next = nil
    }

    if queryTail then
        queryLinks[queryTail].next = cacheKey
    else
        queryHead = cacheKey
    end

    queryTail = cacheKey
    queryCount = queryCount + 1
end


local function readCache( cacheKey, query )
    if query == "" then return emptyCache[cacheKey] end

    local entries = queryCache[cacheKey]
    if entries then touchQueryKey( cacheKey ) end

    return entries
end


local function writeCache( cacheKey, query, entries )
    if query == "" then
        emptyCache[cacheKey] = entries
        return entries
    end

    queryCache[cacheKey] = entries
    touchQueryKey( cacheKey )

    while queryCount > QUERY_CACHE_LIMIT do
        local oldestKey = queryHead
        if not oldestKey then break end

        unlinkQueryKey( oldestKey )
        queryCache[oldestKey] = nil
    end

    return entries
end


local function findCachedPrefix( buildParts, query )
    for length = #query - 1, 1, -1 do
        local prefix = string.sub( query, 1, length )
        if prefix == string.Trim( prefix ) then
            local cacheKey = buildCacheKey( buildParts( prefix ) )
            local cachedEntries = readCache( cacheKey, prefix )
            if cachedEntries then return cachedEntries end
        end
    end

    return nil
end


local function getCountryLabelByKey( countryKey, fallback )
    local cachedLabel = countryLabelCache[countryKey]
    if cachedLabel then return cachedLabel end

    local customKey = rRadio.config.CustomStationCategory or "Custom"
    local label
    if countryKey == customKey and customKey == "Custom" then
        label = rRadio.L( "Custom", "Custom Stations" )
    else
        label = rRadio.client.ui.localisation.GetCountry( countryKey, fallback )
    end

    countryLabelCache[countryKey] = label
    return label
end


local function getCountryLabel( country )
    return getCountryLabelByKey( country.key, country.name )
end


local function isCustomCountryKey( countryKey )
    return countryKey == ( rRadio.config.CustomStationCategory or "Custom" )
end


local function sortCountries( countries )
    local customKey = rRadio.config.CustomStationCategory or "Custom"

    table.sort( countries, function( a, b )
        if rRadio.config.PrioritiseCustom ~= false and a.key ~= b.key then
            if a.key == customKey then return true end
            if b.key == customKey then return false end
        end

        local aFavourite = favourites.IsCountryFavourite( a.key )
        local bFavourite = favourites.IsCountryFavourite( b.key )
        if aFavourite ~= bFavourite then return aFavourite end

        return getCountryLabel( a ) < getCountryLabel( b )
    end )
end


local function sortStationsByFavourite( stations )
    local rows = {}
    for _, station in ipairs( stations ) do
        rows[#rows + 1] = station
    end

    table.sort( rows, function( a, b )
        local aFavourite = favourites.IsStationFavourite( a.id )
        local bFavourite = favourites.IsStationFavourite( b.id )
        if aFavourite ~= bFavourite then return aFavourite end

        if a.name ~= b.name then return a.name < b.name end

        return a.id < b.id
    end )

    return rows
end


local function buildStationSearchText( station, label )
    return string.lower( label ) .. "\n" .. ( station.search or "" )
end


local function makeStationEntry( station, label )
    return {
        kind = "station",
        station = station,
        label = label,
        key = "station:" .. station.id,
        searchText = buildStationSearchText( station, label )
    }
end


local function makeCountryEntry( country )
    local label = getCountryLabel( country )
    local searchText = string.lower( label )

    return search.PrepareEntry( {
        kind = "country",
        country = country,
        label = label,
        key = "country:" .. country.key,
        searchText = searchText
    } )
end


local function makeFavoritesEntry()
    local label = rRadio.L( "FavoriteStations", "Favorite Stations" )

    return search.PrepareEntry( {
        kind = "favorites",
        label = label,
        key = "favorites",
        searchText = string.lower( label )
    } )
end


local function makeRecentEntry()
    local label = rRadio.L( "RecentStations", "Recent Stations" )

    return search.PrepareEntry( {
        kind = "recent",
        label = label,
        key = "recent",
        searchText = string.lower( label )
    } )
end


local function entryIsCustomCountry( entry )
    return entry.kind == "country" and entry.country and isCustomCountryKey( entry.country.key )
end


local function entryIsFavorites( entry )
    return entry.kind == "favorites"
end


local function entryIsRecent( entry )
    return entry.kind == "recent"
end


local function hasRecentStations()
    for _, stationID in ipairs( recent.ListStationIDs() ) do
        if catalog.Get( stationID ) then return true end
    end

    return false
end


local function popEntry( entries, predicate )
    for index, entry in ipairs( entries ) do
        if predicate( entry ) then return table.remove( entries, index ) end
    end

    return nil
end


local function copyEntry( entry )
    if not entry then return nil end

    local copy = {}
    for key, value in pairs( entry ) do
        copy[key] = value
    end

    return copy
end


local function prependTopGroup( entries, topGroup )
    for _, entry in ipairs( topGroup ) do
        entry.dividerBelow = false
    end

    if #topGroup > 0 and #entries > 0 then topGroup[#topGroup].dividerBelow = true end

    for index = #topGroup, 1, -1 do
        table.insert( entries, 1, topGroup[index] )
    end

    return entries
end


local function getTopGroupEntries( countries )
    local customCountryKey
    local topGroup = {}

    for _, country in ipairs( countries ) do
        if isCustomCountryKey( country.key ) then
            customCountryKey = country.key
            topGroup[#topGroup + 1] = makeCountryEntry( country )
            break
        end
    end

    if favourites.HasStationFavourites() then topGroup[#topGroup + 1] = makeFavoritesEntry() end
    if hasRecentStations() then topGroup[#topGroup + 1] = makeRecentEntry() end

    return customCountryKey, topGroup
end


local function ensureManageableCustomCountry( countries )
    if not canManageCustomStations() then return countries end

    local customKey = rRadio.config.CustomStationCategory or "Custom"
    for _, country in ipairs( countries ) do
        if country.key == customKey then return countries end
    end

    countries[#countries + 1] = {
        key = customKey,
        name = customKey,
        stations = {},
        builtinCount = 0
    }

    return countries
end


local function pinTopGroupEntries( entries )
    local topGroup = {}
    local customEntry = popEntry( entries, entryIsCustomCountry )
    if customEntry then topGroup[#topGroup + 1] = copyEntry( customEntry ) end

    local favoritesEntry = popEntry( entries, entryIsFavorites )
    if favoritesEntry then topGroup[#topGroup + 1] = copyEntry( favoritesEntry ) end

    local recentEntry = popEntry( entries, entryIsRecent )
    if recentEntry then topGroup[#topGroup + 1] = copyEntry( recentEntry ) end

    return prependTopGroup( entries, topGroup )
end


local function addStationEntries( entries, stations, includeCountry )
    for _, station in ipairs( stations ) do
        local label = station.name
        if includeCountry then
            label = getCountryLabelByKey( station.countryKey, station.countryName ) .. " - " .. station.name
        end

        entries[#entries + 1] = makeStationEntry( station, label )
    end
end


function queries.Clear()
    emptyCache = {}
    queryCache = {}
    queryLinks = {}
    queryHead = nil
    queryTail = nil
    queryCount = 0
    countryLabelCache = {}
end


function queries.Init()
    if initialized then return end
    initialized = true

    hook.Add( "rRadio_LanguageChanged", "rRadio_StationQueries_ClearCache", function()
        languageVersion = languageVersion + 1
        queries.Clear()
    end )
end


function queries.GetCountries( query )
    query = normalizeQuery( query )
    clearIfSourceVersionsChanged()

    local catalogVersion = catalog.GetVersion()
    local favouritesVersion = favourites.GetVersion()
    local recentVersion = recent.GetVersion()
    local function buildParts( queryText )
        return {
            "countries",
            queryText,
            catalogVersion,
            favouritesVersion,
            recentVersion,
            canManageCustomStations() and "1" or "0",
            languageVersion
        }
    end

    local cacheKey = buildCacheKey( buildParts( query ) )
    local cachedEntries = readCache( cacheKey, query )
    if cachedEntries then return cachedEntries end
    if query ~= "" then
        local baseEntries = findCachedPrefix( buildParts, query ) or queries.GetCountries( "" )
        return writeCache( cacheKey, query, pinTopGroupEntries( search.FilterAndRank( baseEntries, query ) ) )
    end

    local entries = {}
    local countries = catalog.ListCountries()
    ensureManageableCustomCountry( countries )
    local customCountryKey, topGroup = getTopGroupEntries( countries )

    sortCountries( countries )

    for _, country in ipairs( countries ) do
        if country.key ~= customCountryKey then entries[#entries + 1] = makeCountryEntry( country ) end
    end

    prependTopGroup( entries, topGroup )

    return writeCache( cacheKey, query, entries )
end


function queries.GetCountryStations( countryKey, query )
    query = normalizeQuery( query )
    clearIfSourceVersionsChanged()

    local catalogVersion = catalog.GetVersion()
    local favouritesVersion = favourites.GetVersion()
    local function buildParts( queryText )
        return {
            "country",
            countryKey or "",
            queryText,
            catalogVersion,
            favouritesVersion,
            languageVersion
        }
    end

    local cacheKey = buildCacheKey( buildParts( query ) )
    local cachedEntries = readCache( cacheKey, query )
    if cachedEntries then return cachedEntries end
    if query ~= "" then
        local baseEntries = findCachedPrefix( buildParts, query ) or queries.GetCountryStations( countryKey, "" )
        return writeCache( cacheKey, query, search.FilterAndRank( baseEntries, query ) )
    end

    local entries = {}
    addStationEntries( entries, sortStationsByFavourite( catalog.ListStationsForCountry( countryKey ) ), false )

    return writeCache( cacheKey, query, entries )
end


function queries.GetGlobalStations( query )
    query = normalizeQuery( query )
    clearIfSourceVersionsChanged()

    local catalogVersion = catalog.GetVersion()
    local function buildParts( queryText )
        return {
            "global",
            queryText,
            catalogVersion,
            languageVersion
        }
    end

    local cacheKey = buildCacheKey( buildParts( query ) )
    local cachedEntries = readCache( cacheKey, query )
    if cachedEntries then return cachedEntries end
    if query ~= "" then
        local baseEntries = findCachedPrefix( buildParts, query ) or queries.GetGlobalStations( "" )
        return writeCache( cacheKey, query, search.FilterAndRank( baseEntries, query ) )
    end

    local entries = {}
    addStationEntries( entries, catalog.ListStations(), true )

    return writeCache( cacheKey, query, entries )
end


function queries.GetFavouriteStations( query )
    query = normalizeQuery( query )
    clearIfSourceVersionsChanged()

    local catalogVersion = catalog.GetVersion()
    local favouritesVersion = favourites.GetVersion()
    local function buildParts( queryText )
        return {
            "favorites",
            queryText,
            catalogVersion,
            favouritesVersion,
            languageVersion
        }
    end

    local cacheKey = buildCacheKey( buildParts( query ) )
    local cachedEntries = readCache( cacheKey, query )
    if cachedEntries then return cachedEntries end
    if query ~= "" then
        local baseEntries = findCachedPrefix( buildParts, query ) or queries.GetFavouriteStations( "" )
        return writeCache( cacheKey, query, search.FilterAndRank( baseEntries, query ) )
    end

    local entries = {}
    local stations = catalog.ListFavouriteStations( favourites.ListStationIDs() )
    addStationEntries( entries, stations, true )

    return writeCache( cacheKey, query, entries )
end


function queries.GetRecentStations( query )
    query = normalizeQuery( query )
    clearIfSourceVersionsChanged()

    local catalogVersion = catalog.GetVersion()
    local recentVersion = recent.GetVersion()
    local function buildParts( queryText )
        return {
            "recent",
            queryText,
            catalogVersion,
            recentVersion,
            languageVersion
        }
    end

    local cacheKey = buildCacheKey( buildParts( query ) )
    local cachedEntries = readCache( cacheKey, query )
    if cachedEntries then return cachedEntries end
    if query ~= "" then
        local baseEntries = findCachedPrefix( buildParts, query ) or queries.GetRecentStations( "" )
        return writeCache( cacheKey, query, search.FilterAndRank( baseEntries, query ) )
    end

    local stations = {}
    for _, stationID in ipairs( recent.ListStationIDs() ) do
        local station = catalog.Get( stationID )
        if station then stations[#stations + 1] = station end
    end

    local entries = {}
    addStationEntries( entries, stations, true )

    return writeCache( cacheKey, query, entries )
end

return queries
