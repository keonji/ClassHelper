-- Compat/WoW335.lua: the only module allowed to encode WoW 3.3.5a (build 12340)
-- client API signatures. Task 2 adds locale detection; later milestones add item,
-- talent, tooltip, timing, and modified-click adapters here.

local addonName, ns = ...

local Compat = {}
ns.Compat = Compat

function Compat:GetLocale()
    if GetLocale then
        return GetLocale()
    end
    return "enUS"
end