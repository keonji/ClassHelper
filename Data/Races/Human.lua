-- Data/Races/Human.lua: the Human racial overlay for the release profile.

local addonName, ns = ...

local registry = ns.Registry

registry:Register("race", "HUMAN", {
    token = "HUMAN",
    faction = "ALLIANCE",
    nameKey = "RACE_HUMAN",
})

registry:Register("raceOverlay", "HUMAN", {
    raceToken = "HUMAN",
    nameKey = "RACE_HUMAN",
    racials = {
        { key = "THE_EVERY_MAN", nameKey = "RACIAL_THE_EVERY_MAN" },
        { key = "PERCEPTION", nameKey = "RACIAL_PERCEPTION" },
        { key = "DIPLOMACY", nameKey = "RACIAL_DIPLOMACY" },
        { key = "MACE_SPECIALIZATION", nameKey = "RACIAL_MACE_SPECIALIZATION" },
    },
})
