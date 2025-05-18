if SERVER and GAS then
    CreateConVar("rammel_rradio_logging", "0", FCVAR_ARCHIVE, "Enable bLogs integration for rRadio")
end

if not GAS then return end

local loggingEnabled = GetConVar("rammel_rradio_logging"):GetBool()

local MODULE_PLAYS = GAS.Logging:MODULE()

MODULE_PLAYS.Category = "rRadio"
MODULE_PLAYS.Name = "Plays"
MODULE_PLAYS.Colour = Color(255, 153, 0)

MODULE_PLAYS:Setup(function()
    local function StationPlayed(ply, ent, station, stationURL)
        if not loggingEnabled then return end
        MODULE_PLAYS:LogPhrase("Station Played by " .. (ply and GAS.Logging:FormatPlayer(ply) or "Unknown"), {
            { "Player", GAS.Logging:FormatPlayer(ply) },
            { "Entity", GAS.Logging:FormatEntity(ent) },
            { "Station", GAS.Logging:Escape(station) },
            { "Station URL", GAS.Logging:Escape(stationURL) }
        })
    end

    hook.Add("rRadio.PostPlayStation", "StationPlayed", StationPlayed)
end)

if loggingEnabled then GAS.Logging:AddModule(MODULE_PLAYS) end

local MODULE_STOPS = GAS.Logging:MODULE()

MODULE_STOPS.Category = "rRadio"
MODULE_STOPS.Name = "Stops"
MODULE_STOPS.Colour = Color(255, 153, 0)

MODULE_STOPS:Setup(function()
    local function StationStopped(ply, ent)
        if not loggingEnabled then return end
        MODULE_STOPS:LogPhrase("Station Stopped by " .. (ply and GAS.Logging:FormatPlayer(ply) or "Unknown"), {
            { "Player", GAS.Logging:FormatPlayer(ply) },
            { "Entity", GAS.Logging:FormatEntity(ent) },
        })
    end

    hook.Add("rRadio.PostStopStation", "StationStopped", StationStopped)
end)

if loggingEnabled then GAS.Logging:AddModule(MODULE_STOPS) end

cvars.AddChangeCallback("rammel_rradio_logging", function(convar_name, old_value, new_value)
    if tobool(new_value) then
        GAS.Logging:AddModule(MODULE_PLAYS)
        GAS.Logging:AddModule(MODULE_STOPS)
        print("Enabled rRadio logging.")
    else
        print("Disabled rRadio logging.")
    end
end, "rRadio_LoggingCallback")
