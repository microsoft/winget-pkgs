#Requires -Version 5
$PSVersion = (Get-Host).Version.Major
$ScriptHeader = '# Created with YamlCreate.ps1 v2.0.0'
$ManifestVersion = '1.0.0'
$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

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

<#
TO-DO:
    - Handle writing null parameters as comments
    - Ensure licensing for powershell-yaml is met
#>

if (-not(Get-Module -ListAvailable -Name powershell-yaml)) {
    try {
        Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
    } 
    catch {
        Throw "Unmet dependency. 'powershell-yaml' unable to be installed successfully."
    }
}

try {
    $ProgressPreference = 'SilentlyContinue'
    $LocaleSchema = @(Invoke-WebRequest 'https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v1.0.0/manifest.locale.1.0.0.json' -UseBasicParsing | ConvertFrom-Json)
    $LocaleProperties = (ConvertTo-Yaml $LocaleSchema.properties | ConvertFrom-Yaml -Ordered).Keys
    $VersionSchema = @(Invoke-WebRequest 'https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v1.0.0/manifest.version.1.0.0.json' -UseBasicParsing | ConvertFrom-Json)
    $VersionProperties = (ConvertTo-Yaml $VersionSchema.properties | ConvertFrom-Yaml -Ordered).Keys
    $InstallerSchema = @(Invoke-WebRequest 'https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v1.0.0/manifest.installer.1.0.0.json' -UseBasicParsing | ConvertFrom-Json)
    $InstallerProperties = (ConvertTo-Yaml $InstallerSchema.properties | ConvertFrom-Yaml -Ordered).Keys
    $InstallerSwitchProperties = (ConvertTo-Yaml $InstallerSchema.definitions.InstallerSwitches.properties | ConvertFrom-Yaml -Ordered).Keys
    $InstallerEntryProperties = (ConvertTo-Yaml $InstallerSchema.definitions.Installer.properties | ConvertFrom-Yaml -Ordered).Keys
    $InstallerDependencyProperties = (ConvertTo-Yaml $InstallerSchema.definitions.Dependencies.properties | ConvertFrom-Yaml -Ordered).Keys
}
catch {
    Write-Host 'Error downloading schemas. Please run the script again.' -ForegroundColor Red
    exit 1
}

filter TrimString {
    $_.Trim()
}

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

$Patterns = @{
    PackageIdentifier         = $VersionSchema.properties.PackageIdentifier.pattern
    IdentifierMaxLength       = $VersionSchema.properties.PackageIdentifier.maxLength
    PackageVersion            = $InstallerSchema.definitions.PackageVersion.pattern
    VersionMaxLength          = $VersionSchema.properties.PackageVersion.maxLength
    InstallerSha256           = $InstallerSchema.definitions.Installer.properties.InstallerSha256.pattern
    InstallerUrl              = $InstallerSchema.definitions.Installer.properties.InstallerUrl.pattern
    InstallerUrlMaxLength     = $InstallerSchema.definitions.Installer.properties.InstallerUrl.maxLength
    ValidArchitectures        = $InstallerSchema.definitions.Installer.properties.Architecture.enum
    ValidInstallerTypes       = $InstallerSchema.definitions.InstallerType.enum
    SilentSwitchMaxLength     = $InstallerSchema.definitions.InstallerSwitches.properties.Silent.maxLength
    ProgressSwitchMaxLength   = $InstallerSchema.definitions.InstallerSwitches.properties.SilentWithProgress.maxLength
    CustomSwitchMaxLength     = $InstallerSchema.definitions.InstallerSwitches.properties.Custom.maxLength
    SignatureSha256           = $InstallerSchema.definitions.Installer.properties.SignatureSha256.pattern
    FamilyName                = $InstallerSchema.definitions.PackageFamilyName.pattern
    FamilyNameMaxLength       = $InstallerSchema.definitions.PackageFamilyName.maxLength
    PackageLocale             = $LocaleSchema.properties.PackageLocale.pattern
    InstallerLocaleMaxLength  = $InstallerSchema.definitions.Locale.maxLength
    ProductCodeMinLength      = $InstallerSchema.definitions.ProductCode.minLength
    ProductCodeMaxLength      = $InstallerSchema.definitions.ProductCode.maxLength
    MaxItemsFileExtensions    = $InstallerSchema.definitions.FileExtensions.maxItems
    MaxItemsProtocols         = $InstallerSchema.definitions.Protocols.maxItems
    MaxItemsCommands          = $InstallerSchema.definitions.Commands.maxItems
    MaxItemsSuccessCodes      = $InstallerSchema.definitions.InstallerSuccessCodes.maxItems
    MaxItemsInstallModes      = $InstallerSchema.definitions.InstallModes.maxItems
    PackageLocaleMaxLength    = $LocaleSchema.properties.PackageLocale.maxLength
    PublisherMaxLength        = $LocaleSchema.properties.Publisher.maxLength
    PackageNameMaxLength      = $LocaleSchema.properties.PackageName.maxLength
    MonikerMaxLength          = $LocaleSchema.definitions.Tag.maxLength
    GenericUrl                = $LocaleSchema.definitions.Url.pattern
    GenericUrlMaxLength       = $LocaleSchema.definitions.Url.maxLength
    AuthorMinLength           = $LocaleSchema.properties.Author.minLength
    AuthorMaxLength           = $LocaleSchema.properties.Author.maxLength
    LicenseMaxLength          = $LocaleSchema.properties.License.maxLength
    CopyrightMinLength        = $LocaleSchema.properties.Copyright.minLength
    CopyrightMaxLength        = $LocaleSchema.properties.Copyright.maxLength
    TagsMaxItems              = $LocaleSchema.properties.Tags.maxItems
    ShortDescriptionMaxLength = $LocaleSchema.properties.ShortDescription.maxLength
    DescriptionMinLength      = $LocaleSchema.properties.Description.minLength
    DescriptionMaxLength      = $LocaleSchema.properties.Description.maxLength
    ValidInstallModes         = $InstallerSchema.definitions.InstallModes.items.enum
    FileExtension             = $InstallerSchema.definitions.FileExtensions.items.pattern
    FileExtensionMaxLength    = $InstallerSchema.definitions.FileExtensions.items.maxLength
}
Function String.IsValid {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $InputString,
        [Parameter(Mandatory = $false)]
        [regex] $MatchPattern,
        [Parameter(Mandatory = $false)]
        [int] $MinLength,
        [Parameter(Mandatory = $false)]
        [int] $MaxLength
    )

    $_isValid = $true
    
    if ($PSBoundParameters.ContainsKey('MinLength')) {
        $_isValid = $_isValid -and ($InputString.Length -ge $MinLength)
    } 
    if ($PSBoundParameters.ContainsKey('MaxLength')) {
        $_isValid = $_isValid -and ($InputString.Length -le $MaxLength)
    } 
    if ($PSBoundParameters.ContainsKey('MatchPattern')) {
        $_isValid = $_isValid -and ($InputString -match $MatchPattern)
    } 
    return $_isValid
}


