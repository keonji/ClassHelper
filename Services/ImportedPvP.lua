local _, ns = ...
local PvP = {}
ns.ImportedPvP = PvP

local function allows(mask, id)
    return not mask or mask == -1 or math.floor(mask / 2 ^ (id - 1)) % 2 == 1
end

for _, build in ipairs(ns.PvPData.builds) do
    local key = "pvp_" .. build.era .. "_" .. build.phase
    if not ns.Registry:Has("pvpStage", key) then
        ns.Registry:Register("pvpStage", key, { era = build.era, contentMode = "pvp", imported = true,
            levelCap = build.era == "classic" and 60 or build.era == "tbc" and 70 or 80,
            nameKey = "PVP_PHASE_" .. build.phase, displayOrder = 300 + (tonumber(build.phase:sub(2)) or 0) })
    end
end

function PvP:GetGuide(profile, stageKey)
    local stage = ns.Registry:Get("pvpStage", stageKey)
    if not profile or not stage or stage.contentMode ~= "pvp" then return nil end
    local race = ns.BISCatalog.races[profile.raceToken]
    if not race or not (" " .. race.classes .. " "):find(" " .. tostring(profile.classToken) .. " ", 1, true) then return nil end
    for _, build in ipairs(ns.PvPData.builds) do
        if "pvp_" .. build.era .. "_" .. build.phase == stageKey and build.classToken == profile.classToken then
            local matched = false
            for _, spec in ipairs(build.specs) do if spec == profile.sourceSpec then matched = true end end
            if matched then
                local items = {}
                for _, item in ipairs(build.items) do
                    local meta = ns.PvPData.eligibility[item.itemID]
                    if meta and (not item.onlyRace or item.onlyRace == profile.raceToken)
                        and meta.level <= stage.levelCap and allows(meta.raceMask, race.id)
                        and allows(meta.classMask, ns.BISCatalog.classIDs[profile.classToken])
                        and (meta.factionFlags % 2 == 0 or race.faction == "HORDE")
                        and (math.floor(meta.factionFlags / 2) % 2 == 0 or race.faction == "ALLIANCE") then
                        local row = {}
                        for key, value in pairs(item) do row[key] = value end
                        if row.sourceGrouped == 1 then row.sourceText = ns.L:Get("PVP_GROUP_SOURCES") .. row.sourceText end
                        row.contentMode, row.recommended, row.verification = "pvp", true, "historical"
                        items[#items + 1] = row
                    end
                end
                if #items == 0 then return nil end
                local paragraphs = { "PVP_SOURCE_NOTE" }
                if build.shared == 1 then paragraphs[#paragraphs + 1] = "PVP_SHARED_NOTE" end
                if build.era ~= "wrath" then paragraphs[#paragraphs + 1] = "BIS_HISTORICAL_NOTE" end
                local gear = { items = items, imported = true, contentMode = "pvp", paragraphs = paragraphs,
                    sourceText = "Icy Veins / " .. build.title .. " / " .. build.url }
                local references = ns.BISCatalog.classicReferenceRaces[profile.raceToken]
                if build.era == "classic" and references then
                    gear.referenceRaceToken = references[profile.classToken]
                    gear.referenceRaceText = ns.L:Get("BIS_REFERENCE_RACE"):format(ns.L:Get("BIS_RACE_" .. gear.referenceRaceToken))
                end
                return { era = stage.era, imported = true, contentMode = "pvp",
                    sections = { gear = { byStage = { [stageKey] = gear } } } }
            end
        end
    end
end

function PvP:GetSection(profile, stageKey, sectionKey)
    local guide = self:GetGuide(profile, stageKey)
    local gear = guide and guide.sections.gear.byStage[stageKey]
    if sectionKey == "gear" then return gear end
    if sectionKey ~= "trinkets" or not gear then return nil end
    local result = { items = {}, imported = true, paragraphs = gear.paragraphs, sourceText = gear.sourceText }
    for _, row in ipairs(gear.items) do if row.slot == "TRINKET" then result.items[#result.items + 1] = row end end
    if #result.items > 0 then return result end
end
