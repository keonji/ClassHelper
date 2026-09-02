local addonName, ns = ...

local PlayerContext = {}
ns.PlayerContext = PlayerContext

local function observedSpec(classToken, points)
    local winner
    local highest = 0
    local tied = false
    for tab = 1, #points do
        local spent = points[tab] or 0
        if spent > highest then
            highest = spent
            winner = tab
            tied = false
        elseif spent == highest and spent > 0 then
            tied = true
        end
    end
    if not winner or tied then return nil end

    local specs = ns.Registry:List("spec")
    for index = 1, #specs do
        local spec = specs[index]
        if spec.classToken == classToken and spec.tab == winner then
            return spec.key
        end
    end
end

local function pointsKey(points)
    local values = {}
    for index = 1, #points do values[index] = tostring(points[index] or 0) end
    return table.concat(values, ":")
end

function PlayerContext:Snapshot()
    local points = ns.Compat:GetTalentTreePoints()
    local classToken = ns.Compat:GetUnitClassToken("player")
    return {
        raceToken = ns.Compat:GetUnitRaceToken("player"),
        classToken = classToken,
        observedSpecKey = observedSpec(classToken, points),
        talentPoints = points,
    }
end

function PlayerContext:Get()
    return self:Snapshot()
end

function PlayerContext:Refresh()
    local snapshot = self:Snapshot()
    local signature = table.concat({
        snapshot.raceToken or "",
        snapshot.classToken or "",
        snapshot.observedSpecKey or "",
        pointsKey(snapshot.talentPoints),
    }, "|")
    if signature == self.lastSignature then return false, snapshot end
    self.lastSignature = signature
    ns.Events:Dispatch("PLAYER_CONTEXT_CHANGED", snapshot)
    return true, snapshot
end

function PlayerContext:Initialize()
    local frame = ns.Compat:CreateFrame("Frame", nil, UIParent)
    if not frame then return end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    frame:SetScript("OnEvent", function() self:Refresh() end)
    self.eventFrame = frame
end

ns:RegisterModule("PlayerContext", PlayerContext)
