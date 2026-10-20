/***********************************************************************/
/** 	Witcher Gear Infusion — Infuse tab in the blacksmith menu (annotations)
/** 	Replaces the former full-file override of blacksmithMenu.ws. The tab
/** 	itself is registered in InfusionMenuTab.ws; Flash renders it with its
/** 	Disassemble page (whose info panel lists a per-item icon row, used for
/** 	the material costs), the script keeps the state 'Infuse'.
/**
/** 	Hooks (vanilla 5.01 blacksmithMenu.ws unless noted):
/** 	  SetMenuState            Infuse: Flash gets 'Disassemble', script keeps 'Infuse'
/** 	  CR4MenuBase.RefreshMenuState  same for state refreshes (inherited -
/** 	                          wrapped in its declaring class)
/** 	  ApplyMenuState          Infuse grid; setup on first use (replaces the
/** 	                          OnConfigUI event code - events can't be annotated)
/** 	  SetSectionsDataList     Target / sacrifice section headers
/** 	  CR4MenuBase.UpdateInputDeviceType  re-sends the headers when the
/** 	                          input device changes (the step-2 header
/** 	                          names the cancel key)
/** 	  ProcessRequestConfirmation  click routing (vanilla OnRequestConfirmation
/** 	                          calls it for every non-standalone click)
/** 	  ShowItemTooltip         adds the block reason to a disabled target's
/** 	                          tooltip, re-applies the button label (called
/** 	                          from the OnGetItemData event)
/** 	  InventoryUpdateAll      invalidates the grid's verdict cache
/** 	Vanilla's Space/X handler stays untouched: Flash only sends it while
/** 	the key has a label; the Infuse tab clears the label and its bottom-bar
/** 	binding (InfusionUpdateActionLabel). Cancelling a
/** 	target choice = selecting the target again (or switching tabs).
/**
/** 	Annotation rules (docs/TECHNICAL_DISCOVERY.md): no access modifier
/** 	after the annotation; inherited methods are wrapped in the declaring
/** 	class; wrappers call wrappedMethod (here only on the non-Infuse paths).
/***********************************************************************/

// ---------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------

@addField( CR4BlacksmithMenu ) var _infusionInv : W3GuiInfusionInventoryComponent;
@addField( CR4BlacksmithMenu ) var _infusionService : W3InfusionService;
@addField( CR4BlacksmithMenu ) var _infusionPreview : SInfusionPreview;
@addField( CR4BlacksmithMenu ) var _infusionTargetId : SItemUniqueId;
@addField( CR4BlacksmithMenu ) var _infusionSacrificeId : SItemUniqueId;
@addField( CR4BlacksmithMenu ) var _infusionActive : bool;
@addField( CR4BlacksmithMenu ) var _infusionCraftsman : CGameplayEntity;

// ---------------------------------------------------------------------
// Wrapped vanilla methods
// ---------------------------------------------------------------------

// Flash has no page for 'Infuse': it is told 'Disassemble' (the two lines
// of CR4MenuBase.SetMenuState, with the Flash state swapped), the script
// state stays 'Infuse' so ApplyMenuState and the click routing know it.
@wrapMethod( CR4BlacksmithMenu ) function SetMenuState( newState : name ) : void
{
	InfusionDebugLog( "menu state: '" + m_menuState + "' -> '" + newState + "'" );
	if ( newState == 'Infuse' )
	{
		m_menuState = 'Infuse';
		m_fxSetState.InvokeSelfOneArg( FlashArgString( "Disassemble" ) );
		InfusionSetEmptyListText();
		// Entering the tab always starts at target selection.
		InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_infusion_blocked_warning" ) );
		// Flash's setMenuState just reset the button label.
		InfusionUpdateActionLabel();
		if ( m_menuInited )
		{
			ApplyMenuState( newState );
		}
	}
	else
	{
		wrappedMethod( newState );
		// The real Disassemble tab gets its vanilla warning back.
		if ( newState == 'Disassemble' )
		{
			InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_blacksmith_items_cant_disassemble" ) );
		}
	}
}

