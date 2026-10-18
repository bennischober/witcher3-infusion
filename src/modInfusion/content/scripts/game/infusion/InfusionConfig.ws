/***********************************************************************/
/** 	Witcher Gear Infusion — configuration
/** 	Balance model and knobs in one place.
/**
/** 	Auto-balance: the labor fee anchors to the sacrifice item's market
/** 	value (GetItemPriceModified — the game's own level/tier-scaled price)
/** 	as a fraction, so official economy updates rebalance infusion fees
/** 	automatically. Multipliers (§6.2) shape it; a labor floor keeps
/** 	zero-value sacrifices meaningful.
/**
/** 	Settings menu: NOT used (Remastered settings UI is broken for mod
/** 	groups; decision documented in docs/TECHNICAL_DISCOVERY.md). Values
/** 	ship as curated script defaults; a dev-only console override via
/** 	persistent facts allows live tuning without recompiling
/** 	(tests/infuseSetConfig).
/**
/** 	Spec: INFUSION_SPEC.md §6 (fees), §7 (efficiency), §10 (configuration),
/** 	      §8.2 (eligibility thresholds)
/***********************************************************************/

class W3InfusionConfig extends IScriptable
{
	// ============================ feature flags ============================

	// Master switch (spec §10 EnableInfusion).
	private const var ENABLE_INFUSION : bool;
	default ENABLE_INFUSION = true;

	// Category gates. M2/M3 scope: only steelsword enabled; the others
	// activate with their milestones.
	private const var ENABLE_STEEL_SWORD : bool;
	default ENABLE_STEEL_SWORD = true;

	private const var ENABLE_SILVER_SWORD : bool;
	default ENABLE_SILVER_SWORD = false;

	private const var ENABLE_ARMOR : bool;
	default ENABLE_ARMOR = true;

	// ========================== craftsman gates ============================

	// Tier requirements by target quality (spec §8.2). Quality is the game's
	// rarity signal: 1-3 ordinary, 4 = relic, 5 = Witcher gear.
	// ECraftsmanLevel ordinals: 1 = Journeyman ... 4 = Arch Master.
	private const var TIER_REQ_ORDINARY : int;
	default TIER_REQ_ORDINARY = 1;   // ECL_Journeyman

	private const var TIER_REQ_RELIC : int;
	default TIER_REQ_RELIC = 2;      // ECL_Master

	private const var TIER_REQ_WITCHER : int;
	default TIER_REQ_WITCHER = 3;    // ECL_Grand_Master

	// ============================= labor fees ==============================

	// Balancing model (2026-10-18): the fee is anchored to the TARGET's market
	// value (the item being upgraded), not the sacrifice's - sacrifices are
	// usually cheap loot, which made large upgrades of valuable gear nearly
	// free. fee = targetValue * fraction * gapFactor * craftsman * tier.
	// At a 10-level gap the fee is 25% of the target's current value.
	private const var FEE_FRACTION_OF_TARGET_VALUE : float;
	default FEE_FRACTION_OF_TARGET_VALUE = 0.25f;

	// Floor so tiny/zero-value sacrifices still cost something (labor!).
	private const var MIN_LABOR_FEE : int;
	default MIN_LABOR_FEE = 10;

	// Craftsman tier multipliers (spec §6.2; real game tiers).
	private const var MULT_JOURNEYMAN : float;
	default MULT_JOURNEYMAN = 1.0f;

	private const var MULT_MASTER : float;
	default MULT_MASTER = 1.5f;

	private const var MULT_GRAND_MASTER : float;
	default MULT_GRAND_MASTER = 2.0f;

	private const var MULT_ARCH_MASTER : float;
	default MULT_ARCH_MASTER = 2.5f;

	// Target tier multipliers by item quality (1..5) (spec §6.3 knob). 1.0 by
	// default: the target's market value already scales with its tier
	// (Witcher armor ~4,500 base vs ~250 for ordinary armor).
	private const var TIER_MULT_1 : float;
	default TIER_MULT_1 = 1.0f;

	private const var TIER_MULT_2 : float;
	default TIER_MULT_2 = 1.0f;

	private const var TIER_MULT_3 : float;
	default TIER_MULT_3 = 1.0f;

	private const var TIER_MULT_4 : float;
	default TIER_MULT_4 = 1.0f;

	private const var TIER_MULT_5 : float;
	default TIER_MULT_5 = 1.0f;

	// Level-gap factor (spec §7.1), shared by the fee and the material
	// recipe: gapFactor = gap / LEVELS_PER_FULL_SET, capped at MAX_SETS.
	// 10 levels = one full set of the target's components and 1x the fee
	// fraction; the cap keeps huge NG+ jumps bounded (spec §8.3: no level
	// cap, but costs must stay valid).
	private const var LEVELS_PER_FULL_SET : float;
	default LEVELS_PER_FULL_SET = 10.0f;

	private const var MAX_SETS : float;
	default MAX_SETS = 3.0f;

	// ============================== salvage ================================

	private const var ENABLE_SALVAGE : bool;
	default ENABLE_SALVAGE = true;

	// Global multiplier on recovered quantities, rounded down (spec §10).
	private const var SALVAGE_YIELD_MULT : float;
	default SALVAGE_YIELD_MULT = 1.0f;

