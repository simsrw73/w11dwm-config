#Requires AutoHotkey v2.0

; Win+Space opens a which-key style menu (Legend chord mode): press a key to focus an app
; (switching to its komorebi workspace) or launch it. The menu appears if you pause;
; keys that open a submenu are marked with ›, and a green dot means the app is running.
; Backspace goes back a level, Esc or Ctrl+G cancels. The tree also appears as the
; "Launch" page in Alt+/.

Legend.Chord("#Space", "Launch", [
    ChordLaunch("z", "Zed", Apps.Zed),
    ChordLaunch("c", "Claude Code", Apps.ClaudeCode),
    ChordLaunch("s", "Shell", Apps.Shell),
    ChordLaunch("n", "Obsidian", Apps.Obsidian),
    ChordSubmenu("w", "Research", [
        ChordLaunch("w", "Zen", Apps.Zen),
        ChordLaunch("b", "Brave", Apps.Brave),
        ChordLaunch("c", "Chrome", Apps.Chrome),
        ChordLaunch("e", "Edge", Apps.Edge),
        ChordLaunch("t", "Typora", Apps.Typora)]),
    ChordSubmenu("a", "AI Lab", [
        ChordLaunch("p", "Perplexity", Apps.Perplexity),
        ChordLaunch("c", "Claude", Apps.Claude),
        ChordLaunch("o", "ChatGPT", Apps.ChatGPT),
        ChordLaunch("h", "GitHub Copilot", Apps.Copilot),
        ChordLaunch("g", "Gemini", Apps.Gemini)]),
    ChordSubmenu("u", "Admin", [
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
    ChordSubmenu("g", "Games", [
        ChordLaunch("s", "Steam", Apps.Steam),
        ChordLaunch("g", "GOG Galaxy", Apps.GOG),
        ChordLaunch("a", "Amazon Games", Apps.AmazonGames),
        ChordLaunch("b", "Battle.net", Apps.BattleNet),
        ChordLaunch("e", "Epic Games", Apps.Epic),
        ChordLaunch("u", "Ubisoft Connect", Apps.Ubisoft),
        ChordLaunch("x", "Xbox", Apps.Xbox),
        ChordLaunch("v", "Vortex", Apps.Vortex),
        ChordLaunch("m", "Mod Organizer", Apps.ModOrganizer)]),
    ChordLaunch("m", "Spark", Apps.Spark),
    ChordLaunch("t", "TickTick", Apps.TickTick),
    ChordLaunch("d", "Fantastical", Apps.Fantastical),
    ChordLaunch("e", "Explorer", Apps.Explorer),
    ChordLaunch("f", "Everything", Apps.Everything),
    ChordLaunch("k", "Koffee", Apps.Koffee),
    ChordLaunch("b", "Bitwarden", Apps.Bitwarden),
    ChordLaunch("x", "Task Manager", Apps.TaskManager),
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
