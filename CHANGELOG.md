# Changelog

Versions follow [semantic versioning](https://semver.org). 0.x: feature-complete, not yet
playtested in long New Game+ runs or alongside other mods.

## Unreleased

- The step-2 header names the gamepad's button (A, or X on PlayStation; B / O with "swap
  accept/cancel") instead of always E, and follows a switch between pad and keyboard.

## 0.9.0 — first public release (2026-10-20)

- Infusion tab in every blacksmith and armorer menu, right after Repair: pick a target, then a
  higher-level sacrifice of the same type; the target takes the sacrifice's level.
- The target keeps its identity, sockets, runes, glyphs, enchantment and set bonuses, and is
  fully repaired.
- The sacrifice's dismantling yield reduces the material recipe; its tooltip shows how much of
  the recipe it covers ("Covered by sacrifice: 7/18").
- The craftsman charges a labor fee based on his own repair price (regional) of the target or
  the sacrifice, whichever is higher, his rank and the size of the jump. Relics cost 1.5× and
  Witcher gear 2× the fee of ordinary gear; above 2,000 crowns the fee grows with the square
  root (`FEE_SOFT_CAP`, 0 = off).
- Higher-ranked craftsmen need fewer materials: a master 85 %, a grandmaster 70 %, an arch
  master 60 % of the recipe (`MAT_EFF_*`).
- Craftsman gating: blacksmiths infuse swords, armorers armor; relics need a master, Witcher
  gear a grandmaster.
- Items that can't be infused here are listed greyed out with the reason in the tooltip.
- Confirmation popup with level and stat change, covered and additional materials, and price.
- `ENABLE_INFUSION = false` switches the mod off (no Infusion tab).
- No level cap (New Game+ safe); no game script overridden; safe to uninstall.
- Texts in all 18 game languages (only English and German reviewed so far).
