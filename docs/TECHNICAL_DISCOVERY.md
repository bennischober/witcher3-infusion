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
| Game edition | **Remastered (5.01, exe 5.0.0.1048522, updated 2026-10-10)**. DX12-only. Supersedes the Next-Gen edition; base game + all DLCs merged into single bundles. Previously listed as "Next-Gen 4.04c" — that install was upgraded in place. |
| REDkit | Full install at `...\The Witcher 3 REDkit` with `editor.exe`, `wcc_lite.exe`, `bundlebuilder.exe`, `r4Launcher.exe`, `scriptStudio.exe`. |
| Script sources | `REDkit\r4data\scripts` (1,525 `.ws` files) matched the game's `content\content0\scripts` before the 5.00 update (MD5-verified). **After 5.00 the game scripts changed** (UTF-8 re-encode + keyword/compiler changes + gameplay changes) — re-verify any API assumption against the *current* game scripts before relying on it; the community changelog (Nexus mod 12945 / GitHub `ElementaryLewis/The-Witcher-3-Remastered-Changelog`) diffs 4.04b → 5.00b → 5.01 file-by-file. |
| Script deployment | Mods ship **loose `.ws` files** under `mods\modX\content\scripts\...`; the game compiles them at launch. **5.00 requirements: UTF-8 with BOM encoding** (scripts, XML, CSV, w3strings were UTF-16 in Next-Gen); new compiler reserves `map`/`set` as keywords; `precompiled.rsblob` (REDkit-cooked) is the console-safe alternative, optional on PC. |
| User's installed mods (after 2026-10-10 cleanup) | `modHQFacesV3` (texture/mesh assets — unaffected by 5.00), `modRealWeather` (CSV weather assets + `DLC\RealWeather` bundle half — kept, verify in game), `modInfusion` (this project). **Removed:** `modFCR3_2_Nitpicker` + `modFCR3_3_Padlock` (FCR3 is bundled with the game since 4.0), `modLevelingGear` (abandonware, keyword-broken), `mod0000_MergedFiles` (merger output for the two above), `modMoreMoneyForTraders` (UTF-16 script, unfixable), `modOver9000ngplus` (unverified NG+ data mod). Full rationale in `docs/PATCH_NOTES_2026-10-10_scripts.md` and `docs/MOD_CLEANUP_2026-10-10.md`. |
| UI assets | All menus are compiled Flash SWFs inside cooked bundles (e.g. `gameplay\gui_new\swf\repair\panel_blacksmith.redswf`). **Corrected 2026-10-17: REDkit ships the Flash sources** — `REDkit\r4data\gameplay\gui_new\actionscript\` (873 `.as` files, incl. `red\game\witcher3\menus\blacksmith\*.as` and `menus\overlay\PriceConfirmationPopup.as`) and `...\gui_new\fla\` (e.g. `fla\witcher3\menus\repair\panel_blacksmith.fla`). The sources reference Switch 2 input types, i.e. they are current (Remastered era), not 2015 leftovers. They make the script↔Flash protocol verifiable offline (§13). Editing menus visually still needs Adobe Animate + REDkit cooking — out of scope for v1. |
| Localization | Game uses compiled `.w3strings`; REDkit ships `REDstrings.exe` (bin\tools\RedStrings_internal) for string database work. Community encoders exist for adding strings. |
| Console | Not enabled in `user.settings`; enabling requires `DBGConsoleOn=true` (commonly via registry `AllowConsole=1`). **Unverified on this machine** — to be enabled for prototype testing. |
| In-game mod browser | 5.00 integrates the mod.io SDK (Mod Hub) with a curated, platform-validated mod list; Nexus remains usable but only "Remastered Compatible"-tagged mods should be installed. `ModsConfig.json` referenced by the exe (not yet created on this install). |
| Mod settings menus | **Not viable on Remastered 5.01** (verified): the legacy `user_config_matrix` system still exists (`ingameconfig.ini` `MatrixPath`, base-game XMLs load) but mod-menu UI support is broken — displayNames are loc keys with an `option_` prefix (unresolved keys render as `##option_...`), and the mod-hub entry collides with the settings list layout; a community bugfix mod (Nexus 13284) exists for the "only first 10 mods can open settings" bug. **Decision: curated defaults, no settings menu** (spec §10 fallback). The XML source stays in the repo (`src/modInfusion/bin/...`), not deployed; re-enable if CDPR fixes the UI. |
| Fee auto-balance | The labor fee anchors to the **sacrifice item's market value** (`GetItemPriceModified` — the game's own level/tier-scaled price) as a fraction (default 10%), with a labor floor (10 crowns) and the §6.2 tier/tier-target/gap multipliers. Official economy updates therefore rebalance infusion fees automatically — no hard-coded crowns to go stale. |

