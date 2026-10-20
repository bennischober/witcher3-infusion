# modInfusion — dev/test overlay (never shipped)

These files are deployed **on top of** `src/modInfusion` by `tools/deploy-mod.ps1 -Dev` and are
excluded from release builds.

| File | Contents |
| --- | --- |
| `InfusionDebug.ws` | Console commands (thin wrappers) |
| `InfusionScenarios.ws` | Scenario tests (below) |
| `InfusionBalanceReport.ws` | High-level cost report (`infuseBalanceReport`, below) |
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
| `infusePriceProbe` | Price experiment (spec §6.3): for the equipped steel sword and chest armor, log the fee anchor (player-side market value) next to the nearest craftsman's price for a copy of the same item, vanilla's shop modifier and his repair price per point. Compare runs at craftsmen in different regions. |
| `infusePriceProbeAll` | Same probe without travelling: spawns 10 real community craftsman templates (Velen, Novigrad, Skellige — their merchant data comes with the template), probes each, despawns them after 2 min. The zone factor still follows where you stand. If a line says "could not add copies", run it again (re-probes the spawned ones). |
| `infuseBalanceReport` | Cost check for long NG+ runs (spec §6.4), preview only — nothing is charged. Raises real items to L60/100/150 and logs one `balance:` line per item, level and gap (5 and 20 levels, plus a big jump L60 → L150; the sacrifice is a copy of the target raised by the gap): the fee at a journeyman, master and grandmaster craftsman, the fee base, both items' sell prices, the materials to buy and what the salvage covers. Items: ordinary armor (`Light armor 01`), ordinary steel sword (`Novigraadan sword 1`), relic (`Abarad`, master and up), Witcher armor (`Bear Armor 1`, grandmaster only). Lower levels can't be shown — spawned gear comes in at about your level. Spawns test craftsmen (grandmasters from the Toussaint templates, so Blood and Wine is needed); a fresh spawn isn't ready at once — if the notification says craftsmen were just spawned, run it again. |
| `infuseSetConfig(key, n)` | Dev config override via facts: `fee` (multiplier on the craftsman's full-repair price ×1000, 0 = default 1.0), `minfee`, `softcap` (soft fee ceiling in crowns, 0 = default 2000, 10000000 = off), `salvage` (1 = off), `materials` (1 = no material requirements), `debug` (1 = per-item grid log) |
| `infuseDumpConfig` | Log the effective configuration |
| `infuseTestStrings` | Check that the mod's `.w3strings` load |

## Scenario tests (one command each)

`content/scripts/game/infusion/InfusionScenarios.ws`. Every scenario spawns its own items (and a
test craftsman where needed), runs the real service code (`Preview` / `Execute`, the calls the
menu makes), checks the result itself and then puts the inventory back: spawned items removed,
crowns and materials restored to the exact amounts from before.

| Command | Effect |
| --- | --- |
| `infuseScenarioAll` | Runs all scenarios below. Summary on screen and in the log: `SCENARIOS: 33/33 PASS` (or `\| FAIL: … \| SKIP: …`); one `scenario <name>: PASS/FAIL/SKIP (detail)` line per scenario. |
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
| 28 | `fee_formula` | the fee matches the configured formula: value fallback for an ordinary and a Witcher target (incl. the target-tier multiplier), and the craftsman's full-repair price at a journeyman armorer — the higher one of target and sacrifice, softened above the soft ceiling (§6.3, §15.4) |
| 29 | `fee_by_gap` | a 20-level gap costs more than a 5-level gap (§7.1, §15.4) |
| 30 | `fee_config` | doubling the fee multiplier doubles the fee, with the soft ceiling lifted (§15.4) |
| 31 | `fee_soft_cap` | a fee above the soft ceiling becomes √(fee × ceiling), one below it is unchanged (§6.3, §15.4) |
| 32 | `materials_by_tier` | a master armorer's recipe is the journeyman's × the master's material efficiency, rounded to the nearest, and smaller in total (§7.2) |
| 33 | `rollback_mismatch` | the level check after applying fails (forced by the dev fact `InfCfg_TestLevelMismatch`: `InfusionFaultInjection.ws` wraps the service's `ApplyLevelSteps` with `@wrapMethod` and overshoots by real step abilities; release builds don't contain it): `IFE_LevelMismatch`, and the pre-boosted target keeps its level, primary stat, step-ability count and damaged durability; crowns, materials and sacrifice untouched (§13.2–13.3) |

Every successful infusion scenario also checks that the popup's projected primary stat equals
the result (§9.2).

Scenarios 1–9, 24–31 and 33 run without a craftsman (eligibility bypass, mechanics only); 10–11,
the three craftsman rejections, `block_tier` and `materials_by_tier` spawn journeyman/master test craftsmen (despawn after 5 min). SKIP means a
precondition did not hold (game data differs, a freshly spawned craftsman was not ready yet —
run again). Still manual: everything visual in the menu (docs/UI.md checklists).

## Console output caveat (Remastered 5.01)

`LogChannel` text does **not** render in the debug console; it is written to `scriptslog.txt`
(`-debugscripts` launch flag, `tools/launch-debug.ps1`) as `[Infusion]` lines. On screen, results
appear as HUD notifications (queued; visible after closing the console) plus a sound (crafting =
pass, denied = fail). Why there is no out-of-game test bench:
[docs/SCRIPT_TEST_BENCH_RESEARCH.md](../../docs/SCRIPT_TEST_BENCH_RESEARCH.md).
