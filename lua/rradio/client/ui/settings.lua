rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.settings = rRadio.client.ui.settings or {}

local settings = rRadio.client.ui.settings
local settingsDefinitions = rRadio.client.ui.settingsDefinitions
local settingsControls = rRadio.client.ui.settingsControls


local function buildSection( parent, section, context, isFirst, rows )
    settingsControls.BuildSectionHeader( parent, section, isFirst )

    for _, setting in ipairs( section.settings ) do
        rows[#rows + 1] = settingsControls.BuildSettingRow( parent, setting, context )
    end
end


local function getDockedHeight( parent )
    local height = 0

    for _, child in ipairs( parent:GetChildren() ) do
        local _left, top, _right, bottom = 0, 0, 0, 0
        if child.GetDockMargin then _left, top, _right, bottom = child:GetDockMargin() end

        height = height + child:GetTall() + top + bottom
    end

    return height
end


local function setServerSectionExpanded( header, container, scroll, expanded )
    container:SetVisible( expanded )
    container:SetTall( expanded and getDockedHeight( container ) or 0 )
    header:SetExpanded( expanded )
    scroll:InvalidateLayout( true )
end


function settings.Build( parent, entity, callbacks )
    callbacks = callbacks or {}

    local content, scroll = settingsControls.BuildPanel( parent )
    local context = {
        entity = entity,
        parent = parent,
        callbacks = callbacks
    }
    local settingRows = {}
    local serverSections = {}
    local hasRenderedSection = false

    for _, section in ipairs( settingsDefinitions.GetSections( context ) ) do
        if section.serverConfig then
            serverSections[#serverSections + 1] = section
        else
            buildSection( scroll, section, context, not hasRenderedSection, settingRows )
            hasRenderedSection = true
        end
    end

    if #serverSections > 0 then
        local state = rRadio.client.ui.state
        local expanded = state.serverSettingsExpanded == true
        local header
        local serverContainer
        header = settingsControls.BuildServerConfigHeader( scroll, expanded, function()
            expanded = not expanded
            state.serverSettingsExpanded = expanded
            setServerSectionExpanded( header, serverContainer, scroll, expanded )
        end, not hasRenderedSection )

        serverContainer = vgui.Create( "DPanel", scroll )
        serverContainer:Dock( TOP )
        serverContainer.Paint = nil

        for _, section in ipairs( serverSections ) do
            buildSection( serverContainer, section, context, false, settingRows )
        end

        setServerSectionExpanded( header, serverContainer, scroll, expanded )
    end

    content.rRadioSettingRows = settingRows
    function content:RefreshValues()
        for _, row in ipairs( self.rRadioSettingRows or {} ) do
            if row.RefreshValue then row:RefreshValue() end
        end
    end

    return content
end


return settings
