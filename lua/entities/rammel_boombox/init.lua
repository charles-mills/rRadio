local Radio = rRadio
local Config = Radio.config

include("shared.lua")
function ENT:Initialize()
    self.Config = Config.Boombox
    self.BaseClass.Initialize(self)
end