/***********************************************************************/
/** 	© 2015 CD PROJEKT S.A. All rights reserved.
/** 	THE WITCHER© is a trademark of CD PROJEKT S. A.
/** 	The Witcher game is based on the prose of Andrzej Sapkowski. 
/***********************************************************************/
/** 	modInfusion: this file overrides the vanilla blacksmithMenu.ws.
/** 	Changes (search 'modInfusion'):
/** 	  1. The Repair state doubles as the Infusion service: infusion-capable
/** 	     items show an "Infuse" action with the infusion fee; confirming
/** 	     opens the infusion preview popup instead of repairing.
/** 	  2. The repair grid is replaced by W3GuiInfusionInventoryComponent
/** 	     (shows infusion targets even at full durability).
/** 	  3. The Repair panel's button label is swapped per selected item
/** 	     (Flash hardcodes it; see UpdateInfusionActionLabel).
/** 	  Flash protocol reference: REDkit r4data\gameplay\gui_new\actionscript\
/** 	  red\game\witcher3\menus\blacksmith\BlacksmithMenu.as
/** 	CONFLICT NOTICE: overrides vanilla blacksmithMenu.ws; script merging
/** 	with other mods touching this file applies (none on this install).
/***********************************************************************/
class CR4BlacksmithMenu extends CR4MenuBase
{
	private var _disassembleInv 		: W3GuiDisassembleInventoryComponent;
	private var _repairInv 				: W3GuiRepairInventoryComponent;
	// modInfusion: infusion grid (replaces the plain repair grid).
	private var _infusionInv 			: W3GuiInfusionInventoryComponent;
	private var _infusionService 		: W3InfusionService;
	private var _infusionPreview 		: SInfusionPreview;
	private var _infusionTargetId 		: SItemUniqueId;
	private var _infusionSacrificeId 	: SItemUniqueId;
	private var _infusionActive 		: bool;
	private var _infusionCraftsman 		: CGameplayEntity;
	private var _socketInv 				: W3GuiSocketsInventoryComponent;
	private var _curInv	   				: W3GuiBaseInventoryComponent;
	private var _addSocketInv   		: W3GuiAddSocketsInventoryComponent;
	private var _standaloneDismantleInv : W3StandaloneDismantleComponent;
	private var _tooltipDataProvider	: W3TooltipComponent;
	
	protected var _inv 		      : CInventoryComponent;
	protected var _fixerNpc 	  : CNewNPC;
	protected var _fixerInventory : CInventoryComponent;
	
	private var m_standaloneMode : bool;
	private var m_menuInited : bool;
	private var m_lastConfirmedDisassembleQuantity : int;

	private var MAX_ITEM_NR : int;
	default MAX_ITEM_NR = 64;
	private var currentItemsNr : int;
	default	currentItemsNr = 0;
	
	private var InitDataConfirmation 	: PriceConfirmationPopupData;
	private var repairAllPopupData 		: RepairAllPopupData;
	private var quantityPopupData		: QuantityPopupData;
	
	private var m_fxRemoveItem   		: CScriptedFlashFunction;
	private var m_fxConfirmAction		: CScriptedFlashFunction;
	private var m_fxSetPlayerMoney		: CScriptedFlashFunction;
	private var m_fxSetXActionLabel 	: CScriptedFlashFunction;
	
	private var m_sectionsList			: CScriptedFlashArray;
	
	private var m_ingrForMissingDecoctions : array<name>;
	
	event  OnConfigUI()
	{	
		var l_flashPaperdoll		: CScriptedFlashSprite;
		var l_flashInventory		: CScriptedFlashSprite;
		var l_flashObject			: CScriptedFlashObject;
		var l_flashArray			: CScriptedFlashArray;
		var l_obj		 			: IScriptable;
		var l_fixerEntity			: CGameplayEntity;		
		var l_initData				: W3InventoryInitData;
		var l_dismantleInitData	    : W3StandaloneDismantleInitData;
		var hasUpgrades				: bool;
		var items 					: array<SItemUniqueId>;
		var i 						: int;
		
		m_menuInited = false;
		m_standaloneMode = false;
		
		super.OnConfigUI();
		
		m_initialSelectionsToIgnore = 0;
		
		l_obj = GetMenuInitData();
		l_initData = (W3InventoryInitData)l_obj;
		l_dismantleInitData = (W3StandaloneDismantleInitData)l_obj;		
		
		if( l_dismantleInitData )
		{
			m_ingrForMissingDecoctions = l_dismantleInitData.m_ingredientsForMissingDecoctions;
			m_standaloneMode = true;
		}
		else if( l_initData )
		{
			l_fixerEntity = l_initData.containerNPC;
		}
		else
		{
			l_fixerEntity = (CGameplayEntity)l_obj;
		}
		
		if( l_fixerEntity )
		{
			_fixerNpc = (CNewNPC)l_fixerEntity;
			_fixerInventory = l_fixerEntity.GetInventory();
		}
		
		_inv = thePlayer.GetInventory();
		m_flashModule = GetMenuFlash();
		m_fxConfirmAction = m_flashModule.GetMemberFlashFunction( "confirmAction" );
		m_fxSetPlayerMoney = m_flashModule.GetMemberFlashFunction( "setPlayerMoney" );
		m_fxRemoveItem = m_flashModule.GetMemberFlashFunction( "removeItem" );
		m_fxSetXActionLabel = m_flashModule.GetMemberFlashFunction( "setXActionLabel" );
		
		_tooltipDataProvider = new W3TooltipComponent in this;
		_tooltipDataProvider.initialize(_inv, m_flashValueStorage);
		_tooltipDataProvider.setCurrentInventory(_inv);
		
		if( _fixerInventory )
		{
			// modInfusion -- begin: infusion service initialization. The
			// production path always has a craftsman context: the debug
			// bypass (no-craftsman mode for console tests) stays off here.
			_infusionService = new W3InfusionService in this;
			_infusionService.config = new W3InfusionConfig in this;
			_infusionService.debugBypassCraftsman = false;
			_infusionCraftsman = l_fixerEntity;
			// modInfusion -- end

			_repairInv = new W3GuiRepairInventoryComponent in this;
			_repairInv.Initialize( _inv );
			_repairInv.merchantInv = _fixerInventory;
			
			
			_repairInv.repairArmors = true;
			_repairInv.repairSwords = true;
			_repairInv.masteryLevel = 5;
			
			
			// modInfusion -- begin: infusion grid shares the repair grid slot
			_infusionInv = new W3GuiInfusionInventoryComponent in this;
			_infusionInv.Initialize( _inv );
			_infusionInv.merchantInv = _fixerInventory;
			_infusionInv.repairArmors = true;
			_infusionInv.repairSwords = true;
			_infusionInv.masteryLevel = 5;
			_infusionInv.infusionService = _infusionService;
			_infusionInv.craftsman = _infusionCraftsman;
			// modInfusion -- end
			
			_socketInv = new W3GuiSocketsInventoryComponent in this;
			_socketInv.Initialize( _inv );
			_socketInv.SetSocketsFilter(true);
			_socketInv.merchantInv = _fixerInventory;
			
			
			_addSocketInv = new W3GuiAddSocketsInventoryComponent in this;
			_addSocketInv.Initialize( _inv );
			_addSocketInv.merchantInv = _fixerInventory;
			_addSocketInv.ignorePosition = true;
			
			
			_disassembleInv = new W3GuiDisassembleInventoryComponent in this;
			_disassembleInv.Initialize( _inv );
			_disassembleInv.merchantInv = _fixerInventory;
		}
		else
		{
			
			
			
			_standaloneDismantleInv = new W3StandaloneDismantleComponent in this;
			_standaloneDismantleInv.Initialize( _inv );
		}
		
		m_menuInited = true;
		ApplyMenuState(m_menuState);
		
		
		m_flashValueStorage.SetFlashString("repair.grid.player.name", GetLocStringByKeyExt("panel_inventory_grid_name"));
		
		
		if( !m_standaloneMode && m_menuState == 'Disassemble' && ShouldProcessTutorial( 'TutorialDismantleDescription' ) )
		{
			items = _disassembleInv.GetAllItems();
			for(i=0; i<items.Size(); i+=1)
			{
				if(_disassembleInv.ShouldShowItem(items[i]))
				{
					
					GameplayFactsSet("tut_dismantle_cond", 1);				
					theGame.GetTutorialSystem().uiHandler.OnOpeningMenu(GetMenuName());
				
					break;
				}
			}
		}
		else if( m_standaloneMode && ShouldProcessTutorial( 'TutorialMutagenTableDescription' ) )
		{
			theGame.GetTutorialSystem().uiHandler.OnOpeningMenu( 'MutagenDismantleMenu' );
		}
		
		m_fxSetTooltipState.InvokeSelfTwoArgs( FlashArgBool( thePlayer.upscaledTooltipState ), FlashArgBool( true ) );
	}
	
