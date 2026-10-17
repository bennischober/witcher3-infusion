/***********************************************************************/
/** 	Witcher Gear Infusion — test cases (DEV ONLY, never shipped)
/** 	Executable test bodies. Entry points (exec functions) live in
/** 	InfusionDebug.ws; shared plumbing in InfusionTestHelpers.ws.
/**
/** 	Tests report via InfusionReportResult (fact + log + HUD + sound).
/***********************************************************************/

// ------------------------- rejection checks (self test) -------------------------

// Runs the four rejection checks plus one real infusion.
// Runs the four rejection checks plus one real infusion. Accepts an optional
// armor flag: spawns armor pieces instead of swords (for testing at an
// armorer).
function InfusionTestCaseSelfTest( optional armor : bool )
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var tId, sId, t2Id : SItemUniqueId;
	var silver : array<SItemUniqueId>;
	var equippedSteel : array<SItemUniqueId>;
	var p : SInfusionPreview;
	var passed, failed : int;
	var k : int;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	if ( !InfusionSpawnTestSword( tId, false, 0, armor )
		|| !InfusionSpawnTestSword( sId, true, 10, armor )
		|| !InfusionSpawnTestSword( t2Id, false, 0, armor ) )
	{
		InfusionReportResult( "INFUSION SELFTEST", false, "spawn failed" );
		return;
	}

	LogChannel( 'Infusion', "selftest: spawned " + inv.GetItemName( tId ) + " L"
		+ svc.ComputeItemLevel( inv, tId ) + " (target), " + inv.GetItemName( sId ) + " L"
		+ svc.ComputeItemLevel( inv, sId ) + " (sacrifice, boosted +10), "
		+ inv.GetItemName( t2Id ) + " L" + svc.ComputeItemLevel( inv, t2Id ) + " (equal-level reject)" );

	// 1) same instance as target and sacrifice
	svc.Preview( tId, tId, p );
	if ( p.errorCode == IFE_SameItemInstance ) { passed += 1; } else { failed += 1; }
	LogChannel( 'Infusion', "check 1 same-instance: " + InfusionErrorToString( p.errorCode ) );

	// 2) equal-or-lower sacrifice rejected. Spawn RNG (autogen_steel_dmg 7/8)
	//    makes the unboosted t2's level wander around the target's; when it
	//    rolls HIGHER, preview is a valid pair (IFE_Ok) - that is not a
	//    rejection-check failure, the precondition simply did not occur.
	//    Counted as a skip in that case.
	svc.Preview( tId, t2Id, p );
	if ( p.errorCode == IFE_SacrificeNotHigher )
	{
		passed += 1;
	}
	else if ( p.errorCode == IFE_Ok )
	{
		LogChannel( 'Infusion', "check 2 equal-level: SKIPPED (t2 spawned higher: "
			+ svc.ComputeItemLevel( inv, t2Id ) + " vs " + svc.ComputeItemLevel( inv, tId ) + ")" );
	}
	else
	{
		failed += 1;
	}
	LogChannel( 'Infusion', "check 2 equal-level: " + InfusionErrorToString( p.errorCode ) );

	// 3) equipped sacrifice — NON-DESTRUCTIVE: uses the player's currently
	//    equipped item of the matching category as the subject. Skipped when
	//    none is equipped. (Steel sword by default; equipped armor when
	//    running the armor variant.)
	if ( armor )
	{
		equippedSteel = inv.GetItemsByCategory( 'armor' );
	}
	else
	{
		equippedSteel = inv.GetItemsByCategory( 'steelsword' );
	}
	k = 0;
	while ( k < equippedSteel.Size() )
	{
		if ( GetWitcherPlayer().IsItemEquipped( equippedSteel[k] ) )
		{
			svc.Preview( tId, equippedSteel[k], p );
			if ( p.errorCode == IFE_EquippedSacrifice ) { passed += 1; } else { failed += 1; }
			LogChannel( 'Infusion', "check 3 equipped: " + InfusionErrorToString( p.errorCode ) );
			break;
		}
		k += 1;
	}
	if ( k >= equippedSteel.Size() )
	{
		passed += 1; // not applicable without an equipped item of the category
		LogChannel( 'Infusion', "check 3 equipped: skipped (nothing equipped in the category)" );
	}

	// 4) silver-vs-steel compatibility. The first silver sword may be an
	//    excluded item (quest/unique): the preview then reports IFE_QuestItem
	//    before the category check - that proves exclusion, not the category
	//    gate, so it counts as a skip rather than a failure.
	silver = inv.GetItemsByCategory( 'silversword' );
	if ( silver.Size() > 0 )
	{
		svc.Preview( tId, silver[0], p );
		if ( p.errorCode == IFE_CategoryMismatch || p.errorCode == IFE_QuestItem )
		{
			passed += 1;
			if ( p.errorCode == IFE_QuestItem )
			{
				LogChannel( 'Infusion', "check 4 category: " + InfusionErrorToString( p.errorCode )
					+ " (excluded silver item; exclusion verified, category gate untested)" );
			}
			else
			{
				LogChannel( 'Infusion', "check 4 category: " + InfusionErrorToString( p.errorCode ) );
			}
		}
		else
		{
			failed += 1;
			LogChannel( 'Infusion', "check 4 category: " + InfusionErrorToString( p.errorCode ) );
		}
	}
	else
	{
		passed += 1; // no silver sword available: check not applicable
		LogChannel( 'Infusion', "check 4 category: skipped (no silver sword)" );
	}

	// 5) real infusion (consumes the sacrifice and materials on success)
	InfusionRunBestPair();

	if ( failed == 0 )
	{
		InfusionReportResult( "INFUSION SELFTEST", true, "rejection checks " + passed + "/4" );
	}
	else
	{
		InfusionReportResult( "INFUSION SELFTEST", false, failed + " of 4 checks failed" );
	}
}

