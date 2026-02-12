rRadio = rRadio or {}
rRadio.sv = rRadio.sv or {}
rRadio.sv.db = rRadio.sv.db or {}
local db = rRadio.sv.db
function db.Query( q )
    local result = sql.Query( q )
    if result == false then
        local err = sql.LastError() or "unknown"
        rRadio.logger.ErrorScope( "db", "SQL error:", err, "-- Query:", q )
    end
    return result
end

function db.EnsurePermanentTable()
    if not sql.TableExists( "permanent_boomboxes" ) then
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
);]]
        db.Query( query )
        return
    end

    local columnCheckQuery = "PRAGMA table_info(permanent_boomboxes);"
    local columns = db.Query( columnCheckQuery ) or {}
    local mapColumnExists = false
    for _, column in ipairs( columns ) do
        if column.name == "map" then
            mapColumnExists = true
            break
        end
    end

    if not mapColumnExists then
        local alterTableQuery = "ALTER TABLE permanent_boomboxes ADD COLUMN map TEXT NOT NULL DEFAULT '';"
        db.Query( alterTableQuery )
    end
end
return db
