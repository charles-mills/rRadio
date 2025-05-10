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
    if rRadio.DEV then print("[RRADIO DEV] " .. text) end
end

function rRadio.FormattedOutput(text)
    MsgC(SERVER and Color(0, 200, 255) or Color(0, 255, 0), "[rRadio] ", Color(255, 255, 255), text .. "\n")
end

function rRadio.addClConVars()
    if not rRadio.config then 
        rRadio.FormattedOutput("rRadio.config not found, skipping client-side convars")
        return false
    end
    if SERVER then return end
    CreateClientConVar("rammel_rradio_vehicle_animation", rRadio.config.AnimationDefaultOn and "1" or "0", true, false, "Toggle vehicle entry animation")
    CreateClientConVar("rammel_rradio_boombox_hud", "1", true, false, "Show/hide boombox HUD")
    CreateClientConVar("rammel_rradio_menu_key", "21", true, false, "Key to open car radio menu")
    CreateClientConVar("rammel_rradio_menu_theme", "dark", true, false, "Radio theme")
    CreateClientConVar("rammel_rradio_enabled", "1", true, false, "Enable/disable rRadio")
    return true
end

function rRadio.isClientLoadDisabled()
    if SERVER or not rRadio.config then return false end
    local cv = GetConVar("rammel_rradio_enabled")
    return cv and rRadio.config.ClientHardDisable and not cv:GetBool()
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
    surface.CreateFont("rRadio.Roboto24", {font = "Roboto", size = 24, weight = 500, antialias = true, extended = true})
    surface.CreateFont("rRadio.Roboto5", {font = "Roboto", size = ScreenScale(5), weight = 500, antialias = true, extended = true})
    surface.CreateFont("rRadio.Roboto8", {font = "Roboto", size = ScreenScale(8), weight = 700, antialias = true})
end

local function addCSLuaFiles()
    local dirs = {
        "rradio/shared",
        "rradio/client",
        "rradio/client/interface",
        "rradio/client/lang",
        "rradio/client/lang/data",
        "rradio/client/stations",
        "entities/rammel_base_boombox",
        "entities/rammel_boombox",
        "entities/rammel_boombox_gold"
    }
    for _, dir in ipairs(dirs) do
        for _, f in ipairs(file.Find(dir .. "/*.lua", "LUA")) do addCSLua(dir .. "/" .. f) end
    end
end

local function addClProperties()
    properties.Add("radio_mute", {
        MenuLabel = "Mute",
        Order = 1000,
        MenuIcon = "icon16/sound_mute.png",
        Filter = function(self, ent, ply) return rRadio.utils.canUseRadio(ent) and not rRadio.cl.mutedBoomboxes[ent] end,
        Action = function(self, ent) rRadio.cl.mutedBoomboxes[ent] = true end
    })
    properties.Add("radio_unmute", {
        MenuLabel = "Unmute",
        Order = 1001,
        MenuIcon = "icon16/sound.png",
        Filter = function(self, ent, ply) return rRadio.utils.canUseRadio(ent) and rRadio.cl.mutedBoomboxes[ent] end,
        Action = function(self, ent) rRadio.cl.mutedBoomboxes[ent] = nil end
    })
end

local function addPrivileges()
    CAMI.RegisterPrivilege({
        Name = "rradio.UseAll",
        Description = "Allows a player to use all boomboxes",
        MinAccess = "superadmin"
    })
end

local function registerNetStrings()
    local netStrings = {
        "rRadio.PlayStation",
        "rRadio.StopStation",
        "rRadio.OpenMenu",
        "rRadio.PlayVehicleAnimation",
        "rRadio.UpdateRadioStatus",
        "rRadio.SetRadioVolume",
        "rRadio.SetPersistent",
        "rRadio.RemovePersistent",
        "rRadio.SendPersistentConfirmation",
        "rRadio.SetConfigUpdate"
    }
    for _, str in ipairs(netStrings) do util.AddNetworkString(str) end
end

if SERVER then
    resource.AddWorkshop(rRadio.DEV and dev_id or pub_id)
    rRadio.FormattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client-side files")
    registerNetStrings()
    include("rradio/shared/sh_config.lua")
    include("rradio/shared/sh_utils.lua")
    include("rradio/server/sv_utils.lua")
    include("rradio/server/sv_core.lua")
    include("rradio/server/sv_permanent.lua")
    addPrivileges()
    rRadio.FormattedOutput("Finished server-side initialization")
elseif CLIENT then
    createFonts()
    addClientFile("shared/sh_utils.lua")
    addClientFile("client/interface/cl_themes.lua")
    addClientFile("client/lang/cl_language_manager.lua")
    addClientFile("shared/sh_config.lua")
    rRadio.cl = rRadio.cl or {}
    rRadio.cl.mutedBoomboxes = rRadio.cl.mutedBoomboxes or {}
    rRadio.addClConVars()
    addClProperties()
    if rRadio.isClientLoadDisabled() then
        rRadio.FormattedOutput("Client-side load disabled\nUse rammel_rradio_enabled 1 to re-enable")
        return
    end
    rRadio.FormattedOutput("Starting client-side initialization")
    addClientFile("client/interface/cl_interface_utils.lua")
    addClientFile("client/interface/cl_core.lua")
    addClientFile("client/lang/cl_localisation_strings.lua")
    addClientFile("client/lang/data/data_1.lua")
    addClientFile("client/lang/data/data_2.lua")
    addClientFile("client/lang/data/data_3.lua")
    for _, f in ipairs(file.Find("rradio/client/stations/*.lua", "LUA")) do addClientFile("client/stations/" .. f) end
    rRadio.FormattedOutput("Loaded " .. cl_count .. "/38 client-side files")
    rRadio.FormattedOutput("Finished client-side initialization")
end
