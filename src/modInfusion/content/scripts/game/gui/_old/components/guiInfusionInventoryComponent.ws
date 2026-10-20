/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion tab item grid
/** 	Grid of the Infuse tab (extends the repair grid component). Two
/** 	phases (spec §9.1: the player selects both items):
/** 	  1. target phase: infusion-capable targets (damaged ones too -
/** 	     infusion includes the repair), plus targets this craftsman's
/** 	     specialization covers that can't be infused right now, disabled,
/** 	     with the reason in the tooltip (spec §9.3)
/** 	  2. sacrifice phase: the chosen target (section 0) + every valid
/** 	     sacrifice for it (section 1), each priced for that pair
/** 	New class; lives next to the vanilla grid components it extends
/** 	(game/gui/_old/components/). Design: docs/UI.md.
/***********************************************************************/

class W3GuiInfusionInventoryComponent extends W3GuiRepairInventoryComponent
{
	// Injected by the menu.
	public var infusionService : W3InfusionService;
	// The NPC the player is talking to. Every grid verdict is computed for
	// this craftsman, so the grid never lists an item the menu would then
	// refuse (which used to fall through to the vanilla repair flow and
	// charge the infusion fee as a repair price).
	public var craftsman : CGameplayEntity;

	// Per-refresh cache of infusion verdicts. The grid queries each item
	// several times per refresh (filter, price, action label, confirmation)
	// and each query is an inventory scan. The menu calls InvalidateCache()
	// before every full grid rebuild and after every inventory change.
	private var _cacheIds : array<SItemUniqueId>;
	private var _cacheInfusable : array<bool>;
	private var _cacheSacrifices : array<SItemUniqueId>;
	private var _cachePreviews : array<SInfusionPreview>;
	// Why a listed target can't be infused (IFE_Ok when it can, or when it
	// is not listed at all - see GetBlockReason).
	private var _cacheReasons : array<EInfusionError>;

	// Sacrifice phase: the target the player picked, and per-refresh cached
	// verdicts for each candidate sacrifice (target + candidate preview).
	private var _sacrificePhase : bool;
	private var _phaseTarget : SItemUniqueId;
	private var _sacIds : array<SItemUniqueId>;
	private var _sacValid : array<bool>;
	private var _sacPreviews : array<SInfusionPreview>;

	public function InvalidateCache() : void
	{
		_cacheIds.Clear();
		_cacheInfusable.Clear();
		_cacheSacrifices.Clear();
		_cachePreviews.Clear();
		_cacheReasons.Clear();
		_sacIds.Clear();
		_sacValid.Clear();
		_sacPreviews.Clear();
	}

	public function BeginSacrificePhase( target : SItemUniqueId ) : void
	{
		_sacrificePhase = true;
		_phaseTarget = target;
		InvalidateCache();
	}

	public function EndSacrificePhase() : void
	{
		_sacrificePhase = false;
		InvalidateCache();
	}

	public function IsInSacrificePhase() : bool
	{
		return _sacrificePhase;
	}

	public function GetPhaseTarget() : SItemUniqueId
	{
		return _phaseTarget;
	}

	// Sacrifice phase: true when the item is a valid sacrifice for the phase
	// target at this craftsman; returns the preview for that exact pair.
	public function GetSacrificeInfo( item : SItemUniqueId, out preview : SInfusionPreview ) : bool
	{
		var i : int;
		var valid : bool;
		var p : SInfusionPreview;

		for ( i = 0; i < _sacIds.Size(); i += 1 )
		{
			if ( _sacIds[i] == item )
			{
				preview = _sacPreviews[i];
				return _sacValid[i];
			}
		}

		valid = false;
		if ( _sacrificePhase && infusionService && craftsman && item != _phaseTarget
			&& _inv.GetItemCategory( item ) == _inv.GetItemCategory( _phaseTarget ) )
		{
			valid = infusionService.Preview( _phaseTarget, item, p, craftsman ) == IFE_Ok;
		}

		_sacIds.PushBack( item );
		_sacValid.PushBack( valid );
		_sacPreviews.PushBack( p );

		preview = p;
		return valid;
	}

