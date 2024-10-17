-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")

-- Active radios and saved boombox states
local ActiveRadios = {}
local SavedBoomboxStates = {}

-- Table to track retry attempts per player
local PlayerRetryAttempts = {}

-- Table to track player cooldowns for net messages
local PlayerCooldowns = {}

--[[
    Function: AddActiveRadio
    Adds a radio to the active radios list.

    Parameters:
    - entity: The entity representing the radio.
    - stationName: The name of the station.
    - url: The URL of the station.
    - volume: The volume level.
]]
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        return
    end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }
end

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.

    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
end

--[[
    Function: RestoreBoomboxRadio
    Restores the boombox radio state using saved data.

    Parameters:
    - entity: The boombox entity to restore.
]]
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        entity:SetNWString("CurrentRadioStation", savedState.station)
        entity:SetNWString("StationURL", savedState.url)

        if entity.SetStationName then
            entity:SetStationName(savedState.station)
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(savedState.station)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
            net.Broadcast()
            AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
        end
    end
end

-- Hook to restore boombox radio state on entity creation
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

--[[
    Function: CreateBoomboxStatesTable
    Creates the boombox_states table in the SQLite database if it doesn't exist.
]]
local function CreateBoomboxStatesTable()
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

hook.Add("Initialize", "CreateBoomboxStatesTable", CreateBoomboxStatesTable)

--[[
    Function: SaveBoomboxStateToDatabase
    Saves the boombox state to the database.

    Parameters:
    - permaID: The unique PermaProps ID of the boombox.
    - stationName: The name of the station.
    - url: The URL of the station.
    - isPlaying: Boolean indicating if the boombox is playing.
    - volume: The volume level.
]]
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    -- Ensure inputs are valid
    permaID = tonumber(permaID)
    stationName = tostring(stationName or "")
    url = tostring(url or "")
    isPlaying = isPlaying and 1 or 0
    volume = tonumber(volume) or 0

    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying, volume)
    sql.Query(query)
end

--[[
    Function: RemoveBoomboxStateFromDatabase
    Removes the boombox state from the database.

    Parameters:
    - permaID: The unique PermaProps ID of the boombox.
]]
local function RemoveBoomboxStateFromDatabase(permaID)
    permaID = tonumber(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    sql.Query(query)
end

--[[
    Function: LoadBoomboxStatesFromDatabase
    Loads boombox states from the database into the SavedBoomboxStates table.
]]
local function LoadBoomboxStatesFromDatabase()
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

--[[
    Function: SendActiveRadiosToPlayer
    Sends active radios to a specific player with limited retries.

    Parameters:
    - ply: The player to send active radios to.
]]
local function SendActiveRadiosToPlayer(ply)
    if not IsValid(ply) then
        return
    end

    -- Initialize attempt count if not present
    if not PlayerRetryAttempts[ply] then
        PlayerRetryAttempts[ply] = 1
    end

    local attempt = PlayerRetryAttempts[ply]

    if next(ActiveRadios) == nil then
        if attempt >= 3 then
            PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            return
        end

        -- Increment the attempt count
        PlayerRetryAttempts[ply] = attempt + 1

        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            else
                PlayerRetryAttempts[ply] = nil  -- Reset attempt count
            end
        end)
        return
    end

    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(radio.entity)
                net.WriteString(radio.stationName) -- Include stationName
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
        end
    end

    -- Reset attempt count after successful send
    PlayerRetryAttempts[ply] = nil
end

hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

-- Add the hooks to set the networked variable
hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    if vehicle.playerdynseat then
        vehicle:SetNWBool("IsSitAnywhereSeat", true)
    else
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        vehicle:SetNWBool("IsSitAnywhereSeat", false)
    end
end)

hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    if vehicle.playerdynseat then
        return  -- Do not send the message if it's a sit anywhere seat
    end

    net.Start("CarRadioMessage")
    net.Send(ply)
end)

--[[
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station for both vehicles and boomboxes.
]]
net.Receive("PlayCarRadioStation", function(len, ply)
    local currentTime = CurTime()
    local lastRequestTime = PlayerCooldowns[ply] or 0
    if currentTime - lastRequestTime < 0.25 then -- 0.25 second cooldown
        ply:ChatPrint("You are changing stations too quickly.")
        return
    end
    PlayerCooldowns[ply] = currentTime

    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then
        return
    end

    -- Ensure that the entity is of a valid class
    local entityClass = entity:GetClass()

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Check ownership
        local owner = entity:GetNWEntity("Owner")
        if owner ~= ply and not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        -- Validate station name and URL
        if #stationName > 100 then
            ply:ChatPrint("Station name is too long.")
            return
        end

        if #stationURL > 500 then
            ply:ChatPrint("URL is too long.")
            return
        end

        local permaID = entity.PermaProps_ID
        if permaID then
            SavedBoomboxStates[permaID] = {
                station = stationName,
                url = stationURL,
                isPlaying = true,
                volume = volume
            }
            SaveBoomboxStateToDatabase(permaID, stationName, stationURL, true, volume)
        end

        if entity.SetVolume then
            entity:SetVolume(volume)
        end

        if entity.SetStationName then
            entity:SetStationName(stationName)
        end

        AddActiveRadio(entity, stationName, stationURL, volume)

        net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(stationName)
            net.WriteString(stationURL)
            net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString(stationName)
        net.Broadcast()
    elseif entity:IsVehicle() then
        entity = entity:GetParent() or entity

        if not IsValid(entity) or not entity:IsVehicle() then
            return
        end

        -- Validate station name and URL
        if #stationName > 100 then
            ply:ChatPrint("Station name is too long.")
            return
        end

        if #stationURL > 500 then
            ply:ChatPrint("URL is too long.")
            return
        end

        if ActiveRadios[entity:EntIndex()] then
            net.Start("StopCarRadioStation")
                net.WriteEntity(entity)
            net.Broadcast()
            RemoveActiveRadio(entity)
        end

        AddActiveRadio(entity, stationName, stationURL, volume)

        net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(stationName) -- Include stationName
            net.WriteString(stationURL)
            net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString(stationName)
        net.Broadcast()
    else
        return
    end
end)

