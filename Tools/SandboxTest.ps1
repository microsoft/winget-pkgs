### Exit Codes:
# -1 = Sandbox is not enabled
#  0 = Success
#  1 = Error fetching GitHub release
#  2 = Unable to kill a running process
#  3 = WinGet is not installed
#  4 = Manifest validation error
###

[CmdletBinding()]
Param(
    # Manifest
    [Parameter(Position = 0, HelpMessage = 'The Manifest to install in the Sandbox.')]
    [ValidateScript({
            if (-Not (Test-Path -Path $_)) { throw "$_ does not exist" }
            return $true
        })]
    [String] $Manifest,
    # Script
    [Parameter(Position = 1, HelpMessage = 'The script to run in the Sandbox.')]
    [ScriptBlock] $Script,
    # MapFolder
    [Parameter(HelpMessage = 'The folder to map in the Sandbox.')]
    [ValidateScript({
            if (-Not (Test-Path -Path $_ -PathType Container)) { throw "$_ is not a folder." }
            return $true
        })]
    [String] $MapFolder = $pwd,
    # WinGetVersion
    [Parameter(HelpMessage = 'The version of WinGet to use')]
    [string] $WinGetVersion,
    # WinGetOptions
    [Parameter(HelpMessage = 'Additional options for WinGet')]
    [string] $WinGetOptions,
    # Switches
    [switch] $SkipManifestValidation,
    [switch] $Prerelease,
    [switch] $EnableExperimentalFeatures,
    [switch] $Clean
)

enum DependencySources {
    InRelease
    Legacy
}

# Script Behaviors
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop' # This gets overriden most places, but is set explicitly here to help catch errors
if ($PSBoundParameters.Keys -notcontains 'InformationAction') { $InformationPreference = 'Continue' } # If the user didn't explicitly set an InformationAction, Override their preference
$script:OnMappedFolderWarning = ($PSBoundParameters.Keys -contains 'WarningAction') ? $PSBoundParameters.WarningAction : 'Inquire'
$script:UseNuGetForMicrosoftUIXaml = $false
$script:ScriptName = 'SandboxTest'
$script:AppInstallerPFN = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
$script:DependenciesBaseName = 'DesktopAppInstaller_Dependencies'
$script:ReleasesApiUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'
$script:DependencySource = [DependencySources]::InRelease
$script:UsePowerShellModuleForInstall = $false

# File Names
$script:AppInstallerMsixFileName = "$script:AppInstallerPFN.msixbundle" # This should exactly match the name of the file in the CLI GitHub Release
$script:DependenciesZipFileName = "$script:DependenciesBaseName.zip" # This should exactly match the name of the file in the CLI GitHub Release

# Download Urls
$script:VcLibsDownloadUrl = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
$script:UiLibsDownloadUrl_v2_7 = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
$script:UiLibsDownloadUrl_v2_8 = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
$script:UiLibsDownloadUrl_NuGet = 'https://globalcdn.nuget.org/packages/microsoft.ui.xaml.2.8.6.nupkg?packageVersion=2.8.6'

# Expected Hashes
$script:VcLibsHash = 'B56A9101F706F9D95F815F5B7FA6EFBAC972E86573D378B96A07CFF5540C5961'
$script:UiLibsHash_v2_7 = '8CE30D92ABEC6522BEB2544E7B716983F5CBA50751B580D89A36048BF4D90316'
$script:UiLibsHash_v2_8 = '249D2AFB41CC009494841372BD6DD2DF46F87386D535DDF8D9F32C97226D2E46'
$script:UiLibsHash_NuGet = '6B62BD3C277F55518C3738121B77585AC5E171C154936EC58D87268BBAE91736'

# File Paths
$script:AppInstallerDataFolder = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages' -AdditionalChildPath $script:AppInstallerPFN
$script:DependenciesCacheFolder = Join-Path -Path $script:AppInstallerDataFolder -ChildPath "$script:ScriptName.Dependencies"
$script:TestDataFolder = Join-Path -Path $script:AppInstallerDataFolder -ChildPath $script:ScriptName
$script:PrimaryMappedFolder = (Resolve-Path -Path $MapFolder).Path
$script:ConfigurationFile = Join-Path -Path $script:TestDataFolder -ChildPath "$script:ScriptName.wsb"

