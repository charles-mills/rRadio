rRadio = rRadio or {}
rRadio.Modules = {}
rRadio.Version = "1.0.0"
rRadio.Events = {}

function rRadio.LoadModules()
    local files, _ = file.Find("rradio/modules/*/*.lua", "LUA")
    for _, f in ipairs(files) do
        local prefix = string.sub(f, 1, 3)
        if SERVER and prefix == "sv_" or prefix == "sh_" then
            include("rradio/modules/" .. f)
        elseif CLIENT then
            if prefix == "cl_" or prefix == "sh_" then
                include("rradio/modules/" .. f)
            end
        end
    end
end

function rRadio.CheckVersion()
    local function fetchLatestVersion(callback)
        http.Fetch("https://raw.githubusercontent.com/charles-mills/rRadio/main/version.txt",
            function(body)
                local latestVersion = string.Trim(body)
                callback(latestVersion)
            end,
            function(error)
                print("rRadio: Failed to fetch latest version. Error: " .. error)
                callback(nil)
            end
        )
    end

    fetchLatestVersion(function(latestVersion)
        if latestVersion then
            if latestVersion ~= rRadio.Version then
                print("rRadio: A new version is available! Current version: " .. rRadio.Version .. ", Latest version: " .. latestVersion)
                rRadio.TriggerEvent("VersionOutdated", rRadio.Version, latestVersion)
            else
                print("rRadio: You are running the latest version (" .. rRadio.Version .. ")")
            end
        end
    end)
end

function rRadio.TriggerEvent(eventName, ...)
    if rRadio.Events[eventName] then
        for _, func in ipairs(rRadio.Events[eventName]) do
            func(...)
        end
    end
end

function rRadio.AddEventListener(eventName, func)
    rRadio.Events[eventName] = rRadio.Events[eventName] or {}
    table.insert(rRadio.Events[eventName], func)
end

rRadio.LoadModules()
