if SERVER then
    AddCSLuaFile("skidnetworks_training/cl_marker.lua")
    AddCSLuaFile("skidnetworks_training/cl_training.lua")
    AddCSLuaFile("skidnetworks_training/config.lua")
    include("skidnetworks_training/sv_training.lua")
else
    include("skidnetworks_training/cl_marker.lua")
    include("skidnetworks_training/cl_training.lua")
end
