# Witcher Gear Infusion

**A sacrifice-based equipment progression mod for The Witcher 3: Wild Hunt — Remastered.**

Keep the gear you love. Feed it the gear you don't.

Infusion lets you sacrifice an equipment item to raise the level of another one. The sacrifice
is permanently consumed — but it does not vanish into nothing: its crafting materials are
recovered and reduce the cost of the work, and you pay the craftsman's labor fee on top.
The upgraded item keeps its identity: appearance, sockets, installed runes and glyphs,
enchantments, and set bonuses all stay exactly where they were. Only its level, its stats,
and (as part of the service) its durability change.

The mechanic is performed by the game's **existing blacksmiths and armorers**. No new NPCs,
no new quests, no new menus to learn.

## The idea

Loot in The Witcher 3 has a problem: at some point, every sword and every chest piece you find
is either strictly worse than what you carry, or it is *the* item you want — and replacing your
chosen gear feels like losing a companion. Equipment-leveling mods solve this by scaling
everything to your level, which removes the value of loot entirely.

Infusion takes the middle path:

- **Progression stays in the loot.** The sacrifice item's level is what your target gets —
  a higher-level find is worth real progression.
- **Choices stay meaningful.** Is this sword worth consuming? Do I infuse now or wait for a
  better sacrifice? Which craftsman is even allowed to touch Witcher gear? Is the service fee
  worth it — or do I save the crowns for crafting?
- **Nothing is free.** The sacrifice is consumed, materials are needed (reduced by what the
  sacrifice yields), and the craftsman charges for labor.

The target item is recalculated from its *own* definition at the new level. An Ursine chest
piece stays Ursine — it gets stronger, but it never inherits the sacrificed item's bonuses.

## Gameplay summary

| | |
| --- | --- |
| **Target** | The item you keep and upgrade. Never consumed. Keeps identity, sockets, enchantments, set bonuses. |
| **Sacrifice** | A compatible item of the same category (armor → armor, sword → sword). Permanently consumed. |
| **New level** | Exactly the sacrifice's level. No automatic scaling, no level-down infusions. |
| **Materials** | The sacrifice yields recoverable crafting materials; they reduce the recipe requirements. |
| **Labor fee** | Crowns, depending on the craftsman's tier (journeyman → archmaster) and the size of the upgrade. |
| **Durability** | A successful infusion restores the target to 100% — part of the paid service. |
| **Eligibility** | Armorers handle armor, swordsmiths handle swords. Witcher gear requires a qualified master. |

## Status

Work in progress — see [INFUSION_SPEC.md](INFUSION_SPEC.md) for the full design specification
and development milestones.

- ✅ **Milestone 1** — technical discovery (game internals verified: level derivation, autogen
  ability system, salvage data, craftsman tiers)
- ✅ **Milestone 2** — core infusion transaction, verified in game (level transfer, sacrifice
  consumption, save/reload persistence)
- ✅ **Milestone 3** — material recipes and salvage recovery, verified in game (discount math,
  deduction, missing-materials rejection with nothing consumed, side-effect-free test harness)
- ✅ **Milestone 4** — craftsman eligibility, verified in game (specialization rejection,
  tier acceptance at journeyman and master, real service delivery at spawned craftsman NPCs;
  see docs/CRAFTSMAN_MAP.md)
- ✅ **Milestone 5** — pricing and configuration: economy-anchored fee (fraction of the
  sacrifice's market value — auto-balances with official economy updates), tier/tier-target/gap
  multipliers per spec §6.2, curated defaults without a settings menu (Remastered settings UI
  is broken for mod groups; decision documented), dev-only console overrides for live tuning
- ✅ **Milestone 6** — production UI, verified in game: two-step infusion (pick target, then
  sacrifice) inside the blacksmith/armorer Repair tab, confirmation popup with the full cost
  breakdown, craftsman gating, vanilla repair unaffected, save/reload persistence. Release polish
  (log volume, localized error messages) tracked in docs/M6_UI_STATE.md
- 🔜 **Milestone 7** — release packaging
- 🔜 **Milestone 8** — optional bonus-merging extension (separate module)

## Repository structure

```
INFUSION_SPEC.md                 Authoritative design specification (milestones, rules, acceptance criteria)
docs/
  TECHNICAL_DISCOVERY.md         Verified game internals (APIs, level system, salvage data)
  SCRIPT_TEST_BENCH_RESEARCH.md  Why there is no out-of-game test bench (research notes)
  MOD_CLEANUP_2026-10-10.md      Remastered 5.01 environment setup record
  PATCH_NOTES_2026-10-10_scripts.md  5.01 script-compiler keyword fixes for installed mods
src/
  modInfusion/                   RELEASE mod source — ships to players
    content/scripts/game/infusion/
      InfusionTypes.ws           Error codes, preview data, category table
      InfusionService.ws         Level computation, validation, transaction
tests/
  modInfusion/                   DEV-ONLY overlay — never shipped
    content/scripts/game/infusion/
      InfusionDebug.ws           Debug console commands and in-game self test
tools/
  deploy-mod.ps1                 Deploys the mod (default: release, -Dev: with tests)
  launch-debug.bat               Launches the game with script logging
  console-toggle.ahk             Fallback console hotkey for keyboard layouts
backups/                         Local game-folder backups (not committed)
```

### Why `src` and `tests` are separate

`src/` contains only what a player needs. `tests/` contains the debug console commands and the
automated in-game self test — they are deployed **on top of** the release files during
development (`deploy-mod.ps1 -Dev`) but are **never part of a release**. A released build is
exactly `src/`, nothing else.

## Development workflow

Prerequisites: The Witcher 3 — Remastered (5.01), REDkit installed, console enabled
(`DBGConsoleOn=true` in `bin/config/base/general.ini`), and `-debugscripts` in the Steam launch
options (writes `scriptslog.txt` on compile errors).

```powershell
# deploy dev build (release files + debug commands) into the game
powershell -File tools\deploy-mod.ps1 -Dev

# release build (what players get — no test code)
powershell -File tools\deploy-mod.ps1
```

Then launch, load a save, open the console (`~`):

```
infuseHelp            - list debug commands
infusePreview         - validate the best target/sacrifice pair in inventory
infuseRun             - execute the infusion
infuseSelfTest        - full self test; verdict via sounds and HUD notifications
infuseCleanTestItems  - remove spawned test items (keeps one)
```

Compile errors appear in `Documents\The Witcher 3\scriptslog.txt` (requires the
`-debugscripts` launch flag). Runtime verification is in-game by design — see
[docs/SCRIPT_TEST_BENCH_RESEARCH.md](docs/SCRIPT_TEST_BENCH_RESEARCH.md) for why there is no
out-of-game test runner.

## Compatibility notes

- **Remastered 5.01+** (the 2026 "Remastered" edition, game version 5.0). The mod ships only
  **new** script files — it never overrides base game scripts, so it needs no script merger
  and coexists with other mods that do.
- Scripts are UTF-8 with BOM (the Remastered encoding requirement).
- Known safe alongside texture/asset mods. Gameplay overhauls that change damage/armor math
  may shift level formulas; the infusion transaction verifies level equality before committing
  and aborts safely on mismatch.
- Item exclusions: quest items, Aerondight (own progression mechanic), merchant-range
  autogen items.

## License and assets

This repository contains original code and documentation only — no game assets, no third-party
mod files. The Witcher 3 and REDkit are property of CD PROJEKT RED.
