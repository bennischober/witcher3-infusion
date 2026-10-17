/***********************************************************************/
/** 	Witcher Gear Infusion — debug console entry points (DEV ONLY)
/** 	Thin exec-function wrappers; the test bodies live in
/** 	InfusionTestCases.ws, shared plumbing in InfusionTestHelpers.ws.
/**
/** 	Enabled via the game console (DBGConsoleOn). Commands:
/** 	  infuseHelp       - list commands
/** 	  infuseStats      - pointer to the inventory UI verification
/** 	  infusePreview    - validate best pair (sound = verdict)
/** 	  infuseRun        - execute infusion of the best pair
/** 	  infuseSelfTest   - rejection checks + one real infusion
/** 	  infuseCleanTestItems    - remove spawned test items (keeps one)
/** 	  infuseTestMissingMaterials - sad path; side-effect free
/** 	  infuseReadLastTest     - re-show last test result
/** 	  infuseCraftsmanReport  - report nearby craftsmen (type/tier)
/** 	  infuseSpawnTestSmith   - spawn a test smith (optional master)
/** 	  infuseDespawnTestSmith - remove spawned test smiths
/** 	  infuseOpenMenu         - open the smith/armorer service menu here
/** 	                           (args: armorer, master - both optional)
/** 	  infuseSpawnTestPair    - spawn a valid target + sacrifice (optional armor)
/**
/** 	Output channels (5.01): LogChannel -> scriptslog.txt (-debugscripts),
/** 	notifications + HudConsoleMsg on screen, verdicts via sounds. The
/** 	console overlay can hide notifications fired while it is open; tests
/** 	also persist their result in the 'InfLastTest' fact.
/***********************************************************************/

exec function infuseHelp()
{
	theGame.GetGuiManager().ShowNotification(
		"Infusion: selfTest / cleanTestItems / testMissingMaterials / testEligibility / craftsmanReport / spawnTestSmith / openMenu(armorer, master) / spawnTestPair(armor) / preview / run", 9.0 );
}

exec function infuseStats()
{
	theGame.GetGuiManager().ShowNotification( "Infusion: check sword levels in the inventory", 6.0 );
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
		+ ", fee " + p.laborFee, 9.0 );
	theSound.SoundEvent( "gui_crafting_craft_item" );
}

exec function infuseRun()
{
	InfusionRunBestPair();
}

exec function infuseSelfTest( optional armor : bool )
{
	InfusionTestCaseSelfTest( armor );
}

exec function infuseCleanTestItems()
{
	InfusionCleanTestItems();
}

exec function infuseTestMissingMaterials()
{
	InfusionTestCaseMissingMaterials();
}

exec function infuseReadLastTest()
{
	var hud : CR4ScriptedHud;
	var msg : string;

	if ( FactsDoesExist( "InfLastTest" ) )
	{
		if ( FactsQuerySum( "InfLastTest" ) == 1 )
		{
			msg = "last test: PASS";
		}
		else
		{
			msg = "last test: FAIL (or setup failed)";
		}
	}
	else
	{
		msg = "no test result recorded yet";
	}

	LogChannel( 'Infusion', "infuseReadLastTest: " + msg );
	theGame.GetGuiManager().ShowNotification( msg, 9.0 );
	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		hud.HudConsoleMsg( msg );
	}
}

exec function infuseCraftsmanReport()
{
	InfusionTestCaseCraftsmanReport();
}

exec function infuseSpawnTestSmith( optional master : bool )
{
	InfusionSpawnTestSmith( master );
}

exec function infuseDespawnTestSmith()
{
	InfusionDespawnTestSmith();
}

// Opens the service menu (Repair tab = infusion) with a spawned craftsman,
// anywhere in the world - no travel to an NPC per UI test round.
//   infuseOpenMenu              journeyman swordsmith
//   infuseOpenMenu(true)        journeyman armorer
//   infuseOpenMenu(true, true)  master armorer
//   infuseOpenMenu(false, true) master swordsmith
exec function infuseOpenMenu( optional armorer : bool, optional master : bool )
{
	InfusionOpenServiceMenu( armorer, master );
}

// Spawns a valid infusion pair (ordinary gear, sacrifice +10 levels) so the
// service grid has something to show. infuseSpawnTestPair(true) = armor.
exec function infuseSpawnTestPair( optional armor : bool )
{
	InfusionSpawnTestPair( armor );
}

