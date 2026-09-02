local addonName, ns = ...

local ItemResolver = {}
ns.ItemResolver = ItemResolver

local MAX_BATCH = 80

function ItemResolver.New(compat, queue)
    local resolver = {}
    local states = {}
    local batches = {}
    local nextSubscription = 0
    local nextBatch = 0

    local function cloneSnapshot(state)
        if state.state == "loaded" and state.item then
            local snapshot = { state = "loaded" }
            for key, value in pairs(state.item) do snapshot[key] = value end
            return snapshot
        end
        return { state = state.state }
    end

    local function readItem(itemID)
        local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLocation, texture = compat:GetItemInfo(itemID)
        if not name then return nil end
        return {
            itemID = itemID, name = name, link = link, quality = quality,
            itemLevel = itemLevel, minLevel = minLevel, itemType = itemType,
            itemSubType = itemSubType, stackCount = stackCount,
            equipLocation = equipLocation, texture = texture,
        }
    end

    local function notify(itemID)
        local state = states[itemID]
        if not state then return end
        local snapshot = cloneSnapshot(state)
        for _, subscription in pairs(state.subs) do
            local callback = subscription.callback
            if callback then
                local ok, err = pcall(callback, snapshot)
                if not ok and resolver.onError then
                    resolver.onError("item resolver callback: " .. tostring(err))
                end
            end
        end
    end

    function resolver:Peek(itemID)
        local state = states[itemID]
        if state then return cloneSnapshot(state) end
        return { state = "idle" }
    end

    function resolver:SubscriberCount(itemID)
        local state = states[itemID]
        if not state then return 0 end
        local count = 0
        for _ in pairs(state.subs) do count = count + 1 end
        return count
    end

    local function finishItem(itemID, newState, item)
        local state = states[itemID]
        if not state then return end
        state.state = newState
        state.item = item
        queue:Cancel("item:" .. itemID)
        notify(itemID)
    end

    local function startJob(itemID)
        queue:Enqueue("item:" .. itemID, {
            dispatch = function()
                if not states[itemID] then return true end
                local item = readItem(itemID)
                if item then
                    finishItem(itemID, "loaded", item)
                    return true
                end
                if compat:QueryItem(itemID) then
                    states[itemID].state = "loading"
                    notify(itemID)
                else
                    finishItem(itemID, "failed", nil)
                end
                return false
            end,
            poll = function()
                if not states[itemID] then return true end
                local item = readItem(itemID)
                if item then return true, item end
                return false
            end,
            complete = function(status, payload, reason)
                if not states[itemID] then return end
                if status == "success" and payload then
                    finishItem(itemID, "loaded", payload)
                elseif reason ~= "cancelled" and reason ~= "dispatch" then
                    finishItem(itemID, "failed", nil)
                end
            end,
        })
    end

    function resolver:Request(itemID, ownerToken, callback)
        if type(itemID) ~= "number" or itemID < 1 or itemID ~= math.floor(itemID) then
            return nil
        end

        local state = states[itemID]
        if not state or state.state == "failed" then
            local item = readItem(itemID)
            if item then
                state = { state = "loaded", item = item, subs = {} }
            else
                state = { state = "queued", subs = {} }
                states[itemID] = state
                startJob(itemID)
            end
            states[itemID] = state
        end

        nextSubscription = nextSubscription + 1
        local subscriptionID = nextSubscription
        state.subs[subscriptionID] = { owner = ownerToken, callback = callback }

        if callback then
            local snapshot = cloneSnapshot(state)
            local ok, err = pcall(callback, snapshot)
            if not ok and resolver.onError then
                resolver.onError("item resolver callback: " .. tostring(err))
            end
        end

        return subscriptionID
    end

    function resolver:Unsubscribe(subscriptionID)
        for itemID, state in pairs(states) do
            if state.subs and state.subs[subscriptionID] ~= nil then
                state.subs[subscriptionID] = nil
                if next(state.subs) == nil and (state.state == "queued" or state.state == "loading") then
                    queue:Cancel("item:" .. itemID)
                    states[itemID] = nil
                end
                return true
            end
        end
        return false
    end

    function resolver:CancelOwner(ownerToken)
        for itemID, state in pairs(states) do
            if state.subs then
                local removed = false
                for subscriptionID, subscription in pairs(state.subs) do
                    if subscription.owner == ownerToken then
                        state.subs[subscriptionID] = nil
                        removed = true
                    end
                end
                if removed and next(state.subs) == nil
                    and (state.state == "queued" or state.state == "loading") then
                    queue:Cancel("item:" .. itemID)
                    states[itemID] = nil
                end
            end
        end
    end

    function resolver:CancelBatch(batchID)
        local batch = batches[batchID]
        if not batch then return false end
        for _, subscriptionID in pairs(batch.subscriptionIDs) do
            self:Unsubscribe(subscriptionID)
        end
        batches[batchID] = nil
        return true
    end

    function resolver:RequestBatch(itemIDs, ownerToken, progressCallback)
        local unique = {}
        local seen = {}
        for index = 1, #itemIDs do
            local itemID = itemIDs[index]
            if type(itemID) == "number" and not seen[itemID] then
                seen[itemID] = true
                unique[#unique + 1] = itemID
            end
        end

        if #unique > MAX_BATCH then
            return nil, "too_many_items"
        end

        nextBatch = nextBatch + 1
        local batchID = nextBatch
        local batch = {
            id = batchID,
            total = #unique,
            loaded = 0,
            failed = 0,
            seen = {},
            subscriptionIDs = {},
        }

        function batch:report()
            if progressCallback then
                progressCallback({
                    batchID = batchID,
                    total = self.total,
                    loaded = self.loaded,
                    failed = self.failed,
                    complete = self.loaded + self.failed,
                })
            end
        end

        local function isComplete(b)
            return b.loaded + b.failed >= b.total
        end

        batches[batchID] = batch

        for index = 1, #unique do
            local itemID = unique[index]
            local subscriptionID = self:Request(itemID, ownerToken, function(snapshot)
                if snapshot.state ~= "loaded" and snapshot.state ~= "failed" then
                    return
                end
                local batchState = batches[batchID]
                if not batchState or batchState.seen[itemID] then return end
                batchState.seen[itemID] = true
                if snapshot.state == "loaded" then
                    batchState.loaded = batchState.loaded + 1
                else
                    batchState.failed = batchState.failed + 1
                end
                batchState:report()
                if isComplete(batchState) then
                    batches[batchID] = nil
                end
            end)
            if subscriptionID then
                batch.subscriptionIDs[#batch.subscriptionIDs + 1] = subscriptionID
            end
        end

        return batchID, unique
    end

    return resolver
end
