# yasb watchdog for wpm

A [wpm](https://github.com/LGUG2Z/wpm) unit that restarts
[yasb](https://github.com/amnweb/yasb) when it stops running or locks up.
It doesn't get in the way when you reload yasb yourself.

| File                 | Purpose                                                   |
| -------------------- | --------------------------------------------------------- |
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
