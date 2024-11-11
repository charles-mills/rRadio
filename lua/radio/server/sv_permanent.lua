--[[
    Radio Addon Server-Side Permanent Boombox Management
    Author: Charles Mills
    Description: Handles server-side permanent boombox functionality using SQLite storage
    Date: November 10, 2024
]]--

-- Constants
local BOOMBOX_CLASSES = {
    ["boombox"] = true,
    ["golden_boombox"] = true
}

local DATABASE_SCHEMA = [[
    CREATE TABLE permanent_boomboxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        map TEXT NOT NULL,
        permanent_id TEXT,
        model TEXT NOT NULL,
        pos_x REAL NOT NULL,
        pos_y REAL NOT NULL,
        pos_z REAL NOT NULL,
        angle_pitch REAL NOT NULL,
        angle_yaw REAL NOT NULL,
        angle_roll REAL NOT NULL,
        station_name TEXT,
        station_url TEXT,
        volume REAL NOT NULL,
        UNIQUE(map, permanent_id)
    );
]]

-- Local variables
local initialLoadComplete = false
local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes = {}
local currentMap = game.GetMap()

-- ConVars
CreateConVar("boombox_permanent", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Toggle boombox permanence")

-- Utility functions
local function sanitize(str)
    return string.gsub(str, "'", "''")
end

local function GeneratePermanentID()
    return os.time() .. "_" .. math.random(1000, 9999)
end

local function GetStationInfo(ent)
    local entIndex = ent:EntIndex()
    local stationName = ""
    local stationURL = ""
    local volume = ent:GetNWFloat("Volume", 1.0)

    -- Try ActiveRadios first
    if ActiveRadios and ActiveRadios[entIndex] then
        stationName = sanitize(ActiveRadios[entIndex].stationName or "")
        stationURL = sanitize(ActiveRadios[entIndex].url or "")
        if stationName ~= "" and stationURL ~= "" then
            return stationName, stationURL, volume
        end
    end

    -- Try networked variables
    stationName = sanitize(ent:GetNWString("StationName", ""))
    stationURL = sanitize(ent:GetNWString("StationURL", ""))
    if stationName ~= "" and stationURL ~= "" then
        return stationName, stationURL, volume
    end

    -- Try BoomboxStatuses as last resort
    if BoomboxStatuses and BoomboxStatuses[entIndex] then
        stationName = stationName ~= "" and stationName or sanitize(BoomboxStatuses[entIndex].stationName or "")
        stationURL = stationURL ~= "" and stationURL or sanitize(BoomboxStatuses[entIndex].url or "")
    end

    return stationName, stationURL, volume
end

-- Database functions
local function InitializeDatabase()
    if not sql.TableExists("permanent_boomboxes") then
        sql.Query(DATABASE_SCHEMA)
        return
    end

    -- Check for map column
    local columns = sql.Query("PRAGMA table_info(permanent_boomboxes);")
    local hasMapColumn = false
    
    for _, column in ipairs(columns or {}) do
        if column.name == "map" then
            hasMapColumn = true
            break
        end
    end

    if not hasMapColumn then
        sql.Query("ALTER TABLE permanent_boomboxes ADD COLUMN map TEXT NOT NULL DEFAULT '';")
    end
end

local function SavePermanentBoombox(ent)
    if not IsValid(ent) then return false end
    if not sql.TableExists("permanent_boomboxes") then InitializeDatabase() end

    local stationName, stationURL, volume = GetStationInfo(ent)
    local permanentID = ent:GetNWString("PermanentID", "")
    
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString("PermanentID", permanentID)
    end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local model = sanitize(ent:GetModel())

    -- Check if entry exists
    local exists = sql.QueryValue(string.format(
        "SELECT 1 FROM permanent_boomboxes WHERE map = %s AND permanent_id = %s",
        sql.SQLStr(currentMap), sql.SQLStr(permanentID)
    ))

    local query
    if exists then
        query = string.format([[
            UPDATE permanent_boomboxes
            SET model = %s, pos_x = %f, pos_y = %f, pos_z = %f,
                angle_pitch = %f, angle_yaw = %f, angle_roll = %f,
                station_name = %s, station_url = %s, volume = %f
            WHERE map = %s AND permanent_id = %s;
        ]], 
        sql.SQLStr(model), pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
        sql.SQLStr(stationName), sql.SQLStr(stationURL), volume,
        sql.SQLStr(currentMap), sql.SQLStr(permanentID))
    else
        query = string.format([[
            INSERT INTO permanent_boomboxes 
            (map, permanent_id, model, pos_x, pos_y, pos_z, angle_pitch, angle_yaw, angle_roll, station_name, station_url, volume)
            VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, %s, %s, %f);
        ]],
        sql.SQLStr(currentMap), sql.SQLStr(permanentID), sql.SQLStr(model),
        pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
        sql.SQLStr(stationName), sql.SQLStr(stationURL), volume)
    end

    return sql.Query(query) ~= false
