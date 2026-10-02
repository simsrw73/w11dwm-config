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
; Page letters follow the Win+Space launcher (Chords.ahk) where they don't clash.
Legend.Start({
    Pages: [A_ScriptDir "\legend\pages"],
    PageKeys: Map(
        "Zed", "z", "Obsidian", "n", "Spark", "m", "TickTick", "t", "Fantastical", "d",
        "File Explorer", "e", "Everything", "f", "Bitwarden", "b", "Windows Terminal", "s",
        "Claude", "c", "Zen", "w", "Koffee", "o",
        "komorebi", "k", "AutoHotkey", "a", "Launch", "l", "Pickers", "p"),
    Themes: [A_ScriptDir "\legend\themes"],
    Theme: "mocha-yasb"
})

application := App(A_ScriptFullPath)
application.Start()
