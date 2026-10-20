# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Builds the mod's .w3strings files from tools\strings-sources into
# src\modInfusion\content\strings.
#
# Every language the game ships has its own source. A language without one
# gets the English texts - without a file for the player's language the UI
# texts would be empty. Arabic is shaped first (shape-arabic.py, needs
# Python 3). The encoder (w3stringsr) is not committed: tools\README.md.

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

# The list matches the game's content0\*.w3strings (Remastered 5.01).
$languages = @("en", "ar", "br", "cn", "cz", "de", "es", "esmx", "fr", "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh")

$tmp = Join-Path ([IO.Path]::GetTempPath()) "infusion-strings"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Invoke-Encoder([string]$csv, [string]$lang) {
    $out = Join-Path $outDir "$lang.w3strings"
    & $encoder -i $idSpace $csv $out | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "w3stringsr failed for '$lang' ($csv)"
    }
}

# "id|key" of every string line - all sources must have the English set.
function Get-StringKeys([string[]]$lines) {
    $lines | Where-Object { $_ -notmatch '^;' -and $_ -ne "" } | ForEach-Object { ($_ -split '\|')[0, 2] -join '|' }
}

$enLines = Get-Content -Encoding UTF8 (Join-Path $sources "infusion_strings_en.csv")
$enKeys = (Get-StringKeys $enLines) -join "`n"
$translated = @()
$fallback = @()

foreach ($lang in $languages) {
    $csv = Join-Path $sources "infusion_strings_$lang.csv"
    if (Test-Path $csv) {
        $lines = Get-Content -Encoding UTF8 $csv
        if (((Get-StringKeys $lines) -join "`n") -ne $enKeys) {
            Write-Error "$csv does not have the same ids and keys as the English source"
        }
        if ($lang -eq "ar") {
            $shaped = Join-Path $tmp "infusion_strings_ar.csv"
            & python (Join-Path $PSScriptRoot "shape-arabic.py") $csv $shaped
            if ($LASTEXITCODE -ne 0) { Write-Error "shape-arabic.py failed" }
            $csv = $shaped
        }
        $translated += $lang
    } else {
        # The English source with its language header swapped.
        $lines = $enLines | ForEach-Object {
            if ($_ -match '^;meta\[language=') { ";meta[language=$lang]" } else { $_ }
        }
        $csv = Join-Path $tmp "infusion_strings_$lang.csv"
        [System.IO.File]::WriteAllLines($csv, [string[]]$lines, $utf8NoBom)
        $fallback += $lang
    }
    Invoke-Encoder $csv $lang
}

$summary = "Built $($languages.Count) string files in $outDir ($($translated.Count) translated"
if ($fallback.Count -gt 0) { $summary += "; English texts for: $($fallback -join ', ')" }
Write-Host "$summary)"
