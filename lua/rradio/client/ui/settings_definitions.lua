rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.settingsDefinitions = rRadio.client.ui.settingsDefinitions or {}

local settingsDefinitions = rRadio.client.ui.settingsDefinitions
local uiKeys = rRadio.client.ui.keys
local MAX_CROSSFADE_MS = 6000

local function getContextCallbacks( context )
    return context and context.callbacks or {}
end

local function callSettingValue( value, setting, context )
    if type( value ) == "function" then return value( setting, context ) end

    return value
end

local function roundNumber( value, decimals )
    decimals = math.max( tonumber( decimals ) or 0, 0 )
    if decimals <= 0 then return math.floor( value + 0.5 ) end

    local multiplier = 10 ^ decimals
    return math.floor( value * multiplier + 0.5 ) / multiplier
end

local function formatNumber( value, decimals )
    decimals = math.max( tonumber( decimals ) or 0, 0 )
    if decimals <= 0 then return tostring( math.floor( tonumber( value ) or 0 ) ) end

    return string.format( "%." .. decimals .. "f", tonumber( value ) or 0 )
end

local function getThemeChoices()
    local choices = {}
    local localisation = rRadio.client.ui.localisation
    local themes = rRadio.client.ui.themes

    for _, themeName in ipairs( themes.GetNames() ) do
        choices[#choices + 1] = {
            label = localisation.GetTheme( themeName ),
            value = themeName
        }
    end

    return choices
end

local function getBoomboxHudModeChoices()
    return {
        {
            label = rRadio.L( "BoomboxHUDModeFull", "Full" ),
            value = "full"
        },
        {
            label = rRadio.L( "BoomboxHUDModeBasic", "Basic" ),
            value = "basic"
        }
    }
end

local function normalizeBoomboxHudMode( value )
    local mode = tostring( value or "" )
    if mode == "basic" or mode == "compact" then return "basic" end

    return "full"
end

local function readTheme()
    local conVarName = rRadio.GetClientConVarName( "menuTheme" )
    local conVar = conVarName and GetConVar( conVarName )
    local themeName = conVar and conVar:GetString() or nil

    return rRadio.client.ui.themes.ResolveUserThemeName( themeName )
end

local function isGoldThemeOverrideActive()
    local state = rRadio.client.ui.state
    return state and state.goldenThemeActive == true
end

local function readBoomboxHudMode( setting )
    local conVarName = rRadio.GetClientConVarName( setting.conVarID or setting.id )
    local conVar = conVarName and GetConVar( conVarName )
    return normalizeBoomboxHudMode( conVar and conVar:GetString() or "full" )
end

local function writeBoomboxHudMode( _setting, value )
    local mode = normalizeBoomboxHudMode( value )

    local conVarName = rRadio.GetClientConVarName( "boomboxHudMode" )
    if not conVarName then return nil end

    RunConsoleCommand( conVarName, mode )
    return mode
end

local function writeTheme( _setting, value, context )
    local themes = rRadio.client.ui.themes
    local themeName = themes.ResolveUserThemeName( value )
    if themeName == "" then return nil end

    local conVarName = rRadio.GetClientConVarName( "menuTheme" )
    if not conVarName then return nil end

    RunConsoleCommand( conVarName, themeName )

    local callbacks = getContextCallbacks( context )
    if isGoldThemeOverrideActive() then
        if callbacks.onThemeChanged then callbacks.onThemeChanged() end
    else
        themes.Apply( themeName )
    end

    return themeName
end

local function getThemePreviewRestoreValue()
    local themes = rRadio.client.ui.themes
    return themes.GetAppliedName()
end

local function previewTheme( _setting, value )
    if isGoldThemeOverrideActive() then
        return rRadio.client.ui.themes.Apply( "gold", {
            allowExclusive = true,
            preview = true
        } )
    end

    return rRadio.client.ui.themes.Apply( value, { preview = true } )
end

