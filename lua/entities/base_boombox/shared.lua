ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Base Boombox"
ENT.Author = "Rammel"
ENT.Category = "RML Radio"
ENT.Spawnable = false
ENT.AdminSpawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Volume")
    self:NetworkVar("String", 0, "StationName")
end

function ENT:GetVolumeAtPosition(listenerPos)
    local listener = Entity(1) -- or whatever entity is listening
    return Config.CalculateVolume(
        self,
        listener,
        self:GetVolume(),
        self:GetMaxHearingDistance(),
        self:GetMinVolumeDistance()
    )
end
