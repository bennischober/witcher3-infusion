# M6 — Production UI: state, findings, open items (updated 2026-10-19)

Status: **complete — the Infuse tab is the production UI (decision 2026-10-19); every check
passed in game.** The Repair tab is vanilla again. Remaining work is M7 (compatibility,
packaging, docs); the spec-wide gap list is docs/SPEC_COVERAGE.md.
Spec: INFUSION_SPEC.md §9 (UI/interaction), §16 Milestone 6.
Flash protocol reference: docs/TECHNICAL_DISCOVERY.md §13.

## What was built

### Entry point and flow (in the blacksmith service UI)

A dedicated **Infusion tab** in the existing blacksmith/armorer menu, next to Repair (spec §8.1:
the smallest UI extension attached to the existing service). Flash renders its **Disassemble
page** for the tab (its info panel lists a per-item icon row, used for the material costs); the
script keeps the state `'Infuse'`. Infusion is a **two-step flow** — the player picks both items
(spec §9.1); the sacrifice is never chosen automatically.

**Step 1 — target selection:** only items that can be infused at this craftsman right now
(damaged ones too — infusion includes the repair). Info panel: fee and the material row for the
best available sacrifice, `have/need` in green/red. E = **Infundieren**.

**Step 2 — sacrifice selection** (same grid, rebuilt): section headers **Target** (the picked
item) and **Choose a sacrifice** (every valid sacrifice for this craftsman), each priced for that
exact pair. E = **Infundieren**; selecting the target again (header "Ziel (E: abbrechen)") or
switching tabs returns to step 1 (Space / X until 2026-10-19 — dropped with the
annotation port, see below). A sacrifice whose
remaining materials are missing is disabled (`disableAction`: greyed panel, no E button, denied
sound, warning line "Fehlende Materialien").

Switching tabs returns to step 1; a successful infusion returns to step 1, a failed one stays in
step 2. Confirming opens `InfusionConfirmationPopupData` — a vanilla `PriceConfirmationPopup`
carrying the §9.5 summary ("Ziel: … (61 -> 68)", "Opfer: … (68)", materials covered by the
sacrifice, additional materials with icons, permanent-consumption + full-repair note) and the fee
as the popup price. Accept executes via `W3InfusionService.Execute(..., craftsman)` with the NPC
the player is talking to (spec §8.1); the craftsman receives the fee, as with vanilla repairs.
Accept, decline and every rejection answer Flash with `confirmAction(false)`; in the Infuse tab
no click ever reaches the vanilla path (Flash shows the Disassemble page there — a vanilla
`true` would dismantle the item).

### Files

| File | Role |
| --- | --- |
| `src/modInfusion/content/scripts/game/infusion/InfusionMenuTab.ws` | **Annotations** (no file override, since 2026-10-19): `@wrapMethod` on `CR4CommonMenu.DefineSceneMenuStructure` inserts the Infusion tab after Repair; `@replaceMethod` on the global `HaxGetPanelStateName` adds `"Infuse"`. Replaces the former `commonMenu.ws` override. |
| `src/modInfusion/content/scripts/game/infusion/InfusionBlacksmithMenu.ws` | **Annotations** (since 2026-10-19, replaces the `blacksmithMenu.ws` override): fields and helpers via `@addField`/`@addMethod`; wraps `SetMenuState`, `ApplyMenuState`, `SetSectionsDataList`, `InventoryUpdateAll`, `ShowItemTooltip`, `ProcessRequestConfirmation`, `CR4MenuBase.RefreshMenuState`. |
| `src/modInfusion/content/scripts/game/infusion/InfusionConfirmationPopup.ws` | Popup class (new class, moved out of the old override). |
| `src/modInfusion/content/scripts/game/gui/_old/components/guiInfusionInventoryComponent.ws` | **New class** (extends `W3GuiRepairInventoryComponent`): Infuse-tab grid, two phases, craftsman-aware verdicts cached per refresh, fee + material row per item. |
| `src/modInfusion/content/strings/{en,de}.w3strings` | UI labels, popup, notifications, localized rejection messages. |
| `tools/strings-sources/infusion_strings_{en,de}.csv` | Editable sources for the strings. |
| `tools/w3stringsr/` | The community Remastered strings encoder (user-provided; not committed). |
| `tests/.../InfusionDebug.ws` → `infuseOpenMenu` | Dev command: open the real service menu anywhere with a spawned craftsman. |

