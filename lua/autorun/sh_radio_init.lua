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
rRadio.sv = rRadio.sv or {}
rRadio.cl = rRadio.cl or {}
rRadio.sv.CustomStations = rRadio.sv.CustomStations or { data = {}, urlMap = {}, nameMap = {} }
rRadio.cl.BoomboxStatuses = rRadio.cl.BoomboxStatuses or {}
rRadio.Lang = rRadio.Lang or {}

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
        "SendPersistentConfirmation", "SetConfigUpdate", "AddCustomStation", 
        "CustomStationsUpdate", "OpenRadioAddMenu"
    }
    
    for _, str in ipairs(netStrings) do
        util.AddNetworkString("rRadio." .. str)
    end
end

-- Basic configuration
rRadio.config = rRadio.config or {
    AnimationDefaultOn = true,
    ClientHardDisable = false,
    CommandAddStation = "!radioadd",
    CommandRemoveStation = "!radioremove",
    VolumeUpdateDebounce = function() return 0.5 end,
    CleanupInterval = function() return 300 end,
    DriverPlayOnly = true
}

-- Utility functions
rRadio.utils = rRadio.utils or {}
function rRadio.utils.canUseRadio(ent)
    return IsValid(ent) and (ent:IsVehicle() or ent:GetClass():find("rammel_boombox"))
end

function rRadio.utils.GetVehicle(ent)
    return ent:IsVehicle() and ent or nil
end

function rRadio.utils.isSitAnywhereSeat(ent)
    return ent:GetClass() == "prop_vehicle_prisoner_pod"
end

function rRadio.utils.IsBoombox(ent)
    return ent:GetClass():find("rammel_boombox")
end

function rRadio.utils.canInteractWithBoombox(ply, ent)
    return CAMI.PlayerHasAccess(ply, "rradio.UseAll", nil) or ent:GetNWEntity("rRadio.Owner") == ply
end

function rRadio.utils.setRadioStatus(ent, status, station)
    ent:SetNWString("rRadio.Status", status)
    ent:SetNWString("rRadio.Station", station or "")
end

-- Language initialization
if CLIENT then
    rRadio.Lang = rRadio.Lang or {}
    rRadio.Lang.Data = rRadio.Lang.Data or {
        en = {
            play = "Play",
            stop = "Stop",
            mute = "Mute",
            unmute = "Unmute",
            station_added = "Station added: %s",
            invalid_url = "Invalid URL format",
            no_permission = "No permission",
            add_station = "Add Station",
            cancel = "Cancel",
            station_name = "Station Name",
            station_url = "Station URL"
        }
    }
    
    function rRadio.Lang.Get(key)
        local lang = rRadio.Lang.Data.en or {}
        return lang[key] or key
    end
end

-- Server-side custom station handling
if SERVER then
    function rRadio.sv.CustomStations:Load()
        local success, contents = pcall(file.Read, "rradio/customstations.json", "DATA")
        if not success or not contents then
            rRadio.FormattedOutput("Failed to load custom stations")
            return
        end
        local tbl = util.JSONToTable(contents) or {}
        self.data = {}
        self.urlMap = {}
        self.nameMap = {}
        for _, v in ipairs(tbl) do
            if type(v) == "table" and v.url and v.name then
                table.insert(self.data, v)
                self.urlMap[v.url] = true
                self.nameMap[v.name] = true
            end
        end
    end

    function rRadio.sv.CustomStations:Save()
        file.CreateDir("rradio")
        local success, err = pcall(file.Write, "rradio/customstations.json", util.TableToJSON(self.data))
        if not success then
            rRadio.FormattedOutput("Failed to save custom stations: " .. err)
        end
    end

    function rRadio.sv.CustomStations:Add(name, url, ply)
        if self.urlMap[url] or self.nameMap[name] then
            if IsValid(ply) then ply:ChatPrint("[rRadio] Station name or URL already exists") end
            return false
        end
        if not url:match("^https?://.+%.%a+$") then
            if IsValid(ply) then ply:ChatPrint("[rRadio] " .. rRadio.Lang.Get("invalid_url")) end
            return false
        end
        if #name > 50 or #url > 200 then
            if IsValid(ply) then ply:ChatPrint("[rRadio] Name or URL too long") end
            return false
        end
        table.insert(self.data, { name = name, url = url })
        self.urlMap[url] = true
        self.nameMap[name] = true
        self:Save()
        return true
    end

    function rRadio.sv.CustomStations:GetAll()
        return self.data
    end

    rRadio.sv.CustomStations:Load()
