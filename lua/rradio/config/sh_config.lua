rRadio.Config = rRadio.Config or {}

function rRadio.LoadConfig()
    local files, _ = file.Find("rradio/config/*.lua", "LUA")
    for _, f in ipairs(files) do
        include("rradio/config/" .. f)
    end
end

function rRadio.SetConfig(key, value)
    rRadio.Config[key] = value
end

function rRadio.GetConfig(key, default)
    return rRadio.Config[key] or default
end
