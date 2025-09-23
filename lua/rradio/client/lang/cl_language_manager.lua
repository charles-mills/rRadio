local Radio = rRadio
local Config = Radio.config

Radio.LanguageManager = {}
Radio.LanguageManager.languages = {
    de     = "Deutsch",
    en     = "English",
    es_es  = "Español",
    fr     = "Français",
    it     = "Italiano",
    ja     = "日本語",
    ko     = "한국어",
    pt_br  = "Português (Brasil)",
    ru     = "Русский",
    zh_cn  = "简体中文",
    tr     = "Türkçe",
    en_pt  = "Pirate"
}

Radio.LanguageManager.currentLanguage = "en"
Radio.LanguageManager.translations = include("rradio/client/lang/cl_localisation_strings.lua")

Radio.LanguageManager.countryTranslationsA = include("rradio/client/data/langpacks/data_1.lua")
Radio.LanguageManager.countryTranslationsB = include("rradio/client/data/langpacks/data_2.lua")
Radio.LanguageManager.countryTranslationsC = include("rradio/client/data/langpacks/data_3.lua")

Radio.LanguageManager.countryTranslations = {}

for _, pack in ipairs{
    Radio.LanguageManager.countryTranslationsA,
    Radio.LanguageManager.countryTranslationsB,
    Radio.LanguageManager.countryTranslationsC
} do
    table.Merge(Radio.LanguageManager.countryTranslations, pack)
end

local gmodLang = GetConVar("gmod_language")

function Radio.LanguageManager:GetClientLanguageCode()
    local raw = (gmodLang and gmodLang:GetString()) or "en"
    raw = raw:lower():gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
    local langMap = {
        english = "en", german = "de", spanish = "es_es", ["español"] = "es_es",
        french = "fr", ["français"] = "fr", italian = "it", ["italiano"] = "it",
        japanese = "ja", korean = "ko", portuguese = "pt_br", pt_br = "pt_br",
        russian = "ru", chinese = "zh_cn", ["simplified_chinese"] = "zh_cn",
        turkish = "tr", pirate_english = "en_pt", en_pt = "en_pt"
    }
    return langMap[raw] or raw
end

function Radio.LanguageManager:UpdateCurrentLanguage()
    self.currentLanguage = self:GetClientLanguageCode()
    Config.Lang = self.translations[self.currentLanguage] or {}
end

function Radio.LanguageManager:GetCountryTranslation(country_key)
    local lang = self.currentLanguage or "en"
    local translations = self.countryTranslations[lang]
    return (translations and translations[country_key]) or country_key
end

function Radio.LanguageManager:Translate(key)
    return self:GetTranslation(self.currentLanguage, key)
end

function Radio.LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

function Radio.LanguageManager:GetAvailableLanguages()
    return self.languages
end

function Radio.LanguageManager:GetTranslation(lang, key)
    if self.translations[lang] and self.translations[lang][key] then
        return self.translations[lang][key]
    end
    return key
end

function Radio.LanguageManager:GetCustomKey()
    return Config.CustomStationCategory or "Custom"
end

function Radio.LanguageManager:GetCustomTranslation()
    local lang = Radio.Settings and Radio.Settings.Language
                  or self.currentLanguage or "en"

    local pack = self.translations[lang] or self.translations["en"] or {}
    return pack["Custom"] or "Custom Radio Stations"
end

return Radio.LanguageManager
