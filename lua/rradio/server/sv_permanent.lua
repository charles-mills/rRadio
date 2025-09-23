local Radio = rRadio
local DevPrint = Radio.DevPrint
Radio.sv = Radio.sv or {}
local Server = Radio.sv
Server.permanent = Server.permanent or {}

local Permanent = Server.permanent
local Database = Server.db or include("rradio/server/sv_db.lua")
local Status = Radio.status
local ServerUtils = Server.utils
local Config = Radio.config

local initialLoadComplete        = false
local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes           = {}
local currentMap                 = game.GetMap()

Server.BoomboxStatuses = Server.BoomboxStatuses or {}
Database.EnsurePermanentTable()

local function sanitize(str)
    return string.gsub(str, "'", "''")
end

local function GeneratePermanentID()
    return os.time() .. "_" .. math.random(1000, 9999)
end

local function ensurePermanentTable()
    if Database.TableExists("permanent_boomboxes") then
        return true
    end
    Database.EnsurePermanentTable()
    return Database.TableExists("permanent_boomboxes")
end

local function fetchStationData(ent, entIndex)
    local stationName = ""
    local stationURL  = ""
    local volume      = ent:GetNWFloat("Volume", 1.0)

    if Server.ActiveRadios and Server.ActiveRadios[entIndex] then
        stationName = sanitize(Server.ActiveRadios[entIndex].stationName or "")
        stationURL  = sanitize(Server.ActiveRadios[entIndex].url or "")
    end

    if (stationURL == "" or stationName == "") and Server.BoomboxStatuses and Server.BoomboxStatuses[entIndex] then
        if stationURL == "" then
            stationURL = sanitize(Server.BoomboxStatuses[entIndex].url or "")
        end
        if stationName == "" then
            stationName = sanitize(Server.BoomboxStatuses[entIndex].stationName or "")
        end
    end

    if stationURL == "" or stationName == "" then
        if stationName == "" then
            stationName = sanitize(ent:GetNWString("StationName", ""))
        end
        if stationURL == "" then
            stationURL = sanitize(ent:GetNWString("StationURL", ""))
        end
    end

    return stationName, stationURL, volume
end

local function upsertBoombox(permanentID, model, pos, ang, stationName, stationURL, volume)
    local query = string.format([[
        SELECT id FROM permanent_boomboxes
        WHERE map = %s AND permanent_id = %s
        LIMIT 1;
    ]], Database.Escape(currentMap), Database.Escape(permanentID))

    local result = Database.Query(query)
    if result == false then return end

    if result and #result > 0 then
        local id = result[1].id
        local updateQuery = string.format([[
            UPDATE permanent_boomboxes
            SET model        = %s,
                pos_x        = %f,
                pos_y        = %f,
                pos_z        = %f,
                angle_pitch  = %f,
                angle_yaw    = %f,
                angle_roll   = %f,
                station_name = %s,
                station_url  = %s,
                volume       = %f
            WHERE id = %d;
        ]],
            Database.Escape(model), pos.x, pos.y, pos.z,
            ang.p, ang.y, ang.r,
            Database.Escape(stationName), Database.Escape(stationURL),
            volume, tonumber(id)
        )
        Database.Query(updateQuery)
    else
        local insertQuery = string.format([[
            INSERT INTO permanent_boomboxes
                (map, permanent_id, model,
                 pos_x, pos_y, pos_z,
                 angle_pitch, angle_yaw, angle_roll,
                 station_name, station_url, volume)
            VALUES
                (%s, %s, %s,
                 %f, %f, %f,
                 %f, %f, %f,
                 %s, %s, %f);
        ]],
            Database.Escape(currentMap), Database.Escape(permanentID), Database.Escape(model),
            pos.x, pos.y, pos.z,
            ang.p, ang.y, ang.r,
            Database.Escape(stationName), Database.Escape(stationURL), volume
        )
        Database.Query(insertQuery)
    end
end

local function spawnPermanentBoombox(row)
    if spawnedBoomboxes[row.permanent_id] then return end

    local posKey = string.format("%.2f,%.2f,%.2f", row.pos_x, row.pos_y, row.pos_z)
    if spawnedBoomboxesByPosition[posKey] then return end

    local ent = ents.Create("rammel_boombox")
    if not IsValid(ent) then return end

    ent:SetModel(row.model)
    ent:SetPos(Vector(row.pos_x, row.pos_y, row.pos_z))
    ent:SetAngles(Angle(row.angle_pitch, row.angle_yaw, row.angle_roll))
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    ent:SetNWString("PermanentID", row.permanent_id)
    ent:SetNWString("StationName", row.station_name)
    ent:SetNWString("StationURL", row.station_url)
    ent:SetNWFloat("Volume", row.volume)

    ent.IsPermanent = true
    ent:SetNWBool("IsPermanent", true)

    if row.station_url ~= "" then
        local entIndex = ent:EntIndex()
        Server.BoomboxStatuses[entIndex] = Server.BoomboxStatuses[entIndex] or {}
        local status = Server.BoomboxStatuses[entIndex]

        status.url = row.station_url
        status.stationName = row.station_name
        status.stationStatus = Status.PLAYING

        ent:SetNWInt("Status", Status.PLAYING)
        ent:SetNWBool("IsPlaying", true)

        timer.Simple(0.1, function()
            net.Start("rRadio.PlayStation")
            net.WriteEntity(ent)
            net.WriteString(row.station_name or "")
            net.WriteString(row.station_url)
            net.WriteFloat(row.volume)
            net.Broadcast()
        end)

        ServerUtils.AddActiveRadio(ent, row.station_name or "", row.station_url, row.volume)
    end

    spawnedBoomboxes[row.permanent_id] = true
    spawnedBoomboxesByPosition[posKey] = true
