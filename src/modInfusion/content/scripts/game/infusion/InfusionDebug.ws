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

exec function infuseStats()
{
	var svc : W3InfusionService;
	var ids : array<SItemUniqueId>;
	var i : int;
	var lvl : int;
	var inv : CInventoryComponent;

	svc = InfusionGetService();
	inv = thePlayer.inv;

	if ( InfusionGetSteelSwords( ids ) == 0 )
	{
		LogChannel( 'Infusion', "no steelswords in inventory" );
		return;
	}

	LogChannel( 'Infusion', "steelswords in inventory:" );
	for ( i = 0; i < ids.Size(); i += 1 )
	{
		lvl = svc.ComputeItemLevel( inv, ids[i] );
		LogChannel( 'Infusion', "  [" + i + "] " + inv.GetItemName( ids[i] )
			+ "  level=" + lvl
			+ "  slashing=" + inv.GetItemAttributeValue( ids[i], 'SlashingDamage' ).valueBase
			+ "  quest=" + inv.IsItemQuest( ids[i] )
			+ "  equipped=" + thePlayer.IsItemEquipped( ids[i] ) );
	}
}

exec function infusePreview()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var err : EInfusionError;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;

	inv = thePlayer.inv;

	if ( !InfusionFindBestPair( targetId, sacrificeId, err ) )
	{
		return;
	}

	svc = InfusionGetService();
	svc.Preview( targetId, sacrificeId, p );

	LogChannel( 'Infusion', "preview: target " + inv.GetItemName( targetId ) + " (level " + p.targetLevel + ")"
		+ " <- sacrifice " + inv.GetItemName( sacrificeId ) + " (level " + p.sacrificeLevel + ")" );
	LogChannel( 'Infusion', "  gap=" + p.levelGap + "  newLevel=" + p.newLevel
		+ "  ability=" + p.stepAbility + "  fee=" + p.laborFee );
}

exec function infuseRun()
{
	var svc : W3InfusionService;
	var targetId, sacrificeId : SItemUniqueId;
	var err : EInfusionError;
	var p : SInfusionPreview;
	var inv : CInventoryComponent;

	inv = thePlayer.inv;

	if ( !InfusionFindBestPair( targetId, sacrificeId, err ) )
	{
		return;
	}

	svc = InfusionGetService();

	err = svc.Execute( targetId, sacrificeId, p );
	if ( err == IFE_Ok )
	{
		LogChannel( 'Infusion', "infusion complete: " + inv.GetItemName( targetId )
			+ " is now level " + p.sacrificeLevel );
	}
	else
	{
		LogChannel( 'Infusion', "infusion failed: " + InfusionErrorToString( err ) );
	}
}

// Spawns two vanilla steelswords, verifies rejection rules, then performs one
// real infusion and reports the results. The sacrifice is consumed on success.
exec function infuseSelfTest()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var t, s, t2 : array<SItemUniqueId>;
	var p : SInfusionPreview;
	var err : EInfusionError;
	var targetId, sacrificeId : SItemUniqueId;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	LogChannel( 'Infusion', "--- self test: spawn items ---" );
	t  = inv.AddAnItem( 'Novigraadan sword 1', 1 );
	s  = inv.AddAnItem( 'Novigraadan sword 3', 1 );
	t2 = inv.AddAnItem( 'Novigraadan sword 1', 1 );

	if ( t.Size() == 0 || s.Size() == 0 || t2.Size() == 0 )
	{
		LogChannel( 'Infusion', "FAIL: could not spawn test items (wrong item names?)" );
		return;
	}

	LogChannel( 'Infusion', "--- self test: rejection checks (nothing may be consumed) ---" );

	// same instance as target and sacrifice
	svc.Preview( t[0], t[0], p );
	LogChannel( 'Infusion', "  same-instance check: " + InfusionErrorToString( p.errorCode ) + " (expect: target and sacrifice must be different items)" );

	// equal-level sacrifice (both spawned from the same definition)
	svc.Preview( t[0], t2[0], p );
	LogChannel( 'Infusion', "  equal-level check: " + InfusionErrorToString( p.errorCode ) + " (expect: sacrifice must be higher level than target)" );

	// equipped sacrifice
	thePlayer.EquipItem( s[0] );
	svc.Preview( t[0], s[0], p );
	LogChannel( 'Infusion', "  equipped-sacrifice check: " + InfusionErrorToString( p.errorCode ) + " (expect: sacrifice item is equipped)" );
	thePlayer.UnequipItem( s[0] );

	// silver-vs-steel compatibility: any silver sword present?
	if ( inv.GetItemsByCategory( 'silversword' ).Size() > 0 )
	{
		svc.Preview( t[0], inv.GetItemsByCategory( 'silversword' )[0], p );
		LogChannel( 'Infusion', "  category check: " + InfusionErrorToString( p.errorCode ) + " (expect: target and sacrifice are incompatible)" );
	}
	else
	{
		LogChannel( 'Infusion', "  category check: skipped (no silver sword in inventory)" );
	}

	LogChannel( 'Infusion', "--- self test: real infusion (Novigraadan sword 1 <- Novigraadan sword 3) ---" );
	infuseRun();

	infuseStats();

	LogChannel( 'Infusion', "--- self test done. Verify: sacrifice gone, target level raised, durability 100%. Save, reload, run infuseStats again. ---" );
}
