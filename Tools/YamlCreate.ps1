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

filter TrimString {
    $_.Trim()
}

Function Show-OptionMenu {
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
            '1' {$script:Option = 'New'}
            '2' {$script:Option = 'Update'}
            '3' {$script:Option = 'NewLocale'}
            default {exit}
        }
    }
}

Function Read-WinGet-MandatoryInfo {
    while ($PackageIdentifier.Length -lt 4 -or $ID.Length -ge 255) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
        $script:PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
        $PackageIdentifierFolder = $PackageIdentifier.Replace('.','\')
    }
    
    while ([string]::IsNullOrWhiteSpace($PackageVersion) -or $PackageName.Length -ge 128) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
        $script:PackageVersion = Read-Host -Prompt 'Version' | TrimString
    }
    
    if (Test-Path -Path "$PSScriptRoot\..\manifests") {
        $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
    } else {
        $ManifestsFolder = (Resolve-Path ".\").Path
    }
    
    $script:AppFolder = Join-Path $ManifestsFolder -ChildPath $PackageIdentifier.ToLower().Chars(0) | Join-Path -ChildPath $PackageIdentifierFolder | Join-Path -ChildPath $PackageVersion
}

Function Read-PreviousWinGet-Manifest {
    Switch ($Option) {
        'Update' {
            $script:LastVersion = Get-ChildItem -Path "$AppFolder\..\" | Sort-Object | Select-Object -Last 1 -ExpandProperty 'Name'
            $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"

            if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.en-US.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
                $script:OldManifestText = Get-Content -Path "$AppFolder\..\$LastVersion\$PackageIdentifier.installer.yaml", "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.en-US.yaml", "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml"
            } elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
                $script:OldManifestText = Get-Content -Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml"
            } else {
                Throw "Error: Old Manifest not found"
            }
            
            ForEach ($Line in $OldManifestText -ne '') {
                if ($Line -eq "Tags:") {
                    $regex = '(?ms)Tags:(.+?):'
                    $FetchTags = [regex]::Matches($OldManifestText,$regex) | foreach {$_.groups[1].value }
                    $Tags = $FetchTags.Substring(0, $FetchTags.LastIndexOf(' '))
                    New-Variable -Name "Tags" -Value ($Tags.Split("-").Trim()[1..100] -join ", ") -Scope Script -Force
                } elseif ($Line -eq "FileExtensions:") {
                    $regex = '(?ms)FileExtensions:(.+?):'
                    $FetchFileExtensions = [regex]::Matches($OldManifestText,$regex) | foreach {$_.groups[1].value }
                    $FileExtensions = $FetchFileExtensions.Substring(0, $FetchFileExtensions.LastIndexOf(' '))
                    New-Variable -Name "FileExtensions" -Value ($FileExtensions.Split("-").Trim()[1..100] -join ", ") -Scope Script -Force
                } elseif ($Line -eq "Protocols:") {
                    $regex = '(?ms)Protocols:(.+?):'
                    $FetchProtocols = [regex]::Matches($OldManifestText,$regex) | foreach {$_.groups[1].value }
                    $Protocols = $FetchProtocols.Substring(0, $FetchProtocols.LastIndexOf(' '))
                    New-Variable -Name "Protocols" -Value ($Protocols.Split("-").Trim()[1..100] -join ", ") -Scope Script -Force
                } elseif ($Line -eq "Commands:") {
                    $regex = '(?ms)Commands:(.+?):'
                    $FetchCommands = [regex]::Matches($OldManifestText,$regex) | foreach {$_.groups[1].value }
                    $Commands = $FetchCommands.Substring(0, $FetchCommands.LastIndexOf(' '))
                    New-Variable -Name "Commands" -Value ($Commands.Split("-").Trim()[1..100] -join ", ") -Scope Script -Force
                } elseif ($Line -notlike "PackageVersion*") {
                    $Variable = $Line.Replace("#","").Split(":").Trim()
                    New-Variable -Name $Variable[0] -Value ($Variable[1..10] -join ":") -Scope Script -Force
                }
            }

            if (!(Test-Path $AppFolder)) {New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null}
            ForEach ($DifLocale in $OldManifests) {
                if ($DifLocale.Name -notin @("$PackageIdentifier.yaml","$PackageIdentifier.installer.yaml","$PackageIdentifier.locale.en-US.yaml")) {
                    $DifLocaleContent = Get-Content -Path $DifLocale.FullName
                    Out-File ($AppFolder + "\" + $DifLocale.Name) -InputObject $DifLocaleContent.Replace("PackageVersion: $LastVersion","PackageVersion: $PackageVersion") -Encoding 'UTF8'
                }
            }
        }

        'NewLocale' {
            $script:OldManifests = Get-ChildItem -Path "$AppFolder"
            if ($OldManifests.Name -eq "$PackageIdentifier.locale.en-US.yaml") {
                $script:OldManifestText = Get-Content -Path "$AppFolder\$PackageIdentifier.locale.en-US.yaml"
            } else {
                Throw "Error: Multimanifest required"
            }

            ForEach ($Line in $OldManifestText -ne '') {
                if ($Line -eq "Tags:") {
                    $regex = '(?ms)Tags:(.+?):'
                    $FetchTags = [regex]::Matches($OldManifestText,$regex) | foreach {$_.groups[1].value }
                    $Tags = $FetchTags.Substring(0, $FetchTags.LastIndexOf(' '))
                    New-Variable -Name "Tags" -Value ($Tags.Split("-").Trim()[1..100] -join ", ") -Scope Script -Force
                } elseif ($Line -notlike "PackageLocale*") {
                    $Variable = $Line.Replace("#","").Split(":").Trim()
                    New-Variable -Name $Variable[0] -Value ($Variable[1..10] -join ":") -Scope Script -Force
                }
            }
        }
    }
}

