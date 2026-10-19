# Roadmap ideas and tooling notes

Open ideas with a feasibility assessment, to pick up deliberately. Nothing here is implemented.
Spec gaps and their priority: [SPEC_COVERAGE.md](SPEC_COVERAGE.md).

## 1. Show the sacrifice's effect in its tooltip

In step 2, the tooltip of a valid sacrifice could add "Wird verbraucht · Zusätzlich:
Lederstücke x2" via the tooltip's `WarningMessage` line — the same mechanism that shows block
reasons in step 1 (docs/UI.md). Low effort.

## 2. Tooling

- **WolvenKit-7** ([GitHub](https://github.com/WolvenKit/WolvenKit-7), GPL-3.0): REDengine 3
  tool with W3Strings, bundle and Scaleform support. Remastered 5.x support not stated — verify
  before relying on it. Useful for extracting cooked assets (e.g. confirming a shipped SWF matches
  the REDkit sources). Use externally; don't vendor (GPL).
- **FLA inspection:** a small `tools/fla-inspect.py` (list symbols, dump text-field geometry and
  font sizes from the XFL `LIBRARY/*.xml`) would make layout questions repeatable.
- **Separate tooling repo / submodule:** not worth it while one mod uses the tools.

## 3. Optional extension (spec §11, M8)

Bonus merging as a separate module: needs an extension point in the core transaction first
(§11.3: proposed changes validated by the core before commit).
