AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Ensure SavedBoomboxStates is initialized
SavedBoomboxStates = SavedBoomboxStates or {}

-- Table to track the last time a player received a "no permission" message
local lastPermissionMessageTime = {}

-- Cooldown period for permission messages in seconds
local permissionMessageCooldown = 5

-- Function to restore the radio station if needed
local function RestoreBoomboxRadio(entity)
    local permaID = entity.PermaProps_ID
    if not permaID then
        print("Warning: Could not find PermaProps_ID for entity " .. entity:EntIndex())
        return
    end

    if entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox" then
        local savedState = SavedBoomboxStates[permaID]

        if savedState then
            print("Restoring station: " .. savedState.station)
            entity:SetNWString("CurrentRadioStation", savedState.station)
            entity:SetNWString("StationURL", savedState.url)
            entity:SetStationName(savedState.station) -- Assuming this is defined somewhere else

            if savedState.isPlaying then
                net.Start("PlayCarRadioStation")
                net.WriteEntity(entity)
                net.WriteString(savedState.url)
                net.WriteFloat(savedState.volume)
                net.Broadcast()
            end
        else
            print("No saved state found for PermaPropID " .. permaID)
        end
    end
end

-- Hook into OnEntityCreated to restore the boombox radio state for PermaProps
hook.Add("OnEntityCreated", "RestoreBoomboxRadioForPermaProps", function(entity)
    timer.Simple(0.1, function()
        if IsValid(entity) and (entity:GetClass() == "boombox" or entity:GetClass() == "golden_boombox") then
            RestoreBoomboxRadio(entity)
        end
    end)
end)

-- Set the owner when the entity is initialized
function ENT:Initialize()
    self:SetModel(self.Model or "models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    if self.Color then
        self:SetColor(self.Color)
    end

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    -- Set the owner of the boombox
    if IsValid(self.Owner) then
        self:SetNWEntity("Owner", self.Owner)
    end
end

-- Only allow the owner or a superadmin to use the boombox
function ENT:Use(activator, caller)
    if activator:IsPlayer() then
        local owner = self:GetNWEntity("Owner")
        
        -- Check if the player is the owner or a superadmin
        if activator == owner or activator:IsSuperAdmin() then
            net.Start("OpenRadioMenu")
            net.WriteEntity(self)
            net.Send(activator)
        else
            local currentTime = CurTime()

            -- Check if the player has recently received a "no permission" message
            if not lastPermissionMessageTime[activator] or (currentTime - lastPermissionMessageTime[activator] > permissionMessageCooldown) then
                activator:ChatPrint("You do not have permission to use this boombox.")
                lastPermissionMessageTime[activator] = currentTime
            end
        end
    end
end
