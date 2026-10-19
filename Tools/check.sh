#!/bin/sh
set -eu

task_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$task_root"
task_lua=${CLASSHELPER_LUA:-luajit}

if ! command -v "$task_lua" >/dev/null 2>&1; then
    printf '%s\n' 'LuaJIT is required; set CLASSHELPER_LUA to its executable path.' >&2
    exit 1
fi

"$task_lua" Tests/run.lua
"$task_lua" Tools/validate_data.lua --development
node --test Tests/audit_items.test.mjs Tests/export_items.test.mjs Tests/import_bis.test.mjs Tests/import_weights.test.mjs Tests/import_pvp.test.mjs Tests/import_class_guides.test.mjs Tests/rotation_diagrams.test.mjs
git diff --check

if [ "${1:-}" = '--release' ]; then
    "$task_lua" Tools/validate_data.lua --release
fi
