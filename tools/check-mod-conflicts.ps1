# Requires PowerShell 5+ (Windows PowerShell or pwsh).
# Compatibility scanner: checks every other mod in the game's mods folder
# against the script hooks Infusion uses (read from src\, never hard-coded),
# so a new hook is covered automatically. Read-only.
#
#   CONFLICT  won't compile together or one mod silently replaces the other:
#             same @replaceMethod target (e.g. HaxGetPanelStateName), same
#             @addMethod/@addField name on a class, same global name, or the
#             same script file path as one of ours
#   CHECK     works, but play-test the blacksmith menu with both installed:
#             the mod replaces a method we wrap, or overrides a whole vanilla
#             script that defines a class we hook or extend
#   info      harmless overlap: another @wrapMethod on a method we wrap
#             (wrappers chain)
#
#   -GameDir  game folder (default: Steam library lookup, tools\w3paths.ps1)
#   -ModsDir  scan another mods folder instead of <GameDir>\mods
#
# Exit code 1 when a CONFLICT was found.

param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GameDir = "",
    [string]$ModsDir = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "w3paths.ps1")

$modName = "modInfusion"
if (-not $GameDir) { $GameDir = Get-W3GameDir }
if (-not $GameDir -or -not (Test-Path $GameDir)) {
    Write-Error "Game folder not found - pass -GameDir or set W3_GAME_DIR"
}
if (-not $ModsDir) { $ModsDir = Join-Path $GameDir "mods" }
$vanillaRoot = Join-Path $GameDir "content\content0\scripts"
if (-not (Test-Path $vanillaRoot)) {
    Write-Error "Vanilla scripts not found: $vanillaRoot"
}

# Script text without comments (a commented-out annotation is no hook).
function Read-Script([string]$Path) {
    $text = [System.IO.File]::ReadAllText($Path)
    $text = [regex]::Replace($text, '/\*.*?\*/', '', 'Singleline')
    return [regex]::Replace($text, '//[^\r\n]*', '')
}

# Annotations: kind, class ('' = global), member name.
$annotationPattern = '@(wrapMethod|addMethod|addField|replaceMethod)\s*(?:\(\s*(\w+)\s*\))?\s*(?:(?:public|private|protected)\s+)?(?:function|var|event)\s+(\w+)'
# Top-level definitions (column 0; members are indented).
$definitionPattern = '(?m)^(?:import\s+)?(?:abstract\s+)?(?:statemachine\s+)?(class|struct|enum|function)\s+(\w+)(?:\s+extends\s+(\w+))?'

function Get-Annotations([string]$Text) {
    foreach ($m in [regex]::Matches($Text, $annotationPattern)) {
        [pscustomobject]@{ Kind = $m.Groups[1].Value; Class = $m.Groups[2].Value; Member = $m.Groups[3].Value }
    }
}

function Get-Definitions([string]$Text) {
    foreach ($m in [regex]::Matches($Text, $definitionPattern)) {
        [pscustomobject]@{ Kind = $m.Groups[1].Value; Name = $m.Groups[2].Value; Extends = $m.Groups[3].Value }
    }
}

function Get-ScriptFiles([string]$ScriptsRoot) {
    if (-not (Test-Path $ScriptsRoot)) { return @() }
    return Get-ChildItem -Recurse -File -Filter *.ws $ScriptsRoot
}

