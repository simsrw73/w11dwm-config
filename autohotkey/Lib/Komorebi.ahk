#Requires AutoHotkey v2.0

class Komorebi {
    ; True while komorebi is running, even if it is paused.
    static IsRunning() => ProcessExist("komorebi.exe") != 0

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

    ; hwnd → name of the workspace managing it, from one state query (same rule as
    ; WorkspaceOf: the last workspace name before each hwnd).
    static WorkspaceMap() {
        state := this.Query("state")
        result := Map(), name := "", pos := 1
        while pos := RegExMatch(state, '"(name|hwnd)":\s*(?:"([^"]*)"|(\d+))', &match, pos) {
            if match[1] = "name"
                name := match[2]
            else
                result[Integer(match[3])] := name
            pos += match.Len
        }
        return result
    }

    static CommandLine(args) {
        cmd := "komorebic.exe"
        for arg in args
            cmd .= " " (InStr(arg, " ") ? Quote(arg) : arg)
        return cmd
    }
}
