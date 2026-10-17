/***********************************************************************/
/** 	Witcher Gear Infusion — core infusion service
/** 	Level computation, validation, transaction. Reads all balance knobs
/** 	from W3InfusionConfig (InfusionConfig.ws); contains no balance values
/** 	itself.
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
/** 	      §6 (fees), §8.2 (eligibility), §13 (transaction safety)
/***********************************************************************/

class W3InfusionService extends IScriptable
{
	// Upper bound for the step-ability loop in Execute(): expected steps
	// (level gap) plus a small correction budget for rounding/overhaul drift.
	private const var MAX_CORRECTION_STEPS : int;
	default MAX_CORRECTION_STEPS = 3;

	// Injected configuration (set by the owner right after construction).
	// NULL-safe access: lazily creates a default config when unset (debug
	// harness convenience; production code sets it explicitly).
	public var config : W3InfusionConfig;

	// Public accessor for menu code (the private GetConfig stays internal).
	public function GetPublicConfig() : W3InfusionConfig
	{
		return GetConfig();
	}

	private function GetConfig() : W3InfusionConfig
	{
		if ( !config )
		{
			config = new W3InfusionConfig in theGame;
		}
		return config;
	}

	// ---------------------------------------------------------------------
	// Material requirements (spec §5.4) — recipes are balance values and live
	// in the config layer conceptually, but recipes are struct arrays which
	// the config class stores as per-category constants (see GetRecipeForCategory).
	// ---------------------------------------------------------------------

	// Base recipe per supported category. Values deliberately overlap with the
	// category's typical sacrifice yields so the salvage discount is exercised.
	// These are prototype balance values, not final decisions (spec §16 M3).
	private function GetRecipeForCategory( category : name, out recipe : array<SItemParts> ) : bool
	{
		var part : SItemParts;

		switch ( category )
		{
			case 'steelsword':
				part.itemName = 'Leather straps';
				part.quantity = 2;
				recipe.PushBack( part );
				part.itemName = 'Steel ingot';
				part.quantity = 2;
				recipe.PushBack( part );
				return true;

			case 'silversword':
				part.itemName = 'Leather straps';
				part.quantity = 2;
				recipe.PushBack( part );
				part.itemName = 'Meteorite ingot';
				part.quantity = 2;
				recipe.PushBack( part );
				return true;

			case 'armor':
				part.itemName = 'Leather squares';
				part.quantity = 2;
				recipe.PushBack( part );
				part.itemName = 'Thread';
				part.quantity = 4;
				recipe.PushBack( part );
				return true;

			case 'pants':
			case 'boots':
				part.itemName = 'Leather scraps';
				part.quantity = 2;
				recipe.PushBack( part );
				part.itemName = 'Thread';
				part.quantity = 2;
				recipe.PushBack( part );
				return true;

			case 'gloves':
				part.itemName = 'Leather scraps';
				part.quantity = 1;
				recipe.PushBack( part );
				part.itemName = 'Thread';
				part.quantity = 2;
				recipe.PushBack( part );
				return true;
		}
		return false;
	}

	// Salvage yield of the sacrifice: native recycling_parts data (spec §5.2
	// primary path). Returns false when the item has no salvage data; the
	// caller treats that as zero recovery.
	private function GetSalvageYield( inv : CInventoryComponent, item : SItemUniqueId, out yield : array<SItemParts> ) : bool
	{
		var parts : array<SItemParts>;
		var i : int;

		if ( !inv.IsIdValid( item ) )
		{
			return false;
		}

		parts = inv.GetItemRecyclingParts( item );
		if ( parts.Size() == 0 )
		{
			return false;
		}

		for ( i = 0; i < parts.Size(); i += 1 )
		{
			yield.PushBack( parts[i] );
		}
		return true;
	}

	// Remaining material requirements after applying the sacrifice's salvage
	// as a discount (spec §5.4). Excess salvage is discarded, never refunded.
	private function ComputeRemainingMaterials( recipe, salvaged : array<SItemParts>, out remaining : array<SItemParts> ) : void
	{
		var i, j : int;
		var salvagedQty : int;
		var part : SItemParts;

		for ( i = 0; i < recipe.Size(); i += 1 )
		{
			salvagedQty = 0;
			for ( j = 0; j < salvaged.Size(); j += 1 )
			{
				if ( salvaged[j].itemName == recipe[i].itemName )
				{
					salvagedQty = salvaged[j].quantity;
					break;
				}
			}

			part.itemName = recipe[i].itemName;
			part.quantity = recipe[i].quantity - salvagedQty;
			if ( part.quantity < 0 )
			{
				part.quantity = 0;   // excess salvage is discarded (spec §5.4)
			}
			if ( part.quantity > 0 )
			{
				remaining.PushBack( part );
			}
		}
	}

