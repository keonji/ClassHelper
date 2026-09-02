-- Data/Specs/Paladin/Retribution/Shared.lua: the Human Retribution release profile.
-- The Human racial overlays the shared guide; guide data lives in era files.

local addonName, ns = ...

local registry = ns.Registry

registry:Register("profile", "human_paladin_retribution", {
    classToken = "PALADIN",
    specKey = "retribution",
    raceOverlay = "HUMAN",
    eras = { "classic", "tbc", "wrath" },
    release = true,
})
