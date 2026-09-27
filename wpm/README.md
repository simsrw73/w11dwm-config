# wpm watchdogs

[wpm](https://github.com/LGUG2Z/wpm) watchdog units for long-running Windows
desktop programs that can replace their own process during a reload.

| File                 | Purpose                                                   |
| -------------------- | --------------------------------------------------------- |
| autohotkey-watchdog.toml | wpm unit for the reload-safe AutoHotkey watchdog. |
| autohotkey-watchdog.ps1 | Starts the primary AutoHotkey v2 script if it is absent. |
| `app-watchdog.ps1` | Generic watchdog: starts an app by exe if no process with its name is running. |
| `flowlauncher-watchdog.toml` | wpm unit running `app-watchdog.ps1` for Flow Launcher. |
| `yasb-watchdog.toml` | wpm unit. Starts with `wpmd` and restarts the watchdog if it dies. |
| `yasb-watchdog.ps1`  | The watchdog. Starts yasb if it's missing and kills and restarts it if it hangs. |

## Why wpm doesn't run yasb directly

Two things in wpm's source (`wpm/src/unit.rs`) rule out a plain
`yasb.toml` unit:

1. **The healthcheck only runs once, at startup.** wpm checks a unit
   right after starting it and never again. After that it only notices
   when the process exits, so it can't detect a lockup.
2. **wpm tracks a PID, and yasb's reload changes the PID.** A reload from
   the tray, from `yasbc reload`, from `watch_config`, or from a monitor
   change starts a new detached `yasb.exe` and exits the old one with code 0
   (`src/core/utils/controller.py`). wpm sees its child exit and loses
   track of the new one:
   - With `Restart = "OnFailure"`, wpm marks yasb as stopped and stops
     watching the new instance.
   - With `Restart = "Always"`, wpm starts a second copy. yasb's
     single-instance mutex makes that copy exit with code 1, and the unit
     ends up failed while the real yasb runs unwatched.

So wpm supervises the watchdog, and the watchdog finds yasb **by process
name**. When a reload swaps the process, the watchdog just sees a new
`yasb.exe`.

## What the watchdog does

It runs a check every 10 seconds:

- **yasb isn't running:** it waits 20 seconds (`-MissingGraceSec`) in case
  a reload or a manual restart is in progress. If yasb is still gone, it
  starts it.
- **yasb is locked up:** it asks Windows whether each visible yasb window
  is "Not Responding" (`IsHungAppWindow`, the same test that greys out a
  frozen window). If the answer is yes on 3 checks in a row (about 30
  seconds, `-HangChecks`), it force-kills yasb and starts it again. It
  skips this check for the first 45 seconds after yasb starts
  (`-StartupGraceSec`), so a slow startup isn't treated as a hang.
- **The pause file exists:** it does nothing (see below).

You can change the defaults with the commented-out arguments in
`yasb-watchdog.toml`.

## Restarting yasb while you configure it

You don't need to do anything special. All of these are safe with the
watchdog running:

- Saving `config.yaml` or `styles.css` with `watch_config` or
  `watch_stylesheet` turned on
- Tray → Reload YASB, or `yasbc reload`
- `yasbc stop` followed by `yasbc start` within about 20 seconds

To keep yasb **stopped** for a while, pause the watchdog first. Otherwise
it starts yasb again after 20 seconds:

```powershell
# pause (the watchdog keeps running but does nothing)
New-Item -ItemType File -Force "$env:LOCALAPPDATA\wpm\yasb-watchdog.pause"

# resume
Remove-Item "$env:LOCALAPPDATA\wpm\yasb-watchdog.pause"
```

You can also stop the unit with `wpmctl stop yasb-watchdog` and start it
again with `wpmctl start yasb-watchdog`. Stopping the watchdog doesn't
stop yasb.

## Install

```powershell
Copy-Item yasb-watchdog.toml, yasb-watchdog.ps1 (wpmctl units)
wpmctl reload
wpmctl start yasb-watchdog
wpmctl log yasb-watchdog   # watch what it's doing
```

The unit expects the script at `~/.config/wpm/yasb-watchdog.ps1`, which is
the default `wpmctl units` directory. If yours is somewhere else, change
the `-File` path in the `.toml`.

To find yasb, the watchdog checks these in order:

1. The path of the yasb process that's already running
2. `yasb.exe` on `PATH`
3. `C:\Program Files\YASB\yasb.exe`
4. `%LOCALAPPDATA%\Programs\YASB\yasb.exe`

If it can't find yasb, pass `-YasbExe` in the `.toml`.

`Autostart = true` starts the watchdog when `wpmd` starts, but wpm
doesn't start `wpmd` at login. `install-wpmd-task.ps1` registers a
scheduled task named `wpmd` that runs it at logon, hidden and not elevated
(`-Start` also launches it now). yasb's own autostart can stay on or off: if yasb is already running
when the watchdog starts, the watchdog takes it over.

## AutoHotkey watchdog

The AutoHotkey watchdog launches
C:\Users\simsr\.config\autohotkey\autohotkey.ahk with the v2 UIA
interpreter (AutoHotkey64_UIA.exe). It checks every five seconds and, after the first launch, waits
five seconds before relaunching an absent script.

It identifies the script by its hidden AutoHotkey main window, titled
"<script path> - AutoHotkey v<version>", rather than by PID or command line.
The UIA build runs at a higher integrity level, so a non-elevated watchdog
can't read its command line (it comes back empty). Matching on the command
line made the watchdog think the script was always missing and relaunch it
every tick. Editing or reloading the script may replace the interpreter PID; that is
normal, and the watchdog accepts the replacement process without launching a
second instance.

Install the .toml and .ps1 files in the directory printed by wpmctl units,
then activate the unit:

~~~powershell
wpmctl reload
wpmctl start autohotkey-watchdog
wpmctl status autohotkey-watchdog
wpmctl log autohotkey-watchdog
~~~

To keep AutoHotkey deliberately stopped, pause its watchdog:

~~~powershell
# pause
New-Item -ItemType File -Force "$env:LOCALAPPDATA\wpm\autohotkey-watchdog.pause"

# resume
Remove-Item "$env:LOCALAPPDATA\wpm\autohotkey-watchdog.pause"
~~~

After wpmctl status autohotkey-watchdog shows the unit running, remove the
old autohotkey.ahk.lnk Startup-folder entry. Otherwise both Startup and wpm
can try to launch the script at logon.

## Flow Launcher (generic app watchdog)

`flowlauncher-watchdog.toml` runs `app-watchdog.ps1`, a generic watchdog
that tracks an app **by process name** and starts `-Exe` when no process
named `-ProcessName` has existed for `-MissingGraceSec` (10s) seconds.
Flow Launcher replaces its own process on "Restart Flow Launcher", plugin
installs and updates, so wpm can't supervise it by PID directly.

It launches `%LOCALAPPDATA%\FlowLauncher\Flow.Launcher.exe`, the Squirrel
stub, not `app-x.y.z\Flow.Launcher.exe`, so updates don't break the path.

Flow's own "Start Flow Launcher on system startup" setting must stay **off**
(`StartFlowLauncherOnSystemStartup: false` in its `Settings.json`);
otherwise its `HKCU\...\Run` entry launches it at logon too.

Pause with `%LOCALAPPDATA%\wpm\flowlauncher-watchdog.pause`, the same way
as the other watchdogs. To supervise another self-restarting app, copy
the `.toml` and change `-Name`, `-ProcessName` and `-Exe`.
