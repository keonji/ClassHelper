local _, ns = ...
local Section = { labels = {} }
ns.ClassGuideSection = Section

function Section:Clear()
    if self.container then self.container:Hide() end
    if self.buildDropdown then self.buildDropdown:Close(); self.buildDropdown.frame:Hide() end
    for _, label in ipairs(self.labels) do label:Hide() end
    self.labels = {}
    ns.TalentSection:Clear()
    ns.GlyphSection:Clear()
    ns.RotationSection:Clear()
end

function Section:Render(window, view)
    self:Clear()
    local host, widgets = window.contentHost, ns.Widgets
    host.viewport:ClearAllPoints()
    host.viewport:SetPoint("TOPLEFT", 20, -84)
    local viewportHeight = window.frame:GetHeight() - 124
    host.viewport:SetSize(600, viewportHeight)
    host:SetWidth(580)
    local frame = self.container or ns:CreateUIFrame(nil, host)
    self.container = frame
    frame:Show()
    frame:SetPoint("TOPLEFT")
    frame:SetWidth(580)
    local context = ns.ClassGuides:Get(window.profile, "wrath")
    self.context = context
    local y, ru = 8, context.locale == "ruRU"
    local function text(value, heading)
        if not value or value == "" then return end
        self.labelPool = self.labelPool or {}
        local index = #self.labels + 1
        local label = self.labelPool[index] or widgets.Label(frame, "", "GameFontHighlight")
        self.labelPool[index] = label
        label:SetText(value)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", 8, -y)
        label:SetWidth(560)
        label:SetJustifyH("LEFT")
        local font, _, flags = label:GetFont()
        label:SetFont(font, heading and 16 or 13, flags)
        label:SetTextColor(heading and 1 or 0.94, heading and 0.82 or 0.9, heading and 0 or 0.79)
        label:SetHeight(0)
        label:SetHeight(math.max(18, label:GetStringHeight() + 2))
        label:Show()
        self.labels[index] = label
        y = y + label:GetHeight() + 12
    end
    text(ns.L:Get(view.context.tabKey == "talents" and "CLASS_TALENTS" or "CLASS_GLYPHS") .. " - 80 - " .. (context.mode == "pvp" and "PvP" or "PvE"), true)
    local build = ns.ClassGuides:Selected(context)
    if not build then
        text(ns.L:Get(context.missing and "CLASS_NO_SOURCE" or "CLASS_NO_BUILD"))
    else
        if #context.builds > 1 then
            local entries = {}
            for _, variant in ipairs(context.builds) do
                local key = variant.key
                entries[#entries + 1] = { text = ru and variant.titleRu or variant.title, onClick = function()
                    ns.ClassGuides:Select(context, key)
                    window:SelectTab(view.context.tabKey)
                end }
            end
            self.buildDropdown = self.buildDropdown or widgets.Dropdown(frame, nil, 552)
            local dropdown = self.buildDropdown
            dropdown:SetText(ru and build.titleRu or build.title)
            dropdown:SetEntries(function() return entries end)
            dropdown.frame:ClearAllPoints()
            dropdown.frame:SetPoint("TOPLEFT", 8, -y)
            dropdown.frame:Show()
            y = y + 40
        else text(ru and build.titleRu or build.title) end
        if build.notes then text((build.notes[context.locale]:gsub("^Источник:%s*", ""))) end
        if view.context.tabKey == "talents" then
            y = ns.TalentSection:Render(frame, window.profile.classToken, build, y)
            text(ns.L:Get("CLASS_ROTATION"), true)
            text(context.rotation ~= "" and context.rotation or ns.L:Get("CLASS_NO_BUILD"))
            if context.rotationDiagram then
                text(ns.L:Get("ROTATION_" .. context.rotationDiagram.kind))
                y = ns.RotationSection:Render(frame, context.rotationDiagram, build, y)
            end
        else
            y = ns.GlyphSection:Render(frame, window, view, build, y)
            text(ns.L:Get("GLYPH_OBTAIN"), true)
            if #build.glyphs > 0 then text(ns.L:Get("GLYPH_CRAFTED")) end
            if #build.glyphs == 0 then text(ns.L:Get("CLASS_NO_GLYPHS")) end
            if #build.glyphIssues > 0 then text(ns.L:Get("GLYPH_INCOMPATIBLE")) end
        end
    end
    frame:SetHeight(y)
    host:SetHeight(math.max(viewportHeight, y))
    window.statusText:SetText("")
end
