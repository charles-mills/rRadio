rRadio.LanguageManager = {}
rRadio.LanguageManager.languages = {
    de = "Deutsch",
    en = "English",
    es_es = "Español",
    fr = "Français",
    it = "Italiano",
    ja = "日本語",
    ko = "한국어",
    pt_br = "Português (Brasil)",
    ru = "Русский",
    zh_cn = "简体中文",
    tr = "Türkçe",
    en_pt = "Pirate"
}

rRadio.LanguageManager.currentLanguage = "en"
rRadio.LanguageManager.translations = include("rradio/client/lang/cl_localisation_strings.lua")
rRadio.LanguageManager.countryTranslationsA = include("rradio/client/data/langpacks/data_1.lua")
rRadio.LanguageManager.countryTranslationsB = include("rradio/client/data/langpacks/data_2.lua")
rRadio.LanguageManager.countryTranslationsC = include("rradio/client/data/langpacks/data_3.lua")
rRadio.LanguageManager.countryTranslations = {}
for _, pack in ipairs{rRadio.LanguageManager.countryTranslationsA, rRadio.LanguageManager.countryTranslationsB, rRadio.LanguageManager.countryTranslationsC} do
    table.Merge(rRadio.LanguageManager.countryTranslations, pack)
end

local gmodLang = GetConVar("gmod_language")
function rRadio.LanguageManager:GetClientLanguageCode()
    local raw = (gmodLang and gmodLang:GetString()) or "en"
    raw = raw:lower():gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
    local langMap = {
        english = "en",
        german = "de",
        spanish = "es_es",
        ["español"] = "es_es",
        french = "fr",
        ["français"] = "fr",
        italian = "it",
        ["italiano"] = "it",
        japanese = "ja",
        korean = "ko",
        portuguese = "pt_br",
        pt_br = "pt_br",
        russian = "ru",
        chinese = "zh_cn",
        ["simplified_chinese"] = "zh_cn",
        turkish = "tr",
        pirate_english = "en_pt",
        en_pt = "en_pt"
    }
    return langMap[raw] or raw
end

function rRadio.LanguageManager:UpdateCurrentLanguage()
    self.currentLanguage = self:GetClientLanguageCode()
    rRadio.config.Lang = self.translations[self.currentLanguage] or {}
end

function rRadio.LanguageManager:GetCountryTranslation(country_key)
    local lang = self.currentLanguage or "en"
    local translations = self.countryTranslations[lang]
    return (translations and translations[country_key]) or country_key
end

function rRadio.LanguageManager:Translate(key)
    return self:GetTranslation(self.currentLanguage, key)
end

function rRadio.LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

function rRadio.LanguageManager:GetAvailableLanguages()
    return self.languages
end

function rRadio.LanguageManager:GetTranslation(lang, key)
    if self.translations[lang] and self.translations[lang][key] then return self.translations[lang][key] end
    return key
end

function rRadio.LanguageManager:GetCustomKey()
    return rRadio.config.CustomStationCategory or "Custom"
end

function rRadio.LanguageManager:GetCustomTranslation()
    local lang = rRadio.Settings and rRadio.Settings.Language or self.currentLanguage or "en"
    local pack = self.translations[lang] or self.translations["en"] or {}
    return pack["Custom"] or "Custom Radio Stations"
end
return rRadio.LanguageManager
