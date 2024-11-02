--[[
    Radio Addon Server-Side Permanent Boombox Management
    Author: Charles Mills
    Description: This file handles the server-side functionality for managing permanent boomboxes.
                 It includes functions for saving, loading, and removing permanent boomboxes using
                 a SQLite database. The file also manages network communications for permanent
                 boombox actions and provides console commands for administrators to manage the
                 permanent boombox system.
    Date: October 30, 2024
]]--

CreateConVar("boombox_permanent", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Toggle boombox permanence")

local initialLoadComplete = false
local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes = {}
local currentMap = game.GetMap()

local ActiveRadioRegistry = include("radio/server/sv_radio_registry.lua")

local POSITION_SAVE_INTERVAL = 30 -- Save position every 30 seconds
local STATION_SAVE_DEBOUNCE = 2 -- Debounce station saves by 2 seconds
local pendingSaves = {}
local lastPositionSaves = {}

local POSITION_THRESHOLD = 0.5 -- Only save position changes greater than this

local function hasPositionChanged(oldPos, newPos)
    if not oldPos or not newPos then return true end
    return math.abs(oldPos.x - newPos.x) > POSITION_THRESHOLD or
           math.abs(oldPos.y - newPos.y) > POSITION_THRESHOLD or
           math.abs(oldPos.z - newPos.z) > POSITION_THRESHOLD
end

local function hasDataChanged(oldData, newData)
    if not oldData then return true end
    
    -- Check if any essential data has changed
    return oldData.stationName ~= newData.stationName or
           oldData.url ~= newData.url or
           math.abs(oldData.volume - newData.volume) > 0.01 or
           hasPositionChanged(oldData.position, newData.position) or
           oldData.angles ~= newData.angles
end

-- Initialize the SQLite database
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
        
        local result = sql.Query(query)
    else
        -- Check if the 'map' column exists
        local columnCheckQuery = "PRAGMA table_info(permanent_boomboxes);"
        local columns = sql.Query(columnCheckQuery)
        local mapColumnExists = false
        
        for _, column in ipairs(columns) do
            if column.name == "map" then
                mapColumnExists = true
                break
            end
        end
        
        -- If 'map' column doesn't exist, add it
        if not mapColumnExists then
            local alterTableQuery = "ALTER TABLE permanent_boomboxes ADD COLUMN map TEXT NOT NULL DEFAULT '';"
            local result = sql.Query(alterTableQuery)
        end
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
    if not IsValid(ent) then 
        print("[rRadio Debug] SavePermanentBoombox: Invalid entity")
        return 
    end
    
    local entIndex = ent:EntIndex()
    local saveData = pendingSaves[entIndex]
    
    -- Get permanent ID or generate new one
    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString("PermanentID", permanentID)
        print("[rRadio Debug] Generated new PermanentID:", permanentID)
    end
    
    -- Get current radio data from registry first
    local radioData = ActiveRadioRegistry:Get(ent)
    print("[rRadio Debug] SavePermanentBoombox called for entity", entIndex)
    print("  - PermanentID:", permanentID)
    print("  - Has SaveData:", saveData ~= nil)
    print("  - Has RadioData:", radioData ~= nil)
    if radioData then
        print("  - RadioData Station:", radioData.stationName)
        print("  - RadioData URL:", radioData.url)
    end
    
    -- Use pending save data if available, otherwise use current state
    local model = sanitize(ent:GetModel())
    local pos = saveData and saveData.position or ent:GetPos()
    local ang = saveData and saveData.angles or ent:GetAngles()
    local stationName = (saveData and saveData.stationName) or (radioData and radioData.stationName) or ent:GetNWString("StationName", "")
    local stationURL = (saveData and saveData.url) or (radioData and radioData.url) or ent:GetNWString("StationURL", "")
    local volume = (saveData and saveData.volume) or (radioData and radioData.volume) or ent:GetNWFloat("Volume", 1.0)
    
    print("[rRadio Debug] Final save data:")
    print("  - Station:", stationName)
    print("  - URL:", stationURL)
    print("  - Volume:", volume)
    print("  - Position:", pos.x, pos.y, pos.z)
    
    -- Check if the boombox already exists for this map
    local query = string.format([[
        SELECT id FROM permanent_boomboxes
        WHERE map = %s AND permanent_id = %s
        LIMIT 1;
    ]], sql.SQLStr(currentMap), sql.SQLStr(permanentID))

    local result = sql.Query(query)
    if result == false then
        print("[rRadio Debug] SQL Error in existence check:", sql.LastError())
        return
    end

    if result and #result > 0 then
        -- Update existing entry
        local id = result[1].id
        local updateQuery = string.format([[
            UPDATE permanent_boomboxes
            SET model = %s, pos_x = %f, pos_y = %f, pos_z = %f,
                angle_pitch = %f, angle_yaw = %f, angle_roll = %f,
                station_name = %s, station_url = %s, volume = %f
            WHERE id = %d;
        ]],
            sql.SQLStr(model), pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
            sql.SQLStr(stationName), sql.SQLStr(stationURL), volume, tonumber(id)
        )
        result = sql.Query(updateQuery)
        if result == false then
            print("[rRadio Debug] SQL Update Error:", sql.LastError())
            print("[rRadio Debug] Failed Query:", updateQuery)
        else
            print("[rRadio Debug] Successfully updated existing boombox record")
        end
    else
        -- Insert new entry
        local insertQuery = string.format([[
            INSERT INTO permanent_boomboxes 
            (map, permanent_id, model, pos_x, pos_y, pos_z, 
            angle_pitch, angle_yaw, angle_roll, station_name, station_url, volume)
            VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, %s, %s, %f);
        ]],
            sql.SQLStr(currentMap), sql.SQLStr(permanentID), sql.SQLStr(model),
            pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
            sql.SQLStr(stationName), sql.SQLStr(stationURL), volume
        )
        result = sql.Query(insertQuery)
        if result == false then
            print("[rRadio Debug] SQL Insert Error:", sql.LastError())
            print("[rRadio Debug] Failed Query:", insertQuery)
        else
            print("[rRadio Debug] Successfully inserted new boombox record")
        end
    end

    -- Verify the save
    local verifyQuery = string.format([[
        SELECT * FROM permanent_boomboxes 
        WHERE map = %s AND permanent_id = %s;
    ]], sql.SQLStr(currentMap), sql.SQLStr(permanentID))
    
    local verifyResult = sql.Query(verifyQuery)
    if verifyResult and #verifyResult > 0 then
        print("[rRadio Debug] Save verification successful:")
        print("  - Verified Station:", verifyResult[1].station_name)
        print("  - Verified URL:", verifyResult[1].station_url)
        print("  - Verified Volume:", verifyResult[1].volume)
    else
        print("[rRadio Debug] Failed to verify save!")
        if verifyResult == false then
            print("[rRadio Debug] SQL Verify Error:", sql.LastError())
        end
    end
