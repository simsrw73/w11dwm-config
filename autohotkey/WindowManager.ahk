#Requires AutoHotkey v2.0

; komorebi keys, following komorebi's sample whkdrc. Alt is the window-manager modifier.
; Workspaces are numbered across both monitors in komorebi.json order:
;   4K: 1 dev · 2 notes · 3 ai-lab · 4 admin      LG: 5 research · 6 comms · 7 files · 8 games · 9 scratch

BindWorkspaceHotkeys(["dev", "notes", "ai-lab", "admin", "research", "comms", "files", "games", "scratch"])

BindWorkspaceHotkeys(workspaces) {
    for i, workspace in workspaces {
        Hotkey("!" i, FocusWorkspaceHotkey(workspace))
        Hotkey("!+" i, MoveToWorkspaceHotkey(workspace))
    }
}
FocusWorkspaceHotkey(workspace) => (*) => Komorebi.FocusWorkspace(workspace)
MoveToWorkspaceHotkey(workspace) => (*) => Komorebi.MoveToWorkspace(workspace)

!+0::Komorebi.MoveToWorkspace("scratch")

; Focus / move / stack
!h::Komorebi.Run("focus", "left")
!j::Komorebi.Run("focus", "down")
!k::Komorebi.Run("focus", "up")
!l::Komorebi.Run("focus", "right")

!+h::Komorebi.Run("move", "left")
!+j::Komorebi.Run("move", "down")
!+k::Komorebi.Run("move", "up")
!+l::Komorebi.Run("move", "right")
!+Enter::Komorebi.Run("promote")

!^h::Komorebi.Run("stack", "left")
!^j::Komorebi.Run("stack", "down")
!^k::Komorebi.Run("stack", "up")
!^l::Komorebi.Run("stack", "right")
!`;::Komorebi.Run("unstack")
![::Komorebi.Run("cycle-stack", "previous")
!]::Komorebi.Run("cycle-stack", "next")

; Resize
!=::Komorebi.Run("resize-axis", "horizontal", "increase")
!-::Komorebi.Run("resize-axis", "horizontal", "decrease")
!+=::Komorebi.Run("resize-axis", "vertical", "increase")
!+-::Komorebi.Run("resize-axis", "vertical", "decrease")

; Window state
!q::Komorebi.Run("close")
!t::Komorebi.Run("toggle-float")
!+f::Komorebi.Run("toggle-monocle")
!+Space::Komorebi.Run("cycle-layout", "next")
!x::Komorebi.Run("flip-layout", "horizontal")
!y::Komorebi.Run("flip-layout", "vertical")

; Monitors and manager
!+s::Komorebi.SwapWorkspaceWithOtherMonitor()
!+w::Komorebi.Run("cycle-move-to-monitor", "next")
!+r::Komorebi.Run("retile")
!+o::Komorebi.Run("reload-configuration")
!p::Komorebi.Run("toggle-pause")

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
