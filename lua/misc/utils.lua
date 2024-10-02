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
    if utils.VERBOSE_ERRORS then
        print("[CarRadio Error] [" .. (severity or "0") .. "] " .. msg)
    end
end