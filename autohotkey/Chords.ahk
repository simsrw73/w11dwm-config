#Requires AutoHotkey v2.0

; Win+Space opens a which-key style menu (Legend chord mode): press a key to focus an app
; (switching to its komorebi workspace) or launch it. The menu appears if you pause;
; keys that open a submenu are marked with ›, and a green dot means the app is running.
; Backspace goes back a level, Esc or Ctrl+G cancels. The tree also appears as the
; "Launch" page in Alt+/.

Legend.Chord("#Space", "Launch", [
    ;ChordLaunch("c", "Claude Code", Apps.ClaudeCode),

    ChordLaunch("n", "Obsidian", Apps.Obsidian),        ;notes
    ChordLaunch("y", "Typora", Apps.Typora),            ;markdown

    ChordLaunch("m", "Spark", Apps.Spark),              ;email
    ChordLaunch("o", "TickTick", Apps.TickTick),        ;todo/organize
    ChordLaunch("c", "Fantastical", Apps.Fantastical),  ;calendar

    ChordLaunch("z", "Zed", Apps.Zed),
    ChordLaunch("t", "Terminal", Apps.Shell),           ;windows terminal

    ChordLaunch("f", "Explorer", Apps.Explorer),        ;file manager
    ChordLaunch("s", "Everything", Apps.Everything),    ;search
    ChordLaunch("k", "Koffee", Apps.Koffee),

    ChordLaunch("p", "Bitwarden", Apps.Bitwarden),      ;password manager
    ChordLaunch("x", "Task Manager", Apps.TaskManager),

    ChordSubmenu("a", "AI", [
        ChordLaunch("p", "Perplexity", Apps.Perplexity),
        ChordLaunch("a", "Claude", Apps.Claude),
        ChordLaunch("o", "ChatGPT", Apps.ChatGPT),
        ChordLaunch("c", "GitHub Copilot", Apps.Copilot),
        ChordLaunch("g", "Gemini", Apps.Gemini)]),

    ChordSubmenu("b", "Browser", [
        ChordLaunch("z", "Zen", Apps.Zen),
        ChordLaunch("b", "Brave", Apps.Brave),
        ChordLaunch("c", "Chrome", Apps.Chrome),
        ChordLaunch("e", "Edge", Apps.Edge)]),

    ChordSubmenu("g", "Gaming", [
        ChordLaunch("s", "Steam", Apps.Steam),
        ChordLaunch("g", "GOG Galaxy", Apps.GOG),
        ChordLaunch("a", "Amazon Games", Apps.AmazonGames),
        ChordLaunch("b", "Battle.net", Apps.BattleNet),
        ChordLaunch("e", "Epic Games", Apps.Epic),
        ChordLaunch("u", "Ubisoft Connect", Apps.Ubisoft),
        ChordLaunch("x", "Xbox", Apps.Xbox),
        ChordLaunch("v", "Vortex", Apps.Vortex),
        ChordLaunch("m", "Mod Organizer", Apps.ModOrganizer)]),

    ChordSubmenu("T", "Shell", [
        ChordLaunch("p", "Powershell", Apps.Powershell),
        ChordLaunch("a", "Arch", Apps.ArchWSL),
        ChordLaunch("k", "Kali", Apps.KaliWSL),
        ChordLaunch("u", "Ubuntu", Apps.UbuntuWSL),
        ChordLaunch("d", "MS Dev Shell", Apps.MSDevShell)]),

    ChordSubmenu("r", "Admin", [                        ;root
        ChordLaunch("u", "UniGetUI", Apps.UniGetUI),
        ChordAction("w", "Windows Update", OpenWindowsUpdate),
        ChordLaunch("s", "Settings", Apps.Settings),
        ChordLaunch("c", "Control Panel", Apps.ControlPanel),
        ChordLaunch("d", "Device Manager", Apps.DeviceManager),
        ChordLaunch("v", "Services", Apps.Services),
        ChordLaunch("e", "Event Viewer", Apps.EventViewer),
        ChordLaunch("j", "Task Scheduler", Apps.TaskScheduler),
        ChordLaunch("r", "Registry Editor", Apps.RegistryEditor),
        ChordLaunch("a", "Autoruns", Apps.Autoruns),
        ChordLaunch("p", "Process Explorer", Apps.ProcExp),
        ChordLaunch("m", "Process Monitor", Apps.ProcMon),
        ChordLaunch("t", "TCPView", Apps.TCPView),
        ChordLaunch("h", "Windhawk", Apps.Windhawk),
        ChordLaunch("o", "PowerToys", Apps.PowerToys),
        ChordLaunch("i", "HWiNFO", Apps.HWiNFO),
        ChordLaunch("z", "WizTree", Apps.WizTree),
        ChordLaunch("b", "WinBox", Apps.WinBox)]),

    ChordAction("Space", "Flow Launcher", () => Send("^``"))
])

; Focus the app (or launch it); the dot shows whether it is running.
ChordLaunch(key, label, app) => Legend.Run(key, label, (*) => WindowLauncher.ActivateOrRun(app),
    {Status: () => WindowLauncher.Find(app)})
ChordSubmenu(key, label, items) => Legend.Menu(key, label, items)
ChordAction(key, label, command) => Legend.Run(key, label, command)

; Windows Update is a page inside Settings, so reuse (or open) the Settings window first.
OpenWindowsUpdate() {
    WindowLauncher.ActivateOrRun(Apps.Settings)
    Run("ms-settings:windowsupdate")
}
