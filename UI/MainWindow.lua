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

    self.tabs = {}
    for index = 1, #TABS do
        local tab = TABS[index]
        self.tabs[#self.tabs + 1] = widgets.Tab(frame, tab.key, tab.label)
    end
    self.selectedTab = "gear"

    self:RestorePosition()

    ns.Compat:AddEscapeFrame("ClassHelperMainWindow")

    if ns.Config:Get("startHidden") then
        frame:Hide()
    end

    return self
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

function MainWindow:Refresh()
    if self.statusStrip then
        self.statusStrip:SetText("Ready")
    end
end

function MainWindow:SelectTab(key)
    for index = 1, #TABS do
        if TABS[index].key == key then
            self.selectedTab = key
            self:Refresh()
            return true
        end
    end
    return false
end

function MainWindow:Show()
    if not self.frame then self:Create() end
    if self.frame then
        self.frame:Show()
        self:Refresh()
    end
end

function MainWindow:Hide()
    if self.frame then
        self.frame:Hide()
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
