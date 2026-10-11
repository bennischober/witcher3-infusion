# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Deploys the infusion mod sources from this repository into the game's mods folder.
#
# The game directory receives copies only - never edit deployed files directly.
# After deploying, launch the game; WitcherScript compiles loose .ws files at startup.
#
# Modes:
#   default  - release layout: src/modInfusion only (what players get)
#   -Dev     - development layout: src/modInfusion + tests/modInfusion overlaid
#              into the same mod folder (debug console commands available).
#              The overlay must mirror the src structure exactly - both trees
#              are deployed to mods/modInfusion, tests files win.
#
# -Uninstall removes the deployed mod folder entirely.

param(
    [string]$GameDir = "E:\SteamLibrary\steamapps\common\The Witcher 3",
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Dev,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$modName = "modInfusion"
$srcRoot = Join-Path $RepoRoot "src\$modName"
$testRoot = Join-Path $RepoRoot "tests\$modName"
$dstRoot = Join-Path $GameDir "mods\$modName"

if (-not (Test-Path $srcRoot)) {
    Write-Error "Source mod folder not found: $srcRoot"
}

if ($Uninstall) {
    if (Test-Path $dstRoot) {
        Remove-Item -Recurse -Force $dstRoot
        Write-Host "Removed $dstRoot"
    } else {
        Write-Host "Nothing to remove: $dstRoot does not exist"
    }
    $cfgDst = Join-Path $GameDir "bin\config\r4game\user_config_matrix\pc\modInfusion.xml"
    if (Test-Path $cfgDst) {
        Remove-Item -Force $cfgDst
        Write-Host "Removed settings XML: $cfgDst"
    }
    exit 0
}

if (-not (Test-Path $GameDir)) {
    Write-Error "Game directory not found: $GameDir (adjust -GameDir)"
}

# Mirror src/modInfusion/content -> mods/modInfusion/content
# The mod folder is fully owned by this repo, so wipe it first: a previous
# DEV deploy must not leave test scripts behind in a RELEASE deploy.
New-Item -ItemType Directory -Force -Path $dstRoot | Out-Null
if (Test-Path (Join-Path $dstRoot "content")) {
    Remove-Item -Recurse -Force (Join-Path $dstRoot "content")
}
Copy-Item -Recurse -Force -Path (Join-Path $srcRoot "*") -Destination $dstRoot

# The settings-menu XML must live in the GAME's config folder (5.0+ auto-detects
# every XML there; the mod folder's bin/ is NOT scanned for config matrices).
$cfgSrc = Join-Path $srcRoot "bin\config\r4game\user_config_matrix\pc\modInfusion.xml"
$cfgDst = Join-Path $GameDir "bin\config\r4game\user_config_matrix\pc\modInfusion.xml"
if (Test-Path $cfgSrc) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cfgDst) | Out-Null
    Copy-Item -Force $cfgSrc $cfgDst
    Write-Host "Settings XML installed: $cfgDst"
}

# Dev mode: overlay tests tree into the SAME mod folder (files win over src).
# Kept as one folder so the script set compiles exactly as in release,
# plus the debug commands.
if ($Dev) {
    if (Test-Path $testRoot) {
        Copy-Item -Recurse -Force -Path (Join-Path $testRoot "*") -Destination $dstRoot
    } else {
        Write-Warning "Dev mode requested but no tests folder found at $testRoot"
    }
}

# Report what was deployed
$files = Get-ChildItem -Recurse -File -Path $dstRoot | Where-Object { $_.Name -notlike "__folder_managed_by_vortex" }
$mode = if ($Dev) { "DEV (src + tests)" } else { "RELEASE (src only)" }
Write-Host "Deployed [$mode] $($files.Count) files to $dstRoot"
$files | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($dstRoot.Length + 1)) }

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Launch the game (scripts compile at startup; -debugscripts writes scriptslog.txt on compile errors)."
Write-Host "  2. Enable the console (DBGConsoleOn=true in bin/config/base/general.ini)."
if ($Dev) {
    Write-Host "  3. In game, open the console and run: infuseHelp"
} else {
    Write-Host "  3. No debug commands in release mode."
}
