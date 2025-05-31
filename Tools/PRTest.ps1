# This script does a checkout of a Pull Request using the GitHub CLI, and then runs it using SandboxTest.ps1.

Param(
    [Parameter(Position = 0, HelpMessage = 'The Pull Request to checkout.', Mandatory = $true)]
    [String] $PullRequest,
    [Parameter(HelpMessage = "Open the Pull Request's review page in the default browser")]
    [Switch] $Review = $false,
    [Switch] $KeepBranch = $false,
    [Switch] $Prerelease = $false,
    [Switch] $EnableExperimentalFeatures = $false,
    [string] $WinGetVersion = $null,
    [string] $WinGetOptions,
    [scriptblock] $Script = $null,
    [string] $MapFolder = $pwd,
    [switch] $Clean
)

# Virtual Terminal
filter Initialize-VirtualTerminalSequence {
    # https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences
    if ($script:vtSupported) {
        return "$([char]0x001B)[${_}m"
    }
}

# Flags
Write-Debug 'Checking for supported features'
$script:vtSupported = (Get-Host).UI.SupportsVirtualTerminal
$script:GitIsPresent = Get-Command 'git' -ErrorAction SilentlyContinue
$script:GhIsPresent = Get-Command 'gh' -ErrorAction SilentlyContinue
$script:SandboxIsPresent = Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue

Write-Debug 'Initializing Virtual Terminal Sequences'
$script:vtDefault = 0 | Initialize-VirtualTerminalSequence
$script:vtForegroundGreen = 32 | Initialize-VirtualTerminalSequence

Write-Debug 'Creating internal state'
$PullRequest = $PullRequest.TrimStart('#')
$ErrorActionPreference = 'Stop'
$repositoryRoot = 'https://github.com/microsoft/winget-pkgs/'
$rootDirectory = ((Resolve-Path (git rev-parse --show-toplevel)).ToString() + '\')

Write-Verbose 'Ensuring Dependencies are Present'
if (!$script:GhIsPresent) { Write-Error "The GitHub CLI is not installed. Install it via 'winget install GitHub.cli' and come back here!" -ErrorAction Stop }
if (!$script:GitIsPresent) { Write-Error "Git is not installed. Install it via 'winget install Git.Git' and come back here!" -ErrorAction Stop }
if (!$script:SandboxIsPresent) { Write-Error 'Windows Sandbox is not enabled. Enable it and come back here!' -ErrorAction Stop }

Write-Verbose 'Checking out PR'
gh pr checkout $PullRequest $(if (!$KeepBranch) { '--detach' }) -f -R $repositoryRoot | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "There was an error checking out the PR. Make sure you're logged into GitHub via 'gh auth login' and come back here!" -ErrorAction Stop }

Write-Verbose 'Parsing changed files'
$manifest = @(gh pr diff $PullRequest --name-only)
$path = (Get-Item (Resolve-Path ($rootDirectory + $manifest[0]))).Directory

Write-Verbose 'Passing execution to SandboxTest.ps1'
$sandboxTestPath = (Resolve-Path ($PSScriptRoot.ToString() + '\SandboxTest.ps1')).ToString()
$params = @{
    Manifest                   = $path
    SkipManifestValidation     = $true
    Prerelease                 = $Prerelease
    EnableExperimentalFeatures = $EnableExperimentalFeatures
    WinGetVersion              = $WinGetVersion
    WinGetOptions              = $WinGetOptions
    Script                     = $Script
    MapFolder                  = $MapFolder
    Clean                      = $Clean
}
& $sandboxTestPath @params

if ($Review) {
    Write-Information "${script:vtForegroundGreen}" -InformationAction 'Continue'
    & gh pr diff --web $PullRequest
    Write-Information "${script:vtDefault}" -InformationAction 'Continue'
}
