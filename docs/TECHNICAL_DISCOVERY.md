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
| Strings | `.w3strings`, built from CSV with the community encoder w3stringsr (tools/README.md). |
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
| Events | **Can't be annotated** (the parser expects `function`). Hook the function the event calls instead. **Flash calls reach script events only**: an added function named like a Flash call (`OnInventoryItemSelected`) never runs. An annotation-only mod therefore can't receive Flash calls the vanilla menu doesn't already handle. |

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
- `GetItemPriceModified` is native and scales with level and NG+ (the fee anchor).

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
3. §6.3: the labor fee's base is the **target's market value** (`GetItemPriceModified`), not a
   fixed base fee — it auto-balances with the game's economy.
4. §5.4/§7.1: the level gap scales both the fee (labor) and the recipe (physical work) —
   deliberate double scaling. Details: [BALANCING.md](BALANCING.md).
5. §3.3: compatibility is by item **category** (chest↔chest, boots↔boots, steel↔steel,
   silver↔silver), stricter than "armor↔armor", matching the per-slot level formulas.
6. §9: UI via a new tab using the existing Disassemble page; SWF editing out of scope.
7. §13.2: no engine-level atomic transactions (see §6).
