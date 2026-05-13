rRadio = rRadio or {}
rRadio.persistence = rRadio.persistence or {}
rRadio.persistence.service = rRadio.persistence.service or {}

local service = rRadio.persistence.service
local protocol = rRadio.net.protocol
local stateStore = rRadio.radio.stateStore

local TABLE_NAME = "permanent_boomboxes"
local SCHEMA_VERSION = 2
local DEFAULT_MODEL = "models/rammel/boombox.mdl"
local SAVE_DEBOUNCE_SECONDS = 0.75
local SAVE_TIMER_PREFIX = "rRadio.SavePermanentBoombox."
local storagePrepared = false
local cachedColumnSet

local function query( sqlText )
    local result = sql.Query( sqlText )
    if result == false then
        rRadio.logger.WarnScope( "persistence", sql.LastError() or "unknown SQL error" )
    end

    return result
end

local function escape( value )
    return sql.SQLStr( tostring( value or "" ) )
end

local function escapeStationID( stationID )
    stationID = tostring( stationID or "" )
    if stationID == "" then return "''" end

    return escape( stationID )
end

local function normalizeStationID( stationID )
    stationID = string.Trim( tostring( stationID or "" ) )
    if stationID == "" then return "" end
    if string.lower( stationID ) == "null" then return "" end
    if not rRadio.stations.schema.IsValidStationID( stationID ) then return "" end

    return stationID
end

local function getColumnSet()
    if cachedColumnSet then return cachedColumnSet end

    local columns = query( "PRAGMA table_info(" .. TABLE_NAME .. ")" ) or {}
    local columnSet = {}
    for _, column in ipairs( columns ) do
        columnSet[column.name] = true
    end

    cachedColumnSet = columnSet
    return cachedColumnSet
end

