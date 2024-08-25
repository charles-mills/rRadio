ENT.Base = "base_ai"
ENT.Type = "ai"
ENT.PrintName = "SN Car Dealer"
ENT.Author = "Rammel"
ENT.Category = "SkidNet Car Dealer"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:Initialize()
    self:SetModel("models/Humans/Group01/male_07.mdl")
    self:SetSolid(SOLID_BBOX)
    self:CapabilitiesAdd(CAP_ANIMATEDFACE)
    self:SetUseType(SIMPLE_USE)
end

function ENT:AcceptInput(name, activator, caller)
    if name == "Use" and IsValid(caller) and caller:IsPlayer() then
        net.Start("OpenCarDealerMenu")
        net.Send(caller)
    end
end
