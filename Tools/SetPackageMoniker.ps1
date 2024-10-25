<#
.SYNOPSIS
    Sets the moniker for a single package
.DESCRIPTION
    This script will update the moniker for all versions of a package identifier
.EXAMPLE
    PS C:\Projects\winget-pkgs> Get-Help .\Tools\SetPackageMoniker.ps1 -Full
    Show this script's help
.EXAMPLE
    PS C:\Projects\winget-pkgs> .\Tools\SetPackageMoniker.ps1 Google.Chrome chrome
    Set the identifier of Google.Chrome to 'chrome'
.NOTES
    Please file an issue if you run into errors with this script:
    https://github.com/microsoft/winget-pkgs/issues
.LINK
    https://github.com/microsoft/winget-pkgs/blob/master/Tools/SetPackageMoniker.ps1
#>
#Requires -Version 5

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $PackageIdentifier,
    [Parameter(Mandatory = $true)]
    [string] $Moniker
)

$ProgressPreference = 'SilentlyContinue'
$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$ManifestVersion = '1.6.0'
$Schema = "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.defaultLocale.$ManifestVersion.json"

Function Restore-YamlKeyOrder {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'InputObject', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'NoComments', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $InputObject,
        [Parameter(Mandatory = $true, Position = 1)]
        [PSCustomObject] $SortOrder
    )


    $_Temp = [ordered] @{}
    $SortOrder.GetEnumerator() | ForEach-Object {
        if ($InputObject.Contains($_)) {
            $_Temp.Add($_, $InputObject[$_])
        }
    }
    return $_Temp
}


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

# Fetch Schema data from github for entry validation, key ordering, and automatic commenting
try {
    $LocaleSchema = @(Invoke-WebRequest $Schema -UseBasicParsing | ConvertFrom-Json)
    $LocaleProperties = (ConvertTo-Yaml $LocaleSchema.properties | ConvertFrom-Yaml -Ordered).Keys
} catch {
    # Here we want to pass the exception as an inner exception for debugging if necessary
    throw [System.Net.WebException]::new('Manifest schemas could not be downloaded. Try running the script again', $_.Exception)
}

# Set the root folder where manifests should be loaded from
if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path '.\').Path
}

$ManifestsFolder = Join-Path $ManifestsFolder $PackageIdentifier.ToLower()[0] $PackageIdentifier.Split('.')

Write-Verbose "Fetching list of manifests from $ManifestsFolder . . ."
$localeManifests = Get-ChildItem $ManifestsFolder -Recurse -Filter "$PackageIdentifier.locale.*.yaml"
Write-Verbose "Found $($localeManifests.Count) locale manifests"

Write-Verbose 'Filtering manifests for Default Locale. . .'
$defaultLocaleManifests = $localeManifests.Where({ $_ | Get-Content -Raw | Select-String 'defaultLocale' })
Write-Verbose "$($defaultLocaleManifests.Count) manifests are defaultLocale"

Write-Information 'Updating monikers. . .'

$defaultLocaleManifests | ForEach-Object {
    $YamlContent = $_ | Get-Content | ConvertFrom-Yaml
    if (-not ($YamlContent['Moniker'] -ceq $Moniker)) {
        $YamlContent['Moniker'] = $Moniker
        $YamlContent = Restore-YamlKeyOrder $YamlContent $LocaleProperties
        [System.IO.File]::WriteAllLines($_.FullName, @(
                # This regex looks for lines with the special character ⍰ and comments them out
                $(ConvertTo-Yaml $YamlContent).TrimEnd() -replace "(.*)\s+$([char]0x2370)", "# `$1"
            ), $Utf8NoBomEncoding)

        Write-Verbose "Updated $($_.FullName)"
    } else {
        Write-Verbose "Skipped $($_.FullName)"
    }
}


class UnmetDependencyException : Exception {
    UnmetDependencyException([string] $message) : base($message) {}
    UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}
