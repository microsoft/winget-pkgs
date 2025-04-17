<#
.SYNOPSIS
    Checks for monikers to be unique and each package to have a singular moniker
.DESCRIPTION
    This script intends to help ensure that all monikers in the repository are
    unique to a single package identifier and that each package identifire has
    only a single moniker.

    It will parse through each of the manifest files and then iterate over each
    moniker and each package to check for uniqueness.
.EXAMPLE
    PS C:\Projects\winget-pkgs> Get-Help .\Tools\CheckMonikers.ps1 -Full
    Show this script's help
.EXAMPLE
    PS C:\Projects\winget-pkgs> .\Tools\CheckMonikers.ps1
    Run the script to output potential issues with Monikers
.NOTES
    Please file an issue if you run into errors with this script:
    https://github.com/microsoft/winget-pkgs/issues
.LINK
    https://github.com/microsoft/winget-pkgs/blob/master/Tools/CheckMonikers.ps1
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

Write-Verbose "Fetching list of locale manifests from $ManifestsFolder . . ."
$localeManifests = Get-ChildItem $ManifestsFolder -Recurse -Filter '*.locale.*.yaml'
Write-Verbose "Found $($localeManifests.Count) locale manifests"
Write-Verbose 'Filtering manifests for Default Locale and Moniker. . .'
$manifestsWithMonikers = $localeManifests.Where({ $($_ | Get-Content -Raw | Select-String 'Moniker' | Select-String 'defaultLocale') -notmatch '#\s*Moniker' })
Write-Verbose "$($manifestsWithMonikers.Count) manifests contain monikers"
$currentManifestFolder = ''
Write-Verbose 'Parsing manifest contents. . .'
$monikersByManifest = $manifestsWithMonikers | ForEach-Object {
    $processingFolder = ($_.FullName | Select-String '\\[a-z0-9]\\').Matches.Value[1]
    if ($processingFolder -ne $currentManifestFolder) {
        $currentManifestFolder = $processingFolder
        Write-Verbose "Processing ../manifests/$processingFolder/*"
    }
    Write-Debug "Processing $($_.FullName)"
    $YamlContent = $_ | Get-Content | ConvertFrom-Yaml
    return @{
        Package = $YamlContent.PackageIdentifier
        Version = $YamlContent.PackageVersion
        Moniker = $YamlContent.Moniker
    }
}

Write-Verbose 'Creating list of unique monikers. . .'
$allMonikers = $monikersByManifest.Moniker | Select-Object -Unique | Sort-Object
Write-Verbose "$($allMonikers.Count) unique monikers found"
Write-Verbose 'Creating list of unique packages. . .'
$allPackages = $monikersByManifest.Package | Select-Object -Unique
Write-Verbose "$($allPackages.Count) unique packages found"

Write-Verbose 'Checking for monikers that are associated with multiple packages. . .'
$currentStart = ''
$monikersWithMultiplePackages = $allMonikers | ForEach-Object {
    if ($currentStart -ne $_[0]) {
        $currentStart = $_.ToLower()[0]
        Write-Verbose "Processing monikers beginning with $currentStart"
    }
    Write-Debug "Checking moniker $_"
    $moniker = $_
    $packages = $monikersByManifest.Where({ $_.Moniker -eq $moniker }).Package | Select-Object -Unique
    if ($packages.count -gt 1) {
        Write-Debug "Multiple packages found for $moniker"
        return [PSCustomObject]@{
            Moniker  = $moniker
            Packages = $packages
        }
    } else {
        return $null
    }
}
$monikersWithMultiplePackages = $monikersWithMultiplePackages.Where({ $_ })
Write-Verbose "Found $($monikersWithMultiplePackages.count) monikers with multiple packages"

Write-Verbose 'Checking for packages that are associated with multiple monikers. . .'
$currentStart = ''
$packagesWithMultipleMonikers = $allPackages | ForEach-Object {
    if ($currentStart -ne $_[0]) {
        $currentStart = $_.ToLower()[0]
        Write-Verbose "Processing packages beginning with $currentStart"
    }
    Write-Debug "Checking package $_"
    $package = $_
    $monikers = $monikersByManifest.Where({ $_.Package -eq $package }).Moniker | Select-Object -Unique
    if ($monikers.count -gt 1) {
        Write-Debug "Multiple monikers found for $package"
        return [PSCustomObject]@{
            Package  = $package
            Monikers = $monikers
        }
    } else {
        return $null
    }
}
$packagesWithMultipleMonikers = $packagesWithMultipleMonikers.Where({ $_ })
Write-Verbose "Found $($packagesWithMultipleMonikers.count) packages with multiple monikers"

if ($monikersWithMultiplePackages.Count -gt 0) {
    Write-Output 'Monikers with Multiple Packages:'
    $monikersWithMultiplePackages | Out-Host
}

if ($packagesWithMultipleMonikers.Count -gt 0) {
    Write-Output 'Packages with Multiple Monikers:'
    $packagesWithMultipleMonikers | Out-Host
}

class UnmetDependencyException : Exception {
    UnmetDependencyException([string] $message) : base($message) {}
    UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}
