# w11dwm-config

My Windows 11 desktop and window-management setup, shared here so it can be
discussed. It's a tiling window manager driven entirely from the keyboard, with a
custom status bar and a launcher, themed with Catppuccin Mocha throughout.

| Tool | Role | Folder | Lives at |
| --- | --- | --- | --- |
| [komorebi](https://github.com/LGUG2Z/komorebi) | Tiling window manager | [`komorebi/`](komorebi) | `~/.config/komorebi` (`KOMOREBI_CONFIG_HOME`) |
| [AutoHotkey v2](https://www.autohotkey.com/) | All key bindings (replaces whkd), plus a which-key-style app launcher | [`autohotkey/`](autohotkey) | `~/.config/AutoHotKey` |
| [yasb](https://github.com/amnweb/yasb) | Status bar (replaces komorebi-bar) | [`yasb/`](yasb) | `~/.config/yasb` |
| [Flow Launcher](https://www.flowlauncher.com/) | Search and launcher (`Ctrl + ~`) | [`flowlauncher/`](flowlauncher) | `%APPDATA%\FlowLauncher` → `~/.config/FlowLauncher` |
| [wpm](https://github.com/LGUG2Z/wpm) | Process manager. Runs a watchdog that keeps yasb alive | [`wpm/`](wpm) | `~/.config/wpm` |

How it all starts at logon (scheduled tasks, elevation, environment): see [`startup/`](startup).

## How the pieces fit together

- **Workspaces:** these are named workspaces spread over two monitors, defined in `komorebi/komorebi.json`:
  - 4K: `1 dev` · `2 notes` · `3 ai-lab` · `4 admin`
  - LG: `5 research` · `6 comms` · `7 files` · `8 games` · `9 scratch`

  `initial_workspace_rules` put each app on its home workspace when it opens.
- **Keys (AutoHotkey → komorebic):** `autohotkey/WindowManager.ahk` follows komorebi's
  sample whkdrc, with **Alt** as the WM modifier (`Alt+h/j/k/l` to focus, `Alt+1..9` to change workspace,
  `Alt+Shift+1..9` to move a window to a workspace, …). It calls `komorebic` through the small wrapper
  in `autohotkey/Lib/Komorebi.ahk`.
- **App chords:** `Win+Space` opens a which-key style menu (`autohotkey/Chords.ahk`, built on
  [KeyChord](https://github.com/tylerjcw/KeyChord)). Pressing a key focuses that app, or launches it if it isn't running, and
  komorebi's rules take care of which workspace it lands on. Apps are defined once in
  `autohotkey/Apps.ahk`.
- **Bar:** yasb reads komorebi's state for its workspace and layout widgets. It has a full
  bar on the primary monitor and a slim one on the others.
- **Watchdog:** wpm supervises `yasb-watchdog.ps1`, which restarts yasb if it
  dies or hangs. [`wpm/README.md`](wpm/README.md) explains why wpm doesn't supervise
  yasb directly.

## About this repo

The real files live in a private dotfiles repo in `~/.config`. [`sync.ps1`](sync.ps1)
copies an explicit allowlist from there into this repo, mirroring deletions, and then
scans the result for anything that looks like a secret. Flow Launcher plugins are listed in
[`flowlauncher/plugins.md`](flowlauncher/plugins.md) and the plugin binaries aren't included.

```powershell
./sync.ps1        # then review `git diff` and commit
```

Paths in these configs contain my username (`simsr`) and my install locations. Adjust
them for your own machine.

## License

[MIT](LICENSE) covers my files. `autohotkey/Lib/KeyChord` is a submodule pointing to
[tylerjcw/KeyChord](https://github.com/tylerjcw/KeyChord) and isn't covered by this license.
