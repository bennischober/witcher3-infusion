# Technical Discovery Report — Witcher Gear Infusion

Status: **Milestone 1 (technical feasibility) — investigation complete; in-game verification pending**
Target: The Witcher 3: Wild Hunt — Next-Gen (patch 4.04c / exe 5.0.0.1048522), REDkit installed
Date: 2026-10-10

This report documents what was verified directly against the installed game and REDkit sources
(`E:\SteamLibrary\steamapps\common\The Witcher 3` and `...\The Witcher 3 REDkit`). Every claim below
was checked against actual script sources or installed files unless explicitly marked **unverified**.

---

## 1. Verified environment

| Item | Finding |
| --- | --- |
| Game edition | Next-Gen. `bin\x64` (DX11, scriptStudio remnants) and `bin\x64_dx12\witcher3.exe` present. Exe version **5.0.0.1048522** (patch 4.04c era). |
| REDkit | Full install at `...\The Witcher 3 REDkit` with `editor.exe`, `wcc_lite.exe`, `bundlebuilder.exe`, `r4Launcher.exe`, `scriptStudio.exe`. |
| Script sources | `REDkit\r4data\scripts` (1,525 `.ws` files) is **byte-identical** to the game's `content\content0\scripts` (MD5-verified sample: `inventoryComponent.ws`). All engine/game script APIs can therefore be read from REDkit sources with full confidence. |
| Script deployment | Mods ship **loose `.ws` files** under `mods\modX\content\scripts\...`; the game compiles them at launch (proven by installed `modLevelingGear`, which contains only `.ws` files, no bundles, no metadata.store). |
| User's installed mods | `mod0000_MergedFiles` (Vortex script merger — merges `gameParams.ws`, `inventoryComponent.ws`, `playerWitcher.ws`), `modLevelingGear` (Vortex-managed), `modFCR3_2_Nitpicker` + `modFCR3_3_Padlock` (combat overhaul), `modHQFacesV3`, `modMoreMoneyForTraders`, `modOver9000ngplus`, `modRealWeather`. |
| UI assets | All menus are compiled Flash SWFs inside cooked bundles (e.g. `gameplay\gui_new\swf\repair\panel_blacksmith.redswf`). **No SWF sources (`.fla`) are shipped** — modifying existing menus visually requires community SWF tools and is high-risk. |
| Localization | Game uses compiled `.w3strings`; REDkit ships `REDstrings.exe` (bin\tools\RedStrings_internal) for string database work. Community encoders exist for adding strings. |
| Console | Not enabled in `user.settings`; enabling requires `DBGConsoleOn=true` (commonly via registry `AllowConsole=1`). **Unverified on this machine** — to be enabled for prototype testing. |

Implication for the repo: the project currently has no mod skeleton. A script-only mod layout
(`modInfusion\content\scripts\...`) is viable and is the lowest-risk packaging approach.

## 2. Critical conflict constraint (user's install)

Three installed mods **override the same base scripts** and are merged by `mod0000_MergedFiles`:

- `gameParams.ws` — Leveling Gear, FCR3
- `inventoryComponent.ws` — Leveling Gear, FCR3
- `playerWitcher.ws` — Leveling Gear, FCR3

Any mod that also overrides these files would need re-merging on every change and risks breaking
the user's setup. **Design decision: the infusion mod must NOT override any base script file.**
Instead it adds only **new** script files (new classes, new enums) and uses event/extension points
that do not collide with merged files. This satisfies §14 compatibility goals for this specific install.

Note: `W3CraftsmanComponent`, `W3CraftingManager`, `CR4BlacksmithMenu`, `CR4CommonMenu` live in files
that the user's mods do not touch (`craftsmanComponent.ws`, `craftingManager.ws`, `blacksmithMenu.ws`,
`commonMenu.ws`). Overriding those is currently conflict-free — but the smallest prototype should
still avoid menu overrides entirely (see §7).

## 3. How item levels actually work (the core mechanism)

**Item levels are not stored per instance. They are derived from aggregated stats.**

