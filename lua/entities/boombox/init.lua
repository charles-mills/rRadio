include("shared.lua")

util.AddNetworkString("rRadio_PlayRadioStation")
util.AddNetworkString("rRadio_StopRadioStation")
util.AddNetworkString("rRadio_OpenRadioMenu")
util.AddNetworkString("rRadio_UpdateRadioStatus")

function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    self.Config = Config.Boombox

    -- Initialize the radio volume
    self:SetNWFloat("RadioVolume", self.Config.Volume or 0.5)
end

-- Modify the Use function to use the isAuthorizedFriend method from the base entity
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local owner = self:GetNWEntity("Owner")
    if activator == owner or activator:IsAdmin() or self:isAuthorizedFriend(owner, activator) then
        net.Start("rRadio_OpenRadioMenu")
        net.WriteEntity(self)
        net.Send(activator)
    else
        activator:ChatPrint("You don't have permission to use this boombox.")
    end
end

-- Add this hook to ensure the Use function is set up for all boomboxes, including permanent ones
hook.Add("OnEntityCreated", "SetupBoomboxUse", function(ent)
    if IsValid(ent) and ent:GetClass() == "boombox" then
        timer.Simple(0, function()
            if IsValid(ent) and ent.Use then
                local originalUse = ent.Use
                ent.Use = function(self, activator, caller)
                    if not IsValid(activator) or not activator:IsPlayer() then return end
                    
                    local owner = self:GetNWEntity("Owner")
                    if activator == owner or activator:IsAdmin() or self:isAuthorizedFriend(owner, activator) then
                        originalUse(self, activator, caller)
                    else
                        activator:ChatPrint("You don't have permission to use this boombox.")
                    end
                end
                utils.DebugPrint("[CarRadio Debug] Set up Use function for boombox: " .. ent:EntIndex())
            else
                utils.DebugPrint("[CarRadio Debug] Use function not found for boombox: " .. ent:EntIndex())
            end
        end)
    end
end)