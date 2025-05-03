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
rRadio.DEV = true

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
    include("rradio/" .. filename)
    cl_count = cl_count + 1
end

local function addCSLua(filename)
    AddCSLuaFile(filename)
    cl_load_count = cl_load_count + 1
end

local function addCSLuaFiles()
    local dirs = {
        "rradio/shared",
        "rradio/client",
        "rradio/client/lang",
        "rradio/client/stations",
        "entities/rammel_base_boombox",
        "entities/rammel_boombox",
        "entities/rammel_boombox_gold"
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

if SERVER then
    local resourceStr = ""

    resourceStr = rRadio.DEV and "developer" or "public"
    resource.AddWorkshop(rRadio.DEV and dev_id or pub_id)

    rRadio.FormattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client-side files")
    rRadio.FormattedOutput("Assigned " .. resourceStr .. " resource files") 
    include("rradio/shared/sh_config.lua")
    include("rradio/shared/sh_utils.lua")
    include("rradio/server/sv_utils.lua")
    include("rradio/server/sv_core.lua")
    include("rradio/server/sv_permanent.lua")
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

    for _, f in ipairs(file.Find("rradio/client/stations/*.lua", "LUA")) do
        addClientFile("client/stations/" .. f)
    end

    addPrivileges()

    rRadio.FormattedOutput("Loaded " .. cl_count .. "/37 client-side files")
    rRadio.FormattedOutput("Finished client-side initialization")
end