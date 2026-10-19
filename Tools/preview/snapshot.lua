-- Usage: luajit Tools/preview/snapshot.lua <locale> <profile> <stage> <tab> <clicks> <loaded>
-- clicks: comma-separated node ids replayed in order; ids are stable for the same click history.
TestState = { baseG = _G }
dofile("Tests/testlib.lua")
dofile("Tests/load_addon.lua")
dofile("Tests/wow_stub.lua")

local locale, profileKey, stageKey, tabKey = arg[1] or "ruRU", arg[2] or "", arg[3] or "", arg[4] or ""
local clicks, loaded = arg[5] or "", arg[6] == "1"

local stub = WowStub.New({ locale = locale })
if tabKey == "options" then
    stub:SetEnv("InterfaceOptions_AddCategory", function(panel)
        panel:SetSize(640, 560)
        panel:SetPoint("CENTER", stub.env.UIParent, "CENTER")
    end)
end
local ns = LoadAddon(".", stub).namespace
stub:Fire("ADDON_LOADED", "ClassHelper")
local window = ns.MainWindow

local catalogOK, catalog = pcall(dofile, ".runtime/wow-art-png/items.lua")
if loaded and catalogOK then
    -- The preview pretends the client cache is warm; the addon itself never does this.
    local peek = window.resolver.Peek
    window.resolver.Peek = function(resolver, itemID)
        local item = catalog[itemID]
        if item then
            return { state = "loaded", name = item.name, quality = item.quality, link = "item:" .. itemID,
                texture = "Interface\\Icons\\" .. item.icon }
        end
        return peek(resolver, itemID)
    end
end

if profileKey ~= "" then assert(window:SelectProfile(profileKey), "unknown profile") end
window:SelectTab(window.selectedTab)
if stageKey ~= "" then assert(window:SelectStage(stageKey), "unknown stage") end
if tabKey ~= "" then window:SelectTab(tabKey) end
if tabKey == "options" then
    ns.Options.panel:Show()
    ns.Options.panel:GetScript("OnShow")(ns.Options.panel)
else window:Show() end

local function collect()
    local nodes, ids = {}, {}
    local function visit(object, parentID)
        if ids[object] or not object.shown then return end
        local id = #nodes + 1
        ids[object] = id
        nodes[id] = { object = object, parent = parentID }
        for _, child in ipairs(object.children) do
            if child.parent == object then visit(child, id) end
        end
    end
    visit(tabKey == "options" and ns.Options.panel or window.frame)
    return nodes, ids
end

for token in clicks:gmatch("%d+") do
    local nodes = collect()
    local node = nodes[tonumber(token)]
    if node and node.object.scripts.OnClick then node.object:Click() end
end

local nodes, ids = collect()

local function quote(value)
    return '"' .. tostring(value):gsub('[%z\1-\31\\"]', function(c)
        return ('\\u%04x'):format(c:byte())
    end) .. '"'
end
local function json(value)
    local kind = type(value)
    if kind == "string" then return quote(value) end
    if kind == "number" then return value ~= value and "null" or tostring(value) end
    if kind == "boolean" then return tostring(value) end
    if kind ~= "table" then return "null" end
    local parts = {}
    if #value > 0 then
        for _, item in ipairs(value) do parts[#parts + 1] = json(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for key, item in pairs(value) do parts[#parts + 1] = quote(key) .. ":" .. json(item) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local out = {}
for id, node in ipairs(nodes) do
    local object = node.object
    local anchors = {}
    for _, anchor in ipairs(object.anchors or {}) do
        local relative = anchor.relativeTo
        anchors[#anchors + 1] = { point = anchor.point, relativePoint = anchor.relativePoint, x = anchor.x, y = anchor.y,
            relativeTo = relative and (ids[relative] or (relative == stub.env.UIParent and 0) or -1) or node.parent or 0 }
    end
    local texture = object.texture
    out[id] = {
        id = id, parent = node.parent, kind = object.objectType, name = object.name,
        width = object.width, height = object.height, anchors = anchors,
        texture = type(texture) == "string" and texture or nil, color = object.textureColor,
        texCoord = object.texCoord, vertexColor = object.vertexColor, alpha = object.alpha,
        blend = object.blendMode, desaturated = object.desaturated, portrait = object.portrait,
        gradient = object.gradientAlpha, layer = object.layer, strata = object.frameStrata,
        text = object.text, textColor = object.textColor, fontObject = object.fontObject or object.layer,
        fontSize = object.fontSize, justifyH = object.justifyH,
        backdrop = object.backdrop, backdropColor = object.backdropColor, backdropBorderColor = object.backdropBorderColor,
        scroll = object.objectType == "ScrollFrame" and object:GetVerticalScroll() or nil,
        clickable = object.scripts.OnClick ~= nil,
    }
end

local stages = {}
for _, record in ipairs(ns.Registry:List("bisStage")) do
    stages[#stages + 1] = { key = record.key, era = record.era, name = ns.L:Get(record.nameKey) }
end
io.write(json({ nodes = out, stages = stages, profile = window.selectedProfile, stage = window.selectedStage,
    tab = window.selectedTab, itemQueries = stub.calls.GetItemInfo }))
