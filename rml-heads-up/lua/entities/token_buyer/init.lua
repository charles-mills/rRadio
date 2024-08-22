AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Define the NPC entity's behavior when initialized
function ENT:Initialize()
    self:SetModel("models/Humans/Group01/male_07.mdl") -- Change this to your desired NPC model
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:CapabilitiesAdd(CAP_ANIMATEDFACE, CAP_TURN_HEAD)
    self:SetUseType(SIMPLE_USE)
end

-- Define what happens when a player uses (presses E on) the NPC
function ENT:AcceptInput(name, activator, caller)
    if name == "Use" and IsValid(caller) and caller:IsPlayer() then
        net.Start("OpenTokenBuyerMenu")
        net.Send(caller)
    end
end
