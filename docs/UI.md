# Infusion UI — design, constraints, manual checks

Spec: INFUSION_SPEC.md §9. Engine background: [TECHNICAL_DISCOVERY.md](TECHNICAL_DISCOVERY.md).
The development history (test rounds, rejected variants) is in the git log.

## What the player sees

A dedicated **Infusion** tab in every blacksmith/armorer menu, right after Reparieren (spec §8.1:
the smallest UI extension attached to the existing service). Infusion is a **two-step flow** —
the player picks both items (§9.1); the sacrifice is never chosen automatically.

**Step 1 — target.** Items this craftsman can infuse right now (damaged ones too — infusion
includes the repair). The info panel shows the fee and a crafting-style material row for the
best available sacrifice: icon, name, `have/need` in green or red. E = **Infundieren**.

Items of this craftsman's specialization that **can't** be infused here are listed too, disabled
(greyed panel, no E button, warning "Hier nicht infundierbar - siehe Tooltip"). Their tooltip names
the reason in its warning line (spec §9.3):

| Reason | Tooltip text |
| --- | --- |
| Craftsman's tier too low (relic → master, Witcher gear → grandmaster) | "Benötigter Rang: Meister" (the game's tier name) |
| No other item of the category | "Kein anderer Gegenstand dieser Art" |
| None with a higher level | "Kein höherstufiger Gegenstand" |
| Only equipped items are higher | "Höherstufiger Gegenstand angelegt" |
| Excluded gear: quest item, Aerondight, merchant-range item (spec §14.2) | "Kann nicht sicher infundiert werden" |

The tooltip's warning line holds one line (~40 characters at its font size); longer text wraps
over the item name, so keep reasons short.

Items of the other specialization (swords at an armorer) and hidden/body items stay hidden.

**Step 2 — sacrifice.** The grid is rebuilt with two sections: **Ziel (E: abbrechen)** (the picked
item) and **Opfer wählen** (every valid sacrifice), each priced for that exact pair. Selecting a
sacrifice and pressing E opens the confirmation; selecting the target again, or switching tabs,
returns to step 1. A sacrifice whose remaining materials are missing is **disabled** (greyed
panel, no E button, denied sound, warning "Fehlende Materialien"). A sacrifice's tooltip shows
how much of the recipe it covers in its warning line ("Durch Opfer gedeckt: 7/18", material
units: covered / recipe total); without material requirements the line is left out.

**Confirmation popup** (vanilla price popup): "Ziel: … (61 -> 68)", the projected primary stat
with the tooltip's label ("Rüstung: 129 -> 164"; spec §9.2), "Opfer: … (68)", materials
covered by the sacrifice and additional materials (inline icons), the permanent-consumption and
full-repair note, and the fee. Accept executes the infusion with the NPC the player is talking
to; the craftsman receives the fee, as with vanilla repairs. A successful infusion returns to
step 1, a failed one stays in step 2.

Rejection messages are localized (`InfusionErrorToLocString`, en/de).

## How it is built

No vanilla script is overridden — everything hooks in through REDkit script annotations.

| File | Role |
| --- | --- |
| `game/infusion/InfusionMenuTab.ws` | `@wrapMethod CR4CommonMenu.DefineSceneMenuStructure` inserts the tab after Repair; `@replaceMethod HaxGetPanelStateName` (global) adds `"Infuse"` — unknown states map to `''`, which made the tab blank in the first attempt. |
| `game/infusion/InfusionBlacksmithMenu.ws` | Fields and helpers via `@addField`/`@addMethod`; wraps `SetMenuState`, `ApplyMenuState`, `SetSectionsDataList`, `InventoryUpdateAll`, `ShowItemTooltip`, `ProcessRequestConfirmation` and `CR4MenuBase.RefreshMenuState`. |
| `game/infusion/InfusionConfirmationPopup.ws` | Popup data class (extends `ConfirmationPopupData`). |
| `game/gui/_old/components/guiInfusionInventoryComponent.ws` | Grid component (extends `W3GuiRepairInventoryComponent`): the two phases, craftsman-aware verdicts and block reasons (`W3InfusionService.GetBlockReason`) cached per grid rebuild, fee + material row + `disableAction` per item. |

Key mechanics:

- **Flash has no page for `'Infuse'`.** The script tells Flash `'Disassemble'` and keeps
  `'Infuse'` itself (`SetMenuState`, `RefreshMenuState`). The Disassemble page's info panel
  (`ItemDisassembleInfo.as`) shows `item.partList` as up to 5 icon slots — the cost row.
- **Events can't be annotated**, so each event hook goes through a function vanilla calls from
  that event: clicks (`OnRequestConfirmation` → `ProcessRequestConfirmation`), the tooltip
  (`OnGetItemData` → `ShowItemTooltip`). The service and grid are created on the first
  `ApplyMenuState('Infuse')` instead of in `OnConfigUI`.
