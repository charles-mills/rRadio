include("misc/config.lua")
include("misc/utils.lua")

CreateClientConVar("radio_max_volume", 1, true, false)
CreateClientConVar("radio_theme", "dark", true, false)
CreateClientConVar("car_radio_show_messages", "1", true, false, "Enable or disable rRadio messages.")
CreateClientConVar("car_radio_verbose_mode", "0", true, false, "Enable or disable verbose mode for rRadio error handling.")
CreateClientConVar("car_radio_debug_mode", "0", true, false, "Enable or disable debug mode for rRadio.")

cvars.AddChangeCallback("car_radio_verbose_mode", function(convar_name, value_old, value_new)
    if convar_name == "car_radio_verbose_mode" then
        utils.VERBOSE_MODE = tobool(value_new)
    elseif
        convar_name == "car_radio_debug_mode" then
        utils.DEBUG_MODE = tobool(value_new)
    end
end)