// Same for state refreshes (e.g. after a popup closes).
@wrapMethod( CR4MenuBase ) function RefreshMenuState() : void
{
	if ( m_menuState == 'Infuse' && (CR4BlacksmithMenu)this )
	{
		m_fxSetState.InvokeSelfOneArg( FlashArgString( "Disassemble" ) );
	}
	else
	{
		wrappedMethod();
	}
}

// Vanilla's switch has no 'Infuse' case and leaves _curInv alone, so the
// grid is picked before the vanilla body runs (sections, key label, data).
// Vanilla calls this on the open menus when the input device changes
// (CR4CommonMenu.UpdateInputDevice -> child menu). Inherited, so wrapped in
// its declaring class.
@wrapMethod( CR4MenuBase ) function UpdateInputDeviceType() : void
{
	var blacksmith : CR4BlacksmithMenu;

	wrappedMethod();
	blacksmith = (CR4BlacksmithMenu)this;
	if ( blacksmith )
	{
		blacksmith.InfusionOnInputDeviceChanged();
	}
}

@wrapMethod( CR4BlacksmithMenu ) function ApplyMenuState( newState : name ) : void
{
	if ( !m_standaloneMode )
	{
		InfusionPrepareState( newState );
	}
	wrappedMethod( newState );
}

@wrapMethod( CR4BlacksmithMenu ) function SetSectionsDataList( newState : name ) : void
{
	if ( newState == 'Infuse' )
	{
		InfusionSetSections();
	}
	else
	{
		wrappedMethod( newState );
	}
}

// Every click in the Infuse tab belongs to the two-step flow. It must never
// reach vanilla: Flash shows its Disassemble page there, so a vanilla
// confirmation would dismantle the item.
@wrapMethod( CR4BlacksmithMenu ) function ProcessRequestConfirmation( itemId : SItemUniqueId, price : int )
{
	if ( m_menuState == 'Infuse' )
	{
		if ( _infusionActive )
		{
			InfusionHandleClick( itemId );
		}
		else
		{
			InfusionEndRequest();
			OnPlaySoundEvent( "gui_global_denied" );
		}
	}
	else
	{
		wrappedMethod( itemId, price );
	}
}

// A disabled target's tooltip names why it can't be infused here (spec
// §9.3) in the tooltip's warning line - vanilla uses it for "not for sale"
// (TooltipInventory.as tfWarningMessage); a sacrifice's tooltip says how
// much of the recipe it covers. The tooltip follows the hovered item, which
// is the item the line belongs to. Same two calls as vanilla, with the
// line added before the data goes to Flash.
@wrapMethod( CR4BlacksmithMenu ) function ShowItemTooltip( item : SItemUniqueId, compareItemType : int )
{
	var tooltipData : CScriptedFlashObject;
	var warningText : string;

	warningText = "";
	if ( m_menuState == 'Infuse' && _infusionInv )
	{
		warningText = _infusionInv.GetBlockReasonText( item );
		if ( warningText == "" )
		{
			warningText = _infusionInv.GetSacrificeCoverText( item );
		}
	}
	if ( warningText != "" )
	{
		tooltipData = _tooltipDataProvider.GetTooltipData( item, true, true );
		if ( tooltipData )
		{
			tooltipData.SetMemberFlashString( "WarningMessage", warningText );
		}
		m_flashValueStorage.SetFlashObject( "context.tooltip.data", tooltipData );
	}
	else
	{
		wrappedMethod( item, compareItemType );
	}
	InfusionUpdateActionLabel();
}

// Full rebuild: the inventory may have changed since the last render.
@wrapMethod( CR4BlacksmithMenu ) function InventoryUpdateAll()
{
	if ( _infusionInv )
	{
		_infusionInv.InvalidateCache();
	}
	wrappedMethod();
}

// ---------------------------------------------------------------------
// Infuse tab
// ---------------------------------------------------------------------

