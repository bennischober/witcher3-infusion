@echo off
rem ============================================================
rem Launches The Witcher 3 (Remastered, DX12) with script debug
rem logging enabled. Logs are written to:
rem   C:\Users\benni\Documents\The Witcher 3\scriptslog.txt
rem (the engine writes it next to the saves folder when
rem  -debugscripts is active; DebugScriptsLogDir from the INI
rem  files applies when set)
rem
rem Just double-click this file instead of starting the game from
rem Steam. Steam must be running (the exe still talks to Steam
rem for achievements/cloud saves).
rem ============================================================
start "" "E:\SteamLibrary\steamapps\common\The Witcher 3\bin\x64_dx12\witcher3.exe" -debugscripts
