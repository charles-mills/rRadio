include("shared.lua")
function ENT:Initialize()
self.Color = Color(255, 215, 0)
self.Config = rRadio.config.GoldenBoombox
self.BaseClass.Initialize(self)
end