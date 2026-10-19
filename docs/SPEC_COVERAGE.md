# Spec coverage

INFUSION_SPEC.md compared section by section with the implementation. Updated 2026-10-19.

Legend: ✅ implemented and verified in game · ⚠️ partial, or a deliberate deviation
(TECHNICAL_DISCOVERY.md §9) · ❌ missing · — optional, not planned yet

"Scenario" = verified by the one-command scenario suite (`infuseScenarioAll`, 22/22 PASS;
tests/modInfusion/README.md).

## Summary

The **core system is complete and verified**: two-item model, level transfer, salvage and
materials, labor fee, craftsman gating, durability, transaction safety, persistence, uninstall
safety and the production UI — with no vanilla script override. Open: **rejection reasons in the
grid** (§9.3), **NG+ balance playtesting** (§6.4), **compatibility testing with other mods**
(§14), and the **M7 release work**. Bonus merging (§11, M8) has not started.

## Section by section

| Spec | Requirement | Status | Notes |
| --- | --- | --- | --- |
| §1.3 | Non-goals | ✅ | No auto-scaling, no new NPC/quest, no random failure, no level cap, no new resource. |
| §2 | Technical discovery | ✅ | TECHNICAL_DISCOVERY.md. |
| §3.1 | Two distinct items, target kept, sacrifice consumed | ✅ | Scenario. |
| §3.2 | New level = sacrifice level; equal/lower rejected | ✅ | Scenario (`reject_equal`, `reject_lower`). No `AllowEqualLevelInfusion` switch. |
| §3.3 | Compatibility | ✅ ⚠️ | Same item **category** (chest↔chest, boots↔boots, steel↔steel, silver↔silver) — stricter than the spec. Scenario (`reject_category`, `reject_steel_silver`). |
| §3.4 | Full durability restore, stated in the UI | ✅ | Scenario (damaged targets); popup note. |
| §4.1–4.3 | Identity kept, stats recalculated from the target's own definition | ✅ | Only step abilities are added. Scenario: rune, glyph and runeword kept, all previous abilities kept. |
| §4.4 | Validation matrix | ✅ | Scenario: ordinary steel/silver sword, armor, boots, Witcher sword + rune, Witcher armor + glyph, relic + runeword, damaged targets, NG+ above the cap. Unique special-progression items are excluded (Aerondight). |
| §5.1–5.4 | Salvage from native dismantle data, excess discarded | ✅ | `GetItemRecyclingParts`; recipe from the target's own components (BALANCING.md). |
| §5.5 | Exploit protection | ✅ | Scenario (`reject_same`, `reject_materials`, `reject_crowns`: nothing consumed); `Execute` re-validates. |
| §6.1/6.2 | Labor fee separate from materials; craftsman multipliers | ✅ | Scenario (`fee_by_tier`: master > journeyman). |
| §6.3 | Fee formula | ⚠️ | Base = 25 % of the target's market value instead of a fixed base fee. |
| §6.4 | Costs meaningful in long NG+ runs | ❌ | Needs a playtest with real high-level gear (BALANCING.md open questions). |
| §7.1 | Level gap drives cost | ⚠️ | The gap scales fee **and** materials (deliberate). |
| §7.2 | Craftsman efficiency discount | — | Optional; only if playtesting asks for it. |
| §7.3 | No random failure, safe abort | ✅ | |
| §8.1 | Existing NPCs and menu only | ✅ | Infusion tab inside the blacksmith/armorer menu. |
| §8.2 | Tier + specialization from game data | ✅ | Scenario (`reject_craftsman_type`, `reject_tier_witcher`, `reject_tier_relic`, `master_relic_ok`). Relic → master, Witcher gear → grandmaster (config). |
| §8.3 | No level cap, overflow-safe | ✅ | Scenario (`ngplus_uncapped`); gap factor capped at 3 sets. |
| §9.1 | Select target and sacrifice | ✅ | Two-step flow (UI.md). |
| §9.2 | Preview contents | ⚠️ | ✅ names, icons, levels, fee, covered/remaining materials, consumption + repair note. ❌ projected stats (allowed to omit). ❌ eligibility: ineligible items are hidden, not explained. |
| §9.3 | Clear rejection messages | ⚠️ | Messages are localized (en/de), but most never reach the player: the grid **hides** items that can't be infused here. Biggest UX gap — see "Next". |
| §9.5 | Confirmation with fresh data | ✅ | Fresh `Preview` before the popup; `Execute` re-validates. |
| §10 | Configuration | ⚠️ | Script constants in `InfusionConfig.ws` (no settings menu — broken on 5.01); dev overrides via `infuseSetConfig`. Missing switches: `RequireCraftingMaterials`, `AllowEqualLevelInfusion`, `AllowSpecialItems`. Salvage toggle verified (scenario `salvage_off`). ❌ player-facing configuration doc. |
| §11 | Bonus merging | — | M8; the core has no extension point yet (§11.3). |
| §12 | Modular architecture | ✅ | Config / service / grid / menu hooks separated; the service is driven directly by the tests. |
| §13 | Transaction safety | ✅ | Level verified after applying, rollback on mismatch; charge → materials → sacrifice. |
| §13.4 | Save/load integrity | ✅ | Scenario (`persist` + `infuseScenarioPersistCheck`) and manual rounds. |
| §14 | Compatibility | ⚠️ | No vanilla script override (annotations, UI.md). Remaining surface: the global `HaxGetPanelStateName` replacement. Not tested alongside scaling, crafting or UI overhaul mods. |
| §14.2 | Exclusion list with explanation | ⚠️ | Quest, hidden/body, Aerondight, merchant-range items. Excluded items are hidden without explanation. |
| §15.1–15.5 | Core, rejection, salvage, pricing, persistence tests | ✅ | Scenario suite. |
| §15.6 | Regression | ✅ | Repair, repair all, dismantle, sockets; crafting/alchemy/inventory menus; removing the mod from a save (infused items keep their levels). |
| §16 M7 | Release preparation | ❌ | Install guide, configuration doc, known issues, release-build check, packaging. |

## Next

1. **Rejection reasons in the grid** (§9.2/§9.3/§14.2): list supported-but-not-infusable items
   in step 1 as disabled entries with the reason ("Erfordert einen Großmeister-Plattner",
   "Kein höherstufiges Opfer im Inventar"). The disabled warning line is one text per page, so a
   per-item reason needs another carrier — e.g. the item tooltip's `WarningMessage`
   (ROADMAP_IDEAS.md).
2. **M7 release work** (see §16 above).
3. **NG+ balance playtest** (§6.4).
