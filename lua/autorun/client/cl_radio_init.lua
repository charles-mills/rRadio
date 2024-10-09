--[[ 
    rRadio Addon for Garry's Mod - Client Initialization
    Description: Initializes client-side components and configurations for the rRadio addon.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-08
]]

-- Include utils.lua first
local utils = include("misc/utils.lua")

-- Create all client-side console variables
CreateClientConVar("radio_max_volume", 1, true, false)
CreateClientConVar("radio_theme", "dark", true, false)
CreateClientConVar("radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
CreateClientConVar("radio_show_boombox_text", "1", true, false, "Show or hide the text above the boombox.")
CreateClientConVar("radio_open_key", "21", true, false, "Select the key to open the car radio menu.") -- Default is KEY_K
CreateClientConVar("radio_debug_mode", "0", true, false, "Enable or disable debug mode for the radio.")
CreateClientConVar("radio_verbose_errors", "0", true, false, "Enable or disable verbose errors for the radio.")

local Config = include("misc/config.lua")
include("misc/key_names.lua")
local themes = include("misc/theme_palettes.lua")
local languageManager = include("localisation/language_manager.lua")
include("localisation/country_translations.lua")
include("localisation/languages.lua")

-- Initialize UI configuration
local function initializeUI()
    local themeName = GetConVar("radio_theme"):GetString()
    if themes[themeName] then
        Config.UI = themes[themeName]
    else
        Config.UI = themes["dark"] -- Default to dark theme if the saved theme is invalid
    end
end

-- Initialize language
local function initializeLanguage()
    local languageCode = GetConVar("radio_language"):GetString()
    if languageManager.translations[languageCode] then
        Config.Lang = languageManager.translations[languageCode]
    else
        Config.Lang = languageManager.translations["en"] -- Default to English if the saved language is invalid
    end
end

-- Call initialization functions
initializeUI()
initializeLanguage()

-- Function to update radio settings
local function UpdateRadioSettings()
    if utils then
        utils.DEBUG_MODE = GetConVar("radio_debug_mode"):GetBool()
        utils.VERBOSE_ERRORS = GetConVar("radio_verbose_errors"):GetBool()
    end
end

-- Add change callbacks for debug and verbose error settings
cvars.AddChangeCallback("radio_debug_mode", UpdateRadioSettings, "RadioDebugModeChange")
cvars.AddChangeCallback("radio_verbose_errors", UpdateRadioSettings, "RadioVerboseErrorsChange")

-- Initial settings update
UpdateRadioSettings()

-- Now include the files that depend on Config.UI and Config.Lang
include("radio/cl_radio.lua")
include("radio/cl_init.lua")
include("menus/settings_menu.lua")
include("menus/friends_menu.lua")

-- Include boombox-related files
include("entities/base_boombox/cl_init.lua")
include("entities/base_boombox/shared.lua")
include("entities/boombox/shared.lua")
include("entities/golden_boombox/shared.lua")

-- Now include the files that depend on Config.UI and Config.Lang
include("radio/cl_radio.lua")
include("radio/cl_init.lua")
include("menus/settings_menu.lua")
include("menus/friends_menu.lua")

-- Include boombox-related files
include("entities/base_boombox/cl_init.lua")
include("entities/base_boombox/shared.lua")
include("entities/boombox/shared.lua")
include("entities/golden_boombox/shared.lua")

-- Add hooks to update UI and language when ConVars change
cvars.AddChangeCallback("radio_theme", function(convar_name, value_old, value_new)
    initializeUI()
    hook.Run("ThemeChanged", value_new)
end, "RadioThemeChange")

cvars.AddChangeCallback("radio_language", function(convar_name, value_old, value_new)
    initializeLanguage()
    hook.Run("LanguageChanged", value_new)
end, "RadioLanguageChange")

print("[rRadio] Finished client-side initialization")