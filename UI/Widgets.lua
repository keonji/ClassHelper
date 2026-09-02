-- UI/Widgets.lua: thin builders over the Compat frame factory. They only assemble the
-- vertical-slice shell and never inspect raw registries or query the server.

local addonName, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local function compat()
    return ns.Compat
end

local function theme()
    return ns.Theme
end

function Widgets.Backdrop(frame)
    frame:SetBackdrop(theme().Bg)
    frame:SetBackdropColor(theme().Colors.background[1], theme().Colors.background[2],
        theme().Colors.background[3], theme().Colors.background[4])
    frame:SetBackdropBorderColor(theme().Colors.border[1], theme().Colors.border[2],
        theme().Colors.border[3], theme().Colors.border[4])
    return frame
end

function Widgets.Fill(parent, layer)
    local texture = compat():CreateTexture(parent, layer)
    if texture then
        texture:SetAllPoints()
        texture:SetTexture(0, 0, 0, 0.5)
        texture:Show()
    end
    return texture
end

function Widgets.Label(parent, text, fontObject)
    local label = compat():CreateFontString(parent, fontObject or theme().Fonts.body)
    if label then
        label:SetText(text)
        label:Show()
    end
    return label
end

function Widgets.Portrait(parent)
    local portrait = compat():CreateTexture(parent, "BACKGROUND")
    if portrait then
        portrait:SetTexture("Interface\\GLues\\CharacterCreate\\class-Paladin")
        portrait:SetVertexColor(theme().Colors.portrait[1], theme().Colors.portrait[2],
            theme().Colors.portrait[3], theme().Colors.portrait[4])
        portrait:SetSize(64, 64)
        portrait:SetPoint("TOPLEFT", 16, -16)
        portrait:Show()
    end
    return portrait
end

function Widgets.ScrollHost(parent)
    local host = ns:CreateUIFrame("ClassHelperScrollHost", parent)
    if host then
        host:SetWidth(868)
        host:SetHeight(470)
        host:SetPoint("TOP", 0, -96)
    end
    return host
end

function Widgets.StatusStrip(parent)
    local strip = Widgets.Label(parent, "", theme().Fonts.status)
    return strip
end

function Widgets.Tab(parent, key, labelText, onClick)
    local frame = ns:CreateUIFrame("ClassHelperTab" .. key, parent, "Button")
    if not frame then return nil end
    frame:SetSize(150, 26)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function()
        if onClick then onClick(key) end
    end)

    local tab = { key = key, label = labelText, frame = frame }
    tab.background = compat():CreateTexture(frame, "BACKGROUND")
    if tab.background then
        tab.background:SetAllPoints()
        tab.background:SetTexture(0.13, 0.12, 0.10, 0.9)
        tab.background:Show()
    end
    tab.labelWidget = Widgets.Label(frame, labelText, theme().Fonts.header)
    if tab.labelWidget then tab.labelWidget:SetPoint("CENTER") end
    return tab
end

function Widgets.Button(parent, name, labelText, onClick)
    local frame = ns:CreateUIFrame(name, parent, "Button")
    if not frame then return nil end
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", onClick)
    frame.labelWidget = Widgets.Label(frame, labelText, theme().Fonts.header)
    if frame.labelWidget then frame.labelWidget:SetPoint("CENTER") end
    return frame
end