local function writeMenuScale( setting, value, context )
    local style = rRadio.client.ui.style

    local minimum = settingsDefinitions.GetMinimum( setting, context )
    local maximum = settingsDefinitions.GetMaximum( setting, context )
    local fallback = settingsDefinitions.GetDefault( setting, context )
    local clamped = math.Clamp( tonumber( value ) or fallback, minimum, maximum )
    local persisted = not ( context and context.live )

    clamped = style.SetMenuScale( clamped, persisted )

    local callbacks = getContextCallbacks( context )
    if callbacks.onRelayout then callbacks.onRelayout() end
    if persisted and callbacks.onSettingsRebuild then callbacks.onSettingsRebuild() end

    return clamped
end

local function writeMenuWidthScale( setting, value, context )
    local style = rRadio.client.ui.style

    local minimum = settingsDefinitions.GetMinimum( setting, context )
    local maximum = settingsDefinitions.GetMaximum( setting, context )
    local fallback = settingsDefinitions.GetDefault( setting, context )
    local clamped = math.Clamp( tonumber( value ) or fallback, minimum, maximum )
    local persisted = not ( context and context.live )

    clamped = style.SetMenuWidthScale( clamped, persisted )

    local callbacks = getContextCallbacks( context )
    if callbacks.onRelayout then callbacks.onRelayout() end

    return clamped
end

local function resetMenuScale( _setting, _value, context )
    local style = rRadio.client.ui.style

    local config = rRadio.config.MenuScale
    local defaultScale = tonumber( config.Default ) or 1
    local defaultWidth = tonumber( config.WidthDefault ) or 1

    style.SetMenuScale( defaultScale, true )
    style.SetMenuWidthScale( defaultWidth, true )

    local callbacks = getContextCallbacks( context )
    if callbacks.onRelayout then callbacks.onRelayout() end
    if callbacks.onSettingsRebuild then callbacks.onSettingsRebuild() end

    return true
end

local function normalizeCrossfadeMs( value, _context )
    return math.Clamp( tonumber( value ) or 0, 0, MAX_CROSSFADE_MS )
end

local function formatCrossfadeMs( value )
    value = tonumber( value ) or 0
    if value <= 0 then return rRadio.L( "Off", "Off" ) end

    return string.format( "%d ms", math.floor( value + 0.5 ) )
end

local function canShowPermanentBoombox( _setting, context )
    local state = rRadio.client.ui.state
    if state.canManageConfig ~= true then return false end
    if not context or not IsValid( context.entity ) then return false end

    return rRadio.util.IsBoomboxClass( context.entity:GetClass() )
end

local function readPermanentBoombox( _setting, context )
    if not context or not IsValid( context.entity ) then return false end

    return rRadio.client.radio.state.IsPermanent( context.entity )
end

local function writePermanentBoombox( _setting, value )
    return rRadio.client.ui.actions.SetPermanent( value == true )
end

local function canShowPublicBoombox( _setting, context )
    local state = rRadio.client.ui.state
    if state.canSetBoomboxPublic ~= true then return false end
    if not context or not IsValid( context.entity ) then return false end

    return rRadio.util.IsBoomboxClass( context.entity:GetClass() )
end

local function readPublicBoombox( _setting, context )
    if not context or not IsValid( context.entity ) then return false end

    return rRadio.client.radio.state.IsPublic( context.entity )
end

local function writePublicBoombox( _setting, value )
    return rRadio.client.ui.actions.SetPublic( value == true )
end

local function canShowServerConfig()
    local state = rRadio.client.ui.state
    return state.canManageConfig == true
end

local function readServerConfig( setting )
    return rRadio.configSchema.GetValue( setting.serverDefinition )
end

local function writeServerConfig( setting, value )
    local definition = setting.serverDefinition
    local normalized = rRadio.configSchema.NormalizeValue( definition, value )
    if normalized == nil then return nil end

    rRadio.client.ui.actions.SetServerConfig( definition, normalized )
    return normalized
end

local function resetAllServerConfig()
    return rRadio.client.ui.actions.ResetServerConfig( "*" )
end

