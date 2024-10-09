--[[ 
    rRadio Addon for Garry's Mod - Utility Functions
    Description: Provides utility functions for the rRadio addon.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-03
]]

utils = utils or {}
utils.DEBUG_MODE = false
utils.VERBOSE_ERRORS = false

--[[
    Function: isSitAnywhereSeat
    Description: Checks if a vehicle is a "sit anywhere" seat.
    @param vehicle (Entity): The vehicle to check.
    @return (boolean): True if it's a sit anywhere seat, false otherwise.
]]
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle.IsSitAnywhereSeat or false
end

--[[
    Function: isBoombox
    Description: Checks if an entity is a boombox.
    @param ent (Entity): The entity to check.
    @return (boolean): True if it's a boombox, false otherwise.
]]
function utils.isBoombox(ent)
    entity = ent or nil
    if not IsValid(entity) then return false end
    return entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox"
end

-- Function to print errors if verbose_errors is enabled
function utils.PrintError(msg, severity)
    severity = severity or 3
    if utils.VERBOSE_ERRORS then
        print("[rRadio Error] [" .. (severity or "0") .. "] " .. msg)
    end
end

--[[
    Function: formatCountryNameForComparison
    Description: Formats a country name for consistent comparison.
    @param name (string): The country name to format.
    @return (string): The formatted country name.
]]
function utils.formatCountryNameForComparison(name)
    name = name:lower()
    name = name:gsub("^the%s+", "")
    name = name:gsub("%s+and%s+", " ")
    name = name:gsub("^republic%s+of%s+", "")
    -- Add more replacements as needed
    return name
end

--[[
    Function: formatCountryNameForDisplay
    Description: Formats a country name for display purposes.
    @param name (string): The country name to format.
    @return (string): The formatted country name for display.
]]
function utils.formatCountryNameForDisplay(name)
    name = stringGsub(name, "_", " ")
    return stringGsub(name, "(%a)([%w']*)", function(first, rest)
        return stringUpper(first) .. stringLower(rest)
    end)
end

-- Utility function for localization with fallback
function utils.L(key, ...)
    if not Config or not Config.Lang then
        return key
    end
    local str = Config.Lang[key] or key
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

function utils.getMainVehicleEntity(entity)
    if not IsValid(entity) then
        return nil
    end

    -- If the entity is a seat, get its parent
    if entity:GetClass() == "prop_vehicle_prisoner_pod" or entity:GetClass() == "prop_vehicle_jeep" then
        local parent = entity:GetParent()
        if IsValid(parent) then
            return parent
        else
            return entity
        end
    end

    -- For LVS vehicles or other custom vehicles
    if string.find(entity:GetClass(), "lvs_") then
        return entity
    end

    -- For other vehicle types, return the entity itself
    if entity:IsVehicle() then
        return entity
    end

    -- If none of the above, return the entity itself
    return entity
end


return utils