/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion inventory grid component (M6)
/** 	Extends the repair grid component: shows infusion-capable items
/** 	(including undamaged ones) and displays the infusion fee per item.
/** 	New class in a new file — no vanilla file override.
/***********************************************************************/

class W3GuiInfusionInventoryComponent extends W3GuiRepairInventoryComponent
{
	// Injected by the menu (InfusionMenuController).
	public var infusionService : W3InfusionService;

	private function CanInfuseHere( item : SItemUniqueId ) : bool
	{
		var p : SInfusionPreview;
		var ids : array<SItemUniqueId>;
		var i : int;
		var sacrificeFound : bool;

		if ( !infusionService )
		{
			LogChannel( 'Infusion', "grid: item not shown (no service)" );
			return false;
		}

		// Quick gates (cheap first): category support.
		if ( !infusionService.IsSupportedTarget( item ) )
		{
			LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " not a supported target (category/exclusion/config)" );
			return false;
		}

		// Any valid sacrifice for this target in the player inventory?
		_inv.GetAllItems( ids );
		for ( i = 0; i < ids.Size(); i += 1 )
		{
			if ( ids[i] == item )
			{
				continue;
			}
			if ( infusionService.Preview( item, ids[i], p ) == IFE_Ok )
			{
				LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " infusable (sacrifice: " + _inv.GetItemName( ids[i] ) + ", gap " + p.levelGap + ")" );
				return true;
			}
		}
		LogChannel( 'Infusion', "grid: " + _inv.GetItemName( item ) + " has no valid sacrifice (" + ids.Size() + " candidates scanned)" );
		return false;
	}

	// Show infusion-capable items (damaged or not) — unlike repair, which
	// only lists damaged equipment. Access modifier matches the ancestor
	// (protected) — the compiler rejects weaker overrides.
	// Unified service grid: shows repairable items (super's filter: damaged
	// equipment) AND infusion-capable items (even at full durability). The
	// per-item action label (Repair vs Infuse) and price distinguish them.
	protected function ShouldShowItem( item : SItemUniqueId ) : bool
	{
		if ( super.ShouldShowItem( item ) )
		{
			return true;   // damaged: repairable
		}
		return CanInfuseHere( item );   // undamaged but infusable
	}

	// Per-item price: repairable items keep the vanilla repair cost (from
	// super); infusion targets show the infusion labor fee for the best
	// available sacrifice.
	public function SetInventoryFlashObjectForItem( item : SItemUniqueId, out flashObject : CScriptedFlashObject ) : void
	{
		var p : SInfusionPreview;
		var ids : array<SItemUniqueId>;
		var i : int;
		var bestGap : int;
		var bestFee : int;
		var isRepairable : bool;

		super.SetInventoryFlashObjectForItem( item, flashObject );

		// Repairable? Then super already set the repair cost — leave it.
		isRepairable = _inv.HasItemDurability( item )
			&& _inv.GetItemDurability( item ) < _inv.GetItemMaxDurability( item );

		if ( isRepairable || !infusionService )
		{
			return;
		}

		// Infusion target: show the fee for the best available sacrifice.
		_inv.GetAllItems( ids );
		bestGap = 0;
		for ( i = 0; i < ids.Size(); i += 1 )
		{
			if ( ids[i] == item )
			{
				continue;
			}
			if ( infusionService.Preview( item, ids[i], p ) == IFE_Ok && p.levelGap > bestGap )
			{
				bestGap = p.levelGap;
				bestFee = p.laborFee;
			}
		}
		if ( bestGap > 0 )
		{
			flashObject.SetMemberFlashInt( "actionPrice", bestFee );
		}
	}
}
