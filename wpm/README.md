# wpm desktop

[wpm](https://github.com/LGUG2Z/wpm) units that start the Windows desktop
(komorebi, yasb, AutoHotkey, Flow Launcher) at logon and keep it alive,
including apps that replace their own process when they reload, restart or
update.

| File | Purpose |
| --- | --- |
| `watchdog.ps1` | The one watchdog script every unit runs. |
| `komorebi.toml` | komorebi, elevated, through the `komorebi` scheduled task. |
| `yasb.toml` | yasb: restart if it exits or its bar windows hang. Requires komorebi. |
| `autohotkey.toml` | The primary AutoHotkey script (UIA build). |
| `flowlauncher.toml` | Flow Launcher. |
| `desktop.toml` | Starts all of the above by hand: `wpmctl start desktop`. |
| `install-tasks.ps1` | Scheduled tasks: `wpmd` at logon, and the elevated `komorebi` task. |
| `tests/Watchdog.Tests.ps1` | Pester tests: `Invoke-Pester tests/Watchdog.Tests.ps1`. |

## Why wpm doesn't run yasb, AutoHotkey and Flow Launcher directly

Two things in wpm's source (`wpm/src/unit.rs`) rule out a plain unit per app:

1. **The healthcheck only runs once, at startup.** wpm checks a unit
   right after starting it and never again. After that it only notices
   when the process exits, so it can't detect a lockup.
2. **wpm tracks a PID, and these apps change their PID.** yasb's reload
   (tray, `yasbc reload`, `watch_config`, monitor changes) starts a new
   detached `yasb.exe` and exits the old one. Flow Launcher does the same on
   "Restart Flow Launcher", plugin installs and updates; AutoHotkey can on a
   script reload. wpm sees its child exit and loses track of the new one:
   - With `Restart = "OnFailure"`, wpm marks the unit stopped and stops
     watching the new instance.
   - With `Restart = "Always"`, wpm starts a second copy. The app's
     single-instance check makes that copy exit (or replace the real one),
     and the unit ends up failed or flapping.

So wpm supervises `watchdog.ps1`, and the watchdog finds the app **by
process name**, never by PID. When a reload swaps the process, the watchdog
just sees a new one.

## What the watchdog does

Every `-IntervalSec` seconds (default 5):

- **The pause file exists:** it does nothing (see below).
- **The app isn't running:** on the watchdog's first check it starts the
  app immediately. Later, it waits `-MissingGraceSec` (default 10) in case
  a reload or manual restart is in progress, then starts it.
- **The app is locked up** (only with `-HangChecks` > 0): it asks Windows
  whether each visible app window is "Not Responding" (`IsHungAppWindow`,
  the same test that greys out a frozen window). If so on `-HangChecks`
  checks in a row, it force-kills the app and starts it again. It skips
  this for `-StartupGraceSec` (default 45) after the app starts, so a slow
  startup isn't treated as a hang.

| Parameter | Meaning |
| --- | --- |
| `-Name` | Unit name; the pause file is `%LOCALAPPDATA%\wpm\<Name>-watchdog.pause`. |
| `-ProcessName` | Process name without `.exe`, as `Get-Process` shows it. |
| `-Exe`, `-ArgumentList`, `-WorkingDirectory` | How to start the app. If `-Exe` goes missing, the path of the last-seen running process is used. |
| `-WindowClass`, `-WindowTitlePrefix` | Only count processes owning a matching top-level window (title match ignores case). |
| `-IntervalSec`, `-MissingGraceSec` | Check interval and missing grace. |
| `-HangChecks`, `-StartupGraceSec` | Hang detection; `0` (default) turns it off. |

Output goes to the unit's log: `wpmctl log <unit>`.

## The units

**yasb** checks every 10s with a 20s missing grace and hang detection on
(3 checks, about 30s). yasb's own autostart can stay on or off: if yasb is
already running when the watchdog starts, the watchdog takes it over.

**AutoHotkey** runs `~/.config/autohotkey/autohotkey.ahk` with the v2 UIA
interpreter. The UIA build runs at a higher integrity level, so a
non-elevated watchdog can't read its command line (it comes back empty) or
kill it. Instead the script is identified by its hidden AutoHotkey main
window, titled `<script path> - AutoHotkey v<version>`
(`-WindowClass AutoHotkey -WindowTitlePrefix "<script path> - AutoHotkey"`),
which also tells it apart from other AutoHotkey scripts. Keep the script
path in the `.toml` in backslash form so it matches the title.

**Flow Launcher** is started through `%LOCALAPPDATA%\FlowLauncher\Flow.Launcher.exe`,
the Squirrel stub, not `app-x.y.z\Flow.Launcher.exe`, so updates don't break
the path. Flow's own "Start Flow Launcher on system startup" setting must
stay **off** (`StartFlowLauncherOnSystemStartup: false` in its
`Settings.json`); otherwise its `HKCU\...\Run` entry launches it at logon too.

To supervise another app, copy a `.toml` and change the unit `Name`,
`-Name`, `-ProcessName` and `-Exe`.

**komorebi** is the exception: it keeps its PID and reloads its config in
place, so wpm tracks it directly, with no watchdog. It has to run elevated
to manage admin windows, but wpmd isn't elevated, and running wpmd elevated
would elevate yasb, AutoHotkey and Flow Launcher too (everything launched
from Flow would run as admin). So `install-tasks.ps1` registers a `komorebi`
task that runs elevated and has no trigger. The unit starts it with
`schtasks /Run /TN komorebi` (no UAC prompt), uses `Kind = "Forking"` and a
`Target = "komorebi.exe"` healthcheck to adopt the elevated process by name,
and stops it with `komorebic stop` (wpm can't kill an elevated process
itself). `Restart = "OnFailure"` brings it back after a crash or a forced
kill (exit code -1), but not after a deliberate `komorebic stop` (exit 0).

On a cold boot komorebi can take 10s or more to appear. `RetryLimit = 20` on
`ExecStart` gives it about 40s (20 checks, 2s apart) before wpm gives up;
re-running the task while it's still starting does nothing. Without it, wpm
gave up after about 10s, and yasb, which requires komorebi, was never
started.

`komorebic fetch-asc` isn't run at startup: it's a blocking network call at
logon. Run it by hand when you want to update `applications.json`.

## Startup order

Every unit except `desktop` has `Autostart = true`, so one unit failing its
healthcheck can't stop the others from starting (wpm stops starting a unit
at its first failed dependency). `Requires` still sets the order:
autohotkey, then komorebi, then yasb. Flow Launcher is independent.

