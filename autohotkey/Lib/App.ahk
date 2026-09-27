#Requires AutoHotkey v2.0

class App {
    __New(scriptPath) {
        this.scriptPath := scriptPath
        this.startupLink := A_Startup "\\" RegExReplace(A_ScriptName, "\\.ahk$", "") ".lnk"
    }

    Start() {
        A_IconTip := "Autorun script for Windows"
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Edit script", this.EditScript.Bind(this))
        A_TrayMenu.Add("Run at startup", this.ToggleStartup.Bind(this))
        if this.HasOwnedStartupShortcut()
            A_TrayMenu.Check("Run at startup")
        A_TrayMenu.Add()
        A_TrayMenu.Add("Reload", this.ReloadScript.Bind(this))
        A_TrayMenu.Add("Exit", this.Exit.Bind(this))
    }

    EditScript(*) {
        Edit()
    }

    ReloadScript(*) {
        Reload()
    }

    Exit(*) {
        ExitApp()
    }

    HasOwnedStartupShortcut(*) {
        if !FileExist(this.startupLink)
            return false

        target := ""
        arguments := ""
        try FileGetShortcut(this.startupLink, &target, , &arguments)
        catch Error
            return false

        return target = A_AhkPath && arguments = Quote(this.scriptPath)
    }

    CreateStartupShortcut(*) {
        try FileCreateShortcut(A_AhkPath, this.startupLink, A_ScriptDir, Quote(this.scriptPath), "Start " A_ScriptName " with Windows")
        catch Error as err {
            MsgBox("Could not enable startup: " err.Message, "Startup shortcut", "Iconx")
            return false
        }
        return true
    }

    RemoveStartupShortcut(*) {
        if !this.HasOwnedStartupShortcut()
            return false

        try FileDelete(this.startupLink)
        catch Error as err {
            MsgBox("Could not disable startup: " err.Message, "Startup shortcut", "Iconx")
            return false
        }
        return true
    }

    ToggleStartup(*) {
        if this.HasOwnedStartupShortcut() {
            if this.RemoveStartupShortcut() && !this.HasOwnedStartupShortcut()
                A_TrayMenu.Uncheck("Run at startup")
        } else {
            if FileExist(this.startupLink) {
                MsgBox("The startup shortcut already exists but is not owned by this script. It was left unchanged.", "Startup shortcut", "Icon!")
                return
            }

            if this.CreateStartupShortcut() && this.HasOwnedStartupShortcut()
                A_TrayMenu.Check("Run at startup")
        }
    }
}

Quote(value) {
    return '"' value '"'
}