Function Read-WinGet-InstallerValues {
    Clear-Variable -Name 'Architecture' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'InstallerType' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'InstallerUrl' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'InstallerSha256' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'Custom' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'Silent' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'SilentWithProgress' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'ProductCode' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'Scope' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'InstallerLocale' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'UpgradeBehavior' -Force -ErrorAction SilentlyContinue
    Clear-Variable -Name 'AnotherInstaller' -Force -ErrorAction SilentlyContinue

    while ([string]::IsNullOrWhiteSpace($InstallerUrl)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the download url to the installer.'
        $InstallerUrl = Read-Host -Prompt 'Url' | TrimString
    }
    Write-Host $NewLine
    Write-Host 'Downloading URL. This will take awhile...' -ForegroundColor Blue
    $WebClient = New-Object System.Net.WebClient

    try {
        $Stream = $WebClient.OpenRead($InstallerUrl)
        $InstallerSha256 = (Get-FileHash -InputStream $Stream -Algorithm SHA256).Hash
    }
    catch {
        Write-Host 'Error downloading file. Please run the script again.' -ForegroundColor Red
        exit 1
    }
    finally {
        $Stream.Close()
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
        } while ($Silent.Length -gt '2048' -or $SilentWithProgress.Lenth -gt '512' -or $Custom.Length -gt '2048')
    }

    while ([string]::IsNullOrWhiteSpace($InstallerLocale) -or $InstallerLocale.Length -gt '10') {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the locale. For example: en-US, en-CA https://docs.microsoft.com/en-us/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $InstallerLocale = Read-Host -Prompt 'InstallerLocale' | TrimString
    }

    do {
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
        $ProductCode = Read-Host -Prompt 'ProductCode' | TrimString
    } while (-not [string]::IsNullOrWhiteSpace($ProductCode) -and ($ProductCode.Length -lt 1 -or $ProductCode.Length -gt 255))

    do {
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Installer Scope. machine or user'
        $Scope = Read-Host -Prompt 'Scope' | TrimString
    } until ([string]::IsNullOrWhiteSpace($Scope) -or ($Scope -eq 'machine' -or $Scope -eq 'user'))

    do {
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the upgrade method. install or uninstallPrevious'
        $UpgradeBehavior = Read-Host -Prompt 'UpgradeBehavior' | TrimString
    } until ([string]::IsNullOrWhiteSpace($UpgradeBehavior) -or ($UpgradeBehavior -eq 'install' -or $UpgradeBehavior -eq 'uninstallPrevious'))
    if ([string]::IsNullOrWhiteSpace($UpgradeBehavior)) {
        $UpgradeBehavior = 'install'
    }

    $script:Installers += "  - Architecture: $Architecture`n"
    $script:Installers += "    InstallerType: $InstallerType`n"
    $script:Installers += "    InstallerUrl: $InstallerUrl`n"
    $script:Installers += "    InstallerSha256: $InstallerSha256`n"
    if ($Silent) {$script:Installers += "    InstallerSwitches:`n"
    $script:Installers += "      Custom: $Custom`n"
    $script:Installers += "      Silent: $Silent`n"
    $script:Installers += "      SilentWithProgress: $SilentWithProgress`n"}
    $script:Installers += "    ProductCode: $ProductCode`n"
    $script:Installers += "    Scope: $Scope`n"
    $script:Installers += "    InstallerLocale: $InstallerLocale`n"
    $script:Installers += "    UpgradeBehavior: $UpgradeBehavior`n"

    do {
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Do you want to create another installer?'
        $AnotherInstaller = Read-Host -Prompt 'y or n' | TrimString
    } while ([string]::IsNullOrWhiteSpace($AnotherInstaller)) 
    if ($AnotherInstaller -eq 'y') { Read-WinGet-InstallerValues }
}

