# Tools

| File | Purpose |
| --- | --- |
| `deploy-mod.ps1` | Copies the mod into the game's `mods\modInfusion` folder. Default: release files (`src/`) only. `-Dev`: plus the test overlay (`tests/`). `-Uninstall`: removes the folder. |
| `launch-debug.ps1` | Starts the game with `-debugscripts`, so `Documents\The Witcher 3\scriptslog.txt` gets compile errors and the `[Infusion]` log channel. |
| `w3paths.ps1` | Shared helper: finds The Witcher 3 and REDkit in the Steam libraries. Override with the `W3_GAME_DIR` / `W3_REDKIT` environment variables or `-GameDir`. |
| `infusion-cost-table.py` | Offline cost calculator (recipe, salvage, fee) from the REDkit item XML — see [docs/BALANCING.md](../docs/BALANCING.md). REDkit is auto-detected; `--redkit` or `W3_REDKIT` override it. Its constants mirror `InfusionConfig.ws` and must be kept in sync. |
| `strings-sources/infusion_strings_{en,de}.csv` | Source of the mod's UI strings (id space `2112345NNN`). |
| `console-toggle.ahk` | AutoHotkey v1 fallback: F12 sends the console key for keyboard layouts without a reachable tilde. |

```powershell
powershell -File tools\deploy-mod.ps1 -Dev
powershell -File tools\launch-debug.ps1
python tools\infusion-cost-table.py --target "Light armor 01" --sacrifice "Light armor 06" --gap 9
```

## Strings

`.w3strings` files are built with **w3stringsr** (community Remastered encoder; not committed —
place `w3stringsr.exe` in `tools/w3stringsr/`, which git ignores):

```powershell
tools\w3stringsr\w3stringsr.exe -i 12345 tools\strings-sources\infusion_strings_en.csv src\modInfusion\content\strings\en.w3strings
tools\w3stringsr\w3stringsr.exe -i 12345 tools\strings-sources\infusion_strings_de.csv src\modInfusion\content\strings\de.w3strings
```

The output is byte-reproducible from the CSV sources. Add new keys with the next free id and
rebuild both languages.