	public  function SetMenuState(newState : name) : void
	{
		var i : int;
		var hasUpgrades : bool;
		var items : array<SItemUniqueId>;
		var numEnhancements : int;
		var hasEnchantment : bool;
		
		if (newState == 'Sockets')
		{
			m_initialSelectionsToIgnore = 1;
		}
		
		// modInfusion: the Infuse tab has no page of its own in the SWF - Flash
		// receives 'Disassemble' (same grid; its info panel shows a per-item
		// icon list, used for the infusion costs - see SetCostPartList in the
		// grid component). The script state stays 'Infuse' so ApplyMenuState
		// and the confirmation routing know it.
		if ( newState == 'Infuse' )
		{
			super.SetMenuState( 'Disassemble' );
			m_menuState = 'Infuse';
			SetInfuseEmptyListText();
			// Flash's setMenuState just reset the button to "Repair"; in this
			// tab every listed item is an infusion target.
			SetRepairPanelButtonLabel( GetLocStringByKeyExt( "panel_button_inventory_infuse" ) );
		}
		else
		{
			super.SetMenuState(newState);
		}
		if (m_menuInited)
		{
			ApplyMenuState(newState);
		}
		
		if(m_menuState == 'Sockets' && ShouldProcessTutorial('TutorialUpgRemovalDescription'))
		{
			thePlayer.inv.GetAllItems(items);
			hasUpgrades = false;
			
			
			for(i=0; i<items.Size(); i+=1)
			{
				hasEnchantment = thePlayer.inv.GetEnchantment( items[ i ] ) != '';
				numEnhancements = thePlayer.inv.GetItemEnhancementCount( items[ i ] ); 
				if( numEnhancements > 0 && !hasEnchantment )
				{
					hasUpgrades = true;
					break;
				}
			}
			
			GameplayFactsSet("tutorial_upg_removal_cond", (int)hasUpgrades);
			theGame.GetTutorialSystem().uiHandler.OnOpeningMenu(GetMenuName());
		}
	}
	
	protected function ApplyMenuState( newState : name ) : void
	{
		if (m_standaloneMode)
		{
			
			
			switch( newState )
			{
				case 'Disassemble':
					_curInv = _standaloneDismantleInv;
					break;
				case 'Repair':
				case 'Sockets':
				case 'AddSockets':
					
					break;
				default:
					break;
			}
			
			m_sectionsList = NULL;
		}
		else
		{
			
			
			switch( newState )
			{
				// modInfusion: the Repair state is the unified service state —
				// the grid shows repairable AND infusion-capable items; the
				// per-item action (Repair or Infuse) and price are computed
				// per item (label in UpdateInfusionActionLabel, price in the
				// grid component). Any state change ends a pending sacrifice
				// selection (two-step flow, see EnterSacrificePhase).
				// modInfusion: dedicated Infuse tab - infusion only (damaged
				// items too: infusion includes the repair), no repair actions.
				case 'Infuse':
					if ( _infusionInv )
					{
						_infusionInv.EndSacrificePhase();
						_infusionInv.SetInfuseOnly( true );
					}
					_infusionActive = _infusionService && _infusionCraftsman
						&& _infusionService.GetPublicConfig().EnableInfusion();
					if ( _infusionActive )
					{
						_curInv = _infusionInv;
						LogChannel( 'Infusion', "infuse state: infusion-only grid ACTIVE (tab prototype)" );
					}
					else
					{
						_curInv = _repairInv;
						LogChannel( 'Infusion', "infuse state: infusion disabled or no craftsman - repair grid" );
					}
					break;
				case 'Repair':
					if ( _infusionInv )
					{
						_infusionInv.EndSacrificePhase();
						_infusionInv.SetInfuseOnly( false );
					}
					_infusionActive = _infusionService && _infusionCraftsman
						&& _infusionService.GetPublicConfig().EnableInfusion();
					if ( _infusionActive )
					{
						_curInv = _infusionInv;
						LogChannel( 'Infusion', "repair state: infusion grid ACTIVE (v3: craftsman-aware, cached)" );
					}
					else
					{
						_curInv = _repairInv;
						LogChannel( 'Infusion', "repair state: vanilla repair grid (infusion disabled or no craftsman)" );
					}
					break;
				case 'Sockets':
					_curInv = _socketInv;
					_infusionActive = false;
					break;
				case 'Disassemble':
					_curInv = _disassembleInv;
					_infusionActive = false;
					break;
				case 'AddSockets':
					_curInv = _addSocketInv;
					_infusionActive = false;
					break;
				default:
					_infusionActive = false;
					break;
			}
			
			SetSectionsDataList( newState );
		}
		
		UpdateRepairAllInputFeedback( newState );
		UpdateData();
	}
	
