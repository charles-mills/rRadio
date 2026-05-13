rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.list = rRadio.client.ui.menu.list or {}

local list = rRadio.client.ui.menu.list
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local rows = rRadio.client.ui.menu.rows
local viewModel = rRadio.client.ui.menu.viewModel

local ROW_OVERSCAN = 8
local DIVIDER_EXTRA_GAP = 12


local function getExtraGapBelow( entry )
    if entry and entry.dividerBelow then return style.Scale( DIVIDER_EXTRA_GAP ) end

    return 0
end


local function buildLayout( entries, rowHeight, rowGap, topPad )
    local positions = {}
    local cursorY = topPad
    local count = #entries

    for index, entry in ipairs( entries ) do
        positions[index] = cursorY
        cursorY = cursorY + rowHeight

        if index < count then cursorY = cursorY + rowGap + getExtraGapBelow( entry ) end
    end

    if count == 0 then return positions, topPad * 2 end

    return positions, cursorY + topPad
end


local function findFirstVisibleRow( positions, count, rowHeight, scroll )
    local low = 1
    local high = count
    local first = count

    while low <= high do
        local middle = math.floor( ( low + high ) * 0.5 )
        if positions[middle] + rowHeight < scroll then
            low = middle + 1
        else
            first = middle
            high = middle - 1
        end
    end

    return first
end


local function findVisibleRangeEnd( positions, count, bottom )
    local low = 1
    local high = count
    local last = count

    while low <= high do
        local middle = math.floor( ( low + high ) * 0.5 )
        if positions[middle] <= bottom then
            low = middle + 1
        else
            last = middle
            high = middle - 1
        end
    end

    return last
end


local function getVisibleRange( positions, count, rowHeight, scroll, viewHeight )
    if count <= 0 then return 1, 0 end

    local first = findFirstVisibleRow( positions, count, rowHeight, scroll )
    local last = findVisibleRangeEnd( positions, count, scroll + viewHeight )

    return math.max( 1, first - ROW_OVERSCAN ), math.min( count, last + ROW_OVERSCAN )
end


local function getLayout( virtualState, rowHeight, rowGap, topPad )
    if virtualState.layoutEntries == virtualState.entries
        and virtualState.layoutRowHeight == rowHeight
        and virtualState.layoutRowGap == rowGap
        and virtualState.layoutTopPad == topPad
        and virtualState.layoutPositions
        and virtualState.layoutCanvasHeight then
        return virtualState.layoutPositions, virtualState.layoutCanvasHeight
    end

    local positions, canvasHeight = buildLayout( virtualState.entries, rowHeight, rowGap, topPad )
    virtualState.layoutEntries = virtualState.entries
    virtualState.layoutRowHeight = rowHeight
    virtualState.layoutRowGap = rowGap
    virtualState.layoutTopPad = topPad
    virtualState.layoutPositions = positions
    virtualState.layoutCanvasHeight = canvasHeight

    return positions, canvasHeight
end


local function clearLayout( virtualState )
    if not virtualState then return end

    virtualState.layoutEntries = nil
    virtualState.layoutRowHeight = nil
    virtualState.layoutRowGap = nil
    virtualState.layoutTopPad = nil
    virtualState.layoutPositions = nil
    virtualState.layoutCanvasHeight = nil
end


function list.Clear( panel )
    local virtualState = panel.virtualState
    if not virtualState then return end

    for _, row in pairs( virtualState.rows ) do
        if IsValid( row ) then row:Remove() end
    end
    for _, divider in pairs( virtualState.dividers or {} ) do
        if IsValid( divider ) then divider:Remove() end
    end
    if IsValid( virtualState.spacer ) then virtualState.spacer:Remove() end

    panel.virtualState = nil
end


