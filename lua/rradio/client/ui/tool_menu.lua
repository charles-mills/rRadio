rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.toolMenu = rRadio.client.ui.toolMenu or {}

local toolMenu = rRadio.client.ui.toolMenu
local style = rRadio.client.ui.style
local settingsDefinitions = rRadio.client.ui.settingsDefinitions

local DEFAULT_CONTROL_WIDTH = 130
local DEFAULT_CONTROL_HEIGHT = 22
local ACTION_BUTTON_MIN_WIDTH = 64

local function addFormItem( panel, item )
    if panel.AddItem then panel:AddItem( item ) end

    return item
end

local function addHelp( panel, help )
    if not help or help == "" then return end
    if panel.ControlHelp then
        panel:ControlHelp( help )
        return
    end

    if panel.Help then panel:Help( help ) end
end

local function playSuccess()
    if style.PlaySound then style.PlaySound( "SettingsMenuSuccess" ) end
end

local function playError()
    if style.PlaySound then style.PlaySound( "SettingsMenuError" ) end
end

local function makeWriteContext( context, live )
    context = context or {}

    return {
        parent = context.parent,
        callbacks = context.callbacks,
        live = live == true
    }
end

local function getKeyDisplayName( keyCode )
    local name = input.GetKeyName( keyCode )
    if not name or name == "" then return rRadio.L( "PressAKey", "Press a key..." ) end

    return ( name:gsub( "_", " " ):gsub( "(%a)([%w]*)", function( first, rest )
        return first:upper() .. rest:lower()
    end ) )
end

local function updateBinderText( binder )
    binder:SetText( getKeyDisplayName( binder:GetValue() ) )
end

local function shouldConfirmToggle( setting, checked, current )
    return setting.confirmOff == true and current == true and checked == false
end

local function getConfirmText( setting, keyField, fallbackField )
    local key = setting and setting[keyField]
    local fallback = setting and setting[fallbackField]
    if key then return rRadio.L( key, fallback or "" ) end

    return fallback or ""
end

local function showDefaultConfirm( setting, onConfirm, onCancel )
    Derma_Query(
        getConfirmText( setting, "confirmMessageKey", "confirmMessageFallback" ),
        getConfirmText( setting, "confirmTitleKey", "confirmTitleFallback" ),
        getConfirmText( setting, "confirmActionKey", "confirmActionFallback" ),
        onConfirm,
        rRadio.L( "Cancel", "Cancel" ),
        onCancel
    )
end

local function makeLabel( parent, text, font )
    local label = vgui.Create( "DLabel", parent )
    if font then label:SetFont( font ) end
    label:SetText( text )
    if label.SetDark then label:SetDark( true ) end
    label:SizeToContents()

    return label
end

local function sizeInlineControl( control, width )
    if control.SetWide then control:SetWide( width or DEFAULT_CONTROL_WIDTH ) end
    if control.SetTall then control:SetTall( DEFAULT_CONTROL_HEIGHT ) end
end

local function addLabeledControl( panel, labelText, control, controlWidth )
    local label = makeLabel( panel, labelText )
    sizeInlineControl( control, controlWidth )

    if panel.AddItem then
        panel:AddItem( label, control )
    else
        control:Dock( TOP )
    end

    return control
end

local function getActionButtonWidth( text )
    surface.SetFont( "DermaDefault" )
    local textWidth = surface.GetTextSize( tostring( text or "" ) )

    return math.max( ACTION_BUTTON_MIN_WIDTH, textWidth + 24 )
end

local function addSectionHeader( panel, section, isFirst )
    local label = rRadio.L( section.labelKey, section.labelFallback )
    local header = makeLabel( panel, label, "DermaDefaultBold" )
    header:SetTall( 20 )
    header:DockMargin( 0, isFirst and 0 or 8, 0, 2 )

    addFormItem( panel, header )
end

local function getChoicePreviewValue( combo, index )
    local value = combo:GetOptionData( index )
    if value ~= nil then return value end

    return combo:GetOptionText( index )
end

