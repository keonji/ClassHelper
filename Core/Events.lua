local addonName, ns = ...

local events = {}
ns.Events = events

local subscribers = {}

function events:Subscribe(owner, event, callback)
    local list = subscribers[event]
    if not list then
        list = {}
        subscribers[event] = list
    end
    list[#list + 1] = { owner = owner, callback = callback }
end

function events:UnsubscribeOwner(owner)
    for event, list in pairs(subscribers) do
        for index = #list, 1, -1 do
            if list[index].owner == owner then
                table.remove(list, index)
            end
        end
    end
end

function events:Dispatch(event, ...)
    local list = subscribers[event]
    if not list then return end
    for index = 1, #list do
        local subscriber = list[index]
        local ok, err = pcall(subscriber.callback, event, ...)
        if not ok then
            print("[ClassHelper] event handler error for " .. event .. ": " .. tostring(err))
        end
    end
end
