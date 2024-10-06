ENT = ENT or {}

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

if SERVER then
    AddCSLuaFile()
end
