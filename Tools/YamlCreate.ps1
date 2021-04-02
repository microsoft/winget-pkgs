#Requires -Version 5

<#
.SYNOPSIS
    Winget Manifest creation helper script
.DESCRIPTION
    The intent of this file is to help you generate a manifest for publishing
    to the Windows Package Manager repository. 
    
    It'll attempt to download an installer from the user-provided URL to calculate
    a checksum. That checksum and the rest of the input data will be compiled in a 
    .YAML file.
.EXAMPLE
    PS C:\Projects\winget-pkgs> Get-Help .\Tools\YamlCreate.ps1 -Full
    Show this script's help
.EXAMPLE
    PS C:\Projects\winget-pkgs> .\Tools\YamlCreate.ps1
    Run the script to create a manifest file
.NOTES
    Please file an issue if you run into errors with this script:
    https://github.com/microsoft/winget-pkgs/issues/
.LINK
    https://github.com/microsoft/winget-pkgs/blob/master/Tools/YamlCreate.ps1
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$NewLine = [System.Environment]::NewLine

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions?view=powershell-7#filters
filter TrimString {
    $_.Trim()
}

##########################################
#region checksum
while ([string]::IsNullOrWhiteSpace($URL)) {
    $URL = Read-Host -Prompt 'Enter the URL to the installer' | TrimString
}
Write-Host $NewLine
Write-Host 'Downloading URL. This will take awhile...' -ForegroundColor Blue
$WebClient = New-Object System.Net.WebClient

try {
    $Stream = $WebClient.OpenRead($URL)
    $Hash = (Get-FileHash -InputStream $Stream -Algorithm SHA256).Hash
}
catch {
    Write-Host 'Error downloading file. Please run the script again.' -ForegroundColor Red
    exit 1
}
finally {
    $Stream.Close()
}

Write-Host "Url: $URL"
Write-Host "Sha256: $Hash"

Write-Host $NewLine
Write-Host 'File downloaded. Please Fill out required fields.'

#endregion
##########################################

##########################################
#region Read in metadata

$host.UI.RawUI.ForegroundColor = "White"

while ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher.Length -ge 128) {
    $Publisher = Read-Host -Prompt 'Enter the publisher' | TrimString
}

while ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName.Length -ge 128) {
    $PackageName = Read-Host -Prompt 'Enter the application name' | TrimString
}

while ([string]::IsNullOrWhiteSpace($PackageVersion)) {
    $PackageVersion = Read-Host -Prompt 'Enter the version. For example: 1.0.0, 1.0.0.0, 1.0' | TrimString
}

$PackageIdentifier = [System.String]::Concat($Publisher.Replace(' ',''),'.',$PackageName.Replace(' ',''))
if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path ".\").Path
}

$AppFolder = Join-Path $ManifestsFolder $Publisher.Chars(0) $Publisher.Replace(' ','') $PackageName.Replace(' ','') $PackageVersion

$VersionManifest = $AppFolder + "\$PackageIdentifier" + '.yaml'
$InstallerManifest = $AppFolder + "\$PackageIdentifier" + '.installer' + '.yaml'
$DefaultLocaleManifest = $AppFolder + "\$PackageIdentifier" + '.locale.en-US' + '.yaml'