	// True when the item can be infused by this craftsman right now; returns
	// the best sacrifice (highest level gap) and its preview. Cached.
	public function GetInfusionInfo( item : SItemUniqueId, out sacrificeId : SItemUniqueId, out preview : SInfusionPreview ) : bool
	{
		var i : int;
		var infusable : bool;
		var s : SItemUniqueId;
		var p : SInfusionPreview;
		var reason : EInfusionError;

		for ( i = 0; i < _cacheIds.Size(); i += 1 )
		{
			if ( _cacheIds[i] == item )
			{
				sacrificeId = _cacheSacrifices[i];
				preview = _cachePreviews[i];
				return _cacheInfusable[i];
			}
		}

		infusable = false;
		reason = IFE_Ok;
		if ( infusionService && craftsman && infusionService.IsSupportedTarget( item ) )
		{
			infusable = infusionService.FindBestSacrifice( _inv, item, s, p, craftsman );
			// Blocked targets are listed only within this craftsman's
			// specialization: every sword at an armorer would be noise.
			if ( !infusable && infusionService.IsCraftsmanSpecializedFor( craftsman, item ) )
			{
				reason = infusionService.GetBlockReason( _inv, item, craftsman );
			}
			// One line per item and refresh: only with debug logging on.
			if ( infusionService.GetPublicConfig().DebugLogging() )
			{
				if ( infusable )
				{
					LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " infusable (sacrifice: " + _inv.GetItemName( s ) + ", gap " + p.levelGap + ", fee " + p.laborFee + ", fee anchor " + infusionService.GetFeeAnchor( _inv, item, craftsman ) + ")" );
				}
				else
				{
					LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " (L" + infusionService.ComputeItemLevel( _inv, item ) + ") not infusable here - " + infusionService.DescribeLastScan() );
				}
			}
		}
		else if ( infusionService && craftsman && infusionService.IsExplainedExclusion( item )
			&& infusionService.IsCraftsmanSpecializedFor( craftsman, item ) )
		{
			// Excluded gear (quest, Aerondight, ...) is listed disabled with
			// its reason too (spec §14.2).
			reason = IFE_QuestItem;
		}

		_cacheIds.PushBack( item );
		_cacheInfusable.PushBack( infusable );
		_cacheSacrifices.PushBack( s );
		_cachePreviews.PushBack( p );
		_cacheReasons.PushBack( reason );

		sacrificeId = s;
		preview = p;
		return infusable;
	}

	public function IsInfusable( item : SItemUniqueId ) : bool
	{
		var s : SItemUniqueId;
		var p : SInfusionPreview;

		return GetInfusionInfo( item, s, p );
	}

	// Target phase: true when the item is listed as a disabled target;
	// returns why it can't be infused here.
	public function GetBlockReason( item : SItemUniqueId, out reason : EInfusionError ) : bool
	{
		var s : SItemUniqueId;
		var p : SInfusionPreview;
		var i : int;

		reason = IFE_Ok;
		if ( _sacrificePhase || GetInfusionInfo( item, s, p ) )
		{
			return false;
		}
		for ( i = 0; i < _cacheIds.Size(); i += 1 )
		{
			if ( _cacheIds[i] == item )
			{
				reason = _cacheReasons[i];
				break;
			}
		}
		return reason != IFE_Ok;
	}

	// Player text for a blocked target (tooltip warning line). The tier
	// reason names the tier this item needs, with the game's own tier name
	// (CraftsmanLevelToLocalizationKey, craftingTypes.ws).
	public function GetBlockReasonText( item : SItemUniqueId ) : string
	{
		var reason : EInfusionError;
		var quality : int;
		var required : int;

		if ( !GetBlockReason( item, reason ) )
		{
			return "";
		}
		switch ( reason )
		{
			case IFE_CraftsmanLevelTooLow:
				quality = RoundMath( CalculateAttributeValue( _inv.GetItemAttributeValue( item, 'quality' ) ) );
				required = infusionService.GetPublicConfig().GetRequiredCraftsmanLevel( quality );
				return GetLocStringByKeyExt( "panel_infusion_block_tier" ) + " "
					+ GetLocStringByKeyExt( CraftsmanLevelToLocalizationKey( (ECraftsmanLevel)required ) );
			case IFE_SacrificeNotHigher:
				return GetLocStringByKeyExt( "panel_infusion_block_no_higher" );
			case IFE_EquippedSacrifice:
				return GetLocStringByKeyExt( "panel_infusion_block_equipped" );
			case IFE_QuestItem:
				return GetLocStringByKeyExt( "panel_infusion_block_excluded" );
		}
		return InfusionErrorToLocString( reason );
	}

	// Sacrifice phase: how much of the recipe this sacrifice covers, for its
	// tooltip's warning line ("Covered by sacrifice: 7/18", in material
	// units). The info panel lists only what is left to pay; the popup has
	// the full list. Empty for the target and without a recipe.
	public function GetSacrificeCoverText( item : SItemUniqueId ) : string
	{
		var p : SInfusionPreview;
		var covered, total, i : int;

		if ( !_sacrificePhase || item == _phaseTarget || !GetSacrificeInfo( item, p ) )
		{
			return "";
		}
		covered = 0;
		for ( i = 0; i < p.covered.Size(); i += 1 )
		{
			covered += p.covered[i].quantity;
		}
		// recipe = covered + still to pay, per material
		total = covered;
		for ( i = 0; i < p.materials.Size(); i += 1 )
		{
			total += p.materials[i].quantity;
		}
		if ( total <= 0 )
		{
			return "";
		}
		// The warning line is red; this is information, not a warning, so it
		// overrides the colour (the field takes HTML). The red bar behind it
		// is a fixed frame of the tooltip SWF.
		return "<font color=\"#FFFFFF\">" + GetLocStringByKeyExt( "panel_infusion_recovered" )
			+ ": " + covered + "/" + total + "</font>";
	}

	// Phase 1: infusion targets plus blocked targets (disabled); phase 2:
	// the target plus its valid sacrifices. No repair entries. Access
	// modifier matches the ancestor (protected) - the compiler rejects
	// weaker overrides.
	protected function ShouldShowItem( item : SItemUniqueId ) : bool
	{
		var p : SInfusionPreview;

		var reason : EInfusionError;

		if ( _sacrificePhase )
		{
			return item == _phaseTarget || GetSacrificeInfo( item, p );
		}
		return IsInfusable( item ) || GetBlockReason( item, reason );
	}

	// Per-item price and cost row: phase 1 shows the fee and materials for
	// the best available sacrifice, phase 2 those of each exact pair. Flash
	// passes actionPrice back to the menu with the confirmation request.
	public function SetInventoryFlashObjectForItem( item : SItemUniqueId, out flashObject : CScriptedFlashObject ) : void
	{
		var s : SItemUniqueId;
		var p : SInfusionPreview;
		var missing : array<SItemParts>;
		var reason : EInfusionError;

		super.SetInventoryFlashObjectForItem( item, flashObject );

		// Items without durability (e.g. casual clothes) get a placeholder
		// durability of 1 from the base component, which the repair panel
		// renders as "1 %" (ItemRepairInfo.as). The vanilla repair grid never
		// lists such items; ours does (as infusion targets). 0 hides the line.
		if ( !_inv.HasItemDurability( item ) )
		{
			flashObject.SetMemberFlashNumber( "durability", 0 );
		}

		if ( _sacrificePhase )
		{
			// Section 0 ("Target") holds the picked target - activating it
			// cancels the selection; section 1 ("Sacrifice") the candidates,
			// each priced for this exact pair.
			if ( item == _phaseTarget )
			{
				flashObject.SetMemberFlashInt( "sectionId", 0 );
				flashObject.SetMemberFlashInt( "actionPrice", 0 );
				flashObject.SetMemberFlashArray( "partList", flashObject.CreateFlashArray() );
			}
			else
			{
				flashObject.SetMemberFlashInt( "sectionId", 1 );
				if ( GetSacrificeInfo( item, p ) )
				{
					flashObject.SetMemberFlashInt( "actionPrice", p.laborFee );
					SetCostPartList( flashObject, p.materials );
					// Like a disabled craft button: a sacrifice whose
					// remaining materials are missing cannot be activated.
					// Flash then greys the panel, hides the E button,
					// plays the denied sound and shows the page's warning
					// line (text set by the menu) - all selection-driven.
					if ( infusionService.GetMissingMaterials( _inv, p.materials, missing ) )
					{
						flashObject.SetMemberFlashBool( "disableAction", true );
					}
				}
			}
			return;
		}

		if ( GetInfusionInfo( item, s, p ) )
		{
			flashObject.SetMemberFlashInt( "actionPrice", p.laborFee );
			SetCostPartList( flashObject, p.materials );
		}
		else if ( GetBlockReason( item, reason ) )
		{
			// Listed but not infusable here: greyed panel, no E button, the
			// page's warning line points to the tooltip, which names the
			// reason (CR4BlacksmithMenu.ShowItemTooltip wrapper).
			flashObject.SetMemberFlashInt( "actionPrice", 0 );
			flashObject.SetMemberFlashArray( "partList", flashObject.CreateFlashArray() );
			flashObject.SetMemberFlashBool( "disableAction", true );
		}
	}

	// Infuse tab: the materials still to pay (after the salvage discount),
	// shown like the crafting menu's ingredient row. The tab renders Flash's
	// Disassemble page, whose info panel lists item.partList as icon slots
	// (ItemDisassembleInfo.as, max 5; name/iconPath/quantity as in
	// guiDisassembleInventoryComponent.ws). The slot renders quantity as
	// htmlText (InventorySlotOverlay.SetQuantity), so it carries a crafting-
	// style "have/need" in green or red.
	private function SetCostPartList( out flashObject : CScriptedFlashObject, parts : array<SItemParts> ) : void
	{
		var list : CScriptedFlashArray;
		var partData : CScriptedFlashObject;
		var i : int;
		var have : int;
		var color : string;

		list = flashObject.CreateFlashArray();
		for ( i = 0; i < parts.Size(); i += 1 )
		{
			if ( parts[i].quantity <= 0 )
			{
				continue;
			}
			have = _inv.GetItemQuantityByName( parts[i].itemName );
			if ( have >= parts[i].quantity )
			{
				color = "#57D338";
			}
			else
			{
				color = "#EC1212";
			}
			partData = flashObject.CreateFlashObject();
			partData.SetMemberFlashString( "name", GetLocStringByKeyExt( _inv.GetItemLocalizedNameByName( parts[i].itemName ) ) );
			partData.SetMemberFlashString( "iconPath", _inv.GetItemIconPathByName( parts[i].itemName ) );
			partData.SetMemberFlashString( "quantity", "<font color='" + color + "'>" + have + "/" + parts[i].quantity + "</font>" );
			list.PushBackFlashObject( partData );
		}
		flashObject.SetMemberFlashArray( "partList", list );
	}
}
