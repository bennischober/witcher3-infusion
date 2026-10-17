/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion inventory grid component (M6)
/** 	Extends the repair grid component. Two phases (spec §9.1: the
/** 	player selects both items):
/** 	  1. target phase: repairable items + infusion-capable targets
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

	// Infuse-tab mode (tab prototype): only infusion targets are listed,
	// damaged ones included (infusion includes the repair); no repair entries.
	private var _infuseOnly : bool;

	public function SetInfuseOnly( value : bool ) : void
	{
		_infuseOnly = value;
		InvalidateCache();
	}

	public function IsInfuseOnly() : bool
	{
		return _infuseOnly;
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
			if ( infusable )
			{
				LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " infusable (sacrifice: " + _inv.GetItemName( s ) + ", gap " + p.levelGap + ", fee " + p.laborFee + ")" );
			}
			else
			{
				LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " (L" + infusionService.ComputeItemLevel( _inv, item ) + ") not infusable here - " + infusionService.DescribeLastScan() );
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

	// Damaged items keep the vanilla repair action (repair first, then
	// infuse); the infusion action applies to undamaged items only.
	public function IsDamaged( item : SItemUniqueId ) : bool
	{
		return _inv.HasItemDurability( item )
			&& _inv.GetItemDurability( item ) < _inv.GetItemMaxDurability( item );
	}

	// Unified service grid: shows repairable items (super's filter: damaged
	// equipment) AND infusion-capable items (even at full durability).
	// Access modifier matches the ancestor (protected) — the compiler
	// rejects weaker overrides.
	protected function ShouldShowItem( item : SItemUniqueId ) : bool
	{
		var p : SInfusionPreview;

		if ( _sacrificePhase )
		{
			return item == _phaseTarget || GetSacrificeInfo( item, p );
		}
		if ( _infuseOnly )
		{
			return IsInfusable( item );
		}
		if ( super.ShouldShowItem( item ) )
		{
			return true;   // damaged: repairable
		}
		return IsInfusable( item );   // undamaged but infusable
	}

	// Per-item price: repairable items keep the vanilla repair cost (from
	// super); infusion targets show the infusion labor fee for the best
	// available sacrifice. Flash passes actionPrice back to the menu with
	// the confirmation request.
	public function SetInventoryFlashObjectForItem( item : SItemUniqueId, out flashObject : CScriptedFlashObject ) : void
	{
		var s : SItemUniqueId;
		var p : SInfusionPreview;

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
			}
			else
			{
				flashObject.SetMemberFlashInt( "sectionId", 1 );
				if ( GetSacrificeInfo( item, p ) )
				{
					flashObject.SetMemberFlashInt( "actionPrice", p.laborFee );
				}
			}
			return;
		}

		if ( ( _infuseOnly || !IsDamaged( item ) ) && GetInfusionInfo( item, s, p ) )
		{
			flashObject.SetMemberFlashInt( "actionPrice", p.laborFee );
		}
	}
}
