local addonName, ns = ...

local Diagnostics = {}
ns.Diagnostics = Diagnostics

function Diagnostics:Run()
    local report = {
        schemaVersion = 1,
        locale = ns.Compat:GetLocale(),
        stages = 0,
        failed = 0,
        checks = {},
        notTested = { "visual_layout", "physical_input", "server_item_queries", "recommendation_accuracy" },
    }
    local function check(name, callback)
        local ok, err = pcall(callback)
        local entry = { name = name, passed = ok }
        if not ok then
            report.failed = report.failed + 1
            entry.error = string.sub(tostring(err), 1, 500)
        end
        report.checks[#report.checks + 1] = entry
    end
    check("lifecycle", function() assert(ns.initialized, "addon not initialized") end)
    local window = ns.MainWindow
    local imported = window.profile.databaseProfile
    for _, stage in ipairs(ns.Registry:List(imported and "bisStage" or "stage")) do
      if not imported or ns.GuideService:GetGear(window.profile, stage.key) then
        report.stages = report.stages + 1
        check("data:" .. stage.key, function()
            assert(ns.GuideService:GetGear(window.profile, stage.key), "missing gear")
            for _, section in ipairs(imported and {} or { "overview", "stats", "talents", "rotation", "enhancements", "consumables" }) do
                assert(ns.GuideService:GetSection(window.profile, stage.key, section), "missing " .. section)
            end
        end)
      end
    end
    check("ui:window", function()
        assert(window.frame, "missing window")
        assert(window.closeButton and window.classDropdown and window.stageDropdown, "missing controls")
        assert(window.contentHost and window.contentHost.viewport, "missing scroll viewport")
        assert(window.frame:GetScript("OnUpdate"), "missing request update handler")
    end)
    check("ui:tabs", function() assert(#window:GetTabKeys() == (imported and 3 or 5), "unexpected available tabs") end)
    report.passed = #report.checks - report.failed
    ClassHelperDiagnostics = report
    return report
end
