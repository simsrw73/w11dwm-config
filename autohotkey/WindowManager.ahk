#Requires AutoHotkey v2.0

; komorebi keys, following komorebi's sample whkdrc. Alt is the window-manager modifier.
; Workspaces are numbered across both monitors in komorebi.json order:
;   4K: 1 dev · 2 notes · 3 ai-lab · 4 admin      LG: 5 research · 6 comms · 7 files · 8 games · 9 scratch
; Every key registers through Legend, so Alt+/ lists it on the komorebi page.

komorebiKeys := Legend.Page("komorebi")  ; not "komorebi": names are case-insensitive and Komorebi is a class

BindWorkspaceHotkeys(["dev", "notes", "ai-lab", "admin", "research", "comms", "files", "games", "scratch"])

BindWorkspaceHotkeys(workspaces) {
    for i, workspace in workspaces {
        Legend.Bind(["komorebi", "Workspaces", "Focus"], "!" i, i " " workspace, FocusWorkspaceHotkey(workspace))
        Legend.Bind(["komorebi", "Workspaces", "Move window"], "!+" i, "to " i " " workspace, MoveToWorkspaceHotkey(workspace))
    }
}
FocusWorkspaceHotkey(workspace) => (*) => Komorebi.FocusWorkspace(workspace)
MoveToWorkspaceHotkey(workspace) => (*) => Komorebi.MoveToWorkspace(workspace)
; Without komorebi, Alt+H/J/K/L still move focus, by window position.
FocusHotkey(direction) => (*) => Komorebi.IsRunning() ? Komorebi.Run("focus", direction) : LegendWindows.Focus(direction)

komorebiKeys.Category("Workspaces", [
    ["!+0", "to scratch", (*) => Komorebi.MoveToWorkspace("scratch")]
], "Move window")

