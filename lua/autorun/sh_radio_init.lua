--[[

           /$$$$$$$                  /$$ /$$          
          | $$__  $$                | $$|__/          
  /$$$$$$ | $$  \ $$  /$$$$$$   /$$$$$$$ /$$  /$$$$$$ 
 /$$__  $$| $$$$$$$/ |____  $$ /$$__  $$| $$ /$$__  $$
| $$  \__/| $$__  $$  /$$$$$$$| $$  | $$| $$| $$  \ $$
| $$      | $$  \ $$ /$$__  $$| $$  | $$| $$| $$  | $$
| $$      | $$  | $$|  $$$$$$$|  $$$$$$$| $$|  $$$$$$/
|__/      |__/  |__/ \_______/ \_______/|__/ \______/ 

Discord: crjmx
Steam: https://steamcommunity.com/id/rammel/

]]

local cl_count = 1
local cl_load_count = 0

local dev_id = "3465709662"
local pub_id = "3318060741"
local DEV = false

local function formattedOutput(text)
    if SERVER then
        MsgC(Color(0, 200, 255), "[rRADIO] ", Color(255, 255, 255), text .. "\n")
    elseif CLIENT then
        MsgC(Color(0, 255, 0), "[rRADIO] ", Color(255, 255, 255), text .. "\n")
    end
end

local function addClientFile(filename)
    include("radio/" .. filename)
    cl_count = cl_count + 1
end

local function addCSLua(filename)
    AddCSLuaFile(filename)
    cl_load_count = cl_load_count + 1
end

local function addCSLuaFiles()
    local dirs = {
        "radio/shared",
        "radio/client",
        "radio/client/lang",
        "radio/client/stations",
        "entities/base_boombox",
        "entities/boombox",
        "entities/golden_boombox"
    }
    for _, dir in ipairs(dirs) do
        for _, f in ipairs(file.Find(dir .. "/*.lua", "LUA")) do
            addCSLua(dir .. "/" .. f)
        end
    end
end

local function addList()
    list.Set(
        "SpawnableEntities",
        "boombox",
        {
            PrintName = "Boombox",
            ClassName = "boombox",
            Category = "Radio",
            AdminOnly = false,
            Model = "models/rammel/boombox.mdl",
            Description = "A basic boombox, ready to play some music!"
        }
    )
    list.Set(
        "SpawnableEntities",
        "golden_boombox",
        {
            PrintName = "Golden Boombox",
            ClassName = "golden_boombox",
            Category = "Radio",
            AdminOnly = true,
            Model = "models/rammel/boombox.mdl",
            Description = "A boombox with an extreme audio range!"
        }
    )
end

if SERVER then
    local resourceStr = ""

    if DEV then
        resourceStr = "developer"
        resource.AddWorkshop(dev_id)
    else
        resourceStr = "public"
        resource.AddWorkshop(pub_id)
    end

    formattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    formattedOutput("Assigned " .. cl_load_count .. " client-side files")
    formattedOutput("Assigned " .. resourceStr .. " resource files")
    addList()
    formattedOutput("Assigned entities to client spawn list")
    include("radio/server/sv_core.lua")
    formattedOutput("Finished server-side initialization")
else
    formattedOutput("Starting client-side initialization")
    Config = include("radio/shared/sh_config.lua")

    addClientFile("client/lang/cl_language_manager.lua")
    addClientFile("client/cl_themes.lua")
    addClientFile("client/cl_settings.lua")
    addClientFile("client/cl_key_names.lua")
    addClientFile("client/cl_core.lua")
    addClientFile("shared/sh_utils.lua")
    addClientFile("client/lang/cl_localisation_strings.lua")
    addClientFile("client/lang/cl_country_translations_b.lua")

    for _, f in ipairs(file.Find("radio/client/stations/*.lua", "LUA")) do
        addClientFile("client/stations/" .. f)
    end

    formattedOutput("Loaded " .. cl_count .. "/37 client-side files")
    formattedOutput("Finished client-side initialization")
end
