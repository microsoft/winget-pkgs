#Requires -Version 5
$PSVersion = (Get-Host).Version.Major
$ScriptHeader = '# Created with YamlCreate.ps1 v2.0.0'
$ManifestVersion = '1.0.0'
$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$ofs = ', '

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
    } catch {
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
} catch {
    Write-Host 'Error downloading schemas. Please run the script again.' -ForegroundColor Red
    exit 1
}

filter TrimString {
    $_.Trim()
}

filter UniqueItems {
    [string]$($_.Split(',').Trim() | Select-Object -Unique)
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

Function String.Validate {
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
        [int] $MaxLength,
        [switch] $AllowNull,
        [switch] $NotNull,
        [switch] $IsNull,
        [switch] $Not
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
    if ($AllowNull -and [string]::IsNullOrEmpty($InputString)) {
        $_isValid = $true
    } elseif ($NotNull -and [string]::IsNullOrEmpty($InputString)) {
        $_isValid = $false
    }
    if ($IsNull) {
        $_isValid = [string]::IsNullOrEmpty($InputString)
    }

    if ($Not) {
        return !$_isValid
    } else {
        return $_isValid
    }
}


Function Write-Colors {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]] $TextStrings,
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Colors
    )
    If ($TextStrings.Count -ne $Colors.Count) { Throw 'Invalid Function Parameters. Arguments must be of equal length' }
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
    Write-Host -ForegroundColor 'Yellow' "$Prompt"
    if ($PSBoundParameters.ContainsKey('HelpText') -and (![string]::IsNullOrWhiteSpace($HelpText))) {
        if ($PSBoundParameters.ContainsKey('HelpTextColor') -and (![string]::IsNullOrWhiteSpace($HelpTextColor))) {
            Write-Host -ForegroundColor $HelpTextColor $HelpText 
        } else {
            Write-Host -ForegroundColor 'Blue' $HelpText
        }
    }
    foreach ($entry in $Entries) {
        $_isDefault = $entry.StartsWith('*')
        if ($_isDefault) {
            $_entry = '  ' + $entry.Substring(1)
            $_color = 'Green'
        } else {
            $_entry = '  ' + $entry
            $_color = 'White'
        }
        Write-Host -ForegroundColor $_color $_entry
    }
    Write-Host
    if ($PSBoundParameters.ContainsKey('DefaultString') -and (![string]::IsNullOrWhiteSpace($DefaultString))) {
        Write-Host -NoNewline "Enter Choice (default is '$DefaultString'): "
    } else {
        Write-Host -NoNewline 'Enter Choice ('
        Write-Host -NoNewline -ForegroundColor 'Green' 'Green'
        Write-Host -NoNewline ' is default): '
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
    } catch {}
    If ($null -eq $HTTP_Response) { $HTTP_Status = 404 } 
    Else { $HTTP_Response.Close() }

    return $HTTP_Status
}
Function Show-OptionMenu {
    Clear-Host
    Write-Host -ForegroundColor 'Cyan' 'Select Mode'
    Write-Colors "`n[", '1', "] New Manifest or Package Version`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", '2', "] Update Package Metadata`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", '3', "] New Locale`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-Colors "`n[", 'q', ']', " Any key to quit`n" 'DarkCyan', 'White', 'DarkCyan', 'Red'
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
    Write-Host

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
        $script:PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
        $PackageIdentifierFolder = $PackageIdentifier.Replace('.', '\')

        if (String.Validate $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength -MatchPattern $Patterns.PackageIdentifier) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength) {
                $script:_returnValue = [ReturnValue]::LengthError(4, $Patterns.IdentifierMaxLength)
            } elseif (String.Validate -not $PackageIdentifier -MatchPattern $Patterns.PackageIdentifier) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    
    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
        $script:PackageVersion = Read-Host -Prompt 'Version' | TrimString

        if (String.Validate $PackageVersion -MaxLength $Patterns.VersionMaxLength -MatchPattern $Patterns.PackageVersion -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $PackageVersion -MaxLength $Patterns.VersionMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.VersionMaxLength)
            } elseif (String.Validate -not $PackageVersion -MatchPattern $Patterns.PackageVersion) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    
    if (Test-Path -Path "$PSScriptRoot\..\manifests") {
        $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
    } else {
        $ManifestsFolder = (Resolve-Path '.\').Path
    }
    
    $script:AppFolder = Join-Path $ManifestsFolder -ChildPath $PackageIdentifier.ToLower().Chars(0) | Join-Path -ChildPath $PackageIdentifierFolder | Join-Path -ChildPath $PackageVersion
}

