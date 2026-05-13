rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.settingsControls = rRadio.client.ui.settingsControls or {}

local controls = rRadio.client.ui.settingsControls
local settingsDefinitions = rRadio.client.ui.settingsDefinitions
local style = rRadio.client.ui.style
local dialogs = rRadio.client.ui.dialogs

local ROW_HEIGHT = 68
local ACTION_ROW_HEIGHT = 56
local SERVER_GROUP_HEADER_HEIGHT = 42
local CONTROL_WIDTH = 190
local SLIDER_CONTROL_WIDTH = 220
local WIDE_CONTROL_WIDTH = 230
local TEXT_ENTRY_INSET_X = 16
local ACTION_BUTTON_MIN_HEIGHT = 32
local ACTION_BUTTON_PADDING_Y = 7

local function getTextEntryInset()
    return math.max( style.Scale( TEXT_ENTRY_INSET_X ), 10 )
end

local function closeDermaMenusOnScroll( scroll )
    local vbar = scroll:GetVBar()
    scroll.rRadioLastScroll = vbar:GetScroll()

    local baseOnVScroll = scroll.OnVScroll
    scroll.OnVScroll = function( panel, offset )
        local oldScroll = panel.rRadioLastScroll

        baseOnVScroll( panel, offset )

        local newScroll = panel:GetVBar():GetScroll()
        if newScroll ~= oldScroll then CloseDermaMenus() end

        panel.rRadioLastScroll = newScroll
    end
end

local function makeWriteContext( context, live )
    context = context or {}

    return {
        entity = context.entity,
        parent = context.parent,
        callbacks = context.callbacks,
        live = live == true
    }
end

local function playSuccess()
    style.PlaySound( "SettingsMenuSuccess" )
end

local function playError()
    style.PlaySound( "SettingsMenuError" )
end

local function getKeyDisplayName( keyCode )
    local name = input.GetKeyName( keyCode )
    if not name or name == "" then return rRadio.L( "PressAKey", "Press a key..." ) end

    return ( name:gsub( "_", " " ):gsub( "(%a)([%w]*)", function( first, rest )
        return first:upper() .. rest:lower()
    end ) )
end

local function applyTextEntryInset( entry )
    if entry.SetTextInset then entry:SetTextInset( getTextEntryInset(), 0 ) end
end

local function settingHasHelp( setting )
    local help = settingsDefinitions.GetHelp( setting )
    return help and help ~= ""
end

local function getCardHeight( setting )
    if setting.control == "action" and not settingHasHelp( setting ) then return ACTION_ROW_HEIGHT end

    return ROW_HEIGHT
end

local function createCard( parent, setting )
    local card = vgui.Create( "DPanel", parent )
    card:Dock( TOP )
    card:SetTall( style.Scale( getCardHeight( setting ) ) )
    card:DockMargin( 0, 0, 0, style.Scale( 6 ) )
    card.Paint = function( _panel, width, height )
        style.DrawSurface( "card", 8, 0, 0, width, height, style.GetSurfaceColor( "card" ) )
    end

    return card
end

