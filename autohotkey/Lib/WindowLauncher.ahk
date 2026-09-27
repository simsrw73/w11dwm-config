#Requires AutoHotkey v2.0

; Activates the window matching app.Criteria, launching app.Command if none exists.
;
; app fields:
;   Criteria    WinTitle to find the window                         (required)
;   Command     what to Run when no window exists                   (required)
;   Exclude     ExcludeTitle passed to WinExist                     (optional)
;   MatchMode   SetTitleMatchMode for Criteria/Exclude, default 1   (optional)
;   Popup       keep on top and center on the active monitor        (optional)
;   Timeout     seconds to wait for a launched window, default 10   (optional)
class WindowLauncher {
    ; AutoHotkey treats windows komorebi cloaked on other workspaces as hidden, so search
    ; hidden windows too and keep the first one that is really shown (WS_VISIBLE). That
    ; skips the invisible helper windows tray apps keep around.
    static Find(app) {
        static WS_VISIBLE := 0x10000000
        SetTitleMatchMode(app.HasOwnProp("MatchMode") ? app.MatchMode : 1)
        DetectHiddenWindows(true)
        for hwnd in WinGetList(app.Criteria, , app.HasOwnProp("Exclude") ? app.Exclude : "")
            if WinGetStyle(hwnd) & WS_VISIBLE
                return hwnd
        return 0
    }

    static WaitFor(app, timeoutSeconds) {
        deadline := A_TickCount + timeoutSeconds * 1000
        while A_TickCount < deadline {
            if hwnd := this.Find(app)
                return hwnd
            Sleep(100)
        }
        return 0
    }

    static ActivateOrRun(app) {
        popup := app.HasOwnProp("Popup") && app.Popup
        anchor := this.ActiveMonitorWorkArea()

        if !(hwnd := this.Find(app)) {
            try Run(app.Command)
            catch Error as err {
                MsgBox("Could not start " app.Command ".`n`n" err.Message, "AutoHotkey", "Iconx")
                return false
            }

            timeout := app.HasOwnProp("Timeout") ? app.Timeout : 10
            if !(hwnd := this.WaitFor(app, timeout)) {
                TrayTip("Started " app.Command ", but its window did not appear in " timeout " seconds.", "AutoHotkey")
                return false
            }
        }

        this.Activate(hwnd, popup ? anchor : "")
        return true
    }

    ; Brings hwnd forward, switching komorebi to its workspace first when the window is
    ; cloaked on a workspace that isn't showing. Komorebi doesn't follow plain activation.
    static Activate(hwnd, popupArea := "") {
        target := "ahk_id " hwnd
        if this.IsCloaked(hwnd) && (workspace := Komorebi.WorkspaceOf(hwnd))
            Komorebi.FocusWorkspace(workspace)

        if WinGetMinMax(target) = -1
            WinRestore(target)

        if popupArea {
            WinSetAlwaysOnTop(1, target)
            this.CenterIn(target, popupArea)
        }
        WinActivate(target)
    }

    static IsCloaked(hwnd) {
        static DWMWA_CLOAKED := 14
        cloaked := 0
        DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", DWMWA_CLOAKED, "UInt*", &cloaked, "UInt", 4)
        return cloaked != 0
    }

    ; Work area of the monitor showing the active window (or the mouse, if nothing is active).
    static ActiveMonitorWorkArea() {
        x := y := 0
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "A")
            x := wx + ww // 2, y := wy + wh // 2
        } catch {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&x, &y)
        }

        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            if x >= left && x < right && y >= top && y < bottom
                return { Left: left, Top: top, Right: right, Bottom: bottom }
        }
        MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
        return { Left: left, Top: top, Right: right, Bottom: bottom }
    }

    static CenterIn(target, area) {
        WinGetPos(, , &w, &h, target)
        WinMove(area.Left + (area.Right - area.Left - w) // 2, area.Top + (area.Bottom - area.Top - h) // 2, , , target)
    }
}