// Decisive strings test: looks up our loc keys at runtime and logs the
// results. Distinguishes "w3strings file not loaded" (raw key returned)
// from "strings loaded but Flash rendering broken" (proper text returned).
exec function infuseTestStrings()
{
	var label : string;
	var desc : string;
	var button : string;

	label = GetLocStringByKeyExt( "panel_title_infusion" );
	desc = GetLocStringByKeyExt( "panel_title_infusion_desc" );
	button = GetLocStringByKeyExt( "panel_button_inventory_infuse" );

	LogChannel( 'Infusion', "strings test: title='" + label + "' desc='" + desc + "' button='" + button + "'" );

	if ( label == "panel_title_infusion" || label == "" )
	{
		LogChannel( 'Infusion', "strings test: FAILED - w3strings not loaded (raw key or empty returned)" );
		theGame.GetGuiManager().ShowNotification( "STRINGS TEST: NOT LOADED", 8.0 );
	}
	else
	{
		LogChannel( 'Infusion', "strings test: PASSED - strings file loaded and keys resolve" );
		theGame.GetGuiManager().ShowNotification( "STRINGS TEST: LOADED - " + label, 8.0 );
	}
}

// Sets a dev config override via persistent facts (player-invisible):
//   infuseSetConfig('fee', 150)      -> fee fraction = 0.150 (x1000 stored)
//   infuseSetConfig('fee', 0)        -> clear override
//   infuseSetConfig('minfee', 25)    -> minimum labor fee
//   infuseSetConfig('salvage', 1)    -> disable salvage economically (nonzero)
//   infuseSetConfig('salvage', 0)    -> re-enable salvage
exec function infuseSetConfig( key : string, value : int )
{
	var keyNorm : string;

	keyNorm = StrLower( key );

	if ( keyNorm == "fee" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_BaseFee", value );
			LogChannel( 'Infusion', "config override: fee fraction = " + value / 1000.0f );
		}
		else
		{
			FactsRemove( "InfCfg_BaseFee" );
			LogChannel( 'Infusion', "config override: fee fraction cleared (default 0.10)" );
		}
	}
	else if ( keyNorm == "minfee" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_MinFee", value );
			LogChannel( 'Infusion', "config override: min fee = " + value );
		}
		else
		{
			FactsRemove( "InfCfg_MinFee" );
			LogChannel( 'Infusion', "config override: min fee cleared (default 10)" );
		}
	}
	else if ( keyNorm == "salvage" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_Salvage", 1 );
			LogChannel( 'Infusion', "config override: salvage DISABLED" );
		}
		else
		{
			FactsRemove( "InfCfg_Salvage" );
			LogChannel( 'Infusion', "config override: salvage re-enabled" );
		}
	}
	else
	{
		LogChannel( 'Infusion', "infuseSetConfig: unknown key '" + key + "' (fee | minfee | salvage)" );
	}

	theGame.GetGuiManager().ShowNotification( "config override applied - see log", 6.0 );
}

// Dumps the parsed configuration values to the log - the ground truth for
// verifying what the settings menu writes vs. what the config class parses.
exec function infuseDumpConfig()
{
	var c : W3InfusionConfig;

	c = new W3InfusionConfig in theGame;

	LogChannel( 'Infusion', "config dump: enableInfusion=" + c.EnableInfusion()
		+ " steel=" + c.IsCategoryEnabled( 'steelsword' )
		+ " silver=" + c.IsCategoryEnabled( 'silversword' )
		+ " armor=" + c.IsCategoryEnabled( 'armor' ) );
	LogChannel( 'Infusion', "config dump: feeFraction=" + c.GetFeeFraction()
		+ " minFee=" + c.GetMinLaborFee()
		+ " salvage=" + c.SalvageEnabled()
		+ " salvageMult=" + c.SalvageYieldMultiplier()
		+ " restoreDurability=" + c.RestoreTargetDurability() );
	LogChannel( 'Infusion', "config dump: gapMult(10)=" + c.GetLevelGapMultiplier( 10 )
		+ " witcherTierReq=" + c.GetRequiredCraftsmanLevel( 5 ) );

	theGame.GetGuiManager().ShowNotification( "config dumped to log (Infusion channel)", 6.0 );
}
