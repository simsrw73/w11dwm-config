#Requires AutoHotkey v2.0

Legend.Page("AutoHotkey").Category("Script", [
    ["^!#r", "reload AutoHotkey", (*) => Reload()],
    ["^!#q", "exit AutoHotkey", (*) => ExitApp()]
])

; App launching lives in Chords.ahk (Win+Space).


localAppDataDir := EnvGet("LocalAppData")
chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
cleanProfileDir := localAppDataDir "\Google\Chrome\AHK-CleanProfile"

; The match here (not only in legend/pages/zen.md) keeps Win+Shift+O Zen-only.
Legend.Page("Zen", "ahk_exe zen.exe").Category("Tabs", [
    ["#+o", "open current tab in Chrome", (*) => OpenCurrentZenTabInChrome()]
])

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
