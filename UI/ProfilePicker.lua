local _, ns = ...
local Picker = {}
ns.ProfilePicker = Picker

local function profiles(classToken, raceToken, sourceSpec)
    local result = {}
    for _, record in ipairs(ns.Registry:List("profile")) do
        if record.databaseProfile and (not classToken or record.classToken == classToken)
            and (not raceToken or record.raceOverlay == raceToken)
            and (not sourceSpec or record.sourceSpec == sourceSpec) then result[#result + 1] = record end
    end
    return result
end

local function classColor(classToken)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    return color and { color.r, color.g, color.b, 1 } or nil
end

local function colorCode(color)
    return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5),
        math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

function Picker:Attach(window)
    self.window = window
end

function Picker:ChooseClass(classToken)
    local current = self.window.profileRecord
    local candidates = profiles(classToken, current.raceOverlay)
    if #candidates == 0 then candidates = profiles(classToken) end
    if #candidates == 0 then return false end
    return self.window:SelectProfile(candidates[1].key)
end

function Picker:ChooseRace(raceToken)
    local current = self.window.profileRecord
    local candidates = profiles(current.classToken, raceToken, current.sourceSpec)
    if #candidates == 0 then return false end
    return self.window:SelectProfile(candidates[1].key)
end

function Picker:ChooseSpec(sourceSpec)
    local current = self.window.profileRecord
    local candidates = profiles(current.classToken, current.raceOverlay, sourceSpec)
    if #candidates == 0 then candidates = profiles(current.classToken, nil, sourceSpec) end
    if #candidates == 0 then return false end
    return self.window:SelectProfile(candidates[1].key)
end

function Picker:ClassText()
    local record = self.window.profileRecord
    if not record.databaseProfile then return self.window:ProfileName() end
    local className = ns.L:Get("BIS_CLASS_" .. record.classToken)
    local color = classColor(record.classToken)
    if color then className = colorCode(color) .. className .. "|r" end
    return self:SpecText(record) .. " - " .. className
end

function Picker:SpecText(record)
    local data = ns.ClassGuideData[record.classToken .. ":" .. record.sourceSpec]
    local role = data and data.role or "unknown"
    if role == "melee" or role == "ranged" then role = "damage" end
    return (ns.L:Get(record.nameKey) or record.sourceSpec) .. " (" .. ns.L:Get("ROLE_" .. role) .. ")"
end

function Picker:RaceText()
    local record = self.window.profileRecord
    return record.raceOverlay and ns.L:Get("BIS_RACE_" .. record.raceOverlay) or ns.L:Get("BIS_RACE")
end

function Picker:ClassEntries()
    local current = self.window.profileRecord
    local entries = {}
    for _, classToken in ipairs(ns.BISCatalog.classOrder) do
        local token, children, seen = classToken, {}, {}
        for _, record in ipairs(profiles(token)) do
            if not seen[record.sourceSpec] then
                local spec = record.sourceSpec
                seen[spec] = true
                children[#children + 1] = { text = self:SpecText(record),
                    selected = current.classToken == token and current.sourceSpec == spec,
                    onClick = function() self:ChooseClass(token); self:ChooseSpec(spec) end }
            end
        end
        if #children > 0 then
            entries[#entries + 1] = { text = ns.L:Get("BIS_CLASS_" .. token), color = classColor(token),
                selected = current.classToken == token, children = children }
        end
    end
    return entries
end

function Picker:RaceEntries()
    local current = self.window.profileRecord
    local entries = {}
    for _, raceToken in ipairs(ns.BISCatalog.raceOrder) do
        if #profiles(current.classToken, raceToken, current.sourceSpec) > 0 then
            local token = raceToken
            entries[#entries + 1] = { text = ns.L:Get("BIS_RACE_" .. token), selected = current.raceOverlay == token,
                onClick = function() self:ChooseRace(token) end }
        end
    end
    return entries
end
