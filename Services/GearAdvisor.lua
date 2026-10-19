local _, ns = ...
local Advisor = {}
ns.GearAdvisor = Advisor

local simpleSlots = {
    HEAD = true, NECK = true, SHOULDER = true, CLOAK = true, CHEST = true,
    WRIST = true, HANDS = true, WAIST = true, LEGS = true, FEET = true, FINGER = true,
}

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Advisor:Evaluate(profile, era, rows)
    if profile.contentMode == "pvp" then
        local result = {}
        for index, row in ipairs(rows) do result[index] = { mode = "source", best = row.data.recommended == true } end
        return result, "source"
    end
    local scores, mode = {}, "source"
    local reference = ns.ItemWeights[era]
    reference = reference and reference[profile.classToken]
    reference = reference and reference[profile.sourceSpec]
    local weights = reference and reference.stats
    if weights and not reference.historical and #reference.unmapped == 0 and rows[1] and simpleSlots[rows[1].data.slot] then
        local complete = true
        for index, row in ipairs(rows) do
            local snapshot = row.snapshot
            local stats = snapshot and snapshot.state == "loaded" and snapshot.link and ns.Compat:GetItemStats(snapshot.link)
            local score, found = 0, false
            if type(stats) == "table" then
                for key, weight in pairs(weights) do
                    local value = stats[key]
                    if value ~= nil then
                        if not finite(value) then complete = false; break end
                        score, found = score + value * weight, true
                    end
                end
            end
            if not found or not finite(score) or score <= 0 then complete = false end
            scores[index] = score
        end
        if complete then mode = "weights" end
    end
    local best = {}
    for index, row in ipairs(rows) do
        local group = row.data.position or 1
        local value = mode == "weights" and scores[index] or -(row.data.rank or math.huge)
        if not best[group] or value > best[group] then best[group] = value end
    end
    local result = {}
    for index, row in ipairs(rows) do
        local value = mode == "weights" and scores[index] or -(row.data.rank or math.huge)
        result[index] = { mode = mode, best = value == best[row.data.position or 1],
            score = mode == "weights" and scores[index] or nil,
            source = mode == "weights" and reference.source or nil }
    end
    return result, mode
end
