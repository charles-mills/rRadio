function DrawRoundedBoxWithText(cornerRadius, x, y, width, height, bgColor, textColor, text, font)
    draw.RoundedBox(cornerRadius, x, y, width, height, bgColor)
    draw.SimpleText(text, font, x + width / 2, y + height / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
