#Requires AutoHotkey v2.0

; Safety exit hotkey to prevent runaway scripts.
Esc:: {
    MsgBox("Eve Flipper Codex Build Merge Helper will be exited.")
    ExitApp()
}

; =========================
; Configuration
; =========================
APP_NAME := "Eve Flipper Codex Build Merge Helper"
CONFIG_FILE := A_ScriptDir . "\eve_flipper_codex_merge_helper.ini"
PS_HELPER_FILE := A_ScriptDir . "\Invoke-EveFlipperCodexBuildMerge.ps1"

RUN_HOTKEY_NAME := "1"
SET_FEATURE_BRANCH_HOTKEY_NAME := "2"
SHOW_FEATURE_BRANCH_HOTKEY_NAME := "3"

CLEAR_DELAY_MS := 250
COMMAND_DELAY_MS := 150

isRunning := false

EnsurePowerShellHelperScript(PS_HELPER_FILE)

savedFeatureBranch := IniRead(CONFIG_FILE, "Branches", "FeatureBranch", "")

MsgBox(
    APP_NAME . "`n`n"
    . "Instructions:`n"
    . "1. Focus a WezTerm window in your Eve Flipper repo.`n"
    . "2. Copy your long-lived feature branch name to the clipboard.`n"
    . "3. Press " . SET_FEATURE_BRANCH_HOTKEY_NAME . " to save that feature branch.`n"
    . "4. Copy the Codex branch name to the clipboard.`n"
    . "5. Press " . RUN_HOTKEY_NAME . " to run build + conditional merge.`n`n"
    . "Hotkeys while WezTerm is active:`n"
    . RUN_HOTKEY_NAME . " = checkout Codex branch, build, and merge into saved feature branch if successful`n"
    . SET_FEATURE_BRANCH_HOTKEY_NAME . " = save clipboard as target feature branch`n"
    . SHOW_FEATURE_BRANCH_HOTKEY_NAME . " = show saved feature branch`n"
    . "Esc = exit immediately`n`n"
    . "Saved feature branch:`n"
    . (savedFeatureBranch = "" ? "<none saved yet>" : savedFeatureBranch)
)

#HotIf WinActive("ahk_exe wezterm-gui.exe")

1:: {
    global isRunning, APP_NAME

    if isRunning {
        return
    }

    isRunning := true

    try {
        RunCodexBuildMerge()
    } catch as err {
        MsgBox(APP_NAME . "`n`nError:`n" . err.Message)
        ExitApp()
    }
}

2:: {
    global APP_NAME

    try {
        SaveFeatureBranchFromClipboard()
    } catch as err {
        MsgBox(APP_NAME . "`n`nError:`n" . err.Message)
    }
}

3:: {
    ShowSavedFeatureBranch()
}

#HotIf

RunCodexBuildMerge() {
    global APP_NAME, CONFIG_FILE, PS_HELPER_FILE, CLEAR_DELAY_MS, COMMAND_DELAY_MS

    codexBranch := Trim(A_Clipboard)
    featureBranch := IniRead(CONFIG_FILE, "Branches", "FeatureBranch", "")

    if (codexBranch = "") {
        MsgBox(APP_NAME . "`n`nClipboard is empty. Copy the Codex branch name first.")
        ExitApp()
    }

    if (featureBranch = "") {
        MsgBox(APP_NAME . "`n`nNo feature branch is saved yet.`n`nCopy your feature branch name and press 2 first.")
        ExitApp()
    }

    ValidateBranchName(codexBranch, "Codex branch")
    ValidateBranchName(featureBranch, "Feature branch")

    if (codexBranch = featureBranch) {
        MsgBox(APP_NAME . "`n`nCodex branch and feature branch are the same. Nothing to merge.")
        ExitApp()
    }

    confirmationText :=
        APP_NAME . "`n`n"
        . "This will run in the active WezTerm terminal:`n`n"
        . "1. Clear terminal`n"
        . "2. Verify git repo is clean`n"
        . "3. git fetch --all --prune`n"
        . "4. checkout Codex branch:`n"
        . "   " . codexBranch . "`n"
        . "5. Run:`n"
        . "   .\make.ps1 wails`n"
        . "6. If build exits successfully and emits OK:, checkout feature branch:`n"
        . "   " . featureBranch . "`n"
        . "7. Merge Codex branch into feature branch`n`n"
        . "No push will be performed.`n`n"
        . "Press OK to continue or Cancel to abort."

    result := MsgBox(confirmationText, APP_NAME, "OKCancel")

    if (result != "OK") {
        MsgBox(APP_NAME . "`n`nOperation cancelled.")
        ExitApp()
    }

    if !WinActive("ahk_exe wezterm-gui.exe") {
        MsgBox(APP_NAME . "`n`nWezTerm is no longer active. Aborting.")
        ExitApp()
    }

    SendText("Clear")
    Send("{Enter}")
    Sleep(CLEAR_DELAY_MS)

    command := BuildPowerShellCommand(PS_HELPER_FILE, codexBranch, featureBranch)

    Sleep(COMMAND_DELAY_MS)

    if !WinActive("ahk_exe wezterm-gui.exe") {
        MsgBox(APP_NAME . "`n`nWezTerm is no longer active before command send. Aborting.")
        ExitApp()
    }

    SendText(command)
    Send("{Enter}")

    Sleep(100)
    ExitApp()
}

