include("shared.lua")
function ENT:Initialize()
self.Config = Config.Boombox
self.BaseClass.Initialize(self)
end