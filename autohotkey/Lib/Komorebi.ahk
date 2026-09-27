#Requires AutoHotkey v2.0

class Komorebi {
    static Run(args*) {
        return RunWait(this.CommandLine(args), , "Hide")
    }

    static Query(args*) {
        tempFile := A_Temp "\komorebic-" A_TickCount ".out"
        try {
            RunWait(A_ComSpec ' /c "' this.CommandLine(args) ' > "' tempFile '""', , "Hide")
            return FileExist(tempFile) ? Trim(FileRead(tempFile, "UTF-8"), " `r`n") : ""
        } finally {
            try FileDelete(tempFile)
        }
    }

    static FocusWorkspace(name) => this.Run("focus-named-workspace", name)

    static MoveToWorkspace(name) => this.Run("move-to-named-workspace", name)

    static SwapWorkspaceWithOtherMonitor() {
        focused := this.Query("query", "focused-monitor-index")
        if focused = ""
            return
        this.Run("swap-workspaces-with-monitor", focused = "0" ? 1 : 0)
    }

    ; Name of the workspace that manages hwnd, or "" if komorebi doesn't manage it.
    ; Workspace objects serialize "name" before their containers, and windows have no
    ; "name" key, so the last workspace name before the hwnd is the owning workspace.
    static WorkspaceOf(hwnd) {
        state := this.Query("state")
        hwndPos := RegExMatch(state, '"hwnd":\s*' hwnd '\b')
        if !hwndPos
            return ""

        name := ""
        pos := 1
        while (pos := RegExMatch(state, '"name":\s*"([^"]*)"', &match, pos)) && pos < hwndPos {
            name := match[1]
            pos += match.Len
        }
        return name
    }

    static CommandLine(args) {
        cmd := "komorebic.exe"
        for arg in args
            cmd .= " " (InStr(arg, " ") ? Quote(arg) : arg)
        return cmd
    }
}