Function Write-Colors {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]] $TextStrings,
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Colors
    )
    If ($TextStrings.Count -ne $Colors.Count) { Throw "Invalid Function Parameters. Arguments must be of equal length" }
    $_index = 0
    Foreach ($String in $TextStrings) {
        Write-Host -ForegroundColor $Colors[$_index] -NoNewline $String
        $_index++
    }
}

Function KeypressMenu {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Prompt,
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Entries,
        [Parameter(Mandatory = $false)]
        [string] $HelpText,
        [Parameter(Mandatory = $false)]
        [string] $HelpTextColor,
        [Parameter(Mandatory = $false)]
        [string] $DefaultString
    )

    Write-Host "`n"
    Write-Host -ForegroundColor 'Yellow' $Prompt
    if ($PSBoundParameters.ContainsKey('HelpText') -and (![string]::IsNullOrWhiteSpace($HelpText))) {
        if ($PSBoundParameters.ContainsKey('HelpTextColor') -and (![string]::IsNullOrWhiteSpace($HelpTextColor))) {
            Write-Host -ForegroundColor $HelpTextColor $HelpText 
        }
        else {
            Write-Host -ForegroundColor 'Blue' $HelpText
        }
    }
    foreach ($entry in $Entries) {
        $_isDefault = $entry.StartsWith('*')
        if ($_isDefault) {
            $_entry = "  " + $entry.Substring(1)
            $_color = 'Green'
        }
        else {
            $_entry = "  " + $entry
            $_color = 'White'
        }
        Write-Host -ForegroundColor $_color $_entry
    }
    Write-Host
    if ($PSBoundParameters.ContainsKey('DefaultString') -and (![string]::IsNullOrWhiteSpace($DefaultString))) {
        Write-Host -NoNewline "Enter Choice (default is '$DefaultString'): "
    }
    else {
        Write-Host -NoNewline "Enter Choice ("
        Write-Host -NoNewline -ForegroundColor 'Green' "Green"
        Write-Host -NoNewline " is default): "
    }

    do {
        $keyInfo = [Console]::ReadKey($false)
    } until ($keyInfo.Key)

    return $keyInfo.Key
}

Function TestUrlValidity {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $URL
    )
    try {
        $HTTP_Request = [System.Net.WebRequest]::Create($URL)
        $HTTP_Response = $HTTP_Request.GetResponse()
        $HTTP_Status = [int]$HTTP_Response.StatusCode
    }
    catch {}
    if (-not($null -eq $HTTP_Response)) { $HTTP_Response.Close() } 
    
    return $HTTP_Status
}
Function Show-OptionMenu {
    Clear-Host
    Write-Host -ForegroundColor 'Cyan' "Select Mode"
    Write-Colors "`n[", "1", "] New Manifest or Package Version`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", "2", "] Update Package Metadata`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", "3", "] New Locale`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", "q", "]", " Any key to quit`n" 'DarkCyan', 'White', 'DarkCyan', 'Red'
    Write-Colors "`nSelection: " 'White'

    $Keys = @{
        [ConsoleKey]::D1      = '1';
        [ConsoleKey]::D2      = '2';
        [ConsoleKey]::D3      = '3';
        [ConsoleKey]::NumPad1 = '1';
        [ConsoleKey]::NumPad2 = '2';
        [ConsoleKey]::NumPad3 = '3';
    }

    do {
        $keyInfo = [Console]::ReadKey($false)
    } until ($keyInfo.Key)

    switch ($Keys[$keyInfo.Key]) {
        '1' { $script:Option = 'New' }
        '2' { $script:Option = 'EditMetadata' }
        '3' { $script:Option = 'NewLocale' }
        default { Write-Host; exit }
    }
}

