if SERVER then
    print("[RADIO] Starting server-side initialization")
    
    -- Add all the necessary Lua files for the client
    AddCSLuaFile("radio/config.lua")
    AddCSLuaFile("language_manager.lua")
    AddCSLuaFile("country_translations.lua")
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("radio/theme_menu.lua")
    AddCSLuaFile("themes.lua")
    AddCSLuaFile("radio/cl_init.lua")
    AddCSLuaFile("radio/key_names.lua")
    AddCSLuaFile("radio/utils.lua")

    -- Dynamically include all radio station files
    local stationFiles = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(stationFiles) do
        AddCSLuaFile("radio/stations/" .. filename)
    end

    local langFiles = file.Find("radio/lang/*.lua", "LUA")
    for _, filename in ipairs(langFiles) do
        AddCSLuaFile("radio/lang/" .. filename)
    end
    
    -- Include the server-side radio logic
    include("radio/sv_radio.lua")
    
    print("[RADIO] Finished server-side initialization")
else
    print("[RADIO] Starting client-side initialization")
    
    -- Load configuration and other necessary files in the correct order
    Config = include("radio/config.lua")
    include("language_manager.lua")
    include("country_translations.lua")
    include("themes.lua")
    include("radio/theme_menu.lua")
    include("radio/key_names.lua")
    include("radio/cl_init.lua")
    include("radio/cl_radio.lua")
    include("radio/utils.lua")
    
    print("[RADIO] Finished client-side initialization")
end
