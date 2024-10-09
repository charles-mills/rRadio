--[[ 
    rRadio Addon for Garry's Mod - Server Initialization
    Description: Initializes server-side components and configurations for the rRadio addon.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-08
]]

local Config = include("misc/config.lua")
include("misc/utils.lua")
include("radio/sv_radio.lua")

-- Add shared files
AddCSLuaFile("misc/config.lua")
AddCSLuaFile("misc/utils.lua")
AddCSLuaFile("misc/key_names.lua")
AddCSLuaFile("misc/theme_palettes.lua")
AddCSLuaFile("localisation/language_manager.lua")
AddCSLuaFile("localisation/country_translations.lua")
AddCSLuaFile("localisation/languages.lua")

-- Add client-side files
AddCSLuaFile("radio/cl_radio.lua")
AddCSLuaFile("radio/cl_init.lua")
AddCSLuaFile("menus/settings_menu.lua")
AddCSLuaFile("menus/friends_menu.lua")

-- Add boombox-related files
AddCSLuaFile("entities/base_boombox/cl_init.lua")
AddCSLuaFile("entities/base_boombox/shared.lua")
AddCSLuaFile("entities/boombox/shared.lua")
AddCSLuaFile("entities/golden_boombox/shared.lua")

-- Add station files
local files = file.Find("radio/stations/data_*.lua", "LUA")

for _, filename in ipairs(files) do
    AddCSLuaFile("radio/stations/" .. filename)
end

-- Register all network strings
if Config.NETWORK_STRINGS and type(Config.NETWORK_STRINGS) == "table" then
    for _, str in ipairs(Config.NETWORK_STRINGS) do
        util.AddNetworkString(str)
    end
end

resource.AddFile("materials/models/rammel/boombox_base.vtf")
resource.AddFile("materials/models/rammel/boombox_base_n.vtf")
resource.AddFile("materials/models/rammel/boombox_base.vmt")

-- Add entire materials and models directories
resource.AddFile("materials")
resource.AddFile("models")

-- Include the base_boombox init file
include("entities/base_boombox/init.lua")

Config.EnableGoldenBoombox = true

list.Set("SpawnableEntities", "boombox", {
    PrintName = "Boombox",
    ClassName = "boombox",
    Category = "Radio",
    AdminOnly = false,
    Model = "models/rammel/boombox.mdl",
    Description = "A basic boombox, ready to play some music!"
})

list.Set("SpawnableEntities", "golden_boombox", {
    PrintName = "Golden Boombox",
    ClassName = "golden_boombox",
    Category = "Radio",
    AdminOnly = Config.EnableGoldenBoombox or true,  -- Use the config value if available, otherwise default to true
    Model = "models/rammel/boombox.mdl",
    Description = "A boombox with an extreme audio range!"
})

print("[rRadio] Finished server-side initialization")