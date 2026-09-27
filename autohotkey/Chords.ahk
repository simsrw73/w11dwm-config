#Requires AutoHotkey v2.0

; Win+Space opens a which-key style menu: press a key to focus an app (switching to its
; komorebi workspace) or launch it. Keys that open a submenu are marked with ›.
; A green dot means the app is already running.

#Space::Chords.Open(Chords.Root)

class Chords {
    static Timeout := 4

    static Root := ChordMenu("Launch",
        ChordLaunch("z", "Zed", Apps.Zed),
        ChordLaunch("c", "Claude Code", Apps.ClaudeCode),
        ChordLaunch("s", "Shell", Apps.Shell),
        ChordLaunch("n", "Obsidian", Apps.Obsidian),
        ChordSubmenu("w", "Research", ChordMenu("Launch › Research",
            ChordLaunch("w", "Zen", Apps.Zen),
            ChordLaunch("b", "Brave", Apps.Brave),
            ChordLaunch("c", "Chrome", Apps.Chrome),
            ChordLaunch("e", "Edge", Apps.Edge),
            ChordLaunch("t", "Typora", Apps.Typora))),
        ChordSubmenu("a", "AI Lab", ChordMenu("Launch › AI Lab",
            ChordLaunch("p", "Perplexity", Apps.Perplexity),
            ChordLaunch("c", "Claude", Apps.Claude),
            ChordLaunch("o", "ChatGPT", Apps.ChatGPT),
            ChordLaunch("h", "GitHub Copilot", Apps.Copilot),
            ChordLaunch("g", "Gemini", Apps.Gemini))),
        ChordSubmenu("u", "Admin", ChordMenu("Launch › Admin",
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
            ChordLaunch("b", "WinBox", Apps.WinBox))),
        ChordSubmenu("g", "Games", ChordMenu("Launch › Games",
            ChordLaunch("s", "Steam", Apps.Steam),
            ChordLaunch("g", "GOG Galaxy", Apps.GOG),
            ChordLaunch("a", "Amazon Games", Apps.AmazonGames),
            ChordLaunch("b", "Battle.net", Apps.BattleNet),
            ChordLaunch("e", "Epic Games", Apps.Epic),
            ChordLaunch("u", "Ubisoft Connect", Apps.Ubisoft),
            ChordLaunch("x", "Xbox", Apps.Xbox),
            ChordLaunch("v", "Vortex", Apps.Vortex),
            ChordLaunch("m", "Mod Organizer", Apps.ModOrganizer))),
        ChordLaunch("m", "Spark", Apps.Spark),
        ChordLaunch("t", "TickTick", Apps.TickTick),
        ChordLaunch("d", "Fantastical", Apps.Fantastical),
        ChordLaunch("e", "Explorer", Apps.Explorer),
        ChordLaunch("f", "Everything", Apps.Everything),
        ChordLaunch("k", "Koffee", Apps.Koffee),
        ChordLaunch("b", "Bitwarden", Apps.Bitwarden),
        ChordLaunch("x", "Task Manager", Apps.TaskManager),
        ChordAction("Space", "Flow Launcher", () => Send("^``")))

    static Open(menu) {
        overlay := ChordOverlay(menu)
        key := this.ReadKey()
        overlay.Destroy()

        if key = "" || key = "Escape"
            return

        matches := menu.Chord.FindTrue(key)
        if matches.Length
            matches[1].Command.Call()
        else
            KCManager.TimedToolTip("Nothing on " key, 1)
    }

    ; Waits for one non-modifier key and swallows it. Modifiers pass through untouched, so
    ; releasing Win after Win+Space behaves normally.
    static ReadKey() {
        ih := InputHook("L0 T" this.Timeout)
        ih.KeyOpt("{All}", "+ES")
        ih.KeyOpt("{LWin}{RWin}{LShift}{RShift}{LCtrl}{RCtrl}{LAlt}{RAlt}", "-ES")
        ih.Start()
        ih.Wait()
        if ih.EndReason != "EndKey"
            return ""
        return StrLen(ih.EndKey) = 1 ? StrLower(ih.EndKey) : ih.EndKey
    }
}

