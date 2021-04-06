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

while ([string]::IsNullOrWhiteSpace($OptionMenu)) {
    Clear-Host
    Write-Host -ForegroundColor 'Cyan' -Object 'Select Mode'
    Write-Host -ForegroundColor 'DarkCyan' -NoNewline "`n["; Write-Host -NoNewline '1'; Write-Host -ForegroundColor DarkCyan -NoNewline "]"; `
        Write-Host -ForegroundColor 'DarkCyan' -Object ' New Manifest'
    Write-Host -ForegroundColor 'DarkCyan' -NoNewline "`n["; Write-Host -NoNewline '2'; Write-Host -ForegroundColor DarkCyan -NoNewline "]"; `
        Write-Host -ForegroundColor 'DarkCyan' -Object ' Update Manifest'
    Write-Host -ForegroundColor 'DarkCyan' -NoNewline "`n["; Write-Host -NoNewline '3'; Write-Host -ForegroundColor DarkCyan -NoNewline "]"; `
        Write-Host -ForegroundColor 'DarkCyan' -Object ' New Locale'
    Write-Host -ForegroundColor 'DarkCyan' -NoNewline "`n["; Write-Host -NoNewline 'q'; Write-Host -ForegroundColor DarkCyan -NoNewline "]"; `
        Write-Host -ForegroundColor 'Red' -Object ' Any key to quit'
    $OptionMenu = Read-Host "`nSelection"
    switch ($OptionMenu) {
        '1' {$Option = 'New'}
        '2' {$Option = 'Update'}
        '3' {$Option = 'NewLocale'}
        default {exit}
    }
}

##########################################
#region checksum


#endregion
##########################################

##########################################
#region Read in metadata

while ($PackageIdentifier.Length -lt 4 -or $ID.Length -ge 255) {
    Write-Host
    Write-Host -ForegroundColor 'Green' -Object ' [Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
    $PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
    $PackageIdentifierFolder = $PackageIdentifier.Replace('.','\')
}

while ([string]::IsNullOrWhiteSpace($PackageVersion) -or $PackageName.Length -ge 128) {
    Write-Host
    Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
    $PackageVersion = Read-Host -Prompt 'Version' | TrimString
}

if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path ".\").Path
}

$AppFolder = Join-Path $ManifestsFolder $PackageIdentifier.ToLower().Chars(0) $PackageIdentifierFolder $PackageVersion

$VersionManifest = $AppFolder + "\$PackageIdentifier" + '.yaml'
$InstallerManifest = $AppFolder + "\$PackageIdentifier" + '.installer' + '.yaml'
$DefaultLocaleManifest = $AppFolder + "\$PackageIdentifier" + '.locale.en-US' + '.yaml'