Function Read-WinGet-InstallerValues {
    $InstallerValues = @(
        'Architecture'
        'InstallerType'
        'InstallerUrl'
        'InstallerSha256'
        'SignatureSha256'
        'PackageFamilyName'
        'Custom'
        'Silent'
        'SilentWithProgress'
        'ProductCode'
        'Scope'
        'InstallerLocale'
        'UpgradeBehavior'
        'AnotherInstaller'
    )
    Foreach ($InstallerValue in $InstallerValues) { Clear-Variable -Name $InstallerValue -Force -ErrorAction SilentlyContinue }

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the download url to the installer.'
        $InstallerUrl = Read-Host -Prompt 'Url' | TrimString  
        if (String.Validate $InstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -MatchPattern $Patterns.InstallerUrl -NotNull) {
            if ((TestUrlValidity $InstallerUrl) -ne 200) {
                $script:_returnValue = [ReturnValue]::new(502, 'Invalid URL Response', 'The URL did not return a successful response from the server', 2)
            } else {
                $script:_returnValue = [ReturnValue]::Success()
            }
        } else {
            if (String.Validate -not $InstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.InstallerUrlMaxLength)
            } elseif (String.Validate -not $InstallerUrl -MatchPattern $Patterns.InstallerUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    $_menu = @{
        entries       = @('[Y] Yes'; '*[N] No'; '[M] Manually Enter SHA256')
        Prompt        = 'Do you want to save the files to the Temp folder?'
        DefaultString = 'N'
    }

    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
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
            $FileInformation = Get-AppLockerFileInformation -Path $script:dest | Select-Object Publisher | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}'
            $MSIProductCode = $FileInformation.Matches
            if ($script:SaveOption -eq '1' -and -not($script:dest.EndsWith('appx', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('msix', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('appxbundle', 'CurrentCultureIgnoreCase') -or $script:dest.EndsWith('msixbundle', 'CurrentCultureIgnoreCase'))) { Remove-Item -Path $script:dest }
        }
    }

    else {
        Write-Host
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the installer SHA256 Hash'
            $InstallerSha256 = Read-Host -Prompt 'InstallerSha256' | TrimString
            $InstallerSHA256 = $InstallerSha256.toUpper()
            if ($InstallerSha256 -match $Patterns.InstallerSha256) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::PatternError()
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the architecture. Options:' , @($Patterns.ValidArchitectures -join ', ')
        $architecture = Read-Host -Prompt 'Architecture' | TrimString
        if ($architecture -Cin @($Patterns.ValidArchitectures)) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::new(400, 'Invalid Architecture', "Value must exist in the enum - $(@($Patterns.ValidArchitectures -join ', '))", 2)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the InstallerType. Options:' , @($Patterns.ValidInstallerTypes -join ', ' )
        $InstallerType = Read-Host -Prompt 'InstallerType' | TrimString
        if ($InstallerType -Cin @($Patterns.ValidInstallerTypes)) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::new(400, 'Invalid Installer Type', "Value must exist in the enum - $(@($Patterns.ValidInstallerTypes -join ', '))", 2)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    if ($InstallerType -ieq 'exe') {
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent install switch. For example: /S, -verysilent, /qn, --silent, /exenoui'
            $Silent = Read-Host -Prompt 'Silent switch' | TrimString

            if (String.Validate $Silent -MaxLength $Patterns.SilentSwitchMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.SilentSwitchMaxLength)
            }

        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent with progress install switch. For example: /S, -silent, /qb, /exebasicui'
            $SilentWithProgress = Read-Host -Prompt 'Silent with progress switch' | TrimString

            if (String.Validate $SilentWithProgress -MaxLength $Patterns.ProgressSwitchMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.ProgressSwitchMaxLength)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: /norestart, -norestart'
            $Custom = Read-Host -Prompt 'Custom Switch' | TrimString

            if (String.Validate $Custom -MaxLength $Patterns.CustomSwitchMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.CustomSwitchMaxLength)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    } else {
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent install switch. For example: /S, /s, /VERYSILENT, /qn, --silent'
            $Silent = Read-Host -Prompt 'Silent' | TrimString

            if (String.Validate $Silent -MaxLength $Patterns.SilentSwitchMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.SilentSwitchMaxLength)
            }

        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent with progress install switch. For example: /S, /SILENT, /qb'
            $SilentWithProgress = Read-Host -Prompt 'SilentWithProgress' | TrimString

            if (String.Validate $SilentWithProgress -MaxLength $Patterns.ProgressSwitchMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.ProgressSwitchMaxLength)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any custom switches for the installer. For example: /NORESTART, -norestart, /CURRENTUSER, /ALLUSERS'
            $Custom = Read-Host -Prompt 'CustomSwitch' | TrimString

            if (String.Validate $Custom -MaxLength $Patterns.CustomSwitchMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.CustomSwitchMaxLength)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }

    if ($InstallerType -ieq 'msix' -or $InstallerType -ieq 'appx') {
        if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { $SignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() } }
        if (String.Validate $SignatureSha256 -IsNull) {
            do {
                Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
                Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the installer SignatureSha256'
                $SignatureSha256 = Read-Host -Prompt 'SignatureSha256' | TrimString
                
                if (String.Validate $SignatureSha256 -MatchPattern $Patterns.SignatureSha256 -AllowNull) {
                    $script:_returnValue = [ReturnValue]::Success()
                } else {
                    $script:_returnValue = [ReturnValue]::PatternError()
                }
            } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
        }

        $_menu = @{
            entries       = @('*[F] Find Automatically [Note: This will install the package to find Family Name and then removes it.]'; '[M] Manually Enter PackageFamilyName')
            Prompt        = 'Discover the package family name?'
            DefaultString = 'M'
        }
    
        switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
            'F' { $ChoicePfn = '0' }
            'M' { $ChoicePfn = '1' }
            default { $ChoicePfn = '0' }
        }

        if ($ChoicePfn -eq '0') {
            Add-AppxPackage -Path $script:dest
            $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName, PackageFullName
            $PackageFamilyName = $InstalledPkg.PackageFamilyName
            Remove-AppxPackage $InstalledPkg.PackageFullName
            if (String.Validate $PackageFamilyName -IsNull) {
                $script:_returnValue = [ReturnValue]::new(500, 'Could not find PackageFamilyName', 'Value should be entered manually', 1)
            }
        } else {
            Write-Host $null
        }
        
        do {
            if (($ChoicePfn -ne '0') -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
                Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
                Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the PackageFamilyName'
                $PackageFamilyName = Read-Host -Prompt 'PackageFamilyName' | TrimString
            }

            if (String.Validate $PackageFamilyName -MaxLength $Patterns.FamilyNameMaxLength -MatchPattern $Patterns.FamilyName -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                if (String.Validate -not $PackageFamilyName -MaxLength $Patterns.FamilyNameMaxLength) {
                    $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.FamilyNameMaxLength)
                } elseif (String.Validate -not $PackageFamilyName -MatchPattern $Patterns.FamilyName) {
                    $script:_returnValue = [ReturnValue]::PatternError()
                } else {
                    $script:_returnValue = [ReturnValue]::GenericError()
                }
            }

        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
        if ($script:SaveOption -eq '1') { Remove-Item -Path $script:dest }
    }

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the installer locale. For example: en-US, en-CA'
        Write-Host -ForegroundColor 'Blue' -Object 'https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $InstallerLocale = Read-Host -Prompt 'InstallerLocale' | TrimString
        if (String.Validate $InstallerLocale -IsNull) { $InstallerLocale = 'en-US' }

        if (String.Validate $InstallerLocale -MaxLength $Patterns.InstallerLocaleMaxLength -MatchPattern $Patterns.PackageLocale -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $InstallerLocale -MaxLength $Patterns.InstallerLocaleMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.InstallerLocaleMaxLength)
            } elseif (String.Validate -not $InstallerLocale -MatchPattern $Patterns.PackageLocale) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
        Write-Host -ForegroundColor 'White' -Object "ProductCode found from installer: $MSIProductCode"
        Write-Host -ForegroundColor 'White' -Object 'Can be found with ' -NoNewline; Write-Host -ForegroundColor 'DarkYellow' 'get-wmiobject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name -AutoSize'
        $ProductCode = Read-Host -Prompt 'ProductCode' | TrimString

        if (String.Validate $ProductCode -MinLength $Patterns.ProductCodeMinLength -MaxLength $Patterns.ProductCodeMaxLength -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.ProductCodeMinLength, $Patterns.ProductCodeMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    $_menu = @{
        entries       = @('[M] Machine'; '[U] User'; '*[N] No idea')
        Prompt        = '[Optional] Enter the Installer Scope'
        DefaultString = 'N'
    }

    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'M' { $Scope = 'machine' }
        'U' { $Scope = 'user' }
        'N' { $Scope = '' }
        default { $Scope = '' }
    }

    $_menu = @{
        entries       = @('*[I] Install'; '[U] Uninstall Previous')
        Prompt        = '[Optional] Enter the Upgrade Behavior'
        DefaultString = 'I'
    }

    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'I' { $UpgradeBehavior = 'install' }
        'U' { $UpgradeBehavior = 'uninstallPrevious' }
        default { $UpgradeBehavior = 'install' }
    }
    
    if (!$script:Installers) {
        $script:Installers = @()
    }
    $_Installer = [ordered] @{}

    $_InstallerSingletons = [ordered] @{
        'InstallerLocale'   = $InstallerLocale
        'Architecture'      = $Architecture
        'InstallerType'     = $InstallerType
        'Scope'             = $Scope
        'InstallerUrl'      = $InstallerUrl
        'InstallerSha256'   = $InstallerSha256
        'SignatureSha256'   = $SignatureSha256
        'PackageFamilyName' = $PackageFamilyName
    }
    foreach ($_Item in $_InstallerSingletons.GetEnumerator()) {
        If ($_Item.Value) { AddYamlParameter $_Installer $_Item.Name $_Item.Value }
    }

    If ($Silent -or $SilentWithProgress -or $Custom) {
        $_InstallerSwitches = [ordered]@{}
        $_Switches = [ordered] @{
            'Custom'             = $Custom
            'Silent'             = $Silent
            'SilentWithProgress' = $SilentWithProgress
        }
        
        foreach ($_Item in $_Switches.GetEnumerator()) {
            If ($_Item.Value) { AddYamlParameter $_InstallerSwitches $_Item.Name $_Item.Value }
        }
        $_InstallerSwitches = SortYamlKeys $_InstallerSwitches $InstallerSwitchProperties
        $_Installer['InstallerSwitches'] = $_InstallerSwitches
    }

    If ($ProductCode) { AddYamlParameter $_Installer 'ProductCode' $ProductCode }
    AddYamlParameter $_Installer 'UpgradeBehavior' $UpgradeBehavior
    $_Installer = SortYamlKeys $_Installer $InstallerEntryProperties

    $script:Installers += $_Installer

    $_menu = @{
        entries       = @(
            '[Y] Yes'
            '*[N] No'
        )
        Prompt        = 'Do you want to create another installer?'
        DefaultString = 'N'
    }

    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'Y' { $AnotherInstaller = '0' }
        'N' { $AnotherInstaller = '1' }
        default { $AnotherInstaller = '1' }
    }

    if ($AnotherInstaller -eq '0') {
        Write-Host; Read-WinGet-InstallerValues
    }
}