komorebiKeys.Category("Focus / move / stack", [
    ["!h", "focus left", FocusHotkey("left"), {Row: "Alt+H/J/K/L", Text: "focus ← ↓ ↑ →"}],
    ["!j", "focus down", FocusHotkey("down"), {Row: "Alt+H/J/K/L"}],
    ["!k", "focus up", FocusHotkey("up"), {Row: "Alt+H/J/K/L"}],
    ["!l", "focus right", FocusHotkey("right"), {Row: "Alt+H/J/K/L"}],
    ["!+h", "move left", (*) => Komorebi.Run("move", "left"), {Row: "Alt+Shift+H/J/K/L", Text: "move window ← ↓ ↑ →"}],
    ["!+j", "move down", (*) => Komorebi.Run("move", "down"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+k", "move up", (*) => Komorebi.Run("move", "up"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+l", "move right", (*) => Komorebi.Run("move", "right"), {Row: "Alt+Shift+H/J/K/L"}],
    ["!+Enter", "promote to main", (*) => Komorebi.Run("promote")],
    ["!^h", "stack left", (*) => Komorebi.Run("stack", "left"), {Row: "Ctrl+Alt+H/J/K/L", Text: "stack onto ← ↓ ↑ →"}],
    ["!^j", "stack down", (*) => Komorebi.Run("stack", "down"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!^k", "stack up", (*) => Komorebi.Run("stack", "up"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!^l", "stack right", (*) => Komorebi.Run("stack", "right"), {Row: "Ctrl+Alt+H/J/K/L"}],
    ["!;", "unstack", (*) => Komorebi.Run("unstack")],
    ["![", "previous in stack", (*) => Komorebi.Run("cycle-stack", "previous"), {Row: "Alt+[ / ]", Text: "previous / next in stack"}],
    ["!]", "next in stack", (*) => Komorebi.Run("cycle-stack", "next"), {Row: "Alt+[ / ]"}]
])

komorebiKeys.Category("Resize", [
    ["!=", "wider", (*) => Komorebi.Run("resize-axis", "horizontal", "increase"), {Row: "Alt+= / -", Text: "wider / narrower"}],
    ["!-", "narrower", (*) => Komorebi.Run("resize-axis", "horizontal", "decrease"), {Row: "Alt+= / -"}],
    ["!+=", "taller", (*) => Komorebi.Run("resize-axis", "vertical", "increase"), {Row: "Alt+Shift+= / -", Text: "taller / shorter"}],
    ["!+-", "shorter", (*) => Komorebi.Run("resize-axis", "vertical", "decrease"), {Row: "Alt+Shift+= / -"}]
])

komorebiKeys.Category("Window state", [
    ["!q", "close window", (*) => Komorebi.Run("close")],
    ["!t", "toggle float", (*) => Komorebi.Run("toggle-float")],
    ["!+f", "toggle monocle", (*) => Komorebi.Run("toggle-monocle")],
    ["!+Space", "next layout", (*) => Komorebi.Run("cycle-layout", "next")],
    ["!x", "flip horizontal", (*) => Komorebi.Run("flip-layout", "horizontal"), {Row: "Alt+X / Y", Text: "flip horizontal / vertical"}],
    ["!y", "flip vertical", (*) => Komorebi.Run("flip-layout", "vertical"), {Row: "Alt+X / Y"}]
])

komorebiKeys.Category("Monitors & manager", [
    ["!+s", "swap workspace with other monitor", (*) => Komorebi.SwapWorkspaceWithOtherMonitor()],
    ["!+w", "move window to next monitor", (*) => Komorebi.Run("cycle-move-to-monitor", "next")],
    ["!+r", "retile", (*) => Komorebi.Run("retile")],
    ["!+o", "reload komorebi config", (*) => Komorebi.Run("reload-configuration")],
    ["!p", "pause komorebi", (*) => Komorebi.Run("toggle-pause")]
])

; Window switchers (Legend pickers): Alt+A all windows, Alt+S this monitor (h/l in
; either cycles all windows / this desktop / this monitor). komorebi-managed windows
; show their workspace; picking one on a hidden workspace switches to it first.
BindWindowSwitchers()

BindWindowSwitchers() {
    for trigger, scope in Map("!a", "all", "!s", "monitor")
        Legend.WindowSwitcher(trigger, {Scope: scope, Detail: KomorebiDetail, Activate: SwitchToWindow})
}

; komorebi-managed windows go through WindowLauncher (it focuses their workspace first);
; everything else, including windows on other virtual desktops, through Legend.
SwitchToWindow(hwnd) {
    if Komorebi.IsRunning() && Komorebi.WorkspaceOf(hwnd) != ""
        return WindowLauncher.Activate(hwnd)
    LegendWindows.Activate(hwnd)
}

; The row detail: app name, plus the komorebi workspace. One state query per second at most.
KomorebiDetail(win) {
    static workspaces := Map(), stamp := 0
    if A_TickCount - stamp > 1000 {
        workspaces := Komorebi.IsRunning() ? Komorebi.WorkspaceMap() : Map()
        stamp := A_TickCount
    }
    return workspaces.Has(win.Hwnd) ? win.App " · " workspaces[win.Hwnd] : win.App
}

; Windows Hello / credential prompts (CredentialUIBroker) often open behind the active
; window because the app that asked for them isn't in the foreground. komorebi ignores
; them (applications.json), so raise them here like the other popups. The app that asked
; for the prompt (Bitwarden, always-on-top) keeps pulling focus back while it waits, so a
; one-shot raise loses: hold the prompt on top and focused for as long as it is open.
class SecurityPrompts {
    ; Match on class only: the "Windows Security" title isn't set yet when the window is created.
    static Criteria := "ahk_class Credential Dialog Xaml Host"
    static Last := 0

    static Watch() {
        SetTimer(ObjBindMethod(this, "Hold"), 250)
    }

    static Hold() {
        static WS_EX_TOPMOST := 0x8
        if !(hwnd := WinExist(this.Criteria)) {
            this.Last := 0
            return
        }
        target := "ahk_id " hwnd
        try {
            if hwnd != this.Last {           ; new prompt: center it on the monitor in use
                this.Last := hwnd
                WindowLauncher.Activate(hwnd, WindowLauncher.ActiveMonitorWorkArea())
                return
            }
            if !(WinGetExStyle(target) & WS_EX_TOPMOST)
                WinSetAlwaysOnTop(1, target)
            if !WinActive(target)
                WinActivate(target)
        } catch TargetError                  ; the prompt closed under us
            return
    }
}
SecurityPrompts.Watch()
