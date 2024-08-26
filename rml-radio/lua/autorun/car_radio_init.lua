if SERVER then
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("radio/theme_menu.lua")
    AddCSLuaFile("themes.lua")
    AddCSLuaFile("config.lua")
    AddCSLuaFile("radio/cl_init.lua")
    AddCSLuaFile("radio/key_names.lua")
    include("radio/sv_radio.lua")
else
    print("[RADIO] Starting client-side initialization")
    Config = Config or {} -- Ensure Config is initialized
    include("radio/cl_init.lua")
    include("config.lua")
    print(("Config initialized: %s"):format(tostring(Config)))
    print("Config.RadioStations: ", Config.RadioStations)
    include("themes.lua")
    include("radio/cl_radio.lua")
    include("radio/theme_menu.lua")
    include("radio/key_names.lua")
end