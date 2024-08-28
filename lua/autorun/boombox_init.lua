AddCSLuaFile("entities/base_boombox/init.lua")
AddCSLuaFile("entities/base_boombox/cl_init.lua")
AddCSLuaFile("entities/base_boombox/shared.lua")

AddCSLuaFile("entities/boombox/shared.lua")

AddCSLuaFile("entities/golden_boombox/shared.lua")

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