# Sandbox Settings
$script:SandboxDesktopFolder = 'C:\Users\WDAGUtilityAccount\Desktop'
$script:SandboxWorkingDirectory = Join-Path -Path $script:SandboxDesktopFolder -ChildPath $($script:PrimaryMappedFolder | Split-Path -Leaf)
$script:SandboxTestDataFolder = Join-Path -Path $script:SandboxDesktopFolder -ChildPath $($script:TestDataFolder | Split-Path -Leaf)
$script:SandboxBootstrapFile = Join-Path -Path $script:SandboxTestDataFolder -ChildPath "$script:ScriptName.ps1"
$script:HostGeoID = (Get-WinHomeLocation).GeoID

# Misc
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:WebClient = New-Object System.Net.WebClient
$script:CleanupPaths = @()

# The experimental features get updated later based on a switch that is set
$script:SandboxWinGetSettings = @{
    '$schema'            = 'https://aka.ms/winget-settings.schema.json'
    logging              = @{
        level = 'verbose'
    }
    experimentalFeatures = @{
        fonts = $false
    }
}

####
# Description: Cleans up resources used by the script and then exits
# Inputs: Exit code
# Outputs: None
####
function Invoke-CleanExit {
    param (
        [Parameter(Mandatory = $true)]
        [int] $ExitCode
    )
    Invoke-FileCleanup -FilePaths $script:CleanupPaths
    $script:WebClient.Dispose()
    Write-Debug "Exiting ($ExitCode)"
    exit $ExitCode
}

####
# Description: Ensures that a folder is present. Creates it if it does not exist
# Inputs: Path to folder
# Outputs: Boolean. True if path exists or was created; False if otherwise
####
function Initialize-Folder {
    param (
        [Parameter(Mandatory = $true)]
        [String] $FolderPath
    )
    $FolderPath = [System.Io.Path]::GetFullPath($FolderPath) # Normalize the path just in case the separation characters weren't quite right, or dot notation was used
    if (Test-Path -Path $FolderPath -PathType Container) { return $true } # The path exists and is a folder
    if (Test-Path -Path $FolderPath) { return $false } # The path exists but was not a folder
    Write-Debug "Initializing folder at $FolderPath"
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar

    # Build the path up one part at a time. This is safer than using the `-Force` parameter on New-Item to create the directory
    foreach ($pathPart in $FolderPath.Split($directorySeparator)) {
        $builtPath += $pathPart + $directorySeparator
        if (!(Test-Path -Path $builtPath)) { New-Item -Path $builtPath -ItemType Directory | Out-Null }
    }

    # Make sure that the path was actually created
    return Test-Path -Path $FolderPath
}

####
# Description: Gets the details for a specific WinGet CLI release
# Inputs: None
# Outputs: Nullable Object containing GitHub release details
####
function Get-Release {
    $releasesAPIResponse = Invoke-RestMethod $script:ReleasesApiUrl
    if (!$script:Prerelease) {
        $releasesAPIResponse = $releasesAPIResponse.Where({ !$_.prerelease })
    }
    if (![String]::IsNullOrWhiteSpace($script:WinGetVersion)) {
        $releasesAPIResponse = @($releasesAPIResponse.Where({ $_.tag_name -match $('^v?' + [regex]::escape($script:WinGetVersion)) }))
    }
    if ($releasesAPIResponse.Count -lt 1) { return $null }
    return $releasesAPIResponse | Sort-Object -Property published_at -Descending | Select-Object -First 1
}

####
# Description: Gets the content of a file from a URI
# Inputs: Remote URI
# Outputs: File Contents
####
function Get-RemoteContent {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String] $URL,
        [String] $OutputPath = '',
        [switch] $Raw
    )
    Write-Debug "Attempting to fetch content from $URL"
    # Check if the URL is valid before trying to download
    $response = [String]::IsNullOrWhiteSpace($URL) ? @{StatusCode = 400 } : $(Invoke-WebRequest -Uri $URL -Method Head -ErrorAction SilentlyContinue) # If the URL is null, return a status code of 400
    if ($response.StatusCode -ne 200) {
        Write-Debug "Fetching remote content from $URL returned status code $($response.StatusCode)"
        return $null
    }
    $localFile = $OutputPath ? [System.IO.FileInfo]::new($OutputPath) : $(New-TemporaryFile) # If a path was specified, store it at that path; Otherwise use the temp folder
    Write-Debug "Remote content will be stored at $($localFile.FullName)"
    $script:CleanupPaths += $Raw ? @($localFile.FullName) : @() # Mark the file for cleanup when the script ends if the raw data was requested
    try {
        $script:WebClient.DownloadFile($URL, $localFile.FullName)
    }
    catch {
        # If the download fails, write a zero-byte file anyways
        $null | Out-File $localFile.FullName
    }
    return $Raw ? $(Get-Content -Path $localFile.FullName) : $localFile # If the raw content was requested, return the content, otherwise, return the FileInfo object
}

