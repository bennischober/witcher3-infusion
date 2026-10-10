/***********************************************************************/
/** 	Witcher Gear Infusion — Milestone 2 prototype
/** 	Debug console entry points (spec §9.3 alternative; discovery §7 option 3).
/**
/** 	Enabled via the game console (DBGConsoleOn). Commands:
/** 	  infuseStats      - (silent) prepare verification; see inventory UI
/** 	  infusePreview    - (silent) validate best pair; sound: ok = craft sound
/** 	  infuseRun        - execute infusion of the best pair
/** 	  infuseSelfTest   - full test; verdict via SOUND + notification:
/** 	                       PASS = crafting sound, FAIL = denied sound
/**
/** 	Note on output (5.01): LogChannel text does not render in the debug
/** 	console and scriptslog.txt only captures compile errors, so the test
/** 	reports its verdict through game state: sounds, notifications (visible
/** 	after closing the console) and the inventory UI itself.
/***********************************************************************/

exec function infuseHelp()
{
	theGame.GetGuiManager().ShowNotification( "Infusion: infuseStats / infusePreview / infuseRun / infuseSelfTest", 6.0 );
}

// WitcherScript has no static class members; each exec call constructs a
// lightweight service object bound to theGame (same pattern as W3DamageAction
// "new ... in theGame.damageMgr").
function InfusionGetService() : W3InfusionService
{
	var svc : W3InfusionService;
	svc = new W3InfusionService in theGame;
	return svc;
}

// Collects all steelsword ids from the player inventory. Returns the count.
function InfusionGetSteelSwords( out ids : array<SItemUniqueId> ) : int
{
	var all : array<SItemUniqueId>;
	var i : int;
	var inv : CInventoryComponent;

	inv = thePlayer.inv;
	inv.GetAllItems( all );

	for ( i = 0; i < all.Size(); i += 1 )
	{
		if ( inv.GetItemCategory( all[i] ) == 'steelsword' )
		{
			ids.PushBack( all[i] );
		}
	}
	return ids.Size();
}

// Finds the best (highest-level) sacrifice and (lowest-level) target pair.
// Returns true if a valid pair exists.
function InfusionFindBestPair( out targetId : SItemUniqueId, out sacrificeId : SItemUniqueId ) : bool
{
	var svc : W3InfusionService;
	var ids : array<SItemUniqueId>;
	var i, j : int;
	var bestGap : int;
	var p : SInfusionPreview;

	svc = InfusionGetService();

	if ( InfusionGetSteelSwords( ids ) < 2 )
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: need at least two steelswords", 5.0 );
		theSound.SoundEvent( "gui_global_denied" );
		return false;
	}

	bestGap = 0;
	for ( i = 0; i < ids.Size(); i += 1 )
	{
		for ( j = 0; j < ids.Size(); j += 1 )
		{
			if ( i == j )
			{
				continue;
			}
			if ( svc.Preview( ids[i], ids[j], p ) == IFE_Ok && p.levelGap > bestGap )
			{
				bestGap = p.levelGap;
				targetId = ids[i];
				sacrificeId = ids[j];
			}
		}
	}

	if ( bestGap <= 0 )
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: no valid pair (sacrifice must be higher level)", 5.0 );
		theSound.SoundEvent( "gui_global_denied" );
		return false;
	}
	return true;
}

exec function infusePreview()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;

	if ( !InfusionFindBestPair( targetId, sacrificeId ) )
	{
		return;
	}

	inv = thePlayer.inv;
	svc = InfusionGetService();
	svc.Preview( targetId, sacrificeId, p );

	theGame.GetGuiManager().ShowNotification(
		"Infusion preview: " + inv.GetItemName( targetId ) + " L" + p.targetLevel
		+ " <- " + inv.GetItemName( sacrificeId ) + " L" + p.sacrificeLevel
		+ ", fee " + p.laborFee, 6.0 );
	theSound.SoundEvent( "gui_crafting_craft_item" );
}

