util.AddNetworkString("MakeBoomboxPermanent")
util.AddNetworkString("RemoveBoomboxPermanent")
util.AddNetworkString("BoomboxPermanentConfirmation")
CreateConVar("boombox_permanent", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Toggle boombox permanence")
local initialLoadComplete = false
local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes = {}
local currentMap = game.GetMap()
local StationQueue, RadioManager
local function WaitForDependencies()
    if _G.StationQueue and _G.RadioManager then
        StationQueue = _G.StationQueue
        RadioManager = _G.RadioManager
        return
    end

    timer.Simple(0.5, WaitForDependencies)
end

WaitForDependencies()
local function InitializeDatabase()
    if not sql.TableExists("permanent_boomboxes") then
        local query = [[
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
        sql.Query(query)
    else
        local columnCheckQuery = "PRAGMA table_info(permanent_boomboxes);"
        local columns = sql.Query(columnCheckQuery)
        local mapColumnExists = false
        for _, column in ipairs(columns) do
            if column.name == "map" then
                mapColumnExists = true
                break
            end
        end

        if not mapColumnExists then sql.Query("ALTER TABLE permanent_boomboxes ADD COLUMN map TEXT NOT NULL DEFAULT '';") end
    end
end

InitializeDatabase()
local function sanitize(str)
    return string.gsub(str, "'", "''")
end

local function GeneratePermanentID()
    return os.time() .. "_" .. math.random(1000, 9999)
end

local function SavePermanentBoombox(ent)
    if not IsValid(ent) then return end
    if not sql.TableExists("permanent_boomboxes") then
        InitializeDatabase()
        if not sql.TableExists("permanent_boomboxes") then return end
    end

    local entIndex = ent:EntIndex()
    local radioData = RadioManager and RadioManager.active[entIndex]
    local model = sanitize(ent:GetModel())
    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local stationName = ""
    local stationURL = ""
    local volume = 1.0
    if radioData then
        stationName = sanitize(radioData.stationName or "")
        stationURL = sanitize(radioData.url or "")
        volume = radioData.volume or 1.0
    else
        stationName = sanitize(ent:GetNWString("StationName", ""))
        stationURL = sanitize(ent:GetNWString("StationURL", ""))
        volume = ent:GetNWFloat("Volume", 1.0)
    end

    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString("PermanentID", permanentID)
    end

    local query = string.format([[
        SELECT id FROM permanent_boomboxes
        WHERE map = %s AND permanent_id = %s
        LIMIT 1;
    ]], sql.SQLStr(currentMap), sql.SQLStr(permanentID))
    local result = sql.Query(query)
    if result == false then return end
    local sqlQuery
    if result and #result > 0 then
        local id = result[1].id
        sqlQuery = string.format([[
            UPDATE permanent_boomboxes
            SET model = %s, pos_x = %f, pos_y = %f, pos_z = %f,
                angle_pitch = %f, angle_yaw = %f, angle_roll = %f,
                station_name = CASE WHEN %s = '' THEN NULL ELSE %s END,
                station_url = CASE WHEN %s = '' THEN NULL ELSE %s END,
                volume = %f
            WHERE id = %d;
        ]], sql.SQLStr(model), pos.x, pos.y, pos.z, ang.p, ang.y, ang.r, sql.SQLStr(stationName), sql.SQLStr(stationName), sql.SQLStr(stationURL), sql.SQLStr(stationURL), volume, tonumber(id))
    else
        sqlQuery = string.format([[
            INSERT INTO permanent_boomboxes 
            (map, permanent_id, model, pos_x, pos_y, pos_z, angle_pitch, angle_yaw, angle_roll, station_name, station_url, volume)
            VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, 
                    CASE WHEN %s = '' THEN NULL ELSE %s END,
                    CASE WHEN %s = '' THEN NULL ELSE %s END,
                    %f);
        ]], sql.SQLStr(currentMap), sql.SQLStr(permanentID), sql.SQLStr(model), pos.x, pos.y, pos.z, ang.p, ang.y, ang.r, sql.SQLStr(stationName), sql.SQLStr(stationName), sql.SQLStr(stationURL), sql.SQLStr(stationURL), volume)
    end

    sql.Query(sqlQuery)
end

local function RemovePermanentBoombox(ent)
    if not IsValid(ent) then return end
    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then return end
    sql.Query(string.format([[
        DELETE FROM permanent_boomboxes
        WHERE map = '%s' AND permanent_id = '%s';
    ]], currentMap, permanentID))
end

local function LoadPermanentBoomboxes(isReload)
    if not StationQueue then
        timer.Simple(0.5, function() LoadPermanentBoomboxes(isReload) end)
        return
    end

    table.Empty(spawnedBoomboxes)
    table.Empty(spawnedBoomboxesByPosition)
    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then ent:Remove() end
    end

    if not sql.TableExists("permanent_boomboxes") then return end
    local loadQuery = string.format("SELECT *, COALESCE(station_name, '') as station_name, COALESCE(station_url, '') as station_url FROM permanent_boomboxes WHERE map = '%s';", currentMap)
    local result = sql.Query(loadQuery)
    if not result or #result == 0 then return end
    for i, row in ipairs(result) do
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
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        ent:SetNWString("PermanentID", row.permanent_id)
        ent:SetNWString("StationName", row.station_name)
        ent:SetNWString("StationURL", row.station_url)
        ent:SetNWFloat("Volume", row.volume)
        ent:SetNWBool("IsPlaying", row.station_url ~= "")
        ent:SetNWString("Status", row.station_url ~= "" and "playing" or "stopped")
        ent.IsPermanent = true
        ent:SetNWBool("IsPermanent", true)
        if row.station_url ~= "" and row.station_name ~= "" then
            timer.Simple(0.1, function()
                if not IsValid(ent) then return end
                if AddActiveRadio then AddActiveRadio(ent, row.station_name, row.station_url, row.volume) end
                StationQueue:add(ent, {
                    stationName = row.station_name,
                    url = row.station_url,
                    volume = row.volume,
                    player = nil
                })
            end)
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

net.Receive("MakeBoomboxPermanent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("You do not have permission to perform this action.")
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "boombox") then
        ply:ChatPrint("Invalid boombox entity.")
        return
    end

    if ent.IsPermanent then
        ply:ChatPrint("This boombox is already marked as permanent.")
        return
    end

    ent.IsPermanent = true
    ent:SetNWBool("IsPermanent", true)
    SavePermanentBoombox(ent)
    net.Start("BoomboxPermanentConfirmation")
    net.WriteString("Boombox has been marked as permanent.")
    net.Send(ply)
end)

net.Receive("RemoveBoomboxPermanent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("You do not have permission to perform this action.")
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "boombox") then
        ply:ChatPrint("Invalid boombox entity.")
        return
    end

    if not ent.IsPermanent then
        ply:ChatPrint("This boombox is not marked as permanent.")
        return
    end

    ent.IsPermanent = false
    ent:SetNWBool("IsPermanent", false)
    RemovePermanentBoombox(ent)
    if ent.StopRadio then ent:StopRadio() end
    net.Start("BoomboxPermanentConfirmation")
    net.WriteString("Boombox permanence has been removed.")
    net.Send(ply)
end)

_G.SavePermanentBoombox = SavePermanentBoombox
_G.RemovePermanentBoombox = RemovePermanentBoombox
concommand.Add("rradio_clear_permanent_db", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("You must be a superadmin to use this command.")
        return
    end

    sql.Query("DELETE FROM permanent_boomboxes;")
    if IsValid(ply) then ply:ChatPrint("Permanent boombox database has been cleared for all maps.") end
end)

concommand.Add("rradio_reload_permanent_boomboxes", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("You must be a superadmin to use this command.")
        return
    end

    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then ent:Remove() end
    end

    LoadPermanentBoomboxes(true)
    if IsValid(ply) then ply:ChatPrint("Permanent boomboxes have been reloaded.") end
end)

_G.LoadPermanentBoomboxes = function() LoadPermanentBoomboxes(false) end
hook.Add("Initialize", "UpdateCurrentMapForPermanentBoomboxes", function() currentMap = game.GetMap() end)