print("[RADIO] Starting server-side initialization")

AddCSLuaFile("radio/shared/sh_config.lua")
AddCSLuaFile("radio/client/lang/cl_language_manager.lua")
AddCSLuaFile("radio/client/cl_core.lua")
AddCSLuaFile("radio/client/cl_settings.lua")
AddCSLuaFile("radio/shared/sh_utils.lua")

-- Dynamically include all radio station data files
local dataFiles = file.Find("radio/client/stations/data_*.lua", "LUA")
for _, filename in ipairs(dataFiles) do
    AddCSLuaFile("radio/client/stations/" .. filename)
end

-- Dynamically include all language files
local langFiles = file.Find("radio/client/lang/*.lua", "LUA")
for _, filename in ipairs(langFiles) do
    AddCSLuaFile("radio/client/lang/" .. filename)
end

-- Include the server-side radio logic
include("radio/server/sv_core.lua")

-- Add resources
resource.AddFile("models/rammel/boombox.mdl")
resource.AddFile("models/rammel/boombox.phy")
resource.AddFile("models/rammel/boombox.vvd")
resource.AddFile("models/rammel/boombox.dx80.vtx")
resource.AddFile("models/rammel/boombox.dx90.vtx")
resource.AddFile("materials/models/rammel/boombox_back.vmt")
resource.AddFile("materials/models/rammel/boombox_back.vtf")
resource.AddFile("materials/models/rammel/boombox_back_n.vtf")
resource.AddFile("materials/models/rammel/boombox_base.vmt")
resource.AddFile("materials/models/rammel/boombox_base.vtf")
resource.AddFile("materials/models/rammel/boombox_base_n.vtf")
resource.AddFile("materials/models/rammel/plastic_base.vmt")
resource.AddFile("materials/models/rammel/plastic_base.vtf")
resource.AddFile("materials/models/rammel/plastic_base_n.vtf")
resource.AddFile("materials/entities/boombox.png")
resource.AddFile("materials/hud/close.png")
resource.AddFile("materials/hud/github.png")
resource.AddFile("materials/hud/radio.png.png")
resource.AddFile("materials/hud/settings.png")
resource.AddFile("materials/hud/return.png")
resource.AddFile("materials/hud/star_full.png")
resource.AddFile("materials/hud/star.png")
resource.AddFile("materials/hud/vol_down.png")
resource.AddFile("materials/hud/vol_up.png")
resource.AddFile("materials/hud/vol_mute.png")
resource.AddFile("materials/hud/volume.png")

-- Add CSLuaFiles for boombox entities
AddCSLuaFile("entities/boombox/shared.lua")

-- Set up spawnable entities
list.Set("SpawnableEntities", "boombox", {
    PrintName = "Boombox",
    ClassName = "boombox",
    Category = "Radio",
    AdminOnly = false,
    Model = "models/rammel/boombox.mdl",
    Description = "A boombox that can play music."
})

print("[RADIO] Finished server-side initialization")
