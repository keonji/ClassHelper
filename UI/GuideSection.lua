local addonName, ns = ...

local GuideSection = { headers = {}, elements = {}, collapsed = {} }
ns.GuideSection = GuideSection

local sections = {
    { key = "overview", title = "SECTION_OVERVIEW" },
    { key = "stats", title = "SECTION_STAT_PRIORITY" },
    { key = "talents", title = "SECTION_TALENTS" },
    { key = "rotation", title = "SECTION_ROTATION" },
}

function GuideSection:Clear()
    for _, row in ipairs(self.itemRows or {}) do
        row:Unbind()
        row.frame:Hide()
        row.frame:SetParent(nil)
    end
    for _, element in ipairs(self.elements) do element:Hide() end
    self.itemRows, self.headers, self.elements = {}, {}, {}
    self.panels, self.talentCards, self.spellRows = {}, {}, {}
end

local function allocations(trees)
    local totals = {}
    for _, ranks in ipairs(trees) do
        local points = 0
        for rank in ranks:gmatch("%d") do points = points + tonumber(rank) end
        totals[#totals + 1] = points
    end
    return totals
end

function GuideSection:Render(window, view)
    self:Clear()
    self.window, self.view = window, view
    local y = 8
    local function track(element)
        self.elements[#self.elements + 1] = element
        return element
    end
    for _, definition in ipairs(sections) do
        local key = definition.key
        local data = ns.GuideService:GetSection(window.profile, window.selectedStage, key)
        if data then
            local top = y
            local panel = track(ns.Widgets.Panel(window.contentHost, 836, 44))
            panel:SetPoint("TOPLEFT", 8, -top)
            self.panels[#self.panels + 1] = panel
            local stateKey = window.selectedEra .. ":" .. key
            local heading = ns.L:Get(definition.title)
            local totals = data.trees and allocations(data.trees)
            if totals then heading = heading .. " — " .. table.concat(totals, "/") end
            heading = (self.collapsed[stateKey] and "[+] " or "[-] ") .. heading
            local header = track(ns.Widgets.Button(panel, nil, heading, function()
                self.collapsed[stateKey] = not self.collapsed[stateKey]
                ns.Config:Set("collapsedSections", self.collapsed)
                self:Render(window, view)
            end))
            header:SetSize(832, 36)
            header:SetPoint("TOPLEFT", 2, -2)
            header.labelWidget:ClearAllPoints()
            header.labelWidget:SetPoint("LEFT", 16, 0)
            self.headers[#self.headers + 1] = header
            y = y + 48
            local function paragraph(text)
                local label = track(ns.Widgets.Label(panel, text, ns.Theme.Fonts.body))
                label:SetWidth(788)
                label:SetJustifyH("LEFT")
                label:SetPoint("TOPLEFT", 24, -(y - top))
                y = y + math.max(18, label:GetStringHeight()) + 12
            end
            if not self.collapsed[stateKey] then
                for _, textKey in ipairs(data.paragraphs or {}) do paragraph(ns.L:Get(textKey) or ("[" .. textKey .. "]")) end
                if data.trees then
                    local cardsTop, cardsHeight = y, 0
                    for treeIndex, ranks in ipairs(data.trees) do
                        local tree = ns.Registry:Get("talentTree", window.profile.classToken .. ":" .. treeIndex)
                        if tree then
                            local card = track(ns.Widgets.Panel(panel, 252, 48))
                            card:SetPoint("TOPLEFT", 24 + (treeIndex - 1) * 266, -(cardsTop - top))
                            self.talentCards[#self.talentCards + 1] = card
                            local title = track(ns.Widgets.Label(card, ns.L:Get(tree.titleKey) .. "  " .. totals[treeIndex], ns.Theme.Fonts.header))
                            title:SetPoint("TOPLEFT", 12, -12)
                            local offset = 42
                            for talentIndex = 1, #ranks do
                                local rank = tonumber(ranks:sub(talentIndex, talentIndex)) or 0
                                local talent = tree.talents[talentIndex]
                                if rank > 0 and talent then
                                    local spell = ns.SpellResolver:Resolve(talent.spellID)
                                    local icon = ns.Compat:CreateTexture(card, "ARTWORK")
                                    icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                                    icon:SetSize(22, 22)
                                    icon:SetPoint("TOPLEFT", 12, -offset)
                                    local text = track(ns.Widgets.Label(card, rank .. "/" .. talent.maxRank .. " " .. spell.name, ns.Theme.Fonts.status))
                                    text:SetWidth(198)
                                    text:SetJustifyH("LEFT")
                                    text:SetPoint("TOPLEFT", 42, -offset - 3)
                                    offset = offset + math.max(28, text:GetStringHeight() + 10)
                                end
                            end
                            card:SetHeight(offset + 6)
                            cardsHeight = math.max(cardsHeight, offset + 6)
                        end
                    end
                    y = cardsTop + cardsHeight + 16
                end
                if data.glyphs then
                    for _, category in ipairs({ "major", "minor" }) do
                        paragraph(ns.L:Get("GLYPH_" .. string.upper(category)))
                        for _, itemID in ipairs(data.glyphs[category] or {}) do
                            local row = ns.ItemRow.Create(panel, window.resolver, view)
                            row.frame:SetWidth(788)
                            row.nameText:SetWidth(478)
                            row.frame:SetPoint("TOPLEFT", 24, -(y - top))
                            row:Bind(itemID, { itemID = itemID }, view)
                            self.itemRows[#self.itemRows + 1] = row
                            y = y + 44
                        end
                        y = y + 8
                    end
                end
                local previousGroup
                for _, entry in ipairs(data.entries or {}) do
                    if entry.groupKey and entry.groupKey ~= previousGroup then
                        paragraph(ns.L:Get(entry.groupKey))
                        previousGroup = entry.groupKey
                    end
                    local spell = ns.SpellResolver:Resolve(entry.spellID)
                    local row = track(ns.Widgets.Panel(panel, 788, 56))
                    row:SetPoint("TOPLEFT", 24, -(y - top))
                    self.spellRows[#self.spellRows + 1] = row
                    local icon = ns.Compat:CreateTexture(row, "ARTWORK")
                    icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    icon:SetSize(34, 34)
                    icon:SetPoint("TOPLEFT", 10, -10)
                    local name = track(ns.Widgets.Label(row, spell.name, ns.Theme.Fonts.header))
                    name:SetPoint("TOPLEFT", 56, -9)
                    name:SetWidth(712)
                    name:SetJustifyH("LEFT")
                    local note = track(ns.Widgets.Label(row, ns.L:Get(entry.noteKey) or entry.noteKey, ns.Theme.Fonts.body))
                    note:SetPoint("TOPLEFT", 56, -29)
                    note:SetWidth(712)
                    note:SetJustifyH("LEFT")
                    local height = math.max(58, note:GetStringHeight() + 40)
                    row:SetHeight(height)
                    y = y + height + 6
                end
            end
            y = y + 6
            panel:SetHeight(y - top)
            y = y + 12
        end
    end
    self.contentHeight = y
    window.contentHost:SetHeight(math.max(436, y))
    local viewport = window.contentHost.viewport
    viewport:SetVerticalScroll(math.max(0, math.min(viewport:GetVerticalScroll(), math.max(0, y - viewport:GetHeight()))))
    ns.Widgets.UpdateScroll(window.contentHost)
    window.statusText:SetText(ns.L:Get("GUIDE_DRAFT_NOTE"))
end

function GuideSection:Restore()
    local saved = ns.Config:Get("collapsedSections")
    self.collapsed = type(saved) == "table" and saved or {}
end
