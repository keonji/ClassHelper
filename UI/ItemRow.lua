-- UI/ItemRow.lua: one item row widget. It reads resolver state only (never queries
-- the server on render), labels every state textually, and hands a resolved link to
-- HandleModifiedItemClick on click. Rows never store themselves in resolver state.

local addonName, ns = ...

local ItemRow = {}
ns.ItemRow = ItemRow

local QUALITY_COLOR = {
    [-1] = { 0.55, 0.55, 0.55 },
    [0] = { 0.80, 0.80, 0.80 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 0.75, 0.08 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 0.94, 0.09, 0.00 },
    [6] = { 1.00, 0.60, 0.00 },
    [7] = { 0.69, 0.28, 0.97 },
}

ItemRow.QualityColor = QUALITY_COLOR

local Row = {}
local RowMeta = { __index = Row }

local function describeState(snapshot)
    local state = snapshot and snapshot.state or "idle"
    if state == "queued" or state == "loading" then
        return ns.L:Get("ITEM_STATE_LOADING")
    elseif state == "failed" then
        return ns.L:Get("ITEM_STATE_FAILED")
    end
    return ns.L:Get("ITEM_IDLE_TEST_ONLY")
end

function ItemRow.Create(parent, resolver, view, width)
    if not parent then return nil end
    local frame = ns:CreateUIFrame(nil, parent, "Button")
    if not frame then return nil end
    frame:SetSize(width or 820, width and 52 or 40)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")

    local row = setmetatable({
        frame = frame,
        resolver = resolver,
        view = view,
    }, RowMeta)

    row.background = ns.Widgets.Fill(frame, "BACKGROUND")
    row.icon = ns.Compat:CreateTexture(frame, "ARTWORK")
    if row.icon then
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 6, 0)
    end
    row.nameText = ns.Widgets.Label(frame, "", ns.Theme.Fonts.body)
    row.nameText:SetPoint("LEFT", 46, 0)
    row.nameText:SetWidth(510)
    row.nameText:SetJustifyH("LEFT")
    row.stateText = ns.Widgets.Label(frame, ns.L:Get("ITEM_IDLE_TEST_ONLY"), ns.Theme.Fonts.status)
    row.stateText:SetPoint("RIGHT", -10, 0)
    row.stateText:SetWidth(240)
    row.stateText:SetJustifyH("RIGHT")
    if width then
        row.rankText = ns.Widgets.Label(frame, "", ns.Theme.Fonts.status)
        row.rankText:SetPoint("LEFT", 44, 8)
        row.rankText:SetWidth(32)
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("TOPLEFT", 80, -8)
        row.nameText:SetWidth(width - 270)
        row.nameText:SetHeight(18)
        row.stateText:ClearAllPoints()
        row.stateText:SetPoint("BOTTOMLEFT", 80, 8)
        row.stateText:SetWidth(width - 92)
        row.stateText:SetHeight(14)
        row.stateText:SetJustifyH("LEFT")
        row.adviceText = ns.Widgets.Label(frame, "", ns.Theme.Fonts.status)
        row.adviceText:SetPoint("TOPRIGHT", -10, -8)
        row.adviceText:SetWidth(170)
        row.adviceText:SetHeight(18)
        row.adviceText:SetJustifyH("RIGHT")
    end

    frame:SetScript("OnClick", function()
        row:Click()
    end)
    frame:SetScript("OnEnter", function()
        row.background:SetTexture(unpack(ns.Theme.Colors.raised))
        local details = row.stateText:GetText() or ""
        if row.data and row.data.compact and (details ~= "" or row.recommendation) then
            if not row.detailsFrame then
                -- ScrollFrame descendants are composited with the scrolling content in 3.3.5a.
                row.detailsFrame = ns:CreateUIFrame(nil, ns:GetUIParent())
                row.detailsFrame:SetWidth(580)
                row.detailsFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
                row.detailsFrame:SetFrameStrata("TOOLTIP")
                ns.Widgets.Backdrop(row.detailsFrame)
                row.detailsText = ns.Widgets.Label(row.detailsFrame, "", ns.Theme.Fonts.body)
                row.detailsText:SetWidth(548)
                row.detailsText:SetPoint("TOPLEFT", 16, -12)
                row.detailsText:SetJustifyH("LEFT")
            end
            if row.recommendation then details = details .. "\n\n" .. ns.L:Get("RECOMMENDATION_LIMITS") end
            row.detailsText:SetText(details)
            row.detailsFrame:SetHeight(row.detailsText:GetStringHeight() + 24)
            row.detailsFrame:Show()
        end
        local snapshot = row.snapshot
        if snapshot and snapshot.state == "loaded" and snapshot.link then
            ns.Compat:ShowItemTooltip(frame, snapshot.link)
        end
    end)
    frame:SetScript("OnLeave", function()
        if row.detailsFrame then row.detailsFrame:Hide() end
        row.background:SetTexture(unpack(row.recommendationColor or ns.Theme.Colors.panel))
        ns.Compat:HideItemTooltip()
    end)
    frame:SetScript("OnHide", function()
        if row.detailsFrame then row.detailsFrame:Hide() end
    end)

    return row
