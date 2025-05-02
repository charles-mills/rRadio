rRadio.LanguageManager = {}
rRadio.LanguageManager.languages = {
    de = "Deutsch",
    en = "English",
    es = "Español",
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
rRadio.LanguageManager.translations = include("cl_localisation_strings.lua")
rRadio.LanguageManager.countryTranslationsA = include("cl_country_translations_a.lua")
rRadio.LanguageManager.countryTranslationsB = include("cl_country_translations_b.lua")
rRadio.LanguageManager.countryTranslations = {}

for lang, translations in pairs(rRadio.LanguageManager.countryTranslationsA) do
    if type(translations) == "table" then
        rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
        for k, v in pairs(translations) do
            rRadio.LanguageManager.countryTranslations[lang][k] = v
        end
    end
end

for lang, translations in pairs(rRadio.LanguageManager.countryTranslationsB) do
    if type(translations) == "table" then
        rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
        for k, v in pairs(translations) do
            rRadio.LanguageManager.countryTranslations[lang][k] = v
        end
    end
end

local function getClientLanguageCode()
    local raw = GetConVar("gmod_language"):GetString() or "en"
    raw = raw:lower():gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
    local langMap = {
        english = "en", german = "de", spanish = "es", ["español"] = "es",
        french = "fr", ["français"] = "fr", italian = "it", ["italiano"] = "it",
        japanese = "ja", korean = "ko", portuguese = "pt_br", ["pt_br"] = "pt_br",
        russian = "ru", chinese = "zh_cn", ["simplified_chinese"] = "zh_cn",
        turkish = "tr", pirate_english = "en_pt", ["en_pt"] = "en_pt"
    }
    return langMap[raw] or raw
end

function rRadio.LanguageManager:GetCountryTranslation(country_key)
    local lang = getClientLanguageCode()
    local translations = self.countryTranslations[lang]
    if translations and translations[country_key] then
        return translations[country_key]
    end
    return country_key
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
    if self.translations[lang] and self.translations[lang][key] then
        return self.translations[lang][key]
        end
    return key
end

return rRadio.LanguageManager