-- UI/GearSection.lua: fixture Gear tab renderer and batch flow. Rows are the only
-- place that could begin a query; the tab render itself never queries. Batch start
-- requires confirmation through a StaticPopup because bulk queries can be throttled.

local addonName, ns = ...

local GearSection = {}
ns.GearSection = GearSection

local MAX_BATCH = 80

GearSection.rows = {}
GearSection.container = nil
GearSection.resolver = nil
GearSection.controller = nil
GearSection.statusText = nil
GearSection.window = nil
GearSection.view = nil

function GearSection:Initialize()
end

function GearSection:RefreshRecommendations()
    if not self.window or not self.window.profile.databaseProfile or not self.view
        or not self.controller:IsCurrent(self.view.generation) then return end
    if self.mode == "overview" then
        for _, slotRow in ipairs(self.slotRows or {}) do
            if slotRow.frame:IsShown() and not slotRow.empty then
                local candidates = {}
                for index, data in ipairs(slotRow.items) do
                    candidates[index] = { data = data, snapshot = self.resolver:Peek(data.itemID) }
                end
                local advice, mode = ns.GearAdvisor:Evaluate(self.window.profile, self.window.selectedEra, candidates)
                for index, cell in ipairs(slotRow.cells) do
                    if cell.itemID then cell:SetRecommendation(advice[index]) end
                end
                self.advisorMode = mode
            end
        end
        return
    end
    local advice, mode = ns.GearAdvisor:Evaluate(self.window.profile, self.window.selectedEra, self.rows)
    for index, row in ipairs(self.rows) do row:SetRecommendation(advice[index]) end
    self.advisorMode = mode
end

function GearSection:Clear()
    if self.allSlotsButton then self.allSlotsButton:Hide() end
    if self.detailFrame then self.detailFrame:Hide() end
    if self.infoPanel then self.infoPanel:Hide() end
    for _, slotRow in ipairs(self.slotRows or {}) do
        slotRow.frame:Hide()
        for _, cell in ipairs(slotRow.cells) do cell:Clear() end
    end
    if self.container then
        local viewport = self.container.viewport
        viewport:ClearAllPoints()
        viewport:SetPoint("TOP", 0, -108)
        viewport:SetSize(868, 436)
        self.container:SetWidth(868)
    end
    for _, note in ipairs(self.notes or {}) do note:Hide() end
    self.notes = {}
    self.groupHeaders = {}
    for index = #self.rows, 1, -1 do
        local row = self.rows[index]
        row.onResolved = nil
        row:Unbind()
        if row.frame then
            row.frame:Hide()
            row.frame:SetParent(nil)
        end
    end
    self.rows = {}
    if self.batchButton then self.batchButton:Hide() end
end

local ROW_HEIGHT, ROW_STEP, CELL_SIZE, CELL_STEP, CELLS = 44, 46, 34, 38, 6
local LIST_WIDTH = 600