SaveFeatureBranchFromClipboard() {
    global APP_NAME, CONFIG_FILE

    branchName := Trim(A_Clipboard)

    if (branchName = "") {
        MsgBox(APP_NAME . "`n`nClipboard is empty. Copy your feature branch name first.")
        return
    }

    ValidateBranchName(branchName, "Feature branch")

    result := MsgBox(
        APP_NAME . "`n`n"
        . "Save this as the target feature branch?`n`n"
        . branchName,
        APP_NAME,
        "OKCancel"
    )

    if (result != "OK") {
        return
    }

    IniWrite(branchName, CONFIG_FILE, "Branches", "FeatureBranch")

    MsgBox(
        APP_NAME . "`n`n"
        . "Saved feature branch:`n`n"
        . branchName . "`n`n"
        . "This is stored in:`n"
        . CONFIG_FILE
    )
}

ShowSavedFeatureBranch() {
    global APP_NAME, CONFIG_FILE

    featureBranch := IniRead(CONFIG_FILE, "Branches", "FeatureBranch", "")

    MsgBox(
        APP_NAME . "`n`n"
        . "Saved feature branch:`n`n"
        . (featureBranch = "" ? "<none saved yet>" : featureBranch)
    )
}

BuildPowerShellCommand(psHelperFile, codexBranch, featureBranch) {
    return "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
    . QuotePowerShellArg(psHelperFile)
        . " -CodexBranch "
        . QuotePowerShellArg(codexBranch)
        . " -FeatureBranch "
        . QuotePowerShellArg(featureBranch)
}

QuotePowerShellArg(value) {
    return "'" . StrReplace(value, "'", "''") . "'"
}

ValidateBranchName(branchName, label) {
    if (StrLen(branchName) > 200) {
        throw Error(label . " is suspiciously long.")
    }

    if !RegExMatch(branchName, "^[A-Za-z0-9._/\-]+$") {
        throw Error(
            label . " contains unsupported characters.`n`n"
            . "Allowed characters: letters, numbers, dot, underscore, slash, and hyphen.`n`n"
            . "Value:`n"
            . branchName
        )
    }

    if !RegExMatch(branchName, "^[A-Za-z0-9]") || !RegExMatch(branchName, "[A-Za-z0-9]$") {
        throw Error(label . " must start and end with a letter or number.")
    }

    if InStr(branchName, "..") {
        throw Error(label . " cannot contain '..'.")
    }

    if InStr(branchName, "//") {
        throw Error(label . " cannot contain '//'.")
    }

    if InStr(branchName, "/.") || InStr(branchName, "./") {
        throw Error(label . " cannot contain path segments beginning or ending with '.'.")
    }

    if RegExMatch(branchName, "\.lock$") {
        throw Error(label . " cannot end with '.lock'.")
    }
}

EnsurePowerShellHelperScript(psHelperFile) {
    psScript := GetPowerShellHelperScript()

    try {
        if FileExist(psHelperFile) {
            FileDelete(psHelperFile)
        }

        FileAppend(psScript, psHelperFile, "UTF-8")
    } catch as err {
        throw Error("Failed to write PowerShell helper script.`n`n" . err.Message)
    }
}

