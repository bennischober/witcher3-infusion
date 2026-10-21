# Tools

| File | Purpose |
| --- | --- |
| `deploy-mod.ps1` | Copies the mod into the game's `mods\modInfusion` folder. Default: release files (`src/`) only. `-Dev`: plus the test overlay (`tests/`). `-Uninstall`: removes the folder. |
| `launch-debug.ps1` | Starts the game with `-debugscripts`, so `Documents\The Witcher 3\scriptslog.txt` gets compile errors and the `[Infusion]` log channel. |
| `verify-scripts.ps1` | Compile gate: starts the game with `-verifyscriptsandexit` (compiles all scripts, ~20 s, no save). Exit 0 = compiled, 1 = compile errors (listed, read from the game's error window), 2 = could not verify. `-Deploy` installs the dev layout first (`-Release`: release layout). Details and pitfalls: [docs/SCRIPT_TEST_BENCH_RESEARCH.md](../docs/SCRIPT_TEST_BENCH_RESEARCH.md). |
| `run-scenarios.ps1` | **Prototype**: unattended scenario run, nothing simulated. Installs `tests\modInfusionAutoRun` for the run; its script skips the start-up videos, loads the newest save, runs `infuseScenarioAll` and quits (the runner closes the game once it has read the result); the runner reads `SCENARIOS:` from `scriptslog.txt` (exit 0 = all pass, 1 = failure, 2 = no result). Needs `DebugScriptsForceFlush` in `dx12user.settings` (set by the runner, backup `dx12user.settings.pre-infusion`). The newest save is the test bed; leave the game window alone (~75 s). `-ShotDir` writes screenshots for diagnosing. See [docs/SCRIPT_TEST_BENCH_RESEARCH.md](../docs/SCRIPT_TEST_BENCH_RESEARCH.md). |
| `w3paths.ps1` | Shared helper: finds The Witcher 3 and REDkit in the Steam libraries. Override with the `W3_GAME_DIR` / `W3_REDKIT` environment variables or `-GameDir`. |
| `infusion-cost-table.py` | Offline cost calculator (recipe, salvage, fee) from the REDkit item XML — see [docs/BALANCING.md](../docs/BALANCING.md). REDkit is auto-detected; `--redkit` or `W3_REDKIT` override it. Its constants mirror `InfusionConfig.ws` and must be kept in sync. |
| `fla-inspect.py` | Read-only inspector for REDkit's UI sources (`gui_new\fla\*.fla`, XFL): `symbols` lists library symbols and linkage classes, `show` a symbol's layers, keyframes and elements with positions, `texts` every text field's box, font size and alignment, `find` searches all FLAs for an instance, symbol or class name. `--json` for scripts. REDkit is auto-detected like the cost calculator. |
| `build-strings.ps1` | Builds all 18 `.w3strings` files from their sources; a language without a source gets the English texts. Checks every source against the English ids/keys. Needs `w3stringsr` (below) and Python 3 (Arabic). |
| `shape-arabic.py` | Shapes the Arabic source into the presentation forms the game expects (called by `build-strings.ps1`; see TECHNICAL_DISCOVERY.md). |
| `package-release.ps1` | Player release: `dist\modInfusion-<VERSION>.zip` (`mods\modInfusion\` with the `src/` content and the player docs). Release check: no `tests/` file, no `exec function`, UTF-8 BOM on every script, a strings file per language. `-Deploy` also installs the package into the game (release test); `-SkipStrings` skips the string build. |
| `strings-sources/infusion_strings_<lang>.csv` | Source of the mod's UI strings, one per game language (id space `2112345NNN`). Arabic is kept unshaped (readable). |
| `check-mod-conflicts.ps1` | Compatibility scan (read-only): compares every other mod in the game's `mods` folder with Infusion's script hooks, read from `src/` (never hard-coded). CONFLICT = won't compile together or one replaces the other (same `@replaceMethod` target, same added method/field or global name, same script path); CHECK = play-test the blacksmith menu (replaces a method we wrap, or overrides a whole vanilla script defining a class we hook); info = both wrap the same method. Exit code 1 on a conflict. `-ModsDir` scans another folder. |
| `console-toggle.ahk` | AutoHotkey v1 fallback: F12 sends the console key for keyboard layouts without a reachable tilde. |

```powershell
powershell -File tools\deploy-mod.ps1 -Dev
powershell -File tools\launch-debug.ps1
powershell -File tools\verify-scripts.ps1 -Deploy
powershell -File tools\run-scenarios.ps1 -Deploy
powershell -File tools\package-release.ps1 -Deploy
powershell -File tools\check-mod-conflicts.ps1
python tools\infusion-cost-table.py --target "Light armor 01" --sacrifice "Light armor 06" --gap 9
python tools\fla-inspect.py find tfWarningMessage
python tools\fla-inspect.py show panel_blacksmith ItemDisassembleInfo
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
