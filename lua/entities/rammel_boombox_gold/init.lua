local Radio, Config = rRadio:Import("Radio", "config")

include("shared.lua")

function ENT:Initialize()
    self.Color = Color(255, 215, 0)
    self.Config = Config.GoldenBoombox
    self.BaseClass.Initialize(self)
end