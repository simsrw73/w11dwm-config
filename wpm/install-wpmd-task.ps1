# Registers a scheduled task that starts wpmd at logon.
#
# wpmd runs as the current user, NOT elevated: the watchdog relaunches yasb,
# and an elevated yasb would break drag/drop and input with normal windows.
# conhost --headless keeps wpmd's console window hidden.
#
# Safe to re-run; it replaces the existing task. Pass -Start to launch now.

param(
    [string]$WpmdExe = (Get-Command wpmd.exe -ErrorAction SilentlyContinue).Source,
    [switch]$Start
)

$ErrorActionPreference = 'Stop'

if (-not $WpmdExe) {
    $WpmdExe = "$HOME\.local\share\cargo\bin\wpmd.exe"
}
if (-not (Test-Path $WpmdExe)) {
    throw "wpmd.exe not found; pass -WpmdExe <path>"
}

$user      = "$env:USERDOMAIN\$env:USERNAME"
$action    = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument "--headless `"$WpmdExe`""
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'wpmd' -Force `
    -Description 'wpm process manager (supervises yasb-watchdog)' `
    -Action $action -Trigger $trigger -Principal $principal -Settings $settings |
    Select-Object TaskName, State

if ($Start -and -not (Get-Process wpmd -ErrorAction SilentlyContinue)) {
    Start-ScheduledTask -TaskName 'wpmd'
}
