#Requires -Version 5

[CmdletBinding()]
param (
    # No Parameters
)

$ProgressPreference = 'SilentlyContinue'
$1_0 = @('1.0.0');
$1_1 = $1_0 + @('1.0.1')
$1_2 = $1_1 + @('1.0.2')
$1_3 = $1_2 + @('1.0.3')
$1_4 = $1_3 + @('1.0.4')
$1_5 = $1_4 + @('1.0.5')
$1_6 = $1_5 + @('1.0.6')

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


$currentManifestFolder = ''
Write-Verbose 'Parsing manifest contents. . .'
$versionsByManifest = $installerManifests | ForEach-Object {
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
        ManifestVersion = $YamlContent.ManifestVersion
    }
}

return $versionsByManifest

class UnmetDependencyException : Exception {
    UnmetDependencyException([string] $message) : base($message) {}
    UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}
