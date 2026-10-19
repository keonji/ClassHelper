local _, ns = ...
local Guides = {}
ns.ClassGuides = Guides

function Guides:Get(profile, era)
    local level = ({ classic = 60, tbc = 70, wrath = 80 })[era] or 80
    local record = ns.ClassGuideData[profile.classToken .. ":" .. (profile.sourceSpec or "")]
    local mode = profile.contentMode or "pve"
    local data = record and record[mode]
    local locale = ns.L.locale == "ruRU" and "ruRU" or "enUS"
    return {
        level = level, plan = level < 80, mode = mode, role = record and record.role,
        overview = data and data.overview[locale] or {},
        rotation = data and data.rotation[locale] or "",
        rotationDiagram = data and data.rotationDiagram,
        builds = data and data.builds or {}, sources = data and data.sources or {},
        missing = not data, locale = locale,
        selectionKey = profile.classToken .. ":" .. (profile.sourceSpec or "") .. ":" .. mode .. ":" .. level,
    }
end

function Guides:Selected(context)
    local saved = ns.Config:Get("selectedGuideBuilds")
    local key = type(saved) == "table" and saved[context.selectionKey]
    for _, build in ipairs(context.builds) do if build.key == key then return build end end
    return context.builds[1]
end

function Guides:Select(context, key)
    for _, build in ipairs(context.builds) do
        if build.key == key then
            local copy, old = {}, ns.Config:Get("selectedGuideBuilds")
            if type(old) == "table" then for k, v in pairs(old) do if type(k) == "string" and type(v) == "string" then copy[k] = v end end end
            copy[context.selectionKey] = key
            ns.Config:Set("selectedGuideBuilds", copy)
            return true
        end
    end
    return false
end