Function Read-WinGet-InstallerManifest {
    if ([string]::IsNullOrWhiteSpace($FileExtensions)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max 256)'
            $script:FileExtensions = Read-Host -Prompt 'FileExtensions' | TrimString
        } while ($FileExtensions.Split(", ").Count -gt '256')
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max 256)'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $FileExtensions"
            $NewFileExtensions = Read-Host -Prompt 'FileExtensions' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewFileExtensions)) {
                $script:FileExtensions = $NewFileExtensions
            }
        } while ($FileExtensions.Split(", ").Count -gt '256')
    }

    if ([string]::IsNullOrWhiteSpace($Protocols)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max 16)'
            $script:Protocols = Read-Host -Prompt 'Protocols' | TrimString
        } while ($Protocols.Split(", ").Count -gt '16')
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max 16)'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Protocols"
            $NewProtocols = Read-Host -Prompt 'Protocols' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewProtocols)) {
                $script:Protocols = $NewProtocols
            }
        } while ($Protocols.Split(", ").Count -gt '16')
    }

    if ([string]::IsNullOrWhiteSpace($Commands)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max 16)'
            $script:Commands = Read-Host -Prompt 'Commands' | TrimString
        } while ($Commands.Split(", ").Count -gt '16')
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max 16)'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Commands"
            $NewCommands = Read-Host -Prompt 'Commands' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewCommands)) {
                $script:Commands = $NewCommands
            }
        } while ($Commands.Split(", ").Count -gt '16')
    }

}

