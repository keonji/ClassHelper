-- Data validator. Doubles as a library (dofile returns ValidateData) and a CLI tool.
-- It detects CLI via arg[0] because a dofile load runs in the caller's chunk with no
-- CLI arg, whereas `lua Tools/validate_data.lua` sets arg[0] to this file's path.

local validEras = { classic = true, tbc = true, wrath = true }
local validPriorities = { bis = true, alt = true }
local validVerification = { candidate = true, verified = true, server_variant = true }

local validSlots = {
    HEAD = true, NECK = true, SHOULDER = true, SHIRT = true, CHEST = true,
    WAIST = true, LEGS = true, FEET = true, WRIST = true, HANDS = true,
    FINGER = true, TRINKET = true,
    ONEHANDED = true, TWOHANDED = true, OFFHAND = true, RANGED = true, CLOAK = true, RELIC = true,
    INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true,
    INVTYPE_SHIRT = true, INVTYPE_CHEST = true, INVTYPE_ROBE = true,
    INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
    INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true, INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_CLOAK = true,
}

local ValidateData

local function join(...)
    local parts = { ... }
    local out = ""
    for index = 1, #parts do
        out = out .. tostring(parts[index])
    end
    return out
end

local function validSlot(slot)
    return slot ~= nil and validSlots[slot] == true
end

