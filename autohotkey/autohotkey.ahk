#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut

#Include "Lib/App.ahk"
#Include "Lib/WindowLauncher.ahk"
#Include "Lib/Komorebi.ahk"
#Include "Lib/Legend/Legend.ahk"
#Include "Apps.ahk"
#Include "WindowManager.ahk"
#Include "Chords.ahk"
#Include "Hotkeys.ahk"
#Include "Hotstrings.ahk"

; Alt+/ shows the shortcuts registered through Legend plus legend/pages/*.md.
Legend.Start({Pages: [A_ScriptDir "\legend\pages"], Themes: [A_ScriptDir "\legend\themes"], Theme: "mocha-yasb"})

application := App(A_ScriptFullPath)
application.Start()
