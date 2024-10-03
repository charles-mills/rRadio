--[[ 
    rRadio Addon for Garry's Mod - Client Radio Script
    Description: Initializes client-side radio settings and handles configuration changes.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

include("misc/utils.lua")

-- Create client-side console variables
CreateClientConVar("radio_max_volume", 1, true, false)
CreateClientConVar("radio_theme", "dark", true, false)
CreateClientConVar("radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
CreateClientConVar("radio_language", "en", true, false, "Select the language for the radio UI.")
CreateClientConVar("radio_show_boombox_text", "1", true, false, "Show or hide the text above the boombox.")
CreateClientConVar("radio_open_key", "21", true, false, "Select the key to open the car radio menu.") -- Default is KEY_K
CreateClientConVar("radio_debug_mode", "0", true, false, "Enable or disable debug mode for the radio.")
CreateClientConVar("radio_verbose_errors", "0", true, false, "Enable or disable verbose errors for the radio.")

-- Function to update radio settings
local function UpdateRadioSettings()
    local success, err = pcall(function()
        local debugMode = GetConVar("radio_debug_mode"):GetBool()
        local verboseErrors = GetConVar("radio_verbose_errors"):GetBool()

        utils.DEBUG_MODE = debugMode
        utils.VERBOSE_ERRORS = verboseErrors
    end)

    if not success then
        print("Error updating radio settings: " .. err)
    end
end

-- Add change callbacks for console variables
cvars.AddChangeCallback("radio_debug_mode", function(convar_name, value_old, value_new)
    UpdateRadioSettings()
end, "RadioDebugModeChange")

cvars.AddChangeCallback("radio_verbose_errors", function(convar_name, value_old, value_new)
    UpdateRadioSettings()
end, "RadioVerboseErrorsChange")

-- Initial settings update
UpdateRadioSettings()

include("misc/config.lua")