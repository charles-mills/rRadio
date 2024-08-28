AddCSLuaFile("entities/boombox/init.lua")

-- Optionally, if you're using the list.Set method:
list.Set("SpawnableEntities", "boombox", {
    PrintName = "Boombox",
    ClassName = "boombox",
    Category = "Radio",
    AdminOnly = false
})