end

local function RemovePermanentBoombox(ent)
    if not IsValid(ent) then return end
    
    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then return end

    local deleteQuery = string.format([[
        DELETE FROM permanent_boomboxes
        WHERE map = '%s' AND permanent_id = '%s';
    ]], currentMap, permanentID)

    local success = sql.Query(deleteQuery)
end

local function LoadPermanentBoomboxes(isReload)    
    table.Empty(spawnedBoomboxes)
    table.Empty(spawnedBoomboxesByPosition)

    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then
            ent:Remove()
        end
    end

    if not sql.TableExists("permanent_boomboxes") then return end

    local loadQuery = string.format("SELECT * FROM permanent_boomboxes WHERE map = '%s';", currentMap)
    local result = sql.Query(loadQuery)
    
    if not result then return end
    
    for _, row in ipairs(result) do
        if spawnedBoomboxes[row.permanent_id] then continue end

        local posKey = string.format("%.2f,%.2f,%.2f", row.pos_x, row.pos_y, row.pos_z)
        if spawnedBoomboxesByPosition[posKey] then continue end

        local ent = ents.Create("boombox")
        if not IsValid(ent) then continue end

        ent:SetModel(row.model)
        ent:SetPos(Vector(row.pos_x, row.pos_y, row.pos_z))
        ent:SetAngles(Angle(row.angle_pitch, row.angle_yaw, row.angle_roll))
        ent:Spawn()
        ent:Activate()

        ent:SetNWString("PermanentID", row.permanent_id)
        ent:SetNWString("StationName", row.station_name)
        ent:SetNWString("StationURL", row.station_url)
        ent:SetNWFloat("Volume", row.volume)

        ent.IsPermanent = true
        ent:SetNWBool("IsPermanent", true)

        if row.station_url ~= "" then
            ent:SetNWString("StationName", row.station_name)
            ent:SetNWString("StationURL", row.station_url)
            ent:SetNWString("Status", "playing")
            ent:SetNWBool("IsPlaying", true)
            
            local entIndex = ent:EntIndex()
            BoomboxStatuses[entIndex] = {
                stationStatus = "playing",
                stationName = row.station_name,
                url = row.station_url
            }
            
            net.Start("rRadio_UpdateRadioStatus")
                net.WriteEntity(ent)
                net.WriteString(row.station_name)
                net.WriteBool(true)
                net.WriteString("playing")
            net.Broadcast()
            
            net.Start("rRadio_QueueStream")
                net.WriteEntity(ent)
                net.WriteString(row.station_name)
                net.WriteString(row.station_url)
                net.WriteFloat(row.volume)
            net.Broadcast()

            if AddActiveRadio then
                AddActiveRadio(ent, row.station_name, row.station_url, row.volume)
            end
        end

        spawnedBoomboxes[row.permanent_id] = true
        spawnedBoomboxesByPosition[posKey] = true
    end
end

hook.Remove("InitPostEntity", "LoadPermanentBoomboxes")
hook.Remove("PostCleanupMap", "ReloadPermanentBoomboxes")

hook.Add("PostCleanupMap", "LoadPermanentBoomboxes", function()
    timer.Simple(5, function()
        if not initialLoadComplete then
            LoadPermanentBoomboxes()
            initialLoadComplete = true
        else
            LoadPermanentBoomboxes()
        end
    end)
end)

-- Network communication functions
local function BroadcastRadioStatus(ent, stationName, isPlaying, status)
    net.Start("rRadio_UpdateRadioStatus")
        net.WriteEntity(ent)
        net.WriteString(stationName)
        net.WriteBool(isPlaying)
        net.WriteString(status)
    net.Broadcast()
end

local function BroadcastStreamQueue(ent, stationName, stationURL, volume)
    net.Start("rRadio_QueueStream")
        net.WriteEntity(ent)
        net.WriteString(stationName)
        net.WriteString(stationURL)
        net.WriteFloat(volume)
    net.Broadcast()
end

local function NotifyPlayer(ply, message)
    net.Start("rRadio_BoomboxPermanentConfirmation")
        net.WriteString(message)
    net.Send(ply)
end

