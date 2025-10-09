--[[

MIT License

Copyright (c) 2025 Charles Mills

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

Discord: crjmx
Steam: https://steamcommunity.com/id/rammel/

]]

local cl_count = 0
local cl_load_count = 0
local cl_files_expected = 0

local dev_id = "3465709662"
local pub_id = "3318060741"

rRadio = rRadio or {}
local Radio = rRadio
Radio.DEV = false

include("rradio/shared/sh_core.lua")

local Core = Radio.core
local unpack = unpack or table.unpack

function Radio:Import(...)
    local count = select("#", ...)
    local results = {}

    for index = 1, count do
        local key = select(index, ...)
        if type(key) == "string" then
            local ensure = key:sub(1, 1) == "!"
            if ensure then
                key = key:sub(2)
            end

            if key == "Radio" or key == "rRadio" then
                results[index] = self
            else
                if ensure then
                    self[key] = self[key] or {}
                end

                results[index] = self[key]
            end
        else
            results[index] = nil
        end
    end

    return unpack(results, 1, count)
end

function Radio.DevPrint(text)
    if not Radio.DEV then return end

    print("[RRADIO DEV] " .. text .. "\n")
end

local DevPrint = Radio.DevPrint

function Radio.FormattedOutput(text)
    if SERVER then
        MsgC(Color(0,200,255), "[rRadio] ", Color(255,255,255), text .. "\n")
    elseif CLIENT then
        MsgC(Color(0,255,0), "[rRadio] ", Color(255,255,255), text .. "\n")
    end
end

function Radio.addClConVars()
    if not Radio.config then 
        Radio.FormattedOutput("[RRADIO] rRadio.config not found, skipping client-side convars")
        return false
    end

    if SERVER then return end
    
    CreateClientConVar("rammel_rradio_vehicle_animation", Radio.config.AnimationDefaultOn and "1" or "0", true, false, "Toggle the animation upon entering a vehicle.")
    CreateClientConVar("rammel_rradio_boombox_hud", "1", true, false, "Show or hide the HUD for the boombox.")
    CreateClientConVar("rammel_rradio_basic_hud", "0", true, false, "Use the simplified boombox HUD.")
    CreateClientConVar("rammel_rradio_menu_key", "21", true, false, "Select the key to open the car radio menu.")
    CreateClientConVar("rammel_rradio_menu_theme", "dark", true, false, "Set the theme for the radio.")
    CreateClientConVar("rammel_rradio_enabled", "1", true, false, "Enable or disable rRadio.")
    CreateClientConVar("rammel_rradio_max_volume", "1.0", true, false, "Maximum global radio volume (0.0-1.0)")

    return true
end

function Radio.isClientLoadDisabled()
    if not Radio.config then return false end

    if SERVER then return false end

    local cv = GetConVar("rammel_rradio_enabled")

    if not cv then
        return false
    end

    return Radio.config.ClientHardDisable and not cv:GetBool()
end

local function addClientFile(filename)
    include("rradio/" .. filename)
    cl_count = cl_count + 1
end