function GearSection:GroupItems(gear)
    local groups = {}
    for index, item in ipairs(gear.items) do
        if not groups[item.slot] then groups[item.slot] = {} end
        groups[item.slot][#groups[item.slot] + 1] = { data = item, index = index }
    end
    for slot, entries in pairs(groups) do
        table.sort(entries, function(a, b)
            if a.data.rank ~= b.data.rank then return a.data.rank < b.data.rank end
            return a.index < b.index
        end)
        local items = {}
        for index, entry in ipairs(entries) do items[index] = entry.data end
        groups[slot] = items
    end
    return groups
end

function GearSection:SlotsForEra(profile, era, tabKey)
    local seen, slots = {}, {}
    for _, stage in ipairs(self.window:GetStages(era)) do
        local section = ns.GuideService:GetSection(profile, stage.key, tabKey)
        for _, item in ipairs(section and section.items or {}) do
            if not seen[item.slot] then seen[item.slot] = true; slots[#slots + 1] = item.slot end
        end
    end
    local order = ns.BISCatalog.slotOrder
    table.sort(slots, function(a, b) return (order[a] or 99) < (order[b] or 99) end)
    return slots
end

function GearSection:PlaceViewport(top, height)
    local host = self.container
    host.viewport:ClearAllPoints()
    host.viewport:SetPoint("TOPLEFT", 20, top)
    host.viewport:SetSize(LIST_WIDTH, height)
    host:SetWidth(LIST_WIDTH)
end

function GearSection:SlotRow(index)
    self.slotRows = self.slotRows or {}
    local slotRow = self.slotRows[index]
    if slotRow then return slotRow end
    local frame = ns:CreateUIFrame(nil, self.container, "Button")
    frame:SetSize(LIST_WIDTH - 16, ROW_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("LeftButtonUp")
    slotRow = { frame = frame, cells = {} }
    slotRow.background = ns.Compat:CreateTexture(frame, "BACKGROUND")
    slotRow.background:SetTexture("Interface\\Buttons\\WHITE8X8")
    slotRow.background:SetAllPoints()
    if slotRow.background.SetGradientAlpha then
        slotRow.background:SetGradientAlpha("HORIZONTAL", 0.32, 0.27, 0.20, 0.75, 0.05, 0.05, 0.05, 0.05)
    else
        slotRow.background:SetVertexColor(0.32, 0.27, 0.20, 0.6)
    end
    slotRow.divider = ns.Compat:CreateTexture(frame, "BORDER")
    slotRow.divider:SetTexture(0.30, 0.26, 0.20, 0.8)
    slotRow.divider:SetHeight(1)
    slotRow.divider:SetPoint("BOTTOMLEFT")
    slotRow.divider:SetPoint("BOTTOMRIGHT")
    slotRow.highlight = ns.Compat:CreateTexture(frame, "HIGHLIGHT")
    slotRow.highlight:SetTexture(ns.Art.RowHighlight)
    slotRow.highlight:SetBlendMode("ADD")
    slotRow.highlight:SetAllPoints()
    slotRow.icon = ns.Compat:CreateTexture(frame, "ARTWORK")
    slotRow.icon:SetSize(32, 32)
    slotRow.icon:SetPoint("LEFT", 8, 0)
    slotRow.nameText = ns.Widgets.Label(frame, "", ns.Theme.Fonts.slot)
    slotRow.nameText:SetPoint("LEFT", 50, 0)
    slotRow.nameText:SetWidth(LIST_WIDTH - 16 - 58 - CELLS * CELL_STEP)
    slotRow.nameText:SetJustifyH("LEFT")
    for cellIndex = 1, CELLS do
        local cell = ns.ItemCell.Create(frame, self.resolver, self.view, CELL_SIZE)
        cell.frame:SetPoint("RIGHT", -(8 + (CELLS - cellIndex) * CELL_STEP), 0)
        slotRow.cells[cellIndex] = cell
    end
    frame:SetScript("OnClick", function() self:OpenSlot(slotRow.slot) end)
    self.slotRows[index] = slotRow
    return slotRow
end

function GearSection:RenderOverview(groups, slots)
    local theme = ns.Theme
    self.mode = "overview"
    self.modes[self.view.context.tabKey] = "overview"
    self:PlaceViewport(-116, 404)
    if not self.allSlotsButton then
        self.allSlotsButton = ns.Widgets.FramedButton(self.window.frame, "ClassHelperAllSlotsButton", ns.L:Get("BATCH_REQUEST"), function()
            local ids = {}
            for _, item in ipairs(self.gear.items) do ids[#ids + 1] = item.itemID end
            self:ClickBatch(ids, true)
        end)
        self.allSlotsButton:SetSize(360, 24)
        self.allSlotsButton:SetPoint("TOPRIGHT", -36, -80)
    end
    self.allSlotsButton:Show()
    for _, slotRow in ipairs(self.slotRows or {}) do slotRow.frame:Hide() end
    for index, slot in ipairs(slots) do
        local slotRow = self:SlotRow(index)
        local items = groups[slot] or {}
        slotRow.slot, slotRow.items, slotRow.empty = slot, items, #items == 0
        slotRow.frame.slot = slot
        slotRow.frame:SetParent(self.container)
        slotRow.frame:ClearAllPoints()
        slotRow.frame:SetPoint("TOPLEFT", 8, -(index - 1) * ROW_STEP)
        slotRow.icon:SetTexture(ns.Art.SlotTexture(slot))
        slotRow.icon:SetDesaturated(slotRow.empty)
        slotRow.icon:SetAlpha(slotRow.empty and 0.4 or 1)
        slotRow.nameText:SetText(ns.L:Get("SLOT_" .. slot))
        slotRow.nameText:SetTextColor(unpack(slotRow.empty and theme.Colors.dimText or theme.Colors.slotText))
        for cellIndex, cell in ipairs(slotRow.cells) do
            cell.view = self.view
            cell:Clear()
            if items[cellIndex] then cell:Bind(items[cellIndex].itemID, items[cellIndex]) end
            cell.onClick = function() self:OpenSlot(slot) end
        end
        slotRow.cells[CELLS]:SetMore(#items - CELLS)
        slotRow.frame:Show()
    end
    self.container:SetHeight(math.max(436, #slots * ROW_STEP))
    if self.detailFrame then self.detailFrame:Hide() end
    self:RefreshRecommendations()
    if self.restoreScroll then
        local limit = math.max(0, self.container:GetHeight() - 404)
        self.container.viewport:SetVerticalScroll(math.min(self.restoreScroll, limit))
        self.restoreScroll = nil
    end
    ns.Widgets.UpdateScroll(self.container)
end

function GearSection:BuildDetailFrame()
    local window = self.window
    self.detailFrame = ns:CreateUIFrame(nil, window.frame)
    self.detailFrame:SetSize(LIST_WIDTH, 30)
    self.detailFrame:SetPoint("TOPLEFT", 20, -84)
    self.backButton = ns.Widgets.Button(self.detailFrame, nil, ns.L:Get("BIS_BACK"), function() self:CloseSlot() end)
    self.backButton:SetSize(80, 24)
    self.backButton:SetPoint("LEFT", 0, 0)
    self.slotTitle = ns.Widgets.Label(self.detailFrame, "", ns.Theme.Fonts.header)
    self.slotTitle:SetPoint("LEFT", 92, 0)
    self.slotTitle:SetWidth(150)
    self.slotTitle:SetJustifyH("LEFT")
    self.infoButton = ns.Widgets.Button(self.detailFrame, nil, ns.L:Get("BIS_ABOUT"), function()
        if self.infoPanel:IsShown() then self.infoPanel:Hide() else self.infoPanel:Show() end
    end)
    self.infoButton:SetSize(90, 24)
    self.infoButton:SetPoint("RIGHT", 0, 0)
    self.infoPanel = ns:CreateUIFrame(nil, window.frame)
    self.infoPanel:SetSize(560, 220)
    self.infoPanel:SetPoint("TOPLEFT", 40, -118)
    self.infoPanel:SetFrameStrata("FULLSCREEN_DIALOG")
    self.infoPanel:EnableMouse(true)
    ns.Widgets.Backdrop(self.infoPanel)
    self.infoText = ns.Widgets.Label(self.infoPanel, "", ns.Theme.Fonts.body)
    self.infoText:SetPoint("TOPLEFT", 16, -16)
    self.infoText:SetWidth(528)
    self.infoText:SetJustifyH("LEFT")
end

function GearSection:RenderDetail(gear, items)
    self.mode = "detail"
    self.modes[self.view.context.tabKey] = "detail"
    if not self.detailFrame then self:BuildDetailFrame() end
    self.detailFrame:Show()
    self.infoPanel:Hide()
    local details = {}
    if not gear.imported then
        for _, key in ipairs(gear.paragraphs or {}) do details[#details + 1] = ns.L:Get(key) end
    end
    if gear.referenceRaceText then details[#details + 1] = gear.referenceRaceText end
    details[#details + 1] = ns.L:Get("RECOMMENDATION_LIMITS")
    self.infoText:SetText(table.concat(details, "\n\n"))
    self.infoPanel:SetHeight(math.max(140, self.infoText:GetStringHeight() + 32))
    self.slotTitle:SetText(ns.L:Get("SLOT_" .. self.selectedSlot))
    self:PlaceViewport(-118, 402)
    if not self.batchButton then
        self.batchButton = ns.Widgets.Button(self.detailFrame, "ClassHelperGearBatchButton", "", function() self:ClickBatch() end)
    end
    self.batchButton:SetParent(self.detailFrame)
    self.batchButton:ClearAllPoints()
    self.batchButton:SetSize(220, 24)
    self.batchButton:SetPoint("RIGHT", -98, 0)
    self.batchButton.labelWidget:SetText(ns.L:Get("BIS_LOAD_SLOT"))
    self.batchButton:Show()
    local y = 4
    for _, item in ipairs(items) do
        local row = ns.ItemRow.Create(self.container, self.resolver, self.view, 568)
        row.frame:SetPoint("TOPLEFT", 8, -y)
        local data = {}
        for key, value in pairs(item) do data[key] = value end
        data.compact = true
        row:Bind(data.itemID, data, self.view)
        row.onResolved = function() self:RefreshRecommendations() end
        self.rows[#self.rows + 1] = row
        y = y + 56
    end
    self.container:SetHeight(math.max(402, y))
    self:RefreshRecommendations()
    ns.Widgets.UpdateScroll(self.container)
end

function GearSection:RenderBrowser(gear)
    self.modes, self.selectedSlots = self.modes or {}, self.selectedSlots or {}
    self.gear = gear
    local tab = self.view.context.tabKey
    local groups = self:GroupItems(gear)
    self.selectedSlot = self.selectedSlots[tab]
    if self.modes[tab] == "detail" and groups[self.selectedSlot] then
        self:RenderDetail(gear, groups[self.selectedSlot])
    else
        self:RenderOverview(groups, self:SlotsForEra(self.window.profile, self.window.selectedEra, tab))
    end
end

function GearSection:OpenSlot(slot)
    if not self.view or not self.gear then return false end
    local items = self:GroupItems(self.gear)[slot]
    if not items then return false end
    local tab = self.view.context.tabKey
    if self.mode == "overview" then self.overviewScroll = self.container.viewport:GetVerticalScroll() end
    self.selectedSlots[tab], self.modes[tab] = slot, "detail"
    self.window:SelectTab(tab)
    return true
end

function GearSection:CloseSlot()
    if not self.view then return end
    local tab = self.view.context.tabKey
    self.modes[tab] = "overview"
    self.restoreScroll = self.overviewScroll
    self.window:SelectTab(tab)
end

function GearSection:Render(window, view)
    self:Clear()
    self.window = window
    self.resolver = window.resolver
    self.controller = window.viewController
    self.statusText = window.statusText
    self.container = window.contentHost
    self.view = view
    self.statusText:SetText(ns.L:Get(view.context.tabKey == "gear" and "GEAR_CANDIDATE_NOTE" or "GUIDE_DRAFT_NOTE"))

    local gear = ns.GuideService:GetSection(window.profile, window.selectedStage, view.context.tabKey)
    if not gear or not gear.items then
        if window.profile.contentMode == "pvp" then self.statusText:SetText(ns.L:Get("PVP_NO_DATA")) end
        return
    end
    if gear.imported then self.statusText:SetText("") end
    if gear.imported then self:RenderBrowser(gear); return end

    if not self.batchButton then
        self.batchButton = ns.Widgets.Button(self.container, "ClassHelperGearBatchButton",
            ns.L:Get("BATCH_REQUEST"), function() self:ClickBatch() end)
        if self.batchButton then
            self.batchButton:SetSize(360, 28)
            self.batchButton:SetPoint("TOPRIGHT", -16, -12)
        end
    else
        self.batchButton:SetParent(self.container)
        self.batchButton:Show()
    end
    self.batchButton:ClearAllPoints()
    self.batchButton:SetSize(360, 28)
    self.batchButton:SetPoint("TOPRIGHT", -16, -12)
    self.batchButton.labelWidget:SetText(ns.L:Get("BATCH_REQUEST"))

    local y = 48
    local paragraphs = {}
    for _, textKey in ipairs(gear.paragraphs or {}) do paragraphs[#paragraphs + 1] = ns.L:Get(textKey) or textKey end
    if gear.referenceRaceText then paragraphs[#paragraphs + 1] = gear.referenceRaceText end
    for _, text in ipairs(paragraphs) do
        local note = ns.Widgets.Label(self.container, text, ns.Theme.Fonts.body)
        note:SetWidth(804)
        note:SetJustifyH("LEFT")
        note:SetPoint("TOPLEFT", 16, -y)
        y = y + math.max(18, note:GetStringHeight()) + 10
        self.notes[#self.notes + 1] = note
    end
    local previousGroup
    for index = 1, #gear.items do
        local data = gear.items[index]
        if data.groupKey and data.groupKey ~= previousGroup then
            local heading = ns.Widgets.Label(self.container, ns.L:Get(data.groupKey) or data.groupKey, ns.Theme.Fonts.header)
            heading:SetPoint("TOPLEFT", 16, -y)
            heading:SetWidth(804)
            heading:SetJustifyH("LEFT")
            y = y + math.max(20, heading:GetStringHeight()) + 8
            self.notes[#self.notes + 1] = heading
            self.groupHeaders[#self.groupHeaders + 1] = heading
            previousGroup = data.groupKey
        end
        local row = ns.ItemRow.Create(self.container, self.resolver, view)
        if row then
            row.frame:SetPoint("TOPLEFT", 16, -y)
            row:Bind(data.itemID, data, view)
            self.rows[#self.rows + 1] = row
            y = y + 44
            if data.noteKey or data.rank or data.sourceText then
                local text = data.noteKey and (ns.L:Get(data.noteKey) or data.noteKey) or ""
                if data.rank then text = ns.L:Get("BIS_SLOT_RANK"):format(data.rank) end
                if data.sourceText and data.sourceText ~= "" then text = text .. " • " .. data.sourceText end
                if data.suffixID and data.suffixID ~= 0 then text = text .. " • " .. ns.L:Get("BIS_SUFFIX"):format(data.suffixID) end
                if data.pvp or data.sourceType == "pvp" then text = text .. " • " .. ns.L:Get("BIS_PVP_SOURCE") end
                local note = ns.Widgets.Label(self.container, text, ns.Theme.Fonts.status)
                note:SetWidth(780)
                note:SetJustifyH("LEFT")
                note:SetPoint("TOPLEFT", 46, -y)
                y = y + math.max(16, note:GetStringHeight()) + 8
                self.notes[#self.notes + 1] = note
            end
        end
    end
    self.container:SetHeight(math.max(436, y))
    ns.Widgets.UpdateScroll(self.container)
end

function GearSection:BatchItemIDs(override)
    if override then
        local unique = {}
        local seen = {}
        for index = 1, #override do
            local itemID = override[index]
            if itemID and not seen[itemID] then
                seen[itemID] = true
                unique[#unique + 1] = itemID
            end
        end
        return unique
    end

    local ids = {}
    local seen = {}
    for index = 1, #self.rows do
        local itemID = self.rows[index].itemID
        if itemID and not seen[itemID] then
            seen[itemID] = true
            ids[#ids + 1] = itemID
        end
    end
    return ids
end

function GearSection:ReportBatchProgress(progress)
    if not self.statusText then return end
    if self.mode == "overview" then
        for _, slotRow in ipairs(self.slotRows or {}) do
            if slotRow.frame:IsShown() then
                for _, cell in ipairs(slotRow.cells) do
                    if cell.itemID then cell:Render(self.resolver:Peek(cell.itemID)) end
                end
            end
        end
    end
    for _, row in ipairs(self.rows) do
        row:Render(self.resolver:Peek(row.itemID))
    end
    self:RefreshRecommendations()
    local format = ns.L:Get("BATCH_PROGRESS") or "Loaded %d / %d"
    if progress.failed and progress.failed > 0 then
        local failFormat = ns.L:Get("BATCH_PROGRESS_FAILED") or "Loaded %d / %d, failed %d"
        self.statusText:SetText(failFormat:format(progress.loaded, progress.total, progress.failed))
    else
        self.statusText:SetText(format:format(progress.loaded, progress.total))
    end
end

function GearSection:ClickBatch(itemsOverride, allSlots)
    if not self.resolver or not self.controller or not self.view then return end
    if not self.controller:IsCurrent(self.view.generation) then return end

    local ids = self:BatchItemIDs(itemsOverride)
    if #ids == 0 then return end
    if #ids > MAX_BATCH and not allSlots then
        if self.statusText then
            self.statusText:SetText(ns.L:Get("BATCH_TOO_LARGE"))
        end
        return
    end

    if StaticPopup_Visible("CLASS_HELPER_ITEM_QUERY_WARNING") then
        StaticPopup_Hide("CLASS_HELPER_ITEM_QUERY_WARNING")
    end

    local arg = tostring(#ids)
    StaticPopup_Show("CLASS_HELPER_ITEM_QUERY_WARNING", arg, nil, {
        itemIDs = ids,
        section = self,
        ownerToken = self.view.ownerToken,
        generation = self.view.generation,
        allSlots = allSlots,
    })
end

function GearSection:ConfirmBatch(data)
    if not data then return end
    if data.generation and not self.controller:IsCurrent(data.generation) then return end
    if not data.section then return end
    if not data.itemIDs or #data.itemIDs == 0 then return end
    if #data.itemIDs > MAX_BATCH and not data.allSlots then return end

    if data.allSlots then
        local offset, loaded, failed = 1, 0, 0
        local function nextChunk()
            if not self.controller:IsCurrent(data.generation) then return end
            local chunk = {}
            for i = offset, math.min(#data.itemIDs, offset + MAX_BATCH - 1) do chunk[#chunk + 1] = data.itemIDs[i] end
            offset = offset + #chunk
            local finished = false
            self.resolver:RequestBatch(chunk, data.ownerToken, function(progress)
                if not self.controller:IsCurrent(data.generation) or finished then return end
                self:ReportBatchProgress({ loaded = loaded + progress.loaded, failed = failed + progress.failed, total = #data.itemIDs })
                if progress.complete == #chunk then
                    finished = true
                    loaded, failed = loaded + progress.loaded, failed + progress.failed
                    if offset <= #data.itemIDs then nextChunk() end
                end
            end)
        end
        nextChunk()
        return
    end

    data.section.resolver:RequestBatch(data.itemIDs, data.ownerToken, function(progress)
        data.section:ReportBatchProgress(progress)
    end)
end

if StaticPopupDialogs then
StaticPopupDialogs.CLASS_HELPER_ITEM_QUERY_WARNING = {
    text = ns.L:Get("BATCH_WARNING"),
    button1 = ns.L:Get("BATCH_CONFIRM"),
    button2 = ns.L:Get("BATCH_CANCEL"),
    timeout = 0,
    OnAccept = function(self)
        local data = self.data
        if data and data.section then
            data.section:ConfirmBatch(data)
        end
        self.data = nil
    end,
    OnCancel = function(self)
        self.data = nil
    end,
}
end
