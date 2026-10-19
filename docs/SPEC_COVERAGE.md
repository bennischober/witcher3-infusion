# Spec coverage audit (2026-10-19)

INFUSION_SPEC.md compared section by section with the implementation after M6. Purpose: an honest
answer to "have we worked through everything?" and the list of what M7/M8 still have to cover.

Legend: ✅ implemented and verified in game · 🟡 implemented, not yet verified in game ·
⚠️ partial or deliberate deviation (documented) · ❌ missing

## Summary

The **core loop is complete** (two-item model, level transfer, salvage, materials, labor fee,
craftsman gating, durability, transaction safety, production UI). What's left is mostly
**validation breadth** (swords, upgrades, unique items), **player-facing explanations** for
rejected items, **compatibility**, and the **M7 release work**. Nothing in the spec was
silently dropped; the deviations below are deliberate and documented.

## Section by section

| Spec | Requirement | Status | Notes |
| --- | --- | --- | --- |
| §1.3 | Non-goals (no auto-scaling, no new NPC/quest, no random failure, no level cap, no new resource) | ✅ | All respected. |
| §2 | Technical discovery | ✅ | docs/TECHNICAL_DISCOVERY.md. Leveling-mod research done in M1. |
| §3.1 | Two distinct items, target kept, sacrifice consumed | ✅ | |
| §3.2 | New level = sacrifice level; equal/lower rejected | ✅ | Equal level always rejected (no `AllowEqualLevelInfusion` switch — not needed so far). |
| §3.3 | Compatibility armor↔armor, sword↔sword | ✅ ⚠️ | Stricter than the spec: same **category** (chest↔chest, boots↔boots, steel↔steel, silver↔silver), matching the game's level formulas per slot. |
| §3.3 | Silver swords | 🟡 | Were disabled since M2; enabled 2026-10-19. |
| §3.4 | Full durability restore, stated in the UI | ✅ | Popup note "…wird vollständig repariert". |
| §4.1 | Preserve identity, sockets, upgrades, set bonuses | ✅ by design · ❌ not tested | The item is never recreated; only `autogen_fixed_*` step abilities are added. Sockets/runes/glyphs after infusion not yet checked in game. |
| §4.2/4.3 | Stats recalculated from the target's own definition | ✅ | Step abilities = one level of the target's own stat each; the game derives stats and level. |
| §4.4 | Validation matrix | ⚠️ | ✅ ordinary armor, Witcher armor, damaged items, steel sword (M2). ❌ Witcher sword, silver sword, items with sockets/upgrades, enchanted (runewords), unique/relic items. 🟡 All covered by `infuseScenarioAll` (tests/modInfusion/README.md, 2026-10-19) — first run pending. |
| §5.1–5.4 | Salvage from native dismantle data, applied directly, excess discarded | ✅ | `GetItemRecyclingParts`. Recipe from the target's own components (docs/BALANCING.md). |
| §5.5 | Exploit protection | ✅ | Same instance, double use, preview/cancel side-effect free, re-validation in `Execute`. |
| §10 / §15.3 | Disabling salvage changes the calculation | 🟡 | **Bug fixed 2026-10-19:** salvage-off made infusions material-free. |
| §6.1/6.2 | Labor fee separate from materials; craftsman multipliers | ✅ | |
| §6.3 | `BaseFee × multipliers` | ⚠️ | Deviation: base = 25 % of the **target's market value** (auto-balances with the game's economy). docs/BALANCING.md. |
| §6.4 | Costs meaningful in long NG+ runs | ❌ open | Needs playtesting with high-level/NG+ gear (BALANCING.md open questions). |
| §7.1 | Gap drives cost; materials not charged twice | ⚠️ | Deliberate deviation: gap scales fee **and** materials (TECHNICAL_DISCOVERY §12). |
| §7.2 | Craftsman efficiency discount | — | Optional in the spec; not implemented (spec says only if playtesting asks for it). |
| §7.3 | No random failure, safe abort | ✅ | |
| §8.1 | Existing NPCs and menu only | ✅ | New tab inside the existing blacksmith menu (the "smallest extension" clause). |
| §8.2 | Tier + specialization from game data | ✅ | `W3CraftsmanComponent`; swordsmith for swords, armorer for armor; relic → master, Witcher → grandmaster (config). |
| §8.3 | No level cap, overflow-safe | ✅ | Uncapped level above the player's max; gap factor capped at 3 sets. |
| §9.1 | Select target and sacrifice in the existing interface | ✅ | Two-step flow. |
| §9.2 | Preview contents | ⚠️ | ✅ names, icons (grid), levels, fee, covered/remaining materials, consumption + repair note. ❌ projected stats (spec allows omitting them, but asks to explain why). ❌ **eligibility shown**: ineligible items are hidden, not explained. |
| §9.3 | Clear rejection messages | ⚠️ 🟡 | Messages localized (en/de) 2026-10-19, but most rejections never reach the player: the grid **hides** items that can't be infused here (no "a master armorer is required"). Biggest UX gap — see "Proposals". |
| §9.5 | Confirmation summary with fresh data | ✅ | Fresh `Preview` before the popup; `Execute` re-validates. |
| §10 | Configuration | ⚠️ | Script constants in `InfusionConfig.ws` (Remastered settings menu broken for mod groups — documented). Missing switches: `RequireCraftingMaterials`, `AllowEqualLevelInfusion`, `AllowSpecialItems`. ❌ player-facing configuration docs (M7). |
| §11 | Bonus merging (optional) | — | M8. The core has no extension point yet (§11.3). |
| §12 | Modular architecture | ✅ | Config / service / grid / menu separated; the service is used by the console tests. |
| §13.1–13.3 | Validate before commit, rollback, no partial state | ✅ | Level verified after applying; abilities rolled back on mismatch; money → materials → sacrifice. |
| §13.4 | Save/load integrity | ✅ | Verified several times (armor) and by `infuseScenario(persist)` + `infuseScenarioPersistCheck` (steel sword, 2026-10-19). |
| §14 | Compatibility investigation | ❌ 🟡 | `blacksmithMenu.ws` is a **full file override** → conflicts with any mod touching it. `commonMenu.ws` moved to annotations 2026-10-19 (test pending). Scaling mods, crafting overhauls and UI mods untested. |
| §14.2 | Exclusion list with explanation | ⚠️ | List exists (quest, body, hidden, Aerondight, merchant autogen). Excluded items are hidden without explanation. |
| §15.1/15.2 | Core and rejection tests | ⚠️ | Rejections covered by the M2–M5 console harness and gating tests; sword/Witcher-sword/upgrade cases open (§4.4). |
| §15.6 | Regression | ⚠️ | ✅ repair, repair all, dismantle. ✅ crafting / alchemy / inventory menus with the annotation tab (2026-10-19). ⚠️ removing the mod from an existing save (2026-10-19): save loads without new errors, menus vanilla, items looked normal — but the infused items' levels were not compared. Expected safe: infused levels are vanilla `autogen_fixed_*` crafted abilities saved with the item; no mod class or tag is saved. |
| §16 M7 | Release preparation | ❌ | Compatibility, config docs, install instructions, known issues, packaging. |

