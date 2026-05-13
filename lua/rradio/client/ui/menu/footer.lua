rRadio = rRadio or {}
rRadio.client = rRadio.client or {}
rRadio.client.ui = rRadio.client.ui or {}
rRadio.client.ui.menu = rRadio.client.ui.menu or {}
rRadio.client.ui.menu.footer = rRadio.client.ui.menu.footer or {}

local footer = rRadio.client.ui.menu.footer
local state = rRadio.client.ui.state
local style = rRadio.client.ui.style
local suppressVolumeChange = false


function footer.Create( frame, callbacks )
    state.stopButton = vgui.Create( "rRadioMenuAnimatedButton", frame )
    state.stopButton:SetText( rRadio.L( "StopRadio", "STOP" ) )
    state.stopButton:SetFont( "rRadio.Inter8" )
    state.stopButton:SetColorRole( "footerSurface" )
    state.stopButton.DoClick = callbacks.stop

    state.volumePanel = vgui.Create( "DPanel", frame )
    state.volumePanel.Paint = function( _panel, width, height )
        style.DrawSurface(
            "button",
            8,
            0,
            0,
            width,
            height,
            style.GetFooterSurfaceColor(),
            style.GetBorderColor()
        )
    end

    state.volumeIcon = vgui.Create( "DImage", state.volumePanel )
    state.volumeIcon.Paint = function( panel, width, height )
        surface.SetMaterial( panel:GetMaterial() or style.Materials.volumeUp )
        surface.SetDrawColor( rRadio.config.UI.TextColor )
        surface.DrawTexturedRect( 0, 0, width, height )
    end

    state.volumeSlider = vgui.Create( "DNumSlider", state.volumePanel )
    state.volumeSlider:SetMin( 0 )
    state.volumeSlider:SetMax( rRadio.config.MaxVolume or 1 )
    state.volumeSlider:SetDecimals( 2 )
    style.StyleSlider( state.volumeSlider, 0.26 )
    footer.RefreshVolume()
    state.volumeSlider.OnValueChanged = function( _panel, value )
        if suppressVolumeChange then return end

        value = math.Clamp( value, 0, rRadio.config.MaxVolume or 1 )
        if IsValid( state.volumeIcon ) then
            state.volumeIcon:SetMaterial( style.GetVolumeIcon( value ) )
        end

        callbacks.setVolume( value )
    end
end


function footer.RefreshVolume()
    if not IsValid( state.volumeSlider ) then return end

    local currentVolume = 1
    if IsValid( state.currentEntity ) then
        currentVolume = rRadio.client.radio.state.GetVolume( state.currentEntity )
    end

    if IsValid( state.volumeIcon ) then
        state.volumeIcon:SetMaterial( style.GetVolumeIcon( currentVolume ) )
    end

    suppressVolumeChange = true
    state.volumeSlider:SetValue( currentVolume )
    suppressVolumeChange = false
end


function footer.Relayout( geometry )
    if not IsValid( state.stopButton ) or not IsValid( state.volumePanel ) then return end

    state.stopButton:SetPos( geometry.margin, geometry.footerTop )
    state.stopButton:SetSize( geometry.stopWidth, geometry.stopHeight )
    state.stopButton:SetFont(
        style.GetButtonFillFont( state.stopButton:GetText(), geometry.stopWidth, geometry.stopHeight )
    )

    state.volumePanel:SetPos( geometry.margin * 2 + geometry.stopWidth, geometry.footerTop )
    state.volumePanel:SetSize(
        geometry.width - geometry.margin * 3 - geometry.stopWidth,
        geometry.stopHeight
    )

    local iconPadding = style.Scale( 10 )
    local iconSize = style.Scale( 50 )
    state.volumeIcon:SetPos( iconPadding, ( geometry.stopHeight - iconSize ) * 0.5 )
    state.volumeIcon:SetSize( iconSize, iconSize )

    local sliderLeft = iconPadding + iconSize + style.Scale( 3 )
    local sliderTop = style.Scale( 6 )
    local sliderHeight = math.max( style.Scale( 16 ), geometry.stopHeight - sliderTop * 2 )
    local sliderWidth = math.max( style.Scale( 80 ), state.volumePanel:GetWide() - sliderLeft - style.Scale( 12 ) )
    state.volumeSlider:SetPos( sliderLeft, sliderTop )
    state.volumeSlider:SetSize( sliderWidth, sliderHeight )
    style.SyncSliderKnob( state.volumeSlider, 0.48 )
end


return footer
