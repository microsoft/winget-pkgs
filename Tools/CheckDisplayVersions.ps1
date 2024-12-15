<#
.SYNOPSIS
    Checks for DisplayVersions to be unique within each package
.DESCRIPTION
    This script intends to help ensure that all DisplayVersions in the repository
    are unique within each package. Each package version can have multiple DisplayVersion
    but each DisplayVersion should only belong to one package version. This script
    will not build out the Version Range in the same way that WinGet does; as such
    it may not be entirely accurate. However, it should catch a majority of cases.

    It will parse through each of the manifest files and then iterate over each
    DisplayVersion within a package to check for uniqueness.
.EXAMPLE
    PS C:\Projects\winget-pkgs> Get-Help .\Tools\CheckDisplayVersion.ps1 -Full
    Show this script's help
.EXAMPLE
    PS C:\Projects\winget-pkgs> .\Tools\CheckDisplayVersion.ps1
    Run the script to output potential issues with DisplayVersions
.NOTES
    Please file an issue if you run into errors with this script:
    https://github.com/microsoft/winget-pkgs/issues
.LINK
    https://github.com/microsoft/winget-pkgs/blob/master/Tools/CheckDisplayVersion.ps1
#>
#Requires -Version 5

[CmdletBinding()]
param (
    # No Parameters
)

$ProgressPreference = 'SilentlyContinue'

# Installs `powershell-yaml` as a dependency for parsing yaml content
if (-not(Get-Module -ListAvailable -Name powershell-yaml)) {
    try {
        Write-Verbose "PowerShell module 'powershell-yaml' was not found. Attempting to install it. . ."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
    } catch {
        # If there was an exception while installing, pass it as an InternalException for further debugging
        throw [UnmetDependencyException]::new("'powershell-yaml' unable to be installed successfully", $_.Exception)
    } finally {
        # Double check that it was installed properly
        if (-not(Get-Module -ListAvailable -Name powershell-yaml)) {
            throw [UnmetDependencyException]::new("'powershell-yaml' is not found")
        }
        Write-Verbose "PowerShell module 'powershell-yaml' was installed successfully"
    }
}

# Set the root folder where manifests should be loaded from
if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path '.\').Path
}

Write-Verbose "Fetching list of installer manifests from $ManifestsFolder . . ."
$installerManifests = Get-ChildItem $ManifestsFolder -Recurse -Filter '*.installer.yaml'
Write-Verbose "Found $($installerManifests.Count) installer manifests"
Write-Verbose 'Filtering manifests for DisplayVersion. . .'
$manifestsWithDisplayVersions = $installerManifests.Where({ $_ | Get-Content -Raw | Select-String 'DisplayVersion' })
Write-Verbose "$($manifestsWithDisplayVersions.Count) manifests contain displayVersions"
$currentManifestFolder = ''
Write-Verbose 'Parsing manifest contents. . .'
$displayVersionsByManifest = $manifestsWithDisplayVersions | ForEach-Object {
    $processingFolder = ($_.FullName | Select-String '\\[a-z0-9]\\').Matches.Value[1]
    if ($processingFolder -ne $currentManifestFolder) {
        $currentManifestFolder = $processingFolder
        Write-Verbose "Processing ../manifests/$processingFolder/*"
    }
    Write-Debug "Processing $($_.FullName)"
    $YamlContent = $_ | Get-Content | ConvertFrom-Yaml
    $rootEntries = $YamlContent.AppsAndFeaturesEntries.DisplayVersion
    $installerEntries = $YamlContent.Installers.AppsAndFeaturesEntries.DisplayVersion
    return @{
        Package         = $YamlContent.PackageIdentifier
        Version         = $YamlContent.PackageVersion
        DisplayVersions = @($rootEntries; $installerEntries).Where({ $_ }) | Select-Object -Unique
    }
}

Write-Verbose 'Creating list of unique packages. . .'
$allPackages = $displayVersionsByManifest.Package | Select-Object -Unique
Write-Verbose "$($allPackages.Count) unique packages found"

Write-Verbose 'Checking for DisplayVersions that are associated with multiple package versions. . .'
$currentStart = ''
$versionsWithOverlap = $allPackages | ForEach-Object {
    if ($currentStart -ne $_[0]) {
        $currentStart = $_.ToLower()[0]
        Write-Verbose "Processing packages beginning with $currentStart"
    }
    Write-Debug "Checking package $_"
    $package = $_
    $allDisplayVersions = $displayVersionsByManifest.Where({ $_.Package -eq $package }).DisplayVersions
    $uniqueDisplayVersions = $allDisplayVersions | Select-Object -Unique
    if ($allDisplayVersions.count -ne $uniqueDisplayVersions.count) {
        Write-Debug "Overlapping DisplayVersions found for $package"
        $overlappingDisplayVersions = (Compare-Object -ReferenceObject $allDisplayVersions -DifferenceObject $uniqueDisplayVersions).InputObject
        $packageVersionsWithOverlap = $overlappingDisplayVersions | ForEach-Object {
            $overlappedVersion = $_
            return $displayVersionsByManifest.Where({ $_.Package -eq $package -and $_.DisplayVersions -match $overlappedVersion }).Version
        }
        return [PSCustomObject]@{
            Package         = $package
            DisplayVersions = @($overlappingDisplayVersions)
            PackageVersions = @($packageVersionsWithOverlap)
        }
    } else {
        return $null
    }
}
$versionsWithOverlap = $versionsWithOverlap.Where({ $_ })
Write-Verbose "Found $($versionsWithOverlap.count) monikers with multiple packages"


if ($versionsWithOverlap.Count -gt 0) {
    Write-Output $versionsWithOverlap
    exit 1
}

class UnmetDependencyException : Exception {
    UnmetDependencyException([string] $message) : base($message) {}
    UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}
