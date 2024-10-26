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

--[[
    Function: isSitAnywhereSeat
    Description: Checks if a vehicle is a "sit anywhere" seat.
    @param vehicle (Entity): The vehicle to check.
    @return (boolean): True if it's a sit anywhere seat, false otherwise.
]]
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
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
    Function: getVehicleEntity
    Description: Gets the actual vehicle entity, handling parent relationships.
    @param entity (Entity): The entity to check.
    @return (Entity): The actual vehicle entity to use.
]]
function utils.getVehicleEntity(entity)
    if not IsValid(entity) then return nil end
    if entity:IsVehicle() then
        local parent = entity:GetParent()
        return IsValid(parent) and parent or entity
    end
    return entity
end

--[[
    Function: isValidRadioEntity
    Description: Checks if an entity is valid for radio operations.
    @param entity (Entity): The entity to check.
    @param player (Player): Optional player for permission check.
    @return (boolean): True if the entity is valid for radio use.
]]
function utils.isValidRadioEntity(entity, player)
    if not IsValid(entity) then return false end
    
    if entity:GetClass() == "boombox" then
        return player and utils.canInteractWithBoombox(player, entity) or true
    end
    
    return entity:IsVehicle() and not utils.isSitAnywhereSeat(entity)
end

--[[
    Function: getEntityConfig
    Description: Gets the configuration for a radio entity.
    @param entity (Entity): The entity to get config for.
    @return (table): The configuration table for the entity.
]]
function utils.getEntityConfig(entity)
    if not IsValid(entity) then return nil end

    if entity:GetClass() == "boombox" then
        return Config.Boombox
    end
    return Config.VehicleRadio
end

--[[
    Function: updateEntityStatus
    Description: Updates the status of a radio entity.
    @param entity (Entity): The entity to update.
    @param status (string): The status to set.
    @param stationName (string): Optional station name.
]]
function utils.updateEntityStatus(entity, status, stationName)
    if not IsValid(entity) then return end
    
    entity:SetNWString("Status", status)
    entity:SetNWString("StationName", stationName or "")
    entity:SetNWBool("IsPlaying", status == "playing" or status == "tuning")
end

return utils
