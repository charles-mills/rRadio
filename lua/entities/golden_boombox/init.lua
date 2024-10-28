include("shared.lua")

util.AddNetworkString("PlayCarRadioStation")
util.AddNetworkString("StopCarRadioStation")
util.AddNetworkString("OpenRadioMenu")
util.AddNetworkString("UpdateRadioStatus")

function ENT:Initialize()
    self:SetModel("models/rammel/boombox.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetColor(Color(255, 215, 0))

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    self.Config = Config.GoldenBoombox
end