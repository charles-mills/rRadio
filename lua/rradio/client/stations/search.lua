rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.stations = rRadio.client.stations or {}
rRadio.client.stations.search = rRadio.client.stations.search or {}

local search = rRadio.client.stations.search

local EXACT_LABEL_SCORE = 10000
local EXACT_TEXT_SCORE = 8000
local TOKEN_EXACT_SCORE = 1600
local TOKEN_PREFIX_SCORE = 1200
local TOKEN_CONTAINS_SCORE = 850
local INITIALS_EXACT_SCORE = 2600
local INITIALS_PREFIX_SCORE = 2000
local TOKEN_INITIALS_SCORE = 900
local SUBSEQUENCE_SCORE = 450
local POSITION_PENALTY = 2
local LENGTH_PENALTY = 0.01
local TOKEN_SEPARATOR_PATTERN = "[^%w]+"


local function normalizeText( text )
    return string.lower( string.Trim( tostring( text or "" ) ) )
end


local function compactText( text )
    return string.gsub( normalizeText( text ), TOKEN_SEPARATOR_PATTERN, "" )
end


local function tokenize( text )
    local tokens = {}
    for token in string.gmatch( normalizeText( text ), "%w+" ) do
        tokens[#tokens + 1] = token
    end

    return tokens
end


local function buildInitials( tokens )
    local initials = {}
    for _, token in ipairs( tokens ) do
        initials[#initials + 1] = string.sub( token, 1, 1 )
    end

    return table.concat( initials )
end


local function findPlain( haystack, needle, startPosition )
    if needle == "" then return 1 end

    return string.find( haystack, needle, startPosition or 1, true )
end


local function scorePosition( position )
    if not position then return 0 end

    return math.max( 0, 120 - ( position - 1 ) * POSITION_PENALTY )
end


local function scoreToken( candidateToken, queryToken )
    if candidateToken == queryToken then return TOKEN_EXACT_SCORE end

    local prefixPosition = findPlain( candidateToken, queryToken )
    if prefixPosition == 1 then return TOKEN_PREFIX_SCORE end
    if prefixPosition then return TOKEN_CONTAINS_SCORE + scorePosition( prefixPosition ) end

    return 0
end


local function scoreTokens( candidateTokens, queryTokens )
    local score = 0
    local matchedTokens = 0

    for _, queryToken in ipairs( queryTokens ) do
        local bestScore = 0
        for _, candidateToken in ipairs( candidateTokens ) do
            bestScore = math.max( bestScore, scoreToken( candidateToken, queryToken ) )
        end

        if bestScore <= 0 then return nil end

        matchedTokens = matchedTokens + 1
        score = score + bestScore
    end

    return score, matchedTokens
end


local function scoreTokenInitials( candidateTokens, queryTokens )
    local score = 0
    local matchedTokens = 0

    for _, queryToken in ipairs( queryTokens ) do
        if #queryToken ~= 1 then return nil end

        local bestScore = 0
        for _, candidateToken in ipairs( candidateTokens ) do
            if string.sub( candidateToken, 1, 1 ) == string.sub( queryToken, 1, 1 ) then
                bestScore = TOKEN_INITIALS_SCORE
                break
            end
        end

        if bestScore <= 0 then return nil end

        matchedTokens = matchedTokens + 1
        score = score + bestScore
    end

    return score, matchedTokens
end


local function scoreInitials( candidateInitials, queryCompact )
    if queryCompact == "" then return 0 end
    if candidateInitials == queryCompact then return INITIALS_EXACT_SCORE end

    local position = findPlain( candidateInitials, queryCompact )
    if position == 1 then return INITIALS_PREFIX_SCORE end
    if position then return INITIALS_PREFIX_SCORE - 300 + scorePosition( position ) end

    return 0
end


local function scoreSubsequence( candidateCompact, queryCompact )
    if queryCompact == "" then return 0 end

    local searchFrom = 1
    local firstPosition
    local spanEnd

    for index = 1, #queryCompact do
        local character = string.sub( queryCompact, index, index )
        local position = findPlain( candidateCompact, character, searchFrom )
        if not position then return 0 end

        firstPosition = firstPosition or position
        spanEnd = position
        searchFrom = position + 1
    end

    local span = spanEnd - firstPosition + 1
    local loosenessPenalty = math.max( 0, span - #queryCompact ) * 10

    return math.max( 1, SUBSEQUENCE_SCORE + scorePosition( firstPosition ) - loosenessPenalty )
end


local function getEntryKey( entry )
    if entry.key then return entry.key end
    if entry.station then return entry.station.id or "" end
    if entry.country then return entry.country.key or "" end

    return entry.kind or ""
end


local function compareResults( a, b )
    if a.score ~= b.score then return a.score > b.score end
    if a.entry.label ~= b.entry.label then return a.entry.label < b.entry.label end

    return getEntryKey( a.entry ) < getEntryKey( b.entry )
end


local function unwrapResults( results )
    local entries = {}
    for index, result in ipairs( results ) do
        entries[index] = result.entry
    end

    return entries
end


function search.CompileQuery( query )
    local lower = normalizeText( query )
    local tokens = tokenize( lower )
    local compact = compactText( lower )

    return {
        lower = lower,
        tokens = tokens,
        compact = compact,
        initials = buildInitials( tokens )
    }
end


function search.PrepareEntry( entry, searchText )
    local label = normalizeText( entry.label )
    local combinedText = normalizeText( searchText or entry.searchText or entry.label )
    local tokens = tokenize( label .. " " .. combinedText )

    entry.search = {
        label = label,
        text = combinedText,
        compact = compactText( label .. " " .. combinedText ),
        tokens = tokens,
        initials = buildInitials( tokens )
    }

    return entry
end


function search.Score( entry, compiledQuery )
    if not compiledQuery or compiledQuery.lower == "" then return 0 end
    if not entry.search then search.PrepareEntry( entry ) end

    local data = entry.search
    local score = 0
    local satisfiedTokens

    local labelPosition = findPlain( data.label, compiledQuery.lower )
    if labelPosition then score = score + EXACT_LABEL_SCORE + scorePosition( labelPosition ) end

    local textPosition = findPlain( data.text, compiledQuery.lower )
    if textPosition then score = score + EXACT_TEXT_SCORE + scorePosition( textPosition ) end

    local tokenScore, tokenMatches = scoreTokens( data.tokens, compiledQuery.tokens )
    if tokenScore then
        satisfiedTokens = tokenMatches
        score = score + tokenScore
    else
        local initialsTokenScore, initialsTokenMatches = scoreTokenInitials( data.tokens, compiledQuery.tokens )
        if initialsTokenScore then
            satisfiedTokens = initialsTokenMatches
            score = score + initialsTokenScore
        end
    end

    local initialsScore = scoreInitials( data.initials, compiledQuery.compact )
    if initialsScore > 0 then
        satisfiedTokens = #compiledQuery.tokens
        score = score + initialsScore
    end

    local subsequenceScore = scoreSubsequence( data.compact, compiledQuery.compact )
    if subsequenceScore > 0 then
        satisfiedTokens = satisfiedTokens or #compiledQuery.tokens
        score = score + subsequenceScore
    end

    if #compiledQuery.tokens > 0 and satisfiedTokens ~= #compiledQuery.tokens then return nil end
    if score <= 0 then return nil end

    return score - #data.label * LENGTH_PENALTY
end


function search.FilterAndRank( entries, query )
    local compiledQuery = search.CompileQuery( query )
    if compiledQuery.lower == "" then return entries end

    local results = {}
    for _, entry in ipairs( entries ) do
        local score = search.Score( entry, compiledQuery )
        if score then
            results[#results + 1] = {
                entry = entry,
                score = score
            }
        end
    end

    table.sort( results, compareResults )

    return unwrapResults( results )
end


return search