Function Read-WinGet-LocaleManifest {
    while ([string]::IsNullOrWhiteSpace($PackageLocale) -or $PackageLocale.Length -gt '128') {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Locale. For example: en-US, en-CA https://docs.microsoft.com/en-us/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $script:PackageLocale = Read-Host -Prompt 'PackageLocale' | TrimString
    }

    if ([string]::IsNullOrWhiteSpace($Publisher)) {
        while ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher.Length -gt '128') {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation'
            $script:Publisher = Read-Host -Prompt 'Publisher' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full publisher name. For example: Microsoft Corporation'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Publisher"
            $NewPublisher = Read-Host -Prompt 'Publisher' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPublisher)) {
                $script:Publisher = $NewPublisher
            }
        } while ($Publisher.Length -gt '128')
    }

    if ([string]::IsNullOrWhiteSpace($PackageName)) {
        while ([string]::IsNullOrWhiteSpace($PackageName) -or $PackageName.Length -gt '128') {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
            $script:PackageName = Read-Host -Prompt 'PackageName' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full application name. For example: Microsoft Teams'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $PackageName"
            $NewPackageName = Read-Host -Prompt 'PackageName' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPackageName)) {
                $script:PackageName = $NewPackageName
            }
        } while ($PackageName.Length -gt '128')
    }

    if ([string]::IsNullOrWhiteSpace($Moniker)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
            $script:Moniker = Read-Host -Prompt 'Moniker' | TrimString
        } while ($Moniker.Length -gt '40')
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Moniker"
            $NewMoniker = Read-Host -Prompt 'Moniker' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewMoniker)) {
                $script:Moniker = $NewMoniker
            }
        } while ($Moniker.Length -gt '40')
    }

    if ([string]::IsNullOrWhiteSpace($PublisherUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
            $script:PublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherUrl) -and ($PublisherUrl.Length -lt 5 -or $LicenseUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $PublisherUrl"
            $NewPublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewNewPublisherUrl)) {
                $script:PublisherUrl = $NewPublisherUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($PublisherUrl) -and ($PublisherUrl.Length -lt 5 -or $LicenseUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($PublisherSupportUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
            $script:PublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl) -and ($PublisherSupportUrl.Length -lt 5 -or $PublisherSupportUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $PublisherSupportUrl"
            $NewPublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPublisherSupportUrl)) {
                $script:PublisherSupportUrl = $NewPublisherSupportUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($PublisherSupportUrl) -and ($PublisherSupportUrl.Length -lt 5 -or $PublisherSupportUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($PrivacyUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
            $script:PrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PrivacyUrl) -and ($PrivacyUrl.Length -lt 5 -or $PrivacyUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $PrivacyUrl"
            $NewPrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPrivacyUrl)) {
                $script:PrivacyUrl = $NewPrivacyUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($PrivacyUrl) -and ($PrivacyUrl.Length -lt 5 -or $PrivacyUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($Author)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
            $script:Author = Read-Host -Prompt 'Author' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Author) -and ($Author.Length -lt 2 -or $Author.Length -gt 256))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Author"
            $NewAuthor = Read-Host -Prompt 'Author' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewAuthor)) {
                $script:Author = $NewAuthor
            }
        } while (-not [string]::IsNullOrWhiteSpace($Author) -and ($Author.Length -lt 2 -or $Author.Length -gt 256))
    }

    if ([string]::IsNullOrWhiteSpace($PackageUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            $script:PackageUrl = Read-Host -Prompt 'Homepage' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($PackageUrl) -and ($PackageUrl.Length -lt 5 -or $PackageUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $PackageUrl"
            $NewPackageUrl = Read-Host -Prompt 'Homepage' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPackageUrl)) {
                $script:PackageUrl = $NewPackageUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($PackageUrl) -and ($PackageUrl.Length -lt 5 -or $PackageUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($License)) {
        while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 512) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary or Copyright (c) Microsoft Corporation'
            $script:License = Read-Host -Prompt 'License' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License. For example: MIT, GPL, Freeware, Proprietary or Copyright (c) Microsoft Corporation'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $License"
            $NewLicense = Read-Host -Prompt 'License' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewLicense)) {
                $script:License = $NewLicense
            }
        } while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 512)
    }

    if ([string]::IsNullOrWhiteSpace($LicenseUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            $script:LicenseUrl = Read-Host -Prompt 'License URL' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $LicenseUrl"
            $NewLicenseUrl = Read-Host -Prompt 'License URL' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewLicenseUrl)) {
                $script:LicenseUrl = $NewLicenseUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($Copyright)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright.'
            $script:Copyright = Read-Host -Prompt 'Copyright' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Copyright) -and ($Copyright.Length -lt 5 -or $Copyright.Length -gt 512))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Copyright"
            $NewCopyright = Read-Host -Prompt 'Copyright' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewCopyright)) {
                $script:Copyright = $NewCopyright
            }
        } while (-not [string]::IsNullOrWhiteSpace($Copyright) -and ($Copyright.Length -lt 5 -or $Copyright.Length -gt 512))
    }

    if ([string]::IsNullOrWhiteSpace($CopyrightUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
            $script:CopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($CopyrightUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $CopyrightUrl"
            $NewCopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewCopyrightUrl)) {
                $script:CopyrightUrl = $NewCopyrightUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($CopyrightUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))
    }

    if ([string]::IsNullOrWhiteSpace($Tags)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max 16)'
            $script:Tags = Read-Host -Prompt 'Tags' | TrimString
        } while ($Tags.Split(", ").Count -gt '16')
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max 16)'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Tags"
            $NewTags = Read-Host -Prompt 'Tags' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewTags)) {
                $script:Tags = $NewTags
            }
        } while ($Tags.Split(", ").Count -gt '16')
    }

    if ([string]::IsNullOrWhiteSpace($ShortDescription)) {
        while ([string]::IsNullOrWhiteSpace($ShortDescription) -or $ShortDescription.Length -gt '256') {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
            $script:ShortDescription = Read-Host -Prompt 'Short Description' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a short description of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $ShortDescription"
            $NewShortDescription = Read-Host -Prompt 'Short Description' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewShortDescription)) {
                $script:ShortDescription = $NewShortDescription
            }
        } while ([string]::IsNullOrWhiteSpace($ShortDescription) -or $ShortDescription.Length -gt '256')
    }

    if ([string]::IsNullOrWhiteSpace($Description)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            $script:Description = Read-Host -Prompt 'Long Description' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($Description) -and ($Description.Length -lt 3 -or $Description.Length -gt 10000))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Description"
            $NewDescription = Read-Host -Prompt 'Description' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewDescription)) {
                $script:Description = $NewDescription
            }
        } while (-not [string]::IsNullOrWhiteSpace($Description) -and ($Description.Length -lt 3 -or $Description.Length -gt 10000))
    }

}

