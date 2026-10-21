/***********************************************************************/
/** 	Witcher Gear Infusion — infusion confirmation popup (spec §9.5)
/** 	Moved out of the former blacksmithMenu.ws override (new class, no
/** 	vanilla code touched). Opened by CR4BlacksmithMenu.InfusionStartFlow
/** 	(InfusionBlacksmithMenu.ws).
/***********************************************************************/

// Reuses the vanilla PriceConfirmationPopup layout (title, text, price) and
// adds the full transaction summary as the message text: target, sacrifice,
// level change, recovered materials, remaining requirements, and the note
// that the sacrifice is permanently consumed.
class InfusionConfirmationPopupData extends ConfirmationPopupData
{
	public var menuRef : CR4BlacksmithMenu;
	public var targetId : SItemUniqueId;
	public var sacrificeId : SItemUniqueId;
	public var preview : SInfusionPreview;

	private var m_Price : float;

	public function SetPrice( value : float ) : void
	{
		m_Price = value;
	}

	public function GetGFxData(parentFlashValueStorage : CScriptedFlashValueStorage) : CScriptedFlashObject
	{
		var l_flashObject : CScriptedFlashObject;
		var inv : CInventoryComponent;
		var text : string;

		inv = thePlayer.inv;

		text = BuildSummaryText();

		l_flashObject = parentFlashValueStorage.CreateTempFlashObject();
		l_flashObject.SetMemberFlashString("ContentRef", GetContentRef());
		l_flashObject.SetMemberFlashString("TextTitle", GetLocStringByKeyExt("panel_infusion_popup_title"));
		l_flashObject.SetMemberFlashString("TextContent", text);
		l_flashObject.SetMemberFlashNumber("ItempPrice", m_Price);
		return l_flashObject;
	}

	// The full transaction summary (spec §9.5). Fresh values from the preview
	// this popup was opened with. Flash renders TextContent as htmlText
	// (PriceConfirmationPopup.as) and WitcherScript strings do not process
	// backslash escapes, so line breaks are <br> tags.
	// Layout budget (panel_overlay.fla, PriceConfirmationPopup): tfMessage is
	// 481px wide, font size 24, vertically centered between the title and the
	// price (~130px). Only the level change uses the full size; the details
	// use a smaller font so the whole summary fits the frame.
	private function BuildSummaryText() : string
	{
		var inv : CInventoryComponent;
		var text : string;
		var parts : string;

		inv = thePlayer.inv;

		text = GetLocStringByKeyExt( "panel_infusion_target" ) + ": "
			+ GetLocStringByKeyExt( inv.GetItemLocalizedNameByUniqueID( targetId ) )
			+ " (" + preview.targetLevel + " -&gt; " + preview.newLevel + ")";
		text += DescribeStat();

		text += "<br><font size='16'>" + GetLocStringByKeyExt( "panel_infusion_sacrifice" ) + ": "
			+ GetLocStringByKeyExt( inv.GetItemLocalizedNameByUniqueID( sacrificeId ) )
			+ " (" + preview.sacrificeLevel + ")";

		// Only the salvage that actually reduces the recipe; the rest of the
		// sacrifice's breakdown is discarded (spec §5.4) and listing it read
		// like a discount that does not exist.
		parts = DescribeParts( preview.covered );
		if ( parts != "-" )
		{
			text += "<br>" + GetLocStringByKeyExt( "panel_infusion_recovered" ) + ": " + parts;
		}
		parts = DescribeParts( preview.materials );
		if ( parts != "-" )
		{
			text += "<br>" + GetLocStringByKeyExt( "panel_infusion_required" ) + ": " + parts;
		}
		text += "<br>" + GetLocStringByKeyExt( "panel_infusion_consumed_note" );
		// An enchanted sacrifice's runeword/glyphword and its upgrades are
		// lost, as when dismantling it; non-enchanted upgrades come back and
		// need no line here (the panel's rune slots show them).
		if ( preview.sacrificeEnchanted )
		{
			text += "<br><font color='#EC1212'>" + GetLocStringByKeyExt( "panel_infusion_enchant_lost" ) + "</font>";
		}
		text += "</font>";
		return text;
	}

	// "Rüstung: 129 -> 164" with the tooltip's own label and value. Left out
	// when the service has no projection or the tooltip's primary stat is a
	// different one (spec §9.2: no projection that isn't exact).
	private function DescribeStat() : string
	{
		var label : string;
		var shown : float;

		if ( preview.statAttribute == '' )
		{
			return "";
		}
		thePlayer.inv.GetItemPrimaryStat( targetId, label, shown );
		if ( label == "" || RoundMath( shown ) != RoundMath( preview.statBefore ) )
		{
			return "";
		}
		return "<br><font size='16'>" + label + ": " + RoundMath( preview.statBefore )
			+ " -&gt; " + RoundMath( preview.statAfter ) + "</font>";
	}

	private function DescribeParts( parts : array<SItemParts> ) : string
	{
		var i : int;
		var text : string;

		text = "";
		for ( i = 0; i < parts.Size(); i += 1 )
		{
			if ( parts[i].quantity <= 0 )
			{
				continue;
			}
			if ( text != "" )
			{
				text += ", ";
			}
			text += MaterialIconHtml( parts[i].itemName )
				+ GetLocStringByKeyExt( thePlayer.inv.GetItemLocalizedNameByName( parts[i].itemName ) ) + " x" + parts[i].quantity;
		}
		if ( text == "" )
		{
			text = "-";
		}
		return text;
	}

	// Small inline item icon, like the crafting menu's ingredient list. The
	// popup's htmlText resolves img:// item textures (verified in game).
	private function MaterialIconHtml( itemName : name ) : string
	{
		var iconPath : string;

		iconPath = thePlayer.inv.GetItemIconPathByName( itemName );
		if ( iconPath == "" )
		{
			return "";
		}
		return "<img src='img://" + iconPath + "' width='18' height='18' vspace='-4'> ";
	}

	protected function GetContentRef() : string
	{
		return "PriceConfirmationPopupRef";
	}

	protected function OnUserAccept() : void
	{
		menuRef.InfusionConfirm();
		ClosePopup();
	}

	protected function OnUserDecline() : void
	{
		menuRef.InfusionDecline();
		ClosePopup();
	}
}
