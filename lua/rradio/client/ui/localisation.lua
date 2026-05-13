rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.localisation = rRadio.client.ui.localisation or {}

local localisation = rRadio.client.ui.localisation
local translations = {}
local currentLanguage = "en"

local function normalizeLanguage( language )
    language = tostring( language or "en" )
    language = string.lower( language )
    language = string.gsub( language, "%s+", "_" )
    language = string.gsub( language, "-", "_" )
    language = string.gsub( language, "[()]", "" )

    return language
end

local function getCurrentLanguage()
    return currentLanguage
end

local function mergeLanguage( languageKey, data )
    translations[languageKey] = translations[languageKey] or {
        ui = {},
        themes = {},
        countries = {}
    }

    for section, rows in pairs( data ) do
        if type( rows ) == "table" then
            translations[languageKey][section] = translations[languageKey][section] or {}
            for key, value in pairs( rows ) do
                translations[languageKey][section][key] = value
            end
        end
    end
end

function localisation.Init()
    translations = {}
    local languageConVar = GetConVar( "gmod_language" )
    currentLanguage = normalizeLanguage( languageConVar and languageConVar:GetString() or "en" )

    local files = file.Find( "rradio/client/lang/*.lua", "LUA" )
    table.sort( files )

    for _, filename in ipairs( files ) do
        local payloadPath = "rradio/client/lang/" .. filename
        local record = include( payloadPath )
        local payload = rRadio.generatedPayload.DecodeOrError( record, {
            label = payloadPath,
            kind = "locale_chunk",
            maxBytes = 512 * 1024
        } )

        local data = payload.locales
        if type( data ) == "table" then
            for languageKey, languageData in pairs( data ) do
                mergeLanguage( languageKey, languageData )
            end
        end
    end

    cvars.AddChangeCallback( "gmod_language", function( _name, _oldValue, newValue )
        currentLanguage = normalizeLanguage( newValue )
        hook.Run( "rRadio_LanguageChanged", currentLanguage )
    end, "rRadio_UI_LanguageChanged" )
end

function localisation.Get( key, fallback )
    local language = getCurrentLanguage()
    local languageData = translations[language] or {}
    local englishData = translations.en or {}
    local ui = languageData.ui or englishData.ui or {}

    return ui[key] or ( englishData.ui and englishData.ui[key] ) or fallback or key
end

function localisation.GetCountry( countryKey, fallback )
    local language = getCurrentLanguage()
    local languageData = translations[language] or {}
    local englishData = translations.en or {}
    local countryName = fallback or rRadio.util.FormatCountryKey( countryKey )
    local countries = languageData.countries or {}
    local englishCountries = englishData.countries or {}

    return countries[countryName] or englishCountries[countryName] or countryName
end

function localisation.GetTheme( themeName )
    local language = getCurrentLanguage()
    local languageData = translations[language] or {}
    local englishData = translations.en or {}
    local themes = languageData.themes or {}
    local englishThemes = englishData.themes or {}
    local fallback = string.gsub( tostring( themeName or "" ), "^%l", string.upper )

    return themes[themeName] or englishThemes[themeName] or fallback
end

function localisation.GetCurrentLanguage()
    return getCurrentLanguage()
end

function localisation.NormalizeLanguage( language )
    return normalizeLanguage( language )
end

function rRadio.L( key, fallback )
    return localisation.Get( key, fallback )
end

return localisation
