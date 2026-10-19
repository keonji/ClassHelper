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
        texture:SetTexture(unpack(theme().Colors.panel))
        texture:Show()
    end
    return texture
end

function Widgets.Label(parent, text, fontObject)
    local label = compat():CreateFontString(parent, fontObject or theme().Fonts.body)
    if label then
        label:SetText(text)
        local color = fontObject == theme().Fonts.header and theme().Colors.titleText
            or fontObject == theme().Fonts.status and theme().Colors.disabledText or theme().Colors.bodyText
        label:SetTextColor(unpack(color))
        -- Large client font objects carry their own size; forcing 13 pt flattens the hierarchy.
        if label.GetFont and label.SetFont and fontObject ~= theme().Fonts.slot and fontObject ~= "NumberFontNormal" then
            local font, size, flags = label:GetFont()
            label:SetFont(font, fontObject == theme().Fonts.title and 22 or fontObject == theme().Fonts.status and 11 or 13, flags)
        end
        label:Show()
    end
    return label
end

function Widgets.Portrait(parent)
    local art = ns.Art
    local portrait = compat():CreateTexture(parent, "ARTWORK")
    if not portrait then return nil end
    portrait:SetSize(58, 58)
    portrait:SetPoint("TOPLEFT", -14, 16)
    portrait:Show()
    -- MiniMap-TrackingBorder frames a 20 px icon placed at (7, -6) inside a 52 px ring.
    local scale = 58 / 20
    portrait.ring = compat():CreateTexture(parent, "OVERLAY")
    portrait.ring:SetTexture(art.PortraitRing)
    portrait.ring:SetSize(52 * scale, 52 * scale)
    portrait.ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -7 * scale, 6 * scale)
    portrait.ring:Show()
    function portrait:SetClass(classToken)
        local coords = art.ClassCoords[classToken]
        if coords then
            self:SetTexture(art.ClassCircles)
            self:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            self:SetTexture(art.Question)
            self:SetTexCoord(0, 1, 0, 1)
        end
    end
    return portrait
end

function Widgets.WindowChrome(frame)
    local art = ns.Art
    frame:SetBackdrop({ bgFile = art.Window.background, edgeFile = art.Window.border, tile = true,
        tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    frame:SetBackdropColor(1, 1, 1, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    local chrome = {}
    chrome.header = compat():CreateTexture(frame, "ARTWORK")
    chrome.header:SetTexture(art.Window.header)
    chrome.header:SetSize(400, 64)
    chrome.header:SetPoint("TOP", 0, 12)
    chrome.header:Show()
    chrome.titleText = Widgets.Label(frame, "ClassHelper", theme().Fonts.header)
    chrome.titleText:SetPoint("TOP", chrome.header, "TOP", 0, -14)
    chrome.titleText:SetWidth(280)
    chrome.titleText:SetHeight(14)
    chrome.titleText:SetTextColor(unpack(theme().Colors.gold))
    chrome.closeButton = ns:CreateUIFrame("ClassHelperCloseButton", frame, "Button")
    chrome.closeButton:SetSize(32, 32)
    chrome.closeButton:SetPoint("TOPRIGHT", -4, -4)
    chrome.closeButton:EnableMouse(true)
    chrome.closeButton:RegisterForClicks("LeftButtonUp")
    for _, part in ipairs({ "up", "down", "highlight" }) do
        local texture = compat():CreateTexture(chrome.closeButton, part == "highlight" and "HIGHLIGHT" or "ARTWORK")
        texture:SetTexture(art.Close[part])
        texture:SetAllPoints()
        if part == "highlight" then texture:SetBlendMode("ADD") end
        if part == "down" then texture:Hide() else texture:Show() end
        chrome.closeButton[part] = texture
    end
    chrome.footerText = Widgets.Label(frame, "", theme().Fonts.footer)
    chrome.footerText:SetPoint("BOTTOM", 0, 14)
    chrome.footerText:SetWidth(580)
    chrome.footerText:SetJustifyH("CENTER")
    return chrome
end

function Widgets.ScrollHost(parent)
    local viewport = ns:CreateUIFrame("ClassHelperViewport", parent, "ScrollFrame")
    viewport:SetSize(868, 436)
    viewport:SetPoint("TOP", 0, -108)
    viewport:EnableMouseWheel(true)
    local host = ns:CreateUIFrame("ClassHelperScrollHost", viewport)
    if host then
        host:SetWidth(868)
        host:SetHeight(436)
        host:SetPoint("TOPLEFT")
        viewport:SetScrollChild(host)
        host.viewport = viewport
        viewport.thumb = compat():CreateTexture(viewport, "OVERLAY")
        viewport.thumb:SetTexture(unpack(theme().Colors.border))
        viewport.thumb:SetSize(4, 40)
        viewport:SetScript("OnMouseWheel", function(self, delta)
            local limit = math.max(0, host:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 48)))
            Widgets.UpdateScroll(host)
        end)
    end
    return host
end

function Widgets.UpdateScroll(host)
    local viewport = host.viewport
    local visible, total = viewport:GetHeight(), host:GetHeight()
    if total <= visible then viewport.thumb:Hide(); return end
    local track = visible - 16
    local height = math.max(24, track * visible / total)
    local offset = (track - height) * math.min(1, viewport:GetVerticalScroll() / (total - visible))
    viewport.thumb:ClearAllPoints()
    viewport.thumb:SetPoint("TOPRIGHT", -4, -8 - offset)
    viewport.thumb:SetSize(4, height)
    viewport.thumb:Show()
end

function Widgets.StatusStrip(parent)
    local strip = Widgets.Label(parent, "", theme().Fonts.status)
    return strip
end

local TAB_COORDS = { { 0, 0.15625 }, { 0.15625, 0.84375 }, { 0.84375, 1 } }

local function tabParts(frame, file)
    local parts = {}
    for index, coords in ipairs(TAB_COORDS) do
        local texture = compat():CreateTexture(frame, "BACKGROUND")
        texture:SetTexture(file)
        texture:SetTexCoord(coords[1], coords[2], 0, 1)
        texture:SetHeight(32)
        if index ~= 2 then texture:SetWidth(20) end
        parts[index] = texture
    end
    parts[1]:SetPoint("TOPLEFT")
    parts[3]:SetPoint("TOPRIGHT")
    parts[2]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
    parts[2]:SetPoint("TOPRIGHT", parts[3], "TOPLEFT")
    return parts
end

function Widgets.Tab(parent, key, labelText, onClick)
    local frame = ns:CreateUIFrame("ClassHelperTab" .. key, parent, "Button")
    if not frame then return nil end
    frame:SetSize(130, 32)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", function()
        if onClick then onClick(key) end
    end)

    local tab = { key = key, label = labelText, frame = frame }
    tab.activeParts = tabParts(frame, ns.Art.Tab.active)
    tab.inactiveParts = tabParts(frame, ns.Art.Tab.inactive)
    tab.indicator = tab.activeParts[2]
    tab.highlight = compat():CreateTexture(frame, "HIGHLIGHT")
    tab.highlight:SetTexture(ns.Art.Tab.highlight)
    tab.highlight:SetBlendMode("ADD")
    tab.highlight:SetPoint("TOPLEFT", 10, -2)
    tab.highlight:SetPoint("BOTTOMRIGHT", -10, 4)
    tab.labelWidget = Widgets.Label(frame, labelText, theme().Fonts.tab)
    if tab.labelWidget then tab.labelWidget:SetPoint("CENTER", 0, 2) end
    function tab:SetSelected(selected)
        self.selected = selected
        for index = 1, 3 do
            if selected then self.activeParts[index]:Show(); self.inactiveParts[index]:Hide()
            else self.activeParts[index]:Hide(); self.inactiveParts[index]:Show() end
        end
        self.labelWidget:SetTextColor(unpack(selected and theme().Colors.slotText or theme().Colors.gold))
    end
    tab:SetSelected(false)
    return tab
