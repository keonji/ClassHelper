-- Data/Classes.lua: class and specialization catalog. Only Paladin specs are
-- populated for the MVP; the registry is data-driven so other classes register
-- their specs without shared-code changes.

local addonName, ns = ...

local registry = ns.Registry

local classTokens = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}
local classColors = {
    WARRIOR = "C79C6B", PALADIN = "F48CBA", HUNTER = "ABD473", ROGUE = "FFF569",
    PRIEST = "FFFFFF", DEATHKNIGHT = "C41E3A", SHAMAN = "0070DE", MAGE = "69CCF0",
    WARLOCK = "9482C9", DRUID = "FF7D0A",
}

for index = 1, #classTokens do
    local token = classTokens[index]
    registry:Register("class", token, {
        classToken = token,
        color = classColors[token],
    })
end

local paladinSpecs = {
    { key = "holy", tab = 1, role = "HEALER", nameKey = "SPEC_HOLY" },
    { key = "protection", tab = 2, role = "TANK", nameKey = "SPEC_PROTECTION" },
    { key = "retribution", tab = 3, role = "DPS", nameKey = "SPEC_RETRIBUTION" },
}
for index = 1, #paladinSpecs do
    local spec = paladinSpecs[index]
    registry:Register("spec", spec.key, {
        classToken = "PALADIN",
        tab = spec.tab,
        role = spec.role,
        nameKey = spec.nameKey,
    })
end
