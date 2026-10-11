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
/**
/** 	Output channels (5.01): LogChannel -> scriptslog.txt (-debugscripts),
/** 	notifications + HudConsoleMsg on screen, verdicts via sounds. The
/** 	console overlay can hide notifications fired while it is open; tests
/** 	also persist their result in the 'InfLastTest' fact.
/***********************************************************************/

exec function infuseHelp()
{
	theGame.GetGuiManager().ShowNotification(
		"Infusion: selfTest / cleanTestItems / testMissingMaterials / testEligibility / craftsmanReport / spawnTestSmith / preview / run", 9.0 );
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

exec function infuseSelfTest()
{
	InfusionTestCaseSelfTest();
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

exec function infuseTestEligibility()
{
	InfusionTestCaseEligibility();
}
