# Witcher Gear Infusion — configuration

The defaults are balanced for a normal playthrough; you don't need to change anything.

There is **no in-game settings menu** (the Remastered settings menu doesn't work for mod
settings). Settings are constants in one script file, for players who want to tweak them:

```
The Witcher 3\mods\modInfusion\content\scripts\game\infusion\InfusionConfig.ws
```

## How to change a setting

1. Close the game.
2. Open the file in a text editor. It must stay **UTF-8 with BOM** when you save — in Notepad,
   check that the status bar says "UTF-8 with BOM" before saving.
3. Change the value in the setting's `default` line, e.g.

   ```
   default FEE_REPAIR_MULT = 1.0f;     ->     default FEE_REPAIR_MULT = 0.5f;
   ```

   Keep the `f` after decimal numbers and the `;` at the end.
4. Start the game (it recompiles the scripts).

**Updating the mod replaces this file** — note your changes and apply them again afterwards.
Out-of-range values are clamped to the range in the tables below, so a typo can't produce
negative prices or free materials; a syntax error (missing `;`) shows a script compilation error
at startup — fix the line or reinstall.

## Feature switches

| Setting | Default | Effect |
| --- | --- | --- |
| `ENABLE_INFUSION` | `true` | Master switch. `false`: the Infusion tab stays empty. |
| `ENABLE_STEEL_SWORD` | `true` | Steel swords (and axes, which the game files as steel swords). |
| `ENABLE_SILVER_SWORD` | `true` | Silver swords. |
| `ENABLE_ARMOR` | `true` | Chest armor, trousers, boots, gloves. |
| `REQUIRE_MATERIALS` | `true` | `false`: infusion costs only the fee — no materials, no salvage. |
| `ENABLE_SALVAGE` | `true` | `false`: the sacrifice's materials don't reduce the recipe; you pay the full recipe. |
| `RESTORE_DURABILITY` | `true` | `false`: infusion no longer repairs the target (the confirmation text still mentions the repair). |

## Craftsman requirements

The minimum craftsman rank per item tier: `1` journeyman, `2` master, `3` grandmaster,
`4` arch master (range 1–4).

| Setting | Default | Items |
| --- | --- | --- |
| `TIER_REQ_ORDINARY` | `1` | Common, master-crafted and magic items |
| `TIER_REQ_RELIC` | `2` | Relics |
| `TIER_REQ_WITCHER` | `3` | Witcher gear |

## Labor fee

```
fee = full repair price × FEE_REPAIR_MULT × level-gap factor × craftsman multiplier × item tier multiplier
```

The **full repair price** is what this craftsman charges to repair an item from 0 to 100 %
durability — the game's own repair price, so it follows the item's value, NG+ and the region
(Novigrad and Skellige are more expensive than Velen). The fee uses the target's or the
sacrifice's, whichever is higher, so a big jump costs what the new level is worth. The **level-gap factor** is
`gap ÷ LEVELS_PER_FULL_SET`, at most `MAX_SETS` — a 10-level jump costs one full repair at a
journeyman.

| Setting | Default | Range | Effect |
| --- | --- | --- | --- |
| `FEE_REPAIR_MULT` | `1.0` | 0–100 | Overall fee level. `0.5` halves every fee, `0` leaves only the minimum fee. |
| `MIN_LABOR_FEE` | `10` | 0–10,000,000 | Minimum fee in crowns. |
| `MULT_JOURNEYMAN` | `1.0` | 0–100 | Fee multiplier of a journeyman. |
| `MULT_MASTER` | `1.5` | 0–100 | … master. |
| `MULT_GRAND_MASTER` | `2.0` | 0–100 | … grandmaster. |
| `MULT_ARCH_MASTER` | `2.5` | 0–100 | … arch master. |
| `TIER_MULT_1` … `TIER_MULT_5` | `1.0`, `1.0`, `1.0`, `1.5`, `2.0` | 0–100 | Fee multiplier by the target's tier: 1 common, 2 master-crafted, 3 magic, 4 relic, 5 Witcher gear. The repair price barely grows with rarity, so relics and Witcher gear get their own. |
| `LEVELS_PER_FULL_SET` | `10` | 1–1000 | Levels per "full" fee and material set (smaller = larger jumps cost more). |
| `MAX_SETS` | `3` | 0.1–100 | Cap of the level-gap factor: huge NG+ jumps cost at most this many sets. |
| `FALLBACK_VALUE_FRACTION` | `0.25` | 0–100 | Only used if the craftsman has no repair price: fee anchor = this fraction of the item's value. |

## Materials

The recipe is the target's own crafting components (from the game's dismantling data) × the
level-gap factor; the sacrifice's dismantling yield covers part of it.

| Setting | Default | Range | Effect |
| --- | --- | --- | --- |
| `SALVAGE_YIELD_MULT` | `1.0` | 0–10 | Multiplier on what the sacrifice yields (rounded down). Recovered materials only reduce the recipe — the rest is discarded, never added to your inventory. |

## Not meant to be changed

| Setting | Purpose |
| --- | --- |
| `MAX_LABOR_FEE` | Overflow guard (10,000,000 crowns), not a balance setting. |
| `DEBUG_LOGGING` | Developer diagnostics; writes one log line per item to `scriptslog.txt`. |
| `FACT_*` | Developer test switches. |
