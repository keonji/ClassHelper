local _, ns = ...

local BIS = {}
ns.ImportedBIS = BIS
local catalog, registry = ns.BISCatalog, ns.Registry
local cache = {}

local function maskAllows(mask, id)
    return not mask or mask == -1 or math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end

local function eligible(profile, row, stage)
    local meta, race = ns.BISData.eligibility[row.itemID], catalog.races[profile.raceToken]
    if not meta or not race then return false end
    if not maskAllows(meta.raceMask, race.id) or not maskAllows(meta.classMask, catalog.classIDs[profile.classToken]) then return false end
    if meta.level > stage.levelCap then return false end
    if meta.factionFlags % 2 == 1 and race.faction ~= "HORDE" then return false end
    if math.floor(meta.factionFlags / 2) % 2 == 1 and race.faction ~= "ALLIANCE" then return false end
    return true
end

local function slug(value) return value:lower():gsub("[^%w]+", "_") end
local function contains(values, wanted)
    for _, value in ipairs(values or {}) do if value == wanted then return true end end
    return false
end

local function rowsFor(profile, stage)
    local race = catalog.races[profile.raceToken]
    if not race then return nil end
    if stage.era == "classic" then
        if catalog.classicUnavailablePhases[profile.classToken] and catalog.classicUnavailablePhases[profile.classToken][stage.sourcePhase] then return nil end
        local spec = catalog.classicSpecs[profile.classToken] and catalog.classicSpecs[profile.classToken][profile.sourceSpec]
        if not spec then return nil end
        local raceID = race.id
        local reference = catalog.classicReferenceRaces[profile.raceToken]
        if reference then raceID = catalog.races[reference[profile.classToken]].id end
        local result = {}
        for _, item in ipairs(ns.BISData.classic) do
            if item.classID == catalog.classIDs[profile.classToken] and item.specID == spec
                and item.phase <= stage.sourcePhaseLimit
                and (not item.races or contains(item.races, raceID))
                and (not item.factions or contains(item.factions, race.faction == "ALLIANCE" and "Alliance" or "Horde"))
                and (stage.sourcePhase ~= "pr" or (not item.raid and not item.worldBoss)) then
                result[#result + 1] = item
            end
        end
        table.sort(result, function(a, b)
            if a.slot ~= b.slot then return catalog.slotOrder[a.slot] < catalog.slotOrder[b.slot] end
            if a.rank ~= b.rank then return a.rank < b.rank end
            if a.itemID ~= b.itemID then return a.itemID < b.itemID end
            return a.suffixID < b.suffixID
        end)
        return result
    end
    local specs = ns.BISData[stage.era][profile.classToken]
    local spec = specs and specs[stage.era == "tbc" and (catalog.tbcSpecs[profile.sourceSpec] or profile.sourceSpec) or profile.sourceSpec]
    if stage.era == "wrath" then spec = spec and spec[race.faction] end
    return spec and spec[stage.sourcePhase]
end

function BIS:GetGuide(profile, stageKey)
    local stage = registry:Get("bisStage", stageKey)
    if not profile or not profile.databaseProfile or not stage or not stage.imported then return nil end
    local race = catalog.races[profile.raceToken]
    if not race or not (" " .. race.classes .. " "):find(" " .. tostring(profile.classToken) .. " ", 1, true) then return nil end
    local key = table.concat({ profile.raceToken or "", profile.classToken or "", profile.sourceSpec or "", stageKey }, ":")
    if cache[key] ~= nil then return cache[key] or nil end
    local rows = rowsFor(profile, stage)
    if not rows or #rows == 0 then cache[key] = false; return nil end
    local items, seen = {}, {}
    for _, row in ipairs(rows) do
        local identity = row.slot .. ":" .. tostring(row.position or 1) .. ":" .. row.itemID .. ":" .. tostring(row.suffixID or 0)
        if not seen[identity] and eligible(profile, row, stage) then
            local copy = {}
            for field, value in pairs(row) do copy[field] = value end
            copy.priority, copy.verification = "alt", "historical"
            copy.pooled = stage.era ~= "tbc" and (copy.slot == "FINGER" or copy.slot == "TRINKET")
            local inventory = ns.BISData.eligibility[row.itemID].inventoryType
            if copy.slot == "ONEHANDED" and inventory == 17 then copy.slot = "TWOHANDED" end
            if copy.slot == "RANGED" and inventory == 28 then copy.slot = "RELIC" end
            copy.sourceRefs = { stage.era }
            items[#items + 1] = copy
            seen[identity] = true
        end
    end
    if #items == 0 then cache[key] = false; return nil end
    local source = catalog.sources[stage.era]
    local gear = { items = items, paragraphs = { "BIS_RANKING_NOTE", stage.era == "wrath" and "BIS_WRATH_NOTE" or "BIS_HISTORICAL_NOTE" },
        sourceText = source.name .. " / " .. ns.L:Get(stage.nameKey), imported = true }
    if stage.era == "classic" and catalog.classicReferenceRaces[profile.raceToken] then
        gear.referenceRaceToken = catalog.classicReferenceRaces[profile.raceToken][profile.classToken]
        gear.referenceRaceText = ns.L:Get("BIS_REFERENCE_RACE"):format(ns.L:Get("BIS_RACE_" .. gear.referenceRaceToken))
    end
    local guide = { key = key, era = stage.era, classToken = profile.classToken, specKey = profile.specKey,
        stages = { stageKey }, sections = { gear = { byStage = { [stageKey] = gear } } }, imported = true }
    cache[key] = guide
    return guide
end

function BIS:GetSection(profile, stageKey, sectionKey)
    local guide = self:GetGuide(profile, stageKey)
    local gear = guide and guide.sections.gear.byStage[stageKey]
    if sectionKey == "gear" then return gear end
    if sectionKey == "trinkets" and gear then
        local result = { items = {}, paragraphs = gear.paragraphs, sourceText = gear.sourceText, imported = true }
        for _, item in ipairs(gear.items) do if item.slot == "TRINKET" then result.items[#result.items + 1] = item end end
        return #result.items > 0 and result or nil
    end
end

local order = 100
for _, era in ipairs({ "classic", "tbc", "wrath" }) do
    for _, phase in ipairs(catalog.phases[era]) do
        order = order + 1
        registry:Register("bisStage", "bis_" .. era .. "_" .. phase[1], {
            era = era, levelCap = era == "classic" and 60 or era == "tbc" and 70 or 80,
            nameKey = phase[2], displayOrder = order, sourcePhase = phase[1], sourcePhaseLimit = phase[3], imported = true,
        })
    end
end

for _, raceToken in ipairs(catalog.raceOrder) do
    if not registry:Has("raceOverlay", raceToken) then registry:Register("raceOverlay", raceToken, { raceToken = raceToken }) end
end
for _, classToken in ipairs(catalog.classOrder) do
    local specs = {}
    for name in pairs(ns.BISData.wrath[classToken]) do specs[#specs + 1] = name end
    table.sort(specs)
    for _, sourceSpec in ipairs(specs) do
        local specKey = "bis_" .. slug(classToken) .. "_" .. slug(sourceSpec)
        registry:Register("spec", specKey, { classToken = classToken, nameKey = "BIS_SPEC_" .. slug(sourceSpec), sourceSpec = sourceSpec })
        for _, raceToken in ipairs(catalog.raceOrder) do
            local race = catalog.races[raceToken]
            if (" " .. race.classes .. " "):find(" " .. classToken .. " ", 1, true) then
                registry:Register("profile", "bis_" .. slug(raceToken) .. "_" .. slug(classToken) .. "_" .. slug(sourceSpec), {
                    classToken = classToken, specKey = specKey, sourceSpec = sourceSpec, raceOverlay = raceToken,
                    databaseProfile = true, eras = { "classic", "tbc", "wrath" }, release = true,
                    nameKey = "BIS_SPEC_" .. slug(sourceSpec), icon = "Interface\\Icons\\Achievement_" .. catalog.icons[classToken] .. "_ClassIcon",
                    accent = { tonumber(registry:Get("class", classToken).color:sub(1, 2), 16) / 255,
                        tonumber(registry:Get("class", classToken).color:sub(3, 4), 16) / 255,
                        tonumber(registry:Get("class", classToken).color:sub(5, 6), 16) / 255, 1 },
                })
            end
        end
    end
end
