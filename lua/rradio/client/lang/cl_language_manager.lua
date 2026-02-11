rRadio.LanguageManager = {}
rRadio.LanguageManager.currentLanguage = "en"
rRadio.LanguageManager.translations = include( "rradio/client/lang/cl_localisation_strings.lua" )
rRadio.LanguageManager.countryTranslationsA = include( "rradio/client/data/langpacks/data_1.lua" )
rRadio.LanguageManager.countryTranslationsB = include( "rradio/client/data/langpacks/data_2.lua" )
rRadio.LanguageManager.countryTranslationsC = include( "rradio/client/data/langpacks/data_3.lua" )
rRadio.LanguageManager.countryTranslations = {}
local _langPacks = {
    rRadio.LanguageManager.countryTranslationsA,
    rRadio.LanguageManager.countryTranslationsB,
    rRadio.LanguageManager.countryTranslationsC
}

for _, pack in ipairs( _langPacks ) do
    table.Merge( rRadio.LanguageManager.countryTranslations, pack )
end

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

function rRadio.LanguageManager:GetTranslation( lang, key )
    if self.translations[lang] and self.translations[lang][key] then return self.translations[lang][key] end
    if self.translations.en and self.translations.en[key] then return self.translations.en[key] end
    return key
end

function rRadio.LanguageManager:GetText( key, fallback )
    local lang = self.currentLanguage or "en"
    if self.translations[lang] and self.translations[lang][key] ~= nil then return self.translations[lang][key] end
    if self.translations.en and self.translations.en[key] ~= nil then return self.translations.en[key] end
    return fallback or key
end

function rRadio.LanguageManager:Translate( key )
    return self:GetText( key, key )
end

function rRadio.LanguageManager:GetCustomKey()
    return rRadio.config.CustomStationCategory or "Custom"
end

function rRadio.LanguageManager:GetCustomTranslation()
    return self:GetText( "Custom", "Custom Radio Stations" )
end

function rRadio.L( key, fallback )
    return rRadio.LanguageManager:GetText( key, fallback )
end
return rRadio.LanguageManager
