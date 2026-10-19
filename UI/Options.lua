local _, ns = ...
local Options = {}
ns.Options = Options

function Options:SourceEntries()
    local entries, seen = {}, {}
    local function add(label, url, date, revision)
        if not url or url == "" then return end
        local key = label .. url .. (date or "") .. (revision or "")
        if seen[key] then return end
        seen[key] = true
        entries[#entries + 1] = label .. "\n" .. url
            .. (date and ("\n" .. ns.L:Get("OPTIONS_DATE") .. ": " .. date) or "")
            .. (revision and ("\n" .. ns.L:Get("OPTIONS_REVISION") .. ": " .. revision) or "")
    end
    for identity, record in pairs(ns.ClassGuideData) do
        for _, mode in ipairs({ "pve", "pvp" }) do
            for _, source in ipairs(record[mode] and record[mode].sources or {}) do
                add(identity .. " / " .. mode, source.url, source.date)
            end
        end
    end
    for era, source in pairs(ns.BISCatalog.sources) do add("BiS / " .. era .. " / " .. source.name, source.url, nil, source.revision) end
    for _, build in ipairs(ns.PvPData.builds) do add("PvP / " .. build.era .. " / " .. build.classToken .. " / " .. build.title, build.url, build.date) end
    for era, classes in pairs(ns.ItemWeights) do
        for classToken, specs in pairs(classes) do
            for spec, weights in pairs(specs) do
                local repository, page = weights.source:match("^(%S+)%s*/%s*(%S+)$")
                add("EP / " .. era .. " / " .. classToken .. " / " .. spec,
                    repository and ("https://github.com/" .. repository .. "/blob/" .. weights.revision .. "/ui/" .. page .. "/sim.ts"), nil, weights.revision)
            end
        end
    end
    table.sort(entries)
    return entries
end

function Options:SourceText() return table.concat(self:SourceEntries(), "\n\n") end

function Options:Initialize()
    if self.panel or not InterfaceOptions_AddCategory then return end
    local panel = ns.Compat:CreateFrame("Frame", "ClassHelperOptions", UIParent)
    panel.name = "ClassHelper"
    self.panel = panel
    local scroll = ns.Compat:CreateFrame("ScrollFrame", "ClassHelperOptionsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -48)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    local child = ns.Compat:CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    local author = GetAddOnMetadata and GetAddOnMetadata(ns.name, "Author") or "ClassHelper"
    local intro = "ClassHelper\n" .. ns.L:Get("OPTIONS_AUTHOR") .. ": " .. (author or "ClassHelper")
        .. "\n\n" .. ns.L:Get("OPTIONS_DESCRIPTION") .. "\n\n" .. ns.L:Get("OPTIONS_SOURCES") .. "\n\n"
    local text = ns.Widgets.Label(child, "", "GameFontHighlight")
    self.text, self.scroll = text, scroll
    text:SetPoint("TOPLEFT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    local function layout()
        local width = math.max(300, (panel:GetWidth() or 600) - 56)
        child:SetWidth(width)
        text:SetWidth(width)
        child:SetHeight(math.max(1, text:GetStringHeight() + 20))
    end
    self.entries = self:SourceEntries()
    local function showPage(page)
        self.page = math.max(1, math.min(math.ceil(#self.entries / 12), page))
        local lines = {}
        for i = (self.page - 1) * 12 + 1, math.min(#self.entries, self.page * 12) do lines[#lines + 1] = self.entries[i] end
        text:SetText(intro .. table.concat(lines, "\n\n"))
        scroll:SetVerticalScroll(0)
        self.pageLabel:SetText(self.page .. " / " .. math.ceil(#self.entries / 12))
        layout()
    end
    self.pageLabel = ns.Widgets.Label(panel, "", "GameFontNormal")
    self.pageLabel:SetPoint("TOP", 0, -18)
    local previous = ns.Widgets.Button(panel, nil, ns.L:Get("OPTIONS_PREVIOUS"), function() showPage(self.page - 1) end)
    previous:SetSize(110, 24)
    previous:SetPoint("TOPLEFT", 12, -10)
    local nextPage = ns.Widgets.Button(panel, nil, ns.L:Get("OPTIONS_NEXT"), function() showPage(self.page + 1) end)
    nextPage:SetSize(110, 24)
    nextPage:SetPoint("TOPRIGHT", -32, -10)
    self.nextPage, self.previousPage = nextPage, previous
    panel:SetScript("OnShow", function() showPage(self.page or 1) end)
    panel:SetScript("OnSizeChanged", layout)
    panel:Hide()
    showPage(1)
    InterfaceOptions_AddCategory(panel)
end

ns:RegisterModule("Options", Options)