local function attachChoicePreview( combo, setting, context )
    if not settingsDefinitions.HasPreview( setting ) then return end

    local selectionMade = false
    local restoreValue
    local lastPreviewValue
    local previewApplied = false

    local function applyPreview( value )
        if value == lastPreviewValue then return end

        lastPreviewValue = value
        settingsDefinitions.PreviewValue( setting, value, makeWriteContext( context, true ) )
        previewApplied = true
    end

    local function restorePreview()
        if selectionMade or not previewApplied or restoreValue == nil then return end

        settingsDefinitions.RestorePreview( setting, restoreValue, makeWriteContext( context, true ) )
    end

    local function attachMenuHandlers( menu )
        if not IsValid( menu ) or not menu.GetCanvas then return end

        local baseOnRemove = menu.OnRemove
        menu.OnRemove = function( menuPanel )
            restorePreview()
            restoreValue = nil
            lastPreviewValue = nil
            previewApplied = false
            if baseOnRemove then baseOnRemove( menuPanel ) end
        end

        for index, option in ipairs( menu:GetCanvas():GetChildren() ) do
            local baseOnCursorEntered = option.OnCursorEntered
            option.OnCursorEntered = function( optionPanel, ... )
                if baseOnCursorEntered then baseOnCursorEntered( optionPanel, ... ) end

                applyPreview( getChoicePreviewValue( combo, index ) )
            end
        end
    end

    local baseOpenMenu = combo.OpenMenu
    combo.OpenMenu = function( panel, ... )
        restoreValue = settingsDefinitions.GetPreviewRestoreValue( setting, makeWriteContext( context, true ) )
        selectionMade = false
        lastPreviewValue = nil
        previewApplied = false

        baseOpenMenu( panel, ... )
        attachMenuHandlers( panel.Menu )
    end

    local baseChooseOption = combo.ChooseOption
    combo.ChooseOption = function( panel, ... )
        selectionMade = true
        return baseChooseOption( panel, ... )
    end
end

local function invalidateToolPanel( panel )
    if not IsValid( panel ) then return end

    panel:InvalidateLayout( true )
    local parent = panel:GetParent()
    if IsValid( parent ) then parent:InvalidateLayout( true ) end
end

local function refreshToolMenuValues( panel )
    for _, row in ipairs( panel.rRadioSettingRows or {} ) do
        if row.RefreshValue then row:RefreshValue() end
    end
end

local function buildToggleControl( panel, setting, context )
    local checkbox = vgui.Create( "DCheckBoxLabel", panel )
    local initializing = true
    local suppressChange = false

    checkbox:SetText( settingsDefinitions.GetLabel( setting ) )
    if checkbox.SetDark then checkbox:SetDark( true ) end
    checkbox:SetValue( settingsDefinitions.ReadValue( setting, context ) == true and 1 or 0 )
    checkbox:SizeToContents()

    local function setChecked( checked )
        suppressChange = true
        checkbox:SetValue( checked and 1 or 0 )
        suppressChange = false
    end

    local function commit( checked )
        local written = settingsDefinitions.WriteValue( setting, checked, makeWriteContext( context, false ) )
        setChecked( written == true )
        playSuccess()
    end

    checkbox.OnChange = function( _panel, checked )
        if initializing or suppressChange then return end

        local current = settingsDefinitions.ReadValue( setting, context ) == true
        checked = checked == true

        if shouldConfirmToggle( setting, checked, current ) then
            setChecked( current )
            showDefaultConfirm( setting, function()
                commit( checked )
            end, function()
                setChecked( current )
            end )
            return
        end

        commit( checked )
    end

    initializing = false
    addFormItem( panel, checkbox )
    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return function()
        setChecked( settingsDefinitions.ReadValue( setting, context ) == true )
    end
end

