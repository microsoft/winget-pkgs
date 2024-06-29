# This script does a checkout of a Pull Request using the GitHub CLI, and then runs it using SandboxTest.ps1.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]

Param(
    [Parameter(Position = 0, HelpMessage = 'The Pull Request to checkout.', Mandatory = $true)]
    [String] $PullRequest,
    [Parameter(HelpMessage = "Open the Pull Request's review page in the default browser")]
    [Switch] $Review = $false,
    [Switch] $KeepBranch = $false,
    [Switch] $Prerelease = $false,
    [Switch] $EnableExperimentalFeatures = $false,
    [string] $WinGetVersion = $null
)

$PullRequest = $PullRequest.TrimStart('#')

$ErrorActionPreference = 'Stop'

$repositoryRoot = 'https://github.com/microsoft/winget-pkgs/'

$rootDirectory = ((Resolve-Path (git rev-parse --show-toplevel)).ToString() + '\')

if (-Not (Get-Command 'gh' -ErrorAction 'SilentlyContinue')) {
    Write-Host "The GitHub CLI is not installed. Install it via 'winget install GitHub.cli' and come back here!" -ForegroundColor Red
    return
}

if (-Not (Get-Command 'git' -ErrorAction 'SilentlyContinue')) {
    Write-Host "Git is not installed. Install it via 'winget install Git.Git' and come back here!" -ForegroundColor Red
    return
}

gh pr checkout $PullRequest $(if (!$KeepBranch) { '--detach' }) -f | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "There was an error checking out the PR. Make sure you're logged into GitHub via 'gh auth login' and come back here!" -ForegroundColor Red
    return
}

$manifest = (git diff --name-only HEAD~1..HEAD)
if ($manifest.GetType().Name -eq 'Object[]') {
    $path = (Get-Item (Resolve-Path ($rootDirectory + $manifest[0]))).Directory
} else {
    $path = (Get-Item (Resolve-Path ($rootDirectory + $manifest))).Directory
}

$sandboxTestPath = (Resolve-Path ($PSScriptRoot.ToString() + '\SandboxTest.ps1')).ToString()
$params = @{
    Manifest                   = $path
    SkipManifestValidation     = $true
    Prerelease                 = $Prerelease
    EnableExperimentalFeatures = $EnableExperimentalFeatures
    WinGetVersion              = $WinGetVersion
}
& $sandboxTestPath @params

if ($Review) {
    Write-Host "Opening $PullRequest in browser..." -ForegroundColor Green
    Start-Process ($repositoryRoot + 'pull/' + $PullRequest + '/files')
}
