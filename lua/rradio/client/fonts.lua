rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.fonts = rRadio.client.fonts or {}

local fonts = rRadio.client.fonts

local WINDOWS_FAMILY = "Inter 18pt"
local LINUX_MEDIUM_FILE = "inter_18pt_medium.ttf"
local LINUX_BOLD_FILE = "inter_18pt_bold.ttf"
local BOLD_WEIGHT = 700
local SIZE_SCALE = 1.08
local LINUX = system.IsLinux()

function fonts.GetFace( weight )
    if not LINUX then return WINDOWS_FAMILY end
    if ( tonumber( weight ) or 0 ) >= BOLD_WEIGHT then return LINUX_BOLD_FILE end

    return LINUX_MEDIUM_FILE
end

function fonts.ScaleSize( size )
    return math.floor( size * SIZE_SCALE + 0.5 )
end

return fonts