## Proposals (not implemented)

1. **Rejection reasons in the grid (§9.2/§9.3/§14.2).** List supported-but-not-infusable items in
   step 1 as **disabled** entries (same `disableAction` mechanism as missing materials) and put
   the reason in the warning line ("Erfordert einen Großmeister-Plattner", "Kein höherstufiges
   Opfer im Inventar"). Open question: the warning line's text is per page, not per item; it
   would have to be updated from `OnGetItemData` (hover), with the known hover/selection
   mismatch. Alternative: the reason as the item tooltip's `WarningMessage`
   (docs/ROADMAP_IDEAS.md).
2. **Annotations** for `blacksmithMenu.ws` after the `commonMenu.ws` spike passes (compatibility, §14).
3. **Validation round** for the §4.4 matrix — **scenario tests built 2026-10-19**
   (`infuseScenarioAll`: 22 scenarios incl. rejections, salvage-off, fee by tier, NG+; plus a
   two-step persistence check). First run 2026-10-19: 12/22 — all 11 rejections and the master
   relic pass; every infusion executed correctly but the test's stat read returned 0 (fixed:
   item stats are in `valueBase`). `fee_by_tier` found a **real bug**: the fee tier was read as
   the smith tier, so armorers always charged the journeyman rate (fixed in `Preview`).
   Second run: **22/22 PASS** — §4.4 matrix (silver, Witcher sword + rune, Witcher armor +
   glyph, relic + runeword, boots), NG+ above the cap, salvage off, fee by tier, all rejections.
   Persistence check: the sword survived the reload but the check looked for a script-added tag,
   which the game does not save — now matched by name and level. Re-run: **PASS** (L69,
   stat 576, full durability after save/reload).
4. **Uninstall test** (§15.6): first pass done (loads, menus vanilla). Closing it fully:
   `infuseScenario(persist)` → save → remove the mod → load, note the sword's level → save →
   reinstall → load → `infuseScenarioPersistCheck` (proves the item survived a save made without
   the mod).
5. M7 documents: install, configuration (constants + console overrides), known issues.
