-- UI/MainWindow.lua: the vertical-slice Compendium shell. It assembles the fixed
-- 900x620 window, portrait, fixed profile labels, scroll host, status strip, and five
-- bottom tabs. Full Guide section renderers arrive in a later plan.

local addonName, ns = ...

local MainWindow = {}
ns.MainWindow = MainWindow

local TABS = {
    { key = "guide", label = "Guide" },
    { key = "enhancements", label = "Enhancements" },
    { key = "consumables", label = "Consumables" },
    { key = "trinkets", label = "Trinkets" },
    { key = "gear", label = "Gear" },
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
        keys[index] = TABS[index].key
    end
    return keys
end

function MainWindow:Create()
    if self.frame then return self end

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
    widgets.Backdrop(frame)

    frame.title = widgets.Label(frame, "ClassHelper", theme.Fonts.title)
    frame.profileLabel = widgets.Label(frame, "Human / Paladin / Retribution", theme.Fonts.header)

    self.portrait = widgets.Portrait(frame)
    self.scrollHost = widgets.ScrollHost(frame)
    self.statusStrip = widgets.StatusStrip(frame)
    self.statusText = self.statusStrip
    self.contentHost = self.scrollHost

    self:BuildRuntime(frame)

    self.tabs = {}
    for index = 1, #TABS do
        local tab = TABS[index]
        local widget = widgets.Tab(frame, tab.key, tab.label, function(key)
            self:SelectTab(key)
        end)
        if widget then
            widget.frame:SetPoint("BOTTOMLEFT", 18 + ((index - 1) * 170), 18)
            self.tabs[#self.tabs + 1] = widget
        end
    end

    self:RestorePosition()

    self:SelectTab("gear")

    ns.Compat:AddEscapeFrame("ClassHelperMainWindow")

    if ns.Config:Get("startHidden") then
        frame:Hide()
    end

    return self
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
    local known = false
    for index = 1, #TABS do
        if TABS[index].key == key then
            known = true
            break
        end
    end
    if not known then return false end

    self.selectedTab = key

    local view = self.viewController:Begin({ tabKey = key })
    self.currentView = view

    if key == "gear" then
        ns.GearSection:Render(self, view)
    else
        ns.GearSection:Clear()
    end

    return true
end

function MainWindow:Show()
    if not self.frame then self:Create() end
    if self.frame then
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

SLASH_CLASSCODEXWOTLK1 = "/ch"
SLASH_CLASSCODEXWOTLK2 = "/classhelper"
SlashCmdList.CLASSCODEXWOTLK = function()
    MainWindow:Toggle()
end