	// ========================== durability ================================

	private const var RESTORE_DURABILITY : bool;
	default RESTORE_DURABILITY = true;

	// ============================ debug facts ==============================

	// Console overrides (dev harness; tests/infuseSetConfig). A fact set to
	// a nonzero value overrides the corresponding default. Player-invisible.
	//   InfCfg_BaseFee  - overrides the fee fraction (value = fraction x 1000)
	//   InfCfg_MinFee   - overrides MIN_LABOR_FEE
	//   InfCfg_Salvage  - nonzero disables salvage economically
	private const var FACT_BASE_FEE : string;
	default FACT_BASE_FEE = "InfCfg_BaseFee";

	private const var FACT_MIN_FEE : string;
	default FACT_MIN_FEE = "InfCfg_MinFee";

	private const var FACT_SALVAGE_OFF : string;
	default FACT_SALVAGE_OFF = "InfCfg_Salvage";

	// ---------------------------------------------------------------------
	// Accessors (the service's only interface)
	// ---------------------------------------------------------------------

	public function EnableInfusion() : bool
	{
		return ENABLE_INFUSION;
	}

	// Category feature gate.
	public function IsCategoryEnabled( category : name ) : bool
	{
		if ( category == 'steelsword' )
		{
			return ENABLE_STEEL_SWORD;
		}
		if ( category == 'silversword' )
		{
			return ENABLE_SILVER_SWORD;
		}
		if ( category == 'armor' || category == 'pants' || category == 'boots' || category == 'gloves' )
		{
			return ENABLE_ARMOR;
		}
		return false;
	}

	// Craftsman multiplier by tier enum ordinal (1 = Journeyman ... 4 = Arch Master).
	public function GetCraftsmanMultiplier( craftsmanLevel : int ) : float
	{
		if ( craftsmanLevel <= 1 )
		{
			return MULT_JOURNEYMAN;
		}
		if ( craftsmanLevel == 2 )
		{
			return MULT_MASTER;
		}
		if ( craftsmanLevel == 3 )
		{
			return MULT_GRAND_MASTER;
		}
		return MULT_ARCH_MASTER;
	}

	// Target tier multiplier by item quality (1..5).
	public function GetTargetTierMultiplier( quality : int ) : float
	{
		if ( quality <= 1 )
		{
			return TIER_MULT_1;
		}
		if ( quality == 2 )
		{
			return TIER_MULT_2;
		}
		if ( quality == 3 )
		{
			return TIER_MULT_3;
		}
		if ( quality == 4 )
		{
			return TIER_MULT_4;
		}
		return TIER_MULT_5;
	}

	// Level-gap factor (spec §7.1): gap / LEVELS_PER_FULL_SET, capped at
	// MAX_SETS. Used for the fee and for the material recipe.
	public function GetLevelGapMultiplier( levelGap : int ) : float
	{
		var mult : float;

		if ( levelGap <= 0 )
		{
			return 0.0f;
		}

		mult = levelGap / LEVELS_PER_FULL_SET;
		if ( mult > MAX_SETS )
		{
			mult = MAX_SETS;
		}
		return mult;
	}

	// Craftsman tier requirement for a target quality (spec §8.2).
	public function GetRequiredCraftsmanLevel( quality : int ) : int
	{
		if ( quality >= 5 )
		{
			return TIER_REQ_WITCHER;
		}
		if ( quality == 4 )
		{
			return TIER_REQ_RELIC;
		}
		return TIER_REQ_ORDINARY;
	}

	// --------------------------- fee anchors -----------------------------

	// The auto-balance anchor: the target's market value as priced by the
	// game itself (scales with level and tier; official economy updates flow
	// through).
	public function GetTargetValue( inv : CInventoryComponent, targetId : SItemUniqueId ) : int
	{
		return inv.GetItemPriceModified( targetId );
	}

	public function GetFeeFraction() : float
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_BASE_FEE );
		if ( factVal > 0 )
		{
			return factVal / 1000.0f;   // fact stores fraction x 1000
		}
		return FEE_FRACTION_OF_TARGET_VALUE;
	}

	public function GetMinLaborFee() : int
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_MIN_FEE );
		if ( factVal > 0 )
		{
			return factVal;
		}
		return MIN_LABOR_FEE;
	}

	// Salvage toggle including the debug override.
	public function SalvageEnabled() : bool
	{
		if ( FactsQuerySum( FACT_SALVAGE_OFF ) > 0 )
		{
			return false;
		}
		return ENABLE_SALVAGE;
	}

	// Global multiplier on recovered quantities (rounded down by the caller).
	public function SalvageYieldMultiplier() : float
	{
		return SALVAGE_YIELD_MULT;
	}

	public function RestoreTargetDurability() : bool
	{
		return RESTORE_DURABILITY;
	}

	// =====================================================================
	// Validation helpers (spec §10: invalid values must not cause negative
	// costs, unlimited resource generation, or script errors)
	// =====================================================================

	public function SanitizeInt( value : int, minValue : int, maxValue : int ) : int
	{
		if ( value < minValue )
		{
			return minValue;
		}
		if ( value > maxValue )
		{
			return maxValue;
		}
		return value;
	}
}