Verified call chain (REDkit sources):

- `CInventoryComponent.GetItemLevel(item)` (inventoryComponent.ws:305) computes level from the
  item's current attribute values:
  - armor/pants/gloves/boots: `level = 1 + (armor.valueBase - stat_min) / stat_add`
    (armor: min 25, +5/level; pants: min 5, +2; gloves: min 1, +2; boots: min 5, +2)
  - steelsword: sum of 7 damage attributes, `level = ceil(1 + (1 + Σ - 25)/8)`
  - silversword: sum of 6 damage attributes, `level = ceil(1 + (1 + Σ - 90)/10)`
  - minus adjustments: quality 5 (Witcher gear) −2, quality 4 (relic) −1, OlgierdSabre −3, EP1 −1;
    NG+ uncaps to `baseLevel` and caps at player max level (100 by default).
- `theGame.params.GetItemLevel(...)` (gameParams.ws:917) holds the category-specific linear formulas.
- The stat values come from the item's **ability list**: base abilities from the item definition
  (e.g. `Bear Armor 4 _Stats` → `armor type="base" min="240"`) plus **runtime-added crafted abilities**.

**The autogen system** (vanilla loot leveling; inventoryComponent.ws:4410 `GenerateItemLevel`):

- Loot items tagged `Autogen` get `autogen_steel_base`/`autogen_steel_dmg` (etc.) abilities added at
  spawn — one `_dmg` ability **per level**. Each `autogen_fixed_*_dmg` ability adds exactly one
  level's worth of stats:
  - `autogen_fixed_steel_dmg`: +8 SlashingDamage (level step: 8) ✓
  - `autogen_fixed_silver_dmg`: +10 SilverDamage (step: 10) ✓
  - `autogen_fixed_armor_armor`: +5 armor (step: 5) ✓
  - `autogen_fixed_pants_armor` / `autogen_fixed_gloves_armor`: +2 (step: 2) ✓
- `IncreaseNGPItemlevel` (inventoryComponent.ws:5036) does exactly this to raise vanilla items in NG+.

**Consequence for infusion:** raising a target's level by N means adding N `autogen_fixed_*` abilities
(and the matching `autogen_fixed_*_base` ability if absent); lowering is not needed (spec forbids
level-down infusions). The item's derived level then rises by N automatically — no stored level
field is touched, and save/load persistence follows the game's own NG+ mechanism (crafted abilities
are part of the item instance; vanilla relies on the same mechanism across saves, see
`NGPItemAdjusted` item modifier at inventoryComponent.ws:5081).

Leveling Gear (installed mod) confirms the same technique from the other direction: it does not store
levels either; it computes a virtual level from stats and applies per-level autogen abilities
(`GetItemLevel`/`GetItemArmorTotal` in its inventoryComponent.ws override).

**Witcher gear specifics:** Witcher set pieces (e.g. `Bear Armor 4`, tag `BearSet`) are NOT tagged
`Autogen`; their stats are fixed per crafted tier (`Bear Armor 4` → armor 240 → derived level 44,
−2 for quality 5 → displayed 42). `GetItemLevel` still derives their displayed level from stats, so
the same autogen-addition technique works; NG+ already applies `IncreaseNGPItemlevel` to them.

**Removing abilities:** `RemoveItemCraftedAbility(itemId, abilityName)` exists
(inventoryComponent.ws:1374) and is used by the vanilla repair-object system. Whether it removes one
or all duplicate instances of the same ability name is **unverified** — only relevant if we ever need
to lower a level or "re-base" an item; the MVP (level up only) does not need it.

## 4. Salvage / material recovery (§5) — fully supported by vanilla data

- `GetItemRecyclingParts(itemId)` returns `array<SItemParts>` (itemName + quantity) from the item
  definition's `<recycling_parts>` XML node (inventoryComponent.ws:1186, import).
