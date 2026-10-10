; ============================================================
; Witcher 3 debug console enabler (fallback for keyboard layouts
; where the tilde scan code is unreachable).
;
; Requirement: AutoHotkey v1.1 (https://www.autohotkey.com/)
; Usage: double-click this file, keep it running, launch the game.
; While in gameplay, F12 sends the physical tilde key (scan code
; 0x29) — the hardcoded console toggle of the engine.
;
; To stop: right-click the green H icon in the tray -> Exit.
; ============================================================

#IfWinActive ahk_exe witcher3.exe
F12::Send {sc029}
#IfWinActive
