-- Include utility and configuration files
include("misc/utils.lua")
include("misc/config.lua")

-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("ToggleFavoriteCountry")
util.AddNetworkString("SendFavoriteCountries")

-- Declare local variables and functions
local ActiveRadios = {}
local SavedBoomboxStates = SavedBoomboxStates or {}
local debug_mode = false  -- Set to true to enable debug statements

--[[
    Function: AddActiveRadio
    Description: Adds a radio to the active radios list.
    @param entity (Entity): The entity associated with the radio.
    @param stationName (string): The name of the station.
    @param url (string): The URL of the radio stream.
    @param volume (number): The volume level.
]]
local function AddActiveRadio(entity, stationName, url, volume)
    if not IsValid(entity) then
        utils.DebugPrint("Attempted to add a radio to an invalid entity.")
        return
    end

    ActiveRadios[entity:EntIndex()] = {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }

    utils.DebugPrint("Added active radio: Entity " .. tostring(entity:EntIndex()) .. ", Station: " .. stationName)
end

--[[
    Function: RemoveActiveRadio
    Description: Removes a radio from the active radios list.
    @param entity (Entity): The entity associated with the radio.
]]
local function RemoveActiveRadio(entity)
    if ActiveRadios[entity:EntIndex()] then
        ActiveRadios[entity:EntIndex()] = nil
        utils.DebugPrint("Removed active radio: Entity " .. tostring(entity:EntIndex()))
    end
end

--[[
    Function: RestoreBoomboxRadio
    Description: Restores the radio state of a boombox using saved data.
    @param entity (Entity): The boombox entity.
]]
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        utils.DebugPrint("Warning: Could not find PermaProps_ID for entity " .. entity:EntIndex())
        return
    end

    local savedState = SavedBoomboxStates[permaID]
    if savedState then
        entity:SetNWString("CurrentRadioStation", savedState.station)
        entity:SetNWString("StationURL", savedState.url)

        if entity.SetStationName then
            entity:SetStationName(savedState.station)
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        if savedState.isPlaying then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(entity)
            net.WriteString(savedState.url)
            net.WriteFloat(savedState.volume)
            net.Broadcast()

            AddActiveRadio(entity, savedState.station, savedState.url, savedState.volume)
            utils.DebugPrint("Restored and added active radio for PermaProps_ID: " .. permaID)
        else
            utils.DebugPrint("Station is not playing. Not broadcasting PlayCarRadioStation.")
        end
    end
end

