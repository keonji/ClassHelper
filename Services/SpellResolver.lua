local addonName, ns = ...

local SpellResolver = { resolved = {} }
ns.SpellResolver = SpellResolver

function SpellResolver:Resolve(spellID)
    local cached = self.resolved[spellID]
    if cached then return cached end

    local info = ns.Compat:GetSpellInfo(spellID)
    local spell
    if info then
        spell = {
            spellID = spellID,
            name = info.name,
            icon = info.icon,
            rank = info.rank,
            known = true,
        }
    else
        spell = { spellID = spellID, name = "Spell #" .. tostring(spellID), known = false }
    end
    self.resolved[spellID] = spell
    return spell
end
