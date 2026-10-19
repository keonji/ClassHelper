local _, ns = ...
local Section = { trees = {} }
ns.TalentSection = Section

function Section:Clear()
    for _, tree in ipairs(self.trees) do tree.frame:Hide() end
    if GameTooltip then GameTooltip:Hide() end
end

local function tooltip(node)
    if not GameTooltip then return end
    GameTooltip:SetOwner(node.frame, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    local spellID = node.data.spells[math.max(1, node.rank)]
    if ns.Compat:GetSpellInfo(spellID) then
        GameTooltip:SetHyperlink("spell:" .. spellID)
    else
        GameTooltip:AddLine(ns.L.locale == "ruRU" and node.data.nameRu or node.data.name, 1, 0.82, 0)
    end
    GameTooltip:AddLine(ns.L:Get("TALENT_READ_ONLY"):format(node.rank, node.data.maxRank), 1, 1, 1)
    GameTooltip:Show()
end

function Section:Render(parent, classToken, build, y)
    self:Clear()
    local chosen = {}
    for _, allocation in ipairs(build.allocations) do chosen[allocation.talentID] = allocation.rank end
    for index, data in ipairs(ns.TalentCatalog[classToken]) do
        local tree = self.trees[index]
        if not tree then
            tree = { frame = ns.Widgets.Panel(parent, 184, 438), nodes = {}, lines = {} }
            tree.frame:SetBackdrop({ bgFile = ns.Art.Window.background, edgeFile = ns.Art.Window.border,
                tile = true, tileSize = 16, edgeSize = 12, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
            tree.frame:SetBackdropColor(0.08, 0.075, 0.07, 1)
            tree.title = ns.Widgets.Label(tree.frame, "", "GameFontNormal")
            tree.title:SetPoint("TOPLEFT", 12, -9)
            tree.title:SetWidth(128)
            tree.title:SetHeight(24)
            tree.title:SetJustifyH("LEFT")
            tree.title:SetTextColor(unpack(ns.Theme.Colors.gold))
            tree.points = ns.Widgets.Label(tree.frame, "", "NumberFontNormal")
            tree.points:SetPoint("TOPRIGHT", -12, -14)
            tree.points:SetTextColor(unpack(ns.Theme.Colors.gold))
            tree.pieces = {}
            for piece, suffix in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
                local texture = ns.Compat:CreateTexture(tree.frame, "BACKGROUND")
                local right, bottom = piece % 2 == 0, piece > 2
                local leftWidth, topHeight = 172 * 256 / 300, 398 * 256 / 331
                texture:SetSize(right and 172 - leftWidth or leftWidth, bottom and 398 - topHeight or topHeight)
                texture:SetPoint("TOPLEFT", 6 + (right and leftWidth or 0), -34 - (bottom and topHeight or 0))
                texture:SetTexCoord(0, right and 0.6875 or 1, 0, bottom and 0.5859375 or 1)
                texture:SetAlpha(0.62)
                tree.pieces[piece] = { texture = texture, suffix = suffix }
            end
            self.trees[index] = tree
        end
        tree.frame:ClearAllPoints()
        tree.frame:SetPoint("TOPLEFT", (index - 1) * 192, -y)
        tree.frame:Show()
        for _, line in ipairs(tree.lines) do line:Hide() end
        for _, node in ipairs(tree.nodes) do node.frame:Hide() end
        for _, piece in ipairs(tree.pieces) do piece.texture:SetTexture("Interface\\TalentFrame\\" .. data.background .. "-" .. piece.suffix) end
        local points, positions = 0, {}
        for _, talent in ipairs(data.talents) do positions[talent.id] = { x = 12 + talent.col * 40, y = 46 + talent.row * 34 } end
        local lineCount = 0
        local function line(x, yy, width, height, active)
            lineCount = lineCount + 1
            local texture = tree.lines[lineCount] or ns.Compat:CreateTexture(tree.frame, "BORDER")
            tree.lines[lineCount] = texture
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", x, -yy)
            texture:SetSize(math.max(2, width), math.max(2, height))
            texture:SetTexture(active and 0.8 or 0.35, active and 0.65 or 0.35, 0.2, 1)
            texture:Show()
        end
        for j, talent in ipairs(data.talents) do
            local node = tree.nodes[j]
            if not node then
                node = { frame = ns:CreateUIFrame(nil, tree.frame, "Button") }
                node.frame:SetSize(30, 30)
                node.frame:EnableMouse(true)
                node.icon = ns.Compat:CreateTexture(node.frame, "ARTWORK")
                node.icon:SetAllPoints()
                node.edge = ns.Compat:CreateTexture(node.frame, "OVERLAY")
                node.edge:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                node.edge:SetSize(50, 50)
                node.edge:SetPoint("CENTER")
                node.rankBackground = ns.Compat:CreateTexture(node.frame, "OVERLAY")
                node.rankBackground:SetTexture(0, 0, 0, 0.85)
                node.rankBackground:SetSize(26, 12)
                node.rankBackground:SetPoint("BOTTOMRIGHT", 3, -3)
                node.count = ns.Widgets.Label(node.frame, "", "NumberFontNormal")
                node.count:SetPoint("BOTTOMRIGHT", 3, -3)
                node.frame:SetScript("OnEnter", function() tooltip(node) end)
                node.frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                node.frame:SetScript("OnHide", function() if GameTooltip and GameTooltip:IsOwned(node.frame) then GameTooltip:Hide() end end)
                tree.nodes[j] = node
            end
            node.data, node.rank = talent, chosen[talent.id] or 0
            points = points + node.rank
            local p = positions[talent.id]
            node.frame:ClearAllPoints()
            node.frame:SetPoint("TOPLEFT", p.x, -p.y)
            node.frame:Show()
            node.icon:SetTexture(talent.icon or ns.Art.Question)
            node.icon:SetVertexColor(node.rank > 0 and 1 or 0.35, node.rank > 0 and 1 or 0.35, node.rank > 0 and 1 or 0.35, 1)
            node.edge:SetVertexColor(node.rank > 0 and 1 or 0.45, node.rank > 0 and 0.82 or 0.45, node.rank > 0 and 0.25 or 0.45, 1)
            node.count:SetText(node.rank .. "/" .. talent.maxRank)
            node.count:SetTextColor(node.rank > 0 and 1 or 0.7, node.rank > 0 and 0.82 or 0.7, node.rank > 0 and 0 or 0.7)
            local dependency = positions[talent.dependsOn]
            if dependency then
                local fromX, toX = dependency.x + 15, p.x + 15
                local midY = dependency.y + 32
                line(fromX, midY, 2, 3, node.rank > 0)
                line(math.min(fromX, toX), midY + 3, math.abs(fromX - toX), 2, node.rank > 0)
                line(toX, midY + 3, 2, p.y - midY - 3, node.rank > 0)
            end
        end
        tree.title:SetText(ns.L.locale == "ruRU" and data.nameRu or data.name)
        tree.points:SetText(tostring(points))
    end
    return y + 450
end
