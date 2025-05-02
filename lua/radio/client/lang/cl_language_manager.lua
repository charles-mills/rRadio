-- rRadio Language Manager
-- Enhanced logic, optimized performance, and support for volume UI translations

rRadio.LanguageManager = rRadio.LanguageManager or {}

-- State
rRadio.LanguageManager.state = rRadio.LanguageManager.state or {
    currentLanguage = "en",
    clientLanguageCode = nil
}

-- Supported languages
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

-- Load translation tables
rRadio.LanguageManager.translations = include("cl_localisation_strings.lua") or {}
rRadio.LanguageManager.countryTranslationsA = include("cl_country_translations_a.lua") or {}
rRadio.LanguageManager.countryTranslationsB = include("cl_country_translations_b.lua") or {}
rRadio.LanguageManager.countryTranslations = {}

-- Merge country translations
for lang, translations in pairs(rRadio.LanguageManager.countryTranslationsA) do
    if type(translations) == "table" and rRadio.LanguageManager.languages[lang] then
        rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
        for key, value in pairs(translations) do
            if type(key) == "string" and type(value) == "string" then
                rRadio.LanguageManager.countryTranslations[lang][key] = value
            end
        end
    else
        ErrorNoHalt("[rRadio] Invalid country translations A for lang: " .. tostring(lang) .. "\n")
    end
end

for lang, translations in pairs(rRadio.LanguageManager.countryTranslationsB) do
    if type(translations) == "table" and rRadio.LanguageManager.languages[lang] then
        rRadio.LanguageManager.countryTranslations[lang] = rRadio.LanguageManager.countryTranslations[lang] or {}
        for key, value in pairs(translations) do
            if type(key) == "string" and type(value) == "string" then
                rRadio.LanguageManager.countryTranslations[lang][key] = value
            end
        end
    else
        ErrorNoHalt("[rRadio] Invalid country translations B for lang: " .. tostring(lang) .. "\n")
    end
end

-- Get client language code
local function getClientLanguageCode()
    if rRadio.LanguageManager.state.clientLanguageCode then
        return rRadio.LanguageManager.state.clientLanguageCode
    end

    local raw = (GetConVar("gmod_language"):GetString() or "en"):lower()
    raw = raw:gsub("%s+", "_"):gsub("-", "_"):gsub("[()]", "")
    
    local langMap = {
        english = "en", german = "de", spanish = "es", ["español"] = "es",
        french = "fr", ["français"] = "fr", italian = "it", ["italiano"] = "it",
        japanese = "ja", korean = "ko", portuguese = "pt_br", ["pt_br"] = "pt_br",
        russian = "ru", chinese = "zh_cn", ["simplified_chinese"] = "zh_cn",
        turkish = "tr", pirate_english = "en_pt", ["en_pt"] = "en_pt"
    }

    local code = langMap[raw] or "en"
    if not rRadio.LanguageManager.languages[code] then
        code = "en"
        ErrorNoHalt("[rRadio] Unsupported language code: " .. tostring(raw) .. ", defaulting to English\n")
    end

    rRadio.LanguageManager.state.clientLanguageCode = code
    return code
end

-- Set current language
function rRadio.LanguageManager:SetLanguage(lang)
    if self.languages[lang] then
        self.state.currentLanguage = lang
        self.state.clientLanguageCode = nil -- Force refresh of client language code
        hook.Run("LanguageChanged", lang)
        if radioMenuOpen then
            -- Refresh UI translations
            hook.Run("rRadio.RefreshMenuTranslations")
        end
    else
        ErrorNoHalt("[rRadio] Invalid language code: " .. tostring(lang) .. "\n")
    end
end

-- Get country translation
function rRadio.LanguageManager:GetCountryTranslation(country_key)
    local lang = getClientLanguageCode()
    local translations = self.countryTranslations[lang] or self.countryTranslations.en
    return translations and translations[country_key] or self.countryTranslations.en[country_key] or country_key
end

-- Translate a key
function rRadio.LanguageManager:Translate(key)
    return self:GetTranslation(self.state.currentLanguage, key)
end

-- Get language name
function rRadio.LanguageManager:GetLanguageName(code)
    return self.languages[code] or code
end

-- Get available languages
function rRadio.LanguageManager:GetAvailableLanguages()
    return self.languages
end

-- Get translation for a specific language and key
function rRadio.LanguageManager:GetTranslation(lang, key)
    if not key then return "" end
    if self.languages[lang] and self.translations[lang] and self.translations[lang][key] then
        return self.translations[lang][key]
    end
    if self.translations.en and self.translations.en[key] then
        return self.translations.en[key]
    end
    ErrorNoHalt("[rRadio] Missing translation for key: " .. tostring(key) .. " in lang: " .. tostring(lang) .. "\n")
    return tostring(key)
end

-- Hook to refresh menu translations
hook.Add("rRadio.RefreshMenuTranslations", "rRadio.UpdateMenuTranslations", function()
    if not radioMenuOpen or not IsValid(radioMenu) then return end
    -- Update header
    if IsValid(radioMenu.header) then
        radioMenu.header:SetText(rRadio.LanguageManager:Translate("SelectCountry"))
    end
    -- Update search bar placeholder
    if IsValid(radioMenu.searchBox) then
        radioMenu.searchBox:SetPlaceholderText(rRadio.LanguageManager:Translate("Search"))
    end
    -- Update stop button
    if IsValid(radioMenu.stopButton) then
        radioMenu.stopButton:SetText(rRadio.LanguageManager:Translate("Stop"))
    end
    -- Update station buttons
    if IsValid(radioMenu.stationListPanel) then
        for _, button in pairs(radioMenu.stationListPanel:GetChildren()) do
            if IsValid(button) and button.country then
                button:SetText(rRadio.LanguageManager:GetCountryTranslation(button.country))
            end
        end
    end
    -- Update volume panel tooltip
    if IsValid(radioMenu.volumePanel) then
        radioMenu.volumePanel:SetTooltip(rRadio.LanguageManager:Translate("Volume"))
    end
end)

-- Initialize language
hook.Add("InitPostEntity", "rRadio.InitializeLanguage", function()
    rRadio.LanguageManager:SetLanguage(getClientLanguageCode())
end)

return rRadio.LanguageManager