	protected function SetSectionsDataList( newState : name ) : void
	{
		var curDataObject : CScriptedFlashObject;
		
		// modInfusion: sacrifice phase of the two-step infusion flow - the
		// grid sections become "Target" (the picked item) and "Choose a
		// sacrifice" (its valid sacrifices).
		if ( ( newState == 'Repair' || newState == 'Infuse' ) && _infusionInv && _infusionInv.IsInSacrificePhase() )
		{
			m_sectionsList = m_flashValueStorage.CreateTempFlashArray();
			curDataObject = CreateSectionsData( 0, 0, 3, GetLocStringByKeyExt( "panel_infusion_target" ) );
			m_sectionsList.PushBackFlashObject( curDataObject );
			curDataObject = CreateSectionsData( 1, 4, 8, GetLocStringByKeyExt( "panel_infusion_choose_sacrifice" ) );
			m_sectionsList.PushBackFlashObject( curDataObject );
			return;
		}
		
		// modInfusion: in non-standalone mode the Repair state uses the
		// infusion grid when infusion is enabled (handled in ApplyMenuState).
			// modInfusion: Infuse state removed (no Flash page exists for
			// unknown states); the Repair state is the unified service state.
			switch( newState )
			{
				case 'Sockets':
				case 'Repair':
				case 'Infuse':
				case 'AddSockets':
				
				m_sectionsList = m_flashValueStorage.CreateTempFlashArray();
				curDataObject = CreateSectionsData( 0, 0, 3, GetLocStringByKeyExt( "panel_blacksmith_equipped" ) );
				m_sectionsList.PushBackFlashObject( curDataObject );
				curDataObject = CreateSectionsData( 1, 4, 8, GetLocStringByKeyExt( "item_category_misc" ) );
				m_sectionsList.PushBackFlashObject( curDataObject );
				break;
				
			case 'Disassemble':
				
				m_sectionsList = m_flashValueStorage.CreateTempFlashArray();
				curDataObject = CreateSectionsData( 0, 0, 3, GetLocStringByKeyExt( "item_category_equipement" ) );
				m_sectionsList.PushBackFlashObject( curDataObject );
				curDataObject = CreateSectionsData( 1, 4, 8, GetLocStringByKeyExt( "item_category_misc" ) );
				m_sectionsList.PushBackFlashObject( curDataObject );
				
				break;
				
			default:
				
				m_sectionsList = NULL;
				break;
		}
	}
	
	protected function CreateSectionsData( id : int, start : int, end : int, label : string ) : CScriptedFlashObject
	{
		var resData : CScriptedFlashObject;
		
		resData = m_flashValueStorage.CreateTempFlashObject( "red.game.witcher3.menus.inventory_menu.ItemSectionData" );
		resData.SetMemberFlashInt( "id", id );
		resData.SetMemberFlashInt( "start", start );
		resData.SetMemberFlashInt( "end", end );
		resData.SetMemberFlashString( "label", label );
		
		return resData;
	}
	
	protected function UpdateRepairAllInputFeedback(newState : name) : void
	{
		var repairString 		: string;
		var totalRepairCost 	: int;
		var language 	   		: string;
		var audioLanguage  		: string;
		var locStringRepair  	: string;
		var locStringPriceRepair 		: string;
		theGame.GetGameLanguageName( audioLanguage, language);
		
		repairString = "";
		
		// modInfusion: the Infuse tab uses the second key (Space / X, "repair
		// all" in the Repair tab) to cancel the sacrifice choice; no "repair
		// all" while choosing a sacrifice.
		if ( newState == 'Infuse' && _infusionInv && _infusionInv.IsInSacrificePhase() )
		{
			repairString = GetLocStringByKeyExt( "panel_common_cancel" );
		}
		else if (newState == 'Repair' && !( _infusionInv && _infusionInv.IsInSacrificePhase() ))
		{
			totalRepairCost = _repairInv.GetTotalRepairCost();
			
			if (totalRepairCost > 0)
			{
				locStringRepair = GetLocStringByKeyExt( "repair_equipped_items" );
				if( language != "AR")
				{
					repairString = locStringRepair + " (" + totalRepairCost + ")";
				}
				else
				{
					locStringPriceRepair =" *" + totalRepairCost + "*";
					repairString =   locStringRepair + locStringPriceRepair;
				}
			}
		}
		
		m_fxSetXActionLabel.InvokeSelfOneArg(FlashArgString(repairString));
	}
	
	event  OnClearSlotNewFlag(item : SItemUniqueId)
	{
		RemoveNewItemMark(item);
	}
	
	event  OnPlayDeniedSound()
	{
		OnPlaySoundEvent( "gui_global_denied" );
	}
	
	function RemoveNewItemMark(item : SItemUniqueId)
	{
		if (_inv.IsIdValid(item))
		{
			_curInv.ClearItemIsNewFlag(item);
		}
	}
	
	public function HandleActionConfirmation(value:bool):void
	{
		m_fxConfirmAction.InvokeSelfOneArg(FlashArgBool(value));
	}
	
	event  OnRequestConfirmation( itemId : SItemUniqueId, price : int )
	{
		var itemName		: name;
		
		// modInfusion -- begin: in the Repair state, undamaged items start the
		// two-step infusion flow (pick target, then sacrifice; spec §9.1)
		// instead of the repair flow; in the sacrifice phase every click
		// belongs to the infusion flow. Every path must answer Flash with
		// HandleActionConfirmation: Flash waits in its Confirmation state
		// until confirmAction() arrives (see BlacksmithMenu.as in REDkit).
		// Early return replaced with if/else — bare 'return;' in a
		// flash-bound event confuses the compiler's void/Bool handling here.
		if ( _infusionActive
			&& ( m_menuState == 'Infuse'
				|| ( m_menuState == 'Repair'
					&& ( _infusionInv.IsInSacrificePhase() || !_infusionInv.IsDamaged( itemId ) ) ) ) )
		{
			HandleInfusionClick( itemId );
		}
		else if( m_menuState == 'Disassemble' && m_standaloneMode && _inv.GetItemQuantity(itemId) == 1 )
		{
			itemName = _inv.GetItemName( itemId );
			
			if( m_ingrForMissingDecoctions.Contains( itemName ) )
			{
				ShowConfirmationPopup( itemId, price, 1 );
			}
			else
			{
				ProcessRequestConfirmation(itemId, price);
			}
		}
		else
		{
			ProcessRequestConfirmation(itemId, price);
		}
	}
	
	public function ProcessRequestConfirmation( itemId : SItemUniqueId, price : int )
	{
		var additionalDesc	: string = "";
		
		if( m_menuState == 'Disassemble' && _inv.GetItemQuantity(itemId) > 1 )
		{
			if( m_standaloneMode )
			{
				
				price = 0;
			}
			
			if( _inv.GetMoney() < price ) 
			{
				showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
				HandleActionConfirmation( false );
				OnPlaySoundEvent( "gui_global_denied" );
			}
			else
			{
				ShowDisassembleQuantityPopup( itemId, price );
			}
		}
		else
		{
			if (!m_standaloneMode)
			{
				ShowConfirmationPopup( itemId, price, 1 );
			}
			else
			{
				m_lastConfirmedDisassembleQuantity = 1;
				HandleActionConfirmation( true );
			}
		}
	}
	