- **Every confirmation request must be answered** with `HandleActionConfirmation(false)`: Flash
  waits in its Confirmation state otherwise. In the Infuse tab no click may reach the vanilla
  path — Flash shows the Disassemble page there, so a vanilla `true` would dismantle the item.
- **Button label:** Flash hardcodes it; the script sets it through the panel's own
  `setButtonData(label, "enter-gamepad_A", 69)`.
- **Block reasons in the tooltip:** the `ShowItemTooltip` wrapper builds the tooltip data like
  vanilla and sets its `WarningMessage` line (vanilla uses it for "not for sale"; rendered by
  `TooltipInventory.as`). The tooltip follows the hovered item, which is the item the reason
  belongs to. In step 2 the same line carries a sacrifice's recipe coverage
  (`GetSacrificeCoverText`); a block reason takes precedence. The page's disabled warning line
  is one text per page: "Hier nicht infundierbar"
  in step 1, "Fehlende Materialien" in step 2.
- **Space hint off:** after the Repair tab, the vanilla "repair equipped items" Space hint
  stayed in the Infuse tab's bottom bar although every label update was correct (debug log). The
  bar is the script-side binding list (`CR4MenuBase.m_GFxInputBindings`, action 1002), and
  Flash's removal didn't reach it. The tab clears Flash's label (`setXActionLabel("")`), removes
  the binding and refreshes the bar whenever it sets its button label. With
  `infuseSetConfig('debug', 1)` menu-state changes are logged.

## Flash protocol facts (REDkit ActionScript sources)

Sources: `r4data\gameplay\gui_new\actionscript\red\game\witcher3\menus\blacksmith\*.as`,
`menus\overlay\PriceConfirmationPopup.as`, `slots\SlotsListGrid.as`.

| Topic | Behavior | Consequence |
| --- | --- | --- |
| Action flow | `Selection → Confirmation → Waiting`; `OnRequestConfirmation(id, actionPrice)` then waits for `confirmAction(bool)`. `false` = back to selection, no side effects. | Infusion paths always answer `false`. |
| Grid | Renders whatever array arrives on `repair.grid.player`; per-item gate `disableAction`. | Visibility, price and disabled state are fully script-controlled. |
| Space / X | Sent (`OnRepairAllItems`) only while `_xActionLabel` is non-empty; the Disassemble page clears it. | The vanilla handler can't fire in the Infuse tab. |
| Price popup | `tfMessage.htmlText = TextContent`; price shown only when `ItempPrice > 0`; ~481×130 px of text. | `<br>` line breaks (WitcherScript has no `\n` escapes); details at font size 16; inline `<img src='img://…'>` icons render. |
| Selection | The grid reports selection changes (`OnInventoryItemSelected`), but Flash calls reach **script events only**, and annotations can't add events. `OnGetItemData` follows the mouse hover. | The script never knows the *selected* item → constant E label; the section header names the cancel action. |

## Known limitations

- The E label is the same for every item (see above); selecting the target again cancels.
- Layout of the Disassemble page: pliers icon in the middle column, no item picture/condition in
  the panel.
- Axes share the `steelsword` category and infuse with swords (the game's own category model).

## Manual UI checklist

The service logic is covered by `infuseScenarioAll` (tests/modInfusion/README.md). The UI needs a
launch: `infuseSpawnTestPair(true)`, `infuseOpenMenu(true)`, Infusion tab.

1. Compiles (`scriptslog.txt`: no errors).
2. Step 1: infusable items with cost row (green/red `have/need`), E = Infundieren. Blocked items
   (e.g. Witcher gear at a journeyman, your highest-level piece) are greyed with "Hier nicht
   infundierbar - siehe Tooltip"; hovering shows the reason in the tooltip's warning line; E does
   nothing on them. The reason fits on one line; no Space hint and Space does nothing, also when coming from
   Reparieren.
3. Step 2: headers "Ziel (E: abbrechen)" / "Opfer wählen"; per-sacrifice fee and row; a sacrifice
   with missing materials is disabled with "Fehlende Materialien". Hovering a sacrifice shows
   "Durch Opfer gedeckt: n/m" on one line in its tooltip; the target's tooltip has no such line.
4. Selecting the target again cancels; switching tabs cancels; Space does nothing.
5. Popup: names, levels, projected stat (matches the tooltip after infusing), covered/additional
   materials with icons, note, price — everything inside the frame; accept infuses
   (level, crowns, materials, sacrifice gone), decline changes nothing.
6. Close and reopen the menu on the Infusion tab: it reopens there with the grid.
7. Reparieren / Zerlegen (vanilla warning text) / Sockel behave like vanilla.
8. Save, reload: the infused item keeps its level.