	// Scales salvage quantities by the configured yield multiplier (spec §10),
	// rounding down. With salvage disabled economically, zeroes everything.
	private function ApplySalvageMultiplier( salvaged : array<SItemParts> ) : void
	{
		var i : int;

		if ( !GetConfig().SalvageEnabled() )
		{
			for ( i = 0; i < salvaged.Size(); i += 1 )
			{
				salvaged[i].quantity = 0;
			}
			return;
		}

		if ( GetConfig().SalvageYieldMultiplier() == 1.0f )
		{
			return;
		}

		for ( i = 0; i < salvaged.Size(); i += 1 )
		{
			salvaged[i].quantity = FloorF( salvaged[i].quantity * GetConfig().SalvageYieldMultiplier() );
		}
	}

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
	// Public queries (used by the M6 menu integration)
	// ---------------------------------------------------------------------

	// True when the item's category is infusion-supported AND enabled
	// (exclusion rules + config gate). Uses the player's inventory context.
	public function IsSupportedTarget( item : SItemUniqueId ) : bool
	{
		var inv : CInventoryComponent;
		var data : SInfusionCategoryData;

		inv = GetWitcherPlayer().inv;
		if ( !inv.IsIdValid( item ) )
		{
			return false;
		}
		if ( IsExcludedItem( inv, item ) )
		{
			return false;
		}
		if ( !GetCategoryData( inv.GetItemCategory( item ), data ) )
		{
			return false;
		}
		return GetConfig().IsCategoryEnabled( data.category );
	}