	public function ShowConfirmationPopup( itemId : SItemUniqueId, price : int, quantity : int )
	{
		var confirmationTitle 	: string;
		var confirmationText  	: string;
		var costRepairPoint   	: int;
		var invItem 			: SInventoryItem;
		var playerMoney	 		: int;
		
		playerMoney = _inv.GetMoney();
		
		invItem = _inv.GetItem( itemId );
		
		switch (m_menuState)
		{
			case 'Repair':
				confirmationText = "panel_repair_popup_repair_item_text";
				confirmationTitle = "panel_button_common_repair";
				break;
			case 'Sockets':
				confirmationText = "panel_blacksmith_remove_improvement_confirmation";
				confirmationTitle = "panel_title_blacksmith_sockets";
				break;
			case 'Disassemble':
				if (m_standaloneMode)
				{
					confirmationText = "mutagen_dismantling_table_confirmation_popup";
				}
				else
				{
					confirmationText = "panel_repair_popup_disassemble_item_text";
				}
				confirmationTitle = "panel_title_blacksmith_disassamble";
				m_lastConfirmedDisassembleQuantity = quantity;
				break;				
			case 'AddSockets':
				confirmationText = "panel_blacksmith_add_socket_confirmation";
				confirmationTitle = "panel_title_blacksmith_add_sockets";
				break;
			default:
				confirmationText = "";
				confirmationTitle = "";
				break;
		}
		
		if ( playerMoney >= price )
		{
			if (m_lastConfirmedDisassembleQuantity > 1)
			{
				HandleActionConfirmation(true);
			}
			else
			{
				InitDataConfirmation = new PriceConfirmationPopupData in this;
				InitDataConfirmation.menuRef = this;
				InitDataConfirmation.BlurBackground = true;
				InitDataConfirmation.isStandaloneDismantle = m_standaloneMode;
				InitDataConfirmation.itemId = itemId;
				
				if ( confirmationText != "" )
				{
					InitDataConfirmation.SetMessageText( GetLocStringByKeyExt( confirmationText ) );
				}
				
				if ( confirmationTitle != "" )
				{
					InitDataConfirmation.SetMessageTitle( GetLocStringByKeyExt( confirmationTitle ) );
				}
				
				InitDataConfirmation.SetPrice( price );
				
				RequestSubMenu( 'PopupMenu', InitDataConfirmation );
			}
		}
		else
		{
			showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
			HandleActionConfirmation(false);
			OnPlaySoundEvent( "gui_global_denied" );
		}
	}
	
	public function OnDisassembleStack( itemId : SItemUniqueId, price : int, quantity : int )
	{
		var playerMoney	 		: int;
		
		playerMoney = _inv.GetMoney();
		
		if ( playerMoney >= price )
		{
			m_lastConfirmedDisassembleQuantity = quantity;
			HandleActionConfirmation(true);
		}
		else
		{
			showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
			HandleActionConfirmation(false);
			OnPlaySoundEvent( "gui_global_denied" );
		}
	}
	
	private function ShowDisassembleQuantityPopup( itemId : SItemUniqueId, price : int )
	{
		var maxValue : int;
		
		maxValue = _inv.GetItemQuantity(itemId);
		
		if ( quantityPopupData )
		{
			delete quantityPopupData;
		}
		
		quantityPopupData = new QuantityPopupData in this;
		
		quantityPopupData.showPrice = !m_standaloneMode;
		quantityPopupData.itemCost = price;
		quantityPopupData.itemId = itemId;
		quantityPopupData.minValue = 1;
		quantityPopupData.currentValue = _inv.GetItemQuantity(itemId);
		quantityPopupData.maxValue = _inv.GetItemQuantity(itemId);
		quantityPopupData.actionType = QTF_Dismantle;
		quantityPopupData.blacksmithRef = this;
		RequestSubMenu( 'PopupMenu', quantityPopupData );
	}
	
	event  OnRemoveImprovements(item : SItemUniqueId, price : int)
	{
		var socketItems	  : array<name>;
		var itemsListText : string;
		var idx, len	  : int;
		
		_inv.GetItemEnhancementItems(item, socketItems);
		itemsListText = GetLocStringByKeyExt("panel_blacksmith_items_added");
		len = socketItems.Size();
		for (idx = 0; idx < len; idx+=1)
		{
			itemsListText += ("<br/> +" + GetLocStringByKeyExt(_inv.GetItemLocalizedNameByName(socketItems[idx])));
		}
		
		_fixerInventory.AddMoney(price);
		_inv.RemoveMoney(price);
		_inv.RemoveAllItemEnhancements(item);
		
		if (_inv.GetItemQuantity(item) > 1)
		{
			UpdateItem(item);
		}
		else
		{
			RemoveItem(item);
		}
		
		UpdatePlayerMoney();
		UpdateMerchantData();
		theSound.SoundEvent( 'gui_inventory_buy' );		
	}
	