- Verified data: ordinary and Witcher gear both carry `recycling_parts`
  (e.g. `Bear Armor 4`: Hardened leather ×2, Chitin scale ×3, Infused dust ×3, Dwimeryte enriched ore ×2, Glowing ore ×4; Shiadhal armor: Silk, Hardened leather, Meteorite ingot, …).
- Vanilla dismantling (`RecycleItem`, inventoryComponent.ws:2130) adds parts as items and removes the
  source — quality-tier dependent yields at craftsman levels. Our infusion instead **reads** the parts
  and applies them as a discount (no inventory churn), exactly as §5.1 requires.
- Enhancements are refundable by vanilla dismantle logic (blacksmithMenu.ws:651 re-adds installed
  runes when dismantling) — our sacrifice flow can do the same or explicitly discard them (§5.5
  requires a decision; default: not refunded, since the target keeps its own).

## 5. Craftsman system (§8) — verified API, corrected tier names

- `W3CraftsmanComponent` (craftsmanComponent.ws) extends `W3MerchantComponent`; data is
  `craftsmanData : array<SCraftsman>` with `type : ECraftsmanType` and `level : ECraftsmanLevel`.
- **Enums differ from the spec's examples** (craftingTypes.ws:6, :59):
  - `ECraftsmanType`: `ECT_Undefined, ECT_Smith, ECT_Armorer, ECT_Crafter, ECT_Enchanter`
  - `ECraftsmanLevel`: `ECL_Undefined, ECL_Journeyman, ECL_Master, ECL_Grand_Master, ECL_Arch_Master`
  - **There is no "Amateur" tier** — the spec's Amateur/Journeyman/Master examples must map to
    Journeyman/Master/Grandmaster(+Archmaster) or become configurable. Design decision needed (§10).
- Runtime identification: `GetCraftsmanLevel(type)`, `IsCraftsmanType(type)` — usable directly from
  menu context (`_fixerNpc.GetComponentByClassName('W3CraftsmanComponent')`, as `commonMenu.ws:1160`
  already does). NPC-specific tiers live in cooked entity templates (e.g. `hattori.w2ent`) and are
  **not readable offline** here; runtime queries are sufficient and correct per §2.3.
- `GetCraftsmanLevel` has a documented quirk: for `ECT_Crafter` it falls back to Smith/Armorer levels —
  irrelevant for us since we gate on `ECT_Smith` / `ECT_Armorer` explicitly.
- NPC tags (`Blacksmith`, `Armorer`, `Apprentice`, `Specialist`, `Master`, `Archmaster`) are set by
  the component at attach time (craftsmanComponent.ws:120–141) — useful for UI display and for
  checking specialization without touching entity data.

## 6. Money, inventory, durability, transactions (§6, §13) — all verified

- Money: `GetMoney/AddMoney/RemoveMoney/SetMoney` on `CInventoryComponent` (crowns are just a
  `'Crowns'` stack; inventoryComponent.ws:149–191). Menu pattern: `_fixerInventory.AddMoney(price); _inv.RemoveMoney(price)` (blacksmithMenu.ws:741).
- Items: `GetAllItems(out array<SItemUniqueId>)`, `GetItemName/GetItemCategory/ItemHasTag/AddItemTag/
  RemoveItemTag`, `RemoveItem(id, qty)`, `AddAnItem(name, qty, ...)`, `GetItemQuantity`,
  `GetItemQuantityByName`, `SplitItem`, `GetItemModifierInt/SetItemModifierInt` (persistent per-item
  int flags — usable for `InfusedLevel` bookkeeping without new save data).
- Durability: `HasItemDurability`, `GetItemDurability`, `GetItemInitialDurability`,
  `GetItemMaxDurability`, `GetItemDurabilityRatio`, and **`SetItemDurabilityScript(item, max)`** —
  the exact call vanilla repair uses (guiRepairInventoryComponent.ws:97). Full restoration = one call.
- Upgrade preservation: the game's own crafting (`Craft`, craftingManager.ws:156–268) demonstrates
  the full preserve-and-rebuild pattern: read `GetItemEnhancementItems`, `GetEnchantment`,
  `GetItemColor` from the source, then `AddSlot` + `EnhanceItemScript` + `EnchantItem` + `ColorItem`
  on the new item. Our infusion mutates in place (better than rebuild — no identity loss), but this
  fallback exists if a definition swap is ever required.
