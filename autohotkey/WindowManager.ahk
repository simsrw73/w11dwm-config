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
