local addonName, ns = ...

ns.name = addonName
ns.modules = ns.modules or {}
ns.moduleOrder = ns.moduleOrder or {}

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