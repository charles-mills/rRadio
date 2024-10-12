--[[
    Author: Charles Mills
    
    Created: 2024-10-12
    Last Updated: 2024-10-12

    Description:
    Handles ownership and control permissions for rRadio entities.
]]

rRadio = rRadio or {}
rRadio.Ownership = {}

function rRadio.Ownership.CanControlEntity(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end

    -- Check if the player is the owner
    if ent:GetNWEntity("Owner") == ply then return true end

    -- Check if the player is an admin or superadmin
    if ply:IsAdmin() or ply:IsSuperAdmin() then return true end

    -- DarkRP specific checks
    if DarkRP then
        -- Check if the player owns the entity through DarkRP's system
        if ent.Getowning_ent and ent:Getowning_ent() == ply then return true end
        
        -- Check if the player is in the same job category as the owner (e.g., all police can use police equipment)
        local owner = ent:GetNWEntity("Owner")
        if IsValid(owner) and ply:getJobTable().category == owner:getJobTable().category then return true end
    end

    -- TODO: Add "boombox friends" system check here in the future

    return false
end

if SERVER then
    util.AddNetworkString("rRadio_RequestControl")
    util.AddNetworkString("rRadio_UpdateControl")

    function rRadio.Ownership.SetupEntity(ent, owner)
        if IsValid(ent) and IsValid(owner) and owner:IsPlayer() then
            ent:SetNWEntity("Owner", owner)
            rRadio.Ownership.UpdateControlStatus(ent)
            
            -- Debug print
            print("Setting owner for boombox: ", owner:Nick())
        else
            print("Failed to set owner for boombox. Entity valid: ", IsValid(ent), " Owner valid: ", IsValid(owner))
        end
    end

    function rRadio.Ownership.UpdateControlStatus(ent)
        for _, ply in ipairs(player.GetAll()) do
            local canControl = rRadio.Ownership.CanControlEntity(ply, ent)
            ent:SetNWBool("CanControl", canControl, ply)
        end
    end

    net.Receive("rRadio_RequestControl", function(len, ply)
        local ent = net.ReadEntity()
        if IsValid(ent) and ent:GetClass() == "ent_rradio" then
            local canControl = rRadio.Ownership.CanControlEntity(ply, ent)
            ent:SetNWBool("CanControl", canControl, ply)
            net.Start("rRadio_UpdateControl")
            net.WriteEntity(ent)
            net.WriteBool(canControl)
            net.Send(ply)
        end
    end)
end

if CLIENT then
    net.Receive("rRadio_UpdateControl", function()
        local ent = net.ReadEntity()
        local canControl = net.ReadBool()
        if IsValid(ent) and ent:GetClass() == "ent_rradio" then
            ent:SetNWBool("CanControl", canControl)
        end
    end)

    function rRadio.Ownership.RequestControlStatus(ent)
        if IsValid(ent) and ent:GetClass() == "ent_rradio" then
            net.Start("rRadio_RequestControl")
            net.WriteEntity(ent)
            net.SendToServer()
        end
    end
end
