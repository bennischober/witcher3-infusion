# Roadmap ideas and tooling notes

Open ideas with a feasibility assessment, to pick up deliberately. Nothing here is implemented.
Spec gaps and their priority: [SPEC_COVERAGE.md](SPEC_COVERAGE.md).

## 1. Tooling

- **WolvenKit-7** ([GitHub](https://github.com/WolvenKit/WolvenKit-7), GPL-3.0): REDengine 3
  tool with W3Strings, bundle and Scaleform support. Remastered 5.x support not stated — verify
  before relying on it. Useful for extracting cooked assets (e.g. confirming a shipped SWF matches
  the REDkit sources). Use externally; don't vendor (GPL).
- **Separate tooling repo / submodule:** not worth it while one mod uses the tools.

## 2. Optional extension (spec §11, M8)

Bonus merging as a separate module: needs an extension point in the core transaction first
(§11.3: proposed changes validated by the core before commit). Since wrapping the mod's own
classes works, the extension point can be an empty seam method the module wraps
(SPEC_COVERAGE §11).

## 3. Road to 1.0

**Why 0.9 is a beta.** No bug is known; what's missing is exposure. One tester on one setup
(keyboard and mouse), so these are unconfirmed:

- gamepad play (the step-2 header's device switch included);
- 16 of the 18 languages (unreviewed, never seen in game; Arabic display untested);
- long New Game+ runs (KNOWN_ISSUES "Prices");
- other mods next to it (KNOWN_ISSUES "Compatibility").

**1.0 when:**

- [ ] a gamepad pass (UI.md checklist item 9), by a player who has one;
- [ ] a look at a few languages in game (switch the game language, open the menu): texts fit,
      CJK and Cyrillic render; Arabic if possible;
- [ ] some weeks of player feedback without crash, lost-item or wrong-charge reports;
- [ ] a scaling mod and a blacksmith/inventory UI mod tried alongside it.

**Refinement candidates** (small, inside the current no-override approach):

- **Projected stat for blunt weapons:** the popup leaves the line out for maces (their primary
  stat isn't the one the step raises, TECHNICAL_DISCOVERY §3). Option: project the damage the
  step adds instead; needs a check of what the tooltip shows for them.
- **Target's runes and glyphs in the panel:** the Disassemble panel's three rune slots
  (`socketsData`, UI.md Flash table) now show the sacrifice's returned upgrades on step-2
  sacrifice rows. The target's installed upgrades could fill them on step-1 rows and the step-2
  target row, which send none; mixing both meanings in one slot row may confuse, so wait for the
  in-game look of the returned-upgrades use first (no caption, may read as more materials).
- **Step-1 button label:** constant per item (UI.md); only worth it if a single label reads
  better for both steps than "Infuse".

**Out of reach without replacing the game's menu.** The layout (pliers icon, no item picture or
condition bar), the 5 material slots, the red tooltip bar, a per-item button label and a settings
menu all live in the cooked blacksmith SWF or the broken settings UI (TECHNICAL_DISCOVERY §1–2).
Changing them means shipping a modified `panel_blacksmith` SWF: Adobe Animate and cooking, and it
replaces the vanilla menu for every mod, so it conflicts with any blacksmith or UI mod. Not
planned.
