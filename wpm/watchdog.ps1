<#
.SYNOPSIS
    Keeps a desktop app running (and optionally responsive). Meant to be run by wpm.

.DESCRIPTION
    Every -IntervalSec seconds:
      * pause file exists                                   -> do nothing
      * app not running for longer than -MissingGraceSec    -> start it
        (at watchdog startup it's started immediately)
      * -HangChecks > 0 and a visible app window is "Not Responding" on
        that many consecutive checks                        -> kill and start it

    The app is found by process name, never by PID, so apps that restart,
    reload or update themselves (replacing their process) are left alone.
    With -WindowClass / -WindowTitlePrefix, only processes that own a
    matching top-level window count. That tells one AutoHotkey script from
    another without reading command lines, which a non-elevated watchdog
    can't do for elevated or UIAccess processes.

    Output goes to the wpm log: `wpmctl log <unit>`.
#>
param(
    # Unit name; used for the pause file.
    [Parameter(Mandatory)] [string] $Name,
    # Process name without .exe, as Get-Process shows it.
    [Parameter(Mandatory)] [string] $ProcessName,
    [Parameter(Mandatory)] [string] $Exe,
    [string[]] $ArgumentList = @(),
    [string] $WorkingDirectory = '',
    [string] $WindowClass = '',
    [string] $WindowTitlePrefix = '',
    [int] $IntervalSec = 5,
    [int] $MissingGraceSec = 10,
    # 0 disables hang detection.
    [int] $HangChecks = 0,
    [int] $StartupGraceSec = 45,
    [string] $PauseFile = (Join-Path $env:LOCALAPPDATA "wpm\$Name-watchdog.pause"),
    [switch] $NoRun
)

$ErrorActionPreference = 'Stop'
$script:LastSeenPath = $null

if (-not ('WatchdogWindows' -as [type])) {
    Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WatchdogWindows {
    public class Info {
        public uint ProcessId; public string Class; public string Title; public bool Visible; public bool Hung;
    }

    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder name, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool IsHungAppWindow(IntPtr hWnd);

    public static List<Info> All() {
        var found = new List<Info>();
        EnumWindows((hWnd, _) => {
            var cls = new StringBuilder(256);
            GetClassName(hWnd, cls, cls.Capacity);
            var title = new StringBuilder(1024);
            GetWindowText(hWnd, title, title.Capacity);
            uint pid;
            GetWindowThreadProcessId(hWnd, out pid);
            found.Add(new Info {
                ProcessId = pid, Class = cls.ToString(), Title = title.ToString(),
                Visible = IsWindowVisible(hWnd), Hung = IsHungAppWindow(hWnd)
            });
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@
}

function Write-WatchdogLog([string] $Message) {
    Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date), $Message)
}

function Get-TopLevelWindow {
    foreach ($w in [WatchdogWindows]::All()) {
        [pscustomobject]@{
            ProcessId = [int] $w.ProcessId; Class = $w.Class; Title = $w.Title
            Visible = $w.Visible; Hung = $w.Hung
        }
    }
}

function Test-WindowMatch($Window) {
    ((-not $WindowClass) -or $Window.Class -eq $WindowClass) -and
    ((-not $WindowTitlePrefix) -or $Window.Title.StartsWith($WindowTitlePrefix, [StringComparison]::OrdinalIgnoreCase))
}

# Returns the watched processes and, if needed, their top-level windows.
function Get-WatchedApp {
    $procs = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    $windows = @()
    if ($procs.Count -gt 0 -and ($WindowClass -or $WindowTitlePrefix -or $HangChecks -gt 0)) {
        $pids = @($procs.Id)
        $windows = @(Get-TopLevelWindow | Where-Object { $pids -contains $_.ProcessId })
    }
    if ($WindowClass -or $WindowTitlePrefix) {
        $owners = @($windows | Where-Object { Test-WindowMatch $_ } | ForEach-Object ProcessId)
        $procs = @($procs | Where-Object { $owners -contains $_.Id })
        $windows = @($windows | Where-Object { $owners -contains $_.ProcessId })
    }
    [pscustomobject]@{ Processes = $procs; Windows = $windows }
}

function Start-App {
    $path = $Exe
    if (-not (Test-Path -LiteralPath $path) -and $script:LastSeenPath) {
        $path = $script:LastSeenPath
    }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Executable not found: $Exe"
    }

    $dir = $WorkingDirectory
    if (-not $dir) { $dir = Split-Path -Parent $path }
    $params = @{ FilePath = $path; WorkingDirectory = $dir }
    if ($ArgumentList) { $params.ArgumentList = $ArgumentList }
    Start-Process @params
    $path
}

function Invoke-WatchdogCheck {
    param(
        [Nullable[datetime]] $MissingSince,
        [int] $HungCount = 0,
        [switch] $Initial
    )

    if (Test-Path -LiteralPath $PauseFile) {
        return [pscustomobject]@{ Action = 'paused'; MissingSince = $null; HungCount = 0 }
    }

    $app = Get-WatchedApp
    $procs = $app.Processes
    if ($procs.Count -eq 0) {
        if (-not $Initial -and -not $MissingSince) {
            # Just disappeared: give a reload or manual restart time to finish.
            return [pscustomobject]@{ Action = 'missing'; MissingSince = Get-Date; HungCount = 0 }
        }
        if ($Initial -or ((Get-Date) - $MissingSince).TotalSeconds -ge $MissingGraceSec) {
            $path = Start-App
            return [pscustomobject]@{ Action = 'start'; MissingSince = Get-Date; HungCount = 0; Path = $path }
        }
        return [pscustomobject]@{ Action = 'wait'; MissingSince = $MissingSince; HungCount = 0 }
    }

    # Remember where the running app lives so a restart can use the same install.
    try { if ($procs[0].Path) { $script:LastSeenPath = $procs[0].Path } } catch {}

    $healthy = [pscustomobject]@{ Action = 'healthy'; MissingSince = $null; HungCount = 0; Pids = @($procs.Id) }
    if ($HangChecks -le 0) { return $healthy }

    # Don't judge a process that is still starting up (or just reloaded).
    $newest = $procs | ForEach-Object { try { $_.StartTime } catch { $null } } |
        Sort-Object -Descending | Select-Object -First 1
    if ($newest -and ((Get-Date) - $newest).TotalSeconds -lt $StartupGraceSec) { return $healthy }

    $visible = @($app.Windows | Where-Object Visible)
    $hung = @($visible | Where-Object Hung)
    if ($hung.Count -eq 0) { return $healthy }

    $HungCount++
    if ($HungCount -lt $HangChecks) {
        return [pscustomobject]@{
            Action = 'hung'; MissingSince = $null; HungCount = $HungCount; Pids = @($procs.Id)
            Detail = "$($hung.Count) of $($visible.Count) windows"
        }
    }

    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $path = Start-App
    [pscustomobject]@{ Action = 'restart'; MissingSince = Get-Date; HungCount = 0; Path = $path }
}

if ($NoRun) {
    return
}

$what = $ProcessName
if ($WindowTitlePrefix) { $what += " with window '$WindowTitlePrefix*'" }
Write-WatchdogLog ("watching $what (interval ${IntervalSec}s, missing grace ${MissingGraceSec}s, " +
    "hang checks $HangChecks, pause file $PauseFile)")
$missingSince = $null
$hungCount = 0
$initial = $true
$paused = $false
$wasHung = $false

while ($true) {
    try {
        $result = Invoke-WatchdogCheck -MissingSince $missingSince -HungCount $hungCount -Initial:$initial
    }
    catch {
        Write-WatchdogLog "ERROR: $_"
        $result = [pscustomobject]@{ Action = 'error'; MissingSince = Get-Date; HungCount = 0 }
    }

    switch ($result.Action) {
        'healthy' {
            if ($initial) { Write-WatchdogLog "already running (PID $($result.Pids -join ', '))" }
            elseif ($wasHung) { Write-WatchdogLog 'responding again' }
        }
        'missing' { Write-WatchdogLog "not running; starting in ${MissingGraceSec}s unless it comes back" }
        'start' { Write-WatchdogLog "started $($result.Path)" }
        'hung' { Write-WatchdogLog "not responding ($($result.Detail)), check $($result.HungCount)/$HangChecks" }
        'restart' { Write-WatchdogLog "locked up; killed and started $($result.Path)" }
    }
    if ($result.Action -eq 'paused' -and -not $paused) { Write-WatchdogLog 'paused'; $paused = $true }
    elseif ($paused -and $result.Action -ne 'paused') { Write-WatchdogLog 'resumed'; $paused = $false }

    $wasHung = $result.Action -eq 'hung'
    $missingSince = $result.MissingSince
    $hungCount = $result.HungCount
    $initial = $false
    Start-Sleep -Seconds $IntervalSec
}