end

function Row:Bind(itemID, data, view)
    self.itemID = itemID
    self.data = data
    if view then self.view = view end
    self:Render(self.resolver:Peek(itemID))
end

function Row:Unbind()
    if self.subscriptionID then
        self.resolver:Unsubscribe(self.subscriptionID)
        self.subscriptionID = nil
    end
end

function Row:SetRecommendation(advice)
    self.recommendation = advice
    self.recommendationColor = nil
    if not self.adviceText then return end
    self.adviceText:SetText("")
    if advice and advice.best then
        local weighted = advice.mode == "weights"
        self.recommendationColor = weighted and { 0.10, 0.24, 0.17, 1 } or { 0.25, 0.20, 0.10, 1 }
        self.adviceText:SetText(ns.L:Get(weighted and "ADVISOR_WEIGHTS_BEST" or "ADVISOR_SOURCE_BEST"))
        self.adviceText:SetTextColor(unpack(weighted and { 0.45, 0.95, 0.62, 1 } or ns.Theme.Colors.titleText))
    elseif advice and advice.score then
        self.adviceText:SetText(ns.L:Get("ADVISOR_SCORE"):format(advice.score))
    end
    self.background:SetTexture(unpack(self.recommendationColor or ns.Theme.Colors.panel))
end

function Row:Render(snapshot)
    local view = self.view
    if view and view.controller and not view.controller:IsCurrent(view.generation) then return end

    local state = snapshot and snapshot.state or "idle"
    self.snapshot = snapshot
    local prefix = ""
    if self.data and self.data.slot and not self.data.compact then
        prefix = (ns.L:Get("SLOT_" .. self.data.slot) or self.data.slot)
        if not self.data.pooled and (self.data.slot == "FINGER" or self.data.slot == "TRINKET") then
            prefix = prefix .. " " .. tostring(self.data.position or 1)
        end
        prefix = prefix .. " — "
    end
    if self.rankText then self.rankText:SetText(self.data.contentMode == "pvp" and "" or "#" .. tostring(self.data.rank or "")) end
    if state == "loaded" and snapshot.name then
        self.nameText:SetText(prefix .. snapshot.name)
        self.stateText:SetText("")
        local color = QUALITY_COLOR[snapshot.quality] or QUALITY_COLOR[0]
        self.nameText:SetTextColor(color[1], color[2], color[3])
        if self.icon then
            self.icon:SetTexture(snapshot.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.icon:SetVertexColor(1, 1, 1, 1)
        end
    else
        self.nameText:SetText(prefix .. ns.L:Get("ITEM_UNKNOWN_NAME"):format(self.itemID or 0))
        self.nameText:SetTextColor(0.9, 0.87, 0.78)
        self.stateText:SetText(describeState(snapshot))
        if self.icon then
            self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            self.icon:SetVertexColor(1, 1, 1, 1)
        end
    end
    if self.data and self.data.compact then
        local details = {}
        local acquisition = self.data.sourceText
        if acquisition and not acquisition:find("https?://") and not acquisition:find("Icy Veins", 1, true) then
            details[#details + 1] = acquisition
        end
        if self.data.pvp or self.data.sourceType == "pvp" then details[#details + 1] = "PvP" end
        if self.data.suffixID and self.data.suffixID ~= 0 then details[#details + 1] = ns.L:Get("BIS_SUFFIX"):format(self.data.suffixID) end
        if state ~= "loaded" then details[#details + 1] = describeState(snapshot) end
        self.stateText:SetText(table.concat(details, " • "))
    end
end

function Row:Click()
    local view = self.view
    if not view or not view.controller or not view.controller:IsCurrent(view.generation) then return end

    local snapshot = self.resolver:Peek(self.itemID)
    if snapshot.state == "loaded" then
        if snapshot.link then
            ns.Compat:HandleModifiedItemClick(snapshot.link)
        end
        return
    end

    self:Unbind()
    self.subscriptionID = self.resolver:Request(self.itemID, view.ownerToken, function(latest)
        self:Render(latest)
        if self.onResolved then self.onResolved() end
    end)
end

return ItemRow
