AddCSLuaFile("entities/base_boombox/init.lua")
AddCSLuaFile("entities/base_boombox/cl_init.lua")
AddCSLuaFile("entities/base_boombox/shared.lua")

AddCSLuaFile("entities/boombox/shared.lua")

AddCSLuaFile("entities/golden_boombox/shared.lua")

if SERVER then
    resource.AddFile("materials/entities/boombox.png")
    resource.AddFile("materials/entities/golden_boombox.png")
    resource.AddFile("materials/hud/star.png")
    resource.AddFile("materials/hud/star_full.png")

    -- Include the base_boombox init file
    include("entities/base_boombox/init.lua")

    -- Function to set up Use for boomboxes
    local function SetupBoomboxUse(ent)
        if IsValid(ent) and (ent:GetClass() == "boombox" or ent:GetClass() == "golden_boombox") then
            if ENT and ENT.SetupUse then
                ent:SetupUse()
                print("Set up Use function for boombox: " .. ent:EntIndex())
            else
                print("Warning: ENT.SetupUse not found for boombox: " .. ent:EntIndex())
            end
        end
    end

    -- Set up Use for all existing boomboxes
    for _, ent in ipairs(ents.GetAll()) do
        SetupBoomboxUse(ent)
    end

    -- Set up Use for newly created boomboxes
    hook.Add("OnEntityCreated", "SetupBoomboxUseGlobal", function(ent)
        timer.Simple(0, function()
            SetupBoomboxUse(ent)
        end)
    end)
end

list.Set("SpawnableEntities", "boombox", {
    PrintName = "Boombox",
    ClassName = "boombox",
    Category = "Radio",
    AdminOnly = false,
    Model = "models/rammel/boombox.mdl",
    Description = "A basic boombox, ready to play some music!"
})

list.Set("SpawnableEntities", "golden_boombox", {
    PrintName = "Golden Boombox",
    ClassName = "golden_boombox",
    Category = "Radio",
    AdminOnly = true,
    Model = "models/rammel/boombox.mdl",
    Description = "A boombox with an extreme audio range!"
})