end

-- Radio add menu
local function createRadioAddMenu()
    if SERVER then return end
    
    if not vgui or not draw then
        rRadio.FormattedOutput("VGUI or draw library not available")
        return
    end

    local frame = vgui.Create("DFrame")
    if not frame then
        rRadio.FormattedOutput("Failed to create DFrame")
        return
    end

    frame:SetSize(500, 400)
    frame:Center()
    frame:SetTitle("Add Custom Radio Station")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    local panel = vgui.Create("DPanel", frame)
    panel:SetPos(10, 30)
    panel:SetSize(480, 360)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 240))
    end

    local nameLabel = vgui.Create("DLabel", panel)
    nameLabel:SetPos(20, 20)
    nameLabel:SetText(rRadio.Lang.Get("station_name") .. ":")
    nameLabel:SetFont("rRadio.Roboto24")
    nameLabel:SetTextColor(Color(255, 255, 255))

    local nameEntry = vgui.Create("DTextEntry", panel)
    nameEntry:SetPos(20, 50)
    nameEntry:SetSize(440, 30)
    nameEntry:SetPlaceholderText("Enter station name (max 50 chars)")
    nameEntry:SetFont("rRadio.Roboto24")

    local urlLabel = vgui.Create("DLabel", panel)
    urlLabel:SetPos(20, 100)
    urlLabel:SetText(rRadio.Lang.Get("station_url") .. ":")
    urlLabel:SetFont("rRadio.Roboto24")
    urlLabel:SetTextColor(Color(255, 255, 255))

    local urlEntry = vgui.Create("DTextEntry", panel)
    urlEntry:SetPos(20, 130)
    urlEntry:SetSize(440, 30)
    urlEntry:SetPlaceholderText("Enter station URL (https://...)")
    urlEntry:SetFont("rRadio.Roboto24")

    local addButton = vgui.Create("DButton", panel)
    addButton:SetPos(20, 230)
    addButton:SetSize(440, 40)
    addButton:SetText(rRadio.Lang.Get("add_station"))
    addButton:SetFont("rRadio.Roboto24")
    addButton.DoClick = function()
        local name = nameEntry:GetValue():Trim()
        local url = urlEntry:GetValue():Trim()
        
        if name == "" or url == "" then
            Derma_Message("Please fill in both fields", "Error", "OK")
            return
        end
        
        if #name > 50 or #url > 200 then
            Derma_Message("Name or URL too long", "Error", "OK")
            return
        end
        
        if not url:match("^https?://.+%.%a+$") then
            Derma_Message(rRadio.Lang.Get("invalid_url"), "Error", "OK")
            return
        end

        net.Start("rRadio.AddCustomStation")
        net.WriteString(name)
        net.WriteString(url)
        net.SendToServer()
        frame:Close()
    end

    local cancelButton = vgui.Create("DButton", panel)
    cancelButton:SetPos(20, 280)
    cancelButton:SetSize(440, 40)
    cancelButton:SetText(rRadio.Lang.Get("cancel"))
    cancelButton:SetFont("rRadio.Roboto24")
    cancelButton.DoClick = function() frame:Close() end
end

