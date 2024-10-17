print("[rRadio] Initializing server-side core")

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
local SavePermanentBoombox, RemovePermanentBoombox, LoadPermanentBoomboxes

include("sv_permanent.lua")

SavePermanentBoombox = _G.SavePermanentBoombox
RemovePermanentBoombox = _G.RemovePermanentBoombox
LoadPermanentBoomboxes = _G.LoadPermanentBoomboxes

local LatestVolumeUpdates = {}
local VolumeUpdateTimers = {}

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
    Function: IsLVSVehicle
    Checks if the given entity is an LVS vehicle or a seat in an LVS vehicle.
    Parameters:
    - entity: The entity to check.
    Returns:
    - The LVS vehicle entity if it's an LVS vehicle or seat, nil otherwise.
]]
local function IsLVSVehicle(entity)
    if not IsValid(entity) then return nil end
    
    local parent = entity:GetParent()
    if IsValid(parent) and string.StartWith(parent:GetClass(), "lvs_") then
        return parent
    elseif string.StartWith(entity:GetClass(), "lvs_") then
        return entity
    end
    
    return nil
end

local function GetVehicleEntity(entity)
    if IsValid(entity) and entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

--[[
    Network Receiver: PlayCarRadioStation
    Handles playing a radio station for vehicles, LVS vehicles, and boomboxes.
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
    entity = GetVehicleEntity(entity)  -- Use the new function
    local stationName = net.ReadString()
    local stationURL = net.ReadString()
    local volume = net.ReadFloat()

    if not IsValid(entity) then
        print("[rRadio] PlayCarRadioStation: Invalid entity.")
        return
    end

    -- Ensure that the entity is of a valid class
    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Allow only superadmins to interact with boomboxes
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

        -- Ensure the entity has a permanent ID if it's permanent
        if entity.IsPermanent and entity:GetNWString("PermanentID", "") == "" then
            entity:SetNWString("PermanentID", os.time() .. "_" .. math.random(1000, 9999))
        end

        -- Set networked variables
        entity:SetNWString("StationName", stationName)
        entity:SetNWString("StationURL", stationURL)
        entity:SetNWFloat("Volume", volume)

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

        -- Save to database if permanent
        if entity.IsPermanent and SavePermanentBoombox then
            SavePermanentBoombox(entity)
        end

    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity

        -- Validate station name and URL
        if #stationName > 100 then
            ply:ChatPrint("Station name is too long.")
            return
        end

        if #stationURL > 500 then
            ply:ChatPrint("URL is too long.")
            return
        end

        if ActiveRadios[radioEntity:EntIndex()] then
            net.Start("StopCarRadioStation")
                net.WriteEntity(radioEntity)
            net.Broadcast()
            RemoveActiveRadio(radioEntity)
        end

        AddActiveRadio(radioEntity, stationName, stationURL, volume)

        net.Start("PlayCarRadioStation")
            net.WriteEntity(radioEntity)
            net.WriteString(stationName)
            net.WriteString(stationURL)
            net.WriteFloat(volume)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString(stationName)
        net.Broadcast()
    else
        print("[rRadio] PlayCarRadioStation: Unsupported entity class:", entityClass)
        return
    end
end)

--[[
    Network Receiver: StopCarRadioStation
    Handles stopping a radio station for vehicles, LVS vehicles, and boomboxes.
]]
net.Receive("StopCarRadioStation", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)  -- Use the new function

    if not IsValid(entity) then
        print("[rRadio] StopCarRadioStation: Invalid entity.")
        return
    end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)

    if entityClass == "golden_boombox" or entityClass == "boombox" then
        -- Allow only superadmins to interact with boomboxes
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("You do not have permission to control this boombox.")
            return
        end

        -- Don't clear the PermanentID when stopping the radio
        entity:SetNWString("StationName", "")
        entity:SetNWString("StationURL", "")
        entity:SetNWFloat("Volume", 0)

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

        -- Save to database if permanent
        if entity.IsPermanent and SavePermanentBoombox then
            SavePermanentBoombox(entity)
        end

    elseif entity:IsVehicle() or lvsVehicle then
        local radioEntity = lvsVehicle or entity

        RemoveActiveRadio(radioEntity)

        net.Start("StopCarRadioStation")
            net.WriteEntity(radioEntity)
        net.Broadcast()

        net.Start("UpdateRadioStatus")
            net.WriteEntity(radioEntity)
            net.WriteString("")
        net.Broadcast()
    else
        print("[rRadio] StopCarRadioStation: Unsupported entity class:", entityClass)
        return
    end
