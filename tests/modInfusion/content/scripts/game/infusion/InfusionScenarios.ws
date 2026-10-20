/***********************************************************************/
/** 	Witcher Gear Infusion — scenario tests (DEV ONLY, never shipped)
/** 	One console command per scenario (infuseScenario(name)) and one for
/** 	all of them (infuseScenarioAll). Each scenario spawns its own items
/** 	(and craftsman where needed), runs the real service code (Preview /
/** 	Execute - the same calls the menu makes), checks the outcome itself
/** 	and puts the inventory back: spawned items removed, crowns and
/** 	materials restored to the exact amounts from before the scenario.
/**
/** 	Spec coverage: §3.2-3.4, §4.1-4.4, §5.4-5.5, §6.2, §8.2-8.3, §13,
/** 	§15.1-15.5. UI behavior stays manual (docs/UI.md).
/**
/** 	Item names and qualities verified against the REDkit item XML
/** 	(quality 5 = Witcher gear, 4 = relic); scenarios re-check the quality
/** 	at runtime and report SKIP if the game data differs.
/***********************************************************************/

enum EInfScnStatus
{
	ISS_Pass,
	ISS_Fail,
	ISS_Skip
}

// Setup of a successful-infusion scenario.
struct SInfScnSpec
{
	var targetName : name;
	var sacrificeName : name;
	var gap : int;              // sacrifice level = target level + gap
	var targetLevel : int;      // boost the target to at least this level first (0 = as spawned)
	var damageTarget : bool;    // halve the target's durability (restore check)
	var upgradeName : name;     // rune/glyph socketed into the target ('' = none)
	var enchantment : name;     // runeword/glyphword on the target ('' = none)
	var expectQuality : int;    // SKIP unless the target has this quality (0 = any)
}

// Target state before the infusion (identity checks, spec §4.1).
struct SInfScnItemState
{
	var itemName : name;
	var level : int;
	var stat : float;
	var enhancements : array<name>;
	var enchantment : name;
	var abilities : array<name>;
}

function InfusionScenarioNames( out names : array<name> )
{
	names.Clear();
	names.PushBack( 'steel_sword' );
	names.PushBack( 'silver_sword' );
	names.PushBack( 'armor' );
	names.PushBack( 'boots' );
	names.PushBack( 'witcher_sword_rune' );
	names.PushBack( 'witcher_armor_glyph' );
	names.PushBack( 'relic_runeword' );
	names.PushBack( 'ngplus_uncapped' );
	names.PushBack( 'salvage_off' );
	names.PushBack( 'fee_by_tier' );
	names.PushBack( 'master_relic_ok' );
	names.PushBack( 'reject_same' );
	names.PushBack( 'reject_lower' );
	names.PushBack( 'reject_equal' );
	names.PushBack( 'reject_category' );
	names.PushBack( 'reject_steel_silver' );
	names.PushBack( 'reject_quest' );
	names.PushBack( 'reject_crowns' );
	names.PushBack( 'reject_materials' );
	names.PushBack( 'reject_craftsman_type' );
	names.PushBack( 'reject_tier_witcher' );
	names.PushBack( 'reject_tier_relic' );
	names.PushBack( 'block_tier' );
	names.PushBack( 'block_no_higher' );
	names.PushBack( 'block_ok' );
	names.PushBack( 'block_excluded' );
	names.PushBack( 'materials_off' );
	names.PushBack( 'fee_formula' );
	names.PushBack( 'fee_by_gap' );
	names.PushBack( 'fee_config' );
	names.PushBack( 'fee_soft_cap' );
	names.PushBack( 'materials_by_tier' );
}

class W3InfusionScenarioRunner extends IScriptable
{
	public var svc : W3InfusionService;
	public var inv : CInventoryComponent;
	public var detail : string;
	public var lastPreview : SInfusionPreview;
	public var keepTarget : bool;            // persist scenario: target stays in the inventory
	public var lastTarget : SItemUniqueId;

	// The persist scenario's target; PersistCheck finds it by name + level.
	private const var PERSIST_ITEM : name;
	default PERSIST_ITEM = 'Novigraadan sword 1';

	// Crowns/materials before the scenario touched them (RestoreSnapshot).
	private var snapTaken : bool;
	private var snapMoney : int;
	private var snapNames : array<name>;
	private var snapQty : array<int>;

	public function Init()
	{
		inv = thePlayer.inv;
		svc = InfusionGetService();
	}

	// Runs one scenario and always cleans up afterwards.
	public function Run( scenario : name ) : EInfScnStatus
	{
		var status : EInfScnStatus;

		detail = "";
		snapTaken = false;
		status = Dispatch( scenario );
		RestoreSnapshot();
		RemoveScenarioItems();
		return status;
	}

	private function Dispatch( scenario : name ) : EInfScnStatus
	{
		var spec : SInfScnSpec;

		switch ( scenario )
		{
			// ---- successful infusions (spec §4.4 matrix, §3.4, §13.4 parts) ----
			case 'steel_sword':
				spec.targetName = 'Novigraadan sword 1';
				spec.sacrificeName = 'Novigraadan sword 3';
				spec.gap = 10;
				spec.damageTarget = true;
				return RunInfusion( spec, NULL );
			case 'silver_sword':
				spec.targetName = 'Dwarven silver sword 2';
				spec.sacrificeName = 'Elven silver sword 2';
				spec.gap = 10;
				spec.damageTarget = true;
				return RunInfusion( spec, NULL );
			case 'armor':
				spec.targetName = 'Light armor 01';
				spec.sacrificeName = 'Light armor 06';
				spec.gap = 10;
				spec.damageTarget = true;
				return RunInfusion( spec, NULL );
			case 'boots':
				spec.targetName = 'Boots 01';
				spec.sacrificeName = 'Boots 03';
				spec.gap = 10;
				spec.damageTarget = true;
				return RunInfusion( spec, NULL );
			case 'witcher_sword_rune':
				spec.targetName = 'Bear School steel sword 1';
				spec.sacrificeName = 'Novigraadan sword 3';
				spec.gap = 5;
				spec.upgradeName = 'Rune stribog lesser';
				spec.expectQuality = 5;
				return RunInfusion( spec, NULL );
			case 'witcher_armor_glyph':
				spec.targetName = 'Bear Armor 1';
				spec.sacrificeName = 'Light armor 06';
				spec.gap = 5;
				spec.upgradeName = 'Glyph aard lesser';
				spec.expectQuality = 5;
				return RunInfusion( spec, NULL );
			case 'relic_runeword':
				spec.targetName = 'Abarad';
				spec.sacrificeName = 'Novigraadan sword 3';
				spec.gap = 5;
				spec.enchantment = 'Runeword 1';
				spec.expectQuality = 4;
				return RunInfusion( spec, NULL );
			case 'ngplus_uncapped':
				return ScenarioNgPlus();
			case 'salvage_off':
				return ScenarioSalvageOff();
			case 'fee_by_tier':
				return ScenarioFeeByTier();
			case 'master_relic_ok':
				return ScenarioMasterRelic();
			case 'persist':
				return ScenarioPersist();

			// ---- rejections: nothing may change (spec §15.2) ----
			case 'reject_same':
				return ScenarioRejectSame();
			case 'reject_lower':
				return ScenarioRejectLevel( false );
			case 'reject_equal':
				return ScenarioRejectLevel( true );
			case 'reject_category':
				return ScenarioRejectPair( 'Light armor 01', 'Novigraadan sword 3', IFE_CategoryMismatch );
			case 'reject_steel_silver':
				return ScenarioRejectPair( 'Novigraadan sword 1', 'Elven silver sword 2', IFE_CategoryMismatch );
			case 'reject_quest':
				return ScenarioRejectQuest();
			case 'reject_crowns':
				return ScenarioRejectCrowns();
			case 'reject_materials':
				return ScenarioRejectMaterials();
			case 'reject_craftsman_type':
				return ScenarioRejectCraftsman( 'Novigraadan sword 1', 'Novigraadan sword 3', true, IFE_WrongCraftsmanType, 0 );
			case 'reject_tier_witcher':
				return ScenarioRejectCraftsman( 'Bear Armor 1', 'Light armor 06', true, IFE_CraftsmanLevelTooLow, 5 );
			case 'reject_tier_relic':
				return ScenarioRejectCraftsman( 'Abarad', 'Novigraadan sword 3', false, IFE_CraftsmanLevelTooLow, 4 );

			// ---- block reasons for the grid (spec §9.3) ----
			case 'block_tier':
				return ScenarioBlockTier();
			case 'block_no_higher':
				return ScenarioBlockNoHigher();
			case 'block_ok':
				return ScenarioBlockOk();
			case 'block_excluded':
				return ScenarioBlockExcluded();

			// ---- configuration and pricing (spec §10, §15.4) ----
			case 'materials_off':
				return ScenarioMaterialsOff();
			case 'fee_formula':
				return ScenarioFeeFormula();
			case 'fee_by_gap':
				return ScenarioFeeByGap();
			case 'fee_config':
				return ScenarioFeeConfig();
			case 'fee_soft_cap':
				return ScenarioFeeSoftCap();
			case 'materials_by_tier':
				return ScenarioMaterialsByTier();
		}
		detail = "unknown scenario - run infuseScenarioList";
		return ISS_Skip;
	}