Function PromptInstallerManifestValue {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $Variable,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Key,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $Prompt
    )
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
    Write-Host -ForegroundColor 'Yellow' -Object $Prompt
    if (String.Validate -not $Variable -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Value: $Variable" }
    $NewValue = Read-Host -Prompt $Key | TrimString

    if (String.Validate -not $NewValue -IsNull) {
        return $NewValue
    } else {
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
        else { $FileExtensions = $FileExtensions | UniqueItems }
        $script:FileExtensions = PromptInstallerManifestValue $FileExtensions 'FileExtensions' "[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max $($Patterns.MaxItemsFileExtensions))" | UniqueItems

        if (($script:FileExtensions -split ',').Count -le $Patterns.MaxItemsFileExtensions -and $($script:FileExtensions.Split(',').Trim() | Where-Object { String.Validate -not $_ -MaxLength $Patterns.FileExtensionMaxLength -MatchPattern $Patterns.FileExtension -AllowNull }).Count -eq 0) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (($script:FileExtensions -split ',').Count -gt $Patterns.MaxItemsFileExtensions ) {
                $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsFileExtensions)
            } else {
                $script:_returnValue = [ReturnValue]::new(400, 'Invalid Entries', "Some entries do not match the requirements defined in the manifest schema - $($script:FileExtensions.Split(',').Trim() | Where-Object { String.Validate -not $_ -MaxLength $Patterns.FileExtensionMaxLength -MatchPattern $Patterns.FileExtension })", 2)
            }
        }

    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        if (!$Protocols) { $Protocols = '' }
        else { $Protocols = $Protocols | UniqueItems }
        $script:Protocols = PromptInstallerManifestValue $Protocols 'Protocols' "[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max $($Patterns.MaxItemsProtocols))" | UniqueItems
        if (($script:Protocols -split ',').Count -le $Patterns.MaxItemsProtocols) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsProtocols)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        if (!$Commands) { $Commands = '' }        
        else { $Commands = $Commands | UniqueItems }
        $script:Commands = PromptInstallerManifestValue $Commands 'Commands' "[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max $($Patterns.MaxItemsCommands))" | UniqueItems
        if (($script:Commands -split ',').Count -le $Patterns.MaxItemsCommands) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsCommands)
        }
    }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        if (!$InstallerSuccessCodes) { $InstallerSuccessCodes = '' }
        $script:InstallerSuccessCodes = PromptInstallerManifestValue $InstallerSuccessCodes 'InstallerSuccessCodes' "[Optional] List of additional non-zero installer success exit codes other than known default values by winget (Max $($Patterns.MaxItemsSuccessCodes))" | UniqueItems
        if (($script:InstallerSuccessCodes -split ',').Count -le $Patterns.MaxItemsSuccessCodes) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsSuccessCodes)
        }
    }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        if (!$InstallModes) { $InstallModes = '' }
        $InstallModes = $InstallModes | UniqueItems
        $script:InstallModes = PromptInstallerManifestValue $InstallModes 'InstallModes' "[Optional] List of supported installer modes. Options: $($Patterns.ValidInstallModes -join ', ')"
        $script:InstallModes = $script:InstallModes | UniqueItems

        if ( (String.Validate $script:InstallModes -IsNull) -or (($script:InstallModes -split ',').Count -le $Patterns.MaxItemsInstallModes -and $($script:InstallModes.Split(',').Trim() | Where-Object { $_ -CNotIn $Patterns.ValidInstallModes }).Count -eq 0)) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (($script:InstallModes -split ',').Count -gt $Patterns.MaxItemsInstallModes ) {
                $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsInstallModes)
            } else {
                $script:_returnValue = [ReturnValue]::new(400, 'Invalid Entries', "Some entries do not match the requirements defined in the manifest schema - $($script:InstallModes.Split(',').Trim() | Where-Object { $_ -CNotIn $Patterns.ValidInstallModes })", 2)
            }
        }

    }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
}

