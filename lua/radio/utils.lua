utils = utils or {}
utils.debug_mode = false

--[[
    Function: isSitAnywhereSeat
    Description: Checks if a vehicle is a "sit anywhere" seat.
    @param vehicle (Entity): The vehicle to check.
    @return (boolean): True if it's a sit anywhere seat, false otherwise.
]]
function utils.isSitAnywhereSeat(vehicle)
    print("IsSitAnywhereSeat: " .. tostring(vehicle:GetNWBool("IsSitAnywhereSeat", false)))
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
end