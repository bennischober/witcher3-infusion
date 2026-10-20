# Technical reference — Witcher Gear Infusion

Verified facts about the game, the modding toolchain and the APIs the mod relies on. Target:
**The Witcher 3 — Remastered 5.01** (DX12) with REDkit. Every statement was checked against the
game's script sources, the REDkit data/ActionScript sources, the compiler binary or in game;
anything unconfirmed is marked **unverified**. UI specifics: [UI.md](UI.md). Balancing:
[BALANCING.md](BALANCING.md). Spec status: [SPEC_COVERAGE.md](SPEC_COVERAGE.md).

## 1. Environment and packaging

| Topic | Fact |
| --- | --- |
| Game | Remastered 5.01 (exe 5.0.0.1048522). Base game and DLCs merged into single bundles. |
| Script sources | Game: `content\content0\scripts` (the authority after 5.00). REDkit: `r4data\scripts` (pre-5.00 copy — re-check APIs against the game's version). |
| Mod scripts | Loose `.ws` files under `mods\modX\content\scripts\...`, compiled at every game start. **UTF-8 with BOM** (5.00 re-encoded all text files). A REDkit-cooked `precompiled.rsblob` is the console path, optional on PC. |
| Strings | `.w3strings`, built from CSV with the community encoder w3stringsr (tools/README.md). 18 languages in `content0`: `cn` is Simplified Chinese, `zh` Traditional, `br` Brazilian Portuguese, `esmx` Latin American Spanish. `w3stringsr --decode-crlf -d` decodes the game's own tables (needed for its multi-line strings) — used to reuse its terms and to check that every character of a translation already occurs in the game's table for that language (the fonts may not cover anything else). |
| Arabic | `ar.w3strings` stores Arabic in logical order but **pre-shaped into presentation forms** — the UI doesn't join letters. Conventions: non-joining letters stay base letters; yeh initial/medial = Farsi yeh (U+FBFE/FBFF); heh = heh doachashmee (U+06BE initial, U+FBAD medial, U+FBAB final); tah/zah have no initial form (base letter); lam-alef ligatures. `tools/shape-arabic.py` reproduces all 13,257 diacritic-free Arabic UI strings of the game exactly. Display of the mod's Arabic in game **unverified**. |
| UI | Menus are cooked Flash SWFs. **REDkit ships the sources:** `r4data\gameplay\gui_new\actionscript\` (873 `.as` files) and `...\fla\` (XFL zips; some have a malformed central directory — `unzip` copes, Python's `zipfile` doesn't). Editing SWFs needs Adobe Animate + cooking — out of scope. |
| Logging | `-debugscripts` writes `Documents\The Witcher 3\scriptslog.txt`: compile errors and `LogChannel` output. `LogChannel` text does not appear in the in-game console. |
| Console | `DBGConsoleOn=true` in `bin\config\base\general.ini`. |
| Settings menus | The `user_config_matrix` system still loads, but mod-menu UI is broken on 5.01 (unresolved `##option_` labels, layout collisions). Decision: curated script defaults, no settings menu (spec §10 fallback). |

**Reserved words** (compiler token table in `witcher3.exe`) — never use as identifiers: `entry`,
`enter`, `cleanup`, `def`, `defaults`, `hint`, `in`, `inlined`, `local`, `map`, `set`, `parent`,
`quest`, `reward`, `saved`, `savepoint`, `scene`, `single`, `timer`, `any`, `autobind`,
`editable`, `virtual_parent` (`map`/`set` became reserved with 5.00).

Other language traps: string literals don't process backslash escapes; a bare `return;` in an
event bound to Flash confuses the compiler (use if/else); `BoolToString` doesn't exist (`"x" +
boolValue` works); overrides must keep the ancestor's access modifier.

## 2. Script annotations (no file overrides)

Official REDkit docs ("WS Script Compilation Errors / overrides") plus the compiler's own error
messages in `witcher3.exe`, verified in game 2026-10-19:

| Rule | Detail |
| --- | --- |
| Available | `@wrapMethod(Class)`, `@replaceMethod(Class)`, `@addMethod(Class)`, `@addField(Class)`, in any new `.ws` file. **Loose mod scripts support them** — no cooking needed. |
| Syntax | **No access modifier after the annotation**: `@wrapMethod(C) private function F()` fails ("unexpected TOKEN_PRIVATE, expecting TOKEN_FUNCTION"). Write `@wrapMethod(C) function F()`; the wrapper keeps the original's access. |
| Wrappers | Must contain `wrappedMethod`; calling it only on some paths works. Chain with other mods' wrappers. Can read the class's private fields. |
| Inherited methods | Can be neither wrapped nor replaced in a subclass — target the declaring class (e.g. `@wrapMethod(CR4MenuBase) RefreshMenuState`, then check `(CR4BlacksmithMenu)this`). |
| Global functions | Replaceable (`@replaceMethod function F` — no class). No global `@wrapMethod` is documented or referenced by the compiler. A second replacement of the same function in another mod is a compile error ("duplicate found"). |
| Natives | Can't be wrapped outside mod.io (precompiled) mods — e.g. `RequestSubMenu`. |
| Events | **Can't be annotated** (the parser expects `function`). Hook the function the event calls instead. **Flash calls reach script events only**: an added function named like a Flash call (`OnInventoryItemSelected`) never runs. An annotation-only mod therefore can't receive Flash calls the vanilla menu doesn't already handle. Script code may call events directly (e.g. `OnUpdateGFxButtonsList()`). |
| Bottom key bar | Script-side: Flash's `InputFeedbackManager` sends `OnAppendGFxButton`/`OnRemoveGFxButton`, the menu keeps `CR4MenuBase.m_GFxInputBindings`, and `OnUpdateGFxButtonsList` pushes it to the common menu. A stale entry can survive Flash state changes (blacksmith repair-all, action 1002, after the Repair tab); remove it script-side with `RemoveGFxButtonById` + `OnUpdateGFxButtonsList()` (verified 2026-10-19). |

## 3. Item levels

Item levels are **not stored per instance** — they are derived from the item's stats.

- `CInventoryComponent.GetItemLevel(item)` → `theGame.params.GetItemLevel(category, attributes,
  name, out baseItemLevel)` (gameParams.ws) with per-category linear formulas on
  `attribute.valueBase`, then adjustments (Witcher gear −2, relic −1, OlgierdSabre −3, EP1 −1)
  and a cap at the player's max level (100 by default).
- The stats come from the item's abilities: base abilities from the definition plus
  **runtime-added crafted abilities**. Each `autogen_fixed_*` ability adds exactly one level of
  stats: `autogen_fixed_steel_dmg` +8 SlashingDamage, `autogen_fixed_silver_dmg` +10
  SilverDamage, `autogen_fixed_armor_armor` +5 armor, `autogen_fixed_pants_armor` (pants, boots)
  and `autogen_fixed_gloves_armor` +2. The game's NG+ item raise (`IncreaseNGPItemlevel`) uses
  the same abilities.
- **Projected stat** (spec §9.2): the value per step is read at runtime with
  `theGame.GetDefinitionsManager().GetAbilityAttributeValue(stepAbility, attr, min, max)`
  (`min.valueBase`; the abilities are fixed). Projection = current `valueBase` + N × step. The
  tooltip's primary stat (`CInventoryComponent.GetItemPrimaryStat`) reads the same `valueBase`.
  Blunt/piercing weapons in `steelsword` have another primary stat than the step raises → no
  projection shown.
- **Infusion = add N step abilities** (`AddItemCraftedAbility`), N = level gap. The item keeps
  its definition, sockets, enchantment and abilities; stats are recalculated by the game. Crafted
  abilities are saved with the item and survive removing the mod (verified 2026-10-19).
- The mod reads levels through `InfusionService.ComputeItemLevel`: `inv.GetItemLevel` below the
  cap; near/above it, the uncapped `baseItemLevel` plus the same adjustments (spec §8.3: no cap).
  No formula is duplicated, so official changes flow through.
- Witcher set pieces are not `Autogen`-tagged but derive their displayed level the same way.

**Attribute values:** item stats live in `SAbilityAttributeValue.valueBase`.
`CalculateAttributeValue` returns 0 for them (it multiplies by `valueMultiplicative`, which is 0
on items).

## 4. Salvage and materials

- `GetItemRecyclingParts(item)` returns the definition's `<recycling_parts>` (name + quantity);
  ordinary, relic and Witcher gear all carry them. The mod reads them as the sacrifice's salvage
  and as the target's recipe — no inventory churn (spec §5.1).
- Recycling parts also list non-materials (faction insignia, hafts, whole items, food); recipes
  keep only `crafting_ingredient` / `alchemy_ingredient` categories.

## 5. Craftsmen

- `W3CraftsmanComponent` (craftsmanComponent.ws): `GetCraftsmanLevel(type)`,
  `IsCraftsmanType(type)`; `ECraftsmanType` = `ECT_Smith, ECT_Armorer, ECT_Crafter,
  ECT_Enchanter`; `ECraftsmanLevel` = `ECL_Journeyman, ECL_Master, ECL_Grand_Master,
  ECL_Arch_Master` — **no "Amateur" tier**.
- Read the tier **in the specialization the item needs** (armorer for armor): an armorer has no
  smith tier.
- NPC tiers live in cooked entity templates; the offline extraction is in
  [CRAFTSMAN_MAP.md](CRAFTSMAN_MAP.md).

## 6. Inventory, money, durability, transactions

- Money: `GetMoney/AddMoney/RemoveMoney` (crowns are a stack); vanilla pays the craftsman with
  `_fixerInventory.AddMoney(price)`.
- Items: `GetAllItems`, `GetItemName/GetItemCategory/ItemHasTag`, `AddAnItem(name, qty,
  dontInformGui, dontShowPopup)`, `RemoveItem`, `GetItemQuantityByName`, `RemoveItemByName`.
- **Script-added item tags (`AddItemTag`) are not saved** — gone after a reload. Don't use them
  to find items across sessions.
- Durability: `SetItemDurabilityScript(item, GetItemMaxDurability(item))` — the call vanilla
  repair uses.
- Upgrades: `GetItemEnhancementItems`, `EnhanceItemScript` (also applies runewords),
  `AddSlot`, `EnchantItem(item, name, getEnchamtmentStatName(name))`, `GetEnchantment`.
- `StartInvUpdateTransaction` / `FinishInvUpdateTransaction` defer inventory updates during
  multi-step changes. There are no atomic inventory transactions — safety comes from the order
  validate → apply level → verify → charge → consume (spec §13.2).
- `GetItemPriceModified` is native and scales with level and NG+ (the fee anchor). The fee asks
  the **player's** inventory, so shop/region factors don't apply. Vanilla's price levers (script
  view, `inventoryComponent.ws`):
  - per-merchant `priceMult` (`SetPriceMultiplier`, set by quests, e.g. `quest_function.ws`);
  - `GetMerchantPriceModifier(shopNPC, item)`: zone × the NPC's item-type multiplier
    (`armor_price_mult`, `weapon_price_mult`, …) × import origin × `priceMult`. No script caller
    — if used, the engine calls it. Its zone `switch` has no `break`s;
  - repairs: `merchantInv.GetItemPriceRepair(invItem, perPoint, total)` on the **craftsman's**
    inventory (vanilla repair grid), i.e. repair prices can differ per craftsman.
- **Measured** (`infusePriceProbeAll`, 2026-10-20, NGP Lynx Armor 4 L61, player value 4,801; ten
  spawned community templates, run in Velen and again after `gotoNovigrad`):

  | Craftsman template | Shop price of a copy | vs. Velen | Repair per point | vs. Velen |
  | --- | --- | --- | --- | --- |
  | Velen armorers (Baron's Keep, Mouth) | 19,155 (×3.96 player value) | 1.00 | 12 | 1.00 |
  | Velen smith (Snots) | 18,546 | 0.97 | 12 | 1.00 |
  | Novigrad armorers (rich district, White Bridge) | 23,412 | 1.22 | 14 | 1.17 |
  | Novigrad market smith | 22,667 | 1.18 | 14 | 1.17 |
  | Skellige armorers (Kaer Trolde, Larvik) | 22,347 | 1.17 | 13 | 1.08 |
  | Skellige smiths (Kaer Trolde, Larvik) | 21,636 | 1.13 | 13 | 1.08 |

  - The economy is **regional and comes with the craftsman's template** (Novigrad +17–22 %,
    Skellige +8–17 % over Velen). Same region → same prices, regardless of tier (master and
    journeyman equal); a smith prices armor 3 % below an armorer.
  - **The player's position doesn't matter**: identical numbers in Velen and Novigrad.
    `theGame.GetCurrentZone()` returned 0 (undefined) in both places, and the script-side
    `GetMerchantPriceModifier` always returned 1.0 — the native code doesn't use it.
  - Player-side prices ignore all of it: value 4,801, `GetItemPriceModified(item, true)` (selling)
    also 4,801.
  - Vanilla's full repair (repair per point × 100) is exactly 25 % of the item value in Velen
    (1,200 = 4,801 × 0.25, our fee fraction) and follows the region elsewhere (1,400 / 1,300).
- **Second run** (same templates; fresh copies at 0 durability, 2026-10-20):
  - Full repair = per point × max durability (100) exactly — no finer price behind it.
  - Per point is whole crowns, **rounded up**: Light armor 01 (value ~290) 1/pt everywhere,
    Novigraadan sword 1 (~900) and Bear Armor 1 (863) 3/pt everywhere. Regional differences only
    show from a few crowns per point upwards (valuable gear).
  - `GetRepairPriceModifier` is 1.0 at every craftsman and the funds type (Poor/Avg/Rich)
    doesn't match the price differences — neither is the regional knob, and the native factor
    isn't readable from script.
  - → The fee anchor is the craftsman's full-repair price (`W3InfusionService.GetFeeAnchor`).

## 7. Exclusions

Never touched by the mod (`InfusionService.IsExcludedItem`): quest items (`Quest` tag — what
`IsItemQuest` checks), hidden/technical items (`IsItemBody`, `NoShow`,
`NoShowInPlayersInventory` — the player inventory contains body meshes such as
`Body torso medalion` in the armor category), Aerondight (own progression), merchant-range
autogen items (`AutogenUseLevelRange`).

## 8. Testing

No out-of-game test bench is practical ([SCRIPT_TEST_BENCH_RESEARCH.md](SCRIPT_TEST_BENCH_RESEARCH.md)).
Verification runs in game: one-command scenario tests (`infuseScenarioAll`,
tests/modInfusion/README.md) for the service, the manual checklist in [UI.md](UI.md) for the menu.

## 9. Spec deviations (approved)

1. §6.2/§10: craftsman tiers are Journeyman / Master / Grand Master / Arch Master (no Amateur).
2. §5.2: salvage uses native `recycling_parts`; the per-category table is only a fallback for
   items without data.
3. §6.3: the labor fee's base is **this craftsman's full-repair price of the target**
   (`GetItemPriceRepair` × max durability; target value × 0.25 as fallback), not a fixed base
   fee — it follows level, rarity, patch prices and the craftsman's regional economy (§6). The
   spec allows refining the formula during testing.
4. §5.4/§7.1: the level gap scales both the fee (labor) and the recipe (physical work) —
   deliberate double scaling. Details: [BALANCING.md](BALANCING.md).
5. §3.3: compatibility is by item **category** (chest↔chest, boots↔boots, steel↔steel,
   silver↔silver), stricter than "armor↔armor", matching the per-slot level formulas.
6. §9: UI via a new tab using the existing Disassemble page; SWF editing out of scope.
7. §13.2: no engine-level atomic transactions (see §6).
8. §10: settings are script constants in `InfusionConfig.ws` (clamped when read), not a settings
   menu — mod menus are broken on 5.01 (§1); this is the spec's own fallback. Player doc:
   [CONFIGURATION.md](CONFIGURATION.md).

Reviewed with the project owner on 2026-10-20: 3, 4, 5 and 8 stay as they are for 1.0.
