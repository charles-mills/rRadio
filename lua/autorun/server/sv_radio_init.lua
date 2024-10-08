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

-- Add consolidated station files
local files = file.Find("radio/stations/data_*.lua", "LUA")
-- print("[RADIO] Found " .. #files .. " station files")

for _, filename in ipairs(files) do
    AddCSLuaFile("radio/stations/" .. filename)
    -- print("[RADIO] Added station file: " .. filename)
end

-- Register all network strings
if Config.NETWORK_STRINGS and type(Config.NETWORK_STRINGS) == "table" then
    for _, str in ipairs(Config.NETWORK_STRINGS) do
        util.AddNetworkString(str)
    end
else
    print("[RADIO] Error: Config.NETWORK_STRINGS is not properly defined")
end

-- Add entire materials and models directories
resource.AddFile("materials")
resource.AddFile("models")

-- Include the base_boombox init file
include("entities/base_boombox/init.lua")

-- Function to set up Use for boomboxes
local function SetupBoomboxUse(ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        if ENT and ENT.SetupUse then
            ent:SetupUse()
            print("Set up Use function for boombox: " .. ent:EntIndex())
        else
            print("Warning: ENT.SetupUse not found for boombox: " .. ent:EntIndex())
        end
    end
end

-- Set up Use for all existing boomboxes
for _, ent in ipairs(ents.GetAll()) do
    SetupBoomboxUse(ent)
end

-- Set up Use for newly created boomboxes
hook.Add("OnEntityCreated", "SetupBoomboxUseGlobal", function(ent)
    timer.Simple(0, function()
        SetupBoomboxUse(ent)
    end)
end)

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

print("[RADIO] Finished server-side initialization")