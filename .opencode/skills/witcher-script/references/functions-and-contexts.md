# Function kinds, execution contexts, and access modifiers

## Function kinds

WitcherScript function kinds select the execution context. They are not interchangeable labels.

### `exec function` — debug console commands

```ws
exec function addmoney( val : int )
{
    thePlayer.AddMoney( val );
}
```

- Exposed to the in-game debug console (requires `DBGConsoleOn=true`).
- **Console-only entry points: one `exec` function cannot call another from script code**
  (compiler error: "Cannot call exec function ... from scripts instead of the console").
  Shared logic goes into plain helper functions that both the `exec` wrapper and other code call.
- Free functions (outside any class) are allowed and common (`temp.ws`, `playerCheats.ws`).
- Vanilla cheat functions are typically **silent** — the effect is the feedback.

### `latent function` — time-dependent execution

```ws
latent storyscene function ShaveGeralt( player : CStoryScenePlayer )
{
    var acs : array<CComponent>;

    acs = thePlayer.GetComponentsByClassName('CHeadManagerComponent');
    ((CHeadManagerComponent)acs[0]).Shave();

    Sleep(1.0f);
}
```

- Supports `Sleep(seconds)` and similar waiting operations.
- Only callable from contexts that support latent execution (quest functions, storyscene
  functions, other latent functions). Calling `Sleep()` from a non-latent context is an error.
- Composable with context kinds: `latent storyscene function`, `latent quest function`.

### `timer function` — entity timer callbacks

```ws
timer function Loop( dt : float, id : int )
{
    // called by the entity's timer system
}
```

- Registered via `entity.AddTimer( timerName, period, optional repeats, ... )` on a
  `CGameplayEntity`; the engine then invokes the matching `timer function` on that entity.
- The owning entity must define the timer function; external scripts cannot attach timers to
  entities they do not own without overriding their scripts.

### `storyscene function` — scene graph functions

```ws
storyscene function EnableFastTravelPin( player : CStoryScenePlayer, pinTag : name, enable : bool )
{
    var manager : CCommonMapManager;

    manager = theGame.GetCommonMapManager();
    manager.SetEntityMapPinDisabled( pinTag, !enable );
}
```

Called from storyscene elements; the first parameter is conventionally `player : CStoryScenePlayer`.

### `quest function` — quest graph functions

```ws
quest function LaunchCredits()
{
    theGame.GetGuiManager().RequestCreditsMenu( CreditsIndex_Wither3 );
}
```

- Invoked by quest graph nodes; the signature must match how the quest editor calls it.
- Making a function `quest` does **not** wire it into a quest graph — resource/editor setup is
  separate.

### `reward function` — attached to rewards in the editor

Invoked when a reward is granted. Rare; follow existing reward implementations.

### `cleanup function` — post-operation cleanup

```ws
cleanup function ThrowProjectileCleanup()
{
    // no parameters, no return value
}
```

Paired with operations that need post-completion teardown.

### `entry function` — state entry callbacks

Executed when entering a state; uncommon, tied to state-machine classes. Inspect existing state
implementations before writing one.

## Access and storage modifiers

| Modifier | Meaning |
| --- | --- |
| `public` / `private` / `protected` | visibility (default follows surrounding convention; vanilla marks most members explicitly) |
| `final` | cannot be overridden in subclasses |
| `import` | declaration only — implementation is native (C++) or in another script; `import final function` is the standard engine-API shape |
| `event` | event handler (`event OnConfigUI()`, `event OnTick( timeDelta : float )`); dispatched by the engine or `super` chains |
| `saved` | variable is serialized into savegames (`private saved var level : int;`) |
| `editable` | exposed to the REDkit editor |
| `const` | constant (set via `default X = Y;`) |
| `statemachine` | class supports states |

## Engine function flags (documentation-level concepts)

The language guide lists flags such as `FF_NativeFunction`, `FF_StaticFunction`,
`FF_ExecFunction`, `FF_TimerFunction`, `FF_QuestFunction`, `FF_EventFunction`,
`FF_LatentFunction`, `FF_EntryFunction`, `FF_CleanupFunction`, `FF_RewardFunction`,
`FF_SceneFunction`, `FF_OperatorFunction`, `FF_ExportedFunction`, `FF_FinalFunction`,
`FF_PrivateFunction`, `FF_ProtectedFunction`, `FF_PublicFunction`.

These describe function properties at the engine/RTTI level; most are *not* written as ordinary
source modifiers. In day-to-day modding you use the source-level keywords above and treat the
FF_* list as background knowledge (e.g. when reading RTTI dumps or engine logs).

## Events

```ws
class CR4BlacksmithMenu extends CR4MenuBase
{
    event  OnConfigUI()
    {
        // UI setup; called by the menu framework
    }

    event  OnRepairItem( item : SItemUniqueId, price : int )
    {
        // dispatched from Flash UI via the scriptable flash bridge
    }
}
```

- Events are declared with the `event` keyword and usually dispatched by engine systems or UI
  callbacks.
- Override chains: call `super.EventName(...)` when the base implementation matters (the engine
  does not always call base automatically — check the parent class).

## Instantiation

```ws
var svc : W3InfusionService;
svc = new W3InfusionService in theGame;   // "in <owner>" binds the object's lifecycle
```

- `new ClassName in <owner>` — the owner (usually `theGame` or a component) manages lifetime.
- Script classes extending `IScriptable` can be instantiated freely; entity/component classes
  are created by the engine, not by scripts.
