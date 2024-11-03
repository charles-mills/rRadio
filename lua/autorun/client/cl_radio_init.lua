print("[rRadio] Starting client-side initialization")

-- Load shared modules first
include("radio/shared/sh_debug.lua")
_G.RadioDebug = include("radio/shared/sh_debug.lua")
include("radio/shared/sh_events.lua")
include("radio/shared/sh_config.lua")
include("radio/shared/sh_utils.lua")

-- Create and initialize managers in correct order
local StateManager = include("radio/client/cl_state_manager.lua")
if not StateManager.initialized then
    StateManager:Initialize()
end

local StreamManager = include("radio/client/cl_stream_manager.lua")
if not StreamManager.initialized then
    StreamManager:Initialize()
end

-- Verify initialization
if not StateManager.initialized then
    error("[rRadio] Failed to initialize StateManager")
end

if not StreamManager.initialized then
    error("[rRadio] Failed to initialize StreamManager")
end

-- Initialize event bridge after both managers are ready
StateManager:InitializeStreamEvents(StreamManager)

-- Load remaining modules
include("radio/client/cl_theme_manager.lua")
include("radio/client/cl_misc.lua")
include("radio/client/cl_hooks.lua")
include("radio/client/cl_core.lua")

print("[rRadio] Finished client-side initialization")