local function getLegacyStationSetters( columnSet )
    local setters = {}

    if columnSet.station_name then setters[#setters + 1] = "station_name = NULL" end
    if columnSet.station_url then setters[#setters + 1] = "station_url = NULL" end

    return setters
end

local function hasLegacyStationIdentity( row, columnSet )
    if columnSet.station_name and tostring( row.station_name or "" ) ~= "" then return true end
    if columnSet.station_url and tostring( row.station_url or "" ) ~= "" then return true end

    return false
end

local function updateRowAssignments( rowID, assignments )
    if #assignments == 0 then return true end

    return query( string.format(
        "UPDATE %s SET %s WHERE id = %d",
        TABLE_NAME,
        table.concat( assignments, ", " ),
        rowID
    ) ) ~= false
end

local function ensureTable()
    local exists = sql.TableExists( TABLE_NAME )
    if not exists then
        local created = query( string.format( [[
        CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            schema_version INTEGER NOT NULL,
            map TEXT NOT NULL,
            permanent_id TEXT NOT NULL,
            class TEXT NOT NULL,
            model TEXT NOT NULL,
            pos_x REAL NOT NULL,
            pos_y REAL NOT NULL,
            pos_z REAL NOT NULL,
            angle_pitch REAL NOT NULL,
            angle_yaw REAL NOT NULL,
            angle_roll REAL NOT NULL,
            station_id TEXT,
            is_public INTEGER NOT NULL DEFAULT 0,
            volume REAL NOT NULL,
            UNIQUE(map, permanent_id)
        )
        ]], TABLE_NAME ) )
        ~= false
        cachedColumnSet = nil
        return created
    end

    local columnSet = getColumnSet()

    if not columnSet.map then
        if query( "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN map TEXT NOT NULL DEFAULT ''" ) == false then
            return false
        end
        cachedColumnSet = nil
    end

    if not columnSet.permanent_id then
        if query( "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN permanent_id TEXT" ) == false then return false end
        cachedColumnSet = nil
    end

    if not columnSet.schema_version then
        local alterQuery = "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1"
        if query( alterQuery ) == false then return false end
        cachedColumnSet = nil
    end

    if not columnSet.class then
        local defaultClass = escape( rRadio.constants.EntityClasses.BOOMBOX )
        local alterQuery = "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN class TEXT NOT NULL DEFAULT " .. defaultClass
        if query( alterQuery ) == false then return false end
        cachedColumnSet = nil
    end

    if not columnSet.station_id then
        if query( "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN station_id TEXT" ) == false then return false end
        cachedColumnSet = nil
    end

    if not columnSet.is_public then
        if query( "ALTER TABLE " .. TABLE_NAME .. " ADD COLUMN is_public INTEGER NOT NULL DEFAULT 0" ) == false then
            return false
        end
        cachedColumnSet = nil
    end

    return true
end

local function migrateLegacyIdentity()
    if not sql.TableExists( TABLE_NAME ) then return end

    query( string.format(
        "UPDATE %s SET map = %s WHERE map IS NULL OR map = ''",
        TABLE_NAME,
        escape( game.GetMap() )
    ) )

    local rows = query( string.format(
        "SELECT id, permanent_id FROM %s WHERE permanent_id IS NULL OR permanent_id = ''",
        TABLE_NAME
    ) )
    if not rows then return end

    local migratedCount = 0
    for _, row in ipairs( rows ) do
        local rowID = tonumber( row.id ) or 0
        if rowID > 0 then
            query( string.format(
                "UPDATE %s SET permanent_id = %s WHERE id = %d",
                TABLE_NAME,
                escape( "legacy_" .. tostring( rowID ) ),
                rowID
            ) )
            migratedCount = migratedCount + 1
        end
    end

    if migratedCount > 0 then
        rRadio.logger.Info( "Migrated permanent boombox identities:", migratedCount )
    end
end

local function resolveLegacyStation( row )
    local stationURL = tostring( row.station_url or "" )
    if stationURL == "" then return nil end

    local station = rRadio.stations.registry.FindByURL( stationURL )
    if station then return station end

    local stationName = string.Trim( tostring( row.station_name or "" ) )
    if stationName == "" then return nil end

    local ok, customStation = rRadio.stations.registry.AddCustom( stationName, stationURL )
    if ok then return customStation end

    return nil
end

local function migratePermanentRowsToV2()
    if not sql.TableExists( TABLE_NAME ) then return end

    local columnSet = getColumnSet()
    local fields = { "id", "schema_version", "station_id" }
    if columnSet.station_name then fields[#fields + 1] = "station_name" end
    if columnSet.station_url then fields[#fields + 1] = "station_url" end

    local rows = query( string.format(
        "SELECT %s FROM %s",
        table.concat( fields, ", " ),
        TABLE_NAME
    ) )
    if not rows then return end

    local migratedCount = 0
    local finalizedCount = 0
    local unresolvedCount = 0
    for _, row in ipairs( rows ) do
        local rowID = tonumber( row.id ) or 0
        local schemaVersion = tonumber( row.schema_version ) or 0
        local rawStationID = tostring( row.station_id or "" )
        local stationID = normalizeStationID( rawStationID )
        local legacyIdentity = hasLegacyStationIdentity( row, columnSet )

        rRadio.logger.DebugScope(
            "persistence",
            "Migrating permanent row",
            rowID,
            "schema",
            row.schema_version,
            "rawStationID",
            rawStationID,
            "stationID",
            stationID,
            "legacyIdentity",
            legacyIdentity
        )

        if rowID > 0 and stationID == "" and legacyIdentity then
            local station = resolveLegacyStation( row )
            if station then
                stationID = station.id
                migratedCount = migratedCount + 1
            else
                unresolvedCount = unresolvedCount + 1
            end
        end

        local canFinalize = stationID ~= "" or not legacyIdentity
        local shouldFinalize = schemaVersion < SCHEMA_VERSION or rawStationID ~= stationID or legacyIdentity
        if rowID > 0 and canFinalize and shouldFinalize then
            local assignments = {
                "schema_version = " .. tostring( SCHEMA_VERSION ),
                "station_id = " .. escapeStationID( stationID )
            }
            table.Add( assignments, getLegacyStationSetters( columnSet ) )

            if updateRowAssignments( rowID, assignments ) then finalizedCount = finalizedCount + 1 end
        end
    end

    if migratedCount > 0 then
        rRadio.logger.Info( "Migrated permanent boombox station IDs:", migratedCount )
    end

    if finalizedCount > 0 then
        rRadio.logger.Info( "Finalized permanent boombox v2 rows:", finalizedCount )
    end

    if unresolvedCount > 0 then
        rRadio.logger.WarnScope( "persistence", "Unresolved legacy permanent boombox rows:", unresolvedCount )
    end
end

local function prepareStorage()
    if storagePrepared then return true end
    if not ensureTable() then return false end

    migrateLegacyIdentity()
    migratePermanentRowsToV2()

    storagePrepared = true
    return true
end

local function generatePermanentID()
    return tostring( os.time() ) .. "_" .. tostring( math.random( 1000, 9999 ) )
end

local function getPermanentID( entity )
    local permanentID = stateStore.GetPermanentID( entity )
    if permanentID ~= "" then return permanentID end

    permanentID = generatePermanentID()
    stateStore.SetPermanentID( entity, permanentID )
    return permanentID
end

local function getSaveTimerName( entity )
    return SAVE_TIMER_PREFIX .. getPermanentID( entity )
end

local function getExistingSaveTimerName( entity )
    local permanentID = stateStore.GetPermanentID( entity )
    if permanentID == "" then return nil end

    return SAVE_TIMER_PREFIX .. permanentID
end

local function upsertEntity( entity )
    local assignment = rRadio.radio.service.GetAssignment( entity ) or {}
    local columnSet = getColumnSet()
    local legacyStationSetters = getLegacyStationSetters( columnSet )
    local legacyStationUpdateSQL = ""
    local position = entity:GetPos()
    local angles = entity:GetAngles()
    local volume = tonumber( assignment.volume ) or stateStore.GetDefaultVolume( entity )
    local stationID = normalizeStationID( assignment.stationID )
    local permanentID = getPermanentID( entity )
    local mapName = escape( game.GetMap() )
    local escapedPermanentID = escape( permanentID )
    local isPublic = stateStore.IsPublic( entity ) and 1 or 0
    local existingRows = query( string.format(
        "SELECT id FROM %s WHERE map = %s AND permanent_id = %s LIMIT 1",
        TABLE_NAME,
        mapName,
        escapedPermanentID
    ) )
    if existingRows == false then return false end

    if #legacyStationSetters > 0 then
        legacyStationUpdateSQL = "\n                "
            .. table.concat( legacyStationSetters, ",\n                " )
            .. ","
    end

    rRadio.logger.DebugScope(
        "persistence",
        "Saving permanent boombox",
        permanentID,
        "stationID",
        stationID,
        "public",
        isPublic,
        "volume",
        volume,
        "existing",
        existingRows and existingRows[1] ~= nil
    )

    if existingRows and existingRows[1] then
        return query( string.format( [[
            UPDATE %s SET
                schema_version = %d,
                class = %s,
                model = %s,
                pos_x = %f,
                pos_y = %f,
                pos_z = %f,
                angle_pitch = %f,
                angle_yaw = %f,
                angle_roll = %f,
                station_id = %s, %s
                is_public = %d,
                volume = %f
            WHERE id = %d
        ]],
            TABLE_NAME,
            SCHEMA_VERSION,
            escape( entity:GetClass() ),
            escape( entity:GetModel() ),
            position.x,
            position.y,
            position.z,
            angles.p,
            angles.y,
            angles.r,
            escapeStationID( stationID ),
            legacyStationUpdateSQL,
            isPublic,
            volume,
            tonumber( existingRows[1].id ) or 0
        ) )
        ~= false
    end

    return query( string.format( [[
        INSERT INTO %s (
            schema_version,
            map,
            permanent_id,
            class,
            model,
            pos_x,
            pos_y,
            pos_z,
            angle_pitch,
            angle_yaw,
            angle_roll,
            station_id,
            is_public,
            volume
        )
        VALUES (%d, %s, %s, %s, %s, %f, %f, %f, %f, %f, %f, %s, %d, %f)
    ]],
        TABLE_NAME,
        SCHEMA_VERSION,
        mapName,
        escapedPermanentID,
        escape( entity:GetClass() ),
        escape( entity:GetModel() ),
        position.x,
        position.y,
        position.z,
        angles.p,
        angles.y,
        angles.r,
        escapeStationID( stationID ),
        isPublic,
        volume
    ) ) ~= false
end

local function removeEntityRow( entity )
    if not prepareStorage() then return false end

    local permanentID = stateStore.GetPermanentID( entity )
    if permanentID == "" then return true end

    return query( string.format(
        "DELETE FROM %s WHERE map = %s AND permanent_id = %s",
        TABLE_NAME,
        escape( game.GetMap() ),
        escape( permanentID )
    ) ) ~= false
end

local function savePermanentBoomboxNow( entity )
    if not IsValid( entity ) or not stateStore.IsPermanent( entity ) then return false end

    if not prepareStorage() then return false end
    return upsertEntity( entity )
end

local function getPersistentClass( className )
    local classes = rRadio.constants.EntityClasses
    if className == classes.BOOMBOX then return className end
    if className == classes.GOLDEN_BOOMBOX then return className end

    return classes.BOOMBOX
end

local function decodeRow( row )
    if type( row ) ~= "table" then return nil end

    local permanentID = tostring( row.permanent_id or "" )
    if permanentID == "" then return nil end

    local model = tostring( row.model or "" )
    if model == "" then model = DEFAULT_MODEL end

    return {
        rowID = tonumber( row.id ) or 0,
        schemaVersion = tonumber( row.schema_version ) or 0,
        map = tostring( row.map or "" ),
        permanentID = permanentID,
        class = getPersistentClass( tostring( row.class or "" ) ),
        model = model,
        position = Vector(
            tonumber( row.pos_x ) or 0,
            tonumber( row.pos_y ) or 0,
            tonumber( row.pos_z ) or 0
        ),
        angles = Angle(
            tonumber( row.angle_pitch ) or 0,
            tonumber( row.angle_yaw ) or 0,
            tonumber( row.angle_roll ) or 0
        ),
        stationID = normalizeStationID( row.station_id ),
        isPublic = tonumber( row.is_public ) == 1,
        volume = rRadio.util.ClampVolume( tonumber( row.volume ) or 1 )
    }
end

local function spawnRecord( record )
    rRadio.logger.DebugScope(
        "persistence",
        "Spawning permanent row",
        record.rowID,
        record.permanentID,
        record.class,
        "stationID",
        record.stationID
    )

    local entity = ents.Create( record.class )
    if not IsValid( entity ) then
        rRadio.logger.WarnScope( "persistence", "Could not create permanent boombox entity for row:", record.rowID )
        return
    end

    entity:SetModel( record.model )
    entity:SetPos( record.position )
    entity:SetAngles( record.angles )
    entity:Spawn()
    entity:Activate()

    local physics = entity:GetPhysicsObject()
    if IsValid( physics ) then physics:EnableMotion( false ) end

    stateStore.InitializeEntity( entity, {
        permanent = true,
        permanentID = record.permanentID,
        public = record.isPublic == true,
        defaultVolume = record.volume
    } )

    if record.stationID == "" then
        rRadio.logger.DebugScope(
            "persistence",
            "Permanent row has no station to restore",
            record.rowID,
            record.permanentID
        )
        return
    end

    timer.Simple( 0.25, function()
        if not IsValid( entity ) then return end

        rRadio.logger.DebugScope(
            "persistence",
            "Restoring permanent station",
            record.rowID,
            record.permanentID,
            record.stationID
        )

        local ok, reason = rRadio.radio.service.Restore( entity, record.stationID, record.volume )
        if not ok then
            rRadio.logger.WarnScope(
                "persistence",
                "Could not restore permanent station:",
                record.rowID,
                record.permanentID,
                record.stationID,
                tostring( reason or "unknown reason" )
            )
        end
    end )
end

local function clearPermanentEntities( actor, className )
    for _, entity in ipairs( ents.FindByClass( className ) ) do
        if stateStore.IsPermanent( entity ) then
            service.CancelPermanentBoomboxSave( entity )
            stateStore.SetPermanent( entity, false )
            rRadio.radio.snapshots.BroadcastSettings( entity )
            rRadio.radio.service.Stop( actor, entity, "cleanup" )
        end
    end
end

local function sendCommandFeedback( player, message )
    if IsValid( player ) then
        player:ChatPrint( "[rRadio] " .. message )
    else
        print( "[rRadio]", message )
    end
end

function service.SavePermanentBoombox( entity )
    if IsValid( entity ) then
        local timerName = getExistingSaveTimerName( entity )
        if timerName then timer.Remove( timerName ) end
    end

    return savePermanentBoomboxNow( entity )
end

function service.QueuePermanentBoomboxSave( entity )
    if not IsValid( entity ) or not stateStore.IsPermanent( entity ) then return false end

    local timerName = getSaveTimerName( entity )
    timer.Create( timerName, SAVE_DEBOUNCE_SECONDS, 1, function()
        if IsValid( entity ) then service.SavePermanentBoombox( entity ) end
    end )

    return true
end

function service.CancelPermanentBoomboxSave( entity )
    if not IsValid( entity ) then return false end

    local timerName = getExistingSaveTimerName( entity )
    if timerName then timer.Remove( timerName ) end
    return true
end

function service.FlushPermanentBoomboxSave( entity )
    if not IsValid( entity ) or not stateStore.IsPermanent( entity ) then return false end

    local timerName = getSaveTimerName( entity )
    if not timer.Exists( timerName ) then return savePermanentBoomboxNow( entity ) end

    timer.Remove( timerName )
    return savePermanentBoomboxNow( entity )
end

function service.LoadPermanentBoomboxes()
    if not prepareStorage() then return end

    rRadio.logger.DebugScope( "persistence", "Loading permanent boomboxes for map", game.GetMap() )

    for _, entity in ipairs( ents.FindByClass( rRadio.constants.EntityClasses.BOOMBOX ) ) do
        if stateStore.IsPermanent( entity ) then
            service.FlushPermanentBoomboxSave( entity )
            entity:Remove()
        end
    end

    for _, entity in ipairs( ents.FindByClass( rRadio.constants.EntityClasses.GOLDEN_BOOMBOX ) ) do
        if stateStore.IsPermanent( entity ) then
            service.FlushPermanentBoomboxSave( entity )
            entity:Remove()
        end
    end

    local rows = query( string.format(
        "SELECT * FROM %s WHERE map = %s",
        TABLE_NAME,
        escape( game.GetMap() )
    ) )
    if not rows then return end

    rRadio.logger.DebugScope( "persistence", "Loaded permanent row count", #rows )

    for _, row in ipairs( rows ) do
        local record = decodeRow( row )
        if record then spawnRecord( record ) end
    end
end

function service.SetPermanent( actor, entity, permanent )
    if not rRadio.config.AllowCreatePermanentBoombox then return false, "Permanent boomboxes are disabled." end
    if IsValid( actor ) and not rRadio.radio.permissions.CanManageConfig( actor ) then
        return false, "You do not have permission to change permanence."
    end
    if not rRadio.util.IsBoombox( entity ) then return false, "Invalid boombox." end

    if permanent then
        stateStore.SetPermanent( entity, true )
        if service.SavePermanentBoombox( entity ) then
            rRadio.radio.snapshots.BroadcastSettings( entity )
            return true
        end

        stateStore.SetPermanent( entity, false )
        stateStore.SetPermanentID( entity, "" )
        rRadio.radio.snapshots.BroadcastSettings( entity )
        return false, "Could not save permanent boombox."
    end

    service.CancelPermanentBoomboxSave( entity )
    if not removeEntityRow( entity ) then return false, "Could not remove permanent boombox row." end

    stateStore.SetPermanent( entity, false )
    rRadio.radio.service.Stop( actor, entity, "cleanup" )
    stateStore.SetPermanentID( entity, "" )
    rRadio.radio.snapshots.BroadcastSettings( entity )

    return true
end

local function sendResult( player, success, message, entity, permanent )
    net.Start( protocol.Messages.PersistenceResult )
    protocol.WriteVersion()
    net.WriteBool( success )
    net.WriteBool( permanent )
    net.WriteString( message )
    net.WriteEntity( entity )
    net.Send( player )
end

local function receivePersistenceRequest( _length, player )
    if not protocol.ReadClientVersion() then return end

    local entity = net.ReadEntity()
    local permanent = net.ReadBool()
    local ok, reason = service.SetPermanent( player, entity, permanent )
    sendResult( player, ok, ok and "Permanence updated." or tostring( reason ), entity, permanent )
end

local function registerCommands()
    concommand.Add( "rradio_reload_permanent_boomboxes", function( player )
        if IsValid( player ) and not rRadio.radio.permissions.CanManageConfig( player ) then
            player:ChatPrint( "[rRadio] You do not have permission to reload permanent boomboxes." )
            return
        end

        service.LoadPermanentBoomboxes()
        sendCommandFeedback( player, "Permanent boomboxes reloaded." )
    end )

    concommand.Add( "rradio_clear_permanent_db", function( player, _, args )
        if IsValid( player ) and not rRadio.radio.permissions.CanManageConfig( player ) then
            player:ChatPrint( "[rRadio] You do not have permission to clear permanent boomboxes." )
            return
        end

        if args[1] ~= "confirm" then
            local message = "[rRadio] Run rradio_clear_permanent_db confirm to clear permanent boomboxes."
            if IsValid( player ) then
                player:PrintMessage( HUD_PRINTCONSOLE, message )
            else
                print( message )
            end
            return
        end

        if not prepareStorage() or query( "DELETE FROM " .. TABLE_NAME ) == false then
            sendCommandFeedback( player, "Could not clear permanent boombox database." )
            return
        end

        clearPermanentEntities( player, rRadio.constants.EntityClasses.BOOMBOX )
        clearPermanentEntities( player, rRadio.constants.EntityClasses.GOLDEN_BOOMBOX )
        rRadio.logger.WarnScope( "persistence", "Permanent boombox database cleared." )
        sendCommandFeedback( player, "Permanent boombox database cleared." )
    end )
end

function service.Init()
    prepareStorage()

    net.Receive( protocol.Messages.PersistenceRequest, receivePersistenceRequest )
    registerCommands()
    rRadio.persistence.permapropsCompat.Init()

    hook.Add( "InitPostEntity", "rRadio_Persistence_LoadPermanentBoomboxes", function()
        timer.Simple( 1, service.LoadPermanentBoomboxes )
    end )

    hook.Add( "PostCleanupMap", "rRadio_Persistence_ReloadPermanentBoomboxes", function()
        timer.Simple( 1, service.LoadPermanentBoomboxes )
    end )
end

return service