	event  OnDisassembleItem( item : SItemUniqueId, price : int)
	{
		var partList	  		: array <SItemParts>;
		var currentPartList 	: array <SItemParts>;
		var runesList	  		: array <name>;
		var itemsListText 		: string;
		var idx, len			: int;
		var i, x				: int;		
		var itemsCount	  		: int;
		var entryFound			: bool;
		var updateAfter			: bool;
		var craftComp			: W3CraftsmanComponent;
		
		var itemsAdded			: array <SItemUniqueId>;
		var itemsToUpdate		: array <SItemUniqueId>;
		var curPart				: SItemUniqueId;
		
		if( m_lastConfirmedDisassembleQuantity < 1 )
		{
			OnPlaySoundEvent( "gui_global_denied" );
			return 0;
		}
		
		itemsListText = "<font color =\"#404040\">" + GetLocStringByKeyExt( "panel_blacksmith_items_removed" ) + ": </font>";
		itemsListText += "<br/>" + ( GetLocStringByKeyExt( _inv.GetItemLocalizedNameByUniqueID( item ) ) + " x" + m_lastConfirmedDisassembleQuantity );
		
		if ( m_standaloneMode )
		{
			
			
			
			if( _inv.GetItemQuantity( item ) == m_lastConfirmedDisassembleQuantity)
			{
				RemoveItem( item );
				updateAfter = false;
			}
			else
			{
				updateAfter = true;
			}
			
			_standaloneDismantleInv.DoDismantling( item, m_lastConfirmedDisassembleQuantity, itemsAdded );
			
			if( updateAfter )
			{
				UpdateItem( item );
			}
			
			if( itemsAdded.Size() )
			{
				itemsListText += "<br/>" + "<font color =\"#404040\">" + GetLocStringByKeyExt( "panel_blacksmith_items_added" ) + ": </font>";
				itemsListText += "<br/>" + GetLocStringByKeyExt( _inv.GetItemLocalizedNameByName( _inv.GetItemName( itemsAdded[0] ) ) ) + " x" + m_lastConfirmedDisassembleQuantity;
				showNotification( itemsListText );
			}
		}
		else
		{
			
			
			partList = _inv.GetItemRecyclingParts(item);
			
			len = partList.Size();
			for (idx = 0; idx < len; idx+=1)
			{
				partList[idx].quantity = _inv.GetItemQuantityByName(partList[idx].itemName);
			}
			
			itemsListText += "<br/>" + "<font color =\"#404040\">" + GetLocStringByKeyExt("panel_blacksmith_items_added") + ": </font>";
			
			GetWitcherPlayer().StartInvUpdateTransaction();
			
			_fixerInventory.AddMoney(price * m_lastConfirmedDisassembleQuantity);
			_inv.RemoveMoney(price * m_lastConfirmedDisassembleQuantity);
			if ( _inv.GetItemEnhancementCount(item) > 0 && !_inv.IsItemEnchanted( item ) )
			{
				_inv.GetItemEnhancementItems(item, runesList);
				for (idx = 0; idx <  runesList.Size(); idx+=1)
				{
					_inv.AddAnItem( runesList[idx] );
					itemsListText += "<br/>" + (GetLocStringByKeyExt(_inv.GetItemLocalizedNameByName(runesList[idx])) + " x1");
				}		
			}
			
			craftComp = (W3CraftsmanComponent)_fixerNpc.GetComponentByClassName( 'W3CraftsmanComponent' );
			
			for (i = 0; i < m_lastConfirmedDisassembleQuantity; i += 1)
			{
				if ( craftComp )
				{
					if ( craftComp.IsCraftsmanType( ECT_Smith ) )
					{
						itemsAdded = _inv.RecycleItem(item, craftComp.GetCraftsmanLevel( ECT_Smith ) );
					}
					else if ( craftComp.IsCraftsmanType( ECT_Armorer ) )
					{
						itemsAdded = _inv.RecycleItem(item, craftComp.GetCraftsmanLevel( ECT_Armorer ) );
					}
					else
					{
						itemsAdded = _inv.RecycleItem( item, ECL_Journeyman );
					}
				}
				else
				{
					itemsAdded = _inv.RecycleItem( item, ECL_Journeyman );
				}
			}
			
			for (idx = 0; idx < len; idx+=1)
			{
				itemsCount = _inv.GetItemQuantityByName(partList[idx].itemName) - partList[idx].quantity;
				itemsListText += "<br/>" + GetLocStringByKeyExt(_inv.GetItemLocalizedNameByName(partList[idx].itemName)) + " x" + itemsCount;
			}
			
			
			showNotification(itemsListText);
			
			if (_inv.GetItemQuantity(item) > 0)
			{
				itemsToUpdate.PushBack(item);
			}
			else
			{
				RemoveItem(item);
			}
			
			len = itemsAdded.Size();
			for (idx = 0; idx < len; idx+=1)
			{
				curPart = itemsAdded[idx];
				partList.Clear();
				partList = _inv.GetItemRecyclingParts( curPart );
				if (partList.Size() > 0)
				{
					itemsToUpdate.PushBack(curPart);
				}
			}
		}
		
		
		
		if (itemsToUpdate.Size() > 0)
		{
			UpdateItemsList(itemsToUpdate);
		}
		
		GetWitcherPlayer().FinishInvUpdateTransaction();
		
		UpdatePlayerMoney();
		UpdateMerchantData();
		UpdateItemsCounter();
		
		theSound.SoundEvent( 'gui_inventory_buy' );
	}
	
	event  OnStartCrafting()
	{
		OnPlaySoundEvent("gui_crafting_craft_item");
	}
	
	event  OnRepairItem( item : SItemUniqueId, price : int )
	{
		_repairInv.RepairItem( item, 1 );
		_fixerInventory.AddMoney(price);
		_inv.RemoveMoney(price);
		
		// modInfusion: a repaired item that is infusable stays in the grid
		// (now offered for infusion) instead of being removed.
		if ( _infusionActive && _infusionInv.IsInfusable( item ) )
		{
			UpdateItem(item);
			UpdateInfusionActionLabel(item);
		}
		else if (_inv.GetItemQuantity(item) > 1)
		{
			UpdateItem(item);
		}
		else
		{
			RemoveItem(item);
		}
		
		UpdatePlayerMoney();
		UpdateMerchantData();
		
		theSound.SoundEvent( 'gui_inventory_buy' );
		theSound.SoundEvent( 'gui_inventory_repair' );
		
		UpdateRepairAllInputFeedback('Repair');
	}
	
	event  OnAddSocket( item : SItemUniqueId, price : int)
	{
		_addSocketInv.AddSocket( item );
		
		_fixerInventory.AddMoney(price);
		_inv.RemoveMoney(price);
		
		UpdateItem(item);
		
		UpdatePlayerMoney();
		UpdateMerchantData();
		
		theSound.SoundEvent( 'gui_enchanting_socket_add' );
	}
	
	event  OnRepairAllItems()
	{
		var totalRepairCost : int;
		
		totalRepairCost = _repairInv.GetTotalRepairCost();
		
		// modInfusion: in the Infuse tab this key cancels the sacrifice choice
		// (if/else instead of an early return - see OnRequestConfirmation).
		if ( m_menuState == 'Infuse' )
		{
			if ( _infusionInv && _infusionInv.IsInSacrificePhase() )
			{
				ExitSacrificePhase();
			}
		}
		else if (_inv.GetMoney() < totalRepairCost) 
		{
			showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
			HandleActionConfirmation(false);
			OnPlaySoundEvent( "gui_global_denied" );
		}
		else
		{
			repairAllPopupData = new RepairAllPopupData in this;
			repairAllPopupData.menuRef = this;
			repairAllPopupData.BlurBackground = true;
				
			repairAllPopupData.SetPrice( totalRepairCost );
			
			RequestSubMenu( 'PopupMenu', repairAllPopupData );
			
		}
	}
	
	public function RepairAll()
	{
		var emptyString : string;
		var totalRepairCost : int;
		
		emptyString = "";
		totalRepairCost = _repairInv.GetTotalRepairCost();
		
		_repairInv.RepairAllItems(1);
		
		_fixerInventory.AddMoney(totalRepairCost);
		_inv.RemoveMoney(totalRepairCost);
		UpdatePlayerMoney();
		UpdateMerchantData();
		
		theSound.SoundEvent( 'gui_inventory_buy' );
		theSound.SoundEvent( 'gui_inventory_repair' );
		
		InventoryUpdateAll();
		m_fxSetXActionLabel.InvokeSelfOneArg(FlashArgString(emptyString));
	}
	
	event  OnGetItemData(item : SItemUniqueId, compareItemType : int)
	{
		ShowItemTooltip(item, compareItemType);
		// modInfusion: Flash requests the tooltip whenever the selected item
		// changes - the hook for the per-item action button label.
		UpdateInfusionActionLabel(item);
	}
	
	event  OnGlobalUpdate()
	{
		UpdateData();
	}
		
	event  OnSaveItemGridPosition( item : SItemUniqueId, gridPos : int )
	{
		var UIData : SInventoryItemUIData;
		UIData = _inv.GetInventoryItemUIData( item );
		UIData.gridPosition = gridPos;
		
	}
	
	
	
