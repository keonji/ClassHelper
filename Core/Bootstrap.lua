local addonName, ns = ...

ns.name = addonName
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}
ns.createdFrames = ns.createdFrames or {}

function ns:GetUIParent()
    return UIParent
end

function ns:CreateUIFrame(name, parent)
    local compat = self.Compat
    if not compat then return nil end
    parent = parent or self:GetUIParent()
    local frame = compat:CreateFrame("Frame", name, parent)
    if frame then
        self.createdFrames[#self.createdFrames + 1] = frame
    end
    return frame
end

function ns:ResetCreatedFrames()
    self.createdFrames = {}
end

function ns:RegisterModule(name, module)
    assert(type(name) == "string" and name ~= "", "module name is required")
    assert(type(module) == "table", "module must be a table")
    assert(not self.modules[name], "duplicate module: " .. name)
    self.modules[name] = module
    self.moduleOrder[#self.moduleOrder + 1] = name
end

function ns:Initialize()
    if self.initialized then return end
    self.initialized = true
    for index = 1, #self.moduleOrder do
        local module = self.modules[self.moduleOrder[index]]
        if module.Initialize then module:Initialize() end
    end
end