####
# Description: Removes files and folders from the file system
# Inputs: List of paths to remove
# Outputs: None
####
function Invoke-FileCleanup {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [String[]] $FilePaths
    )
    if (!$FilePaths) { return }
    foreach ($path in $FilePaths) {
        Write-Debug "Removing $path"
        if (Test-Path $path) { Remove-Item -Path $path -Recurse }
        else { Write-Warning "Could not remove $path as it does not exist" }
    }
}

####
# Description: Stops a process and waits for it to terminate
# Inputs: ProcessName, TimeoutSeconds
# Outputs: None
####
function Stop-NamedProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [String] $ProcessName,
        [int] $TimeoutMilliseconds = 30000 # Default to 30 seconds
    )
    $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (!$process) { return } # Process was not running

    # Stop The Process
    Write-Information "--> Stopping $ProcessName"
    if ($PSCmdlet.ShouldProcess($process)) { $process | Stop-Process -WhatIf:$WhatIfPreference }

    $elapsedTime = 0
    $waitMilliseconds = 500
    $processStillRunning = $true
    # Wait for the process to terminate
    do {
        $processStillRunning = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processStillRunning) {
            Write-Debug "$ProcessName is still running after $($elapsedTime/1000) seconds"
            Start-Sleep -Milliseconds $waitMilliseconds  # Wait before checking again
            $elapsedTime += $waitMilliseconds
        }
    } while ($processStillRunning -and $elapsedTime -lt $TimeoutMilliseconds)

    if ($processStillRunning) {
        Write-Error -Category OperationTimeout "Unable to terminate running process: $ProcessName" -ErrorAction Continue
        Invoke-CleanExit -ExitCode 2
    }
}

####
# Description: Ensures that a file has the expected checksum
# Inputs: Expected Checksum, Path to file, Hashing algorithm
# Outputs: Boolean
####
function Test-FileChecksum {
    param (
        [Parameter(Mandatory = $true)]
        [String] $ExpectedChecksum,
        [Parameter(Mandatory = $true)]
        [String] $Path,
        [Parameter()]
        [String] $Algorithm = 'SHA256'
    )

    # Get the hash of the file that is currently at the expected location for the dependency; This can be $null
    $currentHash = (Get-FileHash -Path $Path -Algorithm $Algorithm -ErrorAction SilentlyContinue).Hash
    return ($currentHash -eq $ExpectedChecksum)
}

#### Start of main script ####

# Check if Windows Sandbox is enabled
if (-Not (Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue)) {
    Write-Error -ErrorAction Continue -Category NotInstalled -Message @'
Windows Sandbox does not seem to be available. Check the following URL for prerequisites and further details:
https://docs.microsoft.com/windows/security/threat-protection/windows-sandbox/windows-sandbox-overview

You can run the following command in an elevated PowerShell for enabling Windows Sandbox:
$ Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM'
'@
    Invoke-CleanExit -ExitCode -1
}

# Validate the provided manifest
if (!$SkipManifestValidation -and ![String]::IsNullOrWhiteSpace($Manifest)) {
    # Check that WinGet is Installed
    if (!(Get-Command 'winget.exe' -ErrorAction SilentlyContinue)) {
        Write-Error -Category NotInstalled "WinGet is not installed. Manifest cannot be validated" -ErrorAction Continue
        Invoke-CleanExit -ExitCode 3
    }
    Write-Information "--> Validating Manifest"
    $validateCommandOutput = winget.exe validate $Manifest
    switch ($LASTEXITCODE) {
        '-1978335191' {
            ($validateCommandOutput | Select-Object -Skip 1 -SkipLast 1) | Write-Information # Skip the first line and the empty last line
            Write-Error -Category ParserError 'Manifest validation failed' -ErrorAction Continue
            Invoke-CleanExit -ExitCode 4
        }
        '-1978335192' {
            ($validateCommandOutput | Select-Object -Skip 1 -SkipLast 1) | Write-Information # Skip the first line and the empty last line
            Write-Warning "Manifest validation succeeded with warnings"
            Start-Sleep -Seconds 5 # Allow the user 5 seconds to read the warnings before moving on
        }
        Default {
            $validateCommandOutput.Trim() | Write-Information # On the success, print an empty line after the command output
        }
    }
}