switch ($option) {
    'Old' {
        # Use old Manifest
        # Copy Old files to New Location
        # Update PackageVersion

    }

    'NewLocale' {
        # New Locale stuff
        #https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.0.0/manifest.locale.1.0.0.json
    }

    default {
        ########## Read Metadata ##########
        while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 40) {
            $License = Read-Host -Prompt 'Enter the License, For example: MIT, or Copyright (c) Microsoft Corporation' | TrimString
        }
        
        do {
            $LicenseUrl = Read-Host -Prompt '[OPTIONAL] Enter the license URL' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

        while ($architecture -notin @('x86', 'x64', 'arm', 'arm64', 'neutral')) {
            $architecture = Read-Host -Prompt 'Enter the architecture (x86, x64, arm, arm64, Neutral)' | TrimString
        }

        while ($InstallerType -notin @('exe', 'msi', 'msix', 'inno', 'nullsoft', 'appx', 'wix', 'zip')) {
            $InstallerType = Read-Host -Prompt 'Enter the InstallerType. For example: exe, msi, msix, inno, nullsoft' | TrimString
        }

        if ($InstallerType -ieq 'exe') {
            do {
                $Silent = Read-Host -Prompt 'Enter the silent install switch' | TrimString
                $SilentWithProgress = Read-Host -Prompt 'Enter the silent (with progress) install switch' | TrimString
            } while ([string]::IsNullOrWhiteSpace($Silent) -and [string]::IsNullOrWhiteSpace($SilentWithProgress))
        }

        do {
            $Moniker = Read-Host -Prompt '[OPTIONAL] Enter the Moniker (friendly name/alias). For example: vscode' | TrimString
        } while ($Moniker.Length -gt 40)

        do {
            $Tags = Read-Host -Prompt '[OPTIONAL] Enter any tags that would be useful to discover this tool. For example: zip, c++' | TrimString
        } while ($Tags.Length -gt 40)

        do {
            $PackageUrl = Read-Host -Prompt '[OPTIONAL] Enter the Url to the homepage of the application' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PackageUrl) -and ($PackageUrl.Length -lt 10 -or $Homepage.Length -gt 2000))

        while ([string]::IsNullOrWhiteSpace($ShortDescription) -or $ShortDescription.Length -gt '256') {
            $ShortDescription = Read-Host -Prompt 'Enter a short description of the application' | TrimString
        }

        ########## Create Manifests ##########
        New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.0.0.schema.json' | Out-File $VersionManifest
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.0.0.schema.json' | Out-File $InstallerManifest
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultlocale.1.0.0.schema.json' | Out-File $DefaultLocaleManifest

        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $VersionManifest -Append
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $InstallerManifest -Append
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $DefaultLocaleManifest -Append

        Write-Output "PackageVersion: $PackageVersion" | Out-File $VersionManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $InstallerManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $DefaultLocaleManifest -Append

        Write-Output "DefaultLocale: en-US" | Out-File $VersionManifest -Append
        Write-Output "DefaultLocale: en-US" | Out-File $InstallerManifest -Append

        Write-Output "InstallModes:" | Out-File $InstallerManifest -Append
        Write-Output "  - interactive" | Out-File $InstallerManifest -Append
        Write-Output "  - silent" | Out-File $InstallerManifest -Append
        Write-Output "  - silentWithProgress" | Out-File $InstallerManifest -Append

        Write-Output "Installers:" | Out-File $InstallerManifest -Append
        Write-Output "  - Architecture: $architecture" | Out-File $InstallerManifest -Append
        Write-Output "    InstallerUrl: $URL" | Out-File $InstallerManifest -Append
        Write-Output "    InstallerSha256: $Hash" | Out-File $InstallerManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($Scope)) {
            Write-Output "    Scope: $Scope" | Out-File $InstallerManifest -Append
        } else {
            Write-Output "#    Scope: " | Out-File $InstallerManifest -Append
        }

        Write-Output "    InstallerType: $InstallerType" | Out-File $InstallerManifest -Append

        if ((-not [string]::IsNullOrWhiteSpace($Silent)) -or 
            (-not [string]::IsNullOrWhiteSpace($SilentWithProgress))) {
            Write-Output "    InstallerSwitches:" | Out-File $InstallerManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($Silent)) {
            Write-Output "      Silent: $Silent" | Out-File $InstallerManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($SilentWithProgress)) {
            Write-Output "      SilentWithProgress: $SilentWithProgress" | Out-File $InstallerManifest -Append
        }

        Write-Output "UpgradeBehavior: install" | Out-File $InstallerManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($Publisher)) {
            Write-Output "Publisher: $Publisher" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Publisher: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PublisherUrl)) {
            Write-Output "PublisherUrl: $PublisherUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#PublisherUrl: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl)) {
            Write-Output "PublisherSupportUrl: $PublisherSupportUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#PublisherSupportUrl: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PrivacyUrl)) {
            Write-Output "PrivacyUrl: $PrivacyUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#PrivacyUrl: " | Out-File $DefaultLocaleManifest -Append
        }


        if (-not [string]::IsNullOrWhiteSpace($Author)) {
            Write-Output "Author: $Author" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Author: " | Out-File $DefaultLocaleManifest -Append
        }
        
        Write-Output "PackageName: $PackageName" | Out-File $DefaultLocaleManifest -Append
        if (-not [string]::IsNullOrWhiteSpace($PackageUrl)) {
            Write-Output "PackageUrl: $PackageUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#PackageUrl: " | Out-File $DefaultLocaleManifest -Append
        }
        
        if (-not [string]::IsNullOrWhiteSpace($License)) {
            Write-Output "License: $License" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#License: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($LicenseUrl)) {
            Write-Output "LicenseUrl: $LicenseUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#LicenseUrl: " | Out-File $DefaultLocaleManifest -Append
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Copyright)) {
            Write-Output "Copyright: $Copyright" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Copyright: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($CopyrightUrl)) {
            Write-Output "CopyrightUrl: $CopyrightUrl" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#CopyrightUrl: " | Out-File $DefaultLocaleManifest -Append
        }

        Write-Output "ShortDescription: $ShortDescription" | Out-File $DefaultLocaleManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($Moniker)) {
            Write-Output "Moniker: $Moniker" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Moniker: " | Out-File $DefaultLocaleManifest -Append
        }

        Write-Output "Tags:" | Out-File $DefaultLocaleManifest -Append
        
        foreach ($Tag in $Tags.Split(", ")) {
            Write-Output "  - $Tag" | Out-File $DefaultLocaleManifest -Append
        }
        
        Write-Output "ManifestType: version" | Out-File $VersionManifest -Append
        Write-Output "ManifestType: installer" | Out-File $InstallerManifest -Append
        Write-Output "ManifestType: defaultLocale" | Out-File $DefaultLocaleManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $VersionManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $InstallerManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $DefaultLocaleManifest -Append
    }
}

#endregion
##########################################


##########################################
#region Write metadata

# What does this stuff do??

#$FileOldEncoding = Get-Content -Raw $VersionManifest
#Remove-Item -Path $VersionManifest
#$ManifestPath = Join-Path $AppFolder $VersionManifest
#$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
#[System.IO.File]::WriteAllLines($ManifestPath, $FileOldEncoding, $Utf8NoBomEncoding)

Write-Host $NewLine
Write-Host "Yaml file created: $VersionManifest"
Write-Host "Yaml file created: $InstallerManifest"
Write-Host "Yaml file created: $DefaultLocaleManifest"

#endregion
##########################################
