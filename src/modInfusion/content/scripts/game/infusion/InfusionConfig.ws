/***********************************************************************/
/** 	Witcher Gear Infusion — configuration
/** 	Balance model: the labor fee is anchored to the game's own economy —
/** 	it is a fraction of the sacrifice item's market value (the price the
/** 	game itself assigns to the item via GetItemPriceModified, which scales
/** 	with item level/tier). Official updates that change item prices or
/** 	loot scaling therefore automatically rebalance infusion fees — no
/** 	hard-coded crowns to go stale.
/**
/** 	Fee = sacrificeValue x feeFraction x craftsmanMult x targetTierMult
/** 	   x levelGapMult, rounded, clamped to >= minimumFee.
/**
/** 	In-game settings menu: NOT used. The Remastered settings UI is broken
/** 	for mod groups (invisible entries, unresolved labels); configuration
/** 	ships as curated defaults with a dev-only console override.
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
	default ENABLE_ARMOR = false;

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

	// Fee as a fraction of the sacrifice's market value (auto-balance anchor):
	// the game prices items by tier/level, so official rebalancing flows
	// through automatically.
	private const var FEE_FRACTION_OF_SACRIFICE_VALUE : float;
	default FEE_FRACTION_OF_SACRIFICE_VALUE = 0.10f;   // 10% of the sacrifice's value

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

	// Target tier multipliers by item quality (1..5).
	private const var TIER_MULT_1 : float;
	default TIER_MULT_1 = 1.0f;

	private const var TIER_MULT_2 : float;
	default TIER_MULT_2 = 1.2f;

	private const var TIER_MULT_3 : float;
	default TIER_MULT_3 = 1.5f;

	private const var TIER_MULT_4 : float;
	default TIER_MULT_4 = 2.0f;

	private const var TIER_MULT_5 : float;
	default TIER_MULT_5 = 3.0f;

	// Level-gap cost curve (spec §7.1): multiplier = 1 + gap/gapDivisor,
	// capped at gapMaxMult (spec §6.4: large upgrades cost more, but cap so
	// master services are not mandatory for every upgrade, §7.2).
	private const var GAP_DIVISOR : float;
	default GAP_DIVISOR = 10.0f;

	private const var GAP_MAX_MULT : float;
	default GAP_MAX_MULT = 3.0f;

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

	// Console overrides (dev harness; tests/infuseSetConfig). A fact set to a
	// nonzero value overrides the corresponding default. Player-invisible.
	//   InfCfg_BaseFee      - overrides FEE_FRACTION (value = fraction x 1000)
	//   InfCfg_MinFee       - overrides MIN_LABOR_FEE
	//   InfCfg_Salvage      - nonzero disables salvage economically
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

	// Level-gap multiplier (spec §7.1): 1 + gap/divisor, capped.
	public function GetLevelGapMultiplier( levelGap : int ) : float
	{
		var mult : float;

		if ( levelGap <= 0 )
		{
			return 1.0f;
		}

		mult = 1.0f + levelGap / GAP_DIVISOR;
		if ( mult > GAP_MAX_MULT )
		{
			mult = GAP_MAX_MULT;
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

	// The auto-balance anchor: the sacrifice's market value as priced by the
	// game itself (scales with level/tier; official economy updates flow
	// through). inv = the inventory holding the sacrifice.
	public function GetSacrificeValue( inv : CInventoryComponent, sacrificeId : SItemUniqueId ) : int
	{
		return inv.GetItemPriceModified( sacrificeId );
	}

	public function GetFeeFraction() : float
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_BASE_FEE );
		if ( factVal > 0 )
		{
			return factVal / 1000.0f;   // fact stores fraction x 1000
		}
		return FEE_FRACTION_OF_SACRIFICE_VALUE;
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
	public function SalvageEnabledNow() : bool
	{
		if ( FactsQuerySum( FACT_SALVAGE_OFF ) > 0 )
		{
			return false;
		}
		return ENABLE_SALVAGE;
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
