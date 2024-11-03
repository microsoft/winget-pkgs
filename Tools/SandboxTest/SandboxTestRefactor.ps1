### Exit Codes:
# 0 = Success
# 1 = Error fetching GitHub release
###



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
    [switch] $EnableExperimentalFeatures
)


#Region Constants

# Script Behaviors
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$script:UseNuGetForMicrosoftUIXaml = $false
$script:ScriptName = 'SandboxTest'
$script:AppInstallerPFN = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
$script:ReleasesApiUrl = 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'

# File Names
$script:AppInstallerShaFileName = $script:AppInstallerPFN + '.txt'
$script:AppInstallerMsixFileName = $script:AppInstallerPFN + '.msixbundle'
$script:VcLibsAppxFileName = 'Microsoft.VCLibs.Desktop.appx' # This does not match the published file name, but is used for ease of mapping in the Sandbox
$script:UiLibsAppxFileName = 'Microsoft.UI.Xaml.appx' # This does not match the published file name, but is used for ease of mapping in the Sandbox
$script:UiLibsZipFileName = 'Microsoft.UI.Xaml.zip' # This does not match the published file name, but is used for ease of mapping in the Sandbox
$script:DependenciesZipFileName = 'DesktopAppInstaller_Dependencies.zip'
$script:DependenciesShaFileName = 'DesktopAppInstaller_Dependencies.txt' # TODO: https://github.com/microsoft/winget-cli/issues/4938
$script:WinGetSettingsFileName = 'settings.json'

# DownloadUrls
$script:VcLibsDownloadUrl = 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
$script:UiLibsDownloadUrl_v2_7 = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx'
$script:UiLibsDownloadUrl_v2_8 = 'https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx'
$script:UiLibsDownloadUrl_NuGet = 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6'

# Expected Hashes
$script:VcLibsHash = 'B56A9101F706F9D95F815F5B7FA6EFBAC972E86573D378B96A07CFF5540C5961'
$script:UiLibsHash_v2_7 = '8CE30D92ABEC6522BEB2544E7B716983F5CBA50751B580D89A36048BF4D90316'
$script:UiLibsHash_v2_8 = '249D2AFB41CC009494841372BTeD6DD2DF46F87386D535DDF8D9F32C97226D2E46'
$script:UiLibsHash_NuGet = '6B62BD3C277F55518C3738121B77585AC5E171C154936EC58D87268BBAE91736'

# File Paths
$script:AppInstallerDataFolder = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages' -AdditionalChildPath $script:AppInstallerPFN
# $script:TestDataFolder = Join-Path -Path $script:AppInstallerDataFolder -ChildPath $script:ScriptName
$script:TestDataFolder = 'C:\git\winget-pkgs\Tools\SandboxTest\Test\'
$script:PrimaryMappedFolder = (Resolve-Path -Path $MapFolder).Path
$script:SandboxDesktipFolder = 'C:\Users\WDAGUtilityAccount\Desktop'
$script:DependenciesCacheFolder = Join-Path -Path $script:AppInstallerDataFolder -ChildPath ($script:ScriptName + 'Dependencies')

# Settings for writing the WSB file
$script:XmlSettings = New-Object System.Xml.XmlWriterSettings
$script:XmlSettings.Indent = $true

# Sandbox Settings
$script:HostGeoID = (Get-WinHomeLocation).GeoID

# Misc
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$script:WebClient = New-Object System.Net.WebClient

#EndRegion Constants

#Region Variables
$script:CleanupPaths = @()

# This gets set to either the v2.7, v2.8, or NuGet download URL
$script:UiLibsDownloadUrl = ''
# This gets set to the expected hash of the dependencies zip file for the specific version of WinGet the user requested
$script:AppInstallerMsixHash = ''
# This gets set to the expected hash of the dependencies zip for the specific version of WinGet the user requested
# This is not currently implemented due to https://github.com/microsoft/winget-cli/issues/4938
$script:DependenciesZipHash = ''
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

#EndRegion Variables

#Region Functions

