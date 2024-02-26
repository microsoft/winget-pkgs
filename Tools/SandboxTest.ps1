# Parse arguments
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Prerelease', Justification = 'The variable is used in a conditional but ScriptAnalyser does not recognize the scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'WinGetVersion', Justification = 'The variable is used in a conditional but ScriptAnalyser does not recognize the scope')]

Param(
  [Parameter(Position = 0, HelpMessage = 'The Manifest to install in the Sandbox.')]
  [String] $Manifest,
  [Parameter(Position = 1, HelpMessage = 'The script to run in the Sandbox.')]
  [ScriptBlock] $Script,
  [Parameter(HelpMessage = 'The folder to map in the Sandbox.')]
  [String] $MapFolder = $pwd,
  [switch] $SkipManifestValidation,
  [switch] $Prerelease,
  [switch] $EnableExperimentalFeatures,
  [string] $WinGetVersion,
  [Parameter(HelpMessage = 'Additional options for WinGet')]
  [string] $WinGetOptions
)

$ErrorActionPreference = 'Stop'

$mapFolder = (Resolve-Path -Path $MapFolder).Path

if (-Not (Test-Path -Path $mapFolder -PathType Container)) {
  Write-Error -Category InvalidArgument -Message 'The provided MapFolder is not a folder.'
}

# Validate manifest file

if (-Not $SkipManifestValidation -And -Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Write-Host '--> Validating Manifest'

  if (-Not (Test-Path -Path $Manifest)) {
    throw [System.IO.DirectoryNotFoundException]::new('The Manifest does not exist.')
  }

  winget.exe validate $Manifest
  switch ($LASTEXITCODE) {
    '-1978335191' { throw [System.Activities.ValidationException]::new('Manifest validation failed.') }
    '-1978335192' { Start-Sleep -Seconds 5 }
    Default { continue }
  }

  Write-Host
}

# Check if Windows Sandbox is enabled

if (-Not (Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue)) {
  Write-Error -Category NotInstalled -Message @'
Windows Sandbox does not seem to be available. Check the following URL for prerequisites and further details:
https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview

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
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WebClient = New-Object System.Net.WebClient

function Get-Release {
  $releasesAPIResponse = Invoke-RestMethod 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
  if (!$script:Prerelease) {
    $releasesAPIResponse = $releasesAPIResponse.Where({ !$_.prerelease })
  }
  if (![String]::IsNullOrWhiteSpace($script:WinGetVersion)) {
    $releasesAPIResponse = @($releasesAPIResponse.Where({ $_.tag_name -match $('^v?' + [regex]::escape($script:WinGetVersion)) }))
  }
  if ($releasesAPIResponse.Count -lt 1) {
    Write-Output 'No WinGet releases found matching criteria'
    exit 1
  }
  $releasesAPIResponse = $releasesAPIResponse | Sort-Object -Property published_at -Descending

  $assets = $releasesAPIResponse[0].assets
  $shaFileUrl = $assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt' }).browser_download_url
  $shaFile = New-TemporaryFile
  $WebClient.DownloadFile($shaFileUrl, $shaFile.FullName)

  return @{
    shaFileUrl     = $assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt' }).browser_download_url
    msixFileUrl    = $assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' }).browser_download_url
    releaseTag     = $releasesAPIResponse[0].tag_name
    shaFileContent = $(Get-Content $shaFile.FullName)
  }
}

# Hide the progress bar of Invoke-WebRequest
$oldProgressPreference = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'

$latestRelease = Get-Release
$versionTag = $latestRelease.releaseTag
$desktopAppInstaller = @{
  url    = $latestRelease.msixFileUrl
  hash   = $latestRelease.shaFileContent
  SaveTo = $(Join-Path $env:LOCALAPPDATA -ChildPath "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\bin\$versionTag\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle")
}

$ProgressPreference = $oldProgressPreference

$vcLibsUwp = @{
  url    = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
  hash   = 'B56A9101F706F9D95F815F5B7FA6EFBAC972E86573D378B96A07CFF5540C5961'
  SaveTo = $(Join-Path $tempFolder -ChildPath 'Microsoft.VCLibs.x64.14.00.Desktop.appx')
}
$uiLibsUwp = @{
  url    = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
  hash   = '8CE30D92ABEC6522BEB2544E7B716983F5CBA50751B580D89A36048BF4D90316'
  SaveTo = $(Join-Path $tempFolder -ChildPath 'Microsoft.UI.Xaml.2.7.x64.appx')
}

$dependencies = @($desktopAppInstaller, $vcLibsUwp, $uiLibsUwp)

# Clean temp directory
Get-ChildItem $tempFolder -Recurse -Exclude $($(Split-Path $dependencies.SaveTo -Leaf) -replace '\.([^\.]+)$', '.*') | Remove-Item -Force -Recurse

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Copy-Item -Path $Manifest -Recurse -Destination $tempFolder
}

# Download dependencies

Write-Host '--> Checking dependencies'

$desktopInSandbox = 'C:\Users\WDAGUtilityAccount\Desktop'