switch ($Option) {
    'New' {
        while ([string]::IsNullOrWhiteSpace($URL)) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the URL to the installer.'
            $URL = Read-Host -Prompt 'URL' | TrimString
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

        ######################################
        #           Collect Metadata         #
        ######################################
        #           Installer Manifest       #
        while ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher.Length -ge 128) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation'
            $Publisher = Read-Host -Prompt 'Publisher' | TrimString
        }
        
        while ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName.Length -ge 128) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
            $PackageName = Read-Host -Prompt 'PackageName' | TrimString
        }

        while ($architecture -notin @('x86', 'x64', 'arm', 'arm64', 'neutral')) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the architecture (x86, x64, arm, arm64, neutral)'
            $architecture = Read-Host -Prompt 'Architecture' | TrimString
        }

        while ($InstallerType -notin @('exe', 'msi', 'msix', 'inno', 'nullsoft', 'appx', 'wix', 'zip')) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the InstallerType. For example: exe, msi, msix, inno, nullsoft'
            $InstallerType = Read-Host -Prompt 'InstallerType' | TrimString
        }

        if ($InstallerType -ieq 'exe') {
            while ([string]::IsNullOrWhiteSpace($Silent) -or ([string]::IsNullOrWhiteSpace($SilentWithProgress))) {
                Write-Host
                Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent install switch. For example: /s, -verysilent /qn'
                $Silent = Read-Host -Prompt 'Silent switch' | TrimString

                Write-Host
                Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent with progress install switch. For example: /s, -silent /qb'
                $SilentWithProgress = Read-Host -Prompt 'Silent with progress switch' | TrimString

                do {
                    Write-Host
                    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: -norestart'
                    $Custom = Read-Host -Prompt 'Custom Switch' | TrimString
                } while ($Custom.Length -gt '2048')
            }
        } else {
            do {
                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent install switch. For example: /s, -verysilent /qn'
                $Silent = Read-Host -Prompt 'Silent' | TrimString

                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent with progress install switch. For example: /s, -silent /qb'
                $SilentWithProgress = Read-Host -Prompt 'SilentWithProgress' | TrimString

                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: -norestart'
                $Custom = Read-Host -Prompt 'CustomSwitch' | TrimString
            } while ($Silent.Length -gt '2048') -or ($SilentWithProgress.Lenth -gt '512') -or ($Custom.Length -gt '2048')
        }

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
            $ProductCode = Read-Host -Prompt 'ProductCode' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($ProductCode) -and ($ProductCode.Length -lt 1 -or $ProductCode.Length -gt 255))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the upgrade method. install or uninstallPrevious'
            $UpgradeBehavior = Read-Host -Prompt 'UpgradeBehavior' | TrimString
        } until ([string]::IsNullOrWhiteSpace($UpgradeBehavior) -or ($UpgradeBehavior -eq 'install' -or $UpgradeBehavior -eq 'uninstallPrevious'))
        if ([string]::IsNullOrWhiteSpace($UpgradeBehavior)) {
            $UpgradeBehavior = 'install'
        }

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max 256)'
            $FileExtensions = Read-Host -Prompt 'FileExtensions' | TrimString
        } while ($FileExtensions.Split(", ").Count -gt '256')

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max 16)'
            $Protocols = Read-Host -Prompt 'Protocols' | TrimString
        } while ($Protocols.Split(", ").Count -gt '16')

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max 16)'
            $Commands = Read-Host -Prompt 'Commands' | TrimString
        } while ($Commands.Split(", ").Count -gt '16')

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Installer Scope. machine or user'
            $Scope = Read-Host -Prompt 'Scope' | TrimString
        } until ([string]::IsNullOrWhiteSpace($Scope) -or ($Scope -eq 'machine' -or $Scope -eq 'user'))

        #        DefaultLocale Manifest      #
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
            $Moniker = Read-Host -Prompt 'Moniker' | TrimString
        } while ($Moniker.Length -gt 40)
        
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
            $PublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherUrl) -and ($PublisherUrl.Length -lt 5 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
            $PublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl) -and ($PublisherSupportUrl.Length -lt 5 -or $PublisherSupportUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
            $PrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PrivacyUrl) -and ($PrivacyUrl.Length -lt 5 -or $PrivacyUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
            $Author = Read-Host -Prompt 'Author' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Author) -and ($Author.Length -lt 2 -or $Author.Length -gt 256))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            $PackageUrl = Read-Host -Prompt 'Homepage' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PackageUrl) -and ($PackageUrl.Length -lt 5 -or $PackageUrl.Length -gt 2000))

        while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 512) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary or Copyright (c) Microsoft Corporation'
            $License = Read-Host -Prompt 'License' | TrimString
        }
        
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            $LicenseUrl = Read-Host -Prompt 'License URL' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright.'
            $Copyright = Read-Host -Prompt 'Copyright' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Copyright) -and ($Copyright.Length -lt 5 -or $Copyright.Length -gt 512))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
            $CopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($CopyrightUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max 16)'
            $Tags = Read-Host -Prompt 'Tags' | TrimString
        } while ($Tags.Split(", ").Count -gt '16')

        while ([string]::IsNullOrWhiteSpace($ShortDescription) -or $ShortDescription.Length -gt '256') {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
            $ShortDescription = Read-Host -Prompt 'Short description' | TrimString
        }

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            $Description = Read-Host -Prompt 'Long Description' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Description) -and ($Description.Length -lt 3 -or $Description.Length -gt 10000))

        ######################################
        #           Create Manifests         #
        ######################################
        New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

        ######################################
        #           VersionManifest          #
        ######################################
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.0.0.schema.json' | Out-File $VersionManifest
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $VersionManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $VersionManifest -Append
        Write-Output "DefaultLocale: en-US" | Out-File $VersionManifest -Append
        Write-Output "ManifestType: version" | Out-File $VersionManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $VersionManifest -Append

        $FileOldEncoding = Get-Content -Raw $VersionManifest
        Remove-Item -Path $VersionManifest
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($VersionManifest, $FileOldEncoding, $Utf8NoBomEncoding)

        Write-Host 
        Write-Host "Yaml file created: $VersionManifest"

        ######################################
        #           InstallerManifest        #
        ######################################
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.0.0.schema.json' | Out-File $InstallerManifest
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $InstallerManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $InstallerManifest -Append
        Write-Output "FileExtensions:" | Out-File $InstallerManifest -Append
        if (-not [string]::IsNullOrWhiteSpace($FileExtensions)) {
            foreach ($FileExtension in $FileExtensions.Split(", ")) {
                Write-Output "  - $FileExtension" | Out-File $InstallerManifest -Append
            }
        } else {
            Write-Output "#  - " | Out-File $InstallerManifest -Append
        }
        Write-Output "Protocols:" | Out-File $InstallerManifest -Append
        if (-not [string]::IsNullOrWhiteSpace($Protocols)) {
            foreach ($Protocol in $Protocols.Split(", ")) {
                Write-Output "  - $Protocol" | Out-File $InstallerManifest -Append
            }
        } else {
            Write-Output "#  - " | Out-File $InstallerManifest -Append
        }
        Write-Output "Commands:" | Out-File $InstallerManifest -Append
        if (-not [string]::IsNullOrWhiteSpace($Commands)) {
            foreach ($Command in $Commands.Split(", ")) {
                Write-Output "  - $Command" | Out-File $InstallerManifest -Append
            }
        } else {
            Write-Output "#  - " | Out-File $InstallerManifest -Append
        }
        Write-Output "MinimumOSVersion: 10.0.0.0" | Out-File $InstallerManifest -Append
        Write-Output "InstallModes:" | Out-File $InstallerManifest -Append
        Write-Output "  - interactive" | Out-File $InstallerManifest -Append
        Write-Output "  - silent" | Out-File $InstallerManifest -Append
        Write-Output "  - silentWithProgress" | Out-File $InstallerManifest -Append
        Write-Output "Installers:" | Out-File $InstallerManifest -Append
        Write-Output "  - Architecture: $architecture" | Out-File $InstallerManifest -Append
        Write-Output "    InstallerType: $InstallerType" | Out-File $InstallerManifest -Append
        Write-Output "    InstallerUrl: $URL" | Out-File $InstallerManifest -Append
        Write-Output "    InstallerSha256: $Hash" | Out-File $InstallerManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($Scope)) {
            Write-Output "    Scope: $Scope" | Out-File $InstallerManifest -Append } else { Write-Output "#    Scope: " | Out-File $InstallerManifest -Append
        }

        Write-Output "    InstallerLocale: en-US" | Out-File $InstallerManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
            Write-Output "    ProductCode: `"$ProductCode`"" | Out-File $InstallerManifest -Append } else { Write-Output "#    ProductCode: " | Out-File $InstallerManifest -Append
        }
        
        if ((-not [string]::IsNullOrWhiteSpace($Silent)) -or (-not [string]::IsNullOrWhiteSpace($SilentWithProgress))) {
            Write-Output "    InstallerSwitches:" | Out-File $InstallerManifest -Append
            Write-Output "      Custom: $Custom" | Out-File $InstallerManifest -Append
            Write-Output "      Silent: $Silent" | Out-File $InstallerManifest -Append
            Write-Output "      SilentWithProgress: $SilentWithProgress" | Out-File $InstallerManifest -Append
        }

        Write-Output "    UpgradeBehavior: $UpgradeBehavior" | Out-File $InstallerManifest -Append
        Write-Output "ManifestType: installer" | Out-File $InstallerManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $InstallerManifest -Append

        $FileOldEncoding = Get-Content -Raw $InstallerManifest
        Remove-Item -Path $InstallerManifest
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($InstallerManifest, $FileOldEncoding, $Utf8NoBomEncoding)

        Write-Host
        Write-Host "Yaml file created: $InstallerManifest"

        ######################################
        #        DefaultLocaleManifest       #
        ######################################
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultlocale.1.0.0.schema.json' | Out-File $DefaultLocaleManifest
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $DefaultLocaleManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $DefaultLocaleManifest -Append
        Write-Output "PackageLocale: en-US" | Out-File $DefaultLocaleManifest -Append
        
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

        if (-not [string]::IsNullOrWhiteSpace($Description)) {
            Write-Output "Description: $Description" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Description: " | Out-File $DefaultLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($Moniker)) {
            Write-Output "Moniker: $Moniker" | Out-File $DefaultLocaleManifest -Append
        } else {
            Write-Output "#Moniker: " | Out-File $DefaultLocaleManifest -Append
        }

        Write-Output "Tags:" | Out-File $DefaultLocaleManifest -Append
        
        if (-not [string]::IsNullOrWhiteSpace($Tags)) {
            foreach ($Tag in $Tags.Split(", ")) {
                Write-Output "  - $Tag" | Out-File $DefaultLocaleManifest -Append
            }
        } else {
            Write-Output "#  - " | Out-File $DefaultLocaleManifest -Append
        }
        
        Write-Output "ManifestType: defaultLocale" | Out-File $DefaultLocaleManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $DefaultLocaleManifest -Append

        $FileOldEncoding = Get-Content -Raw $DefaultLocaleManifest
        Remove-Item -Path $DefaultLocaleManifest
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($DefaultLocaleManifest, $FileOldEncoding, $Utf8NoBomEncoding)

        Write-Host
        Write-Host "Yaml file created: $DefaultLocaleManifest"
    }

    'Update' {
        $LastVersion = Get-ChildItem -Path "$AppFolder\..\" | Sort-Object | Select-Object -Last 1 -ExpandProperty 'Name'
        $OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"

        if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.en-US.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
            while ([string]::IsNullOrWhiteSpace($URL)) {
                Write-Host
                Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the URL to the installer.'
                $URL = Read-Host -Prompt 'URL' | TrimString
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

            Write-Host

            New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null
            Copy-Item -Path $OldManifests -Destination $AppFolder

            do {
                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
                $ProductCode = Read-Host -Prompt 'ProductCode' | TrimString
            } while (-not [string]::IsNullOrWhiteSpace($ProductCode) -and ($ProductCode.Length -lt 1 -or $ProductCode.Length -gt 255))

            if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
                ((Get-Content -Path $InstallerManifest) -replace '(?<=ProductCode: ).*',"`"$ProductCode`"") | Set-Content -Path $InstallerManifest
            } else {
                ((Get-Content -Path $InstallerManifest) -replace '(    ProductCode: ).*',"#    ProductCode: ") | Set-Content -Path $InstallerManifest
            }

            ((Get-Content -Path $VersionManifest) -replace '(?<=PackageVersion: ).*',"$PackageVersion") | Set-Content -Path $VersionManifest
            ((Get-Content -Path $InstallerManifest) -replace '(?<=PackageVersion: ).*',"$PackageVersion") | Set-Content -Path $InstallerManifest
            ((Get-Content -Path $DefaultLocaleManifest) -replace '(?<=PackageVersion: ).*',"$PackageVersion") | Set-Content -Path $DefaultLocaleManifest

            ((Get-Content -Path $InstallerManifest) -replace '(?<=InstallerUrl: ).*',"$URL") | Set-Content -Path $InstallerManifest
            ((Get-Content -Path $InstallerManifest) -replace '(?<=InstallerSha256: ).*',"$Hash") | Set-Content -Path $InstallerManifest
            
            ((Get-Content -Path $InstallerManifest) -replace '(?<=ProductCode: ).*',"`"$ProductCode`"") | Set-Content -Path $InstallerManifest

            $FileOldEncoding = Get-Content -Raw $VersionManifest
            Remove-Item -Path $VersionManifest
            $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($VersionManifest, $FileOldEncoding, $Utf8NoBomEncoding)

            $FileOldEncoding = Get-Content -Raw $InstallerManifest
            Remove-Item -Path $InstallerManifest
            $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($InstallerManifest, $FileOldEncoding, $Utf8NoBomEncoding)

            $FileOldEncoding = Get-Content -Raw $DefaultLocaleManifest
            Remove-Item -Path $DefaultLocaleManifest
            $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllLines($DefaultLocaleManifest, $FileOldEncoding, $Utf8NoBomEncoding)

            Write-Host
            Write-Host "Updated Yaml file: $VersionManifest"
            Write-Host "Updated Yaml file: $InstallerManifest"
            Write-Host "Updated Yaml file: $DefaultLocaleManifest"
        } else {
            $option = "New"
            Write-Host "Error: The old manifest does not contain a multi manifest."
        }
    }

    'NewLocale' {
        New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null
        ######################################
        #           Create Manifests         #
        ######################################
        while ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher.Length -ge 128) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation'
            $Publisher = Read-Host -Prompt 'Publisher' | TrimString
        }
        
        while ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName.Length -ge 128) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
            $PackageName = Read-Host -Prompt 'PackageName' | TrimString
        }
        
        while ([string]::IsNullOrWhiteSpace($PackageLocale) -or $PackageLocale.Length -ge 20) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the locale. For example: en-US, en-CA'
            $PackageLocale = Read-Host -Prompt 'PackageLocale' | TrimString
            
            $NewLocaleManifest = $AppFolder + "\$PackageIdentifier" + ".locale.$PackageLocale" + '.yaml'
        }

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url'
            $PublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherUrl) -and ($PublisherUrl.Length -lt 5 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url'
            $PublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl) -and ($PublisherSupportUrl.Length -lt 5 -or $PublisherSupportUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Privacy Url'
            $PrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PrivacyUrl) -and ($PrivacyUrl.Length -lt 5 -or $PrivacyUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Application Author'
            $Author = Read-Host -Prompt 'Author' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Author) -and ($Author.Length -lt 1 -or $Author.Length -gt 256))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            $PackageUrl = Read-Host -Prompt 'Homepage' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PackageUrl) -and ($PackageUrl.Length -lt 5 -or $PackageUrl.Length -gt 2000))

        while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 512) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary or Copyright (c) Microsoft Corporation'
            $License = Read-Host -Prompt 'License' | TrimString
        }
        
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            $LicenseUrl = Read-Host -Prompt 'License URL' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright'
            $Copyright = Read-Host -Prompt 'Copyright' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Copyright) -and ($Copyright.Length -lt 5 -or $Copyright.Length -gt 512))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url'
            $CopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($CopyrightUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max 16)'
            $Tags = Read-Host -Prompt 'Tags' | TrimString
        } while ($Tags.Split(", ").Count -gt '16')

        while ([string]::IsNullOrWhiteSpace($ShortDescription) -or $ShortDescription.Length -gt '256') {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
            $ShortDescription = Read-Host -Prompt 'Short description' | TrimString
        }

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            $Description = Read-Host -Prompt 'Long Description' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Description) -and ($Description.Length -lt 10 -or $Description.Length -gt 10000))

        ######################################
        #           Locale Manifests         #
        ######################################
        Write-Output '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json' | Out-File $NewLocaleManifest
        Write-Output "PackageIdentifier: $PackageIdentifier" | Out-File $NewLocaleManifest -Append
        Write-Output "PackageVersion: $PackageVersion" | Out-File $NewLocaleManifest -Append
        Write-Output "PackageLocale: $PackageLocale" | Out-File $NewLocaleManifest -Append
        
        if (-not [string]::IsNullOrWhiteSpace($Publisher)) {
            Write-Output "Publisher: $Publisher" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#Publisher: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PublisherUrl)) {
            Write-Output "PublisherUrl: $PublisherUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#PublisherUrl: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl)) {
            Write-Output "PublisherSupportUrl: $PublisherSupportUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#PublisherSupportUrl: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($PrivacyUrl)) {
            Write-Output "PrivacyUrl: $PrivacyUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#PrivacyUrl: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($Author)) {
            Write-Output "Author: $Author" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#Author: " | Out-File $NewLocaleManifest -Append
        }

        Write-Output "PackageName: $PackageName" | Out-File $NewLocaleManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($PackageUrl)) {
            Write-Output "PackageUrl: $PackageUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#PackageUrl: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($License)) {
            Write-Output "License: $License" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#License: " | Out-File $NewLocaleManifest -Append
        }
        
        if (-not [string]::IsNullOrWhiteSpace($LicenseUrl)) {
            Write-Output "LicenseUrl: $LicenseUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#LicenseUrl: " | Out-File $NewLocaleManifest -Append
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Copyright)) {
            Write-Output "Copyright: $Copyright" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#Copyright: " | Out-File $NewLocaleManifest -Append
        }
        
        if (-not [string]::IsNullOrWhiteSpace($CopyrightUrl)) {
            Write-Output "CopyrightUrl: $CopyrightUrl" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#CopyrightUrl: " | Out-File $NewLocaleManifest -Append
        }

        Write-Output "ShortDescription: $ShortDescription" | Out-File $NewLocaleManifest -Append

        if (-not [string]::IsNullOrWhiteSpace($Description)) {
            Write-Output "Description: $Description" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#Description: " | Out-File $NewLocaleManifest -Append
        }

        if (-not [string]::IsNullOrWhiteSpace($Moniker)) {
            Write-Output "Moniker: $Moniker" | Out-File $NewLocaleManifest -Append
        } else {
            Write-Output "#Moniker: " | Out-File $NewLocaleManifest -Append
        }

        Write-Output "Tags:" | Out-File $NewLocaleManifest -Append
        
        if (-not [string]::IsNullOrWhiteSpace($Tags)) {
            foreach ($Tag in $Tags.Split(", ")) {
                Write-Output "  - $Tag" | Out-File $NewLocaleManifest -Append
            }
        } else {
            Write-Output "#  - " | Out-File $NewLocaleManifest -Append
        }
        
        Write-Output "ManifestType: locale" | Out-File $NewLocaleManifest -Append
        Write-Output "ManifestVersion: 1.0.0" | Out-File $NewLocaleManifest -Append

        $FileOldEncoding = Get-Content -Raw $NewLocaleManifest
        Remove-Item -Path $NewLocaleManifest
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($NewLocaleManifest, $FileOldEncoding, $Utf8NoBomEncoding)

        Write-Host
        Write-Host "Yaml file created: $NewLocaleManifest"
    }

    Default {
        Exit
    }
}