Function Read-WinGet-MandatoryInfo {
    while (!(String.IsValid $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength -MatchPattern $Patterns.PackageIdentifier)) {
        Write-Host "`n"
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
        $script:PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
        $PackageIdentifierFolder = $PackageIdentifier.Replace('.', '\')
    }
    
    while (!(String.IsValid $PackageVersion -MinLength 1 -MaxLength $Patterns.VersionMaxLength -MatchPattern $Patterns.PackageVersion)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
        $script:PackageVersion = Read-Host -Prompt 'Version' | TrimString
    }
    
    if (Test-Path -Path "$PSScriptRoot\..\manifests") {
        $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
    }
    else {
        $ManifestsFolder = (Resolve-Path ".\").Path
    }
    
    $script:AppFolder = Join-Path $ManifestsFolder -ChildPath $PackageIdentifier.ToLower().Chars(0) | Join-Path -ChildPath $PackageIdentifierFolder | Join-Path -ChildPath $PackageVersion
}

Function Read-WinGet-InstallerValues {
    $InstallerValues = @(
        "Architecture"
        "InstallerType"
        "InstallerUrl"
        "InstallerSha256"
        "SignatureSha256"
        "PackageFamilyName"
        "Custom"
        "Silent"
        "SilentWithProgress"
        "ProductCode"
        "Scope"
        "InstallerLocale"
        "UpgradeBehavior"
        "AnotherInstaller"
    )
    Foreach ($InstallerValue in $InstallerValues) { Clear-Variable -Name $InstallerValue -Force -ErrorAction SilentlyContinue }

    while (!(String.IsValid $InstallerUrl -MinLength 1 -MaxLength $Patterns.InstallerUrlMaxLength -MatchPattern $Patterns.InstallerUrl)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the download url to the installer.'
        $InstallerUrl = Read-Host -Prompt 'Url' | TrimString
    }

    $_menu = @{
        entries = @("[Y] Yes"; "*[N] No"; "[M] Manually Enter SHA256")
        Prompt  = "Do you want to save the files to the Temp folder?"
        DefaultString = "N"
    }

    switch (KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
        'Y' { $script:SaveOption = '0' }
        'N' { $script:SaveOption = '1' }
        'M' { $script:SaveOption = '2' }
        default { $script:SaveOption = '1' }
    }

    if ($script:SaveOption -ne '2') {
        Write-Host
        $start_time = Get-Date
        Write-Host $NewLine
        Write-Host 'Downloading URL. This will take a while...' -ForegroundColor Blue
        $WebClient = New-Object System.Net.WebClient
        $Filename = [System.IO.Path]::GetFileName($InstallerUrl)
        $script:dest = "$env:TEMP\$FileName"

        try {
            $WebClient.DownloadFile($InstallerUrl, $script:dest)
        } catch {
            Write-Host 'Error downloading file. Please run the script again.' -ForegroundColor Red
            exit 1
        } finally {
            Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" -ForegroundColor Green
            $InstallerSha256 = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
            $FileInformation = Get-AppLockerFileInformation -Path $script:dest | Select-Object Publisher | Select-String -Pattern "{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}"
            $MSIProductCode = $FileInformation.Matches
            if ($script:SaveOption -eq '1' -and -not($script:dest.EndsWith('appx', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('msix', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('appxbundle', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('msixbundle', 'CurrentCultureIgnoreCase'))) { Remove-Item -Path $script:dest }
        }
    } else {
        while ($InstallerSha256 -notmatch $Patterns.InstallerSha256) {
            Write-Host
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the installer SHA256 Hash'
            $InstallerSha256 = Read-Host -Prompt 'InstallerSha256' | TrimString
            $InstallerSHA256 = $InstallerSha256.toUpper()
        }
    }

    while ($architecture -notin @($Patterns.ValidArchitectures)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the architecture. Options:' , @($Patterns.ValidArchitectures -join ', ')
        $architecture = Read-Host -Prompt 'Architecture' | TrimString
    }

    while ($InstallerType -notin @($Patterns.ValidInstallerTypes)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the InstallerType. Options:' , @($Patterns.ValidInstallerTypes -join ', ' )
        $InstallerType = Read-Host -Prompt 'InstallerType' | TrimString
    }

    if ($InstallerType -ieq 'exe') {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent install switch. For example: /S, -verysilent, /qn, --silent, /exenoui'
            $Silent = Read-Host -Prompt 'Silent switch' | TrimString
        } while (!(String.IsValid $Silent -MinLength 1 -MaxLength $Patterns.SilentSwitchMaxLength))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent with progress install switch. For example: /S, -silent, /qb, /exebasicui'
            $SilentWithProgress = Read-Host -Prompt 'Silent with progress switch' | TrimString
        } while (!(String.IsValid $SilentWithProgress -MinLength 1 -MaxLength $Patterns.ProgressSwitchMaxLength))

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: /norestart, -norestart'
            $Custom = Read-Host -Prompt 'Custom Switch' | TrimString
        } while ($Custom.Length -gt $Patterns.CustomSwitchMaxLength)
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent install switch. For example: /S, /s, /VERYSILENT, /qn, --silent'
            $Silent = Read-Host -Prompt 'Silent' | TrimString 
        } while ($Silent.Length -gt $Patterns.SilentSwitchMaxLength)

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent with progress install switch. For example: /S, /SILENT, /qb'
            $SilentWithProgress = Read-Host -Prompt 'SilentWithProgress' | TrimString
        } while ($SilentWithProgress.Length -gt $Patterns.ProgressSwitchMaxLength)

        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: /NORESTART, -norestart, /CURRENTUSER, /ALLUSERS'
            $Custom = Read-Host -Prompt 'CustomSwitch' | TrimString
        } while ($Custom.Length -gt $Patterns.CustomSwitchMaxLength)
    }

    if ($InstallerType -ieq 'msix' -or $InstallerType -ieq 'appx') {
        if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { $SignatureSha256 = winget hash -m $script:dest | Select-String -Pattern "SignatureSha256:" | ConvertFrom-String; if ($SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() } }
        if ([string]::IsNullOrWhiteSpace($SignatureSha256)) {
            do {
                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the installer SignatureSha256'
                $SignatureSha256 = Read-Host -Prompt 'SignatureSha256' | TrimString
            } while (-not [string]::IsNullOrWhiteSpace($SignatureSha256) -and ($SignatureSha256 -notmatch $Patterns.SignatureSha256))
        }
        
        do {
            $_menu = @{
                entries       = @("*[F] Find Automatically [Note: This will install the package to find Family Name and then removes it.]"; "[M] Manually Enter PackageFamilyName")
                Prompt        = "[Recommended] Enter the installer PackageFamilyName"
                DefaultString = "M"
            }
        
            switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
                'F' { $ChoicePfn = '0' }
                'M' { $ChoicePfn = '1' }
                default { $ChoicePfn = '0' }
            }

            if ($ChoicePfn -eq '0') {
                Add-AppxPackage -Path $script:dest
                $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName, PackageFullName
                $PackageFamilyName = $InstalledPkg.PackageFamilyName
                Remove-AppxPackage $InstalledPkg.PackageFullName
                if ([string]::IsNullOrWhiteSpace($PackageFamilyName)) {
                    Write-Host -ForegroundColor 'Red' "Error finding PackageFamilyName. Please enter manually."
                    $PackageFamilyName = Read-Host -Prompt 'PackageFamilyName' | TrimString
                }
            } else {
                Write-Host
                $PackageFamilyName = Read-Host -Prompt 'PackageFamilyName' | TrimString
            }
        } while (-not [string]::IsNullOrWhiteSpace($PackageFamilyName) -and (!(String.IsValid $PackageFamilyName -MaxLength $Patterns.FamilyNameMaxLength -MatchPattern $Patterns.FamilyName)))        
        if ($script:SaveOption -eq '1') { Remove-Item -Path $script:dest }
    }

    do {
        Write-Host
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the installer locale. For example: en-US, en-CA'
        Write-Host -ForegroundColor 'Blue' -Object 'https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $InstallerLocale = Read-Host -Prompt 'InstallerLocale' | TrimString
    } while (-not [string]::IsNullOrWhiteSpace($InstallerLocale) -and (!(String.IsValid $InstallerLocale -MaxLength $Patterns.InstallerLocaleMaxLength -MatchPattern $Patterns.PackageLocale)))
    if ([string]::IsNullOrWhiteSpace($InstallerLocale)) { $InstallerLocale = 'en-US' }

    do {
        Write-Host
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
        Write-Host -ForegroundColor 'White' -Object "ProductCode found from installer: $MSIProductCode"
        Write-Host -ForegroundColor 'White' -Object 'Can be found with ' -NoNewline; Write-Host -ForegroundColor 'DarkYellow' 'get-wmiobject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name -AutoSize'
        $ProductCode = Read-Host -Prompt 'ProductCode' | TrimString
    } while (-not [string]::IsNullOrWhiteSpace($ProductCode) -and (!(String.IsValid $ProductCode -MinLength $Patterns.ProductCodeMinLength -MaxLength $Patterns.ProductCodeMaxLength)))

    $_menu = @{
        entries       = @("[M] Machine"; "[U] User"; '*[N] No idea')
        Prompt        = "[Optional] Enter the Installer Scope"
        DefaultString = "N"
    }

    switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
        'M' { $Scope = 'machine' }
        'U' { $Scope = 'user' }
        'N' { $Scope = '' }
        default { $Scope = '' }
    }

    $_menu = @{
        entries       = @("*[I] install"; "[U] uninstallPrevious")
        Prompt        = "[Optional] Enter the Upgrade Behavior"
        DefaultString = "I"
    }

    switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
        'I' { $UpgradeBehavior = 'install' }
        'U' { $UpgradeBehavior = 'uninstallPrevious' }
        default { $UpgradeBehavior = 'install' }
    }
    
    if (!$script:Installers) { $script:Installers = @() }

    $_Installer = [ordered] @{}

    $_InstallerSingletons = [ordered] @{
        "InstallerLocale"   = $InstallerLocale
        "Architecture"      = $Architecture
        "InstallerType"     = $InstallerType
        "Scope"             = $Scope
        "InstallerUrl"      = $InstallerUrl
        "InstallerSha256"   = $InstallerSha256
        "SignatureSha256"   = $SignatureSha256
        "PackageFamilyName" = $PackageFamilyName
    }

    foreach ($_Item in $_InstallerSingletons.GetEnumerator()) {
        If ($_Item.Value) { AddYamlParameter $_Installer $_Item.Name $_Item.Value }
    }

    if ($Silent -or $SilentWithProgress -or $Custom) {
        $_InstallerSwitches = [ordered]@{}
        $_Switches = [ordered] @{
            "Custom"             = $Custom
            "Silent"             = $Silent
            "SilentWithProgress" = $SilentWithProgress
        }
        
        foreach ($_Item in $_Switches.GetEnumerator()) {
            If ($_Item.Value) { AddYamlParameter $_InstallerSwitches $_Item.Name $_Item.Value }
        }
        $_InstallerSwitches = SortYamlKeys $_InstallerSwitches $InstallerSwitchProperties
        $_Installer["InstallerSwitches"] = $_InstallerSwitches
    }

    if ($ProductCode) { AddYamlParameter $_Installer "ProductCode" $ProductCode }
    AddYamlParameter $_Installer "UpgradeBehavior" $UpgradeBehavior
    $_Installer = SortYamlKeys $_Installer $InstallerEntryProperties

    $script:Installers += $_Installer

    $_menu = @{
        entries = @(
            "[Y] Yes"
            "*[N] No"
        )
        Prompt = "Do you want to create another installer?"
        DefaultString = "N"
    }

    switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
        'Y' { $AnotherInstaller = '0' }
        'N' { $AnotherInstaller = '1' }
        default { $AnotherInstaller = '1' }
    }

    if ($AnotherInstaller -eq '0') { Write-Host; Read-WinGet-InstallerValues }
}

