-- UI/Sections/Gear.lua: fixture Gear tab renderer and batch flow. Rows are the only
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

function GearSection:Clear()
    for index = #self.rows, 1, -1 do
        local row = self.rows[index]
        row:Unbind()
        if row.frame then
            row.frame:SetParent(nil)
        end
    end
    self.rows = {}
end

function GearSection:Render(window, view)
    self:Clear()
    self.window = window
    self.resolver = window.resolver
    self.controller = window.viewController
    self.statusText = window.statusText
    self.container = window.contentHost
    self.view = view

    local guide = ns.Registry:Get("guide", "fixture_human_paladin_retribution_wrath")
    if not guide then return end

    local gear = guide.sections and guide.sections.gear
    if not gear or not gear.items then return end

    for index = 1, #gear.items do
        local data = gear.items[index]
        local row = ns.ItemRow.Create(self.container, self.resolver, view)
        if row then
            row:Bind(data.itemID, data, view)
            self.rows[#self.rows + 1] = row
        end
    end
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
    local format = ns.L:Get("BATCH_PROGRESS") or "Loaded %d / %d"
    if progress.failed and progress.failed > 0 then
        local failFormat = ns.L:Get("BATCH_PROGRESS_FAILED") or "Loaded %d / %d, failed %d"
        self.statusText:SetText(failFormat:format(progress.loaded, progress.total, progress.failed))
    else
        self.statusText:SetText(format:format(progress.loaded, progress.total))
    end
end

function GearSection:ClickBatch(itemsOverride)
    if not self.resolver or not self.controller or not self.view then return end
    if not self.controller:IsCurrent(self.view.generation) then return end

    local ids = self:BatchItemIDs(itemsOverride)
    if #ids == 0 then return end
    if #ids > MAX_BATCH then
        if self.statusText then
            self.statusText:SetText(ns.L:Get("BATCH_TOO_LARGE"))
        end
        return
    end

    if StaticPopupHasVisible("CLASS_HELPER_ITEM_QUERY_WARNING") then
        StaticPopup_Hide("CLASS_HELPER_ITEM_QUERY_WARNING")
    end

    local arg = tostring(#ids)
    StaticPopup_Show("CLASS_HELPER_ITEM_QUERY_WARNING", arg, nil, {
        itemIDs = ids,
        section = self,
        ownerToken = self.view.ownerToken,
        generation = self.view.generation,
    })
end

function GearSection:ConfirmBatch(data)
    if not data then return end
    if data.generation and not self.controller:IsCurrent(data.generation) then return end
    if not data.section then return end
    if not data.itemIDs or #data.itemIDs == 0 then return end
    if #data.itemIDs > MAX_BATCH then return end

    data.section.resolver:RequestBatch(data.itemIDs, data.ownerToken, function(progress)
        data.section:ReportBatchProgress(progress)
    end)
end

StaticPopupDialogs.CLASS_HELPER_ITEM_QUERY_WARNING = {
    text = "This queries %s item(s) from the server. Some private realms throttle bulk queries. Continue?",
    button1 = "Query",
    button2 = "Cancel",
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