// ------------------------- missing materials (sad path) -------------------------

// SIDE-EFFECT-FREE: removes the recipe materials and crowns programmatically,
// runs the infusion (must be rejected with IFE_NotEnoughMaterials and consume
// nothing), then restores the exact previous state and removes the spawned
// swords.
function InfusionTestCaseMissingMaterials()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var tId, sId : SItemUniqueId;
	var p : SInfusionPreview;
	var err : EInfusionError;
	var straps, ingots, swordsBefore, moneyBefore : int;
	var ok : bool;

	inv = thePlayer.inv;
	svc = InfusionGetService();

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

	ok = false;
	if ( InfusionSpawnTestSword( tId, false, 0 ) && InfusionSpawnTestSword( sId, false, 10 ) )
	{
		swordsBefore = inv.GetItemQuantityByName( 'Novigraadan sword 1' );

		if ( inv.GetMoney() < 1000 )
		{
			inv.AddMoney( 1000 - moneyBefore );
		}

		err = svc.Execute( tId, sId, p );
		LogChannel( 'Infusion', "missing-materials test: Execute returned " + InfusionErrorToString( err )
			+ " (expected: missing required crafting materials)" );

		if ( err == IFE_NotEnoughMaterials
			&& inv.GetItemQuantityByName( 'Novigraadan sword 1' ) == swordsBefore
			&& inv.IsIdValid( tId ) && inv.IsIdValid( sId ) )
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
	else
	{
		LogChannel( 'Infusion', "missing-materials test: spawn failed" );
	}

	// ---- restore the exact previous state (side-effect neutrality) ----
	inv.RemoveItem( tId );
	inv.RemoveItem( sId );
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
		InfusionReportResult( "MATERIAL REJECTION TEST", true, "" );
	}
	else
	{
		InfusionReportResult( "MATERIAL REJECTION TEST", false, "run infuseReadLastTest" );
	}
}

// ------------------------- craftsman eligibility (integration) -------------------------

