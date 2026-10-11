/***********************************************************************/
/** 	Witcher Gear Infusion — configuration
/** 	All balance knobs and tuning values in one place. The service reads
/** 	these through getters; M5 swaps the backing source (script constants
/** 	-> in-game settings) WITHOUT touching the service logic.
/**
/** 	Spec: INFUSION_SPEC.md §6 (fees), §7 (efficiency), §10 (configuration),
/** 	      §8.2 (eligibility thresholds)
/***********************************************************************/

class W3InfusionConfig extends IScriptable
{
	// ============================ feature flags ============================

	// Master switch for the whole feature (spec §10 EnableInfusion).
	public var enableInfusion : bool;
	default enableInfusion = true;

	// Category toggles (spec §10). M2/M3 gate: only steelsword is enabled;
	// the remaining categories activate with their milestones.
	public var enableSteelSwordInfusion : bool;
	default enableSteelSwordInfusion = true;

	public var enableSilverSwordInfusion : bool;
	default enableSilverSwordInfusion = false;   // Milestone: silver swords

	public var enableArmorInfusion : bool;
	default enableArmorInfusion = false;         // Milestone: armor pieces

	// ========================== craftsman gates ============================

	// Tier requirements by target quality (spec §8.2). Quality is the game's
	// own rarity signal: 1-3 ordinary, 4 = relic, 5 = Witcher gear.
	// Values are ECraftsmanLevel enum ordinals (1 = Journeyman ... 4 = Arch Master).
	public var craftsmanLevelForOrdinaryGear : int;
	default craftsmanLevelForOrdinaryGear = 1;   // ECL_Journeyman

	public var craftsmanLevelForRelicGear : int;
	default craftsmanLevelForRelicGear = 2;      // ECL_Master

	public var craftsmanLevelForWitcherGear : int;
	default craftsmanLevelForWitcherGear = 3;    // ECL_Grand_Master

	// ============================= labor fees ==============================

	// LaborFee = baseFee x craftsmanMult(tier) x targetTierMult(quality)
	//          x levelGapMult(gap)   (spec §6.3)
	public var baseLaborFee : int;
	default baseLaborFee = 50;

	// Craftsman tier multipliers (spec §6.2, real game tiers).
	public var laborMultJourneyman : float;
	default laborMultJourneyman = 1.0f;

	public var laborMultMaster : float;
	default laborMultMaster = 1.5f;

	public var laborMultGrandMaster : float;
	default laborMultGrandMaster = 2.0f;

	public var laborMultArchMaster : float;
	default laborMultArchMaster = 2.5f;

	// Target tier multipliers by item quality (grey..Witcher gear).
	// Index = quality (1..5).
	public var targetTierMult1, targetTierMult2, targetTierMult3 : float;
	default targetTierMult1 = 1.0f;
	default targetTierMult2 = 1.2f;
	default targetTierMult3 = 1.5f;

	public var targetTierMult4, targetTierMult5 : float;
	default targetTierMult4 = 2.0f;
	default targetTierMult5 = 3.0f;

	// Level-gap cost curve (spec §6.3/§7.1): fee multiplier grows with the
	// gap. Multiplier = 1 + gap / gapDivisor, capped at gapMaxMult.
	public var gapCostDivisor : float;
	default gapCostDivisor = 10.0f;

	public var gapCostMaxMult : float;
	default gapCostMaxMult = 3.0f;

	// ============================== salvage ================================

	// Enables material recovery from the sacrifice (spec §10 EnableSalvage).
	public var enableSalvage : bool;
	default enableSalvage = true;

	// Global multiplier on recovered quantities (spec §10 SalvageYieldMultiplier).
	// Fractional results round down; 0 disables recovery economically.
	public var salvageYieldMultiplier : float;
	default salvageYieldMultiplier = 1.0f;

	// ========================== durability ================================

	// Full durability restoration as part of the service (spec §3.4, §10).
	public var restoreTargetDurability : bool;
	default restoreTargetDurability = true;

	// ============================ validation ===============================

	// Applies the §10 safety rules to a candidate integer knob.
	// Returns the sanitized value (never negative, sane bounds).
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

	// Craftsman multiplier by tier enum ordinal (1 = Journeyman ... 4 = Arch Master).
	public function GetCraftsmanMultiplier( craftsmanLevel : int ) : float
	{
		if ( craftsmanLevel <= 1 )
		{
			return laborMultJourneyman;
		}
		if ( craftsmanLevel == 2 )
		{
			return laborMultMaster;
		}
		if ( craftsmanLevel == 3 )
		{
			return laborMultGrandMaster;
		}
		return laborMultArchMaster;
	}

	// Target tier multiplier by item quality (1..5).
	public function GetTargetTierMultiplier( quality : int ) : float
	{
		if ( quality <= 1 )
		{
			return targetTierMult1;
		}
		if ( quality == 2 )
		{
			return targetTierMult2;
		}
		if ( quality == 3 )
		{
			return targetTierMult3;
		}
		if ( quality == 4 )
		{
			return targetTierMult4;
		}
		return targetTierMult5;
	}

	// Level-gap multiplier for the fee curve (spec §7.1).
	public function GetLevelGapMultiplier( levelGap : int ) : float
	{
		var mult : float;

		if ( levelGap <= 0 )
		{
			return 1.0f;
		}

		mult = 1.0f + levelGap / gapCostDivisor;
		if ( mult > gapCostMaxMult )
		{
			mult = gapCostMaxMult;
		}
		return mult;
	}

	// Craftsman tier requirement for a target quality (spec §8.2).
	public function GetRequiredCraftsmanLevel( quality : int ) : int
	{
		if ( quality >= 5 )
		{
			return craftsmanLevelForWitcherGear;
		}
		if ( quality == 4 )
		{
			return craftsmanLevelForRelicGear;
		}
		return craftsmanLevelForOrdinaryGear;
	}

	// Category feature gate (M2/M3 scope: only steelsword enabled).
	public function IsCategoryEnabled( category : name ) : bool
	{
		if ( category == 'steelsword' )
		{
			return enableSteelSwordInfusion;
		}
		if ( category == 'silversword' )
		{
			return enableSilverSwordInfusion;
		}
		if ( category == 'armor' || category == 'pants' || category == 'boots' || category == 'gloves' )
		{
			return enableArmorInfusion;
		}
		return false;
	}
}
