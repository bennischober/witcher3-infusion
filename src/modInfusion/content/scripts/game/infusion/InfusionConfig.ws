/***********************************************************************/
/** 	Witcher Gear Infusion — configuration
/** 	All balance knobs and tuning values in one place. Values come from the
/** 	in-game settings menu (Options -> Mods -> Witcher Gear Infusion,
/** 	user_config_matrix XML) with script defaults as fallback when a var is
/** 	not present (e.g. menu not installed / older saves).
/**
/** 	Spec: INFUSION_SPEC.md §6 (fees), §7 (efficiency), §10 (configuration),
/** 	      §8.2 (eligibility thresholds)
/***********************************************************************/

class W3InfusionConfig extends IScriptable
{
	// Cached raw values (refreshed on ReadAll; the menu only writes
	// user.settings on apply, so caching per session is fine).
	private var cacheEnableInfusion : bool;
	private var cacheSteel, cacheSilver, cacheArmor : bool;
	private var cacheBaseFee : int;
	private var cacheSalvageEnabled : bool;
	private var cacheSalvageMult : float;
	private var cacheRestoreDurability : bool;
	private var cacheGapDivisor : float;
	private var cacheGapMaxMult : float;
	private var cacheWitcherTierReq : int;
	private var cacheLoaded : bool;

	// ---------------------------------------------------------------------
	// Settings-system access
	// ---------------------------------------------------------------------

	// Reads one string var from the mod's settings group; "" when absent.
	private function GetVar( varName : name ) : string
	{
		return theGame.GetInGameConfigWrapper().GetVarValue( 'modInfusion', varName );
	}

	// Reads one bool var ("1"/"true"/"0"/"false"); fallback when absent.
	private function GetVarBool( varName : name, fallback : bool ) : bool
	{
		var v : string;

		v = GetVar( varName );
		if ( v == "" )
		{
			return fallback;
		}
		return v == "1" || v == "true";
	}

	// Reads one int var; fallback when absent or unparseable.
	private function GetVarInt( varName : name, fallback : int ) : int
	{
		var v : string;

		v = GetVar( varName );
		if ( v == "" )
		{
			return fallback;
		}
		return StringToInt( v, fallback );
	}

	// Reads one float var scaled by 100 (menu sliders are integer percent);
	// fallback when absent.
	private function GetVarFloatPercent( varName : name, fallback : float ) : float
	{
		var v : string;

		v = GetVar( varName );
		if ( v == "" )
		{
			return fallback;
		}
		return StringToInt( v, 100 ) / 100.0f;
	}

	// ---------------------------------------------------------------------
	// Loading
	// ---------------------------------------------------------------------

	// Refreshes the cache from the settings system. Safe to call repeatedly;
	// cheap enough for on-demand use and required after menu changes.
	public function ReadAll() : void
	{
		cacheEnableInfusion = GetVarBool( 'EnableInfusion', true );

		cacheSteel = GetVarBool( 'EnableSteelSwordInfusion', true );
		cacheSilver = GetVarBool( 'EnableSilverSwordInfusion', false );
		cacheArmor = GetVarBool( 'EnableArmorInfusion', false );

		cacheBaseFee = SanitizeInt( GetVarInt( 'BaseLaborFee', 50 ), 0, 100000 );
		cacheSalvageEnabled = GetVarBool( 'EnableSalvage', true );
		cacheSalvageMult = GetVarFloatPercent( 'SalvageYieldMultiplier', 1.0f );
		cacheRestoreDurability = GetVarBool( 'RestoreTargetDurability', true );

		cacheGapDivisor = SanitizeFloat( GetVarFloatPercent( 'GapCostDivisor', 10.0f ), 1.0f, 50.0f, 10.0f );
		cacheGapMaxMult = GetVarFloatPercent( 'GapCostMaxMult', 3.0f );

		cacheWitcherTierReq = SanitizeInt( GetVarInt( 'CraftsmanLevelForWitcherGear', 3 ), 1, 4 );
		cacheLoaded = true;
	}

	// ---------------------------------------------------------------------
	// Feature flags (spec §10)
	// ---------------------------------------------------------------------

	public function EnableInfusion() : bool
	{
		return cacheEnableInfusion;
	}

	// Category feature gate.
	public function IsCategoryEnabled( category : name ) : bool
	{
		if ( category == 'steelsword' )
		{
			return cacheSteel;
		}
		if ( category == 'silversword' )
		{
			return cacheSilver;
		}
		if ( category == 'armor' || category == 'pants' || category == 'boots' || category == 'gloves' )
		{
			return cacheArmor;
		}
		return false;
	}

	// ============================ fees (§6) ==============================

	public function BaseLaborFee() : int
	{
		return cacheBaseFee;
	}

	// Craftsman multiplier by tier enum ordinal (1 = Journeyman ... 4 = Arch Master).
	// Spec §6.2 starting values: 1.0 / 1.5 / 2.0 / 2.5.
	public function GetCraftsmanMultiplier( craftsmanLevel : int ) : float
	{
		if ( craftsmanLevel <= 1 )
		{
			return 1.0f;
		}
		if ( craftsmanLevel == 2 )
		{
			return 1.5f;
		}
		if ( craftsmanLevel == 3 )
		{
			return 2.0f;
		}
		return 2.5f;
	}

	// Target tier multiplier by item quality (1..5). Spec-derived starting values.
	public function GetTargetTierMultiplier( quality : int ) : float
	{
		if ( quality <= 1 )
		{
			return 1.0f;
		}
		if ( quality == 2 )
		{
			return 1.2f;
		}
		if ( quality == 3 )
		{
			return 1.5f;
		}
		if ( quality == 4 )
		{
			return 2.0f;
		}
		return 3.0f;
	}

	// Level-gap multiplier (spec §7.1): 1 + gap/divisor, capped.
	public function GetLevelGapMultiplier( levelGap : int ) : float
	{
		var mult : float;

		if ( levelGap <= 0 )
		{
			return 1.0f;
		}

		mult = 1.0f + levelGap / cacheGapDivisor;
		if ( mult > cacheGapMaxMult )
		{
			mult = cacheGapMaxMult;
		}
		return mult;
	}

	// ============================ salvage (§5) ============================

	public function SalvageEnabled() : bool
	{
		return cacheSalvageEnabled;
	}

	public function SalvageYieldMultiplier() : float
	{
		return cacheSalvageMult;
	}

	// ========================== durability (§3.4) =========================

	public function RestoreTargetDurability() : bool
	{
		return cacheRestoreDurability;
	}

	// ========================= eligibility (§8.2) =========================

	// Craftsman tier requirement for a target quality.
	public function GetRequiredCraftsmanLevel( quality : int ) : int
	{
		if ( quality >= 5 )
		{
			return cacheWitcherTierReq;
		}
		if ( quality == 4 )
		{
			return 2;   // relic: master
		}
		return 1;       // ordinary: journeyman
	}

	// ============================ validation ===============================

	// §10 safety rules: clamp to sane bounds.
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

	private function SanitizeFloat( value : float, minValue : float, maxValue : float, fallback : float ) : float
	{
		if ( value < minValue || value > maxValue )
		{
			return fallback;
		}
		return value;
	}
}
