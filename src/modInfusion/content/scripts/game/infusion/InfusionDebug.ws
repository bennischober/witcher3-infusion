/***********************************************************************/
/** 	Witcher Gear Infusion — Milestone 2 prototype
/** 	Debug console entry points (spec §9.3 alternative; discovery §7 option 3).
/**
/** 	Enabled via the game console (DBGConsoleOn). Commands:
/** 	  infuseStats      - show computed levels for all steelswords in inventory
/** 	  infusePreview    - preview the best target/sacrifice pair
/** 	  infuseRun        - execute infusion of the best pair
/** 	  infuseSelfTest   - spawn test swords, run invalid + valid transactions, report
/**
/** 	All commands are read-only except infuseRun/infuseSelfTest, which perform a
/** 	fully validated transaction (the service aborts without consuming on failure).
/***********************************************************************/

exec function infuseHelp()
{
	LogChannel( 'Infusion', "Infusion debug commands:" );
	LogChannel( 'Infusion', "  infuseStats      - compute levels of all steelswords in inventory" );
	LogChannel( 'Infusion', "  infusePreview    - preview the best target/sacrifice pair" );
	LogChannel( 'Infusion', "  infuseRun        - run the infusion of the best pair" );
	LogChannel( 'Infusion', "  infuseSelfTest   - spawn test swords, run validation and one infusion" );
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
// Returns true if a valid pair exists (also fills err for diagnostics).
function InfusionFindBestPair( out targetId : SItemUniqueId, out sacrificeId : SItemUniqueId, out err : EInfusionError ) : bool
{
	var svc : W3InfusionService;
	var ids : array<SItemUniqueId>;
	var i, j : int;
	var bestGap : int;
	var p : SInfusionPreview;

	svc = InfusionGetService();
	err = IFE_SacrificeNotHigher;

	if ( InfusionGetSteelSwords( ids ) < 2 )
	{
		LogChannel( 'Infusion', "need at least two steelswords in inventory" );
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
		LogChannel( 'Infusion', "no valid pair found (need a sacrifice strictly higher level than the target)" );
		return false;
	}
	return true;
}

exec function infusePreview()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var err : EInfusionError;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;
	var msg : string;

	inv = thePlayer.inv;

	if ( !InfusionFindBestPair( targetId, sacrificeId, err ) )
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: no valid pair (need sacrifice > target level)", 5.0 );
		return;
	}

	svc = InfusionGetService();
	svc.Preview( targetId, sacrificeId, p );

	msg = "target " + inv.GetItemName( targetId ) + " (level " + p.targetLevel + ")"
		+ " <- sacrifice " + inv.GetItemName( sacrificeId ) + " (level " + p.sacrificeLevel + ")";
	LogChannel( 'Infusion', "preview: " + msg );
	theGame.GetGuiManager().ShowNotification( msg, 6.0 );

	msg = "gap=" + p.levelGap + "  newLevel=" + p.newLevel
		+ "  ability=" + p.stepAbility + "  fee=" + p.laborFee;
	LogChannel( 'Infusion', "  " + msg );
	theGame.GetGuiManager().ShowNotification( msg, 6.0 );
}

exec function infuseRun()
{
	InfusionRunBestPair();
}

exec function infuseStats()
{
	InfusionPrintStats();
}

