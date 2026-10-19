local _, ns = ...
local Section = { slots = {} }
ns.GlyphSection = Section

function Section:Clear()
    if self.frame then self.frame:Hide() end
    for _, slot in ipairs(self.slots) do slot.cell:Clear() end
    ns.Compat:HideItemTooltip()
end

function Section:Render(parent, window, view, build, y)
    self:Clear()
    self.frame = self.frame or ns:CreateUIFrame(nil, parent)
    local frame = self.frame
    if not self.background then
        self.background = ns.Compat:CreateTexture(frame, "BACKGROUND")
        self.background:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
        self.background:SetTexCoord(0.02, 0.66, 0.12, 0.84)
        self.background:SetSize(310, 300)
        self.background:SetPoint("CENTER")
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 0, -y)
    frame:SetSize(576, 300)
    frame:Show()
    local byType = { major = {}, minor = {} }
    for _, glyph in ipairs(build.glyphs) do table.insert(byType[glyph.category], glyph) end
    local positions = { { 0, 94 }, { -104, -58 }, { 104, -58 }, { -104, 50 }, { 104, 50 }, { 0, -102 } }
    for i = 1, 6 do
        local kind = i <= 3 and "major" or "minor"
        local size = i <= 3 and 50 or 38
        local slot = self.slots[i]
        if not slot then
            local socket = ns.Compat:CreateTexture(frame, "BACKGROUND")
            socket:SetTexture("Interface\\Spellbook\\UI-GlyphFrame")
            socket:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625)
            socket:SetSize(size + 34, size + 34)
            socket:SetPoint("CENTER", positions[i][1], positions[i][2])
            local cell = ns.ItemCell.Create(frame, window.resolver, view, size)
            cell.frame:SetPoint("CENTER", positions[i][1], positions[i][2])
            local label = ns.Widgets.Label(frame, ns.L:Get("CLASS_GLYPH_" .. kind), "GameFontNormalSmall")
            label:SetPoint("TOP", cell.frame, "BOTTOM", 0, -7)
            slot = { cell = cell, label = label, socket = socket }
            self.slots[i] = slot
        end
        local cell = slot.cell
        cell.view, cell.resolver = view, window.resolver
        local glyph = byType[kind][i <= 3 and i or i - 3]
        slot.data = glyph
        if glyph then
            local spell = ns.SpellResolver:Resolve(glyph.spellID)
            cell:Bind(glyph.itemID, { glyph = true, name = spell.known and spell.name or glyph.name, fallbackIcon = glyph.icon })
            cell.onClick = function()
                if cell.snapshot and cell.snapshot.state == "loaded" then return end
                window.resolver:Request(glyph.itemID, view.ownerToken, function(snapshot)
                    if window.viewController:IsCurrent(view.generation) then cell:Render(snapshot) end
                end)
            end
        else
            cell:Clear()
            cell.onClick = nil
            cell.icon:SetTexture("Interface\\Spellbook\\UI-Glyph-Rune1")
            cell.icon:SetVertexColor(0.35, 0.35, 0.35, 1)
        end
    end
    return y + 312
end
