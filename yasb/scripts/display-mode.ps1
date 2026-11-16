<#
.SYNOPSIS
    Reports or toggles the Windows display mode for the yasb display_mode widget.

.DESCRIPTION
    Without -Toggle, prints the current mode as JSON for the widget's label:
    "extend" when more than one display is active, otherwise "external".

    With -Toggle, switches between Extend and Second screen only (the Win+P
    options, through DisplaySwitch.exe). Before switching to Second screen only
    it stops komorebi, if it's running, and restores the windows it hid, the
    same way the wpm unit stops it. Switching back to Extend leaves komorebi
    alone; start it again with `wpmctl start komorebi` when you want it.

.PARAMETER Toggle
    Switch modes instead of printing the current one.
#>
[CmdletBinding()]
param([switch]$Toggle)

Add-Type -AssemblyName System.Windows.Forms
$extended = [System.Windows.Forms.Screen]::AllScreens.Count -gt 1

if (-not $Toggle) {
    $state = if ($extended) {
        @{ mode = 'extend'; icon = [char]::ConvertFromUtf32(0xF037A); tooltip = 'Displays: Extend (click for second screen only)' } # nf-md-monitor_multiple
    } else {
        @{ mode = 'external'; icon = [char]::ConvertFromUtf32(0xF0379); tooltip = 'Displays: Second screen only (click to extend)' } # nf-md-monitor
    }
    # Escaped, so the icon survives whatever code page the console uses
    $state | ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
    return
}

$displaySwitch = Join-Path $env:SystemRoot 'System32\DisplaySwitch.exe'

if ($extended) {
    if (Get-Process komorebi -ErrorAction SilentlyContinue) {
        # Exit code 0, so wpm (Restart = "OnFailure") leaves it stopped
        komorebic stop | Out-Null
        # Wait for it to exit, so it doesn't react to the display change
        for ($i = 0; $i -lt 20 -and (Get-Process komorebi -ErrorAction SilentlyContinue); $i++) {
            Start-Sleep -Milliseconds 250
        }
        komorebic restore-windows | Out-Null
    }
    & $displaySwitch /external
} else {
    & $displaySwitch /extend
}