--[[
    Function: CreateBoomboxStatesTable
    Description: Creates the boombox_states table in the database if it doesn't exist.
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
    if sql.Query(createTableQuery) == false then
        utils.DebugPrint("Failed to create boombox_states table: " .. sql.LastError())
    else
        utils.DebugPrint("Boombox_states table created or verified successfully")
    end
end

--[[
    Function: SaveBoomboxStateToDatabase
    Description: Saves the state of a boombox to the database.
    @param permaID (number): The PermaProps ID of the boombox.
    @param stationName (string): The name of the station.
    @param url (string): The URL of the radio stream.
    @param isPlaying (boolean): Whether the radio is playing.
    @param volume (number): The volume level.
]]
local function SaveBoomboxStateToDatabase(permaID, stationName, url, isPlaying, volume)
    local query = string.format("REPLACE INTO boombox_states (permaID, station, url, isPlaying, volume) VALUES (%d, %s, %s, %d, %f)",
        permaID, sql.SQLStr(stationName), sql.SQLStr(url), isPlaying and 1 or 0, volume)
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to save boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Saved boombox state to database: PermaID = " .. permaID)
    end
end

--[[
    Function: RemoveBoomboxStateFromDatabase
    Description: Removes the state of a boombox from the database.
    @param permaID (number): The PermaProps ID of the boombox.
]]
local function RemoveBoomboxStateFromDatabase(permaID)
    local query = string.format("DELETE FROM boombox_states WHERE permaID = %d", permaID)
    if sql.Query(query) == false then
        utils.DebugPrint("Failed to remove boombox state: " .. sql.LastError())
    else
        utils.DebugPrint("Removed boombox state from database: PermaID = " .. permaID)
    end
end

--[[
    Function: LoadBoomboxStatesFromDatabase
    Description: Loads boombox states from the database into SavedBoomboxStates table.
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
            utils.DebugPrint("Loaded boombox state from database: PermaID = " .. permaID)
        end
    else
        SavedBoomboxStates = {}
        utils.DebugPrint("No saved boombox states found in the database.")
    end
end

--[[
    Function: SendActiveRadiosToPlayer
    Description: Sends information about active radios to a player.
    @param ply (Player): The player to send the information to.
]]
local function SendActiveRadiosToPlayer(ply)
    utils.DebugPrint("Sending active radios to player: " .. ply:Nick())
    if next(ActiveRadios) == nil then
        utils.DebugPrint("No active radios found. Retrying in 5 seconds.")
        timer.Simple(5, function()
            if IsValid(ply) then
                SendActiveRadiosToPlayer(ply)
            end
        end)
        return
    end

    for _, radio in pairs(ActiveRadios) do
        if IsValid(radio.entity) then
            net.Start("PlayCarRadioStation")
            net.WriteEntity(radio.entity)
            net.WriteString(radio.url)
            net.WriteFloat(radio.volume)
            net.Send(ply)
        else
            utils.DebugPrint("Invalid radio entity detected in SendActiveRadiosToPlayer.")
        end
    end
end

--[[
    Function: IsDarkRP
    Description: Checks if the current gamemode is DarkRP or derived from it.
    @return (boolean): True if DarkRP or derived, false otherwise.
]]
local function IsDarkRP()
    return DarkRP ~= nil and DarkRP.getPhrase ~= nil
end

--[[
    Function: AssignOwner
    Description: Assigns ownership of an entity to a player using CPPI.
    @param ply (Player): The player to assign as the owner.
    @param ent (Entity): The entity to assign ownership of.
]]
local function AssignOwner(ply, ent)
    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)
    end
    ent:SetNWEntity("Owner", ply)
end

--[[
    Function: InitializeBoomboxOwnershipHooks
    Description: Sets up hooks for assigning boombox ownership based on the gamemode.
]]
local function InitializeBoomboxOwnershipHooks()
    timer.Simple(1, function()
        if IsDarkRP() then
            print("[CarRadio] DarkRP or DerivedRP detected. Setting up CPPI-based ownership hooks.")

            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and utils.isBoombox(entity) then
                    AssignOwner(ply, ent)
                end
            end)
        else
            print("[CarRadio] Non-DarkRP gamemode detected. Using sandbox-compatible ownership hooks.")
        end
    end)
end

--[[
    Function: CleanupActiveRadioOnEntityRemove
    Description: Cleans up active radios when an entity is removed.
    @param entity (Entity): The entity being removed.
]]
local function CleanupActiveRadioOnEntityRemove(entity)
    local mainVehicle = entity:GetParent() or entity
    if not IsValid(mainVehicle) then
        mainVehicle = entity
    end

    if ActiveRadios[mainVehicle:EntIndex()] then
        RemoveActiveRadio(mainVehicle)
    end
end

--[[
    Function: HandlePlayCarRadioStation
    Description: Handles the PlayCarRadioStation network message.
    @param len (number): The length of the message.
    @param ply (Player): The player who sent the message.
]]
local function HandlePlayCarRadioStation(len, ply)
    local entity = net.ReadEntity()
    local stationName = net.ReadString()
    local url = net.ReadString()
    local volume = math.Clamp(net.ReadFloat(), 0, 1)

    if not IsValid(entity) then
        utils.DebugPrint("Invalid entity received in PlayCarRadioStation.")
        return
    end

    utils.DebugPrint("PlayCarRadioStation received: Entity " .. entity:EntIndex())

    if utils.isBoombox(entity) then
        local permaID = entity.PermaProps_ID
        if permaID then
            SavedBoomboxStates[permaID] = {
                station = stationName,
                url = url,
                isPlaying = true,
                volume = volume
            }
            SaveBoomboxStateToDatabase(permaID, stationName, url, true, volume)
        end

        if entity.SetVolume then
            entity:SetVolume(volume)
        else
            utils.DebugPrint("Warning: SetVolume function not found for entity: " .. entity:EntIndex())
        end

        if entity.SetStationName then
            entity:SetStationName(stationName)
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
        end

        AddActiveRadio(entity, stationName, url, volume)

        net.Start("PlayCarRadioStation")
        net.WriteEntity(entity)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(entity)
        net.WriteString(stationName)
        net.Broadcast()

    elseif entity:IsVehicle() then
        local mainVehicle = entity:GetParent() or entity
        if not IsValid(mainVehicle) then
            mainVehicle = entity
        end

        if ActiveRadios[mainVehicle:EntIndex()] then
            net.Start("StopCarRadioStation")
            net.WriteEntity(mainVehicle)
            net.Broadcast()
            RemoveActiveRadio(mainVehicle)
        end

        AddActiveRadio(mainVehicle, stationName, url, volume)

        net.Start("PlayCarRadioStation")
        net.WriteEntity(mainVehicle)
        net.WriteString(url)
        net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString(stationName)
        net.Broadcast()
    end
end

--[[
    Function: HandleStopCarRadioStation
    Description: Handles the StopCarRadioStation network message.
    @param len (number): The length of the message.
    @param ply (Player): The player who sent the message.
]]
local function HandleStopCarRadioStation(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then return end

    if utils.isBoombox(entity) then
        local permaID = entity.PermaProps_ID
        if permaID and SavedBoomboxStates[permaID] then
            SavedBoomboxStates[permaID].isPlaying = false
            SaveBoomboxStateToDatabase(permaID, SavedBoomboxStates[permaID].station, SavedBoomboxStates[permaID].url, false, SavedBoomboxStates[permaID].volume)
        end

        if entity.SetStationName then
            entity:SetStationName("")
        else
            utils.DebugPrint("Warning: SetStationName function not found for entity: " .. entity:EntIndex())
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
        local mainVehicle = entity:GetParent() or entity
        if not IsValid(mainVehicle) then
            mainVehicle = entity
        end

        RemoveActiveRadio(mainVehicle)

        net.Start("StopCarRadioStation")
        net.WriteEntity(mainVehicle)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
        net.WriteEntity(mainVehicle)
        net.WriteString("")
        net.Broadcast()
    end
end

--[[
    Function: Initialize
    Description: Initializes the server-side script.
]]
local function Initialize()
    utils.DebugPrint("Attempting to load Boombox States from the database")
    LoadBoomboxStatesFromDatabase()
    utils.DebugPrint("Finished restoring active radios")
end

--[[
    Function: RemoveAllBoomboxStates
    Description: Clears all boombox states from the database.
]]
local function RemoveAllBoomboxStates(ply, cmd, args)
    if not ply or ply:IsAdmin() then
        local result = sql.Query("DELETE FROM boombox_states")
        if result == false then
            print("[CarRadio] Failed to clear boombox states: " .. sql.LastError())
        else
            print("[CarRadio] All boombox states cleared successfully.")
            SavedBoomboxStates = {}
            ActiveRadios = {}
        end
    else
        ply:ChatPrint("You do not have permission to run this command.")
    end
end

--[[
    Hook: OnEntityCreated
    Description: Restores boombox radio state when a boombox entity is created.
]]
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.5, function()
        if IsValid(entity) and utils.isBoombox(entity) then
            RestoreBoomboxRadio(entity)
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

--[[
    Hook: PlayerEnteredVehicle
    Description: Sends a car radio message when a player enters a vehicle.
]]
hook.Add("PlayerEnteredVehicle", "CarRadioMessageOnEnter", function(ply, vehicle, role)
    if vehicle.playerdynseat then
        return  -- Do not send the message if it's a sit anywhere seat
    end

    net.Start("CarRadioMessage")
    net.Send(ply)
end)

--[[
    Hook: PlayerInitialSpawn
    Description: Sends active radios to a player when they join.
]]
hook.Add("PlayerInitialSpawn", "SendActiveRadiosOnJoin", function(ply)
    timer.Simple(3, function()
        if IsValid(ply) then
            SendActiveRadiosToPlayer(ply)
        end
    end)
end)

--[[
    Hook: EntityRemoved
    Description: Cleans up active radios when an entity is removed.
]]
hook.Add("EntityRemoved", "CleanupActiveRadioOnEntityRemove", CleanupActiveRadioOnEntityRemove)

--[[
    Hook: Initialize
    Description: Creates the boombox_states table in the database.
]]
hook.Add("Initialize", "CreateBoomboxStatesTable", CreateBoomboxStatesTable)

--[[
    Hook: Initialize
    Description: Loads boombox states from the database on server start.
]]
hook.Add("Initialize", "LoadBoomboxStatesOnStartup", Initialize)

--[[
    Hook: Initialize
    Description: Sets up boombox ownership hooks after entities are initialized.
]]
hook.Add("InitPostEntity", "SetupBoomboxHooks", InitializeBoomboxOwnershipHooks)

--[[
    Hook: CanTool
    Description: Allows the owner to use tools on the boombox.
]]
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true
        end
    end
end)

--[[
    Hook: PhysgunPickup
    Description: Allows the owner to pick up the boombox with the physgun.
]]
hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and utils.isBoombox(ent) then
        local owner = ent:GetNWEntity("Owner")
        if owner == ply then
            return true
        end
    end
end)

--[[
    Network Receiver: PlayCarRadioStation
    Description: Handles the PlayCarRadioStation network message.
]]
net.Receive("PlayCarRadioStation", HandlePlayCarRadioStation)

--[[
    Network Receiver: StopCarRadioStation
    Description: Handles the StopCarRadioStation network message.
]]
net.Receive("StopCarRadioStation", HandleStopCarRadioStation)

--[[
    Console Command: rradio_remove_all
    Description: Clears all boombox states from the database.
]]
concommand.Add("rradio_remove_all", RemoveAllBoomboxStates)

--[[
    PermaProps Support: Handling boombox entities.
]]
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
            net.WriteString(savedState.url)
            net.WriteFloat(savedState.volume)
            net.Broadcast()

            AddActiveRadio(ent, savedState.station, savedState.url, savedState.volume)
        end
    end
end

-- Duplicate handling for golden_boombox
PermaProps.SpecialENTSSpawn["golden_boombox"] = PermaProps.SpecialENTSSpawn["boombox"]