# Get the details for the version of WinGet that was requested
Write-Verbose "Fetching release details from $script:ReleasesApiUrl; Filters: {Prerelease=$script:Prerelease; Version~=$script:WinGetVersion}"
$script:WinGetReleaseDetails = Get-Release
if (!$script:WinGetReleaseDetails) {
    Write-Error -Category ObjectNotFound 'No WinGet releases found matching criteria' -ErrorAction Continue
    Invoke-CleanExit -ExitCode 1
}
if (!$script:WinGetReleaseDetails.assets) {
    Write-Error -Category ResourceUnavailable 'Could not fetch WinGet CLI release assets' -ErrorAction Continue
    Invoke-CleanExit -ExitCode 1
}

Write-Verbose "Parsing Release Information"
# Parse the needed URLs out of the release. It is entirely possible that these could end up being $null
$script:AppInstallerMsixShaDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq "$script:AppInstallerPFN.txt" }).browser_download_url
$script:AppInstallerMsixDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:AppInstallerMsixFileName }).browser_download_url
$script:DependenciesShaDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq "$script:DependenciesBaseName.txt" }).browser_download_url
$script:DependenciesZipDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:DependenciesZipFileName }).browser_download_url
Write-Debug @"

    AppInstallerMsixShaDownloadUrl = $script:AppInstallerMsixShaDownloadUrl
    AppInstallerMsixDownloadUrl = $script:AppInstallerMsixDownloadUrl
    DependenciesShaDownloadUrl = $script:DependenciesShaDownloadUrl
    DependenciesZipDownloadUrl = $script:DependenciesZipDownloadUrl
"@

# Parse out the version
$script:AppInstallerReleaseTag = $script:WinGetReleaseDetails.tag_name
$script:AppInstallerParsedVersion = [System.Version]($script:AppInstallerReleaseTag -replace '(^v)|(-preview$)')
Write-Debug "Using Release version $script:AppinstallerReleaseTag ($script:AppInstallerParsedVersion)"

# Get the hashes for the files that change with each release version
Write-Verbose "Fetching file hash information"
$script:AppInstallerMsixHash = Get-RemoteContent -URL $script:AppInstallerMsixShaDownloadUrl -Raw
$script:DependenciesZipHash = Get-RemoteContent -URL $script:DependenciesShaDownloadUrl -Raw
Write-Debug @"

    AppInstallerMsixHash = $script:AppInstallerMsixHash
    DependenciesZipHash = $script:DependenciesZipHash
"@

# Set the folder for the files that change with each release version
$script:AppInstallerReleaseAssetsFolder = Join-Path $script:AppInstallerDataFolder -ChildPath 'bin' -AdditionalChildPath $script:AppInstallerReleaseTag

