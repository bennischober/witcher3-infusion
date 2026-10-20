/***********************************************************************/
/** 	Witcher Gear Infusion — balance report (DEV ONLY, never shipped)
/** 	Spec §6.4: are the costs still meaningful in long NG+ runs? Logs
/** 	what an infusion costs at high levels - the fee at each craftsman
/** 	tier, the materials to buy and what the salvage covers - for real
/** 	items raised to L30/60/100/150, so the numbers can be judged without
/** 	a long playthrough. Preview only: nothing is charged, the spawned
/** 	items are removed again. The sacrifice is a copy of the target
/** 	raised by the gap.
/***********************************************************************/

class W3InfusionBalanceReport extends W3InfusionScenarioRunner
{
	public var rows : int;
	public var missingCraftsmen : int;   // tiers without a ready craftsman (run again)

	// Index 0..2 = journeyman, master, grandmaster.
	private var smiths : array<CGameplayEntity>;
	private var armorers : array<CGameplayEntity>;

	public function Write()
	{
		var levels : array<int>;
		var gaps : array<int>;
		var i, j : int;

		levels.PushBack( 30 );
		levels.PushBack( 60 );
		levels.PushBack( 100 );
		levels.PushBack( 150 );
		gaps.PushBack( 5 );
		gaps.PushBack( 20 );
		rows = 0;
		PrepareCraftsmen();

		LogChannel( 'Infusion', "balance: player level " + GetWitcherPlayer().GetLevel() + ", crowns " + inv.GetMoney()
			+ " | fees in crowns per craftsman tier | sacrifice = a copy of the target raised by the gap" );
		for ( i = 0; i < levels.Size(); i += 1 )
		{
			for ( j = 0; j < gaps.Size(); j += 1 )
			{
				Row( 'Light armor 01', true, 0, levels[i], gaps[j] );       // ordinary armor
				Row( 'Novigraadan sword 1', false, 0, levels[i], gaps[j] ); // ordinary steel sword
				Row( 'Abarad', false, 1, levels[i], gaps[j] );              // relic: master and up
				Row( 'Bear Armor 1', true, 2, levels[i], gaps[j] );         // Witcher gear: grandmaster
			}
		}
	}

	// One craftsman per type and tier for the whole report. A fresh spawn
	// may not be ready on the first run (GetCraftsmanAt returns NULL).
	private function PrepareCraftsmen()
	{
		var tiers : array<ECraftsmanLevel>;
		var i : int;

		tiers.PushBack( ECL_Journeyman );
		tiers.PushBack( ECL_Master );
		tiers.PushBack( ECL_Grand_Master );
		missingCraftsmen = 0;
		for ( i = 0; i < tiers.Size(); i += 1 )
		{
			smiths.PushBack( GetCraftsmanAt( false, tiers[i] ) );
			armorers.PushBack( GetCraftsmanAt( true, tiers[i] ) );
			if ( !smiths[i] )
			{
				missingCraftsmen += 1;
			}
			if ( !armorers[i] )
			{
				missingCraftsmen += 1;
			}
		}
	}

	// lowestTier: index of the first tier allowed to infuse this item.
	private function Row( itemName : name, armorer : bool, lowestTier : int, targetLevel : int, gap : int )
	{
		var t, s : SItemUniqueId;
		var craftsman : CGameplayEntity;
		var p : SInfusionPreview;
		var err : EInfusionError;
		var tierNames : array<string>;
		var fees, line, materials, covered : string;
		var anchor : float;
		var priced : bool;
		var i : int;

		if ( !Spawn( itemName, t ) || !Spawn( itemName, s ) || !BoostTo( t, targetLevel ) || !BoostTo( s, Level( t ) + gap ) )
		{
			LogChannel( 'Infusion', "balance: " + itemName + " L" + targetLevel + " gap " + gap + ": " + detail );
			RemoveScenarioItems();
			return;
		}

		tierNames.PushBack( "journeyman" );
		tierNames.PushBack( "master" );
		tierNames.PushBack( "grandmaster" );
		fees = "";
		priced = false;
		for ( i = lowestTier; i < tierNames.Size(); i += 1 )
		{
			if ( armorer )
			{
				craftsman = armorers[i];
			}
			else
			{
				craftsman = smiths[i];
			}
			if ( fees != "" )
			{
				fees = fees + ", ";
			}
			fees = fees + tierNames[i] + " ";
			if ( !craftsman )
			{
				fees = fees + "(no craftsman)";
				continue;
			}
			err = svc.Preview( t, s, p, craftsman );
			if ( err != IFE_Ok )
			{
				fees = fees + "(" + InfusionErrorToString( err ) + ")";
				continue;
			}
			fees = fees + p.laborFee;
			if ( !priced )
			{
				// Materials don't depend on the craftsman; the anchor is the
				// lowest tier's (regional, see TECHNICAL_DISCOVERY.md §6).
				priced = true;
				anchor = svc.GetFeeAnchor( inv, t, craftsman );
				materials = Parts( p.materials );
				covered = Parts( p.covered );
			}
		}

		line = "balance: " + itemName + " L" + Level( t ) + " -> L" + Level( s ) + " | fee " + fees;
		if ( priced )
		{
			line = line + " | anchor " + RoundMath( anchor )
				+ " | sells for: target " + inv.GetItemPriceModified( t, true ) + ", sacrifice " + inv.GetItemPriceModified( s, true )
				+ " | materials to buy: " + materials + " | covered by salvage: " + covered;
		}
		LogChannel( 'Infusion', line );
		rows += 1;
		RemoveScenarioItems();
	}

	private function Parts( parts : array<SItemParts> ) : string
	{
		var text : string;
		var i : int;

		text = "";
		for ( i = 0; i < parts.Size(); i += 1 )
		{
			if ( parts[i].quantity <= 0 )
			{
				continue;
			}
			if ( text != "" )
			{
				text = text + ", ";
			}
			text = text + parts[i].itemName + " x" + parts[i].quantity;
		}
		if ( text == "" )
		{
			text = "none";
		}
		return text;
	}
}

function InfusionBalanceReport()
{
	var report : W3InfusionBalanceReport;
	var msg : string;

	report = new W3InfusionBalanceReport in theGame;
	report.Init();
	report.Write();
	msg = "balance report: " + report.rows + " rows written to the log";
	if ( report.missingCraftsmen > 0 )
	{
		msg += " - " + report.missingCraftsmen + " craftsmen were just spawned, run it again for their fees";
	}
	LogChannel( 'Infusion', msg );
	theGame.GetGuiManager().ShowNotification( msg, 9.0 );
}