Implication for the repo: the project currently has no mod skeleton. A script-only mod layout
(`modInfusion\content\scripts\...`) is viable and is the lowest-risk packaging approach.

**Development workflow (decided):** all mod source lives in this repository (e.g. `src\modInfusion\...`);
the game's `mods\` directory receives copies only via a deploy script. The game directory is never
edited directly. Script merging is still required for any mod that overrides base scripts — it was
not simplified by the Next-Gen/REDkit update (the community maintains a "Script Merger - Remastered"
fork for the UTF-8 change, and Vortex integrates it). By shipping only new script files, this mod
avoids the merger entirely for itself and all users; any future base-file override (e.g. a
blacksmith-menu tab in Milestone 6) must be justified and its conflict surface documented.

## 2. Critical conflict constraint (user's install)

**Superseded 2026-10-10:** the original install carried three script-merging mods
(`mod0000_MergedFiles` merging `gameParams.ws`, `inventoryComponent.ws`, `playerWitcher.ws` for
Leveling Gear + FCR3). Those mods were **removed** during the Remastered cleanup (FCR3 is bundled
with the game since 4.0; Leveling Gear was keyword-broken and abandonware; see
`docs/MOD_CLEANUP_2026-10-10.md`). The constraint below is retained as the general design rule —
it now costs nothing locally and remains essential for distribution:

- **Never override a base game script file** (`gameParams.ws`, `inventoryComponent.ws`,
  `playerWitcher.ws`, etc.). Ship only new files in new folders. This keeps the mod
  script-merger-free for every user (Next-Gen and Remastered alike).
- *Update 2026-10-17:* the official REDkit docs describe the annotations (`@wrapMethod`,
  `@replaceMethod` — also for **global functions** —, `@addMethod`, `@addField`, since the
  2024-06-06 patch) as written in a new `.ws` file; loose-script support and event wrapping are
  not stated and need a spike. Migration plan: docs/ROADMAP_IDEAS.md §3.
- *Update 2026-10-19:* the compiler's annotation errors (strings in witcher3.exe 5.01) add
  what the docs omit: global functions can be **replaced** (`@replaceMethod function F`,
  "cannot have a target class"), a second replacement of the same function is a compile error
  ("duplicate found"), definitions inherited from a parent class can be neither wrapped nor
  replaced, native functions can be wrapped only in mod.io (precompiled) mods. No message refers
  to a global `@wrapMethod`, so it is treated as unsupported. Spike: `commonMenu.ws` override
  replaced by `InfusionMenuTab.ws` (wrap `DefineSceneMenuStructure` + insert the tab, replace
  `HaxGetPanelStateName`) — verified in game 2026-10-19 (tab after Repair, other menus normal).
- *Finding 2026-10-19 (scenario tests):* item tags added by script (`AddItemTag`) are **not
  saved** — gone after a save/reload. Never use them to find items across sessions. Item stats
  (damage, armor) live in `SAbilityAttributeValue.valueBase`; `CalculateAttributeValue` returns 0
  for them (it multiplies by `valueMultiplicative`, which is 0 on items).
