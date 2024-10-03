/*
Adding a new Language?

1) Add your language code to the languages table below. The key should be the language code (e.g., "fr" for French), and the value should be the display name of the language (e.g., "Français").
2) Create a new Lua file in the 'radio/lang/' directory with the name of your language code (e.g., 'fr.lua' for French).
3) Add translations for each key in the 'radio/lang/en.lua' file to your new language file.
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

LanguageManager.translations = {}

-- Function to load and add a language
function LanguageManager:AddLanguage(code, displayName, translations)
    self.translations[code] = translations
    self.languages[code] = displayName
end

-- Function to get a translation
function LanguageManager:GetTranslation(code, key)
    local lang = self.translations[code]
    if lang and lang[key] then
        return lang[key]
    else
        return self.translations["en"] and self.translations["en"][key] or key -- Fallback to English or the key itself
    end
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

-- Function to load language files from the 'radio/lang/' directory
function LanguageManager:LoadLanguageFiles()
    for code, displayName in pairs(self.languages) do
        local path = "localisation/lang/" .. code .. ".lua"
        if file.Exists(path, "LUA") then
            local translations = include(path)
            self:AddLanguage(code, displayName, translations)
        else
            print("[LanguageManager] Language file not found for code: " .. code .. " at path: " .. path)
        end
    end
end

-- Load all language files
LanguageManager:LoadLanguageFiles()

return LanguageManager
