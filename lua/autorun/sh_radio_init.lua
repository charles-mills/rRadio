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
    CreateClientConVar("rammel_rradio_max_volume", "1.0", true, false, "Maximum global radio volume (0.0-1.0)")

    return true
end

function rRadio.isClientLoadDisabled()
    if not rRadio.config then return false end

    if SERVER then return false end

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

local function createFonts()
    surface.CreateFont(
        "rRadio.Roboto24",
        {
            font = "Roboto",
            size = 24,
            weight = 500,
            antialias = true,
            extended = true
        }
    )

    surface.CreateFont(
        "rRadio.Roboto5",
        {
            font = "Roboto",
            size = ScreenScale(5),
            weight = 500,
            antialias = true,
            extended = true
        }
    )

    surface.CreateFont(
        "rRadio.Roboto8",
        {
            font = "Roboto",
            size = ScreenScale(8),
            weight = 700
        }
    )
end

local function addCSLuaFiles()
    local dirs = {
        "rradio/shared",
        "rradio/client",
        "rradio/client/interface",
        "rradio/client/lang",
        "rradio/client/data/langpacks",
        "rradio/client/data/stationpacks",
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

local function addClProperties()
    properties.Add("radio_mute", {
        MenuLabel = "Mute",
        Order     = 1501,
        MenuIcon  = "icon16/SOUND_MUTE.png",
        Filter    = function(self, ent, ply)
            return rRadio.utils.canUseRadio(ent) and not rRadio.cl.mutedBoomboxes[ent]
        end,
        Action    = function(self, ent)
            rRadio.cl.mutedBoomboxes[ent] = true
        end
    })

    properties.Add("radio_unmute", {
        MenuLabel = "Unmute",
        Order     = 1502,
        MenuIcon  = "icon16/SOUND.png",
        Filter    = function(self, ent, ply)
            return rRadio.utils.canUseRadio(ent) and rRadio.cl.mutedBoomboxes[ent]
        end,
        Action    = function(self, ent)
            rRadio.cl.mutedBoomboxes[ent] = nil
        end
    })
end

local function addPrivileges()
    local privs = {
        {
            Name = "rradio.UseAll",
            Description = "Allows a usergroup to use all boomboxes regardless of owner",
            MinAccess = "superadmin"
        },

        {
            Name = "rradio.AddCustomStation",
            Description = "Allows a usergroup to add custom stations to the client station list",
            MinAccess = "superadmin"
        }
    }

    for _, priv in ipairs(privs) do
        CAMI.RegisterPrivilege(priv)
    end
end

local function registerNetStrings()
    util.AddNetworkString("rRadio.PlayStation")
    util.AddNetworkString("rRadio.StopStation")
    util.AddNetworkString("rRadio.OpenMenu")
    util.AddNetworkString("rRadio.PlayVehicleAnimation")
    util.AddNetworkString("rRadio.UpdateRadioStatus")
    util.AddNetworkString("rRadio.SetRadioVolume")
    util.AddNetworkString("rRadio.SetPersistent")
    util.AddNetworkString("rRadio.RemovePersistent")
    util.AddNetworkString("rRadio.SendPersistentConfirmation")
    util.AddNetworkString("rRadio.SetConfigUpdate")
    util.AddNetworkString("rRadio.CustomStationsUpdate")
    util.AddNetworkString("rRadio.ListCustomStations")
end

if SERVER then
    local resourceStr = ""

    resourceStr = rRadio.DEV and "developer" or "public"
    resource.AddWorkshop(rRadio.DEV and dev_id or pub_id)

    rRadio.FormattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client-side files")
    rRadio.FormattedOutput("Using " .. resourceStr .. " resources")

    registerNetStrings()
    rRadio.FormattedOutput("Registered network strings")

    include("rradio/shared/sh_config.lua")
    include("rradio/shared/sh_utils.lua")
    include("rradio/server/sv_utils.lua")
    include("rradio/server/sv_core.lua")
    include("rradio/server/sv_permanent.lua")
    include("rradio/server/sv_blogs.lua")
    addPrivileges()
    
    rRadio.FormattedOutput("Finished server-side initialization")
elseif CLIENT then
    createFonts()
    addPrivileges()
    addClientFile("shared/sh_utils.lua")
    addClientFile("client/interface/cl_themes.lua")
    addClientFile("client/lang/cl_language_manager.lua")
    addClientFile("client/lang/cl_localisation_strings.lua")
    addClientFile("shared/sh_config.lua")

    rRadio.cl = rRadio.cl or {}
    rRadio.cl.mutedBoomboxes = rRadio.cl.mutedBoomboxes or {}

    if rRadio.config.UsePlayerBindHook == nil then
        rRadio.config.UsePlayerBindHook = not game.SinglePlayer()
    end

    rRadio.addClConVars()
    addClProperties()

    if (rRadio.isClientLoadDisabled()) then
        rRadio.FormattedOutput("Client-side load disabled")
        rRadio.FormattedOutput("Use rammel_rradio_enabled 1 to re-enable")
        return
    end

    rRadio.FormattedOutput("Starting client-side initialization")
    
    addClientFile("client/interface/cl_interface_utils.lua")
    addClientFile("client/interface/cl_core.lua")
    addClientFile("client/interface/cl_tool_menu.lua")

    addClientFile("client/data/langpacks/data_1.lua")
    addClientFile("client/data/langpacks/data_2.lua")
    addClientFile("client/data/langpacks/data_3.lua")

    for _, f in ipairs(file.Find("rradio/client/data/stationpacks/*.lua", "LUA")) do
        addClientFile("client/data/stationpacks/" .. f)
    end

    rRadio.FormattedOutput("Loaded " .. cl_count .. "/39 client-side files")
    rRadio.FormattedOutput("Finished client-side initialization")
end
