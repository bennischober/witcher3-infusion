# modInfusion — dev/test overlay (never shipped)

These files are deployed **on top of** `src/modInfusion` by `tools/deploy-mod.ps1 -Dev` and are
excluded from release builds. They exist so milestone acceptance criteria can be verified
in game without building production UI first.

- `content/scripts/game/infusion/InfusionDebug.ws` — debug console commands:

| Command | Effect |
| --- | --- |
| `infuseHelp` | List commands (HUD notification) |
| `infusePreview` | Validate the best target/sacrifice pair; sound = verdict |
| `infuseRun` | Execute the infusion of the best pair |
| `infuseSelfTest` | Spawn test swords, run all rejection checks + one real infusion; final verdict sound (crafting = pass, denied = fail) |
| `infuseCleanTestItems` | Remove spawned test items (keeps one — typically the infused target) |

## Console output caveat (Remastered 5.01)

`LogChannel` text does **not** render in the debug console, and `scriptslog.txt`
(`-debugscripts` launch flag) only captures compile errors. The test therefore reports through
game state: sounds, HUD notifications (queued; visible after closing the console), and the
inventory UI itself (sword level, damage, durability). See
[docs/SCRIPT_TEST_BENCH_RESEARCH.md](../../docs/SCRIPT_TEST_BENCH_RESEARCH.md) for the full
research on why there is no out-of-game test bench.

## Manual test protocol (Milestone 2 acceptance)

1. `infuseSelfTest` — listen for the final verdict sound; check inventory:
   target raised to sacrifice level, sacrifice consumed, durability 100%.
2. Save, reload, re-check: level persists, no item duplication, sacrifice stays gone.
3. `infuseCleanTestItems` — clean up spawned test items.