// Creates the service and grid on first use, for the NPC the menu was
// opened with (same lookup as vanilla OnConfigUI). The production path
// always validates the real craftsman (debug bypass off).
@addMethod( CR4BlacksmithMenu ) function InfusionEnsureInit() : void
{
	var obj : IScriptable;
	var initData : W3InventoryInitData;
	var fixer : CGameplayEntity;

	if ( _infusionInv || !_fixerInventory )
	{
		return;
	}
	obj = GetMenuInitData();
	initData = (W3InventoryInitData)obj;
	if ( initData )
	{
		fixer = initData.containerNPC;
	}
	else
	{
		fixer = (CGameplayEntity)obj;
	}
	if ( !fixer )
	{
		return;
	}

	_infusionCraftsman = fixer;
	_infusionService = new W3InfusionService in this;
	_infusionService.config = new W3InfusionConfig in this;
	_infusionService.debugBypassCraftsman = false;

	_infusionInv = new W3GuiInfusionInventoryComponent in this;
	_infusionInv.Initialize( _inv );
	_infusionInv.merchantInv = _fixerInventory;
	_infusionInv.repairArmors = true;
	_infusionInv.repairSwords = true;
	_infusionInv.masteryLevel = 5;
	_infusionInv.infusionService = _infusionService;
	_infusionInv.craftsman = _infusionCraftsman;
}

// Infuse: infusion targets (damaged ones too - infusion includes the
// repair) plus disabled blocked targets, always starting at target
// selection. Without a craftsman or with infusion disabled the grid stays
// empty and clicks are refused. The page texts are (re)set here too: when
// the menu opens directly on this tab, SetMenuState runs before the Flash
// module exists.
@addMethod( CR4BlacksmithMenu ) function InfusionPrepareState( newState : name ) : void
{
	if ( newState != 'Infuse' )
	{
		_infusionActive = false;
		return;
	}
	InfusionEnsureInit();
	if ( _infusionInv )
	{
		_infusionInv.EndSacrificePhase();
		_curInv = _infusionInv;
	}
	else
	{
		_curInv = _repairInv;
	}
	_infusionActive = _infusionInv && _infusionService && _infusionCraftsman
		&& _infusionService.GetPublicConfig().EnableInfusion();
	InfusionSetEmptyListText();
	InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_infusion_blocked_warning" ) );
	InfusionUpdateActionLabel();
}

// Target selection: the Repair tab's sections (equipped / other). Sacrifice
// selection: "Target" (select again to cancel) and "Choose a sacrifice".
@addMethod( CR4BlacksmithMenu ) function InfusionSetSections() : void
{
	var curDataObject : CScriptedFlashObject;

	m_sectionsList = m_flashValueStorage.CreateTempFlashArray();
	if ( _infusionInv && _infusionInv.IsInSacrificePhase() )
	{
		curDataObject = CreateSectionsData( 0, 0, 3, StrReplace(
			GetLocStringByKeyExt( "panel_infusion_target_cancel" ), "%KEY%", InfusionAcceptKeyName() ) );
		m_sectionsList.PushBackFlashObject( curDataObject );
		curDataObject = CreateSectionsData( 1, 4, 8, GetLocStringByKeyExt( "panel_infusion_choose_sacrifice" ) );
		m_sectionsList.PushBackFlashObject( curDataObject );
	}
	else
	{
		curDataObject = CreateSectionsData( 0, 0, 3, GetLocStringByKeyExt( "panel_blacksmith_equipped" ) );
		m_sectionsList.PushBackFlashObject( curDataObject );
		curDataObject = CreateSectionsData( 1, 4, 8, GetLocStringByKeyExt( "item_category_misc" ) );
		m_sectionsList.PushBackFlashObject( curDataObject );
	}
}

