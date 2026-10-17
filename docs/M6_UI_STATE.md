# M6 — Production UI: state, findings, open items (updated 2026-10-17)

Status: **functionally complete — the full checklist passed in game (2026-10-17).** Remaining
work is release polish (see "Open items before release").
Spec: INFUSION_SPEC.md §9 (UI/interaction), §16 Milestone 6.
Flash protocol reference: docs/TECHNICAL_DISCOVERY.md §13.

## What was built

### Entry point and flow (in the blacksmith service UI)

The **Repair tab of the existing blacksmith/armorer menu doubles as the infusion service**
(spec §9.1: extend the existing service interface). Infusion is a **two-step flow** — the player
picks both items (spec §9.1); the sacrifice is never chosen automatically.

**Step 1 — target selection** (normal Repair tab):

| Item state | Panel button | Price shown | Activating does |
| --- | --- | --- | --- |
| Damaged | Repair (vanilla) | repair cost | vanilla repair |
| Full durability + at least one valid sacrifice + eligible craftsman | **Infuse** (swapped via Flash `setButtonData`) | fee with the highest-level sacrifice | picks it as the target → step 2 |
| Damaged *and* infusable | Repair | repair cost | vanilla repair; the item then stays in the grid as an infusion target |
| Full durability, not infusable here | — (not listed) | — | — |

**Step 2 — sacrifice selection** (same grid, rebuilt): section headers become **Target** (the
picked item) and **Choose a sacrifice** (every valid sacrifice for it at this craftsman); "Repair
all" is hidden.

| Item | Panel button | Price shown | Activating does |
| --- | --- | --- | --- |
| The target (section "Target") | **Cancel** (vanilla `panel_common_cancel`) | — | back to step 1 |
| A sacrifice | **Infuse** | fee for this exact pair | confirmation popup |

Switching tabs also returns to step 1; a successful infusion returns to step 1, a failed one stays
in step 2. Confirming opens `InfusionConfirmationPopupData` — a vanilla
`PriceConfirmationPopup` carrying the §9.5 summary with labeled roles ("Target: … (61 -> 68)",
"Sacrifice: … (68)"), 
recovered materials, remaining requirements, permanent-consumption + full-repair note) and the
fee as the popup price. Accept executes via `W3InfusionService.Execute(..., craftsman)` with the
NPC the player is talking to (spec §8.1); the craftsman receives the fee, as with vanilla repairs.
Accept, decline and every rejection answer Flash with `confirmAction(false)`.

### Files

| File | Role |
| --- | --- |
| `src/modInfusion/content/scripts/game/gui/menus/blacksmithMenu.ws` | **Override** of vanilla (conflict-free on this install; changes marked `modInfusion`). Grid swap, confirmation routing, Flash handshake, per-item button label, popup class. |
| `src/modInfusion/content/scripts/game/gui/_old/components/guiInfusionInventoryComponent.ws` | **New class** (extends `W3GuiRepairInventoryComponent`): unified service grid, craftsman-aware verdicts cached per refresh, per-item fee. |
| `src/modInfusion/content/strings/{en,de}.w3strings` | UI labels (button + popup + notifications). |
| `tools/strings-sources/infusion_strings_{en,de}.csv` | Editable sources for the strings. |
| `tools/w3stringsr/` | The community Remastered strings encoder (user-provided; not committed). |
| `tests/.../InfusionDebug.ws` → `infuseOpenMenu` | Dev command: open the real service menu anywhere with a spawned craftsman. |

`commonMenu.ws` is overridden again **for the Infuse-tab prototype only** (2026-10-17, see
"Infuse tab prototype"); if the Repair-tab variant wins, the override goes away.

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

## Infuse tab prototype (2026-10-17, untested)

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

## Open items before release

1. **Log volume:** the grid writes one `[Infusion] grid:` line per item on every refresh (useful
   for diagnosis, noisy for players). Gate behind a debug flag before release.
2. **Error messages are English-only:** `InfusionErrorToString` is used for in-game
   notifications (e.g. missing materials). Move to w3strings keys (en/de).
3. **Label follows hover** (cosmetic, not fixable without SWF changes) — mention in known issues.
4. **Dedicated Infuse tab (optional):** likely feasible after all. The earlier blank page
   (finding 1) was probably not a missing Flash page: `HaxGetPanelStateName` in `commonMenu.ws`
   maps unknown tab states to `''`, and the old attempt never added `"Infuse"` there, so the
   blacksmith menu received an empty state. Needs a `commonMenu.ws` override again (conflict
   surface) — decide before release.
5. **M7 work:** release packaging, compatibility notes for the vanilla override
   (`blacksmithMenu.ws`), installation docs.

## Risk assessment

All runtime unknowns from the Flash analysis resolved in game: `GetMemberFlashObject` /
`setButtonData` work from script, the popup layout fits, `infuseOpenMenu` opens the real service
menu. Execution always re-validates in `Execute`, so UI defects cannot consume items incorrectly.
