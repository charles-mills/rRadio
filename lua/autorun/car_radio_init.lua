if SERVER then
    print("[RADIO] Starting server-side initialization")
    
    -- Add all the necessary Lua files for the client
    AddCSLuaFile("misc/config.lua")
    AddCSLuaFile("localisation/language_manager.lua")
    AddCSLuaFile("localisation/country_translations.lua")
    AddCSLuaFile("radio/cl_init.lua")
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("themes/theme_menu.lua")
    AddCSLuaFile("themes/theme_palettes.lua")
    AddCSLuaFile("misc/key_names.lua")
    AddCSLuaFile("misc/utils.lua")

    -- Dynamically include all radio station files
    local stationFiles = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(stationFiles) do
        AddCSLuaFile("radio/stations/" .. filename)
    end

    local langFiles = file.Find("localisation/lang/*.lua", "LUA")
    for _, filename in ipairs(langFiles) do
        AddCSLuaFile("localisation/lang/" .. filename)
    end
    
    -- Include the server-side radio logic
    include("radio/sv_radio.lua")
    
    print("[RADIO] Finished server-side initialization")
else
    print("[RADIO] Starting client-side initialization")
    
    -- Load configuration and other necessary files in the correct order
    Config = include("misc/config.lua")
    include("localisation/language_manager.lua")
    include("localisation/country_translations.lua")
    include("radio/cl_init.lua")
    include("themes/theme_palettes.lua")
    include("themes/theme_menu.lua")
    include("misc/key_names.lua")
    include("radio/cl_radio.lua")
    include("misc/utils.lua")
    
    print("[RADIO] Finished client-side initialization")
end
