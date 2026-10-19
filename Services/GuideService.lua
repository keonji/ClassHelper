local addonName, ns = ...

local GuideService = {}
ns.GuideService = GuideService

local function matchesProfile(guide, profile)
    return profile and guide.raceOverlay == profile.raceToken
        and guide.classToken == profile.classToken
        and guide.specKey == profile.specKey
end

local function coversStage(guide, stageKey)
    for _, key in ipairs(guide.stages or {}) do
        if key == stageKey then return true end
    end
    return false
end

function GuideService:GetGuide(profile, stageKey)
    if profile and profile.contentMode == "pvp" then return ns.ImportedPvP:GetGuide(profile, stageKey) end
    if profile and profile.databaseProfile then return ns.ImportedBIS:GetGuide(profile, stageKey) end
    local stage = ns.Registry:Get("stage", stageKey)
    if not stage then return nil end

    local guides = ns.Registry:List("guide")
    for index = 1, #guides do
        local guide = guides[index]
        if guide.era == stage.era and matchesProfile(guide, profile)
            and coversStage(guide, stageKey) then
            return guide
        end
    end
end

function GuideService:GetSection(profile, stageKey, sectionKey)
    if profile and profile.contentMode == "pvp" then return ns.ImportedPvP:GetSection(profile, stageKey, sectionKey) end
    if profile and profile.databaseProfile then return ns.ImportedBIS:GetSection(profile, stageKey, sectionKey) end
    if sectionKey == "trinkets" then return self:GetTrinkets(profile, stageKey) end
    local guide = self:GetGuide(profile, stageKey)
    local section = guide and guide.sections and guide.sections[sectionKey]
    if not section then return nil end
    if section.byStage then return section.byStage[stageKey] end
    local stage = ns.Registry:Get("stage", stageKey)
    local selected
    for _, variant in ipairs(section.variants or {}) do
        local first = ns.Registry:Get("stage", variant.fromStage)
        local last = ns.Registry:Get("stage", variant.throughStage)
        if first and last and first.era == stage.era and last.era == stage.era
            and stage.displayOrder >= first.displayOrder
            and stage.displayOrder <= last.displayOrder then
            if selected then return nil end
            selected = variant
        end
    end
    return selected
end

function GuideService:GetTrinkets(profile, stageKey)
    local stage = ns.Registry:Get("stage", stageKey)
    local gear = stage and self:GetGear(profile, stageKey)
    if not gear then return nil end
    local result = { items = {}, paragraphs = { "TRINKETS_COMPARISON_NOTE" } }
    local seen = {}
    local function append(snapshot, group)
        for _, item in ipairs(snapshot and snapshot.items or {}) do
            if item.slot == "TRINKET" and not seen[item.itemID] then
                local copy = {}
                for key, value in pairs(item) do copy[key] = value end
                copy.groupKey, copy.noteKey = group, group == "TRINKETS_CURRENT" and "TRINKET_CURRENT_NOTE" or "TRINKET_EARLIER_NOTE"
                result.items[#result.items + 1] = copy
                seen[item.itemID] = true
            end
        end
    end
    append(gear, "TRINKETS_CURRENT")
    local previous
    for _, candidate in ipairs(ns.Registry:List("stage")) do
        if candidate.era == stage.era and candidate.displayOrder < stage.displayOrder
            and (not previous or candidate.displayOrder > previous.displayOrder) then previous = candidate end
    end
    if previous then append(self:GetGear(profile, previous.key), "TRINKETS_EARLIER") end
    return #result.items > 0 and result or nil
end

function GuideService:GetGear(profile, stageKey)
    local guide = self:GetGuide(profile, stageKey)
    local byStage = guide and guide.sections and guide.sections.gear
        and guide.sections.gear.byStage
    return byStage and byStage[stageKey] or nil
end
