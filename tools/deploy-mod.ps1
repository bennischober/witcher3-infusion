# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Deploys the infusion mod sources from this repository into the game's mods folder.
#
# The game directory receives copies only - never edit deployed files directly.
# After deploying, launch the game; WitcherScript compiles loose .ws files at startup.

param(
    [string]$GameDir = "E:\SteamLibrary\steamapps\common\The Witcher 3",
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$modName = "modInfusion"
$srcRoot = Join-Path $RepoRoot "src\$modName"
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
New-Item -ItemType Directory -Force -Path $dstRoot | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $srcRoot "*") -Destination $dstRoot

# Report what was deployed
$files = Get-ChildItem -Recurse -File -Path $dstRoot | Where-Object { $_.Name -notlike "__folder_managed_by_vortex" }
Write-Host "Deployed $($files.Count) file(s) to ${dstRoot}:"
$files | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($dstRoot.Length + 1)) }

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Launch the game (scripts compile at startup)."
Write-Host "  2. Enable the console (DBGConsoleOn) if not yet enabled."
Write-Host "  3. In game, open the console and run: infuseHelp"
