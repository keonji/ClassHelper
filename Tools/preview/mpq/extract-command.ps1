$ErrorActionPreference = "Stop"
$root = "\\Mac\Home\Projects\ClassHelper"
$data = "C:\Program Files (x86)\World of Warcraft\Data"
# Highest priority first, matching the client's patch load order.
$archives = @("ruRU\patch-ruRU-Z.MPQ", "ruRU\patch-ruRU-D.MPQ", "patch-V.mpq", "ruRU\patch-ruRU-3.MPQ", "patch-3.MPQ",
    "ruRU\patch-ruRU-2.MPQ", "patch-2.MPQ", "ruRU\patch-ruRU.MPQ", "patch.MPQ", "ruRU\lichking-locale-ruRU.MPQ",
    "lichking.MPQ", "ruRU\expansion-locale-ruRU.MPQ", "expansion.MPQ", "ruRU\locale-ruRU.MPQ", "ruRU\base-ruRU.MPQ",
    "common-2.MPQ", "common.MPQ") | ForEach-Object { Join-Path $data $_ }
Add-Type -TypeDefinition (Get-Content -Raw -LiteralPath "$root\Tools\preview\mpq\MpqExtract.cs")
$output = "$root\.runtime\wow-art"
$names = Get-Content -LiteralPath "$output\__LIST__"
[MpqExtract]::Run($archives, $names, $output) | Set-Content -LiteralPath "$output\extract-report.txt" -Encoding UTF8
"done"