local function addLabelPanel( card, setting )
    local labelPanel = vgui.Create( "DPanel", card )
    labelPanel:Dock( FILL )
    labelPanel:DockMargin( style.Scale( 10 ), 0, style.Scale( 10 ), 0 )
    labelPanel.Paint = function( _panel, width, height )
        local label = settingsDefinitions.GetLabel( setting )
        local help = settingsDefinitions.GetHelp( setting )
        local hasHelp = help and help ~= ""
        local titleY = hasHelp and style.Scale( 21 ) or height * 0.5
        local title = style.TruncateText( label, "rRadio.Inter5", width )

        draw.SimpleText(
            title,
            "rRadio.Inter5",
            0,
            titleY,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        if not hasHelp then return end

        local helpText = style.TruncateText( help, "rRadio.Inter4", width )
        draw.SimpleText(
            helpText,
            "rRadio.Inter4",
            0,
            style.Scale( 45 ),
            ColorAlpha( rRadio.config.UI.TextColor, 155 ),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    return labelPanel
end

local function addControlPanel( card, setting )
    local controlPanel = vgui.Create( "DPanel", card )
    controlPanel:Dock( RIGHT )
    local verticalMargin = style.Scale( setting.control == "action" and 12 or 8 )
    controlPanel:DockMargin( 0, verticalMargin, style.Scale( 10 ), verticalMargin )
    local width = CONTROL_WIDTH
    if setting.control == "slider" then width = SLIDER_CONTROL_WIDTH end
    if setting.control == "text"
        or setting.control == "list"
        or setting.control == "vector"
    then
        width = WIDE_CONTROL_WIDTH
    end
    controlPanel:SetWide( style.Scale( width ) )
    controlPanel.Paint = nil

    return controlPanel
end

local function styleTextEntry( entry )
    entry:SetFont( "rRadio.Inter5" )
    entry:SetTextColor( rRadio.config.UI.TextColor )
    entry:SetCursorColor( rRadio.config.UI.TextColor )
    entry:SetHighlightColor( rRadio.config.UI.ButtonHoverColor )
    if entry.SetTextInset then entry:SetTextInset( 0, 0 ) end
    entry:SetDrawBorder( false )
    entry:SetPaintBackground( false )
    style.SetTextCursor( entry )

    local basePerformLayout = entry.PerformLayout
    entry.PerformLayout = function( panel, width, height )
        if basePerformLayout then basePerformLayout( panel, width, height ) end
        if panel.SetTextInset then panel:SetTextInset( 0, 0 ) end
    end

    entry.Paint = function( panel )
        panel:DrawTextEntryText(
            rRadio.config.UI.TextColor,
            rRadio.config.UI.ButtonHoverColor,
            rRadio.config.UI.TextColor
        )
    end
end

local function createTextEntryControl( parent )
    local shell = vgui.Create( "DPanel", parent )
    shell:Dock( FILL )
    shell.Paint = function( _panel, width, height )
        style.DrawSurface(
            "control",
            6,
            0, 0, width, height,
            style.GetSurfaceColor( "panel" ) or rRadio.config.UI.SearchBoxColor
        )
    end
    style.SetTextCursor( shell )

    local entry = vgui.Create( "DTextEntry", shell )
    styleTextEntry( entry )

    shell.PerformLayout = function( _panel, width, height )
        local leftInset = getTextEntryInset()
        local rightInset = math.max( style.Scale( 10 ), 8 )
        entry:SetPos( leftInset, 0 )
        entry:SetSize( math.max( 0, width - leftInset - rightInset ), height )
    end

    shell.OnMousePressed = function()
        entry:RequestFocus()
    end

    return entry
end

local function paintDropdown( panel, width, height )
    style.DrawSurface(
        "control",
        6,
        0, 0, width, height,
        style.GetSurfaceColor( "panel" ) or rRadio.config.UI.SearchBoxColor
    )

    local arrowSize = style.Scale( 8 )
    local arrowX = width - arrowSize - style.Scale( 8 )
    local arrowY = math.floor( height * 0.5 - arrowSize * 0.5 )
    surface.SetDrawColor( rRadio.config.UI.TextColor )
    draw.NoTexture()

    if panel:IsMenuOpen() then
        surface.DrawPoly( {
            { x = arrowX, y = arrowY + arrowSize },
            { x = arrowX + arrowSize, y = arrowY + arrowSize },
            { x = arrowX + arrowSize * 0.5, y = arrowY }
        } )
    else
        surface.DrawPoly( {
            { x = arrowX, y = arrowY },
            { x = arrowX + arrowSize, y = arrowY },
            { x = arrowX + arrowSize * 0.5, y = arrowY + arrowSize }
        } )
    end

    panel:DrawTextEntryText(
        rRadio.config.UI.TextColor,
        rRadio.config.UI.ButtonHoverColor,
        rRadio.config.UI.TextColor
    )
end

local function styleDropdownMenu( menu )
    menu.Paint = function( _panel, width, height )
        style.DrawSurface(
            "control",
            6,
            0, 0, width, height,
            style.GetSurfaceColor( "panel" ) or rRadio.config.UI.SearchBoxColor
        )
    end

    style.StyleScrollBar( menu.VBar )

    local children = menu:GetCanvas():GetChildren()
    local count = #children
    for index, option in ipairs( children ) do
        if option.SetTextColor then option:SetTextColor( rRadio.config.UI.TextColor ) end
        if option.SetFont then option:SetFont( "rRadio.Inter5" ) end
        style.SetButtonCursor( option )

        local rowHeight = math.max( style.Scale( 40 ), 32 )
        local textInset = getTextEntryInset()
        option:SetTall( rowHeight )
        if option.SetTextInset then option:SetTextInset( textInset, 0 ) end

        local basePerformLayout = option.PerformLayout
        option.PerformLayout = function( panel, width, height )
            if basePerformLayout then basePerformLayout( panel, width, height ) end
            if panel:GetTall() ~= rowHeight then panel:SetTall( rowHeight ) end
            if panel.SetTextInset then panel:SetTextInset( textInset, 0 ) end
        end

        local isLast = index == count
        option.Paint = function( panel, width, height )
            local pad = math.max( 1, math.floor( style.Scale( 2 ) ) )
            local padY = math.max( 3, math.floor( style.Scale( 4 ) ) )
            local radius = math.max( 2, math.floor( style.Scale( 4 ) ) )

            if panel:IsHovered() then
                draw.RoundedBox(
                    radius,
                    pad, padY,
                    width - pad * 2, height - padY * 2,
                    style.GetSurfaceColor( "cardHover" ) or rRadio.config.UI.ButtonHoverColor
                )
            end

            if isLast then return end

            local fallback = style.GetDividerColor()
            local divider = style.GetChromeBorderColor( "divider", ColorAlpha( fallback, 190 ) )
            if not divider then return end

            surface.SetDrawColor( divider )
            local dividerInset = math.max( math.floor( style.Scale( 8 ) ), pad + 1 )
            surface.DrawRect( dividerInset, height - 1, math.max( 1, width - dividerInset * 2 ), 1 )
        end
    end
end

local function refreshDropdownTheme( combo )
    style.RefreshPanelTheme( combo )
    style.RefreshPanelTheme( combo.Menu )
end

local function getChoicePreviewValue( combo, index )
    local value = combo:GetOptionData( index )
    if value ~= nil then return value end

    return combo:GetOptionText( index )
end

function controls.AttachChoicePreview( combo, setting, context, onPreviewApplied )
    if combo.rRadioChoicePreviewAttached then return end
    if not settingsDefinitions.HasPreview( setting ) then return end

    combo.rRadioChoicePreviewAttached = true

    local selectionMade = false
    local restoreValue
    local lastPreviewValue
    local previewApplied = false

    local function refreshPreview()
        if type( onPreviewApplied ) == "function" then
            onPreviewApplied( combo )
            return
        end

        refreshDropdownTheme( combo )
    end

    local function applyPreview( value )
        if value == lastPreviewValue then return end

        lastPreviewValue = value
        settingsDefinitions.PreviewValue( setting, value, makeWriteContext( context, true ) )
        previewApplied = true
        refreshPreview()
    end

    local function restorePreview()
        if selectionMade or not previewApplied or restoreValue == nil then return end

        settingsDefinitions.RestorePreview( setting, restoreValue, makeWriteContext( context, true ) )
        refreshPreview()
    end

    local function attachMenuHandlers( menu )
        local baseOnRemove = menu.OnRemove
        menu.OnRemove = function( panel )
            restorePreview()
            restoreValue = nil
            lastPreviewValue = nil
            previewApplied = false
            if baseOnRemove then baseOnRemove( panel ) end
        end

        for index, option in ipairs( menu:GetCanvas():GetChildren() ) do
            local baseOnCursorEntered = option.OnCursorEntered
            option.OnCursorEntered = function( panel, ... )
                if baseOnCursorEntered then baseOnCursorEntered( panel, ... ) end

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

local function makeStyledDropdown( parent )
    local combo = vgui.Create( "DComboBox", parent )
    combo:Dock( FILL )
    combo:SetTextColor( rRadio.config.UI.TextColor )
    combo:SetFont( "rRadio.Inter5" )
    combo:SetSortItems( false )
    applyTextEntryInset( combo )
    style.SetButtonCursor( combo )

    if combo.DropButton then
        style.SetButtonCursor( combo.DropButton )
        combo.DropButton.Paint = function() end
    end

    combo.Paint = paintDropdown

    local baseOpenMenu = combo.OpenMenu
    local basePerformLayout = combo.PerformLayout
    combo.PerformLayout = function( panel, width, height )
        if basePerformLayout then basePerformLayout( panel, width, height ) end
        applyTextEntryInset( panel )
    end

    combo.OpenMenu = function( panel, ... )
        baseOpenMenu( panel, ... )
        styleDropdownMenu( panel.Menu )
    end

    return combo
end

local function getConfirmText( setting, keyField, fallbackField )
    local key = setting and setting[keyField]
    local fallback = setting and setting[fallbackField]
    if key then return rRadio.L( key, fallback or "" ) end

    return fallback or ""
end

local function showConfirmDialog( setting, context, onConfirm )
    local parent = context and context.parent or nil
    if not parent then return end

    dialogs.Show( parent, {
        title = getConfirmText( setting, "confirmTitleKey", "confirmTitleFallback" ),
        message = getConfirmText( setting, "confirmMessageKey", "confirmMessageFallback" ),
        confirmText = getConfirmText( setting, "confirmActionKey", "confirmActionFallback" ),
        danger = true,
        onConfirm = onConfirm
    } )
end

local function shouldConfirmToggle( setting, checked, current )
    return setting.confirmOff == true and current == true and checked == false
end

local function buildToggleControl( parent, setting, context )
    local toggle = vgui.Create( "DButton", parent )
    toggle:Dock( RIGHT )
    toggle:SetWide( style.Scale( 56 ) )
    toggle:SetText( "" )
    toggle.checked = settingsDefinitions.ReadValue( setting, context ) == true
    toggle.lerp = toggle.checked and 1 or 0
    toggle.hoverLerp = 0
    toggle.trackColor = Color( 0, 0, 0, 255 )
    toggle.trackHoverColor = Color( 0, 0, 0, 255 )
    toggle.fillColor = Color( 0, 0, 0, 255 )
    toggle.idleBorderColor = Color( 0, 0, 0, 255 )
    toggle.hoverBorderColor = Color( 0, 0, 0, 255 )
    toggle.borderColor = Color( 0, 0, 0, 255 )
    toggle.knobColor = Color( 0, 0, 0, 255 )
    style.SetButtonCursor( toggle )

    function toggle:SetChecked( checked )
        self.checked = checked == true
    end

    function toggle:GetChecked()
        return self.checked == true
    end

    toggle.Think = function( panel )
        panel:SetChecked( settingsDefinitions.ReadValue( setting, context ) == true )
        panel.lerp = style.ApproachLerp( panel.lerp, panel:GetChecked() and 1 or 0, 10 )
        panel.hoverLerp = style.ApproachLerp( panel.hoverLerp, panel:IsHovered() and 1 or 0, 10 )
    end

    local function commitToggle( panel, checked )
        local written = settingsDefinitions.WriteValue( setting, checked, makeWriteContext( context, false ) )
        panel:SetChecked( written == true )
        playSuccess()
    end

    toggle.DoClick = function( panel )
        local current = panel:GetChecked()
        local checked = not current

        if shouldConfirmToggle( setting, checked, current ) then
            showConfirmDialog( setting, context, function()
                commitToggle( panel, checked )
            end )
            return
        end

        commitToggle( panel, checked )
    end

    toggle.Paint = function( panel, width, height )
        local trackWidth = math.min( width, style.Scale( 50 ) )
        local trackHeight = math.min( height, style.Scale( 26 ) )
        local x = math.floor( width - trackWidth )
        local y = math.floor( ( height - trackHeight ) * 0.5 )
        local radius = math.floor( trackHeight * 0.5 )
        local offColor = style.GetSurfaceColor( "control" )
        local offHoverColor = style.GetSurfaceColor( "controlHover" ) or offColor
        local onColor = rRadio.config.UI.AccentPrimary
        local onHoverColor = rRadio.config.UI.AccentSecondary or offHoverColor or onColor
        local idleTrackColor = style.LerpColor( panel.lerp, offColor, onColor, panel.trackColor )
        local hoverTrackColor = style.LerpColor( panel.lerp, offHoverColor, onHoverColor, panel.trackHoverColor )
        local fillColor = style.LerpColor( panel.hoverLerp, idleTrackColor, hoverTrackColor, panel.fillColor )
        local idleBorder = style.GetKnobBorderColor()
        local hoverBorder = rRadio.config.UI.AccentSecondary or offHoverColor or onColor
        local idleBorderColor = style.LerpColor( panel.lerp, idleBorder, onColor, panel.idleBorderColor )
        local hoverBorderColor = style.LerpColor( panel.lerp, hoverBorder, onHoverColor, panel.hoverBorderColor )
        local borderColor = style.LerpColor( panel.hoverLerp, idleBorderColor, hoverBorderColor, panel.borderColor )
        local knobColor = style.LerpColor(
            panel.hoverLerp,
            style.GetKnobColor(),
            style.GetKnobHoverColor(),
            panel.knobColor
        )

        style.DrawSurface(
            "state",
            radius,
            x, y,
            trackWidth,
            trackHeight,
            fillColor,
            borderColor
        )

        local knobSize = trackHeight - style.Scale( 6 )
        local knobX = x + style.Scale( 3 ) + ( trackWidth - knobSize - style.Scale( 6 ) ) * panel.lerp
        local knobY = y + style.Scale( 3 )
        draw.RoundedBox(
            math.floor( knobSize * 0.5 ),
            math.floor( knobX ),
            knobY,
            knobSize,
            knobSize,
            knobColor
        )
    end

    return function()
        toggle:SetChecked( settingsDefinitions.ReadValue( setting, context ) == true )
    end
end

local function buildSliderControl( parent, setting, context )
    local valueLabel = vgui.Create( "DLabel", parent )
    valueLabel:Dock( TOP )
    valueLabel:SetTall( style.Scale( 18 ) )
    valueLabel:SetFont( "rRadio.Inter4" )
    valueLabel:SetTextColor( ColorAlpha( rRadio.config.UI.TextColor, 175 ) )
    valueLabel:SetContentAlignment( 6 )

    local slider = vgui.Create( "DNumSlider", parent )
    slider:Dock( FILL )
    slider:SetMin( settingsDefinitions.GetMinimum( setting, context ) )
    slider:SetMax( settingsDefinitions.GetMaximum( setting, context ) )
    slider:SetDecimals( settingsDefinitions.GetDecimals( setting ) )
    style.StyleSlider( slider )

    local function setValueText( value )
        valueLabel:SetText( settingsDefinitions.FormatValue( setting, value ) )
    end

    local basePerformLayout = slider.PerformLayout
    slider.PerformLayout = function( panel, width, height )
        if basePerformLayout then basePerformLayout( panel, width, height ) end
        style.SyncSliderKnob( panel, 0.55 )
    end

    local initializing = true
    local suppressChange = false
    local pendingValue
    local wasEditing = false
    local current = settingsDefinitions.ReadValue( setting, context )

    slider.OnValueChanged = function( _panel, value )
        value = math.Clamp(
            value,
            settingsDefinitions.GetMinimum( setting, context ),
            settingsDefinitions.GetMaximum( setting, context )
        )
        setValueText( value )
        if initializing or suppressChange then return end

        pendingValue = value
        settingsDefinitions.WriteValue( setting, value, makeWriteContext( context, true ) )
    end

    local baseThink = slider.Think
    slider.Think = function( panel )
        if baseThink then baseThink( panel ) end

        local editing = panel:IsEditing()
        if wasEditing and not editing and pendingValue ~= nil then
            local writeContext = makeWriteContext( context, false )
            local committed = settingsDefinitions.WriteValue( setting, pendingValue, writeContext )
            pendingValue = nil
            if tonumber( committed ) then
                suppressChange = true
                panel:SetValue( committed )
                suppressChange = false
                setValueText( committed )
            end

            playSuccess()
        end

        wasEditing = editing
    end

    slider:SetValue( current )
    initializing = false
    setValueText( current )

    return function()
        if slider:IsEditing() then return end

        local value = settingsDefinitions.ReadValue( setting, context )
        slider:SetMin( settingsDefinitions.GetMinimum( setting, context ) )
        slider:SetMax( settingsDefinitions.GetMaximum( setting, context ) )
        suppressChange = true
        slider:SetValue( value )
        suppressChange = false
        setValueText( value )
    end
end

local function buildChoiceControl( parent, setting, context )
    local combo = makeStyledDropdown( parent )
    local currentValue = settingsDefinitions.ReadValue( setting, context )
    local selectedLabel
    local labelsByValue = {}

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

    controls.AttachChoicePreview( combo, setting, context )

    return function()
        local label = labelsByValue[settingsDefinitions.ReadValue( setting, context )]
        if label then combo:SetValue( label ) end
    end
end

local function makeCommitter( setting, context, readValue, applyValue, makeToken )
    local lastToken

    return function()
        local rawValue = readValue()
        local token = makeToken and makeToken( rawValue ) or tostring( rawValue )
        if token == lastToken then return nil end

        local written = settingsDefinitions.WriteValue( setting, rawValue, makeWriteContext( context, false ) )
        if written == nil or written == false then
            playError()
            return nil
        end

        if applyValue then applyValue( written ) end
        lastToken = makeToken and makeToken( readValue() ) or tostring( readValue() )
        playSuccess()
        return written
    end
end

local function bindImmediateCommit( field, commit )
    field.OnEnter = commit
    field.OnLoseFocus = commit
end

local function isIntegerSetting( setting )
    local definition = setting and setting.serverDefinition
    return definition and definition.type == "integer"
end

local function allowsNegativeValue( setting, context )
    return settingsDefinitions.GetMinimum( setting, context ) < 0
end

local function allowNumericInput( field, setting, context )
    field.AllowInput = function( panel, character )
        if string.match( character, "^%d$" ) then return false end

        local text = panel:GetText() or ""
        if character == "-" then
            if not allowsNegativeValue( setting, context ) then return true end
            if string.find( text, "-", 1, true ) then return true end

            return panel:GetCaretPos() ~= 0
        end

        if character == "." then
            if isIntegerSetting( setting ) then return true end

            return string.find( text, ".", 1, true ) ~= nil
        end

        return true
    end
end

local function buildNumberControl( parent, setting, context )
    local field = createTextEntryControl( parent )
    field:SetText( tostring( settingsDefinitions.ReadValue( setting, context ) or 0 ) )
    allowNumericInput( field, setting, context )

    local commit = makeCommitter( setting, context, function()
        return field:GetText()
    end, function( written )
        field:SetText( tostring( written or 0 ) )
    end )

    bindImmediateCommit( field, commit )

    return function()
        if field:HasFocus() then return end

        field:SetText( tostring( settingsDefinitions.ReadValue( setting, context ) or 0 ) )
    end
end

local function buildTextEntryControl( parent, setting, context, options )
    options = options or {}

    local field = createTextEntryControl( parent )
    field:SetText( options.formatRead( settingsDefinitions.ReadValue( setting, context ) ) )

    local commit = makeCommitter( setting, context, function()
        return field:GetText()
    end, function( written )
        field:SetText( options.formatWritten( written ) )
    end )

    bindImmediateCommit( field, commit )

    return function()
        if field:HasFocus() then return end

        field:SetText( options.formatRead( settingsDefinitions.ReadValue( setting, context ) ) )
    end
end

local function buildTextControl( parent, setting, context )
    return buildTextEntryControl( parent, setting, context, {
        formatRead = function( value )
            return tostring( value or "" )
        end,
        formatWritten = function( value )
            return tostring( value or "" )
        end
    } )
end

local function buildListControl( parent, setting, context )
    local function formatList( value )
        return table.concat( value or {}, ", " )
    end

    return buildTextEntryControl( parent, setting, context, {
        formatRead = formatList,
        formatWritten = formatList
    } )
end

local function vectorToken( value )
    return table.concat( {
        tostring( value.x or 0 ),
        tostring( value.y or 0 ),
        tostring( value.z or 0 )
    }, "," )
end

local function buildVectorControl( parent, setting, context )
    local values = settingsDefinitions.ReadValue( setting, context ) or Vector( 0, 0, 0 )
    local inputs = {}
    local suppressChange = false

    local commit = makeCommitter( setting, context, function()
        return {
            x = inputs[1]:GetText(),
            y = inputs[2]:GetText(),
            z = inputs[3]:GetText()
        }
    end, function( written )
        suppressChange = true
        inputs[1]:SetText( tostring( written.x or 0 ) )
        inputs[2]:SetText( tostring( written.y or 0 ) )
        inputs[3]:SetText( tostring( written.z or 0 ) )
        suppressChange = false
    end, vectorToken )

    for index, axis in ipairs( { "x", "y", "z" } ) do
        local axisPanel = vgui.Create( "DPanel", parent )
        axisPanel:Dock( LEFT )
        axisPanel:DockMargin( index == 1 and 0 or style.Scale( 4 ), 0, 0, 0 )
        axisPanel:SetWide( math.floor( ( style.Scale( WIDE_CONTROL_WIDTH ) - style.Scale( 8 ) ) / 3 ) )
        axisPanel.Paint = nil

        local label = vgui.Create( "DLabel", axisPanel )
        label:Dock( LEFT )
        label:SetWide( style.Scale( 14 ) )
        label:SetText( string.upper( axis ) )
        label:SetFont( "rRadio.Inter4" )
        label:SetTextColor( ColorAlpha( rRadio.config.UI.TextColor, 155 ) )
        label:SetContentAlignment( 5 )

        local field = createTextEntryControl( axisPanel )
        field:SetText( tostring( values[axis] or 0 ) )
        allowNumericInput( field, setting, context )
        bindImmediateCommit( field, function()
            if suppressChange then return end

            commit()
        end )
        inputs[index] = field
    end

    return function()
        for _, field in ipairs( inputs ) do
            if field:HasFocus() then return end
        end

        local latest = settingsDefinitions.ReadValue( setting, context ) or Vector( 0, 0, 0 )
        suppressChange = true
        inputs[1]:SetText( tostring( latest.x or 0 ) )
        inputs[2]:SetText( tostring( latest.y or 0 ) )
        inputs[3]:SetText( tostring( latest.z or 0 ) )
        suppressChange = false
    end
end

local function buildKeybindControl( parent, setting, context )
    local binder = vgui.Create( "DBinder", parent )
    binder:Dock( FILL )
    binder:SetConVar( settingsDefinitions.GetConVarName( setting ) )
    binder:SetText( "" )
    binder:SetFont( "rRadio.Inter5" )
    binder:SetTextColor( rRadio.config.UI.TextColor )
    binder:SetValue( settingsDefinitions.ReadValue( setting, context ) )
    binder.waiting = false
    binder.previousValue = binder:GetValue()
    style.SetButtonCursor( binder )

    function binder:UpdateText()
        self:SetText( "" )
    end

    binder.Paint = function( panel, width, height )
        style.DrawSurface(
            panel.waiting and "state" or "control",
            6,
            0, 0, width, height,
            style.GetSurfaceColor( "panel" ) or rRadio.config.UI.SearchBoxColor
        )

        local text = panel.waiting and rRadio.L( "PressAKey", "Press a key..." )
            or getKeyDisplayName( panel:GetValue() )
        local color = panel.waiting and ColorAlpha( rRadio.config.UI.TextColor, 180 ) or rRadio.config.UI.TextColor

        draw.SimpleText(
            text,
            "rRadio.Inter5",
            getTextEntryInset(),
            height * 0.5,
            color,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    local baseOnMousePressed = binder.OnMousePressed
    binder.OnMousePressed = function( panel, code )
        if baseOnMousePressed then baseOnMousePressed( panel, code ) end
        panel.previousValue = settingsDefinitions.ReadValue( setting, context )
        panel.waiting = true
        panel:SetText( "" )
        style.PlaySound( "ButtonPressSecondary" )
    end

    local baseOnChange = binder.OnChange
    binder.OnChange = function( panel, keyCode )
        keyCode = tonumber( keyCode ) or panel:GetSelectedNumber()
        if settingsDefinitions.IsBlockedKey( setting, keyCode ) then
            local fallback = settingsDefinitions.GetKeybindFallback( setting, panel.previousValue, context )
            panel:SetValue( fallback )
            panel:SetText( "" )
            panel.waiting = false
            settingsDefinitions.WriteValue( setting, fallback, makeWriteContext( context, false ) )
            playError()
            return
        end

        if baseOnChange then baseOnChange( panel, keyCode ) end
        settingsDefinitions.WriteValue( setting, keyCode, makeWriteContext( context, false ) )
        panel.previousValue = keyCode
        panel:SetText( "" )
        panel.waiting = false
        playSuccess()
    end

    return function()
        if binder.waiting then return end

        binder:SetValue( settingsDefinitions.ReadValue( setting, context ) )
        binder:SetText( "" )
    end
end

local function getActionButtonHeight( button, availableHeight )
    surface.SetFont( "rRadio.Inter5" )
    local _textWidth, textHeight = surface.GetTextSize( button:GetText() or "" )
    local paddingY = math.max( style.Scale( ACTION_BUTTON_PADDING_Y ), 6 )
    local desiredHeight = math.max( style.Scale( ACTION_BUTTON_MIN_HEIGHT ), textHeight + paddingY * 2 )

    return math.min( math.max( 0, availableHeight ), desiredHeight )
end

local function buildActionControl( parent, setting, context )
    local button = vgui.Create( "rRadioMenuAnimatedButton", parent )
    local buttonText = setting.buttonFallback or settingsDefinitions.GetLabel( setting )
    if setting.buttonKey then buttonText = rRadio.L( setting.buttonKey, buttonText ) end

    button:SetText( buttonText )
    button:SetColorRole( "action" )

    parent.PerformLayout = function( _panel, width, height )
        local buttonHeight = getActionButtonHeight( button, height )
        button:SetPos( 0, math.floor( ( height - buttonHeight ) * 0.5 ) )
        button:SetSize( width, buttonHeight )
    end

    button.DoClick = function()
        settingsDefinitions.WriteValue( setting, true, makeWriteContext( context, false ) )
        playSuccess()
    end

    return nil
end

function controls.BuildPanel( parent )
    local content = vgui.Create( "DPanel", parent )
    content.Paint = function( _panel, width, height )
        style.DrawSurface( "panel", 8, 0, 0, width, height, style.GetSurfaceColor( "panel" ) )
    end

    local scroll = vgui.Create( "DScrollPanel", content )
    scroll:Dock( FILL )
    scroll:DockMargin( style.Scale( 6 ), style.Scale( 6 ), style.Scale( 6 ), style.Scale( 6 ) )
    style.StyleScrollBar( scroll:GetVBar() )
    closeDermaMenusOnScroll( scroll )

    local canvas = scroll:GetCanvas()
    if canvas.DockPadding then canvas:DockPadding( 0, 0, style.Scale( 14 ), style.Scale( 6 ) ) end

    return content, scroll
end

function controls.BuildSectionHeader( parent, section, isFirst )
    local header = vgui.Create( "rRadioMenuHeader", parent )
    header:SetTextLabel( rRadio.L( section.labelKey, section.labelFallback ) )
    header:SetIsFirst( isFirst )
    header:Dock( TOP )
    header:DockMargin( 0, isFirst and style.Scale( 4 ) or style.Scale( 14 ), 0, style.Scale( 6 ) )

    return header
end

function controls.BuildServerConfigHeader( parent, expanded, onToggle, isFirst )
    local button = vgui.Create( "DButton", parent )
    button:Dock( TOP )
    button:SetTall( style.Scale( SERVER_GROUP_HEADER_HEIGHT ) )
    button:DockMargin( 0, isFirst and style.Scale( 4 ) or style.Scale( 14 ), 0, style.Scale( 6 ) )
    button:SetText( "" )
    button.expanded = expanded == true
    style.SetButtonCursor( button )

    function button:SetExpanded( nextExpanded )
        self.expanded = nextExpanded == true
    end

    button.DoClick = function()
        style.PlaySound( "ButtonPressSecondary" )
        if onToggle then onToggle() end
    end

    button.Paint = function( panel, width, height )
        local hovered = panel:IsHovered()
        local fillColor = hovered and ( style.GetSurfaceColor( "cardHover" ) or rRadio.config.UI.ButtonHoverColor )
            or style.GetSurfaceColor( "card" )

        style.DrawSurface( "button", 8, 0, 0, width, height, fillColor, style.GetBorderColor() )

        local arrow = panel.expanded and "v" or ">"
        draw.SimpleText(
            arrow,
            "rRadio.Inter5",
            style.Scale( 14 ),
            height * 0.5,
            ColorAlpha( rRadio.config.UI.TextColor, 180 ),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            rRadio.L( "ServerConfig", "Server config" ),
            "rRadio.Inter5",
            style.Scale( 32 ),
            height * 0.5,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    return button
end

function controls.BuildSettingRow( parent, setting, context )
    local card = createCard( parent, setting )
    local controlPanel = addControlPanel( card, setting )
    addLabelPanel( card, setting )
    local refreshValue

    if setting.control == "toggle" then
        refreshValue = buildToggleControl( controlPanel, setting, context )
    elseif setting.control == "slider" then
        refreshValue = buildSliderControl( controlPanel, setting, context )
    elseif setting.control == "choice" then
        refreshValue = buildChoiceControl( controlPanel, setting, context )
    elseif setting.control == "number" then
        refreshValue = buildNumberControl( controlPanel, setting, context )
    elseif setting.control == "text" then
        refreshValue = buildTextControl( controlPanel, setting, context )
    elseif setting.control == "list" then
        refreshValue = buildListControl( controlPanel, setting, context )
    elseif setting.control == "vector" then
        refreshValue = buildVectorControl( controlPanel, setting, context )
    elseif setting.control == "keybind" then
        refreshValue = buildKeybindControl( controlPanel, setting, context )
    elseif setting.control == "action" then
        refreshValue = buildActionControl( controlPanel, setting, context )
    end

    card.RefreshValue = refreshValue
    return card
end

return controls
