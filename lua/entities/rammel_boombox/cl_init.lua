include( "shared.lua" )

function ENT:Initialize()
    rRadio.client.hud.Register( self )
end

function ENT:OnRemove()
    rRadio.client.hud.Unregister( self )
end

function ENT:Draw()
    self:DrawModel()
end
