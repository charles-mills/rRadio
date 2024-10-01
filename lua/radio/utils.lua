utils = utils or {}

-- Function: isSitAnywhereSeat
-- Description: Checks if a vehicle is a "sit anywhere" seat.
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
end