exec function infuseRun()
{
	InfusionRunBestPair();
}

exec function infuseStats()
{
	// Silent by design: verify results in the inventory UI (sword level +
	// durability). Kept as a no-op command for workflow habit.
	theGame.GetGuiManager().ShowNotification( "Infusion: check sword levels in the inventory", 5.0 );
}

// Shared implementation used by the infuseRun console command and infuseSelfTest
// (exec functions cannot call each other directly from script).
function InfusionRunBestPair()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var err : EInfusionError;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;
	var i : int;
	var matText : string;

	if ( !InfusionFindBestPair( targetId, sacrificeId ) )
	{
		return;
	}

	inv = thePlayer.inv;
	svc = InfusionGetService();

	err = svc.Execute( targetId, sacrificeId, p );
	if ( err == IFE_Ok )
	{
		matText = "";
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			if ( i > 0 )
			{
				matText += ", ";
			}
			matText += p.materials[i].itemName + " x" + p.materials[i].quantity;
		}
		if ( matText == "" )
		{
			matText = "(fully covered by salvage)";
		}
		theGame.GetGuiManager().ShowNotification(
			"Infusion OK: " + inv.GetItemName( targetId ) + " is now level " + p.sacrificeLevel, 6.0 );
		theGame.GetGuiManager().ShowNotification( "materials consumed: " + matText, 6.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		theGame.GetGuiManager().ShowNotification(
			"Infusion FAILED: " + InfusionErrorToString( err ), 6.0 );
		theSound.SoundEvent( "gui_global_denied" );
	}
}

