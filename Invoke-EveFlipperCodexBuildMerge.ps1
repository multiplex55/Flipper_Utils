param(
    [Parameter(Mandatory = $true)]
    [string]$CodexBranch,

    [Parameter(Mandatory = $true)]
    [string]$FeatureBranch
)

$ErrorActionPreference = 'Continue'

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host ('== ' + $Message) -ForegroundColor Cyan
}

function Fail {
    param([string]$Message)
    Write-Host ''
    Write-Host ('FAIL: ' + $Message) -ForegroundColor Red
    exit 1
}

function Require-CleanWorkingTree {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) { Fail 'Unable to read git status.' }
    if ($status) {
        Write-Host ''
        Write-Host 'Working tree is not clean:' -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host $_ }
        Fail 'Commit, stash, or discard local changes before running this helper.'
    }
}

function Test-LocalBranch {
    param([string]$BranchName)
    git show-ref --verify --quiet ('refs/heads/' + $BranchName)
    return ($LASTEXITCODE -eq 0)
}

function Test-RemoteBranch {
    param([string]$BranchName)
    git show-ref --verify --quiet ('refs/remotes/origin/' + $BranchName)
    return ($LASTEXITCODE -eq 0)
}

function Checkout-CodexBranch {
    param([string]$BranchName)
    if (Test-LocalBranch $BranchName) {
        git checkout $BranchName
        if ($LASTEXITCODE -ne 0) { Fail ('Failed to checkout local Codex branch: ' + $BranchName) }
        return
    }

    if (Test-RemoteBranch $BranchName) {
        git checkout -B $BranchName ('origin/' + $BranchName)
        if ($LASTEXITCODE -ne 0) { Fail ('Failed to create local Codex branch from origin/' + $BranchName) }
        return
    }

    Fail ('Codex branch does not exist locally or on origin: ' + $BranchName)
}

function Checkout-ExistingLocalBranch {
    param([string]$BranchName)
    if (-not (Test-LocalBranch $BranchName)) { Fail ('Target feature branch must already exist locally: ' + $BranchName) }
    git checkout $BranchName
    if ($LASTEXITCODE -ne 0) { Fail ('Failed to checkout feature branch: ' + $BranchName) }
}

Write-Step 'Eve Flipper Codex Build/Merge Helper'

if ($CodexBranch -eq $FeatureBranch) { Fail 'Codex branch and feature branch are the same branch.' }

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) { Fail 'Current terminal directory is not inside a git repository.' }

Set-Location $repoRoot
Write-Host ('Repo: ' + $repoRoot)

Write-Step 'Checking clean working tree'
Require-CleanWorkingTree

Write-Step 'Fetching branches'
git fetch --all --prune
if ($LASTEXITCODE -ne 0) { Fail 'git fetch --all --prune failed.' }

Write-Step ('Checking out Codex branch: ' + $CodexBranch)
Checkout-CodexBranch $CodexBranch

Write-Step 'Checking clean working tree after checkout'
Require-CleanWorkingTree

Write-Step 'Building with .\make.ps1 wails'
$buildStartTime = Get-Date
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$buildOutput = & .\make.ps1 wails 2>&1
$buildExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

$buildOutputText = $buildOutput | ForEach-Object { $_.ToString() }
$buildOutputText | ForEach-Object { Write-Host $_ }

if ($buildExitCode -ne 0) { Fail ('Build failed with exit code ' + $buildExitCode + '. Merge skipped.') }

$wailsBinaryPath = Join-Path $repoRoot 'build\eve-flipper-wails.exe'
if (-not (Test-Path -LiteralPath $wailsBinaryPath)) {
    Fail ('Build exited successfully, but expected binary was not found: ' + $wailsBinaryPath)
}

$binaryInfo = Get-Item -LiteralPath $wailsBinaryPath
Write-Host ''
Write-Host ('Verified Wails binary: ' + $binaryInfo.FullName) -ForegroundColor Green
Write-Host ('Binary last write time: ' + $binaryInfo.LastWriteTime) -ForegroundColor DarkGreen

$frontendBuiltLine = $buildOutputText | Where-Object { $_ -match 'built in\s+\d+(\.\d+)?s' } | Select-Object -Last 1
$okLine = $buildOutputText | Where-Object { $_ -match 'OK:\s*build[/\\]eve-flipper-wails\.exe' } | Select-Object -Last 1

if ($frontendBuiltLine) {
    Write-Host ('Frontend build marker found: ' + $frontendBuiltLine) -ForegroundColor Green
} else {
    Write-Host 'Frontend build marker was not found, but exit code and binary check passed.' -ForegroundColor Yellow
}

if ($okLine) {
    Write-Host ('Wails OK marker found: ' + $okLine) -ForegroundColor Green
} else {
    Write-Host 'Wails OK marker was not found in captured text, but exit code and binary check passed.' -ForegroundColor Yellow
}

Write-Step 'Checking clean working tree after build'
Require-CleanWorkingTree

Write-Step ('Checking out target feature branch: ' + $FeatureBranch)
Checkout-ExistingLocalBranch $FeatureBranch

Write-Step 'Checking clean working tree before merge'
Require-CleanWorkingTree

Write-Step ('Merging Codex branch into feature branch: ' + $CodexBranch + ' -> ' + $FeatureBranch)
git merge --no-ff $CodexBranch
if ($LASTEXITCODE -ne 0) { Fail 'Merge failed. Resolve conflicts manually, then continue or abort the merge yourself.' }

Write-Step 'Final status'
git status --short --branch

Write-Host ''
Write-Host ('SUCCESS: merged ' + $CodexBranch + ' into ' + $FeatureBranch) -ForegroundColor Green
Write-Host 'No push was performed.' -ForegroundColor Yellow
exit 0
