# Roadmap ideas and tooling notes

Open ideas with a feasibility assessment, to pick up deliberately. Nothing here is implemented.
Spec gaps and their priority: [SPEC_COVERAGE.md](SPEC_COVERAGE.md).

## 1. Rejection reasons in the grid (spec §9.3)

Today the Infusion tab hides items this craftsman can't infuse. Goal: show supported items in
step 1 even when they can't be infused, disabled, with the reason.

Building blocks:

- `disableAction` on the grid item greys the info panel and blocks E (already used for missing
  materials). Its warning line is **one text per page**, set by script, so it can't carry a
  per-item reason by itself.
- The **item tooltip** is built by script (`ShowItemTooltip` → `W3TooltipComponent.GetTooltipData`)
  and describes the *hovered* item, so a per-item text there is consistent with what the player
  points at. Vanilla sets a `WarningMessage` line on it (`guiTooltipComponent.ws`), rendered by
  `TooltipInventory.as` (`tfWarningMessage`). `ShowItemTooltip` is already wrapped.
- Reasons come from the service: `FindBestSacrifice` records rejection counts per error
  (`DescribeLastScan`); map the dominant one to `InfusionErrorToLocString`.

Plan: in step 1 also list supported-but-not-infusable items with `disableAction`; set the
warning line to a generic "Hier nicht infundierbar"; put the specific reason into the tooltip's
`WarningMessage`. One test launch for wording/length.

## 2. Show the sacrifice's effect in its tooltip

In step 2, the tooltip of a valid sacrifice could add "Wird verbraucht · Zusätzlich:
Lederstücke x2" via the same `WarningMessage` line. Low effort once §1 exists.

## 3. Tooling

- **WolvenKit-7** ([GitHub](https://github.com/WolvenKit/WolvenKit-7), GPL-3.0): REDengine 3
  tool with W3Strings, bundle and Scaleform support. Remastered 5.x support not stated — verify
  before relying on it. Useful for extracting cooked assets (e.g. confirming a shipped SWF matches
  the REDkit sources). Use externally; don't vendor (GPL).
- **FLA inspection:** a small `tools/fla-inspect.py` (list symbols, dump text-field geometry and
  font sizes from the XFL `LIBRARY/*.xml`) would make layout questions repeatable.
- **Separate tooling repo / submodule:** not worth it while one mod uses the tools.

## 4. Optional extension (spec §11, M8)

Bonus merging as a separate module: needs an extension point in the core transaction first
(§11.3: proposed changes validated by the core before commit).