local function validateProfile(registry, profile, errors)
    local key = profile.key

    local classToken = profile.classToken
    if not classToken or not registry:Has("class", classToken) then
        errors[#errors + 1] = join("profile ", key, " references unknown class ", tostring(classToken))
    end

    local specKey = profile.specKey
    if specKey then
        local spec = registry:Get("spec", specKey)
        if not spec then
            errors[#errors + 1] = join("profile ", key, " references unknown spec ", tostring(specKey))
        elseif classToken and spec.classToken ~= classToken then
            errors[#errors + 1] = join("profile ", key, " spec ", specKey,
                " does not belong to class ", tostring(classToken))
        end
    end

    local overlay = profile.raceOverlay
    if overlay then
        local overlayRecord = registry:Get("raceOverlay", overlay)
        if not overlayRecord then
            errors[#errors + 1] = join("profile ", key, " references unknown raceOverlay ", tostring(overlay))
        elseif not registry:Has("race", overlayRecord.raceToken) then
            errors[#errors + 1] = join("profile ", key, " raceOverlay ", overlay,
                " has unknown race ", tostring(overlayRecord.raceToken))
        end
    end

    if profile.eras then
        for index = 1, #profile.eras do
            local era = profile.eras[index]
            if not validEras[era] then
                errors[#errors + 1] = join("profile ", key, " lists unknown era ", tostring(era))
            end
        end
    end
end

local function validateGearItems(registry, guide, errors, options)
    local key = guide.key
    local gear = guide.sections and guide.sections.gear
    if not gear then return end
    if gear.byStage then
        for _, stageKey in ipairs(guide.stages or {}) do
            local snapshot = gear.byStage[stageKey]
            if not snapshot or not snapshot.items then
                errors[#errors + 1] = key .. " missing gear snapshot " .. stageKey
            else
                local expectedCount = guide.classToken == "MAGE" and 17 or 16
                if #snapshot.items ~= expectedCount then
                    errors[#errors + 1] = key .. " incomplete gear snapshot " .. stageKey
                end
                validateGearItems(registry, {
                    key = key .. "/" .. stageKey,
                    classToken = guide.classToken,
                    sourceCatalog = guide.sourceCatalog,
                    sections = { gear = snapshot },
                }, errors, options)
            end
        end
        return
    end
    if not gear.items then return end

    local bisSeen = {}
    for index = 1, #gear.items do
        local item = gear.items[index]
        local label = join(key, " gear #", index)

        local itemID = item.itemID
        if type(itemID) ~= "number" or itemID ~= math.floor(itemID) or itemID < 1 then
            errors[#errors + 1] = join(label, " has invalid itemID ", tostring(itemID))
        else
            label = join(key, " item ", itemID)
        end

        if not validSlot(item.slot) then
            errors[#errors + 1] = join(label, " has unknown slot ", tostring(item.slot))
        end

        if not validPriorities[item.priority] then
            errors[#errors + 1] = join(label, " has invalid priority ", tostring(item.priority))
        end

        if item.verification and not validVerification[item.verification] then
            errors[#errors + 1] = join(label, " has invalid verification ", tostring(item.verification))
        end
        if options.release and item.verification ~= "verified" then
            errors[#errors + 1] = label .. " is not verified"
        end
        if not item.sourceRefs or #item.sourceRefs == 0 then
            errors[#errors + 1] = label .. " has no source references"
        else
            for _, sourceKey in ipairs(item.sourceRefs) do
                if not guide.sourceCatalog or not guide.sourceCatalog[sourceKey] then
                    errors[#errors + 1] = label .. " has unknown source " .. tostring(sourceKey)
                end
            end
        end

        local position = item.position or 1
        if type(position) ~= "number" or position < 1 then
            errors[#errors + 1] = join(label, " has invalid position ", tostring(position))
        else
            local slotKey = join(tostring(item.slot), ":", position)
            if item.priority == "bis" then
                if bisSeen[slotKey] then
                    errors[#errors + 1] = join(key, " has multiple bis entries for ", slotKey)
                end
                bisSeen[slotKey] = true
            end
        end
    end
end

local function validateSections(registry, guide, options, errors)
    for sectionKey, section in pairs(guide.sections or {}) do
        if section.variants then
            local covered = {}
            for index, variant in ipairs(section.variants) do
                local label = guide.key .. "/" .. sectionKey .. " #" .. index
                local first = registry:Get("stage", variant.fromStage)
                local last = registry:Get("stage", variant.throughStage)
                local validRange = first and last and first.era == guide.era
                    and last.era == guide.era and first.displayOrder <= last.displayOrder
                if not validRange then
                    errors[#errors + 1] = label .. " invalid stage range"
                else
                    for _, stageKey in ipairs(guide.stages or {}) do
                        local stage = registry:Get("stage", stageKey)
                        if stage and stage.displayOrder >= first.displayOrder and stage.displayOrder <= last.displayOrder then
                            if covered[stageKey] then errors[#errors + 1] = label .. " overlapping variants at " .. stageKey end
                            covered[stageKey] = true
                        end
                    end
                end
                if not validVerification[variant.verification] then errors[#errors + 1] = label .. " invalid verification" end
                if options.release and variant.verification ~= "verified" then errors[#errors + 1] = label .. " is not verified" end
                if not variant.sourceRefs or #variant.sourceRefs == 0 then errors[#errors + 1] = label .. " has no source references" end
                for _, source in ipairs(variant.sourceRefs or {}) do
                    if not guide.sourceCatalog or not guide.sourceCatalog[source] then
                        errors[#errors + 1] = label .. " unknown source " .. tostring(source)
                    end
                end
                local function checkText(key)
                    if options.catalog and (type(key) ~= "string" or not options.catalog[key]) then
                        errors[#errors + 1] = label .. " missing localization " .. tostring(key)
                    end
                end
                for _, key in ipairs(variant.paragraphs or {}) do checkText(key) end
                for _, entry in ipairs(variant.entries or {}) do
                    if type(entry.spellID) ~= "number" or entry.spellID < 1 or entry.spellID % 1 ~= 0 then
                        errors[#errors + 1] = label .. " invalid spellID"
                    end
                    if not validRange or type(entry.minLevel) ~= "number" or entry.minLevel > first.levelCap then
                        errors[#errors + 1] = label .. " ability above level cap or missing level"
                    end
                    checkText(entry.noteKey)
                    if entry.groupKey then checkText(entry.groupKey) end
                end
                for _, item in ipairs(variant.items or {}) do
                    if type(item.itemID) ~= "number" or item.itemID < 1 or item.itemID % 1 ~= 0 then
                        errors[#errors + 1] = label .. " invalid itemID"
                    end
                    checkText(item.noteKey)
                    if item.groupKey then checkText(item.groupKey) end
                end
                if variant.trees then
                    local level = first and first.levelCap or 0
                    local seenGlyphs = {}
                    for _, category in ipairs({ "major", "minor" }) do
                        local glyphs = variant.glyphs and variant.glyphs[category] or {}
                        local limit = category == "major" and (level >= 80 and 3 or level >= 30 and 2 or level >= 15 and 1 or 0)
                            or (level >= 70 and 3 or level >= 50 and 2 or level >= 15 and 1 or 0)
                        if #glyphs > limit then errors[#errors + 1] = label .. " too many " .. category .. " glyphs" end
                        for _, itemID in ipairs(glyphs) do
                            local glyph = registry:Get("glyph", tostring(itemID))
                            if not glyph then errors[#errors + 1] = label .. " unknown glyph " .. tostring(itemID)
                            else
                                if glyph.classToken ~= guide.classToken then errors[#errors + 1] = label .. " glyph class mismatch" end
                                if glyph.category ~= category then errors[#errors + 1] = label .. " glyph category mismatch" end
                                if glyph.minLevel > level then errors[#errors + 1] = label .. " glyph above level cap" end
                            end
                            if seenGlyphs[itemID] then errors[#errors + 1] = label .. " duplicate glyph" end
                            seenGlyphs[itemID] = true
                        end
                    end
                    local total = 0
                    for treeIndex, ranks in ipairs(variant.trees) do
                        if type(ranks) ~= "string" or ranks:find("[^0-5]") then
                            errors[#errors + 1] = label .. " invalid talent ranks"
                        else
                            for rank in ranks:gmatch("%d") do total = total + tonumber(rank) end
                            local tree = registry:Get("talentTree", guide.classToken .. ":" .. treeIndex)
                            if not tree then
                                errors[#errors + 1] = label .. " missing talent metadata"
                            else
                                for talentIndex = 1, #ranks do
                                    local rank = tonumber(ranks:sub(talentIndex, talentIndex))
                                    local talent = tree.talents[talentIndex]
                                    if not talent or rank > talent.maxRank then
                                        errors[#errors + 1] = label .. " rank exceeds maximum"
                                    elseif rank > 0 then
                                        local earlier = 0
                                        for otherIndex, other in ipairs(tree.talents) do
                                            if other.tier < talent.tier then
                                                earlier = earlier + (tonumber(ranks:sub(otherIndex, otherIndex)) or 0)
                                            end
                                        end
                                        if earlier < (talent.tier - 1) * 5 then errors[#errors + 1] = label .. " locked talent tier" end
                                        if talent.prerequisite then
                                            local parent = tree.talents[talent.prerequisite]
                                            local spent = tonumber(ranks:sub(talent.prerequisite, talent.prerequisite)) or 0
                                            if spent < parent.maxRank then errors[#errors + 1] = label .. " missing prerequisite" end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if not validRange or total ~= first.levelCap - 9 or total ~= variant.points then
                        errors[#errors + 1] = label .. " invalid talent point total"
                    end
                end
            end
        end
    end
end

local function validateGuide(registry, guide, options, errors)
    local key = guide.key

    if guide.developmentFixture and options.release then
        local excluded = options.excludedGuideKeys and options.excludedGuideKeys[key]
        if not excluded then
            errors[#errors + 1] = join(key, " is a development fixture")
        end
    end

    local classToken = guide.classToken
    if classToken and not registry:Has("class", classToken) then
        errors[#errors + 1] = join("guide ", key, " references unknown class ", tostring(classToken))
    end

    local specKey = guide.specKey
    if specKey then
        local spec = registry:Get("spec", specKey)
        if not spec then
            errors[#errors + 1] = join("guide ", key, " references unknown spec ", tostring(specKey))
        elseif classToken and spec.classToken ~= classToken then
            errors[#errors + 1] = join("guide ", key, " spec ", specKey,
                " does not belong to class ", tostring(classToken))
        end
    end

    local overlay = guide.raceOverlay
    if overlay then
        local overlayRecord = registry:Get("raceOverlay", overlay)
        if not overlayRecord then
            errors[#errors + 1] = join("guide ", key, " references unknown raceOverlay ", tostring(overlay))
        elseif not registry:Has("race", overlayRecord.raceToken) then
            errors[#errors + 1] = join("guide ", key, " raceOverlay ", overlay,
                " has unknown race ", tostring(overlayRecord.raceToken))
        end
    end

    if guide.era and not validEras[guide.era] then
        errors[#errors + 1] = join("guide ", key, " references unknown era ", tostring(guide.era))
    end

    if guide.stages then
        for index = 1, #guide.stages do
            local stageKey = guide.stages[index]
            if not registry:Has("stage", stageKey) then
                errors[#errors + 1] = join("guide ", key, " references unknown stage ", tostring(stageKey))
            elseif registry:Get("stage", stageKey).era ~= guide.era then
                errors[#errors + 1] = key .. " stage has wrong era " .. stageKey
            end
        end
    end

    validateGearItems(registry, guide, errors, options)
    validateSections(registry, guide, options, errors)
end

local function validateStages(registry, errors)
    local stages = registry:List("stage")
    for index = 1, #stages do
        local stage = stages[index]
        if stage.era and not validEras[stage.era] then
            errors[#errors + 1] = join("stage ", stage.key, " references unknown era ", tostring(stage.era))
        end
        if stage.previousKey and not registry:Has("stage", stage.previousKey) then
            errors[#errors + 1] = join("stage ", stage.key, " references unknown previous stage ", tostring(stage.previousKey))
        end
    end
end

ValidateData = function(registry, options)
    options = options or {}
    local errors = {}
    local warnings = {}

    local profiles = registry:List("profile")
    for index = 1, #profiles do
        validateProfile(registry, profiles[index], errors)
    end

    validateStages(registry, errors)

    local guides = registry:List("guide")
    for index = 1, #guides do
        validateGuide(registry, guides[index], options, errors)
    end

    return { errors = errors, warnings = warnings }
end

local function readTextFile(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("a")
    handle:close()
    return text
end

local function loadValidationNamespace(root)
    local namespace = {}
    local files = {
        "Core/Registry.lua",
        "Locales/enUS.lua",
        "Locales/ruRU.lua",
        "Data/Classes.lua",
        "Data/Glyphs.lua",
        "Data/Races.lua",
        "Data/Progression.lua",
        "Data/Races/Human.lua",
        "Data/Specs/Paladin/Retribution/Shared.lua",
        "Data/Specs/Paladin/Retribution/Talents.lua",
        "Data/Specs/Paladin/Retribution/Enhancements.lua",
        "Data/Specs/Paladin/Retribution/GearData.lua",
        "Data/Specs/Paladin/Retribution/GuideData.lua",
        "Data/Specs/Paladin/Retribution/Classic.lua",
        "Data/Specs/Paladin/Retribution/BurningCrusade.lua",
        "Data/Specs/Paladin/Retribution/Wrath.lua",
        "Data/Specs/Mage/Fire/Shared.lua",
        "Data/Specs/Mage/Fire/Talents.lua",
        "Data/Specs/Mage/Fire/GuideData.lua",
        "Data/Specs/Mage/Fire/GearData.lua",
        "Data/Specs/Mage/Fire/Classic.lua",
        "Data/Specs/Mage/Fire/BurningCrusade.lua",
        "Data/Specs/Mage/Fire/Wrath.lua",
    }

    for index = 1, #files do
        local path = root .. "/" .. files[index]
        if files[index] == "Data/Glyphs.lua" or files[index]:sub(1, 11) == "Data/Specs/" then
            path = root .. "/knowledge_base/archive/manual-guides/" .. files[index]
        end
        local source = readTextFile(path)
        if not source then
            return nil, "missing data file: " .. path
        end

        local chunk, err
        if setfenv then
            chunk, err = loadstring(source, "@" .. path)
            if chunk then setfenv(chunk, _G) end
        else
            chunk, err = load(source, "@" .. path, "t", _G)
        end
        if not chunk then
            return nil, "compile " .. path .. ": " .. tostring(err)
        end

        local ok, runErr = pcall(chunk, "ClassHelper", namespace)
        if not ok then
            return nil, "load " .. path .. ": " .. tostring(runErr)
        end
    end

    return namespace
end

local cliMode = false
if type(arg) == "table" and arg[0] and string.find(arg[0], "validate_data", 1, true) then
    cliMode = true
elseif select("#", ...) > 0 then
    cliMode = true
end

if cliMode then
    local release = true
    local excludeFixtures = false
    local root = "."
    local index = 1
    if arg then
        while index <= #arg do
            local flag = arg[index]
            if flag == "--development" then
                release = false
            elseif flag == "--release" then
                release = true
            elseif flag == "--exclude-fixtures" then
                excludeFixtures = true
            elseif flag == "--root" and index < #arg then
                index = index + 1
                root = arg[index]
            end
            index = index + 1
        end
    end

    local namespace, loadErr = loadValidationNamespace(root)
    if not namespace then
        print("validate_data: " .. tostring(loadErr))
        os.exit(1)
    end

    local excludedGuideKeys
    if excludeFixtures then
        excludedGuideKeys = {}
        local guides = namespace.Registry:List("guide")
        for guideIndex = 1, #guides do
            if guides[guideIndex].developmentFixture then
                excludedGuideKeys[guides[guideIndex].key] = true
            end
        end
    end

    local mode = release and "release" or "development"
    if excludeFixtures then mode = mode .. " (fixtures excluded)" end
    local result = ValidateData(namespace.Registry, {
        release = release,
        catalog = namespace.L.catalog.enUS,
        excludedGuideKeys = excludedGuideKeys,
    })

    if #result.errors > 0 then
        print("validate_data (" .. mode .. "): " .. #result.errors .. " error(s)")
        for errorIndex = 1, #result.errors do
            print("  " .. result.errors[errorIndex])
        end
        os.exit(1)
    end

    print("validate_data (" .. mode .. "): ok")
    os.exit(0)
end

return ValidateData
