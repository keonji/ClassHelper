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

function Compat:GetUnitRaceToken(unit)
    if UnitRace then
        local _, english = UnitRace(unit or "player")
        return english
    end
end

function Compat:GetTalentTreePoints()
    local points = {}
    if not GetNumTalentTabs then return points end
    for tab = 1, GetNumTalentTabs(false, false) do
        local _, _, spent = GetTalentTabInfo(tab, false, false, GetActiveTalentGroup())
        points[tab] = spent or 0
    end
    return points
end

function Compat:GetSpellInfo(spellID)
    if not GetSpellInfo then return end
    local name, rank, icon = GetSpellInfo(spellID)
    if name then
        return { name = name, rank = rank, icon = icon }
    end
end

function Compat:GetItemInfo(itemID)
    if not GetItemInfo then return end
    local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLocation, texture = GetItemInfo(itemID)
    if not name then return end
    return name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, equipLocation, texture
end

function Compat:GetItemStats(link)
    if not GetItemStats or not link then return nil end
    local ok, stats = pcall(GetItemStats, link)
    if ok and type(stats) == "table" then return stats end
end

function Compat:QueryItem(itemID)
    if not self.queryTooltip then
        self.queryTooltip = self:CreateFrame("GameTooltip", "ClassHelperQueryTooltip", UIParent, "GameTooltipTemplate")
        if self.queryTooltip and self.queryTooltip.SetOwner then
            self.queryTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
    end
    local tooltip = self.queryTooltip
    if not tooltip or not tooltip.SetHyperlink then
        return false
    end
    local ok = pcall(tooltip.SetHyperlink, tooltip, ("item:%d:0:0:0:0:0:0:0:0"):format(itemID))
    return ok
end

function Compat:GetTime()
    if GetTime then return GetTime() end
    return 0
end

function Compat:CreateFrame(objectType, name, parent, template)
    if not CreateFrame then return nil end
    return CreateFrame(objectType, name, parent, template)
end

function Compat:SetPortraitToTexture(texture, path)
    if SetPortraitToTexture then
        SetPortraitToTexture(texture, path)
    else
        texture:SetTexture(path)
    end
end

function Compat:CreateTexture(parent, layer)
    if parent and parent.CreateTexture then
        return parent:CreateTexture(nil, layer or "OVERLAY")
    end
end

function Compat:CreateFontString(parent, fontObject)
    if parent and parent.CreateFontString then
        return parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
    end
end

function Compat:AddEscapeFrame(name)
    if not UISpecialFrames then return end
    for index = 1, #UISpecialFrames do
        if UISpecialFrames[index] == name then return end
    end
    table.insert(UISpecialFrames, name)
end

function Compat:HandleModifiedItemClick(link)
    if HandleModifiedItemClick then
        return HandleModifiedItemClick(link)
    end
end

function Compat:ShowItemTooltip(owner, link)
    if not GameTooltip or not link then return false end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    GameTooltip:Show()
    return true
end

function Compat:HideItemTooltip()
    if GameTooltip then GameTooltip:Hide() end
end
