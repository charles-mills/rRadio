include("shared.lua")
function ENT:Initialize()
self.Config = rRadio.config.Boombox
self.BaseClass.Initialize(self)
end