-- Entity management functions
local function SetupPermanentBoombox(ent, row)
    if not IsValid(ent) then return false end

    ent:SetModel(row.model)
    ent:SetPos(Vector(row.pos_x, row.pos_y, row.pos_z))
    ent:SetAngles(Angle(row.angle_pitch, row.angle_yaw, row.angle_roll))
    ent:Spawn()
    ent:Activate()

    -- Set networked variables
    ent:SetNWString("PermanentID", row.permanent_id)
    ent:SetNWString("StationName", row.station_name)
    ent:SetNWString("StationURL", row.station_url)
    ent:SetNWFloat("Volume", row.volume)
    ent:SetNWBool("IsPermanent", true)
    ent.IsPermanent = true

    if row.station_url ~= "" then
        InitializeBoomboxPlayback(ent, row)
    end

    return true
end

local function InitializeBoomboxPlayback(ent, data)
    ent:SetNWString("Status", "playing")
    ent:SetNWBool("IsPlaying", true)
    
    -- Update status tracking
    BoomboxStatuses[ent:EntIndex()] = {
        stationStatus = "playing",
        stationName = data.station_name,
        url = data.station_url
    }
    
    -- Broadcast status and queue stream
    BroadcastRadioStatus(ent, data.station_name, true, "playing")
    BroadcastStreamQueue(ent, data.station_name, data.station_url, data.volume)

    -- Add to active radios if available
    if AddActiveRadio then
        AddActiveRadio(ent, data.station_name, data.station_url, data.volume)
    end
end

-- Network receivers
local function HandleMakePermanent(ply, ent)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        NotifyPlayer(ply, "You do not have permission to perform this action.")
        return false
    end

    if not IsValid(ent) or not BOOMBOX_CLASSES[ent:GetClass()] then
        NotifyPlayer(ply, "Invalid boombox entity.")
        return false
    end

    if ent.IsPermanent then
        NotifyPlayer(ply, "This boombox is already marked as permanent.")
        return false
    end

    ent.IsPermanent = true
    ent:SetNWBool("IsPermanent", true)

    if SavePermanentBoombox(ent) then
        NotifyPlayer(ply, "Boombox has been marked as permanent.")
        return true
    end

    return false
end

local function HandleRemovePermanent(ply, ent)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        NotifyPlayer(ply, "You do not have permission to perform this action.")
        return false
    end

    if not IsValid(ent) or not BOOMBOX_CLASSES[ent:GetClass()] then
        NotifyPlayer(ply, "Invalid boombox entity.")
        return false
    end

    if not ent.IsPermanent then
        NotifyPlayer(ply, "This boombox is not marked as permanent.")
        return false
    end

    ent.IsPermanent = false
    ent:SetNWBool("IsPermanent", false)
    
    RemovePermanentBoombox(ent)

    if ent.StopRadio then
        ent:StopRadio()
    end

    NotifyPlayer(ply, "Boombox permanence has been removed.")
    return true
end

-- Network receivers registration
net.Receive("rRadio_MakeBoomboxPermanent", function(len, ply)
    HandleMakePermanent(ply, net.ReadEntity())
end)

net.Receive("rRadio_RemoveBoomboxPermanent", function(len, ply)
    HandleRemovePermanent(ply, net.ReadEntity())
end)

-- Console commands
local function ClearPermanentDatabase(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        NotifyPlayer(ply, "You must be a superadmin to use this command.")
        return
    end

    sql.Query("DELETE FROM permanent_boomboxes;")
    
    if IsValid(ply) then
        NotifyPlayer(ply, "Permanent boombox database has been cleared for all maps.")
    end
end

local function ReloadPermanentBoomboxes(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        NotifyPlayer(ply, "You must be a superadmin to use this command.")
        return
    end

    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then
            ent:Remove()
        end
    end

    LoadPermanentBoomboxes(true)
    
    if IsValid(ply) then
        NotifyPlayer(ply, "Permanent boomboxes have been reloaded.")
    end
end

-- Console commands registration
concommand.Add("rradio_clear_permanent_db", ClearPermanentDatabase)
concommand.Add("rradio_reload_permanent_boomboxes", ReloadPermanentBoomboxes)

-- Initialize hooks
hook.Add("Initialize", "UpdateCurrentMapForPermanentBoomboxes", function()
    currentMap = game.GetMap()
end)

hook.Add("PostCleanupMap", "LoadPermanentBoomboxes", function()
    timer.Simple(5, function()
        LoadPermanentBoomboxes(not initialLoadComplete)
        initialLoadComplete = true
    end)
end)

-- Global exports
_G.SavePermanentBoombox = SavePermanentBoombox
_G.RemovePermanentBoombox = RemovePermanentBoombox
_G.LoadPermanentBoomboxes = function() LoadPermanentBoomboxes(false) end
