### Exit Codes:
#  0 = Success
#  1 = Missing dependency
#  2 = Pull request checkout error
#  3 = Validation completed check was not found
#  4 = Artifact download URL was not found
#  5 = YAML manifest was not found
###

# This script checks out a Pull Request or downloads its validated merged manifest,
# and then runs it using SandboxTest.ps1.

Param(
    [Parameter(Position = 0, HelpMessage = 'The Pull Request to test.', Mandatory = $true)]
    [String] $PullRequest,
    [Parameter(HelpMessage = "Open the Pull Request's review page in the default browser")]
    [Switch] $Review = $false,
    [Switch] $KeepBranch = $false,
    [Switch] $NoCheckout = $false,
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

function Write-PRTestError {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message,
        [Parameter(Mandatory = $true)]
        [int] $ExitCode
    )

    Write-Error -Message $Message -ErrorAction Continue
    exit $ExitCode
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
$repository = 'microsoft/winget-pkgs'

Write-Verbose 'Ensuring Dependencies are Present'
if (!$script:GhIsPresent) { Write-PRTestError "The GitHub CLI is not installed. Install it via 'winget install GitHub.cli' and come back here!" 1 }
if (!$NoCheckout -and !$script:GitIsPresent) { Write-PRTestError "Git is not installed. Install it via 'winget install Git.Git' and come back here!" 1 }
if (!$script:SandboxIsPresent) { Write-PRTestError 'Windows Sandbox is not enabled. Enable it and come back here!' 1 }

if ($NoCheckout) {
    $rootFolder = Join-Path $env:TEMP 'WinGet-PRTest'
    if ($Clean -and (Test-Path $rootFolder)) { Remove-Item $rootFolder -Recurse -Force }

    Write-Output '--> Retrieving PR check runs'
    $headSha = gh api "repos/$repository/pulls/$PullRequest" --jq '.head.sha'
    $checkRuns = gh api "repos/$repository/commits/$headSha/check-runs?app_id=1451866&filter=latest&per_page=100" |
        ConvertFrom-Json -ErrorAction SilentlyContinue
    $validationCompletedCheck = $checkRuns.check_runs |
        Where-Object {
            $_.name -eq '10. Validation Completed' -and
            $_.app.slug -eq 'wingetvalidator-prod' -and
            $_.head_sha -eq $headSha -and
            $_.status -eq 'completed'
        } |
        Select-Object -First 1

    if (!$validationCompletedCheck) {
        Write-PRTestError "The check run was not found for PR #$PullRequest." 3
    }

    $json = [regex]::Match(
        [string] $validationCompletedCheck.output.text,
        '(?ms)```json\s*(?<json>.*?)\s*```'
    ).Groups['json'].Value
    $artifactDownloadUrl = ($json | ConvertFrom-Json -ErrorAction SilentlyContinue).Artifacts.ArtifactDownloadUrl
    if ([string]::IsNullOrWhiteSpace($artifactDownloadUrl)) {
        Write-PRTestError "The artifact download URL was not found for PR #$PullRequest." 4
    }

    $runFolder = Join-Path $rootFolder "$PullRequest\$headSha"
    $zipPath = Join-Path $runFolder 'artifacts.zip'
    $manifestFolder = Join-Path $runFolder 'Manifest'
    if (Test-Path $runFolder) { Remove-Item $runFolder -Recurse -Force }
    New-Item $manifestFolder -ItemType Directory | Out-Null

    Write-Output '--> Downloading validation artifact'
    Invoke-WebRequest $artifactDownloadUrl -OutFile $zipPath

    # Only extract the YAML manifest entry from the archive; the artifact also contains
    # installation verification logs whose long, nested paths can fail to extract.
    $manifestFile = $null
    try {
        $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        $yamlEntries = @($zipArchive.Entries | Where-Object { $_.Name -like '*.yaml' })
        if ($yamlEntries.Count -eq 1) {
            Write-Output "--> Extracting file: $($yamlEntries[0].Name)"
            $manifestFile = Join-Path $manifestFolder $yamlEntries[0].Name
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($yamlEntries[0], $manifestFile)
        }
    } finally {
        if ($zipArchive) { $zipArchive.Dispose() }
    }

    if (!$manifestFile -or !(Test-Path $manifestFile -PathType Leaf)) {
        Write-PRTestError "A single YAML manifest was not found in the validation artifact for PR #$PullRequest." 5
    }

    $path = $manifestFolder
} else {
    $repositoryRoot = 'https://github.com/microsoft/winget-pkgs/'
    $rootDirectory = ((Resolve-Path (git rev-parse --show-toplevel)).ToString() + '\')

    Write-Verbose 'Checking out PR'
    gh pr checkout $PullRequest $(if (!$KeepBranch) { '--detach' }) -f -R $repositoryRoot | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-PRTestError "There was an error checking out the PR. Make sure you're logged into GitHub via 'gh auth login' and come back here!" 2
    }

    Write-Verbose 'Parsing changed files'
    $manifest = @(gh pr diff $PullRequest --name-only)
    $path = (Get-Item (Resolve-Path ($rootDirectory + $manifest[0]))).Directory
}

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