- *Finding 2026-10-19 (blacksmithMenu port):* events (`event OnX`) cannot be annotated — the
  parser expects `function` after `@wrapMethod(...)`. Workaround: wrap the function the event
  calls (`OnRequestConfirmation` → `ProcessRequestConfirmation`, `OnGetItemData` →
  `ShowItemTooltip`); move `OnConfigUI` setup to the first call of a wrapped function.
  `RequestSubMenu` is native (`flashScriptImports.ws`), so popups opened by events can't be
  intercepted. Flash's `BlacksmithMenu.as` only sends Space/X (`OnRepairAllItems`) while
  `_xActionLabel` is non-empty.
  First launch: **loose scripts parse annotations** (the error came from the token after
  `@wrapMethod(...)`, not from the annotation itself). Syntax rule found: **no access modifier
  after the annotation** — `@wrapMethod(C) private function F()` fails with "unexpected
  TOKEN_PRIVATE, expecting TOKEN_FUNCTION"; write `@wrapMethod(C) function F()`. Modifiers
  dropped on `@addMethod` too (the docs' `public` example is not relied on).
- On Remastered, prefer the new conflict-free mechanisms for anything that *must* touch base code:
  script annotations (`@wrapMethod`), scope-based scripting (add functions/vars/enums to a class
  from a separate file), and XML `on_conflict="extend"` definitions. These require cooking a
  `precompiled.rsblob` via REDkit (optional on PC, required on consoles).

Any mod that also overrides these files would need re-merging on every change and risks breaking
the user's setup. **Design decision: the infusion mod must NOT override any base script file.**
Instead it adds only **new** script files (new classes, new enums) and uses event/extension points
that do not collide with other mods. This satisfies §14 compatibility goals for this specific install.

Note: `W3CraftsmanComponent`, `W3CraftingManager`, `CR4BlacksmithMenu`, `CR4CommonMenu` live in files
that no installed mod touches (`craftsmanComponent.ws`, `craftingManager.ws`, `blacksmithMenu.ws`,
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

*Update 2026-10-18 (patch safety):* the mod no longer duplicates these formulas. Below the
player's max level it uses `inv.GetItemLevel` directly; near/above the cap it takes the
uncapped `baseItemLevel` from `theGame.params.GetItemLevel` plus the adjustment block
(`InfusionService.ComputeItemLevel` / `ComputeUncappedItemLevel`). Official changes to the
per-slot formulas therefore flow through automatically.

**The autogen system** (vanilla loot leveling; inventoryComponent.ws `GenerateItemLevel`):

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

Leveling Gear (removed 2026-10-10; its source was studied before removal) confirmed the same
technique from the other direction: it did not store levels either; it computed a virtual level from
stats and applied per-level autogen abilities (`GetItemLevel`/`GetItemArmorTotal` in its
inventoryComponent.ws override).

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
   base game scripts (§2). If a future feature *must* modify those, prefer Remastered
   annotations/scope-based scripting, or document the conflict surface.
2. ~~**FCR3 stat overhaul**~~ **Resolved 2026-10-10:** FCR3 was removed from the install (bundled
   with the game since 4.0; the installed copy was an old pre-4.0 version with keyword-broken
   scripts). The vanilla stat system applies. *Caveat:* the game's built-in FCR3 is a curated
   subset — if it alters damage/armor semantics relative to 1.x-era vanilla, the level formulas in
   §3 must be re-verified against in-game values (the prototype's add-until-equal loop is robust
   to different `stat_add` values either way).
3. ~~**Leveling Gear auto-scale side effect**~~ **Resolved 2026-10-10:** Leveling Gear was removed.
   `GetItemLevel` is side-effect-free vanilla again. The infusion service still computes levels
   itself (signature stability + FCR3-in-bundle uncertainty), which remains the right call.
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
   *Update 2026-10-17:* the ActionScript/FLA sources ship with REDkit (§1, §13) — Flash behavior
   is now read from source instead of guessed; SWF *editing* remains out of scope.
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
3. §2.2 reference mods: Leveling Gear's source was studied before its removal (it demonstrated the
   level-derivation technique). For future Remastered-era reference, use the community changelog
   (Nexus 12945 / GitHub) and Remastered-tagged mods.
4. §9: "extend the repair interface" is only feasible via script-level menu overrides; MVP uses
   script-only UI paths. SWF editing explicitly out of scope for v1 (the `.fla` sources exist in
   REDkit, but rebuilding/cooking SWFs adds a toolchain and a conflict surface we avoid).
5. §5.2: salvage uses native `recycling_parts` directly — the configurable salvage mapping is a
   fallback for items lacking data, not the primary path.
6. §13.2: engine-level atomic inventory transactions do not exist; safety comes from the
   validate-verify-consume order plus `StartInvUpdateTransaction` (verified pattern above).

7. §5.4/§6.1/§7.1 (2026-10-18, user-approved): the recipe is the target's own dismantle data
   scaled by the level gap, and the fee is anchored to the target's value — both scale with the
   gap (deliberate double scaling: labor vs. physical work). Details: docs/BALANCING.md.

None of these change the gameplay model: sacrifice-based level transfer, no bonus merging, no
automatic scaling, existing craftsmen only.

## 13. Blacksmith menu Flash protocol (verified from REDkit ActionScript sources, 2026-10-17)

Source files (REDkit `r4data\gameplay\gui_new\actionscript\red\game\witcher3\`):
`menus\blacksmith\BlacksmithMenu.as`, `BlacksmithItemPanel.as`, `ItemRepairInfo.as`,
`ModuleBlacksmithGrid.as`, `menus\overlay\PriceConfirmationPopup.as`,
`managers\ContextInfoManager.as`. Static reading only — runtime behavior of the items marked
*(runtime)* still needs an in-game check.

| Topic | Verified behavior | Consequence for the mod |
| --- | --- | --- |
| Action flow | Flash state machine `Selection → Confirmation → Waiting`. Activating an item calls `OnRequestConfirmation(id, actionPrice)` and **waits** in `Confirmation` until script calls `confirmAction(bool)`. `true` → progress animation → `OnRepairItem(id, actionPrice)` (Repair tab); `false` → back to `Selection`, no side effects. | Every script path that handles a confirmation request must call `HandleActionConfirmation`. The infusion flow ends with `false` (never `true`, which would trigger a repair charge). Missing it freezes the grid until a tab switch. |
| `actionPrice` | Flash passes the item's `actionPrice` back with the request and with `OnRepairItem`; the info panel shows it (red when unaffordable). | The grid component overwrites it with the infusion fee for undamaged infusion targets. Undamaged items in the Repair tab must never reach the vanilla repair path (it would charge that fee). |
| Grid filtering | `ModuleBlacksmithGrid` renders whatever array arrives on `repair.grid.player`; the only per-item gate is `disableAction` (repair component: quality > `masteryLevel` = 5). | Grid visibility is fully script-controlled — no slot-count/frame limit to work around. |
| Panel button label | Hardcoded in Flash: `setMenuState` → `panelRepair.setButtonData("[[panel_button_common_repair]]", GAMEPAD_A, KeyCode.E)`. | The script swaps it via `GetMemberFlashObject("panelRepair").GetMemberFlashFunction("setButtonData")` with `"enter-gamepad_A"` / `69`. *(runtime: `GetMemberFlashObject` is an engine import with no vanilla caller.)* |
| `GetItemDefaultActionName` | Defined in `blacksmithMenu.ws` but **never called** anywhere in the game scripts. | Not usable as a label hook. Restored to vanilla. |
| Selection hook | The tooltip manager calls `OnGetItemData(item, compareType)` whenever the selected/hovered item's tooltip is requested (blacksmith menu has no mouse override). | Used to update the button label per item. |
| Price popup | `PriceConfirmationPopup.populateData`: `tfMessage.htmlText = TextContent`; price shown only when `ItempPrice > 0`. Message field grows with text, background does not. | Popup text uses `<br>` (also: WitcherScript strings do not process `\n` escapes); price set via `SetPrice`; summary kept short. *(runtime: layout with 4–6 lines.)* |
| Menu with NPC context | `CommonMenu` derives the NPC context from its init data (`W3InventoryInitData.containerNPC` or the entity itself); `BlacksmithMenu` takes the same object as `_fixerNpc`. Vanilla `cookingPlace.ws` passes an entity directly to `RequestMenuWithBackground`. | Dev command `infuseOpenMenu` opens the real service menu anywhere with a spawned craftsman. *(runtime)* |

**Technical body items.** The player inventory contains hidden body meshes such as
`Body torso medalion` (`_technical_items_defs.xml`: `category="armor"`, tags `NoDrop,NoShow,Body`).
They pass category checks as armor and were selected as sacrifices by the M6 grid (seen in
`scriptslog.txt`, 2026-10-11). `IsExcludedItem` now rejects `Body`, `NoShow` and
`NoShowInPlayersInventory` — the same tags the vanilla inventory UI hides.