local function addCSLua(filename)
    if SERVER then
        AddCSLuaFile(filename)
        cl_load_count = cl_load_count + 1
    end

    cl_files_expected = cl_files_expected + 1
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
        "rradio/client/core",
        "rradio/client/interface",
        "rradio/client/interface/components",
        "rradio/client/lang",
        "rradio/client/data/langpacks",
        "rradio/client/data/stationpacks",
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
            return Radio.utils.CanUseRadio(ent) and not Radio.cl.mutedBoomboxes[ent]
        end,
        Action    = function(self, ent)
            Radio.cl.mutedBoomboxes[ent] = true
            Radio.interface.refreshVolume(ent)
        end
    })

    properties.Add("radio_unmute", {
        MenuLabel = "Unmute",
        Order     = 1502,
        MenuIcon  = "icon16/SOUND.png",
        Filter    = function(self, ent, ply)
            return Radio.utils.CanUseRadio(ent) and Radio.cl.mutedBoomboxes[ent]
        end,
        Action    = function(self, ent)
            Radio.cl.mutedBoomboxes[ent] = nil
            Radio.interface.refreshVolume(ent)
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
    Core.registerNetworkStrings()
end

if SERVER then
    local resourceStr = ""

    resourceStr = Radio.DEV and "developer" or "public"
    resource.AddWorkshop(Radio.DEV and dev_id or pub_id)

    Radio.FormattedOutput("Starting server-side initialization")
    addCSLuaFiles()
    Radio.FormattedOutput("Assigned " .. cl_load_count .. " client-side files")
    Radio.FormattedOutput("Using " .. resourceStr .. " resources")

    registerNetStrings()
    Radio.FormattedOutput("Registered network strings")

    include("rradio/shared/sh_config.lua")
    include("rradio/shared/sh_utils.lua")
    include("rradio/server/sv_utils.lua")
    include("rradio/server/sv_core.lua")
    include("rradio/server/sv_db.lua")
    include("rradio/server/sv_permanent.lua")
    include("rradio/server/sv_blogs.lua")
    addPrivileges()
    
    Radio.FormattedOutput("Finished server-side initialization")
elseif CLIENT then
    addCSLuaFiles()
    createFonts()
    addPrivileges()
    addClientFile("shared/sh_core.lua")
    addClientFile("shared/sh_config.lua")
    addClientFile("shared/sh_utils.lua")
    addClientFile("client/interface/cl_themes.lua")
    addClientFile("client/lang/cl_language_manager.lua")
    addClientFile("client/lang/cl_localisation_strings.lua")

    Radio.cl = Radio.cl or {}
    Radio.cl.radioSources = Radio.cl.radioSources or {}
    Radio.cl.mutedBoomboxes = Radio.cl.mutedBoomboxes or {}

    if Radio.config.UsePlayerBindHook == nil then
        Radio.config.UsePlayerBindHook = not game.SinglePlayer()
    end

    Radio.addClConVars()

    cvars.AddChangeCallback("rammel_rradio_max_volume", function(cvar, old, new)
        for ent in pairs(Radio.cl.radioSources) do
            Radio.interface.refreshVolume(ent)
        end
    end, "rRadioMaxVolCB")

    addClProperties()

    if (Radio.isClientLoadDisabled()) then
        Radio.FormattedOutput("Client-side load disabled")
        Radio.FormattedOutput("Use rammel_rradio_enabled 1 to re-enable")
        return
    end

    Radio.FormattedOutput("Starting client-side initialization")
    
    addClientFile("client/core/cl_utils.lua")

    addClientFile("client/interface/components/star.lua")
    addClientFile("client/interface/components/button.lua")
    addClientFile("client/interface/components/nav_button.lua")
    addClientFile("client/interface/components/animated_button.lua")
    addClientFile("client/interface/components/checkbox.lua")
    addClientFile("client/interface/components/dropdown.lua")
    addClientFile("client/interface/components/header.lua")
    addClientFile("client/interface/components/icon_button.lua")
    addClientFile("client/interface/components/separator.lua")
    
    addClientFile("client/core/cl_state.lua")
    addClientFile("client/core/cl_station_data.lua")
    addClientFile("client/core/cl_networking.lua")
    addClientFile("client/core/cl_playback.lua")
    addClientFile("client/interface/cl_ui_components.lua")
    addClientFile("client/interface/cl_ui_settings.lua")
    addClientFile("client/interface/cl_ui_menu.lua")
    addClientFile("client/core/cl_hooks.lua")
    addClientFile("client/core/cl_commands.lua")

    addClientFile("client/interface/cl_tool_menu.lua")

    addClientFile("client/data/langpacks/data_1.lua")
    addClientFile("client/data/langpacks/data_2.lua")
    addClientFile("client/data/langpacks/data_3.lua")

    for _, f in ipairs(file.Find("rradio/client/data/stationpacks/*.lua", "LUA")) do
        addClientFile("client/data/stationpacks/" .. f)
    end

    Radio.FormattedOutput("Loaded " .. cl_count .. "/55 client-side files")
    Radio.FormattedOutput("Finished client-side initialization")
end
