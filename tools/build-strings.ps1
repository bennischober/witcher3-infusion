# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Builds the mod's .w3strings files from tools\strings-sources into
# src\modInfusion\content\strings.
#
# en and de have their own sources. Every other language the game ships gets
# the English texts - without a file for the player's language the UI texts
# would be empty. The encoder (w3stringsr) is not committed: tools\README.md.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$encoder = Join-Path $PSScriptRoot "w3stringsr\w3stringsr.exe"
if (-not (Test-Path $encoder)) {
    Write-Error "w3stringsr.exe not found at $encoder - see tools\README.md"
}

$sources = Join-Path $PSScriptRoot "strings-sources"
$outDir = Join-Path $RepoRoot "src\modInfusion\content\strings"
$idSpace = "12345"

# Languages with their own translation, and the ones that get English.
# The list matches the game's content0\*.w3strings (Remastered 5.01).
$own = [ordered]@{ en = "infusion_strings_en.csv"; de = "infusion_strings_de.csv" }
$fallback = @("ar", "br", "cn", "cz", "es", "esmx", "fr", "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh")

$tmp = Join-Path ([IO.Path]::GetTempPath()) "infusion-strings"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Encoder([string]$csv, [string]$lang) {
    $out = Join-Path $outDir "$lang.w3strings"
    & $encoder -i $idSpace $csv $out | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "w3stringsr failed for '$lang' ($csv)"
    }
}

foreach ($lang in $own.Keys) {
    Invoke-Encoder (Join-Path $sources $own[$lang]) $lang
}

# Fallback languages: the English source with its language header swapped.
$enLines = Get-Content -Encoding UTF8 (Join-Path $sources $own["en"])
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($lang in $fallback) {
    $lines = $enLines | ForEach-Object {
        if ($_ -match '^;meta\[language=') { ";meta[language=$lang]" } else { $_ }
    }
    $csv = Join-Path $tmp "infusion_strings_$lang.csv"
    [System.IO.File]::WriteAllLines($csv, [string[]]$lines, $utf8NoBom)
    Invoke-Encoder $csv $lang
}

Write-Host "Built $($own.Count + $fallback.Count) string files in $outDir ($($own.Keys -join ', ') translated, $($fallback.Count) languages with English texts)"
