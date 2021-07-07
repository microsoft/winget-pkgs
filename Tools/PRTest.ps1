# This script does a checkout of a Pull Request using the GitHub CLI, and then runs it using SandboxTest.ps1.

Param(
  [Parameter(Position = 0, HelpMessage = "The Pull Request to checkout.", Mandatory=$true)]
  [String] $PullRequest,
  [Parameter(HelpMessage = "Open the Pull Request's review page in the default browser")]
  [Switch] $Review = $false
)
$ErrorActionPreference = "Stop"

$repositoryRoot = "https://github.com/microsoft/winget-pkgs/"

$rootDirectory = ((Resolve-Path (git rev-parse --show-toplevel)).ToString() + "\")

if (-Not (Get-Command "gh" -ErrorAction "SilentlyContinue")) {
    Write-Host "The GitHub CLI is not installed. Install it via 'winget install gh' and come back here!" -ForegroundColor Red
    return
}

gh pr checkout $PullRequest | Out-Null

if($LASTEXITCODE -ne 0) {
    Write-Host "There was an error checking out the PR. Make sure you're logged into GitHub via 'gh auth login' and come back here!" -ForegroundColor Red
    return
}

$manifest = (git diff --name-only HEAD~1..HEAD)
if ($manifest.GetType().Name -eq "Object[]") {
    $path = (Get-Item (Resolve-Path ($rootDirectory + $manifest[0]))).Directory
}
else {
    $path = (Get-Item (Resolve-Path ($rootDirectory + $manifest))).Directory
}

$sandboxTestPath = (Resolve-Path ($PSScriptRoot.ToString() + "\SandboxTest.ps1")).ToString()
& $sandboxTestPath $path

if ($Review) {
    Write-Host "Opening $PullRequest in browser..." -ForegroundColor Green
    Start-Process ($repositoryRoot + "pull/" + $PullRequest + "/files")
}