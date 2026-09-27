# [Feature request] Ongoing healthchecks, hang detection, and following processes that respawn under a new PID

## Summary

I'd like wpm to keep a long-running GUI app alive. Today three gaps
prevent that:

1. **Healthchecks only run at startup.** After a unit passes its first
   check, wpm only notices if the process exits.
2. **wpm can't detect a hung process.** A process that is still running
   but not responding passes every check wpm has.
3. **wpm loses track of apps that restart themselves.** Some apps reload
   by starting a new copy of themselves and exiting. wpm then treats the
   unit as stopped or failed, while the new copy runs unmonitored.

This issue proposes three opt-in additions, one per gap. Each is useful
on its own, and existing unit files keep working unchanged.

## Motivating example: yasb

[yasb](https://github.com/amnweb/yasb) is a Qt status bar for Windows. It
sometimes crashes and sometimes freezes. I wanted a unit that keeps it
running, but a plain `Simple` unit doesn't work:

- **Reload changes the PID.** yasb reloads when you pick Reload in the
  tray, run `yasbc reload`, save the config with `watch_config` on, or
  plug in or unplug a monitor. Each reload calls
  `QProcess.startDetached(sys.executable, args)` and then quits the old
  process with exit code 0
  ([`controller.py`](https://github.com/amnweb/yasb/blob/d6d1e6d553b0aac34fd5fb34928d3ca82b8d055f/src/core/utils/controller.py#L16-L39)).
  - With `Restart = "OnFailure"`, wpm records the unit as terminated.
    The new yasb keeps running, but nothing watches it.
  - With `Restart = "Always"`, wpm starts another yasb. yasb holds a
    single-instance mutex
    ([`main.py`](https://github.com/amnweb/yasb/blob/d6d1e6d553b0aac34fd5fb34928d3ca82b8d055f/src/main.py#L29-L55)),
    so wpm's copy exits with code 1 and the unit fails its healthcheck.
    The unit is marked failed while yasb is actually running.
- **Freezes aren't caught.** When yasb's UI thread locks up, the
  process stays alive, so the startup liveness check it already passed
  is never repeated.

My workaround is a wpm unit that runs a PowerShell watchdog. The watchdog
polls for `yasb.exe` by name, calls `IsHungAppWindow` on its visible
windows, and kills and restarts it when needed. That works, but it
duplicates what wpm is for. Other apps would hit the same problems:
anything that updates or reloads itself by respawning (many Electron and
Qt apps), and anything whose UI thread can freeze.

## Current behavior

The links below point to commit
[`3872830`](https://github.com/LGUG2Z/wpm/tree/3872830704fb7c625281cbc6a579ad58ca551914).

- **Healthchecks run once.** `Definition::healthcheck` runs when a unit
  starts. It returns early if the unit is already in `running`
  (["we don't want to run redundant healthchecks"](https://github.com/LGUG2Z/wpm/blob/3872830704fb7c625281cbc6a579ad58ca551914/wpm/src/unit.rs#L672-L676)).
  Nothing runs it again later.
- **Exit is the only runtime signal.** `monitor_child` blocks on
  `child.wait()` and applies `Restart` when the process exits
  ([unit.rs L800-L884](https://github.com/LGUG2Z/wpm/blob/3872830704fb7c625281cbc6a579ad58ca551914/wpm/src/unit.rs#L800-L884)).
- **Command healthchecks have no timeout.** The check runs
  `command.spawn()?.wait()?`
  ([unit.rs L699](https://github.com/LGUG2Z/wpm/blob/3872830704fb7c625281cbc6a579ad58ca551914/wpm/src/unit.rs#L699)).
  A check command that talks to a hung service can block the check
  forever.
- **A PID is tracked for the life of the unit.** `Child::Pid` and the
  `Process.Target` lookup
  ([unit.rs L735-L757](https://github.com/LGUG2Z/wpm/blob/3872830704fb7c625281cbc6a579ad58ca551914/wpm/src/unit.rs#L735-L757))
  can already adopt a process by image name. They only do it once, at
  startup, and the adopted PID is then tracked until it exits.

## Proposal

### 1. Periodic healthchecks

Add optional fields to both `Healthcheck.Command` and
`Healthcheck.Process`:

| Field              | Default         | Meaning |
| ------------------ | --------------- | ------- |
| `IntervalSec`      | none (off)      | Re-run the healthcheck every N seconds while the unit is running. |
| `FailureThreshold` | `3`             | Number of consecutive failures before wpm acts. |
| `StartupGraceSec`  | `0`             | Skip periodic checks for N seconds after a start or a respawn (see section 3). |
| `TimeoutSec`       | none            | `Command` only. Kill the check command and count a failure if it runs longer than N seconds. |
| `OnFailure`        | `"Restart"`     | `"Restart"` kills the process tree and starts the unit again, going through the `Restart` policy and `RestartSec`. `"Log"` only logs the failure. |

When a unit fails its periodic check `FailureThreshold` times in a row,
wpm logs `{name}: failed periodic healthcheck (n/n)` and applies
`OnFailure`. Leaving `IntervalSec` unset keeps today's behavior.

### 2. Hang detection for GUI processes

Add `Responsive = true` to `Healthcheck.Process`. When set, the check
fails if any visible top-level window owned by the tracked PID is hung.

On Windows, `IsHungAppWindow(hwnd)` gives the same verdict as the "Not
Responding" title bar: the window hasn't processed messages for about 5
seconds. An alternative that allows a custom timeout is
`SendMessageTimeoutW(hwnd, WM_NULL, 0, 0, SMTO_ABORTIFHUNG, timeout, …)`.
The windows to check can be listed with `EnumWindows` and
`GetWindowThreadProcessId`. If the process has no visible windows, the
responsiveness part of the check passes, so tray-only or hidden states
are never treated as hung.

This only makes sense together with section 1, because a hang happens
after startup.

### 3. Following a process that respawns itself

Add an optional `[Service.Track]` table:

```toml
[Service.Track]
Follow = "Descendant"   # "Pid" (default, today's behavior) | "Descendant" | "ImageName"
ReacquireSec = 15       # how long to wait for a replacement after the tracked PID exits
```

When the tracked PID exits and `Follow` is not `"Pid"`, wpm first waits
up to `ReacquireSec` for a replacement process:

- **`Descendant`:** a process whose parent PID is the one that exited,
  running the same executable. Windows doesn't reparent orphaned
  processes, so the respawned process keeps the old PID as its parent
  even after the old process exits. To avoid matching a reused PID,
  also require that the candidate was created after the exited process.
  This is the strictest option, and it covers yasb and any other app
  that respawns with `startDetached`, `CreateProcess`, or `ShellExecute`.
- **`ImageName`:** any process with the same executable path, or with
  the same file name if a `Process.Target` is set. This also covers apps
  that respawn through a launcher or updater.

If wpm finds a replacement, it:

- logs `{name}: process <old> respawned as <new>`
- updates the unit's `ProcessState` in place
- starts monitoring the new PID
- skips the `Restart` policy, doesn't count the respawn as a failure,
  and doesn't run `ExecStopPost`
- restarts the `StartupGraceSec` window from section 1

If no replacement appears, wpm handles the exit as it does today: it
runs `ExecStopPost` and then applies `Restart`. An intentional quit,
such as tray → Exit, has no replacement, so it still ends up as
`terminated`, or gets restarted under `Restart = "Always"`.

### 4. Status and visibility

Add the following to `wpmctl status <unit>` and `wpmctl state`:

- current PID
- respawn count
- time and result of the last periodic check
- number of consecutive failures

This lets users tell apart a unit that wpm restarted, one that reloaded
itself, and one that is currently failing its checks.

### Crash-loop protection (optional, related)

With periodic checks able to trigger restarts, a limit like systemd's
`StartLimitIntervalSec` / `StartLimitBurst` would stop a broken config
from restarting an app every few seconds forever. For example:

```toml
StartLimitBurst = 5
StartLimitIntervalSec = 300
```

After the limit is hit, wpm would stop restarting the unit and mark it
failed.

## Example unit using all of the above

```toml
[Unit]
Name = "yasb"
Description = "Status bar"

[Service]
Kind = "Simple"
Autostart = true
Restart = "Always"
RestartSec = 5

[Service.ExecStart]
Executable = "C:/Program Files/YASB/yasb.exe"

[Service.Track]
Follow = "Descendant"
ReacquireSec = 15

[Service.Healthcheck.Process]
DelaySec = 2
IntervalSec = 10
FailureThreshold = 3
StartupGraceSec = 45
Responsive = true
```

Expected behavior with this unit:

| Event | wpm today | With this proposal |
| ----- | --------- | ------------------ |
| yasb crashes | Restarted | Restarted |
| User reloads yasb (new PID, old exits 0) | Restarts a duplicate, which yasb's mutex rejects, and the unit is marked failed | Follows the new PID and doesn't restart anything |
| yasb UI thread freezes | Not detected | Killed and restarted after about 30 s |
| User quits yasb from the tray | Restarted (`Always`) | Unchanged: restarted, or left stopped under `OnFailure` |

## Compatibility

Every new field is optional, and the defaults reproduce current
behavior:

- `IntervalSec` unset means no periodic checks.
- `Responsive` defaults to `false`.
- `Follow` defaults to `"Pid"`.

No existing unit file changes meaning. `schema.unit.json` would gain the
new optional properties.

## Implementation notes

These are suggestions and I'm happy to defer to how you'd rather
structure it:

- A single scheduler thread in `wpmd` could run the periodic checks for
  all units, instead of one thread per unit.
- Replacement detection could reuse the `sysinfo` refresh that the
  `Process.Target` path already does, filtered by `parent()` and
  `start_time()`.
- A respawn-follow should keep the unit in `running` for the whole
  handover. That way `wpmctl start` of a dependent unit doesn't see a
  gap and try to restart the dependency.

I can test a branch against yasb, and I can share the watchdog script I
use today as a reference implementation of the hang check.
