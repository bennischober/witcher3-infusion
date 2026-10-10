---
name: witcher-script
description: "Write, explain, debug, refactor, and review WitcherScript (.ws) for The Witcher 3: Wild Hunt and REDkit. Use for WitcherScript syntax, quest and storyscene functions, gameplay scripting, native engine APIs, classes, imports, state machines, and script compilation errors."
---

# WitcherScript Development Skill

Write idiomatic WitcherScript for The Witcher 3: Wild Hunt and REDkit. Verify before assuming:
this language looks familiar but punishes borrowed habits from TypeScript, C++, C#, and
JavaScript.

## Workflow

1. **Verify the environment first.** Identify the game edition (Classic / Next-Gen / Remastered
   5.01) — encoding, keywords, and console behavior differ. Read the target scripts, not memory.
2. **Find a vanilla precedent.** Search the installed scripts
   (`content/content0/scripts/`) for the API or pattern before writing anything. If a function
   exists in vanilla, its real signature is there.
3. **Write it**, following vanilla conventions: tabs, `PascalCase` functions, lowercase locals,
   declarations at function top.
4. **Compile-check honestly.** Loose scripts compile at game launch; compile errors land in
   `Documents\The Witcher 3\scriptslog.txt` when the game runs with `-debugscripts`. Never claim
   compilation succeeded without evidence.

## Hard rules (compiler-enforced; details in references)

- Declare **all local variables at the top of the function**, before any statement — no
  mid-function `var`, no `for ( var i = 0; ... )`.
- **Assign call results to locals** before member access or indexing:
  `GetItemAttributeValue(...).valueBase` and `GetItemsByCategory(...)[0]` are compile errors.
- **`exec` functions are console-only entry points** — they cannot call each other from script
  code. Share logic through plain helper functions.
- Methods live on specific classes: `IsItemEquipped` is on `W3PlayerWitcher`
  (`GetWitcherPlayer()`), not on `thePlayer` (`CR4Player`). Check the owning class.
- `String` = double quotes, `name` = single quotes. Never interchange them casually.
- Remastered (5.01): scripts must be **UTF-8 with BOM**; `map` and `set` are **reserved
  keywords** and unusable as identifiers.

## Reference hierarchy (in order)

1. [Official WitcherScript Language Guide](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/36307090/WS+Language+Guide)
2. [Official WitcherScript overview](https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/36306960/WitcherScript)
3. The installed game's scripts under `content/content0/scripts/` — the ground truth for every
   signature.
4. Other official REDkit documentation (quests, Script Studio, compilation).
5. Established community documentation, when official sources do not answer the question.

Do not invent function signatures, class names, enums, globals, or engine behavior. If a
reference is unavailable, say so. Never claim to have inspected files, compiled a script, or
tested behavior unless it actually happened.

## References (load only what the task needs)

| File | Contents |
| --- | --- |
| [references/language.md](references/language.md) | Types, variables, parameters, operators, casts, defaults, arrays, enums, structs |
| [references/functions-and-contexts.md](references/functions-and-contexts.md) | Function kinds (`exec`, `latent`, `timer`, `quest`, …), access modifiers, function flags |
| [references/classes-and-imports.md](references/classes-and-imports.md) | Classes, native imports, state machines, inheritance, instantiation |
| [references/globals-and-environment.md](references/globals-and-environment.md) | Global objects, `redscripts.ini`, player/inventory access, GUI, sound |
| [references/debugging-and-remaster.md](references/debugging-and-remaster.md) | Compile-error diagnosis, the strictness rules with error messages, 5.01 changes (keywords, encoding, console/logging behavior) |

## Response requirements

- Provide complete, compilable implementations when APIs are known; label anything uncertain.
- When modifying scripts: preserve behavior, avoid unrelated refactoring, explain compatibility
  impact.
- When researching APIs: exact signatures only when verified against scripts or official docs;
  otherwise say what needs verification.
- The goal is not plausible-looking code — it is code that respects the language, the engine,
  and the actual REDkit environment.