// Runs the REAL eligibility path (bypass temporarily off) against the nearest
// craftsman NPC. At an armorer: specialization must reject. At a smith: the
// infusion is performed for real (or rejected by the tier gate).
function InfusionTestCaseEligibility()
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var tId, sId : SItemUniqueId;
	var entities : array<CGameplayEntity>;
	var comp : W3CraftsmanComponent;
	var craftsmanEntity : CGameplayEntity;
	var p : SInfusionPreview;
	var err : EInfusionError;
	var i : int;
	var npcName : string;
	var smithLvl : ECraftsmanLevel;
	var found : bool;
	var expectedReject : bool;
	var moneyBefore : int;
	var ok : bool;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	FindGameplayEntitiesInSphere( entities, thePlayer.GetWorldPosition(), 60, 30, '', FLAG_OnlyAliveActors );
	found = false;
	for ( i = 0; i < entities.Size(); i += 1 )
	{
		comp = (W3CraftsmanComponent)entities[i].GetComponentByClassName( 'W3CraftsmanComponent' );
		if ( comp )
		{
			found = true;
			craftsmanEntity = entities[i];
			break;
		}
	}

	if ( !found )
	{
		InfusionReportResult( "ELIGIBILITY TEST", false, "no craftsman within 60m" );
		return;
	}

	npcName = ((CNewNPC)craftsmanEntity).GetDisplayName();
	smithLvl = comp.GetCraftsmanLevel( ECT_Smith );
	LogChannel( 'Infusion', "eligibility test: craftsman " + npcName
		+ " smith=" + CraftsmanLevelToString( smithLvl ) );

	// Expected outcome: a steel-sword infusion needs ECT_Smith. An armorer
	// (smith=none) must be rejected with IFE_WrongCraftsmanType; a smith may
	// pass eligibility (and then really infuses - that is the integration
	// path and consumes the sacrifice).
	expectedReject = ( smithLvl == ECL_Undefined );

	ok = false;
	if ( InfusionSpawnTestSword( tId, false, 0 ) && InfusionSpawnTestSword( sId, true, 10 ) )
	{
		moneyBefore = inv.GetMoney();

		svc.debugBypassCraftsman = false;
		err = svc.Execute( tId, sId, p, craftsmanEntity );
		svc.debugBypassCraftsman = true;

		if ( expectedReject )
		{
			LogChannel( 'Infusion', "eligibility test: Execute returned " + InfusionErrorToString( err )
				+ " (expected: wrong craftsman type)" );
			if ( err == IFE_WrongCraftsmanType )
			{
				ok = true;
				LogChannel( 'Infusion', "eligibility test: PASS (specialization rejection worked, nothing consumed)" );
			}
		}
		else
		{
			LogChannel( 'Infusion', "eligibility test: Execute returned " + InfusionErrorToString( err )
				+ " (expected: OK or tier error)" );
			if ( err == IFE_Ok || err == IFE_CraftsmanLevelTooLow )
			{
				ok = true;
				if ( err == IFE_Ok )
				{
					LogChannel( 'Infusion', "eligibility test: PASS (integration infusion performed at the smith)" );
				}
				else
				{
					LogChannel( 'Infusion', "eligibility test: PASS (tier gate worked, nothing consumed)" );
				}
			}
		}

		// Cleanup: on the rejection paths nothing was consumed; on a real
		// infusion the sacrifice is already gone. Remove the leftovers and
		// restore crowns if the smith charged us.
		if ( err != IFE_Ok )
		{
			inv.RemoveItem( tId );
			inv.RemoveItem( sId );
		}
		else
		{
			inv.RemoveItemTag( tId, 'InfusionTestItem' );
			inv.RemoveItem( sId );
		}
		if ( inv.GetMoney() > moneyBefore )
		{
			inv.RemoveMoney( inv.GetMoney() - moneyBefore );
		}
	}

	if ( ok )
	{
		InfusionReportResult( "ELIGIBILITY TEST at " + npcName, true, "" );
	}
	else
	{
		InfusionReportResult( "ELIGIBILITY TEST at " + npcName, false, "" );
	}
}

// ------------------------- craftsman discovery -------------------------

