# Registers the scheduled tasks behind the wpm desktop:
#
#   wpmd      runs at logon as the current user, NOT elevated. The watchdogs
#             relaunch apps, and an elevated yasb/Flow Launcher would break
#             drag/drop and launch everything as admin.
#             conhost --headless keeps wpmd's console window hidden.
#   komorebi  elevated, with no trigger. The komorebi wpm unit starts it with
#             `schtasks /Run`, which needs no UAC prompt, so komorebi can
#             manage admin windows while wpmd stays unelevated.
#   wpm-librehardwaremonitor, wpm-crystaldiskinfo
#             elevated, with no trigger, started the same way by their wpm
#             units. Both need admin to read sensors and SMART data. Turn off
#             each app's own "start with Windows" option, which registers
#             a logon task of its own.
#
# All run at priority 4 (normal). The task default of 7 makes the process,
# and every child it starts, run at BelowNormal.
#
# Run elevated (registering a Highest task needs it). Safe to re-run; it
# replaces the existing tasks. Pass -Start to launch wpmd now.

#Requires -RunAsAdministrator

param(
    [string]$WpmdExe = (Get-Command wpmd.exe -ErrorAction SilentlyContinue).Source,
    [string]$KomorebicExe = "$env:ProgramFiles\komorebi\bin\komorebic-no-console.exe",
    [string]$KomorebiConfig = "$HOME\.config\komorebi\komorebi.json",
    [string]$LhmExe = (Get-Command LibreHardwareMonitor.exe -ErrorAction SilentlyContinue).Source,
    [string]$CrystalDiskInfoExe = "$env:ProgramFiles\CrystalDiskInfo\DiskInfo64.exe",
    [switch]$Start
)

$ErrorActionPreference = 'Stop'

if (-not $WpmdExe) {
    $WpmdExe = "$HOME\.local\share\cargo\bin\wpmd.exe"
}
if (-not $LhmExe) { throw "LibreHardwareMonitor.exe not on PATH; pass -LhmExe" }
foreach ($exe in $WpmdExe, $KomorebicExe, $LhmExe, $CrystalDiskInfoExe) {
    if (-not (Test-Path $exe)) { throw "$exe not found; pass its path as a parameter" }
}

$user = "$env:USERDOMAIN\$env:USERNAME"

function New-Settings {
    New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -Priority 4
}

Register-ScheduledTask -TaskName 'wpmd' -Force `
    -Description 'wpm process manager (supervises the desktop units)' `
    -Action (New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument "--headless `"$WpmdExe`"") `
    -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $user) `
    -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited) `
    -Settings (New-Settings) |
    Select-Object TaskName, State

Register-ScheduledTask -TaskName 'komorebi' -Force `
    -Description 'komorebi, elevated; started by the komorebi wpm unit, not at logon' `
    -Action (New-ScheduledTaskAction -Execute $KomorebicExe -Argument "start --config `"$KomorebiConfig`"") `
    -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest) `
    -Settings (New-Settings) |
    Select-Object TaskName, State

function Register-ElevatedTask([string]$Name, [string]$Description, [string]$Exe, [string]$Arguments) {
    $action = if ($Arguments) {
        New-ScheduledTaskAction -Execute $Exe -Argument $Arguments -WorkingDirectory (Split-Path $Exe)
    } else {
        New-ScheduledTaskAction -Execute $Exe -WorkingDirectory (Split-Path $Exe)
    }
    Register-ScheduledTask -TaskName $Name -Force -Description $Description -Action $action `
        -Principal (New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest) `
        -Settings (New-Settings) |
        Select-Object TaskName, State
}

Register-ElevatedTask 'wpm-librehardwaremonitor' `
    'LibreHardwareMonitor, elevated; started by the librehardwaremonitor wpm unit, not at logon' `
    $LhmExe ''

Register-ElevatedTask 'wpm-crystaldiskinfo' `
    'CrystalDiskInfo, elevated; started by the crystaldiskinfo wpm unit, not at logon' `
    $CrystalDiskInfoExe '/Startup'

if ($Start -and -not (Get-Process wpmd -ErrorAction SilentlyContinue)) {
    Start-ScheduledTask -TaskName 'wpmd'
}
