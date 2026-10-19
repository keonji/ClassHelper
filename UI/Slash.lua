-- UI/Slash.lua: chat trigger registration and slash handler.

local addonName, ns = ...

-- The window is resolved at command time, not at load time, so the handler
-- does not depend on which file defined it first.
SLASH_CLASSCODEXWOTLK1 = "/ch"
SLASH_CLASSCODEXWOTLK2 = "/classhelper"

SlashCmdList.CLASSCODEXWOTLK = function(message)
    if string.lower((message or ""):match("^%s*(.-)%s*$")) == "diag" then
        local report = ns.Diagnostics:Run()
        local text
        if ns.Compat:GetLocale() == "ruRU" then
            text = "ClassHelper: диагностика %d/%d, ошибок %d. Отчёт сохранится в ClassHelperDiagnostics после /reload или выхода. Внешний вид, клики, сервер и точность рекомендаций не проверены."
        else
            text = "ClassHelper: diagnostics %d/%d, failures %d. ClassHelperDiagnostics will be saved after /reload or logout. Layout, clicks, server and recommendation accuracy are not tested."
        end
        print(text:format(report.passed, #report.checks, report.failed))
        return
    end
    ns.MainWindow:Toggle()
end