Function PromptInstallerManifestValue {
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $Variable,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Key,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $Prompt
    )

    Write-Host
    Write-Host -ForegroundColor 'Yellow' -Object $Prompt
    if (![string]::IsNullOrWhiteSpace($Variable)) { Write-Host -ForegroundColor 'DarkGray' "Old Value: $Variable" }
    $NewValue = Read-Host -Prompt $Key | TrimString

    if (-not [string]::IsNullOrWhiteSpace($NewValue)) {
        return $NewValue
    }
    else {
        return $Variable
    }
}

Function SortYamlKeys {
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

Function Read-WinGet-InstallerManifest {
    Write-Host
    do {
        if (!$FileExtensions) { $FileExtensions = '' }
        $script:FileExtensions = PromptInstallerManifestValue $FileExtensions 'FileExtensions' "[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max $($Patterns.MaxItemsFileExtensions))"
    } while (($script:FileExtensions -split ",").Count -gt $Patterns.MaxItemsFileExtensions -or !([string]::IsNullOrEmpty($($script:FileExtensions -split "," | TrimString | Where-Object { -not (String.IsValid $_ -MaxLength $Patterns.FileExtensionMaxLength -MatchPattern $Patterns.FileExtension) }))))

    do {
        if (!$Protocols) { $Protocols = '' }
        $script:Protocols = PromptInstallerManifestValue $Protocols 'Protocols' "[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max $($Patterns.MaxItemsProtocols))"
    } while (($script:Protocols -split ",").Count -gt $Patterns.MaxItemsProtocols)

    do {
        if (!$Commands) { $Commands = '' }
        $script:Commands = PromptInstallerManifestValue $Commands 'Commands' "[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max $($Patterns.MaxItemsCommands))"
    } while (($script:Commands -split ",").Count -gt $Patterns.MaxItemsCommands)

    do {
        if (!$InstallerSuccessCodes) { $InstallerSuccessCodes = '' }
        $script:InstallerSuccessCodes = PromptInstallerManifestValue $InstallerSuccessCodes 'InstallerSuccessCodes' "[Optional] List of additional non-zero installer success exit codes other than known default values by winget (Max $($Patterns.MaxItemsSuccessCodes))"
    } while (($script:InstallerSuccessCodes -split ",").Count -gt $Patterns.MaxItemsSuccessCodes)

    do {
        if (!$InstallModes) { $InstallModes = '' }
        $script:InstallModes = PromptInstallerManifestValue $InstallModes 'InstallModes' "[Optional] List of supported installer modes. Options: $($Patterns.ValidInstallModes -join ", ")"
    } while (($script:InstallModes -split ",").Count -gt $Patterns.MaxItemsInstallModes -or !([string]::IsNullOrEmpty($($script:InstallModes -split "," | TrimString | Where-Object { $_ -notin $Patterns.ValidInstallModes } | Select-Object -First 1))))
}

Function Read-WinGet-LocaleManifest {
    while (!(String.IsValid $script:PackageLocale -MatchPattern $Patterns.PackageLocale -MaxLength $Patterns.PackageLocaleMaxLength -MinLength 1)) {
        Write-Host
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Locale. For example: en-US, en-CA https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $script:PackageLocale = Read-Host -Prompt 'PackageLocale' | TrimString
    }
    
    if ([string]::IsNullOrWhiteSpace($script:Publisher)) {
        while (!(String.IsValid $script:Publisher -MinLength 1 -MaxLength $Patterns.PublisherMaxLength)) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation'
            $script:Publisher = Read-Host -Prompt 'Publisher' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full publisher name. For example: Microsoft Corporation'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Publisher"
            $NewPublisher = Read-Host -Prompt 'Publisher' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPublisher)) {
                $script:Publisher = $NewPublisher
            }
        } while ($script:Publisher.Length -gt $Patterns.PublisherMaxLength)
    }

    if ([string]::IsNullOrWhiteSpace($script:PackageName)) {
        while (!(String.IsValid $script:PackageName -MinLength 1 -MaxLength $Patterns.PackageNameMaxLength)) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
            $script:PackageName = Read-Host -Prompt 'PackageName' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full application name. For example: Microsoft Teams'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageName"
            $NewPackageName = Read-Host -Prompt 'PackageName' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPackageName)) {
                $script:PackageName = $NewPackageName
            }
        } while ($script:PackageName.Length -gt $Patterns.PackageNameMaxLength)
    }

    if ($Option -ne 'NewLocale') {
        if ([string]::IsNullOrWhiteSpace($script:Moniker)) {
            do {
                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
                $script:Moniker = Read-Host -Prompt 'Moniker' | TrimString
            } while ($script:Moniker.Length -gt $Patterns.MonikerMaxLength)
        } else {
            do {
                Write-Host
                Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
                Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Moniker"
                $NewMoniker = Read-Host -Prompt 'Moniker' | TrimString
        
                if (-not [string]::IsNullOrWhiteSpace($NewMoniker)) {
                    $script:Moniker = $NewMoniker
                }
            } while ($script:Moniker.Length -gt $Patterns.MonikerMaxLength)
        }
    }

    if ([string]::IsNullOrWhiteSpace($script:PublisherUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
            $script:PublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:PublisherUrl) -and (!(String.IsValid $script:PublisherUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherUrl"
            $NewPublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewNewPublisherUrl)) {
                $script:PublisherUrl = $NewPublisherUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:PublisherUrl) -and (!(String.IsValid $script:PublisherUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength )))
    }

    if ([string]::IsNullOrWhiteSpace($script:PublisherSupportUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
            $script:PublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:PublisherSupportUrl) -and (!(String.IsValid $script:PublisherSupportUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherSupportUrl"
            $NewPublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPublisherSupportUrl)) {
                $script:PublisherSupportUrl = $NewPublisherSupportUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:PublisherSupportUrl) -and (!(String.IsValid $script:PublisherSupportUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:PrivacyUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
            $script:PrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:PrivacyUrl) -and (!(String.IsValid $script:PrivacyUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PrivacyUrl"
            $NewPrivacyUrl = Read-Host -Prompt 'Privacy Url' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPrivacyUrl)) {
                $script:PrivacyUrl = $NewPrivacyUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:PrivacyUrl) -and (!(String.IsValid $script:PrivacyUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:Author)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
            $script:Author = Read-Host -Prompt 'Author' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:Author) -and (!(String.IsValid $script:Author -MinLength $Patterns.AuthorMinLength -MaxLength $Patterns.AuthorMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Author"
            $NewAuthor = Read-Host -Prompt 'Author' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewAuthor)) {
                $script:Author = $NewAuthor
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:Author) -and (!(String.IsValid $script:Author -MinLength $Patterns.AuthorMinLength -MaxLength $Patterns.AuthorMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:PackageUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            $script:PackageUrl = Read-Host -Prompt 'Homepage' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:PackageUrl) -and (!(String.IsValid $script:PackageUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageUrl"
            $NewPackageUrl = Read-Host -Prompt 'Homepage' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewPackageUrl)) {
                $script:PackageUrl = $NewPackageUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:PackageUrl) -and (!(String.IsValid $script:PackageUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:License)) {
        while (!(String.IsValid $script:License -MinLength 1 -MaxLength $Patterns.LicenseMaxLength)) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
            $script:License = Read-Host -Prompt 'License' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:License"
            $NewLicense = Read-Host -Prompt 'License' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewLicense)) {
                $script:License = $NewLicense
            }
        } while (!(String.IsValid $script:License -MinLength $Patterns.LicenseMinLength -MaxLength $Patterns.LicenseMaxLength))
    }

    if ([string]::IsNullOrWhiteSpace($script:LicenseUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            $script:LicenseUrl = Read-Host -Prompt 'License URL' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:LicenseUrl) -and (!(String.IsValid $script:LicenseUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:LicenseUrl"
            $NewLicenseUrl = Read-Host -Prompt 'License URL' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewLicenseUrl)) {
                $script:LicenseUrl = $NewLicenseUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:LicenseUrl) -and (!(String.IsValid $script:LicenseUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:Copyright)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright. For example: Copyright (c) Microsoft Corporation'
            $script:Copyright = Read-Host -Prompt 'Copyright' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:Copyright) -and (!(String.IsValid $script:Copyright -MinLength $Patterns.CopyrightMinLength -MaxLength $Patterns.CopyrightMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright. For example: Copyright (c) Microsoft Corporation'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Copyright"
            $NewCopyright = Read-Host -Prompt 'Copyright' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewCopyright)) {
                $script:Copyright = $NewCopyright
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:Copyright) -and (!(String.IsValid $script:Copyright -MinLength $Patterns.CopyrightMinLength -MaxLength $Patterns.CopyrightMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:CopyrightUrl)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
            $script:CopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:CopyrightUrl) -and (!(String.IsValid $script:CopyrightUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:CopyrightUrl"
            $NewCopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewCopyrightUrl)) {
                $script:CopyrightUrl = $NewCopyrightUrl
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:CopyrightUrl) -and (!(String.IsValid $script:CopyrightUrl -MatchPattern $Patterns.GenericUrl -MaxLength $Patterns.GenericUrlMaxLength)))
    }

    if ([string]::IsNullOrWhiteSpace($script:Tags)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max', ($Patterns.TagsMaxItems), 'items)'
            $script:Tags = Read-Host -Prompt 'Tags' | TrimString
        } while (($script:Tags -split ",").Count -gt $Patterns.TagsMaxItems)
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool. For example: zip, c++ (Max', ($Patterns.TagsMaxItems), 'items)'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $($script:Tags -join ", ")"
            $NewTags = Read-Host -Prompt 'Tags' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewTags)) {
                $script:Tags = $NewTags
            }
        } while (($script:Tags -split ",").Count -gt $Patterns.TagsMaxItems)
    }

    if ([string]::IsNullOrWhiteSpace($script:ShortDescription)) {
        while (!(String.IsValid $script:ShortDescription -MinLength 1 -MaxLength $Patterns.ShortDescriptionMaxLength)) {
            Write-Host
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
            $script:ShortDescription = Read-Host -Prompt 'Short Description' | TrimString
        }
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a short description of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:ShortDescription"
            $NewShortDescription = Read-Host -Prompt 'Short Description' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewShortDescription)) {
                $script:ShortDescription = $NewShortDescription
            }
        } while (!(String.IsValid $script:ShortDescription -MinLength 1 -MaxLength $Patterns.ShortDescriptionMaxLength))
    }

    if ([string]::IsNullOrWhiteSpace($script:Description)) {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            $script:Description = Read-Host -Prompt 'Long Description' | TrimString
        } while (-not [string]::IsNullOrWhiteSpace($script:Description) -and (!(String.IsValid $script:Description -MinLength $Patterns.DescriptionMinLength -MaxLength $Patterns.DescriptionMaxLength)))
    } else {
        do {
            Write-Host
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Description"
            $NewDescription = Read-Host -Prompt 'Description' | TrimString
    
            if (-not [string]::IsNullOrWhiteSpace($NewDescription)) {
                $script:Description = $NewDescription
            }
        } while (-not [string]::IsNullOrWhiteSpace($script:Description) -and (!(String.IsValid $script:Description -MinLength $Patterns.DescriptionMinLength -MaxLength $Patterns.DescriptionMaxLength)))
    }
}