	function UpdateData()
	{
		InventoryUpdateAll();
		UpdateItemsCounter();
		UpdateMerchantData();
		m_fxSetPlayerMoney.InvokeSelfOneArg( FlashArgInt( thePlayer.GetMoney() ) );
	}
	
	function InventoryUpdateAll()
	{
		var l_flashObject  : CScriptedFlashObject;
		var l_flashArray   : CScriptedFlashArray;
		
		if( _curInv )
		{
			l_flashObject = m_flashValueStorage.CreateTempFlashObject();
			l_flashArray = m_flashValueStorage.CreateTempFlashArray();
			
			// modInfusion: full rebuild - the inventory may have changed
			// since the last render; recompute infusion verdicts.
			if ( _infusionInv )
			{
				_infusionInv.InvalidateCache();
			}

			_curInv.GetInventoryFlashArray( l_flashArray, l_flashObject );
			
			m_flashValueStorage.SetFlashArray( "blacksmith.grid.section", m_sectionsList );
			m_flashValueStorage.SetFlashArray( "repair.grid.player", l_flashArray );
		}
	}
	
	function UpdateMerchantData() : void
	{
		var l_merchantData			: CScriptedFlashObject;
		l_merchantData = m_flashValueStorage.CreateTempFlashObject();
		GetNpcInfo((CGameplayEntity)_fixerNpc, l_merchantData);
		m_flashValueStorage.SetFlashObject("blacksmith.merchant.info", l_merchantData);
	}
	
	function InventoryUpdateItems( itemsList : array<SItemUniqueId>  )
	{
		var i					: int;
		var tempFlashObject		: CScriptedFlashObject;
		var itemDataObject		: CScriptedFlashObject;
		var itemsDataList		: CScriptedFlashArray;
		
		if (_curInv)
		{
			itemsDataList = m_flashValueStorage.CreateTempFlashArray();
			tempFlashObject = m_flashValueStorage.CreateTempFlashObject();
			for ( i = 0; i < itemsList.Size(); i += 1 )
			{
				itemDataObject = tempFlashObject.CreateFlashObject("red.game.witcher3.menus.common.ItemDataStub");
				_curInv.SetInventoryFlashObjectForItem(itemsList[i], itemDataObject);
				itemsDataList.PushBackFlashObject(itemDataObject);
			}
			m_flashValueStorage.SetFlashArray( "repair.grid.player.itemsUpdate", itemsDataList );
		}
	}
	
	function UpdatePlayerMoney()
	{
		var commonMenu 				: CR4CommonMenu;
		commonMenu = (CR4CommonMenu)m_parentMenu;
		
		if( commonMenu )
		{
			commonMenu.UpdatePlayerOrens();
		}
	}
	
	private function UpdateItemsList( itemsList : array<SItemUniqueId> ):void
	{
		var tempFlashObject : CScriptedFlashObject;
		var tempFlashArray  : CScriptedFlashArray;
		var itemDataObject	: CScriptedFlashObject;
		var idx, len:int;
		
		tempFlashObject = m_flashValueStorage.CreateTempFlashObject();
		tempFlashArray = m_flashValueStorage.CreateTempFlashArray();
		len = itemsList.Size();
		for (idx = 0; idx < len; idx +=1)
		{
			itemDataObject = tempFlashObject.CreateFlashObject("red.game.witcher3.menus.common.ItemDataStub");
			_curInv.SetInventoryFlashObjectForItem(itemsList[idx], itemDataObject);
			tempFlashArray.PushBackFlashObject(itemDataObject);
		}
		
		m_flashValueStorage.SetFlashArray( "blacksmith.item.list.update", tempFlashArray );
	}
	
	private function UpdateItem( item : SItemUniqueId )
	{
		var tempFlashObject		: CScriptedFlashObject;
		var itemDataObject		: CScriptedFlashObject;
		
		if (_curInv)
		{
			tempFlashObject = m_flashValueStorage.CreateTempFlashObject();
			itemDataObject = tempFlashObject.CreateFlashObject("red.game.witcher3.menus.common.ItemDataStub");
			_curInv.SetInventoryFlashObjectForItem(item, itemDataObject);
			m_flashValueStorage.SetFlashObject( "blacksmith.item.update", itemDataObject );
		}
	}
	
	private function RemoveItem( item : SItemUniqueId ):void
	{
		m_fxRemoveItem.InvokeSelfTwoArgs( FlashArgUInt(ItemToFlashUInt(item)), FlashArgBool( false ));
	}
	
	private function UpdateItemsCounter()
	{
		var itemsNr : int;
		var commonMenu 				: CR4CommonMenu;
		
		commonMenu = (CR4CommonMenu)m_parentMenu;
		if( commonMenu )
		{
			itemsNr = commonMenu.UpdateItemsCounter();
		}
		
		if( itemsNr >= MAX_ITEM_NR && currentItemsNr != itemsNr )
		{
			currentItemsNr = itemsNr;
			
		}
	}
	
	function GetCurrentInventory():CInventoryComponent
	{
		return _inv;
	}
	
	function GetItemDefaultActionName( item : SItemUniqueId ) : string
	{
		var itemAction : EInventoryActionType;
		itemAction = GetItemDefaultAction(item);
		
		return GetItemActionFriendlyName(itemAction,GetWitcherPlayer().IsItemEquipped(item));
	}
	
	function GetItemDefaultAction( item : SItemUniqueId ) : EInventoryActionType
	{
		return IAT_Repair;
	}

	// modInfusion -- begin: infusion helpers ------------------------------------------------

	// Flash must never see the 'Infuse' state (no page for it in the SWF).
	public function RefreshMenuState() : void
	{
		if ( m_menuState == 'Infuse' )
		{
			m_fxSetState.InvokeSelfOneArg( FlashArgString( "Disassemble" ) );
		}
		else
		{
			super.RefreshMenuState();
		}
	}

	// Flash's Repair page shows "nothing to repair" for an empty grid; the
	// Infuse tab replaces it (setMenuState sets it, so call after it).
	private function SetInfuseEmptyListText() : void
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

