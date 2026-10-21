/***********************************************************************/
/** 	Witcher Gear Infusion — unattended scenario run (DEV ONLY, never shipped)
/** 	Installed as its own mod folder by tools/run-scenarios.ps1 for one run
/** 	and removed afterwards, so a normal dev deploy never auto-loads a save.
/**
/** 	Flow, no input needed: the main menu loads the newest save (what
/** 	"Continue" does), the loaded game starts a timer, the timer runs
/** 	infuseScenarioAll (InfusionScenarios.ws) and quits the game.
/***********************************************************************/

// Seconds between the save being loaded and the scenarios starting
// (the world and the inventory must be up).
function InfusionAutoRunDelay() : float
{
	return 8.0;
}

// Seconds between the last scenario line and quitting (see InfusionAutoRunExitTimer).
function InfusionAutoRunExitDelay() : float
{
	return 90.0;
}

// The game object outlives menus and loads: load the save once per process, or a menu that
// comes up again (after the load, after a failed load) would start another load.
@addField( CR4Game ) var infAutoRunLoadRequested : bool;
@addField( CR4Game ) var infAutoRunStarted : bool;

// The start-up bumpers (disclaimers, legal, logo) and the "previously on" recap are menus that
// play a video each and wait for Space. Closing them right away is what the vanilla menus do
// themselves when they have no movie to show (CR4StartupMoviesMenu.OnConfigUI).
@wrapMethod( CR4StartupMoviesMenu ) function OnConfigUI()
{
	wrappedMethod();
	CloseMenu();
}

@wrapMethod( CR4RecapMoviesMenu ) function OnConfigUI()
{
	wrappedMethod();
	CloseMenu();
}

@wrapMethod( CR4IngameMenu ) function OnConfigUI()
{
	var game : CR4Game;

	wrappedMethod();
	game = (CR4Game)theGame;       // theGame itself is const: its fields can't be assigned
	if ( isMainMenu && !game.infAutoRunLoadRequested )
	{
		game.infAutoRunLoadRequested = true;
		LogChannel( 'Infusion', "autorun: main menu is up, loading the newest save" );
		LoadLastSave( false );
	}
}

@wrapMethod( CR4Game ) function OnGameStarted( restored : bool )
{
	wrappedMethod( restored );
	if ( !infAutoRunStarted )
	{
		infAutoRunStarted = true;
		LogChannel( 'Infusion', "autorun: game started (restored=" + restored + "), scenarios in " + InfusionAutoRunDelay() + " s" );
		thePlayer.AddTimer( 'InfusionAutoRunTimer', InfusionAutoRunDelay(), false );
	}
}

@addMethod( CR4Player ) timer function InfusionAutoRunTimer( dt : float, id : int )
{
	LogChannel( 'Infusion', "autorun: running the scenarios" );
	InfusionRunAllScenarios();
	LogChannel( 'Infusion', "autorun: done, exiting in " + InfusionAutoRunExitDelay() + " s" );
	// Quitting at once (and 6 s later) lost the log lines (scriptslog.txt stayed at its header):
	// the log reaches the file with a delay. The runner closes the game itself as soon as it has
	// read the result; this timer is only the fallback.
	AddTimer( 'InfusionAutoRunExitTimer', InfusionAutoRunExitDelay(), false );
}

@addMethod( CR4Player ) timer function InfusionAutoRunExitTimer( dt : float, id : int )
{
	// ExitGame() does not end the process here (it ended the session: back to the menu,
	// credits); RequestExit() is what the main menu's quit uses.
	theGame.RequestExit();
}
