-- Locales/enUS.lua: complete fallback catalog. Client item and spell names are
-- never stored here; only UI labels and guide prose keys.

local addonName, ns = ...

local L = ns.L
if not L then
    L = {}
    ns.L = L
end
L.catalog = L.catalog or {}

local enUS = {
    ITEM_IDLE_TEST_ONLY = "Data not requested",
    ITEM_STATE_LOADING = "Loading",
    ITEM_STATE_FAILED = "Data unavailable or request timed out",

    BATCH_PROGRESS = "Loaded %d / %d",
    BATCH_PROGRESS_FAILED = "Loaded %d / %d, failed %d",
    BATCH_TOO_LARGE = "Too many items; request them individually",
    BATCH_REQUEST = "Request server data for all items",

    TAB_GUIDE = "Guide",
    TAB_ENCHANTMENTS = "Enchants & Gems",
    TAB_CONSUMABLES = "Consumables",
    TAB_TRINKETS = "Trinkets",
    TAB_GEAR = "BiS Gear",

    SECTION_OVERVIEW = "Overview",
    SECTION_STAT_PRIORITY = "Stat Priority",
    SECTION_TALENTS = "Talents",
    SECTION_ROTATION = "Rotation",

    RACE_HUMAN = "Human",
    SPEC_RETRIBUTION = "Retribution",
    SPEC_HOLY = "Holy",
    SPEC_PROTECTION = "Protection",

    STAGE_CLASSIC_PRE_RAID = "Pre-Raid Dungeons",
    STAGE_CLASSIC_MOLTEN_CORE = "Molten Core",
    STAGE_CLASSIC_ONYXIA = "Onyxia's Lair",
    STAGE_CLASSIC_BWL = "Blackwing Lair",
    STAGE_CLASSIC_ZG = "Zul'Gurub",
    STAGE_CLASSIC_AQ20 = "Ruins of Ahn'Qiraj",
    STAGE_CLASSIC_AQ40 = "Temple of Ahn'Qiraj",

    STAGE_TBC_PRE_RAID = "Level 70 Dungeons",
    STAGE_TBC_GRUUL_MAGTHERIDON = "Gruul and Magtheridon",
    STAGE_TBC_KARAZHAN = "Karazhan",
    STAGE_TBC_OGRILA = "Ogri'la",
    STAGE_TBC_SERPENTSHRINE = "Serpentshrine Cavern",
    STAGE_TBC_TEMPEST_KEEP = "Tempest Keep and Sha'tari Skyguard",
    STAGE_TBC_HYJAL = "Battle for Mount Hyjal and Netherwing",
    STAGE_TBC_BLACK_TEMPLE = "Black Temple",
    STAGE_TBC_ZULAMAN = "Zul'Aman",
    STAGE_TBC_ISLE = "Isle of Quel'Danas and Magisters' Terrace",
    STAGE_TBC_SUNWELL = "Sunwell Plateau",

    STAGE_WRATH_NORMAL_DUNGEONS = "Level 80 Normal Dungeons",
    STAGE_WRATH_HEROIC_DUNGEONS = "Level 80 Heroic Dungeons",
    STAGE_WRATH_TIER_7 = "Naxxramas, Eye of Eternity, Obsidian Sanctum",
    STAGE_WRATH_ULDUAR = "Ulduar",
    STAGE_WRATH_CRUSADERS_COLISEUM = "Onyxia and Crusaders' Coliseum",
    STAGE_WRATH_ICECROWN = "Icecrown Citadel and Frozen Halls",
    STAGE_WRATH_RUBY_SANCTUM = "Ruby Sanctum",
}
L.catalog.enUS = enUS

local function normalizeLocale(locale)
    if locale == "ruRU" then
        return "ruRU"
    end
    return "enUS"
end

local function currentLocale()
    if ns.Compat and ns.Compat.GetLocale then
        return ns.Compat:GetLocale()
    end
    return "enUS"
end

function L:Get(key, ...)
    if key == nil then
        return nil
    end
    local catalog = self.catalog
    local str = catalog[self.locale] and catalog[self.locale][key]
    if str == nil then
        str = catalog.enUS[key]
    end
    return str
end

L.locale = normalizeLocale(currentLocale())
