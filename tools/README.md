# Tools

| File | Purpose |
| --- | --- |
| `deploy-mod.ps1` | Copies the mod into the game's `mods\modInfusion` folder. Default: release files (`src/`) only. `-Dev`: plus the test overlay (`tests/`). `-Uninstall`: removes the folder. |
| `launch-debug.ps1` | Starts the game with `-debugscripts`, so `Documents\The Witcher 3\scriptslog.txt` gets compile errors and the `[Infusion]` log channel. |
| `w3paths.ps1` | Shared helper: finds The Witcher 3 and REDkit in the Steam libraries. Override with the `W3_GAME_DIR` / `W3_REDKIT` environment variables or `-GameDir`. |
| `infusion-cost-table.py` | Offline cost calculator (recipe, salvage, fee) from the REDkit item XML — see [docs/BALANCING.md](../docs/BALANCING.md). REDkit is auto-detected; `--redkit` or `W3_REDKIT` override it. Its constants mirror `InfusionConfig.ws` and must be kept in sync. |
| `build-strings.ps1` | Builds all 18 `.w3strings` files from their sources; a language without a source gets the English texts. Checks every source against the English ids/keys. Needs `w3stringsr` (below) and Python 3 (Arabic). |
| `shape-arabic.py` | Shapes the Arabic source into the presentation forms the game expects (called by `build-strings.ps1`; see TECHNICAL_DISCOVERY.md). |
| `package-release.ps1` | Player release: `dist\modInfusion-<VERSION>.zip` (`mods\modInfusion\` with the `src/` content and the player docs). Release check: no `tests/` file, no `exec function`, UTF-8 BOM on every script, a strings file per language. `-Deploy` also installs the package into the game (release test); `-SkipStrings` skips the string build. |
| `strings-sources/infusion_strings_<lang>.csv` | Source of the mod's UI strings, one per game language (id space `2112345NNN`). Arabic is kept unshaped (readable). |
| `console-toggle.ahk` | AutoHotkey v1 fallback: F12 sends the console key for keyboard layouts without a reachable tilde. |

```powershell
powershell -File tools\deploy-mod.ps1 -Dev
powershell -File tools\launch-debug.ps1
powershell -File tools\package-release.ps1 -Deploy
python tools\infusion-cost-table.py --target "Light armor 01" --sacrifice "Light armor 06" --gap 9
```

## Strings

`.w3strings` files are built with **w3stringsr** (community Remastered encoder; not committed —
place `w3stringsr.exe` in `tools/w3stringsr/`, which git ignores):

```powershell
powershell -File tools\build-strings.ps1
```

The output is byte-reproducible from the CSV sources. Add new keys with the next free id to every
CSV and rebuild — the build fails if a source's ids/keys differ from English. A language without a
source gets the English file with the language header swapped — without a file for the game's
language the UI texts would be empty. Arabic: write it normally without diacritics; the build
shapes it.