// Spawns two vanilla steelswords, verifies rejection rules, then performs one
// real infusion and reports the results. The sacrifice is consumed on success.
exec function infuseSelfTest()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var t, s, t2 : array<SItemUniqueId>;
	var silver : array<SItemUniqueId>;
	var p : SInfusionPreview;
	var msg : string;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	LogChannel( 'Infusion', "--- self test: spawn items ---" );
	t  = inv.AddAnItem( 'Novigraadan sword 1', 1 );
	s  = inv.AddAnItem( 'Novigraadan sword 3', 1 );
	t2 = inv.AddAnItem( 'Novigraadan sword 1', 1 );

	if ( t.Size() == 0 || s.Size() == 0 || t2.Size() == 0 )
	{
		msg = "SELFTEST FAIL: could not spawn test items";
		LogChannel( 'Infusion', msg );
		theGame.GetGuiManager().ShowNotification( msg, 6.0 );
		return;
	}

	LogChannel( 'Infusion', "--- self test: rejection checks (nothing may be consumed) ---" );

	// same instance as target and sacrifice
	svc.Preview( t[0], t[0], p );
	msg = "1/4 same-instance: " + InfusionErrorToString( p.errorCode );
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 5.0 );

	// equal-level sacrifice (both spawned from the same definition)
	svc.Preview( t[0], t2[0], p );
	msg = "2/4 equal-level: " + InfusionErrorToString( p.errorCode );
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 5.0 );

	// equipped sacrifice
	thePlayer.EquipItem( s[0] );
	svc.Preview( t[0], s[0], p );
	msg = "3/4 equipped: " + InfusionErrorToString( p.errorCode );
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 5.0 );
	thePlayer.UnequipItem( s[0] );

	// silver-vs-steel compatibility: any silver sword present?
	silver = inv.GetItemsByCategory( 'silversword' );
	if ( silver.Size() > 0 )
	{
		svc.Preview( t[0], silver[0], p );
		msg = "4/4 category: " + InfusionErrorToString( p.errorCode );
	}
	else
	{
		msg = "4/4 category: skipped (no silver sword)";
	}
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 5.0 );

	LogChannel( 'Infusion', "--- self test: real infusion (Novigraadan sword 1 <- Novigraadan sword 3) ---" );
	InfusionRunBestPair();

	InfusionPrintStats();

	LogChannel( 'Infusion', "--- self test done ---" );
	theGame.GetGuiManager().ShowNotification( "Infusion self test done", 4.0 );
}

// Shared implementation used by the infuseRun / infuseStats console commands and
// by infuseSelfTest (exec functions cannot call each other directly from script).
function InfusionRunBestPair()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var err : EInfusionError;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;
	var msg : string;

	inv = thePlayer.inv;

	if ( !InfusionFindBestPair( targetId, sacrificeId, err ) )
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: no valid pair found", 5.0 );
		return;
	}

	svc = InfusionGetService();

	err = svc.Execute( targetId, sacrificeId, p );
	if ( err == IFE_Ok )
	{
		msg = "Infusion OK: " + inv.GetItemName( targetId ) + " is now level " + p.sacrificeLevel;
		LogChannel( 'Infusion', msg );
		theGame.GetGuiManager().ShowNotification( msg, 6.0 );
	}
	else
	{
		msg = "Infusion FAILED: " + InfusionErrorToString( err );
		LogChannel( 'Infusion', msg );
		theGame.GetGuiManager().ShowNotification( msg, 6.0 );
	}
}

// Shared implementation behind the infuseStats console command.
function InfusionPrintStats()
{
	var svc : W3InfusionService;
	var ids : array<SItemUniqueId>;
	var i : int;
	var lvl : int;
	var inv : CInventoryComponent;
	var witcher : W3PlayerWitcher;
	var stat : SAbilityAttributeValue;
	var msg : string;

	svc = InfusionGetService();
	inv = thePlayer.inv;
	witcher = GetWitcherPlayer();

	if ( InfusionGetSteelSwords( ids ) == 0 )
	{
		theGame.GetGuiManager().ShowNotification( "Infusion: no steelswords in inventory", 4.0 );
		LogChannel( 'Infusion', "no steelswords in inventory" );
		return;
	}

	LogChannel( 'Infusion', "steelswords in inventory:" );
	for ( i = 0; i < ids.Size(); i += 1 )
	{
		lvl = svc.ComputeItemLevel( inv, ids[i] );
		stat = inv.GetItemAttributeValue( ids[i], 'SlashingDamage' );
		msg = "  [" + i + "] " + inv.GetItemName( ids[i] )
			+ "  level=" + lvl
			+ "  slashing=" + stat.valueBase
			+ "  quest=" + inv.IsItemQuest( ids[i] )
			+ "  equipped=" + witcher.IsItemEquipped( ids[i] );
		LogChannel( 'Infusion', msg );
		theGame.GetGuiManager().ShowNotification( msg, 4.0 );
	}
}
