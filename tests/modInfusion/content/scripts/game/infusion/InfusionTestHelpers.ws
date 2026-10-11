/***********************************************************************/
/** 	Witcher Gear Infusion — test harness helpers (DEV ONLY, never shipped)
/** 	Shared plumbing for the debug test suite: service construction,
/** 	item spawning/tagging, pair selection, result reporting.
/**
/** 	Files: InfusionDebug.ws (exec entry points), InfusionTestCases.ws
/** 	(test bodies), InfusionTestHelpers.ws (this file).
/***********************************************************************/

// Service factory: constructs the service and injects a fresh config
// instance (production code will inject the real config service).
function InfusionGetService() : W3InfusionService
{
	var svc : W3InfusionService;
	svc = new W3InfusionService in theGame;
	svc.config = new W3InfusionConfig in theGame;
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
// Debug mode: no craftsman context (service bypasses eligibility).
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

// Shared implementation used by the infuseRun console command and the tests
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
			"Infusion OK: " + inv.GetItemName( targetId ) + " is now level " + p.sacrificeLevel, 9.0 );
		theGame.GetGuiManager().ShowNotification( "materials consumed: " + matText, 9.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		theGame.GetGuiManager().ShowNotification(
			"Infusion FAILED: " + InfusionErrorToString( err ), 9.0 );
		theSound.SoundEvent( "gui_global_denied" );
	}
}

// Spawns a quiet (no popup) steel sword and tags it as a test item.
// boostLevels > 0 adds that many fixed step abilities (deterministic level
// advantage). Returns the instance id; invalid on failure.
function InfusionSpawnTestSword( out id : SItemUniqueId, sword3 : bool, boostLevels : int ) : bool
{
	var inv : CInventoryComponent;
	var ids : array<SItemUniqueId>;
	var i : int;

	inv = thePlayer.inv;
	if ( sword3 )
	{
		ids = inv.AddAnItem( 'Novigraadan sword 3', 1, true, true );
	}
	else
	{
		ids = inv.AddAnItem( 'Novigraadan sword 1', 1, true, true );
	}

	if ( ids.Size() == 0 )
	{
		return false;
	}

	id = ids[0];
	inv.AddItemTag( id, 'InfusionTestItem' );

	for ( i = 0; i < boostLevels; i += 1 )
	{
		inv.AddItemCraftedAbility( id, 'autogen_fixed_steel_dmg', true );
	}
	return true;
}

// Test result plumbing: records the outcome of the last test in the
// 'InfLastTest' fact (1 = pass, 0 = fail) and reports it on all channels.
function InfusionReportResult( testName : string, passed : bool, detail : string )
{
	var hud : CR4ScriptedHud;
	var msg : string;

	if ( passed )
	{
		msg = testName + ": PASS";
		if ( detail != "" )
		{
			msg += " (" + detail + ")";
		}
	}
	else
	{
		msg = testName + ": FAIL";
		if ( detail != "" )
		{
			msg += " (" + detail + ")";
		}
	}

	if ( passed )
	{
		FactsSet( "InfLastTest", 1 );
	}
	else
	{
		FactsSet( "InfLastTest", 0 );
	}
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 9.0 );
	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		hud.HudConsoleMsg( msg );
	}
}

function CraftsmanLevelToString( level : ECraftsmanLevel ) : string
{
	switch ( level )
	{
		case ECL_Undefined:    return "none";
		case ECL_Journeyman:   return "journeyman";
		case ECL_Master:       return "master";
		case ECL_Grand_Master: return "grandmaster";
		case ECL_Arch_Master:  return "archmaster";
	}
	return "?";
}
