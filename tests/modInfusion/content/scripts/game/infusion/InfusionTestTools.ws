/***********************************************************************/
/** 	Witcher Gear Infusion — test tools (DEV ONLY, never shipped)
/** 	Shared helpers for the console commands (InfusionDebug.ws) and the
/** 	scenario tests (InfusionScenarios.ws): service factory, test items,
/** 	test craftsmen, opening the real service menu, cleanup.
/***********************************************************************/

// Service with a fresh config, debug bypass on (no craftsman needed unless
// one is passed to Preview/Execute).
function InfusionGetService() : W3InfusionService
{
	var svc : W3InfusionService;
	svc = new W3InfusionService in theGame;
	svc.config = new W3InfusionConfig in theGame;
	svc.debugBypassCraftsman = true;
	return svc;
}

// Spawns a quiet (no popup) item and tags it as a test item.
// boostLevels > 0 adds that many fixed step abilities (deterministic level
// advantage). sword3=false spawns 'Novigraadan sword 1', true spawns
// 'Novigraadan sword 3'. armor=true spawns armor pieces instead
// ('Light armor 01' as target / 'Light armor 06' as sacrifice).
function InfusionSpawnTestItem( out id : SItemUniqueId, sword3 : bool, boostLevels : int, optional armor : bool ) : bool
{
	var inv : CInventoryComponent;
	var ids : array<SItemUniqueId>;
	var i : int;
	var itemName : name;

	inv = thePlayer.inv;
	if ( armor )
	{
		if ( sword3 )
		{
			itemName = 'Light armor 06';   // sacrifice: higher-tier piece
		}
		else
		{
			itemName = 'Light armor 01';   // target
		}
	}
	else if ( sword3 )
	{
		itemName = 'Novigraadan sword 3';
	}
	else
	{
		itemName = 'Novigraadan sword 1';
	}

	ids = inv.AddAnItem( itemName, 1, true, true );

	if ( ids.Size() == 0 )
	{
		return false;
	}

	id = ids[0];
	inv.AddItemTag( id, 'InfusionTestItem' );

	// Level boost: swords use the steel step ability; armor uses the armor
	// step ability (one per level, verified autogen values).
	for ( i = 0; i < boostLevels; i += 1 )
	{
		if ( armor )
		{
			inv.AddItemCraftedAbility( id, 'autogen_fixed_armor_armor', true );
		}
		else
		{
			inv.AddItemCraftedAbility( id, 'autogen_fixed_steel_dmg', true );
		}
	}
	return true;
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

// Read-only: reports the type/tier data of every craftsman NPC within 40m.
function InfusionCraftsmanReport()
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

// Price experiment (spec §6.3): does the craftsman's region or shop change
// prices? The fee is anchored to the player-side market value
// (GetItemPriceModified on the player's inventory). For the equipped steel
// sword and chest armor this logs that anchor next to what the nearest
// craftsman would charge for a fresh copy of the same item (copies are added
// to both inventories, priced and removed again), vanilla's script-side shop
// modifier (GetMerchantPriceModifier) and the craftsman's repair price per
// durability point. Run it at craftsmen in different regions and compare.
function InfusionPriceProbe()
{
	var entities : array<CGameplayEntity>;
	var npc, nearest : CNewNPC;
	var dist, bestDist : float;
	var i : int;

	FindGameplayEntitiesInSphere( entities, thePlayer.GetWorldPosition(), 40, 30, '', FLAG_OnlyAliveActors );
	bestDist = 1000000.0f;
	for ( i = 0; i < entities.Size(); i += 1 )
	{
		if ( !entities[i].GetComponentByClassName( 'W3CraftsmanComponent' ) )
		{
			continue;
		}
		npc = (CNewNPC)entities[i];
		dist = VecDistance( npc.GetWorldPosition(), thePlayer.GetWorldPosition() );
		if ( npc && dist < bestDist )
		{
			nearest = npc;
			bestDist = dist;
		}
	}
	if ( !nearest )
	{
		theGame.GetGuiManager().ShowNotification( "price probe: no craftsman within 40 m" );
		return;
	}

	LogChannel( 'Infusion', "price probe at " + nearest.GetDisplayName() + " (zone " + (int)theGame.GetCurrentZone() + ")" );
	InfusionPriceProbeSlot( nearest, EES_SteelSword );
	InfusionPriceProbeSlot( nearest, EES_Armor );
	theGame.GetGuiManager().ShowNotification( "price probe written to the log (" + nearest.GetDisplayName() + ")" );
}

// Same probe for regional craftsmen without travelling: spawns the real
// community templates (Velen, Novigrad, Skellige; their merchant data -
// funds, store, area tag - comes with the template) and probes each. The
// zone factor still follows where the player stands. The spawned NPCs
// stay for 2 minutes; if a fresh one wasn't ready ("could not add
// copies"), run the command again - it re-probes the spawned ones.
function InfusionPriceProbeTemplates()
{
	var paths : array<string>;
	var existing : array<CEntity>;
	var ent : CEntity;
	var npc : CNewNPC;
	var i : int;

	theGame.GetEntitiesByTag( 'InfusionPriceProbe', existing );
	if ( existing.Size() == 0 )
	{
		paths.PushBack( "gameplay\community\shops_and_craftsmen
o_mans_landarons_keeparons_keep_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen
o_mans_land\mouth\mouth_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen
o_mans_land\snots\snots_blacksmith_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen
ovigradich_district
ovigrad_rich_district_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen
ovigrad\whitebridge\whitebridge_redanian_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen
ovigrad\market
ovigrad_market_smith_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen\skellige\kaer_trolde\kaer_trolde_castle_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen\skellige\larvik\larvik_armorer_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen\skellige\kaer_trolde\kaer_trolde_castle_blacksmith_01.w2ent" );
		paths.PushBack( "gameplay\community\shops_and_craftsmen\skellige\larvik\larvik_smith_01.w2ent" );
		for ( i = 0; i < paths.Size(); i += 1 )
		{
			ent = InfusionCreateTestCraftsman( paths[i], 120.0f );
			if ( ent )
			{
				ent.AddTag( 'InfusionPriceProbe' );
				existing.PushBack( ent );
			}
		}
	}

	LogChannel( 'Infusion', "price probe (templates): " + existing.Size() + " craftsmen, zone " + (int)theGame.GetCurrentZone() );
	for ( i = 0; i < existing.Size(); i += 1 )
	{
		npc = (CNewNPC)existing[i];
		if ( !npc )
		{
			continue;
		}
		LogChannel( 'Infusion', "price probe at " + npc.GetDisplayName() + " [" + npc.GetReadableName() + "]" );
		InfusionPriceProbeSlot( npc, EES_SteelSword );
		InfusionPriceProbeSlot( npc, EES_Armor );
	}
	theGame.GetGuiManager().ShowNotification( "price probe: " + existing.Size() + " template craftsmen probed (log)" );
}

function InfusionPriceProbeSlot( craftsman : CNewNPC, slot : EEquipmentSlots )
{
	var inv, shopInv : CInventoryComponent;
	var svc : W3InfusionService;
	var item : SItemUniqueId;
	var itemName : name;
	var playerCopies, shopCopies : array<SItemUniqueId>;
	var playerCopyPrice, shopCopyPrice : int;
	var repairPoint, repairTotal : int;
	var shopMod : float;
	var msg : string;

	inv = thePlayer.inv;
	shopInv = craftsman.GetInventory();
	svc = InfusionGetService();
	if ( !GetWitcherPlayer().GetItemEquippedOnSlot( slot, item ) || !inv.IsIdValid( item ) || !shopInv )
	{
		LogChannel( 'Infusion', "price probe: nothing equipped in slot " + (int)slot );
		return;
	}
	itemName = inv.GetItemName( item );

	msg = "price probe: " + itemName + " L" + svc.ComputeItemLevel( inv, item )
		+ " | fee anchor (player value) " + inv.GetItemPriceModified( item, false )
		+ " | base " + inv.GetItemPrice( item )
		+ " | player sells for " + inv.GetItemPriceModified( item, true );

	shopInv.GetItemPriceRepair( inv.GetItem( item ), repairPoint, repairTotal );
	msg += " | repair per point " + repairPoint + " (now " + repairTotal + ")";

	playerCopies = inv.AddAnItem( itemName, 1, true, true );
	shopCopies = shopInv.AddAnItem( itemName, 1, true, true );
	if ( playerCopies.Size() > 0 && shopCopies.Size() > 0 )
	{
		playerCopyPrice = inv.GetItemPriceModified( playerCopies[0], false );
		shopCopyPrice = shopInv.GetItemPriceModified( shopCopies[0], false );
		shopMod = shopInv.GetMerchantPriceModifier( craftsman, shopCopies[0] );
		msg += " | copy in player inv L" + svc.ComputeItemLevel( inv, playerCopies[0] ) + ": " + playerCopyPrice
			+ " | copy in shop inv L" + svc.ComputeItemLevel( shopInv, shopCopies[0] ) + ": " + shopCopyPrice
			+ " | shop modifier (script) " + shopMod;
	}
	else
	{
		msg += " | could not add copies";
	}
	if ( playerCopies.Size() > 0 )
	{
		inv.RemoveItem( playerCopies[0], 1 );
	}
	if ( shopCopies.Size() > 0 )
	{
		shopInv.RemoveItem( shopCopies[0], 1 );
	}
	LogChannel( 'Infusion', msg );
}

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

// Opens the blacksmith/armorer service menu anywhere in the world, exactly as
// the dialogue does: CommonMenu with the NPC as init data and BlacksmithMenu
// as the menu to open (it opens on the Repair tab; the Infusion tab is next
// to it). Reuses a spawned test craftsman of the requested kind, otherwise
// spawns one (despawns after 10 minutes or via infuseDespawnTestSmith).
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
	var initData : W3InventoryInitData;
	var merchant : W3MerchantNPC;

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

	// Same init data as the game's scenes (scene_functions.ws ShowCraftingPanel
	// / OpenInventoryForScene): W3InventoryInitData with the NPC and an
	// explicit default state. Passing the bare entity opened the menu without
	// a state (no Repair page, empty grid - verified in game 2026-10-17).
	initData = new W3InventoryInitData in theGame.GetGuiManager();
	initData.containerNPC = (CGameplayEntity)smith;
	initData.setDefaultState( 'Repair' );
	merchant = (W3MerchantNPC)smith;
	if ( merchant )
	{
		merchant.SetCraftingEnabled( true );
	}

	LogChannel( 'Infusion', "open service menu with " + path );
	theGame.GetGuiManager().SetLastOpenedCommonMenuName( 'None' );
	theGame.RequestMenuWithBackground( 'BlacksmithMenu', 'CommonMenu', initData );
}

// Spawns a valid infusion pair for UI tests: an ordinary target and a
// same-category sacrifice boosted by 10 levels (both tagged
// 'InfusionTestItem', removable with infuseCleanTestItems). Ordinary gear,
// so a journeyman of the matching specialization can infuse it.
function InfusionSpawnTestPair( armor : bool )
{
	var svc : W3InfusionService;
	var inv : CInventoryComponent;
	var tId, sId : SItemUniqueId;

	inv = thePlayer.inv;
	svc = InfusionGetService();

	if ( !InfusionSpawnTestItem( tId, false, 0, armor ) || !InfusionSpawnTestItem( sId, true, 10, armor ) )
	{
		theGame.GetGuiManager().ShowNotification( "TEST PAIR: spawn failed", 6.0 );
		return;
	}

	LogChannel( 'Infusion', "test pair: target " + inv.GetItemName( tId ) + " L" + svc.ComputeItemLevel( inv, tId )
		+ ", sacrifice " + inv.GetItemName( sId ) + " L" + svc.ComputeItemLevel( inv, sId ) );
	theGame.GetGuiManager().ShowNotification( "TEST PAIR: " + GetLocStringByKeyExt( inv.GetItemLocalizedNameByUniqueID( tId ) ) + " L" + svc.ComputeItemLevel( inv, tId )
		+ " + sacrifice L" + svc.ComputeItemLevel( inv, sId ), 8.0 );
	theSound.SoundEvent( "gui_crafting_craft_item" );
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

// Removes spawned test items. Two populations:
//  a) tagged 'InfusionTestItem' (spawned this session)
//  b) untagged 'Novigraadan sword 1/3' steel swords - test items from an
//     earlier session lose their tag (script-added tags are not saved)
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
