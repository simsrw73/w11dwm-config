#Requires AutoHotkey v2.0

; Directional window focus for when komorebi isn't running. Windows are placed by their
; visible top-left corner. Focus moves to the nearest visible window that way on the
; current monitor, or crosses to the next monitor that way when there is none (like
; komorebi). Window list and geometry come from Legend's LegendWindows.
class WindowFocus {
    static Move(direction) => LegendWindows.InPhysicalPixels(() => this.MoveNow(direction))

    static MoveNow(direction) {
        if !(active := WinExist("A"))
            return
        from := LegendWindows.Bounds(active)
        monitors := LegendWindows.Monitors()
        current := monitors[LegendWindows.MonitorAt(monitors, from.X, from.Y)]

        windows := LegendWindows.List({Exclude: active, VisibleOnly: true, Minimized: false})
        onCurrent := []
        for w in windows
            if w.Monitor = current.Index
                onCurrent.Push(w)

        target := this.Best(onCurrent, direction, from.X, from.Y, true)
        if !target {
            if !(next := this.NextMonitor(monitors, current, direction))
                return
            onNext := []
            for w in windows
                if w.Monitor = next.Index
                    onNext.Push(w)
            entry := this.EntryPoint(next, direction, from)
            target := this.Best(onNext, direction, entry.X, entry.Y, false)
        }
        if target
            WinActivate("ahk_id " target.Hwnd)
    }

    ; Nearest monitor lying wholly beyond the current one in that direction.
    static NextMonitor(monitors, current, direction) {
        beyond := []
        for m in monitors {
            switch direction {
                case "right": ok := m.Left >= current.Right
                case "left": ok := m.Right <= current.Left
                case "down": ok := m.Top >= current.Bottom
                case "up": ok := m.Bottom <= current.Top
            }
            if ok
                beyond.Push({monitor: m, X: m.Left, Y: m.Top})
        }
        best := this.Best(beyond, direction, current.Left, current.Top, false)
        return best ? best.monitor : ""
    }

    ; Where you enter the next monitor: its near edge, level with the active window.
    static EntryPoint(m, direction, from) {
        switch direction {
            case "right": return {X: m.Left, Y: from.Y}
            case "left": return {X: m.Right, Y: from.Y}
            case "down": return {X: from.X, Y: m.Top}
            case "up": return {X: from.X, Y: m.Bottom}
        }
    }

    ; Item nearest (x, y) in the direction, preferring ones in line with it. With strict,
    ; only items strictly beyond (x, y) in that direction qualify.
    static Best(items, direction, x, y, strict) {
        best := "", bestScore := ""
        for item in items {
            dx := item.X - x, dy := item.Y - y
            switch direction {
                case "right": primary := dx, cross := dy
                case "left": primary := -dx, cross := dy
                case "down": primary := dy, cross := dx
                case "up": primary := -dy, cross := dx
            }
            if strict && primary <= 0
                continue
            score := Abs(primary) + 2 * Abs(cross)
            if bestScore = "" || score < bestScore
                best := item, bestScore := score
        }
        return best
    }
}
