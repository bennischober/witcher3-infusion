# Script test-bench feasibility (research notes, 2026-10-10)

Question: can we write WitcherScript tests that run **without launching the game**?
Short answer: **No ready-made framework exists, and a DIY bench is not worth it for this
project.** This document records what was verified, what almost worked, and why we stopped —
so the work is not repeated.

## What was verified

### 1. No test framework ships with the game or REDkit

- The shipped script base (1,525 `.ws` files) contains no test framework, test runner, or
  assert library. The only remnants are two unused helpers in `scripts/core/misc.ws`:
  `LogAssert(condition, text)` and the `LogAutomationTest` channel wrapper.
- The engine binary contains an internal `Red::System::UnitTestMode()` (C++ side, surfaced in
  `entityPool.cpp` strings) — not exposed to script or to modders.
- REDkit's `editor.exe` / `r4Launcher.exe` expose no headless or test-run modes
  (string-level verification).

### 2. `wcc_lite.exe` can compile scripts without the game (half a bench)

`wcc_lite.exe` (REDkit) has a `compileScripts` commandlet — the same script compiler the game
uses at startup. It produces a cooked `.redscripts`/`.rsblob` and reports **compile errors**
without launching the game. That makes it a compile-check gate, *not* an execution/test bench:
no runtime, no game state, no assertions.

Making it run requires a `gameconf.cfg` discoverable by `wcc_lite`:

- It looks for `gameconf.cfg` by walking **up** from the current working directory
  (verified behavior: running from `tools\wcc-test` made it search `tools\`).
- The config's paths (`data`, `scripts`, …) must be **relative** to the game root; absolute
  paths get double-prepended (observed: `...\REDkit\E:\SteamLibrary\...`).
- A working layout is a mock game root:
  `gameconf.cfg` + junctions `r4data -> <REDkit>\r4data` and `bin -> <REDkit>\bin`, then
  `wcc_lite compileScripts` from inside the mock root.
- Full-corpus compilation took **>15 minutes without completing** in our attempt
  (depot scan dominated; `dep.cache` present but the run still did not finish).

### 3. The licensing wall (project decision)

A durable bench needs the vanilla script corpus co-located with the compiler — and committing
1,525 proprietary `.ws` files (or a copy of them) to this repository violates the project rule
against committing proprietary game assets. Junctions into the game install work locally but
are fragile (drive/move/verify-integrity changes) and cannot be shared or used in CI.
**This rules out a repository-integrated bench regardless of tooling.**

## Decision

Verification runs in game:

- **Scenario tests** (`tests/modInfusion/.../InfusionScenarios.ws`, dev deploys only):
  `infuseScenarioAll` runs every service-level scenario in one command and reports
  PASS/FAIL/SKIP on screen and in `scriptslog.txt` (tests/modInfusion/README.md).
- `-debugscripts` makes the engine write `scriptslog.txt` (compile errors and `[Infusion]`
  log lines) — the everyday compile gate (`tools/launch-debug.ps1`).
- The menu itself is checked by hand (docs/UI.md, "Manual UI checklist").

## When to revisit

- If a future REDkit update ships a script-only compile/verify mode, or the community builds a
  `wcc_lite`-based compile gate with reasonable runtime (< a minute), a compile-check CI step
  becomes practical — without the licensing problem, as long as it references the local game
  install rather than committing game files.
- If the mod grows a logic layer that is testable headlessly (pure calculations with no engine
  calls), consider mirroring that logic in a real test framework outside WitcherScript
  (e.g. PowerShell/Python computing the same formulas) — accepted trade-off: duplicate logic,
  but zero game dependency. Not currently worth it for the size of this codebase.
