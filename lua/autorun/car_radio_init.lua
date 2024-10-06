--[[ 
    rRadio Addon for Garry's Mod - Initialization Script
    Description: Initializes the rRadio addon and manages version checking.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

local CURRENT_VERSION = "v1.2.1"
local GITHUB_API_URL = "https://api.github.com/repos/charles-mills/rradio/releases/latest"

local function checkVersion() -- In case locally installed
    http.Fetch(GITHUB_API_URL,
        function(body, size, headers, code)
            if code == 200 then
                local data = util.JSONToTable(body)
                if data and data.tag_name then
                    local latestVersion = string.Trim(data.tag_name)
                    if latestVersion ~= CURRENT_VERSION then
                        print("[rRadio] A new version is available: " .. latestVersion)
                        print("[rRadio] Please update your rRadio addon.")
                        -- Notify admins in-game
                        if SERVER then
                            timer.Simple(5, function()
                                for _, ply in ipairs(player.GetAll()) do
                                    if ply:IsAdmin() then
                                        ply:ChatPrint("[rRadio] A new version is available: " .. latestVersion)
                                    end
                                end
                            end)
                        end
                    else
                        print("[rRadio] rRadio is up to date (version " .. CURRENT_VERSION .. ")")
                    end
                else
                    print("[rRadio] Failed to parse version information")
                end
            else
                print("[rRadio] Failed to check for updates. HTTP Status: " .. code)
            end
        end,
        function(error)
            print("[rRadio] Failed to check for updates: " .. error)
        end
    )
end

local function LoadFiles(isServer)
    local function IncludeFile(file, serverOnly)
        if isServer then
            if serverOnly then
                include(file)
            else
                AddCSLuaFile(file)
                include(file)
            end
        else
            include(file)
        end
    end

    IncludeFile("misc/config.lua")
    IncludeFile("localisation/language_manager.lua")
    IncludeFile("localisation/country_translations.lua")
    IncludeFile("misc/theme_palettes.lua")
    IncludeFile("misc/key_names.lua")
    IncludeFile("misc/utils.lua")
    
    if isServer then
        IncludeFile("radio/sv_radio.lua", true)
    else
        IncludeFile("radio/cl_init.lua")
        IncludeFile("radio/cl_radio.lua")
        IncludeFile("menus/settings_menu.lua")
        IncludeFile("menus/friends_menu.lua")
    end

    -- Dynamically include all radio station files
    local stationFiles = file.Find("radio/stations/*.lua", "LUA")
    for _, filename in ipairs(stationFiles) do
        IncludeFile("radio/stations/" .. filename)
    end

    -- Dynamically include all language files
    local langFiles = file.Find("localisation/lang/*.lua", "LUA")
    for _, filename in ipairs(langFiles) do
        IncludeFile("localisation/lang/" .. filename)
    end
end

if SERVER then
    print("[RADIO] Starting server-side initialization")
    checkVersion()
    
    -- Load the config file first to get the network strings
    local Config = include("misc/config.lua")
    
    -- Check if NETWORK_STRINGS exists and is a table
    if Config.NETWORK_STRINGS and type(Config.NETWORK_STRINGS) == "table" then
        -- Register all network strings
        for _, str in ipairs(Config.NETWORK_STRINGS) do
            util.AddNetworkString(str)
        end
    else
        print("[RADIO] Error: Config.NETWORK_STRINGS is not properly defined")
    end
    
    LoadFiles(true)
    
    print("[RADIO] Finished server-side initialization")
else
    print("[RADIO] Starting client-side initialization")
    LoadFiles(false)
    print("[RADIO] Finished client-side initialization")
end