print("[RADIO] Starting client-side initialization")

-- Load core dependencies first
Config = include("radio/shared/sh_config.lua")
include("radio/shared/sh_utils.lua")

-- Load language manager first
LanguageManager = include("radio/client/lang/cl_language_manager.lua")

-- Load and initialize StateManager
_G.StateManager = include("radio/client/cl_state_manager.lua")
if not StateManager then
    error("[RADIO] Failed to load StateManager")
end

if not StateManager.initialized then
    StateManager:Initialize()
end

-- Load UI and language dependencies
include("radio/client/cl_themes.lua")
include("radio/client/cl_settings.lua")
include("radio/client/cl_key_names.lua")

-- Load core after all dependencies
include("radio/client/cl_core.lua")

-- Load language files last
include("radio/client/lang/cl_localisation_strings.lua")
include("radio/client/lang/cl_country_translations_a.lua")
include("radio/client/lang/cl_country_translations_b.lua")

print("[RADIO] Finished client-side initialization")
