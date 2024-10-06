--[[ 
    rRadio Addon for Garry's Mod - Database Management
    Description: Handles database operations for the rRadio addon.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

local database = {}

function database.CreateBoomboxStatesTable()
    local createTableQuery = [[
        CREATE TABLE IF NOT EXISTS boombox_states (
            permaID INTEGER PRIMARY KEY,
            station TEXT,
            url TEXT,
            isPlaying INTEGER,
            volume REAL
        )
    ]]
    sql.Query(createTableQuery)
end

function database.SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format(
        "REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume
    )
    sql.Query(query)
end

function database.RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    sql.Query(query)
end

function database.LoadBoomboxStatesFromDatabase()
    local rows = sql.Query("SELECT * FROM boombox_states")
    if rows then
        for _, row in ipairs(rows) do
            local permaID = tonumber(row.permaID)
            SavedBoomboxStates[permaID] = {
                station = row.station,
                url = row.url,
                isPlaying = tonumber(row.isPlaying) == 1,
                volume = tonumber(row.volume)
            }
        end
    else
        SavedBoomboxStates = {}
    end
end

return database
