rRadio.sv.permanent = rRadio.sv.permanent or {}
local db = rRadio.sv.db or include( "rradio/server/sv_db.lua" )
local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes = {}
local currentMap = game.GetMap()
rRadio.sv.BoomboxStatuses = rRadio.sv.BoomboxStatuses or {}
db.EnsurePermanentTable()

local function GeneratePermanentID()
    return os.time() .. "_" .. math.random( 1000, 9999 )
end

local function ensurePermanentTable()
    if sql.TableExists( "permanent_boomboxes" ) then return true end
    db.EnsurePermanentTable()
    return sql.TableExists( "permanent_boomboxes" )
end

local function fetchStationData( ent, entIndex )
    local stationName = ""
    local stationURL = ""
    local volume = ent:GetNWFloat( "Volume", 1.0 )
    if rRadio.sv.ActiveRadios and rRadio.sv.ActiveRadios[entIndex] then
        stationName = rRadio.sv.ActiveRadios[entIndex].stationName or ""
        stationURL = rRadio.sv.ActiveRadios[entIndex].url or ""
    end

    if ( stationURL == "" or stationName == "" )
        and rRadio.sv.BoomboxStatuses
        and rRadio.sv.BoomboxStatuses[entIndex] then
        if stationURL == "" then stationURL = rRadio.sv.BoomboxStatuses[entIndex].url or "" end
        if stationName == "" then stationName = rRadio.sv.BoomboxStatuses[entIndex].stationName or "" end
    end

    if stationURL == "" or stationName == "" then
        if stationName == "" then stationName = ent:GetNWString( "StationName", "" ) end
        if stationURL == "" then stationURL = ent:GetNWString( "StationURL", "" ) end
    end
    return stationName, stationURL, volume
end

local function upsertBoombox( permanentID, model, pos, ang, stationName, stationURL, volume )
    local query = string.format( [[
        INSERT INTO permanent_boomboxes
            (map, permanent_id, model,
             pos_x, pos_y, pos_z,
             angle_pitch, angle_yaw, angle_roll,
             station_name, station_url, volume)
        VALUES
            (%s, %s, %s,
             %f, %f, %f,
             %f, %f, %f,
             %s, %s, %f)
        ON CONFLICT(map, permanent_id) DO UPDATE SET
            model        = excluded.model,
            pos_x        = excluded.pos_x,
            pos_y        = excluded.pos_y,
            pos_z        = excluded.pos_z,
            angle_pitch  = excluded.angle_pitch,
            angle_yaw    = excluded.angle_yaw,
            angle_roll   = excluded.angle_roll,
            station_name = excluded.station_name,
            station_url  = excluded.station_url,
            volume       = excluded.volume;
    ]], sql.SQLStr( currentMap ),
        sql.SQLStr( permanentID ),
        sql.SQLStr( model ),
        pos.x, pos.y, pos.z,
        ang.p, ang.y, ang.r,
        sql.SQLStr( stationName ),
        sql.SQLStr( stationURL ), volume )
    db.Query( query )
end

local function spawnPermanentBoombox( row )
    if spawnedBoomboxes[row.permanent_id] then return end
    local posKey = string.format( "%.2f,%.2f,%.2f", row.pos_x, row.pos_y, row.pos_z )
    if spawnedBoomboxesByPosition[posKey] then return end
    local ent = ents.Create( "rammel_boombox" )
    if not IsValid( ent ) then return end
    ent:SetModel( row.model )
    ent:SetPos( Vector( row.pos_x, row.pos_y, row.pos_z ) )
    ent:SetAngles( Angle( row.angle_pitch, row.angle_yaw, row.angle_roll ) )
    ent:Spawn()
    ent:Activate()
    local phys = ent:GetPhysicsObject()
    if IsValid( phys ) then phys:EnableMotion( false ) end
    ent:SetNWString( "PermanentID", row.permanent_id )
    ent:SetNWString( "StationName", row.station_name )
    ent:SetNWString( "StationURL", row.station_url )
    ent:SetNWFloat( "Volume", row.volume )
    ent.IsPermanent = true
    ent:SetNWBool( "IsPermanent", true )
    if row.station_url ~= "" then
        local entIndex = ent:EntIndex()
        rRadio.sv.BoomboxStatuses[entIndex] = rRadio.sv.BoomboxStatuses[entIndex] or {}
        local status = rRadio.sv.BoomboxStatuses[entIndex]
        status.url = row.station_url
        status.stationName = row.station_name
        status.stationStatus = rRadio.status.PLAYING
        ent:SetNWInt( "Status", rRadio.status.PLAYING )
        ent:SetNWBool( "IsPlaying", true )
        timer.Simple( 0.1, function()
            if not IsValid( ent ) then return end
            rRadio.sv.utils.BroadcastPlay( ent, row.station_name or "", row.station_url, row.volume )
        end )

        rRadio.sv.utils.AddActiveRadio( ent, row.station_name or "", row.station_url, row.volume )
    end

    spawnedBoomboxes[row.permanent_id] = true
    spawnedBoomboxesByPosition[posKey] = true
end

function rRadio.sv.permanent.SavePermanentBoombox( ent )
    if not IsValid( ent ) then return end
    if not ensurePermanentTable() then return end
    local model = ent:GetModel()
    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local entIndex = ent:EntIndex()
    local stationName, stationURL, volume = fetchStationData( ent, entIndex )
    local permanentID = ent:GetNWString( "PermanentID", "" )
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString( "PermanentID", permanentID )
    end

    upsertBoombox( permanentID, model, pos, ang, stationName, stationURL, volume )
