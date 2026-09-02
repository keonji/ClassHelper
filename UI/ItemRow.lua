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

function ItemRow.Create(parent, resolver, view)
    if not parent then return nil end
    local frame = ns:CreateUIFrame(nil, parent, "Button")
    if not frame then return nil end
    frame:SetSize(820, 24)
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
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 4, 0)
    end
    row.nameText = ns.Widgets.Label(frame, "", ns.Theme.Fonts.body)
    row.stateText = ns.Widgets.Label(frame, ns.L:Get("ITEM_IDLE_TEST_ONLY"), ns.Theme.Fonts.status)

    frame:SetScript("OnClick", function()
        row:Click()
    end)
    frame:SetScript("OnEnter", function()
        local snapshot = row.snapshot
        if snapshot and snapshot.state == "loaded" and snapshot.link then
            ns.Compat:ShowItemTooltip(frame, snapshot.link)
        end
    end)
    frame:SetScript("OnLeave", function()
        ns.Compat:HideItemTooltip()
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

function Row:Render(snapshot)
    local view = self.view
    if view and view.controller and not view.controller:IsCurrent(view.generation) then return end

    local state = snapshot and snapshot.state or "idle"
    self.snapshot = snapshot
    if state == "loaded" and snapshot.name then
        self.nameText:SetText(snapshot.name)
        self.stateText:SetText("")
        if self.icon then
            local color = QUALITY_COLOR[snapshot.quality] or QUALITY_COLOR[0]
            self.icon:SetVertexColor(color[1], color[2], color[3], 1.0)
        end
    else
        self.nameText:SetText(("Item %d"):format(self.itemID or 0))
        self.stateText:SetText(describeState(snapshot))
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
    end)
end

return ItemRow
