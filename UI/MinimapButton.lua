local _, ns = ...
local Launcher = {}
ns.MinimapButton = Launcher

function Launcher:Initialize()
    if self.frame or not Minimap then return end
    local button = ns:CreateUIFrame("ClassHelperMinimapButton", Minimap, "Button")
    self.frame = button
    button:SetSize(32, 32)
    button:SetPoint("CENTER", Minimap, "CENTER", -58, -58)
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    local icon = ns.Compat:CreateTexture(button, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)

    local border = ns.Compat:CreateTexture(button, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    local highlight = ns.Compat:CreateTexture(button, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetAllPoints()
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function()
        if GameTooltip then GameTooltip:Hide() end
        ns.MainWindow:Toggle()
    end)
    button:SetScript("OnEnter", function()
        if not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("ClassHelper", 1, 0.82, 0)
        GameTooltip:AddLine(ns.L:Get("MINIMAP_TOGGLE"), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    button:SetScript("OnHide", function() if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end end)
    button:Show()
end

ns:RegisterModule("MinimapButton", Launcher)
