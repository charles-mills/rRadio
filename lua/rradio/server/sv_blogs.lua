if SERVER and GAS then
    CreateConVar("rammel_rradio_logging", "0", FCVAR_ARCHIVE, "Enable bLogs integration for rRadio")
end

local MODULE = GAS.Logging:MODULE()

MODULE.Category = "rRadio"
MODULE.Name = "Plays"
MODULE.Colour = Color(255, 153, 0)

MODULE:Setup(function()
    local function StationPlayed(ply, ent, station, stationURL)
        if not GetConVar("rammel_rradio_logging"):GetBool() then return end
        MODULE:LogPhrase("Station Played by " .. (ply and GAS.Logging:FormatPlayer(ply) or "Unknown"), {
            { "Player", GAS.Logging:FormatPlayer(ply) },
            { "Entity", GAS.Logging:FormatEntity(ent) },
            { "Station", GAS.Logging:Escape(station) },
            { "Station URL", GAS.Logging:Escape(stationURL) }
        })
    end

    hook.Add("rRadio.PostPlayStation", "StationPlayed", StationPlayed)
end)

GAS.Logging:AddModule(MODULE)

local MODULE = GAS.Logging:MODULE()

MODULE.Category = "rRadio"
MODULE.Name = "Stops"
MODULE.Colour = Color(255, 153, 0)

MODULE:Setup(function()
    local function StationStopped(ply, ent)
        if not GetConVar("rammel_rradio_logging"):GetBool() then return end
        MODULE:LogPhrase("Station Stopped by " .. (ply and GAS.Logging:FormatPlayer(ply) or "Unknown"), {
            { "Player", GAS.Logging:FormatPlayer(ply) },
            { "Entity", GAS.Logging:FormatEntity(ent) },
        })
    end

    hook.Add("rRadio.PostStopStation", "StationStopped", StationStopped)
end)

GAS.Logging:AddModule(MODULE)