### Service API used by the UI

`W3InfusionService.IsSupportedTarget(item)` (category + exclusion + config gate) and
`FindBestSacrifice(inv, target, out sacrifice, out preview, craftsman)` (highest level gap wins;
category pre-filter before the full `Preview`). The menu sets `debugBypassCraftsman = false` — the
production path always validates the real craftsman.

## Findings (ordered by discovery)

1. **Extra menu tab does not work — flash pages are not data-driven.** Tab *buttons* render
   from script data, but the *page* per state is baked into the SWF: `setState('Infuse')` has no
   frame → blank panel (verified in game twice). The Repair tab carries the UX. (The `.fla`
   sources exist in REDkit, so a new page is technically buildable, but it needs Adobe Animate,
   SWF cooking and a full override of a vanilla SWF — out of scope.)
2. **The Rust w3strings crate produces files the game misreads.** The community encoder
   (`w3stringsr`) produces files the game reads correctly. Strings regenerated with it.
3. **Armor was config-disabled** (M2-era default) — enabled.
4. **Grid performance with hoarder inventories** (~1,000 items): O(n·m) sacrifice scans.
   Now: category pre-filter inside `FindBestSacrifice`, verdicts cached per grid rebuild
   (previously the filter, the price and the label each re-scanned the inventory).
5. **Stale-override trap (recurring class):** full-file vanilla copies are valid only for the
   game version they were taken from.
6. **Grid verdicts are logged per item** (`grid: <item> infusable (sacrifice: <x>, gap N, fee F)` /
   `has no valid sacrifice at this craftsman`).
