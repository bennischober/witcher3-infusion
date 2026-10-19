# Balancing model (2026-10-18)

Replaces the Milestone 3/5 placeholders (fixed per-slot recipe, fee anchored to the sacrifice's
value), which made every armor cost "Lederstücke 2 + Zwirn 4" and large upgrades ~100 crowns
regardless of tier (user feedback 2026-10-18).

## Formulas

| Part | Formula | Source in code |
| --- | --- | --- |
| Gap factor | `min(gap / 10, 3)` — 10 levels = 1 "set", capped at 3 | `InfusionConfig.GetLevelGapMultiplier` (`LEVELS_PER_FULL_SET`, `MAX_SETS`) |
| Recipe | the **target's own dismantle data** (`recycling_parts`, what the item is made of) × gap factor, rounded up per material, at least 1 each | `InfusionService.GetRecipeForTarget` |
| Material filter | only `crafting_ingredient` / `alchemy_ingredient` parts count (dismantle data also lists junk like faction insignia, hafts, whole items, food) | `IsRecipeMaterial` |
| Fallback recipe | old per-category table, only for targets without usable dismantle data | `GetRecipeForCategory` |
| Salvage | the sacrifice's dismantle data × `SALVAGE_YIELD_MULT` (1.0) | `GetSalvageYield`, `ApplySalvageMultiplier` |
| Covered / you pay | per recipe material: covered = `min(salvage, recipe)`, pay = `recipe − salvage`; salvage of non-recipe materials is discarded (spec §5.4) | `ComputeRemainingMaterials` (`preview.covered`, `preview.materials`) |
| Fee | `max(10, round(targetValue × 0.25 × gapFactor × craftsman × tier))`, at most 10,000,000 (overflow guard); `targetValue` = `GetItemPriceModified(target)` (native, level/NG+-scaled) | `GetLaborFee`, `GetTargetValue` |
| Craftsman | journeyman 1.0, master 1.5, grandmaster 2.0, arch master 2.5 | `MULT_*` |
| Tier | 1.0 for all qualities (the target's value already scales with its tier) | `TIER_MULT_*` |

Config values are clamped when read (`InfusionConfig.ws`): multipliers and the fee fraction to
0–100, `LEVELS_PER_FULL_SET` to 1–1000, `MAX_SETS` to 0.1–100, the yield multiplier to 0–10,
tier requirements to 1–4, the minimum fee to 0–10,000,000. `REQUIRE_MATERIALS = false` makes
infusion cost the labor fee only.

**Spec deviation (deliberate):** spec §6.1/§7.1 say not to charge the same level gap twice.
Here both the fee (labor) and the materials (physical work per level) scale with the gap,
because a 1-level touch-up must not cost the same materials as a 30-level jump. Recorded in
TECHNICAL_DISCOVERY §9.

## What it does (examples from `tools/infusion-cost-table.py`)

| Target ← sacrifice, gap 9 | Recipe | Covered by sacrifice | You pay | Fee |
| --- | --- | --- | --- | --- |
| Light armor 01 ← Light armor 06 (journeyman, value 288) | Linen 2, Leather squares 4, Leather straps 2, Thread 4, Cotton 6 | Linen 2, Leather straps 2, Thread 3 | Leather squares 4, Thread 1, **Cotton 6** | 65 |
| NGP Bear Armor 4 ← Light armor 06 (grandmaster) | Hardened leather 2, Chitin scale 3, Infused dust 3, Dwimeryte enriched ore 2, Glowing ore 4 | — | all of it | 2,046 (base price; in-game value higher) |
| NGP Bear Armor 4 ← NGP Wolf Armor 4 (grandmaster) | same | everything | — | 2,046 (base price) |
| Novigraadan sword 1 ← Novigraadan sword 3 (journeyman) | Leather squares 1, Iron ingot 3 | — | Leather squares 1, Iron ingot 3 | 10 |

Consequences: Witcher gear needs its rare materials unless the sacrifice is comparable gear;
matching sacrifices make infusions material-free; ordinary items can need materials the player
doesn't carry (e.g. cotton). Previously "infusable" test pairs may now be refused for missing
materials — the info panel's red `have/need` shows why.

## Tuning without launching the game

```
python tools/infusion-cost-table.py --target "Bear Armor 4" --sacrifice "Light armor 06" --gap 9 --craftsman grandmaster
python tools/infusion-cost-table.py --target "Light armor 01" --sacrifice "Light armor 06" --gap 9 --value 288 --have "Thread=112,Leather squares=5"
python tools/infusion-cost-table.py --table armor --gap 10
python tools/infusion-cost-table.py --find "Bear Armor"
```

Recipes are exact (REDkit item XML, base game + DLC, hidden/quest items filtered like the mod).
The fee needs the target's **in-game value** (`--value`, the crown value in the item tooltip):
`GetItemPriceModified` is native and scales with level and NG+, so XML base prices are only a
lower bound. The grid log prints the real value per item (`target value N`) for calibration.
**Keep the script's constants in sync with `InfusionConfig.ws`.**

## Open balancing questions (need playtesting)

- Is 25% of the target's value per 10 levels right? NG+ Witcher gear values are unknown until
  read from the grid log.
- Should the recipe use fewer materials for ordinary gear (e.g. drop the smallest components)?
- 3-set cap for very large NG+ jumps — enough?
- Price of rare materials vs. crowns: is buying them at merchants a viable path?
