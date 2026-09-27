<#
.SYNOPSIS
    Keeps yasb running and responsive. Meant to be run by wpm (yasb-watchdog.toml).

.DESCRIPTION
    Every -IntervalSec seconds:
      * yasb.exe not running for longer than -MissingGraceSec  -> start it
      * a visible yasb window reports "not responding" on -HangChecks
        consecutive checks                                       -> kill and start it
      * pause file exists                                        -> do nothing

    yasb is tracked by process name, not PID, so yasb's own reloads (tray
    "Reload", `yasbc reload`, watch_config, monitor changes), which replace
    the process with a new one, are left alone.

    Output goes to the wpm log: `wpmctl log yasb-watchdog`.
#>
param(
    [string] $YasbExe = '',
    [int] $IntervalSec = 10,
    [int] $MissingGraceSec = 20,
    [int] $StartupGraceSec = 45,
    [int] $HangChecks = 3,
    [string] $PauseFile = (Join-Path $env:LOCALAPPDATA 'wpm\yasb-watchdog.pause')
)

$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class YasbWindows {
    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsHungAppWindow(IntPtr hWnd);

    // Returns { visible window count, hung window count } for the given PIDs.
    public static int[] Check(int[] pids) {
        var owners = new HashSet<uint>();
        foreach (var p in pids) owners.Add((uint)p);
        int visible = 0, hung = 0;
        EnumWindows((hWnd, _) => {
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            if (owners.Contains(pid) && IsWindowVisible(hWnd)) {
                visible++;
                if (IsHungAppWindow(hWnd)) hung++;
            }
            return true;
        }, IntPtr.Zero);
        return new[] { visible, hung };
    }
}
'@

function Write-Log([string] $Message) {
    Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date), $Message)
}

function Resolve-YasbExe {
    if ($script:YasbExe -and (Test-Path $script:YasbExe)) { return $script:YasbExe }
    $cmd = Get-Command yasb.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
            (Join-Path $env:ProgramFiles 'YASB\yasb.exe'),
            (Join-Path $env:LOCALAPPDATA 'Programs\YASB\yasb.exe'))) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Start-Yasb {
    $exe = Resolve-YasbExe
    if (-not $exe) {
        Write-Log 'ERROR: cannot find yasb.exe; pass -YasbExe in yasb-watchdog.toml'
        return
    }
    Write-Log "starting $exe"
    try { Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) }
    catch { Write-Log "ERROR: failed to start yasb: $_" }
}

Write-Log "watching yasb (interval ${IntervalSec}s, pause file $PauseFile)"

$missingSince = $null
$hungCount = 0
$paused = $false

while ($true) {
    if (Test-Path $PauseFile) {
        if (-not $paused) { Write-Log 'paused'; $paused = $true }
        $missingSince = $null
        $hungCount = 0
        Start-Sleep -Seconds $IntervalSec
        continue
    }
    if ($paused) { Write-Log 'resumed'; $paused = $false }

    $procs = @(Get-Process -Name yasb -ErrorAction SilentlyContinue)

    if ($procs.Count -eq 0) {
        $hungCount = 0
        if (-not $missingSince) {
            $missingSince = Get-Date
            Write-Log "yasb not running; restarting in ${MissingGraceSec}s unless it comes back"
        }
        elseif (((Get-Date) - $missingSince).TotalSeconds -ge $MissingGraceSec) {
            Start-Yasb
            $missingSince = $null
        }
        Start-Sleep -Seconds $IntervalSec
        continue
    }

    $missingSince = $null
    # Remember where the running yasb lives so a restart uses the same install.
    if (-not $YasbExe -and $procs[0].Path) { $YasbExe = $procs[0].Path }

    # Don't judge a process that is still starting up (or just reloaded).
    $newest = ($procs | Sort-Object StartTime -Descending | Select-Object -First 1).StartTime
    if (((Get-Date) - $newest).TotalSeconds -lt $StartupGraceSec) {
        $hungCount = 0
        Start-Sleep -Seconds $IntervalSec
        continue
    }

    $visible, $hung = [YasbWindows]::Check([int[]]($procs | ForEach-Object Id))
    if ($hung -gt 0) {
        $hungCount++
        Write-Log "yasb not responding ($hung of $visible windows), check $hungCount/$HangChecks"
        if ($hungCount -ge $HangChecks) {
            Write-Log 'yasb locked up; killing and restarting'
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Yasb
            $hungCount = 0
        }
    }
    elseif ($hungCount -gt 0) {
        Write-Log 'yasb responding again'
        $hungCount = 0
    }

    Start-Sleep -Seconds $IntervalSec
}