// The key that selects - and so cancels on the picked target - for the
// step-2 header. The header is plain text (ModuleBlacksmithGrid.as sets
// .text), so no button icons: E on keyboard and mouse (the button's own
// key code, InfusionSetButtonLabel), the pad's letter otherwise. With the
// game's "swap accept/cancel" option the pad accepts with B / circle
// (vanilla GetIconForKey). PlayStation buttons are named X and O, as
// players call them.
@addMethod( CR4BlacksmithMenu ) function InfusionAcceptKeyName() : string
{
	var config : CInGameConfigWrapper;
	var swapped : bool;
	var padType : EInputDeviceType;

	if ( !theInput.LastUsedGamepad() )
	{
		return "E";
	}
	config = (CInGameConfigWrapper)theGame.GetInGameConfigWrapper();
	swapped = config.GetVarValue( 'Controls', 'SwapAcceptCancel' );
	padType = theInput.GetLastUsedGamepadType();
	if ( padType == IDT_PS4 || padType == IDT_PS5 )
	{
		if ( swapped )
		{
			return "O";
		}
		return "X";
	}
	if ( swapped )
	{
		return "B";
	}
	return "A";
}

// Step 2 shows the cancel key in its header: re-send the headers alone
// (BlacksmithMenu.as setSectionsList redraws the titles; the grid stays).
@addMethod( CR4BlacksmithMenu ) function InfusionOnInputDeviceChanged() : void
{
	if ( m_menuState != 'Infuse' || !_infusionInv || !_infusionInv.IsInSacrificePhase() )
	{
		return;
	}
	SetSectionsDataList( m_menuState );
	m_flashValueStorage.SetFlashArray( "blacksmith.grid.section", m_sectionsList );
}

// The Disassemble page's warning line (warningDisassemble.container.
// textField, BlacksmithMenu.as) appears for items with disableAction. Flash
// sets its text once at construction; the Infuse tab uses it for
// "missing materials", the Disassemble tab restores the vanilla text.
@addMethod( CR4BlacksmithMenu ) function InfusionSetDisassembleWarningText( text : string ) : void
{
	var warning : CScriptedFlashSprite;
	var container : CScriptedFlashSprite;
	var tf : CScriptedFlashTextField;

	if ( !m_flashModule )
	{
		return;
	}
	warning = m_flashModule.GetChildFlashSprite( "warningDisassemble" );
	if ( warning )
	{
		container = warning.GetChildFlashSprite( "container" );
	}
	if ( container )
	{
		tf = container.GetChildFlashTextField( "textField" );
	}
	if ( tf )
	{
		tf.SetText( text );
	}
	else
	{
		LogChannel( 'Infusion', "warning text: warningDisassemble.container.textField not reachable" );
	}
}

// Flash's empty-grid text; Flash's setMenuState sets it, so call after it.
@addMethod( CR4BlacksmithMenu ) function InfusionSetEmptyListText() : void
{
	var tf : CScriptedFlashTextField;

	if ( !m_flashModule )
	{
		return;
	}
	tf = m_flashModule.GetChildFlashTextField( "txtEmptyList" );
	if ( tf )
	{
		tf.SetText( StrUpperUTF( GetLocStringByKeyExt( "panel_infusion_no_sacrifice" ) ) );
	}
}

// One constant "Infuse" label on the execute button. The script never
// learns which item is selected: OnGetItemData follows the mouse hover,
// and Flash's selection event (OnInventoryItemSelected) only reaches
// script events, which annotations can't add (verified 2026-10-19). A
// per-item label would mismatch with the mouse; the step-2 header names
// the cancel action instead ("Ziel (E: abbrechen)").
//
//
// The Space hint ("repair equipped items") must stay off here. After the
// Repair tab it stayed in the bottom bar although every label update said
// 'Infuse' (debug log, 2026-10-19): the bar is the script-side binding list
// (CR4MenuBase.m_GFxInputBindings, action 1002), and Flash's removal didn't
// reach it. So the binding is removed here and the bar refreshed; the empty
// label also clears Flash's copy (BlacksmithMenu.as setXActionLabel; vanilla
// passes a string variable, not a literal).
@addMethod( CR4BlacksmithMenu ) function InfusionUpdateActionLabel() : void
{
	var noLabel : string;

	if ( m_menuState == 'Infuse' )
	{
		InfusionSetButtonLabel( GetLocStringByKeyExt( "panel_button_inventory_infuse" ) );
		noLabel = "";
		if ( m_fxSetXActionLabel )
		{
			m_fxSetXActionLabel.InvokeSelfOneArg( FlashArgString( noLabel ) );
		}
		RemoveGFxButtonById( 1002 );
		OnUpdateGFxButtonsList();
	}
}

