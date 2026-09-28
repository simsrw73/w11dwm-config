BeforeAll {
    $script:watchdog = Join-Path $PSScriptRoot '..\watchdog.ps1'
    $script:exe = Join-Path $TestDrive 'app.exe'
    New-Item -ItemType File $script:exe -Force | Out-Null

    function New-Proc([int] $Id, [int] $AgeSec = 600) {
        [pscustomobject]@{ Id = $Id; StartTime = (Get-Date).AddSeconds(-$AgeSec); Path = $script:exe }
    }
    function New-Window([int] $ProcessId, [string] $Class = 'Win', [string] $Title = '', [bool] $Visible = $true, [bool] $Hung = $false) {
        [pscustomobject]@{ ProcessId = $ProcessId; Class = $Class; Title = $Title; Visible = $Visible; Hung = $Hung }
    }
}

Describe 'watchdog: process-name detection' {
    BeforeAll {
        . $watchdog -Name test -ProcessName app -Exe $exe -PauseFile (Join-Path $TestDrive 'none.pause') -NoRun
    }

    BeforeEach {
        Mock Get-Process { @() }
        Mock Get-TopLevelWindow { @() }
        Mock Start-Process {}
        Mock Stop-Process {}
    }

    It 'is healthy when any process with the name exists, whatever its PID' {
        Mock Get-Process { @((New-Proc 101), (New-Proc 202)) }

        $result = Invoke-WatchdogCheck -Initial
        $result.Action | Should -Be 'healthy'
        $result.Pids | Should -Be @(101, 202)
    }

    It 'starts immediately when initially absent' {
        (Invoke-WatchdogCheck -Initial).Action | Should -Be 'start'
        Should -Invoke Start-Process -Times 1
    }

    It 'accepts the explicitly null missing state used by the loop' {
        $missingSince = $null
        (Invoke-WatchdogCheck -MissingSince $missingSince -Initial).Action | Should -Be 'start'
    }

    It 'waits out the grace period when the app first disappears (e.g. mid-reload)' {
        $result = Invoke-WatchdogCheck -MissingSince $null
        $result.Action | Should -Be 'missing'
        $result.MissingSince | Should -Not -BeNullOrEmpty
        Should -Invoke Start-Process -Times 0
    }

    It 'waits during a later missing grace period' {
        (Invoke-WatchdogCheck -MissingSince (Get-Date)).Action | Should -Be 'wait'
        Should -Invoke Start-Process -Times 0
    }

    It 'starts after the missing grace period' {
        (Invoke-WatchdogCheck -MissingSince (Get-Date).AddMinutes(-1)).Action | Should -Be 'start'
    }

    It 'does nothing while paused' {
        $PauseFile = Join-Path $TestDrive 'test.pause'
        New-Item -ItemType File $PauseFile -Force | Out-Null

        (Invoke-WatchdogCheck -Initial).Action | Should -Be 'paused'
        Should -Invoke Start-Process -Times 0
    }

    It 'does not check for hangs when HangChecks is 0' {
        Mock Get-Process { @(New-Proc 101) }
        Mock Get-TopLevelWindow { @(New-Window 101 -Hung $true) }

        (Invoke-WatchdogCheck -HungCount 5).Action | Should -Be 'healthy'
        Should -Invoke Stop-Process -Times 0
    }
}

Describe 'watchdog: window-title detection' {
    BeforeAll {
        . $watchdog -Name test -ProcessName AutoHotkey64_UIA -Exe $exe `
            -WindowClass AutoHotkey -WindowTitlePrefix 'C:\Users\simsr\.config\autohotkey\autohotkey.ahk - AutoHotkey' `
            -PauseFile (Join-Path $TestDrive 'none.pause') -NoRun
    }

    BeforeEach {
        Mock Get-Process { @((New-Proc 101), (New-Proc 202), (New-Proc 303)) }
        Mock Get-TopLevelWindow { @() }
        Mock Start-Process {}
    }

    It 'matches only processes owning a matching window, ignoring title case' {
        Mock Get-TopLevelWindow {
            @(
                (New-Window 101 -Class AutoHotkey -Title 'C:\Users\simsr\.config\AutoHotKey\autohotkey.ahk - AutoHotkey v2.0.28' -Visible $false),
                (New-Window 202 -Class AutoHotkey -Title 'C:\Users\simsr\other.ahk - AutoHotkey v2.0.28' -Visible $false),
                (New-Window 303 -Class Other -Title 'C:\Users\simsr\.config\autohotkey\autohotkey.ahk - AutoHotkey')
            )
        }

        $result = Invoke-WatchdogCheck -Initial
        $result.Action | Should -Be 'healthy'
        $result.Pids | Should -Be @(101)
    }

    It 'starts when only other scripts are running' {
        Mock Get-TopLevelWindow { @(New-Window 202 -Class AutoHotkey -Title 'C:\Users\simsr\other.ahk - AutoHotkey v2.0.28') }

        (Invoke-WatchdogCheck -Initial).Action | Should -Be 'start'
    }
}

Describe 'watchdog: hang detection' {
    BeforeAll {
        . $watchdog -Name test -ProcessName app -Exe $exe -HangChecks 3 -StartupGraceSec 45 `
            -PauseFile (Join-Path $TestDrive 'none.pause') -NoRun
    }

    BeforeEach {
        Mock Get-Process { @(New-Proc 101) }
        Mock Get-TopLevelWindow { @((New-Window 101), (New-Window 101 -Hung $true)) }
        Mock Start-Process {}
        Mock Stop-Process {}
        Mock Start-Sleep {}
    }

    It 'counts a hung visible window without acting yet' {
        $result = Invoke-WatchdogCheck -HungCount 0
        $result.Action | Should -Be 'hung'
        $result.HungCount | Should -Be 1
        Should -Invoke Stop-Process -Times 0
    }

    It 'kills and restarts after HangChecks consecutive hung checks' {
        $result = Invoke-WatchdogCheck -HungCount 2
        $result.Action | Should -Be 'restart'
        $result.HungCount | Should -Be 0
        Should -Invoke Stop-Process -Times 1
        Should -Invoke Start-Process -Times 1
    }

    It 'resets the count when windows respond again' {
        Mock Get-TopLevelWindow { @(New-Window 101) }

        $result = Invoke-WatchdogCheck -HungCount 2
        $result.Action | Should -Be 'healthy'
        $result.HungCount | Should -Be 0
    }

    It 'ignores hidden hung windows' {
        Mock Get-TopLevelWindow { @(New-Window 101 -Visible $false -Hung $true) }

        (Invoke-WatchdogCheck -HungCount 2).Action | Should -Be 'healthy'
    }

    It 'skips hang checks during the startup grace period' {
        Mock Get-Process { @(New-Proc 101 -AgeSec 10) }

        (Invoke-WatchdogCheck -HungCount 2).Action | Should -Be 'healthy'
        Should -Invoke Stop-Process -Times 0
    }

    It 'restarts from the running process path when -Exe is missing' {
        $Exe = Join-Path $TestDrive 'missing.exe'
        Mock Get-Process { @(New-Proc 101) }
        Mock Get-TopLevelWindow { @(New-Window 101) }
        Invoke-WatchdogCheck | Out-Null
        Mock Get-Process { @() }

        (Invoke-WatchdogCheck -Initial).Action | Should -Be 'start'
        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq $script:exe }
    }
}

Describe 'Get-TopLevelWindow' {
    BeforeAll {
        . $watchdog -Name test -ProcessName app -Exe $exe -NoRun
    }

    It 'enumerates real windows' {
        @(Get-TopLevelWindow).Count | Should -BeGreaterThan 0
    }
}
