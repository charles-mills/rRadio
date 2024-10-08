--[[ 
    rRadio Addon for Garry's Mod - Utility Functions
    Description: Provides utility functions for the rRadio addon.
    Author: Charles Mills (https://github.com/charles-mills)
    Date: 2024-10-06
]]

utils = utils or {}

-- Configuration
utils.DEBUG_MODE = true
utils.VERBOSE_ERRORS = true

-- Local references for performance
local stringLower = string.lower
local stringGsub = string.gsub
local stringSub = string.sub
local stringUpper = string.upper

--[[ ENTITY CHECKS ]]--

--[[
    Function: isSitAnywhereSeat
    Description: Checks if a vehicle is a "sit anywhere" seat.
    @param vehicle (Entity): The vehicle to check.
    @return (boolean): True if it's a sit anywhere seat, false otherwise.
]]
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then 
        utils.DebugPrint("Invalid vehicle in isSitAnywhereSeat check")
        return false 
    end
    local isSitAnywhere = vehicle:GetNWBool("IsSitAnywhereSeat", false)
    utils.DebugPrint("Vehicle " .. vehicle:EntIndex() .. " is a sit anywhere seat: " .. tostring(isSitAnywhere))
    return isSitAnywhere
end

--[[
    Function: isBoombox
    Description: Checks if an entity is a boombox.
    @param ent (Entity): The entity to check.
    @return (boolean): True if it's a boombox, false otherwise.
]]
function utils.isBoombox(ent)
    if not IsValid(ent) then 
        utils.DebugPrint("Invalid entity in isBoombox check")
        return false 
    end
    return ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox"
end

--[[ DEBUGGING AND ERROR HANDLING ]]--

--[[
    Function: DebugPrint
    Description: Prints debug messages if DEBUG_MODE is enabled.
    @param msg (string): The message to print.
]]
function utils.DebugPrint(msg)
    if utils.DEBUG_MODE then
        print("[rRadio Debug] " .. tostring(msg))
    end
end

--[[
    Function: PrintError
    Description: Prints error messages if VERBOSE_ERRORS is enabled.
    @param msg (string): The error message.
    @param severity (number): Error severity level (1-5, default 3).
]]
function utils.PrintError(msg, severity)
    severity = severity or 3
    if utils.VERBOSE_ERRORS then
        print("[rRadio Error] [" .. tostring(severity) .. "] " .. tostring(msg))
    end
end

--[[ STRING FORMATTING ]]--

--[[
    Function: formatCountryNameForComparison
    Description: Formats a country name for consistent comparison.
    @param name (string): The country name to format.
    @return (string): The formatted country name.
]]
function utils.formatCountryNameForComparison(name)
    name = string.lower(name)
    name = string.gsub(name, "[ -]", "_")
    name = string.gsub(name, "[^a-z0-9_]", "")
    return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
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

--[[
    Function: FastFormatCountryName
    Description: Quickly formats a country name for comparison (optimized version).
    @param name (string): The country name to format.
    @return (string): The formatted country name.
]]
function utils.FastFormatCountryName(name)
    name = stringLower(name)
    name = stringGsub(name, "[ -]", "_")
    name = stringGsub(name, "[^a-z0-9_]", "")
    return stringUpper(stringSub(name, 1, 1)) .. stringSub(name, 2)
end

--[[ LOCALIZATION ]]--

--[[
    Function: L
    Description: Retrieves a localized string.
    @param key (string): The localization key.
    @param ... (vararg): Optional arguments for string formatting.
    @return (string): The localized string or the key if not found.
]]
function utils.L(key, ...)
    if not Config or not Config.Lang then
        utils.DebugPrint("Config or Config.Lang not available for localization")
        return key
    end
    local str = Config.Lang[key]
    if not str then
        utils.DebugPrint("Missing localization key: " .. key)
        return key
    end
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

--[[ AUTHORIZATION ]]--

--[[
    Function: IsPlayerAuthorized
    Description: Checks if a player is authorized to interact with an entity.
    @param ply (Player): The player to check.
    @param entity (Entity): The entity to check against.
    @return (boolean): True if the player is authorized, false otherwise.
]]
function utils.IsPlayerAuthorized(ply, entity)
    if not IsValid(ply) or not IsValid(entity) then 
        utils.DebugPrint("Invalid player or entity in IsPlayerAuthorized")
        return false 
    end
    
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end
    
    local owner = entity.CPPIGetOwner and entity:CPPIGetOwner() or entity:GetNWEntity("Owner")
    
    return ply == owner or utils.isAuthorizedFriend(owner, ply)
end

--[[ RADIO FUNCTIONALITY ]]--

--[[
    Function: HandleRadioPlay
    Description: Handles the playing of a radio station on an entity.
    @param entity (Entity): The entity to play the radio on.
    @param stationName (string): The name of the radio station.
    @param url (string): The URL of the radio stream.
    @param volume (number): The volume level (0-1).
    @param country (string): The country of the radio station.
    @return (table): A table with the play information, or nil if failed.
]]
function utils.HandleRadioPlay(entity, stationName, url, volume, country)
    if not IsValid(entity) then
        utils.PrintError("Invalid entity in HandleRadioPlay", 2)
        return nil
    end

    entity:SetNWString("CurrentRadioStation", stationName)
    entity:SetNWString("StationURL", url)
    entity:SetNWFloat("Volume", volume)
    entity:SetNWString("Country", country)
    entity:SetNWBool("IsRadioSource", true)

    net.Start("rRadio_PlayRadioStation")
    net.WriteEntity(entity)
    net.WriteString(url)
    net.WriteFloat(volume)
    net.WriteString(country)
    net.Broadcast()

    return {
        entity = entity,
        stationName = stationName,
        url = url,
        volume = volume
    }
end

--[[
    Function: UpdateSitAnywhereSeatStatus
    Description: Updates the status of a vehicle as a "sit anywhere" seat.
    @param vehicle (Entity): The vehicle to update.
]]
function utils.UpdateSitAnywhereSeatStatus(vehicle)
    if not IsValid(vehicle) then return end

    local isSitAnywhere = vehicle.playerdynseat or false
    vehicle:SetNWBool("IsSitAnywhereSeat", isSitAnywhere)

    -- Check if we're on the server before using net library
    if SERVER then
        if not net then
            ErrorNoHalt("net library not available in UpdateSitAnywhereSeatStatus")
            return
        end

        -- Use a unique timer name for each vehicle
        local timerName = "rRadio_UpdateSitAnywhereSeat_" .. vehicle:EntIndex()

        -- Cancel any existing timer for this vehicle
        timer.Remove(timerName)

        -- Create a new timer to send the network message
        timer.Create(timerName, 0.1, 1, function()
            if IsValid(vehicle) then
                net.Start("rRadio_UpdateSitAnywhereSeat")
                net.WriteEntity(vehicle)
                net.WriteBool(isSitAnywhere)
                net.Broadcast()
            end
        end)
    end
end

--[[ HOOKS ]]--

hook.Add("PlayerEnteredVehicle", "MarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        utils.UpdateSitAnywhereSeatStatus(vehicle)
    end
end)

hook.Add("PlayerLeaveVehicle", "UnmarkSitAnywhereSeat", function(ply, vehicle)
    if IsValid(vehicle) then
        utils.UpdateSitAnywhereSeatStatus(vehicle)
    end
end)

hook.Add("OnEntityCreated", "UpdateSitAnywhereSeatOnSpawn", function(ent)
    if IsValid(ent) and ent:IsVehicle() then
        timer.Simple(0.1, function()
            if IsValid(ent) then
                utils.UpdateSitAnywhereSeatStatus(ent)
            end
        end)
    end
end)

return utils