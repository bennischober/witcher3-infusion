# Script test-bench feasibility (research notes, 2026-10-10, revised 2026-10-21)

Question: how much of the verification can run **without a person at the game**?

Short answer: the game has a built-in **script-verify mode** — that is the compile gate
(`tools/verify-scripts.ps1`, done). The scenarios run unattended through a dev-only script that
loads the newest save itself (`tools/run-scenarios.ps1`, prototype, below). No test framework or
headless/null-renderer mode exists, so a bench is always a real game window.

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

## Running scenarios unattended (prototype works, 2026-10-21)

`tools/run-scenarios.ps1` starts the game and reads the result; **nothing is simulated** (no
keys, no mouse). The game window appears (there is no headless mode) and the run takes ~75 s,
minutes, mostly the save load.

How it works (script side, dev only): `tests/modInfusionAutoRun` is copied to
`mods\modInfusionAutoRun` for the run and removed afterwards, so a normal dev launch never
auto-loads a save. Its script (`InfusionAutoRun.ws`) uses only vanilla script API:

0. `@wrapMethod(CR4StartupMoviesMenu) OnConfigUI` and `@wrapMethod(CR4RecapMoviesMenu)
   OnConfigUI`: call the original and then `CloseMenu()`. These two menus play the start-up
   bumpers (disclaimers, legal, logo) and the "previously on" recap and wait for Space; the
   vanilla start-up menu closes itself the same way when it has no movie.
1. `@wrapMethod(CR4IngameMenu) OnConfigUI`: on the main menu, once per process, calls
   `LoadLastSave(false)` - the same call the "Continue" button makes (newest save).
2. `@wrapMethod(CR4Game) OnGameStarted`: starts a timer on the player (8 s).
3. The timer runs `InfusionRunAllScenarios()` (what `infuseScenarioAll` runs) and, as a fallback
   90 s later, quits (`RequestExit`).

The runner waits for the process and prints the `[Infusion]` lines of `scriptslog.txt`; it
closes the game itself 10 s after the `SCENARIOS:` line shows up. Exit 0 = `SCENARIOS: n/n PASS`,
1 = a failure/skip, 2 = no result.

Verified (Remastered 5.0.1, 2026-10-21): the last run of `tools/run-scenarios.ps1` went from the
launch straight into the newest save without any input (the start-up videos are skipped), logged
the main menu at 18 s, ran the scenarios and ended with `SCENARIOS: 36/36 PASS`; the runner then
closed the game (exit code 0, 73 s in total) and exited 0.

Findings that matter:

- **One-shot guard needed.** Without it the main menu (which comes back whenever a session ends)
  loads the save again, in a loop. The guard is a field added to `CR4Game` (`theGame` is const:
  its fields cannot be assigned, use a local `(CR4Game)theGame`).
- **`theGame.ExitGame()` does not end the process:** it ends the *session* (back to the menu /
  the credits). The main menu's quit uses `theGame.RequestExit()`. The runner also closes the
  window itself 10 s after the result line appears, in case the quit does not work.
- **`scriptslog.txt` needs `DebugScriptsForceFlush=true` (and `LogDebugScripts=true`) under
  `[Scripts]` in `dx12user.settings`** (the DX12 build reads that file, not `user.settings`).
  Without it the log stayed at its 101-byte header. The game rewrites the file on exit and drops
  the keys, so the runner puts them back before every launch (backup once as
  `dx12user.settings.pre-infusion`). Whether the keys alone are enough, or the run itself is what
  changed, was not isolated.
- `-debugscripts` is required (the runner passes it); the game folder must be the working
  directory.
- "Continue" loads the **newest** save (~45 s). Use a dedicated test save as the newest one. The
  scenarios put the inventory back, but the run does not save.
- **The long start of a launch is menus, not engine startup.** Without the skip, the game plays
  the bumpers and the recap and waits for Space (minutes of waiting). They are `CR4StartupMoviesMenu`
  and `CR4RecapMoviesMenu` (`mainStartupMoviesMenu.ws`, `mainRecapMoviesMenu.ws`), queued by
  `CR4Game.PopulateMenuQueueStartupOnce` / `PopulateMenuQueueMainOnce`. Removing
  `RecapMoviesMenu` from that queue (wrapping `PopulateMenuQueueMainOnce`) did **not** stop the
  recap; closing the menus in their `OnConfigUI` did. The recap's story pictures with subtitles
  still show on the load screen of the save (screenshots at 16 s and 30 s) - that part is not
  skipped and not needed. I did not isolate which of the two wrappers does the work.
- **Quit and log.** The script's `RequestExit()` ends the process with exit code 0 (seen with a
  quit 8 s and 14 s after the scenarios). Two such runs left `scriptslog.txt` at its 101-byte
  header although the scenarios must have run (the game quit at the expected time) - the
  result was lost. The run after, with the quit moved 90 s away, had log content from 18 s on.
  Why the two earlier logs stayed empty is **not understood**; the runner therefore waits for
  the `SCENARIOS:` line and closes the game itself, and reports "NO RESULT" (exit 2) otherwise.
- The compile gate (`verify-scripts.ps1`) also compiles `modInfusionAutoRun` when it is
  installed; it is not part of the dev layout.

Not verified: that the result is reproducible (one run of the final version passed, two earlier
ones lost the log, see above), a run from a save in the open world versus one in a conversation
(the test save stood next to an armorer), and the failure paths (a failing scenario, a missing
save, a game that never loads).

### Superseded: keystroke automation

An earlier prototype of the runner drove the window with `SendInput` (skip the intro, click
Continue, open the console, type `infuseScenarioAll`). It was dropped: it needed the foreground
window and took over keyboard and mouse, depended on the keyboard layout (the console key is the
tilde only on a US layout - on de-DE it is `^` and the typed letters hit game hotkeys, so the
window had to be switched to en-US), on hidden menu highlight state, on the recap cinematic and on
fixed waits. Everything it did the game can do itself through the script API above.

Not used: the `-net` channel (TCP 37001/37010, the Script Studio protocol - undocumented, not
reverse-engineered, and the game listens on all interfaces without authentication).

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
- **Unattended behavior run:** `tools/run-scenarios.ps1` (prototype; one complete verified run,
  ~75 s, 36/36 PASS).

## When to revisit

- If the game or REDkit gains a null-renderer / test mode.
- If the mod grows a logic layer that is testable headlessly (pure calculations with no engine
  calls): mirror it in a real test framework outside WitcherScript (accepted trade-off: duplicate
  logic, no game dependency). Not worth it for the current size.
