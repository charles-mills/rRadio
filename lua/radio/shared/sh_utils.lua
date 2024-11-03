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
    ["wac_hc_base"] = true,                     -- WAC Aircraft
    ["wac_pl_base"] = true,                     -- WAC Aircraft
    ["lunasflightschool_basescript"] = true,    -- LFS
    ["sent_sakarias_car_base"] = true,          -- SCars
    ["lvs_base_wheelvehicle"] = true,          -- LVS Wheeled Vehicles
    ["lvs_base_trackvehicle"] = true,          -- LVS Tracked Vehicles
    ["lvs_base_airplane"] = true,              -- LVS Aircraft
    ["lvs_base_helicopter"] = true,            -- LVS Helicopters
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
    
    -- Special handling for LVS seats
    if IsValid(parent) then
        -- Check if parent is an LVS vehicle
        if parent.LVS or string.StartWith(parent:GetClass(), "lvs_") then
            return parent
        end
        ent = parent
    end
    
    -- Return nil if it's a SitAnywhere seat (but not if it's part of an LVS vehicle)
    if utils.SitAnywhereSeats[ent:GetClass()] and not (ent:GetParent().LVS or (IsValid(ent:GetParent()) and string.StartWith(ent:GetParent():GetClass(), "lvs_"))) then 
        return 
    end
    
    -- Check if entity itself is an LVS vehicle
    if ent.LVS or string.StartWith(ent:GetClass(), "lvs_") then
        return ent
    end
    
    -- Check various vehicle frameworks
    if utils.VehicleClasses[ent:GetClass()] or 
       ent:IsVehicle() or 
       string.StartWith(ent:GetClass(), "ses_") or  -- SligWolf
       (ent.isWacAircraft == true) or              -- WAC
       (ent.LFS == true) or                        -- LFS
       (ent.IsScar == true) then                   -- SCars
        return ent
    end
    
    -- Check for additional framework-specific properties
    if ent.IsVehicle and ent:IsVehicle() then return ent end
    if ent.IsSimfphyscar then return ent end
    if ent.ForceDefaultProperties then return ent end -- Advanced Driver Seat
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
    
    -- Check for common SitAnywhere properties
    if vehicle.IsSitAnywhere or vehicle.SitAnywhere then
        return true
    end
    
    -- Check networked value (set by server)
    if vehicle:GetNWBool("IsSitAnywhereSeat", false) then
        return true
    end
    
    -- Check if it's a seat without a valid vehicle parent
    if vehicle:GetClass() == "prop_vehicle_prisoner_pod" then
        local parent = vehicle:GetParent()
        if not IsValid(parent) or not utils.canUseRadio(parent) then
            return true
        end
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
    
    -- Get actual vehicle entity
    local vehicle = utils.GetVehicle(entity)
    if vehicle then
        -- Check if vehicle has radio disabled
        if vehicle.RadioDisabled then return false end
        
        -- Check for framework-specific properties
        if vehicle.isWacAircraft then return true end
        if vehicle.LFS then return true end
        if vehicle.IsScar then return true end
        if vehicle.IsSimfphyscar then return true end
        if vehicle.LVS then return true end
        if string.StartWith(vehicle:GetClass(), "lvs_") then return true end
        
        -- Default vehicle check
        return true
    end
    
    -- Check if it's a boombox
    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        return true
    end
    
    return false
end

--[[
    Function: isPlayerInVehicle
    Description: Checks if a player is in a specific vehicle or any of its seats
    @param player (Player): The player to check
    @param vehicle (Entity): The vehicle to check
    @return (boolean): True if the player is in the vehicle or any of its seats
]]
function utils.isPlayerInVehicle(player, vehicle)
    if not IsValid(player) or not IsValid(vehicle) then return false end
    
    -- Get the actual vehicle entity
    vehicle = utils.GetVehicle(vehicle) or vehicle
    if not vehicle then return false end
    
    -- Check if player is the driver
    local driver = utils.GetVehicleDriver(vehicle)
    if driver == player then return true end
    
    -- Check if player is in any of the vehicle's seats
    if vehicle:IsVehicle() then
        for _, seat in pairs(ents.FindByClass("prop_vehicle_prisoner_pod")) do
            if IsValid(seat) and seat:GetParent() == vehicle and seat:GetDriver() == player then
                return true
            end
        end
    end
    
    return false
end

--[[
    Function: playErrorSound
    Description: Plays an error sound for the client
    @param type (string): The type of error ("connection", "permission", etc.)
]]
function utils.playErrorSound(type)
    if CLIENT then
        if type == "connection" then
            surface.PlaySound("buttons/button10.wav") -- Error/failure sound
        elseif type == "permission" then
            surface.PlaySound("buttons/button11.wav") -- Denied sound
        else
            surface.PlaySound("buttons/button8.wav") -- Generic error sound
        end
    end
end

--[[
    Function: truncateStationName
    Truncates a station name to a maximum length and adds ellipsis if needed.
    This is for display purposes only and doesn't modify the actual station data.

    Parameters:
    - name: The station name to truncate
    - maxLength: (optional) Maximum length before truncation, defaults to 15

    Returns:
    - The truncated name with ellipsis if needed
]]
function utils.truncateStationName(name, maxLength)
    maxLength = maxLength or Config.MaxStationNameLength
    if string.len(name) <= maxLength then
        return name
    end
    return string.sub(name, 1, maxLength) .. "..."
end

--[[
    Function: GetVehicleDriver
    Description: Gets the driver of a vehicle across different frameworks
    @param vehicle (Entity): The vehicle to check
    @return (Player): The driver of the vehicle, or nil if no driver
]]
function utils.GetVehicleDriver(vehicle)
    if not IsValid(vehicle) then return end
    
    -- LVS vehicles
    if vehicle.LVS or string.StartWith(vehicle:GetClass(), "lvs_") then
        if vehicle.GetDriver then
            return vehicle:GetDriver()
        end
        -- Some LVS vehicles use different methods
        if vehicle.GetAIDriver then
            return vehicle:GetAIDriver()
        end
    end
    
    -- WAC Aircraft
    if vehicle.isWacAircraft and vehicle.seats and vehicle.seats[1] then
        return vehicle.seats[1]:GetDriver()
    end
    
    -- LFS
    if vehicle.LFS and vehicle.GetDriver then
        return vehicle:GetDriver()
    end
    
    -- SCars
    if vehicle.IsScar and vehicle.Driver then
        return vehicle.Driver
    end
    
    -- Default/Simfphys/Other
    if vehicle.GetDriver then
        return vehicle:GetDriver()
    end
    
    return nil
end

--[[
    Function: DebugPrint
    Description: Prints debug information if the radio_debug convar is enabled
    @param ...: The arguments to print
]]
function utils.DebugPrint(...)
    if GetConVar("radio_debug"):GetBool() then
        print("[rRadio Debug]", ...)
    end
end

return utils
