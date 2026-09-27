#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut

#Include "Lib/App.ahk"
#Include "Lib/WindowLauncher.ahk"
#Include "Lib/Komorebi.ahk"
#Include "Lib/KeyChord/KeyChord.ahk"
#Include "Apps.ahk"
#Include "WindowManager.ahk"
#Include "Chords.ahk"
#Include "Hotkeys.ahk"
#Include "Hotstrings.ahk"

application := App(A_ScriptFullPath)
application.Start()