- Bulk-update guard: `thePlayer.StartInvUpdateTransaction()` / `FinishInvUpdateTransaction()`
  (playerWitcher.ws:6943) defers encumbrance updates during multi-step item changes — the correct
  wrapper for the commit sequence.
- Pricing precedent: repair price = `priceRepair * durabilityDiff` (inventoryComponent.ws:2930);
  crafting price is stored per schematic and `CalculateCostOfCrafting` builds it from the crafted
  item's price (craftsmanComponent.ws:87). Infusion pricing will be its own configurable formula
  (§6.3 of spec) — no vanilla formula to extend safely, as the spec anticipated.

## 7. UI integration options (§9) — ranked

Vanilla services UI is `CR4BlacksmithMenu` (blacksmithMenu.ws), opened via
`theGame.RequestMenuWithBackground('BlacksmithMenu', 'CommonMenu', initData)` from `CR4CommonMenu`
(commonMenu.ws:1090–1098 defines tabs Repair/Sockets/Disassemble/AddSockets). States map to
inventory-filter components (`W3GuiRepairInventoryComponent`, `W3GuiDisassembleInventoryComponent`,
…) that override `ShouldShowItem` and `SetInventoryFlashObjectForItem`. Confirmation flows use
`PriceConfirmationPopupData` → `PopupMenu` (blacksmithMenu.ws:474–492). Error notifications use
`showNotification(GetLocStringByKeyExt(...))` with existing `panel_crafting_exception_*` keys
(craftingTypes.ws:33) — reusable for §9.3 messages.

1. **Chosen for MVP: new standalone menu class in a new file** (`CR4InfusionMenu extends CR4MenuBase`,
   opened with `theGame.RequestMenu('InfusionMenu', initData)` from a hook), reusing the existing
   inventory-grid Flash assets is not required initially — a minimal scripted menu (or even a
   confirmation popup driven flow) is enough for Milestone 2. This touches **zero** merged files.
2. **Later: add an "Infusion" tab to the blacksmith menu** — requires overriding
   `commonMenu.ws` (tab registration, commonMenu.ws:1071 `DefineSceneMenuStructure`) and
   `blacksmithMenu.ws` (new menu state + event). Both files are currently untouched by the user's
   mods, so a merge burden doesn't exist today, but SWF-side tab visuals may be impossible without
   SWF editing. Defer until the core works.
3. **Prototype-only alternative: debug console flow** — `exec function` commands
   (e.g. `temp.ws:5968 additem`) prove exec functions work; a temporary `InfusionDebug.ws` with exec
   functions (`infuseTarget`, `infuseSacrifice`, `infusePreview`) would test the full transaction
   without any UI. Enable console via `DBGConsoleOn=true` (**unverified on this machine**).

The existing `ItemSelectionPopup` (gui\popups\ItemSelectionPopup.ws) supports tag/category filtered
item picking from the player inventory — a candidate for sacrifice selection in a later milestone.

## 8. New Game+ and level caps (§8.3)

- Player max level: `W3LevelManager.GetMaxLevel()` returns hard **100** (levelManager.ws); the game
  supports infinite levels via `geralt_levelups.xml` (`<level number="-1" requiredExp="2000">` —
  "infinite levels" comment; `lastCustomLevel` handling, levelManager.ws:26–91). The installed
  `modOver9000ngplus` raises capabilities by bundling modified `geralt_stats.xml` — demonstrating
  data-only level extension works.
- Item level derivation in NG+ uncaps: `GetItemLevel` uses `baseLevel` (uncapped) when NG+ fact is
  set (inventoryComponent.ws:371–377), then caps at player max. Our infusion must mirror this: level
  transfer itself is uncapped; display/caps follow vanilla behavior. No hard infusion cap needed —
  consistent with spec §8.3.