// Full self test. Verdict signals:
//   crafting sound ("gui_crafting_craft_item") = ALL checks passed
//   denied sound  ("gui_global_denied")        = at least one check failed
// The final notification summarizes the count; detailed per-check
// notifications fire immediately before (they queue on the HUD).
exec function infuseSelfTest()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var t, s, t2 : array<SItemUniqueId>;
	var silver : array<SItemUniqueId>;
	var equippedSteel : array<SItemUniqueId>;
	var p : SInfusionPreview;
	var passed, failed : int;
	var k : int;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	t  = inv.AddAnItem( 'Novigraadan sword 1', 1, true, true );
	s  = inv.AddAnItem( 'Novigraadan sword 3', 1, true, true );
	t2 = inv.AddAnItem( 'Novigraadan sword 1', 1, true, true );

	if ( t.Size() == 0 || s.Size() == 0 || t2.Size() == 0 )
	{
		theGame.GetGuiManager().ShowNotification( "INFUSION SELFTEST: FAIL (spawn failed)", 6.0 );
		theSound.SoundEvent( "gui_global_denied" );
		return;
	}

	// Guarantee a level advantage for the sacrifice: spawned autogen items
	// both roll to playerLevel-1, so without this the pair is usually equal
	// level and the test fails with IFE_SacrificeNotHigher (spawn RNG from
	// autogen_steel_dmg min7/max8 only rarely produces a +1 gap). Adding ten
	// fixed step abilities makes the sacrifice exactly ten levels higher.
	for ( k = 0; k < 10; k += 1 )
	{
		inv.AddItemCraftedAbility( s[0], 'autogen_fixed_steel_dmg', true );
	}

	LogChannel( 'Infusion', "selftest: spawned " + inv.GetItemName( t[0] ) + " L"
		+ svc.ComputeItemLevel( inv, t[0] ) + " (target), " + inv.GetItemName( s[0] ) + " L"
		+ svc.ComputeItemLevel( inv, s[0] ) + " (sacrifice, boosted +10), "
		+ inv.GetItemName( t2[0] ) + " L" + svc.ComputeItemLevel( inv, t2[0] ) + " (equal-level reject)" );

	// Mark all spawned items so infuseCleanTestItems can remove them later.
	inv.AddItemTag( t[0], 'InfusionTestItem' );
	inv.AddItemTag( s[0], 'InfusionTestItem' );
	inv.AddItemTag( t2[0], 'InfusionTestItem' );

	// 1) same instance as target and sacrifice
	svc.Preview( t[0], t[0], p );
	if ( p.errorCode == IFE_SameItemInstance ) { passed += 1; } else { failed += 1; }
	theGame.GetGuiManager().ShowNotification( "check 1 same-instance: " + InfusionErrorToString( p.errorCode ), 4.0 );

	// 2) equal-level sacrifice (both spawned from the same definition)
	svc.Preview( t[0], t2[0], p );
	if ( p.errorCode == IFE_SacrificeNotHigher ) { passed += 1; } else { failed += 1; }
	theGame.GetGuiManager().ShowNotification( "check 2 equal-level: " + InfusionErrorToString( p.errorCode ), 4.0 );

	// 3) equipped sacrifice — NON-DESTRUCTIVE: use the player's currently
	//    equipped steel sword as the subject instead of equipping a test
	//    item (equipping would steal the steel slot and unequip the
	//    player's weapon). Skipped when no steel sword is equipped.
	equippedSteel = inv.GetItemsByCategory( 'steelsword' );
	k = 0;
	while ( k < equippedSteel.Size() )
	{
		if ( GetWitcherPlayer().IsItemEquipped( equippedSteel[k] ) )
		{
			svc.Preview( t[0], equippedSteel[k], p );
			if ( p.errorCode == IFE_EquippedSacrifice ) { passed += 1; } else { failed += 1; }
			theGame.GetGuiManager().ShowNotification( "check 3 equipped: " + InfusionErrorToString( p.errorCode ), 4.0 );
			break;
		}
		k += 1;
	}
	if ( k >= equippedSteel.Size() )
	{
		passed += 1; // not applicable without an equipped steel sword
		theGame.GetGuiManager().ShowNotification( "check 3 equipped: skipped (no steel sword equipped)", 4.0 );
	}

	// 4) silver-vs-steel compatibility
	silver = inv.GetItemsByCategory( 'silversword' );
	if ( silver.Size() > 0 )
	{
		svc.Preview( t[0], silver[0], p );
		if ( p.errorCode == IFE_CategoryMismatch ) { passed += 1; } else { failed += 1; }
		theGame.GetGuiManager().ShowNotification( "check 4 category: " + InfusionErrorToString( p.errorCode ), 4.0 );
	}
	else
	{
		passed += 1; // no silver sword available: check not applicable
		theGame.GetGuiManager().ShowNotification( "check 4 category: skipped (no silver sword)", 4.0 );
	}

	// 5) real infusion (consumes the sacrifice and materials on success)
	InfusionRunBestPair();

	// Verdict: the infusion itself reports its own sound; here we report the
	// rejection-check tally only.
	if ( failed == 0 )
	{
		theGame.GetGuiManager().ShowNotification( "INFUSION SELFTEST: rejection checks " + passed + "/4 PASS", 6.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		theGame.GetGuiManager().ShowNotification( "INFUSION SELFTEST: " + failed + " of 4 checks FAILED", 6.0 );
		theSound.SoundEvent( "gui_global_denied" );
	}

	// Material sanity print: what the next infusion of a similar pair would
	// require after salvage discount (read-only; from the freshly spawned pair
	// these values were just exercised by the real infusion above).
	svc.Preview( t[0], t2[0], p );
	if ( p.errorCode == IFE_Ok )
	{
		theGame.GetGuiManager().ShowNotification( "material preview (next pair): " + p.materials.Size() + " requirement(s)", 4.0 );
	}
}

