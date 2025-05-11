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
    print("[RRADIO DEV] " .. text)
end

function rRadio.FormattedOutput(text)
    local prefixColor = SERVER and Color(0,200,255) or Color(0,255,0)
    MsgC(prefixColor, "[rRadio] ", Color(255,255,255), text .. "\n")
end

function rRadio.addClConVars()
    if not rRadio.config then 
        rRadio.FormattedOutput("Config not found, skipping client convars")
        return false
    end

    if SERVER then return end
    
    CreateClientConVar("rammel_rradio_vehicle_animation", rRadio.config.AnimationDefaultOn and "1" or "0", true, false, "Toggle vehicle entry animation")
    CreateClientConVar("rammel_rradio_boombox_hud", "1", true, false, "Toggle boombox HUD")
    CreateClientConVar("rammel_rradio_menu_key", "21", true, false, "Car radio menu key")
    CreateClientConVar("rammel_rradio_menu_theme", "dark", true, false, "Radio theme")
    CreateClientConVar("rammel_rradio_enabled", "1", true, false, "Enable rRadio")

    return true
end

function rRadio.isClientLoadDisabled()
    if SERVER or not rRadio.config then return false end
    local cv = GetConVar("rammel_rradio_enabled")
    return cv and rRadio.config.ClientHardDisable and not cv:GetBool()
end

local function addClientFile(filename)
    local success, err = pcall(include, "rradio/" .. filename)
    if not success then
        rRadio.FormattedOutput("Failed to load " .. filename .. ": " .. err)
        return
    end
    cl_count = cl_count + 1
end

local function addCSLua(filename)
    AddCSLuaFile(filename)
    cl_load_count = cl_load_count + 1
end

local function createFonts()
    local fonts = {
        ["rRadio.Roboto24"] = { font = "Roboto", size = 24, weight = 500, antialias = true, extended = true },
        ["rRadio.Roboto5"] = { font = "Roboto", size = ScreenScale(5), weight = 500, antialias = true, extended = true },
        ["rRadio.Roboto8"] = { font = "Roboto", size = ScreenScale(8), weight = 700, antialias = true, extended = true }
    }
    
    for name, settings in pairs(fonts) do
        surface.CreateFont(name, settings)
    end
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
        local files = file.Find(dir .. "/*.lua", "LUA")
        for _, f in ipairs(files) do
            addCSLua(dir .. "/" .. f)
        end
    end
end

local function addClProperties()
    local propertiesData = {
        radio_mute = {
            MenuLabel = "Mute",
            Order = 1501,
            MenuIcon = "icon16/SOUND_MUTE.png",
            Filter = function(self, ent, ply) return rRadio.utils.canUseRadio(ent) and not rRadio.cl.mutedBoomboxes[ent] end,
            Action = function(self, ent) rRadio.cl.mutedBoomboxes[ent] = true end
        },
        radio_unmute = {
            MenuLabel = "Unmute",
            Order = 1502,
            MenuIcon = "icon16/SOUND.png",
            Filter = function(self, ent, ply) return rRadio.utils.canUseRadio(ent) and rRadio.cl.mutedBoomboxes[ent] end,
            Action = function(self, ent) rRadio.cl.mutedBoomboxes[ent] = nil end
        }
    }

    for id, data in pairs(propertiesData) do
        properties.Add(id, data)
    end
end

local function addPrivileges()
    local privs = {
        { Name = "rradio.UseAll", Description = "Use all boomboxes regardless of owner", MinAccess = "superadmin" },
        { Name = "rradio.AddCustomStation", Description = "Add custom stations to client list", MinAccess = "superadmin" }
    }

    for _, priv in ipairs(privs) do
        CAMI.RegisterPrivilege(priv)
    end
end