7. **REDkit ships the Flash sources** (2026-10-17) — `r4data\gameplay\gui_new\actionscript\` and
   `fla\`. The discovery report's "no SWF sources" was wrong. All findings below were read from
   them (details: TECHNICAL_DISCOVERY §13).
8. **Grid froze after the first Infuse click:** Flash waits for `confirmAction()` after every
   confirmation request; the infusion flow never sent it. Fixed.
9. **"Infundieren" label never displayed:** `GetItemDefaultActionName` is dead code in the
   blacksmith menu and Flash hardcodes the panel button text. Fixed via `setButtonData`.
10. **Popup showed no price and literal `\n`:** price never set; WitcherScript strings do not
    process escapes and the field is `htmlText`. Fixed (`SetPrice`, `<br>`).
11. **Money loss at the wrong craftsman:** the grid ignored the craftsman (debug bypass on by
    default), listed items the NPC can't infuse, and a click fell through to the vanilla repair
    path, charging the infusion fee for "repairing" an undamaged item. Fixed.
12. **Body-item sacrifice (critical):** the 2026-10-11 log shows `Body torso medalion` (Geralt's
    torso mesh: armor category, tags `NoDrop,NoShow,Body`) chosen as an armor sacrifice. Executing
    it would have deleted a body part. Now excluded in `IsExcludedItem`.
13. Axes (e.g. `W_Axe06`) share the `steelsword` category and are accepted as steel-sword
    sacrifices — consistent with the game's own category model; noted for balance review.

## Verified in game so far (before the 2026-10-17 fixes)

- Tab bar renders data-driven tabs ✅
- Compile clean with all overrides ✅
- Repair state activates the infusion grid ✅
- Grid filter detects real infusable items (NG+ Witcher steel swords, spawned armor) ✅
- Craftsman panel (tier/name/crowns) works with our NPC context ✅

## Test round 2026-10-17 (first launch with the fixes)

- Compile clean ✅ (no script errors in `scriptslog.txt`).
- Real dialogue, journeyman armorer: Repair tab renders as vanilla, infusion grid active, damaged
  item shows **Reparieren** with the repair price ✅.
- **No item was infusable** at that armorer. The log only said "no valid sacrifice"; reasons are
  now logged per item (`grid: <item> (L<n>) not infusable here - <k> candidates: <reason> xN;`).
  Most of the inventory is NG+ Witcher gear (quality 5 → needs a grandmaster by default), so
  this was probably correct behavior, not a bug. Untested parts of the checklist (B–D) remain
  open; `infuseSpawnTestPair` now provides a guaranteed valid pair.
- **`infuseOpenMenu` opened the menu without a state** (empty grid, wrong info panel, no
  `repair state:` log line): passing the bare entity gives `CommonMenu` no default state. Fixed
  by using `W3InventoryInitData { containerNPC, defaultState = 'Repair' }`, as the game's own
  scenes do (`scene_functions.ws`).

### Second round (same day, with `infuseOpenMenu` fixed and a spawned test pair)

- `infuseOpenMenu(true)` opens the Repair page with the infusion grid ✅
- Button label swaps to **Infundieren** for infusable items ✅ (`setButtonData` from script works)
- Popup opens with the fee as price ✅; accept executes ✅ — log:
  `OK: target Skellige Casual Suit 01 level 61 -> 68, sacrifice Light armor 06 consumed, fee 89`.
  After the infusion the grid offers the infused shirt (now L68) as a sacrifice for others,
  i.e. the new level is live in-session.
- **Bugs found, fixed afterwards:**
  - Popup showed raw loc keys (`item_name_skellige_suit01`): `GetItemLocalizedNameBy*` return
    keys, not text; wrapped in `GetLocStringByKeyExt` like vanilla.
  - Popup text overflowed the frame (9 lines at size 24). Geometry read from
    `panel_overlay.fla` (`tfMessage` 481px wide, size 24, ~130px between title and price);
    details now use `<font size='16'>`, the level change stays full size.
  - "Zustand 1 %" for items without durability (casual clothes): the base component sends a
    placeholder `durability = 1`, which the repair panel prints. The vanilla repair grid never
    lists such items; ours hides the line (`durability = 0`). The shirt was never damaged —
    "not repaired" was correct.
- Not yet confirmed: persistence after reload (check the shirt's tooltip: required level 68),
  grid responsiveness after decline.

### Third round (two-step flow)

Run: `infuseSpawnTestPair(true)`, `infuseOpenMenu(true)`, pick *Light armor 01* (Cidarischer
Gambeson, L52) as target, pick *Light armor 06* (Verdenischer Schützengambeson, L61) as sacrifice,
accept. Log: `flow: target Light armor 01 picked`, then `OK: ... level 52 -> 61, sacrifice Light
armor 06 consumed (9 x autogen_fixed_armor_armor added), fee 91`.

- Sacrifice phase renders: headers **Ziel** / **Opfer wählen**, target alone on the left,
  sacrifices on the right, per-pair price in the panel ✅
- Popup: **Ziel: Cidarischer Gambeson (52 -> 61)**, **Opfer: Verdenischer Schützengambeson
  (61)**, recovered + additional materials, note — real names, everything inside the frame ✅
- Stats recalculated from the target's own definition: armor 286 → 331 (+45 = 9 levels × 5),
  required level 52 → 61, value 288 → 341; its own resistances (+7/+10/+15 %) unchanged ✅
- **Persistence:** after save + reload the gambeson still shows 331 armor / level 61 ✅
- **Known limitation (cosmetic):** the panel button label follows the item whose tooltip is
  shown (`OnGetItemData`), the panel itself follows the grid selection. With the mouse hovering a
  different item than the selected one, the label can mismatch (seen: "Abbrechen" while a
  sacrifice was selected). Flash sends no selection event to script (verified in the AS
  sources), so this is not fixable without SWF changes; gamepad/keyboard are unaffected
  (selection and tooltip coincide), and mouse clicks activate the clicked item directly.
- Fourth round (user-reported): Abbrechen returns to step 1 ✅; popup decline and the next
  click behave like vanilla (no freeze) ✅; gating at a swordsmith works as intended ✅; repair
  and repair-all behave like vanilla ✅. Label follows hover, as documented above.

## Test checklist (all passed 2026-10-17; keep for regression rounds)

Deploy with `tools\deploy-mod.ps1 -Dev`, launch with `tools\launch-debug.bat`. Everything below
is unverified until checked off. Log lines go to `Documents\The Witcher 3\scriptslog.txt`
(filter for `[Infusion]`).

**A. Compile + entry (2 min)**
1. Game reaches the main menu → no compile error (`scriptslog.txt` has no errors).
2. Load a save, open the console: `infuseOpenMenu(true)` → service menu opens with a journeyman
   armorer, Repair tab available. (If it doesn't open: walk to any real armorer instead and
   report what happened.)

**B. Grid + label** — first run `infuseSpawnTestPair(true)` (armor pair) and
`infuseSpawnTestPair` (sword pair), then `infuseOpenMenu(true)` for armor, `infuseOpenMenu` for
swords.
3. The Repair tab lists undamaged armor that has a valid sacrifice.
4. Selecting such an item → the panel button reads **Infuse** (DE: Infundieren); selecting a
   damaged item → **Repair**. Log shows no `label: ... not reachable` line.
5. The panel price equals the infusion fee.
6. The log has no `sacrifice: Body ...` lines; the popup never names a body/hidden item as
   the sacrifice.

**C. Two-step flow + popup + handshake**
7. Activate an Infuse item (e.g. Light armor 01) → the grid rebuilds: left header **Ziel** with
   only that item, right header **Opfer wählen** with its valid sacrifices (e.g. Light armor 06),
   each with its own price; "Repair all" is gone.
8. Select the target → button reads **Abbrechen**; activate it → back to the normal grid.
9. Pick the target again, activate a sacrifice → popup: **Ziel: <name> (53 -> 68)** in large
   font, **Opfer: <name> (68)** + materials + note in smaller font, real item names (no
   `item_name_...`), all text inside the frame, fee with coin icon.
10. Decline → still in the sacrifice grid; activate another item → it reacts (no freeze).
11. Accept → "Infusion abgeschlossen", target level = sacrifice level, sacrifice gone,
    durability 100 % (for items with durability), crowns deducted (top bar too), grid back in
    target selection and responsive.

**D. Craftsman gating**
12. `infuseOpenMenu` (journeyman swordsmith): no armor listed for infusion; undamaged armor never
    shows a price; clicking items charges nothing unexpected.
13. Witcher gear at a journeyman: not listed (needs grandmaster by default).

**E. Repair still works**
14. A damaged item: Repair → repaired and charged the repair cost; if infusable it stays in the
    grid with the Infuse label, otherwise it disappears (vanilla).
15. "Repair all" (Space / X) still works.

**F. Persistence**
16. Save, reload: infused item keeps its level and stats; sacrifice still gone; no duplicate.

Cleanup: `infuseDespawnTestSmith`.

## Infuse tab prototype (2026-10-17, verified in game)

Hypothesis: the blank tab of 2026-10-11 (finding 1) came from `HaxGetPanelStateName` mapping the
unknown state to `''`, not from a missing SWF page. Prototype:

- `commonMenu.ws` override: **Infusion** tab after Repair (`panel_title_infusion`, repair icon);
  `"Infuse"` added to `HaxGetPanelStateName`.
- `blacksmithMenu.ws`: script state `'Infuse'`, Flash state `'Repair'` (`SetMenuState`,
  `RefreshMenuState`) — the repair page renders with our grid; the empty-grid text says
  "Kein geeignetes Opferitem verfügbar".
- Infuse tab: infusion targets only, **damaged ones included** (infusion includes the repair),
  same two-step flow, no "Repair all". The Repair tab keeps the unified behavior so both
  variants can be compared side by side.

Test: `infuseSpawnTestPair(true)`, `infuseOpenMenu(true)`, then
1. A sixth tab **Infusion** appears next to Reparieren; switching to it shows the grid (not a
   blank page). Log: `infuse state: infusion-only grid ACTIVE (tab prototype)`.
2. Only infusable items are listed (damaged ones too), all with the Infundieren label and fee.
3. Two-step flow + popup + accept work as in the Repair tab.
4. Switching Infusion ↔ Reparieren works both ways; Reparieren still repairs.
5. Close and reopen the menu while on the Infusion tab — it reopens there without a blank page.

If the page is still blank while the log shows the line from step 1, Flash received `'Infuse'`
directly (some path bypassing `SetMenuState`) — report it and the tab gets reverted.

**Result (2026-10-17):** the tab renders the grid (no blank page) — hypothesis confirmed: the
old blank tab came from `HaxGetPanelStateName`, not from the SWF. Two-step flow, Ziel/Opfer
grid and popup work in the tab. Follow-ups found in this round:
- The button showed "Reparieren" until the first hover (Flash's `setMenuState` resets it) —
  fixed: the tab sets the Infuse label right after the state change.
- Witcher gear was not listed at the journeyman armorer — correct: quality 5 needs a
  grandmaster by default (log: "this craftsman is not qualified for this equipment").
- The rejection log exposed a **level-formula bug**: boots/pants/gloves used the chest-armor
  formula (NG+ Witcher boots computed as L18). Fixed to the per-slot values from
  `gameParams.ws`; infusions of those slots would previously have aborted (rolled back).
- Red X on a sacrifice slot is vanilla: the item's required level exceeds Geralt's.
- Next: decide tab vs. Repair tab and move `commonMenu.ws` to annotations
  (docs/ROADMAP_IDEAS.md §1, §3).

## Cost display round (2026-10-18)

- Popup: inline material icons render ✅. Bug: each material listed twice — `Preview`
  appended to reused arrays (menu's stored preview, `FindBestSacrifice`'s loop, the dev
  self-test's `Execute`). Fixed by clearing the lists in `Preview`; in-game menu infusions were
  charged correctly (fresh struct in `ConfirmInfusion`).
- Infuse tab now uses Flash's **Disassemble** page: the info panel shows the materials still
  to pay as icon slots with green/red "have/need", following the selection. **Verified in
  game:** e.g. Lederstücke 5/2 (recipe 2, no salvage) and Zwirn 112/1 (recipe 4 − 3 salvaged),
  same row in step 1 and step 2 for identical sacrifices. Layout trade-offs of the Disassemble
  page: pliers icon in the middle column, no item picture/condition in the panel, price box at
  the bottom. (A compile error on the first try — `entry` is a reserved word — was fixed.)

Test: `infuseSpawnTestPair(true)`, `infuseOpenMenu(true)`, Infusion tab:
1. Info panel (right) shows item icon, price and up to 5 material slots under it with icon,
   name and a green/red `have/need` (e.g. `61/2`); the button reads Infundieren.
2. Step 2 (after picking the target): the slots change per selected sacrifice; the target
   itself shows no slots.
3. Popup lists each material once.
4. If the panel shows "cannot be dismantled" warnings or the Zerlegen label, report it.

## Consistency round (2026-10-18)

User report: the panel showed different materials than the popup, and the E label still
followed hover.
- Materials were consistent but misleading: the panel shows what the player pays; the popup's
  "recovered" line listed the sacrifice's full breakdown, most of which the recipe doesn't use
  (discarded, spec §5.4). The popup now shows only the covered part ("Durch Opfer gedeckt",
  `preview.covered`) next to "Zusätzliche Materialien" — the same numbers as the panel.
- Infuse tab buttons: E is always "Infundieren"; **Space / X = "Abbrechen"** while choosing a
  sacrifice (second key, label + event script-controlled). No more hover dependency in this
  tab. Check in game that the "Abbrechen" hint is visible (key-hint bar) on the Disassemble page.

## Balancing round (2026-10-18)

New model (docs/BALANCING.md) verified in game with Zireael armor (61 → 65): recipe from its
own components, sacrifice covers silk/straps, panel and popup agree, fee 165. Found: the popup
still opened with a material shortfall (glowing ingot 1/3) → fixed: missing materials stop the
flow before the popup with a localized notification naming them.
- Follow-ups: the notification overlay briefly covered the menu (felt like flicker) →
  sacrifices with missing materials are now disabled (`disableAction`: greyed panel, no E
  button, denied sound, warning line "Fehlende Materialien" on the Disassemble page). A
  Redanian armor's recipe asked for a unique insignia → recipes keep only crafting/alchemy
  ingredients (docs/BALANCING.md).

## Tab decision and release polish (2026-10-19)

The user confirmed the last round (missing-materials state, insignia filter, level refactor,
Zerlegen warning text, normal infusion) and chose the **Infuse tab**. Changes:
- **Repair tab back to vanilla:** grid, routing, button label and "repair all" untouched by the
  mod; the unified Repair-tab variant and its hover-dependent label are gone.
- **Log volume:** the per-item `grid:` lines only appear with debug logging
  (`DEBUG_LOGGING` in `InfusionConfig.ws`, or `infuseSetConfig debug 1`). Transaction results
  (OK / ABORT) are always logged.
- **Localized rejections:** notifications use `InfusionErrorToLocString` (12 new w3strings keys,
  en/de); `InfusionErrorToString` stays the English log text.
- **Master switch:** `EnableInfusion = false` now empties the tab (service-level check) instead of
  falling back to the repair grid on the Disassemble page.
- **Silver swords enabled** (had been off since M2; same mechanism as steel, `autogen_fixed_silver_dmg`
  verified in TECHNICAL_DISCOVERY).
- **Bug fixed — salvage toggle:** with salvage disabled the discount still applied and the
  remaining materials were not charged (free infusions). Now: no salvage → full recipe, always
  charged.

Test round (next launch): see "Test checklist 2026-10-19" below.

### Test checklist 2026-10-19

Setup: `infuseSpawnTestPair(true)`, `infuseOpenMenu(true)` (armorer) or `infuseOpenMenu()`
(swordsmith).
1. Compiles; `scriptslog.txt` has **no** `grid:` lines; `infuseSetConfig debug 1` brings them back
   after reopening the menu.
2. **Reparieren** tab: vanilla — only damaged items, "Reparieren" label, repair and "repair all"
   work; undamaged items are not listed.
3. **Infusion** tab: unchanged from the last round (two steps, cost row, disabled sacrifices,
   Space cancels).
4. **Silver sword** at a swordsmith: infuse one; level, stats and durability correct.
5. **Steel sword** at a swordsmith (blacksmith specialization in the real menu).
6. **Runes / glyphs:** infuse an item with an upgrade socketed; the upgrade is still there.
7. **Salvage off:** `infuseSetConfig salvage 1`, reopen the menu: the cost row shows the full
   recipe (nothing "covered"), and an infusion deducts exactly those materials.
   `infuseSetConfig salvage 0` afterwards.
8. Any rejection notification appears in German (they are rare now — the grid pre-filters).
9. **Annotation spike** (`commonMenu.ws` override removed, `InfusionMenuTab.ws` instead):
   - the game compiles — if not, send the first `scriptslog.txt` error (likely an
     annotation rule); `git revert` of the spike commit restores the override;
   - the Infusion tab appears **right after Reparieren**, and opening/closing the menu on it
     works as before;
   - **regression:** the other menus built by `CR4CommonMenu` look normal — inventory, crafting
     (Handwerk), alchemy, and an enchanter if one is at hand (Enchanting + Add sockets tabs).

## Scenario tests (2026-10-19)

`infuseScenarioAll` (tests/modInfusion/README.md) covers the service-level checks in one
command. First run: 12/22 (see docs/SPEC_COVERAGE.md); its fee check found that **master
armorers charged the journeyman fee** (tier read as smith) — fixed. In the menu, master
armorers now show 1.5× the journeyman fee. Second run: **22/22 PASS**.

## Annotation port of blacksmithMenu.ws (2026-10-19)

The mod no longer overrides any vanilla script. Events can't be annotated, so each event hook
moved to a function vanilla calls from that event:

| Old override | Now |
| --- | --- |
| `OnConfigUI` creates service + grid | first `ApplyMenuState('Infuse')` creates them (`InfusionEnsureInit`, craftsman from `GetMenuInitData()`) |
| `OnRequestConfirmation` routes Infuse clicks | `ProcessRequestConfirmation` wrapper (vanilla calls it for every non-standalone click) |
| `OnGetItemData` re-applies the label | `ShowItemTooltip` wrapper |
| `RefreshMenuState` override | `@wrapMethod(CR4MenuBase)` — inherited methods must be wrapped in the declaring class |
| `OnRepairAllItems` + key label: Space cancels | **dropped**: the event opens the repair-all popup via the native `RequestSubMenu` (natives can't be wrapped outside mod.io mods). Flash only sends Space while the key has a label (BlacksmithMenu.as), and the Disassemble page clears it, so vanilla is safe in the Infuse tab. |

Unverified until the next launch: wrappers/added methods reading the menu's **private** fields
(`_curInv`, `m_sectionsList`, `m_menuInited`, `m_standaloneMode`); conditional `wrappedMethod`
calls; another file's class (the popup) calling an `@addMethod` method.
Fallback: `git revert` of the port commit restores the override.

**Port test (2026-10-19): all 7 points passed.** Follow-ups: the long header overflowed the
target section → shortened to "Ziel (E: abbrechen)". User idea: E = "Abbrechen" on the selected
target, "Infundieren" on sacrifices. Flash's grid sends `OnInventoryItemSelected(id)` on every
selection change (SlotsListGrid.as `handleSelectChange`; click/keyboard/gamepad, not hover); the
blacksmith menu never handled it. Experiment: an `@addMethod` function of that name (events
can't be annotated) drives the label from the selection. If the engine doesn't deliver Flash
calls to non-event functions, nothing changes (constant label; no `selection event received`
log line).

Check next launch: in step 2, select the target → E reads **Abbrechen**; select a sacrifice →
**Infundieren**; hovering other items does not change it. Log: `selection event received`.

### Test checklist (port)

1. Compiles. If not: first `scriptslog.txt` error.
2. `infuseScenarioAll` still 22/22 (service unchanged — sanity check).
3. `infuseOpenMenu(true)` → **Infusion** tab: grid, cost row, E = Infundieren, empty-grid text,
   "Fehlende Materialien" on a disabled sacrifice; the **Zerlegen** tab shows its vanilla warning.
4. Step 2: header "Ziel – erneut wählen zum Abbrechen" (readable, not cut off); selecting the
   target cancels; switching tabs cancels; a sacrifice opens the popup; accept infuses, decline
   does nothing.
5. **Space in the Infusion tab does nothing** (no repair-all popup) — in step 1 and step 2.
6. Close the menu on the Infusion tab and reopen it: opens on the tab with the grid (no blank page).
7. Reparieren / Zerlegen / Sockel tabs behave like vanilla (repair, repair all, dismantle).

## Open items

1. **Compatibility (M7):** no vanilla script override left (pending the port test). Remaining
   conflict surface: `@replaceMethod HaxGetPanelStateName` (a second replacement elsewhere fails
   to compile); other mods hooking the same blacksmith methods chain with ours.
2. **Rejection reasons in the grid (spec §9.3):** items that can't be infused here are hidden
   without a reason (e.g. Witcher gear at a journeyman). See docs/SPEC_COVERAGE.md.
3. Optional hint in the empty step-2 target panel; tooltip `WarningMessage` idea
   (docs/ROADMAP_IDEAS.md).

## Risk assessment

All runtime unknowns from the Flash analysis resolved in game: `GetMemberFlashObject` /
`setButtonData` work from script, the popup layout fits, `infuseOpenMenu` opens the real service
menu. Execution always re-validates in `Execute`, so UI defects cannot consume items incorrectly.
