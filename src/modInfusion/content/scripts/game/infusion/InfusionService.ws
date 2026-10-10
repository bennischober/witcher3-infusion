/***********************************************************************/
/** 	Witcher Gear Infusion — Milestone 2 prototype
/** 	Core infusion service: level computation, validation, transaction.
/**
/** 	Design constraints (docs/TECHNICAL_DISCOVERY.md):
/** 	  - No overrides of gameParams.ws / inventoryComponent.ws / playerWitcher.ws
/** 	    (script-merger conflict avoidance). New classes only.
/** 	  - Levels are DERIVED from stats; we replicate the derivation side-effect-free
/** 	    instead of calling inventoryComponent.GetItemLevel (which under the
/** 	    Leveling Gear mod auto-scales the item — an unacceptable side effect —
/** 	    and has an install-dependent signature).
/**
/** 	Spec: INFUSION_SPEC.md §3 (rules), §4 (identity), §5.5 (exploit guards),
/** 	      §6 (fees), §13 (transaction safety)
/***********************************************************************/

class W3InfusionService extends IScriptable
{
	// ----- configuration (M2: script constants; M3+: configuration service) -----

	// Labor fee in crowns for the M2 prototype. Milestone 5 replaces this
	// with the full formula (BaseFee x tier x tier-mult x level-gap mult).
	private const var DEBUG_LABOR_FEE : int;
	default DEBUG_LABOR_FEE = 50;

	// Upper bound for the step-ability loop in Execute(): expected steps
	// (level gap) plus a small correction budget for rounding/overhaul drift.
	private const var MAX_CORRECTION_STEPS : int;
	default MAX_CORRECTION_STEPS = 3;

	// ---------------------------------------------------------------------
	// Category support table
	// ---------------------------------------------------------------------

	private function GetCategoryData( category : name, out data : SInfusionCategoryData ) : bool
	{
		data.category = category;

		switch ( category )
		{
			case 'steelsword':
				data.stepAbility = 'autogen_fixed_steel_dmg';
				data.stepValue = 8;
				data.attributeName = 'SlashingDamage';
				return true;

			case 'silversword':
				data.stepAbility = 'autogen_fixed_silver_dmg';
				data.stepValue = 10;
				data.attributeName = 'SilverDamage';
				return true;

			case 'armor':
				data.stepAbility = 'autogen_fixed_armor_armor';
				data.stepValue = 5;
				data.attributeName = 'armor';
				return true;

			case 'pants':
			case 'boots':
				data.stepAbility = 'autogen_fixed_pants_armor';
				data.stepValue = 2;
				data.attributeName = 'armor';
				return true;

			case 'gloves':
				data.stepAbility = 'autogen_fixed_gloves_armor';
				data.stepValue = 2;
				data.attributeName = 'armor';
				return true;
		}
		return false;
	}

	// ---------------------------------------------------------------------
	// Level computation (side-effect free replication of the game's derivation)
	// ---------------------------------------------------------------------

	// Computes the level the game would display for this item WITHOUT mutating it.
	// Replicates inventoryComponent.GetItemLevel + gameParams.GetItemLevel
	// (verified identical in vanilla 4.04c and in this install's merged scripts,
	// for the categories supported here; bolts/crossbows are not supported).
	//
	// Deliberately UNCAPPED at the upper end (no maxLevel clamp): the add-until-equal
	// loop in Execute relies on uncapped equality, and uncapped equality of two items
	// implies equality of their clamped tooltip levels on every install variant
	// (vanilla NG+ uncaps tooltips; the merged scripts cap them — both are monotonic).
	// The lower clamp (>= 1) matches vanilla semantics on both sides.
	public function ComputeItemLevel( inv : CInventoryComponent, item : SItemUniqueId ) : int
	{
		var category : name;
		var quality : int;
		var level : int;
		var stat : SAbilityAttributeValue;
		var statF : float;

		if ( !inv.IsIdValid( item ) )
		{
			return 0;
		}

		category = inv.GetItemCategory( item );
		quality = RoundMath( CalculateAttributeValue( inv.GetItemAttributeValue( item, 'quality' ) ) );

		switch ( category )
		{
			case 'armor':
			case 'boots':
			case 'gloves':
			case 'pants':
				stat = inv.GetItemAttributeValue( item, 'armor' );
				level = FloorF( 1 + ( stat.valueBase - 25 ) / 5 );
				break;

			case 'silversword':
				statF = SumWeaponDamage( inv, item, true );
				level = CeilF( 1 + ( 1 + statF - 90 ) / 10 );
				break;

			case 'steelsword':
				statF = SumWeaponDamage( inv, item, false );
				level = CeilF( 1 + ( 1 + statF - 25 ) / 8 );
				break;

			default:
				return 0; // unsupported category: no meaningful level
		}

		level = level - 1;

		// Quality adjustments (inventoryComponent.GetItemLevel):
		if ( quality == 5 ) level -= 2;   // Witcher gear
		if ( quality == 4 ) level -= 1;   // relic gear

		if ( inv.ItemHasTag( item, 'OlgierdSabre' ) ) level -= 3;
		if ( ( quality == 4 || quality == 5 ) && inv.ItemHasTag( item, 'EP1' ) ) level -= 1;

		if ( level < 1 ) level = 1;

		return level;
	}