####
# Description: Ensures that a folder is present. Creates it if it does not exist
# Inputs: Path to folder
# Outputs: Boolean. True if path exists or was created; False if otherwise
####
function Initialize-Folder {
    param (
        [String] $FolderPath
    )
    Write-Debug "Initializing folder at $FolderPath"
    $FolderPath = [System.Io.Path]::GetFullPath($FolderPath) # Normalize the path just in case the separation characters weren't quite right, or dot notation was used
    if (Test-Path -Path $FolderPath -PathType Container) { return $true } # The path exists and is a folder
    if (Test-Path -Path $FolderPath) { return $false } # The path exists but was not a folder

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
        [String] $URL,
        [String] $Path = '',
        [switch] $Raw
    )
    Write-Debug "Attempting to fetch content from $URL"
    # Check if the URL is valid before trying to download
    $response = [String]::IsNullOrWhiteSpace($URL) ? @{StatusCode = 400} : $(Invoke-WebRequest -Uri $URL -Method Head -ErrorAction SilentlyContinue) # If the URL is null, return a status code of 400
    if ($response.StatusCode -ne 200) {
        Write-Debug "Fetching remote content from $URL returned status code $($response.StatusCode)"
        return $null
    }
    $localFile = $Path ? [System.IO.FileInfo]::new($Path) : $(New-TemporaryFile) # If a path was specified, store it at that path; Otherwise use the temp folder
    Write-Debug "Remote content will be stored at $($localFile.FullName)"
    $script:CleanupPaths += $Raw ? @($localFile.FullName) : @() # Mark the file for cleanup when the script ends if the raw data was requested
    $script:WebClient.DownloadFile($URL, $localFile.FullName)
    return $Raw ? $(Get-Content -Path $localFile.FullName) : $localFile # If the raw content was requested, return the content, otherwise, return the FileInfo object
}

function Invoke-FileCleanup {
    param (
        [String[]] $FilePaths
    )
    foreach ($path in $FilePaths) {
        Write-Debug "Removing $path"
        if (Test-Path $path) { Remove-Item -Path $path -Recurse }
        else { Write-Warning "Could not remove $path as it does not exist" }
    }
}

#EndRegion Functions

#### Start of main script ####


# Get the details for the version of WinGet that was requested
Write-Verbose "Fetching release details from $script:ReleasesApiUrl; Filters: {Prerelease=$script:Prerelease; Version~=$script:WinGetVersion}"
$script:WinGetReleaseDetails = Get-Release
if (!$script:WinGetReleaseDetails) {
    Write-Error 'No WinGet releases found matching criteria'
    exit 1
}
if (!$script:WinGetReleaseDetails.assets) {
    Write-Error 'Could not fetch WinGet CLI release assets'
    exit 1
}

Write-Verbose "Parsing Release Information"
# Parse the needed URLs out of the release. It is entirely possible that these could end up being $null
$script:AppInstallerMsixShaDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:AppInstallerShaFileName }).browser_download_url
$script:AppInstallerMsixDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:AppInstallerMsixFileName }).browser_download_url
$script:DependenciesShaDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:DependenciesShaFileName }).browser_download_url # This is expected to be null until the completion of https://github.com/microsoft/winget-cli/issues/4938
$script:DependenciesZipDownloadUrl = $script:WinGetReleaseDetails.assets.Where({ $_.name -eq $script:DependenciesZipFileName }).browser_download_url


$script:AppInstallerReleaseTag = $script:WinGetReleaseDetails.tag_name
$script:AppInstallerParsedVersion = [System.Version]($script:AppInstallerReleaseTag -replace '(^v)|(-preview$)')
Write-Debug @"

    AppInstallerMsixShaDownloadUrl = $script:AppInstallerMsixShaDownloadUrl
    AppInstallerMsixDownloadUrl = $script:AppInstallerMsixDownloadUrl
    DependenciesShaDownloadUrl = $script:DependenciesShaDownloadUrl
    DependenciesZipDownloadUrl = $script:DependenciesZipDownloadUrl
"@


Write-Verbose "Fetching file hash information"
$script:AppInstallerMsixHash = Get-RemoteContent -URL $script:AppInstallerMsixShaDownloadUrl -Raw
$script:DependenciesZipHash = Get-RemoteContent -URL $script:DependenciesShaDownloadUrl -Raw
Write-Debug @"

    AppInstallerMsixHash = $script:AppInstallerMsixHash
    DependenciesZipHash = $script:DependenciesZipHash
"@


# Remove the test data folder if it exists. We will rebuild it with new test data
Invoke-FileCleanup -FilePaths $script:TestDataFolder

# Create the paths if they don't exist
if (!(Initialize-Folder $script:TestDataFolder)) { throw 'Could not create folder for mapping files into the sandbox' }
if (!(Initialize-Folder $script:DependenciesCacheFolder)) { throw 'Could not create folder for caching dependencies' }

Invoke-FileCleanup -FilePaths $script:CleanupPaths
return $script:AppInstallerMsixHash

# Write the settings file to the
