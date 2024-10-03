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
    self:SetColor(Color(255, 215, 0))

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

    self.Config = Config.GoldenBoombox
end