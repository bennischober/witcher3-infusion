# WitcherScript language reference

Fundamental syntax, verified against the shipped game scripts (Next-Gen 4.04 / Remastered 5.01).

## Basic types

| Type | Notes |
| --- | --- |
| `int` | 32-bit integer |
| `float` | literals commonly use the `f` suffix (`1.0f`); ~2,600 suffix usages in vanilla |
| `bool` | `true` / `false` (not UnrealScript `Yes`/`No`) |
| `String` | double-quoted literals: `"text"`; both `String` and `string` spellings appear in vanilla (~1,311 each) — match the file you are editing |
| `name` | single-quoted literals: `'TagName'`; identifiers, tags, attribute names |
| `Vector` | four-component XYZW |
| `EulerAngles` | Pitch, Yaw, Roll |
| `Matrix` | matrix value |
| `array<T>` | e.g. `array<SItemUniqueId>`; engine types like `SItemUniqueId` are opaque structs |

Do not interchange `String` and `name` without checking the API — most engine accessors take
one or the other specifically (`GetItemName` returns `name`, localization functions take
`string` keys).

## Variables

All local variables must be declared at the **top of the function**, before the first
executable statement. This is compiler-enforced:

```ws
function Example( count : int ) : int
{
    var i : int;
    var total : int;
    var items : array<SItemUniqueId>;

    // executable statements start here
    total = 0;
    for ( i = 0; i < count; i += 1 )
    {
        total += i;
    }
    return total;
}
```

- Multiple declarations of the same type on one line are idiomatic: `var i, j : int;`
- Class members are declared inside the class body, before functions:

```ws
class Test
{
    var SomeText : String;
}
```

## Functions

```ws
function CalculateValue( amount : int ) : int
{
    return amount * 2;
}
```

- Parameters: `name : Type`, comma-separated.
- Return type after the parameter list; `void` for none.
- `out` parameters return values through the argument: `function Get( out value : int ) : bool`
  — callers must declare a variable and pass it; the callee must assign before returning.
- `optional` parameters may be omitted by callers:
  `function Add( item : name, optional count : int, optional equip : bool )`.
- Vanilla style: `PascalCase` function names, tab indentation, `K&R`-style braces on their own
  lines (matching the file being edited).

## Operators and expressions

- String concatenation: `+` (`"a" + b + "c"`); numbers are concatenated via implicit
  conversion in `string` context — vanilla does this everywhere in log messages.
- Comparison `==` / `!=` works on handles, structs (`SItemUniqueId`), and primitives.
- Integer division truncates; use floats explicitly when needed.
- `+=`, `-=`, `*=` supported; no `++`/`--` (vanilla writes `i += 1`).
- Logical `&&` / `||` with short-circuit.
- Casts: prefix form `(Type)expression` — e.g. `(CNewNPC)entity`,
  `(W3PlayerWitcher)thePlayer`. Casts to incompatible types fail at runtime, not compile time;
  validate with `IsIdValid`, class checks, or `GetClassName` where the vanilla code does.

## Arrays

```ws
var items : array<SItemUniqueId>;

inv.GetAllItems( items );        // engine fills the array (out-style)
items.PushBack( x );
items.Size();
items[0];                        // index access — only on a variable, never on a call result
items.EraseFast( 0 );            // removes by index (order not preserved)
items.Clear();
```

Arrays are reference-ish values; engine APIs that "fill" an array take it as an `out`-style
parameter and append. Check whether an API clears the array first (most do not; vanilla often
declares fresh locals per call).

## Enums

```ws
enum ECraftsmanLevel
{
    ECL_Undefined,
    ECL_Journeyman,
    ECL_Master,
    ECL_Grand_Master,
    ECL_Arch_Master
}
```

- First element = 0 unless specified.
- Compare directly: `if ( level == ECL_Master )`.
- `EnumGetMax('ECraftsmanLevel')`, `EnumGetMin(...)` return the numeric bounds;
  `EnumToString` / string-to-enum helpers exist per enum (vanilla defines
  `ParseCraftsmanLevelStringToEnum` style converters in the file that owns the enum).

## Structs

```ws
struct SItemParts
{
    import var itemName : name;
    import var quantity : int;
}
```

- Script-declared structs use plain `var`; engine-visible ones use `import var` / `saved var`.
- Structs are value types — passing to functions copies; mutating a copy does not affect the
  original.
- Script structs may contain engine opaque types (`SItemUniqueId` etc.) — verified common in
  vanilla (`craftingTypes.ws`, `r4guimanager.ws`).

## `default` values (class members)

```ws
class W3Params
{
    public const var MAX_PLAYER_LEVEL : int;
    default MAX_PLAYER_LEVEL = 100;
}
```

`default X = Y;` lines initialize class member variables; `const var` members are set via
`default` too. This is the standard pattern for configuration constants.

## Comments

- `//` single line, `/* ... */` block.
- Vanilla headers use a distinctive `/*** ... ***/` banner comment block at file top.
