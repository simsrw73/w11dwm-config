#Requires AutoHotkey v2.0

^!#r::Reload()
^!#q::ExitApp()

; App launching lives in Chords.ahk (Win+Space).


localAppDataDir := EnvGet("LocalAppData")
chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
cleanProfileDir := localAppDataDir "\Google\Chrome\AHK-CleanProfile"

zenWin := "ahk_exe zen.exe"

; Meta + Shift + O: Open current Zen tab in Chrome
#HotIf WinActive(zenWin)
#+o::OpenCurrentZenTabInChrome()
#HotIf

OpenCurrentZenTabInChrome() {
    global chromePath, cleanProfileDir

    savedClip := ClipboardAll()
    A_Clipboard := ""

    ; Zen default: Copy Current URL = Ctrl+Shift+C ("^+c")
    ; Modified to Ctrl+Alt+C
    Send "^!c"

    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        MsgBox "Couldn't get the current tab URL from Zen.", "AHK", "Icon!"
        return
    }
    url := Trim(A_Clipboard)
    A_Clipboard := savedClip

    if !RegExMatch(url, "i)^(https?|file|ftp)://") {
        MsgBox "Clipboard did not contain a valid URL:`n`n" url, "AHK", "Icon!"
        return
    }

    DirCreate(cleanProfileDir)

    cmd := '"' chromePath '" --new-window --user-data-dir="' cleanProfileDir '" "' url '"'

    try Run(cmd)
    catch Error as err {
        MsgBox "Failed to launch Chrome.`n`n" err.Message, "AHK", "Icon!"
    }
}
