# modInfusion — dev/test overlay (never shipped)

These files are deployed **on top of** `src/modInfusion` by `tools/deploy-mod.ps1 -Dev` and are
excluded from release builds.

| File | Contents |
| --- | --- |
| `InfusionDebug.ws` | Console commands (thin wrappers) |
| `InfusionScenarios.ws` | Scenario tests (below) |
| `InfusionTestTools.ws` | Shared helpers: service factory, test items, test craftsmen, opening the service menu, cleanup |

## Console commands

| Command | Effect |
| --- | --- |
| `infuseHelp` | List commands (HUD notification) |
| `infuseOpenMenu(armorer, master)` | Spawn a craftsman (or reuse a spawned one) and open his service menu right here (opens on the Repair tab; the Infusion tab is next to it). No args: journeyman swordsmith; `(true)`: journeyman armorer; `(true, true)`: master armorer; `(false, true)`: master swordsmith. Despawns after 10 min or via `infuseDespawnTestSmith`. |
| `infuseSpawnTestPair(armor)` | Spawn a valid pair (ordinary target + same-category sacrifice boosted +10 levels). No args: steel swords (`Novigraadan sword 1` / `3`); `(true)`: armor (`Light armor 01` / `06`). |
| `infuseCleanTestItems` | Remove spawned test items (keeps the highest-level one — typically the infused target) |
| `infuseDespawnTestSmith` | Remove spawned test craftsmen |
| `infuseCraftsmanReport` | Log type/tier of every craftsman within 40 m |
| `infuseSetConfig(key, n)` | Dev config override via facts: `fee` (fraction ×1000, 0 = default), `minfee`, `salvage` (1 = off), `materials` (1 = no material requirements), `debug` (1 = per-item grid log) |
| `infuseDumpConfig` | Log the effective configuration |
| `infuseTestStrings` | Check that the mod's `.w3strings` load |

## Scenario tests (one command each)

`content/scripts/game/infusion/InfusionScenarios.ws`. Every scenario spawns its own items (and a
test craftsman where needed), runs the real service code (`Preview` / `Execute`, the calls the
menu makes), checks the result itself and then puts the inventory back: spawned items removed,
crowns and materials restored to the exact amounts from before.

| Command | Effect |
| --- | --- |
| `infuseScenarioAll` | Runs all scenarios below. Summary on screen and in the log: `SCENARIOS: 30/30 PASS` (or `\| FAIL: … \| SKIP: …`); one `scenario <name>: PASS/FAIL/SKIP (detail)` line per scenario. |
| `infuseScenario(name)` | Runs one scenario, e.g. `infuseScenario(silver_sword)`. |
| `infuseScenarioN(n)` | Same by number (1-based, order below) — fallback if the console rejects a bare name. |
| `infuseScenarioList` | Lists the names with their numbers. |
| `infuseScenario(persist)` + `infuseScenarioPersistCheck` | Persistence (§13.4): infuses a `Novigraadan sword 1` and keeps it; save, reload, then the check finds it by name + level (script-added tags are not saved), verifies level, stat and durability, and removes it. |

Successful infusions check: new level = sacrifice level, primary stat higher, durability 100 %
(target damaged first where marked), sacrifice consumed, item identity, socketed upgrades,
enchantment and all previous abilities intact, crowns charged = fee, materials used = preview.

| # | Scenario | Checks (spec) |
| --- | --- | --- |
| 1 | `steel_sword` | ordinary steel sword, damaged target (§4.4, §3.4) |
| 2 | `silver_sword` | ordinary silver sword, damaged target |
| 3 | `armor` | ordinary chest armor, damaged target |
| 4 | `boots` | boots (separate level formula) |
| 5 | `witcher_sword_rune` | Witcher steel sword with a rune socketed — rune kept (§4.1) |
| 6 | `witcher_armor_glyph` | Witcher armor with a glyph socketed — glyph kept |
| 7 | `relic_runeword` | relic sword with a runeword — enchantment kept |
| 8 | `ngplus_uncapped` | target and sacrifice above the player's max level (§8.3) |
| 9 | `salvage_off` | salvage disabled: nothing covered, full recipe charged (§15.3) |
| 10 | `fee_by_tier` | master armorer charges more than journeyman (§6.2, §15.4) |
| 11 | `master_relic_ok` | master smith accepts a relic (§8.2) |
| 12–22 | `reject_same`, `reject_lower`, `reject_equal`, `reject_category`, `reject_steel_silver`, `reject_quest`, `reject_crowns`, `reject_materials`, `reject_craftsman_type`, `reject_tier_witcher`, `reject_tier_relic` | exact rejection code **and** nothing consumed (§15.2, §13.3) |
| 23 | `block_tier` | the grid's block reason for Witcher gear at a journeyman armorer is the tier (§9.3) |
| 24 | `block_no_higher` | a target above every other item of its category: "no higher-level item" |
| 25 | `block_ok` | a valid pair has no block reason (consistent with the infusable check) |
| 26 | `block_excluded` | a quest-tagged sword is an explained exclusion (listed disabled, §14.2); untagged it isn't |
| 27 | `materials_off` | material requirements off: labor fee only, no material consumed (§10) |
| 28 | `fee_formula` | the fee matches the configured formula for an ordinary and a Witcher target, incl. the target-tier multiplier (§6.3, §15.4) |
| 29 | `fee_by_gap` | a 20-level gap costs more than a 5-level gap (§7.1, §15.4) |
| 30 | `fee_config` | doubling the fee fraction doubles the fee (§15.4) |

Every successful infusion scenario also checks that the popup's projected primary stat equals
the result (§9.2).

Scenarios 1–9 and 24–30 run without a craftsman (eligibility bypass, mechanics only); 10–11,
the three craftsman rejections and `block_tier` spawn journeyman/master test craftsmen (despawn after 5 min). SKIP means a
precondition did not hold (game data differs, a freshly spawned craftsman was not ready yet —
run again). Still manual: everything visual in the menu (docs/UI.md checklists).

## Console output caveat (Remastered 5.01)

`LogChannel` text does **not** render in the debug console; it is written to `scriptslog.txt`
(`-debugscripts` launch flag, `tools/launch-debug.ps1`) as `[Infusion]` lines. On screen, results
appear as HUD notifications (queued; visible after closing the console) plus a sound (crafting =
pass, denied = fail). Why there is no out-of-game test bench:
[docs/SCRIPT_TEST_BENCH_RESEARCH.md](../../docs/SCRIPT_TEST_BENCH_RESEARCH.md).
