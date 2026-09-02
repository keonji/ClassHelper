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
    ONEHANDED = true, TWOHANDED = true, RANGED = true, CLOAK = true,
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

local function validateGearItems(registry, guide, errors)
    local key = guide.key
    local gear = guide.sections and guide.sections.gear
    if not gear or not gear.items then return end

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
            end
        end
    end

    validateGearItems(registry, guide, errors)
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
        "Data/Classes.lua",
        "Data/Races.lua",
        "Data/Progression.lua",
        "Data/Races/Human.lua",
        "Data/Specs/Paladin/Retribution/Shared.lua",
        "Data/Specs/Paladin/Retribution/Wrath.lua",
    }

    for index = 1, #files do
        local path = root .. "/" .. files[index]
        local source = readTextFile(path)
        if not source then
            return nil, "missing data file: " .. path
        end

        local chunk, err
        if setfenv then
            chunk, err = load(source, "@" .. path)
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
