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
; Page letters match the top level of the Win+Space launcher (Chords.ahk), so a
; letter means the same app in both. Pages of my own use letters the launcher doesn't.
Legend.Start({
    Pages: [A_ScriptDir "\legend\pages"],
    PageKeys: Map(
        "Obsidian", "n", "Typora", "y", "Spark", "m", "TickTick", "o", "Fantastical", "c",
        "Zed", "z", "Windows Terminal", "t", "File Explorer", "f", "Everything", "s",
        "Koffee", "k", "Bitwarden", "p",
        "komorebi", "w", "AutoHotkey", "h", "Launch", "l", "Pickers", "i"),
    Themes: [A_ScriptDir "\legend\themes"],
    Theme: "mocha-yasb"
})

application := App(A_ScriptFullPath)
application.Start()
