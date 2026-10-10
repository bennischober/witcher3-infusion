/***********************************************************************/
/** 	Witcher Gear Infusion — Milestone 2 prototype
/** 	Type definitions shared by the infusion system.
/**
/** 	Spec: INFUSION_SPEC.md §3 (core rules), §12 (architecture)
/** 	Discovery: docs/TECHNICAL_DISCOVERY.md §3 (level derivation), §10 (architecture)
/***********************************************************************/

enum EInfusionError
{
	IFE_Ok,
	IFE_InvalidItemId,        // target or sacrifice is not a valid inventory item
	IFE_UnsupportedCategory,  // item category has no infusion support (not a leveled equipment category)
	IFE_DisabledCategory,     // category supported by code but disabled in configuration (M2/M3: steel only)
	IFE_CategoryMismatch,     // target and sacrifice categories differ (spec §3.3)
	IFE_SameItemInstance,     // the same inventory instance was passed as target and sacrifice (spec §5.5)
	IFE_QuestItem,            // quest items must never be consumed (spec §14.2)
	IFE_EquippedSacrifice,    // sacrifice is currently equipped; unequip first
	IFE_SacrificeNotHigher,   // sacrifice level <= target level (spec §3.2)
	IFE_LevelMismatch,        // post-application verification failed; transaction aborted
	IFE_NotEnoughCrowns,      // player cannot pay the labor fee (spec §6)
	IFE_NotEnoughMaterials    // player lacks remaining materials after the salvage discount (spec §5.4)
}

// One entry per supported item category. Values mirror the vanilla autogen system
// (r4data/gameplay/items/def_item_weapons_relic_autogen.xml) and the per-level stat
// steps in theGame.params.GetItemLevel (gameParams.ws:917).
//   steelsword: autogen_fixed_steel_dmg adds +8 SlashingDamage == one level (stat_add = 8)
//   silversword: autogen_fixed_silver_dmg adds +10 SilverDamage == one level (stat_add = 10)
//   armor: autogen_fixed_armor_armor adds +5 armor == one level (stat_add = 5)
//   pants/boots: autogen_fixed_pants_armor adds +2 == one level (stat_add = 2)
//   gloves: autogen_fixed_gloves_armor adds +2 == one level (stat_add = 2)
struct SInfusionCategoryData
{
	var category : name;        // item category as returned by GetItemCategory
	var stepAbility : name;     // crafted ability added once per level
	var stepValue : int;        // stat delta of one step ability == one level of stats
	var attributeName : name;   // attribute the step ability modifies
}

struct SInfusionPreview
{
	var errorCode : EInfusionError;

	var targetId : SItemUniqueId;
	var sacrificeId : SItemUniqueId;
	var targetCategory : name;

	var targetLevel : int;      // computed current level of the target
	var sacrificeLevel : int;   // computed current level of the sacrifice
	var levelGap : int;         // sacrificeLevel - targetLevel (> 0 required)
	var newLevel : int;         // projected target level after infusion

	var laborFee : int;         // crowns charged for the service (M3: flat formula)
	var stepsToAdd : int;       // number of step abilities that will be added to the target
	var stepAbility : name;     // which ability will be used

	// Material model (spec §5.4): AdditionalRequired = max(0, RecipeRequired - Salvaged)
	var materials : array<SItemParts>;   // remaining requirements AFTER the salvage discount
	var salvaged : array<SItemParts>;    // recovered from the sacrifice (excess discarded, §5.4)
}

function InfusionErrorToString( err : EInfusionError ) : string
{
	switch ( err )
	{
		case IFE_Ok:               return "OK";
		case IFE_InvalidItemId:    return "invalid item";
		case IFE_UnsupportedCategory: return "item category cannot be infused";
		case IFE_DisabledCategory: return "infusion disabled for this category";
		case IFE_CategoryMismatch: return "target and sacrifice are incompatible";
		case IFE_SameItemInstance: return "target and sacrifice must be different items";
		case IFE_QuestItem:        return "quest items cannot be used";
		case IFE_EquippedSacrifice: return "sacrifice item is equipped";
		case IFE_SacrificeNotHigher: return "sacrifice must be higher level than target";
		case IFE_LevelMismatch:    return "internal level verification failed (aborted, nothing consumed)";
		case IFE_NotEnoughCrowns:  return "not enough crowns";
		case IFE_NotEnoughMaterials: return "missing required crafting materials";
	}
	return "unknown error";
}
