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
| **Sacrifice** | A compatible item of the same category (armor → armor, sword → sword). Permanently consumed; its socketed runes and glyphs return to your inventory, as when dismantling (an enchanted sacrifice loses them). |
| **New level** | Exactly the sacrifice's level. No automatic scaling, no level-down infusions. |
| **Materials** | The sacrifice yields recoverable crafting materials; they reduce the recipe requirements. |
| **Labor fee** | Crowns, depending on the craftsman's tier (journeyman → archmaster) and the size of the upgrade. |
| **Durability** | A successful infusion restores the target to 100% — part of the paid service. |
| **Eligibility** | Armorers handle armor, swordsmiths handle swords. Witcher gear requires a qualified master. |

## Status

**0.9.0 — first public release (beta).** The core system is complete and verified in game; no
game script is overridden. Changes: [CHANGELOG.md](CHANGELOG.md).

- Limitations and compatibility notes: [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md)
- What the [spec](INFUSION_SPEC.md) asks for, what is done and what is open (compatibility
  tests next to other mods; optional bonus merging): [docs/SPEC_COVERAGE.md](docs/SPEC_COVERAGE.md)
- Why it's a beta and what 1.0 needs: [docs/ROADMAP_IDEAS.md](docs/ROADMAP_IDEAS.md#3-road-to-10)

## Repository structure

```
INFUSION_SPEC.md                 Authoritative design specification (milestones, rules, acceptance criteria)
VERSION, CHANGELOG.md            Release version and notes
docs/
  INSTALL.md                     Player install guide (ships as the mod's README.md)
  CONFIGURATION.md               Player settings reference (InfusionConfig.ws)
  KNOWN_ISSUES.md                Player-facing limitations
  TECHNICAL_DISCOVERY.md         Verified engine/toolchain facts (annotations, item levels, APIs)
  UI.md                          Infusion tab: design, Flash constraints, manual checklist
  BALANCING.md                   Cost model and offline tuning
  SPEC_COVERAGE.md               Spec section by section: done, verified, open
  CRAFTSMAN_MAP.md               Craftsman tiers extracted from game data
  ROADMAP_IDEAS.md               Open ideas
  SCRIPT_TEST_BENCH_RESEARCH.md  What can be checked without playing (compile gate) and what cannot
src/modInfusion/                 RELEASE mod source — ships to players
tests/modInfusion/               DEV-ONLY overlay (console commands, scenario tests) — never shipped
tools/                           Deploy/launch scripts, cost table, string sources (tools/README.md)
```

### Why `src` and `tests` are separate

`src/` contains only what a player needs. `tests/` contains the debug console commands and the
automated in-game self test — they are deployed **on top of** the release files during
development (`deploy-mod.ps1 -Dev`) but are **never part of a release**. A released build is
exactly `src/`, nothing else.

## Development workflow

Prerequisites: The Witcher 3 — Remastered (5.01), REDkit, the console enabled
(`DBGConsoleOn=true` in `bin/config/base/general.ini`). The tools find the game through the
Steam libraries (override: `W3_GAME_DIR`); see [tools/README.md](tools/README.md).

```powershell
powershell -File tools\deploy-mod.ps1 -Dev    # release files + test commands
powershell -File tools\deploy-mod.ps1         # release build (what players get)
powershell -File tools\launch-debug.ps1       # start the game with script logging
powershell -File tools\package-release.ps1    # player zip in dist\ (+ -Deploy: install it)
```

In game, open the console (`~`):

```
infuseScenarioAll        - run all service scenarios, PASS/FAIL summary
infuseOpenMenu(true)     - open an armorer's menu here (Infusion tab)
infuseSpawnTestPair(true) - spawn a target + sacrifice to try the UI
infuseHelp               - list all commands
```

Compile errors and `[Infusion]` log lines go to `Documents\The Witcher 3\scriptslog.txt`.
Test commands: [tests/modInfusion/README.md](tests/modInfusion/README.md). Manual UI checks:
[docs/UI.md](docs/UI.md).

## Compatibility notes

- **Remastered 5.01+** (the 2026 "Remastered" edition, game version 5.0). The mod ships only
  **new** script files — it never overrides base game scripts (menu integration via REDkit
  script annotations, `@wrapMethod`/`@addMethod`), so it needs no script merger and coexists
  with other mods that do. One exception to chaining: it replaces the global
  `HaxGetPanelStateName` (`@replaceMethod`); another mod replacing the same function would
  fail to compile.
- Scripts are UTF-8 with BOM (the Remastered encoding requirement).
- Known safe alongside texture/asset mods. Gameplay overhauls that change damage/armor math
  may shift level formulas; the infusion transaction verifies level equality before committing
  and aborts safely on mismatch.
- Item exclusions: quest items, hidden/technical items, Aerondight (own progression mechanic),
  merchant-range autogen items.
- Removing the mod is safe: infused items keep their levels (they use the game's own level
  abilities); nothing else is stored in the save.

## License and assets

MIT License, see [LICENSE](LICENSE). Exception: the body of `HaxGetPanelStateName` in
`InfusionMenuTab.ws` is the game's own function with one added case; that code belongs to
CD PROJEKT RED and isn't covered by the license.

This repository contains original code and documentation only — no game assets, no third-party
mod files. The Witcher 3 and REDkit are property of CD PROJEKT RED.