	// Label of the Repair panel's execute button. Flash hardcodes it to
	// "[[panel_button_common_repair]]" in its setMenuState (BlacksmithMenu.as
	// updateButtonsLabels), so the script swaps it per selected item through
	// the panel's own setButtonData(label, gamepadNavCode, keyCode) - the
	// exact call Flash makes (GAMEPAD_A = "enter-gamepad_A", KeyCode.E = 69).
	private function UpdateInfusionActionLabel( item : SItemUniqueId ) : void
	{
		var label : string;

		if ( ( m_menuState != 'Repair' && m_menuState != 'Infuse' ) || !_infusionInv || !m_flashModule )
		{
			return;
		}

		// Infuse tab: one constant label. Flash only tells script which item
		// is hovered (OnGetItemData), not which one is selected, so any
		// per-item label can mismatch with the mouse; cancelling the target
		// choice lives on the second key instead (UpdateRepairAllInputFeedback).
		if ( m_menuState == 'Infuse' )
		{
			SetRepairPanelButtonLabel( GetLocStringByKeyExt( "panel_button_inventory_infuse" ) );
			return;
		}

		if ( _infusionActive && _infusionInv.IsInSacrificePhase() && _inv.IsIdValid( item )
			&& item == _infusionInv.GetPhaseTarget() )
		{
			// Activating the picked target again cancels the selection.
			label = GetLocStringByKeyExt( "panel_common_cancel" );
		}
		else if ( _infusionActive && _infusionInv.IsInSacrificePhase() && _inv.IsIdValid( item ) )
		{
			label = GetLocStringByKeyExt( "panel_button_inventory_infuse" );
		}
		else if ( _infusionActive && _inv.IsIdValid( item )
			&& ( _infusionInv.IsInfuseOnly() || !_infusionInv.IsDamaged( item ) )
			&& _infusionInv.IsInfusable( item ) )
		{
			label = GetLocStringByKeyExt( "panel_button_inventory_infuse" );
		}
		else
		{
			label = "[[panel_button_common_repair]]";
		}

		SetRepairPanelButtonLabel( label );
	}

	private function SetRepairPanelButtonLabel( label : string ) : void
	{
		var panel : CScriptedFlashObject;
		var fxSetButtonData : CScriptedFlashFunction;
		var panelName : string;

		if ( !m_flashModule )
		{
			return;
		}
		// The Infuse tab renders the Disassemble page (see SetMenuState).
		if ( m_menuState == 'Infuse' )
		{
			panelName = "panelDisassemble";
		}
		else
		{
			panelName = "panelRepair";
		}
		panel = m_flashModule.GetMemberFlashObject( panelName );
		if ( !panel )
		{
			LogChannel( 'Infusion', "label: " + panelName + " not reachable from script" );
			return;
		}
		fxSetButtonData = panel.GetMemberFlashFunction( "setButtonData" );
		if ( !fxSetButtonData )
		{
			LogChannel( 'Infusion', "label: " + panelName + ".setButtonData not reachable from script" );
			return;
		}
		fxSetButtonData.InvokeSelfThreeArgs( FlashArgString( label ), FlashArgString( "enter-gamepad_A" ), FlashArgInt( 69 ) );
	}

	// Ends a confirmation request without a vanilla action. Flash waits in
	// its Confirmation state after OnRequestConfirmation until confirmAction
	// arrives; true would make it call OnRepairItem (charging a repair),
	// false returns it to item selection without side effects.
	private function EndInfusionRequest() : void
	{
		HandleActionConfirmation( false );
	}

	// Two-step infusion flow (spec §9.1: the player selects target AND
	// sacrifice). Step 1: the clicked undamaged item becomes the target and
	// the grid switches to its valid sacrifices. Step 2: the clicked
	// sacrifice opens the confirmation popup; clicking the target again
	// cancels. Every path ends the Flash confirmation request.
	private function HandleInfusionClick( item : SItemUniqueId ) : void
	{
		if ( !_infusionInv.IsInSacrificePhase() )
		{
			EnterSacrificePhase( item );
		}
		else if ( item == _infusionInv.GetPhaseTarget() )
		{
			EndInfusionRequest();
			ExitSacrificePhase();
		}
		else
		{
			StartInfusionFlow( item );
		}
	}

	private function EnterSacrificePhase( target : SItemUniqueId ) : void
	{
		if ( !_infusionService.IsSupportedTarget( target ) || !_infusionInv.IsInfusable( target ) )
		{
			showNotification( GetLocStringByKeyExt( "panel_infusion_no_sacrifice" ) );
			OnPlaySoundEvent( "gui_global_denied" );
			EndInfusionRequest();
			return;
		}

		_infusionTargetId = target;
		_infusionInv.BeginSacrificePhase( target );
		LogChannel( 'Infusion', "flow: target " + _inv.GetItemName( target ) + " picked - choose a sacrifice" );

		EndInfusionRequest();
		SetSectionsDataList( m_menuState );
		UpdateRepairAllInputFeedback( m_menuState );
		InventoryUpdateAll();
		UpdateInfusionActionLabel( target );
		OnPlaySoundEvent( "gui_global_submenu_whoosh" );
	}

	private function ExitSacrificePhase() : void
	{
		_infusionInv.EndSacrificePhase();
		LogChannel( 'Infusion', "flow: back to target selection" );

		SetSectionsDataList( m_menuState );
		UpdateRepairAllInputFeedback( m_menuState );
		InventoryUpdateAll();
		UpdateInfusionActionLabel( _infusionTargetId );
	}

	// Runs a fresh preview for the picked target and the clicked sacrifice
	// (spec §9.5: no stale values) and opens the confirmation popup with
	// the full cost breakdown.
	private function StartInfusionFlow( sacrifice : SItemUniqueId ) : void
	{
		var popupData : InfusionConfirmationPopupData;
		var err : EInfusionError;
		var missing : array<SItemParts>;
		var missingText : string;
		var i : int;

		err = _infusionService.Preview( _infusionTargetId, sacrifice, _infusionPreview, _infusionCraftsman );
		if ( err != IFE_Ok )
		{
			showNotification( InfusionErrorToString( err ) );
			OnPlaySoundEvent( "gui_global_denied" );
			EndInfusionRequest();
			return;
		}

		if ( _inv.GetMoney() < _infusionPreview.laborFee )
		{
			showNotification( GetLocStringByKeyExt( "panel_shop_notification_not_enough_money" ) );
			OnPlaySoundEvent( "gui_global_denied" );
			EndInfusionRequest();
			return;
		}

		// Missing materials stop the flow here, before the confirmation
		// (Execute would refuse anyway); the notification names what and how
		// many are missing.
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
			EndInfusionRequest();
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

	// Executes the confirmed infusion using the menu's craftsman (spec §8.1:
	// the NPC the player is actually talking to). Execute re-validates
	// everything before committing (spec §13.1).
	public function ConfirmInfusion() : void
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
			SetSectionsDataList( m_menuState );
		}
		else
		{
			showNotification( InfusionErrorToString( err ) );
			theSound.SoundEvent( "gui_global_denied" );
		}

