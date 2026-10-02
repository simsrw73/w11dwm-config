#Requires AutoHotkey v2.0

; One entry per app the chords can reach. Fields are documented in Lib/WindowLauncher.ahk.
; Workspace placement lives in ~/.config/komorebi/komorebi.json (initial_workspace_rules).

AppsFolder(appId) => 'explorer.exe "shell:AppsFolder\' appId '"'

LocalPrograms := EnvGet("LocalAppData") "\Programs"
Projects := EnvGet("UserProfile") "\projects"
Sysinternals := EnvGet("UserProfile") "\.local\share\scoop\apps\sysinternals\current"

Apps := {
    ; dev
    Zed:         { Criteria: "ahk_exe Zed.exe", Command: Quote(LocalPrograms "\Zed\Zed.exe") },
    ClaudeCode:  { Criteria: "Claude Code ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w claude new-tab --title "Claude Code" --suppressApplicationTitle -p "PowerShell" -d "' Projects '" pwsh.exe -NoExit -Command claude' },
    Shell:       { Criteria: "Shell ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w shell new-tab --title "Shell" --suppressApplicationTitle -p "PowerShell"' },

    ; shells: each in its own named Terminal window (Criteria matches the title's start)
    Powershell:  { Criteria: "PowerShell ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w powershell new-tab --title "PowerShell" --suppressApplicationTitle -p "PowerShell"' },
    ArchWSL:     { Criteria: "Arch ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w arch new-tab --title "Arch" --suppressApplicationTitle -p "Arch Linux"' },
    KaliWSL:     { Criteria: "Kali ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w kali new-tab --title "Kali" --suppressApplicationTitle -p "kali-linux"' },
    UbuntuWSL:   { Criteria: "Ubuntu ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w ubuntu new-tab --title "Ubuntu" --suppressApplicationTitle -p "Ubuntu-26.04"' },
    MSDevShell:  { Criteria: "MS Dev Shell ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w devshell new-tab --title "MS Dev Shell" --suppressApplicationTitle -p "Developer Command Prompt (VS 2026)"' },

    ; notes
    Obsidian:    { Criteria: "ahk_exe Obsidian.exe", Command: Quote(LocalPrograms "\Obsidian\Obsidian.exe") },

    ; research
    Zen:         { Criteria: "ahk_exe zen.exe", Command: Quote("C:\Program Files\Zen Browser\zen.exe") },
    Brave:       { Criteria: "ahk_exe brave.exe", Command: Quote("C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe") },
    Chrome:      { Criteria: "ahk_exe chrome.exe", Exclude: "Gemini", MatchMode: 2,
                   Command: Quote("C:\Program Files\Google\Chrome\Application\chrome.exe") },
    Edge:        { Criteria: "ahk_exe msedge.exe", Command: Quote("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") },
    Typora:      { Criteria: "ahk_exe Typora.exe", Command: Quote(LocalPrograms "\Typora\Typora.exe") },

    ; ai-lab
    Perplexity:  { Criteria: "ahk_exe Perplexity.exe", Command: AppsFolder("PerplexityAI.PerplexityApp_3jh4kjrg4dzr2!ai.perplexity.PerplexityPersonalComputer.Electron") },
    Claude:      { Criteria: "ahk_exe claude.exe", Command: AppsFolder("Claude_pzs8sxrjxfjjc!Claude") },
    ChatGPT:     { Criteria: "ahk_exe ChatGPT.exe", Command: AppsFolder("OpenAI.Codex_2p2nqsd0c76g0!App") },
    Copilot:     { Criteria: "ahk_exe github.exe", Command: Quote(LocalPrograms "\GitHub Copilot\github.exe") },
    Gemini:      { Criteria: "Gemini ahk_exe chrome.exe", MatchMode: 2, Command: AppsFolder("Chrome._crx_gdfaincndodkhapmbffkckdkhn") },

    ; comms
    Spark:       { Criteria: "ahk_exe Spark Desktop.exe", Command: Quote(LocalPrograms "\SparkDesktop\Spark Desktop.exe") },
    TickTick:    { Criteria: "ahk_exe TickTick.exe", Command: Quote("C:\Program Files (x86)\TickTick\TickTick.exe") },
    Fantastical: { Criteria: "ahk_exe Fantastical.exe", Command: AppsFolder("FlexibitsInc.Fantastical_xhwyj10g4qjsr!AppMain") },

    ; files
    Explorer:    { Criteria: "ahk_class CabinetWClass", Exclude: "Control Panel", MatchMode: 2, Command: "explorer.exe" },
    Everything:  { Criteria: "ahk_class EVERYTHING ahk_exe Everything.exe", Command: Quote("C:\Program Files\Everything\Everything.exe") },

    ; admin
    UniGetUI:       { Criteria: "ahk_exe UniGetUI.exe", Command: Quote(LocalPrograms "\UniGetUI\UniGetUI.exe") },
    Windhawk:       { Criteria: "Windhawk ahk_exe VSCodium.exe", MatchMode: 2, Command: Quote("C:\Program Files\Windhawk\windhawk.exe") },
    PowerToys:      { Criteria: "ahk_exe PowerToys.Settings.exe", Command: Quote(EnvGet("LocalAppData") "\PowerToys\PowerToys.exe") },
    Autoruns:       { Criteria: "ahk_exe Autoruns64.exe", Command: Quote(Sysinternals "\Autoruns64.exe") },
    ProcExp:        { Criteria: "ahk_exe procexp64.exe", Command: Quote(Sysinternals "\procexp64.exe") },
    ProcMon:        { Criteria: "ahk_exe Procmon64.exe", Command: Quote(Sysinternals "\Procmon64.exe") },
    TCPView:        { Criteria: "ahk_exe tcpview64.exe", Command: Quote(Sysinternals "\tcpview64.exe") },
    DeviceManager:  { Criteria: "Device Manager ahk_exe mmc.exe", Command: "devmgmt.msc" },
    Services:       { Criteria: "Services ahk_exe mmc.exe", Command: "services.msc" },
    EventViewer:    { Criteria: "Event Viewer ahk_exe mmc.exe", Command: "eventvwr.msc" },
    TaskScheduler:  { Criteria: "Task Scheduler ahk_exe mmc.exe", Command: "taskschd.msc" },
    ControlPanel:   { Criteria: "Control Panel ahk_class CabinetWClass", MatchMode: 2, Command: "control.exe" },
    Settings:       { Criteria: "Settings ahk_class ApplicationFrameWindow", MatchMode: 3, Command: "ms-settings:" },
    RegistryEditor: { Criteria: "ahk_exe regedit.exe", Command: "regedit.exe" },
    HWiNFO:         { Criteria: "ahk_exe HWiNFO64.EXE", Command: Quote("C:\Program Files\HWiNFO64\HWiNFO64.EXE") },
    WizTree:        { Criteria: "ahk_exe WizTree64.exe", Command: Quote("C:\Program Files\WizTree\WizTree64.exe") },
    WinBox:         { Criteria: "ahk_exe WinBox.exe", Command: Quote(EnvGet("LocalAppData") "\Microsoft\WinGet\Links\WinBox.exe") },

    ; games
    Steam:        { Criteria: "Steam ahk_exe steamwebhelper.exe", MatchMode: 3, Command: Quote("C:\Program Files (x86)\Steam\steam.exe") },
    GOG:          { Criteria: "ahk_exe GalaxyClient.exe", Command: AppsFolder("GogCom.GalaxyClient.Main") },
    AmazonGames:  { Criteria: "ahk_exe Amazon Games UI.exe", Command: AppsFolder("Amazon.AmazonGamesApp") },
    BattleNet:    { Criteria: "ahk_exe Battle.net.exe", Command: Quote("G:\Games\BattleNet\Battle.net Launcher.exe") },
    Epic:         { Criteria: "ahk_exe EpicGamesLauncher.exe", Command: Quote("C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe") },
    Ubisoft:      { Criteria: "ahk_exe upc.exe", Command: Quote("C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe") },
    Xbox:         { Criteria: "ahk_exe XboxPcApp.exe", Command: AppsFolder("Microsoft.GamingApp_8wekyb3d8bbwe!Microsoft.Xbox.App") },
    Vortex:       { Criteria: "ahk_exe Vortex.exe", Command: AppsFolder("com.nexusmods.vortex") },
    ModOrganizer: { Criteria: "ahk_exe ModOrganizer.exe", Command: Quote("G:\Games\Modding\MO2\ModOrganizer.exe") },

    ; popups: ignored by komorebi, so they stay visible on every workspace
    Koffee:      { Criteria: "ahk_exe Koffee.exe", Popup: true, Command: Quote(EnvGet("UserProfile") "\.local\share\scoop\apps\koffee\current\Koffee.exe") },
    Bitwarden:   { Criteria: "ahk_exe Bitwarden.exe", Popup: true, Command: Quote(LocalPrograms "\Bitwarden\Bitwarden.exe") },
    TaskManager: { Criteria: "ahk_exe Task Manager.exe", Popup: true, Command: Quote(LocalPrograms "\Task Manager TMOG\Task Manager.exe") },
}
