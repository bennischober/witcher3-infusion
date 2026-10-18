# Debugging, compile errors, and the Remastered 5.01 environment

## Compile pipeline and log locations

- Loose mod scripts (`mods/<mod>/content/scripts/**/*.ws`) compile **at game launch**.
- Compile errors show as an on-screen dialog AND are written to
  `Documents\The Witcher 3\scriptslog.txt` — **only when the game is launched with the
  `-debugscripts` flag** (Steam launch options). Without the flag the file is not written.
- `scriptslog.txt` is truncated (mode `w`) at each launch with the flag. **With the flag active
  it captures ALL `LogChannel` runtime output for the whole session** (verified on 5.01 — a
  2-minute session produced >1 MB covering every channel). An early test session produced only
  the 101-byte header because nothing logged during it, which briefly looked like a channel
  filter — it is not. Runtime file logging works.
- Practical consequence: with `-debugscripts` active, `LogChannel('MyChannel', ...)` IS the file
  logging mechanism for mods. Grep the file for the channel name to extract a mod's trace.
- For user-visible feedback use HUD notifications
  (`theGame.GetGuiManager().ShowNotification`), sounds (`theSound.SoundEvent`), or observable
  game state — note the console overlay can hide notification lines fired while it is open, so
  tests should also persist a result (e.g. `FactsSet`) and offer a re-display command.

## Compiler strictness rules (with real error messages)

These were verified by hitting each error in practice. The compiler's diagnostics name the
rule, but the messages can be cryptic — knowing the pattern saves cycles.

### 1. All `var` declarations at function top

```
Error ...(217): syntax error, unexpected TOKEN_VAR, expecting ';', near 'var'
```

`for ( var i = 0; ... )` and any mid-function `var x : T;` are illegal. Declare at the top;
use `while` loops when a dedicated loop counter is needed. Follow-up errors (`unexpected '}'`,
`expecting $end`) are usually cascade noise from this one line — fix the declaration and they
disappear.

### 2. No member access or indexing on call results

```
Error ...: Cannot access struct property 'valueBase'. Parent scope does not come from variable.
Error ...: Only arrays coming from variables can be modified
Error ...: Only arrays coming from variables can be indexed
```

Assign to a local first:

```ws
// WRONG:
var v : float = inv.GetItemAttributeValue( id, 'armor' ).valueBase;
var n : int = inv.GetItemsByCategory( 'steelsword' ).Size();

// RIGHT:
var stat : SAbilityAttributeValue;
var silver : array<SItemUniqueId>;
stat = inv.GetItemAttributeValue( id, 'armor' );
v = stat.valueBase;
silver = inv.GetItemsByCategory( 'steelsword' );
n = silver.Size();
```

### 3. `exec` functions are console-only

```
Error ...: Cannot call exec function 'foo' from scripts instead of the console.
```

`exec` functions cannot call each other, and no script code can call them. Move shared logic
into plain functions; keep `exec` wrappers thin.

### 4. Method ownership: check the class

```
Error ...: Could not find function 'IsItemEquipped'
```

`thePlayer` is `CR4Player`; many gameplay functions live on `W3PlayerWitcher` (get it via
`GetWitcherPlayer()`), on components, or on the inventory component. Grep the shipped scripts
for `function <Name>` to find the declaring class before calling.

### 5. Handle comparisons: use truthiness, never `== NULL`

```
Error ...: Unable to find suitable operator 'OperatorEqual' for given types (&handle:CGameplayEntity, void)
```

WitcherScript handles (class references) have no equality operator against `void`/`NULL`.
The vanilla idiom — used universally, zero `== NULL` comparisons in the shipped corpus — is
implicit boolean conversion:

```ws
// WRONG:                          // RIGHT (vanilla idiom):
if ( craftsman == NULL )           if ( !craftsman )
if ( comp != NULL )                if ( comp )
```

Applies to entity handles, component handles, and any class-typed variable. Structs
(value types) are not affected — but note engine opaque structs cannot be null-checked at all.

### 6. No ternary operator

The corpus contains zero `cond ? a : b` expressions — conditionals are if/else only.

### 7. Struct member initialization

Struct locals are zero-initialized by type, not auto-constructed. Assign every member you rely
on (vanilla often assigns the whole struct before use, or uses `out` parameters that the callee
fills completely).

### 8. General diagnosis order

