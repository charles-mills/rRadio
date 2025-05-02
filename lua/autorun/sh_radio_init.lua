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

local cl_count = 0
local cl_load_count = 0

local dev_id = "3465709662"
local pub_id = "3318060741"

rRadio = rRadio or {}
rRadio.DEV = false

function rRadio.DevPrint(text)
    if not rRadio.DEV then return end

    print("[RRADIO DEV] " .. text .. "\n")
end

function rRadio.FormattedOutput(text)
    if SERVER then
        MsgC(Color(0,200,255), "[rRadio] ", Color(255,255,255), text .. "\n")
    elseif CLIENT then
        MsgC(Color(0,255,0), "[rRadio] ", Color(255,255,255), text .. "\n")
    end
end

function rRadio.addClConVars()
    if not rRadio.config then 
        rRadio.FormattedOutput("[RRADIO] rRadio.config not found, skipping client-side convars")
        return false
    end

    if SERVER then return end
    
    CreateClientConVar("rammel_rradio_vehicle_animation", rRadio.config.AnimationDefaultOn and "1" or "0", true, false, "Toggle the animation upon entering a vehicle.")
    CreateClientConVar("rammel_rradio_boombox_hud", "1", true, false, "Show or hide the HUD for the boombox.")
    CreateClientConVar("rammel_rradio_menu_key", "21", true, false, "Select the key to open the car radio menu.")
    CreateClientConVar("rammel_rradio_menu_theme", "dark", true, false, "Set the theme for the radio.")
    CreateClientConVar("rammel_rradio_enabled", "1", true, false, "Enable or disable rRadio.")

    return true
end

function rRadio.isClientLoadDisabled()
    if not rRadio.config then return end

    if SERVER then return end

    local cv = GetConVar("rammel_rradio_enabled")

    if not cv then
        return false
    end

    return rRadio.config.ClientHardDisable and not cv:GetBool()
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

local function addPrivileges()
    local privs = {
        {
            Name = "rradio.UseAll",
            Description = "Allows a player (typically an admin) to use all boomboxes",
            MinAccess = "superadmin"
        }
    }

    for _, priv in ipairs(privs) do
        CAMI.RegisterPrivilege(priv)
    end
end

local function addList()
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
    AdminOnly = true,
    Model = "models/rammel/boombox.mdl",
    Description = "A boombox with an extreme audio range!"
    })
end

if SERVER then
    local resourceStr = ""

    if rRadio.DEV then
        resourceStr = "developer"
        resource.AddWorkshop(dev_id)
    else
        resourceStr = "public"
        resource.AddWorkshop(pub_id)
    end

    rRadio.FormattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client-side files")
    rRadio.FormattedOutput("Assigned " .. resourceStr .. " resource files") 
    addList()
    rRadio.FormattedOutput("Assigned entities to client spawn list")
    include("radio/shared/sh_config.lua")
    include("radio/shared/sh_utils.lua")
    include("radio/server/sv_core.lua")
    addPrivileges()

    rRadio.FormattedOutput("Finished server-side initialization")
elseif CLIENT then
    addClientFile("shared/sh_utils.lua")
    addClientFile("client/interface/cl_themes.lua")
    addClientFile("client/lang/cl_language_manager.lua")
    addClientFile("shared/sh_config.lua")
    rRadio.addClConVars()

    if (rRadio.isClientLoadDisabled()) then
        rRadio.FormattedOutput("Client-side load disabled")
        rRadio.FormattedOutput("Use rammel_rradio_enabled 1 to re-enable")
        return
    end

    rRadio.FormattedOutput("Starting client-side initialization")
    
    addClientFile("client/interface/cl_interface_utils.lua")
    addClientFile("client/interface/cl_core.lua")

    addClientFile("client/lang/cl_localisation_strings.lua")
    addClientFile("client/lang/cl_country_translations_a.lua")
    addClientFile("client/lang/cl_country_translations_b.lua")

    for _, f in ipairs(file.Find("radio/client/stations/*.lua", "LUA")) do
        addClientFile("client/stations/" .. f)
    end

    addPrivileges()

    rRadio.FormattedOutput("Loaded " .. cl_count .. "/37 client-side files")
    rRadio.FormattedOutput("Finished client-side initialization")
end