end

function rRadio.sv.permanent.ClearSavedStation( ent )
    if not IsValid( ent ) then return end
    local permanentID = ent:GetNWString( "PermanentID", "" )
    if permanentID == "" then return end
    if not ensurePermanentTable() then
        rRadio.logger.WarnScope( "permanent", "Permanent boombox table does not exist, cannot clear station." )
        return
    end

    local model = ent:GetModel()
    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local volume = ent:GetNWFloat( "Volume", rRadio.config.DefaultVolume or 1.0 )
    upsertBoombox( permanentID, model, pos, ang, "", "", volume )
    rRadio.logger.DebugScope(
        "permanent", "Cleared saved station for permanent boombox ID:",
        permanentID, "on map", currentMap
    )
end

local function RemovePermanentBoombox( ent )
    if not IsValid( ent ) then return end
    local permanentID = ent:GetNWString( "PermanentID", "" )
    if permanentID == "" then return end
    local deleteQuery = string.format( [[
        DELETE FROM permanent_boomboxes
        WHERE map = %s AND permanent_id = %s;
    ]], sql.SQLStr( currentMap ), sql.SQLStr( permanentID ) )
    db.Query( deleteQuery )
end

function rRadio.sv.permanent.LoadPermanentBoomboxes( _isReload )
    table.Empty( spawnedBoomboxes )
    table.Empty( spawnedBoomboxesByPosition )
    for _, ent in ipairs( ents.FindByClass( "rammel_boombox" ) ) do
        if ent.IsPermanent then ent:Remove() end
    end

    if not sql.TableExists( "permanent_boomboxes" ) then return end
    local loadQuery = string.format( "SELECT * FROM permanent_boomboxes WHERE map = %s;", sql.SQLStr( currentMap ) )
    local result = db.Query( loadQuery )
    if not result then return end
    for _, row in ipairs( result ) do
        spawnPermanentBoombox( row )
    end
end

hook.Remove( "InitPostEntity", "rRadio.LoadPermanentBoomboxes" )
hook.Remove( "PostCleanupMap", "rRadio.ReloadPermanentBoomboxes" )
hook.Add( "PostCleanupMap", "rRadio.LoadPermanentBoomboxes", function()
    timer.Simple( 5, function()
        rRadio.sv.permanent.LoadPermanentBoomboxes()
    end )
end )

local function validatePersistentRequest( ply )
    if not IsValid( ply ) then return nil end
    if not ply:IsSuperAdmin() then
        ply:ChatPrint( "[rRadio] You do not have permission to perform this action." )
        return nil
    end

    local ent = net.ReadEntity()
    if not IsValid( ent ) or not rRadio.utils.IsBoombox( ent ) then
        ply:ChatPrint( "[rRadio] Invalid boombox entity." )
        return nil
    end

    return ent
end

net.Receive( "rRadio.SetPersistent", function( _len, ply )
    local ent = validatePersistentRequest( ply )
    if not ent then return end

    if not rRadio.config.AllowCreatePermanentBoombox then
        ply:ChatPrint( "[rRadio] Creating permanent boomboxes is disabled by the server." )
        return
    end

    if ent.IsPermanent then
        ply:ChatPrint( "[rRadio] This boombox is already marked as permanent." )
        return
    end

    ent.IsPermanent = true
    ent:SetNWBool( "IsPermanent", true )
    rRadio.sv.permanent.SavePermanentBoombox( ent )
    net.Start( "rRadio.SendPersistentConfirmation" )
    net.WriteString( "Boombox has been marked as permanent." )
    net.Send( ply )
end )

net.Receive( "rRadio.RemovePersistent", function( _len, ply )
    local ent = validatePersistentRequest( ply )
    if not ent then return end

    if not ent.IsPermanent then
        ply:ChatPrint( "[rRadio] This boombox is not marked as permanent." )
        return
    end

    ent.IsPermanent = false
    ent:SetNWBool( "IsPermanent", false )
    RemovePermanentBoombox( ent )
    if ent.StopRadio then ent:StopRadio() end
    net.Start( "rRadio.SendPersistentConfirmation" )
    net.WriteString( "Boombox permanence has been removed." )
    net.Send( ply )
end )

local function requireSuperAdmin( ply )
    if not IsValid( ply ) then return true end
    if ply:IsSuperAdmin() then return true end
    ply:ChatPrint( "[rRadio] You must be a superadmin to use this command." )
    return false
end

concommand.Add( "rradio_clear_permanent_db", function( ply, _cmd, _args )
    if not requireSuperAdmin( ply ) then return end

    db.Query( "DELETE FROM permanent_boomboxes;" )
    if IsValid( ply ) then ply:ChatPrint( "[rRadio] Permanent boombox database has been cleared for all maps." ) end
end )

concommand.Add( "rradio_reload_permanent_boomboxes", function( ply, _cmd, _args )
    if not requireSuperAdmin( ply ) then return end

    for _, ent in ipairs( ents.FindByClass( "rammel_boombox" ) ) do
        if ent.IsPermanent then ent:Remove() end
    end

    rRadio.sv.permanent.LoadPermanentBoomboxes( true )
    if IsValid( ply ) then ply:ChatPrint( "[rRadio] Permanent boomboxes have been reloaded." ) end
end )

hook.Add( "Initialize", "rRadio.UpdateCurrentMapForPermanentBoomboxes", function() currentMap = game.GetMap() end )