Function Test-Manifest {
    if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { winget validate $AppFolder }

    if (Get-Command 'WindowsSandbox.exe' -ErrorAction SilentlyContinue) {

        $_menu = @{
            entries       = @("*[Y] Yes"; "[N] No")
            Prompt        = "[Recommended] Do you want to test your Manifest in Windows Sandbox?"
            DefaultString = "Y"
        }
        
        switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
            'Y' { $script:SandboxTest = '0' }
            'N' { $script:SandboxTest = '1' }
            default { $script:SandboxTest = '0' }
        }

        Write-Host
        if ($script:SandboxTest -eq '0') {
            if (Test-Path -Path "$PSScriptRoot\SandboxTest.ps1") {
                $SandboxScriptPath = (Resolve-Path "$PSScriptRoot\SandboxTest.ps1").Path
            } else {
                while ([string]::IsNullOrWhiteSpace($SandboxScriptPath)) {
                    Write-Host
                    Write-Host -ForegroundColor 'Green' -Object 'SandboxTest.ps1 not found, input path'
                    $SandboxScriptPath = Read-Host -Prompt 'SandboxTest.ps1' | TrimString
                }
            }

            & $SandboxScriptPath -Manifest $AppFolder
        }
    }
}

Function Enter-PR-Parameters {
    $PrBodyContent = Get-Content $args[0]
    ForEach ($_line in ($PrBodyContent | Where-Object { $_ -like '-*[ ]*' })) {
        $_showMenu = $true
        switch -Wildcard ( $_line ) {
            '*CLA*' {
                $_menu = @{
                    Prompt        = "Have you signed the Contributor License Agreement (CLA)?"
                    Entries       = @("[Y] Yes"; "*[N] No")
                    HelpText      = "Reference Link: https://cla.opensource.microsoft.com/microsoft/winget-pkgs"
                    HelpTextColor = ""
                    DefaultString = "N"
                }
            }
    
            '*open `[pull requests`]*' {
                $_menu = @{
                    Prompt        = "Have you checked that there aren't other open pull requests for the same manifest update/change?"
                    Entries       = @("[Y] Yes"; "*[N] No")
                    HelpText      = "Reference Link: https://github.com/microsoft/winget-pkgs/pulls"
                    HelpTextColor = ""
                    DefaultString = "N"
                }
            }
    
            '*winget validate*' {
                if ($?) {
                    $PrBodyContentReply += @($_line.Replace("[ ]", "[X]"))
                    $_showMenu = $false
                } else {
                    $_menu = @{
                        Prompt        = "Have you validated your manifest locally with 'winget validate --manifest <path>'?"
                        Entries       = @("[Y] Yes"; "*[N] No")
                        HelpText      = "Automatic manifest validation failed. Check your manifest and try again"
                        HelpTextColor = "Red"
                        DefaultString = "N"
                    }
                }
            }
    
            '*tested your manifest*' {
                if ($script:SandboxTest -eq '0') {
                    $PrBodyContentReply += @($_line.Replace("[ ]", "[X]"))
                    $_showMenu = $false
                } else {
                    $_menu = @{
                        Prompt        = "Have you tested your manifest locally with 'winget install --manifest <path>'?"
                        Entries       = @("[Y] Yes"; "*[N] No")
                        HelpText      = "You did not test your Manifest in Windows Sandbox previously."
                        HelpTextColor = "Red"
                        DefaultString = "N"
                    }
                }
            }
    
            '*schema*' {
                $_menu = @{
                    Prompt        = "Does your manifest conform to the 1.0 schema?"
                    Entries       = @("[Y] Yes"; "*[N] No")
                    HelpText      = "Reference Link: https://github.com/microsoft/winget-cli/blob/master/doc/ManifestSpecv1.0.md"
                    HelpTextColor = ""
                    DefaultString = "N"
                }
            }
    
            Default {
                $_menu = @{
                    Prompt        = $_line.TrimStart("- [ ]")
                    Entries       = @("[Y] Yes"; "*[N] No")
                    HelpText      = ""
                    HelpTextColor = ""
                    DefaultString = "N"
                }
            }
        }

        if ($_showMenu) {
            switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"] -HelpText $_menu["HelpText"] -HelpTextColor $_menu["HelpTextColor"]) {
                'Y' { $PrBodyContentReply += @($_line.Replace("[ ]", "[X]")) }
                default { $PrBodyContentReply += @($_line) }
            }
        }
    }

    $_menu = @{
        entries       = @("[Y] Yes"; "*[N] No")
        Prompt        = "Does this pull request resolve any issues?"
        DefaultString = "N"
    }
    
    switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
        'Y' {
            Write-Host
            Write-Host "Enter issue number. For example`: 21983, 43509"
            $ResolvedIssues = Read-Host -Prompt 'Resolved Issues'
            $PrBodyContentReply += @("")
            Foreach ($i in ($ResolvedIssues.Split(",").Trim())) {
                if ($i.Contains("#")) {
                    $_UrlParameters = $i.Split("#")
                    switch ($_UrlParameters.Count) {
                        2 {
                            if ([string]::IsNullOrWhiteSpace($_urlParameters[0])) {
                                $_checkedURL = "https://github.com/microsoft/winget-pkgs/issues/$($_urlParameters[1])" 
                            } else {
                                $_checkedURL = "https://github.com/$($_urlParameters[0])/issues/$($_urlParameters[1])" 
                            }
                        }
                        default {
                            Write-Host -ForegroundColor "Red" "Invalid Issue: $i"
                            continue
                        }
                    }

                    $_responseCode = TestUrlValidity $_checkedURL
                    if ($_responseCode -ne 200) {
                        Write-Host -ForegroundColor "Red" "Invalid Issue: $i"
                        continue
                    }

                    $PrBodyContentReply += @("Resolves $i")
                } else {
                    $_checkedURL = "https://github.com/microsoft/winget-pkgs/issues/$i"
                    $_responseCode = TestUrlValidity $_checkedURL
                    if ($_responseCode -ne 200) {
                        Write-Host -ForegroundColor "Red" "Invalid Issue: $i"
                        continue
                    }
                    $PrBodyContentReply += @("Resolves #$i")
                }
            }
        }
        default { Write-Host }
    }

    Set-Content -Path PrBodyFile -Value $PrBodyContentReply | Out-Null
    gh pr create --body-file PrBodyFile -f
    Remove-Item PrBodyFile  
}
Function Submit-Manifest {
    if (Get-Command 'git.exe' -ErrorAction SilentlyContinue) {
        $_menu = @{
            entries       = @("*[Y] Yes"; "[N] No")
            Prompt        = "Do you want to submit your PR now?"
            DefaultString = "Y"
        }
        
        switch ( KeypressMenu -Prompt $_menu["Prompt"] -Entries $_menu["Entries"] -DefaultString $_menu["DefaultString"]) {
            'Y' { $PromptSubmit = '0' }
            'N' { $PromptSubmit = '1' }
            default { $PromptSubmit = '0' }
        }
    }

    Write-Host
    if ($PromptSubmit -eq '0') {
        switch ($Option) {
            'New' {
                if ( $script:OldManifestType -eq 'None' ) { $CommitType = 'New package' }
                elseif ($script:LastVersion -lt $script:PackageVersion ) { $CommitType = 'New version' }
                elseif ($script:PackageVersion -in $script:ExistingVersions) { $CommitType = 'Update' }
                elseif ($script:LastVersion -gt $script:PackageVersion ) { $CommitType = 'Add version' }
            }
            'EditMetadata' { $CommitType = 'Metadata' }
            'NewLocale' { $CommitType = 'Locale' }
        }

        $_previousConfig = git config --global --get core.safecrlf
        
        if ($_previousConfig) {
            git config --global --replace core.safecrlf false
        } else {
            git config --global --add core.safecrlf false
        }

        git fetch upstream master --quiet
        git switch -d upstream/master       
        if ($LASTEXITCODE -eq '0') {
            git add -A
            git commit -m "$CommitType`: $PackageIdentifier version $PackageVersion" --quiet

            git switch -c "$PackageIdentifier-$PackageVersion" --quiet
            git push --set-upstream origin "$PackageIdentifier-$PackageVersion" --quiet

            if (Get-Command 'gh.exe' -ErrorAction SilentlyContinue) {
            
                if (Test-Path -Path "$PSScriptRoot\..\.github\PULL_REQUEST_TEMPLATE.md") {
                    Enter-PR-Parameters "$PSScriptRoot\..\.github\PULL_REQUEST_TEMPLATE.md"
                } else {
                    while ([string]::IsNullOrWhiteSpace($SandboxScriptPath)) {
                        Write-Host
                        Write-Host -ForegroundColor 'Green' -Object 'PULL_REQUEST_TEMPLATE.md not found, input path'
                        $PRTemplate = Read-Host -Prompt 'PR Template' | TrimString
                    }
                    Enter-PR-Parameters "$PRTemplate"
                }
            }
        }
        if ($_previousConfig) {
            git config --global --replace core.safecrlf $_previousConfig
        } else {
            git config --global --unset core.safecrlf
        }
    } else {
        Write-Host
        Exit
    }
}