// Also usable before the Infuse tab was opened (no service yet).
@addMethod( CR4BlacksmithMenu ) function InfusionDebugLog( msg : string ) : void
{
	var cfg : W3InfusionConfig;

	if ( _infusionService )
	{
		cfg = _infusionService.GetPublicConfig();
	}
	else
	{
		cfg = new W3InfusionConfig in this;
	}
	if ( cfg.DebugLogging() )
	{
		LogChannel( 'Infusion', msg );
	}
}

// Label of the execute button on the Disassemble page's panel. Flash
// hardcodes it in its setMenuState (BlacksmithMenu.as updateButtonsLabels),
// so the script sets it through the panel's own setButtonData(label,
// gamepadNavCode, keyCode) - the exact call Flash makes (GAMEPAD_A =
// "enter-gamepad_A", KeyCode.E = 69).
@addMethod( CR4BlacksmithMenu ) function InfusionSetButtonLabel( label : string ) : void
{
	var panel : CScriptedFlashObject;
	var fxSetButtonData : CScriptedFlashFunction;

	if ( !m_flashModule )
	{
		return;
	}
	panel = m_flashModule.GetMemberFlashObject( "panelDisassemble" );
	if ( !panel )
	{
		LogChannel( 'Infusion', "label: panelDisassemble not reachable from script" );
		return;
	}
	fxSetButtonData = panel.GetMemberFlashFunction( "setButtonData" );
	if ( !fxSetButtonData )
	{
		LogChannel( 'Infusion', "label: panelDisassemble.setButtonData not reachable from script" );
		return;
	}
	fxSetButtonData.InvokeSelfThreeArgs( FlashArgString( label ), FlashArgString( "enter-gamepad_A" ), FlashArgInt( 69 ) );
}

// Ends a confirmation request without a vanilla action. Flash waits in its
// Confirmation state after OnRequestConfirmation until confirmAction
// arrives; false returns it to item selection without side effects.
@addMethod( CR4BlacksmithMenu ) function InfusionEndRequest() : void
{
	HandleActionConfirmation( false );
}

// Two-step flow (spec §9.1: the player selects target AND sacrifice).
// Step 1: the clicked item becomes the target and the grid switches to its
// valid sacrifices. Step 2: a sacrifice opens the confirmation popup; the
// target again cancels. Every path ends the Flash confirmation request.
@addMethod( CR4BlacksmithMenu ) function InfusionHandleClick( item : SItemUniqueId ) : void
{
	if ( !_infusionInv.IsInSacrificePhase() )
	{
		InfusionEnterSacrificePhase( item );
	}
	else if ( item == _infusionInv.GetPhaseTarget() )
	{
		InfusionEndRequest();
		InfusionExitSacrificePhase();
	}
	else
	{
		InfusionStartFlow( item );
	}
}

@addMethod( CR4BlacksmithMenu ) function InfusionEnterSacrificePhase( target : SItemUniqueId ) : void
{
	if ( !_infusionService.IsSupportedTarget( target ) || !_infusionInv.IsInfusable( target ) )
	{
		showNotification( GetLocStringByKeyExt( "panel_infusion_no_sacrifice" ) );
		OnPlaySoundEvent( "gui_global_denied" );
		InfusionEndRequest();
		return;
	}

	_infusionTargetId = target;
	_infusionInv.BeginSacrificePhase( target );
	InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_infusion_missing" ) );
	LogChannel( 'Infusion', "flow: target " + _inv.GetItemName( target ) + " picked - choose a sacrifice" );

	InfusionEndRequest();
	SetSectionsDataList( m_menuState );
	InventoryUpdateAll();
	InfusionUpdateActionLabel();
	OnPlaySoundEvent( "gui_global_submenu_whoosh" );
}