	// =====================================================================
	// Successful infusion: setup, execute, verify every post-condition
	// =====================================================================

	public function RunInfusion( spec : SInfScnSpec, craftsman : CGameplayEntity ) : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var before : SInfScnItemState;
		var p : SInfusionPreview;
		var err : EInfusionError;
		var moneyBefore : int;
		var matBefore : array<int>;
		var i : int;

		if ( !Spawn( spec.targetName, t ) || !Spawn( spec.sacrificeName, s ) )
		{
			return ISS_Fail;
		}
		lastTarget = t;

		if ( spec.expectQuality > 0 && inv.GetItemQuality( t ) != spec.expectQuality )
		{
			detail = "" + spec.targetName + " has quality " + inv.GetItemQuality( t ) + ", expected " + spec.expectQuality;
			return ISS_Skip;
		}
		if ( spec.targetLevel > 0 && !BoostTo( t, spec.targetLevel ) )
		{
			return ISS_Fail;
		}
		if ( spec.upgradeName != '' && !SocketUpgrade( t, spec.upgradeName ) )
		{
			return ISS_Skip;
		}
		if ( spec.enchantment != '' && !Enchant( t, spec.enchantment ) )
		{
			return ISS_Skip;
		}
		if ( !BoostTo( s, Level( t ) + spec.gap ) )
		{
			return ISS_Fail;
		}
		if ( spec.damageTarget && inv.HasItemDurability( t ) )
		{
			inv.SetItemDurabilityScript( t, inv.GetItemMaxDurability( t ) * 0.5f );
		}

		before = Capture( t );

		err = svc.Preview( t, s, p, craftsman );
		if ( err != IFE_Ok )
		{
			detail = "preview refused: " + InfusionErrorToString( err );
			return ISS_Fail;
		}

