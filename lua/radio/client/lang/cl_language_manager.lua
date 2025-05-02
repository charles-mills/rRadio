-- Language manager for radio UI translations
rRadio.LanguageManager = {}

-- Supported languages with display names
rRadio.LanguageManager.languages = {
    ["de"] = "Deutsch",
    ["en"] = "English",
    ["es"] = "Español",
    ["fr"] = "Français",
    ["it"] = "Italiano",
    ["ja"] = "日本語",
    ["ko"] = "한국어",
    ["pt-br"] = "Português (Brasil)",
    ["ru"] = "Русский",
    ["zh-cn"] = "简体中文",
    ["tr"] = "Türkçe",
    ["en-pt"] = "Pirate"
}

-- Default language
rRadio.LanguageManager.currentLanguage = "en"

-- Initialize translation tables
rRadio.LanguageManager.translations = include("cl_localisation_strings.lua") or {}
rRadio.LanguageManager.countryTranslations = {}

-- Merge country translations from multiple sources
local function mergeTranslations(source)
    if not source then return end
    for lang, translations in pairs(source) do
        rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
        for k, v in pairs(translations) do
            if type(k) == "string" and type(v) == "string" then
                rRadio.LanguageManager.countryTranslations[lang][k] = v
            end
        end
    end
end

mergeTranslations(include("cl_country_translations_a.lua"))
mergeTranslations(include("cl_country_translations_b.lua"))

-- Language code mapping for GMod settings
local languageMap = {
    english = "en",
    german = "de",
    spanish = "es",
    ["español"] = "es",
    french = "fr",
    ["français"] = "fr",
    italian = "it",
    ["italiano"] = "it",
    japanese = "ja",
    korean = "ko",
    portuguese = "pt-br",
    pt_br = "pt-br",
    russian = "ru",
    chinese = "zh-cn",
    simplified_chinese = "zh-cn",
    turkish = "tr",
    pirate_english = "en-pt",
    en_pt = "en-pt"
}

-- Cache for client language code
local cachedLanguageCode = nil

-- Normalize and map client language code
local function getClientLanguageCode()
    if cachedLanguageCode then return cachedLanguageCode end
    local raw = (GetConVar("gmod_language") and GetConVar("gmod_language"):GetString() or "en"):lower()
    raw = raw:gsub("[^a-z0-9]", "")
    cachedLanguageCode = languageMap[raw] or "en"
    return cachedLanguageCode
end

-- Get country translation with fallback
function rRadio.LanguageManager:GetCountryTranslation(country_key)
    if not country_key or type(country_key) ~= "string" then return country_key or "Unknown" end
    local lang = getClientLanguageCode()
    local translations = self.countryTranslations[lang] or self.countryTranslations["en"] or {}
    return translations[country_key] or self.countryTranslations["en"][country_key] or country_key
end

-- Get UI translation for a key
function rRadio.LanguageManager:Translate(key)
    if not key or type(key) ~= "string" then return key or "Invalid Key" end
    return self:GetTranslation(self.currentLanguage, key)
end

-- Get display name for a language code
function rRadio.LanguageManager:GetLanguageName(code)
    return self.languages[code] or code or "Unknown"
end

-- Get available languages
function rRadio.LanguageManager:GetAvailableLanguages()
    return self.languages
end

-- Get translation for a specific language and key
function rRadio.LanguageManager:GetTranslation(lang, key)
    if not lang or not key or type(lang) ~= "string" or type(key) ~= "string" then
        return key or "Invalid Key"
    end
    local translations = self.translations[lang] or self.translations["en"] or {}
    return translations[key] or self.translations["en"][key] or key
end

return rRadio.LanguageManager
