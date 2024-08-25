function validateConfig()
    -- Validate volume settings
    if Config.Volume < 0.0 or Config.Volume > 1.0 then
        error("Config.Volume must be between 0.0 and 1.0")

        if Config.Volume < 0.0 then
            Config.Volume = 0.0
        elseif Config.Volume > 1.0 then
            Config.Volume = 1.0
        end
    end

    -- Validate distance settings
    if Config.MaxHearingDistance <= 0 then
        error("Config.MaxHearingDistance must be greater than 0")
        Config.MaxHearingDistance = 0
    end

    if Config.MinVolumeDistance < 0 or Config.MinVolumeDistance > Config.MaxHearingDistance then
        error("Config.MinVolumeDistance must be between 0 and Config.MaxHearingDistance")
        Config.MinVolumeDistance = 0
    end

    -- Validate retry settings
    if Config.RetryAttempts < 0 then
        error("Config.RetryAttempts must be a non-negative integer")
        Config.RetryAttempts = 0
    end

    if Config.RetryDelay < 0 then
        error("Config.RetryDelay must be a non-negative number")
        Config.RetryDelay = 0
    end

    -- Validate UI settings
    if Config.UI and Config.UI.FrameSize and (Config.UI.FrameSize.width <= 0 or Config.UI.FrameSize.height <= 0) then
        error("Config.UI.FrameSize must have positive width and height")
        Config.UI.FrameSize.width = 400
    end
end