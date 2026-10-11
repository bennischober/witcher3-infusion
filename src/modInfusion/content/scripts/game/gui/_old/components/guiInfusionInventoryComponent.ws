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
			return false;
		}

		// Quick gates (cheap first): category support.
		if ( !infusionService.IsSupportedTarget( item ) )
		{
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
				sacrificeFound = true;
				break;
			}
		}
		return sacrificeFound;
	}

	// Show infusion-capable items (damaged or not) — unlike repair, which
	// only lists damaged equipment. Access modifier matches the ancestor
	// (protected) — the compiler rejects weaker overrides.
	protected function ShouldShowItem( item : SItemUniqueId ) : bool
	{
		if ( !super.ShouldShowItem( item ) )
		{
			return false;
		}
		return CanInfuseHere( item );
	}

	// The grid item's action price shows the infusion labor fee.
	public function SetInventoryFlashObjectForItem( item : SItemUniqueId, out flashObject : CScriptedFlashObject ) : void
	{
		var p : SInfusionPreview;
		var ids : array<SItemUniqueId>;
		var i : int;
		var bestGap : int;
		var bestFee : int;

		super.SetInventoryFlashObjectForItem( item, flashObject );

		if ( infusionService )
		{
			// Show the fee for the best available sacrifice.
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
			flashObject.SetMemberFlashInt( "actionPrice", bestFee );
		}
	}
}