Function Read-WinGet-LocaleManifest {
    if (String.Validate -not $script:PackageLocale -MaxLength $Patterns.PackageLocaleMaxLength -MatchPattern $Patterns.PackageLocale -NotNull) {
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Locale. For example: en-US, en-CA'
            Write-Host -ForegroundColor 'Blue' 'Reference Link: https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
            $script:PackageLocale = Read-Host -Prompt 'PackageLocale' | TrimString
            if (String.Validate $script:PackageLocale -MaxLength $Patterns.PackageLocaleMaxLength -MatchPattern $Patterns.PackageLocale -NotNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                if (String.Validate $script:PackageLocale -not -MaxLength $Patterns.PackageLocaleMaxLength -NotNull) {
                    $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.PackageLocaleMaxLength)
                } elseif (String.Validate $script:PackageLocale -not -MatchPattern $Patterns.PackageLocale ) {
                    $script:_returnValue = [ReturnValue]::PatternError()
                } else {
                    $script:_returnValue = [ReturnValue]::GenericError()
                }
            }
        }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString() 
        if (String.Validate $script:Publisher -IsNull) {
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation' 
        } else {
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full publisher name. For example: Microsoft Corporation'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Publisher"
        }
        $NewPublisher = Read-Host -Prompt 'Publisher' | TrimString

        if (String.Validate $NewPublisher -NotNull) {
            $script:Publisher = $NewPublisher
        }

        if (String.Validate $script:Publisher -MaxLength $Patterns.PublisherMaxLength -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.PublisherMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        if (String.Validate $script:PackageName -IsNull) {
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
        } else {
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full application name. For example: Microsoft Teams'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageName"
        }
        $NewPackageName = Read-Host -Prompt 'PackageName' | TrimString
        if (String.Validate -not $NewPackageName -IsNull) { $script:PackageName = $NewPackageName }

        if (String.Validate $script:PackageName -MaxLength $Patterns.PackageNameMaxLength -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.PackageNameMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    if ($Option -ne 'NewLocale') {
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Moniker (friendly name/alias). For example: vscode'
            if (String.Validate -not $script:Moniker -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Moniker" }
            $NewMoniker = Read-Host -Prompt 'Moniker' | TrimString
            if (String.Validate -not $NewMoniker -IsNull) { $script:Moniker = $NewMoniker }

            if (String.Validate $script:Moniker -MaxLength $Patterns.MonikerMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.MonikerMaxLength)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Url.'
        if (String.Validate -not $script:PublisherUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherUrl" }
        $NewPublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
        if (String.Validate -not $NewPublisherUrl -IsNull) { $script:PublisherUrl = $NewPublisherUrl }

        if (String.Validate $script:PublisherUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:PublisherUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:PublisherUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Support Url.'
        if (String.Validate -not $script:PublisherSupportUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherSupportUrl" }
        $NewPublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
        if (String.Validate -not $NewPublisherSupportUrl -IsNull) { $script:PublisherSupportUrl = $NewPublisherSupportUrl }

        if (String.Validate $script:PublisherSupportUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:PublisherSupportUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:PublisherSupportUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Publisher Privacy Url.'
        if (String.Validate -not $script:PrivacyUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PrivacyUrl" }
        $NewPrivacyUrl = Read-Host -Prompt 'Publisher Privacy Url' | TrimString
        if (String.Validate -not $NewPrivacyUrl -IsNull) { $script:PrivacyUrl = $NewPrivacyUrl }

        if (String.Validate $script:PrivacyUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:PrivacyUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:PrivacyUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Author.'
        if (String.Validate -not $script:Author -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Author" }
        $NewAuthor = Read-Host -Prompt 'Author' | TrimString
        if (String.Validate -not $NewAuthor -IsNull) { $script:Author = $NewAuthor }

        if (String.Validate $script:Author -MinLength $Patterns.AuthorMinLength -MaxLength $Patterns.AuthorMaxLength -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.AuthorMinLength, $Patterns.AuthorMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
        if (String.Validate -not $script:PackageUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageUrl" }
        $NewPackageUrl = Read-Host -Prompt 'Homepage' | TrimString
        if (String.Validate -not $NewPackageUrl -IsNull) { $script:PackageUrl = $NewPackageUrl }

        if (String.Validate $script:PackageUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:PackageUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:PackageUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        
        if (String.Validate $script:License -IsNull) {
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
        } else { 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:License"
        }
        $NewLicense = Read-Host -Prompt 'License' | TrimString
        if (String.Validate -not $NewLicense -IsNull) { $script:License = $NewLicense }

        if (String.Validate $script:License -MinLength $Patterns.LicenseMinLength -MaxLength $Patterns.LicenseMaxLength -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } elseif (String.Validate $script:License -IsNull) {
            $script:_returnValue = [ReturnValue]::new(400, 'Required Field', 'The value entered cannot be null or empty', 2)
        } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.LicenseMinLength, $Patterns.LicenseMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
        if (String.Validate -not $script:LicenseUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:LicenseUrl" }
        $NewLicenseUrl = Read-Host -Prompt 'License URL' | TrimString
        if (String.Validate -not $NewLicenseUrl -IsNull) { $script:LicenseUrl = $NewLicenseUrl }

        if (String.Validate $script:LicenseUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:LicenseUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:LicenseUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    
    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright.'
        Write-Host -ForegroundColor 'Blue' 'Example: Copyright (c) Microsoft Corporation'
        if (String.Validate -not $script:Copyright -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Copyright" }
        $NewCopyright = Read-Host -Prompt 'Copyright' | TrimString
        if (String.Validate -not $NewCopyright -IsNull) { $script:Copyright = $NewCopyright }

        if (String.Validate $script:Copyright -MinLength $Patterns.CopyrightMinLength -MaxLength $Patterns.CopyrightMaxLength -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.CopyrightMinLength, $Patterns.CopyrightMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
        if (String.Validate -not $script:CopyrightUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:CopyrightUrl" }
        $NewCopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
        if (String.Validate -not $NewCopyrightUrl -IsNull) { $script:CopyrightUrl = $NewCopyrightUrl }

        if (String.Validate $script:CopyrightUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $script:CopyrightUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
            } elseif (String.Validate -not $script:CopyrightUrl -MatchPattern $Patterns.GenericUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        $script:Tags = [string]$script:Tags
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter any tags that would be useful to discover this tool.'
        Write-Host -ForegroundColor 'Blue' -Object 'Example: zip, c++, photos, OBS (Max', ($Patterns.TagsMaxItems), 'items)'
        if (String.Validate -not $script:Tags -IsNull) {
            $script:Tags = $script:Tags | UniqueItems
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Tags" 
        }
        $NewTags = Read-Host -Prompt 'Tags' | TrimString | UniqueItems
        if (String.Validate -not $NewTags -IsNull) { $script:Tags = $NewTags }

        if (($script:Tags -split ',').Count -le $Patterns.TagsMaxItems) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.TagsMaxItems)
        }        
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)


    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        if (String.Validate $script:ShortDescription -IsNull) {
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
        } else { 
            Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a short description of the application.'
            Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:ShortDescription"
        }
        $NewShortDescription = Read-Host -Prompt 'Short Description' | TrimString
        if (String.Validate -not $NewShortDescription -IsNull) { $script:ShortDescription = $NewShortDescription }

        if (String.Validate $script:ShortDescription -MaxLength $Patterns.ShortDescriptionMaxLength -NotNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.ShortDescriptionMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
        if (String.Validate -not $script:Description -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Description" }
        $NewDescription = Read-Host -Prompt 'Description' | TrimString
        if (String.Validate -not $NewDescription -IsNull) { $script:Description = $NewDescription }

        if (String.Validate $script:Description -MinLength $Patterns.DescriptionMinLength -MaxLength $Patterns.DescriptionMaxLength -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.DescriptionMinLength, $Patterns.DescriptionMaxLength)
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
}

Function Test-Manifest {
    if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { winget validate $AppFolder }

    if (Get-Command 'WindowsSandbox.exe' -ErrorAction SilentlyContinue) {

        $_menu = @{
            entries       = @('*[Y] Yes'; '[N] No')
            Prompt        = '[Recommended] Do you want to test your Manifest in Windows Sandbox?'
            DefaultString = 'Y'
        }
        
        switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
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
                    Prompt        = 'Have you signed the Contributor License Agreement (CLA)?'
                    Entries       = @('[Y] Yes'; '*[N] No')
                    HelpText      = 'Reference Link: https://cla.opensource.microsoft.com/microsoft/winget-pkgs'
                    HelpTextColor = ''
                    DefaultString = 'N'
                }
            }
    
            '*open `[pull requests`]*' {
                $_menu = @{
                    Prompt        = "Have you checked that there aren't other open pull requests for the same manifest update/change?"
                    Entries       = @('[Y] Yes'; '*[N] No')
                    HelpText      = 'Reference Link: https://github.com/microsoft/winget-pkgs/pulls'
                    HelpTextColor = ''
                    DefaultString = 'N'
                }
            }
    
            '*winget validate*' {
                if ($?) {
                    $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
                    $_showMenu = $false
                } else {
                    $_menu = @{
                        Prompt        = "Have you validated your manifest locally with 'winget validate --manifest <path>'?"
                        Entries       = @('[Y] Yes'; '*[N] No')
                        HelpText      = 'Automatic manifest validation failed. Check your manifest and try again'
                        HelpTextColor = 'Red'
                        DefaultString = 'N'
                    }
                }
            }
    
            '*tested your manifest*' {
                if ($script:SandboxTest -eq '0') {
                    $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
                    $_showMenu = $false
                } else {
                    $_menu = @{
                        Prompt        = "Have you tested your manifest locally with 'winget install --manifest <path>'?"
                        Entries       = @('[Y] Yes'; '*[N] No')
                        HelpText      = 'You did not test your Manifest in Windows Sandbox previously.'
                        HelpTextColor = 'Red'
                        DefaultString = 'N'
                    }
                }
            }
    
            '*schema*' {
                $_menu = @{
                    Prompt        = 'Does your manifest conform to the 1.0 schema?'
                    Entries       = @('[Y] Yes'; '*[N] No')
                    HelpText      = 'Reference Link: https://github.com/microsoft/winget-cli/blob/master/doc/ManifestSpecv1.0.md'
                    HelpTextColor = ''
                    DefaultString = 'N'
                }
            }
    
            Default {
                $_menu = @{
                    Prompt        = $_line.TrimStart('- [ ]')
                    Entries       = @('[Y] Yes'; '*[N] No')
                    HelpText      = ''
                    HelpTextColor = ''
                    DefaultString = 'N'
                }
            }
        }

        if ($_showMenu) {
            switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
                'Y' { $PrBodyContentReply += @($_line.Replace('[ ]', '[X]')) }
                default { $PrBodyContentReply += @($_line) }
            }
        }
    }

    $_menu = @{
        entries       = @('[Y] Yes'; '*[N] No')
        Prompt        = 'Does this pull request resolve any issues?'
        DefaultString = 'N'
    }
    
    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'Y' {
            Write-Host
            Write-Host "Enter issue number. For example`: 21983, 43509"
            $ResolvedIssues = Read-Host -Prompt 'Resolved Issues' | UniqueItems
            $PrBodyContentReply += @('')
            Foreach ($i in ($ResolvedIssues.Split(',').Trim())) {

                if ($i.Contains('#')) {
                    $_UrlParameters = $i.Split('#')
                    switch ($_UrlParameters.Count) {
                        2 {
                            if ([string]::IsNullOrWhiteSpace($_urlParameters[0])) {
                                $_checkedURL = "https://github.com/microsoft/winget-pkgs/issues/$($_urlParameters[1])" 
                            } else {
                                $_checkedURL = "https://github.com/$($_urlParameters[0])/issues/$($_urlParameters[1])" 
                            }
                        }
                        default {
                            Write-Host -ForegroundColor 'Red' "Invalid Issue: $i"
                            continue
                        }
                    }
                    $_responseCode = TestUrlValidity $_checkedURL
                    if ($_responseCode -ne 200) {
                        Write-Host -ForegroundColor 'Red' "Invalid Issue: $i"
                        continue
                    }
                    $PrBodyContentReply += @("Resolves $i")
                } else {
                    $_checkedURL = "https://github.com/microsoft/winget-pkgs/issues/$i"
                    $_responseCode = TestUrlValidity $_checkedURL
                    if ($_responseCode -ne 200) {
                        Write-Host -ForegroundColor 'Red' "Invalid Issue: $i"
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
            entries       = @('*[Y] Yes'; '[N] No')
            Prompt        = 'Do you want to submit your PR now?'
            DefaultString = 'Y'
        }
        
        switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
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
    Foreach ($Value in $Values.Split(',').Trim()) {
        if ($Parameter -eq 'InstallerSuccessCodes') {
            try {
                $Value = [int]$Value
            } catch {}
        }
        $_Values += $Value
    }
    $Object[$Parameter] = $_Values
}

Function AddYamlParameter {
    Param
    (
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
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter
    )
    $_vals = $($script:OldInstallerManifest[$Parameter] + $script:OldLocaleManifest[$Parameter] + $script:OldVersionManifest[$Parameter] | Where-Object { $_ })
    return ($_vals -join ', ')
}
Function Write-WinGet-VersionManifest-Yaml {
    [PSCustomObject]$VersionManifest = [ordered]@{}

    $_Singletons = [ordered]@{
        'PackageIdentifier' = $PackageIdentifier
        'PackageVersion'    = $PackageVersion
        'DefaultLocale'     = 'en-US'
        'ManifestType'      = 'version'
        'ManifestVersion'   = $ManifestVersion
    }

    foreach ($_Item in $_Singletons.GetEnumerator()) {
        If ($_Item.Value) { AddYamlParameter $VersionManifest $_Item.Name $_Item.Value }
    }
    $VersionManifest = SortYamlKeys $VersionManifest $VersionProperties
    
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
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

    if ($script:OldManifestType -eq 'MultiManifest') {
        $InstallerManifest = $script:OldInstallerManifest
    }

    if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

    AddYamlParameter $InstallerManifest 'PackageIdentifier' $PackageIdentifier
    AddYamlParameter $InstallerManifest 'PackageVersion' $PackageVersion
    $InstallerManifest['MinimumOSVersion'] = If ($MinimumOSVersion) { $MinimumOSVersion } Else { '10.0.0.0' }

    $_ListSections = [ordered]@{
        'FileExtensions'        = $FileExtensions
        'Protocols'             = $Protocols
        'Commands'              = $Commands
        'InstallerSuccessCodes' = $InstallerSuccessCodes
        'InstallModes'          = $InstallModes
    }
    foreach ($Section in $_ListSections.GetEnumerator()) {
        If ($Section.Value) { AddYamlListParameter $InstallerManifest $Section.Name $Section.Value }
    }

    if ($Option -ne 'EditMetadata') {
        $InstallerManifest['Installers'] = $script:Installers
    } elseif ($script:OldInstallerManifest) {
        $InstallerManifest['Installers'] = $script:OldInstallerManifest['Installers']
    } else {
        $InstallerManifest['Installers'] = $script:OldVersionManifest['Installers']
    }

    AddYamlParameter $InstallerManifest 'ManifestType' 'installer'
    AddYamlParameter $InstallerManifest 'ManifestVersion' $ManifestVersion
    If ($InstallerManifest['Dependencies']) {
        $InstallerManifest['Dependencies'] = SortYamlKeys $InstallerManifest['Dependencies'] $InstallerDependencyProperties
    }

    $InstallerManifest = SortYamlKeys $InstallerManifest $InstallerProperties
   
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
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
    
    if ($script:OldManifestType -eq 'MultiManifest') {
        $LocaleManifest = $script:OldLocaleManifest
    }
    
    if (!$LocaleManifest) { [PSCustomObject]$LocaleManifest = [ordered]@{} }
    
    if ($PackageLocale -eq 'en-US') { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.0.0.schema.json' }else { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json' }
    
    $_Singletons = [ordered]@{
        'PackageIdentifier'   = $PackageIdentifier
        'PackageVersion'      = $PackageVersion
        'PackageLocale'       = $PackageLocale
        'Publisher'           = $Publisher
        'PublisherUrl'        = $PublisherUrl
        'PublisherSupportUrl' = $PublisherSupportUrl
        'PrivacyUrl'          = $PrivacyUrl
        'Author'              = $Author
        'PackageName'         = $PackageName
        'PackageUrl'          = $PackageUrl
        'License'             = $License
        'LicenseUrl'          = $LicenseUrl
        'Copyright'           = $Copyright
        'CopyrightUrl'        = $CopyrightUrl
        'ShortDescription'    = $ShortDescription
        'Description'         = $Description
    }

    foreach ($_Item in $_Singletons.GetEnumerator()) {
        If ($_Item.Value) { AddYamlParameter $LocaleManifest $_Item.Name $_Item.Value }
    }

    If ($Tags) { AddYamlListParameter $LocaleManifest 'Tags' $Tags }
    If ($Moniker -and $PackageLocale -eq 'en-US') { AddYamlParameter $LocaleManifest 'Moniker' $Moniker }
    If ($PackageLocale -eq 'en-US') { $_ManifestType = 'defaultLocale' }else { $_ManifestType = 'locale' }
    AddYamlParameter $LocaleManifest 'ManifestType' $_ManifestType
    AddYamlParameter $LocaleManifest 'ManifestVersion' $ManifestVersion
    $LocaleManifest = SortYamlKeys $LocaleManifest $LocaleProperties

    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $LocaleManifestPath = $AppFolder + "\$PackageIdentifier" + '.locale.' + "$PackageLocale" + '.yaml'

    #TO-DO: Write keys with no values as comments

    $ScriptHeader + " using YAML parsing`n$yamlServer`n" > $LocaleManifestPath
    ConvertTo-Yaml $LocaleManifest >> $LocaleManifestPath
    $MyRawString = Get-Content -Raw $LocaleManifestPath | TrimString
    [System.IO.File]::WriteAllLines($LocaleManifestPath, $MyRawString, $Utf8NoBomEncoding)

    if ($OldManifests) {
        ForEach ($DifLocale in $OldManifests) {
            if ($DifLocale.Name -notin @("$PackageIdentifier.yaml", "$PackageIdentifier.installer.yaml", "$PackageIdentifier.locale.en-US.yaml")) {
                if (!(Test-Path $AppFolder)) { New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null }
                $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $DifLocale.FullName -Encoding UTF8) -join "`n") -Ordered
                $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
                $script:OldLocaleManifest = SortYamlKeys $script:OldLocaleManifest $LocaleProperties

                $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json'
            
                $ScriptHeader + " using YAML parsing`n$yamlServer`n" > ($AppFolder + '\' + $DifLocale.Name)
                ConvertTo-Yaml $OldLocaleManifest >> ($AppFolder + '\' + $DifLocale.Name)
                $MyRawString = Get-Content -Raw $($AppFolder + '\' + $DifLocale.Name) | TrimString
                [System.IO.File]::WriteAllLines($($AppFolder + '\' + $DifLocale.Name), $MyRawString, $Utf8NoBomEncoding)
            }
        }
    }

    Write-Host 
    Write-Host "Yaml file created: $LocaleManifestPath"
}


Function Read-PreviousWinGet-Manifest-Yaml {
    
    if (($Option -eq 'NewLocale') -or ($Option -eq 'EditMetadata')) {
        if (Test-Path -Path "$AppFolder\..\$PackageVersion") {
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

    if (-not (Test-Path -Path "$AppFolder\..")) {
        $script:OldManifestType = 'None'
        return
    }
    
    if (!$LastVersion) {
        try {
            $script:LastVersion = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml').FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Last 1
            $script:ExistingVersions = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml').FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Unique
            Write-Host -ForegroundColor 'DarkYellow' -Object "Found Existing Version: $LastVersion"
            $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"
        } catch {
            Out-Null
        }
    }

    if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.en-US.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
        $script:OldManifestType = 'MultiManifest'
        $script:OldInstallerManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.installer.yaml") -Encoding UTF8) -join "`n") -Ordered
        $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.en-US.yaml") -Encoding UTF8) -join "`n") -Ordered
        $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
    } elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
        if ($Option -eq 'NewLocale') { Throw 'Error: MultiManifest Required' }
        $script:OldManifestType = 'Singleton'
        $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
    } else {
        Throw "Error: Version $LastVersion does not contain the required manifests"
    }

    if ($OldManifests) {

        $_Parameters = @(
            'Publisher'; 'PublisherUrl'; 'PublisherSupportUrl'; 'PrivacyUrl'
            'Author'; 
            'PackageName'; 'PackageUrl'; 'Moniker'
            'License'; 'LicenseUrl'
            'Copyright'; 'CopyrightUrl'
            'ShortDescription'; 'Description'
            'Channel'
            'Platform'; 'MinimumOSVersion'
            'InstallerType'
            'Scope'
            'UpgradeBehavior'
            'PackageFamilyName'; 'ProductCode'
            'Tags'; 'FileExtensions'
            'Protocols'; 'Commands'
            'InstallModes'; 'InstallerSuccessCodes'
            'Capabilities'; 'RestrictedCapabilities'
        )

        Foreach ($param in $_Parameters) {
            New-Variable -Name $param -Value $(if ($script:OldManifestType -eq 'MultiManifest') { (GetMultiManifestParameter $param) } else { $script:OldVersionManifest[$param] }) -Scope Script -Force
        }
    }
}

$script:_returnValue = [ReturnValue]::new(200)
Show-OptionMenu
Read-WinGet-MandatoryInfo
Read-PreviousWinGet-Manifest-Yaml

Switch ($Option) {
    
    'New' {
        Read-WinGet-InstallerValues
        Read-WinGet-InstallerManifest
        New-Variable -Name 'PackageLocale' -Value 'en-US' -Scope 'Script' -Force
        Read-WinGet-LocaleManifest
        Write-WinGet-InstallerManifest-Yaml
        Write-WinGet-VersionManifest-Yaml
        Write-WinGet-LocaleManifest-Yaml
        Test-Manifest
        Submit-Manifest
    }

    'EditMetadata' {
        Read-WinGet-InstallerManifest
        New-Variable -Name 'PackageLocale' -Value 'en-US' -Scope 'Script' -Force
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
        New-Variable -Name 'PackageLocale' -Value 'en-US' -Scope 'Script' -Force
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
        if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { winget validate $AppFolder }
        Submit-Manifest
    }
}

Enum ErrorLevel {
    Undefined = -1
    Info = 0
    Warning = 1
    Error = 2
    Critical = 3
}

Class ReturnValue {
    [int] $StatusCode
    [string] $Title
    [string] $Message
    [ErrorLevel] $Severity

    ReturnValue() {
        
    }

    ReturnValue(
        [int]$statusCode
    ) {
        $this.StatusCode = $statusCode
        $this.Title = '-'
        $this.Message = '-'
        $this.Severity = -1
    }

    ReturnValue(
        [int] $statusCode,
        [string] $title,
        [string] $message,
        [ErrorLevel] $severity    
    ) {
        $this.StatusCode = $statusCode
        $this.Title = $title
        $this.Message = $message
        $this.Severity = $severity
    }

    [ReturnValue] static Success() {
        return [ReturnValue]::new(200, 'OK', 'The command completed successfully', 'Info')
    }

    [ReturnValue] static GenericError() {
        return [ReturnValue]::new(500, 'Internal Error', 'Value was not able to be saved successfully', 2)
        
    }

    [ReturnValue] static PatternError() {
        return [ReturnValue]::new(400, 'Invalid Pattern', 'The value entered does not match the pattern requirements defined in the manifest schema', 2)
    }

    [ReturnValue] static LengthError([int]$MinLength, [int]$MaxLength) {
        return [ReturnValue]::new(400, 'Invalid Length', "Length must be between $MinLength and $MaxLength characters", 2)
    }

    [ReturnValue] static MaxItemsError([int]$MaxEntries) {
        return [ReturnValue]::new(400, 'Too many entries', "Number of entries must be less than or equal to $MaxEntries", 2)
    }

    [string] ToString() {
        return "[$($this.Severity)] ($($this.StatusCode)) $($this.Title) - $($this.Message)"
    }

    [string] ErrorString() {
        if ($this.StatusCode -eq 200) {
            return $null
        } else {
            return "[$($this.Severity)] $($this.Title) - $($this.Message)`n"
        }
    }
}