--[[
    Radio Addon Shared Utility Functions
    Author: Charles Mills
    Description: This file provides utility functions used by both client and server scripts
                 in the Radio Addon. It includes helper functions for entity checks,
                 permission validations, and other common operations used throughout the addon.
    Date: October 17, 2024
]]--

utils = utils or {}
utils.debug_mode = false

utils.VehicleClasses = {
    ["prop_vehicle_prisoner_pod"] = true,
    ["prop_vehicle_jeep"] = true,
    ["prop_vehicle_airboat"] = true,
    ["gmod_sent_vehicle_fphysics_base"] = true, -- Simfphys
}

utils.SitAnywhereSeats = {
    ["Seat_Airboat"] = true,
    ["Chair_Office2"] = true,
    ["Chair_Plastic"] = true,
    ["Seat_Jeep"] = true,
    ["Chair_Office1"] = true,
    ["Chair_Wood"] = true,
}

--[[
    Function: GetVehicle
    Description: Returns the actual vehicle entity, handling parent relationships
    @param ent (Entity): The entity to check
    @return (Entity): The actual vehicle entity or nil
]]
function utils.GetVehicle(ent)
    if not IsValid(ent) then return end
    
    -- Check parent first (for seats/pods)
    local parent = ent:GetParent()
    ent = IsValid(parent) and parent or ent
    
    -- Return nil if it's a SitAnywhere seat
    if utils.SitAnywhereSeats[ent:GetClass()] then return end
    
    -- Check if it's a valid vehicle
    if utils.VehicleClasses[ent:GetClass()] or 
       ent:IsVehicle() or 
       string.StartWith(ent:GetClass(), "lvs_") or 
       string.StartWith(ent:GetClass(), "ses_") then
        return ent
    end
end

--[[
    Function: isSitAnywhereSeat
    Description: Checks if a vehicle is a "sit anywhere" seat
    @param vehicle (Entity): The vehicle to check
    @return (boolean): True if it's a sit anywhere seat
]]
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    
    -- Quick check for known SitAnywhere classes
    if utils.SitAnywhereSeats[vehicle:GetClass()] then 
        return true 
    end
    
    -- Check networked value (set by server)
    local nwValue = vehicle:GetNWBool("IsSitAnywhereSeat", nil)
    if nwValue ~= nil then
        return nwValue
    end
    
    -- Server-side check for playerdynseat
    if SERVER then
        return vehicle.playerdynseat or false
    end
    
    return false
end

--[[
    Function: getOwner
    Description: Gets the owner of an entity.
    @param ent (Entity): The entity to check.
    @return (Player): The owner of the entity, or nil if no owner.
]]
function utils.getOwner(ent)
    if not IsValid(ent) then return nil end
    return ent:GetNWEntity("Owner")
end

--[[
    Function: canInteractWithBoombox
    Description: Checks if a player can interact with a boombox.
    @param ply (Player): The player attempting to interact.
    @param boombox (Entity): The boombox entity.
    @return (boolean): True if the player can interact, false otherwise.
]]
function utils.canInteractWithBoombox(ply, boombox)
    if not IsValid(ply) or not IsValid(boombox) then return false end
    if ply:IsSuperAdmin() then return true end
    local owner = utils.getOwner(boombox)
    return IsValid(owner) and owner == ply
end

--[[
    Function: GetEntityConfig
    Description: Returns the configuration for an entity based on its class
    @param entity (Entity): The entity to check
    @return (table): The configuration for the entity, or nil if no configuration exists
]]
function utils.GetEntityConfig(entity)
    if not IsValid(entity) then return nil end

    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif utils.GetVehicle(entity) then
        return Config.VehicleRadio
    end
    
    return nil
end

--[[
    Function: setRadioStatus
    Description: Sets the status of a radio entity and updates all relevant states
    @param entity (Entity): The radio entity
    @param status (string): The status to set ("playing", "tuning", "stopped")
    @param stationName (string): The name of the station (optional, defaults to "")
    @param isPlaying (boolean): Whether the radio is playing (optional, defaults based on status)
    @param updateNameOnly (boolean): Only update the station name, keep current status (optional)
]]
function utils.setRadioStatus(entity, status, stationName, isPlaying, updateNameOnly)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()

    -- Clear any existing status update timers
    if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
        timer.Remove("UpdateBoomboxStatus_" .. entIndex)
    end

    stationName = stationName or ""
    
    -- Determine isPlaying if not provided
    if isPlaying == nil then
        isPlaying = (status == "playing" or status == "tuning")
    end

    -- Initialize or update BoomboxStatuses
    if not BoomboxStatuses[entIndex] then
        BoomboxStatuses[entIndex] = {}
    end

    -- Update networked variables and status table atomically
    if not updateNameOnly then
        entity:SetNWString("Status", status)
        entity:SetNWBool("IsPlaying", isPlaying)
        BoomboxStatuses[entIndex].stationStatus = status
    end

    -- Always update station name
    entity:SetNWString("StationName", stationName)
    BoomboxStatuses[entIndex].stationName = stationName

    -- If we're on the server, broadcast the status update
    if SERVER then
        net.Start("UpdateRadioStatus")
            net.WriteEntity(entity)
            net.WriteString(stationName)
            net.WriteBool(isPlaying)
            net.WriteString(updateNameOnly and BoomboxStatuses[entIndex].stationStatus or status)
        net.Broadcast()
    end
end

--[[
    Function: clearRadioStatus
    Description: Cleans up all radio status for an entity
    @param entity (Entity): The radio entity
]]
function utils.clearRadioStatus(entity)
    if not IsValid(entity) then return end
    
    local entIndex = entity:EntIndex()

    -- Clear any existing timers
    if timer.Exists("UpdateBoomboxStatus_" .. entIndex) then
        timer.Remove("UpdateBoomboxStatus_" .. entIndex)
    end

    -- Reset all status
    utils.setRadioStatus(entity, "stopped", "", false)
end

--[[
    Function: IsBoombox
    Description: Checks if an entity is a boombox (regular or golden)
    @param entity (Entity): The entity to check
    @return (boolean): True if the entity is a boombox, false otherwise
]]
function utils.IsBoombox(entity)
    if not IsValid(entity) then return false end
    local class = entity:GetClass()
    return class == "boombox" or class == "golden_boombox"
end

--[[
    Function: canUseRadio
    Description: Checks if a given entity can use radio functionality
    @param entity (Entity): The entity to check
    @return (boolean): True if the entity can use radio, false otherwise
]]
function utils.canUseRadio(entity)
    if not IsValid(entity) then return false end
    
    -- Check if it's a boombox
    if utils.IsBoombox(entity) then return true end
    
    -- Get the actual vehicle entity
    local vehicle = utils.GetVehicle(entity)
    if not vehicle then return false end
    
    -- Check if it's a sit anywhere seat
    if utils.isSitAnywhereSeat(vehicle) then return false end
    
    return true
end

return utils
