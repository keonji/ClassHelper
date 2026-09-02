-- Data/Races.lua: race catalog excluding the Human overlay in Data/Races/Human.lua.
-- Only metadata is stored here; the sole release guide stays Human-only.

local addonName, ns = ...

local registry = ns.Registry

local races = {
    { key = "DWARF", faction = "ALLIANCE" },
    { key = "NIGHTELF", faction = "ALLIANCE" },
    { key = "GNOME", faction = "ALLIANCE" },
    { key = "DRAENEI", faction = "ALLIANCE" },
    { key = "WORGEN", faction = "ALLIANCE" },
    { key = "ORC", faction = "HORDE" },
    { key = "TAUREN", faction = "HORDE" },
    { key = "UNDEAD", faction = "HORDE" },
    { key = "TROLL", faction = "HORDE" },
    { key = "BLOODELF", faction = "HORDE" },
    { key = "GOBLIN", faction = "HORDE" },
    { key = "TAUBEN", faction = "HORDE" },
    { key = "PANDAREN", faction = "NEUTRAL" },
}

for index = 1, #races do
    local race = races[index]
    registry:Register("race", race.key, {
        token = race.key,
        faction = race.faction,
    })
end