local function registerNetStrings()
    local netStrings = {
        "PlayStation", "StopStation", "OpenMenu", "PlayVehicleAnimation",
        "UpdateRadioStatus", "SetRadioVolume", "SetPersistent", "RemovePersistent",
        "SendPersistentConfirmation", "SetConfigUpdate", "AddCustomStation", "CustomStationsUpdate"
    }
    
    for _, str in ipairs(netStrings) do
        util.AddNetworkString("rRadio." .. str)
    end
end

local function createRadioAddMenu()
    if SERVER then return end
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(400, 300)
    frame:Center()
    frame:SetTitle("Add Custom Radio Station")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()

    local nameEntry = vgui.Create("DTextEntry", frame)
    nameEntry:SetPos(20, 50)
    nameEntry:SetSize(360, 30)
    nameEntry:SetPlaceholderText("Station Name")

    local urlEntry = vgui.Create("DTextEntry", frame)
    urlEntry:SetPos(20, 100)
    urlEntry:SetSize(360, 30)
    urlEntry:SetPlaceholderText("Station URL")

    local addButton = vgui.Create("DButton", frame)
    addButton:SetPos(20, 150)
    addButton:SetSize(360, 40)
    addButton:SetText("Add Station")
    addButton.DoClick = function()
        local name = nameEntry:GetValue()
        local url = urlEntry:GetValue()
        
        if name ~= "" and url ~= "" then
            net.Start("rRadio.AddCustomStation")
            net.WriteString(name)
            net.WriteString(url)
            net.SendToServer()
            frame:Close()
        else
            Derma_Message("Please fill in both fields!", "Error", "OK")
        end
    end
end

if SERVER then
    local resourceStr = rRadio.DEV and "developer" or "public"
    resource.AddWorkshop(rRadio.DEV and dev_id or pub_id)

    rRadio.FormattedOutput("Starting server initialization")
    addCSLuaFiles()
    registerNetStrings()
    addPrivileges()

    local serverFiles = {
        "shared/sh_config.lua",
        "shared/sh_utils.lua",
        "server/sv_utils.lua",
        "server/sv_core.lua",
        "server/sv_permanent.lua"
    }

    for _, f in ipairs(serverFiles) do
        include("rradio/" .. f)
    end
    
    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client files")
    rRadio.FormattedOutput("Using " .. resourceStr .. " resources")
    rRadio.FormattedOutput("Server initialization complete")
elseif CLIENT then
    createFonts()
    addPrivileges()
    
    local clientFiles = {
        "shared/sh_utils.lua",
        "client/interface/cl_themes.lua",
        "client/lang/cl_language_manager.lua",
        "client/lang/cl_localisation_strings.lua",
        "shared/sh_config.lua"
    }

    for _, f in ipairs(clientFiles) do
        addClientFile(f)
    end

    rRadio.cl = rRadio.cl or {}
    rRadio.cl.mutedBoomboxes = rRadio.cl.mutedBoomboxes or {}

    rRadio.addClConVars()
    addClProperties()

    if rRadio.isClientLoadDisabled() then
        rRadio.FormattedOutput("Client load disabled")
        rRadio.FormattedOutput("Use rammel_rradio_enabled 1 to enable")
        return
    end

    rRadio.FormattedOutput("Starting client initialization")
    
    local clientCoreFiles = {
        "client/interface/cl_interface_utils.lua",
        "client/interface/cl_core.lua"
    }

    for _, f in ipairs(clientCoreFiles) do
        addClientFile(f)
    end

    -- Load language packs with error handling
    local langPacks = {"data_1.lua", "data_2.lua", "data_3.lua"}
    for _, lp in ipairs(langPacks) do
        addClientFile("client/data/langpacks/" .. lp)
    end

    -- Load station packs
    for _, f in ipairs(file.Find("rradio/client/data/stationpacks/*.lua", "LUA")) do
        addClientFile("client/data/stationpacks/" .. f)
    end

    rRadio.FormattedOutput("Loaded " .. cl_count .. " client files")
    rRadio.FormattedOutput("Client initialization complete")

    -- Add radioadd command
    concommand.Add("radioadd", createRadioAddMenu, nil, "Opens menu to add custom radio station")
end
