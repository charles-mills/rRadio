AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_chatbox.lua")

include("shared.lua")

if SERVER then
    util.AddNetworkString("OpenChatBox")

    function ENT:Initialize()
        self:SetModel("models/Humans/Group01/male_03.mdl")
        self:SetHullType(HULL_HUMAN)
        self:SetHullSizeNormal()
        self:SetNPCState(NPC_STATE_SCRIPT)
        self:SetSolid(SOLID_BBOX)
        self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
        self:SetUseType(SIMPLE_USE)
    end

    function ENT:Use(activator, caller)
        if IsValid(caller) and caller:IsPlayer() then
            net.Start("OpenChatBox")
            net.Send(caller)
        end
    end
end