# Build the dependency information
Write-Verbose "Building Dependency List"
$script:AppInstallerDependencies = @()
if ($script:AppInstallerParsedVersion -ge [System.Version]'1.9.25180') {
    # As of WinGet 1.9.25180, VCLibs no longer publishes to the public URL and must be downloaded from the WinGet release
    # Add the Zip file from the release to the dependencies
    Write-Debug "Adding $script:DependenciesZipFileName to dependency list"
    $script:AppInstallerDependencies += @{
        DownloadUrl = $script:DependenciesZipDownloadUrl
        Checksum    = $script:DependenciesZipHash
        Algorithm   = 'SHA256'
        SaveTo      = (Join-Path -Path $script:AppInstallerReleaseAssetsFolder -ChildPath $script:DependenciesZipFileName)
    }
}
else {
    $script:DependencySource = [DependencySources]::Legacy
    # Add the VCLibs to the dependencies
    Write-Debug "Adding VCLibs UWP to dependency list"
    $script:AppInstallerDependencies += @{
        DownloadUrl = $script:VcLibsDownloadUrl
        Checksum    = $script:VcLibsHash
        Algorithm   = 'SHA256'
        SaveTo      = (Join-Path -Path $script:DependenciesCacheFolder -ChildPath 'Microsoft.VCLibs.Desktop.x64.appx')
    }
    if ($script:UseNuGetForMicrosoftUIXaml) {
        # Add the NuGet file to the dependencies
        Write-Debug "Adding Microsoft.UI.Xaml (NuGet) to dependency list"
        $script:AppInstallerDependencies += @{
            DownloadUrl = $script:UiLibsDownloadUrl_NuGet
            Checksum    = $script:UiLibsHash_NuGet
            Algorithm   = 'SHA256'
            SaveTo      = (Join-Path -Path $script:DependenciesCacheFolder -ChildPath 'Microsoft.UI.Xaml.zip')
        }
    }
    # As of WinGet 1.7.10514 (https://github.com/microsoft/winget-cli/pull/4218), the dependency on uiLibsUwP was bumped from version 2.7.3 to version 2.8.6
    elseif ($script:AppInstallerParsedVersion -lt [System.Version]'1.7.10514') {
        # Add Xaml 2.7 to the dependencies
        Write-Debug "Adding Microsoft.UI.Xaml (v2.7) to dependency list"
        $script:AppInstallerDependencies += @{
            DownloadUrl = $script:UiLibsDownloadUrl_v2_7
            Checksum    = $script:UiLibsHash_v2_7
            Algorithm   = 'SHA256'
            SaveTo      = (Join-Path -Path $script:DependenciesCacheFolder -ChildPath 'Microsoft.UI.Xaml.2.7.x64.appx')
        }
    }
    else {
        # Add Xaml 2.8 to the dependencies
        Write-Debug "Adding Microsoft.UI.Xaml (v2.8) to dependency list"
        $script:AppInstallerDependencies += @{
            DownloadUrl = $script:UiLibsDownloadUrl_v2_8
            Checksum    = $script:UiLibsHash_v2_8
            Algorithm   = 'SHA256'
            SaveTo      = (Join-Path -Path $script:DependenciesCacheFolder -ChildPath 'Microsoft.UI.Xaml.2.8.x64.appx')
        }
    }
}

# Add WinGet as a dependency for itself
# This seems weird, but it's the easiest way to ensure that it is downloaded and has the right hash
Write-Debug "Adding $script:AppInstallerMsixFileName ($script:AppInstallerReleaseTag) to dependency list"
$script:AppInstallerDependencies += @{
    DownloadUrl = $script:AppInstallerMsixDownloadUrl
    Checksum    = $script:AppInstallerMsixHash
    Algorithm   = 'SHA256'
    SaveTo      = (Join-Path -Path $script:AppInstallerReleaseAssetsFolder -ChildPath $script:AppInstallerMsixFileName)
}

# If the PowerShell Module will be used, destroy the dependency list that was just created
# This is cleaner than adding if statements everywhere to try and handle this flag.
# Since the time it takes to build the dependency tree is minimal, don't worry about performance yet
if ($script:UsePowerShellModuleForInstall) {
    $script:AppInstallerDependencies = @()
}

# Process the dependency list
Write-Information "--> Checking Dependencies"
foreach ($dependency in $script:AppInstallerDependencies) {
    # On a clean install, remove the existing files
    if ($Clean) { Invoke-FileCleanup -FilePaths $dependency.SaveTo }

    # If the hash doesn't match, the dependency needs to be re-downloaded
    # If the file doesn't exist on the system, the hashes will not match since $null != ''
    Write-Verbose "Checking the hash of $($dependency.SaveTo)"
    if (!(Test-FileChecksum -ExpectedChecksum $dependency.Checksum -Path $dependency.SaveTo -Algorithm $dependency.Algorithm)) {
        if (!(Initialize-Folder $($dependency.SaveTo | Split-Path))) { throw "Could not create folder for caching $($dependency.DownloadUrl)" } # The folder needs to be present, otherwise the WebClient request will fail
        Write-Information "  - Downloading $($dependency.DownloadUrl)"
        Get-RemoteContent -URL $dependency.DownloadUrl -OutputPath $dependency.SaveTo -ErrorAction SilentlyContinue | Out-Null
    }

    # If the hash didn't match, remove the item so the sandbox can fall-back to using the PowerShell module
    if (!(Test-FileChecksum -ExpectedChecksum $dependency.Checksum -Path $dependency.SaveTo -Algorithm $dependency.Algorithm)) {
        $script:UsePowerShellModuleForInstall = $true
        Write-Debug "Hashes did not match; Expected $($dependency.Checksum), Received $((Get-FileHash $dependency.SaveTo -Algorithm $dependency.Algorithm -ErrorAction Continue).Hash)"
        Remove-Item $dependency.SaveTo -Force | Out-Null
        # Continue on these errors because the PowerShell module will be used instead
        Write-Error -Category SecurityError 'Dependency hash does not match the downloaded file' -ErrorAction Continue
        Write-Error -Category SecurityError 'Please open an issue referencing this error at https://bit.ly/WinGet-SandboxTest-Needs-Update' -ErrorAction Continue
        break # Skip processing further dependencies, since the PowerShell Module will be used
    }
}

