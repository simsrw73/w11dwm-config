<#
.SYNOPSIS
Copies the desktop/window-management configs from ~/.config into this repo.

.DESCRIPTION
~/.config is the source of truth (a private dotfiles repo). This script copies
an explicit allowlist into the repo so nothing gets published unless it's
listed here. Tool folders are mirrored: files removed at the source are removed
here too. After copying, it scans for anything that looks like a secret and
fails if it finds one.

autohotkey/Lib/Legend is a git submodule and isn't touched.
#>
[CmdletBinding()]
param(
    [string] $Source = (Join-Path $HOME '.config')
)
$ErrorActionPreference = 'Stop'
$Repo = $PSScriptRoot

# dest folder => source folder + allowlist globs (relative to the source folder)
$Map = [ordered]@{
    komorebi     = @{ From = 'komorebi';     Include = 'komorebi.json', 'applications.json' }
    yasb         = @{ From = 'yasb';         Include = 'config.yaml', 'styles.css', 'launchpad/apps.json', 'launchpad/icons/*.png' }
    autohotkey   = @{ From = 'AutoHotKey';   Include = '*.ahk', 'Lib/*.ahk' }
    flowlauncher = @{ From = 'FlowLauncher'; Include = 'Settings/Settings.json', 'Settings/Plugins/*/Settings.json',
                                                       'Settings/Plugins/*/PluginSettings.json', 'Themes/*.xaml'
                      Exclude = 'Settings/Plugins/Github Quick Launcher/*' }   # holds a GitHub token
    wpm          = @{ From = 'wpm';          Include = '*.toml', '*.ps1', '*.md', 'tests/Watchdog.Tests.ps1' }
}

# Keep these untouched when mirroring (not copied from the source)
$Preserve = 'autohotkey/Lib/Legend/*', 'flowlauncher/plugins.md'

# Flow Launcher rewrites these values as it runs; pin them in the copy
# (the same pins as lib/flow-state.sed in the dotfiles repo).
$FlowState = 'flowlauncher/Settings/Settings.json',
             'flowlauncher/Settings/Plugins/Flow.Launcher.Plugin.Program/Settings.json'

# Copies text files with LF line endings (the repo's .gitattributes checks
# them out as LF, so copies always match) and binary files as-is.
function Copy-RepoFile([string] $From, [string] $To, [string] $RepoPath) {
    if ($From -like '*.png') { Copy-Item -LiteralPath $From $To -Force; return }
    # Latin1 maps bytes 1:1, so encodings and BOMs pass through unchanged
    $latin1 = [Text.Encoding]::Latin1
    $text = $latin1.GetString([IO.File]::ReadAllBytes($From)).Replace("`r`n", "`n")
    if ($FlowState -contains $RepoPath) {
        $text = $text -replace '(?m)^(\s*"(?:WindowLeft|WindowTop|ActivateTimes)": )[0-9.]+', '${1}0'
        $text = $text -replace '(?m)^(\s*"LastIndexTime": )"[^"]*"', '${1}"0001-01-01T00:00:00"'
    }
    [IO.File]::WriteAllBytes($To, $latin1.GetBytes($text))
}

function Get-Allowed($root, $include, $exclude) {
    foreach ($glob in $include) {
        $dir = Join-Path $root (Split-Path $glob -Parent)
        $leaf = Split-Path $glob -Leaf
        # Handles one wildcard directory level, e.g. Settings/Plugins/*/Settings.json
        $dirs = if ($dir -match '\*') { Get-Item $dir -ErrorAction SilentlyContinue | Where-Object PSIsContainer } else { Get-Item $dir -ErrorAction SilentlyContinue }
        foreach ($d in $dirs) {
            Get-ChildItem -LiteralPath $d.FullName -Filter $leaf -File -ErrorAction SilentlyContinue | ForEach-Object {
                $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
                if (-not ($exclude | Where-Object { $rel -like $_ })) { $rel }
            }
        }
    }
}

foreach ($dest in $Map.Keys) {
    $spec = $Map[$dest]
    $srcRoot = (Resolve-Path (Join-Path $Source $spec.From)).Path
    $dstRoot = Join-Path $Repo $dest
    $wanted = @(Get-Allowed $srcRoot $spec.Include @($spec.Exclude) | Sort-Object -Unique)

    foreach ($rel in $wanted) {
        $target = Join-Path $dstRoot $rel
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-RepoFile (Join-Path $srcRoot $rel) $target "$dest/$rel"
    }

    # Mirror: drop files that are no longer in the allowlist / source
    if (Test-Path $dstRoot) {
        Get-ChildItem $dstRoot -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($dstRoot.Length + 1).Replace('\', '/')
            $keep = ($wanted -contains $rel) -or ($Preserve | Where-Object { "$dest/$rel" -like $_ })
            if (-not $keep) { Remove-Item -LiteralPath $_.FullName; Write-Host "removed $dest/$rel" }
        }
        Get-ChildItem $dstRoot -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } | Remove-Item
    }
    Write-Host ("{0,-13} {1} files" -f $dest, $wanted.Count)
}

# Flow Launcher plugins: list them instead of copying binaries
$plugins = Get-ChildItem (Join-Path $Source 'FlowLauncher/Plugins') -Directory | ForEach-Object {
    $meta = Get-Content -Raw (Join-Path $_.FullName 'plugin.json') -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($meta) { "| {0} | {1} | {2} |" -f $meta.Name, $meta.Version, ($meta.Website ?? '') }
} | Sort-Object
$lines = @('# Flow Launcher plugins', '', 'Third-party plugins installed (generated by `sync.ps1`).', '',
  '| Plugin | Version | Website |', '| --- | --- | --- |') + $plugins
# LF, not Set-Content's CRLF (see .gitattributes)
[IO.File]::WriteAllText((Join-Path $Repo 'flowlauncher/plugins.md'), ($lines -join "`n") + "`n")

# Secret scan over everything that was synced
$pattern = '(?i)(token|api[_-]?key|secret|password|bearer)\s*["'']?\s*[:=]\s*["'']?[A-Za-z0-9_\-\.]{8,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}'
$hits = Get-ChildItem ($Map.Keys | ForEach-Object { Join-Path $Repo $_ }) -Recurse -File -Exclude *.png |
    Where-Object FullName -notmatch '\\Legend\\' | Select-String -Pattern $pattern
if ($hits) {
    $hits | ForEach-Object { Write-Warning ("{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()) }
    throw "Possible secrets found. Fix the source or the allowlist before committing."
}
Write-Host 'secret scan: clean'
