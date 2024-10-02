include("misc/utils.lua")

CreateClientConVar("radio_max_volume", 1, true, false)
CreateClientConVar("radio_theme", "dark", true, false)
CreateClientConVar("radio_show_messages", "1", true, false, "Enable or disable car radio messages.")
CreateClientConVar("radio_debug_mode", "0", true, false, "Enable or disable debug mode for the radio.")
CreateClientConVar("radio_verbose_errors", "0", true, false, "Enable or disable verbose errors for the radio.")

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

cvars.AddChangeCallback("radio_debug_mode", function(convar_name, value_old, value_new)
    UpdateRadioSettings()
end, "RadioDebugModeChange")

cvars.AddChangeCallback("radio_verbose_errors", function(convar_name, value_old, value_new)
    UpdateRadioSettings()
end, "RadioVerboseErrorsChange")

UpdateRadioSettings()

include("misc/config.lua")