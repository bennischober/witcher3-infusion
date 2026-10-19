# Launches The Witcher 3 (Remastered, DX12) with script logging (-debugscripts).
# The log is written to <Documents>\The Witcher 3\scriptslog.txt.
# Steam must be running. Game folder: auto-detected from the Steam libraries,
# override with -GameDir or the W3_GAME_DIR environment variable.
#
#   powershell -File tools\launch-debug.ps1

param(
    [string]$GameDir = ""
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\w3paths.ps1"

if (-not $GameDir) { $GameDir = Get-W3GameDir }
if (-not $GameDir) {
    Write-Error "The Witcher 3 not found in the Steam libraries - pass -GameDir or set W3_GAME_DIR"
}

$exe = Join-Path $GameDir "bin\x64_dx12\witcher3.exe"
if (-not (Test-Path $exe)) {
    Write-Error "Game executable not found: $exe"
}

Start-Process -FilePath $exe -ArgumentList "-debugscripts"
Write-Host "Started $exe -debugscripts"
Write-Host ("Log: " + (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "The Witcher 3\scriptslog.txt"))
