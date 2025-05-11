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

local function merge(src)
    for lang, tbl in pairs(src) do
        if type(tbl) == "table" then
            rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
            for k, v in pairs(tbl) do
                rRadio.LanguageManager.countryTranslations[lang][k] = v
            end
        end
    end
end

merge(rRadio.LanguageManager.countryTranslationsA)
merge(rRadio.LanguageManager.countryTranslationsB)
merge(rRadio.LanguageManager.countryTranslationsC)

local function getClientLanguageCode()
    local raw = GetConVar("gmod_language"):GetString() or "en"
    raw = raw:lower():gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
    local langMap = {
        english = "en", german = "de", spanish = "es_es", ["español"] = "es_es",
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