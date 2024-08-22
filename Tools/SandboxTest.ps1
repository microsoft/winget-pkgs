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

$useNuGetForMicrosoftUIXaml = $false
$mapFolder = (Resolve-Path -Path $MapFolder).Path
$geoID = (Get-WinHomeLocation).GeoID

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

function Test-GitHubToken {
  # If a GitHub Token is present, check if it is valid.
  # If it is valid, use it for the API requests
  if ($null -ne $script:IsValidGitHubToken) {
    # If the token has already been validated in this run, it doesn't need to be re-validated
    # This assumes the token is not changing while the script is executing
    return $script:IsValidGitHubToken
  }

  if (!$env:GITHUB_TOKEN) {
    # If the environment variable doesn't exist, there is no token to validate
    # Don't query the API at all in this case
    $script:IsValidGitHubToken = $false
    return $script:IsValidGitHubToken
  }

  # The rate limit for authorized users is usually much higher than 60
  $requestParameters = @{
    Uri            = 'https://api.github.com/rate_limit'
    Authentication = 'Bearer'
    Token          = $(ConvertTo-SecureString "$env:GITHUB_TOKEN" -AsPlainText)
  }

  $script:IsValidGitHubToken = (Invoke-RestMethod @requestParameters).resources.core.limit -gt 60
  return $script:IsValidGitHubToken
}

function Get-ReleasesResponse {
  if (Get-Command 'gh' -ErrorAction SilentlyContinue) {
    # If the user is logged in, use the gh cli for getting the information
    if ($(gh auth status >$null; $?)) {
      return $(gh api repos/microsoft/winget-cli/releases --paginate | ConvertFrom-Json)
    }
  }

  # If the user is not logged in the API will be queried directly
  $requestParameters = @{
    Uri = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
  }

  if (Test-GitHubToken) {
    $requestParameters.Add('Authentication', 'Bearer')
    $requestParameters.Add('Token', $(ConvertTo-SecureString "$env:GITHUB_TOKEN" -AsPlainText))
  } else {
    # See https://docs.github.com/zh/rest/using-the-rest-api/rate-limits-for-the-rest-api?apiVersion=2022-11-28#primary-rate-limit-for-unauthenticated-users
    Write-Host "WARNING: You may encounter 'API rate limit exceeded' error! Please consider adding `GITHUB_TOKEN` to your environment variable."
  }

  return Invoke-RestMethod @requestParameters
}

function Get-Release {
  $releasesAPIResponse = Get-ReleasesResponse
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
$uiLibsUwp_2_7 = @{
  url    = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
  hash   = '8CE30D92ABEC6522BEB2544E7B716983F5CBA50751B580D89A36048BF4D90316'
  SaveTo = $(Join-Path $tempFolder -ChildPath 'Microsoft.UI.Xaml.2.7.x64.appx')
}
$uiLibsUwp_2_8 = @{
  url    = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
  hash   = '249D2AFB41CC009494841372BD6DD2DF46F87386D535DDF8D9F32C97226D2E46'
  SaveTo = $(Join-Path $tempFolder -ChildPath 'Microsoft.UI.Xaml.2.8.x64.appx')
}
$uiLibs_nuget = @{
  url    = 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6'
  hash   = '6B62BD3C277F55518C3738121B77585AC5E171C154936EC58D87268BBAE91736'
  SaveTo = $(Join-Path $tempFolder -ChildPath 'Microsoft.UI.Xaml.2.8.zip')
}

$dependencies = @($desktopAppInstaller, $vcLibsUwp, $uiLibsUwp_2_7, $uiLibsUwp_2_8)

if ($useNuGetForMicrosoftUIXaml) {
  $dependencies += $uiLibs_nuget
}

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

### The NuGet may be needed if the latest Appx Packages are not available on GitHub ###
if ($useNuGetForMicrosoftUIXaml) {
  $bootstrapPs1Content += @"
`$ProgressPreference = 'SilentlyContinue'

Expand-Archive -Path $($uiLibs_nuget.pathInSandbox) -DestinationPath C:\Users\WDAGUtilityAccount\Downloads\Microsoft.UI.Xaml -ErrorAction SilentlyContinue
Get-ChildItem C:\Users\WDAGUtilityAccount\Downloads\Microsoft.UI.Xaml\tools\AppX\x64\Release -Filter *.appx | Add-AppxPackage

"@
}
#######################################################################################

$bootstrapPs1Content += @"
Write-Host @'
--> Installing WinGet
'@
`$ProgressPreference = 'SilentlyContinue'
try {
  Add-AppxPackage -Path '$($vcLibsUwp.pathInSandbox)' -ErrorAction Stop
  Add-AppxPackage -Path '$($uiLibsUwp_2_7.pathInSandbox)' -ErrorAction Stop
  Add-AppxPackage -Path '$($uiLibsUwp_2_8.pathInSandbox)' -ErrorAction Stop
  Add-AppxPackage -Path '$($desktopAppInstaller.pathInSandbox)' -ErrorAction Stop
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
Set-WinHomeLocation -GeoID $geoID
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
