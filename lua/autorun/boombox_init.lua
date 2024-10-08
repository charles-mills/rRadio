local Config = include("misc/config.lua")

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
    resource.AddFile("materials/hud/volume.png")
    resource.AddFile("materials/hud/radio.png")
    resource.AddFile("materials/hud/flag.png")
    resource.AddFile("materials/models/rammel/boombox_back.vtf")
    resource.AddFile("materials/models/rammel/boombox_back.vmt")
    resource.AddFile("materials/models/rammel/boombox_back_n.vtf")
    resource.AddFile("materials/models/rammel/boombox_back_n.vmt")
    resource.AddFile("materials/models/rammel/boombox_base.vtf")
    resource.AddFile("materials/models/rammel/boombox_base_n.vtf")
    resource.AddFile("materials/models/rammel/boombox_base_n.vmt")
    resource.AddFile("materials/models/rammel/plastic_base.vtf")
    resource.AddFile("materials/models/rammel/plastic_base.vmt")

    resource.AddFile("models/rammel/boombox.mdl")
    resource.AddFile("models/rammel/boombox.phy")
    resource.AddFile("models/rammel/boombox.dx80.vtx")
    resource.AddFile("models/rammel/boombox.dx90.vtx")
    resource.AddFile("models/rammel/boombox.vvd")

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

Config.EnableGoldenBoombox = true

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
    AdminOnly = Config.EnableGoldenBoombox or true,  -- Use the config value if available, otherwise default to true
    Model = "models/rammel/boombox.mdl",
    Description = "A boombox with an extreme audio range!"
})
