# M6 — Production UI: state, findings, open items (2026-10-11)

Status: **core flow implemented and wired; final rendering verification pending.**
Spec: INFUSION_SPEC.md §9 (UI/interaction), §16 Milestone 6.

## What was built

### Entry point and flow (in the blacksmith service UI)

The **Repair tab of the existing blacksmith/armorer menu doubles as the infusion service**
(spec §9.1: extend the existing service interface). Per item in the grid:

| Item state | Action label | Price shown | Confirm does |
| --- | --- | --- | --- |
| Damaged | Reparieren (vanilla) | repair cost | vanilla repair |
| Full durability + valid sacrifice in inventory | **Infundieren** (our label) | infusion fee | infusion confirmation popup |
| Damaged *and* infusable | Reparieren | repair cost | vanilla repair (repair first) |

Confirming an infusion opens `InfusionConfirmationPopupData` — a vanilla
`PriceConfirmationPopup` carrying the full §9.5 transaction summary (target level change,
sacrifice + its level, recovered materials, remaining requirements, permanent-consumption
note). Accept executes via `W3InfusionService.Execute(..., craftsman = _fixerNpc)` — the NPC
the player is actually talking to (spec §8.1).

### Files

| File | Role |
| --- | --- |
| `src/modInfusion/content/scripts/game/gui/menus/blacksmithMenu.ws` | **Override** of vanilla (conflict-free on this install; merge surface documented). Menu wiring: grid swap, Infuse action label, confirmation interception, popup class, memoization. |
| `src/modInfusion/content/scripts/game/gui/menus/commonMenu.ws` | **Override** of vanilla. Tab definitions — the *added Infuse tab was reverted* (see findings #1); file kept as override base for future needs, currently vanilla-equivalent + comments. |
| `src/modInfusion/content/scripts/game/gui/_old/components/guiInfusionInventoryComponent.ws` | **New class** (extends `W3GuiRepairInventoryComponent`): unified service grid, per-item fee, category pre-filter. |
| `src/modInfusion/content/strings/{en,de}.w3strings` | UI labels (settings + button + popup + tab). |
| `tools/strings-sources/infusion_strings_{en,de}.csv` | Editable sources for the strings. |
| `tools/w3stringsr/` | The community Remastered strings encoder (user-provided; not committed). |

### Service API added in M6

`W3InfusionService.IsSupportedTarget(item)` (category+exclusion+config gate) and
`FindBestSacrifice(target, out sacrifice, out preview, craftsman)` (highest level gap wins).
Grid checks are memoized per menu refresh (invalidated on state change / global update /
infusion).

## Findings (ordered by how they were discovered)

1. **Extra menu tab does not work — flash pages are not data-driven.** Tab *buttons* render
   from script data (`panel.main.setup` array), but the *page* per state is baked into the
   SWF: `setState('Infuse')` has no frame → blank panel, regardless of any script-side
   fallback (sending `'Repair'` to Flash afterwards did not recover it — verified in game
   twice). **The tab was removed; the Repair tab carries the UX.** Even FCR3's
   CDPR-affiliated author never added new menu states — only tweaks inside existing panels.
2. **The Rust w3strings crate produces files the game misreads.** Round-trip decoding of our
   own file was clean, but at runtime `GetLocStringByKeyExt` returned binary garbage (the
   strings test caught it: title = `'<binary bytes>'`). The official community encoder
   (`w3stringsr`, id-space `21[n]nnnnNNN`) produces files the game reads correctly — the
   crate apparently differs in id/mask handling. **Strings were regenerated with
   w3stringsr; verification pending.**
3. **Armor was config-disabled** (M2-era default `ENABLE_ARMOR=false`) — the armor test runs
   and grid entries failed with `IFE_DisabledCategory`. Enabled now.
4. **Grid performance with hoarder inventories:** the user's inventory holds ~1,011 items;
   the per-item sacrifice scan is O(n·m) with heavy attribute computation. Mitigated with a
   category pre-filter (cheap name compare before `Preview`). Memoization only dedupes
   repeated queries for the same item.
5. **Stale-override trap (recurring class):** a mod overriding a vanilla file with an
   outdated copy breaks *other* vanilla files that reference the shadowed class (real case:
   pre-5.0 merchant mod broke `content0/gui/inventoryContext.ws` + `PopupData.ws` because
   its 4.04-era `inventoryMenu.ws` lacked 5.01 members). Full-file vanilla copies are valid
   only for the game version they were taken from.
6. **Grid verdicts are logged per item** (`grid: <item> infusable (sacrifice: <x>, gap N)` /
   `not a supported target` / `no valid sacrifice (N candidates)`) — the repair-tab visit
   produces a complete trace of why each item is shown or hidden.

## Verified in game so far

- Tab bar renders data-driven tabs (button visible, icon fine) ✅
- Compile clean with all overrides ✅
- Repair state activates the infusion grid (`repair state: infusion grid ACTIVE`) ✅
- Grid filter detects real infusable items (NG+ Witcher steel swords, spawned armor) ✅
- Craftsman panel (tier/name/crowns) works with our NPC context ✅
- Trader money mini-mod (reinstalled original, rebuilt for 5.01) ✅

## Open items for the next verification round

1. **Grid rendering:** repair tab with spawned armor pieces in inventory — the log says
   "infusable"; does the grid *show* them with the Infundieren label? (Pending — the last
   screenshot predates the armor enable + strings fix.)
2. **Popup rendering:** `InfusionConfirmationPopupData` on a vanilla popup layout with our
   `TextContent` — renders? Labels resolve (strings fix)?
3. **Full flow:** popup → accept → infusion by the real craftsman (Fergus for armor).
4. **Persistence:** save/reload with the infused item.
5. **Settings menu labels:** with the fixed strings, `##option_` labels should resolve.

## Honest risk assessment

If the grid still doesn't *render* the new items after this round, the remaining suspects
are (a) the Flash grid's item-slot count per frame (the repair frame may have a fixed slot
count that ignores extra data — needs a SWF-aware check) or (b) a refresh-timing issue
(`SetFlashArray` before the frame is on screen). Both are diagnosable with the existing
instrumentation; worst case the M6 fallback is the **debug-command flow** (already built and
verified through M2–M4) shipped as the UI, with the popup-based flow as a stretch goal.