--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for both vehicles and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    local entityClass = entity:GetClass()

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        local owner = entity:GetNWEntity("Owner")
        if owner ~= ply and not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        local permaID = entity.PermaProps_ID
        if permaID and SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end

        if entity.SetStationName then
            entity:SetStationName("")
        end

        RemoveActiveRadio(entity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
        net.Broadcast()

    elseif entity:IsVehicle() then
        entity = entity:GetParent() or entity

        if not IsValid(entity) or not entity:IsVehicle() then
            return
        end

        RemoveActiveRadio(entity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(entity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString("")
        net.Broadcast()
    else
        -- Invalid entity
        return
    end
end)

net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()

    if IsValid(entity) and entity:GetClass() == "boombox" then
        entity:SetVolume(volume)
    end
end)

-- Cleanup active radios when an entity is removed
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", function(entity)
    local mainEntity = entity:GetParent() or entity

    if ActiveRadios[mainEntity:EntIndex()] then
        RemoveActiveRadio(mainEntity)
    end
end)

--[[
    Function: IsDarkRP
    Utility function to detect if the gamemode is DarkRP or DerivedRP.

    Returns:
    - Boolean indicating if DarkRP is detected.
]]
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

--[[
    Function: AssignOwner
    Assigns ownership of an entity using CPPI.

    Parameters:
    - ply: The player to assign as the owner.
    - ent: The entity to assign ownership to.
]]
local function AssignOwner(ply, ent)
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)  -- Assign the owner using CPPI
    end

    -- Set the owner as a networked entity so the client can access it
    ent:SetNWEntity("Owner", ply)
end

-- Hook into InitPostEntity to ensure everything is initialized
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
                    AssignOwner(ply, ent)
                end
            end)
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true  -- Allow owner to use tools on the boombox
        else
            return false -- Disallow others
        end
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true  -- Allow owner to physgun the boombox
        else
            return false -- Disallow others
        end
    end
end)

-- PermaProps integration for boomboxes
if not PermaProps then PermaProps = {} end
PermaProps.SpecialENTSSpawn = PermaProps.SpecialENTSSpawn or {}
PermaProps.SpecialENTSSpawn["boombox"] = function(ent, data)
    local permaID = ent.PermaProps_ID
    if not permaID then return end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        ent:SetNWString("CurrentRadioStation", savedState.station)
        ent:SetNWString("StationURL", savedState.url)

        if ent.SetStationName then
            ent:SetStationName(savedState.station)
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
                net.WriteEntity(ent)
                net.WriteString(savedState.station) -- Corrected variable
                net.WriteString(savedState.url)     -- Corrected variable
                net.WriteFloat(savedState.volume)   -- Corrected variable
            net.Broadcast()

            AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
        end
    end
end

PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]

hook.Add("Initialize", "LoadBoomboxStatesOnStartup", function()
    LoadBoomboxStatesFromDatabase()
end)

-- Clear all boombox states from the database (Admin Only)
concommand.Add("rradio_remove_all", function(ply, cmd, args)
    if not ply or ply:IsAdmin() then
        sql.Query("DELETE FROM boombox_states")
        SavedBoomboxStates = {}
        ActiveRadios = {}
        ply:ChatPrint("All boombox states have been cleared.")
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end)

-- Clean up player data on disconnect
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
end)

-- PermaProps compatibility
local function HasPermaPropsPermission(ply, name)
    if not PermaProps or not PermaProps.Permissions or not PermaProps.Permissions[ply:GetUserGroup()] then 
        return false 
    end

    local userGroup = ply:GetUserGroup()
    local permissions = PermaProps.Permissions[userGroup]

    if permissions.Custom == false and permissions.Inherits and PermaProps.Permissions[permissions.Inherits] then
        return PermaProps.Permissions[permissions.Inherits][name]
    end

    return permissions[name]
end

-- CanTool hook for PermaProps
hook.Add("CanTool", "BoomboxPermaPropsTool", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and ent.PermaProps and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        if tool == "permaprops" then
            return true
        end
        return HasPermaPropsPermission(ply, "Tool") or ply:IsSuperAdmin()
    end
end)

-- CanProperty hook for PermaProps
hook.Add("CanProperty", "BoomboxPermaPropsProperty", function(ply, property, ent)
    if IsValid(ent) and ent.PermaProps and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        return HasPermaPropsPermission(ply, "Property") or ply:IsSuperAdmin()
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgunPermaProps", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        local owner = ent:GetNWEntity("Owner")
        if ent.PermaProps then
            return HasPermaPropsPermission(ply, "Physgun") or ply:IsSuperAdmin()
        elseif owner == ply or ply:IsSuperAdmin() then
            return true
        else
            return false
        end
    end
end)