local function buildSliderControl( panel, setting, context )
    local slider = vgui.Create( "DNumSlider", panel )
    local initializing = true
    local suppressChange = false
    local pendingValue
    local wasEditing = false

    slider:SetText( settingsDefinitions.GetLabel( setting ) )
    slider:SetMin( settingsDefinitions.GetMinimum( setting, context ) )
    slider:SetMax( settingsDefinitions.GetMaximum( setting, context ) )
    slider:SetDecimals( settingsDefinitions.GetDecimals( setting ) )
    slider:SetValue( settingsDefinitions.ReadValue( setting, context ) )
    if slider.Label and slider.Label.SetDark then slider.Label:SetDark( true ) end

    local function setValue( value )
        suppressChange = true
        slider:SetValue( value )
        suppressChange = false
    end

    slider.OnValueChanged = function( _panel, value )
        if initializing or suppressChange then return end

        value = math.Clamp(
            value,
            settingsDefinitions.GetMinimum( setting, context ),
            settingsDefinitions.GetMaximum( setting, context )
        )
        pendingValue = value
        settingsDefinitions.WriteValue( setting, value, makeWriteContext( context, true ) )
    end

    local baseThink = slider.Think
    slider.Think = function( sliderPanel )
        if baseThink then baseThink( sliderPanel ) end

        local editing = sliderPanel:IsEditing()
        if wasEditing and not editing and pendingValue ~= nil then
            local written = settingsDefinitions.WriteValue( setting, pendingValue, makeWriteContext( context, false ) )
            pendingValue = nil
            if tonumber( written ) then setValue( written ) end
            playSuccess()
        end

        wasEditing = editing
    end

    initializing = false
    addFormItem( panel, slider )
    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return function()
        if slider:IsEditing() then return end

        slider:SetMin( settingsDefinitions.GetMinimum( setting, context ) )
        slider:SetMax( settingsDefinitions.GetMaximum( setting, context ) )
        setValue( settingsDefinitions.ReadValue( setting, context ) )
    end
end

local function buildChoiceControl( panel, setting, context )
    local combo = vgui.Create( "DComboBox", panel )
    local currentValue = settingsDefinitions.ReadValue( setting, context )
    local labelsByValue = {}
    local selectedLabel

    combo:SetSortItems( false )

    for _, choice in ipairs( settingsDefinitions.GetChoices( setting, context ) ) do
        local selected = choice.value == currentValue
        combo:AddChoice( choice.label, choice.value, selected )
        labelsByValue[choice.value] = choice.label
        if selected then selectedLabel = choice.label end
    end

    if selectedLabel then combo:SetValue( selectedLabel ) end

    combo.OnSelect = function( _panel, _index, _label, value )
        settingsDefinitions.WriteValue( setting, value, makeWriteContext( context, false ) )
        playSuccess()
    end

    attachChoicePreview( combo, setting, context )
    addLabeledControl( panel, settingsDefinitions.GetLabel( setting ), combo )
    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return function()
        local label = labelsByValue[settingsDefinitions.ReadValue( setting, context )]
        if label then combo:SetValue( label ) end
    end
end

local function makeCommitter( setting, context, readValue, applyValue )
    local lastValue = tostring( readValue() )

    local function markClean()
        lastValue = tostring( readValue() )
    end

    local function commit()
        local rawValue = readValue()
        if tostring( rawValue ) == lastValue then return nil end

        local written = settingsDefinitions.WriteValue( setting, rawValue, makeWriteContext( context, false ) )
        if written == nil or written == false then
            playError()
            return nil
        end

        if applyValue then applyValue( written ) end
        lastValue = tostring( readValue() )
        playSuccess()
        return written
    end

    return commit, markClean
end

local function bindImmediateCommit( field, commit )
    field.OnEnter = commit
    field.OnLoseFocus = commit
end

local function buildTextEntryControl( panel, setting, context, formatRead, formatWritten )
    local field = vgui.Create( "DTextEntry", panel )
    field:SetText( formatRead( settingsDefinitions.ReadValue( setting, context ) ) )

    local commit, markClean = makeCommitter( setting, context, function()
        return field:GetText()
    end, function( written )
        field:SetText( formatWritten( written ) )
    end )

    bindImmediateCommit( field, commit )
    addLabeledControl( panel, settingsDefinitions.GetLabel( setting ), field )
    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return function()
        if field:HasFocus() then return end

        field:SetText( formatRead( settingsDefinitions.ReadValue( setting, context ) ) )
        markClean()
    end
end

local function buildNumberControl( panel, setting, context )
    return buildTextEntryControl( panel, setting, context, function( value )
        return tostring( value or 0 )
    end, function( value )
        return tostring( value or 0 )
    end )
end

local function buildTextControl( panel, setting, context )
    return buildTextEntryControl( panel, setting, context, function( value )
        return tostring( value or "" )
    end, function( value )
        return tostring( value or "" )
    end )
end

local function buildListControl( panel, setting, context )
    local function formatList( value )
        return table.concat( value or {}, ", " )
    end

    return buildTextEntryControl( panel, setting, context, formatList, formatList )
end

