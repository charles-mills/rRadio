rRadio.LanguageManager = {}
rRadio.LanguageManager.currentLanguage = "en"
rRadio.LanguageManager.countryTranslations = {}

local TRANSLATIONS = {}
local THEME_TRANSLATIONS = {}

local localeFiles = file.Find( "rradio/client/lang/locales/*.lua", "LUA" )
table.sort( localeFiles )
for _, f in ipairs( localeFiles ) do
    local data = include( "rradio/client/lang/locales/" .. f )
    if data then
        for lang, langData in pairs( data ) do
            if langData.ui then
                TRANSLATIONS[lang] = langData.ui
            end
            if langData.themes then
                THEME_TRANSLATIONS[lang] = langData.themes
            end
            if langData.countries then
                rRadio.LanguageManager.countryTranslations[lang] = langData.countries
            end
        end
    end
end

local function applyTranslationFallbacks()
    local english = TRANSLATIONS.en or {}
    local langs = {}
    for langCode in pairs( TRANSLATIONS ) do
        langs[langCode] = true
    end
    for langCode in pairs( THEME_TRANSLATIONS ) do
        langs[langCode] = true
    end

    for langCode in pairs( langs ) do
        local source = TRANSLATIONS[langCode] or {}
        local merged = {}
        for key, value in pairs( source ) do
            merged[key] = value
        end
        for key, value in pairs( english ) do
            if merged[key] == nil then
                merged[key] = value
            end
        end
        rRadio.LanguageManager.translations[langCode] = merged
    end
end

local function applyThemeTranslations()
    for langCode, translations in pairs( THEME_TRANSLATIONS ) do
        local langTable = rRadio.LanguageManager.translations[langCode]
        if langTable then
            for themeName, label in pairs( translations ) do
                langTable[themeName] = label
            end
        end
    end
end

rRadio.LanguageManager.translations = {}
applyTranslationFallbacks()
applyThemeTranslations()

local gmodLang = GetConVar( "gmod_language" )
function rRadio.LanguageManager:GetClientLanguageCode()
    local raw = gmodLang and gmodLang:GetString() or "en"
    return raw:lower():gsub( "%s+", "_" ):gsub( "-", "_" ):gsub( "[()]", "" )
end

function rRadio.LanguageManager:UpdateCurrentLanguage()
    self.currentLanguage = self:GetClientLanguageCode()
    rRadio.config.Lang = self.translations[self.currentLanguage] or self.translations.en or {}
end

function rRadio.LanguageManager:GetCountryTranslation( country_key )
    local lang = self.currentLanguage or "en"
    local translations = self.countryTranslations[lang]
    return translations and translations[country_key] or country_key
end

function rRadio.LanguageManager:GetText( key, fallback )
    local lang = self.currentLanguage or "en"
    if self.translations[lang] and self.translations[lang][key] ~= nil then return self.translations[lang][key] end
    if self.translations.en and self.translations.en[key] ~= nil then return self.translations.en[key] end
    return fallback or key
end

function rRadio.LanguageManager:FormatText( key, replacements, fallback )
    local text = self:GetText( key, fallback or key )
    if replacements then
        for placeholder, value in pairs( replacements ) do
            text = string.Replace( text, "{" .. placeholder .. "}", tostring( value ) )
        end
    end
    return text
end

function rRadio.LanguageManager:Translate( key )
    return self:GetText( key, key )
end

function rRadio.LanguageManager:GetCustomTranslation()
    return self:GetText( "Custom", "Custom Radio Stations" )
end

function rRadio.L( key, fallback )
    return rRadio.LanguageManager:GetText( key, fallback )
end

function rRadio.Lf( key, replacements, fallback )
    return rRadio.LanguageManager:FormatText( key, replacements, fallback )
end
return rRadio.LanguageManager
