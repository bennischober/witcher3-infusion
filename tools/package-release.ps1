# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Builds the player release: dist\modInfusion-<version>.zip
#
#   mods\modInfusion\content\...       the release scripts and strings (src\ only)
#   mods\modInfusion\README.md         install guide      (docs\INSTALL.md)
#   mods\modInfusion\CONFIGURATION.md  configuration      (docs\CONFIGURATION.md)
#   mods\modInfusion\KNOWN_ISSUES.md   known issues       (docs\KNOWN_ISSUES.md)
#   mods\modInfusion\CHANGELOG.md      release notes      (CHANGELOG.md)
#
# Players extract the zip into the game folder. The release check fails the
# build if any dev tooling (tests\ files, console commands) would ship.
#
#   -Version      overrides the VERSION file
#   -SkipStrings  don't rebuild the .w3strings files (needs no encoder)
#   -Deploy       also install the packaged mod into the game (release test:
#                 exactly what players get, no debug commands)

param(
    [string]$Version = "",
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$SkipStrings,
    [switch]$Deploy,
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$modName = "modInfusion"
if (-not $Version) {
    $Version = (Get-Content (Join-Path $RepoRoot "VERSION") -TotalCount 1).Trim()
}
if ($Version -notmatch '^\d+\.\d+\.\d+([-+][0-9A-Za-z.]+)?$') {
    Write-Error "Version '$Version' is not semantic (x.y.z)"
}

if (-not $SkipStrings) {
    & (Join-Path $PSScriptRoot "build-strings.ps1") -RepoRoot $RepoRoot
}

# ---- stage -----------------------------------------------------------------
$dist = Join-Path $RepoRoot "dist"
$stage = Join-Path $dist "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
$modDst = Join-Path $stage "mods\$modName"
New-Item -ItemType Directory -Force -Path $modDst | Out-Null

Copy-Item -Recurse -Path (Join-Path $RepoRoot "src\$modName\content") -Destination $modDst
Copy-Item (Join-Path $RepoRoot "docs\INSTALL.md") (Join-Path $modDst "README.md")
Copy-Item (Join-Path $RepoRoot "docs\CONFIGURATION.md") (Join-Path $modDst "CONFIGURATION.md")
Copy-Item (Join-Path $RepoRoot "docs\KNOWN_ISSUES.md") (Join-Path $modDst "KNOWN_ISSUES.md")
Copy-Item (Join-Path $RepoRoot "CHANGELOG.md") (Join-Path $modDst "CHANGELOG.md")

# ---- release check ---------------------------------------------------------
$problems = @()

# No file from the dev overlay may ship.
$testNames = Get-ChildItem -Recurse -File (Join-Path $RepoRoot "tests\$modName\content") | ForEach-Object { $_.Name }
$leaks = Get-ChildItem -Recurse -File $modDst | Where-Object { $testNames -contains $_.Name }
foreach ($f in $leaks) { $problems += "dev file in the release: $($f.FullName.Substring($stage.Length + 1))" }

# No console command may ship.
$scripts = Get-ChildItem -Recurse -File -Path $modDst -Filter *.ws
$execs = $scripts | Select-String -Pattern '^\s*exec\s+function'
foreach ($m in $execs) { $problems += "console command in the release: $($m.Filename):$($m.LineNumber)" }

# Scripts must be UTF-8 with BOM (Remastered requirement).
foreach ($s in $scripts) {
    $head = [System.IO.File]::ReadAllBytes($s.FullName) | Select-Object -First 3
    if (-not ($head.Count -eq 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)) {
        $problems += "script without UTF-8 BOM: $($s.Name)"
    }
}

# Every game language needs a strings file.
$languages = @("ar", "br", "cn", "cz", "de", "en", "es", "esmx", "fr", "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh")
foreach ($lang in $languages) {
    if (-not (Test-Path (Join-Path $modDst "content\strings\$lang.w3strings"))) {
        $problems += "missing strings file: $lang.w3strings (run tools\build-strings.ps1)"
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Error "Release check failed ($($problems.Count) problems)"
}

# ---- zip -------------------------------------------------------------------
$zip = Join-Path $dist "$modName-$Version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$files = Get-ChildItem -Recurse -File $stage
Write-Host "Release check passed: $($scripts.Count) scripts, no dev files, no console commands, $($languages.Count) languages"
Write-Host "Packaged $($files.Count) files -> $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)"
$files | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($stage.Length + 1)) }

# ---- optional release test deploy ------------------------------------------
if ($Deploy) {
    . "$PSScriptRoot\w3paths.ps1"
    if (-not $GameDir) { $GameDir = Get-W3GameDir }
    if (-not $GameDir -or -not (Test-Path $GameDir)) {
        Write-Error "The Witcher 3 not found - pass -GameDir or set W3_GAME_DIR"
    }
    $dstRoot = Join-Path $GameDir "mods\$modName"
    if (Test-Path $dstRoot) { Remove-Item -Recurse -Force $dstRoot }
    Copy-Item -Recurse -Path $modDst -Destination (Join-Path $GameDir "mods")
    Write-Host ""
    Write-Host "Installed the release package to $dstRoot (no debug commands)."
}