end

local function RemovePermanentBoombox(ent)
    if not IsValid(ent) then 
        return 
    end
    
    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then 
        return 
    end

    local deleteQuery = string.format([[
        DELETE FROM permanent_boomboxes
        WHERE map = '%s' AND permanent_id = '%s';
    ]], currentMap, permanentID)

    local success = sql.Query(deleteQuery)
end

local function LoadPermanentBoomboxes(isReload)    
    print("[rRadio Debug] Starting LoadPermanentBoomboxes (isReload:", isReload, ")")
    
    -- Clear existing permanent boomboxes
    if isReload then
        local count = 0
        for _, ent in ipairs(ents.FindByClass("boombox")) do
            if ent.IsPermanent then
                ent:Remove()
                count = count + 1
            end
        end
        print("[rRadio Debug] Cleared", count, "existing permanent boomboxes")
    end

    if not sql.TableExists("permanent_boomboxes") then
        print("[rRadio Debug] No permanent_boomboxes table exists")
        return
    end

    -- Dump current database state for debugging
    print("[rRadio Debug] Current Database State:")
    local dumpQuery = string.format("SELECT * FROM permanent_boomboxes WHERE map = '%s';", currentMap)
    local dumpResult = sql.Query(dumpQuery)
    if dumpResult then
        for _, row in ipairs(dumpResult) do
            print(string.format("DB Entry: ID=%s, PermanentID=%s", row.id, row.permanent_id))
            print("  - Station:", row.station_name)
            print("  - URL:", row.station_url)
            print("  - Volume:", row.volume)
        end
    end

    local loadQuery = string.format("SELECT * FROM permanent_boomboxes WHERE map = '%s';", currentMap)
    local result = sql.Query(loadQuery)
    
    if not result then 
        print("[rRadio Debug] No permanent boomboxes found for map:", currentMap)
        return 
    end
    
    print("[rRadio Debug] Found", #result, "permanent boomboxes to restore")
    
    for _, row in ipairs(result) do
        print("[rRadio Debug] Restoring boombox:", row.permanent_id)
        print("  - Position:", row.pos_x, row.pos_y, row.pos_z)
        print("  - Station:", row.station_name)
        print("  - URL:", row.station_url)
        print("  - Volume:", row.volume)
        
        -- Create the boombox entity
        local ent = ents.Create("boombox")
        if not IsValid(ent) then 
            print("[rRadio Debug] Failed to create boombox entity")
            continue 
        end

        ent:SetModel(row.model)
        ent:SetPos(Vector(row.pos_x, row.pos_y, row.pos_z))
        ent:SetAngles(Angle(row.angle_pitch, row.angle_yaw, row.angle_roll))
        ent:Spawn()
        ent:Activate()

        -- Freeze the boombox
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        -- Set permanent properties
        ent:SetNWString("PermanentID", row.permanent_id)
        ent.IsPermanent = true
        ent:SetNWBool("IsPermanent", true)

        -- If there's a station, start playing through ActiveRadioRegistry
        if row.station_url and row.station_url ~= "" then
            print("[rRadio Debug] Starting station playback for boombox:", row.permanent_id)
            print("  - Station Name:", row.station_name)
            print("  - URL:", row.station_url)
            print("  - Volume:", row.volume)
            
            -- Set initial networked values
            ent:SetNWString("StationName", row.station_name)
            ent:SetNWString("StationURL", row.station_url)
            ent:SetNWFloat("Volume", row.volume)
            
            -- Add to registry first
            local success = ActiveRadioRegistry:Add(
                ent, 
                row.station_name,
                row.station_url,
                row.volume,
                true  -- Mark as permanent
            )
            print("[rRadio Debug] Initial registry add result:", success)
            
            if success then
                -- Start the stream
                net.Start("PlayCarRadioStation")
                    net.WriteEntity(ent)
                    net.WriteString(row.station_name)
                    net.WriteString(row.station_url)
                    net.WriteFloat(row.volume)
                net.Broadcast()  -- Broadcast to all clients, they will handle range checking

                -- Set status after starting stream
                utils.setRadioStatus(ent, "playing", row.station_name, true)
                
                -- Then load as permanent boombox
                success = ActiveRadioRegistry:LoadPermanentBoombox(
                    ent,
                    row.station_name,
                    row.station_url,
                    row.volume
                )
                print("[rRadio Debug] LoadPermanentBoombox result:", success)
            end
        else
            print("[rRadio Debug] No station URL for boombox:", row.permanent_id)
        end
    end
    
    print("[rRadio Debug] Finished loading permanent boomboxes")
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

-- Network Receiver: MakeBoomboxPermanent
net.Receive("MakeBoomboxPermanent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("You do not have permission to perform this action.")
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "boombox" and ent:GetClass() ~= "golden_boombox") then
        ply:ChatPrint("Invalid boombox entity.")
        return
    end

    -- Check if already permanent
    if ent.IsPermanent then
        ply:ChatPrint("This boombox is already marked as permanent.")
        return
    end

    -- Mark as permanent
    ent.IsPermanent = true
    ent:SetNWBool("IsPermanent", true)

    -- Save to database
    SavePermanentBoombox(ent)

    -- Send confirmation to client
    net.Start("BoomboxPermanentConfirmation")
        net.WriteString("Boombox has been marked as permanent.")
    net.Send(ply)
end)

