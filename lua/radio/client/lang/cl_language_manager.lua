/*
Adding a new Language?

1) Add your language code to the languages table below. The key should be the language code (e.g., "fr" for French), and the value should be the display name of the language (e.g., "Français").
2) Create a new Lua file in the 'radio/client/lang/' directory with the name of your language code (e.g., 'fr.lua' for French).
3) Add translations for each key in the 'radio/client/lang/en.lua' file to your new language file.
4) Complete country translations by accessing country_translations.lua and adding translations for each country name (optional).
4) Submit a pull request and your language will be added to the official addon :)
*/


local LanguageManager = {}

LanguageManager.languages = {
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
}

LanguageManager.translations = include("cl_localisation_strings.lua")
LanguageManager.countryTranslations = include("cl_country_translations.lua")

LanguageManager.GetCountryName = LanguageManager.countryTranslations.GetCountryName

-- Function to get a country translation
function LanguageManager:GetCountryTranslation(lang, country_key)
    -- Reformat the country name (e.g., "the_united_kingdom" -> "The United Kingdom")
    local formattedName = country_key:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. string.lower(b) end)
    
    -- Get the translated name if it exists and is not empty; otherwise, use the formatted name
    local translatedName = self.countryTranslations[lang] and self.countryTranslations[lang][formattedName]
    if translatedName == nil or translatedName == "" then
        translatedName = formattedName
    end
    
    return translatedName
end

-- Function to set the current language (default to English)
LanguageManager.currentLanguage = "en"

function LanguageManager:SetLanguage(code)
    if self.translations[code] then
        self.currentLanguage = code
    else
        print("[LanguageManager] Language not found! Falling back to English.")
        self.currentLanguage = "en"
    end
end

-- Function to get the current language's translation
function LanguageManager:Translate(key)
    return self:GetTranslation(self.currentLanguage, key)
end

-- Function to get the display name of a language
function LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

-- Function to get all available languages
function LanguageManager:GetAvailableLanguages()
    return self.languages
end

-- Function to get a translation for a specific language
function LanguageManager:GetTranslation(lang, key)
    if self.translations[lang] and self.translations[lang][key] then
        return self.translations[lang][key]
    end
    return key -- Return the key if translation is not found
end

return LanguageManager