GetPowerShellHelperScript() {
    lines := []

    lines.Push("param(")
    lines.Push("    [Parameter(Mandatory = $true)]")
    lines.Push("    [string]$CodexBranch,")
    lines.Push("")
    lines.Push("    [Parameter(Mandatory = $true)]")
    lines.Push("    [string]$FeatureBranch")
    lines.Push(")")
    lines.Push("")
    lines.Push("$ErrorActionPreference = 'Continue'")
    lines.Push("")
    lines.Push("function Write-Step {")
    lines.Push("    param([string]$Message)")
    lines.Push("    Write-Host ''")
    lines.Push("    Write-Host ('== ' + $Message) -ForegroundColor Cyan")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Fail {")
    lines.Push("    param([string]$Message)")
    lines.Push("    Write-Host ''")
    lines.Push("    Write-Host ('FAIL: ' + $Message) -ForegroundColor Red")
    lines.Push("    exit 1")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Require-CleanWorkingTree {")
    lines.Push("    $status = git status --porcelain")
    lines.Push("    if ($LASTEXITCODE -ne 0) { Fail 'Unable to read git status.' }")
    lines.Push("    if ($status) {")
    lines.Push("        Write-Host ''")
    lines.Push("        Write-Host 'Working tree is not clean:' -ForegroundColor Yellow")
    lines.Push("        $status | ForEach-Object { Write-Host $_ }")
    lines.Push("        Fail 'Commit, stash, or discard local changes before running this helper.'")
    lines.Push("    }")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Test-LocalBranch {")
    lines.Push("    param([string]$BranchName)")
    lines.Push("    git show-ref --verify --quiet ('refs/heads/' + $BranchName)")
    lines.Push("    return ($LASTEXITCODE -eq 0)")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Test-RemoteBranch {")
    lines.Push("    param([string]$BranchName)")
    lines.Push("    git show-ref --verify --quiet ('refs/remotes/origin/' + $BranchName)")
    lines.Push("    return ($LASTEXITCODE -eq 0)")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Checkout-CodexBranch {")
    lines.Push("    param([string]$BranchName)")
    lines.Push("    if (Test-LocalBranch $BranchName) {")
    lines.Push("        git checkout $BranchName")
    lines.Push("        if ($LASTEXITCODE -ne 0) { Fail ('Failed to checkout local Codex branch: ' + $BranchName) }")
    lines.Push("        return")
    lines.Push("    }")
    lines.Push("")
    lines.Push("    if (Test-RemoteBranch $BranchName) {")
    lines.Push("        git checkout -B $BranchName ('origin/' + $BranchName)")
    lines.Push("        if ($LASTEXITCODE -ne 0) { Fail ('Failed to create local Codex branch from origin/' + $BranchName) }")
    lines.Push("        return")
    lines.Push("    }")
    lines.Push("")
    lines.Push("    Fail ('Codex branch does not exist locally or on origin: ' + $BranchName)")
    lines.Push("}")
    lines.Push("")
    lines.Push("function Checkout-ExistingLocalBranch {")
    lines.Push("    param([string]$BranchName)")
    lines.Push("    if (-not (Test-LocalBranch $BranchName)) { Fail ('Target feature branch must already exist locally: ' + $BranchName) }")
    lines.Push("    git checkout $BranchName")
    lines.Push("    if ($LASTEXITCODE -ne 0) { Fail ('Failed to checkout feature branch: ' + $BranchName) }")
    lines.Push("}")
    lines.Push("")
    lines.Push("Write-Step 'Eve Flipper Codex Build/Merge Helper'")
    lines.Push("")
    lines.Push("if ($CodexBranch -eq $FeatureBranch) { Fail 'Codex branch and feature branch are the same branch.' }")
    lines.Push("")
    lines.Push("$repoRoot = git rev-parse --show-toplevel 2>$null")
    lines.Push("if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) { Fail 'Current terminal directory is not inside a git repository.' }")
    lines.Push("")
    lines.Push("Set-Location $repoRoot")
    lines.Push("Write-Host ('Repo: ' + $repoRoot)")
    lines.Push("")
    lines.Push("Write-Step 'Checking clean working tree'")
    lines.Push("Require-CleanWorkingTree")
    lines.Push("")
    lines.Push("Write-Step 'Fetching branches'")
    lines.Push("git fetch --all --prune")
    lines.Push("if ($LASTEXITCODE -ne 0) { Fail 'git fetch --all --prune failed.' }")
    lines.Push("")
    lines.Push("Write-Step ('Checking out Codex branch: ' + $CodexBranch)")
    lines.Push("Checkout-CodexBranch $CodexBranch")
    lines.Push("")
    lines.Push("Write-Step 'Checking clean working tree after checkout'")
    lines.Push("Require-CleanWorkingTree")
    lines.Push("")
    lines.Push("Write-Step 'Building with .\make.ps1 wails'")
    lines.Push("Write-Step 'Building with .\make.ps1 wails'")
    lines.Push("$buildStartTime = Get-Date")
    lines.Push("$previousErrorActionPreference = $ErrorActionPreference")
    lines.Push("$ErrorActionPreference = 'Continue'")
    lines.Push("$buildOutput = & .\make.ps1 wails 2>&1")
    lines.Push("$buildExitCode = $LASTEXITCODE")
    lines.Push("$ErrorActionPreference = $previousErrorActionPreference")
    lines.Push("")
    lines.Push("$buildOutputText = $buildOutput | ForEach-Object { $_.ToString() }")
    lines.Push("$buildOutputText | ForEach-Object { Write-Host $_ }")
    lines.Push("")
    lines.Push("if ($buildExitCode -ne 0) { Fail ('Build failed with exit code ' + $buildExitCode + '. Merge skipped.') }")
    lines.Push("")
    lines.Push("$wailsBinaryPath = Join-Path $repoRoot 'build\eve-flipper-wails.exe'")
    lines.Push("if (-not (Test-Path -LiteralPath $wailsBinaryPath)) {")
    lines.Push("    Fail ('Build exited successfully, but expected binary was not found: ' + $wailsBinaryPath)")
    lines.Push("}")
    lines.Push("")
    lines.Push("$binaryInfo = Get-Item -LiteralPath $wailsBinaryPath")
    lines.Push("Write-Host ''")
    lines.Push("Write-Host ('Verified Wails binary: ' + $binaryInfo.FullName) -ForegroundColor Green")
    lines.Push("Write-Host ('Binary last write time: ' + $binaryInfo.LastWriteTime) -ForegroundColor DarkGreen")
    lines.Push("")
    lines.Push("$frontendBuiltLine = $buildOutputText | Where-Object { $_ -match 'built in\s+\d+(\.\d+)?s' } | Select-Object -Last 1")
    lines.Push("$okLine = $buildOutputText | Where-Object { $_ -match 'OK:\s*build[/\\]eve-flipper-wails\.exe' } | Select-Object -Last 1")
    lines.Push("")
    lines.Push("if ($frontendBuiltLine) {")
    lines.Push("    Write-Host ('Frontend build marker found: ' + $frontendBuiltLine) -ForegroundColor Green")
    lines.Push("} else {")
    lines.Push("    Write-Host 'Frontend build marker was not found, but exit code and binary check passed.' -ForegroundColor Yellow")
    lines.Push("}")
    lines.Push("")
    lines.Push("if ($okLine) {")
    lines.Push("    Write-Host ('Wails OK marker found: ' + $okLine) -ForegroundColor Green")
    lines.Push("} else {")
    lines.Push("    Write-Host 'Wails OK marker was not found in captured text, but exit code and binary check passed.' -ForegroundColor Yellow")
    lines.Push("}")
    lines.Push("")
    lines.Push("Write-Step 'Checking clean working tree after build'")
    lines.Push("Require-CleanWorkingTree")
    lines.Push("")
    lines.Push("Write-Step ('Checking out target feature branch: ' + $FeatureBranch)")
    lines.Push("Checkout-ExistingLocalBranch $FeatureBranch")
    lines.Push("")
    lines.Push("Write-Step 'Checking clean working tree before merge'")
    lines.Push("Require-CleanWorkingTree")
    lines.Push("")
    lines.Push("Write-Step ('Merging Codex branch into feature branch: ' + $CodexBranch + ' -> ' + $FeatureBranch)")
    lines.Push("git merge --no-ff --no-edit $CodexBranch")
    lines.Push("if ($LASTEXITCODE -ne 0) { Fail 'Merge failed. Resolve conflicts manually, then continue or abort the merge yourself.' }")
    lines.Push("")
    lines.Push("Write-Step 'Final status'")
    lines.Push("git status --short --branch")
    lines.Push("")
    lines.Push("Write-Host ''")
    lines.Push("Write-Host ('SUCCESS: merged ' + $CodexBranch + ' into ' + $FeatureBranch) -ForegroundColor Green")
    lines.Push("Write-Host 'No push was performed.' -ForegroundColor Yellow")
    lines.Push("exit 0")

    return JoinLines(lines)
}

JoinLines(lines) {
    text := ""

    for _, line in lines {
        text .= line . "`r`n"
    }

    return text
}