function list.UpdateVisibleRows( panel )
    local virtualState = panel.virtualState
    if not virtualState then return end

    local canvas = panel:GetCanvas()
    local vbar = panel:GetVBar()
    virtualState.dividers = virtualState.dividers or {}

    local rowHeight = style.Scale( 40 )
    local rowGap = style.Scale( 5 )
    local topPad = style.Scale( 5 )
    local sidePad = style.Scale( 5 )
    local dividerInset = style.Scale( 8 )
    local dividerHeight = math.max( 1, style.Scale( 1 ) )
    local count = #virtualState.entries
    local positions, canvasHeight = getLayout( virtualState, rowHeight, rowGap, topPad )

    if not IsValid( virtualState.spacer ) then
        virtualState.spacer = vgui.Create( "DPanel", canvas )
        virtualState.spacer:Dock( TOP )
        virtualState.spacer.Paint = nil
    end
    virtualState.spacer:SetTall( math.max( panel:GetTall(), canvasHeight ) )

    local scroll = vbar:GetScroll()
    local first, last = getVisibleRange( positions, count, rowHeight, scroll, panel:GetTall() )

    for index, row in pairs( virtualState.rows ) do
        if index < first or index > last then
            if IsValid( row ) then row:Remove() end
            virtualState.rows[index] = nil
        end
    end

    for index, divider in pairs( virtualState.dividers ) do
        local entry = virtualState.entries[index]
        if index < first or index > last or not ( entry and entry.dividerBelow and index < count ) then
            if IsValid( divider ) then divider:Remove() end
            virtualState.dividers[index] = nil
        end
    end

    local width = math.max( 0, canvas:GetWide() - sidePad * 2 )
    for index = first, last do
        local entry = virtualState.entries[index]
        local row = virtualState.rows[index]
        if not IsValid( row ) then
            row = rows.Create( canvas, entry, virtualState.callbacks )
            row:Dock( NODOCK )
            virtualState.rows[index] = row
        end

        row:SetPos( sidePad, positions[index] )
        row:SetSize( width, rowHeight )
        if row.SetKeyboardSelected then row:SetKeyboardSelected( index == state.keyboardIndex ) end

        if entry.dividerBelow and index < count then
            local divider = virtualState.dividers[index]
            if not IsValid( divider ) then
                divider = vgui.Create( "rRadioMenuSeparator", canvas )
                divider:Dock( NODOCK )
                virtualState.dividers[index] = divider
            end

            local dividerGap = rowGap + getExtraGapBelow( entry )
            local dividerY = positions[index] + rowHeight + math.floor( ( dividerGap - dividerHeight ) * 0.5 )
            local dividerWidth = math.max( 0, width - dividerInset * 2 )

            divider:SetPos( sidePad + dividerInset, dividerY )
            divider:SetSize( dividerWidth, dividerHeight )
        elseif IsValid( virtualState.dividers[index] ) then
            virtualState.dividers[index]:Remove()
            virtualState.dividers[index] = nil
        end
    end

    virtualState.lastScroll = scroll
    virtualState.lastTall = panel:GetTall()
    virtualState.lastWide = canvas:GetWide()
end


function list.GetPageStep( panel )
    local rowHeight = style.Scale( 40 )
    local rowGap = style.Scale( 5 )
    local stride = math.max( 1, rowHeight + rowGap )

    return math.max( 1, math.floor( panel:GetTall() / stride ) - 1 )
end


function list.EnsureIndexVisible( panel, index )
    local virtualState = panel.virtualState
    if not virtualState then return end

    index = tonumber( index )
    if not index or not virtualState.entries[index] then return end

    local vbar = panel:GetVBar()

    local rowHeight = style.Scale( 40 )
    local rowGap = style.Scale( 5 )
    local topPad = style.Scale( 5 )
    local positions = getLayout( virtualState, rowHeight, rowGap, topPad )
    local rowTop = positions[index] or 0
    local rowBottom = rowTop + rowHeight
    local scroll = vbar:GetScroll()
    local viewHeight = panel:GetTall()

    if rowTop < scroll then
        vbar:SetScroll( rowTop )
    elseif rowBottom > scroll + viewHeight then
        vbar:SetScroll( math.max( 0, rowBottom - viewHeight ) )
    end

    list.UpdateVisibleRows( panel )
end


function list.SetEntries( panel, entries, listKey, callbacks )
    local vbar = panel:GetVBar()
    local scroll = vbar:GetScroll()
    local virtualState = panel.virtualState
    if virtualState and virtualState.listKey == listKey and viewModel.EntriesMatch( virtualState.entries, entries ) then
        virtualState.entries = entries
        virtualState.callbacks = callbacks
        clearLayout( virtualState )
        for index, row in pairs( virtualState.rows ) do
            local entry = entries[index]
            if IsValid( row ) and entry and row.SetTextLabel then
                row:SetTextLabel( entry.label )
            end
        end

        list.UpdateVisibleRows( panel )
        return
    end

    list.Clear( panel )
    panel:Clear()
    panel.virtualState = {
        entries = entries,
        rows = {},
        dividers = {},
        spacer = nil,
        callbacks = callbacks,
        listKey = listKey,
        lastScroll = nil,
        lastTall = nil,
        lastWide = nil
    }

    vbar:SetScroll( virtualState and virtualState.listKey == listKey and scroll or 0 )
    list.UpdateVisibleRows( panel )
end


return list