local CLIENT_SETTING_OVERRIDES = {
    menuTheme = {
        read = readTheme,
        choices = getThemeChoices,
        getPreviewRestoreValue = getThemePreviewRestoreValue,
        preview = previewTheme,
        restorePreview = previewTheme,
        write = writeTheme
    },
    menuScale = {
        read = function()
            return rRadio.client.ui.style.GetMenuScale()
        end,
        write = writeMenuScale
    },
    menuWidthScale = {
        read = function()
            return rRadio.client.ui.style.GetMenuWidthScale()
        end,
        write = writeMenuWidthScale
    },
    menuKey = {
        blockedKeys = uiKeys.GetMenuKeyBlockedKeys()
    },
    crossfadeMs = {
        normalize = normalizeCrossfadeMs,
        formatValue = formatCrossfadeMs
    },
    boomboxHudMode = {
        choices = getBoomboxHudModeChoices,
        read = readBoomboxHudMode,
        write = writeBoomboxHudMode
    }
}

local STATIC_SETTINGS = {
    {
        id = "resetMenuScale",
        section = "appearance",
        scope = "client",
        control = "action",
        labelKey = "ResetMenuScale",
        labelFallback = "Reset menu scale",
        helpKey = "SettingResetMenuScaleHelp",
        helpFallback = "Restore the default menu size and width.",
        buttonKey = "Reset",
        buttonFallback = "Reset",
        write = resetMenuScale
    },
    {
        id = "publicBoombox",
        section = "superadmin",
        scope = "entity",
        control = "toggle",
        labelKey = "MakeBoomboxPublic",
        labelFallback = "Make Boombox Public",
        helpKey = "SettingPublicHelp",
        helpFallback = "Allow anyone to open and control this boombox.",
        visible = canShowPublicBoombox,
        read = readPublicBoombox,
        write = writePublicBoombox
    },
    {
        id = "permanentBoombox",
        section = "superadmin",
        scope = "entity",
        control = "toggle",
        labelKey = "MakeBoomboxPermanent",
        labelFallback = "Make Boombox Permanent",
        helpKey = "SettingPermanentHelp",
        helpFallback = "Persist this boombox across map cleanup and server restarts.",
        visible = canShowPermanentBoombox,
        read = readPermanentBoombox,
        write = writePermanentBoombox
    }
}

local function copySettingValue( value )
    if type( value ) ~= "table" then return value end

    local copy = {}
    for key, child in pairs( value ) do
        copy[key] = copySettingValue( child )
    end

    return copy
end

local function applySettingOverrides( setting, overrides )
    if type( overrides ) ~= "table" then return setting end

    for key, value in pairs( overrides ) do
        setting[key] = copySettingValue( value )
    end

    return setting
end

local function materializeClientSetting( definition )
    local setting = {}

    for key, value in pairs( definition ) do
        if key ~= "conVarName" and key ~= "conVarDefault" then
            setting[key] = copySettingValue( value )
        end
    end

    setting.conVarID = setting.conVarID or setting.id
    return applySettingOverrides( setting, CLIENT_SETTING_OVERRIDES[setting.id] )
end

