if SERVER then
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("radio/theme_menu.lua")
    include("radio/sv_radio.lua")
else
    include("radio/cl_radio.lua")
    include("radio/theme_menu.lua")
end