		// Give the player exactly what is missing (restored afterwards).
		TakeSnapshot( p );
		Fund( p );
		moneyBefore = inv.GetMoney();
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			matBefore.PushBack( inv.GetItemQuantityByName( p.materials[i].itemName ) );
		}

		err = svc.Execute( t, s, p, craftsman );
		lastPreview = p;
		if ( err != IFE_Ok )
		{
			detail = "execute refused: " + InfusionErrorToString( err );
			return ISS_Fail;
		}

		if ( !VerifyInfusion( t, s, before, p, moneyBefore, matBefore ) )
		{
			return ISS_Fail;
		}
		detail = "" + spec.targetName + " L" + before.level + " -> L" + p.newLevel + ", " + p.statAttribute + " "
			+ RoundMath( p.statBefore ) + " -> " + RoundMath( p.statAfter ) + ", fee " + p.laborFee + DescribeKept( before );
		return ISS_Pass;
	}

	private function VerifyInfusion( t, s : SItemUniqueId, before : SInfScnItemState, p : SInfusionPreview, moneyBefore : int, matBefore : array<int> ) : bool
	{
		var after : SInfScnItemState;
		var i : int;
		var used : int;
		var statValue : SAbilityAttributeValue;
		var actualStat : float;

		if ( !inv.IsIdValid( t ) )
		{
			detail = "target vanished";
			return false;
		}
		if ( inv.IsIdValid( s ) )
		{
			detail = "sacrifice was not consumed";
			return false;
		}
		after = Capture( t );
		if ( after.itemName != before.itemName )
		{
			detail = "identity changed: " + before.itemName + " -> " + after.itemName;
			return false;
		}
		if ( after.level != p.newLevel || after.level != p.sacrificeLevel )
		{
			detail = "level " + after.level + ", expected " + p.sacrificeLevel;
			return false;
		}
		if ( after.stat <= before.stat )
		{
			detail = "primary stat did not rise (" + FloatToString( before.stat ) + " -> " + FloatToString( after.stat ) + ")";
			return false;
		}
		// The popup's projected stat (spec §9.2) must match the result.
		if ( p.statAttribute == '' )
		{
			detail = "no stat projection";
			return false;
		}
		statValue = inv.GetItemAttributeValue( t, p.statAttribute );
		actualStat = statValue.valueBase;
		if ( AbsF( actualStat - p.statAfter ) > 0.5f )
		{
			detail = "projected " + p.statAttribute + " " + FloatToString( p.statAfter ) + ", got " + FloatToString( actualStat );
			return false;
		}
		if ( inv.HasItemDurability( t ) && inv.GetItemDurability( t ) < inv.GetItemMaxDurability( t ) - 0.5f )
		{
			detail = "durability not restored (" + FloatToString( inv.GetItemDurability( t ) ) + " of " + FloatToString( inv.GetItemMaxDurability( t ) ) + ")";
			return false;
		}
		if ( after.enhancements.Size() != before.enhancements.Size() )
		{
			detail = "socketed upgrades changed (" + before.enhancements.Size() + " -> " + after.enhancements.Size() + ")";
			return false;
		}
		for ( i = 0; i < before.enhancements.Size(); i += 1 )
		{
			if ( !after.enhancements.Contains( before.enhancements[i] ) )
			{
				detail = "upgrade lost: " + before.enhancements[i];
				return false;
			}
		}
		if ( after.enchantment != before.enchantment )
		{
			detail = "enchantment changed: '" + before.enchantment + "' -> '" + after.enchantment + "'";
			return false;
		}
		for ( i = 0; i < before.abilities.Size(); i += 1 )
		{
			if ( !after.abilities.Contains( before.abilities[i] ) )
			{
				detail = "ability lost: " + before.abilities[i];
				return false;
			}
		}
		if ( moneyBefore - inv.GetMoney() != p.laborFee )
		{
			detail = "charged " + ( moneyBefore - inv.GetMoney() ) + " crowns, fee was " + p.laborFee;
			return false;
		}
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			used = matBefore[i] - inv.GetItemQuantityByName( p.materials[i].itemName );
			if ( used != p.materials[i].quantity )
			{
				detail = "used " + used + " x " + p.materials[i].itemName + ", expected " + p.materials[i].quantity;
				return false;
			}
		}
		return true;
	}

	private function DescribeKept( before : SInfScnItemState ) : string
	{
		var text : string;

		text = "";
		if ( before.enhancements.Size() > 0 )
		{
			text += ", " + before.enhancements.Size() + " upgrade(s) kept";
		}
		if ( before.enchantment != '' )
		{
			text += ", " + before.enchantment + " kept";
		}
		return text;
	}

	// =====================================================================
	// Special scenarios
	// =====================================================================

	// Spec §8.3: no level cap - target and sacrifice above the player's max level.
	private function ScenarioNgPlus() : EInfScnStatus
	{
		var spec : SInfScnSpec;
		var status : EInfScnStatus;
		var maxLevel : int;

		maxLevel = GetWitcherPlayer().GetMaxLevel();
		spec.targetName = 'Light armor 01';
		spec.sacrificeName = 'Light armor 06';
		spec.gap = 10;
		spec.targetLevel = maxLevel + 3;
		status = RunInfusion( spec, NULL );
		if ( status == ISS_Pass && lastPreview.newLevel <= maxLevel )
		{
			detail = "new level " + lastPreview.newLevel + " is not above the cap " + maxLevel;
			return ISS_Fail;
		}
		if ( status == ISS_Pass )
		{
			detail += " (player cap " + maxLevel + ")";
		}
		return status;
	}

	// Spec §10/§15.3: salvage disabled -> no discount, full recipe charged.
	private function ScenarioSalvageOff() : EInfScnStatus
	{
		var spec : SInfScnSpec;
		var status : EInfScnStatus;
		var prevFact : int;

		prevFact = FactsQuerySum( "InfCfg_Salvage" );
		FactsSet( "InfCfg_Salvage", 1 );

		spec.targetName = 'Light armor 01';
		spec.sacrificeName = 'Light armor 06';
		spec.gap = 10;
		status = RunInfusion( spec, NULL );
		if ( status == ISS_Pass && ( lastPreview.salvaged.Size() > 0 || lastPreview.covered.Size() > 0 ) )
		{
			detail = "salvage still applied (" + lastPreview.covered.Size() + " covered materials)";
			status = ISS_Fail;
		}
		else if ( status == ISS_Pass && lastPreview.materials.Size() == 0 )
		{
			detail = "no materials charged with salvage off";
			status = ISS_Fail;
		}

		if ( prevFact > 0 )
		{
			FactsSet( "InfCfg_Salvage", prevFact );
		}
		else
		{
			FactsRemove( "InfCfg_Salvage" );
		}
		return status;
	}

	// Spec §6.2/§15.4: a master charges more labor than a journeyman.
	private function ScenarioFeeByTier() : EInfScnStatus
	{
		var journeyman, master : CGameplayEntity;
		var t, s : SItemUniqueId;
		var pj, pm : SInfusionPreview;
		var errJ, errM : EInfusionError;

		journeyman = GetCraftsman( true, false );
		master = GetCraftsman( true, true );
		if ( !journeyman || !master )
		{
			return ISS_Skip;
		}
		if ( !Spawn( 'Light armor 01', t ) || !Spawn( 'Light armor 06', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		errJ = svc.Preview( t, s, pj, journeyman );
		errM = svc.Preview( t, s, pm, master );
		if ( errJ != IFE_Ok || errM != IFE_Ok )
		{
			detail = "preview refused: journeyman " + InfusionErrorToString( errJ ) + ", master " + InfusionErrorToString( errM );
			return ISS_Fail;
		}
		detail = "journeyman " + pj.laborFee + ", master " + pm.laborFee + " crowns";
		if ( pm.laborFee <= pj.laborFee )
		{
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// Spec §8.2: a master smith may infuse a relic (preview only).
	private function ScenarioMasterRelic() : EInfScnStatus
	{
		var master : CGameplayEntity;
		var t, s : SItemUniqueId;
		var p : SInfusionPreview;
		var err : EInfusionError;

		master = GetCraftsman( false, true );
		if ( !master )
		{
			return ISS_Skip;
		}
		if ( !Spawn( 'Abarad', t ) || !Spawn( 'Novigraadan sword 3', s ) )
		{
			return ISS_Fail;
		}
		if ( inv.GetItemQuality( t ) != 4 )
		{
			detail = "Abarad has quality " + inv.GetItemQuality( t ) + ", expected 4";
			return ISS_Skip;
		}
		if ( !BoostTo( s, Level( t ) + 5 ) )
		{
			return ISS_Fail;
		}
		err = svc.Preview( t, s, p, master );
		if ( err != IFE_Ok )
		{
			detail = "master smith refused: " + InfusionErrorToString( err );
			return ISS_Fail;
		}
		detail = "accepted, fee " + p.laborFee;
		return ISS_Pass;
	}

	// Spec §13.4: infuse and keep the target; infuseScenarioPersistCheck
	// verifies it after a save/reload.
	private function ScenarioPersist() : EInfScnStatus
	{
		var spec : SInfScnSpec;
		var status : EInfScnStatus;

		spec.targetName = PERSIST_ITEM;
		spec.sacrificeName = 'Novigraadan sword 3';
		spec.gap = 10;
		spec.damageTarget = true;
		status = RunInfusion( spec, NULL );
		if ( status == ISS_Pass )
		{
			// Keep the sword (cleanup removes tagged items only).
			inv.RemoveItemTag( lastTarget, 'InfusionScenarioItem' );
			FactsSet( "InfScn_PersistLevel", Level( lastTarget ) );
			FactsSet( "InfScn_PersistStat", RoundMath( PrimaryStat( lastTarget ) ) );
			detail += " - now save, reload and run infuseScenarioPersistCheck";
		}
		return status;
	}

	public function PersistCheck() : EInfScnStatus
	{
		var all : array<SItemUniqueId>;
		var t : SItemUniqueId;
		var found : bool;
		var i : int;
		var expectedLevel, expectedStat : int;
		var status : EInfScnStatus;
		var levelsSeen : string;

		expectedLevel = FactsQuerySum( "InfScn_PersistLevel" );
		expectedStat = FactsQuerySum( "InfScn_PersistStat" );
		if ( expectedLevel <= 0 )
		{
			detail = "no persist scenario recorded - run infuseScenario(persist) first";
			return ISS_Skip;
		}

		// Script-added item tags are not saved (verified 2026-10-19: the
		// 'InfusionPersistItem' tag was gone after reload), so the sword is
		// found by its name and the recorded level and stat.
		inv.GetAllItems( all );
		levelsSeen = "";
		for ( i = 0; i < all.Size(); i += 1 )
		{
			if ( inv.GetItemName( all[i] ) != PERSIST_ITEM )
			{
				continue;
			}
			if ( !found && Level( all[i] ) == expectedLevel && AbsF( PrimaryStat( all[i] ) - expectedStat ) <= 1.0f )
			{
				t = all[i];
				found = true;
			}
			levelsSeen += " L" + Level( all[i] );
		}
		if ( !found )
		{
			if ( levelsSeen == "" )
			{
				detail = "no " + PERSIST_ITEM + " in the inventory after reload";
			}
			else
			{
				detail = "no " + PERSIST_ITEM + " at L" + expectedLevel + " / stat " + expectedStat + " after reload (found:" + levelsSeen + ")";
			}
			return ISS_Fail;
		}

		status = ISS_Pass;
		detail = "L" + Level( t ) + ", stat " + RoundMath( PrimaryStat( t ) );
		if ( Level( t ) != expectedLevel || AbsF( PrimaryStat( t ) - expectedStat ) > 1.0f )
		{
			detail += ", expected L" + expectedLevel + ", stat " + expectedStat;
			status = ISS_Fail;
		}
		else if ( inv.HasItemDurability( t ) && inv.GetItemDurability( t ) < inv.GetItemMaxDurability( t ) - 0.5f )
		{
			detail += ", durability not full";
			status = ISS_Fail;
		}

		inv.RemoveItem( t );
		FactsRemove( "InfScn_PersistLevel" );
		FactsRemove( "InfScn_PersistStat" );
		return status;
	}

	// =====================================================================
	// Rejections
	// =====================================================================

	// Executes the pair and expects exactly this rejection with nothing
	// changed (spec §13.3: no item, crown or material consumed).
	private function ExpectRejection( t, s : SItemUniqueId, expected : EInfusionError, craftsman : CGameplayEntity ) : EInfScnStatus
	{
		var p : SInfusionPreview;
		var err : EInfusionError;
		var levelBefore, moneyBefore, totalBefore : int;

		levelBefore = Level( t );
		moneyBefore = inv.GetMoney();
		totalBefore = TotalQuantity();

		err = svc.Execute( t, s, p, craftsman );
		if ( err != expected )
		{
			detail = "expected '" + InfusionErrorToString( expected ) + "', got '" + InfusionErrorToString( err ) + "'";
			return ISS_Fail;
		}
		if ( !inv.IsIdValid( t ) || !inv.IsIdValid( s ) || Level( t ) != levelBefore
			|| inv.GetMoney() != moneyBefore || TotalQuantity() != totalBefore )
		{
			detail = "rejected correctly, but the inventory changed";
			return ISS_Fail;
		}
		detail = InfusionErrorToString( err ) + "; nothing consumed";
		return ISS_Pass;
	}

	private function ScenarioRejectSame() : EInfScnStatus
	{
		var t : SItemUniqueId;

		if ( !Spawn( 'Novigraadan sword 1', t ) )
		{
			return ISS_Fail;
		}
		return ExpectRejection( t, t, IFE_SameItemInstance, NULL );
	}

	// equal = true: same level; false: sacrifice below the target.
	private function ScenarioRejectLevel( equal : bool ) : EInfScnStatus
	{
		var t, s : SItemUniqueId;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', s ) )
		{
			return ISS_Fail;
		}
		if ( equal )
		{
			// Spawn rolls differ by a level or two: raise the lower one.
			if ( Level( t ) < Level( s ) )
			{
				BoostTo( t, Level( s ) );
			}
			else if ( Level( s ) < Level( t ) )
			{
				BoostTo( s, Level( t ) );
			}
			if ( Level( t ) != Level( s ) )
			{
				detail = "could not equalize levels (" + Level( t ) + " vs " + Level( s ) + ")";
				return ISS_Skip;
			}
		}
		else if ( !BoostTo( t, Level( s ) + 5 ) )
		{
			return ISS_Fail;
		}
		return ExpectRejection( t, s, IFE_SacrificeNotHigher, NULL );
	}

	private function ScenarioRejectPair( targetName : name, sacrificeName : name, expected : EInfusionError ) : EInfScnStatus
	{
		var t, s : SItemUniqueId;

		if ( !Spawn( targetName, t ) || !Spawn( sacrificeName, s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		return ExpectRejection( t, s, expected, NULL );
	}

	private function ScenarioRejectQuest() : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var status : EInfScnStatus;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		inv.AddItemTag( s, 'Quest' );
		status = ExpectRejection( t, s, IFE_QuestItem, NULL );
		inv.RemoveItemTag( s, 'Quest' );
		return status;
	}

	private function ScenarioRejectCrowns() : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var p : SInfusionPreview;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		if ( svc.Preview( t, s, p ) != IFE_Ok )
		{
			detail = "setup pair invalid";
			return ISS_Fail;
		}
		TakeSnapshot( p );
		inv.RemoveMoney( inv.GetMoney() );
		return ExpectRejection( t, s, IFE_NotEnoughCrowns, NULL );
	}

	private function ScenarioRejectMaterials() : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var p : SInfusionPreview;
		var i, have : int;

		if ( !Spawn( 'Light armor 01', t ) || !Spawn( 'Light armor 06', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		if ( svc.Preview( t, s, p ) != IFE_Ok )
		{
			detail = "setup pair invalid";
			return ISS_Fail;
		}
		if ( p.materials.Size() == 0 )
		{
			detail = "salvage covers the whole recipe - nothing to withhold";
			return ISS_Skip;
		}
		TakeSnapshot( p );
		if ( inv.GetMoney() < p.laborFee )
		{
			inv.AddMoney( p.laborFee - inv.GetMoney() );
		}
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			have = inv.GetItemQuantityByName( p.materials[i].itemName );
			if ( have > 0 )
			{
				inv.RemoveItemByName( p.materials[i].itemName, have );
			}
		}
		return ExpectRejection( t, s, IFE_NotEnoughMaterials, NULL );
	}

	// Real craftsman gate (spec §8.2): journeyman armorer or smith.
	private function ScenarioRejectCraftsman( targetName : name, sacrificeName : name, armorer : bool, expected : EInfusionError, expectQuality : int ) : EInfScnStatus
	{
		var craftsman : CGameplayEntity;
		var t, s : SItemUniqueId;

		craftsman = GetCraftsman( armorer, false );
		if ( !craftsman )
		{
			return ISS_Skip;
		}
		if ( !Spawn( targetName, t ) || !Spawn( sacrificeName, s ) )
		{
			return ISS_Fail;
		}
		if ( expectQuality > 0 && inv.GetItemQuality( t ) != expectQuality )
		{
			detail = "" + targetName + " has quality " + inv.GetItemQuality( t ) + ", expected " + expectQuality;
			return ISS_Skip;
		}
		if ( !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		return ExpectRejection( t, s, expected, craftsman );
	}

	// =====================================================================
	// Block reasons (what the Infusion tab's tooltip shows, spec §9.3)
	// =====================================================================

	private function ExpectBlockReason( t : SItemUniqueId, expected : EInfusionError, craftsman : CGameplayEntity ) : EInfScnStatus
	{
		var reason : EInfusionError;

		reason = svc.GetBlockReason( inv, t, craftsman );
		detail = "reason '" + InfusionErrorToString( reason ) + "'";
		if ( reason != expected )
		{
			detail += ", expected '" + InfusionErrorToString( expected ) + "'";
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// Witcher gear at a journeyman armorer: the tier is the reason.
	private function ScenarioBlockTier() : EInfScnStatus
	{
		var craftsman : CGameplayEntity;
		var t, s : SItemUniqueId;

		craftsman = GetCraftsman( true, false );
		if ( !craftsman )
		{
			return ISS_Skip;
		}
		if ( !Spawn( 'Bear Armor 1', t ) || !Spawn( 'Light armor 06', s ) )
		{
			return ISS_Fail;
		}
		if ( inv.GetItemQuality( t ) != 5 )
		{
			detail = "Bear Armor 1 has quality " + inv.GetItemQuality( t ) + ", expected 5";
			return ISS_Skip;
		}
		if ( !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		return ExpectBlockReason( t, IFE_CraftsmanLevelTooLow, craftsman );
	}

	// A target far above every other chest armor: nothing higher to sacrifice.
	private function ScenarioBlockNoHigher() : EInfScnStatus
	{
		var t : SItemUniqueId;

		if ( !Spawn( 'Light armor 01', t ) || !BoostTo( t, GetWitcherPlayer().GetMaxLevel() + 40 ) )
		{
			return ISS_Fail;
		}
		return ExpectBlockReason( t, IFE_SacrificeNotHigher, NULL );
	}

	// A valid pair: no block reason (consistent with FindBestSacrifice).
	private function ScenarioBlockOk() : EInfScnStatus
	{
		var t, s : SItemUniqueId;

		if ( !Spawn( 'Light armor 01', t ) || !Spawn( 'Light armor 06', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		return ExpectBlockReason( t, IFE_Ok, NULL );
	}

	// Excluded gear is listed with an explanation (spec §14.2): a quest-tagged
	// sword counts as an explained exclusion, the same sword without the tag
	// does not.
	private function ScenarioBlockExcluded() : EInfScnStatus
	{
		var t : SItemUniqueId;
		var tagged, untagged : bool;

		if ( !Spawn( 'Novigraadan sword 1', t ) )
		{
			return ISS_Fail;
		}
		inv.AddItemTag( t, 'Quest' );
		tagged = svc.IsExplainedExclusion( t );
		inv.RemoveItemTag( t, 'Quest' );
		untagged = svc.IsExplainedExclusion( t );
		detail = "quest-tagged: " + tagged + ", untagged: " + untagged;
		if ( !tagged || untagged )
		{
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// =====================================================================
	// Configuration and pricing (spec §10, §15.4)
	// =====================================================================

	// RequireCraftingMaterials off: labor fee only, nothing else consumed
	// (RunInfusion checks that no material count changed).
	private function ScenarioMaterialsOff() : EInfScnStatus
	{
		var spec : SInfScnSpec;
		var status : EInfScnStatus;
		var prevFact : int;

		prevFact = SetFactTemp( "InfCfg_NoMaterials", 1 );
		spec.targetName = 'Light armor 01';
		spec.sacrificeName = 'Light armor 06';
		spec.gap = 10;
		status = RunInfusion( spec, NULL );
		if ( status == ISS_Pass && ( lastPreview.materials.Size() > 0 || lastPreview.salvaged.Size() > 0 || lastPreview.covered.Size() > 0 ) )
		{
			detail = "materials still required (" + lastPreview.materials.Size() + " remaining, " + lastPreview.covered.Size() + " covered)";
			status = ISS_Fail;
		}
		RestoreFact( "InfCfg_NoMaterials", prevFact );
		return status;
	}

	// The fee follows the configured formula: anchor x multiplier x
	// craftsman x target tier x gap, softened above the soft ceiling,
	// floored and capped (spec §6.3; the
	// target-tier multiplier is part of it). Without a craftsman the anchor
	// is the value fallback (ordinary and Witcher target); at a journeyman
	// armorer it is his full-repair price, read here independently from his
	// inventory (GetItemPriceRepair per point x max durability).
	private function ScenarioFeeFormula() : EInfScnStatus
	{
		var details : string;
		var armorer : CGameplayEntity;

		if ( !CheckFeeFormula( 'Light armor 01', 'Light armor 06', NULL ) )
		{
			return ISS_Fail;
		}
		details = detail;
		if ( !CheckFeeFormula( 'Bear Armor 1', 'Light armor 06', NULL ) )
		{
			return ISS_Fail;
		}
		details += "; " + detail;
		armorer = GetCraftsman( true, false );
		if ( !armorer )
		{
			detail = details + "; no journeyman armorer for the repair anchor";
			return ISS_Skip;
		}
		if ( !CheckFeeFormula( 'Light armor 01', 'Light armor 06', armorer ) )
		{
			return ISS_Fail;
		}
		detail = details + "; " + detail;
		return ISS_Pass;
	}

	private function CheckFeeFormula( targetName, sacrificeName : name, craftsman : CGameplayEntity ) : bool
	{
		var cfg : W3InfusionConfig;
		var t, s : SItemUniqueId;
		var p : SInfusionPreview;
		var err : EInfusionError;
		var quality, craftsmanLevel, perPoint, total, sacrificePerPoint, softCap : int;
		var anchor, expected : float;
		var comp : W3CraftsmanComponent;
		var label : string;

		if ( !Spawn( targetName, t ) || !Spawn( sacrificeName, s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return false;
		}
		err = svc.Preview( t, s, p, craftsman );
		if ( err != IFE_Ok )
		{
			detail = "preview refused " + targetName + ": " + InfusionErrorToString( err );
			return false;
		}
		cfg = svc.GetPublicConfig();
		quality = inv.GetItemQuality( t );
		craftsmanLevel = 0;   // no craftsman (test bypass): priced like a journeyman
		if ( craftsman )
		{
			// Fee base = the higher full-repair price of target and sacrifice.
			craftsman.GetInventory().GetItemPriceRepair( inv.GetItem( t ), perPoint, total );
			anchor = perPoint * inv.GetItemMaxDurability( t );
			craftsman.GetInventory().GetItemPriceRepair( inv.GetItem( s ), sacrificePerPoint, total );
			anchor = MaxF( anchor, sacrificePerPoint * inv.GetItemMaxDurability( s ) );
			comp = (W3CraftsmanComponent)craftsman.GetComponentByClassName( 'W3CraftsmanComponent' );
			craftsmanLevel = comp.GetCraftsmanLevel( ECT_Armorer );
			label = "repair " + perPoint + "/pt, sacrifice " + sacrificePerPoint + "/pt";
		}
		else
		{
			anchor = MaxF( cfg.GetTargetValue( inv, t ), cfg.GetTargetValue( inv, s ) ) * cfg.GetFallbackValueFraction();
			label = "value fallback";
		}
		expected = anchor * cfg.GetFeeMultiplier()
			* cfg.GetCraftsmanMultiplier( craftsmanLevel ) * cfg.GetTargetTierMultiplier( quality )
			* cfg.GetLevelGapMultiplier( p.levelGap );
		softCap = cfg.GetFeeSoftCap();
		if ( softCap > 0 && expected > softCap )
		{
			expected = SqrtF( expected * softCap );
			label += ", softened";
		}
		expected = ClampF( expected, cfg.GetMinLaborFee(), cfg.GetMaxLaborFee() );
		detail = targetName + " (" + label + ", quality " + quality + ", tier x" + cfg.GetTargetTierMultiplier( quality )
			+ "): fee " + p.laborFee + ", formula " + RoundMath( expected );
		return Abs( p.laborFee - RoundMath( expected ) ) <= 1;
	}

	// A larger level gap costs more labor (spec §7.1, §15.4). The fee floor
	// is lowered so both fees come from the formula.
	private function ScenarioFeeByGap() : EInfScnStatus
	{
		var t, small, large : SItemUniqueId;
		var ps, pl : SInfusionPreview;
		var errS, errL : EInfusionError;
		var prevFact : int;
		var status : EInfScnStatus;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', small ) || !Spawn( 'Novigraadan sword 3', large )
			|| !BoostTo( small, Level( t ) + 5 ) || !BoostTo( large, Level( t ) + 20 ) )
		{
			return ISS_Fail;
		}
		prevFact = SetFactTemp( "InfCfg_MinFee", 1 );
		errS = svc.Preview( t, small, ps, NULL );
		errL = svc.Preview( t, large, pl, NULL );
		RestoreFact( "InfCfg_MinFee", prevFact );
		if ( errS != IFE_Ok || errL != IFE_Ok )
		{
			detail = "preview refused: " + InfusionErrorToString( errS ) + " / " + InfusionErrorToString( errL );
			return ISS_Fail;
		}
		detail = "gap " + ps.levelGap + ": " + ps.laborFee + ", gap " + pl.levelGap + ": " + pl.laborFee + " crowns";
		status = ISS_Pass;
		if ( pl.laborFee <= ps.laborFee )
		{
			status = ISS_Fail;
		}
		return status;
	}

	// A config change changes the price (spec §15.4): doubling the fee
	// multiplier doubles the fee (within rounding). The soft ceiling is
	// lifted so the fee stays linear at any player level.
	private function ScenarioFeeConfig() : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var pa, pb : SInfusionPreview;
		var errA, errB : EInfusionError;
		var prevFee, prevMin, prevCap : int;
		var multiplier : float;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		prevMin = SetFactTemp( "InfCfg_MinFee", 1 );
		prevFee = SetFactTemp( "InfCfg_BaseFee", 0 );
		prevCap = SetFactTemp( "InfCfg_SoftCap", svc.GetPublicConfig().GetMaxLaborFee() );
		errA = svc.Preview( t, s, pa, NULL );
		multiplier = svc.GetPublicConfig().GetFeeMultiplier();
		FactsSet( "InfCfg_BaseFee", RoundMath( multiplier * 2000 ) );
		errB = svc.Preview( t, s, pb, NULL );
		RestoreFact( "InfCfg_SoftCap", prevCap );
		RestoreFact( "InfCfg_BaseFee", prevFee );
		RestoreFact( "InfCfg_MinFee", prevMin );
		if ( errA != IFE_Ok || errB != IFE_Ok )
		{
			detail = "preview refused: " + InfusionErrorToString( errA ) + " / " + InfusionErrorToString( errB );
			return ISS_Fail;
		}
		detail = "multiplier " + multiplier + ": " + pa.laborFee + ", multiplier " + ( multiplier * 2 ) + ": " + pb.laborFee + " crowns";
		if ( pa.laborFee <= 1 || Abs( pb.laborFee - 2 * pa.laborFee ) > 2 )
		{
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// The soft ceiling (spec §6.4): a fee below it is unchanged, a fee
	// above it becomes sqrt(fee x ceiling) - lower, but still more than
	// the ceiling. The ceiling is set relative to the unsoftened fee, so
	// the check works at any player level.
	private function ScenarioFeeSoftCap() : EInfScnStatus
	{
		var t, s : SItemUniqueId;
		var pRaw, pLow, pHigh : SInfusionPreview;
		var errRaw, errLow, errHigh : EInfusionError;
		var prevMin, prevCap, cap, expected : int;
		var rawFee : float;

		if ( !Spawn( 'Novigraadan sword 1', t ) || !Spawn( 'Novigraadan sword 3', s ) || !BoostTo( s, Level( t ) + 20 ) )
		{
			return ISS_Fail;
		}
		prevMin = SetFactTemp( "InfCfg_MinFee", 1 );
		prevCap = SetFactTemp( "InfCfg_SoftCap", svc.GetPublicConfig().GetMaxLaborFee() );
		errRaw = svc.Preview( t, s, pRaw, NULL );
		cap = Max( 1, pRaw.laborFee / 4 );
		FactsSet( "InfCfg_SoftCap", cap );
		errLow = svc.Preview( t, s, pLow, NULL );
		FactsSet( "InfCfg_SoftCap", pRaw.laborFee * 2 );
		errHigh = svc.Preview( t, s, pHigh, NULL );
		RestoreFact( "InfCfg_SoftCap", prevCap );
		RestoreFact( "InfCfg_MinFee", prevMin );
		if ( errRaw != IFE_Ok || errLow != IFE_Ok || errHigh != IFE_Ok )
		{
			detail = "preview refused: " + InfusionErrorToString( errRaw ) + " / " + InfusionErrorToString( errLow )
				+ " / " + InfusionErrorToString( errHigh );
			return ISS_Fail;
		}
		rawFee = pRaw.laborFee;
		expected = RoundMath( SqrtF( rawFee * cap ) );
		detail = "unsoftened " + pRaw.laborFee + "; ceiling " + cap + ": " + pLow.laborFee + " (expected " + expected
			+ "); ceiling " + ( pRaw.laborFee * 2 ) + ": " + pHigh.laborFee;
		if ( pRaw.laborFee < 8 )
		{
			detail += " - fee too small to soften";
			return ISS_Skip;
		}
		if ( Abs( pLow.laborFee - expected ) > 1 || pLow.laborFee <= cap || pLow.laborFee >= pRaw.laborFee
			|| pHigh.laborFee != pRaw.laborFee )
		{
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// Spec §7.2: a master armorer needs fewer materials than a journeyman for
	// the same pair - each recipe material is the journeyman's amount x the
	// master's efficiency, rounded to the nearest (half up), at least 1. A
	// 10-level gap is one set, so the journeyman's amounts are the unscaled
	// recipe.
	private function ScenarioMaterialsByTier() : EInfScnStatus
	{
		var journeyman, master : CGameplayEntity;
		var t, s : SItemUniqueId;
		var pj, pm : SInfusionPreview;
		var errJ, errM : EInfusionError;
		var cfg : W3InfusionConfig;
		var comp : W3CraftsmanComponent;
		var names : array<name>;
		var masterLevel, i, qJ, qM, expected, totalJ, totalM : int;
		var efficiency : float;

		journeyman = GetCraftsman( true, false );
		master = GetCraftsman( true, true );
		if ( !journeyman || !master )
		{
			return ISS_Skip;
		}
		cfg = svc.GetPublicConfig();
		if ( !cfg.RequireCraftingMaterials() || cfg.GetMaterialEfficiency( 1 ) != 1.0f || cfg.GetLevelGapMultiplier( 10 ) != 1.0f )
		{
			detail = "config differs from the defaults (materials, journeyman efficiency or levels per set)";
			return ISS_Skip;
		}
		if ( !Spawn( 'Light armor 01', t ) || !Spawn( 'Light armor 06', s ) || !BoostTo( s, Level( t ) + 10 ) )
		{
			return ISS_Fail;
		}
		errJ = svc.Preview( t, s, pj, journeyman );
		errM = svc.Preview( t, s, pm, master );
		if ( errJ != IFE_Ok || errM != IFE_Ok )
		{
			detail = "preview refused: journeyman " + InfusionErrorToString( errJ ) + ", master " + InfusionErrorToString( errM );
			return ISS_Fail;
		}
		comp = (W3CraftsmanComponent)master.GetComponentByClassName( 'W3CraftsmanComponent' );
		masterLevel = comp.GetCraftsmanLevel( ECT_Armorer );
		efficiency = cfg.GetMaterialEfficiency( masterLevel );

		for ( i = 0; i < pj.covered.Size(); i += 1 )
		{
			if ( !names.Contains( pj.covered[i].itemName ) )
			{
				names.PushBack( pj.covered[i].itemName );
			}
		}
		for ( i = 0; i < pj.materials.Size(); i += 1 )
		{
			if ( !names.Contains( pj.materials[i].itemName ) )
			{
				names.PushBack( pj.materials[i].itemName );
			}
		}
		totalJ = 0;
		totalM = 0;
		for ( i = 0; i < names.Size(); i += 1 )
		{
			qJ = RecipeQuantity( pj, names[i] );
			qM = RecipeQuantity( pm, names[i] );
			expected = Max( 1, FloorF( qJ * efficiency + 0.5001f ) );
			totalJ += qJ;
			totalM += qM;
			if ( qM != expected )
			{
				detail = names[i] + ": journeyman " + qJ + ", master " + qM + ", expected " + expected + " (x" + efficiency + ")";
				return ISS_Fail;
			}
		}
		detail = "journeyman " + totalJ + " materials, master (tier " + masterLevel + ", x" + efficiency + ") " + totalM;
		if ( totalJ == 0 || ( efficiency < 1.0f && totalM >= totalJ ) )
		{
			return ISS_Fail;
		}
		return ISS_Pass;
	}

	// Recipe amount of one material in a preview: covered by the sacrifice
	// plus still to pay.
	private function RecipeQuantity( p : SInfusionPreview, itemName : name ) : int
	{
		var i, total : int;

		total = 0;
		for ( i = 0; i < p.covered.Size(); i += 1 )
		{
			if ( p.covered[i].itemName == itemName )
			{
				total += p.covered[i].quantity;
			}
		}
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			if ( p.materials[i].itemName == itemName )
			{
				total += p.materials[i].quantity;
			}
		}
		return total;
	}

	// Sets a config fact for one scenario; returns the previous value.
	private function SetFactTemp( fact : string, value : int ) : int
	{
		var prev : int;

		prev = FactsQuerySum( fact );
		FactsRemove( fact );
		if ( value != 0 )
		{
			FactsSet( fact, value );
		}
		return prev;
	}

	private function RestoreFact( fact : string, prev : int ) : void
	{
		FactsRemove( fact );
		if ( prev != 0 )
		{
			FactsSet( fact, prev );
		}
	}

	// =====================================================================
	// Helpers
	// =====================================================================

	protected function Spawn( itemName : name, out id : SItemUniqueId ) : bool
	{
		var ids : array<SItemUniqueId>;

		ids = inv.AddAnItem( itemName, 1, true, true );
		if ( ids.Size() == 0 )
		{
			detail = "could not spawn " + itemName;
			return false;
		}
		id = ids[0];
		inv.AddItemTag( id, 'InfusionScenarioItem' );
		return true;
	}

	protected function Level( id : SItemUniqueId ) : int
	{
		return svc.ComputeItemLevel( inv, id );
	}

	// One step ability = one level of the item's own stats (same table as
	// W3InfusionService.GetCategoryData).
	private function StepAbility( id : SItemUniqueId ) : name
	{
		switch ( inv.GetItemCategory( id ) )
		{
			case 'steelsword':  return 'autogen_fixed_steel_dmg';
			case 'silversword': return 'autogen_fixed_silver_dmg';
			case 'armor':       return 'autogen_fixed_armor_armor';
			case 'pants':
			case 'boots':       return 'autogen_fixed_pants_armor';
			case 'gloves':      return 'autogen_fixed_gloves_armor';
		}
		return '';
	}

	protected function BoostTo( id : SItemUniqueId, wanted : int ) : bool
	{
		var ability : name;
		var guard : int;

		ability = StepAbility( id );
		if ( ability == '' )
		{
			detail = "no step ability for " + inv.GetItemName( id );
			return false;
		}
		guard = 0;
		while ( Level( id ) < wanted && guard < 400 )
		{
			inv.AddItemCraftedAbility( id, ability, true );
			guard += 1;
		}
		if ( Level( id ) < wanted )
		{
			detail = "could not raise " + inv.GetItemName( id ) + " to L" + wanted + " (L" + Level( id ) + ")";
			return false;
		}
		return true;
	}

	private function PrimaryStat( id : SItemUniqueId ) : float
	{
		var attr : name;
		var value : SAbilityAttributeValue;

		switch ( inv.GetItemCategory( id ) )
		{
			case 'steelsword':  attr = 'SlashingDamage'; break;
			case 'silversword': attr = 'SilverDamage'; break;
			default:            attr = 'armor'; break;
		}
		// Item stats live in valueBase (the field gameParams.GetItemLevel
		// reads); CalculateAttributeValue multiplies it by valueMultiplicative,
		// which is 0 for item stats - it returned 0 for every item.
		value = inv.GetItemAttributeValue( id, attr );
		return value.valueBase + value.valueAdditive;
	}

	private function Capture( id : SItemUniqueId ) : SInfScnItemState
	{
		var st : SInfScnItemState;
		var enhancements : array<name>;
		var abilities : array<name>;

		st.itemName = inv.GetItemName( id );
		st.level = Level( id );
		st.stat = PrimaryStat( id );
		inv.GetItemEnhancementItems( id, enhancements );
		st.enhancements = enhancements;
		st.enchantment = inv.GetEnchantment( id );
		inv.GetItemAbilities( id, abilities );
		st.abilities = abilities;
		return st;
	}

	// Sockets a rune/glyph (vanilla EnhanceItemScript, as the crafting
	// manager does it). False = SKIP: the game refused the upgrade.
	private function SocketUpgrade( t : SItemUniqueId, upgradeName : name ) : bool
	{
		var u : SItemUniqueId;

		if ( inv.GetItemEnhancementSlotsCount( t ) == 0 )
		{
			inv.AddSlot( t );
		}
		if ( !Spawn( upgradeName, u ) )
		{
			return false;
		}
		if ( !inv.EnhanceItemScript( t, u ) || inv.GetItemEnhancementCount( t ) == 0 )
		{
			detail = "could not socket " + upgradeName + " (" + inv.GetItemEnhancementSlotsCount( t ) + " slots)";
			return false;
		}
		return true;
	}

	// Applies a runeword/glyphword like the enchanter (enchantingMenu.ws).
	private function Enchant( t : SItemUniqueId, enchantment : name ) : bool
	{
		var guard : int;

		guard = 0;
		while ( inv.GetItemEnhancementSlotsCount( t ) < 3 && guard < 3 )
		{
			inv.AddSlot( t );
			guard += 1;
		}
		inv.EnchantItem( t, enchantment, getEnchamtmentStatName( enchantment ) );
		if ( !inv.IsItemEnchanted( t ) )
		{
			detail = "could not apply " + enchantment + " (" + inv.GetItemEnhancementSlotsCount( t ) + " slots)";
			return false;
		}
		return true;
	}

	// Sum of all stack quantities: any consumed item or material changes it.
	private function TotalQuantity() : int
	{
		var all : array<SItemUniqueId>;
		var i, total : int;

		inv.GetAllItems( all );
		total = 0;
		for ( i = 0; i < all.Size(); i += 1 )
		{
			total += inv.GetItemQuantity( all[i] );
		}
		return total;
	}

	// Records crowns and the preview's materials before the scenario
	// changes them; RestoreSnapshot puts back exactly these amounts.
	private function TakeSnapshot( p : SInfusionPreview )
	{
		var i : int;

		snapTaken = true;
		snapMoney = inv.GetMoney();
		snapNames.Clear();
		snapQty.Clear();
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			snapNames.PushBack( p.materials[i].itemName );
			snapQty.PushBack( inv.GetItemQuantityByName( p.materials[i].itemName ) );
		}
	}

	private function Fund( p : SInfusionPreview )
	{
		var i, have : int;

		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			have = inv.GetItemQuantityByName( p.materials[i].itemName );
			if ( have < p.materials[i].quantity )
			{
				inv.AddAnItem( p.materials[i].itemName, p.materials[i].quantity - have, true, true );
			}
		}
		if ( inv.GetMoney() < p.laborFee )
		{
			inv.AddMoney( p.laborFee - inv.GetMoney() );
		}
	}

	private function RestoreSnapshot()
	{
		var i, have : int;

		if ( !snapTaken )
		{
			return;
		}
		for ( i = 0; i < snapNames.Size(); i += 1 )
		{
			have = inv.GetItemQuantityByName( snapNames[i] );
			if ( have < snapQty[i] )
			{
				inv.AddAnItem( snapNames[i], snapQty[i] - have, true, true );
			}
			else if ( have > snapQty[i] )
			{
				inv.RemoveItemByName( snapNames[i], have - snapQty[i] );
			}
		}
		if ( inv.GetMoney() < snapMoney )
		{
			inv.AddMoney( snapMoney - inv.GetMoney() );
		}
		else if ( inv.GetMoney() > snapMoney )
		{
			inv.RemoveMoney( inv.GetMoney() - snapMoney );
		}
		snapTaken = false;
	}

	protected function RemoveScenarioItems()
	{
		var all : array<SItemUniqueId>;
		var i : int;

		inv.GetAllItems( all );
		for ( i = 0; i < all.Size(); i += 1 )
		{
			if ( inv.ItemHasTag( all[i], 'InfusionScenarioItem' ) )
			{
				inv.RemoveItemTag( all[i], 'Quest' );
				inv.RemoveItem( all[i], inv.GetItemQuantity( all[i] ) );
			}
		}
	}

	// A spawned test craftsman of this type and tier (reused when present).
	// NULL = SKIP: spawn failed or the entity has no craftsman component yet.
	private function GetCraftsman( armorer : bool, master : bool ) : CGameplayEntity
	{
		if ( master )
		{
			return GetCraftsmanAt( armorer, ECL_Master );
		}
		return GetCraftsmanAt( armorer, ECL_Journeyman );
	}

	// Same for any tier: journeyman (Velen), master (Novigrad), grandmaster
	// (Toussaint, Blood and Wine templates; tiers read from the templates'
	// W3CraftsmanComponent, docs/CRAFTSMAN_MAP.md).
	protected function GetCraftsmanAt( armorer : bool, requiredLevel : ECraftsmanLevel ) : CGameplayEntity
	{
		var existing : array<CEntity>;
		var comp : W3CraftsmanComponent;
		var requiredType : ECraftsmanType;
		var path : string;
		var smith : CEntity;
		var i : int;

		if ( armorer )
		{
			requiredType = ECT_Armorer;
			switch ( requiredLevel )
			{
				case ECL_Journeyman:
					path = "gameplay\community\shops_and_craftsmen\no_mans_land\barons_keep\barons_keep_armorer_01.w2ent";
					break;
				case ECL_Master:
					path = "gameplay\community\shops_and_craftsmen\novigrad\rich_district\novigrad_rich_district_armorer_01.w2ent";
					break;
				case ECL_Grand_Master:
					path = "dlc\bob\data\living_world\merchants\shop_38_city_west_armourer.w2ent";
					break;
			}
		}
		else
		{
			requiredType = ECT_Smith;
			switch ( requiredLevel )
			{
				case ECL_Journeyman:
					path = "gameplay\community\shops_and_craftsmen\no_mans_land\snots\snots_blacksmith_01.w2ent";
					break;
				case ECL_Master:
					path = "gameplay\community\shops_and_craftsmen\novigrad\market\novigrad_market_smith_01.w2ent";
					break;
				case ECL_Grand_Master:
					path = "dlc\bob\data\living_world\merchants\shop_39_city_west_blacksmith.w2ent";
					break;
			}
		}
		if ( path == "" )
		{
			detail = "no craftsman template for this tier";
			return NULL;
		}

		theGame.GetEntitiesByTag( 'InfusionTestSmith', existing );
		for ( i = 0; i < existing.Size(); i += 1 )
		{
			comp = (W3CraftsmanComponent)existing[i].GetComponentByClassName( 'W3CraftsmanComponent' );
			if ( comp && comp.IsCraftsmanType( requiredType ) && comp.GetCraftsmanLevel( requiredType ) == requiredLevel )
			{
				return (CGameplayEntity)existing[i];
			}
		}

		smith = InfusionCreateTestCraftsman( path, 300.f );
		if ( !smith )
		{
			detail = "craftsman spawn failed";
			return NULL;
		}
		comp = (W3CraftsmanComponent)smith.GetComponentByClassName( 'W3CraftsmanComponent' );
		if ( !comp || !comp.IsCraftsmanType( requiredType ) || comp.GetCraftsmanLevel( requiredType ) != requiredLevel )
		{
			detail = "craftsman spawned but not ready (or wrong tier) - run the scenario again";
			return NULL;
		}
		return (CGameplayEntity)smith;
	}
}

// ---------------------------------------------------------------------
// Entry points (called by the exec functions in InfusionDebug.ws)
// ---------------------------------------------------------------------

function InfusionScenarioStatusText( status : EInfScnStatus ) : string
{
	switch ( status )
	{
		case ISS_Pass: return "PASS";
		case ISS_Fail: return "FAIL";
	}
	return "SKIP";
}

function InfusionScenarioLine( scenario : name, status : EInfScnStatus, detail : string ) : string
{
	var line : string;

	line = "scenario " + scenario + ": " + InfusionScenarioStatusText( status );
	if ( detail != "" )
	{
		line += " (" + detail + ")";
	}
	return line;
}

function InfusionScenarioHud( msg : string )
{
	var hud : CR4ScriptedHud;

	hud = (CR4ScriptedHud)theGame.GetHud();
	if ( hud )
	{
		hud.HudConsoleMsg( msg );
	}
}

function InfusionRunScenario( scenario : name )
{
	var runner : W3InfusionScenarioRunner;
	var status : EInfScnStatus;
	var line : string;

	runner = new W3InfusionScenarioRunner in theGame;
	runner.Init();
	status = runner.Run( scenario );
	line = InfusionScenarioLine( scenario, status, runner.detail );

	LogChannel( 'Infusion', line );
	InfusionScenarioHud( line );
	theGame.GetGuiManager().ShowNotification( line, 10.0 );
	if ( status == ISS_Fail )
	{
		theSound.SoundEvent( "gui_global_denied" );
	}
	else
	{
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
}

// Index-based variant for consoles that won't take a bare name (1-based,
// order of infuseScenarioList).
function InfusionRunScenarioByIndex( index : int )
{
	var names : array<name>;

	InfusionScenarioNames( names );
	if ( index < 1 || index > names.Size() )
	{
		theGame.GetGuiManager().ShowNotification( "scenario index 1-" + names.Size() + " (see infuseScenarioList)", 8.0 );
		return;
	}
	InfusionRunScenario( names[index - 1] );
}

function InfusionRunAllScenarios()
{
	var runner : W3InfusionScenarioRunner;
	var names : array<name>;
	var status : EInfScnStatus;
	var passed, failed, skipped, i : int;
	var failedList, skippedList, line, summary : string;

	InfusionScenarioNames( names );
	runner = new W3InfusionScenarioRunner in theGame;
	runner.Init();

	LogChannel( 'Infusion', "scenarios: running " + names.Size() );
	for ( i = 0; i < names.Size(); i += 1 )
	{
		status = runner.Run( names[i] );
		line = InfusionScenarioLine( names[i], status, runner.detail );
		LogChannel( 'Infusion', line );
		InfusionScenarioHud( line );
		if ( status == ISS_Pass )
		{
			passed += 1;
		}
		else if ( status == ISS_Fail )
		{
			failed += 1;
			if ( failedList != "" )
			{
				failedList += ", ";
			}
			failedList += names[i];
		}
		else
		{
			skipped += 1;
			if ( skippedList != "" )
			{
				skippedList += ", ";
			}
			skippedList += names[i];
		}
	}

	summary = "SCENARIOS: " + passed + "/" + names.Size() + " PASS";
	if ( failed > 0 )
	{
		summary += " | FAIL: " + failedList;
	}
	if ( skipped > 0 )
	{
		summary += " | SKIP: " + skippedList;
	}
	LogChannel( 'Infusion', summary );
	InfusionScenarioHud( summary );
	theGame.GetGuiManager().ShowNotification( summary, 15.0 );
	if ( failed > 0 )
	{
		theSound.SoundEvent( "gui_global_denied" );
	}
	else
	{
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
}

function InfusionListScenarios()
{
	var names : array<name>;
	var i : int;
	var text : string;

	InfusionScenarioNames( names );
	text = "";
	for ( i = 0; i < names.Size(); i += 1 )
	{
		if ( text != "" )
		{
			text += ", ";
		}
		text += "" + ( i + 1 ) + " " + names[i];
	}
	LogChannel( 'Infusion', "scenarios: " + text + " (+ persist, manual)" );
	InfusionScenarioHud( "scenarios: " + text );
	theGame.GetGuiManager().ShowNotification( "scenarios: " + text, 20.0 );
}

function InfusionScenarioPersistCheck()
{
	var runner : W3InfusionScenarioRunner;
	var status : EInfScnStatus;
	var line : string;

	runner = new W3InfusionScenarioRunner in theGame;
	runner.Init();
	status = runner.PersistCheck();
	line = InfusionScenarioLine( 'persist_check', status, runner.detail );
	LogChannel( 'Infusion', line );
	InfusionScenarioHud( line );
	theGame.GetGuiManager().ShowNotification( line, 10.0 );
	if ( status == ISS_Fail )
	{
		theSound.SoundEvent( "gui_global_denied" );
	}
	else
	{
		theSound.SoundEvent( "gui_crafting_craft_item" );
	}
}