if SERVER then
    local resourceStr = rRadio.DEV and "developer" or "public"
    resource.AddWorkshop(rRadio.DEV and dev_id or pub_id)

    rRadio.FormattedOutput("Starting server initialization")
    addCSLuaFiles()
    registerNetStrings()
    addPrivileges()

    rRadio.sv.utils = rRadio.sv.utils or {}
    function rRadio.sv.utils.BroadcastPlay(ent, station, url, volume)
        net.Start("rRadio.PlayStation")
        net.WriteEntity(ent)
        net.WriteString(station)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()
    end

    function rRadio.sv.utils.BroadcastStop(ent)
        net.Start("rRadio.StopStation")
        net.WriteEntity(ent)
        net.Broadcast()
    end

    net.Receive("rRadio.AddCustomStation", function(len, ply)
        if not IsValid(ply) then return end
        if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
            ply:ChatPrint("[rRadio] " .. rRadio.Lang.Get("no_permission"))
            return
        end

        local name = net.ReadString()
        local url = net.ReadString()
        
        if rRadio.sv.CustomStations:Add(name, url, ply) then
            ply:ChatPrint(string.format("[rRadio] " .. rRadio.Lang.Get("station_added"), name))
            net.Start("rRadio.CustomStationsUpdate")
            net.WriteTable(rRadio.sv.CustomStations:GetAll())
            net.Broadcast()
        end
    end)

    net.Receive("rRadio.OpenRadioAddMenu", function(len, ply)
        if not IsValid(ply) then return end
        if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
            ply:ChatPrint("[rRadio] " .. rRadio.Lang.Get("no_permission"))
            return
        end
        net.Start("rRadio.OpenRadioAddMenu")
        net.Send(ply)
    end)

    hook.Add("PlayerSay", "rRadio.HandleAddStation", function(ply, text)
        if not text:lower():StartWith(rRadio.config.CommandAddStation) then return end
        
        local name, url = text:match('!radioadd%s+"([^"]+)"%s+"([^"]+)"')
        if not name then
            net.Start("rRadio.OpenRadioAddMenu")
            net.Send(ply)
            return ""
        end

        if not CAMI.PlayerHasAccess(ply, "rradio.AddCustomStation", nil) then
            ply:ChatPrint("[rRadio] " .. rRadio.Lang.Get("no_permission"))
            return ""
        end

        if rRadio.sv.CustomStations:Add(name, url, ply) then
            ply:ChatPrint(string.format("[rRadio] " .. rRadio.Lang.Get("station_added"), name))
            net.Start("rRadio.CustomStationsUpdate")
            net.WriteTable(rRadio.sv.CustomStations:GetAll())
            net.Broadcast()
        end
        return ""
    end)

    hook.Add("PlayerInitialSpawn", "rRadio.SendCustomStations", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                net.Start("rRadio.CustomStationsUpdate")
                net.WriteTable(rRadio.sv.CustomStations:GetAll())
                net.Send(ply)
            end
        end)
    end)

    rRadio.FormattedOutput("Assigned " .. cl_load_count .. " client files")
    rRadio.FormattedOutput("Using " .. resourceStr .. " resources")
    rRadio.FormattedOutput("Server initialization complete")
elseif CLIENT then
    createFonts()
    addPrivileges()
    
    local clientFiles = {
        "shared/sh_utils.lua",
        "client/lang/cl_language_manager.lua",
        "client/lang/cl_localisation_strings.lua",
        "client/interface/cl_themes.lua",
        "shared/sh_config.lua"
    }

    for _, f in ipairs(clientFiles) do
        local success, err = pcall(addClientFile, f)
        if not success then
            rRadio.FormattedOutput("Failed to load client file " .. f .. ": " .. err)
        end
    end

    rRadio.cl = rRadio.cl or {}
    rRadio.cl.mutedBoomboxes = rRadio.cl.mutedBoomboxes or {}
    rRadio.cl.BoomboxStatuses = rRadio.cl.BoomboxStatuses or {}

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
        local success, err = pcall(addClientFile, f)
        if not success then
            rRadio.FormattedOutput("Failed to load core file " .. f .. ": " .. err)
        end
    end

    -- Skip language packs if they don't exist
    local langPacks = {"data_1.lua", "data_2.lua", "data_3.lua"}
    for _, lp in ipairs(langPacks) do
        if file.Exists("rradio/client/data/langpacks/" .. lp, "LUA") then
            local success, err = pcall(addClientFile, "client/data/langpacks/" .. lp)
            if not success then
                rRadio.FormattedOutput("Failed to load language pack " .. lp .. ": " .. err)
            end
        else
            rRadio.FormattedOutput("Language pack " .. lp .. " not found, using default language")
        end
    end

    for _, f in ipairs(file.Find("rradio/client/data/stationpacks/*.lua", "LUA")) do
        local success, err = pcall(addClientFile, "client/data/stationpacks/" .. f)
        if not success then
            rRadio.FormattedOutput("Failed to load station pack " .. f .. ": " .. err)
        end
    end

    net.Receive("rRadio.CustomStationsUpdate", function()
        rRadio.cl.customStations = net.ReadTable() or {}
    end)

    net.Receive("rRadio.OpenRadioAddMenu", function()
        createRadioAddMenu()
    end)

    rRadio.FormattedOutput("Loaded " .. cl_count .. " client files")
    rRadio.FormattedOutput("Client initialization complete")

    concommand.Add("radioadd", function()
        net.Start("rRadio.OpenRadioAddMenu")
        net.SendToServer()
    end, nil, "Opens menu to add custom radio station")
end
