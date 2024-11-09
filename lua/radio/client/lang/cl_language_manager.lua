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
LanguageManager.currentLanguage = "en"
LanguageManager.translations = include("cl_localisation_strings.lua")
LanguageManager.countryTranslationsA = include("cl_country_translations_a.lua")
LanguageManager.countryTranslationsB = include("cl_country_translations_b.lua")
LanguageManager.countryTranslations = {}
for lang, translations in pairs(LanguageManager.countryTranslationsA) do
if type(translations) == "table" then
LanguageManager.countryTranslations[lang] = LanguageManager.countryTranslations[lang] or {}
for k, v in pairs(translations) do
LanguageManager.countryTranslations[lang][k] = v
end
end
end
for lang, translations in pairs(LanguageManager.countryTranslationsB) do
if type(translations) == "table" then
LanguageManager.countryTranslations[lang] = LanguageManager.countryTranslations[lang] or {}
for k, v in pairs(translations) do
LanguageManager.countryTranslations[lang][k] = v
end
end
end
function LanguageManager:GetCountryTranslation(lang, country_key)
if self.countryTranslations[lang] then
local translation = self.countryTranslations[lang][country_key]
if translation then
return translation
end
end
return country_key
end
function LanguageManager:SetLanguage(code)
if self.translations[code] then
self.currentLanguage = code
else
print("[LanguageManager] Language not found! Falling back to English.")
self.currentLanguage = "en"
end
end
function LanguageManager:Translate(key)
return self:GetTranslation(self.currentLanguage, key)
end
function LanguageManager:GetLanguageName(code)
return self.languages[code] or code
end
function LanguageManager:GetAvailableLanguages()
return self.languages
end
function LanguageManager:GetTranslation(lang, key)
if self.translations[lang] and self.translations[lang][key] then
return self.translations[lang][key]
end
return key
end
return LanguageManager