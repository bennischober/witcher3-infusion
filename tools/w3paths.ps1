# Shared path lookup for the tools (dot-source: . "$PSScriptRoot\w3paths.ps1").
#
# Finds The Witcher 3 and REDkit in the Steam libraries
# (HKCU\Software\Valve\Steam SteamPath -> steamapps\libraryfolders.vdf).
# Overrides: the W3_GAME_DIR / W3_REDKIT environment variables, or the
# -GameDir parameter of the calling script.

function Get-SteamLibraryPaths {
    $libs = @()
    $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $libs }
    $libs += $steam
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($m in Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"') {
            $libs += $m.Matches[0].Groups[1].Value -replace '\\\\', '\'
        }
    }
    return $libs | Select-Object -Unique
}

function Find-SteamApp([string]$FolderName) {
    foreach ($lib in Get-SteamLibraryPaths) {
        $p = Join-Path $lib "steamapps\common\$FolderName"
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-W3GameDir {
    if ($env:W3_GAME_DIR) { return $env:W3_GAME_DIR }
    return Find-SteamApp 'The Witcher 3'
}

function Get-W3REDkitDir {
    if ($env:W3_REDKIT) { return $env:W3_REDKIT }
    return Find-SteamApp 'The Witcher 3 REDkit'
}
