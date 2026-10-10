# Next-Gen update script-compatibility fixes (game 5.0.0.1048522, 2026-10-10)

## What broke

Today's update shipped a new script compiler that added seven new tokens
(`map`, `set`, `add`, `addfield`, `replace`, `wrap`, `enum_type` — verified by
extracting `TOKEN_*` names from `witcher3.exe` and diffing against the old
compiler's list in `scriptStudio.exe`). `map` and `set` are now reserved words;
the other five are proven safe as identifiers (used in vanilla and FCR3 sources,
no errors).

Two installed mods still used those words as identifiers and failed to compile:

| Error | File | Cause |
| --- | --- | --- |
| `unexpected TOKEN_MAP ... near 'map'` | `mod0000_MergedFiles` `inventoryComponent.ws(1623)` | `ClearTHmaps()` declares `var map : array<SItemUniqueId>;` |
| `unexpected TOKEN_SET ... near 'set'` | `modFCR3_2_Nitpicker` `temp.ws(12582)` | `addset()` declares parameter `set : EItemSetType` |

Vanilla compiles because CDPR renamed their own occurrences in the same patch
(`ClearTHmaps` now uses `itemsMap` — used as the canonical rename here).

## What was changed (game files, outside the repository)

Four files, identifier renames only — no logic changes. Byte-level backups in
`%TEMP%\opencode\scriptfix-backup\`.

1. `mods\mod0000_MergedFiles\content\scripts\game\components\inventoryComponent.ws`
   — `ClearTHmaps()`: `map` → `itemsMap` (3 lines)
2. `mods\modFCR3_2_Nitpicker\content\scripts\game\components\inventoryComponent.ws`
   — same function, same rename (3 lines)
3. `mods\modLevelingGear\content\scripts\game\components\inventoryComponent.ws`
   — same function, same rename (3 lines)
4. `mods\modFCR3_2_Nitpicker\content\scripts\game\temp.ws`
   — `addset()`: parameter `set` → `setType` (2 lines; declaration + `switch( set )`)

Console command `addset` behavior is unchanged (same enum value passed through).
`ClearTHmaps` behavior is unchanged (local variable name is not observable).

## Verification performed

- Full re-scan of all installed mod scripts: zero remaining `map`/`set`
  declarations/parameters after the fix.
- `add`/`addfield`/`replace`/`wrap`/`enum_type` confirmed safe as identifiers
  (vanilla and FCR3 use them; base game compiles).
- `src/modInfusion` scripts checked against all 100 compiler tokens: clean.

## Limitations / follow-ups

- **In-game compile check pending** — launch the game and confirm no script
  errors appear. If further errors surface, they are additional old-mod
  incompatibilities; repeat the same rename approach per error.
- The FCR3 authors and the Leveling Gear author should be notified / their
  updated versions used when available. If either mod updates, re-running the
  vanilla-vs-mod diff (or Script Merger - Remastered) will be needed again.
- If the Vortex script merger re-merges these files later, it will re-introduce
  the unpatched originals — re-apply this fix after any merger run (or run
  Script Merger first, then apply the renames to `mod0000_MergedFiles`).
