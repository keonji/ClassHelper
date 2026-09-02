-- Data/Specs/Paladin/Retribution/Wrath.lua: a development-only Gear fixture for the
-- item-resolution vertical slice. It is explicitly unverified (developmentFixture +
-- candidate) and uses placeholder item IDs, so it is never mistaken for reviewed
-- release BiS data. Real era guides replace this file's role in a later slice.

local addonName, ns = ...

local registry = ns.Registry

local gearItems = {
    { itemID = 100001, slot = "HEAD", position = 1, priority = "bis", verification = "candidate" },
    { itemID = 100002, slot = "HEAD", position = 2, priority = "alt", verification = "candidate" },
    { itemID = 100003, slot = "TRINKET", position = 1, priority = "bis", verification = "candidate" },
}

registry:Register("guide", "fixture_human_paladin_retribution_wrath", {
    raceOverlay = "HUMAN",
    classToken = "PALADIN",
    specKey = "retribution",
    era = "wrath",
    stages = { "wrath_icecrown", "wrath_ruby_sanctum" },
    developmentFixture = true,
    sections = {
        gear = { items = gearItems },
    },
})
