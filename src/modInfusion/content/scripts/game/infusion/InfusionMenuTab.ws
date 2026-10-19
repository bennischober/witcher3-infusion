/***********************************************************************/
/** 	Witcher Gear Infusion — Infusion tab registration (annotations)
/** 	Replaces the former full-file override of commonMenu.ws with two
/** 	REDkit script annotations (official docs: "WS Script Compilation
/** 	Errors / overrides"; compiler messages verified in witcher3.exe 5.01):
/** 	  1. @wrapMethod CR4CommonMenu.DefineSceneMenuStructure: runs the
/** 	     vanilla menu structure, then inserts the 'Infuse' tab right after
/** 	     the blacksmith's Repair tab. Chainable with other mods' wrappers.
/** 	  2. @replaceMethod HaxGetPanelStateName (global): vanilla body plus
/** 	     "Infuse". Unknown states map to '' - the root cause of the blank
/** 	     Infuse tab in the 2026-10-11 attempt. Global functions can only be
/** 	     replaced (the docs list no global form of @wrapMethod), so a
/** 	     second mod replacing it would fail with "duplicate found".
/** 	Flash renders the tab with its Disassemble page; see
/** 	CR4BlacksmithMenu.SetMenuState (blacksmithMenu.ws).
/***********************************************************************/

@wrapMethod( CR4CommonMenu ) private function DefineSceneMenuStructure() : void
{
	wrappedMethod();
	InfusionAddBlacksmithTab();
}

// Inserts the Infuse tab after the blacksmith's Repair tab. The Repair tab
// only exists where vanilla defines it (crafting available), so the
// Infuse tab appears exactly where the blacksmith service does.
@addMethod( CR4CommonMenu ) private function InfusionAddBlacksmithTab() : void
{
	var tab : SMenuTab;
	var i : int;

	for ( i = 0; i < m_menuData.Size(); i += 1 )
	{
		if ( m_menuData[i].MenuName == 'BlacksmithMenu' && m_menuData[i].MenuState == 'Repair' )
		{
			tab.MenuName = 'BlacksmithMenu';
			tab.MenuLabel = "panel_title_infusion";
			tab.Visible = true;
			tab.Enabled = true;
			tab.ParentMenu = '';
			tab.MenuState = 'Infuse';
			tab.MenuIcon = 'BlacksmithRepair';
			m_menuData.Insert( i + 1, tab );
			return;
		}
	}
}

// Vanilla 5.01 body (commonMenu.ws) plus the Infuse state.
@replaceMethod function HaxGetPanelStateName( stateName : string ) : name
{
	switch(stateName)
	{
		case "CharacterInventory" :
			return 'CharacterInventory';
		case "HorseInventory" :
			return 'HorseInventory';
		case "GlobalMap" :
			return 'GlobalMap';
		case "FastTravel" :
			return 'FastTravel';
		case "Objectives" :
			return 'Objectives';
		case "Sockets" :
			return 'Sockets';
		case "Repair" :
			return 'Repair';
		case "Infuse" :
			return 'Infuse';
		case "Disassemble" :
			return 'Disassemble';
		case "AddSockets":
			return 'AddSockets';
		case "Transmog":
			return 'Transmog';
	}
	return '';
}