-- Network Receiver: RemoveBoomboxPermanent
net.Receive("RemoveBoomboxPermanent", function(len, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        ply:ChatPrint("You do not have permission to perform this action.")
        return
    end

    local ent = net.ReadEntity()
    if not IsValid(ent) or (ent:GetClass() ~= "boombox" and ent:GetClass() ~= "golden_boombox") then
        ply:ChatPrint("Invalid boombox entity.")
        return
    end

    -- Check if it's marked as permanent
    if not ent.IsPermanent then
        ply:ChatPrint("This boombox is not marked as permanent.")
        return
    end

    -- Remove permanence
    ent.IsPermanent = false
    ent:SetNWBool("IsPermanent", false)

    -- Remove from database
    RemovePermanentBoombox(ent)

    -- Stop the radio if desired
    if ent.StopRadio then
        ent:StopRadio()
    end

    -- Send confirmation to client
    net.Start("BoomboxPermanentConfirmation")
        net.WriteString("Boombox permanence has been removed.")
    net.Send(ply)
end)

-- Make functions globally accessible
_G.SavePermanentBoombox = SavePermanentBoombox
_G.RemovePermanentBoombox = RemovePermanentBoombox

local AddActiveRadio = _G.AddActiveRadio

-- ConCommand to clear the permanent boombox database
concommand.Add("rradio_clear_permanent_db", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("You must be a superadmin to use this command.")
        return
    end

    -- Clear all boomboxes from the database
    local clearQuery = "DELETE FROM permanent_boomboxes;"
    sql.Query(clearQuery)
    
    if IsValid(ply) then
        ply:ChatPrint("Permanent boombox database has been cleared for all maps.")
    end
end)

-- Update the concommand to use the isReload parameter
concommand.Add("rradio_reload_permanent_boomboxes", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("You must be a superadmin to use this command.")
        return
    end

    -- Remove existing permanent boomboxes
    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then
            ent:Remove()
        end
    end

    -- Reload permanent boomboxes
    LoadPermanentBoomboxes(true)
    
    if IsValid(ply) then
        ply:ChatPrint("Permanent boomboxes have been reloaded.")
    end
end)

_G.LoadPermanentBoomboxes = function()
    LoadPermanentBoomboxes(false)
end

hook.Add("Initialize", "UpdateCurrentMapForPermanentBoomboxes", function()
    currentMap = game.GetMap()
end)

local function QueueSave(entity, reason)
    if not IsValid(entity) or not entity.IsPermanent then 
        print("[rRadio Debug] QueueSave rejected:", not IsValid(entity) and "Invalid entity" or "Not permanent")
        return 
    end
    
    local entIndex = entity:EntIndex()
    local radioData = ActiveRadioRegistry:Get(entity)
    local currentTime = CurTime()
    
    print("[rRadio Debug] QueueSave called")
    print("  - Entity:", entIndex)
    print("  - Reason:", reason)
    print("  - Has RadioData:", radioData ~= nil)
    print("  - Current Station:", radioData and radioData.stationName or "none")
    print("  - Current URL:", radioData and radioData.url or "none")
    
    -- Get current state
    local currentState = {
        position = entity:GetPos(),
        angles = entity:GetAngles(),
        stationName = radioData and radioData.stationName or entity:GetNWString("StationName", ""),
        url = radioData and radioData.url or entity:GetNWString("StationURL", ""),
        volume = entity:GetNWFloat("Volume", 1.0)
    }
    
    -- Initialize or update pending save
    if not pendingSaves[entIndex] then
        pendingSaves[entIndex] = {
            entity = entity,
            lastSave = 0,
            nextSave = currentTime + STATION_SAVE_DEBOUNCE,
            position = currentState.position,
            lastSavedPosition = currentState.position,
            angles = currentState.angles,
            lastPositionSave = lastPositionSaves[entIndex] or 0,
            stationName = currentState.stationName,
            url = currentState.url,
            volume = currentState.volume,
            lastSavedState = table.Copy(currentState)
        }
        print("[rRadio Debug] Created new pending save")
    else
        -- Check if position has changed significantly
        local positionChanged = hasPositionChanged(
            pendingSaves[entIndex].lastSavedPosition,
            currentState.position
        )
        
        -- Check if other data has changed
        local dataChanged = hasDataChanged(
            pendingSaves[entIndex].lastSavedState,
            currentState
        )
        
        if positionChanged or dataChanged then
            print("[rRadio Debug] Updating pending save")
            print("  - Position changed:", positionChanged)
            print("  - Data changed:", dataChanged)
            
            pendingSaves[entIndex].position = currentState.position
            pendingSaves[entIndex].angles = currentState.angles
            pendingSaves[entIndex].stationName = currentState.stationName
            pendingSaves[entIndex].url = currentState.url
            pendingSaves[entIndex].volume = currentState.volume
            pendingSaves[entIndex].nextSave = currentTime + STATION_SAVE_DEBOUNCE
            
            -- Only update position save time if position changed
            if positionChanged then
                pendingSaves[entIndex].lastPositionSave = currentTime
                pendingSaves[entIndex].lastSavedPosition = currentState.position
            end
            
            -- Update saved state
            pendingSaves[entIndex].lastSavedState = table.Copy(currentState)
        else
            print("[rRadio Debug] No significant changes to save")
        end
    end
end

_G.QueueBoomboxSave = QueueSave

-- Update the timer that processes saves
timer.Create("ProcessPermanentBoomboxSaves", 1, 0, function()
    local currentTime = CurTime()
    
    for entIndex, saveData in pairs(pendingSaves) do
        if not IsValid(saveData.entity) then
            print("[rRadio Debug] Removing invalid entity from pending saves:", entIndex)
            pendingSaves[entIndex] = nil
            continue
        end
        
        local shouldSave = false
        local reasons = {}
        
        -- Check if position needs saving
        if currentTime - saveData.lastPositionSave >= POSITION_SAVE_INTERVAL then
            if hasPositionChanged(saveData.lastSavedPosition, saveData.position) then
                shouldSave = true
                table.insert(reasons, "position_update")
            end
        end
        
        -- Check if station data needs saving
        if currentTime >= saveData.nextSave then
            -- Get current state
            local currentState = {
                stationName = saveData.stationName,
                url = saveData.url,
                volume = saveData.volume
            }
            
            -- Compare with last saved state
            if not saveData.lastSavedState or 
               currentState.stationName ~= saveData.lastSavedState.stationName or
               currentState.url ~= saveData.lastSavedState.url or
               math.abs(currentState.volume - saveData.lastSavedState.volume) > 0.01 then
                shouldSave = true
                table.insert(reasons, "station_update")
            end
        end
        
        if shouldSave then
            print(string.format("[rRadio Debug] Processing save for boombox %d", entIndex))
            print("  - Reasons:", table.concat(reasons, ", "))
            print("  - Station:", saveData.stationName)
            print("  - URL:", saveData.url)
            
            SavePermanentBoombox(saveData.entity)
            
            -- Update save times and last saved state
            saveData.lastSave = currentTime
            if table.HasValue(reasons, "position_update") then
                saveData.lastPositionSave = currentTime
                saveData.lastSavedPosition = saveData.position
            end
            
            -- Update last saved state
            saveData.lastSavedState = {
                stationName = saveData.stationName,
                url = saveData.url,
                volume = saveData.volume
            }
            
            -- Clear pending save
            pendingSaves[entIndex] = nil
        end
    end
end)
