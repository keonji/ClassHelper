local addonName, ns = ...

local frame = ns.Compat:CreateFrame("Frame")
if frame then
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, loadedAddon)
        if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns:Initialize()
    end)
end