Function AddYamlListParameter {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $Object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter,
        [Parameter(Mandatory = $true, Position = 2)]
        $Values
    )
    $_Values = @()
    Foreach ($Value in $Values.Split(",").Trim()) {
        if ($Parameter -eq 'InstallerSuccessCodes') {
            try {
                $Value = [int]$Value
            }
            catch {}
        }
        $_Values += $Value
    }
    $Object[$Parameter] = $_Values
}

Function AddYamlParameter {
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $Object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $Value
    )
    $Object[$Parameter] = $Value
}

Function GetMultiManifestParameter {
    Param (
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter
    )
    $_vals = $($script:OldInstallerManifest[$Parameter] + $script:OldLocaleManifest[$Parameter] + $script:OldVersionManifest[$Parameter] | Where-Object { $_ })
    return ($_vals -join ", ")
}
Function Write-WinGet-VersionManifest-Yaml {
    [PSCustomObject]$VersionManifest = [ordered]@{}

    $_Singletons = [ordered]@{
        "PackageIdentifier" = $PackageIdentifier
        "PackageVersion"    = $PackageVersion
        "DefaultLocale"     = "en-US"
        "ManifestType"      = "version"
        "ManifestVersion"   = $ManifestVersion
    }

    foreach ($_Item in $_Singletons.GetEnumerator()) {
        if ($_Item.Value) { AddYamlParameter $VersionManifest $_Item.Name $_Item.Value }
    }
    $VersionManifest = SortYamlKeys $VersionManifest $VersionProperties
    
    New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null
    $VersionManifestPath = $AppFolder + "\$PackageIdentifier" + '.yaml'
    
    #TO-DO: Write keys with no values as comments
    
    $ScriptHeader + " using YAML parsing`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.1.0.0.schema.json`n" > $VersionManifestPath
    ConvertTo-Yaml $VersionManifest >> $VersionManifestPath
    $MyRawString = Get-Content -Raw $VersionManifestPath | TrimString
    [System.IO.File]::WriteAllLines($VersionManifestPath, $MyRawString, $Utf8NoBomEncoding)
    
    Write-Host 
    Write-Host "Yaml file created: $VersionManifestPath"
}
Function Write-WinGet-InstallerManifest-Yaml {

    if ($script:OldManifestType -eq 'MultiManifest') { $InstallerManifest = $script:OldInstallerManifest }

    if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

    AddYamlParameter $InstallerManifest "PackageIdentifier" $PackageIdentifier
    AddYamlParameter $InstallerManifest "PackageVersion" $PackageVersion
    $InstallerManifest["MinimumOSVersion"] = If ($MinimumOSVersion) { $MinimumOSVersion } Else { "10.0.0.0" }

    $_ListSections = [ordered]@{
        "FileExtensions"        = $FileExtensions
        "Protocols"             = $Protocols
        "Commands"              = $Commands
        "InstallerSuccessCodes" = $InstallerSuccessCodes
        "InstallModes"          = $InstallModes
    }
    foreach ($Section in $_ListSections.GetEnumerator()) {
        If ($Section.Value) { AddYamlListParameter $InstallerManifest $Section.Name $Section.Value }
    }

    if ($Option -ne 'EditMetadata') { $InstallerManifest["Installers"] = $script:Installers }
    elseif ($script:OldInstallerManifest) { $InstallerManifest["Installers"] = $script:OldInstallerManifest["Installers"] }
    else { $InstallerManifest["Installers"] = $script:OldVersionManifest["Installers"] }

    AddYamlParameter $InstallerManifest "ManifestType" "installer"
    AddYamlParameter $InstallerManifest "ManifestVersion" $ManifestVersion
    if ($InstallerManifest["Dependencies"]) { $InstallerManifest["Dependencies"] = SortYamlKeys $InstallerManifest["Dependencies"] $InstallerDependencyProperties }

    $InstallerManifest = SortYamlKeys $InstallerManifest $InstallerProperties
   
    New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null
    $InstallerManifestPath = $AppFolder + "\$PackageIdentifier" + '.installer' + '.yaml'
    
    #TO-DO: Write keys with no values as comments
    
    $ScriptHeader + " using YAML parsing`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.1.0.0.schema.json`n" > $InstallerManifestPath
    ConvertTo-Yaml $InstallerManifest >> $InstallerManifestPath
    $MyRawString = Get-Content -Raw $InstallerManifestPath | TrimString
    [System.IO.File]::WriteAllLines($InstallerManifestPath, $MyRawString, $Utf8NoBomEncoding)

    Write-Host 
    Write-Host "Yaml file created: $InstallerManifestPath"
}