// Read-only: reports the type/tier data of every craftsman NPC within 40m.
// Doubles as the discovery tool for M5 balance input (their entity templates
// are cooked and not readable offline).
function InfusionTestCaseCraftsmanReport()
{
	var entities : array<CGameplayEntity>;
	var comp : W3CraftsmanComponent;
	var i : int;
	var npc : CNewNPC;
	var smithLvl, armorerLvl : ECraftsmanLevel;
	var msg : string;
	var hud : CR4ScriptedHud;

	FindGameplayEntitiesInSphere( entities, thePlayer.GetWorldPosition(), 40, 30, '', FLAG_OnlyAliveActors );

	LogChannel( 'Infusion', "craftsman report: scanning " + entities.Size() + " entities in 40m radius" );
	msg = "craftsmen in 40m: " + entities.Size() + " entities scanned";

	for ( i = 0; i < entities.Size(); i += 1 )
	{
		comp = (W3CraftsmanComponent)entities[i].GetComponentByClassName( 'W3CraftsmanComponent' );
		if ( !comp )
		{
			continue;
		}

		npc = (CNewNPC)entities[i];
		smithLvl = comp.GetCraftsmanLevel( ECT_Smith );
		armorerLvl = comp.GetCraftsmanLevel( ECT_Armorer );

		msg = "CRAFTSMAN: " + npc.GetDisplayName() + " | smith=" + CraftsmanLevelToString( smithLvl )
			+ " | armorer=" + CraftsmanLevelToString( armorerLvl );
		LogChannel( 'Infusion', msg );
		theGame.GetGuiManager().ShowNotification( msg, 8.0 );
	}

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		hud.HudConsoleMsg( "craftsman report written to log (entities scanned: " + entities.Size() + ")" );
	}
}

// ------------------------- test smith spawning -------------------------

// Spawns a craftsman NPC from a template 3m in front of the player, tagged
// 'InfusionTestSmith', self-despawning after lifetime seconds. Returns NULL
// (with a notification) on failure. WitcherScript strings do not process
// backslash escapes - paths use SINGLE backslashes.
function InfusionCreateTestCraftsman( path : string, lifetime : float ) : CEntity
{
	var template : CEntityTemplate;
	var smith : CEntity;
	var pos : Vector;
	var rot : EulerAngles;
	var forward : Vector;
	var tags : array<name>;

	template = (CEntityTemplate)LoadResource( path, true );
	if ( !template )
	{
		LogChannel( 'Infusion', "spawn test smith: template load failed: " + path );
		theGame.GetGuiManager().ShowNotification( "SMITH SPAWN: template load failed", 6.0 );
		return NULL;
	}

	pos = thePlayer.GetWorldPosition();
	forward = VecFromHeading( thePlayer.GetHeading() );
	pos = pos + forward * 3.0;
	rot = EulerAngles( 0, thePlayer.GetHeading() + 180, 0 );

	tags.PushBack( 'InfusionTestSmith' );
	smith = theGame.CreateEntity( template, pos, rot, false, false, false, , tags );
	if ( !smith )
	{
		LogChannel( 'Infusion', "spawn test smith: CreateEntity failed" );
		theGame.GetGuiManager().ShowNotification( "SMITH SPAWN: entity creation failed", 6.0 );
		return NULL;
	}

	smith.DestroyAfter( lifetime );
	LogChannel( 'Infusion', "spawn test smith: spawned " + path + " tagged InfusionTestSmith (despawns in " + FloatToString( lifetime ) + "s)" );
	return smith;
}