Function Write-WinGet-VersionManifest {
$VersionManifest = @(
'# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.0.0.schema.json'
"PackageIdentifier: $PackageIdentifier"
"PackageVersion: $PackageVersion"
"DefaultLocale: en-US"
"ManifestType: version"
"ManifestVersion: 1.0.0"
)
New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

$VersionManifestPath = $AppFolder + "\$PackageIdentifier" + '.yaml'

Out-File $VersionManifestPath -InputObject $VersionManifest -Encoding 'UTF8'

Write-Host 
Write-Host "Yaml file created: $VersionManifestPath"
}

Function Write-WinGet-InstallerManifest {
$InstallerManifest = @(
'# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.0.0.schema.json'
"PackageIdentifier: $PackageIdentifier"
"PackageVersion: $PackageVersion"
"MinimumOSVersion: 10.0.0.0"
if ($FileExtensions) {"FileExtensions:"
Foreach ($FileExtension in $FileExtensions.Split(",").Trim()) {"  - $FileExtension" }}
if ($Protocols) {"Protocols:"
Foreach ($Protocol in $Protocols.Split(",").Trim()) {"  - $Protocol" }}
if ($Commands) {"Commands:"
Foreach ($Command in $Commands.Split(",").Trim()) {"  - $Command" }}
"InstallModes:"
"  - interactive"
"  - silent"
"  - silentWithProgress"
"Installers:"
$Installers.TrimEnd()
"ManifestType: installer"
"ManifestVersion: 1.0.0"
)

New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

$InstallerManifestPath = $AppFolder + "\$PackageIdentifier" + '.installer' + '.yaml'

Out-File $InstallerManifestPath -InputObject $InstallerManifest -Encoding 'UTF8'

Write-Host 
Write-Host "Yaml file created: $InstallerManifestPath"

ForEach ($Line in (Get-Content $InstallerManifestPath)) {
    $LookForVariable = $Line.Split(":").Trim()
    if ($LookForVariable[1] -eq '' -and $Line -notin @("FileExtensions:","Protocols:","Commands:","InstallModes:","Installers:","  - Architecture","    InstallerSwitches:")) {
        ((Get-Content -Path "$InstallerManifestPath") -replace ($LookForVariable[0] + ":"),("#"+$LookForVariable[0] + ":")) | Set-Content -Path "$InstallerManifestPath" -Encoding 'UTF8'
    }
}
((Get-Content -Path "$InstallerManifestPath") -replace "##","#") | Set-Content -Path "$InstallerManifestPath" -Encoding 'UTF8' # Anyway to fix this?
}

