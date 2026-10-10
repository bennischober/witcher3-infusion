# Classes, native imports, and state machines

## Scripted classes

```ws
class InterpCurve
{
    var something : float;

    function doSomething( inVal : float, outVal : float ) : int
    {
        return 10;
    }
}
```

- Members first, then functions.
- Inheritance: `class W3CraftsmanComponent extends W3MerchantComponent`.
- Vanilla naming: gameplay classes `W3*` (`W3PlayerWitcher`, `W3CraftsmanComponent`), engine
  classes `C*` (`CGameplayEntity`, `CInventoryComponent`), menus `CR4*`, structs `S*`, enums
  `E*` with short prefixed values (`ECL_Master`, `ECT_Smith`).
- One class per file is the dominant convention, file name = class name.

## Native classes and imports

Native classes are implemented in C++ and exposed through import declarations:

```ws
import class C2dArray extends CResource
{
    import final function GetValueAt( column : int, row : int ) : string;
    import final function GetValue( header : string, row : int ) : string;
    import final function GetNumRows() : int;
}
```

Rules for working with engine APIs:

- **The shipped scripts are the ground truth.** `content/content0/scripts/` contains the full
  import declarations of every native class. Find the real signature there before calling.
- Preserve parameter order, types, `optional`/`out` markers, and return types exactly.
- `import final function` cannot be overridden or shadowed.
- Never fabricate an import to make an undocumented method "exist". If the API is absent from
  the scripts, it is absent from the engine (for that game version).
- Opaque engine types (`SItemUniqueId`, `SInventoryItem`, `SAbilityAttributeValue`) are
  declared as `import struct` with `import var` members — they cross the script/engine boundary
  and their fields are readable, but constructing them from script is not possible.

## Inheritance and override rules

```ws
class W3GuiRepairInventoryComponent extends W3GuiBaseInventoryComponent
{
    public function ShouldShowItem( item : SItemUniqueId ) : bool
    {
        // filter logic; call super.ShouldShowItem( item ) to include base filtering
    }
}
```

- A mod can **override a whole script file** by shipping a file with the same path — the last
  loaded mod wins per file (this is what script mergers reconcile). Prefer avoiding file
  overrides: Remastered adds merge-free mechanisms (script annotations `@wrapMethod`,
  scope-based additions, XML `on_conflict="extend"`), and loose-script file overrides conflict
  with any other mod touching the same file.
- Overriding non-final scripted functions in *new* subclasses is always safe.
- `super.MethodName(...)` calls the parent implementation explicitly.

## State machines

```ws
statemachine class MyEntity extends CEntity
{
    default autoState = 'TurnedOff';
}

state TurnedOff in MyEntity
{
    event OnEnterState( prevStateName : name )
    {
        super.OnEnterState( prevStateName );
    }
}

state TurnedOn in MyEntity
{
    event OnEnterState( prevStateName : name )
    {
        super.OnEnterState( prevStateName );
    }
}
```

- `statemachine class` — the class supports states; `default autoState = 'Name';` sets the
  initial state.
- `state Name in OwningClass` — associates a state with its owning class (the state can live in
  a different file than the class, which is how vanilla spreads NPC states across files).
- Lifecycle events: `OnEnterState( prevStateName )`, `OnLeaveState( nextStateName )` — call
  `super` so base state machinery runs.
- State helper APIs exist for guarded transitions (can-enter/can-leave), pausing/resuming.
- Real examples: player states (`CR4PlayerStateCombat` etc.), NPC AI states in
  `scripts/game/behavior_tree/` and player state files.
- Before writing complex transitions, read `scripts/core/states.ws` and a vanilla
  statemachine class.

## Where scripts live and how they load

```
mods/<modName>/content/scripts/game/...     loose mod scripts (compiled at game launch)
content/content0/scripts/game/...           vanilla scripts (ground truth)
```

- Loose mod scripts are **compiled at game start**; a compile error anywhere shows a dialog and
  the mod (often the whole script set) fails.
- Script files must be **UTF-8 with BOM** on Remastered 5.01.
- New classes can live in any subfolder (e.g. `scripts/game/infusion/`); only *file overrides*
  need the exact vanilla path.
- Console enablement: `DBGConsoleOn=true` in `bin/config/base/general.ini`; script error log:
  launch with `-debugscripts`, output in `Documents\The Witcher 3\scriptslog.txt`.