- `theGame.params.NEW_GAME_PLUS_LEVEL_ADD` / `GetNewGamePlusLevel()` are the supported NG+ hooks.

## 9. Risks and unresolved items

1. **Script merge conflicts** — mitigated by design: new files only; no overrides of
   `gameParams.ws` / `inventoryComponent.ws` / `playerWitcher.ws` (§2). If a future feature *must*
   modify those, it must ship merge instructions for Vortex/`mod0000_MergedFiles`.
2. **FCR3 stat overhaul** — FCR3 changes damage/armor semantics (its own `GenerateItemLevel` scales
   off enemy levels). Autogen ability math (stat_add per level) may differ under FCR3. The infusion
   MVP must compute the level step from **actual observed stat deltas** at runtime rather than
   hard-coding 8/10/5/2 — or verify FCR3 keeps vanilla autogen abilities (partially verified: FCR3
   still calls `GenerateItemLevel` and uses autogen abilities, inventoryComponent.ws FCR3:4383+).
   → Prototype test on this install required.
3. **Leveling Gear auto-scale side effect (verified in merged files)** — on this install,
   `GetItemLevel(item)` mutates scalable items: if the item's derived level is below the player's
   level, it permanently adds `autogen_fixed_*` abilities until the item reaches player level
   (merged `inventoryComponent.ws` lines 425–428, `isItemScalable` at 470ff). Consequences:
   - Reading a level via `GetItemLevel` is **not side-effect free** for weapons/armor below player
     level; merely opening the inventory triggers the same behavior (this is Leveling Gear's
     "items level with you" mechanic).
   - The infusion service must therefore compute levels itself (aggregate stat + counted autogen
     abilities + formula) instead of relying on `GetItemLevel`, or accept that both target and
     sacrifice will already be scaled to player level.
   - Infusion remains meaningful under this setup: only sacrifices **above** player level produce
     progression, matching the install's item ecosystem.
4. **Per-level stat step** — read at runtime via
   `GetItemAbilityAttributeValue(itemId, attributeName, 'autogen_fixed_steel_dmg')` (import at
   inventoryComponent.ws:197) rather than hard-coding 8/10/5/2; robust under overhauls. Fallback
   table required only when the item has no autogen ability yet. The XML `type=` attribute on
   autogen damage abilities is omitted; vanilla behavior (NG+ item leveling works off these
   abilities and levels are derived from `valueBase`) implies omitted type defaults to `base` —
   **inferred, verify in-game**.
5. **`RemoveItemCraftedAbility` duplicate semantics** — unverified (§3). Not needed for MVP.
6. **Derived-level rounding** — `FloorF` vs `CeilF` per category; adding exactly N abilities should
   raise derived level by exactly N, but quality −2/−1 adjustments are applied *after* the formula.
   Since we transfer level *differences* (same item, same quality), adjustments cancel out. Verify
   empirically.
7. **Non-standard items** — quest items, Aerondight (its own leveling script, effects\other\
   aerondight.ws), bolts, crossbows, and `AutogenUseLevelRange` merchant items need exclusion rules.
   MVP: restrict to player weapons/armor categories and exclude quest-tagged and Aerondight items.
8. **UI without SWF editing** — a fully custom menu has no Flash asset to bind; solution for MVP is
   script-driven interaction (popup-based or debug exec), production UI in a later milestone using
   option 2 or a SWF from a compatible community framework. Documented as §9.4 limitation.
9. **In-game testing not yet performed** — everything above is static verification. Milestone 2
   includes the first in-game validation (console + debug commands).

## 10. Recommended architecture (maps to spec §12)

