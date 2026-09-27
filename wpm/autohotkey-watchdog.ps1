<#
.SYNOPSIS
    Keeps the primary AutoHotkey script running across PID-changing reloads.

.DESCRIPTION
    wpm supervises this script. This watchdog finds the AutoHotkey process by
    its script argument rather than PID, so normal AutoHotkey reloads are
    accepted without creating a duplicate instance.
#>
param(
    [string] $AutoHotkeyExe = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64_UIA.exe',
    [string] $ScriptPath = 'C:\Users\simsr\.config\autohotkey\autohotkey.ahk',
    [int] $IntervalSec = 5,
    [int] $MissingGraceSec = 5,
    [string] $PauseFile = (Join-Path $env:LOCALAPPDATA 'wpm\autohotkey-watchdog.pause'),
    [switch] $NoRun
)

$ErrorActionPreference = 'Stop'
$script:CanonicalScriptPath = [IO.Path]::GetFullPath($ScriptPath)

function Write-WatchdogLog([string] $Message) {
    Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date), $Message)
}

if (-not ('AhkWindows' -as [type])) {
    Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class AhkWindows {
    delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr hWnd, StringBuilder name, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int max);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);

    public static List<KeyValuePair<uint, string>> Find() {
        var found = new List<KeyValuePair<uint, string>>();
        EnumWindows((hWnd, _) => {
            var cls = new StringBuilder(256);
            GetClassName(hWnd, cls, cls.Capacity);
            if (cls.ToString() == "AutoHotkey") {
                var title = new StringBuilder(1024);
                GetWindowText(hWnd, title, title.Capacity);
                uint pid;
                GetWindowThreadProcessId(hWnd, out pid);
                found.Add(new KeyValuePair<uint, string>(pid, title.ToString()));
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@
}

# Every running AutoHotkey script owns a hidden main window of class
# "AutoHotkey" titled "<script path> - AutoHotkey v<version>". The UIA build
# runs at a higher integrity level, which hides its command line from this
# non-elevated watchdog, but its window title is still readable.
function Get-AutoHotkeyScriptWindow {
    foreach ($w in [AhkWindows]::Find()) {
        [pscustomobject]@{ ProcessId = [int] $w.Key; Title = $w.Value }
    }
}

function Get-ManagedAutoHotkeyProcess {
    $prefix = "$script:CanonicalScriptPath - AutoHotkey"
    @(Get-AutoHotkeyScriptWindow |
        Where-Object { $_.Title.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
}

function Start-ManagedAutoHotkey([switch] $DryRun) {
    if (-not (Test-Path -LiteralPath $AutoHotkeyExe)) {
        throw "AutoHotkey executable not found: $AutoHotkeyExe"
    }
    if (-not (Test-Path -LiteralPath $script:CanonicalScriptPath)) {
        throw "AutoHotkey script not found: $script:CanonicalScriptPath"
    }

    if (-not $DryRun) {
        Start-Process -FilePath $AutoHotkeyExe -ArgumentList @($script:CanonicalScriptPath) -WorkingDirectory (Split-Path -Parent $script:CanonicalScriptPath)
    }
}

function Invoke-AutoHotkeyWatchdogCheck {
    param(
        [Nullable[datetime]] $MissingSince,
        [switch] $Initial,
        [switch] $DryRun
    )

    if (Test-Path -LiteralPath $PauseFile) {
        return [pscustomobject]@{ Action = 'paused'; MissingSince = $null }
    }

    $procs = @(Get-ManagedAutoHotkeyProcess)
    if ($procs.Count -gt 0) {
        return [pscustomobject]@{
            Action = 'healthy'
            MissingSince = $null
            Pids = @($procs.ProcessId)
        }
    }

    if ($Initial -or -not $MissingSince -or
        ((Get-Date) - $MissingSince).TotalSeconds -ge $MissingGraceSec) {
        Start-ManagedAutoHotkey -DryRun:$DryRun
        return [pscustomobject]@{ Action = 'start'; MissingSince = Get-Date }
    }

    [pscustomobject]@{ Action = 'wait'; MissingSince = $MissingSince }
}

if ($NoRun) {
    return
}

Write-WatchdogLog "watching $script:CanonicalScriptPath (interval ${IntervalSec}s, missing grace ${MissingGraceSec}s)"
$missingSince = $null
$initial = $true
$paused = $false

while ($true) {
    $result = Invoke-AutoHotkeyWatchdogCheck -MissingSince $missingSince -Initial:$initial
    if ($result.Action -eq 'healthy' -and $initial) {
        Write-WatchdogLog "managed script already running (PID $($result.Pids -join ', '))"
    }
    elseif ($result.Action -eq 'start') {
        Write-WatchdogLog "starting $script:CanonicalScriptPath"
    }
    elseif ($result.Action -eq 'paused' -and -not $paused) {
        Write-WatchdogLog 'paused'
        $paused = $true
    }
    elseif ($paused -and $result.Action -ne 'paused') {
        Write-WatchdogLog 'resumed'
        $paused = $false
    }

    $missingSince = $result.MissingSince
    $initial = $false
    Start-Sleep -Seconds $IntervalSec
}
