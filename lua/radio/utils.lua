utils = utils or {}

-- #################################################
-- #                Debugging Utilities            #
-- #################################################

utils.debug_mode = true

-- Function: DebugPrint
-- Description: Prints debug messages if debug mode is enabled.
function utils.DebugPrint(msg)
    if utils.debug_mode then
        print("[CarRadio Debug] " .. msg)
    end
end

-- #################################################
-- #                Entity Utilities               #
-- #################################################

-- Function: isBoombox
-- Description: Checks if the given entity is a boombox.
function utils.isBoombox(entity)
    if not IsValid(entity) then return false end
    local class = entity:GetClass()
    return class == "boombox" or class == "golden_boombox"
end

-- Function: getMainVehicle
-- Description: Returns the main vehicle, accounting for parented entities.
function utils.getMainVehicle(entity)
    local parent = entity:GetParent()
    if IsValid(parent) and parent:IsVehicle() then
        return parent
    else
        return entity
    end
end

-- Function: isSitAnywhereSeat
-- Description: Checks if a vehicle is a "sit anywhere" seat.
function utils.isSitAnywhereSeat(vehicle)
    if not IsValid(vehicle) then return false end
    return vehicle:GetNWBool("IsSitAnywhereSeat", false)
end

-- Function: getEntityConfig
-- Description: Retrieves the configuration for the given entity.
function utils.getEntityConfig(entity)
    if not Config then
        utils.DebugPrint("Error: Config is not available in utils.getEntityConfig")
        return nil
    end

    local entityClass = entity:GetClass()
    if entityClass == "golden_boombox" then
        return Config.GoldenBoombox
    elseif entityClass == "boombox" then
        return Config.Boombox
    elseif entity:IsVehicle() then
        return Config.VehicleRadio
    else
        return Config.VehicleRadio
    end
end

-- Function: formatCountryName
-- Description: Formats and translates a country name for display.
local countryTranslations = include("country_translations.lua")
function utils.formatCountryName(name)
    -- Reformat and then translate the country name
    local formattedName = name:gsub("_", " "):gsub("(%a)([%w_\']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    local lang = GetConVar("radio_language"):GetString() or "en"
    return countryTranslations:GetCountryName(lang, formattedName)
end

-- #################################################
-- #               Gamemode Utilities              #
-- #################################################

if SERVER then
    -- Function: isDarkRP
    -- Description: Determines if the current gamemode is DarkRP or derived.
    function utils.isDarkRP()
        return DarkRP ~= nil and DarkRP.getPhrase ~= nil
    end

    -- Function: assignOwner
    -- Description: Assigns ownership to an entity (supports CPPI).
    function utils.assignOwner(ply, ent)
        if ent.CPPISetOwner then
            ent:CPPISetOwner(ply)
        end
        ent:SetNWEntity("Owner", ply)
    end
end

-- #################################################
-- #               Client-Side Utilities           #
-- #################################################

if CLIENT then
    -- Function: Scale
    -- Description: Scales a value based on the screen width (for UI elements).
    function utils.Scale(value)
        return value * (ScrW() / 2560)
    end
end