function Get-RelativePath([string]$Root, [string]$Path) {
    return $Path.Substring($Root.TrimEnd('\').Length + 1).ToLowerInvariant()
}

# ---- our hooks ----
$ourRoot = Join-Path $RepoRoot "src\$modName\content\scripts"
$ourAnnotations = @()
$ourDefinitions = @()
$ourPaths = @{}
foreach ($f in Get-ScriptFiles $ourRoot) {
    $text = Read-Script $f.FullName
    $ourAnnotations += @(Get-Annotations $text)
    $ourDefinitions += @(Get-Definitions $text)
    $ourPaths[(Get-RelativePath $ourRoot $f.FullName)] = $true
}

# Vanilla classes we hook or extend, and the global functions we replace.
$hookedClasses = @{}
foreach ($a in $ourAnnotations) { if ($a.Class) { $hookedClasses[$a.Class] = $true } }
foreach ($d in $ourDefinitions) { if ($d.Extends -and $d.Extends -ne 'IScriptable') { $hookedClasses[$d.Extends] = $true } }
$replacedGlobals = @{}
foreach ($a in $ourAnnotations) { if ($a.Kind -eq 'replaceMethod' -and -not $a.Class) { $replacedGlobals[$a.Member] = $true } }
$ourNames = @{}
foreach ($d in $ourDefinitions) { $ourNames[$d.Name] = $true }

# Vanilla files that define them (a mod overriding one of these replaces it).
$vanillaHookFiles = @{}
foreach ($f in Get-ScriptFiles $vanillaRoot) {
    $text = Read-Script $f.FullName
    foreach ($d in Get-Definitions $text) {
        if (($d.Kind -eq 'class' -and $hookedClasses.ContainsKey($d.Name)) -or
            ($d.Kind -eq 'function' -and $replacedGlobals.ContainsKey($d.Name))) {
            $rel = Get-RelativePath $vanillaRoot $f.FullName
            if (-not $vanillaHookFiles.ContainsKey($rel)) { $vanillaHookFiles[$rel] = @() }
            $vanillaHookFiles[$rel] += $d.Name
        }
    }
}

Write-Host "Infusion hooks: $($ourAnnotations.Count) annotations on $(@($hookedClasses.Keys | Sort-Object) -join ', ');"
Write-Host "  replaces $(@($replacedGlobals.Keys) -join ', '); vanilla files: $(@($vanillaHookFiles.Keys | Sort-Object) -join ', ')"
Write-Host "Scanning $ModsDir"
Write-Host ""

# ---- other mods ----
$conflicts = 0
$mods = Get-ChildItem -Directory $ModsDir | Where-Object { $_.Name -ne $modName } | Sort-Object Name
foreach ($mod in $mods) {
    $findings = @()
    $scriptsRoot = Join-Path $mod.FullName "content\scripts"
    $files = @(Get-ScriptFiles $scriptsRoot)

    foreach ($f in $files) {
        $rel = Get-RelativePath $scriptsRoot $f.FullName
        $text = Read-Script $f.FullName

        if ($ourPaths.ContainsKey($rel)) {
            $findings += "CONFLICT  same script path as Infusion: $rel"
        }
        if ($vanillaHookFiles.ContainsKey($rel)) {
            $findings += "CHECK     overrides vanilla $rel (defines $($vanillaHookFiles[$rel] -join ', '))"
        }
        foreach ($d in Get-Definitions $text) {
            if ($ourNames.ContainsKey($d.Name)) {
                $findings += "CONFLICT  defines $($d.Kind) $($d.Name), also defined by Infusion ($rel)"
            }
        }
        foreach ($a in Get-Annotations $text) {
            foreach ($o in $ourAnnotations) {
                if ($a.Class -ne $o.Class -or $a.Member -ne $o.Member) { continue }
                $target = $a.Member
                if ($a.Class) { $target = "$($a.Class).$($a.Member)" }
                if ($a.Kind -eq 'replaceMethod' -and $o.Kind -eq 'replaceMethod') {
                    $findings += "CONFLICT  @replaceMethod $target - both mods replace it (duplicate found)"
                } elseif ($a.Kind -eq $o.Kind -and ($a.Kind -eq 'addMethod' -or $a.Kind -eq 'addField')) {
                    $findings += "CONFLICT  @$($a.Kind) $target - same name added by both mods"
                } elseif ($a.Kind -eq 'replaceMethod' -and $o.Kind -eq 'wrapMethod') {
                    $findings += "CHECK     @replaceMethod $target - Infusion wraps this method"
                } elseif ($a.Kind -eq 'wrapMethod' -and $o.Kind -eq 'wrapMethod') {
                    $findings += "info      @wrapMethod $target - both wrap it (wrappers chain)"
                }
            }
        }
    }

    $summary = "$($files.Count) scripts"
    if ($files.Count -eq 0) { $summary = "no scripts (assets only)" }
    $findings = @($findings | Select-Object -Unique)
    $modConflicts = @($findings | Where-Object { $_ -like 'CONFLICT*' }).Count
    $conflicts += $modConflicts
    if ($findings.Count -eq 0) {
        Write-Host ("{0,-28} {1,-26} OK" -f $mod.Name, $summary) -ForegroundColor Green
    } else {
        $color = "Yellow"
        if ($modConflicts -gt 0) { $color = "Red" }
        Write-Host ("{0,-28} {1}" -f $mod.Name, $summary) -ForegroundColor $color
        foreach ($line in $findings) { Write-Host "    $line" }
    }
}

Write-Host ""
if ($conflicts -gt 0) {
    Write-Host "$conflicts conflict(s) - these mods can't be installed together with Infusion as they are." -ForegroundColor Red
    exit 1
}
Write-Host "No conflicts with $($mods.Count) mod(s)."