## Stopping an app on purpose

Reloads and quick restarts are safe with the watchdog running. To keep an
app **stopped**, pause its watchdog first, or it will start the app again
after the missing grace:

```powershell
# pause (the watchdog keeps running but does nothing)
New-Item -ItemType File -Force "$env:LOCALAPPDATA\wpm\yasb-watchdog.pause"

# resume
Remove-Item "$env:LOCALAPPDATA\wpm\yasb-watchdog.pause"
```

Use `autohotkey-watchdog.pause` or `flowlauncher-watchdog.pause` for the
others. `wpmctl stop <unit>` also works, but note that this wpm build
restarts `Restart = "Always"` units after an explicit stop. komorebi has no
watchdog: `wpmctl stop komorebi` or `komorebic stop` keeps it stopped.

## Install

`~/.config/wpm` is the default `wpmctl units` directory; the units expect
`watchdog.ps1` there.

```powershell
wpmctl reload
wpmctl start desktop     # or one unit: komorebi, yasb, autohotkey, flowlauncher
wpmctl log yasb          # watch what it's doing
```

`Autostart = true` starts each unit when `wpmd` starts, but wpm doesn't
start `wpmd` at login. Run `install-tasks.ps1` from an elevated shell (`-Start`
also launches wpmd now). It registers:

- `wpmd`: runs at logon, hidden and **not** elevated.
- `komorebi`: elevated, with no trigger; only the komorebi unit starts it.

Both tasks run at priority 4. Task Scheduler's default of 7 runs the task,
and every process it starts, at BelowNormal priority, which slows logon and
leaves yasb and Flow Launcher less responsive.

Remove any other autostart entries (Startup folder shortcuts, the apps' own
"start at logon" settings, komorebi's own logon task) for apps these units
manage.
