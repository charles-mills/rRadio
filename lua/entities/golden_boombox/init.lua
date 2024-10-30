include("shared.lua")

function ENT:Initialize()
    self.Config = Config.GoldenBoombox
    self.Color = Color(255, 215, 0)
    self.BaseClass.Initialize(self)
end