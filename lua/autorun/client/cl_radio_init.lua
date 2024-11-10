print("[rRadio] Starting client-side initialization")

-- Load core dependencies first
Config = include("radio/shared/sh_config.lua")
include("radio/shared/sh_utils.lua")

-- Load and initialize StateManager
_G.StateManager = include("radio/client/cl_state_manager.lua")
if not StateManager then
    error("[rRadio] Failed to load StateManager")
end

if not StateManager.initialized then
    StateManager:Initialize()
end

-- Load UI and language dependencies
include("radio/client/cl_theme_manager.lua")
local Misc = include("radio/client/cl_misc.lua")
-- Load core after all dependencies
include("radio/client/cl_core.lua")

-- Add admin panel
include("radio/client/cl_admin.lua")

print("[rRadio] Finished client-side initialization")