@addMethod( CR4BlacksmithMenu ) function InfusionExitSacrificePhase() : void
{
	_infusionInv.EndSacrificePhase();
	InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_infusion_blocked_warning" ) );
	LogChannel( 'Infusion', "flow: back to target selection" );

	SetSectionsDataList( m_menuState );
	InventoryUpdateAll();
	InfusionUpdateActionLabel();
}

// Fresh preview for the picked target and the clicked sacrifice (spec
// §9.5: no stale values), then the confirmation popup.
@addMethod( CR4BlacksmithMenu ) function InfusionStartFlow( sacrifice : SItemUniqueId ) : void
{
	var popupData : InfusionConfirmationPopupData;
	var err : EInfusionError;
	var missing : array<SItemParts>;
	var missingText : string;
	var i : int;

	err = _infusionService.Preview( _infusionTargetId, sacrifice, _infusionPreview, _infusionCraftsman );
	if ( err != IFE_Ok )
	{
		showNotification( InfusionErrorToLocString( err ) );
		OnPlaySoundEvent( "gui_global_denied" );
		InfusionEndRequest();
		return;
	}

	if ( _inv.GetMoney() < _infusionPreview.laborFee )
	{
		showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
		OnPlaySoundEvent( "gui_global_denied" );
		InfusionEndRequest();
		return;
	}

	// Safety net: sacrifices with missing materials are disabled in the grid
	// (disableAction); Execute would refuse anyway.
	if ( _infusionService.GetMissingMaterials( _inv, _infusionPreview.materials, missing ) )
	{
		missingText = "";
		for ( i = 0; i < missing.Size(); i += 1 )
		{
			if ( missingText != "" )
			{
				missingText += ", ";
			}
			missingText += GetLocStringByKeyExt( _inv.GetItemLocalizedNameByName( missing[i].itemName ) ) + " x" + missing[i].quantity;
		}
		showNotification( GetLocStringByKeyExt( "panel_infusion_missing" ) + ": " + missingText );
		OnPlaySoundEvent( "gui_global_denied" );
		InfusionEndRequest();
		return;
	}

	_infusionSacrificeId = sacrifice;

	popupData = new InfusionConfirmationPopupData in this;
	popupData.menuRef = this;
	popupData.BlurBackground = true;
	popupData.targetId = _infusionTargetId;
	popupData.sacrificeId = _infusionSacrificeId;
	popupData.preview = _infusionPreview;
	popupData.SetPrice( _infusionPreview.laborFee );
	RequestSubMenu( 'PopupMenu', popupData );
}

// Executes the confirmed infusion with the menu's craftsman (spec §8.1).
// Execute re-validates everything before committing (spec §13.1).
@addMethod( CR4BlacksmithMenu ) function InfusionConfirm() : void
{
	var err : EInfusionError;
	var p : SInfusionPreview;

	err = _infusionService.Execute( _infusionTargetId, _infusionSacrificeId, p, _infusionCraftsman );
	if ( err == IFE_Ok )
	{
		// The craftsman is paid like for a vanilla repair.
		if ( _fixerInventory )
		{
			_fixerInventory.AddMoney( p.laborFee );
		}
		showNotification( GetLocStringByKeyExt( "panel_infusion_done" ) );
		theSound.SoundEvent( 'gui_crafting_craft_item' );

		// Done: back to target selection (a failed attempt stays in the
		// sacrifice phase so another sacrifice can be picked).
		_infusionInv.EndSacrificePhase();
		InfusionSetDisassembleWarningText( GetLocStringByKeyExt( "panel_infusion_blocked_warning" ) );
		SetSectionsDataList( m_menuState );
	}
	else
	{
		showNotification( InfusionErrorToLocString( err ) );
		theSound.SoundEvent( "gui_global_denied" );
	}

	InfusionEndRequest();
	UpdateData();
	UpdatePlayerMoney();
	InfusionUpdateActionLabel();
}

@addMethod( CR4BlacksmithMenu ) function InfusionDecline() : void
{
	InfusionEndRequest();
}
