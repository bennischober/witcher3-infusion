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
#
# Game folder: auto-detected from the Steam libraries (tools\w3paths.ps1);
# override with -GameDir or the W3_GAME_DIR environment variable.

param(
    [string]$GameDir = "",
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Dev,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\w3paths.ps1"

if (-not $GameDir) { $GameDir = Get-W3GameDir }
if (-not $GameDir) {
    Write-Error "The Witcher 3 not found in the Steam libraries - pass -GameDir or set W3_GAME_DIR"
}

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