foreach ($dependency in $dependencies) {
  $dependency.pathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $(Split-Path $dependency.SaveTo -Leaf))

  # Only download if the file does not exist, or its hash does not match.
  if (-Not ((Test-Path -Path $dependency.SaveTo) -And $dependency.hash -eq $(Get-FileHash $dependency.SaveTo).Hash)) {
    Write-Host @"
    - Downloading:
      $($dependency.url)
"@

    try {
      # If the directory doesn't already exist, create it
      $saveDirectory = Split-Path $dependency.SaveTo
      if (-Not (Test-Path -Path $saveDirectory)) {
        New-Item -ItemType Directory -Path $saveDirectory -Force | Out-Null
      }
      $WebClient.DownloadFile($dependency.url, $dependency.SaveTo)

    } catch {
      # If the download failed, remove the item so the sandbox can fall-back to using the PowerShell module
      Remove-Item $dependency.SaveTo -Force | Out-Null
    }
    if (-not ($dependency.hash -eq $(Get-FileHash $dependency.SaveTo).Hash)) {
      # If the hash didn't match, remove the item so the sandbox can fall-back to using the PowerShell module
      Write-Host -ForegroundColor Red '      Dependency hash does not match the downloaded file'
      Write-Host -ForegroundColor Red '      Please open an issue referencing this error at https://bit.ly/WinGet-SandboxTest-Needs-Update'
      Write-Host
      Remove-Item $dependency.SaveTo -Force | Out-Null
    }
  }
}

# Copy the version of winget to the sandbox test folder
Copy-Item -Path $desktopAppInstaller.SaveTo -Destination (Join-Path -Path $tempFolder -ChildPath (Split-Path $desktopAppInstaller.SaveTo -Leaf))

# Create Bootstrap settings
# Experimental features can be enabled for forward compatibility with PR's
$bootstrapSettingsContent = @{}
$bootstrapSettingsContent['$schema'] = 'https://aka.ms/winget-settings.schema.json'
$bootstrapSettingsContent['logging'] = @{level = 'verbose' }
if ($EnableExperimentalFeatures) {
  $bootstrapSettingsContent['experimentalFeatures'] = @{
    dependencies     = $true
    openLogsArgument = $true
  }
}

$settingsFolderName = 'WingetSettings'
$settingsFolder = Join-Path -Path $tempFolder -ChildPath $settingsFolderName

New-Item $settingsFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$bootstrapSettingsFileName = 'settings.json'
$bootstrapSettingsContent | ConvertTo-Json | Out-File (Join-Path -Path $settingsFolder -ChildPath $bootstrapSettingsFileName) -Encoding ascii
$settingsPathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath "$settingsFolderName\settings.json")

# Create Bootstrap script

# See: https://stackoverflow.com/a/22670892/12156188
$bootstrapPs1Content = @'
function Update-EnvironmentVariables {
  foreach($level in "Machine","User") {
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
        # For Path variables, append the new values, if they're not already in there
        if($_.Name -match '^Path$') {
          $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
        }
        $_
    } | Set-Content -Path { "Env:$($_.Name)" }
  }
}

function Get-ARPTable {
  $registry_paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
  return Get-ItemProperty $registry_paths -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and (-not $_.SystemComponent -or $_.SystemComponent -ne 1 ) } |
      Select-Object DisplayName, DisplayVersion, Publisher, @{N='ProductCode'; E={$_.PSChildName}}, @{N='Scope'; E={if($_.PSDrive.Name -eq 'HKCU') {'User'} else {'Machine'}}}
}
'@

$bootstrapPs1Content += @"
Write-Host @'
--> Installing WinGet
'@
`$ProgressPreference = 'SilentlyContinue'
try {
  Add-AppxPackage -Path '$($desktopAppInstaller.pathInSandbox)' -DependencyPath '$($vcLibsUwp.pathInSandbox)','$($uiLibsUwp.pathInSandbox)'
} catch {
  Write-Host -ForegroundColor Red 'Could not install from cached packages. Falling back to Repair-WinGetPackageManager cmdlet'
  try {
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
  } catch {
    throw "Microsoft.Winget.Client was not installed successfully"
  } finally {
    # Check to be sure it acutally installed
    if (-not(Get-Module -ListAvailable -Name Microsoft.Winget.Client)) {
      throw "Microsoft.Winget.Client was not found. Check that the Windows Package Manager PowerShell module was installed correctly."
    }
  }
  Repair-WinGetPackageManager -Version $versionTag
}

Write-Host @'
--> Disabling safety warning when running installer
'@
New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations' | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations' -Name 'ModRiskFileTypes' -Type 'String' -Value '.bat;.exe;.reg;.vbs;.chm;.msi;.js;.cmd' | Out-Null

Write-Host @'
Tip: you can type 'Update-EnvironmentVariables' to update your environment variables, such as after installing a new software.
'@


"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  $manifestFileName = Split-Path $Manifest -Leaf
  $manifestPathInSandbox = Join-Path -Path $desktopInSandbox -ChildPath (Join-Path -Path $tempFolderName -ChildPath $manifestFileName)

  $bootstrapPs1Content += @"
Write-Host @'

--> Configuring Winget
'@
winget settings --Enable LocalManifestFiles
winget settings --Enable LocalArchiveMalwareScanOverride
copy -Path $settingsPathInSandbox -Destination C:\Users\WDAGUtilityAccount\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json
`$originalARP = Get-ARPTable
Write-Host @'


--> Installing the Manifest $manifestFileName

'@
winget install -m '$manifestPathInSandbox' --verbose-logs --ignore-local-archive-malware-scan --dependency-source winget $WinGetOptions

Write-Host @'

--> Refreshing environment variables
'@
Update-EnvironmentVariables

Write-Host @'

--> Comparing ARP Entries
'@
(Compare-Object (Get-ARPTable) `$originalARP -Property DisplayName,DisplayVersion,Publisher,ProductCode,Scope)| Select-Object -Property * -ExcludeProperty SideIndicator | Format-Table

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

$bootstrapPs1Content += @'
Write-Host
'@

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
    - Configuring Winget
"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
  Write-Host @"
    - Installing the Manifest $manifestFileName
    - Refreshing environment variables
    - Comparing ARP Entries
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
