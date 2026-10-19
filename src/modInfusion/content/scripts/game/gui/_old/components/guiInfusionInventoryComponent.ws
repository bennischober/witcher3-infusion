/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion inventory grid component (M6)
/** 	Grid of the Infuse tab (extends the repair grid component). Two
/** 	phases (spec §9.1: the player selects both items):
/** 	  1. target phase: infusion-capable targets (damaged ones too -
/** 	     infusion includes the repair)
/** 	  2. sacrifice phase: the chosen target (section 0) + every valid
/** 	     sacrifice for it (section 1), each priced for that pair
/** 	New class in a new file — no vanilla file override.
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
		if ( infusionService && craftsman && infusionService.IsSupportedTarget( item ) )
		{
			infusable = infusionService.FindBestSacrifice( _inv, item, s, p, craftsman );
			// One line per item and refresh: only with debug logging on.
			if ( infusionService.GetPublicConfig().DebugLogging() )
			{
				if ( infusable )
				{
					LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " infusable (sacrifice: " + _inv.GetItemName( s ) + ", gap " + p.levelGap + ", fee " + p.laborFee + ", target value " + infusionService.GetPublicConfig().GetTargetValue( _inv, item ) + ")" );
				}
				else
				{
					LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " (L" + infusionService.ComputeItemLevel( _inv, item ) + ") not infusable here - " + infusionService.DescribeLastScan() );
				}
			}
		}

		_cacheIds.PushBack( item );
		_cacheInfusable.PushBack( infusable );
		_cacheSacrifices.PushBack( s );
		_cachePreviews.PushBack( p );

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

	// Only infusion targets (phase 1) or the target plus its valid
	// sacrifices (phase 2); no repair entries. Access modifier matches the
	// ancestor (protected) - the compiler rejects weaker overrides.
	protected function ShouldShowItem( item : SItemUniqueId ) : bool
	{
		var p : SInfusionPreview;

		if ( _sacrificePhase )
		{
			return item == _phaseTarget || GetSacrificeInfo( item, p );
		}
		return IsInfusable( item );
	}

	// Per-item price and cost row: phase 1 shows the fee and materials for
	// the best available sacrifice, phase 2 those of each exact pair. Flash
	// passes actionPrice back to the menu with the confirmation request.
	public function SetInventoryFlashObjectForItem( item : SItemUniqueId, out flashObject : CScriptedFlashObject ) : void
	{
		var s : SItemUniqueId;
		var p : SInfusionPreview;
		var missing : array<SItemParts>;

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
