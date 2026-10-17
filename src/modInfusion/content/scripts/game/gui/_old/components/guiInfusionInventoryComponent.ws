/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion inventory grid component (M6)
/** 	Extends the repair grid component: shows infusion-capable items
/** 	(including undamaged ones) and displays the infusion fee per item.
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

	public function InvalidateCache() : void
	{
		_cacheIds.Clear();
		_cacheInfusable.Clear();
		_cacheSacrifices.Clear();
		_cachePreviews.Clear();
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

		if ( !IsDamaged( item ) && GetInfusionInfo( item, s, p ) )
		{
			flashObject.SetMemberFlashInt( "actionPrice", p.laborFee );
		}
	}
}