# Kill the active running sandbox, if it exists, otherwise the test data folder can't be removed
Stop-NamedProcess -ProcessName 'WindowsSandboxClient'
Start-Sleep -Milliseconds 5000 # Wait for the lock on the file to be released

# Remove the test data folder if it exists. We will rebuild it with new test data
Write-Verbose "Cleaning up previous test data"
Invoke-FileCleanup -FilePaths $script:TestDataFolder

# Create the paths if they don't exist
if (!(Initialize-Folder $script:TestDataFolder)) { throw 'Could not create folder for mapping files into the sandbox' }
if (!(Initialize-Folder $script:DependenciesCacheFolder)) { throw 'Could not create folder for caching dependencies' }

# Set Experimental Features to be Enabled, If requested
if ($EnableExperimentalFeatures) {
    Write-Debug "Setting Experimental Features to Enabled"
    $experimentalFeatures = @($script:SandboxWinGetSettings.experimentalFeatures.Keys)
    foreach ($feature in $experimentalFeatures) {
        $script:SandboxWinGetSettings.experimentalFeatures[$feature] = $true
    }
}

# Copy Files to the TestDataFolder that will be mapped into sandbox
Write-Verbose "Copying assets into $script:TestDataFolder"
if ($Manifest) { Copy-Item -Path $Manifest -Destination $script:TestDataFolder -Recurse -ErrorAction SilentlyContinue }
$script:SandboxWinGetSettings | ConvertTo-Json | Out-File -FilePath (Join-Path -Path $script:TestDataFolder -ChildPath 'settings.json') -Encoding ascii
foreach ($dependency in $script:AppInstallerDependencies) { Copy-Item -Path $dependency.SaveTo -Destination $script:TestDataFolder -ErrorAction SilentlyContinue }

# Create a script file from the script parameter
if (-Not [String]::IsNullOrWhiteSpace($Script)) {
    Write-Verbose "Creating script file from 'Script' argument"
    $Script | Out-File -Path (Join-Path $script:TestDataFolder -ChildPath 'BoundParameterScript.ps1')
}

