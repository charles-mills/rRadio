include("shared.lua")

function ENT:Initialize()
    self.Config = Config.GoldenBoombox
    self.Color = Color(255, 191, 0)
    self.BaseClass.Initialize(self)
end