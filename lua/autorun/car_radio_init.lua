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
    
    -- Dynamically include all radio station files
    local files = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(files) do
        AddCSLuaFile("radio/stations/" .. filename)
    end
    
    -- Include the server-side radio logic
    include("radio/sv_radio.lua")
    
    print("[RADIO] Finished server-side initialization")
else
    print("[RADIO] Starting client-side initialization")
    
    -- Include all necessary files for the client
    Config = include("radio/config.lua")
    include("language_manager.lua")
    include("country_translations.lua")
    include("radio/cl_radio.lua")
    include("themes.lua")
    include("radio/theme_menu.lua")
    include("radio/key_names.lua")
    include("radio/cl_init.lua")
    
    print("[RADIO] Finished client-side initialization")
end
