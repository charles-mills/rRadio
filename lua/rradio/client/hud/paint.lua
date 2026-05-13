rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.hud = rRadio.client.hud or {}
rRadio.client.hud.paint = rRadio.client.hud.paint or {}

local paint = rRadio.client.hud.paint

local DETAIL_SCALE = rRadio.client.hud.DETAIL_SCALE or 2
local EQ_BARS = 5
local DIVIDER_TOP_BORDER = DETAIL_SCALE
local BAR_BORDER = DETAIL_SCALE


local function drawBackground( hudState, renderer )
    local measuredLayout = hudState.layout
    renderer.DrawRect(
        measuredLayout.left,
        measuredLayout.top,
        measuredLayout.width,
        measuredLayout.height,
        hudState.colors.background
    )
end


local function drawText( hudState, renderer )
    local measuredLayout = hudState.layout
    renderer.DrawOutlinedText(
        measuredLayout.text,
        measuredLayout.font,
        measuredLayout.textDrawX,
        measuredLayout.textY + hudState.textSlide,
        hudState.colors.text,
        hudState.colors.textBorder
    )
end


local function drawDivider( measuredLayout, renderer, color, shadowColor )
    renderer.DrawRect(
        measuredLayout.left,
        measuredLayout.stripY - DIVIDER_TOP_BORDER,
        measuredLayout.width,
        DIVIDER_TOP_BORDER,
        shadowColor
    )
    renderer.DrawRect(
        measuredLayout.left,
        measuredLayout.stripY,
        measuredLayout.width,
        measuredLayout.stripHeight,
        color
    )
end


function paint.PaintBasic( hudState, renderer )
    drawBackground( hudState, renderer )
    drawText( hudState, renderer )
end


function paint.PaintFull( hudState, renderer )
    local measuredLayout = hudState.layout
    drawBackground( hudState, renderer )

    if hudState.isConnectingPhase then
        local barWidth = measuredLayout.width * 0.3
        local offset = hudState.tuningOffset * ( measuredLayout.width - barWidth )
        drawDivider( measuredLayout, renderer, hudState.colors.dimAccent, hudState.colors.shadow )
        renderer.DrawRect(
            measuredLayout.left + offset,
            measuredLayout.stripY,
            barWidth,
            measuredLayout.stripHeight,
            hudState.colors.accent
        )
    else
        drawDivider( measuredLayout, renderer, hudState.colors.accent, hudState.colors.shadow )
    end

    if not hudState.isPlayingPhase then
        renderer.DrawRect(
            measuredLayout.statusX - BAR_BORDER,
            measuredLayout.statusY - BAR_BORDER,
            measuredLayout.statusWidth + BAR_BORDER * 2,
            measuredLayout.statusHeight + BAR_BORDER * 2,
            hudState.colors.shadow
        )
        renderer.DrawRect(
            measuredLayout.statusX,
            measuredLayout.statusY,
            measuredLayout.statusWidth,
            measuredLayout.statusHeight,
            hudState.colors.phase
        )
    end

    drawText( hudState, renderer )

    if not hudState.isPlayingPhase or not hudState.equalizerActive then return end

    for index = 1, EQ_BARS do
        local barHeight = measuredLayout.equalizerMaxHeight * hudState.equalizer[index]
        local barX = measuredLayout.equalizerX + ( index - 1 )
            * ( measuredLayout.equalizerBarWidth + measuredLayout.equalizerGap )
        local barY = measuredLayout.equalizerY - barHeight * 0.5

        if barHeight > 0.5 then
            renderer.DrawRect(
                barX - BAR_BORDER,
                barY - BAR_BORDER,
                measuredLayout.equalizerBarWidth + BAR_BORDER * 2,
                barHeight + BAR_BORDER * 2,
                hudState.colors.shadow
            )
        end

        renderer.DrawRect(
            barX,
            barY,
            measuredLayout.equalizerBarWidth,
            barHeight,
            hudState.colors.phase
        )
    end
end


function paint.Paint( hudState, renderer )
    if hudState.mode == "basic" then
        paint.PaintBasic( hudState, renderer )
        return
    end

    paint.PaintFull( hudState, renderer )
end


return paint