Function Write-WinGet-LocaleManifest-Yaml {
    
    if ($script:OldManifestType -eq 'MultiManifest') { $LocaleManifest = $script:OldLocaleManifest }
    
    if (!$LocaleManifest) { [PSCustomObject]$LocaleManifest = [ordered]@{} }
    
    if ($PackageLocale -eq 'en-US') { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.0.0.schema.json' }else { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json' }
    
    $_Singletons = [ordered]@{
        "PackageIdentifier"   = $PackageIdentifier
        "PackageVersion"      = $PackageVersion
        "PackageLocale"       = $PackageLocale
        "Publisher"           = $Publisher
        "PublisherUrl"        = $PublisherUrl
        "PublisherSupportUrl" = $PublisherSupportUrl
        "PrivacyUrl"          = $PrivacyUrl
        "Author"              = $Author
        "PackageName"         = $PackageName
        "PackageUrl"          = $PackageUrl
        "License"             = $License
        "LicenseUrl"          = $LicenseUrl
        "Copyright"           = $Copyright
        "CopyrightUrl"        = $CopyrightUrl
        "ShortDescription"    = $ShortDescription
        "Description"         = $Description
    }

    foreach ($_Item in $_Singletons.GetEnumerator()) {
        if ($_Item.Value) { AddYamlParameter $LocaleManifest $_Item.Name $_Item.Value }
    }

    if ($Tags) { AddYamlListParameter $LocaleManifest "Tags" $Tags }
    if ($Moniker -and $PackageLocale -eq 'en-US') { AddYamlParameter $LocaleManifest "Moniker" $Moniker }
    if ($PackageLocale -eq 'en-US') { $_ManifestType = "defaultLocale" }else { $_ManifestType = "locale" }
    AddYamlParameter $LocaleManifest "ManifestType" $_ManifestType
    AddYamlParameter $LocaleManifest "ManifestVersion" $ManifestVersion
    $LocaleManifest = SortYamlKeys $LocaleManifest $LocaleProperties

    New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null
    $LocaleManifestPath = $AppFolder + "\$PackageIdentifier" + ".locale." + "$PackageLocale" + '.yaml'

    #TO-DO: Write keys with no values as comments

    $ScriptHeader + " using YAML parsing`n$yamlServer`n" > $LocaleManifestPath
    ConvertTo-Yaml $LocaleManifest >> $LocaleManifestPath
    $MyRawString = Get-Content -Raw $LocaleManifestPath | TrimString
    [System.IO.File]::WriteAllLines($LocaleManifestPath, $MyRawString, $Utf8NoBomEncoding)

    if ($OldManifests) {
        ForEach ($DifLocale in $OldManifests) {
            if ($DifLocale.Name -notin @("$PackageIdentifier.yaml", "$PackageIdentifier.installer.yaml", "$PackageIdentifier.locale.en-US.yaml")) {
                if (!(Test-Path $AppFolder)) { New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null }
                $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $DifLocale.FullName -Encoding UTF8) -join "`n") -Ordered
                $script:OldLocaleManifest["PackageVersion"] = $PackageVersion
                $script:OldLocaleManifest = SortYamlKeys $script:OldLocaleManifest $LocaleProperties

                $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json'
            
                $ScriptHeader + " using YAML parsing`n$yamlServer`n" > ($AppFolder + "\" + $DifLocale.Name)
                ConvertTo-Yaml $OldLocaleManifest >> ($AppFolder + "\" + $DifLocale.Name)
                $MyRawString = Get-Content -Raw $($AppFolder + "\" + $DifLocale.Name) | TrimString
                [System.IO.File]::WriteAllLines($($AppFolder + "\" + $DifLocale.Name), $MyRawString, $Utf8NoBomEncoding)
            }
        }
    }

    Write-Host 
    Write-Host "Yaml file created: $LocaleManifestPath"
}


Function Read-PreviousWinGet-Manifest-Yaml {
    
    if (($Option -eq 'NewLocale') -or ($Option -eq 'EditMetadata')) {
        if (Test-Path  -Path "$AppFolder\..\$PackageVersion") {
            $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$PackageVersion"
            $LastVersion = $PackageVersion
        }
        while (-not ($OldManifests.Name -like "$PackageIdentifier*.yaml")) {
            Write-Host
            Write-Host -ForegroundColor 'Red' -Object 'Could not find required manifests, input a version containing required manifests or "exit" to cancel'
            $PromptVersion = Read-Host -Prompt 'Version' | TrimString
            if ($PromptVersion -eq 'exit') { exit 1 }
            if (Test-Path -Path "$AppFolder\..\$PromptVersion") {
                $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$PromptVersion" 
            }
            $LastVersion = $PromptVersion
            $script:AppFolder = (Split-Path $AppFolder) + "\$LastVersion"
            $script:PackageVersion = $LastVersion
        }
    }

    if (-not (Test-Path  -Path "$AppFolder\..")) {
        $script:OldManifestType = 'None'
        return
    }
    
    if (!$LastVersion) {
        try {
            $script:LastVersion = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter "*.yaml").FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Last 1
            $script:ExistingVersions = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter "*.yaml").FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Unique
            Write-Host -ForegroundColor 'DarkYellow' -Object "Found Existing Version: $LastVersion"
            $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"
        }
        catch { Out-Null }
    }

    if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.en-US.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
        $script:OldManifestType = 'MultiManifest'
        $script:OldInstallerManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.installer.yaml") -Encoding UTF8) -join "`n") -Ordered
        $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.en-US.yaml") -Encoding UTF8) -join "`n") -Ordered
        $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
    } elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
        if ($Option -eq 'NewLocale') { Throw "Error: MultiManifest Required" }
        $script:OldManifestType = 'Singleton'
        $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
    } else {
        Throw "Error: Version $LastVersion does not contain the required manifests"
    }

    if ($OldManifests) {

        $_Parameters = @(
            "Publisher"; "PublisherUrl"; "PublisherSupportUrl"; "PrivacyUrl"
            "Author"; 
            "PackageName"; "PackageUrl"; "Moniker"
            "License"; "LicenseUrl"
            "Copyright"; "CopyrightUrl"
            "ShortDescription"; "Description"
            "Channel"
            "Platform"; "MinimumOSVersion"
            "InstallerType"
            "Scope"
            "UpgradeBehavior"
            "PackageFamilyName"; "ProductCode"
            "Tags"; "FileExtensions"
            "Protocols"; "Commands"
            "InstallModes"; "InstallerSuccessCodes"
            "Capabilities"; "RestrictedCapabilities"
        )

        Foreach ($param in $_Parameters) {
            New-Variable -Name $param -Value $(if ($script:OldManifestType -eq 'MultiManifest') { (GetMultiManifestParameter $param) } else { $script:OldVersionManifest[$param] }) -Scope Script -Force
        }
    }
}
        
