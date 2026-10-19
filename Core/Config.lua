local addonName, ns = ...

local Config = {}
ns.Config = Config

local DEFAULTS = {
    schemaVersion = 2,
    displayMode = "auto",
    enableItemTooltips = true,
    enableCooldownText = true,
    showRacialSuggestions = true,
    startHidden = true,
    windowPosition = "CENTER:0:0",
    selectedEra = "wrath",
    selectedContentMode = "pve",
    selectedPveStage = "",
    selectedPvpStage = "",
    selectedProfile = "bis_human_paladin_retribution",
    selectedStage = "wrath_normal_dungeons",
    selectedTab = "gear",
    selectedGuideBuilds = false,
    collapsedSections = false,
}

local function buildDatabase(saved, restoring)
    local database = {}
    for key, value in pairs(DEFAULTS) do
        database[key] = value
    end
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if DEFAULTS[key] ~= nil then
                database[key] = value
            end
        end
    end
    local profiles = { human_paladin_retribution = "bis_human_paladin_retribution", human_mage_fire = "bis_human_mage_fire" }
    local retiredProfile = restoring and profiles[database.selectedProfile] and not ns.Registry:Has("profile", database.selectedProfile)
    if type(saved) ~= "table" or (tonumber(saved.schemaVersion) or 0) < 2 or retiredProfile then
        if profiles[database.selectedProfile] then database.selectedProfile = profiles[database.selectedProfile] end
        local phases = {
            classic_pre_raid = "classic_pr", classic_molten_core = "classic_p1", classic_onyxia = "classic_p1",
            classic_blackwing_lair = "classic_p3", classic_zulgurub = "classic_p4", classic_aq20 = "classic_p5", classic_aq40 = "classic_p5",
            tbc_pre_raid = "tbc_prebis", tbc_gruul_magtheridon = "tbc_phase1", tbc_karazhan = "tbc_phase1", tbc_ogrila = "tbc_phase1",
            tbc_serpentshrine = "tbc_phase2", tbc_tempest_keep = "tbc_phase2", tbc_hyjal = "tbc_phase3", tbc_black_temple = "tbc_phase3",
            tbc_zulaman = "tbc_phase4", tbc_isle = "tbc_phase5", tbc_sunwell = "tbc_phase5",
            wrath_normal_dungeons = "wrath_PR", wrath_heroic_dungeons = "wrath_PR", wrath_tier_7 = "wrath_T7",
            wrath_ulduar = "wrath_T8", wrath_crusaders_coliseum = "wrath_T9", wrath_icecrown = "wrath_T10", wrath_ruby_sanctum = "wrath_RS",
        }
        if type(database.selectedProfile) == "string" and database.selectedProfile:sub(1, 4) == "bis_" and phases[database.selectedStage] then
            database.selectedStage = "bis_" .. phases[database.selectedStage]
            database.selectedTab = "gear"
        end
    end
    database.schemaVersion = DEFAULTS.schemaVersion
    return database
end

local database = buildDatabase(ClassHelperDB)
ClassHelperDB = database

function Config:Initialize()
    database = buildDatabase(ClassHelperDB, true)
    ClassHelperDB = database
end

function Config:Has(key)
    return DEFAULTS[key] ~= nil
end

function Config:Get(key)
    if DEFAULTS[key] == nil then
        error("unknown config key: " .. tostring(key), 0)
    end
    return database[key]
end

function Config:Set(key, value)
    if DEFAULTS[key] == nil then
        error("unknown config key: " .. tostring(key), 0)
    end
    database[key] = value
end

ns:RegisterModule("Config", Config)
