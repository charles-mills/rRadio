rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.customStations = rRadio.client.ui.customStations or {}

local customStations = rRadio.client.ui.customStations
local actions = rRadio.client.ui.actions
local catalog = rRadio.client.stations.catalog
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style

local FORM_HEIGHT = 176
local ROW_HEIGHT = 72
local NOTICE_HEIGHT = 34
local GUIDE_FOOTER_HEIGHT = 40
local BUTTON_HEIGHT = 30
local BUTTON_GAP = 6
local GUIDE_URL = "https://steamcommunity.com/workshop/filedetails/discussion/"
    .. "3318060741/594022969417731427/"


local function setNotice( action, success, message )
    state.customStationNotice = {
        action = action or "local",
        success = success == true,
        message = message or "",
        expiresAt = CurTime() + 4
    }
end


local function getNotice()
    local notice = state.customStationNotice
    if not notice then return nil end
    if notice.expiresAt and notice.expiresAt < CurTime() then
        state.customStationNotice = nil
        return nil
    end

    return notice
end


local function makeButton( parent, text, danger )
    local button = vgui.Create( "rRadioMenuAnimatedButton", parent )
    button:SetText( text )
    button:SetFont( "rRadio.Inter5" )

    if danger then
        local errorColor = rRadio.config.UI.Error or Color( 248, 81, 73 )
        button:SetColors( rRadio.config.UI.TextColor, ColorAlpha( errorColor, 125 ), errorColor )
    else
        button:SetColors(
            rRadio.config.UI.TextColor,
            rRadio.config.UI.CloseButtonColor or rRadio.config.UI.ButtonColor,
            rRadio.config.UI.CloseButtonHoverColor or rRadio.config.UI.ButtonHoverColor
        )
    end

    return button
end