local function buildSettings()
    local rows = {}

    for _, definition in ipairs( rRadio.settingsCatalog.GetClientSettings() ) do
        rows[#rows + 1] = materializeClientSetting( definition )
    end

    for _, setting in ipairs( STATIC_SETTINGS ) do
        rows[#rows + 1] = copySettingValue( setting )
    end

    return rows
end

local SETTINGS = buildSettings()
local SECTION_ORDER

local function getServerConfigControl( definition )
    if definition.type == "bool" then return "toggle" end
    if definition.type == "number" or definition.type == "integer" then return "number" end
    if definition.type == "vector" then return "vector" end
    if definition.type == "stringList" then return "list" end

    return "text"
end

local function appendServerConfigSettings()
    local sectionRows = {}

    SETTINGS[#SETTINGS + 1] = {
        id = "serverConfigResetAll",
        section = "serverGeneral",
        control = "action",
        labelKey = "ServerConfigResetAll",
        labelFallback = "Reset all server config",
        helpKey = "ServerConfigResetAllHelp",
        helpFallback = "Restore every managed server config value to its Lua default.",
        buttonKey = "Reset",
        buttonFallback = "Reset",
        visible = canShowServerConfig,
        write = resetAllServerConfig
    }

    sectionRows.serverGeneral = { "serverConfigResetAll" }

    for _, section in ipairs( rRadio.configSchema.GetSections() ) do
        sectionRows[section.id] = sectionRows[section.id] or {}

        for _, definitionID in ipairs( section.rows ) do
            local definition = rRadio.configSchema.GetDefinition( definitionID )
            if definition then
                local settingID = "serverConfig." .. definition.id
                SETTINGS[#SETTINGS + 1] = {
                    id = settingID,
                    section = section.id,
                    control = definition.control or getServerConfigControl( definition ),
                    labelKey = definition.labelKey or "ServerConfig." .. definition.id,
                    labelFallback = definition.labelFallback,
                    helpKey = definition.helpKey or "ServerConfigHelp." .. definition.id,
                    helpFallback = definition.helpFallback,
                    minimum = definition.minimum,
                    maximum = definition.maximum,
                    decimals = definition.decimals,
                    visible = canShowServerConfig,
                    serverDefinition = definition,
                    read = readServerConfig,
                    write = writeServerConfig
                }

                sectionRows[section.id][#sectionRows[section.id] + 1] = settingID
            end
        end
    end

    for _, section in ipairs( rRadio.configSchema.GetSections() ) do
        local rows = sectionRows[section.id]
        if rows and #rows > 0 then
            SECTION_ORDER[#SECTION_ORDER + 1] = {
                id = section.id,
                labelKey = section.labelKey or "ServerConfigSection." .. section.id,
                labelFallback = section.labelFallback,
                serverConfig = true,
                rows = rows
            }
        end
    end
end

SECTION_ORDER = {
    {
        id = "appearance",
        labelKey = "AppearanceOptions",
        labelFallback = "Appearance",
        rows = {
            "menuTheme",
            "softBorders",
            "goldBoomboxTheme",
            "hideResizeGrabbers",
            "menuScale",
            "menuWidthScale",
            "resetMenuScale"
        }
    },
    {
        id = "controls",
        labelKey = "Controls",
        labelFallback = "Controls",
        rows = { "menuKey", "blockVehicleKillBind", "menuMoveCursor" }
    },
    {
        id = "audio",
        labelKey = "Audio",
        labelFallback = "Audio",
        rows = { "maxVolume", "crossfadeMs", "muteGameMenu" }
    },
    {
        id = "general",
        labelKey = "General",
        labelFallback = "General",
        rows = { "enabled", "boomboxHud", "boomboxHudMode", "vehicleAnimation" }
    },
    {
        id = "superadmin",
        labelKey = "Superadmin",
        labelFallback = "Superadmin",
        rows = { "publicBoombox", "permanentBoombox" }
    }
}

appendServerConfigSettings()

local settingsByID = {}

for _, setting in ipairs( SETTINGS ) do
    settingsByID[setting.id] = setting
end

function settingsDefinitions.GetSetting( id )
    return settingsByID[tostring( id or "" )]
end

function settingsDefinitions.IsBlockedKey( setting, keyCode )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    keyCode = tonumber( keyCode )
    if not setting or not keyCode or not setting.blockedKeys then return false end

    return setting.blockedKeys[keyCode] == true
end

function settingsDefinitions.GetKeybindFallback( setting, previousValue, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end

    local candidates = {
        tonumber( previousValue ),
        tonumber( settingsDefinitions.GetDefault( setting, context ) ),
        KEY_K
    }

    for _, keyCode in ipairs( candidates ) do
        if keyCode and not settingsDefinitions.IsBlockedKey( setting, keyCode ) then return keyCode end
    end

    return KEY_K
end

function settingsDefinitions.GetConVarName( setting )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end

    return rRadio.GetClientConVarName( setting.conVarID or setting.id )
end

function settingsDefinitions.GetDefault( setting, context )
    local explicitDefault = callSettingValue( setting.default, setting, context )
    if explicitDefault ~= nil then return explicitDefault end

    local conVarDefinition = rRadio.GetClientConVarDefinition( setting.conVarID or setting.id )
    if conVarDefinition then return conVarDefinition.default end

    return nil
end

function settingsDefinitions.GetMinimum( setting, context )
    return tonumber( callSettingValue( setting.minimum, setting, context ) ) or 0
end

function settingsDefinitions.GetMaximum( setting, context )
    return tonumber( callSettingValue( setting.maximum, setting, context ) ) or 1
end

function settingsDefinitions.GetDecimals( setting )
    return math.max( tonumber( setting.decimals ) or 0, 0 )
end

function settingsDefinitions.GetLabel( setting )
    return rRadio.L( setting.labelKey, setting.labelFallback or setting.id )
end

function settingsDefinitions.GetHelp( setting )
    if not setting.helpKey then return nil end

    return rRadio.L( setting.helpKey, setting.helpFallback or "" )
end

function settingsDefinitions.GetChoices( setting, context )
    if type( setting.choices ) ~= "function" then return {} end

    return setting.choices( setting, context ) or {}
end

function settingsDefinitions.FormatValue( setting, value )
    if type( setting.formatValue ) == "function" then return setting.formatValue( value ) end
    if setting.control == "slider" then return formatNumber( value, settingsDefinitions.GetDecimals( setting ) ) end

    return tostring( value or "" )
end

function settingsDefinitions.IsVisible( setting, context )
    if type( setting.visible ) == "function" then return setting.visible( setting, context ) end
    if setting.visible ~= nil then return setting.visible == true end

    return true
end

function settingsDefinitions.IsInScope( setting, context )
    local scope = context and context.scope
    if not scope or scope == "" then return true end

    return setting and setting.scope == scope
end

function settingsDefinitions.HasPreview( setting )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return false end

    return type( setting.preview ) == "function"
end

function settingsDefinitions.GetPreviewRestoreValue( setting, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end
    if type( setting.getPreviewRestoreValue ) == "function" then
        return setting.getPreviewRestoreValue( setting, context )
    end

    return settingsDefinitions.ReadValue( setting, context )
end

function settingsDefinitions.PreviewValue( setting, value, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting or type( setting.preview ) ~= "function" then return nil end

    return setting.preview( setting, value, context )
end

function settingsDefinitions.RestorePreview( setting, value, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end
    if type( setting.restorePreview ) == "function" then return setting.restorePreview( setting, value, context ) end

    return settingsDefinitions.PreviewValue( setting, value, context )
end

local function getConVar( setting )
    local conVarName = settingsDefinitions.GetConVarName( setting )
    if not conVarName then return nil end

    return GetConVar( conVarName )
end

local function normalizeSliderValue( setting, value, context )
    local minimum = settingsDefinitions.GetMinimum( setting, context )
    local maximum = settingsDefinitions.GetMaximum( setting, context )
    local fallback = settingsDefinitions.GetDefault( setting, context ) or 0
    local normalized = math.Clamp( tonumber( value ) or fallback, minimum, maximum )

    if type( setting.normalize ) == "function" then normalized = setting.normalize( normalized, context ) end

    return math.Clamp( roundNumber( normalized, settingsDefinitions.GetDecimals( setting ) ), minimum, maximum )
end

function settingsDefinitions.ReadValue( setting, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end
    if type( setting.read ) == "function" then return setting.read( setting, context ) end

    local conVar = getConVar( setting )
    if setting.control == "toggle" then
        if conVar then return conVar:GetBool() end

        return tobool( settingsDefinitions.GetDefault( setting, context ) )
    end

    if setting.control == "slider" then
        local value = conVar and conVar:GetFloat() or settingsDefinitions.GetDefault( setting, context )
        return normalizeSliderValue( setting, value, { live = true } )
    end

    if setting.control == "keybind" then
        return conVar and conVar:GetInt() or tonumber( settingsDefinitions.GetDefault( setting, context ) ) or KEY_K
    end

    if setting.control == "choice" then
        return conVar and conVar:GetString() or tostring( settingsDefinitions.GetDefault( setting, context ) or "" )
    end

    return settingsDefinitions.GetDefault( setting, context )
end

function settingsDefinitions.WriteValue( setting, value, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end
    if type( setting.write ) == "function" then return setting.write( setting, value, context ) end

    local conVarName = settingsDefinitions.GetConVarName( setting )
    if not conVarName then return nil end

    if setting.control == "toggle" then
        local boolValue = value == true or value == 1
        RunConsoleCommand( conVarName, boolValue and "1" or "0" )
        return boolValue
    end

    if setting.control == "slider" then
        local numeric = normalizeSliderValue( setting, value, context )
        RunConsoleCommand( conVarName, formatNumber( numeric, settingsDefinitions.GetDecimals( setting ) ) )
        return numeric
    end

    if setting.control == "keybind" then
        local keyCode = tonumber( value )
        if not keyCode or settingsDefinitions.IsBlockedKey( setting, keyCode ) then
            keyCode = settingsDefinitions.GetKeybindFallback( setting, nil, context )
        end

        RunConsoleCommand( conVarName, tostring( keyCode ) )
        return keyCode
    end

    RunConsoleCommand( conVarName, tostring( value or "" ) )
    return value
end

function settingsDefinitions.ResetValue( setting, context )
    if type( setting ) == "string" then setting = settingsDefinitions.GetSetting( setting ) end
    if not setting then return nil end
    if type( setting.reset ) == "function" then return setting.reset( setting, context ) end

    return settingsDefinitions.WriteValue( setting, settingsDefinitions.GetDefault( setting, context ), context )
end

function settingsDefinitions.GetSections( context )
    local sections = {}

    for _, section in ipairs( SECTION_ORDER ) do
        local rows = {}
        for _, settingID in ipairs( section.rows ) do
            local setting = settingsByID[settingID]
            if setting
                and settingsDefinitions.IsInScope( setting, context )
                and settingsDefinitions.IsVisible( setting, context )
            then
                rows[#rows + 1] = setting
            end
        end

        if #rows > 0 then
            sections[#sections + 1] = {
                id = section.id,
                labelKey = section.labelKey,
                labelFallback = section.labelFallback,
                serverConfig = section.serverConfig == true,
                settings = rows
            }
        end
    end

    return sections
end

function settingsDefinitions.ValidateMenuKeyConVar( fallbackValue )
    local setting = settingsDefinitions.GetSetting( "menuKey" )
    if not setting then return nil end

    local conVarName = settingsDefinitions.GetConVarName( setting )
    local conVar = conVarName and GetConVar( conVarName )
    if not conVar or not settingsDefinitions.IsBlockedKey( setting, conVar:GetInt() ) then return nil end

    local fallback = settingsDefinitions.GetKeybindFallback( setting, fallbackValue, nil )
    RunConsoleCommand( conVarName, tostring( fallback ) )
    return fallback
end

function settingsDefinitions.InitReservedMenuKeyGuard()
    cvars.AddChangeCallback( "rammel_rradio_menu_key", function( _name, oldValue, newValue )
        if settingsDefinitions.restoringMenuKey then return end
        if not settingsDefinitions.IsBlockedKey( "menuKey", tonumber( newValue ) ) then return end

        settingsDefinitions.restoringMenuKey = true
        settingsDefinitions.ValidateMenuKeyConVar( oldValue )
        settingsDefinitions.restoringMenuKey = false
    end, "rRadio_Settings_BlockReservedMenuKey" )

    timer.Simple( 0, function()
        settingsDefinitions.ValidateMenuKeyConVar()
    end )
end

settingsDefinitions.InitReservedMenuKeyGuard()

return settingsDefinitions