end

function Permanent.SavePermanentBoombox(ent)
    if not IsValid(ent) then return end
    if not ensurePermanentTable() then return end

    local model    = sanitize(ent:GetModel())
    local pos      = ent:GetPos()
    local ang      = ent:GetAngles()
    local entIndex = ent:EntIndex()

    local stationName, stationURL, volume = fetchStationData(ent, entIndex)

    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString("PermanentID", permanentID)
    end

    upsertBoombox(permanentID, model, pos, ang, stationName, stationURL, volume)
    Database.Query(string.format("SELECT * FROM permanent_boomboxes WHERE permanent_id = %s", Database.Escape(permanentID)))
end

function Permanent.ClearSavedStation(ent)
    if not IsValid(ent) then return end

    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then return end

    if not ensurePermanentTable() then
        print("[rRadio] Permanent boombox table does not exist, cannot clear station.")
        return
    end

    local model  = sanitize(ent:GetModel())
    local pos    = ent:GetPos()
    local ang    = ent:GetAngles()
    local volume = ent:GetNWFloat("Volume", Config.DefaultVolume or 1.0)

    upsertBoombox(permanentID, model, pos, ang, "", "", volume)

    DevPrint("[rRadio] Cleared saved station for permanent boombox ID: " .. permanentID .. " on map " .. currentMap)
end

local function RemovePermanentBoombox(ent)
    if not IsValid(ent) then return end

    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then return end

    local deleteQuery = string.format([[
        DELETE FROM permanent_boomboxes
        WHERE map = %s AND permanent_id = %s;
    ]], Database.Escape(currentMap), Database.Escape(permanentID))

    Database.Query(deleteQuery)
end

function Permanent.LoadPermanentBoomboxes(isReload)
    table.Empty(spawnedBoomboxes)
    table.Empty(spawnedBoomboxesByPosition)

    for _, ent in ipairs(ents.FindByClass("rammel_boombox")) do
        if ent.IsPermanent then
            ent:Remove()
        end
    end

    if not Database.TableExists("permanent_boomboxes") then return end

    local loadQuery = string.format("SELECT * FROM permanent_boomboxes WHERE map = %s;", Database.Escape(currentMap))
    local result = Database.Query(loadQuery)
    if not result then return end

    for _, row in ipairs(result) do
        spawnPermanentBoombox(row)
    end
end

hook.Remove("InitPostEntity", "rRadio.LoadPermanentBoomboxes")
hook.Remove("PostCleanupMap", "rRadio.ReloadPermanentBoomboxes")

hook.Add("PostCleanupMap", "rRadio.LoadPermanentBoomboxes", function()
    timer.Simple(5, function()
        if not initialLoadComplete then
            Permanent.LoadPermanentBoomboxes()
            initialLoadComplete = true
        else
            Permanent.LoadPermanentBoomboxes()
        end
    end)
end)

net.Receive("rRadio.SetPersistent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRadio] You do not have permission to perform this action.")
        return false
    end

    if not Config.AllowCreatePermanentBoombox then
        ply:ChatPrint("[rRadio] Creating permanent boomboxes is disabled by the server.")
        return false
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "rammel_boombox" and ent:GetClass() ~= "rammel_boombox_gold") then
        ply:ChatPrint("[rRadio] Invalid boombox entity.")
        return false
    end

    if ent.IsPermanent then
        ply:ChatPrint("[rRadio] This boombox is already marked as permanent.")
        return false
    end

    ent.IsPermanent = true
    ent:SetNWBool("IsPermanent", true)
    Permanent.SavePermanentBoombox(ent)

    net.Start("rRadio.SendPersistentConfirmation")
    net.WriteString("Boombox has been marked as permanent.")
    net.Send(ply)
end)

net.Receive("rRadio.RemovePersistent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRadio] You do not have permission to perform this action.")
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "rammel_boombox" and ent:GetClass() ~= "rammel_boombox_gold") then
        ply:ChatPrint("[rRadio] Invalid boombox entity.")
        return
    end

    if not ent.IsPermanent then
        ply:ChatPrint("[rRadio] This boombox is not marked as permanent.")
        return
    end

    ent.IsPermanent = false
    ent:SetNWBool("IsPermanent", false)
    RemovePermanentBoombox(ent)

    if ent.StopRadio then
        ent:StopRadio()
    end

    net.Start("rRadio.SendPersistentConfirmation")
    net.WriteString("Boombox permanence has been removed.")
    net.Send(ply)
end)

concommand.Add("rradio_clear_permanent_db", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRadio] You must be a superadmin to use this command.")
        return
    end

    Database.Query("DELETE FROM permanent_boomboxes;")

    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Permanent boombox database has been cleared for all maps.")
    end
end)

concommand.Add("rradio_reload_permanent_boomboxes", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("[rRadio] You must be a superadmin to use this command.")
        return
    end

    for _, ent in ipairs(ents.FindByClass("rammel_boombox")) do
        if ent.IsPermanent then
            ent:Remove()
        end
    end

    Permanent.LoadPermanentBoomboxes(true)

    if IsValid(ply) then
        ply:ChatPrint("[rRadio] Permanent boomboxes have been reloaded.")
    end
end)

hook.Add("Initialize", "rRadio.UpdateCurrentMapForPermanentBoomboxes", function()
    currentMap = game.GetMap()
end)