Function Write-WinGet-LocaleManifest {
$DefaultLocaleManifest = @(
if ($PackageLocale -eq 'en-US') {'# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultlocale.1.0.0.schema.json'}else{'# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json'}
"PackageIdentifier: $PackageIdentifier"
"PackageVersion: $PackageVersion"
"PackageLocale: $PackageLocale"
"Publisher: $Publisher"
"PublisherUrl: $PublisherUrl"
"PublisherSupportUrl: $PublisherSupportUrl"
"PrivacyUrl: $PrivacyUrl"
"Author: $Author"
"PackageName: $PackageName"
"PackageUrl: $PackageUrl"
"License: $License"
"LicenseUrl: $LicenseUrl"
"Copyright: $Copyright"
"CopyrightUrl: $CopyrightUrl"
"ShortDescription: $ShortDescription"
"Description: $Description"
if ($Moniker -and $PackageLocale -eq 'en-US') {"Moniker: $Moniker"}
if ($Tags) {"Tags:"
Foreach ($Tag in $Tags.Split(",").Trim()) {"  - $Tag" }}
if ($PackageLocale -eq 'en-US') {"ManifestType: defaultLocale"}else{"ManifestType: locale"}
"ManifestVersion: 1.0.0"
)

New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

$DefaultLocaleManifestPath = $AppFolder + "\$PackageIdentifier" + ".locale." + "$PackageLocale" + '.yaml'

Out-File $DefaultLocaleManifestPath -InputObject $DefaultLocaleManifest -Encoding 'UTF8'

Write-Host 
Write-Host "Yaml file created: $DefaultLocaleManifestPath"

ForEach ($Line in (Get-Content $DefaultLocaleManifestPath)) {
    $LookForVariable = $Line.Split(":").Trim()
    if ($LookForVariable[1] -eq '' -and $Line -notin @("Tags:", "  -*")) {
        ((Get-Content -Path "$DefaultLocaleManifestPath") -replace ($LookForVariable[0] + ":"),("#"+$LookForVariable[0] + ":")) | Set-Content -Path "$DefaultLocaleManifestPath" -Encoding 'UTF8'
    }
}
((Get-Content -Path "$DefaultLocaleManifestPath") -replace "Short#Description","ShortDescription") | Set-Content -Path "$DefaultLocaleManifestPath" -Encoding 'UTF8' # Anyway to fix this?
}

Show-OptionMenu

Switch ($Option) {
    'New' {
        Read-WinGet-MandatoryInfo
        Read-WinGet-InstallerValues
        Read-WinGet-InstallerManifest
        New-Variable -Name "PackageLocale" -Value "en-US" -Scope "Script" -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest
        Write-WinGet-VersionManifest
        Write-WinGet-LocaleManifest
    }

    'Update' {
        Read-WinGet-MandatoryInfo
        Read-PreviousWinGet-Manifest
        Read-WinGet-InstallerValues
        Read-WinGet-InstallerManifest
        New-Variable -Name "PackageLocale" -Value "en-US" -Scope "Script" -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest
        Write-WinGet-VersionManifest
        Write-WinGet-LocaleManifest
    }

    'NewLocale' {
        Read-WinGet-MandatoryInfo
        Read-PreviousWinGet-Manifest
        Read-WinGet-LocaleManifest
        Write-WinGet-LocaleManifest
    }
}
