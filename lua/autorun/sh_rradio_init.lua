rRadio = rRadio or {}
rRadio.startup = rRadio.startup or {}

local SHARED_FILES = {
    "rradio/shared/core/constants.lua",
    "rradio/shared/core/settings_catalog.lua",
    "rradio/shared/core/config.lua",
    "rradio/shared/core/config_schema.lua",
    "rradio/shared/core/logger.lua",
    "rradio/shared/core/privileges.lua",
    "rradio/shared/core/vehicle.lua",
    "rradio/shared/core/util.lua",
    "rradio/shared/core/generated_payload.lua",
    "rradio/shared/net/protocol.lua",
    "rradio/shared/stations/schema.lua"
}

local SERVER_FILES = {
    "rradio/server/config/service.lua",
    "rradio/server/stations/builtin_registry.lua",
    "rradio/server/stations/registry.lua",
    "rradio/server/radio/state_store.lua",
    "rradio/server/radio/permissions.lua",
    "rradio/server/radio/cooldowns.lua",
    "rradio/server/radio/snapshots.lua",
    "rradio/server/radio/playback.lua",
    "rradio/server/radio/custom_stations.lua",
    "rradio/server/radio/network.lua",
    "rradio/server/radio/commands.lua",
    "rradio/server/radio/lifecycle.lua",
    "rradio/server/radio/service.lua",
    "rradio/server/persistence/service.lua",
    "rradio/server/persistence/permaprops_compat.lua"
}

local CLIENT_FILES = {
    "rradio/client/fonts.lua",
    "rradio/client/stations/builtin_catalog.lua",
    "rradio/client/stations/catalog.lua",
    "rradio/client/stations/favourites.lua",
    "rradio/client/stations/recent.lua",
    "rradio/client/stations/search.lua",
    "rradio/client/stations/queries.lua",
    "rradio/client/radio/state.lua",
    "rradio/client/radio/mutes.lua",
    "rradio/client/audio/manager.lua",
    "rradio/client/ui/properties.lua",
    "rradio/client/net/handlers.lua",
    "rradio/client/hud/theme.lua",
    "rradio/client/hud/text.lua",
    "rradio/client/hud/layout.lua",
    "rradio/client/hud/renderer.lua",
    "rradio/client/hud/paint.lua",
    "rradio/client/hud/state.lua",
    "rradio/client/hud/visibility.lua",
    "rradio/client/hud/service.lua",
    "rradio/client/ui/themes.lua",
    "rradio/client/ui/localisation.lua",
    "rradio/client/ui/state.lua",
    "rradio/client/ui/style.lua",
    "rradio/client/ui/keys.lua",
    "rradio/client/ui/components.lua",
    "rradio/client/ui/dialogs.lua",
    "rradio/client/ui/vehicle_hint.lua",
    "rradio/client/ui/actions.lua",
    "rradio/client/ui/custom_stations.lua",
    "rradio/client/ui/settings_definitions.lua",
    "rradio/client/ui/settings_controls.lua",
    "rradio/client/ui/settings.lua",
    "rradio/client/ui/menu/view_model.lua",
    "rradio/client/ui/menu/rows.lua",
    "rradio/client/ui/menu/list.lua",
    "rradio/client/ui/menu/keyboard.lua",
    "rradio/client/ui/menu/footer.lua",
    "rradio/client/ui/menu/resize.lua",
    "rradio/client/ui/menu/frame.lua",
    "rradio/client/ui/menu/vehicle.lua",
    "rradio/client/ui/menu/controller.lua",
    "rradio/client/ui/tool_menu.lua"
}

local RESOURCE_FILES = {
    "resource/fonts/inter_18pt_medium.ttf",
    "resource/fonts/inter_18pt_bold.ttf"
}

local function includeSharedFile( path )
    if SERVER then AddCSLuaFile( path ) end
    include( path )
end

for _, path in ipairs( SHARED_FILES ) do
    includeSharedFile( path )
end

rRadio.privileges.RegisterWhenAvailable()

if CLIENT then
    rRadio.L = rRadio.L or function( key, fallback )
        return fallback or key
    end
end

if SERVER then
    for _, path in ipairs( RESOURCE_FILES ) do
        resource.AddSingleFile( path )
    end

    local generatedCatalogFiles = file.Find( "rradio/client/stations/generated/*.lua", "LUA" )
    table.sort( generatedCatalogFiles )
    for _, filename in ipairs( generatedCatalogFiles ) do
        AddCSLuaFile( "rradio/client/stations/generated/" .. filename )
    end

    local localeFiles = file.Find( "rradio/client/lang/*.lua", "LUA" )
    table.sort( localeFiles )
    for _, filename in ipairs( localeFiles ) do
        AddCSLuaFile( "rradio/client/lang/" .. filename )
    end

    for _, path in ipairs( CLIENT_FILES ) do
        AddCSLuaFile( path )
    end

    for _, path in ipairs( SERVER_FILES ) do
        include( path )
    end

    rRadio.configManager.service.Init()
    rRadio.stations.registry.Init()
    rRadio.radio.service.Init()
    rRadio.persistence.service.Init()
    hook.Run( "rRadio_PostServerLoad" )
    rRadio.startup.server = true
else
    rRadio.AddClientConVars()

    for _, path in ipairs( CLIENT_FILES ) do
        include( path )
    end

    rRadio.client.stations.catalog.Init()
    rRadio.client.stations.favourites.Init()
    rRadio.client.stations.recent.Init()
    rRadio.client.stations.queries.Init()
    rRadio.client.radio.state.Init()
    rRadio.client.radio.mutes.Init()
    rRadio.client.ui.themes.Init()
    rRadio.client.ui.localisation.Init()
    rRadio.client.ui.vehicleHint.Init()
    rRadio.client.audio.manager.Init()
    rRadio.client.ui.properties.Init()
    rRadio.client.net.handlers.Init()
    rRadio.client.hud.Init()
    rRadio.client.ui.menu.controller.Init()
    rRadio.client.ui.toolMenu.Init()
    rRadio.startup.client = true
end
