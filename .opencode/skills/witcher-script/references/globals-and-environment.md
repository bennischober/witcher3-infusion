# Global objects and environment access

## Global objects

Defined in `bin/redscripts.ini` (`[globals]` section) — verified for 5.01:

| Global | Class | Typical use |
| --- | --- | --- |
| `theGame` | `CR4Game` | game params (`theGame.params`), GUI manager, definitions manager, menu requests, facts, timescale |
| `thePlayer` | `CR4Player` | inventory (`thePlayer.inv`), money, equip, skills |
| `theCamera` | `CCamera` | camera queries |
| `theSound` | `CScriptSoundSystem` | `theSound.SoundEvent('gui_crafting_craft_item')` |
| `theDebug` | `CDebugAttributesManager` | debug attribute queries |
| `theTimer` | `CTimerScriptKeyword` | timer keywords |
| `theInput` | `CInputManager` | input context, key queries |
| `theServer` | `CServerInterface` | (multiplayer stub, unused in vanilla scripts) |
| `theUI` | `CGuiWitcher` | (unused in vanilla scripts) |

Do not rename aliases in `redscripts.ini` — compatibility with other mods depends on the
standard names.

**Method ownership is class-specific.** `thePlayer` is `CR4Player`, but most gameplay-relevant
item functions live one level up on `W3PlayerWitcher`:

```ws
// WRONG:  thePlayer.IsItemEquipped( id );        // not on CR4Player
// RIGHT:
var witcher : W3PlayerWitcher;
witcher = GetWitcherPlayer();
witcher.IsItemEquipped( id );
```

`GetWitcherPlayer()` (global function in `playerWitcher.ws`) returns the `W3PlayerWitcher`
singleton. When in doubt about where a method lives: grep the scripts for the function
declaration and check the class.

## Inventory access (the most-used surface)

```ws
var inv : CInventoryComponent;
var items : array<SItemUniqueId>;
var id : SItemUniqueId;

inv = thePlayer.inv;                 // or entity.GetInventory()
inv.GetAllItems( items );            // fills array with every item instance

// identification
inv.GetItemName( id );               // name (definition name)
inv.GetItemCategory( id );           // 'steelsword', 'armor', 'gloves', ...
inv.ItemHasTag( id, 'PlayerSteelWeapon' );
inv.GetItemQuantity( id );
inv.IsIdValid( id );
inv.IsItemQuest( id );

// attributes and stats
var stat : SAbilityAttributeValue;
stat = inv.GetItemAttributeValue( id, 'SlashingDamage' );   // .valueBase/.valueAdditive/.valueMultiplicative
var level : int;
level = RoundMath( CalculateAttributeValue( stat ) );

// modification
inv.AddItemCraftedAbility( id, 'autogen_fixed_steel_dmg', true );  // add ability instance (true = allow duplicates)
inv.RemoveItemCraftedAbility( id, 'autogen_fixed_steel_dmg' );
inv.AddItemTag( id, 'SomeTag' );     // tags persist with the item instance
inv.RemoveItemTag( id, 'SomeTag' );
inv.RemoveItem( id );                // consume/remove
inv.AddAnItem( 'Item Def Name', 1 ); // spawn by definition name -> array<SItemUniqueId>
inv.RemoveItemByName( 'Name', 1 );
inv.GetItemsByName( 'Name' );        // array of matching instances
inv.GetItemsByCategory( 'steelsword' );
inv.GetItemModifierInt( id, 'ModifierName' );
inv.SetItemModifierInt( id, 'ModifierName', 1 );

// durability
inv.HasItemDurability( id );
inv.GetItemDurability( id );
inv.GetItemMaxDurability( id );
inv.SetItemDurabilityScript( id, inv.GetItemMaxDurability( id ) );  // full repair

// money (crowns are just an item stack)
inv.GetMoney();
inv.AddMoney( amount );
inv.RemoveMoney( amount );
```

**Sacrifice/infusion-relevant strictness**: item levels are *derived*, not stored —
`inventoryComponent.GetItemLevel()` computes from aggregated stats, and under some mods it has
side effects. Compute levels from stats yourself when side-effect-free reads matter.

## Gameplay helpers (global functions, `scripts/core/misc.ws`)

```ws
RoundMath( f );        // round half away from zero
FloorF( f );  CeilF( f );
Clamp( v, min, max );
RandRangeF( max, min );
CalculateAttributeValue( att );   // SAbilityAttributeValue -> float

LogChannel( 'ChannelName', "text" );   // internal log channels (see debugging reference)
LogItems( "..." ); LogCrafting( "..." ); LogStats( "..." );   // preset channels
```

## Facts (persistent global state)

```ws
FactsAdd( "FactName" );                  // value 1
FactsAdd( "FactName", 3 );               // value 3
FactsQuerySum( "FactName" );             // int sum (0 if absent)
FactsDoesExist( "FactName" );
FactsRemove( "FactName" );
GameplayFactsSet( "FactName", 1 );
```

Facts persist in savegames and are the standard way to store mod state without new save data.

## GUI feedback from scripts

```ws
// HUD notification (queued, auto-dismisses)
theGame.GetGuiManager().ShowNotification( "text", 4.0 );

// menu opening
theGame.RequestMenu( 'MenuName', initData );                 // or RequestMenuWithBackground
theGame.RequestPopup( 'PopupName', popupData );
```

Remastered 5.01 caveat: console-overlay visibility of some HUD output differs from Next-Gen —
see the debugging reference.

## Definitions manager (XML game data)

```ws
var dm : CDefinitionsManagerAccessor;
dm = theGame.GetDefinitionsManager();
var node : SCustomNode;
node = dm.GetCustomDefinition( 'crafting_schematics' );
// attribute readers:
dm.GetCustomNodeAttributeValueName( node, 'key', outVal );
dm.GetCustomNodeAttributeValueInt( node, 'key', outVal );
dm.GetCustomDefinitionSubNode( node, 'ingredients', outSub );
```

Item definitions (`recycling_parts`, abilities, tags) and custom definitions
(`crafting_schematics`, `leveling`) are read through this — the data side of most gameplay mods.