All new files under `mods\modInfusion\content\scripts\game\infusion\` (no base-file overrides):

| Component | File / class | Verified building blocks |
| --- | --- | --- |
| Infusion service (core) | `InfusionService.ws` — `W3InfusionService extends IScriptable` | `GetItemLevel`, `GetItemAttributeValue`, `GetItemCategory`, autogen ability addition, `SetItemDurabilityScript` |
| Salvage calculator | part of service | `GetItemRecyclingParts`, `GetItemQuantityByName` |
| Cost calculator | part of service | config-driven formula (own), integer-checked |
| Eligibility | part of service | `W3CraftsmanComponent.GetCraftsmanLevel/IsCraftsmanType`, NPC tags |
| Transaction manager | part of service | `StartInvUpdateTransaction`, money/item APIs, re-validate before commit |
| Config | `InfusionConfig.ws` — static class reading user.settings-compatible storage | `CInGameConfigWrapper` (inGameConfigWrapper.ws) or script constants |
| Debug entry points | `InfusionDebug.ws` — `exec function`s for MVP testing | console (`additem` precedent) |
| UI (later) | `InfusionMenu.ws` | `CR4MenuBase`, `RequestMenuWithBackground`, `PriceConfirmationPopupData` pattern |

Compatibility guard: the service never imports/extends classes from `gameParams.ws`,
`inventoryComponent.ws`, or `playerWitcher.ws` overrides; it only calls existing public APIs on
`thePlayer`, `theGame`, and the craftsman's components.

## 11. Smallest working prototype (Milestone 2 scope)

Goal: one verified end-to-end transaction on ordinary **steel swords**, debug-driven, no UI.

1. `exec function infuseTest()` (console): spawns two steel swords at different levels via
   `AddAnItem` + autogen ability manipulation (or takes existing inventory items).
2. Service validates: same category, `Lvl(sacrifice) > Lvl(target)`, distinct instances, not
   quest/Aerondight, craftsman present (or debug-bypass flag for first test).
3. Commit sequence (in this order, mirroring vanilla transaction safety):
   a. `StartInvUpdateTransaction()`
   b. record target's current derived level
   c. add `autogen_fixed_steel_base` (if missing) + N × `autogen_fixed_steel_dmg` to the target
      where N = sacrificeLevel − targetLevel
   d. verify `GetItemLevel(target) == sacrificeLevel`; if not, log and abort (no consumption)
   e. `RemoveItem(sacrifice)`; `_inv.RemoveMoney(laborFee)` (debug fee initially 0 or 1)
   f. `SetItemDurabilityScript(target, GetItemMaxDurability(target))`
   g. `FinishInvUpdateTransaction()`
4. Save/reload; re-verify level, stats, sockets, durability, and that the sacrifice stays consumed.

Acceptance: transaction survives save/reload with correct identity and stats; invalid inputs change
nothing. This proves the §3/§4/§13 core with the smallest possible surface, after which Milestone 3
(salvage + materials) and Milestone 4 (craftsman eligibility via `W3CraftsmanComponent`) layer on
within the same architecture.

## 12. Spec deviations required by findings (to be applied to INFUSION_SPEC.md)

1. §6.2/§10: craftsman tiers are `Journeyman / Master / Grand Master / Arch Master` — no Amateur.
   Config keys become `JourneymanLaborMultiplier`, `MasterLaborMultiplier`, `GrandMasterLaborMultiplier`,
   `ArchMasterLaborMultiplier` (or a lookup). **Approved by user 2026-10-10.**
2. §9 MVP interface: debug console (`exec function`s) for Milestone 2; menu integration deferred.
   **Approved by user 2026-10-10.**
3. §2.2 reference mods: Leveling Gear is installed locally and its full source is available for
   study — use it as primary reference (it already demonstrates the level-derivation technique).
4. §9: "extend the repair interface" is only feasible via script-level menu overrides (no SWF
   sources); MVP uses script-only UI paths. SWF editing explicitly out of scope for v1.
5. §5.2: salvage uses native `recycling_parts` directly — the configurable salvage mapping is a
   fallback for items lacking data, not the primary path.
6. §13.2: engine-level atomic inventory transactions do not exist; safety comes from the
   validate-verify-consume order plus `StartInvUpdateTransaction` (verified pattern above).

None of these change the gameplay model: sacrifice-based level transfer, no bonus merging, no
automatic scaling, existing craftsmen only.
