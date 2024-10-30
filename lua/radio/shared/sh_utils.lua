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

return utils
