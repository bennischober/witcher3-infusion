# Script test-bench feasibility (research notes, 2026-10-10, revised 2026-10-21)

Question: how much of the verification can run **without a person at the game**?

Short answer: the game has a built-in **script-verify mode** — that is the compile gate
(`tools/verify-scripts.ps1`, done). Running the scenarios unattended is **not solved yet**: it
needs the game to load a save and take the console command from outside (options below). No
test framework or headless/null-renderer mode exists, so a bench is always a real game window.

## Compile gate (verified 2026-10-21, Remastered 5.0.1)

`witcher3.exe -verifyscriptsandexit` compiles every script (vanilla + all mods) and quits.
Verified behavior:

- Clean run: the game exits by itself after ~17–25 s with **exit code 3**. No window.
- Compile error: the game does **not** exit; it stops on a "The Witcher 3: Wild Hunt – Script
  Compilation Errors" window (Retry / Copy to Clipboard / Exit Application) listing
  `Error [mod]file.ws(line): message` lines. The same exit code 3 results if that window is
  closed, so **the exit code is not the verdict — the window is.** `-silentscripts` hides the
  window and makes failures invisible; do not use it.
- The game **must start with its own folder (`bin\x64_dx12`) as working directory.** From
  another folder it quits after ~4 s without compiling anything (exit code 0, no log) — an easy
  false "pass".
- `-debugscripts` is not needed for the gate, and `scriptslog.txt` is not written in this mode.
- The error window's text is readable through UI Automation (class `Edit`, id 3002, text in the
  element's Name).
- Other mods in the `mods` folder are compiled too, so their errors fail the gate as well (the
  mod name is in the message).

`tools/verify-scripts.ps1` wraps this: waits for exit (PASS) or the error window (FAIL, lists the
errors, kills the game); exit code 0/1/2 (2 = could not verify). Tested with a deliberately
broken mod and with the installed mods. The earlier `wcc_lite` route is superseded (below).

Binary-level findings (strings in `witcher3.exe`; flags not tested unless stated above):
`-verifyscriptsandexit` (and the typo'd `-verifyscripsandexit`), `-forcescriptcompilation`,
`-noscriptcrc`, `-dumpscripts[=]`, `-scriptdefines=`, `-silentscripts`, `-windowed`,
`-width`/`-height`, `-position`, `-noRayTracing`, `-nolog`, `-noplayer`, `-world`, `-savehack`,
`-debugsaves`, `-ignoreCommandLineTxt` (the game also reads a `commandline.txt`), and config keys
`DebugScriptsLogDir` / `DebugScriptsForceFlush`. Scripts can end the game with
`theGame.ExitGame()` (engine/game.ws).

## Running scenarios unattended (open)

What is known:

- The game starts and shows its window from a script-launched process (tested
  `-net -debugscripts -windowed -width 800 -height 450`); Space skips the intro logos.
- With `-net` the game listens on TCP **37001** and **37010** (all interfaces, no
  authentication — only use on a trusted network / behind the firewall). Both stay silent until a
  client speaks first. This is the connection Script Studio (`bin\x64\scriptStudio.exe`, ships
  with the game; debugger, breakpoints, script reload) uses; the protocol is undocumented and was
  **not** reverse-engineered (version-dependent, so avoided on purpose).
- Results already reach the outside: `[Infusion]` lines in `scriptslog.txt` with
  `-debugscripts`.

What is missing: loading a save and sending the console command (`infuseScenarioAll`) without
hands. Candidate approaches, in order of preference:

1. Keystroke automation of the game window (skip intro → menu → load → console → command), poll
   `scriptslog.txt` for the `SCENARIOS:` line, end with `ExitGame` or a kill. Black box, uses only
   public behavior; fragile only against UI changes.
2. The `-net` channel (Script Studio protocol): cleanest, but needs protocol reverse-engineering.
3. Script-side trigger (a dev-only script that runs the scenarios at start) — untested whether
   scenarios can run before a save is loaded; they need a player and an inventory.

## What was ruled out

### No test framework ships with the game or REDkit

- The shipped script base (1,525 `.ws` files) contains no test framework, runner or assert
  library — only two unused helpers in `scripts/core/misc.ws`: `LogAssert(condition, text)` and
  the `LogAutomationTest` channel wrapper.
- The engine has an internal `Red::System::UnitTestMode()` (C++ side) — not exposed to script.
- REDkit's `editor.exe` / `r4Launcher.exe` expose no headless or test-run modes (string-level
  verification). WolvenKit's command-line tool is documented for Cyberpunk; nothing found for
  launching or testing the Witcher 3.

### `wcc_lite.exe compileScripts` (REDkit)

Same script compiler, no game needed, but it needs a `gameconf.cfg` found by walking up from the
working directory, with paths relative to the game root (a mock root with junctions to REDkit's
`r4data` and `bin`). Full-corpus compilation took **> 15 minutes without finishing** in our
attempt. The game's own verify mode does the same in ~20 s against the real install, so this
route is not needed.

### A repository-integrated bench with the vanilla scripts

A bench that keeps the vanilla script corpus next to the compiler would put 1,525 proprietary
`.ws` files in the repository — against the project rule. The compile gate avoids this by using
the local game install, so it works on any machine that has the game, but not in hosted CI.

## Decision

- **Compile gate:** `tools/verify-scripts.ps1` (before every in-game test round; `-Deploy` installs
  the current tree first).
- **Behavior:** still verified in game — scenario tests (`tests/modInfusion/.../InfusionScenarios.ws`,
  `infuseScenarioAll`, dev deploys only; results in `scriptslog.txt` and on screen), and the menu
  by hand (docs/UI.md checklists).
- **Next:** the unattended scenario runner above, as its own step.

## When to revisit

- If the game or REDkit gains a null-renderer / test mode.
- If the mod grows a logic layer that is testable headlessly (pure calculations with no engine
  calls): mirror it in a real test framework outside WitcherScript (accepted trade-off: duplicate
  logic, no game dependency). Not worth it for the current size.
