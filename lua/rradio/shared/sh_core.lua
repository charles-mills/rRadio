--[[
    rRadio Core Module
    Centralises shared constants, namespaces, and helpers that are used by both
    server and client code. This file should be the first shared dependency
    loaded by the addon so that later files can rely on the common shape of the
    `rRadio` table.
]]

rRadio = rRadio or {}

local core = rRadio.core or {}

if core._initialised then
    return core
end

core.version = "1.0.0"

-- Namespaces --------------------------------------------------------------

local function ensureTable(root, key)
    local tbl = root[key]
    if tbl == nil then
        tbl = {}
        root[key] = tbl
    end
    return tbl
end

function core.ensureNamespace(name)
    return ensureTable(rRadio, name)
end

function core.ensurePath(root, ...)
    local current = root
    for _, key in ipairs({ ... }) do
        current = ensureTable(current, key)
    end
    return current
end

core.ensureNamespace("sv")
core.ensureNamespace("cl")
core.ensureNamespace("config")
core.ensureNamespace("utils")

-- Constants --------------------------------------------------------------

core.Status = core.Status or {
    STOPPED = 0,
    TUNING  = 1,
    PLAYING = 2
}

core.TimerPrefix = core.TimerPrefix or {
    RadioStatus = "rRadio_UpdateStatus_",
    VolumeUpdate = "VolumeUpdate_",
    StationUpdate = "StationUpdate_"
}

core.Net = core.Net or {
    PlayStation             = "rRadio.PlayStation",
    StopStation             = "rRadio.StopStation",
    SetRadioVolume          = "rRadio.SetRadioVolume",
    UpdateRadioStatus       = "rRadio.UpdateRadioStatus",
    ActiveRadios            = "rRadio.ActiveRadios",
    PlayVehicleAnimation    = "rRadio.PlayVehicleAnimation",
    OpenMenu                = "rRadio.OpenMenu",
    SetPersistent           = "rRadio.SetPersistent",
    RemovePersistent        = "rRadio.RemovePersistent",
    SendPersistentConfirm   = "rRadio.SendPersistentConfirmation",
    SetConfigUpdate         = "rRadio.SetConfigUpdate",
    CustomStationsUpdate    = "rRadio.CustomStationsUpdate",
    ListCustomStations      = "rRadio.ListCustomStations"
}

-- Provide legacy aliases so existing code continues to function while the
-- refactor proceeds.
rRadio.status = rRadio.status or core.Status
rRadio.net    = rRadio.net or core.Net

-- Networking helpers -----------------------------------------------------

local registeredStrings = {}

function core.registerNetworkStrings()
    if CLIENT then return end

    for key, message in pairs(core.Net) do
        if not registeredStrings[message] then
            util.AddNetworkString(message)
            registeredStrings[message] = true
        end
    end
end

-- Diagnostics ------------------------------------------------------------

function core.logger(channel)
    local prefix = string.format("[rRadio][%s]", channel or "core")
    return function(...)
        if not rRadio.DEV then return end
        MsgC(Color(0, 200, 255), prefix .. " ")
        print(...)
    end
end

core._initialised = true

rRadio.core = core

return core
