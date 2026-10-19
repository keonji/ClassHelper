TestState = { baseG = _G }
dofile("Tests/testlib.lua")
dofile("Tests/load_addon.lua")
dofile("Tests/wow_stub.lua")

local stub = WowStub.New()
local ns = LoadDraftAddon(".", stub).namespace
local sets, auxiliarySets = {}, {}
for _, guide in ipairs(ns.Registry:List("guide")) do
    for _, stageKey in ipairs(guide.stages or {}) do
        local stage = ns.Registry:Get("stage", stageKey)
        local snapshot = guide.sections.gear.byStage[stageKey]
        sets[#sets + 1] = {
            guideKey = guide.key, stageKey = stageKey, era = stage.era, displayOrder = stage.displayOrder,
            levelCap = stage.levelCap, classToken = guide.classToken, raceToken = guide.raceOverlay, items = snapshot.items,
        }
        local profile = { raceToken = guide.raceOverlay, classToken = guide.classToken, specKey = guide.specKey }
        for _, key in ipairs({ "enhancements", "consumables", "talents" }) do
            local section = ns.GuideService:GetSection(profile, stageKey, key)
            local items = section and section.items or {}
            if key == "talents" then
                items = {}
                for _, category in ipairs({ "major", "minor" }) do
                    for _, id in ipairs(section and section.glyphs and section.glyphs[category] or {}) do
                        items[#items + 1] = { itemID = id }
                    end
                end
            end
            auxiliarySets[#auxiliarySets + 1] = { guideKey = guide.key, stageKey = stageKey, levelCap = stage.levelCap,
                classToken = guide.classToken, raceToken = guide.raceOverlay, kind = key == "talents" and "glyphs" or key, items = items }
        end
    end
end

local function quote(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(char)
        return ('\\u%04x'):format(char:byte())
    end) .. '"'
end

local function json(value)
    if type(value) == "string" then return quote(value) end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    if type(value) ~= "table" then return "null" end
    local parts = {}
    if #value > 0 then
        for _, item in ipairs(value) do parts[#parts + 1] = json(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for key, item in pairs(value) do parts[#parts + 1] = quote(key) .. ":" .. json(item) end
    return "{" .. table.concat(parts, ",") .. "}"
end

io.write(json({ sets = sets, auxiliarySets = auxiliarySets, itemQueries = stub.calls.GetItemInfo }))