local function buildKeybindControl( panel, setting, context )
    local binder = vgui.Create( "DBinder", panel )
    local suppressChange = false

    binder:SetValue( settingsDefinitions.ReadValue( setting, context ) )
    updateBinderText( binder )

    local function setValue( value )
        suppressChange = true
        binder:SetValue( value )
        updateBinderText( binder )
        suppressChange = false
    end

    binder.OnChange = function( binderPanel, keyCode )
        if suppressChange then return end

        keyCode = tonumber( keyCode ) or binderPanel:GetSelectedNumber()
        if settingsDefinitions.IsBlockedKey( setting, keyCode ) then
            local fallback = settingsDefinitions.GetKeybindFallback(
                setting,
                settingsDefinitions.ReadValue( setting, context ),
                context
            )
            setValue( fallback )
            settingsDefinitions.WriteValue( setting, fallback, makeWriteContext( context, false ) )
            playError()
            return
        end

        settingsDefinitions.WriteValue( setting, keyCode, makeWriteContext( context, false ) )
        updateBinderText( binderPanel )
        playSuccess()
    end

    addLabeledControl( panel, settingsDefinitions.GetLabel( setting ), binder )
    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return function()
        setValue( settingsDefinitions.ReadValue( setting, context ) )
    end
end

local function buildActionControl( panel, setting, context )
    local buttonText = setting.buttonFallback or settingsDefinitions.GetLabel( setting )
    if setting.buttonKey then buttonText = rRadio.L( setting.buttonKey, buttonText ) end

    local button = vgui.Create( "DButton", panel )
    button:SetText( buttonText )
    addLabeledControl( panel, settingsDefinitions.GetLabel( setting ), button, getActionButtonWidth( buttonText ) )

    if button.SetTooltip then button:SetTooltip( buttonText ) end
    button.DoClick = function()
        settingsDefinitions.WriteValue( setting, true, makeWriteContext( context, false ) )
        playSuccess()
    end

    addHelp( panel, settingsDefinitions.GetHelp( setting ) )

    return nil
end

local function buildSettingControl( panel, setting, context )
    if setting.control == "toggle" then
        return buildToggleControl( panel, setting, context )
    elseif setting.control == "slider" then
        return buildSliderControl( panel, setting, context )
    elseif setting.control == "choice" then
        return buildChoiceControl( panel, setting, context )
    elseif setting.control == "number" then
        return buildNumberControl( panel, setting, context )
    elseif setting.control == "text" then
        return buildTextControl( panel, setting, context )
    elseif setting.control == "list" then
        return buildListControl( panel, setting, context )
    elseif setting.control == "keybind" then
        return buildKeybindControl( panel, setting, context )
    elseif setting.control == "action" then
        return buildActionControl( panel, setting, context )
    end

    return nil
end

local function buildSettingsControls( panel )
    if not IsValid( panel ) then return end

    if style.SyncScaleFromConVars then style.SyncScaleFromConVars() end
    if style.RefreshFonts then style.RefreshFonts() end

    local context
    context = {
        parent = panel,
        scope = "client",
        callbacks = {
            onRelayout = function()
                invalidateToolPanel( panel )
            end,
            onSettingsRebuild = function()
                toolMenu.QueueRebuild( panel )
            end,
            onThemeChanged = function()
                refreshToolMenuValues( panel )
            end
        }
    }

    local rows = {}
    local hasRenderedSection = false

    for _, section in ipairs( settingsDefinitions.GetSections( context ) ) do
        addSectionHeader( panel, section, not hasRenderedSection )

        for _, setting in ipairs( section.settings ) do
            rows[#rows + 1] = {
                RefreshValue = buildSettingControl( panel, setting, context )
            }
        end

        hasRenderedSection = true
    end

    panel.rRadioSettingRows = rows
    panel.RefreshValues = refreshToolMenuValues
end

function toolMenu.QueueRebuild( panel )
    if not IsValid( panel ) or panel.rRadioRebuildQueued then return end

    panel.rRadioRebuildQueued = true
    timer.Simple( 0, function()
        if not IsValid( panel ) then return end

        panel.rRadioRebuildQueued = false
        toolMenu.Build( panel )
    end )
end

function toolMenu.Build( panel )
    panel:ClearControls()
    buildSettingsControls( panel )
end

function toolMenu.Init()
    hook.Add( "PopulateToolMenu", "rRadio_ToolMenu_Settings", function()
        spawnmenu.AddToolMenuOption( "Options", "Rammel", "rRadio", "rRadio", "", "", function( panel )
            toolMenu.Build( panel )
        end )
    end )
end

return toolMenu
