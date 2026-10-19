# Roadmap ideas and tooling notes (2026-10-17)

Collected ideas with a feasibility assessment, so they can be picked up deliberately instead of
all at once. Nothing here is implemented unless stated.

## 1. UI: Infuse tab vs. Repair tab

**Decided 2026-10-19: Infuse tab.** Infusion was stripped from the Repair tab, which is vanilla
again (docs/M6_UI_STATE.md). Moving the `commonMenu.ws` change to annotations (§3) is still open.
The options as they were weighed:

- **Infuse tab:** clearer (infusion is its own service, Repair stays vanilla, damaged items can
  be infused directly). Costs a `commonMenu.ws` change — see §3 for doing it without a file
  override.
- **Repair tab only:** no `commonMenu.ws` change at all; mixed Repair/Infuse labels in one grid.

If §3 fails, the tab stays a `commonMenu.ws` override (documented conflict surface).

## 2. Show the required materials at the sacrifice (user idea)

Goal: while choosing the sacrifice, see what it recovers and what you still have to pay, at the
item itself rather than only in the popup.

Verified building blocks:

- The info panel (`ItemRepairInfo`) has no free text field — only icon, durability and price
  from the item data. Writing into its text fields from script would follow the *hovered*
  item (`OnGetItemData`) while the panel shows the *selected* one (same mismatch as the button
  label), so the panel is the wrong place.
- The **item tooltip** is built by script (`CR4BlacksmithMenu.ShowItemTooltip` →
  `W3TooltipComponent.GetTooltipData`) and always describes the hovered item. Vanilla sets a
  `WarningMessage` line on it (`guiTooltipComponent.ws`: "not for sale"), which Flash renders in
  `TooltipInventory.as` (`tfWarningMessage`).

Plan (small): in the sacrifice phase, after `GetTooltipData`, set `WarningMessage` for valid
sacrifices to e.g. "Wird verbraucht · Zusätzlich: Lederstücke x2, Zwirn x1" (from the pair's
preview). Needs 1–2 new strings. One test launch to check line length/wrapping.

### 2b. Material icons like the crafting menu (user idea)

- The crafting menu's icon list is a Flash module (`RequiredIngredientsListModule`, used by
  `CraftingMenu.as`, `AlchemyMenu.as`, `EnchantingMenu.as`). It is **not** in
  `panel_blacksmith.fla` or `panel_overlay.fla` (popup) — reusing it would mean SWF editing
  (out of scope).
- **Inline icons in text are plausible:** both the popup message and the tooltip warning line
  are `htmlText`, and vanilla embeds images in such text (`localizedContent.ws`
  `GetHTMLForItemICO`: `<img src="ICO_....png" vspace="-10" />`). Those are UI-library symbols,
  though; item icons are textures loaded at runtime via `img://` + `GetItemIconPathByName`
  (`PopupData.ws`, `W3UILoader.as`). Whether Scaleform resolves `<img src="img://icons/...">`
  inside `htmlText` in this engine is **unverified**.
- Experiment (small, harmless if unsupported — worst case an empty box or nothing): prefix each
  material in the popup with `<img src='img://<icon path>' width='20' height='20'
  vspace='-5'>`. Line height grows with the icons, so the popup layout budget (~130px) needs a
  recheck — or show icons only for the additional (paid) materials.
- **Result 2026-10-18:** inline `img://` item icons **render** in the popup's `htmlText`
  (18×18, `vspace='-4'`) — verified in game. The same round showed every material listed twice
  (root cause: `Preview` appended to reused arrays — fixed in the service).
- **Crafting-style cost row (user idea, built 2026-10-18, untested):** the Infuse tab now
  renders Flash's **Disassemble** page, whose info panel lists `item.partList` as icon slots
  (`ItemDisassembleInfo.as`, max 5) and follows the grid *selection*. The grid fills it with
  the materials still to pay: icon, name, and `quantity` as htmlText
  `<font color='#57D338|#EC1212'>have/need</font>` (green/red like crafting).

