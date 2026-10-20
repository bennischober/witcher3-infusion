/***********************************************************************/
/** 	Witcher Gear Infusion — fault injection (DEV ONLY, never shipped)
/** 	Wraps the service's level step so scenario rollback_mismatch can
/** 	make Execute's level check fail and its rollback run. Inert unless
/** 	the fact InfCfg_TestLevelMismatch is set; the scenario sets it for
/** 	one Execute call and clears it again.
/***********************************************************************/

// Overshoots by real step abilities, so the rollback removes genuine
// duplicates. The returned count includes them: the rollback removes
// exactly what was added.
@wrapMethod(W3InfusionService) function ApplyLevelSteps( inv : CInventoryComponent, targetId : SItemUniqueId, preview : SInfusionPreview ) : int
{
	var added, extra : int;

	added = wrappedMethod( inv, targetId, preview );
	if ( FactsQuerySum( "InfCfg_TestLevelMismatch" ) <= 0 )
	{
		return added;
	}
	extra = 0;
	while ( ComputeItemLevel( inv, targetId ) == preview.sacrificeLevel && extra < 3 )
	{
		inv.AddItemCraftedAbility( targetId, preview.stepAbility, true );
		extra += 1;
	}
	return added + extra;
}
