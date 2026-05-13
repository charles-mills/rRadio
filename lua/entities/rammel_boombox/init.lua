AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

local DEFAULT_MODEL = "models/rammel/boombox.mdl"
local NEXT_USE_KEY = "rRadioNextUse"
local INTERACT_COOLDOWN = 1
local permissionMessageTimes = setmetatable( {}, { __mode = "k" } )

function ENT:Initialize()
    self:SetModel( self.Model or DEFAULT_MODEL )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( SIMPLE_USE )

    if self.Color then self:SetColor( self.Color ) end

    local physics = self:GetPhysicsObject()
    if IsValid( physics ) then physics:Wake() end

    rRadio.radio.stateStore.InitializeEntity( self )

    self[NEXT_USE_KEY] = 0
end

function ENT:Use( activator )
    if not IsValid( activator ) or not activator:IsPlayer() then return end

    local now = CurTime()
    if now < ( self[NEXT_USE_KEY] or 0 ) then return end

    self[NEXT_USE_KEY] = now + INTERACT_COOLDOWN

    local allowed, reason = rRadio.radio.permissions.CanOpenMenu( activator, self )
    if not allowed then
        if now - ( permissionMessageTimes[activator] or 0 ) > ( rRadio.config.MessageCooldown or 5 ) then
            activator:ChatPrint( "[rRadio] " .. tostring( reason ) )
            permissionMessageTimes[activator] = now
        end

        return
    end

    net.Start( rRadio.net.protocol.Messages.OpenMenu )
    rRadio.net.protocol.WriteVersion()
    net.WriteEntity( self )
    local canSetPublic = rRadio.radio.permissions.CanSetBoomboxPublic( activator, self )
    net.WriteBool( canSetPublic == true )
    rRadio.configManager.service.WriteSnapshotPayload( activator )
    net.Send( activator )
end

function ENT:SpawnFunction( player, trace, className )
    if not trace.Hit then return nil end

    local entity = ents.Create( className )
    if not IsValid( entity ) then return nil end

    entity:SetPos( trace.HitPos + trace.HitNormal * 16 )
    entity:SetAngles( Angle( 0, player:EyeAngles().y - 90, 0 ) )
    entity:Spawn()
    entity:Activate()

    rRadio.radio.stateStore.SetOwner( entity, player )

    return entity
end

function ENT:CanTool( player, _trace, mode, _tool, button )
    if mode == "permaprops" then
        local allowed = rRadio.persistence.permapropsCompat.CanUseTool( player, self, button )
        if allowed ~= nil then return allowed end
    end

    return rRadio.radio.permissions.CanModifyBoombox( player, self )
end

function ENT:PhysgunPickup( player )
    return rRadio.radio.permissions.CanModifyBoombox( player, self )
end

function ENT:PhysicsCollide()
    if rRadio.config.DisablePushDamage then return true end
end

hook.Add( "PlayerDisconnected", "rRadio_Boombox_ClearPermissionCooldowns", function( player )
    permissionMessageTimes[player] = nil
end )
