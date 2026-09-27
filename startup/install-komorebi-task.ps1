# Registers a scheduled task that starts komorebi at logon.
#
# komorebi runs elevated (RunLevel Highest) so it can manage elevated windows
# too. A scheduled task is the only way to start elevated at logon without a
# UAC prompt. komorebic-no-console avoids a console window flashing.
#
# Safe to re-run; it replaces the existing task. Pass -Start to launch now.

param(
    [string]$KomorebicExe = (Get-Command komorebic-no-console.exe -ErrorAction SilentlyContinue).Source,
    [string]$Config = "$HOME\.config\komorebi\komorebi.json",
    [switch]$Start
)

$ErrorActionPreference = 'Stop'

if (-not $KomorebicExe) {
    $KomorebicExe = "$env:ProgramFiles\komorebi\bin\komorebic-no-console.exe"
}
if (-not (Test-Path $KomorebicExe)) {
    throw "komorebic-no-console.exe not found; pass -KomorebicExe <path>"
}
if (-not (Test-Path $Config)) {
    throw "komorebi config not found at $Config; pass -Config <path>"
}

$user      = "$env:USERDOMAIN\$env:USERNAME"
$action    = New-ScheduledTaskAction -Execute $KomorebicExe -Argument "start --config `"$Config`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'komorebi' -Force `
    -Description 'komorebi tiling window manager' `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings |
    Select-Object TaskName, State

if ($Start -and -not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
    Start-ScheduledTask -TaskName 'komorebi'
}