# Create the bootstrapping script
Write-Verbose "Creating the script for bootstrapping the sandbox"
@"
function Update-EnvironmentVariables {
    foreach(`$level in "Machine","User") {
        [Environment]::GetEnvironmentVariables(`$level).GetEnumerator() | % {
            # For Path variables, append the new values, if they're not already in there
            if(`$_.Name -match '^Path$') {
                `$_.Value = (`$((Get-Content "Env:`$(`$_.Name)") + ";`$(`$_.Value)") -split ';' | Select -unique) -join ';'
            }
          `$_
        } | Set-Content -Path { "Env:`$(`$_.Name)" }
    }
}

function Get-ARPTable {
    `$registry_paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    return Get-ItemProperty `$registry_paths -ErrorAction SilentlyContinue |
        Where-Object { `$_.DisplayName -and (-not `$_.SystemComponent -or `$_.SystemComponent -ne 1 ) } |
        Select-Object DisplayName, DisplayVersion, Publisher, @{N='ProductCode'; E={`$_.PSChildName}}, @{N='Scope'; E={if(`$_.PSDrive.Name -eq 'HKCU') {'User'} else {'Machine'}}}
}

Push-Location $($script:SandboxTestDataFolder)
Write-Host @'
--> Installing WinGet
'@
`$ProgressPreference = 'SilentlyContinue'

try {
    if ($([int]$script:UsePowerShellModuleForInstall)) { throw } # Using exceptions for control logic is generally not preferred, but is done here to keep things clean and readable
    Get-ChildItem -Filter '*.zip' | Expand-Archive
    Get-ChildItem -Recurse -Filter '*.appx' | Where-Object {`$_.FullName -match 'x64'} | Add-AppxPackage -ErrorAction Stop
    # This path is set explicitly instead of using Get-ChildItem as an error prevention measure
    Add-AppxPackage './$($script:AppInstallerPFN).msixbundle' -ErrorAction Stop
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
  Repair-WinGetPackageManager -Version $($script:AppInstallerReleaseTag)
}

Write-Host @'
--> Disabling safety warning when running installers
'@
New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations' | Out-Null
New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Associations' -Name 'ModRiskFileTypes' -Type 'String' -Value '.bat;.exe;.reg;.vbs;.chm;.msi;.js;.cmd' | Out-Null

Write-Host @'
Tip: you can type 'Update-EnvironmentVariables' to update your environment variables, such as after installing a new software.
'@

Write-Host @'

--> Configuring Winget
'@
winget settings --Enable LocalManifestFiles
winget settings --Enable LocalArchiveMalwareScanOverride
Get-ChildItem -Filter 'settings.json' | Copy-Item -Destination C:\Users\WDAGUtilityAccount\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json
Set-WinHomeLocation -GeoID $($script:HostGeoID)

`$manifestFolder = (Get-ChildItem `$pwd -Directory).Where({Get-ChildItem `$_ -Filter '*.yaml'}).FullName | Select-Object -First 1
if (`$manifestFolder) {
    Write-Host @"

--> Installing the Manifest `$(`$manifestFolder | Split-Path -Leaf)

`"@
    `$originalARP = Get-ARPTable
    winget install -m `$manifestFolder --accept-package-agreements --verbose-logs --ignore-local-archive-malware-scan --dependency-source winget $WinGetOptions

    Write-Host @'

--> Refreshing environment variables
'@
    Update-EnvironmentVariables

    Write-Host @'

--> Comparing ARP Entries
'@
    (Compare-Object (Get-ARPTable) `$originalARP -Property DisplayName,DisplayVersion,Publisher,ProductCode,Scope)| Select-Object -Property * -ExcludeProperty SideIndicator | Format-Table
}

`$BoundParameterScript = Get-ChildItem -Filter 'BoundParameterScript.ps1'
if (`$BoundParameterScript) {
    Write-Host @'

--> Running the following script: {
`$(Get-Content -Path `$BoundParameterScript.FullName)
}

'@
& `$BoundParameterScript.FullName
}

Pop-Location
"@ | Out-File -FilePath $(Join-Path -Path $script:TestDataFolder -ChildPath "$script:ScriptName.ps1")

# Create the WSB file
# Although this could be done using the native XML processor, it's easier to just write the content directly as a string
Write-Verbose "Creating WSB file for launching the sandbox"
@"
<Configuration>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$($script:TestDataFolder)</HostFolder>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$($script:PrimaryMappedFolder)</HostFolder>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
  <Command>PowerShell Start-Process PowerShell -WindowStyle Maximized -WorkingDirectory '$($script:SandboxWorkingDirectory)' -ArgumentList '-ExecutionPolicy Bypass -NoExit -NoLogo -File $($script:SandboxBootstrapFile)'</Command>
  </LogonCommand>
</Configuration>
"@ | Out-File -FilePath $script:ConfigurationFile

if ($script:PrimaryMappedFolder -notmatch 'winget-pkgs') {
    Write-Warning @"
The mapped folder does not appear to be within the winget-pkgs repository path.
This will give read-and-write access to $($script:PrimaryMappedFolder) within the sandbox
"@ -WarningAction $script:OnMappedFolderWarning
}

Write-Information @"
--> Starting Windows Sandbox, and:
    - Mounting the following directories:
      - $($script:TestDataFolder) as read-and-write
      - $($script:PrimaryMappedFolder) as read-and-write
    - Installing WinGet
    - Configuring Winget
"@

if (-Not [String]::IsNullOrWhiteSpace($Manifest)) {
    Write-Information @"
      - Installing the Manifest $(Split-Path $Manifest -Leaf)
      - Refreshing environment variables
      - Comparing ARP Entries
"@
}

if (-Not [String]::IsNullOrWhiteSpace($Script)) {
    Write-Information @"
      - Running the following script: {
$Script
}
"@
}

Write-Verbose "Invoking the sandbox using $script:ConfigurationFile"
WindowsSandbox $script:ConfigurationFile
Invoke-CleanExit -ExitCode 0