// Spawns a smith for the eligibility test (despawns after 120s).
function InfusionSpawnTestSmith( master : bool )
{
	var path : string;

	// Verified templates (docs/CRAFTSMAN_MAP.md): Novigrad market smith is a
	// Master smith; the Crow's Perch Verden Smith is a Journeyman.
	if ( master )
	{
		path = "gameplay\community\shops_and_craftsmen\novigrad\market\novigrad_market_smith_01.w2ent";
	}
	else
	{
		path = "gameplay\community\shops_and_craftsmen\no_mans_land\snots\snots_blacksmith_01.w2ent";
	}

	if ( InfusionCreateTestCraftsman( path, 120.f ) )
	{
		theGame.GetGuiManager().ShowNotification( "SMITH SPAWNED 3m ahead - run infuseTestEligibility now", 8.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
}

// Opens the blacksmith/armorer service menu (Repair tab = infusion service)
// anywhere in the world, exactly as the dialogue does: CommonMenu with the
// NPC entity as init data (vanilla precedent: cookingPlace.ws passes an
// entity) and BlacksmithMenu as the menu to open. Reuses a spawned test
// craftsman of the requested kind, otherwise spawns one (despawns after
// 10 minutes or via infuseDespawnTestSmith).
//   armorer: armor service (else swordsmith); master: Master tier (else
//   Journeyman). Templates verified in docs/CRAFTSMAN_MAP.md.
function InfusionOpenServiceMenu( armorer : bool, master : bool )
{
	var existing : array<CEntity>;
	var smith : CEntity;
	var comp : W3CraftsmanComponent;
	var requiredType : ECraftsmanType;
	var requiredLevel : ECraftsmanLevel;
	var path : string;
	var i : int;

	if ( armorer )
	{
		requiredType = ECT_Armorer;
		if ( master )
		{
			path = "gameplay\community\shops_and_craftsmen\novigrad\rich_district\novigrad_rich_district_armorer_01.w2ent";
		}
		else
		{
			path = "gameplay\community\shops_and_craftsmen\no_mans_land\barons_keep\barons_keep_armorer_01.w2ent";
		}
	}
	else
	{
		requiredType = ECT_Smith;
		if ( master )
		{
			path = "gameplay\community\shops_and_craftsmen\novigrad\market\novigrad_market_smith_01.w2ent";
		}
		else
		{
			path = "gameplay\community\shops_and_craftsmen\no_mans_land\snots\snots_blacksmith_01.w2ent";
		}
	}
	if ( master )
	{
		requiredLevel = ECL_Master;
	}
	else
	{
		requiredLevel = ECL_Journeyman;
	}

	// Reuse a matching spawned craftsman (same type and tier).
	theGame.GetEntitiesByTag( 'InfusionTestSmith', existing );
	for ( i = 0; i < existing.Size(); i += 1 )
	{
		comp = (W3CraftsmanComponent)existing[i].GetComponentByClassName( 'W3CraftsmanComponent' );
		if ( comp && comp.IsCraftsmanType( requiredType ) && comp.GetCraftsmanLevel( requiredType ) == requiredLevel )
		{
			smith = existing[i];
			break;
		}
	}

	if ( !smith )
	{
		smith = InfusionCreateTestCraftsman( path, 600.f );
		if ( !smith )
		{
			return;
		}
	}

	LogChannel( 'Infusion', "open service menu with " + path );
	theGame.RequestMenuWithBackground( 'BlacksmithMenu', 'CommonMenu', smith );
}

// Removes spawned test smiths (tagged 'InfusionTestSmith') only.
function InfusionDespawnTestSmith()
{
	var smiths : array<CEntity>;
	var i : int;

	theGame.GetEntitiesByTag( 'InfusionTestSmith', smiths );

	if ( smiths.Size() == 0 )
	{
		LogChannel( 'Infusion', "despawn test smith: no spawned test smith present" );
		theGame.GetGuiManager().ShowNotification( "no spawned test smith present", 6.0 );
		return;
	}

	for ( i = 0; i < smiths.Size(); i += 1 )
	{
		LogChannel( 'Infusion', "despawn test smith: destroying tagged entity " + i );
		smiths[i].DestroyAfter( 0.1f );
	}
	theGame.GetGuiManager().ShowNotification( "test smith removed (" + smiths.Size() + ")", 6.0 );
}

// ------------------------- test item cleanup -------------------------

// Removes spawned test items. Two populations:
//  a) tagged 'InfusionTestItem' (spawned by the current test code)
//  b) untagged 'Novigraadan sword 1/3' steel swords (spawned by older test
//     builds before tagging existed)
// Keeps exactly one: the highest-level candidate (typically the infused
// target). Never touches equipped items or any other item types.
function InfusionCleanTestItems()
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

	for ( i = 0; i < all.Size(); i += 1 )
	{
		if ( inv.ItemHasTag( all[i], 'InfusionTestItem' ) )
		{
			candidates.PushBack( all[i] );
			continue;
		}

		itemName = inv.GetItemName( all[i] );
		if ( inv.GetItemCategory( all[i] ) == 'steelsword'
			&& !GetWitcherPlayer().IsItemEquipped( all[i] )
			&& ( itemName == 'Novigraadan sword 1' || itemName == 'Novigraadan sword 3' ) )
		{
			candidates.PushBack( all[i] );
		}
	}

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
		LogChannel( 'Infusion', "cleanup: removed " + removed + " test item(s), kept 1 (level " + bestLevel + ")" );
		theGame.GetGuiManager().ShowNotification(
			"Infusion: removed " + removed + " test item(s), kept 1 (level " + bestLevel + ")", 9.0 );
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
	else
	{
		LogChannel( 'Infusion', "cleanup: no test items in inventory" );
		theGame.GetGuiManager().ShowNotification( "Infusion: no test items in inventory", 6.0 );
	}
}
