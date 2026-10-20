/***********************************************************************/
/** 	Witcher Gear Infusion — configuration
/** 	Balance model and knobs in one place.
/**
/** 	Auto-balance: the labor fee anchors to the craftsman's full-repair
/** 	price of the target or the sacrifice, whichever is higher (the game's
/** 	own level-scaled, regional price), so official economy updates
/** 	rebalance infusion fees automatically. Multipliers (§6.2) shape it; a labor floor keeps
/** 	cheap targets meaningful, a soft ceiling keeps expensive ones affordable.
/** 	Model: docs/BALANCING.md.
/**
/** 	Settings menu: NOT used (the Remastered settings UI is broken for mod
/** 	groups; docs/TECHNICAL_DISCOVERY.md §1). Values ship as curated script
/** 	defaults; dev builds can override some at runtime via facts
/** 	(console command infuseSetConfig).
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

	// Category gates (spec §10 EnableSwordInfusion / EnableArmorInfusion).
	private const var ENABLE_STEEL_SWORD : bool;
	default ENABLE_STEEL_SWORD = true;

	private const var ENABLE_SILVER_SWORD : bool;
	default ENABLE_SILVER_SWORD = true;

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

	// The fee is anchored to what THIS craftsman charges for a full repair
	// (vanilla repair service: price per durability point x max durability)
	// of the target or the sacrifice, whichever is higher. That price follows
	// the item's level, rarity and NG+ value and the craftsman's regional
	// economy (measured: Novigrad +17 %, Skellige +8 % over Velen;
	// TECHNICAL_DISCOVERY.md §6). The sacrifice's price stands in for the
	// level the target is raised to: priced on the target alone, a big jump
	// from a low level cost less than a small one at a high level.
	// fee = fullRepair * FEE_REPAIR_MULT * gapFactor * craftsman * tier.
	// At a 10-level gap the fee is one full repair at this craftsman.
	private const var FEE_REPAIR_MULT : float;
	default FEE_REPAIR_MULT = 1.0f;

	// Without a craftsman (scenario tests) the anchor is this fraction of the
	// target's market value - about what vanilla charges for a full repair.
	private const var FALLBACK_VALUE_FRACTION : float;
	default FALLBACK_VALUE_FRACTION = 0.25f;

	// Floor so tiny/zero-value sacrifices still cost something (labor!).
	private const var MIN_LABOR_FEE : int;
	default MIN_LABOR_FEE = 10;

	// Ceiling for any fee (overflow guard, not a balance knob).
	private const var MAX_LABOR_FEE : int;
	default MAX_LABOR_FEE = 10000000;

	// Soft ceiling in crowns. Up to it the fee is unchanged; above it the
	// fee grows with the square root: fee = sqrt(fee x FEE_SOFT_CAP), so
	// 8,000 -> 4,000 and 18,000 -> 6,000. Costlier jobs still cost more,
	// but stay payable: the balance report (2026-10-20) reached 18,000 at
	// L150, while a finished playthrough leaves about 10,000 crowns - NG+
	// sell prices don't become income, traders carry limited money.
	// 0 = off.
	private const var FEE_SOFT_CAP : int;
	default FEE_SOFT_CAP = 2000;

	// Craftsman tier multipliers (spec §6.2; real game tiers).
	private const var MULT_JOURNEYMAN : float;
	default MULT_JOURNEYMAN = 1.0f;

	private const var MULT_MASTER : float;
	default MULT_MASTER = 1.5f;

	private const var MULT_GRAND_MASTER : float;
	default MULT_GRAND_MASTER = 2.0f;

	private const var MULT_ARCH_MASTER : float;
	default MULT_ARCH_MASTER = 2.5f;

	// Target tier multipliers by item quality (1..5) (spec §6.3 knob). The
	// repair price barely follows rarity at high levels (balance report
	// 2026-10-20: Witcher armor ~1.4x ordinary armor, a relic sword ~1.1x an
	// ordinary sword at L150), so relics and Witcher gear - the items that
	// need a master or grandmaster - get their own multiplier.
	private const var TIER_MULT_1 : float;
	default TIER_MULT_1 = 1.0f;

	private const var TIER_MULT_2 : float;
	default TIER_MULT_2 = 1.0f;

	private const var TIER_MULT_3 : float;
	default TIER_MULT_3 = 1.0f;

	private const var TIER_MULT_4 : float;
	default TIER_MULT_4 = 1.5f;   // relic

	private const var TIER_MULT_5 : float;
	default TIER_MULT_5 = 2.0f;   // Witcher gear

	// Level-gap factor (spec §7.1), shared by the fee and the material
	// recipe: gapFactor = gap / LEVELS_PER_FULL_SET, capped at MAX_SETS.
	// 10 levels = one full set of the target's components and 1x the fee
	// fraction; the cap keeps huge NG+ jumps bounded (spec §8.3: no level
	// cap, but costs must stay valid).
	private const var LEVELS_PER_FULL_SET : float;
	default LEVELS_PER_FULL_SET = 10.0f;

	private const var MAX_SETS : float;
	default MAX_SETS = 3.0f;

	// ============================= materials ===============================

	// Material requirements (spec §10 RequireCraftingMaterials). Off: the
	// infusion costs the labor fee only, salvage is irrelevant.
	private const var REQUIRE_MATERIALS : bool;
	default REQUIRE_MATERIALS = true;

	// ============================== salvage ================================

	private const var ENABLE_SALVAGE : bool;
	default ENABLE_SALVAGE = true;

	// Global multiplier on recovered quantities, rounded down (spec §10).
	private const var SALVAGE_YIELD_MULT : float;
	default SALVAGE_YIELD_MULT = 1.0f;

	// ========================== durability ================================

	private const var RESTORE_DURABILITY : bool;
	default RESTORE_DURABILITY = true;

	// ============================== logging ================================

	// Per-item grid diagnostics (one log line per item and grid refresh -
	// floods scriptslog.txt in large inventories). Off by default; the
	// InfCfg_Debug fact switches it on at runtime (infuseSetConfig debug 1).
	// Transaction results (OK / ABORT) are always logged.
	private const var DEBUG_LOGGING : bool;
	default DEBUG_LOGGING = false;

	// ============================ debug facts ==============================

	// Console overrides (dev harness; tests/infuseSetConfig). A fact set to
	// a nonzero value overrides the corresponding default. Player-invisible.
	//   InfCfg_BaseFee  - overrides FEE_REPAIR_MULT (value = multiplier x 1000)
	//   InfCfg_MinFee   - overrides MIN_LABOR_FEE
	//   InfCfg_SoftCap  - overrides FEE_SOFT_CAP (a huge value switches it off)
	//   InfCfg_Salvage  - nonzero disables salvage (no discount: full recipe)
	//   InfCfg_NoMaterials - nonzero disables material requirements
	//   InfCfg_Debug    - nonzero enables the per-item grid logging
	private const var FACT_BASE_FEE : string;
	default FACT_BASE_FEE = "InfCfg_BaseFee";

	private const var FACT_MIN_FEE : string;
	default FACT_MIN_FEE = "InfCfg_MinFee";

	private const var FACT_SOFT_CAP : string;
	default FACT_SOFT_CAP = "InfCfg_SoftCap";

	private const var FACT_SALVAGE_OFF : string;
	default FACT_SALVAGE_OFF = "InfCfg_Salvage";

	private const var FACT_DEBUG_LOG : string;
	default FACT_DEBUG_LOG = "InfCfg_Debug";

	private const var FACT_NO_MATERIALS : string;
	default FACT_NO_MATERIALS = "InfCfg_NoMaterials";

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
			return SafeMultiplier( MULT_JOURNEYMAN );
		}
		if ( craftsmanLevel == 2 )
		{
			return SafeMultiplier( MULT_MASTER );
		}
		if ( craftsmanLevel == 3 )
		{
			return SafeMultiplier( MULT_GRAND_MASTER );
		}
		return SafeMultiplier( MULT_ARCH_MASTER );
	}

	// Target tier multiplier by item quality (1..5).
	public function GetTargetTierMultiplier( quality : int ) : float
	{
		if ( quality <= 1 )
		{
			return SafeMultiplier( TIER_MULT_1 );
		}
		if ( quality == 2 )
		{
			return SafeMultiplier( TIER_MULT_2 );
		}
		if ( quality == 3 )
		{
			return SafeMultiplier( TIER_MULT_3 );
		}
		if ( quality == 4 )
		{
			return SafeMultiplier( TIER_MULT_4 );
		}
		return SafeMultiplier( TIER_MULT_5 );
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

		mult = levelGap / ClampF( LEVELS_PER_FULL_SET, 1.0f, 1000.0f );
		return MinF( mult, ClampF( MAX_SETS, 0.1f, 100.0f ) );
	}

	// Craftsman tier requirement for a target quality (spec §8.2).
	public function GetRequiredCraftsmanLevel( quality : int ) : int
	{
		if ( quality >= 5 )
		{
			return Clamp( TIER_REQ_WITCHER, 1, 4 );
		}
		if ( quality == 4 )
		{
			return Clamp( TIER_REQ_RELIC, 1, 4 );
		}
		return Clamp( TIER_REQ_ORDINARY, 1, 4 );
	}

	// --------------------------- fee anchors -----------------------------

	// The target's market value as priced by the game itself (player side:
	// level, rarity, NG+; no regional factor). Fallback anchor only.
	public function GetTargetValue( inv : CInventoryComponent, targetId : SItemUniqueId ) : int
	{
		return inv.GetItemPriceModified( targetId );
	}

	// Multiplier on the craftsman's full-repair price (spec §6.3 BaseFee).
	public function GetFeeMultiplier() : float
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_BASE_FEE );
		if ( factVal > 0 )
		{
			return SafeMultiplier( factVal / 1000.0f );   // fact stores multiplier x 1000
		}
		return SafeMultiplier( FEE_REPAIR_MULT );
	}

	public function GetFallbackValueFraction() : float
	{
		return SafeMultiplier( FALLBACK_VALUE_FRACTION );
	}

	public function GetMinLaborFee() : int
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_MIN_FEE );
		if ( factVal > 0 )
		{
			return Min( factVal, MAX_LABOR_FEE );
		}
		return Clamp( MIN_LABOR_FEE, 0, MAX_LABOR_FEE );
	}

	// Soft-ceiling threshold in crowns (0 = off).
	public function GetFeeSoftCap() : int
	{
		var factVal : int;

		factVal = FactsQuerySum( FACT_SOFT_CAP );
		if ( factVal > 0 )
		{
			return Min( factVal, MAX_LABOR_FEE );
		}
		return Clamp( FEE_SOFT_CAP, 0, MAX_LABOR_FEE );
	}

	// Upper bound for any fee (spec §8.3/§15.4: no overflow at NG+ levels).
	public function GetMaxLaborFee() : int
	{
		return MAX_LABOR_FEE;
	}

	// Material requirement toggle including the debug override.
	public function RequireCraftingMaterials() : bool
	{
		if ( FactsQuerySum( FACT_NO_MATERIALS ) > 0 )
		{
			return false;
		}
		return REQUIRE_MATERIALS;
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
		return ClampF( SALVAGE_YIELD_MULT, 0.0f, 10.0f );
	}

	public function RestoreTargetDurability() : bool
	{
		return RESTORE_DURABILITY;
	}

	public function DebugLogging() : bool
	{
		return DEBUG_LOGGING || FactsQuerySum( FACT_DEBUG_LOG ) > 0;
	}

	// --------------------------- validation ------------------------------

	// Config values are player-editable constants (spec §10: invalid values
	// must not cause negative costs or script errors). Multipliers and
	// fractions are clamped to [0, 100]; the accessors above clamp the rest.
	private function SafeMultiplier( value : float ) : float
	{
		return ClampF( value, 0.0f, 100.0f );
	}
}
