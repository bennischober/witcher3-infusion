/***********************************************************************/
/** 	Witcher Gear Infusion — shared types
/** 	Error codes, category data, the preview/transaction record and the
/** 	error messages (log text and localized player text).
/**
/** 	Spec: INFUSION_SPEC.md §3 (core rules), §9.3 (messages), §12
/** 	Engine background: docs/TECHNICAL_DISCOVERY.md §3 (item levels)
/***********************************************************************/

enum EInfusionError
{
	IFE_Ok,
	IFE_InvalidItemId,        // target or sacrifice is not a valid inventory item
	IFE_UnsupportedCategory,  // item category has no infusion support (not a leveled equipment category)
	IFE_DisabledCategory,     // infusion or the category disabled in the configuration
	IFE_CategoryMismatch,     // target and sacrifice categories differ (spec §3.3)
	IFE_SameItemInstance,     // the same inventory instance was passed as target and sacrifice (spec §5.5)
	IFE_QuestItem,            // excluded item: quest, hidden/body, Aerondight, merchant range (spec §14.2)
	IFE_EquippedSacrifice,    // sacrifice is currently equipped; unequip first
	IFE_SacrificeNotHigher,   // sacrifice level <= target level (spec §3.2)
	IFE_LevelMismatch,        // post-application verification failed; transaction aborted
	IFE_NotEnoughCrowns,      // player cannot pay the labor fee (spec §6)
	IFE_NotEnoughMaterials,   // player lacks remaining materials after the salvage discount (spec §5.4)
	IFE_NoCraftsman,          // no craftsman context and debug bypass is off (spec §8.1)
	IFE_WrongCraftsmanType,   // craftsman specialization does not match the target category (spec §8.2)
	IFE_CraftsmanLevelTooLow, // craftsman tier insufficient for the target's tier (spec §8.2)
	IFE_NoSacrifice           // no other item of the target's category in the inventory
}

// One entry per supported item category: the vanilla autogen ability that
// adds exactly one level of the item's stats (gameParams.ws GetItemLevel
// steps: steel +8 SlashingDamage, silver +10 SilverDamage, armor +5,
// pants/boots/gloves +2).
struct SInfusionCategoryData
{
	var category : name;        // item category as returned by GetItemCategory
	var stepAbility : name;     // crafted ability added once per level
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

	var laborFee : int;         // crowns charged for the service (spec §6)
	var stepsToAdd : int;       // number of step abilities that will be added to the target
	var stepAbility : name;     // which ability will be used

	// Material model (spec §5.4): AdditionalRequired = max(0, RecipeRequired - Salvaged)
	var materials : array<SItemParts>;   // remaining requirements AFTER the salvage discount
	var salvaged : array<SItemParts>;    // recovered from the sacrifice (excess discarded, §5.4)
	var covered : array<SItemParts>;     // part of the salvage that actually reduces the recipe
	                                     // (recipe materials only, capped at the recipe amount)
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
		case IFE_NoCraftsman:      return "no craftsman available";
		case IFE_WrongCraftsmanType: return "this craftsman cannot infuse this equipment";
		case IFE_CraftsmanLevelTooLow: return "this craftsman is not qualified for this equipment";
		case IFE_NoSacrifice:      return "no other item of this category";
	}
	return "unknown error";
}

// Player-facing message for a rejection (spec §9.3), localized through the
// mod's w3strings (tools/strings-sources). InfusionErrorToString stays the
// English log text.
function InfusionErrorToLocString( err : EInfusionError ) : string
{
	switch ( err )
	{
		case IFE_InvalidItemId:       return GetLocStringByKeyExt( "panel_infusion_err_unavailable" );
		case IFE_UnsupportedCategory: return GetLocStringByKeyExt( "panel_infusion_err_unsupported" );
		case IFE_DisabledCategory:    return GetLocStringByKeyExt( "panel_infusion_err_disabled" );
		case IFE_CategoryMismatch:    return GetLocStringByKeyExt( "panel_infusion_err_incompatible" );
		case IFE_SameItemInstance:    return GetLocStringByKeyExt( "panel_infusion_err_same_item" );
		case IFE_QuestItem:           return GetLocStringByKeyExt( "panel_infusion_err_excluded" );
		case IFE_EquippedSacrifice:   return GetLocStringByKeyExt( "panel_infusion_err_equipped" );
		case IFE_SacrificeNotHigher:  return GetLocStringByKeyExt( "panel_infusion_err_level" );
		case IFE_LevelMismatch:       return GetLocStringByKeyExt( "panel_infusion_err_aborted" );
		case IFE_NotEnoughCrowns:     return GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" );
		case IFE_NotEnoughMaterials:  return GetLocStringByKeyExt( "panel_infusion_missing" );
		case IFE_NoCraftsman:         return GetLocStringByKeyExt( "panel_infusion_err_no_craftsman" );
		case IFE_WrongCraftsmanType:  return GetLocStringByKeyExt( "panel_infusion_err_craftsman_type" );
		case IFE_CraftsmanLevelTooLow: return GetLocStringByKeyExt( "panel_infusion_err_craftsman_level" );
		case IFE_NoSacrifice:         return GetLocStringByKeyExt( "panel_infusion_block_no_candidates" );
	}
	return InfusionErrorToString( err );
}