Show-OptionMenu
Read-WinGet-MandatoryInfo
Read-PreviousWinGet-Manifest-Yaml

Switch ($Option) {
    
    'New' {
        Read-WinGet-InstallerValues
        Read-WinGet-InstallerManifest
        New-Variable -Name "PackageLocale" -Value "en-US" -Scope "Script" -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest-Yaml
        Write-WinGet-VersionManifest-Yaml
        Write-WinGet-LocaleManifest-Yaml
        Test-Manifest
        Submit-Manifest
    }

    'EditMetadata' {
        Read-WinGet-InstallerManifest
        New-Variable -Name "PackageLocale" -Value "en-US" -Scope "Script" -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest-Yaml
        Write-WinGet-VersionManifest-Yaml
        Write-WinGet-LocaleManifest-Yaml
        Test-Manifest
        Submit-Manifest
    }

    'Update' {
        Read-WinGet-InstallerValues
        Read-WinGet-InstallerManifest
        New-Variable -Name "PackageLocale" -Value "en-US" -Scope "Script" -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest-Yaml
        Write-WinGet-VersionManifest-Yaml
        Write-WinGet-LocaleManifest-Yaml
        Test-Manifest
        Submit-Manifest
    }

    'NewLocale' {
        Read-WinGet-LocaleManifest
        Write-WinGet-LocaleManifest-Yaml
        if (Get-Command "winget.exe" -ErrorAction SilentlyContinue) { winget validate $AppFolder }
        Submit-Manifest
    }
}