end

local DROPDOWN_COORDS = { { 0, 0.1953125, 25 }, { 0.1953125, 0.8046875 }, { 0.8046875, 1, 25 } }
local openDropdown

function Widgets.CloseDropdowns()
    if openDropdown then openDropdown:Close() end
end

local function menuFrame()
    local art = ns.Art.Dropdown
    local menu = ns:CreateUIFrame(nil, ns:GetUIParent())
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:SetBackdrop({ bgFile = art.menuBackground, edgeFile = art.menuBorder, tile = true,
        tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    menu.entries, menu.pool = {}, {}
    menu:Hide()
    return menu
end

local function fillMenu(menu, items, onPick, onExpand)
    for _, button in ipairs(menu.pool) do button:Hide() end
    menu.entries = {}
    local width = 120
    for index, item in ipairs(items) do
        local button = menu.pool[index]
        if not button then
            button = ns:CreateUIFrame(nil, menu, "Button")
            button:SetHeight(18)
            button:EnableMouse(true)
            button:RegisterForClicks("LeftButtonUp")
            button.highlight = compat():CreateTexture(button, "HIGHLIGHT")
            button.highlight:SetTexture(ns.Art.Dropdown.highlight)
            button.highlight:SetBlendMode("ADD")
            button.highlight:SetAllPoints()
            button.labelWidget = Widgets.Label(button, "", theme().Fonts.dropdown)
            button.labelWidget:SetPoint("LEFT", 6, 0)
            button.labelWidget:SetJustifyH("LEFT")
            button.arrow = compat():CreateTexture(button, "ARTWORK")
            button.arrow:SetTexture(ns.Art.Dropdown.expand)
            button.arrow:SetSize(16, 16)
            button.arrow:SetPoint("RIGHT", -2, 0)
            menu.pool[index] = button
        end
        button.item, button.childItems = item, item.children
        button.labelWidget:SetText(item.text)
        button.labelWidget:SetTextColor(unpack(item.color or (item.selected and theme().Colors.gold) or theme().Colors.slotText))
        if item.children then button.arrow:Show() else button.arrow:Hide() end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 14, -14 - (index - 1) * 18)
        button:SetScript("OnClick", function()
            if item.children then onExpand(button) else onPick(item) end
        end)
        button:Show()
        menu.entries[index] = button
        width = math.max(width, (button.labelWidget.GetStringWidth and button.labelWidget:GetStringWidth() or 0) + 40)
    end
    for _, button in ipairs(menu.entries) do button:SetWidth(width) end
    menu:SetSize(width + 28, #items * 18 + 28)
end

function Widgets.Dropdown(parent, name, width)
    local art = ns.Art.Dropdown
    local frame = ns:CreateUIFrame(name, parent, "Button")
    frame:SetSize(width, 32)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    local dropdown = { frame = frame }
    local previous
    for index, coords in ipairs(DROPDOWN_COORDS) do
        local texture = compat():CreateTexture(frame, "ARTWORK")
        texture:SetTexture(art.frame)
        texture:SetTexCoord(coords[1], coords[2], 0, 1)
        texture:SetSize(coords[3] or (width - 34), 64)
        if previous then texture:SetPoint("LEFT", previous, "RIGHT") else texture:SetPoint("TOPLEFT", -16, 17) end
        previous = texture
    end
    dropdown.arrow = compat():CreateTexture(frame, "OVERLAY")
    dropdown.arrow:SetTexture(art.arrowUp)
    dropdown.arrow:SetSize(24, 24)
    dropdown.arrow:SetPoint("RIGHT", -2, 1)
    dropdown.labelWidget = Widgets.Label(frame, "", theme().Fonts.dropdown)
    dropdown.labelWidget:SetPoint("LEFT", 8, 1)
    dropdown.labelWidget:SetWidth(width - 36)
    dropdown.labelWidget:SetHeight(14)
    dropdown.labelWidget:SetJustifyH("LEFT")
    dropdown.menu = menuFrame()
    dropdown.menu:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -12, 2)
    dropdown.submenu = menuFrame()

    function dropdown:SetText(text, color)
        self.labelWidget:SetText(text)
        self.labelWidget:SetTextColor(unpack(color or theme().Colors.slotText))
    end
    function dropdown:SetEntries(provider) self.provider = provider end
    function dropdown:IsOpen() return self.menu:IsShown() end
    function dropdown:Close()
        self.menu:Hide()
        self.submenu:Hide()
        self.arrow:SetTexture(art.arrowUp)
        if openDropdown == self then openDropdown = nil end
    end
    function dropdown:Open()
        if openDropdown and openDropdown ~= self then openDropdown:Close() end
        self.menu:SetFrameLevel(self.frame:GetFrameLevel() + 10)
        self.submenu:SetFrameLevel(self.menu:GetFrameLevel() + 10)
        local pick = function(item)
            self:Close()
            if item.onClick then item.onClick() end
        end
        fillMenu(self.menu, self.provider and self.provider() or {}, pick, function(button)
            fillMenu(self.submenu, button.childItems, pick, function() end)
            self.submenu:ClearAllPoints()
            self.submenu:SetPoint("TOPLEFT", button, "TOPRIGHT", 12, 14)
            self.submenu:Show()
        end)
        self.submenu:Hide()
        self.menu:Show()
        self.arrow:SetTexture(art.arrowDown)
        openDropdown = self
    end
    frame:SetScript("OnClick", function()
        if dropdown:IsOpen() then dropdown:Close() else dropdown:Open() end
    end)
    frame:SetScript("OnHide", function() dropdown:Close() end)
    return dropdown
end

function Widgets.Button(parent, name, labelText, onClick)
    local frame = ns:CreateUIFrame(name, parent, "Button")
    if not frame then return nil end
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", onClick)
    frame.background = Widgets.Fill(frame)
    frame:SetScript("OnEnter", function() frame.background:SetTexture(unpack(theme().Colors.raised)) end)
    frame:SetScript("OnLeave", function() frame.background:SetTexture(unpack(theme().Colors.panel)) end)
    frame.labelWidget = Widgets.Label(frame, labelText, theme().Fonts.header)
    if frame.labelWidget then frame.labelWidget:SetPoint("CENTER") end
    return frame
end

function Widgets.FramedButton(parent, name, labelText, onClick)
    local frame = Widgets.Button(parent, name, labelText, onClick)
    if not frame then return nil end
    frame.background:Hide()
    frame:SetBackdrop({ bgFile = ns.Art.Window.background, edgeFile = ns.Art.Window.border,
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    frame:SetBackdropColor(1, 1, 1, 1)
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    frame.labelWidget:SetTextColor(unpack(theme().Colors.gold))
    frame:SetScript("OnEnter", function() frame:SetBackdropBorderColor(1, 0.82, 0.45, 1) end)
    frame:SetScript("OnLeave", function() frame:SetBackdropBorderColor(1, 1, 1, 1) end)
    return frame
end

function Widgets.Panel(parent, width, height)
    local panel = ns:CreateUIFrame(nil, parent)
    panel:SetSize(width, height)
    Widgets.Backdrop(panel)
    panel:SetBackdropColor(unpack(theme().Colors.panel))
    return panel
end
