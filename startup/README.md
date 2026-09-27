# What starts at logon

| Tool | How it starts | Elevated? |
| --- | --- | --- |
| komorebi | Scheduled task `komorebi` → `komorebic-no-console.exe start --config %USERPROFILE%\.config\komorebi\komorebi.json` ([install-komorebi-task.ps1](install-komorebi-task.ps1)) | Yes |
| wpmd | Scheduled task `wpmd` → `conhost --headless wpmd.exe` ([../wpm/install-wpmd-task.ps1](../wpm/install-wpmd-task.ps1)) | No |
| yasb | yasb's own autostart (Startup registry entry). The `yasb-watchdog` wpm unit starts it if it's missing and restarts it if it hangs, see [../wpm/README.md](../wpm/README.md) | No |
| AutoHotkey | Startup-folder shortcut `autohotkey.ahk.lnk` → `AutoHotkey64_UIA.exe "%USERPROFILE%\.config\AutoHotKey\autohotkey.ahk"`. The script's tray menu has a "Run at startup" toggle that creates or removes the shortcut (`Lib/App.ahk`) | No (UIA build) |
| Flow Launcher | Flow Launcher's own "Start on system startup" setting | No |

## Notes

- **Why komorebi is elevated:** a non-elevated window manager can't move or resize
  elevated windows (Task Manager, regedit, installers), so komorebi runs with
  `RunLevel Highest` from a scheduled task, which avoids a UAC prompt at logon.
- **Why AutoHotkey uses the `_UIA` build:** `AutoHotkey64_UIA.exe` has UI Access. Its
  hotkeys keep working while an elevated window has focus, but it doesn't run
  the whole script as admin. The shortcut has to point at the `_UIA` exe for
  this to work.
- **Why wpmd is *not* elevated:** it (through the watchdog) relaunches yasb, and an elevated
  yasb breaks drag and drop and input with normal windows.
- **Environment:** `KOMOREBI_CONFIG_HOME` = `%USERPROFILE%\.config\komorebi` (user
  variable). `komorebi.json` uses it to find `applications.json`.
- komorebi's own bar and whkd are disabled. yasb is the bar (`run_ahk: false`, `run_whkd: false`
  in the yasb komorebi config), and AutoHotkey handles all the key bindings.

## Setup on a new machine

```powershell
[Environment]::SetEnvironmentVariable('KOMOREBI_CONFIG_HOME', "$HOME\.config\komorebi", 'User')
./startup/install-komorebi-task.ps1 -Start     # run from an elevated shell
./wpm/install-wpmd-task.ps1 -Start
```

Then turn on autostart in yasb and Flow Launcher, and run the AHK script once and check
**Run at startup** in its tray menu.
