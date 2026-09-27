<#
.SYNOPSIS
    Keeps a desktop app running across self-restarts. Meant to be run by wpm.

.DESCRIPTION
    Every -IntervalSec seconds:
      * no process named -ProcessName for longer than -MissingGraceSec -> start -Exe
      * pause file exists                                             -> do nothing

    The app is tracked by process name, not PID, so apps that restart or
    update themselves (replacing their process) are left alone.

    Output goes to the wpm log: `wpmctl log <unit>`.
#>
param(
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [string] $ProcessName,
    [Parameter(Mandatory)] [string] $Exe,
    [string[]] $ArgumentList = @(),
    [int] $IntervalSec = 5,
    [int] $MissingGraceSec = 10,
    [string] $PauseFile = (Join-Path $env:LOCALAPPDATA "wpm\$Name-watchdog.pause"),
    [switch] $NoRun
)

$ErrorActionPreference = 'Stop'

function Write-WatchdogLog([string] $Message) {
    Write-Output ('{0:yyyy-MM-ddTHH:mm:ss} {1}' -f (Get-Date), $Message)
}

function Start-App([switch] $DryRun) {
    if (-not (Test-Path -LiteralPath $Exe)) {
        throw "Executable not found: $Exe"
    }

    if (-not $DryRun) {
        $params = @{ FilePath = $Exe; WorkingDirectory = (Split-Path -Parent $Exe) }
        if ($ArgumentList) { $params.ArgumentList = $ArgumentList }
        Start-Process @params
    }
}

function Invoke-AppWatchdogCheck {
    param(
        [Nullable[datetime]] $MissingSince,
        [switch] $Initial,
        [switch] $DryRun
    )

    if (Test-Path -LiteralPath $PauseFile) {
        return [pscustomobject]@{ Action = 'paused'; MissingSince = $null }
    }

    $procs = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        return [pscustomobject]@{
            Action = 'healthy'
            MissingSince = $null
            Pids = @($procs.Id)
        }
    }

    if ($Initial -or -not $MissingSince -or
        ((Get-Date) - $MissingSince).TotalSeconds -ge $MissingGraceSec) {
        Start-App -DryRun:$DryRun
        return [pscustomobject]@{ Action = 'start'; MissingSince = Get-Date }
    }

    [pscustomobject]@{ Action = 'wait'; MissingSince = $MissingSince }
}

if ($NoRun) {
    return
}

Write-WatchdogLog "watching $ProcessName (interval ${IntervalSec}s, missing grace ${MissingGraceSec}s)"
$missingSince = $null
$initial = $true
$paused = $false

while ($true) {
    $result = Invoke-AppWatchdogCheck -MissingSince $missingSince -Initial:$initial
    if ($result.Action -eq 'healthy' -and $initial) {
        Write-WatchdogLog "$ProcessName already running (PID $($result.Pids -join ', '))"
    }
    elseif ($result.Action -eq 'start') {
        Write-WatchdogLog "starting $Exe"
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
