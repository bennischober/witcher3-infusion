# Unattended scenario run: starts the game, which loads the newest save, runs every scenario
# and exits by itself - no keystrokes, no mouse, nothing is simulated.
#
#   powershell -File tools\run-scenarios.ps1            # run what is installed (dev layout needed)
#   powershell -File tools\run-scenarios.ps1 -Deploy    # deploy src + tests first
#
# How it works: tests\modInfusionAutoRun is installed next to the mod for this one run (and
# removed afterwards, so a normal dev launch never auto-loads a save). Its script loads the
# newest save from the main menu (what "Continue" does), waits a few seconds after the game
# started, runs infuseScenarioAll and quits (RequestExit). This script waits for the game to
# exit (or for the "SCENARIOS:" line, then closes the game itself) and reads the "[Infusion]"
# lines of scriptslog.txt.
#
# The newest save is the test bed: the scenarios spawn their items and put the inventory back,
# but use a dedicated save anyway. The game window appears (there is no headless mode) and
# should be left alone.
#
# Exit codes: 0 = all scenarios passed, 1 = a scenario failed or was skipped, 2 = no result
# (game missing, no "SCENARIOS:" line in time, game ended without one).

param(
    [string]$GameDir = "",
    [int]$TimeoutSec = 300,
    [string]$ShotDir = "",      # diagnostics: a screenshot of the game window every 15 s
    [switch]$Deploy
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\w3paths.ps1"

if (-not $GameDir) { $GameDir = Get-W3GameDir }
if (-not $GameDir) {
    Write-Error "The Witcher 3 not found in the Steam libraries - pass -GameDir or set W3_GAME_DIR"
}
$exe = Join-Path $GameDir "bin\x64_dx12\witcher3.exe"
if (-not (Test-Path $exe)) { Write-Error "Game executable not found: $exe" }
if (Get-Process -Name witcher3 -ErrorAction SilentlyContinue) {
    Write-Error "The game is already running - close it first"
}
if (-not (Get-Process -Name steam -ErrorAction SilentlyContinue)) {
    Write-Warning "Steam is not running - the game may refuse to start"
}

if ($Deploy) {
    & "$PSScriptRoot\deploy-mod.ps1" -GameDir $GameDir -Dev 6>$null
    Write-Host "Deployed dev layout"
}
if (-not (Test-Path (Join-Path $GameDir "mods\modInfusion\content\scripts\game\infusion\InfusionScenarios.ws"))) {
    Write-Error "The dev layout is not installed (no InfusionScenarios.ws) - use -Deploy"
}

$docs = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "The Witcher 3"
$log = Join-Path $docs "scriptslog.txt"

# The DX12 build reads dx12user.settings and rewrites it on exit (dropping unknown keys), so
# make sure the script log is flushed on every launch. Backup once next to the file.
$settings = Join-Path $docs "dx12user.settings"
if (Test-Path $settings) {
    $text = [IO.File]::ReadAllText($settings)
    if ($text -notmatch 'DebugScriptsForceFlush') {
        if (-not (Test-Path "$settings.pre-infusion")) { Copy-Item $settings "$settings.pre-infusion" }
        $nl = if ($text -match "`r`n") { "`r`n" } else { "`n" }
        $text = $text -replace '\[Scripts\]\r?\n', ("[Scripts]" + $nl + "DebugScriptsForceFlush=true" + $nl + "LogDebugScripts=true" + $nl)
        [IO.File]::WriteAllText($settings, $text, (New-Object Text.UTF8Encoding($false)))
        Write-Host "Enabled DebugScriptsForceFlush in dx12user.settings (backup: dx12user.settings.pre-infusion)"
    }
}

if ($ShotDir) {
    Add-Type -AssemblyName System.Drawing
    Add-Type -TypeDefinition @'
using System; using System.Drawing; using System.Runtime.InteropServices;
public static class W3Shot {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    public static void Save(IntPtr h, string path) {
        SetProcessDPIAware();
        RECT r; if (!GetWindowRect(h, out r) || r.R <= r.L) return;
        using (var b = new Bitmap(r.R - r.L, r.B - r.T)) {
            using (var g = Graphics.FromImage(b)) g.CopyFromScreen(r.L, r.T, 0, 0, b.Size);
            b.Save(path, System.Drawing.Imaging.ImageFormat.Png);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing
    New-Item -ItemType Directory -Force $ShotDir | Out-Null
}

$autoSrc = Join-Path (Split-Path -Parent $PSScriptRoot) "tests\modInfusionAutoRun"
$autoDst = Join-Path $GameDir "mods\modInfusionAutoRun"
$proc = $null
$line = $null
try {
    if (Test-Path $autoDst) { Remove-Item -Recurse -Force $autoDst }
    Copy-Item -Recurse $autoSrc $autoDst

    $startedAt = Get-Date
    $proc = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru `
        -ArgumentList "-debugscripts -windowed -width 1280 -height 720 -noRayTracing"
    Write-Host "Game started (pid $($proc.Id)); it loads the newest save and runs the scenarios ..."

    $watch = [Diagnostics.Stopwatch]::StartNew()
    $shots = 0
    $resultSeen = $null
    $logGrew = $false
    while (-not $proc.HasExited -and $watch.Elapsed.TotalSeconds -lt $TimeoutSec) {
        Start-Sleep -Seconds 2
        # The result line is in the log before the game has quit; if the quit does not work,
        # close the window ourselves a few seconds after the line appeared.
        if (-not $logGrew -and (Test-Path $log) -and (Get-Item $log).Length -gt 101) {
            $logGrew = $true
            Write-Host ("scriptslog.txt has content after {0} s" -f [int]$watch.Elapsed.TotalSeconds)
        }
        if ((Test-Path $log) -and (Select-String -Path $log -Pattern 'SCENARIOS:' -Quiet)) {
            if (-not $resultSeen) { $resultSeen = Get-Date }
            elseif (((Get-Date) - $resultSeen).TotalSeconds -gt 10) {
                $proc.CloseMainWindow() | Out-Null
                if (-not $proc.WaitForExit(10000)) { Stop-Process -Id $proc.Id -Force }
            }
        }
        if ($ShotDir -and $watch.Elapsed.TotalSeconds -ge $shots * 15) {
            $proc.Refresh()
            [W3Shot]::Save($proc.MainWindowHandle, (Join-Path $ShotDir ("t{0:000}.png" -f [int]$watch.Elapsed.TotalSeconds)))
            $shots++
        }
    }
    if (-not $proc.HasExited) {
        Write-Host "TIMEOUT: the game did not exit within $TimeoutSec s (stopped)"
        Stop-Process -Id $proc.Id -Force
    } else {
        Write-Host ("Game exited after {0} s with code {1}" -f [int]$watch.Elapsed.TotalSeconds, $proc.ExitCode)
    }
} finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    if (Test-Path $autoDst) { Remove-Item -Recurse -Force $autoDst }
}

$lines = @()
if (Test-Path $log) {
    $lines = @(Get-Content $log | Where-Object { $_ -match '\[Infusion\]' })
}
$lines | ForEach-Object { Write-Host $_ }
$line = $lines | Where-Object { $_ -match 'SCENARIOS:' } | Select-Object -Last 1
if (-not $line) {
    $size = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
    Write-Host "NO RESULT: no 'SCENARIOS:' line in scriptslog.txt ($size bytes)"
    exit 2
}
if ($line -match 'SCENARIOS:\s*(\d+)/(\d+)\s+PASS\s*$') {
    Write-Host "PASS: $($Matches[1])/$($Matches[2]) scenarios"
    exit 0
}
Write-Host "FAIL: $line"
exit 1