end)

--[[
    Network Receiver: UpdateRadioVolume
    Updates the volume of a boombox or vehicle radio with a debounce system.
    Parameters:
    - entity: The boombox or vehicle entity.
    - volume: The new volume level.
]]
net.Receive("UpdateRadioVolume", function(len, ply)
    local entity = net.ReadEntity()
    entity = GetVehicleEntity(entity)  -- Use the new function
    local volume = net.ReadFloat()

    if not IsValid(entity) then
        print("[rRadio] UpdateRadioVolume: Invalid entity.")
        return
    end

    local entityClass = entity:GetClass()
    local lvsVehicle = IsLVSVehicle(entity)
    local radioEntity = lvsVehicle or entity
    local entIndex = radioEntity:EntIndex()

    -- Store the latest volume update request
    LatestVolumeUpdates[entIndex] = {
        ply = ply,
        volume = volume,
        time = CurTime()
    }

    -- Function to process the volume update
    local function ProcessVolumeUpdate()
        local latestUpdate = LatestVolumeUpdates[entIndex]
        if not latestUpdate then return end

        local updatePly = latestUpdate.ply
        local updateVolume = latestUpdate.volume

        if entityClass == "boombox" or entityClass == "golden_boombox" then
            -- Allow only superadmins to update boombox volume
            if not updatePly:IsSuperAdmin() then
                updatePly:ChatPrint("You do not have permission to control this boombox's volume.")
                return
            end

            radioEntity:SetNWFloat("Volume", updateVolume)
            print("[rRadio] Volume updated for boombox:", radioEntity, "Volume:", updateVolume)

            -- Save to database if permanent
            if radioEntity.IsPermanent and SavePermanentBoombox then
                SavePermanentBoombox(radioEntity)
            end
        elseif entity:IsVehicle() or lvsVehicle then
            -- Update the volume in the ActiveRadios table
            if ActiveRadios[entIndex] then
                ActiveRadios[entIndex].volume = updateVolume
                print("[rRadio] Volume updated for vehicle radio:", radioEntity, "Volume:", updateVolume)

                -- Broadcast the volume change to all clients
                net.Start("UpdateRadioVolume")
                    net.WriteEntity(radioEntity)
                    net.WriteFloat(updateVolume)
                net.Broadcast()
            else
                print("[rRadio] UpdateRadioVolume: No active radio found for vehicle:", radioEntity)
            end
        else
            print("[rRadio] UpdateRadioVolume: Unsupported entity class:", entityClass)
        end

        -- Clear the latest update after processing
        LatestVolumeUpdates[entIndex] = nil
    end

    -- Cancel any existing timer for this entity
    if VolumeUpdateTimers[entIndex] then
        timer.Remove(VolumeUpdateTimers[entIndex])
    end

    -- Set a new timer to process the update after a short delay
    local timerName = "VolumeUpdate_" .. entIndex
    timer.Create(timerName, 0.1, 1, ProcessVolumeUpdate)
    VolumeUpdateTimers[entIndex] = timerName
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

hook.Add("InitPostEntity", "LoadPermanentBoomboxesOnServerStart", function()
    timer.Simple(0.5, function()
        if LoadPermanentBoomboxes then
            LoadPermanentBoomboxes()
        else
            print("[rRadio] Error: LoadPermanentBoomboxes function not found")
        end
    end)
end)

hook.Add("EntityRemoved", "CleanupVolumeUpdateData", function(entity)
    local entIndex = entity:EntIndex()
    LatestVolumeUpdates[entIndex] = nil
    if VolumeUpdateTimers[entIndex] then
        timer.Remove(VolumeUpdateTimers[entIndex])
        VolumeUpdateTimers[entIndex] = nil
    end
end)

hook.Add("PlayerDisconnected", "CleanupPlayerVolumeUpdateData", function(ply)
    for entIndex, updateData in pairs(LatestVolumeUpdates) do
        if updateData.ply == ply then
            LatestVolumeUpdates[entIndex] = nil
            if VolumeUpdateTimers[entIndex] then
                timer.Remove(VolumeUpdateTimers[entIndex])
                VolumeUpdateTimers[entIndex] = nil
            end
        end
    end
end)

_G.AddActiveRadio = AddActiveRadio
