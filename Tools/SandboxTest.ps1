# Parse arguments

Param(
  [Parameter(Position = 0, HelpMessage = "The Manifest to install in the Sandbox.")]
  [String] $Manifest,
  [Parameter(Position = 1, HelpMessage = "The script to run in the Sandbox.")]
  [ScriptBlock] $Script,
  [Parameter(HelpMessage = "The folder to map in the Sandbox.")]
  [String] $MapFolder = $pwd,
  [switch] $SkipManifestValidation
)

$ErrorActionPreference = "Stop"

$mapFolder = (Resolve-Path -Path $MapFolder).Path

if (-Not (Test-Path -Path $mapFolder -PathType Container)) {
  Write-Error -Category InvalidArgument -Message 'The provided MapFolder is not a folder.'
}

# Validate manifest file

if (-Not $SkipManifestValidation -And -Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Write-Host '--> Validating Manifest'

  if (-Not (Test-Path -Path $Manifest)) {
    throw 'The Manifest does not exist.'
  }

  winget.exe validate $Manifest
  if (-Not $?) {
    throw 'Manifest validation failed.'
  }

  Write-Host
}

# Check if Windows Sandbox is enabled

if (-Not (Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue)) {
  Write-Error -Category NotInstalled -Message @'
Windows Sandbox does not seem to be available. Check the following URL for prerequisites and further details:
https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview

You can run the following command in an elevated PowerShell for enabling Windows Sandbox:
$ Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM'
'@
}

# Close Windows Sandbox

$sandbox = Get-Process 'WindowsSandboxClient' -ErrorAction SilentlyContinue
if ($sandbox) {
  Write-Host '--> Closing Windows Sandbox'

  $sandbox | Stop-Process
  Start-Sleep -Seconds 5

  Write-Host
}
Remove-Variable sandbox

# Initialize Temp Folder

$tempFolderName = 'SandboxTest'
$tempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $tempFolderName

New-Item $tempFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# Set dependencies

$apiLatestUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WebClient = New-Object System.Net.WebClient

function Get-LatestUrl {
  ((Invoke-WebRequest $apiLatestUrl -UseBasicParsing | ConvertFrom-Json).assets | Where-Object { $_.name -match '^Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle$' }).browser_download_url
}

function Get-LatestHash {
  $shaUrl = ((Invoke-WebRequest $apiLatestUrl -UseBasicParsing | ConvertFrom-Json).assets | Where-Object { $_.name -match '^Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt$' }).browser_download_url

  $shaFile = Join-Path -Path $tempFolder -ChildPath 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt'
  $WebClient.DownloadFile($shaUrl, $shaFile)

  Get-Content $shaFile
}

# Hide the progress bar of Invoke-WebRequest
$oldProgressPreference = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'

$desktopAppInstaller = @{
  fileName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
  url      = $(Get-LatestUrl)
  hash     = $(Get-LatestHash)
}

$ProgressPreference = $oldProgressPreference

$vcLibsUwp = @{
  fileName = 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
  url      = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
  hash     = '6602159c341bafea747d0edf15669ac72df8817299fbfaa90469909e06794256'
}

$dependencies = @($desktopAppInstaller, $vcLibsUwp)

# Clean temp directory

Get-ChildItem $tempFolder -Recurse -Exclude $dependencies.fileName | Remove-Item -Force -Recurse

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Copy-Item -Path $Manifest -Recurse -Destination $tempFolder
}

# Download dependencies

Write-Host '--> Checking dependencies'

$desktopInSandbox = 'C:\Users\WDAGUtilityAccount\Desktop'

foreach ($dependency in $dependencies) {
  $dependency.file = Join-Path -Path $tempFolder -ChildPath $dependency.fileName
  $dependency.pathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $dependency.fileName)

  # Only download if the file does not exist, or its hash does not match.
  if (-Not ((Test-Path -Path $dependency.file -PathType Leaf) -And $dependency.hash -eq $(get-filehash $dependency.file).Hash)) {
    Write-Host @"
    - Downloading:
      $($dependency.url)
"@

    try {
      $WebClient.DownloadFile($dependency.url, $dependency.file)
    }
    catch {
      throw "Error downloading $($dependency.url)."
    }
    if (-not ($dependency.hash -eq $(get-filehash $dependency.file).Hash)) {
      throw 'Hashes do not match, try gain.'
    }
  }
}

Write-Host

# Create Bootstrap script

# See: https://stackoverflow.com/a/22670892/12156188
$bootstrapPs1Content = @'
function Update-EnvironmentVariables {
  foreach($level in "Machine","User") {
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
        # For Path variables, append the new values, if they're not already in there
        if($_.Name -match 'Path$') {
          $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
        }
        $_
    } | Set-Content -Path { "Env:$($_.Name)" }
  }
}


'@

$bootstrapPs1Content += @"
Write-Host @'
--> Installing WinGet

'@
Add-AppxPackage -Path '$($desktopAppInstaller.pathInSandbox)' -DependencyPath '$($vcLibsUwp.pathInSandbox)'

Write-Host @'

Tip: you can type 'Update-EnvironmentVariables' to update your environment variables, such as after installing a new software.

'@


"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  $manifestFileName = Split-Path $Manifest -Leaf
  $manifestPathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $manifestFileName)

  $bootstrapPs1Content += @"
Write-Host @'

--> Installing the Manifest $manifestFileName

'@
winget install -m '$manifestPathInSandbox'

Write-Host @'

--> Refreshing environment variables
'@
Update-EnvironmentVariables


"@
}

if (-Not [String]::IsNullOrWhiteSpace($Script)) {
  $bootstrapPs1Content += @"
Write-Host @'

--> Running the following script:

{
$Script
}

'@

$Script


"@
}

$bootstrapPs1Content += @"
Write-Host
"@

$bootstrapPs1FileName = 'Bootstrap.ps1'
$bootstrapPs1Content | Out-File (Join-Path -Path $tempFolder -ChildPath $bootstrapPs1FileName)

# Create Wsb file

$bootstrapPs1InSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $bootstrapPs1FileName)
$mapFolderInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Split-Path -Path $mapFolder -Leaf)

$sandboxTestWsbContent = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$tempFolder</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$mapFolder</HostFolder>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
  <Command>PowerShell Start-Process PowerShell -WindowStyle Maximized -WorkingDirectory '$mapFolderInSandbox' -ArgumentList '-ExecutionPolicy Bypass -NoExit -NoLogo -File $bootstrapPs1InSandbox'</Command>
  </LogonCommand>
</Configuration>
"@

$sandboxTestWsbFileName = 'SandboxTest.wsb'
$sandboxTestWsbFile = Join-Path -Path $tempFolder -ChildPath $sandboxTestWsbFileName
$sandboxTestWsbContent | Out-File $sandboxTestWsbFile

Write-Host @"
--> Starting Windows Sandbox, and:
    - Mounting the following directories:
      - $tempFolder as read-only
      - $mapFolder as read-and-write
    - Installing WinGet
"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Write-Host @"
    - Installing the Manifest $manifestFileName
    - Refreshing environment variables
"@
}

if (-Not [String]::IsNullOrWhiteSpace($Script)) {
  Write-Host @"
    - Running the following script:

{
$Script
}
"@
}

Write-Host

WindowsSandbox $SandboxTestWsbFile
