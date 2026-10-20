# Spec coverage

INFUSION_SPEC.md compared section by section with the implementation. Updated 2026-10-19.

Legend: ✅ implemented and verified in game · ⚠️ partial, or a deliberate deviation
(TECHNICAL_DISCOVERY.md §9) · ❌ missing · — optional, not planned yet

"Scenario" = verified by the one-command scenario suite (`infuseScenarioAll`, 30 scenarios;
tests/modInfusion/README.md). Re-audited against every spec section on 2026-10-19.

## Summary

The **core system is complete and verified**: two-item model, level transfer, salvage and
materials, labor fee, craftsman gating, durability, transaction safety, persistence, uninstall
safety and the production UI with rejection reasons — with no vanilla script override.
Open, in spec order, see [Open items](#open-items-top-to-bottom). Bonus merging (§11, M8) has not
started.

## Section by section

| Spec | Requirement | Status | Notes |
| --- | --- | --- | --- |
| §1.3 | Non-goals | ✅ | No auto-scaling, no new NPC/quest, no random failure, no level cap, no new resource. |
| §2 | Technical discovery | ✅ | TECHNICAL_DISCOVERY.md. |
| §3.1 | Two distinct items, target kept, sacrifice consumed | ✅ | Scenario. |
| §3.2 | New level = sacrifice level; equal/lower rejected | ✅ | Scenario (`reject_equal`, `reject_lower`). Deliberately no `AllowEqualLevelInfusion` switch: an equal-level infusion is zero-benefit, which §3.2 forbids ("never consume an item for an invalid or zero-benefit infusion"); no use case found. |
| §3.3 | Compatibility | ✅ ⚠️ | Same item **category** (chest↔chest, boots↔boots, steel↔steel, silver↔silver) — stricter than the spec. Scenario (`reject_category`, `reject_steel_silver`). |
| §3.4 | Full durability restore, stated in the UI | ✅ | Scenario (damaged targets); popup note. |
| §4.1–4.3 | Identity kept, stats recalculated from the target's own definition | ✅ | Only step abilities are added. Scenario: rune, glyph and runeword kept, all previous abilities kept. |
| §4.4 | Validation matrix | ✅ | Scenario: ordinary steel/silver sword, armor, boots, Witcher sword + rune, Witcher armor + glyph, relic + runeword, damaged targets, NG+ above the cap. Unique special-progression items are excluded (Aerondight). |
| §5.1–5.4 | Salvage from native dismantle data, excess discarded | ✅ | `GetItemRecyclingParts`; recipe from the target's own components (BALANCING.md). |
| §5.5 | Exploit protection | ✅ | Scenario (`reject_same`, `reject_materials`, `reject_crowns`: nothing consumed); `Execute` re-validates. |
| §6.1/6.2 | Labor fee separate from materials; craftsman multipliers | ✅ | Scenario (`fee_by_tier`: master > journeyman). |
| §6.3 | Fee formula | ⚠️ | Base = 25 % of the target's market value instead of a fixed base fee (follows level, rarity, NG+ and patch prices). Regional/shop price factors are not applied — experiment `infusePriceProbe` pending: does the same item cost differently at craftsmen in different regions? |
| §6.4 | Costs meaningful in long NG+ runs | ❌ | Needs a playtest with real high-level gear (BALANCING.md open questions). |
| §7.1 | Level gap drives cost | ⚠️ | The gap scales fee **and** materials (deliberate). |
| §7.2 | Craftsman efficiency discount | — | Optional; only if playtesting asks for it. |
| §7.3 | No random failure, safe abort | ✅ | |
| §8.1 | Existing NPCs and menu only | ✅ | Infusion tab inside the blacksmith/armorer menu. |
| §8.2 | Tier + specialization from game data | ✅ | Scenario (`reject_craftsman_type`, `reject_tier_witcher`, `reject_tier_relic`, `master_relic_ok`). Relic → master, Witcher gear → grandmaster (config). |
| §8.3 | No level cap, overflow-safe | ✅ | Scenario (`ngplus_uncapped`); gap factor capped at 3 sets. |
| §9.1 | Select target and sacrifice | ✅ | Two-step flow (UI.md). |
| §9.2 | Preview contents | ⚠️ | ✅ names, icons, levels, fee, covered/remaining materials, consumption + repair note, eligibility (blocked targets with reason). projected primary stat in the popup (current stat + steps × the step ability's fixed value; every infusion scenario checks it against the result). In-game popup layout check pending. |
| §9.3 | Clear rejection messages | ✅ | Blocked targets are listed disabled with the reason in the tooltip (tier with the game's rank name, no/only-lower/only-equipped sacrifices); popup-time rejections as localized notifications (en/de). Scenario (`block_tier`, `block_no_higher`, `block_ok`); UI checked in game (one-line reasons, no Space hint). |
| §9.5 | Confirmation with fresh data | ✅ | Fresh `Preview` before the popup; `Execute` re-validates. |
| §10 | Configuration | ⚠️ | Script constants in `InfusionConfig.ws` (no settings menu — broken on 5.01); dev overrides via `infuseSetConfig`. Salvage toggle (scenario `salvage_off`), `RequireCraftingMaterials` (`REQUIRE_MATERIALS`, scenario `materials_off`). Values are clamped when read (BALANCING.md), fees capped at 10,000,000. Not added: `AllowEqualLevelInfusion` (§3.2), `AllowSpecialItems` (nothing special is tested), `EnableBonusMerging` (no extension). ❌ player-facing configuration doc (M7). |
| §11 | Bonus merging | — | M8; the core has no extension point yet (§11.3). |
| §12 | Modular architecture | ✅ | Config / service / grid / menu hooks separated; the service is driven directly by the tests. |
| §13 | Transaction safety | ✅ | Level verified after applying, rollback on mismatch; charge → materials → sacrifice. |
| §13.4 | Save/load integrity | ✅ | Scenario (`persist` + `infuseScenarioPersistCheck`) and manual rounds. |
| §14 | Compatibility | ⚠️ | No vanilla script override (annotations, UI.md). Remaining surface: the global `HaxGetPanelStateName` replacement. Not tested alongside scaling, crafting or UI overhaul mods. |
| §14.2 | Exclusion list with explanation | ✅ | Quest, hidden/body, Aerondight, merchant-range items. Excluded gear of the craftsman's specialization is listed disabled with "Kann nicht sicher infundiert werden" (scenario `block_excluded`); hidden/body items stay hidden. |
| §15.1–15.3, 15.5 | Core, rejection, salvage, persistence tests | ✅ | Scenario suite. |
| §15.4 | Pricing tests | ✅ | Master > journeyman (`fee_by_tier`), formula incl. target-tier multiplier (`fee_formula`), larger gap → higher fee (`fee_by_gap`), config change → price change (`fee_config`), no negative/overflow at NG+ levels (`ngplus_uncapped`), salvage doesn't touch the fee. "Journeymen > lower tier" doesn't apply (no lower tier in the game). |
| §15.6 | Regression | ✅ | Repair, repair all, dismantle, sockets; crafting/alchemy/inventory menus; removing the mod from a save (infused items keep their levels). `EnableInfusion = false` (empty tab, clicks refused) untested in game. |
| §16 M7 | Release preparation | ❌ | Install guide, configuration doc, known issues, release-build check, packaging. |

## Open items, top to bottom

| # | Spec | Item | Who | Size |
| --- | --- | --- | --- | --- |
| 1 | §9.2 | ~~Projected primary stat in the popup~~ — done, popup layout check pending | code | S |
| 2 | §10 | ~~Validate config values~~ — done | code | S |
| 3 | §10 | ~~`RequireCraftingMaterials` switch~~ — done | code | S |
| 4 | §14.2 | ~~List excluded gear disabled with a reason~~ — done, UI check pending | code | S |
| 5 | §15.4 | ~~Pricing scenarios~~ — done | tests | S |
| 6 | §6.4 | NG+ balance playtest with real high-level gear | playtest | M |
| 7 | §14 | Test next to popular mods (scaling, crafting, UI overhauls) | playtest | M |
| 8 | §16 M7 | Install guide, configuration doc, known issues, release build without the test scripts, packaging | docs | M |
| — | §10 | `AllowSpecialItems`: nothing special is allowed today; add a switch only for a category that gets tested | — | — |
| — | §11 / M8 | Bonus merging (optional, separate module) | — | L |