	// Sum of damage attributes used by the level formula.
	// silversword: SilverDamage + Bludgeoning + Rending + Elemental + Fire + Piercing
	// steelsword : SlashingDamage + Bludgeoning + Rending + Elemental + Fire + Silver + Piercing
	private function SumWeaponDamage( inv : CInventoryComponent, item : SItemUniqueId, isSilver : bool ) : float
	{
		var sum : float;
		var stat : SAbilityAttributeValue;

		if ( isSilver )
		{
			sum += GetAttrBase( inv, item, 'SilverDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'BludgeoningDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'RendingDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'ElementalDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'FireDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'PiercingDamage' ) - 1;
		}
		else
		{
			sum += GetAttrBase( inv, item, 'SlashingDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'BludgeoningDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'RendingDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'ElementalDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'FireDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'SilverDamage' ) - 1;
			sum += GetAttrBase( inv, item, 'PiercingDamage' ) - 1;
		}
		return sum;
	}

	private function GetAttrBase( inv : CInventoryComponent, item : SItemUniqueId, attributeName : name ) : float
	{
		var stat : SAbilityAttributeValue;
		stat = inv.GetItemAttributeValue( item, attributeName );
		return stat.valueBase;
	}

	// ---------------------------------------------------------------------
	// Item eligibility
	// ---------------------------------------------------------------------

	// Items the infusion must never touch (spec §14.2). Extend deliberately.
	private function IsExcludedItem( inv : CInventoryComponent, item : SItemUniqueId ) : bool
	{
		if ( inv.IsItemQuest( item ) )
		{
			return true;
		}
		// Aerondight grows through its own quest mechanic (effects/other/aerondight.ws).
		if ( inv.ItemHasTag( item, 'Aerondight' ) )
		{
			return true;
		}
		// Merchant-stocked leveled items use the AutogenUseLevelRange range system.
		// Not player loot; keep them out of the transaction for M2.
		if ( inv.ItemHasTag( item, 'AutogenUseLevelRange' ) )
		{
			return true;
		}
		return false;
	}

	// ---------------------------------------------------------------------
	// Preview / validation
	// ---------------------------------------------------------------------

	// Validates a prospective infusion WITHOUT modifying anything (spec §9.2, §5.5).
	public function Preview( targetId : SItemUniqueId, sacrificeId : SItemUniqueId, out preview : SInfusionPreview ) : EInfusionError
	{
		var inv : CInventoryComponent;
		var targetData, sacrificeData : SInfusionCategoryData;
		var targetLevel, sacrificeLevel : int;
		var gap : int;

		preview.targetId = targetId;
		preview.sacrificeId = sacrificeId;
		preview.errorCode = IFE_Ok;

		inv = GetWitcherPlayer().inv;

		if ( !inv.IsIdValid( targetId ) || !inv.IsIdValid( sacrificeId ) )
		{
			preview.errorCode = IFE_InvalidItemId;
			return preview.errorCode;
		}

		if ( targetId == sacrificeId )
		{
			preview.errorCode = IFE_SameItemInstance;
			return preview.errorCode;
		}

		// Distinctness on the underlying template too: two instances of the same
		// item definition are fine (different instances), but guard against
		// pathological duplicates via instance ids only (SItemUniqueId compare).

		if ( IsExcludedItem( inv, targetId ) || IsExcludedItem( inv, sacrificeId ) )
		{
			preview.errorCode = IFE_QuestItem;
			return preview.errorCode;
		}

		if ( !GetCategoryData( inv.GetItemCategory( targetId ), targetData ) )
		{
			preview.errorCode = IFE_UnsupportedCategory;
			return preview.errorCode;
		}

		if ( !GetCategoryData( inv.GetItemCategory( sacrificeId ), sacrificeData ) )
		{
			preview.errorCode = IFE_UnsupportedCategory;
			return preview.errorCode;
		}

		if ( targetData.category != sacrificeData.category )
		{
			preview.errorCode = IFE_CategoryMismatch;
			return preview.errorCode;
		}

		// M2 scope gate: steelswords only (spec §16 Milestone 2).
		if ( targetData.category != 'steelsword' )
		{
			preview.errorCode = IFE_DisabledCategory;
			return preview.errorCode;
		}

		if ( GetWitcherPlayer().IsItemEquipped( sacrificeId ) )
		{
			preview.errorCode = IFE_EquippedSacrifice;
			return preview.errorCode;
		}

		targetLevel = ComputeItemLevel( inv, targetId );
		sacrificeLevel = ComputeItemLevel( inv, sacrificeId );

		preview.targetCategory = targetData.category;
		preview.targetLevel = targetLevel;
		preview.sacrificeLevel = sacrificeLevel;
		preview.stepAbility = targetData.stepAbility;
		preview.stepValue = targetData.stepValue;

		gap = sacrificeLevel - targetLevel;
		preview.levelGap = gap;

		if ( gap <= 0 )
		{
			preview.errorCode = IFE_SacrificeNotHigher;
			return preview.errorCode;
		}

		preview.stepsToAdd = gap;
		preview.newLevel = targetLevel + gap;
		preview.laborFee = GetLaborFee( gap );
		preview.errorCode = IFE_Ok;
		return preview.errorCode;
	}

	// ---------------------------------------------------------------------
	// Labor fee (M2 flat; M5 full formula per spec §6.3)
	// ---------------------------------------------------------------------

	private function GetLaborFee( levelGap : int ) : int
	{
		var fee : int;
		fee = DEBUG_LABOR_FEE + levelGap * 10;
		if ( fee < 0 )
		{
			fee = 0;
		}
		return fee;
	}

	// ---------------------------------------------------------------------
	// Transaction (spec §13: validate -> verify -> commit -> verify)
	// ---------------------------------------------------------------------

	public function Execute( targetId : SItemUniqueId, sacrificeId : SItemUniqueId, out preview : SInfusionPreview ) : EInfusionError
	{
		var inv : CInventoryComponent;
		var err : EInfusionError;
		var levelBefore, levelAfter : int;
		var added, guard : int;
		var i : int;

		// 1) Full re-validation immediately before commit (spec §13.1).
		err = Preview( targetId, sacrificeId, preview );
		if ( err != IFE_Ok )
		{
			return err;
		}

		inv = GetWitcherPlayer().inv;

		if ( inv.GetMoney() < preview.laborFee )
		{
			preview.errorCode = IFE_NotEnoughCrowns;
			return preview.errorCode;
		}

		levelBefore = preview.targetLevel;

		// 2) Begin deferred inventory update (verified vanilla pattern).
		GetWitcherPlayer().StartInvUpdateTransaction();

		// 3) Apply level: add fixed step abilities until the target's UNCAPPED level
		//    equals the sacrifice's level (see ComputeItemLevel for why uncapped).
		//    Each autogen_fixed_* ability carries exactly one level's worth of stats
		//    (stepValue == stat_add), so the expected count is preview.levelGap; the
		//    small correction budget absorbs rounding or overhaul-mod drift. The loop
		//    condition (<) can never overshoot; the guard prevents runaway if ability
		//    addition were ever ineffective.
		added = 0;
		guard = preview.stepsToAdd + MAX_CORRECTION_STEPS;
		while ( ComputeItemLevel( inv, targetId ) < preview.sacrificeLevel && added < guard )
		{
			inv.AddItemCraftedAbility( targetId, preview.stepAbility, true );
			added += 1;
		}

		// 4) Verify the derived level actually moved as projected (spec §13.2).
		//    If not, roll back everything we added and abort without consuming anything.
		levelAfter = ComputeItemLevel( inv, targetId );
		if ( levelAfter != preview.sacrificeLevel )
		{
			LogChannel( 'Infusion', "ABORT: level mismatch after ability application. expected "
				+ preview.sacrificeLevel + ", got " + levelAfter + " after adding " + added
				+ " x " + preview.stepAbility + "; rolling back" );

			for ( i = 0; i < added; i += 1 )
			{
				inv.RemoveItemCraftedAbility( targetId, preview.stepAbility );
			}

			levelAfter = ComputeItemLevel( inv, targetId );
			LogChannel( 'Infusion', "rollback: level now " + levelAfter + " (was " + levelBefore + ")" );

			GetWitcherPlayer().FinishInvUpdateTransaction();
			preview.errorCode = IFE_LevelMismatch;
			return preview.errorCode;
		}

		// 5) Commit irreversible parts, in loss-minimizing order:
		//    charge money first, then consume the sacrifice (spec §13.2).
		inv.RemoveMoney( preview.laborFee );
		inv.RemoveItem( sacrificeId );

		// 6) Restore durability as part of the paid service (spec §3.4).
		if ( inv.HasItemDurability( targetId ) )
		{
			inv.SetItemDurabilityScript( targetId, inv.GetItemMaxDurability( targetId ) );
		}

		GetWitcherPlayer().FinishInvUpdateTransaction();

		LogChannel( 'Infusion', "OK: target " + inv.GetItemName( targetId )
			+ " level " + levelBefore + " -> " + levelAfter
			+ ", sacrifice " + inv.GetItemName( sacrificeId ) + " consumed ("
			+ added + " x " + preview.stepAbility + " added)"
			+ ", fee " + preview.laborFee );

		preview.errorCode = IFE_Ok;
		return IFE_Ok;
	}
}
