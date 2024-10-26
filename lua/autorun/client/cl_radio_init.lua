print("[RADIO] Starting client-side initialization")

Config = include("radio/shared/sh_config.lua")
include("radio/client/lang/cl_language_manager.lua")
include("radio/client/cl_settings.lua")
include("radio/client/cl_core.lua")
include("radio/shared/sh_utils.lua")
include("radio/client/lang/cl_country_translations.lua")
print("[RADIO] Finished client-side initialization")