## 3. Remastered script annotations instead of full-file overrides (user idea)

Official REDkit docs ([WS Script Compilation Errors / overrides](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/36241598/WS+Script+Compilation+Errors+overrides),
introduced with the 2024-06-06 patch) document four annotations, written in a **new `.ws` file**:

| Annotation | Effect | Notes |
| --- | --- | --- |
| `@wrapMethod(Class) function F(...) { wrappedMethod(...); ... }` | wraps a method; must call `wrappedMethod` | chainable across mods (compatible) |
| `@replaceMethod(Class) function F(...)` | replaces a method | **global functions: omit the class** (`@replaceMethod function F()`) |
| `@addMethod(Class) function F()` | adds a method | |
| `@addField(Class) var x : T;` | adds a field | |

Not stated in the docs: whether events (`event OnX`) can be wrapped, private-member access from
wrappers, and whether loose scripts in `mods\` support annotations without a cooked
`precompiled.rsblob` (our skill note says some cases need precompiled scripts — unverified).

Migration plan, smallest first (one test launch each):

1. **`commonMenu.ws` → annotations (spike) — implemented 2026-10-19, in-game test pending**
   (`src/.../game/infusion/InfusionMenuTab.ws`; tab inserted into `m_menuData` after Repair). `@wrapMethod(CR4CommonMenu) DefineSceneMenuStructure`
   (call the original, then add/insert the Infuse tab) + `@replaceMethod function
   HaxGetPanelStateName` (vanilla body + `"Infuse"`). Removes the 2,400-line override. Tab order
   may need an insert into `m_menuData` instead of an append.
2. **`blacksmithMenu.ws` → annotations — implemented 2026-10-19, in-game test pending.** Events
   can't be annotated (parser expects `function` after the annotation); each event hook moved to
   a function vanilla calls from it (docs/M6_UI_STATE.md, "Annotation port"). Space-to-cancel
   was dropped (native `RequestSubMenu`).
3. Update the skill reference (`.opencode/skills/witcher-script/references/debugging-and-remaster.md`)
   with the verified facts.

Payoff: no full-file overrides → no script merging for users, no stale-copy trap after game
updates. This is the most valuable item for release (M7).

## 4. Tooling

**Strings (`.w3strings`).** `tools/w3stringsr/` (community encoder, user-provided, not committed)
works and is byte-reproducible on our sources (verified 2026-10-17). The old Rust crate under
`tools/w3strings-tool/` produced files the game misread (M6 finding 2) — candidate for removal
or a clear "deprecated" note. No need to write another encoder.

**WolvenKit-7** ([GitHub](https://github.com/WolvenKit/WolvenKit-7)): open-source REDengine 3
modding tool (GPL-3.0) with W3Strings, Bundles and Scaleform projects. Remastered 5.x support is
not stated on the page — verify before relying on it. Useful mainly for **extracting cooked
assets from the game bundles** (e.g. confirming the shipped `panel_blacksmith` SWF matches the
REDkit sources). Use as an external tool; don't vendor its code (GPL).

**FLA/ActionScript inspection.** The REDkit `.fla` files are zip archives (XFL); symbol layouts
live in `LIBRARY/*.xml` (some archives have a slightly malformed central directory — `unzip`
copes, Python's `zipfile` does not). A small `tools/fla-inspect.py` (list symbols, dump text
field geometry/font sizes) would make layout questions like the popup sizing repeatable.

**Separate repo / submodule?** Not yet. Submodules pay off for code we own and reuse across
projects; today that would be a deploy script, a strings wrapper and a log/FLA helper — a
`tools/` folder covers it. Third-party binaries (w3stringsr, WolvenKit) should not be committed
or vendored; document version, source and checksum instead (a `tools/README.md`). Revisit when a
second mod reuses the tooling.

## 5. Release polish (from M6)

- Gate the per-item `[Infusion] grid:` logging behind a debug flag.
- Localize the failure notifications (`InfusionErrorToString` is English-only).
- Known issue: the panel button label follows hover, not selection (Flash limitation).
