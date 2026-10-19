local _, ns = ...
local Section = { tiles = {}, arrows = {} }
ns.RotationSection = Section

function Section:Clear()
    if self.frame then self.frame:Hide() end
    for _, tile in ipairs(self.tiles) do tile.frame:Hide() end
    for _, arrow in ipairs(self.arrows) do arrow:Hide() end
end

function Section:Render(parent, diagram, build, y)
    self:Clear()
    if not diagram then return y end
    self.frame = self.frame or ns:CreateUIFrame(nil, parent)
    local frame = self.frame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 0, -y)
    frame:SetWidth(576)
    frame:Show()
    local frostPoints = 0
    for _, a in ipairs(build.allocations) do if a.tree == 3 then frostPoints = frostPoints + a.rank end end
    for i, data in ipairs(diagram.steps) do
        local tile = self.tiles[i]
        if not tile then
            tile = { frame = ns:CreateUIFrame(nil, frame, "Button") }
            tile.frame:SetSize(44, 44)
            tile.frame:EnableMouse(true)
            tile.frame:SetBackdrop({ bgFile = ns.Art.Window.background, edgeFile = ns.Art.Window.border,
                tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
            tile.icon = ns.Compat:CreateTexture(tile.frame, "ARTWORK")
            tile.icon:SetPoint("TOPLEFT", 4, -4)
            tile.icon:SetPoint("BOTTOMRIGHT", -4, 4)
            tile.number = ns.Widgets.Label(tile.frame, "", "NumberFontNormal")
            tile.number:SetPoint("TOPLEFT", 1, 3)
            tile.name = ns.Widgets.Label(tile.frame, "", "GameFontHighlightSmall")
            tile.name:SetPoint("TOP", tile.frame, "BOTTOM", 0, -6)
            tile.name:SetWidth(88)
            tile.name:SetHeight(34)
            tile.name:SetJustifyH("CENTER")
            tile.frame:SetScript("OnEnter", function()
                if not GameTooltip then return end
                GameTooltip:SetOwner(tile.frame, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                if ns.Compat:GetSpellInfo(tile.spellID) then GameTooltip:SetHyperlink("spell:" .. tile.spellID)
                else GameTooltip:AddLine(tile.data.name, 1, 0.82, 0) end
                local condition = ns.L.locale == "ruRU" and tile.data.conditionRu or tile.data.condition
                if condition and condition ~= "" then GameTooltip:AddLine(condition, 1, 1, 1, true) end
                GameTooltip:Show()
            end)
            tile.frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            tile.frame:SetScript("OnHide", function() if GameTooltip and GameTooltip:IsOwned(tile.frame) then GameTooltip:Hide() end end)
            self.tiles[i] = tile
        end
        local row, column = math.floor((i - 1) / 6), (i - 1) % 6
        if row % 2 == 1 then column = 5 - column end
        tile.frame:ClearAllPoints()
        tile.frame:SetPoint("TOPLEFT", column * 96 + 26, -row * 108)
        tile.frame:Show()
        tile.data = data
        tile.spellID = data.spellID == 42833 and frostPoints >= 17 and 47610 or data.spellID
        local spell = ns.SpellResolver:Resolve(tile.spellID)
        tile.icon:SetTexture(spell.icon or (tile.spellID ~= data.spellID and data.ffbIcon) or data.icon or ns.Art.Question)
        tile.name:SetText(spell.known and spell.name or (tile.spellID == 47610 and "Frostfire Bolt" or data.name))
        tile.number:SetText(tostring(i))
        if i < #diagram.steps then
            local arrow = self.arrows[i] or ns.Compat:CreateTexture(frame, "ARTWORK")
            self.arrows[i] = arrow
            arrow:SetTexture(ns.Art.Dropdown.expand)
            arrow:SetVertexColor(1, 0.82, 0.3, 1)
            arrow:ClearAllPoints()
            arrow:SetSize(20, 20)
            if i % 6 == 0 then
                arrow:SetPoint("TOPLEFT", column * 96 + 38, -row * 108 - 85)
                arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
            else
                arrow:SetPoint("TOPLEFT", column * 96 + (row % 2 == 0 and 85 or -9), -row * 108 - 12)
                arrow:SetTexCoord(row % 2 == 0 and 0 or 1, row % 2 == 0 and 1 or 0, 0, 1)
            end
            arrow:Show()
        end
    end
    local height = math.ceil(#diagram.steps / 6) * 108
    frame:SetHeight(height)
    return y + height + 10
end
