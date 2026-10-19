-- UI/MainWindow.lua: the vertical-slice Compendium shell. It assembles the fixed
-- 900x620 window, portrait, fixed profile labels, scroll host, status strip, and five
-- bottom tabs. Full Guide section renderers arrive in a later plan.

local addonName, ns = ...

local MainWindow = {}
ns.MainWindow = MainWindow

local TABS = {
    { key = "talents", localeKey = "CLASS_TALENTS", classGuide = true },
    { key = "glyphs", localeKey = "CLASS_GLYPHS", classGuide = true },
    { key = "guide", localeKey = "TAB_GUIDE", section = "overview" },
    { key = "enhancements", localeKey = "TAB_ENCHANTMENTS", section = "enhancements" },
    { key = "consumables", localeKey = "TAB_CONSUMABLES", section = "consumables" },
    { key = "trinkets", localeKey = "TAB_TRINKETS", section = "trinkets" },
    { key = "gear", localeKey = "TAB_GEAR" },
}

-- The shell always presents the Human Retribution PvE guide. These controls are
-- manual and fixed, never derived from the current unit's class.
MainWindow.profile = {
    raceToken = "HUMAN",
    classToken = "PALADIN",
    specKey = "retribution",
    fixed = true,
}

function MainWindow:GetTabKeys()
    local keys = {}
    for index = 1, #TABS do
        if self:IsTabAvailable(TABS[index]) then keys[#keys + 1] = TABS[index].key end
    end
    return keys
end

function MainWindow:IsTabAvailable(tab)
    if tab.classGuide then return self.profile.databaseProfile ~= nil and self.profile.databaseProfile ~= false end
    if self.profile.databaseProfile and tab.key ~= "gear" then return false end
    if self.profile.databaseProfile and tab.key == "trinkets" then return false end
    if self.profile.contentMode == "pvp" and tab.key == "gear" then return true end
    local stageKey = self.selectedStage or ns.Config:Get("selectedStage")
    if tab.key == "guide" then
        for _, key in ipairs({ "overview", "stats", "talents", "rotation" }) do
            if ns.GuideService:GetSection(self.profile, stageKey, key) then return true end
        end
        return false
    end
    return ns.GuideService:GetSection(self.profile, stageKey, tab.section or tab.key) ~= nil
end

function MainWindow:Create()
    if self.frame then return self end

    self:RestoreProfile()

    local widgets = ns.Widgets
    local theme = ns.Theme
    local parent = UIParent

    local frame = ns:CreateUIFrame("ClassHelperMainWindow", parent)
    if not frame then return self end
    self.frame = frame

    frame:SetWidth(theme.Window.width)
    frame:SetHeight(theme.Window.height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    self.chrome = widgets.WindowChrome(frame)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        if point and x and y then
            ns.Config:Set("windowPosition", point .. ":" .. tostring(x) .. ":" .. tostring(y))
        end
    end)
    self.closeButton = self.chrome.closeButton
    self.closeButton:SetScript("OnClick", function() self:Hide() end)

    frame.title = self.chrome.titleText
    ns.ProfilePicker:Attach(self)

    self.stageBackground = ns.Compat:CreateTexture(frame, "BACKGROUND")
    self.stageBackground:SetPoint("TOPLEFT", 14, -78)
    self.stageBackground:SetPoint("BOTTOMRIGHT", -14, 34)
    self.stageBackground:SetVertexColor(0.55, 0.55, 0.55, 1)
    self.stageBackground:SetAlpha(0.45)
    self.portrait = widgets.Portrait(frame)
    self.portrait:SetClass(self.profileRecord.classToken)
    self.scrollHost = widgets.ScrollHost(frame)
    self.statusStrip = self.chrome.footerText
    self.statusText = self.statusStrip
    self.contentHost = self.scrollHost

    self:BuildRuntime(frame)
    self:BuildProgressionControls(frame)
    ns.GuideSection:Restore()

    self:UpdateTabs()

    self:RestorePosition()

    local selected = ns.Config:Get("selectedTab")
    if not self:SelectTab(selected) then self:SelectTab("gear") end

    ns.Compat:AddEscapeFrame("ClassHelperMainWindow")

    if ns.Config:Get("startHidden") then
        frame:Hide()
    end

    return self
end

function MainWindow:UpdateTabs()
    self.tabCache, self.tabs = self.tabCache or {}, {}
    for _, widget in pairs(self.tabCache) do widget.frame:Hide() end
    local count = #self:GetTabKeys()
    if count == 0 then return end
    local width = math.min(150, math.floor((self.frame:GetWidth() - 40) / count))
    for _, tab in ipairs(TABS) do
        if self:IsTabAvailable(tab) then
            local widget = self.tabCache[tab.key]
            if not widget then
                widget = ns.Widgets.Tab(self.frame, tab.key, ns.L:Get(tab.localeKey), function(key) self:SelectTab(key) end)
                self.tabCache[tab.key] = widget
            end
            widget.labelWidget:SetText(ns.L:Get(self.profile.databaseProfile and tab.key == "gear" and "EQUIPMENT_TAB" or tab.localeKey))
            widget.frame:ClearAllPoints()
            widget.frame:SetWidth(width)
            widget.frame:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT", 20 + #self.tabs * (width - 14), 2)
            widget.frame:Show()
            self.tabs[#self.tabs + 1] = widget
        end
    end
end

function MainWindow:RefreshNavigation()
    ns.Widgets.CloseDropdowns()
    self:UpdateProgressionLabels()
    self:UpdateTabs()
    if not self:SelectTab(self.selectedTab) then
        local keys = self:GetTabKeys()
        if keys[1] then self:SelectTab(keys[1]) end
    end
end

function MainWindow:RestoreProfile(key)
    local record = ns.Registry:Get("profile", key or ns.Config:Get("selectedProfile"))
        or ns.Registry:Get("profile", "bis_human_paladin_retribution")
    self.profileRecord, self.selectedProfile = record, record.key
    self.profile = { raceToken = record.raceOverlay, classToken = record.classToken, specKey = record.specKey,
        databaseProfile = record.databaseProfile, sourceSpec = record.sourceSpec, fixed = true,
        contentMode = ns.Config:Get("selectedContentMode") == "pvp" and "pvp" or "pve" }
    ns.Config:Set("selectedProfile", record.key)
end

function MainWindow:ProfileName()
    local record = self.profileRecord
    if not record.databaseProfile then return ns.L:Get(record.nameKey) end
    return table.concat({ ns.L:Get("BIS_RACE_" .. record.raceOverlay), ns.L:Get("BIS_CLASS_" .. record.classToken),
        ns.L:Get(record.nameKey) or record.sourceSpec }, " • ")
end

function MainWindow:GetStage(key)
    for era, level in pairs({ classic = 60, tbc = 70, wrath = 80 }) do
        if key == "class_guide_" .. era then return { key = key, era = era, nameKey = "CLASS_LEVEL_" .. level } end
    end
    if self.profile.contentMode == "pvp" then return ns.Registry:Get("pvpStage", key) end
    return ns.Registry:Get(self.profile.databaseProfile and "bisStage" or "stage", key)
end

function MainWindow:SelectProfile(key)
    if not ns.Registry:Get("profile", key) then return false end
    self:RestoreProfile(key)
    if self.frame then
        self.portrait:SetClass(self.profileRecord.classToken)
        local stages = self:GetStages(self.selectedEra)
        if #stages == 0 then
            self.selectedEra = "wrath"
            stages = self:GetStages(self.selectedEra)
        end
        local valid = false
        for _, stage in ipairs(stages) do if stage.key == self.selectedStage then valid = true end end
        if not valid then self.selectedStage = stages[1] and stages[1].key end
        self:RefreshNavigation()
    end
    return true
end

function MainWindow:GetStages(era)
    local result = {}
    for _, stage in ipairs(ns.Registry:List(self.profile.contentMode == "pvp" and "pvpStage" or self.profile.databaseProfile and "bisStage" or "stage")) do
        if stage.era == era and (stage.contentMode or "pve") == self.profile.contentMode
            and ns.GuideService:GetGear(self.profile, stage.key) then
            result[#result + 1] = stage
        end
    end
    if #result == 0 and self.profile.databaseProfile then
        local level = ({ classic = 60, tbc = 70, wrath = 80 })[era]
        if level then result[1] = { key = "class_guide_" .. era, era = era, nameKey = "CLASS_LEVEL_" .. level } end
    end
    return result
end

function MainWindow:SelectContentMode(mode)
    if mode ~= "pve" and mode ~= "pvp" then return false end
    local previous = self.profile.contentMode or "pve"
    ns.Config:Set(previous == "pvp" and "selectedPvpStage" or "selectedPveStage", self.selectedStage or "")
    ns.Config:Set("selectedContentMode", mode)
    self.profile.contentMode = mode
    local saved = ns.Config:Get(mode == "pvp" and "selectedPvpStage" or "selectedPveStage")
    self.selectedStage = nil
    for _, era in ipairs({ self.selectedEra, "wrath", "tbc", "classic" }) do
        for _, stage in ipairs(self:GetStages(era)) do
            if not self.selectedStage or stage.key == saved then
                self.selectedStage, self.selectedEra = stage.key, era
            end
        end
    end
    self:RefreshNavigation()
    return true
end

function MainWindow:BuildProgressionControls(frame)
    self.selectedEra = ns.Config:Get("selectedEra")
    local stages = self:GetStages(self.selectedEra)
    if #stages == 0 then
        self.selectedEra = "wrath"
        stages = self:GetStages(self.selectedEra)
    end
    self.selectedStage = ns.Config:Get("selectedStage")
    local valid = false
    for _, stage in ipairs(stages) do
        if stage.key == self.selectedStage then valid = true end
    end
    if not valid then self.selectedStage = stages[1] and stages[1].key end

    local picker = ns.ProfilePicker
    self.classDropdown = ns.Widgets.Dropdown(frame, "ClassHelperClassDropdown", 210)
    self.classDropdown.frame:SetPoint("TOPLEFT", 56, -40)
    self.classDropdown:SetEntries(function() return picker:ClassEntries() end)
    self.raceDropdown = ns.Widgets.Dropdown(frame, "ClassHelperRaceDropdown", 150)
    self.raceDropdown.frame:SetPoint("TOPLEFT", 274, -40)
    self.raceDropdown:SetEntries(function() return picker:RaceEntries() end)
    self.stageDropdown = ns.Widgets.Dropdown(frame, "ClassHelperStageDropdown", 190)
    self.stageDropdown.frame:SetPoint("TOPLEFT", 432, -40)
    self.stageDropdown:SetEntries(function() return self:StageEntries() end)
    self.modeButton = ns.Widgets.FramedButton(frame, "ClassHelperContentMode", "", function()
        self:SelectContentMode(self.profile.contentMode == "pvp" and "pve" or "pvp")
    end)
    self.modeButton:SetSize(64, 24)
    self.modeButton:SetPoint("TOPRIGHT", -48, -8)
    self:UpdateProgressionLabels()
end

function MainWindow:StageEntries()
    local entries = {}
    for _, era in ipairs({ "classic", "tbc", "wrath" }) do
        local stages, children = self:GetStages(era), {}
        for _, stage in ipairs(stages) do
            local key = stage.key
            children[#children + 1] = { text = ns.L:Get(stage.nameKey), selected = key == self.selectedStage,
                onClick = function() self:SelectStage(key) end }
        end
        if #children > 0 then
            entries[#entries + 1] = { text = ns.L:Get("ERA_" .. string.upper(era)) .. " / " .. tostring(stages[1].levelCap),
                color = ns.Theme.Colors.eraColors[era], selected = era == self.selectedEra, children = children }
        end
    end
    return entries
end

function MainWindow:SelectStage(key)
    local stage = self:GetStage(key)
    if not stage then return false end
    for _, candidate in ipairs(self:GetStages(stage.era)) do
        if candidate.key == key then
            self.selectedEra, self.selectedStage = stage.era, key
            self:RefreshNavigation()
            return true
        end
    end
    return false
end

function MainWindow:RefreshDropdowns()
    local stage = self:GetStage(self.selectedStage)
    self.classDropdown:SetText(ns.ProfilePicker:ClassText())
    self.raceDropdown:SetText(ns.ProfilePicker:RaceText())
    if stage then self.stageDropdown:SetText(ns.L:Get(stage.nameKey), ns.Theme.Colors.eraColors[self.selectedEra]) end
    if not stage then self.stageDropdown:SetText(ns.L:Get("PVP_NO_STAGE")) end
    if self.modeButton then self.modeButton.labelWidget:SetText(self.profile.contentMode == "pvp" and "PvP" or "PvE") end
end

function MainWindow:UpdateProgressionLabels()
    local stage = self:GetStage(self.selectedStage)
    self:RefreshDropdowns()
    self:UpdateTitle()
    if not stage then return end
    ns.Config:Set("selectedEra", self.selectedEra)
    ns.Config:Set("selectedStage", self.selectedStage)
end

function MainWindow:UpdateTitle()
    local stage = self:GetStage(self.selectedStage)
    local background = ns.Art.ForStage(self.selectedStage)
    if background then
        self.stageBackground:SetTexture(background)
        self.stageBackground:Show()
    else
        self.stageBackground:Hide()
    end
    self.frame.title:SetText("ClassHelper")
end

function MainWindow:CycleEra(direction)
    local eras = { "classic", "tbc", "wrath" }
    local current = 1
    for index, era in ipairs(eras) do
        if era == self.selectedEra then current = index end
    end
    for offset = 1, #eras do
        local era = eras[((current - 1 + direction * offset) % #eras) + 1]
        local stages = self:GetStages(era)
        if #stages > 0 then self.selectedEra, self.selectedStage = era, stages[1].key; break end
    end
    self:RefreshNavigation()
end

function MainWindow:CycleStage(direction)
    local stages = self:GetStages(self.selectedEra)
    if #stages == 0 then return end
    local current = 1
    for index, stage in ipairs(stages) do
        if stage.key == self.selectedStage then current = index end
    end
    self.selectedStage = stages[((current - 1 + direction) % #stages) + 1].key
    self:RefreshNavigation()
end

function MainWindow:BuildRuntime(frame)
    local compat = ns.Compat

    local queue = ns.RequestQueue.New({
        now = function() return compat:GetTime() end,
        onError = function(message)
            if print then print("ClassHelper queue error: " .. tostring(message)) end
        end,
    })
    self.queue = queue
    ns.RuntimeQueue = queue

    local resolver = ns.ItemResolver.New(compat, queue)
    self.resolver = resolver
    ns.ItemResolverInstance = resolver

    local controller = ns.ViewController.New(resolver)
    self.viewController = controller
    frame:SetScript("OnHide", function()
        ns.Widgets.CloseDropdowns()
        controller:Close()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
        queue:Update(elapsed)
    end)
end

function MainWindow:RestorePosition()
    local raw = ns.Config:Get("windowPosition")
    local point, x, y = string.match(raw or "", "^([%w_]+):([%-]?[%d.]+):([%-]?[%d.]+)$")
    local frame = self.frame
    frame:ClearAllPoints()
    if point and point ~= "CENTER" then
        frame:SetPoint(point, UIParent, point, tonumber(x) or 0, tonumber(y) or 0)
    else
        frame:SetPoint("CENTER")
    end
end

function MainWindow:SelectTab(key)
    if key == "trinkets" and self.profile.databaseProfile then
        key = "gear"
        if ns.GearSection.modes then ns.GearSection.modes.gear = "overview" end
    end
    local known = false
    for index = 1, #TABS do
        if TABS[index].key == key and self:IsTabAvailable(TABS[index]) then
            known = true
            break
        end
    end
    if not known then return false end

    self.selectedTab = key
    self.frame:SetHeight(key == "talents" and 680 or ns.Theme.Window.height)
    if self.stageDropdown then
        if key == "talents" or key == "glyphs" then self.stageDropdown:Close(); self.stageDropdown.frame:Hide()
        else self.stageDropdown.frame:Show() end
    end
    ns.Widgets.CloseDropdowns()
    for _, tab in ipairs(self.tabs or {}) do tab:SetSelected(tab.key == key) end
    ns.Config:Set("selectedTab", key)
    ns.GearSection:Clear()
    ns.GuideSection:Clear()
    ns.ClassGuideSection:Clear()
    self.contentHost.viewport:SetVerticalScroll(0)
    self.contentHost:SetHeight(436)

    local view = self.viewController:Begin({
        tabKey = key, era = self.selectedEra, stageKey = self.selectedStage,
    })
    self.currentView = view

    if key == "description" or key == "talents" or key == "glyphs" then
        ns.ClassGuideSection:Render(self, view)
    elseif key ~= "guide" then
        ns.GearSection:Render(self, view)
    else
        ns.GuideSection:Render(self, view)
    end

    return true
end

function MainWindow:Show()
    if not self.frame then self:Create() end
    if self.frame then
        if self.viewController and not self.viewController:IsCurrent(self.currentView.generation) then
            self:SelectTab(self.selectedTab or "gear")
        end
        self.frame:Show()
    end
end

function MainWindow:Hide()
    if self.frame then
        self.frame:Hide()
    end
    if self.viewController then
        self.viewController:Close()
    end
end

function MainWindow:Toggle()
    if not self.frame then
        self:Create()
    end
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function MainWindow:Initialize()
    self:Create()
end

ns:RegisterModule("MainWindow", MainWindow)
