/*
Adding a new Language?

1) Add your language code to the languages table below. The key should be the language code (e.g., "fr" for French), and the value should be the display name of the language (e.g., "Français").
2) Create a new Lua file in the 'radio/lang/' directory with the name of your language code (e.g., 'fr.lua' for French).
3) Add translations for each key in the 'radio/lang/en.lua' file to your new language file.
4) Complete country translations by accessing country_translations.lua and adding translations for each country name (optional).
4) Submit a pull request and your language will be added to the official addon :)
*/


local Languages = include("localisation/languages.lua")

local LanguageManager = {}
LanguageManager.languages = Languages.Available
LanguageManager.translations = Languages.Strings

LanguageManager.currentLanguage = "en"

function LanguageManager:SetLanguage(code)
    if self.translations[code] then
        self.currentLanguage = code
    else
        print("[LanguageManager] Language not found! Falling back to English.")
        self.currentLanguage = "en"
    end
end

function LanguageManager:Translate(key)
    local translation = self.translations[self.currentLanguage][key]
    if translation then
        return translation
    else
        return self.translations["en"][key] or key
    end
end

function LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

function LanguageManager:GetAvailableLanguages()
    return self.languages
end

return LanguageManager