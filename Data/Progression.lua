-- Data/Progression.lua: semantic progression stages and their AzerothCore source
-- brackets. Brackets are diagnostic metadata and never a visible stage name.

local addonName, ns = ...

local registry = ns.Registry

local stages = {
    { key = "classic_pre_raid", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_PRE_RAID",
      brackets = { "50_59_1", "50_59_2", "60_1_1" } },
    { key = "classic_molten_core", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_MOLTEN_CORE",
      brackets = { "60_1_2" } },
    { key = "classic_onyxia", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_ONYXIA",
      brackets = { "60_2_1" } },
    { key = "classic_blackwing_lair", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_BWL",
      brackets = { "60_2_2" } },
    { key = "classic_zulgurub", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_ZG",
      brackets = { "60_3_1" } },
    { key = "classic_aq20", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_AQ20",
      brackets = { "60_3_2" } },
    { key = "classic_aq40", era = "classic", levelCap = 60, nameKey = "STAGE_CLASSIC_AQ40",
      brackets = { "60_3_3" } },

    { key = "tbc_pre_raid", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_PRE_RAID",
      brackets = { "70_1_1", "70_1_2" } },
    { key = "tbc_gruul_magtheridon", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_GRUUL_MAGTHERIDON",
      brackets = { "70_2_1" } },
    { key = "tbc_karazhan", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_KARAZHAN",
      brackets = { "70_2_2" } },
    { key = "tbc_ogrila", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_OGRILA",
      brackets = { "70_2_3" } },
    { key = "tbc_serpentshrine", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_SERPENTSHRINE",
      brackets = { "70_3_1" } },
    { key = "tbc_tempest_keep", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_TEMPEST_KEEP",
      brackets = { "70_3_2" } },
    { key = "tbc_hyjal", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_HYJAL",
      brackets = { "70_4_1" } },
    { key = "tbc_black_temple", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_BLACK_TEMPLE",
      brackets = { "70_4_2" } },
    { key = "tbc_zulaman", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_ZULAMAN",
      brackets = { "70_5" } },
    { key = "tbc_isle", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_ISLE",
      brackets = { "70_6_1" } },
    { key = "tbc_sunwell", era = "tbc", levelCap = 70, nameKey = "STAGE_TBC_SUNWELL",
      brackets = { "70_6_2" } },

    { key = "wrath_normal_dungeons", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_NORMAL_DUNGEONS",
      brackets = { "80_1_1" } },
    { key = "wrath_heroic_dungeons", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_HEROIC_DUNGEONS",
      brackets = { "80_1_2" } },
    { key = "wrath_tier_7", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_TIER_7",
      brackets = { "80_1_3" } },
    { key = "wrath_ulduar", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_ULDUAR",
      brackets = { "80_2" } },
    { key = "wrath_crusaders_coliseum", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_CRUSADERS_COLISEUM",
      brackets = { "80_3" } },
    { key = "wrath_icecrown", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_ICECROWN",
      brackets = { "80_4_1" } },
    { key = "wrath_ruby_sanctum", era = "wrath", levelCap = 80, nameKey = "STAGE_WRATH_RUBY_SANCTUM",
      brackets = { "80_4_2" } },
}

local previousKey = nil
for index = 1, #stages do
    local stage = stages[index]
    registry:Register("stage", stage.key, {
        era = stage.era,
        levelCap = stage.levelCap,
        nameKey = stage.nameKey,
        displayOrder = index,
        previousKey = previousKey,
        azerothBrackets = stage.brackets,
    })
    previousKey = stage.key
end