local function makeTextEntry( parent, placeholder )
    local shell = vgui.Create( "DPanel", parent )
    shell.entry = vgui.Create( "DTextEntry", shell )

    local entry = shell.entry
    entry:SetFont( "rRadio.Inter5" )
    entry:SetTextColor( rRadio.config.UI.TextColor )
    entry:SetCursorColor( rRadio.config.UI.TextColor )
    entry:SetHighlightColor( rRadio.config.UI.ButtonHoverColor )
    entry:SetPlaceholderText( placeholder )
    entry:SetPlaceholderColor( ColorAlpha( rRadio.config.UI.TextColor, 145 ) )
    entry:SetDrawBorder( false )
    entry:SetPaintBackground( false )
    entry.rRadioPlaceholder = placeholder
    style.SetTextCursor( shell )
    style.SetTextCursor( entry )

    shell.GetText = function( panel )
        return panel.entry:GetText()
    end

    shell.SetText = function( panel, text )
        panel.entry:SetText( text or "" )
    end

    shell.GetValue = shell.GetText
    shell.SetValue = shell.SetText

    shell.IsEditing = function( panel )
        return panel.entry:IsEditing()
    end

    shell.OnMousePressed = function( panel )
        panel.entry:RequestFocus()
    end

    shell.PerformLayout = function( panel, width, height )
        local leftInset = style.Scale( 10 )
        local rightInset = style.Scale( 8 )
        panel.entry:SetPos( leftInset, 0 )
        panel.entry:SetSize( math.max( 0, width - leftInset - rightInset ), height )
    end

    shell.Paint = function( _panel, width, height )
        style.DrawSurface( "control", 6, 0, 0, width, height, style.GetSurfaceColor( "control" ) )
    end

    entry.Paint = function( panel, _width, height )
        if panel:GetText() == "" and not panel:IsEditing() then
            draw.SimpleText(
                panel.rRadioPlaceholder or "",
                "rRadio.Inter5",
                0,
                height * 0.5,
                ColorAlpha( rRadio.config.UI.TextColor, 145 ),
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
            return
        end

        panel:DrawTextEntryText(
            rRadio.config.UI.TextColor,
            rRadio.config.UI.ButtonHoverColor,
            rRadio.config.UI.TextColor
        )
    end

    entry.OnChange = function()
        if type( shell.OnChange ) == "function" then shell.OnChange( shell ) end
    end

    entry.OnEnter = function()
        if type( shell.OnEnter ) == "function" then shell.OnEnter( shell ) end
    end

    return shell
end


local function stationStillExists( stationID )
    return catalog.Get( stationID ) ~= nil
end


local function handleServerResult( panel )
    local notice = state.customStationNotice
    if not notice or panel.lastHandledNotice == notice then return end

    panel.lastHandledNotice = notice
    if not notice.success then return end

    if notice.action == "add" or notice.action == "edit" then
        panel.editingID = nil
        panel.draftName = ""
        panel.draftURL = ""
    elseif notice.action == "remove" and panel.editingID and not stationStillExists( panel.editingID ) then
        panel.editingID = nil
        panel.draftName = ""
        panel.draftURL = ""
    end
end


local function buildNotice( parent )
    local notice = getNotice()
    local panel = vgui.Create( "DPanel", parent )
    panel:Dock( TOP )
    panel:DockMargin( 0, 0, 0, notice and style.Scale( 6 ) or 0 )
    panel:SetTall( notice and style.Scale( NOTICE_HEIGHT ) or 0 )

    panel.Think = function( self )
        local currentNotice = getNotice()
        local targetHeight = currentNotice and style.Scale( NOTICE_HEIGHT ) or 0
        if self:GetTall() ~= targetHeight then
            self:SetTall( targetHeight )
            self:InvalidateParent()
        end
    end

    panel.Paint = function( _panel, width, height )
        local currentNotice = getNotice()
        if not currentNotice or height <= 0 then return end

        local color = currentNotice.success and ( rRadio.config.UI.AccentPrimary or Color( 58, 114, 255 ) )
            or ( rRadio.config.UI.Error or Color( 248, 81, 73 ) )
        style.DrawSurface( "state", 8, 0, 0, width, height, ColorAlpha( color, 90 ), color )

        local text = style.TruncateText( currentNotice.message or "", "rRadio.Inter5", width - style.Scale( 20 ) )
        draw.SimpleText(
            text,
            "rRadio.Inter5",
            style.Scale( 10 ),
            height * 0.5,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    return panel
end


local function resetDraft( panel )
    panel.editingID = nil
    panel.draftName = ""
    panel.draftURL = ""
    if panel.nameEntry then panel.nameEntry:SetText( "" ) end
    if panel.urlEntry then panel.urlEntry:SetText( "" ) end
end


local function submitDraft( panel )
    local name = panel.nameEntry:GetText()
    local url = panel.urlEntry:GetText()
    name = string.Trim( tostring( name or "" ) )
    url = string.Trim( tostring( url or "" ) )

    if name == "" or url == "" then
        setNotice( "local", false, rRadio.L( "CustomStationRequired", "Enter a station name and stream URL." ) )
        panel:Refresh()
        return
    end

    style.PlaySound( "ButtonPressSecondary" )
    if panel.editingID then
        if not actions.EditCustomStation( panel.editingID, name, url ) then
            setNotice( "local", false, rRadio.L( "CustomStationRequired", "Enter a station name and stream URL." ) )
            panel:Refresh()
        end
        return
    end

    if not actions.AddCustomStation( name, url ) then
        setNotice( "local", false, rRadio.L( "CustomStationRequired", "Enter a station name and stream URL." ) )
        panel:Refresh()
    end
end


local function buildForm( parent, panel )
    local editingStation = panel.editingID and catalog.Get( panel.editingID ) or nil
    if panel.editingID and not editingStation then resetDraft( panel ) end

    local isEditing = panel.editingID ~= nil
    local card = vgui.Create( "DPanel", parent )
    card:Dock( TOP )
    card:DockMargin( 0, 0, 0, style.Scale( 8 ) )
    card:SetTall( style.Scale( FORM_HEIGHT ) )

    local titleText = isEditing
        and rRadio.L( "CustomStationEdit", "Edit custom station" )
        or rRadio.L( "CustomStationAdd", "Add custom station" )

    panel.nameEntry = makeTextEntry( card, rRadio.L( "CustomStationNamePlaceholder", "Station name" ) )
    panel.urlEntry = makeTextEntry( card, rRadio.L( "CustomStationURLPlaceholder", "Stream URL" ) )

    local nameText = panel.draftName
    local urlText = panel.draftURL
    if nameText == nil and editingStation then nameText = editingStation.name end
    if urlText == nil and editingStation then urlText = editingStation.url end

    panel.nameEntry:SetText( nameText or "" )
    panel.urlEntry:SetText( urlText or "" )

    panel.nameEntry.OnChange = function( entry ) panel.draftName = entry:GetText() end
    panel.urlEntry.OnChange = function( entry ) panel.draftURL = entry:GetText() end
    panel.nameEntry.OnEnter = function() submitDraft( panel ) end
    panel.urlEntry.OnEnter = function() submitDraft( panel ) end

    local primaryText = isEditing
        and rRadio.L( "CustomStationSave", "Save station" )
        or rRadio.L( "CustomStationAdd", "Add custom station" )
    local secondaryText = isEditing
        and rRadio.L( "Cancel", "Cancel" )
        or rRadio.L( "Clear", "Clear" )

    local primaryButton = makeButton( card, primaryText, false )
    local secondaryButton = makeButton( card, secondaryText, false )

    primaryButton.DoClick = function() submitDraft( panel ) end
    secondaryButton.DoClick = function()
        style.PlaySound( "ButtonPressSecondary" )
        resetDraft( panel )
        panel:Refresh()
    end

    card.Paint = function( _card, width, height )
        style.DrawSurface( "card", 8, 0, 0, width, height, style.GetSurfaceColor( "card" ) )

        local title = style.TruncateText( titleText, "rRadio.Inter8", width - style.Scale( 20 ) )
        draw.SimpleText(
            title,
            "rRadio.Inter8",
            style.Scale( 10 ),
            style.Scale( 23 ),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    card.PerformLayout = function( _card, width, _height )
        local margin = style.Scale( 10 )
        local fieldHeight = style.Scale( 32 )
        local buttonHeight = style.Scale( BUTTON_HEIGHT )
        local buttonGap = style.Scale( BUTTON_GAP )
        local buttonWidth = math.max( style.Scale( 108 ), math.floor( width * 0.31 ) )
        local secondaryWidth = math.max( style.Scale( 82 ), math.floor( width * 0.22 ) )
        local y = style.Scale( 44 )

        panel.nameEntry:SetPos( margin, y )
        panel.nameEntry:SetSize( width - margin * 2, fieldHeight )
        y = y + fieldHeight + style.Scale( 8 )

        panel.urlEntry:SetPos( margin, y )
        panel.urlEntry:SetSize( width - margin * 2, fieldHeight )

        local buttonY = style.Scale( FORM_HEIGHT ) - margin - buttonHeight
        primaryButton:SetPos( width - margin - buttonWidth, buttonY )
        primaryButton:SetSize( buttonWidth, buttonHeight )
        primaryButton:SetFont( style.GetButtonFillFont( primaryButton:GetText(), buttonWidth, buttonHeight ) )

        secondaryButton:SetPos( width - margin - buttonWidth - buttonGap - secondaryWidth, buttonY )
        secondaryButton:SetSize( secondaryWidth, buttonHeight )
        secondaryButton:SetFont( style.GetButtonFillFont( secondaryButton:GetText(), secondaryWidth, buttonHeight ) )
    end

    return card
end


local function beginEdit( panel, station )
    panel.pendingDeleteID = nil
    panel.editingID = station.id
    panel.draftName = station.name or ""
    panel.draftURL = station.url or ""
    panel.skipDraftCapture = true
    panel:Refresh()
end


local function buildStationRow( parent, panel, station )
    local row = vgui.Create( "DPanel", parent )
    row:Dock( TOP )
    row:DockMargin( 0, 0, 0, style.Scale( 6 ) )
    row:SetTall( style.Scale( ROW_HEIGHT ) )

    local editButton = makeButton( row, rRadio.L( "Edit", "Edit" ), false )
    local deleteButton = makeButton( row, rRadio.L( "Delete", "Delete" ), true )
    local confirmButton
    local cancelButton
    local confirming = panel.pendingDeleteID == station.id

    if confirming then
        confirmButton = makeButton( row, rRadio.L( "Confirm", "Confirm" ), true )
        cancelButton = makeButton( row, rRadio.L( "Cancel", "Cancel" ), false )
        editButton:SetVisible( false )
        deleteButton:SetVisible( false )

        confirmButton.DoClick = function()
            style.PlaySound( "ButtonPressSecondary" )
            panel.pendingDeleteID = nil
            actions.RemoveCustomStation( station.id )
            panel:Refresh()
        end

        cancelButton.DoClick = function()
            style.PlaySound( "ButtonPressSecondary" )
            panel.pendingDeleteID = nil
            panel:Refresh()
        end
    else
        editButton.DoClick = function()
            style.PlaySound( "ButtonPressSecondary" )
            beginEdit( panel, station )
        end

        deleteButton.DoClick = function()
            style.PlaySound( "ButtonPressSecondary" )
            panel.pendingDeleteID = station.id
            panel:Refresh()
        end
    end

    row.Paint = function( _row, width, height )
        local borderColor = style.GetBorderColor()
        if panel.editingID == station.id then borderColor = rRadio.config.UI.AccentPrimary or borderColor end

        style.DrawSurface( "card", 8, 0, 0, width, height, style.GetSurfaceColor( "card" ), borderColor )

        local buttonArea = confirming and style.Scale( 188 ) or style.Scale( 178 )
        local textWidth = math.max( 0, width - style.Scale( 20 ) - buttonArea )
        local name = style.TruncateText( station.name or "", "rRadio.Inter5", textWidth )
        local url = style.TruncateText( station.url or "", "rRadio.Inter4", textWidth )

        draw.SimpleText(
            name,
            "rRadio.Inter5",
            style.Scale( 10 ),
            style.Scale( 24 ),
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        draw.SimpleText(
            url,
            "rRadio.Inter4",
            style.Scale( 10 ),
            style.Scale( 50 ),
            ColorAlpha( rRadio.config.UI.TextColor, 150 ),
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )
    end

    row.PerformLayout = function( _row, width, height )
        local buttonHeight = style.Scale( BUTTON_HEIGHT )
        local buttonWidth = style.Scale( 82 )
        local gap = style.Scale( BUTTON_GAP )
        local x = width - style.Scale( 10 ) - buttonWidth
        local y = math.floor( ( height - buttonHeight ) * 0.5 )

        if confirming then
            confirmButton:SetPos( x, y )
            confirmButton:SetSize( buttonWidth, buttonHeight )
            confirmButton:SetFont( style.GetButtonFillFont( confirmButton:GetText(), buttonWidth, buttonHeight ) )

            x = x - gap - buttonWidth
            cancelButton:SetPos( x, y )
            cancelButton:SetSize( buttonWidth, buttonHeight )
            cancelButton:SetFont( style.GetButtonFillFont( cancelButton:GetText(), buttonWidth, buttonHeight ) )
            return
        end

        deleteButton:SetPos( x, y )
        deleteButton:SetSize( buttonWidth, buttonHeight )
        deleteButton:SetFont( style.GetButtonFillFont( deleteButton:GetText(), buttonWidth, buttonHeight ) )

        x = x - gap - buttonWidth
        editButton:SetPos( x, y )
        editButton:SetSize( buttonWidth, buttonHeight )
        editButton:SetFont( style.GetButtonFillFont( editButton:GetText(), buttonWidth, buttonHeight ) )
    end

    return row
end


local function buildEmptyState( parent )
    local panel = vgui.Create( "DPanel", parent )
    panel:Dock( TOP )
    panel:SetTall( style.Scale( 74 ) )
    panel.Paint = function( _panel, width, height )
        style.DrawSurface( "card", 8, 0, 0, width, height, style.GetSurfaceColor( "card" ) )
        local text = style.TruncateText(
            rRadio.L( "CustomStationEmpty", "No custom stations yet." ),
            "rRadio.Inter5",
            width - style.Scale( 20 )
        )
        draw.SimpleText(
            text,
            "rRadio.Inter5",
            width * 0.5,
            height * 0.5,
            ColorAlpha( rRadio.config.UI.TextColor, 170 ),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end
end


local function buildStationList( parent, panel )
    local stations = catalog.ListCustomStations()
    if #stations == 0 then
        buildEmptyState( parent )
        return
    end

    for _, station in ipairs( stations ) do
        buildStationRow( parent, panel, station )
    end
end


local function buildGuideFooter( parent )
    local footer = vgui.Create( "DButton", parent )
    footer:Dock( BOTTOM )
    footer:DockMargin( style.Scale( 6 ), 0, style.Scale( 6 ), style.Scale( 6 ) )
    footer:SetTall( style.Scale( GUIDE_FOOTER_HEIGHT ) )
    footer:SetText( "" )
    footer.lerp = 0
    footer.lerpColor = Color( 0, 0, 0, 255 )
    style.SetButtonCursor( footer )

    footer.Think = function( panel )
        panel.lerp = style.ApproachLerp( panel.lerp, panel:IsHovered() and 1 or 0, 10 )
    end

    footer.DoClick = function()
        style.PlaySound( "ButtonPressSecondary" )
        if gui and gui.OpenURL then gui.OpenURL( GUIDE_URL ) end
    end

    footer.Paint = function( panel, width, height )
        local fillColor = style.LerpColor(
            panel.lerp,
            style.GetSurfaceColor( "card" ),
            style.GetSurfaceColor( "cardHover" ) or rRadio.config.UI.ButtonHoverColor,
            panel.lerpColor
        )
        style.DrawSurface( "button", 8, 0, 0, width, height, fillColor )

        local text = style.TruncateText(
            rRadio.L(
                "CustomStationGuideFooter",
                "Not sure what to do here? Click to open the guide."
            ),
            "rRadio.Inter5",
            width - style.Scale( 20 )
        )
        draw.SimpleText(
            text,
            "rRadio.Inter5",
            width * 0.5,
            height * 0.5,
            rRadio.config.UI.TextColor,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    return footer
end


local function isScrollBarActive( scroll )
    local bar = scroll:GetVBar()
    if bar.Enabled ~= nil then return bar.Enabled == true end

    return bar:IsVisible()
end


local function updateScrollCanvasPadding( scroll )
    local canvas = scroll:GetCanvas()
    if not canvas.DockPadding then return end

    local rightPadding = isScrollBarActive( scroll ) and style.Scale( 14 ) or 0
    local bottomPadding = style.Scale( 6 )
    if scroll.rRadioRightPadding == rightPadding and scroll.rRadioBottomPadding == bottomPadding then return end

    scroll.rRadioRightPadding = rightPadding
    scroll.rRadioBottomPadding = bottomPadding
    canvas:DockPadding( 0, 0, rightPadding, bottomPadding )
    if canvas.InvalidateLayout then canvas:InvalidateLayout( false ) end
end


local function clearPanelChildren( panel )
    for _, child in ipairs( panel:GetChildren() ) do
        child:Remove()
    end
end


function customStations.Build( parent )
    local content = vgui.Create( "DPanel", parent )
    content.Paint = function( _panel, width, height )
        style.DrawSurface( "panel", 8, 0, 0, width, height, style.GetSurfaceColor( "panel" ) )
    end
    content.draftName = ""
    content.draftURL = ""

    content.guideFooter = buildGuideFooter( content )

    content.formPanel = vgui.Create( "DPanel", content )
    content.formPanel:Dock( TOP )
    content.formPanel.Paint = nil

    content.scroll = vgui.Create( "DScrollPanel", content )
    content.scroll:Dock( FILL )
    style.StyleScrollBar( content.scroll:GetVBar() )

    local basePerformLayout = content.scroll.PerformLayout
    content.scroll.PerformLayout = function( panel, width, height )
        if basePerformLayout then basePerformLayout( panel, width, height ) end
        updateScrollCanvasPadding( panel )
    end

    content.scroll.Think = function( panel )
        updateScrollCanvasPadding( panel )
    end

    content.PerformLayout = function( panel )
        local outerPadding = style.Scale( 6 )

        panel.guideFooter:DockMargin( outerPadding, 0, outerPadding, outerPadding )
        panel.guideFooter:SetTall( style.Scale( GUIDE_FOOTER_HEIGHT ) )

        panel.formPanel:DockMargin( outerPadding, outerPadding, outerPadding, 0 )
        panel.formPanel:SetTall( style.Scale( FORM_HEIGHT + 8 ) )

        panel.scroll:DockMargin( outerPadding, 0, outerPadding, outerPadding )
    end

    function content:Refresh()
        if self.skipDraftCapture then
            self.skipDraftCapture = false
        else
            if self.nameEntry then self.draftName = self.nameEntry:GetText() end
            if self.urlEntry then self.draftURL = self.urlEntry:GetText() end
        end

        handleServerResult( self )

        clearPanelChildren( self.formPanel )
        buildForm( self.formPanel, self )

        self.scroll:Clear()
        buildNotice( self.scroll )
        buildStationList( self.scroll, self )
        updateScrollCanvasPadding( self.scroll )
    end

    content:Refresh()

    return content
end


return customStations
