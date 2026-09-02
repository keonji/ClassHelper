local addonName, ns = ...

local Config = {}
ns.Config = Config

local DEFAULTS = {
    schemaVersion = 1,
    displayMode = "auto",
    enableItemTooltips = true,
    enableCooldownText = true,
    showRacialSuggestions = true,
    startHidden = true,
    windowPosition = "CENTER:0:0",
}

local function buildDatabase(saved)
    local database = {}
    for key, value in pairs(DEFAULTS) do
        database[key] = value
    end
    if type(saved) == "table" then
        for key, value in pairs(saved) do
            if DEFAULTS[key] ~= nil then
                database[key] = value
            end
        end
    end
    database.schemaVersion = DEFAULTS.schemaVersion
    return database
end

local database = buildDatabase(ClassHelperDB)

function Config:Has(key)
    return DEFAULTS[key] ~= nil
end

function Config:Get(key)
    if DEFAULTS[key] == nil then
        error("unknown config key: " .. tostring(key), 0)
    end
    return database[key]
end

function Config:Set(key, value)
    if DEFAULTS[key] == nil then
        error("unknown config key: " .. tostring(key), 0)
    end
    database[key] = value
end
