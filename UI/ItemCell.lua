local _, ns = ...

local ItemCell = {}
ns.ItemCell = ItemCell

local WEIGHTS_COLOR = { 0.25, 1, 0.35, 1 }

local Cell = {}
local CellMeta = { __index = Cell }

function ItemCell.Create(parent, resolver, view, size)
    local frame = ns:CreateUIFrame(nil, parent, "Button")
    if not frame then return nil end
    size = size or 34
    frame:SetSize(size, size)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    local cell = setmetatable({ frame = frame, resolver = resolver, view = view }, CellMeta)
    cell.icon = ns.Compat:CreateTexture(frame, "ARTWORK")
    cell.icon:SetAllPoints()
    cell.icon:Show()
    -- UI-ActionButton-Border draws its glow in the centre 36/62 of the texture.
    cell.border = ns.Compat:CreateTexture(frame, "OVERLAY")
    cell.border:SetTexture(ns.Art.CellBorder)
    cell.border:SetBlendMode("ADD")
    cell.border:SetSize(size * 62 / 36, size * 62 / 36)
    cell.border:SetPoint("CENTER", frame, "CENTER", 0, 0)
    cell.border:Hide()
    cell.moreText = ns.Widgets.Label(frame, "", "NumberFontNormal")
    cell.moreText:SetPoint("BOTTOMRIGHT", -2, 2)
    cell.moreText:Hide()
    frame:SetScript("OnEnter", function() cell:ShowTooltip() end)
    frame:SetScript("OnLeave", function() ns.Compat:HideItemTooltip() end)
    frame:SetScript("OnHide", function() if GameTooltip and GameTooltip:IsOwned(frame) then ns.Compat:HideItemTooltip() end end)
    frame:SetScript("OnClick", function() cell:Click() end)
    cell:Clear()
    return cell
end

function Cell:Bind(itemID, data)
    self.itemID, self.data = itemID, data
    self:Render(self.resolver:Peek(itemID))
end

function Cell:Clear()
    self.itemID, self.data, self.snapshot = nil, nil, nil
    self.icon:SetTexture(ns.Art.EmptyCell)
    self.icon:SetVertexColor(1, 1, 1, 1)
    self:SetRecommendation(nil)
    self:SetMore(0)
end

function Cell:Render(snapshot)
    self.snapshot = snapshot
    local loaded = snapshot and snapshot.state == "loaded"
    self.icon:SetTexture(loaded and snapshot.texture or self.data and self.data.fallbackIcon or ns.Art.Question)
    self:SetRecommendation(self.recommendation)
end

function Cell:SetRecommendation(advice)
    self.recommendation = advice
    local color
    if advice and advice.best then
        color = advice.mode == "weights" and WEIGHTS_COLOR or ns.Theme.Colors.gold
    elseif self.snapshot and self.snapshot.state == "loaded" and (self.snapshot.quality or 0) >= 2 then
        local quality = ns.ItemRow.QualityColor[self.snapshot.quality]
        color = quality and { quality[1], quality[2], quality[3], 0.7 }
    end
    if color then
        self.border:SetVertexColor(unpack(color))
        self.border:Show()
    else
        self.border:Hide()
    end
end

function Cell:SetMore(count)
    if count and count > 0 then
        self.moreText:SetText("+" .. count)
        self.moreText:Show()
    else
        self.moreText:SetText("")
        self.moreText:Hide()
    end
end

function Cell:ShowTooltip()
    if not self.itemID then return end
    local snapshot = self.snapshot
    if snapshot and snapshot.state == "loaded" and snapshot.link then
        ns.Compat:ShowItemTooltip(self.frame, snapshot.link)
        return
    end
    if not GameTooltip then return end
    -- SetHyperlink on an uncached item makes the client query the server.
    GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
    local prefix = self.data and (self.data.contentMode == "pvp" or self.data.glyph) and "" or ns.L:Get("BIS_SLOT_RANK"):format(self.data and self.data.rank or 0) .. "  "
    GameTooltip:SetText(prefix .. (self.data and self.data.glyph and self.data.name or ns.L:Get("ITEM_UNKNOWN_NAME"):format(self.itemID)))
    if self.data and self.data.glyph then GameTooltip:AddLine(ns.L:Get("GLYPH_CLICK_TO_LOAD"), 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end

function Cell:Click()
    local snapshot = self.snapshot
    if snapshot and snapshot.state == "loaded" and snapshot.link
        and ns.Compat:HandleModifiedItemClick(snapshot.link) then return end
    if self.onClick then self.onClick() end
end

return ItemCell
