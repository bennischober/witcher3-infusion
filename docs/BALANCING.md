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
| Fee | `max(10, round(fullRepair × 1.0 × gapFactor × craftsman × tier))`, at most 10,000,000 (overflow guard). `fullRepair` = this craftsman's vanilla repair price from 0 to full durability (`GetItemPriceRepair` per point × max durability) of the **target or the sacrifice, whichever is higher** — the sacrifice's price stands in for the level the target is raised to (see the balance report below). Follows level, rarity, NG+ and his **regional economy** (Novigrad +17 %, Skellige +8 % over Velen). Per point is whole crowns, rounded up — cheap items cost 1 crown per point. Without a craftsman (tests): the higher item value × 0.25 | `GetLaborFee`, `GetFeeBase`, `GetFeeAnchor` |
| Craftsman | journeyman 1.0, master 1.5, grandmaster 2.0, arch master 2.5 | `MULT_*` |
| Tier | by the target's quality: relic (4) 1.5, Witcher gear (5) 2.0, everything else 1.0 — the repair price barely follows rarity at high levels (balance report below) | `TIER_MULT_*` |

Config values are clamped when read (`InfusionConfig.ws`): multipliers (incl. `FEE_REPAIR_MULT`) to
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
| NGP Bear Armor 4 ← Light armor 06 (grandmaster) | Hardened leather 2, Chitin scale 3, Infused dust 3, Dwimeryte enriched ore 2, Glowing ore 4 | — | all of it | 4,091 (base price, Witcher ×2; in-game value higher) |
| NGP Bear Armor 4 ← NGP Wolf Armor 4 (grandmaster) | same | everything | — | 4,091 (base price) |
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
The fee needs the **in-game values** (`--value` and `--sacrifice-value`, the crown values in the
item tooltips):
`GetItemPriceModified` is native and scales with level and NG+, so XML base prices are only a
lower bound. The grid log prints the real value per item (`target value N`) for calibration.
**Keep the script's constants in sync with `InfusionConfig.ws`.**

## Balance report (spec §6.4, 2026-10-20)

`infuseBalanceReport` (dev console, tests/modInfusion/README.md) previews infusions of real items
at high levels for every craftsman tier, so long NG+ runs can be judged without playing them.
First run in game on 2026-10-20 (player level 61), **with the formula as it was then** (fee base =
the target's repair price, tier multipliers all 1.0). Fees in crowns, journeyman / master /
grandmaster (journeyman Velen, master Novigrad, grandmaster Toussaint):

| Item | L60 +5 | L60 +20 | L100 +5 | L100 +20 | L150 +5 | L150 +20 |
| --- | --- | --- | --- | --- | --- | --- |
| Ordinary armor (`Light armor 01`) | 50 / 75 / 200 | 200 / 300 / 800 | 100 / 150 / 200 | 400 / 600 / 1,200 | 150 / 300 / 400 | 600 / 1,200 / 1,600 |
| Ordinary sword (`Novigraadan sword 1`) | 150 / 225 / 400 | 600 / 900 / 1,600 | 350 / 600 / 900 | 1,400 / 2,400 / 3,600 | 700 / 1,200 / 1,800 | 2,800 / 4,800 / 7,600 |
| Relic (`Abarad`) | – / 375 / 500 | – / 1,500 / 2,000 | – / 675 / 1,000 | – / 2,700 / 4,000 | – / 1,350 / 2,000 | – / 5,400 / 8,000 |
| Witcher armor (`Bear Armor 1`, L78 minimum) | – / – / 300 | – / – / 1,200 | – / – / 400 | – / – / 1,600 | – / – / 600 | – / – / 2,400 |

Findings:

- **Holds up:** a 5-level step costs about 12–30 % of the item's sell price at every level; a
  higher rank always costs more (Toussaint is ~35 % above Velen on top of the rank multiplier);
  the fee stays at about a quarter of the target's sell price per 10 levels from L60 to L150, so
  it keeps pace with NG+ loot income. Materials: a 5-level step is fully covered by a same-type
  sacrifice, a 20-level step needs one more set; at high levels they're cheap next to the fee.
- **Big jumps were cheap:** priced on the target's own repair price and with the gap factor capped
  at 3 sets, an L60 sword taken to L150 cost ~900 at a journeyman (300 × 3) — less than a
  20-level step at L150 (2,800). Spec §6.4: large upgrades should require more investment.
- **Witcher gear was the cheapest:** the repair price barely follows rarity at high levels (L150:
  Witcher armor sells for ~1.4× ordinary armor, the relic for ~1.1× an ordinary sword), so Bear
  Armor at L150 +20 cost 2,400 at a grandmaster — less than an ordinary sword there.
- No data below ~L55: spawned gear comes in at about the player's level, Witcher gear at its own
  minimum. Low levels are played in a normal run anyway.

Changes (approved 2026-10-20):

1. **Fee base = the higher repair price of target and sacrifice** (`GetFeeBase`). Expected: L60
   sword → L150 about 4,200 at a journeyman (L150 price 1,400 × 3) instead of ~900. Same-item
   steps cost a little more too, since the sacrifice is a few levels higher than the target.
2. **Tier multipliers**: relic 1.5, Witcher gear 2.0. Expected: Bear Armor L150 +20 at least
   4,800 at a grandmaster.
3. The report now covers L60/100/150 and a big jump L60 → L150 for every item.

The new numbers still need a second run in game.

## Open balancing questions (need playtesting)

- Should the recipe use fewer materials for ordinary gear (e.g. drop the smallest components)?
- 3-set cap for very large NG+ jumps — enough?
- Price of rare materials vs. crowns: is buying them at merchants a viable path?
