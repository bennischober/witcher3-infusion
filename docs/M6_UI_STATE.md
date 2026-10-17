# M6 — Production UI: state, findings, open items (updated 2026-10-17)

Status: **core flow implemented; Flash protocol verified from source; in-game verification of the
2026-10-17 fixes pending** (checklist below).
Spec: INFUSION_SPEC.md §9 (UI/interaction), §16 Milestone 6.
Flash protocol reference: docs/TECHNICAL_DISCOVERY.md §13.

## What was built

### Entry point and flow (in the blacksmith service UI)

The **Repair tab of the existing blacksmith/armorer menu doubles as the infusion service**
(spec §9.1: extend the existing service interface). Per item in the grid:

| Item state | Panel button | Price shown | Confirm does |
| --- | --- | --- | --- |
| Damaged | Repair (vanilla) | repair cost | vanilla repair |
| Full durability + valid sacrifice + eligible craftsman | **Infuse** (swapped via Flash `setButtonData`) | infusion fee | infusion confirmation popup |
| Damaged *and* infusable | Repair | repair cost | vanilla repair; the item then stays in the grid as an infusion target |
| Full durability, not infusable here | — (not listed) | — | — |

Confirming an infusion opens `InfusionConfirmationPopupData` — a vanilla
`PriceConfirmationPopup` carrying the §9.5 summary (target level change, sacrifice + its level,
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

`commonMenu.ws` is **no longer overridden** (removed 2026-10-17; it differed from vanilla only by
comments after the Infuse tab was reverted).

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

## Test checklist for the next game session

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

**C. Popup + handshake**
7. Activate an Infuse item → popup shows title, 3–5 readable lines (no literal `\n`, no `<br>`
   text), fee with coin icon, text fits inside the frame.
8. Decline → back in the grid; immediately activate another item → it reacts (no freeze).
9. Activate again → Accept → "Infusion complete", target level = sacrifice level, sacrifice
   gone, durability 100 %, crowns deducted; top-bar crowns updated; grid still responsive.

**D. Craftsman gating**
10. `infuseOpenMenu` (journeyman swordsmith): no armor listed for infusion; undamaged armor never
    shows a price; clicking items charges nothing unexpected.
11. Witcher gear at a journeyman: not listed (needs grandmaster by default).

**E. Repair still works**
12. A damaged item: Repair → repaired and charged the repair cost; if infusable it stays in the
    grid with the Infuse label, otherwise it disappears (vanilla).
13. "Repair all" (Space / X) still works.

**F. Persistence**
14. Save, reload: infused item keeps its level and stats; sacrifice still gone; no duplicate.

Cleanup: `infuseDespawnTestSmith`.

## Honest risk assessment

Remaining runtime-only unknowns: (a) whether `GetMemberFlashObject("panelRepair")` resolves from
script (engine import, no vanilla caller — if not, the label stays "Repair" but the flow still
works, and the log says so); (b) popup layout with multi-line text; (c) `infuseOpenMenu` relies on
the spawned template being a `W3MerchantNPC` with crafting enabled, like the dialogue NPCs.
None of these can consume items incorrectly: execution always re-validates in `Execute`.
