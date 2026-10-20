/***********************************************************************/
/** 	Witcher Gear Infusion — debug console commands (DEV ONLY)
/** 	Thin exec wrappers; scenario tests live in InfusionScenarios.ws,
/** 	shared helpers in InfusionTestTools.ws. Console: DBGConsoleOn.
/**
/** 	  infuseScenarioAll          - run every scenario, PASS/FAIL/SKIP summary
/** 	  infuseScenario(name)       - run one scenario
/** 	  infuseScenarioN(n)         - same, by number from infuseScenarioList
/** 	  infuseScenarioList         - list the scenario names
/** 	  infuseScenarioPersistCheck - after infuseScenario(persist) + save/reload
/** 	  infuseOpenMenu             - open the smith/armorer menu here
/** 	                               (args: armorer, master - both optional)
/** 	  infuseSpawnTestPair        - spawn a valid target + sacrifice (optional armor)
/** 	  infuseCleanTestItems       - remove spawned test items (keeps one)
/** 	  infuseDespawnTestSmith     - remove spawned test craftsmen
/** 	  infuseCraftsmanReport      - report nearby craftsmen (type/tier)
/** 	  infusePriceProbe           - fee anchor vs. the nearest craftsman's prices
/** 	  infusePriceProbeAll        - same for spawned regional craftsman templates
/** 	  infuseBalanceReport        - fees and materials at L30-150 per craftsman tier
/** 	  infuseSetConfig(key, n)    - dev config override (fee/minfee/salvage/materials/debug)
/** 	  infuseDumpConfig           - log the effective configuration
/** 	  infuseTestStrings          - check that the mod's strings load
/**
/** 	Output: LogChannel -> scriptslog.txt (-debugscripts); notifications and
/** 	HudConsoleMsg on screen (shown after closing the console).
/***********************************************************************/

exec function infuseHelp()
{
	theGame.GetGuiManager().ShowNotification(
		"Infusion: scenarioAll / scenario(name) / scenarioN(n) / scenarioList / scenarioPersistCheck / openMenu(armorer, master) / spawnTestPair(armor) / cleanTestItems / despawnTestSmith / craftsmanReport / balanceReport / setConfig(key, n) / dumpConfig / testStrings", 9.0 );
}

exec function infuseCleanTestItems()
{
	InfusionCleanTestItems();
}

exec function infuseCraftsmanReport()
{
	InfusionCraftsmanReport();
}

// Price experiment: fee anchor vs. the nearest craftsman's prices (log).
exec function infusePriceProbe()
{
	InfusionPriceProbe();
}

// Same for regional craftsman templates spawned here (Velen, Novigrad,
// Skellige) - no travelling needed.
exec function infusePriceProbeAll()
{
	InfusionPriceProbeTemplates();
}

// Spec §6.4: what infusions cost at L30/60/100/150 for every craftsman tier
// (log). The first run spawns the craftsmen; run it again if it says so.
exec function infuseBalanceReport()
{
	InfusionBalanceReport();
}

exec function infuseDespawnTestSmith()
{
	InfusionDespawnTestSmith();
}

// Opens the service menu with a spawned craftsman, anywhere in the world -
// no travel to an NPC per UI test round.
//   infuseOpenMenu              journeyman swordsmith
//   infuseOpenMenu(true)        journeyman armorer
//   infuseOpenMenu(true, true)  master armorer
//   infuseOpenMenu(false, true) master swordsmith
exec function infuseOpenMenu( optional armorer : bool, optional master : bool )
{
	InfusionOpenServiceMenu( armorer, master );
}

// Spawns a valid infusion pair (ordinary gear, sacrifice +10 levels) so the
// Infusion tab has something to show. infuseSpawnTestPair(true) = armor.
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
//   infuseSetConfig('fee', 1500)     -> fee = 1.5 x the craftsman's full repair (x1000 stored)
//   infuseSetConfig('fee', 0)        -> clear override
//   infuseSetConfig('minfee', 25)    -> minimum labor fee
//   infuseSetConfig('salvage', 1)    -> disable salvage (full recipe, no discount)
//   infuseSetConfig('salvage', 0)    -> re-enable salvage
//   infuseSetConfig('materials', 1)  -> no material requirements (labor fee only)
//   infuseSetConfig('debug', 1)      -> per-item grid logging on (0 = off)
exec function infuseSetConfig( key : string, value : int )
{
	var keyNorm : string;

	keyNorm = StrLower( key );

	if ( keyNorm == "fee" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_BaseFee", value );
			LogChannel( 'Infusion', "config override: fee multiplier = " + value / 1000.0f );
		}
		else
		{
			FactsRemove( "InfCfg_BaseFee" );
			LogChannel( 'Infusion', "config override: fee multiplier cleared (default 1.0)" );
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
	else if ( keyNorm == "materials" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_NoMaterials", 1 );
			LogChannel( 'Infusion', "config override: material requirements DISABLED" );
		}
		else
		{
			FactsRemove( "InfCfg_NoMaterials" );
			LogChannel( 'Infusion', "config override: material requirements re-enabled" );
		}
	}
	else if ( keyNorm == "debug" )
	{
		if ( value > 0 )
		{
			FactsSet( "InfCfg_Debug", 1 );
			LogChannel( 'Infusion', "config override: grid debug logging ON" );
		}
		else
		{
			FactsRemove( "InfCfg_Debug" );
			LogChannel( 'Infusion', "config override: grid debug logging off" );
		}
	}
	else
	{
		LogChannel( 'Infusion', "infuseSetConfig: unknown key '" + key + "' (fee | minfee | salvage | materials | debug)" );
	}

	theGame.GetGuiManager().ShowNotification( "config override applied - see log", 6.0 );
}

// Logs the effective configuration (defaults plus console overrides).
exec function infuseDumpConfig()
{
	var c : W3InfusionConfig;

	c = new W3InfusionConfig in theGame;

	LogChannel( 'Infusion', "config dump: enableInfusion=" + c.EnableInfusion()
		+ " steel=" + c.IsCategoryEnabled( 'steelsword' )
		+ " silver=" + c.IsCategoryEnabled( 'silversword' )
		+ " armor=" + c.IsCategoryEnabled( 'armor' ) );
	LogChannel( 'Infusion', "config dump: feeMultiplier=" + c.GetFeeMultiplier()
		+ " fallbackValueFraction=" + c.GetFallbackValueFraction()
		+ " minFee=" + c.GetMinLaborFee()
		+ " materials=" + c.RequireCraftingMaterials()
		+ " salvage=" + c.SalvageEnabled()
		+ " salvageMult=" + c.SalvageYieldMultiplier()
		+ " restoreDurability=" + c.RestoreTargetDurability()
		+ " debugLog=" + c.DebugLogging() );
	LogChannel( 'Infusion', "config dump: gapMult(10)=" + c.GetLevelGapMultiplier( 10 )
		+ " witcherTierReq=" + c.GetRequiredCraftsmanLevel( 5 ) );

	theGame.GetGuiManager().ShowNotification( "config dumped to log (Infusion channel)", 6.0 );
}

// ---- scenario tests (InfusionScenarios.ws) ----

exec function infuseScenarioAll()
{
	InfusionRunAllScenarios();
}

exec function infuseScenario( scenarioName : name )
{
	InfusionRunScenario( scenarioName );
}

exec function infuseScenarioN( index : int )
{
	InfusionRunScenarioByIndex( index );
}

exec function infuseScenarioList()
{
	InfusionListScenarios();
}

exec function infuseScenarioPersistCheck()
{
	InfusionScenarioPersistCheck();
}
