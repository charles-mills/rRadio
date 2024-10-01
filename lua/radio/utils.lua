-- utils.lua

utils = utils or {}
utils.debug_mode = false

-- Function: isSitAnywhereSeat
-- Description: Checks if a vehicle is a "sit anywhere" seat.
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
end

-- Function: formatCountryName
-- Description: Formats a country name by replacing underscores and dashes with spaces, and capitalizing words.
function utils.formatCountryName(name)
    local formattedName = name:gsub("[-_]", " "):gsub("(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    return formattedName
end

-- Function: getEntityConfig
-- Description: Returns the radio configuration for a given entity.
function utils.getEntityConfig(entity)
    local entityClass = entity:GetClass()
    
    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    else
        return nil
    end
end

-- Include themes and language manager
local themes = include("themes.lua")
local languageManager = include("language_manager.lua")

-- Function: applyTheme
-- Description: Applies the selected theme to the Config.
function utils.applyTheme(themeName)
    if themes[themeName] then
        Config.UI = themes[themeName]
        hook.Run("ThemeChanged", themeName)
    else
        print("Invalid theme name: " .. themeName)
    end
end

-- Function: applyLanguage
-- Description: Applies the selected language to the Config.
function utils.applyLanguage(languageCode)
    if languageManager.languages[languageCode] then
        Config.Lang = languageManager.translations[languageCode]
        hook.Run("LanguageChanged", languageCode)
        hook.Run("LanguageUpdated")
    else
        print("Invalid language code: " .. languageCode)
    end
end

-- Function: loadSavedSettings
-- Description: Loads and applies the saved theme and language from ConVars.
function utils.loadSavedSettings()
    local themeName = GetConVar("radio_theme"):GetString()
    utils.applyTheme(themeName)

    local languageCode = GetConVar("radio_language"):GetString()
    utils.applyLanguage(languageCode)
end

-- Function: DebugPrint
-- Description: Prints debug messages if debug_mode is enabled.
function utils.DebugPrint(msg)
    if utils.debug_mode then
        print("[CarRadio Debug] " .. msg)
    end
end