	// Finds the best valid sacrifice for a target (highest level gap wins;
	// ties broken by lower fee). Returns false when none exists.
	public function FindBestSacrifice( inv : CInventoryComponent, targetId : SItemUniqueId, out sacrificeId : SItemUniqueId, out preview : SInfusionPreview, optional craftsman : CGameplayEntity ) : bool
	{
		var all : array<SItemUniqueId>;
		var p : SInfusionPreview;
		var i : int;
		var bestGap : int;

		bestGap = 0;
		inv.GetAllItems( all );

		for ( i = 0; i < all.Size(); i += 1 )
		{
			if ( all[i] == targetId )
			{
				continue;
			}
			if ( Preview( targetId, all[i], p, craftsman ) == IFE_Ok && p.levelGap > bestGap )
			{
				bestGap = p.levelGap;
				sacrificeId = all[i];
				preview = p;
			}
		}
		return bestGap > 0;
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
		// Technical body items (e.g. 'Body torso medalion': category armor,
		// tags NoDrop,NoShow,Body) are Geralt's own body meshes. They live in
		// the player inventory but are never shown to the player; consuming
		// one as a sacrifice would delete a body part. Same filters the
		// vanilla inventory UI applies (W3GuiBaseInventoryComponent).
		if ( inv.IsItemBody( item )
			|| inv.ItemHasTag( item, theGame.params.TAG_DONT_SHOW )
			|| inv.ItemHasTag( item, theGame.params.TAG_DONT_SHOW_ONLY_IN_PLAYERS ) )
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
	// craftsman: the NPC performing the service; NULL requires debugBypassCraftsman.
	public function Preview( targetId : SItemUniqueId, sacrificeId : SItemUniqueId, out preview : SInfusionPreview, optional craftsman : CGameplayEntity ) : EInfusionError
	{
		var inv : CInventoryComponent;
		var targetData, sacrificeData : SInfusionCategoryData;
		var targetLevel, sacrificeLevel : int;
		var gap : int;
		var remaining : array<SItemParts>;
		var quality : int;
		var craftsmanLevel : int;
		var comp : W3CraftsmanComponent;

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

		// Category feature gate (spec §10).
		if ( !GetConfig().IsCategoryEnabled( targetData.category ) )
		{
			preview.errorCode = IFE_DisabledCategory;
			return preview.errorCode;
		}

		if ( GetWitcherPlayer().IsItemEquipped( sacrificeId ) )
		{
			preview.errorCode = IFE_EquippedSacrifice;
			return preview.errorCode;
		}

		quality = RoundMath( CalculateAttributeValue( inv.GetItemAttributeValue( targetId, 'quality' ) ) );

		// Craftsman eligibility (M4, spec §8.2) — before costs so an
		// ineligible craftsman never sees a price.
		craftsmanLevel = 1;
		if ( craftsman )
		{
			comp = (W3CraftsmanComponent)craftsman.GetComponentByClassName( 'W3CraftsmanComponent' );
			if ( comp )
			{
				craftsmanLevel = comp.GetCraftsmanLevel( ECT_Smith );
			}
		}
		if ( !VerifyCraftsman( inv, targetId, craftsman, preview ) )
		{
			return preview.errorCode;
		}

		targetLevel = ComputeItemLevel( inv, targetId );
		sacrificeLevel = ComputeItemLevel( inv, sacrificeId );

		preview.targetCategory = targetData.category;
		preview.targetLevel = targetLevel;
		preview.sacrificeLevel = sacrificeLevel;
		preview.stepAbility = targetData.stepAbility;

		gap = sacrificeLevel - targetLevel;
		preview.levelGap = gap;

		if ( gap <= 0 )
		{
			preview.errorCode = IFE_SacrificeNotHigher;
			return preview.errorCode;
		}

		// Materials (spec §5.2/§5.4): native salvage data as discount, scaled
		// by the configured yield multiplier. Recipes are not gap-dependent
		// (spec §6.1: no double-charging the same gap).
		GetRecipeForCategory( targetData.category, preview.materials );
		GetSalvageYield( inv, sacrificeId, preview.salvaged );
		ApplySalvageMultiplier( preview.salvaged );
		remaining.Clear();
		ComputeRemainingMaterials( preview.materials, preview.salvaged, remaining );
		preview.materials = remaining;

		preview.stepsToAdd = gap;
		preview.newLevel = targetLevel + gap;
		preview.laborFee = GetLaborFee( inv, sacrificeId, gap, quality, craftsmanLevel );
		preview.errorCode = IFE_Ok;
		return preview.errorCode;
	}

	// ---------------------------------------------------------------------
	// Craftsman eligibility (M4, spec §8.2; data comes from the live NPC's
	// W3CraftsmanComponent — never hard-coded per NPC; thresholds from config)
	// ---------------------------------------------------------------------

	// Debug bypass: when true, Preview/Execute run without a craftsman
	// context (unit-style testing anywhere in the world). The production UI
	// path must always pass a craftsman entity and will not enable this.
	public var debugBypassCraftsman : bool;
	default debugBypassCraftsman = true;

	// Validates the craftsman against the target item.
	// craftsman may be NULL when debugBypassCraftsman is enabled.
	// Sets preview.errorCode and returns false on ineligibility.
	private function VerifyCraftsman( inv : CInventoryComponent, targetId : SItemUniqueId, craftsman : CGameplayEntity, out preview : SInfusionPreview ) : bool
	{
		var quality : int;
		var requiredLevel : int;
		var comp : W3CraftsmanComponent;
		var craftsmanLevel : ECraftsmanLevel;
		var category : name;
		var requiredType : ECraftsmanType;

		// Handle truthiness is the vanilla idiom (no == NULL comparisons).
		if ( !craftsman )
		{
			if ( debugBypassCraftsman )
			{
				return true;   // unit-test mode: no craftsman context required
			}
			preview.errorCode = IFE_NoCraftsman;
			return false;
		}

		comp = (W3CraftsmanComponent)craftsman.GetComponentByClassName( 'W3CraftsmanComponent' );
		if ( !comp )
		{
			preview.errorCode = IFE_NoCraftsman;
			return false;
		}

		category = inv.GetItemCategory( targetId );
		quality = RoundMath( CalculateAttributeValue( inv.GetItemAttributeValue( targetId, 'quality' ) ) );

		// Specialization: swordsmith for swords, armorer for armor pieces.
		if ( category == 'steelsword' || category == 'silversword' )
		{
			requiredType = ECT_Smith;
		}
		else
		{
			requiredType = ECT_Armorer;
		}

		if ( !comp.IsCraftsmanType( requiredType ) )
		{
			preview.errorCode = IFE_WrongCraftsmanType;
			return false;
		}

		// Tier: required level depends on the target's quality tier (config §8.2).
		requiredLevel = GetConfig().GetRequiredCraftsmanLevel( quality );
		craftsmanLevel = comp.GetCraftsmanLevel( requiredType );

		if ( craftsmanLevel < requiredLevel )
		{
			preview.errorCode = IFE_CraftsmanLevelTooLow;
			return false;
		}

		return true;
	}

	// ---------------------------------------------------------------------
	// Material inventory operations (spec §5.4, §13.1)
	// ---------------------------------------------------------------------

	// True when the inventory holds at least the required quantity of every
	// remaining material.
	private function VerifyMaterials( inv : CInventoryComponent, required : array<SItemParts> ) : bool
	{
		var i : int;

		for ( i = 0; i < required.Size(); i += 1 )
		{
			if ( required[i].quantity > 0
				&& inv.GetItemQuantityByName( required[i].itemName ) < required[i].quantity )
			{
				return false;
			}
		}
		return true;
	}

	// Deducts the required material quantities from the inventory.
	// Call only after VerifyMaterials passed (spec §13.1).
	private function RemoveMaterials( inv : CInventoryComponent, required : array<SItemParts> ) : void
	{
		var i : int;

		for ( i = 0; i < required.Size(); i += 1 )
		{
			if ( required[i].quantity > 0 )
			{
				inv.RemoveItemByName( required[i].itemName, required[i].quantity );
			}
		}
	}

	// Human-readable material list for log lines ("item xN[, item xN...]").
	private function DescribeMaterials( parts : array<SItemParts> ) : string
	{
		var i : int;
		var text : string;

		text = "";
		for ( i = 0; i < parts.Size(); i += 1 )
		{
			if ( parts[i].quantity <= 0 )
			{
				continue;
			}
			if ( text != "" )
			{
				text += ", ";
			}
			text += parts[i].itemName + " x" + parts[i].quantity;
		}
		if ( text == "" )
		{
			text = " none";
		}
		return text;
	}

	// ---------------------------------------------------------------------
	// Labor fee (auto-balanced: fraction of the sacrifice's market value,
	// scaled by craftsman tier, target tier, and level gap — spec §6.2/§6.3)
	// ---------------------------------------------------------------------

	private function GetLaborFee( inv : CInventoryComponent, sacrificeId : SItemUniqueId, gap : int, quality : int, craftsmanLevel : int ) : int
	{
		var fee : float;
		var mult : float;
		var sacrificeValue : int;
		var minFee : int;

		// Anchor: the sacrifice's market value (auto-balances with the game's
		// economy — official updates to item prices/loot scaling flow through).
		sacrificeValue = GetConfig().GetSacrificeValue( inv, sacrificeId );

		mult = GetConfig().GetCraftsmanMultiplier( craftsmanLevel )
			* GetConfig().GetTargetTierMultiplier( quality )
			* GetConfig().GetLevelGapMultiplier( gap );

		fee = sacrificeValue * GetConfig().GetFeeFraction() * mult;

		// Labor floor: even a zero-value sacrifice costs the craftsman's time.
		minFee = GetConfig().GetMinLaborFee();
		if ( fee < minFee )
		{
			fee = minFee;
		}
		return RoundMath( fee );
	}

	// ---------------------------------------------------------------------
	// Transaction (spec §13: validate -> verify -> commit -> verify)
	// ---------------------------------------------------------------------

	public function Execute( targetId : SItemUniqueId, sacrificeId : SItemUniqueId, out preview : SInfusionPreview, optional craftsman : CGameplayEntity ) : EInfusionError
	{
		var inv : CInventoryComponent;
		var err : EInfusionError;
		var levelBefore, levelAfter : int;
		var added, guard : int;
		var i : int;
		var sacrificeName : name;

		// 1) Full re-validation immediately before commit (spec §13.1).
		err = Preview( targetId, sacrificeId, preview, craftsman );
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

		// Material check AFTER the salvage discount (spec §5.4/§13.1).
		if ( !VerifyMaterials( inv, preview.materials ) )
		{
			preview.errorCode = IFE_NotEnoughMaterials;
			LogChannel( 'Infusion', "ABORT: missing materials. requirements:" + DescribeMaterials( preview.materials )
				+ " (salvage covered " + DescribeMaterials( preview.salvaged ) + ")" );
			return preview.errorCode;
		}

		levelBefore = preview.targetLevel;
		sacrificeName = inv.GetItemName( sacrificeId );

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
		//    charge money, consume materials, then consume the sacrifice
		//    (spec §13.2).
		inv.RemoveMoney( preview.laborFee );
		if ( GetConfig().SalvageEnabled() )
		{
			RemoveMaterials( inv, preview.materials );
		}
		inv.RemoveItem( sacrificeId );

		// 6) Restore durability as part of the paid service (spec §3.4).
		if ( GetConfig().RestoreTargetDurability() && inv.HasItemDurability( targetId ) )
		{
			inv.SetItemDurabilityScript( targetId, inv.GetItemMaxDurability( targetId ) );
		}

		GetWitcherPlayer().FinishInvUpdateTransaction();

		LogChannel( 'Infusion', "OK: target " + inv.GetItemName( targetId )
			+ " level " + levelBefore + " -> " + levelAfter
			+ ", sacrifice " + sacrificeName + " consumed ("
			+ added + " x " + preview.stepAbility + " added)"
			+ ", fee " + preview.laborFee );

		preview.errorCode = IFE_Ok;
		return IFE_Ok;
	}
}
