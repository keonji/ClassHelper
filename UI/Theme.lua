-- UI/Theme.lua: colors, fonts, and backdrop metadata for the Compendium shell. Kept
-- separate so the later full Compendium can restyle without touching window code.

local addonName, ns = ...

local Theme = {}
ns.Theme = Theme

Theme.Window = {
    width = 900,
    height = 620,
    minWidth = 560,
    minHeight = 420,
}

Theme.Colors = {
    background = { 0.08, 0.07, 0.06, 0.93 },
    panel = { 0.13, 0.12, 0.10, 0.90 },
    border = { 0.55, 0.45, 0.20, 1.0 },
    titleText = { 1.0, 0.93, 0.62, 1.0 },
    bodyText = { 0.90, 0.87, 0.78, 1.0 },
    disabledText = { 0.55, 0.53, 0.48, 1.0 },
    portrait = { 1.0, 1.0, 1.0, 1.0 },
}

Theme.Fonts = {
    title = "GameFontNormalHuge",
    header = "GameFontNormal",
    body = "GameFontHighlight",
    status = "GameFontDisableSmall",
}

Theme.Bg = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
