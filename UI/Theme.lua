-- UI/Theme.lua: colors, fonts, and backdrop metadata for the Compendium shell. Kept
-- separate so the later full Compendium can restyle without touching window code.

local addonName, ns = ...

local Theme = {}
ns.Theme = Theme

Theme.Window = {
    width = 640,
    height = 560,
    minWidth = 560,
    minHeight = 420,
}

Theme.Colors = {
    background = { 0.063, 0.082, 0.118, 0.98 },
    panel = { 0.098, 0.129, 0.176, 1.0 },
    raised = { 0.141, 0.184, 0.247, 1.0 },
    border = { 0.24, 0.29, 0.36, 1.0 },
    titleText = { 0.847, 0.718, 0.42, 1.0 },
    bodyText = { 0.902, 0.922, 0.949, 1.0 },
    disabledText = { 0.60, 0.66, 0.74, 1.0 },
    accent = { 0.96, 0.55, 0.73, 1.0 },
    portrait = { 1.0, 1.0, 1.0, 1.0 },
    gold = { 1.0, 0.82, 0.0, 1.0 },
    slotText = { 0.96, 0.95, 0.92, 1.0 },
    dimText = { 0.42, 0.40, 0.38, 1.0 },
    window = { 0.08, 0.075, 0.07, 1.0 },
    eraColors = {
        classic = { 1.0, 0.82, 0.0, 1.0 },
        tbc = { 0.12, 1.0, 0.0, 1.0 },
        wrath = { 0.64, 0.21, 0.93, 1.0 },
    },
}

Theme.Fonts = {
    title = "GameFontNormalHuge",
    header = "GameFontNormal",
    body = "GameFontHighlight",
    status = "GameFontDisableSmall",
    slot = "GameFontHighlightLarge",
    dropdown = "GameFontHighlight",
    footer = "GameFontDisableSmall",
    tab = "GameFontNormalSmall",
}

Theme.Bg = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = true,
    tileSize = 16,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
