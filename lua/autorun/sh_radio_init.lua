--[[

MIT License

Copyright (c) 2026 Rammel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


           /$$$$$$$                  /$$ /$$          
          | $$__  $$                | $$|__/          
  /$$$$$$ | $$  \ $$  /$$$$$$   /$$$$$$$ /$$  /$$$$$$ 
 /$$__  $$| $$$$$$$/ |____  $$ /$$__  $$| $$ /$$__  $$
| $$  \__/| $$__  $$  /$$$$$$$| $$  | $$| $$| $$  \ $$
| $$      | $$  \ $$ /$$__  $$| $$  | $$| $$| $$  | $$
| $$      | $$  | $$|  $$$$$$$|  $$$$$$$| $$|  $$$$$$/
|__/      |__/  |__/ \_______/ \_______/|__/ \______/ 

Steam: https://steamcommunity.com/id/rammel/

]]
local cl_count = 0
local DEV_WORKSHOP_ID = "3465709662"
local PUBLIC_WORKSHOP_ID = "3318060741"
local CLIENT_DISTRIBUTION_DIRS = {"rradio/shared", "rradio/client", "rradio/client/core", "rradio/client/interface", "rradio/client/interface/components", "rradio/client/lang", "rradio/client/data/langpacks", "rradio/client/data/stationpacks", "entities/rammel_base_boombox", "entities/rammel_boombox", "entities/rammel_boombox_gold"}
local SERVER_MODULES = {"rradio/shared/sh_config.lua", "rradio/shared/sh_utils.lua", "rradio/server/sv_utils.lua", "rradio/server/sv_core.lua", "rradio/server/sv_db.lua", "rradio/server/sv_permanent.lua", "rradio/server/sv_blogs.lua"}
local CLIENT_BOOTSTRAP_FILES = {"shared/sh_config.lua", "shared/sh_utils.lua", "client/interface/cl_themes.lua", "client/lang/cl_language_manager.lua"}
local CLIENT_COMPONENT_FILES = {"client/interface/components/star.lua", "client/interface/components/button.lua", "client/interface/components/nav_button.lua", "client/interface/components/animated_button.lua", "client/interface/components/checkbox.lua", "client/interface/components/dropdown.lua", "client/interface/components/header.lua", "client/interface/components/icon_button.lua", "client/interface/components/separator.lua"}
local CLIENT_PRE_COMPONENT_FILES = {"client/core/cl_utils.lua"}
local CLIENT_POST_COMPONENT_FILES = {"client/core/cl_state.lua", "client/core/cl_station_data.lua", "client/core/cl_networking.lua", "client/core/cl_playback.lua", "client/interface/cl_ui_components.lua", "client/interface/cl_ui_settings.lua", "client/interface/cl_ui_menu.lua", "client/core/cl_hooks.lua", "client/core/cl_commands.lua", "client/interface/cl_tool_menu.lua"}
local CLIENT_LANGPACK_FILES = {"client/data/langpacks/data_1.lua", "client/data/langpacks/data_2.lua", "client/data/langpacks/data_3.lua"}
rRadio = rRadio or {}
if rRadio.DEV == nil then rRadio.DEV = false end
if SERVER then CreateConVar("rammel_rradio_debug_logging", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable debug logging for rRadio on both server and clients.") end
include("rradio/shared/sh_logger.lua")
function rRadio.addClConVars()
    if not rRadio.config then
        rRadio.logger.WarnScope("init", "rRadio.config not found, skipping client-side convars")
        return false
    end

    if SERVER then return false end
    local menuScaleConfig = rRadio.config.MenuScale or {}
    local defaultMenuScale = tostring(menuScaleConfig.Default or 1.00)
    local defaultMenuWidthScale = tostring(menuScaleConfig.WidthDefault or 1.00)
    CreateClientConVar("rammel_rradio_vehicle_animation", rRadio.config.AnimationDefaultOn and "1" or "0", true, false, "Toggle the animation upon entering a vehicle.")
    CreateClientConVar("rammel_rradio_boombox_hud", "1", true, false, "Show or hide the HUD for the boombox.")
    CreateClientConVar("rammel_rradio_basic_hud", "0", true, false, "Use the simplified boombox HUD.")
    CreateClientConVar("rammel_rradio_menu_key", "21", true, false, "Select the key to open the car radio menu.")
    CreateClientConVar("rammel_rradio_menu_theme", "dark", true, false, "Set the theme for the radio.")
    CreateClientConVar("rammel_rradio_menu_scale", defaultMenuScale, true, false, "Scale factor for the rRadio menu size.")
    CreateClientConVar("rammel_rradio_menu_width_scale", defaultMenuWidthScale, true, false, "Horizontal scale factor for the rRadio menu width.")
    CreateClientConVar("rammel_rradio_enabled", "1", true, false, "Enable or disable rRadio.")
    CreateClientConVar("rammel_rradio_max_volume", "1.0", true, false, "Maximum global radio volume (0.0-1.0)")
    return true
end

function rRadio.isClientLoadDisabled()
    if not rRadio.config then return false end
    if SERVER then return false end
    local cv = GetConVar("rammel_rradio_enabled")
    if not cv then return false end
    return rRadio.config.ClientHardDisable and not cv:GetBool()
end

local function addClientFile(path)
    include("rradio/" .. path)
    cl_count = cl_count + 1
end

local function addClientFiles(paths)
    for _, path in ipairs(paths) do
        addClientFile(path)
    end
end

local function createFonts()
    local fonts = {
        {
            Name = "rRadio.Roboto24",
            Data = {
                font = "Roboto",
                size = 24,
                weight = 500,
                antialias = true,
                extended = true
            }
        },
        {
            Name = "rRadio.Roboto5",
            Data = {
                font = "Roboto",
                size = ScreenScale(5),
                weight = 500,
                antialias = true,
                extended = true
            }
        },
        {
            Name = "rRadio.Roboto8",
            Data = {
                font = "Roboto",
                size = ScreenScale(8),
                weight = 700
            }
        }
    }

    for _, fontDef in ipairs(fonts) do
        surface.CreateFont(fontDef.Name, fontDef.Data)
    end
end

local function addCSLuaFiles()
    local sentCount = 0
    for _, dir in ipairs(CLIENT_DISTRIBUTION_DIRS) do
        local files = file.Find(dir .. "/*.lua", "LUA")
        table.sort(files)
        for _, filename in ipairs(files) do
            AddCSLuaFile(dir .. "/" .. filename)
            sentCount = sentCount + 1
        end
    end
    return sentCount
end

local function addClProperties()
    properties.Add("radio_mute", {
        MenuLabel = "Mute",
        Order = 1501,
        MenuIcon = "icon16/SOUND_MUTE.png",
        Filter = function(self, ent, ply) return rRadio.utils.CanUseRadio(ent) and not rRadio.cl.mutedBoomboxes[ent] end,
        Action = function(self, ent)
            rRadio.cl.mutedBoomboxes[ent] = true
            rRadio.interface.refreshVolume(ent)
        end
    })

    properties.Add("radio_unmute", {
        MenuLabel = "Unmute",
        Order = 1502,
        MenuIcon = "icon16/SOUND.png",
        Filter = function(self, ent, ply) return rRadio.utils.CanUseRadio(ent) and rRadio.cl.mutedBoomboxes[ent] end,
        Action = function(self, ent)
            rRadio.cl.mutedBoomboxes[ent] = nil
            rRadio.interface.refreshVolume(ent)
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
    local netStrings = {"rRadio.PlayStation", "rRadio.StopStation", "rRadio.OpenMenu", "rRadio.PlayVehicleAnimation", "rRadio.UpdateRadioStatus", "rRadio.SetRadioVolume", "rRadio.SetPersistent", "rRadio.RemovePersistent", "rRadio.SendPersistentConfirmation", "rRadio.SetConfigUpdate", "rRadio.CustomStationsUpdate", "rRadio.ListCustomStations"}
    for _, netString in ipairs(netStrings) do
        util.AddNetworkString(netString)
    end
end

local function initServer()
    local workshopId = rRadio.DEV and DEV_WORKSHOP_ID or PUBLIC_WORKSHOP_ID
    local resourceType = rRadio.DEV and "developer" or "public"
    resource.AddWorkshop(workshopId)
    rRadio.logger.InfoScope("init", "Starting server-side initialization")
    local sentCount = addCSLuaFiles()
    rRadio.logger.InfoScope("init", "Assigned", sentCount, "client-side files")
    rRadio.logger.InfoScope("init", "Using", resourceType, "resources")
    registerNetStrings()
    rRadio.logger.InfoScope("init", "Registered network strings")
    for _, modulePath in ipairs(SERVER_MODULES) do
        include(modulePath)
    end

    addPrivileges()
    rRadio.logger.InfoScope("init", "Finished server-side initialization")
end

local function initClient()
    createFonts()
    addPrivileges()
    addClientFiles(CLIENT_BOOTSTRAP_FILES)
    rRadio.cl = rRadio.cl or {}
    rRadio.cl.radioSources = rRadio.cl.radioSources or {}
    rRadio.cl.mutedBoomboxes = rRadio.cl.mutedBoomboxes or {}
    if rRadio.config.UsePlayerBindHook == nil then rRadio.config.UsePlayerBindHook = not game.SinglePlayer() end
    rRadio.addClConVars()
    cvars.AddChangeCallback("rammel_rradio_max_volume", function(cvar, old, new)
        for ent in pairs(rRadio.cl.radioSources) do
            rRadio.interface.refreshVolume(ent)
        end
    end, "rRadioMaxVolCB")

    addClProperties()
    if rRadio.isClientLoadDisabled() then
        rRadio.logger.InfoScope("init", "Client-side load disabled")
        rRadio.logger.InfoScope("init", "Use rammel_rradio_enabled 1 to re-enable")
        return
    end

    rRadio.logger.InfoScope("init", "Starting client-side initialization")
    addClientFiles(CLIENT_PRE_COMPONENT_FILES)
    addClientFiles(CLIENT_COMPONENT_FILES)
    addClientFiles(CLIENT_POST_COMPONENT_FILES)
    addClientFiles(CLIENT_LANGPACK_FILES)
    local stationPackFiles = file.Find("rradio/client/data/stationpacks/*.lua", "LUA")
    table.sort(stationPackFiles)
    for _, stationPack in ipairs(stationPackFiles) do
        addClientFile("client/data/stationpacks/" .. stationPack)
    end

    rRadio.logger.InfoScope("init", "Loaded", cl_count, "client-side files")
    rRadio.logger.InfoScope("init", "Finished client-side initialization")
end

if SERVER then
    initServer()
elseif CLIENT then
    initClient()
end
