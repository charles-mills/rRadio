-- Network Strings
util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("CarRadioMessage")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")
util.AddNetworkString("UpdateRadioVolume")

-- Active radios and saved boombox states
local ActiveRadios = {}

-- Table to track retry attempts per player
local PlayerRetryAttempts = {}

-- Table to track player cooldowns for net messages
local PlayerCooldowns = {}

-- Global table to store boombox statuses
BoomboxStatuses = BoomboxStatuses or {}

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

    print("[rRadio] Added active radio:", entity, "Station:", stationName)
end

--[[
    Function: RemoveActiveRadio
    Removes a radio from the active radios list.

    Parameters:
    - entity: The entity representing the radio.
]]
local function RemoveActiveRadio(entity)
    ActiveRadios[entity:EntIndex()] = nil
    print("[rRadio] Removed active radio:", entity)
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
                net.WriteString(radio.stationName)
                net.WriteString(radio.url)
                net.WriteFloat(radio.volume)
            net.Send(ply)
            print("[rRadio] Sent active radio to player:", ply:Nick(), "Station:", radio.stationName)
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
        print("[rRadio] PlayCarRadioStation: Invalid entity.")
        return
    end

    -- Ensure that the entity is of a valid class
    local entityClass = entity:GetClass()

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Allow only superadmins to interact
        if not ply:IsSuperAdmin() then
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
        -- Allow only superadmins to interact with vehicle radios
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this vehicle radio.")
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
            net.WriteString(stationName)
            net.WriteString(stationURL)
            net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString(stationName)
        net.Broadcast()
    else
        print("[rRadio] PlayCarRadioStation: Unsupported entity class:", entityClass)
        return
    end
end)

--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for both vehicles and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()

    if not IsValid(entity) then
        print("[rRadio] StopCarRadioStation: Invalid entity.")
        return
    end

    local entityClass = entity:GetClass()

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Allow only superadmins to interact
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
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
        -- Allow only superadmins to interact with vehicle radios
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this vehicle radio.")
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
        print("[rRadio] StopCarRadioStation: Unsupported entity class:", entityClass)
        return
    end
end)

--[[
    Network Receiver: UpdateRadioVolume
    Updates the volume of a boombox.

    Parameters:
    - entity: The boombox entity.
    - volume: The new volume level.
]]
net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    local volume = net.ReadFloat()

    if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
        -- Allow only superadmins to update volume
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this boombox's volume.")
            return
        end

        entity:SetVolume(volume)
        print("[rRadio] Volume updated for entity:", entity, "Volume:", volume)
    else
        print("[rRadio] UpdateRadioVolume: Invalid entity or unsupported class.")
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
    if not IsValid(ply) or not IsValid(ent) then
        print("[rRadio] Invalid player or entity during ownership assignment.")
        return
    end

    if ent.CPPISetOwner then
        ent:CPPISetOwner(ply)  -- Assign the owner using CPPI if available
    end

    -- Set the owner as a networked entity so the client can access it
    ent:SetNWEntity("Owner", ply)
    print("[rRadio] Assigned owner:", ply:Nick(), "to entity:", ent)
end

-- Hook into InitPostEntity to ensure everything is initialized
hook.Add("InitPostEntity", "SetupBoomboxHooks", function()
    timer.Simple(1, function()
        if IsDarkRP() then
            hook.Add("playerBoughtCustomEntity", "AssignBoomboxOwnerInDarkRP", function(ply, entTable, ent, price)
                if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
                    -- No owner assignment since boomboxes should only be usable by superadmins
                    print("[rRadio] Boombox purchased by:", ply:Nick(), "No owner assigned.")
                end
            end)
            print("[rRadio] Set up DarkRP hooks for boombox ownership.")
        end
    end)
end)

-- Toolgun and Physgun Pickup for Boomboxes (remove CPPI dependency for Sandbox)
hook.Add("CanTool", "AllowBoomboxToolgun", function(ply, tr, tool)
    local ent = tr.Entity
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        if ply:IsSuperAdmin() then
            return true
        end

        -- Since no owner is assigned, disallow tool usage for non-superadmins
        print("[rRadio] Non-superadmin attempting to use tools on boombox:", ent)
        return false
    end
end)

hook.Add("PhysgunPickup", "AllowBoomboxPhysgun", function(ply, ent)
    if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
        if ply:IsSuperAdmin() then
            print("[rRadio] Superadmin is Physgun picking up:", ent)
            return true
        end

        -- Since no owner is assigned, disallow physgun pickup for non-superadmins
        print("[rRadio] Non-superadmin attempting to Physgun pickup boombox:", ent)
        return false
    end
end)

-- Clean up player data on disconnect
hook.Add("PlayerDisconnected", "ClearPlayerDataOnDisconnect", function(ply)
    PlayerRetryAttempts[ply] = nil
    PlayerCooldowns[ply] = nil
    print("[rRadio] Cleared player data for disconnected player:", ply:Nick())
end)

