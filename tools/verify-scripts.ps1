# Requires Windows PowerShell 5+ (uses UI Automation to read the error dialog).
# Compile gate: asks the game to compile every script (vanilla + all mods in its
# mods folder) and quit - no save, no player, ~20 s.
#
#   powershell -File tools\verify-scripts.ps1            # verify what is installed
#   powershell -File tools\verify-scripts.ps1 -Deploy    # deploy src + tests first (-Dev layout)
#   powershell -File tools\verify-scripts.ps1 -Deploy -Release   # deploy the release layout first
#
# How it works: witcher3.exe -verifyscriptsandexit compiles the scripts and exits by
# itself (exit code 3 - the same on failure, so the code is NOT the verdict). On a
# compile error the game instead stops on a "Script Compilation Errors" window; this
# script waits for it, reads the error list from the window and closes the game.
# Do not add -silentscripts: it hides that window and the failure becomes invisible.
#
# The game must start with its own folder as working directory (done here) - from any
# other folder it quits after a few seconds without compiling anything.
#
# Exit codes: 0 = compiled, 1 = compile errors (listed), 2 = could not verify
# (game missing, timeout, unexpected exit).
#
# Other mods in the mods folder are compiled too: an error in one of them fails the
# gate as well - the file name in the message tells which mod.

param(
    [string]$GameDir = "",
    [int]$TimeoutSec = 180,
    [switch]$Deploy,
    [switch]$Release
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
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) {
    Write-Error "The game is already running - close it first (two instances share one script cache)"
}
if (-not (Get-Process -Name steam -ErrorAction SilentlyContinue)) {
    Write-Warning "Steam is not running - the game may refuse to start"
}

if ($Deploy) {
    $deployArgs = @{ GameDir = $GameDir }
    if (-not $Release) { $deployArgs.Dev = $true }
    & "$PSScriptRoot\deploy-mod.ps1" @deployArgs 6>$null
    Write-Host ("Deployed " + $(if ($Release) { "release" } else { "dev" }) + " layout")
}

# The dialog is a plain Win32 window whose error list is an Edit control (id 3002).
# UI Automation reports it as a Pane with the text as its Name.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

function Get-ErrorDialogText($proc) {
    try {
        $win = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)
        $edit = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ClassNameProperty, "Edit")
        $el = $win.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $edit)
        if ($el) { return $el.Current.Name }
    } catch { }
    return $null
}

$watch = [Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $exe -ArgumentList "-verifyscriptsandexit" `
    -WorkingDirectory (Split-Path $exe) -PassThru
Write-Host "Compiling scripts (game pid $($proc.Id)) ..."

$failed = $false
$errorText = $null
while (-not $proc.HasExited) {
    $proc.Refresh()
    if ($proc.MainWindowTitle -match 'Script Compilation Errors') {
        # The list is filled when the window opens; give the controls a moment.
        Start-Sleep -Milliseconds 700
        $errorText = Get-ErrorDialogText $proc
        $failed = $true
        Stop-Process -Id $proc.Id -Force
        $proc.WaitForExit(5000) | Out-Null
        break
    }
    if ($watch.Elapsed.TotalSeconds -gt $TimeoutSec) {
        Stop-Process -Id $proc.Id -Force
        Write-Host "TIMEOUT: no result after $TimeoutSec s (game stopped)"
        exit 2
    }
    Start-Sleep -Milliseconds 500
}

$secs = [int]$watch.Elapsed.TotalSeconds
if ($failed) {
    Write-Host "FAIL: script compilation errors ($secs s)"
    if ($errorText) {
        $errorText.Trim() -split "\r?\n" | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  (the error list could not be read from the window - run tools\launch-debug.ps1 and read the dialog)"
    }
    exit 1
}

# 3 is what a clean verify run returns today; anything else is not a verdict we know.
if ($proc.ExitCode -ne 3) {
    Write-Host "UNKNOWN: the game exited with code $($proc.ExitCode) after $secs s, without a compile error window"
    Write-Host "  (a clean run returned 3; a crash or a wrong launch - e.g. Steam not running - ends differently)"
    exit 2
}
Write-Host "PASS: all scripts compile ($secs s)"
exit 0
