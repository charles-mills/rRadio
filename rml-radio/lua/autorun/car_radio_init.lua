if SERVER then
    AddCSLuaFile("radio/cl_radio.lua")
    AddCSLuaFile("radio/theme_menu.lua")
    AddCSLuaFile("themes.lua")
    AddCSLuaFile("config.lua")
    AddCSLuaFile("radio/validate_config.lua")
    AddCSLuaFile("radio/cl_init.lua")
    include("radio/sv_radio.lua")
else
    include("radio/cl_init.lua")
    include("themes.lua")
    include("config.lua")
    include("radio/validate_config.lua")
    include("radio/cl_radio.lua")
    include("radio/theme_menu.lua")
end