class ChordMenu {
    __New(title, items*) {
        this.Title := title
        this.Items := items
        this.Chord := KeyChord()
        for item in items
            this.Chord.Set(item.Key, item.Command, True, item.Label)
    }
}

ChordLaunch(key, label, app) => { Key: key, Label: label, App: app, Command: () => WindowLauncher.ActivateOrRun(app) }
ChordSubmenu(key, label, menu) => { Key: key, Label: label, Menu: menu, Command: () => Chords.Open(menu) }
ChordAction(key, label, command) => { Key: key, Label: label, Command: command }

; Windows Update is a page inside Settings, so reuse (or open) the Settings window first.
OpenWindowsUpdate() {
    WindowLauncher.ActivateOrRun(Apps.Settings)
    Run("ms-settings:windowsupdate")
}

; Catppuccin Mocha panel that matches the yasb bar and popups.
class ChordOverlay {
    static Colors := {
        crust: "11111B", surface0: "313244", surface1: "45475A", overlay0: "6C7086",
        overlay1: "7F849C", subtext0: "A6ADC8", text: "CDD6F4", lavender: "B4BEFE", green: "A6E3A1",
    }

    __New(menu) {
        c := ChordOverlay.Colors
        g := this.Gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000") ; WS_EX_NOACTIVATE
        g.BackColor := c.crust
        g.MarginX := 22, g.MarginY := 18

        g.SetFont("s9 w600 c" c.overlay1, "Inter")
        g.AddText("xm ym", StrUpper(menu.Title))

        rowHeight := 30, colWidth := 240, top := 50
        rows := menu.Items.Length > 8 ? Ceil(menu.Items.Length / 2) : menu.Items.Length
        for i, item in menu.Items {
            x := g.MarginX + ((i - 1) // rows) * colWidth
            y := top + Mod(i - 1, rows) * rowHeight

            g.SetFont("s11 w700 c" c.lavender, "JetBrainsMono Nerd Font")
            g.AddText("x" x " y" y " w48", item.Key = "Space" ? "spc" : item.Key)

            running := item.HasOwnProp("App") && WindowLauncher.Find(item.App)
            g.SetFont("s7 c" (running ? c.green : c.surface1), "Inter")
            g.AddText("x" (x + 48) " y" (y + 5) " w14", item.HasOwnProp("App") ? "●" : "")

            g.SetFont("s11 w500 c" (item.HasOwnProp("Menu") ? c.subtext0 : c.text), "Inter")
            g.AddText("x" (x + 64) " y" y " w" (colWidth - 72), item.Label (item.HasOwnProp("Menu") ? "  ›" : ""))
        }

        g.SetFont("s9 w500 c" c.overlay0, "Inter")
        g.AddText("xm y" (top + rows * rowHeight + 10), "esc  close")

        this.RoundCorners(g.Hwnd, c.surface0)
        g.Show("NA Hide AutoSize")
        WinGetPos(, , &w, &h, g)
        area := WindowLauncher.ActiveMonitorWorkArea()
        g.Show("NA x" (area.Left + (area.Right - area.Left - w) // 2) " y" (area.Top + (area.Bottom - area.Top - h) // 2))
        WinSetTransparent(245, g)
    }

    Destroy() => this.Gui.Destroy()

    RoundCorners(hwnd, borderRgb) {
        static DWMWA_WINDOW_CORNER_PREFERENCE := 33, DWMWCP_ROUND := 2, DWMWA_BORDER_COLOR := 34
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_WINDOW_CORNER_PREFERENCE, "Int*", DWMWCP_ROUND, "UInt", 4)
        rgb := Integer("0x" borderRgb)
        bgr := ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_BORDER_COLOR, "UInt*", bgr, "UInt", 4)
    }
}