		EndInfusionRequest();
		UpdateData();
		UpdatePlayerMoney();
		UpdateRepairAllInputFeedback( m_menuState );
		UpdateInfusionActionLabel( _infusionTargetId );
	}

	public function DeclineInfusion() : void
	{
		EndInfusionRequest();
	}

	// modInfusion -- end ---------------------------------------------------------------------

	
	event  OnCloseMenu()
	{
		if( m_standaloneMode )
		{
			theGame.GetTutorialSystem().uiHandler.OnClosingMenu( 'MutagenDismantleMenu' );
		}
		
		CloseMenu();
		
		if( m_parentMenu )
		{
			m_parentMenu.ChildRequestCloseMenu();
		}
	}
	
	event  OnClosingMenu()
	{
		if (_repairInv)
		{
			delete _repairInv;
		}
		if (_socketInv)
		{
			delete _socketInv;
		}
		if (InitDataConfirmation)
		{
			delete InitDataConfirmation;
		}
		if (quantityPopupData)
		{
			delete quantityPopupData;
		}
		if (repairAllPopupData)
		{
			delete repairAllPopupData;
		}
		
		theGame.GetGuiManager().SetLastOpenedCommonMenuName( GetMenuName() );
		super.OnClosingMenu();		
	}

	
	event  OnMoveItem( item : SItemUniqueId, moveToIndex : int )
	{
	}

	
	event  OnMoveItems( item : SItemUniqueId, moveToIndex : int, itemSecond : SItemUniqueId, moveToSecondIndex : int )
	{
	}
	
	event  OnPlaySound( soundKey : string )
	{
		theSound.SoundEvent( soundKey );
	}
	
	
	event  OnSetCurrentPlayerGrid( value : string )
	{
		
	}
	
	
	event  OnEquipItem( item : SItemUniqueId, slot : int, quantity : int )
	{
		
	}
	
	
	

	public function ShowItemTooltip(item : SItemUniqueId, compareItemType : int)
	{
		var tooltipData : CScriptedFlashObject;
		tooltipData = _tooltipDataProvider.GetTooltipData(item, true, true);
		m_flashValueStorage.SetFlashObject("context.tooltip.data", tooltipData);
	}
	
	event  OnShowItemPopup( item : SItemUniqueId )
	{
		var initData : ItemInfoPopupData;
		
		initData = new ItemInfoPopupData in this;
		initData.invRef = GetCurrentInventory();
		initData.itemId = item;
		RequestSubMenu('PopupMenu', initData);	
	}
	
	function PlayOpenSoundEvent()
	{
		
		
	}
	
	event  OnAppendGFxButton(actionId:int, gamepadNavCode:String, keyboardKeyCode:int, label:String, holdPrefix:bool, optional holdDuration:float)
	{
		var newButtonDef:SKeyBinding;
		
		RemoveGFxButtonById(actionId);
		newButtonDef.ActionID = actionId;
		newButtonDef.Gamepad_NavCode = gamepadNavCode;
		newButtonDef.Keyboard_KeyCode = keyboardKeyCode;
		
		if (holdPrefix)
		{
			newButtonDef.LocalizationKey = GetHoldLabel() + " " + GetLocStringByKeyExt(label);
			newButtonDef.IsLocalized = true;
			newButtonDef.IsHold = true;
			newButtonDef.HoldDuration = holdDuration;
		}
		else
		{
			newButtonDef.LocalizationKey = label;
		}
		
		if (actionId == 1002)
		{
			newButtonDef.IsLocalized = true;
		}
		
		m_GFxInputBindings.PushBack(newButtonDef);
	}
}



// modInfusion -- begin: infusion confirmation popup (spec §9.5) -----------
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
		text += "<br>" + GetLocStringByKeyExt( "panel_infusion_consumed_note" ) + "</font>";

		// Experiment (inline material icons): logged so the exact markup can
		// be compared with what renders.
		LogChannel( 'Infusion', "popup html: " + text );
		return text;
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

	// Experiment: small inline item icon like the crafting ingredient list.
	// Vanilla embeds images in htmlText (localizedContent.ws GetHTMLForItemICO)
	// but only UI-library symbols; item icons are textures loaded via img://
	// (PopupData.ws). Whether htmlText resolves img:// textures is what this
	// tests - if not, the tag renders nothing or an empty box.
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
		menuRef.ConfirmInfusion();
		ClosePopup();
	}

	protected function OnUserDecline() : void
	{
		menuRef.DeclineInfusion();
		ClosePopup();
	}
}
// modInfusion -- end -------------------------------------------------------




class PriceConfirmationPopupData extends ConfirmationPopupData
{
	private var m_Price : float;
	
	public var itemId : SItemUniqueId;
	public var isStandaloneDismantle : bool;
	public var menuRef : CR4BlacksmithMenu; 

	public  function GetGFxData(parentFlashValueStorage : CScriptedFlashValueStorage) : CScriptedFlashObject
	{
		var l_flashObject : CScriptedFlashObject;
		
		l_flashObject = parentFlashValueStorage.CreateTempFlashObject();
		l_flashObject.SetMemberFlashString("ContentRef", GetContentRef());
		l_flashObject.SetMemberFlashString("TextContent", m_TextContent);
		l_flashObject.SetMemberFlashString("TextTitle", m_TextTitle);
		l_flashObject.SetMemberFlashNumber("ItempPrice", m_Price);
		return l_flashObject;
	}
	
	public function SetPrice( value : float ) : void
	{
		m_Price = value;
	}
	
	protected function GetContentRef() : string
	{
		return "PriceConfirmationPopupRef";
	}
	
	protected function OnUserAccept() : void
	{
		if (isStandaloneDismantle)
		{
			menuRef.ProcessRequestConfirmation(itemId, 0);
		}
		else
		{
			menuRef.HandleActionConfirmation(true);
		}
		
		ClosePopup();
	}
	
	protected function OnUserDecline() : void
	{
		menuRef.HandleActionConfirmation(false);
		ClosePopup();
	}
}

class RepairAllPopupData extends ConfirmationPopupData
{
	private var m_Price : float;
	public var menuRef : CR4BlacksmithMenu; 

	public  function GetGFxData(parentFlashValueStorage : CScriptedFlashValueStorage) : CScriptedFlashObject
	{
		var l_flashObject : CScriptedFlashObject;
		
		l_flashObject = parentFlashValueStorage.CreateTempFlashObject();
		l_flashObject.SetMemberFlashString("ContentRef", GetContentRef());
		l_flashObject.SetMemberFlashString("TextContent", GetLocStringByKeyExt("repair_equipped_items_description"));
		l_flashObject.SetMemberFlashString("TextTitle", GetLocStringByKeyExt("repair_equipped_items"));
		l_flashObject.SetMemberFlashNumber("ItempPrice", m_Price);
		return l_flashObject;
	}
	
	public function SetPrice( value : float ) : void
	{
		m_Price = value;
	}
	
	protected function GetContentRef() : string
	{
		return "PriceConfirmationPopupRef";
	}
	
	protected function OnUserAccept() : void
	{
		menuRef.RepairAll();
		ClosePopup();
	}
	
	protected function OnUserDecline() : void
	{
		ClosePopup();
	}
}


exec function repairmenu()
{
	theGame.RequestMenuWithBackground( 'BlacksmithMenu', 'CommonMenu' );
}

exec function tdisass()
{
	var initDataObject:W3StandaloneDismantleInitData = new W3StandaloneDismantleInitData in theGame.GetGuiManager();
	
	initDataObject.setDefaultState( 'Disassemble' );
	initDataObject.unlockCraftingMenu = true;
	initDataObject.SetBlockOtherPanels( true );
	
	theGame.RequestMenuWithBackground( 'BlacksmithMenu', 'CommonMenu', initDataObject );
}