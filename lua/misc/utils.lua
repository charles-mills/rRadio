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
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
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

-- Debug function to print messages if debug_mode is enabled
function utils.DebugPrint(msg)
    if utils.DEBUG_MODE then
        print("[CarRadio Debug] " .. msg)
    end
end

-- Function to print errors if verbose_errors is enabled
function utils.PrintError(msg, severity)
    severity = severity or 3
    if utils.VERBOSE_ERRORS then
        print("[CarRadio Error] [" .. (severity or "0") .. "] " .. msg)
    end
end

-- Add this new function to the existing utils.lua file

--[[ 
    Function: formatCountryNameForComparison
    Description: Formats a country name for consistent comparison.
    @param name (string): The country name to format.
    @return (string): The formatted country name.
]]
function utils.formatCountryNameForComparison(name)
    -- Convert to lowercase
    name = string.lower(name)
    -- Replace spaces and hyphens with underscores
    name = string.gsub(name, "[ -]", "_")
    -- Remove any non-alphanumeric characters (except underscores)
    name = string.gsub(name, "[^a-z0-9_]", "")
    -- Capitalize the first letter
    name = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
    return name
end

function utils.formatCountryNameForDisplay(name)
    -- Remove underscores
    name = string.gsub(name, "_", " ")
    -- Apply title case
    name = string.gsub(name, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
    return name
end
