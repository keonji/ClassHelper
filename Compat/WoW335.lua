local addonName, ns = ...

local Compat = {}
ns.Compat = Compat

function Compat:GetLocale()
    if GetLocale then
        local locale = GetLocale()
        if locale and locale ~= "" then return locale end
    end
    return "enUS"
end

function Compat:GetUnitClassToken(unit)
    if UnitClass then
        local _, english = UnitClass(unit or "player")
        return english
    end
end

function Compat:GetTalentTreePoints()
    local points = {}
    if not GetNumTalentTabs then return points end
    for tab = 1, GetNumTalentTabs(false, false) do
        local _, _, _, spent = GetTalentTabInfo(tab, false, false, GetActiveTalentGroup())
        points[tab] = spent or 0
    end
    return points
end

function Compat:GetSpellInfo(spellID)
    if not GetSpellInfo then return end
    local name, icon, level = GetSpellInfo(spellID)
    if name then
        return { name = name, icon = icon, level = level }
    end
end

function Compat:GetItemInfo(itemID)
    if not GetItemInfo then return end
    local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLocation, texture = GetItemInfo(itemID)
    if not name then return end
    return name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLocation, texture
end

function Compat:QueryItem(itemID)
    local tooltip = ClassHelperQueryTooltip
    if tooltip and tooltip.SetHyperlink then
        tooltip:SetHyperlink(("item:%d:0:0:0:0:0:0:0:0"):format(itemID))
        return true
    end
    return false
end