// Removes spawned test items. Two populations:
//  a) tagged 'InfusionTestItem' (spawned by the current test code)
//  b) untagged 'Novigraadan sword 1/3' steel swords (spawned by older test
//     builds before tagging existed) — identified by item name + category,
//     which only the test spawner produces for the player.
// Keeps exactly one: the highest-level candidate (typically the infused
// target). Never touches equipped items or any other item types.
exec function infuseCleanTestItems()
{
	var inv : CInventoryComponent;
	var all : array<SItemUniqueId>;
	var candidates : array<SItemUniqueId>;
	var bestId : SItemUniqueId;
	var bestLevel : int;
	var lvl : int;
	var itemName : name;
	var removed, kept : int;
	var i : int;
	var svc : W3InfusionService;

	inv = thePlayer.inv;
	inv.GetAllItems( all );
	svc = InfusionGetService();

	// Collect candidates: tagged test items, plus legacy untagged test swords.
	for ( i = 0; i < all.Size(); i += 1 )
	{
		if ( inv.ItemHasTag( all[i], 'InfusionTestItem' ) )
		{
			candidates.PushBack( all[i] );
			continue;
		}

		// Legacy fallback: test spawner only ever created these two defs.
		itemName = inv.GetItemName( all[i] );
		if ( inv.GetItemCategory( all[i] ) == 'steelsword'
			&& !GetWitcherPlayer().IsItemEquipped( all[i] )
			&& ( itemName == 'Novigraadan sword 1' || itemName == 'Novigraadan sword 3' ) )
		{
			candidates.PushBack( all[i] );
		}
	}

	// Keep the highest-level candidate (the infused trophy), remove the rest.
	removed = 0;
	kept = 0;
	for ( i = 0; i < candidates.Size(); i += 1 )
	{
		lvl = svc.ComputeItemLevel( inv, candidates[i] );
		if ( kept == 0 || lvl > bestLevel )
		{
			if ( kept > 0 )
			{
				inv.RemoveItem( bestId );
				removed += 1;
			}
			bestId = candidates[i];
			bestLevel = lvl;
			kept += 1;
		}
		else
		{
			inv.RemoveItemTag( candidates[i], 'InfusionTestItem' );
			inv.RemoveItem( candidates[i] );
			removed += 1;
		}
	}

	if ( removed > 0 || kept > 0 )
	{
		theGame.GetGuiManager().ShowNotification(
			"Infusion: removed " + removed + " test item(s), kept 1 (level " + bestLevel + ")", 6.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: no test items in inventory", 5.0 );
	}
}

// Negative-case test for the material requirement (spec §5.4/§13.1).
// SIDE-EFFECT-FREE by design: the test removes the recipe materials and the
// required crowns programmatically, runs the infusion (which must be
// rejected with IFE_NotEnoughMaterials and consume nothing), then restores
// the exact previous material and crown counts. The sword pair it spawns is
// removed as well. The inventory and purse are unchanged after the run.
// Result is stored in the 'InfLastTest' fact (1 = pass, 0 = fail) so
// infuseReadLastTest can re-show it after the console is closed.
exec function infuseTestMissingMaterials()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var t, s : array<SItemUniqueId>;
	var p : SInfusionPreview;
	var err : EInfusionError;
	var straps, ingots, swordsBefore, moneyBefore : int;
	var k : int;
	var ok : bool;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	// Capture the full side-effect surface, then neutralize it for the test.
	straps = inv.GetItemQuantityByName( 'Leather straps' );
	ingots = inv.GetItemQuantityByName( 'Steel ingot' );
	moneyBefore = inv.GetMoney();
	LogChannel( 'Infusion', "missing-materials test: setup straps=" + straps + " ingots=" + ingots
		+ " money=" + moneyBefore );

	if ( straps > 0 )
	{
		inv.RemoveItemByName( 'Leather straps', straps );
	}
	if ( ingots > 0 )
	{
		inv.RemoveItemByName( 'Steel ingot', ingots );
	}

	// Quiet spawns/restore: dontInformGui + dontMarkAsNew prevent the
	// "new item" popups that made the restore step look like the test
	// granted hundreds of materials (the counts were unchanged; the popup
	// just announced the re-added stack).

	t = inv.AddAnItem( 'Novigraadan sword 1', 1, true, true );
	s = inv.AddAnItem( 'Novigraadan sword 1', 1, true, true );
	ok = false;
	if ( t.Size() == 0 || s.Size() == 0 )
	{
		LogChannel( 'Infusion', "missing-materials test: ABORTED (spawn failed)" );
	}
	else
	{
		inv.AddItemTag( t[0], 'InfusionTestItem' );
		inv.AddItemTag( s[0], 'InfusionTestItem' );

		// Guarantee the level gap (same mechanism as infuseSelfTest).
		for ( k = 0; k < 10; k += 1 )
		{
			inv.AddItemCraftedAbility( s[0], 'autogen_fixed_steel_dmg', true );
		}

		swordsBefore = inv.GetItemQuantityByName( 'Novigraadan sword 1' );

		// De-money the test: crowns must not influence the material rejection
		// path (temporary grant, reverted below).
		if ( moneyBefore < 1000 )
		{
			inv.AddMoney( 1000 - moneyBefore );
		}

		err = svc.Execute( t[0], s[0], p );
		LogChannel( 'Infusion', "missing-materials test: Execute returned " + InfusionErrorToString( err )
			+ " (expected: missing required crafting materials)" );

		if ( err == IFE_NotEnoughMaterials
			&& inv.GetItemQuantityByName( 'Novigraadan sword 1' ) == swordsBefore
			&& inv.IsIdValid( t[0] ) && inv.IsIdValid( s[0] ) )
		{
			ok = true;
			LogChannel( 'Infusion', "missing-materials test: PASS (rejected, nothing consumed)" );
		}
		else
		{
			LogChannel( 'Infusion', "missing-materials test: FAIL (got " + InfusionErrorToString( err )
				+ ", swords now " + inv.GetItemQuantityByName( 'Novigraadan sword 1' )
				+ " expected " + swordsBefore + ")" );
		}
	}

	// ---- restore the exact previous state (side-effect neutrality) ----
	inv.RemoveItem( t[0] );
	inv.RemoveItem( s[0] );
	if ( straps > 0 )
	{
		inv.AddAnItem( 'Leather straps', straps, true, true );
	}
	if ( ingots > 0 )
	{
		inv.AddAnItem( 'Steel ingot', ingots, true, true );
	}
	if ( inv.GetMoney() > moneyBefore )
	{
		inv.RemoveMoney( inv.GetMoney() - moneyBefore );
	}

	if ( ok )
	{
		FactsSet( "InfLastTest", 1 );
		theGame.GetGuiManager().ShowNotification( "MATERIAL REJECTION TEST: PASS (state restored)", 6.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		FactsSet( "InfLastTest", 0 );
		theGame.GetGuiManager().ShowNotification( "MATERIAL REJECTION TEST: FAIL - run infuseReadLastTest after closing the console", 6.0 );
		theSound.SoundEvent( "gui_global_denied" );
	}
}

// Re-displays the result of the last infuseTestMissingMaterials run.
// Uses two channels: HUD notification AND the HudConsoleMsg ("Game saved"
// style top-left message), because the notification queue can be busy or
// hidden behind the console overlay. Also logs to the file.
exec function infuseReadLastTest()
{
	var hud : CR4ScriptedHud;
	var msg : string;

	if ( FactsDoesExist( "InfLastTest" ) )
	{
		if ( FactsQuerySum( "InfLastTest" ) == 1 )
		{
			msg = "last material rejection test: PASS";
		}
		else
		{
			msg = "last material rejection test: FAIL (or setup failed)";
		}
	}
	else
	{
		msg = "no material rejection test result recorded yet";
	}

	LogChannel( 'Infusion', "infuseReadLastTest: " + msg );
	theGame.GetGuiManager().ShowNotification( msg, 6.0 );
	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		hud.HudConsoleMsg( msg );
	}
}
