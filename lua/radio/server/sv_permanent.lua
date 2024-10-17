--[[
    Permanent Boombox Server-Side Script
    Author: Charles Mills
    Description: Handles making boomboxes permanent, saving to and loading from a SQLite database.
    Date: October 17, 2024
]]--

-- Network Strings
util.AddNetworkString("MakeBoomboxPermanent")
util.AddNetworkString("RemoveBoomboxPermanent")
util.AddNetworkString("BoomboxPermanentConfirmation")

-- Create the ConVar for boombox permanence
CreateConVar("boombox_permanent", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Toggle boombox permanence")

local spawnedBoomboxesByPosition = {}
local spawnedBoomboxes = {}
local currentMap = game.GetMap()

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
        if result == false then
            print("[Permanent Boombox] Failed to create 'permanent_boomboxes' table.")
            print("[Permanent Boombox] SQL Error: " .. sql.LastError())
        else
            print("[Permanent Boombox] Database table 'permanent_boomboxes' created successfully.")
        end
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
            if result == false then
                print("[Permanent Boombox] Failed to add 'map' column to 'permanent_boomboxes' table.")
                print("[Permanent Boombox] SQL Error: " .. sql.LastError())
            else
                print("[Permanent Boombox] Added 'map' column to 'permanent_boomboxes' table successfully.")
            end
        end
    end
end

-- Call the initialization function
InitializeDatabase()

-- Function to sanitize inputs to prevent SQL injection
local function sanitize(str)
    return string.gsub(str, "'", "''")
end

-- Function to generate a unique permanent ID
local function GeneratePermanentID()
    return os.time() .. "_" .. math.random(1000, 9999)
end

-- Function to add or update a permanent boombox in the database
local function SavePermanentBoombox(ent)
    print("[Permanent Boombox] Attempting to save boombox to database:", ent)
    if not IsValid(ent) then 
        print("[Permanent Boombox] Error: Invalid entity")
        return 
    end
    local model = sanitize(ent:GetModel())
    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    local stationName = sanitize(ent:GetNWString("StationName", ""))
    local stationURL = sanitize(ent:GetNWString("StationURL", ""))
    local volume = ent:GetNWFloat("Volume", 1.0)

    print("[Permanent Boombox] Entity details:")
    print("  Model:", model)
    print("  Position:", pos)
    print("  Angles:", ang)
    print("  Station Name:", stationName)
    print("  Station URL:", stationURL)
    print("  Volume:", volume)

    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then
        permanentID = GeneratePermanentID()
        ent:SetNWString("PermanentID", permanentID)
    end

    -- Check if the boombox already exists for this map
    local query = string.format([[
        SELECT id FROM permanent_boomboxes
        WHERE map = '%s' AND permanent_id = '%s'
        LIMIT 1;
    ]], currentMap, permanentID)

    local result = sql.Query(query)
    if sql.LastError() then
        print("[Permanent Boombox] SQL Error during select query:", sql.LastError())
        return
    end

    if result and #result > 0 then
        -- Update existing entry
        local id = result[1].id
        local updateQuery = string.format([[
            UPDATE permanent_boomboxes
            SET model = '%s', pos_x = %f, pos_y = %f, pos_z = %f,
                angle_pitch = %f, angle_yaw = %f, angle_roll = %f,
                station_name = '%s', station_url = '%s', volume = %f
            WHERE id = %d;
        ]],
            model, pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
            stationName, stationURL, volume, tonumber(id)
        )
        local success = sql.Query(updateQuery)
        if success == false then
            print("[Permanent Boombox] Failed to update boombox in database:", ent)
            print("[Permanent Boombox] SQL Error:", sql.LastError())
            print("[Permanent Boombox] Update Query:", updateQuery)
        else
            print("[Permanent Boombox] Updated permanent boombox in database:", ent)
            print("[Permanent Boombox] Permanent ID:", permanentID)
        end
    else
        -- Insert new entry
        local insertQuery = string.format([[
            INSERT INTO permanent_boomboxes (map, permanent_id, model, pos_x, pos_y, pos_z, angle_pitch, angle_yaw, angle_roll, station_name, station_url, volume)
            VALUES ('%s', '%s', '%s', %f, %f, %f, %f, %f, %f, '%s', '%s', %f);
        ]],
            currentMap, permanentID, model, pos.x, pos.y, pos.z, ang.p, ang.y, ang.r,
            stationName, stationURL, volume
        )
        local success = sql.Query(insertQuery)
        if success == false then
            print("[Permanent Boombox] Failed to add boombox to database:", ent)
            print("[Permanent Boombox] SQL Error:", sql.LastError())
            print("[Permanent Boombox] Insert Query:", insertQuery)
        else
            print("[Permanent Boombox] Added permanent boombox to database:", ent)
            print("[Permanent Boombox] Permanent ID:", permanentID)
        end
    end

    -- After saving, let's verify the entry
    local verifyQuery = string.format("SELECT * FROM permanent_boomboxes WHERE permanent_id = '%s'", permanentID)
    local verifyResult = sql.Query(verifyQuery)
    if verifyResult and #verifyResult > 0 then
        print("[Permanent Boombox] Verified: Boombox exists in database after save.")
    else
        print("[Permanent Boombox] Error: Boombox not found in database after save attempt.")
        print("[Permanent Boombox] Verify Query:", verifyQuery)
        print("[Permanent Boombox] SQL Error:", sql.LastError())
    end
end

-- Function to remove a permanent boombox from the database
local function RemovePermanentBoombox(ent)
    if not IsValid(ent) then 
        print("[Permanent Boombox] Error: Invalid entity passed to RemovePermanentBoombox")
        return 
    end
    
    local permanentID = ent:GetNWString("PermanentID", "")
    if permanentID == "" then 
        print("[Permanent Boombox] Error: Entity has no PermanentID")
        return 
    end

    local deleteQuery = string.format([[
        DELETE FROM permanent_boomboxes
        WHERE map = '%s' AND permanent_id = '%s';
    ]], currentMap, permanentID)

    local success = sql.Query(deleteQuery)
    if success == false then
        print("[Permanent Boombox] Failed to remove boombox from database:", ent)
        print("[Permanent Boombox] SQL Error:", sql.LastError())
        print("[Permanent Boombox] Delete Query:", deleteQuery)
    else
        print("[Permanent Boombox] Successfully removed permanent boombox from database. PermanentID:", permanentID)
    end
end

-- Function to load and spawn all permanent boomboxes from the database
local function LoadPermanentBoomboxes(isReload)
    if isReload then
        print("[Permanent Boombox] Reloading permanent boomboxes.")
    else
        print("[Permanent Boombox] Loading permanent boomboxes for the first time.")
    end

    print("[Permanent Boombox] Attempting to load permanent boomboxes from database.")
    
    -- Clear the tracking tables
    table.Empty(spawnedBoomboxes)
    table.Empty(spawnedBoomboxesByPosition)

    -- Remove existing permanent boomboxes
    for _, ent in ipairs(ents.FindByClass("boombox")) do
        if ent.IsPermanent then
            print("[Permanent Boombox] Removing existing permanent boombox:", ent)
            ent:Remove()
        end
    end

    if not sql.TableExists("permanent_boomboxes") then
        print("[Permanent Boombox] Error: Table 'permanent_boomboxes' does not exist.")
        return
    end

    local loadQuery = string.format("SELECT * FROM permanent_boomboxes WHERE map = '%s';", currentMap)
    local result = sql.Query(loadQuery)
    
    if result == false then
        print("[Permanent Boombox] SQL Error when loading boomboxes: " .. sql.LastError())
        return
    elseif result == nil or #result == 0 then
        print("[Permanent Boombox] No permanent boomboxes found in the database.")
        return
    end

    print("[Permanent Boombox] Found " .. #result .. " boomboxes in the database.")

    for i, row in ipairs(result) do
        print(string.format("[Permanent Boombox] Processing boombox #%d: ID=%s, Model=%s, Pos=(%f, %f, %f)", 
            i, row.permanent_id, row.model, row.pos_x, row.pos_y, row.pos_z))

        -- Check if this boombox has already been spawned by ID
        if spawnedBoomboxes[row.permanent_id] then
            print("[Permanent Boombox] Skipping duplicate boombox #" .. i .. " with ID: " .. row.permanent_id)
            continue
        end

        -- Check if a boombox already exists at this position
        local posKey = string.format("%.2f,%.2f,%.2f", row.pos_x, row.pos_y, row.pos_z)
        if spawnedBoomboxesByPosition[posKey] then
            print("[Permanent Boombox] Skipping duplicate boombox #" .. i .. " at position: " .. posKey)
            continue
        end

        local ent = ents.Create("boombox")
        if not IsValid(ent) then
            print("[Permanent Boombox] Failed to create boombox entity from database entry #" .. i)
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

        -- Set networked variables
        ent:SetNWString("PermanentID", row.permanent_id)
        ent:SetNWString("StationName", row.station_name)
        ent:SetNWString("StationURL", row.station_url)
        ent:SetNWFloat("Volume", row.volume)

        -- Mark as permanent
        ent.IsPermanent = true
        ent:SetNWBool("IsPermanent", true)

        -- Start playing the radio
        if row.station_url ~= "" then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(ent)
                net.WriteString(row.station_name)
                net.WriteString(row.station_url)
                net.WriteFloat(row.volume)
            net.Broadcast()

            -- Add to active radios
            if AddActiveRadio then
                AddActiveRadio(ent, row.station_name, row.station_url, row.volume)
            else
                print("[Permanent Boombox] Warning: AddActiveRadio function not found")
            end
        end

        -- Mark this boombox as spawned
        spawnedBoomboxes[row.permanent_id] = true
        spawnedBoomboxesByPosition[posKey] = true

        print("[Permanent Boombox] Successfully loaded permanent boombox #" .. i .. ": " .. tostring(ent))
    end

    print("[Permanent Boombox] Finished loading permanent boomboxes.")
    print("[Permanent Boombox] Total boomboxes spawned: " .. table.Count(spawnedBoomboxes))
end

-- Near the top of the file, add this flag
local initialLoadComplete = false

-- Remove the existing hooks
hook.Remove("InitPostEntity", "LoadPermanentBoomboxes")
hook.Remove("PostCleanupMap", "ReloadPermanentBoomboxes")

-- Add a single hook for both initial load and map changes
hook.Add("PostCleanupMap", "LoadPermanentBoomboxes", function()
    timer.Simple(5, function()
        if not initialLoadComplete then
            print("[Permanent Boombox] Performing initial load of permanent boomboxes.")
            LoadPermanentBoomboxes()
            initialLoadComplete = true
        else
            print("[Permanent Boombox] Reloading permanent boomboxes after map change.")
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

    print("[Permanent Boombox] Permanence removed for boombox:", ent, "by player:", ply:Nick())
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
    
    print("[Permanent Boombox] Permanent boombox database has been cleared for all maps.")
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
    
    print("[Permanent Boombox] Permanent boomboxes have been reloaded.")
    if IsValid(ply) then
        ply:ChatPrint("Permanent boomboxes have been reloaded.")
    end
end)

_G.LoadPermanentBoomboxes = function()
    LoadPermanentBoomboxes(false)
end

hook.Add("Initialize", "UpdateCurrentMapForPermanentBoomboxes", function()
    currentMap = game.GetMap()
    print("[Permanent Boombox] Current map set to: " .. currentMap)
end)
