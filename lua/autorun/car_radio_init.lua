local CURRENT_VERSION = "v1.2.1"
local GITHUB_API_URL = "https://api.github.com/repos/charles-mills/rradio/releases/latest"

local function checkVersion() -- In case locally installed
    http.Fetch(GITHUB_API_URL,
        function(body)
            local data = util.JSONToTable(body)
            if data and data.tag_name then
                local latestVersion = string.Trim(data.tag_name)
                if latestVersion ~= CURRENT_VERSION then
                    print("[rRadio] A new version is available: " .. latestVersion)
                    print("[rRadio] Please update your rRadio addon.")
                else
                    print("[rRadio] rRadio is up to date (version " .. CURRENT_VERSION .. ")")
                end
            else
                print("[rRadio] Failed to parse version information")
            end
        end,
        function(error)
            print("[rRadio] Failed to check for updates: " .. error)
        end
    )
end

if SERVER then
    print("[RADIO] Starting server-side initialization")
    checkVersion()
    
    -- Load the config file first to get the network strings
    Config = include("misc/config.lua")
    
    -- Register all network strings
    for _, str in ipairs(NETWORK_STRINGS) do
        util.AddNetworkString(str)
    end
    
    -- Add all the necessary Lua files for the client
    AddCSLuaFile("misc/config.lua")
    AddCSLuaFile("localisation/language_manager.lua")
    AddCSLuaFile("localisation/country_translations.lua")
    AddCSLuaFile("radio/cl_init.lua")
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("menus/settings_menu.lua")
    AddCSLuaFile("misc/theme_palettes.lua")
    AddCSLuaFile("misc/key_names.lua")
    AddCSLuaFile("misc/utils.lua")
    AddCSLuaFile("menus/friends_menu.lua")

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
    include("misc/theme_palettes.lua")
    include("menus/settings_menu.lua")
    include("misc/key_names.lua")
    include("radio/cl_radio.lua")
    include("misc/utils.lua")
    include("menus/friends_menu.lua")
    
    print("[RADIO] Finished client-side initialization")
end