1. Read the exact message + line number (first error is the real one; the rest are cascades).
2. Check declaration order, missing `;`, unbalanced braces.
3. Verify the called API exists **in the shipped scripts** for the running game version.
4. Check parameter types, `out`/`optional` markers, casts.
5. Check function kind vs. call context (`exec`/`latent`/`quest` rules).
6. Smallest fix first; recompile; repeat.

## Remastered 5.01 environment changes (vs Next-Gen 4.04)

### Reserved keywords: `map` and `set`

The 5.0 compiler added new type tokens (verified by token-table diff against the 4.04
compiler): `map`, `set`, plus annotation-related keywords. Scripts using these as **identifiers**
now fail:

```
Error [mod...]...ws(1623): syntax error, unexpected TOKEN_MAP, expecting TOKEN_IDENT, near 'map'
Error [mod...]...ws(12582): syntax error, unexpected TOKEN_SET, expecting ')', near 'set'
```

Fix: rename the identifier (`map` → `itemsMap` — the name CDPR itself used in the same patch;
`set` → `setType`). The other new tokens (`add`, `addfield`, `replace`, `wrap`, `enum_type`)
remain usable as identifiers in practice.

**Older keywords bite too** (verified 2026-10-18: `var entry : CScriptedFlashObject;` →
`unexpected TOKEN_ENTRY, expecting TOKEN_IDENT, near 'entry'`). The full token table in
`witcher3.exe` (5.01, `grep -a -o "TOKEN_[A-Z_0-9]*"`) contains these word tokens besides the
obvious language keywords — never use them as identifiers:
`any`, `autobind`, `cleanup`, `def`, `defaults`, `editable`, `enter`, `entry`, `hint`, `in`,
`inlined`, `local`, `map`, `parent`, `quest`, `reward`, `saved`, `savepoint`, `scene`, `set`,
`single`, `timer`, `virtual_parent` (plus `theGame`/`thePlayer`-style globals: `GET_GAME`,
`GET_PLAYER`, `GET_CAMERA`, `GET_SOUND`, `GET_DEBUG`, `GET_INPUT`, `GET_TIMER`, `GET_TELEMETRY`).
Re-run the grep after game updates.

### Encoding: UTF-8 with BOM

All text files (`.ws`, `.xml`, `.csv`, `.w3strings`) must be **UTF-8 with BOM** (Next-Gen used
UTF-16 LE BOM). Old UTF-16 mod files fail. Add the BOM (`EF BB BF`) to every shipped script.
BOM-less UTF-8 has worked in practice but is not the documented contract — ship with BOM.

### Script modding options on 5.01

- **Loose scripts** (`mods/mod/content/scripts/...`) — still fully supported on PC; compiled at
  launch; **not allowed on consoles**.
- **`precompiled.rsblob`** — cooked via REDkit; required for consoles; on PC coexists with
  loose scripts (a precompiled blob overrides loose scripts for the same functions).
- **Script annotations** — `@wrapMethod(Class) function ...` wraps methods without file
  overrides; wrapping native functions requires precompiled scripts.
- **Scope-based scripting** — add functions/variables/enum values to existing classes from a
  new file; engine merges at startup; also requires precompiled scripts.
- **XML `on_conflict="extend"/"replace"`** — merge or replace item/ability definitions from a
  DLC-mounted XML without editing vanilla files.

### Mod environment changes

- Native DX12 only (no DX11 filelist shenanigans); no `filelist` edits needed.
- In-game Mod Hub (mod.io) exists; Nexus mods remain loose-folder installs.
- `mods.settings` (Documents) still gates mod enable/priority for loose mods.
- Base game + DLCs merged into single bundles; `cookedfinal.redscripts` still ships, but loose
  script overrides work as before.

## Debug workflow for this project (repository-specific)

1. Deploy: `powershell -File tools\deploy-mod.ps1 -Dev` (dev overlay) or without `-Dev`
   (release layout).
2. Launch with `-debugscripts` active (Steam launch options; see `tools/launch-debug.bat`).
3. Compile errors → `Documents\The Witcher 3\scriptslog.txt`.
4. Runtime verification → in-game debug commands (see `tests/modInfusion/README.md`): sounds +
   HUD notifications + inventory state. The 5.01 console does not echo `LogChannel`.
5. Console open requires being **in gameplay** (not the main menu); key is the physical tilde
   position — on German layouts try `^` (double-press), `Ö`; fallback: AutoHotkey
   `F12::Send {sc029}` (`tools/console-toggle.ahk`).
