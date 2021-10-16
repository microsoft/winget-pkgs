#Requires -Version 5
Param
(
    [switch] $Settings,
    [switch] $AutoUpgrade,
    [switch] $help,
    [Parameter(Mandatory = $false)]
    [string] $PackageIdentifier,
    [Parameter(Mandatory = $false)]
    [string] $PackageVersion,
    [Parameter(Mandatory = $false)]
    [string] $Mode
)

if ($help) {
    Write-Host -ForegroundColor 'Green' 'For full documentation of the script, see https://github.com/microsoft/winget-pkgs/tree/master/doc/tools/YamlCreate.md'
    Write-Host -ForegroundColor 'Yellow' 'Usage: ' -NoNewline
    Write-Host -ForegroundColor 'White' '.\YamlCreate.ps1 [-PackageIdentifier <identifier>] [-PackageVersion <version>] [-Mode <1-5>] [-Settings]'
    Write-Host
    exit
}

# Set settings directory on basis of Operating System
$script:SettingsPath = Join-Path $(if ([System.Environment]::OSVersion.Platform -match 'Win') { $env:LOCALAPPDATA } else { $env:HOME + '/.config' } ) -ChildPath 'YamlCreate'
# Check for settings directory and create it if none exists
if (!(Test-Path $script:SettingsPath)) { New-Item -ItemType 'Directory' -Force -Path $script:SettingsPath | Out-Null }
# Check for settings file and create it if none exists
$script:SettingsPath = $(Join-Path $script:SettingsPath -ChildPath 'Settings.yaml')
if (!(Test-Path $script:SettingsPath)) { '# See https://github.com/microsoft/winget-pkgs/tree/master/doc/tools/YamlCreate.md for a list of available settings' > $script:SettingsPath }
# Load settings from file
$ScriptSettings = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $script:SettingsPath -Encoding UTF8) -join "`n")

if ($Settings) {
    Invoke-Item -Path $script:SettingsPath
    exit
}

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

# Installs `powershell-yaml` as a dependency for parsing yaml content
if (-not(Get-Module -ListAvailable -Name powershell-yaml)) {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
        Install-Module -Name powershell-yaml -Force -Repository PSGallery -Scope CurrentUser
    } catch {
        # If there was an exception while installing powershell-yaml, pass it as an InternalException for further debugging
        throw [UnmetDependencyException]::new("'powershell-yaml' unable to be installed successfully", $_.Exception)
    } finally {
        # Double check that it was installed properly
        if (-not(Get-Module -ListAvailable -Name powershell-yaml)) {
            throw [UnmetDependencyException]::new("'powershell-yaml' is not found")
        }
    }
}

# Fetch Schema data from github for entry validation, key ordering, and automatic commenting
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
    # Here we want to pass the exception as an inner exception for debugging if necessary
    throw [System.Net.WebException]::new('Manifest schemas could not be downloaded. Try running the script again', $_.Exception)
}

filter TrimString {
    $_.Trim()
}

filter UniqueItems {
    [string]$($_.Split(',').Trim() | Select-Object -Unique)
}

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

# Various patterns used in validation to simplify the validation logic
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

# This function validates whether a string matches Minimum Length, Maximum Length, and Regex pattern
# The switches can be used to specify if null values are allowed regardless of validation
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

# Takes an array of strings and an array of colors then writes one line of text composed of each string being its respective color
Function Write-Colors {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]] $TextStrings,
        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Colors
    )
    If ($TextStrings.Count -ne $Colors.Count) {
        throw [System.ArgumentException]::new('Invalid Function Parameters. Arguments must be of equal length')
    }
    $_index = 0
    Foreach ($String in $TextStrings) {
        Write-Host -ForegroundColor $Colors[$_index] -NoNewline $String
        $_index++
    }
}

# Custom menu prompt that listens for keypresses. Requires a prompt and array of entries at minimum. Entries preceeded with `*` are shown in green
# Returns a console key value
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

# Checks a URL and returns the status code received from the URL
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
    } catch {
        # Take no action here; If there is an exception, we will treat it like a 404
    }
    If ($null -eq $HTTP_Response) { $HTTP_Status = 404 }
    Else { $HTTP_Response.Close() }

    return $HTTP_Status
}

# Checks a file name for validity and returns a boolean value
function Test-ValidFileName {
    param([string]$FileName)
    $IndexOfInvalidChar = $FileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
    # IndexOfAny() returns the value -1 to indicate no such character was found
    return $IndexOfInvalidChar -eq -1
}

# Prompts user to enter an Installer URL, Tests the URL to ensure it results in a response code of 200, validates it against the manifest schema
# Returns the validated URL which was entered
Function Request-Installer-Url {
    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the download url to the installer.'
        $NewInstallerUrl = Read-Host -Prompt 'Url' | TrimString
        if (String.Validate $NewInstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -MatchPattern $Patterns.InstallerUrl -NotNull) {
            if ((TestUrlValidity $NewInstallerUrl) -ne 200) {
                $script:_returnValue = [ReturnValue]::new(502, 'Invalid URL Response', 'The URL did not return a successful response from the server', 2)
            } else {
                $script:_returnValue = [ReturnValue]::Success()
            }
        } else {
            if (String.Validate -not $NewInstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -NotNull) {
                $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.InstallerUrlMaxLength)
            } elseif (String.Validate -not $NewInstallerUrl -MatchPattern $Patterns.InstallerUrl) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    return $NewInstallerUrl
}

# Prompts the user to enter installer values
# Sets the $script:Installers value as an output
# Returns void
Function Read-Installer-Values {
    # Clear prompted variables to ensure data from previous installer entries is not used for new entries
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

    # Request user enter Installer URL
    $InstallerUrl = Request-Installer-Url

    # Get or request Installer Sha256
    # Check the settings to see if we need to display this menu
    switch ($ScriptSettings.SaveToTemporaryFolder) {
        'always' { $script:SaveOption = '0' }
        'never' { $script:SaveOption = '1' }
        'manual' { $script:SaveOption = '2' }
        default {
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
        }
    }

    # If user did not select manual entry for Sha256, download file and calculate hash
    # Also attempt to detect installer type and architecture
    if ($script:SaveOption -ne '2') {
        Write-Host
        $start_time = Get-Date
        Write-Host $NewLine
        Write-Host 'Downloading URL. This will take a while...' -ForegroundColor Blue
        try {
            # Download and store the binary, but do not write to a file yet
            $download = Invoke-WebRequest -Uri $InstallerUrl -UserAgent 'winget/1.0' -DisableKeepAlive -TimeoutSec 30 -UseBasicParsing
            # Attempt to get the file from the headers
            try {
                $contentDisposition = [System.Net.Mime.ContentDisposition]::new($download.Headers['Content-Disposition'])
                $_Filename = $contentDisposition.FileName
            } catch {}
            # Validate the headers reurned a valid file name
            if (![string]::IsNullOrWhiteSpace($_Filename) -and $(Test-ValidFileName $_Filename)) {
                $Filename = $_Filename
            }
            # If the headers did not return a valid file name, build our own file name
            # Attempt to preserve the extension if it exists, otherwise, create our own
            else {
                $Filename = "$PackageIdentifier v$PackageVersion" + $(if ([System.IO.Path]::HasExtension($_Filename)) { [System.IO.Path]::GetExtension($_Filename) } elseif ([System.IO.Path]::HasExtension($InstallerUrl)) { [System.IO.Path]::GetExtension($InstallerUrl) } else { '.winget-tmp' })
            }
            # Write File to disk
            $script:dest = Join-Path -Path $env:TEMP -ChildPath $Filename
            $file = [System.IO.FileStream]::new($script:dest, [System.IO.FileMode]::Create)
            $file.Write($download.Content, 0, $download.RawContentLength)
            $file.Close()
        } catch {
            # Here we also want to pass the exception through for potential debugging
            throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
        } finally {
            Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" -ForegroundColor Green

            $InstallerSha256 = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash

            if ($script:dest -match '\.msix(bundle){0,1}$') { $InstallerType = 'msix' }
            elseif ($script:dest -match '\.msi$') { $InstallerType = 'msi' }
            elseif ($script:dest -match '\.appx(bundle){0,1}$') { $InstallerType = 'appx' }
            elseif ($script:dest -match '\.zip$') { $InstallerType = 'zip' }

            if ($InstallerUrl -match '\b(x|win){0,1}64\b') { $architecture = 'x64' }
            elseif ($InstallerUrl -match '\b((win|ia)32)|(x{0,1}86)\b') { $architecture = 'x86' }
            elseif ($InstallerUrl -match '\b(arm|aarch)64\b') { $architecture = 'arm64' }
            elseif ($InstallerUrl -match '\barm\b') { $architecture = 'arm' }

            $MSIProductCode = $(Get-AppLockerFileInformation -Path $script:dest | Select-Object Publisher | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches

            if ($script:SaveOption -eq '1' -and -not($script:dest -match '\.(msix|appx)(bundle){0,1}$')) { Remove-Item -Path $script:dest }
        }
    }
    # Manual Entry of Sha256 with validation
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

    # Manual Entry of Architecture with validation
    if ($architecture -CNotIn @($Patterns.ValidArchitectures)) {
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
    }

    # Manual Entry of Installer Type with validation
    if ($InstallerType -CNotIn @($Patterns.ValidInstallerTypes)) {
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
    }

    # If Installer Type is `exe`, require the silent switches to be entered
    if ($InstallerType -ieq 'exe') {
        # Required entry of `Silent` switches with validation
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

        # Required entry of `SilentWithProgress` swtich with validation
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
    }
    # If Installer Type is not `exe`, the silent switches are optional
    else {
        # Optional entry of `Silent` switch with validation
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

        # Optional entry of `SilentWithProgress` switch with validation
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
    }

    # Optional entry of `Custom` switches with validation for all installer types
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

    # If the installer is `msix` or `appx`, prompt for or detect additional fields
    if ($InstallerType -ieq 'msix' -or $InstallerType -ieq 'appx') {
        # Detect or prompt for Signature Sha256
        if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { $SignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() } }
        if (String.Validate $SignatureSha256 -IsNull) {
            # Manual entry of Signature Sha256 with validation
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

        # Prompt user to find package name automatically, unless package was not downloaded
        if ($script:SaveOption -eq '2' -or (!$(Test-Path $script:dest))) {
            $ChoicePfn = '1'
        } else {
            $_menu = @{
                entries       = @('*[F] Find Automatically [Note: This will install the package to find Family Name and then removes it.]'; '[M] Manually Enter PackageFamilyName')
                Prompt        = 'Discover the package family name?'
                DefaultString = 'F'
            }
            switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
                'F' { $ChoicePfn = '0' }
                'M' { $ChoicePfn = '1' }
                default { $ChoicePfn = '0' }
            }
        }

        # If user selected to find automatically -
        # Install package, get family name, uninstall package
        if ($ChoicePfn -eq '0') {
            try {
                Add-AppxPackage -Path $script:dest
                $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName, PackageFullName
                $PackageFamilyName = $InstalledPkg.PackageFamilyName
                Remove-AppxPackage $InstalledPkg.PackageFullName
            } catch {
                # Take no action here, we just want to catch the exceptions as a precaution
                Out-Null
            } finally {
                if (String.Validate $PackageFamilyName -IsNull) {
                    $script:_returnValue = [ReturnValue]::new(500, 'Could not find PackageFamilyName', 'Value should be entered manually', 1)
                }
            }
        }

        # Validate Package Family Name if found automatically
        # Allow for manual entry if selected or if validation failed
        do {
            if (($ChoicePfn -ne '0') -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
                Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
                Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the PackageFamilyName'
                $PackageFamilyName = Read-Host -Prompt 'PackageFamilyName' | TrimString
            }

            if (String.Validate $PackageFamilyName -MaxLength $Patterns.FamilyNameMaxLength -MatchPattern $Patterns.FamilyName -AllowNull) {
                if (String.Validate $PackageFamilyName -IsNull) { $PackageFamilyName = "$([char]0x2370)" }
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

    # Request installer locale with validation as optional
    do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the installer locale. For example: en-US, en-CA'
        Write-Host -ForegroundColor 'Blue' -Object 'https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
        $InstallerLocale = Read-Host -Prompt 'InstallerLocale' | TrimString
        # If user defined a default locale, add it
        if ((String.Validate $InstallerLocale -IsNull) -and (String.Validate -not $ScriptSettings.DefaultInstallerLocale -IsNull)) { $InstallerLocale = $ScriptSettings.DefaultInstallerLocale }

        if (String.Validate $InstallerLocale -MaxLength $Patterns.InstallerLocaleMaxLength -MatchPattern $Patterns.PackageLocale -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
        } else {
            if (String.Validate -not $InstallerLocale -MaxLength $Patterns.InstallerLocaleMaxLength -AllowNull) {
                $script:_returnValue = [ReturnValue]::LengthError(0, $Patterns.InstallerLocaleMaxLength)
            } elseif (String.Validate -not $InstallerLocale -MatchPattern $Patterns.PackageLocale) {
                $script:_returnValue = [ReturnValue]::PatternError()
            } else {
                $script:_returnValue = [ReturnValue]::GenericError()
            }
        }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    # Request product code with validation
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

    # Request installer scope
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

    # Request upgrade behavior
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

    # If the installers array is empty, create it
    if (!$script:Installers) {
        $script:Installers = @()
    }

    # Set up a new empty installer
    $_Installer = [ordered] @{}

    # Add the single-line parameters to the installer entry
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

    # Add the installer switches to the installer entry, if they exist
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
        $_InstallerSwitches = SortYamlKeys $_InstallerSwitches $InstallerSwitchProperties -NoComments
        $_Installer['InstallerSwitches'] = $_InstallerSwitches
    }

    # Add the product code to the installer entry, if it exists
    If ($ProductCode) { AddYamlParameter $_Installer 'ProductCode' $ProductCode }
    AddYamlParameter $_Installer 'UpgradeBehavior' $UpgradeBehavior

    # Add the completed installer to the installers array
    $_Installer = SortYamlKeys $_Installer $InstallerEntryProperties -NoComments
    $script:Installers += $_Installer

    # Prompt the user for additional intaller entries
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

    # If there are additional entries, run this function again to fetch the values and add them to the installers array
    if ($AnotherInstaller -eq '0') {
        Write-Host; Read-Installer-Values
    }
}

# Prompts user for Installer Values using the `Quick Update` Method
# Sets the $script:Installers value as an output
# Returns void
Function Read-Installer-Values-Minimal {
    # We know old manifests exist if we got here without error
    # Fetch the old installers based on the manifest type
    if ($script:OldInstallerManifest) { $_OldInstallers = $script:OldInstallerManifest['Installers'] } else {
        $_OldInstallers = $script:OldVersionManifest['Installers']
    }

    $_iteration = 0
    $_NewInstallers = @()
    foreach ($_OldInstaller in $_OldInstallers) {
        # Create the new installer as an exact copy of the old installer entry
        # This is to ensure all previously entered and un-modified parameters are retained
        $_iteration += 1
        $_NewInstaller = $_OldInstaller

        # Show the user which installer entry they should be entering information for
        Write-Host -ForegroundColor 'Green' "Installer Entry #$_iteration`:`n"
        if ($_OldInstaller.InstallerLocale) { Write-Host -ForegroundColor 'Yellow' "`tInstallerLocale: $($_OldInstaller.InstallerLocale)" }
        if ($_OldInstaller.Architecture) { Write-Host -ForegroundColor 'Yellow' "`tArchitecture: $($_OldInstaller.Architecture)" }
        if ($_OldInstaller.InstallerType) { Write-Host -ForegroundColor 'Yellow' "`tInstallerType: $($_OldInstaller.InstallerType)" }
        if ($_OldInstaller.Scope) { Write-Host -ForegroundColor 'Yellow' "`tScope: $($_OldInstaller.Scope)" }
        Write-Host

        # Request user enter the new Installer URL
        $_NewInstaller['InstallerUrl'] = Request-Installer-Url

        try {
            # Download and store the binary, but do not write to a file yet
            $download = Invoke-WebRequest -Uri $_NewInstaller['InstallerUrl'] -UserAgent 'winget/1.0' -DisableKeepAlive -TimeoutSec 30 -UseBasicParsing
            # Attempt to get the file from the headers
            try {
                $contentDisposition = [System.Net.Mime.ContentDisposition]::new($download.Headers['Content-Disposition'])
                $_Filename = $contentDisposition.FileName
            } catch {}
            # Validate the headers reurned a valid file name
            if (![string]::IsNullOrWhiteSpace($_Filename) -and $(Test-ValidFileName $_Filename)) {
                $Filename = $_Filename
            }
            # If the headers did not return a valid file name, build our own file name
            # Attempt to preserve the extension if it exists, otherwise, create our own
            else {
                $Filename = "$PackageIdentifier v$PackageVersion" + $(if ([System.IO.Path]::HasExtension($_Filename)) { [System.IO.Path]::GetExtension($_Filename) } elseif ([System.IO.Path]::HasExtension($InstallerUrl)) { [System.IO.Path]::GetExtension($InstallerUrl) } else { '.winget-tmp' })
            }
            # Write File to disk
            $script:dest = Join-Path -Path $env:TEMP -ChildPath $Filename
            $file = [System.IO.FileStream]::new($script:dest, [System.IO.FileMode]::Create)
            $file.Write($download.Content, 0, $download.RawContentLength)
            $file.Close()
        } catch {
            # Here we also want to pass the exception through for potential debugging
            throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
        } finally {
            # Get the Sha256
            $_NewInstaller['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
            # Update the product code, if a new one exists
            # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
            $MSIProductCode = [string]$(Get-AppLockerFileInformation -Path $script:dest | Select-Object Publisher | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches
            if (String.Validate -not $MSIProductCode -IsNull) {
                $_NewInstaller['ProductCode'] = $MSIProductCode
            } elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ($script:dest -notmatch '.exe$')) {
                $_NewInstaller.Remove('ProductCode')
            }
            # If the installer is msix or appx, try getting the new SignatureSha256
            # If the new SignatureSha256 can't be found, remove it if it exists
            if ($_NewInstaller.InstallerType -in @('msix', 'appx')) {
                if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { $NewSignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() } }
            }
            if (String.Validate -not $NewSignatureSha256 -IsNull) {
                $_NewInstaller['SignatureSha256'] = $NewSignatureSha256
            } elseif ($_NewInstaller.Keys -contains 'SignatureSha256') {
                $_NewInstaller.Remove('SignatureSha256')
            }
            # If the installer is msix or appx, try getting the new package family name
            # If the new package family name can't be found, remove it if it exists
            if ($script:dest -match '\.(msix|appx)(bundle){0,1}$') {
                try {
                    Add-AppxPackage -Path $script:dest
                    $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName, PackageFullName
                    $PackageFamilyName = $InstalledPkg.PackageFamilyName
                    Remove-AppxPackage $InstalledPkg.PackageFullName
                } catch {
                    # Take no action here, we just want to catch the exceptions as a precaution
                    Out-Null
                } finally {
                    if (String.Validate -not $PackageFamilyName -IsNull) {
                        $_NewInstaller['PackageFamilyName'] = $PackageFamilyName
                    } elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') {
                        $_NewInstaller.Remove('PackageFamilyName')
                    }
                }
            }
            # Remove the downloaded files
            Remove-Item -Path $script:dest
        }
        #Add the updated installer to the new installers array
        $_NewInstaller = SortYamlKeys $_NewInstaller $InstallerEntryProperties -NoComments
        $_NewInstallers += $_NewInstaller
    }
    $script:Installers = $_NewInstallers
}

# Requests the user enter an optional value with a prompt
# If the value already exists, also print the existing value
# Returns the new value if entered, Returns the existing value if no new value was entered
Function PromptInstallerManifestValue {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
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

# Sorts keys within an object based on a reference ordered dictionary
# If a key does not exist, it sets the value to a special character to be removed / commented later
# Returns the result as a new object
Function SortYamlKeys {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject] $InputObject,
        [Parameter(Mandatory = $true, Position = 1)]
        [PSCustomObject] $SortOrder,
        [switch] $NoComments
    )

    $_ExcludedKeys = @(
        'InstallerSwitches'
        'Capabilities'
        'RestrictedCapabilities'
        'InstallerSuccessCodes'
        'ProductCode'
        'PackageFamilyName'
        'InstallerLocale'
        'InstallerType'
        'Scope'
        'UpgradeBehavior'
        'Dependencies'
    )

    $_Temp = [ordered] @{}
    $SortOrder.GetEnumerator() | ForEach-Object {
        if ($InputObject.Contains($_)) {
            $_Temp.Add($_, $InputObject[$_])
        } else {
            if (!$NoComments -and $_ -notin $_ExcludedKeys) {
                $_Temp.Add($_, "$([char]0x2370)")
            }
        }
    }
    return $_Temp
}

# Requests the user to input optional values for the Installer Manifest file
Function Read-WinGet-InstallerManifest {
    Write-Host

    # Request File Extensions and validate
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

    # Request Protocols and validate
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

    # Request Commands and validate
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

    # Request Installer Success Codes and validate
    do {
        if (!$InstallerSuccessCodes) { $InstallerSuccessCodes = '' }
        $script:InstallerSuccessCodes = PromptInstallerManifestValue $InstallerSuccessCodes 'InstallerSuccessCodes' "[Optional] List of additional non-zero installer success exit codes other than known default values by winget (Max $($Patterns.MaxItemsSuccessCodes))" | UniqueItems
        if (($script:InstallerSuccessCodes -split ',').Count -le $Patterns.MaxItemsSuccessCodes) {
            $script:_returnValue = [ReturnValue]::Success()
            try {
                #Ensure all values are integers
                $script:InstallerSuccessCodes.Split(',').Trim()| ForEach-Object {[long]$_}
                $script:_returnValue = [ReturnValue]::Success()
            } catch {
                $script:_returnValue = [ReturnValue]::new(400,"Invalid Data Type","The value entered does not match the type requirements defined in the manifest schema")
            }
        } else {
            $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsSuccessCodes)
        }
    }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    # Request Install Modes and validate
    do {
        if ($script:InstallModes) { $script:InstallModes = $script:InstallModes | UniqueItems }
        $script:InstallModes = PromptInstallerManifestValue $script:InstallModes 'InstallModes' "[Optional] List of supported installer modes. Options: $($Patterns.ValidInstallModes -join ', ')"
        if ($script:InstallModes) { $script:InstallModes = $script:InstallModes | UniqueItems }
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

# Requests the user to input values for the Locale Manifest file
Function Read-WinGet-LocaleManifest {
    # Request Package Locale and Validate
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

    # Request Publisher Name and Validate
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

    # Request Application Name and Validate
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

    # If the option is `NewLocale` then these moniker should already exist
    # If the option is not `NewLocale`, Request Moniker and Validate
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

    #Request Publisher URL and Validate
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

    # Request Publisher Support URL and Validate
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

    # Request Publisher Privacy URL and Validate
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

    # Request Author and Validate
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

    # Request Package URL and Validate
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

    # Request License and Validate
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

    # Request License URL and Validate
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

    # Request Copyright and Validate
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

    # Request Copyright URL and Validate
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

    # Request Tags and Validate
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

    # Request Short Description and Validate
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

    # Request Long Description and Validate
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

# Requests the user to answer the prompts found in the winget-pkgs pull request template
# Uses this template and responses to create a PR
Function Enter-PR-Parameters {
    $PrBodyContent = Get-Content $args[0]
    ForEach ($_line in ($PrBodyContent | Where-Object { $_ -like '-*[ ]*' })) {
        $_showMenu = $true
        switch -Wildcard ( $_line ) {
            '*CLA*' {
                if ($ScriptSettings.SignedCLA -eq 'true') {
                    $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
                    $_showMenu = $false
                } else {
                    $_menu = @{
                        Prompt        = 'Have you signed the Contributor License Agreement (CLA)?'
                        Entries       = @('[Y] Yes'; '*[N] No')
                        HelpText      = 'Reference Link: https://cla.opensource.microsoft.com/microsoft/winget-pkgs'
                        HelpTextColor = ''
                        DefaultString = 'N'
                    }
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

    # Request user to enter if there were any issues resolved by the PR
    $_menu = @{
        entries       = @('[Y] Yes'; '*[N] No')
        Prompt        = 'Does this pull request resolve any issues?'
        DefaultString = 'N'
    }
    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'Y' {
            # If there were issues resolved by the PR, request user to enter them
            Write-Host
            Write-Host "Enter issue number. For example`: 21983, 43509"
            $ResolvedIssues = Read-Host -Prompt 'Resolved Issues' | UniqueItems
            $PrBodyContentReply += @('')

            # Validate each of the issues entered by checking the URL to ensure it returns a 200 status code
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
                    $PrBodyContentReply += @("* Resolves #$i")
                }
            }
        }
        default { Write-Host }
    }

    # If we are removing a manifest, we need to include the reason
    if ($CommitType -eq 'Remove') {
        $PrBodyContentReply = @("## $($script:RemovalReason)"; '') + $PrBodyContentReply
    }

    # Write the PR using a temporary file
    Set-Content -Path PrBodyFile -Value $PrBodyContentReply | Out-Null
    gh pr create --body-file PrBodyFile -f
    Remove-Item PrBodyFile
}

# Takes a comma separated list of values, converts it to an array object, and adds the result to a specified object-key
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
        $_Values += $Value
    }
    $Object[$Parameter] = $_Values
}

# Takes a single value and adds it to a specified object-key
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

# Fetch the value of a manifest value regardless of which manifest file it exists in
Function GetMultiManifestParameter {
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter
    )
    $_vals = $($script:OldInstallerManifest[$Parameter] + $script:OldLocaleManifest[$Parameter] + $script:OldVersionManifest[$Parameter] | Where-Object { $_ })
    return ($_vals -join ', ')
}

Function GetDebugString {
    $debug = ' $debug='
    $debug += $(switch ($script:Option) {
            'New' { 'NV' }
            'QuickUpdateVersion' { 'QU' }
            'EditMetadata' { 'MD' }
            'NewLocale' { 'NL' }
            'Auto' { 'AU' }
            Default { 'XX' }
        })
    $debug += $(
        switch ($script:SaveOption) {
            '0' { 'S0.' }
            '1' { 'S1.' }
            '2' { 'S2.' }
            Default { 'SU.' }
        }
    )
    $debug += $PSVersionTable.PSVersion -Replace '\.', '-'
    return $debug
}

# Take all the entered values and write the version manifest file
Function Write-Version-Manifest {
    # Create new empty manifest
    [PSCustomObject]$VersionManifest = [ordered]@{}

    # Write these values into the manifest
    $_Singletons = [ordered]@{
        'PackageIdentifier' = $PackageIdentifier
        'PackageVersion'    = $PackageVersion
        'DefaultLocale'     = if ($PackageLocale) { $PackageLocale } else { 'en-US' }
        'ManifestType'      = 'version'
        'ManifestVersion'   = $ManifestVersion
    }
    foreach ($_Item in $_Singletons.GetEnumerator()) {
        If ($_Item.Value) { AddYamlParameter $VersionManifest $_Item.Name $_Item.Value }
    }
    $VersionManifest = SortYamlKeys $VersionManifest $VersionProperties

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $VersionManifestPath = $AppFolder + "\$PackageIdentifier" + '.yaml'

    # Write the manifest to the file
    $ScriptHeader + "$(GetDebugString)`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.1.0.0.schema.json`n" > $VersionManifestPath
    ConvertTo-Yaml $VersionManifest >> $VersionManifestPath
    $(Get-Content $VersionManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $VersionManifestPath -Force
    $MyRawString = Get-Content -Raw $VersionManifestPath | TrimString
    [System.IO.File]::WriteAllLines($VersionManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $VersionManifestPath"
}

# Take all the entered values and write the installer manifest file
Function Write-Installer-Manifest {
    # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
    if ($script:OldManifestType -eq 'MultiManifest') {
        $InstallerManifest = $script:OldInstallerManifest
    }
    if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

    #Add the properties to the manifest
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
        $InstallerManifest['Dependencies'] = SortYamlKeys $InstallerManifest['Dependencies'] $InstallerDependencyProperties -NoComments
    }
    # Move Installer Level Keys to Manifest Level
    $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties }
    foreach ($_Key in $_KeysToMove) {
        if ($_Key -in $InstallerManifest.Installers[0].Keys) {
            # Handle the switches specially
            if ($_Key -eq 'InstallerSwitches') {
                # Go into each of the subkeys to see if they are the same
                foreach ($_InstallerSwitchKey in $InstallerManifest.Installers[0].$_Key.Keys) {
                    $_AllAreSame = $true
                    $_FirstInstallerSwitchKeyValue = ConvertTo-Json($InstallerManifest.Installers[0].$_Key.$_InstallerSwitchKey)
                    foreach ($_Installer in $InstallerManifest.Installers) {
                        $_CurrentInstallerSwitchKeyValue = ConvertTo-Json($_Installer.$_Key.$_InstallerSwitchKey)
                        if (String.Validate $_CurrentInstallerSwitchKeyValue -IsNull) { $_AllAreSame = $false }
                        else { $_AllAreSame = $_AllAreSame -and (@(Compare-Object $_CurrentInstallerSwitchKeyValue $_FirstInstallerSwitchKeyValue).Length -eq 0) }
                    }
                    if ($_AllAreSame) {
                        if ($_Key -notin $InstallerManifest.Keys) { $InstallerManifest[$_Key] = @{} }
                        $InstallerManifest.$_Key[$_InstallerSwitchKey] = $InstallerManifest.Installers[0].$_Key.$_InstallerSwitchKey
                    }
                }
                # Remove them from the individual installer switches if we moved them to the manifest level
                if ($_Key -in $InstallerManifest.Keys) {
                    foreach ($_InstallerSwitchKey in $InstallerManifest.$_Key.Keys) {
                        foreach ($_Installer in $InstallerManifest.Installers) {
                            if ($_Installer.Keys -contains $_Key) {
                                if ($_Installer.$_Key.Keys -contains $_InstallerSwitchKey) { $_Installer.$_Key.Remove($_InstallerSwitchKey) }
                                if (@($_Installer.$_Key.Keys).Count -eq 0) { $_Installer.Remove($_Key) }
                            }
                        }
                    }
                }
            } else {
                # Check if all installers are the same
                $_AllAreSame = $true
                $_FirstInstallerKeyValue = ConvertTo-Json($InstallerManifest.Installers[0].$_Key)
                foreach ($_Installer in $InstallerManifest.Installers) {
                    $_CurrentInstallerKeyValue = ConvertTo-Json($_Installer.$_Key)
                    if (String.Validate $_CurrentInstallerKeyValue -IsNull) { $_AllAreSame = $false }
                    else { $_AllAreSame = $_AllAreSame -and (@(Compare-Object $_CurrentInstallerKeyValue $_FirstInstallerKeyValue).Length -eq 0) }
                }
                # If all installers are the same move the key to the manifest level
                if ($_AllAreSame) {
                    $InstallerManifest[$_Key] = $InstallerManifest.Installers[0].$_Key
                    foreach ($_Installer in $InstallerManifest.Installers) {
                        $_Installer.Remove($_Key)
                    }
                }
            }
        }
    }
    if ($InstallerManifest.Keys -contains 'InstallerSwitches') { $InstallerManifest['InstallerSwitches'] = SortYamlKeys $InstallerManifest.InstallerSwitches $InstallerSwitchProperties -NoComments }
    foreach ($_Installer in $InstallerManifest.Installers) {
        if ($_Installer.Keys -contains 'InstallerSwitches') { $_Installer['InstallerSwitches'] = SortYamlKeys $_Installer.InstallerSwitches $InstallerSwitchProperties -NoComments }
    }
    $InstallerManifest = SortYamlKeys $InstallerManifest $InstallerProperties -NoComments

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $InstallerManifestPath = $AppFolder + "\$PackageIdentifier" + '.installer' + '.yaml'

    # Write the manifest to the file
    $ScriptHeader + "$(GetDebugString)`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.1.0.0.schema.json`n" > $InstallerManifestPath
    ConvertTo-Yaml $InstallerManifest >> $InstallerManifestPath
    $(Get-Content $InstallerManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $InstallerManifestPath -Force
    $MyRawString = Get-Content -Raw $InstallerManifestPath | TrimString
    [System.IO.File]::WriteAllLines($InstallerManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $InstallerManifestPath"
}

# Take all the entered values and write the locale manifest file
Function Write-Locale-Manifests {
    # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
    if ($script:OldManifestType -eq 'MultiManifest') {
        $LocaleManifest = $script:OldLocaleManifest
    }
    if (!$LocaleManifest) { [PSCustomObject]$LocaleManifest = [ordered]@{} }

    # Set the appropriate langage server depending on if it is a default locale file or generic locale file
    if ($LocaleManifest.ManifestType -eq 'defaultLocale') { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.0.0.schema.json' } else { $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json' }

    # Add the properties to the manifest
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
    If (!$LocaleManifest.ManifestType) { $LocaleManifest['ManifestType'] = 'defaultLocale' }
    If ($Moniker -and $($LocaleManifest.ManifestType -eq 'defaultLocale')) { AddYamlParameter $LocaleManifest 'Moniker' $Moniker }
    AddYamlParameter $LocaleManifest 'ManifestVersion' $ManifestVersion
    $LocaleManifest = SortYamlKeys $LocaleManifest $LocaleProperties

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $script:LocaleManifestPath = $AppFolder + "\$PackageIdentifier" + '.locale.' + "$PackageLocale" + '.yaml'

    # Write the manifest to the file
    $ScriptHeader + "$(GetDebugString)`n$yamlServer`n" > $LocaleManifestPath
    ConvertTo-Yaml $LocaleManifest >> $LocaleManifestPath
    $(Get-Content $LocaleManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $LocaleManifestPath -Force
    $MyRawString = Get-Content -Raw $LocaleManifestPath | TrimString
    [System.IO.File]::WriteAllLines($LocaleManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Copy over all locale files from previous version that aren't the same
    if ($OldManifests) {
        ForEach ($DifLocale in $OldManifests) {
            if ($DifLocale.Name -notin @("$PackageIdentifier.yaml", "$PackageIdentifier.installer.yaml", "$PackageIdentifier.locale.$PackageLocale.yaml")) {
                if (!(Test-Path $AppFolder)) { New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null }
                $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $DifLocale.FullName -Encoding UTF8) -join "`n") -Ordered
                $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
                if ($script:OldLocaleManifest.Keys -contains 'Moniker') { $script:OldLocaleManifest.Remove('Moniker') }
                $script:OldLocaleManifest = SortYamlKeys $script:OldLocaleManifest $LocaleProperties

                $yamlServer = '# yaml-language-server: $schema=https://aka.ms/winget-manifest.locale.1.0.0.schema.json'

                $ScriptHeader + "$(GetDebugString)`n$yamlServer`n" > ($AppFolder + '\' + $DifLocale.Name)
                ConvertTo-Yaml $OldLocaleManifest >> ($AppFolder + '\' + $DifLocale.Name)
                $(Get-Content $($AppFolder + '\' + $DifLocale.Name) -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $($AppFolder + '\' + $DifLocale.Name) -Force
                $MyRawString = Get-Content -Raw $($AppFolder + '\' + $DifLocale.Name) | TrimString
                [System.IO.File]::WriteAllLines($($AppFolder + '\' + $DifLocale.Name), $MyRawString, $Utf8NoBomEncoding)
            }
        }
    }

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $LocaleManifestPath"
}

function Remove-Manifest-Version {
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $PathToVersion
    )

    # Remove the manifest, and then any parent folders so long as the parent folders are empty
    do {
        Remove-Item -Path $PathToVersion -Recurse -Force
        $PathToVersion = Split-Path $PathToVersion
    } while (@(Get-ChildItem $PathToVersion).Count -eq 0)
}

# Initialize the return value to be a success
$script:_returnValue = [ReturnValue]::new(200)

$script:UsingAdvancedOption = ($ScriptSettings.EnableDeveloperOptions -eq 'true') -and ($AutoUpgrade)

if (!$script:UsingAdvancedOption) {
    # Request the user to choose an operation mode
    Clear-Host
    if ($Mode -in 1..5) {
        $UserChoice = $Mode
    } else {
        Write-Host -ForegroundColor 'Yellow' "Select Mode:`n"
        Write-Colors '  [', '1', "] New Manifest or Package Version`n" 'DarkCyan', 'White', 'DarkCyan'
        Write-Colors '  [', '2', '] Quick Update Package Version ', "(Note: Must be used only when previous version`'s metadata is complete.)`n" 'DarkCyan', 'White', 'DarkCyan', 'Green'
        Write-Colors '  [', '3', "] Update Package Metadata`n" 'DarkCyan', 'White', 'DarkCyan'
        Write-Colors '  [', '4', "] New Locale`n" 'DarkCyan', 'White', 'DarkCyan'
        Write-Colors '  [', '5', "] Remove a manifest`n" 'DarkCyan', 'White', 'DarkCyan'
        Write-Colors '  [', 'Q', ']', " Any key to quit`n" 'DarkCyan', 'White', 'DarkCyan', 'Red'
        Write-Colors "`nSelection: " 'White'

        # Listen for keypress and set operation mode based on keypress
        $Keys = @{
            [ConsoleKey]::D1      = '1';
            [ConsoleKey]::D2      = '2';
            [ConsoleKey]::D3      = '3';
            [ConsoleKey]::D4      = '4';
            [ConsoleKey]::D5      = '5';
            [ConsoleKey]::NumPad1 = '1';
            [ConsoleKey]::NumPad2 = '2';
            [ConsoleKey]::NumPad3 = '3';
            [ConsoleKey]::NumPad4 = '4';
            [ConsoleKey]::NumPad5 = '5';
        }
        do {
            $keyInfo = [Console]::ReadKey($false)
        } until ($keyInfo.Key)

        $UserChoice = $Keys[$keyInfo.Key]
    }
    switch ($UserChoice) {
        '1' { $script:Option = 'New' }
        '2' { $script:Option = 'QuickUpdateVersion' }
        '3' { $script:Option = 'EditMetadata' }
        '4' { $script:Option = 'NewLocale' }
        '5' { $script:Option = 'RemoveManifest' }
        default { Write-Host; exit }
    }
} else {
    if ($AutoUpgrade) { $script:Option = 'Auto' }
}

# Confirm the user undertands the implications of using the quick update mode
if (($script:Option -eq 'QuickUpdateVersion') -and ($ScriptSettings.SuppressQuickUpdateWarning -ne 'true')) {
    $_menu = @{
        entries       = @('[Y] Continue with Quick Update'; '[N] Use Full Update Experience'; '*[Q] Exit Script')
        Prompt        = 'Quick Updates only allow for changes to the existing Installer URLs, Sha256 Values, and Product Codes. Are you sure you want to continue?'
        HelpText      = 'This mode should be used with caution. If you are not 100% certain this is correct, please use Option 1 to go through the full update experience'
        HelpTextColor = 'Red'
        DefaultString = 'Q'
    }
    switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
        'Y' { Write-Host -ForegroundColor DarkYellow -Object "`n`nContinuing with Quick Update" }
        'N' { $script:Option = 'New'; Write-Host -ForegroundColor DarkYellow -Object "`n`nSwitched to Full Update Experience" }
        default { Write-Host; exit }
    }
}
Write-Host

# Request Package Identifier and Validate
do {
    if ((String.Validate $PackageIdentifier -IsNull) -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
        $script:PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
    }

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

# Request Package Version and Validate
do {
    if ((String.Validate $PackageVersion -IsNull) -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
        $script:PackageVersion = Read-Host -Prompt 'Version' | TrimString
    }
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

# Check the api for open PR's
# This is unauthenticated because the call-rate per minute is assumed to be low
if ($ScriptSettings.ContinueWithExistingPRs -ne 'always' -and $script:Option -ne 'RemoveManifest') {
    $PRApiResponse = @(Invoke-WebRequest "https://api.github.com/search/issues?q=repo%3Amicrosoft%2Fwinget-pkgs%20is%3Apr%20$($PackageIdentifier -replace '\.', '%2F'))%2F$PackageVersion%20in%3Apath&per_page=1" -UseBasicParsing -ErrorAction SilentlyContinue | ConvertFrom-Json)[0]
    # If there was a PR found, get the URL and title
    if ($PRApiResponse.total_count -gt 0) {
        $_PRUrl = $PRApiResponse.items.html_url
        $_PRTitle = $PRApiResponse.items.title
        if ($ScriptSettings.ContinueWithExistingPRs -eq 'never') { Write-Host -ForegroundColor Red "Existing PR Found - $_PRUrl"; exit }
        $_menu = @{
            entries       = @('[Y] Yes'; '*[N] No')
            Prompt        = 'There may already be a PR for this change. Would you like to continue anyways?'
            DefaultString = 'N'
            HelpText      = "$_PRTitle - $_PRUrl"
            HelpTextColor = 'Blue'
        }
        switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor'] ) {
            'Y' { Write-Host }
            default { Write-Host; exit }
        }
    }
}

# Set the root folder where new manifests should be created
if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path '.\').Path
}

# Set the folder for the specific package and version
$script:AppFolder = Join-Path $ManifestsFolder -ChildPath $PackageIdentifier.ToLower().Chars(0) | Join-Path -ChildPath $PackageIdentifierFolder | Join-Path -ChildPath $PackageVersion

# If the user selected `NewLocale` or `EditMetadata` the version *MUST* already exist in the folder structure
if ($script:Option -in @('NewLocale'; 'EditMetadata'; 'RemoveManifest')) {
    # Try getting the old manifests from the specified folder
    if (Test-Path -Path "$AppFolder\..\$PackageVersion") {
        $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$PackageVersion"
        $LastVersion = $PackageVersion
    }
    # If the old manifests could not be found, request a new version
    while (-not ($OldManifests.Name -like "$PackageIdentifier*.yaml")) {
        Write-Host
        Write-Host -ForegroundColor 'Red' -Object 'Could not find required manifests, input a version containing required manifests or "exit" to cancel'
        $PromptVersion = Read-Host -Prompt 'Version' | TrimString
        if ($PromptVersion -eq 'exit') { exit }
        if (Test-Path -Path "$AppFolder\..\$PromptVersion") {
            $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$PromptVersion"
        }
        # If a new version is entered, we need to be sure to update the folder for writing manifests
        $LastVersion = $PromptVersion
        $script:AppFolder = (Split-Path $AppFolder) + "\$LastVersion"
        $script:PackageVersion = $LastVersion
    }
}

# If the user selected `QuickUpdateVersion`, the old manifests must exist
# If the user selected `New`, the old manifest type is specified as none
if (-not (Test-Path -Path "$AppFolder\..")) {
    if ($script:Option -in @('QuickUpdateVersion', 'Auto')) { Write-Host -ForegroundColor Red 'This option requires manifest of previous version of the package. If you want to create a new package, please select Option 1.'; exit }
    $script:OldManifestType = 'None'
}

# Try getting the last version of the package and the old manifests to be updated
if (!$LastVersion) {
    try {
        $script:LastVersion = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml' -ErrorAction SilentlyContinue).FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Last 1
        $script:ExistingVersions = Split-Path (Split-Path (Get-ChildItem -Path "$AppFolder\..\" -Recurse -Depth 1 -File -Filter '*.yaml' -ErrorAction SilentlyContinue).FullName ) -Leaf | Sort-Object $ToNatural | Select-Object -Unique
        if ($script:Option -eq 'Auto' -and $PackageVersion -in $script:ExistingVersions) { $LastVersion = $PackageVersion }
        Write-Host -ForegroundColor 'DarkYellow' -Object "Found Existing Version: $LastVersion"
        $script:OldManifests = Get-ChildItem -Path "$AppFolder\..\$LastVersion"
    } catch {
        # Take no action here, we just want to catch the exceptions as a precaution
        Out-Null
    }
}

# If the old manifests exist, find the default locale
if ($OldManifests.Name -match "$([Regex]::Escape($PackageIdentifier))\.locale\..*\.yaml") {
    $_LocaleManifests = $OldManifests | Where-Object { $_.Name -match "$([Regex]::Escape($PackageIdentifier))\.locale\..*\.yaml" }
    foreach ($_Manifest in $_LocaleManifests) {
        $_ManifestContent = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $($_Manifest.FullName) -Encoding UTF8) -join "`n") -Ordered
        if ($_ManifestContent.ManifestType -eq 'defaultLocale') { $PackageLocale = $_ManifestContent.PackageLocale }
    }
}

# If the old manifests exist, read their information into variables
# Also ensure additional requirements are met for creating or updating files
if ($OldManifests.Name -eq "$PackageIdentifier.installer.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.locale.$PackageLocale.yaml" -and $OldManifests.Name -eq "$PackageIdentifier.yaml") {
    $script:OldManifestType = 'MultiManifest'
    $script:OldInstallerManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.installer.yaml") -Encoding UTF8) -join "`n") -Ordered
    # Move Manifest Level Keys to installer Level
    $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties }
    foreach ($_Key in $_KeysToMove) {
        if ($_Key -in $script:OldInstallerManifest.Keys) {
            # Handle Installer switches separately
            if ($_Key -eq 'InstallerSwitches') {
                $_SwitchKeysToMove = $script:OldInstallerManifest.$_Key.Keys
                foreach ($_SwitchKey in $_SwitchKeysToMove) {
                    # If the InstallerSwitches key doesn't exist, we need to create it, otherwise, preserve switches that were already there
                    foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
                        if ('InstallerSwitches' -notin $_Installer.Keys) { $_Installer['InstallerSwitches'] = @{} }
                        $_Installer.InstallerSwitches["$_SwitchKey"] = $script:OldInstallerManifest.$_Key.$_SwitchKey
                    }
                }
                $script:OldInstallerManifest.Remove($_Key)
                continue
            } else {
                foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
                    if ($_Key -eq 'InstallModes') { $script:InstallModes = [string]$script:OldInstallerManifest.$_Key }
                    $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
                }
            }
            New-Variable -Name $_Key -Value $($script:OldInstallerManifest.$_Key -join ', ') -Scope Script -Force
            $script:OldInstallerManifest.Remove($_Key)
        }
    }
    $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.$PackageLocale.yaml") -Encoding UTF8) -join "`n") -Ordered
    $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
} elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
    if ($script:Option -eq 'NewLocale') { throw [ManifestException]::new('MultiManifest Required') }
    $script:OldManifestType = 'MultiManifest'
    $script:OldSingletonManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
    $PackageLocale = $script:OldSingletonManifest.PackageLocale
    # Create new empty manifests
    $script:OldInstallerManifest = [ordered]@{}
    $script:OldLocaleManifest = [ordered]@{}
    $script:OldVersionManifest = [ordered]@{}
    # Parse version keys to version manifest
    foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $VersionProperties })) {
        $script:OldVersionManifest[$_Key] = $script:OldSingletonManifest.$_Key
    }
    $script:OldVersionManifest['ManifestType'] = 'version'
    #Parse locale keys to locale manifest
    foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $LocaleProperties })) {
        $script:OldLocaleManifest[$_Key] = $script:OldSingletonManifest.$_Key
    }
    $script:OldLocaleManifest['ManifestType'] = 'defaultLocale'
    #Parse installer keys to installer manifest
    foreach ($_Key in $($OldSingletonManifest.Keys | Where-Object { $_ -in $InstallerProperties })) {
        $script:OldInstallerManifest[$_Key] = $script:OldSingletonManifest.$_Key
    }
    $script:OldInstallerManifest['ManifestType'] = 'installer'
    # Move Manifest Level Keys to installer Level
    $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties }
    foreach ($_Key in $_KeysToMove) {
        if ($_Key -in $script:OldInstallerManifest.Keys) {
            # Handle Installer switches separately
            if ($_Key -eq 'InstallerSwitches') {
                $_SwitchKeysToMove = $script:OldInstallerManifest.$_Key.Keys
                foreach ($_SwitchKey in $_SwitchKeysToMove) {
                    # If the InstallerSwitches key doesn't exist, we need to create it, otherwise, preserve switches that were already there
                    foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
                        if ('InstallerSwitches' -notin $_Installer.Keys) { $_Installer['InstallerSwitches'] = @{} }
                        $_Installer.InstallerSwitches["$_SwitchKey"] = $script:OldInstallerManifest.$_Key.$_SwitchKey
                    }
                }
                $script:OldInstallerManifest.Remove($_Key)
                continue
            } else {
                foreach ($_Installer in $script:OldInstallerManifest['Installers']) {
                    if ($_Key -eq 'InstallModes') { $script:InstallModes = [string]$script:OldInstallerManifest.$_Key }
                    $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
                }
            }
            New-Variable -Name $_Key -Value $($script:OldInstallerManifest.$_Key -join ', ') -Scope Script -Force
            $script:OldInstallerManifest.Remove($_Key)
        }
    }
} else {
    if ($script:Option -ne 'New') { throw [ManifestException]::new("Version $LastVersion does not contain the required manifests") }
    $script:OldManifestType = 'None'
}

# If the old manifests exist, read the manifest keys into their specific variables
if ($OldManifests -and $Option -ne 'NewLocale') {
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
        'InstallerSuccessCodes'
        'Capabilities'; 'RestrictedCapabilities'
    )
    Foreach ($param in $_Parameters) {
        $_ReadValue = $(if ($script:OldManifestType -eq 'MultiManifest') { (GetMultiManifestParameter $param) } else { $script:OldVersionManifest[$param] })
        if (String.Validate -Not $_ReadValue -IsNull) { New-Variable -Name $param -Value $_ReadValue -Scope Script -Force }
    }
}

# Run the data entry and creation of manifests appropriate to the option the user selected
Switch ($script:Option) {
    'QuickUpdateVersion' {
        Read-Installer-Values-Minimal
        Write-Locale-Manifests
        Write-Installer-Manifest
        Write-Version-Manifest
    }

    'New' {
        Read-Installer-Values
        Read-WinGet-InstallerManifest
        Read-WinGet-LocaleManifest
        Write-Installer-Manifest
        Write-Version-Manifest
        Write-Locale-Manifests
    }

    'EditMetadata' {
        Read-WinGet-InstallerManifest
        Read-WinGet-LocaleManifest
        Write-Installer-Manifest
        Write-Version-Manifest
        Write-Locale-Manifests
    }

    'NewLocale' {
        $PackageLocale = $null
        $script:OldLocaleManifest = [ordered]@{}
        $script:OldLocaleManifest['ManifestType'] = 'locale'
        Read-WinGet-LocaleManifest
        Write-Locale-Manifests
    }

    'RemoveManifest' {
        # Confirm the user is sure they know what they are doing
        $_menu = @{
            entries       = @("[Y] Remove $PackageIdentifier version $PackageVersion"; '*[N] Cancel')
            Prompt        = 'Are you sure you want to continue?'
            HelpText      = "Manifest Versions should only be removed when necessary`n"
            HelpTextColor = 'Red'
            DefaultString = 'N'
        }
        switch ( KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
            'Y' { Write-Host; continue }
            default { Write-Host; exit 1 }
        }

        # Require that a reason for the deletion is provided
        do {
            Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
            Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the reason for removing this manifest'
            $script:RemovalReason = Read-Host -Prompt 'Reason' | TrimString
            # Check the reason for validity. The length requirements are arbitrary, but they have been set to encourage concise yet meaningful reasons
            if (String.Validate $script:RemovalReason -MinLength 8 -MaxLength 128 -NotNull) {
                $script:_returnValue = [ReturnValue]::Success()
            } else {
                $script:_returnValue = [ReturnValue]::LengthError(8, 128)
            }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        Remove-Manifest-Version $AppFolder
    }

    'Auto' {
        # Set new package version
        $script:OldInstallerManifest['PackageVersion'] = $PackageVersion
        $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
        $script:OldVersionManifest['PackageVersion'] = $PackageVersion

        # Update the manifest with URLs that are already there
        Write-Host $NewLine
        Write-Host 'Updating Manifest Information. This may take a while...' -ForegroundColor Blue
        foreach ($_Installer in $script:OldInstallerManifest.Installers) {
            try {
                # Download and store the binary, but do not write to a file yet
                $download = Invoke-WebRequest -Uri $_Installer.InstallerUrl -UserAgent 'winget/1.0' -DisableKeepAlive -TimeoutSec 30 -UseBasicParsing
                # Attempt to get the file from the headers
                try {
                    $contentDisposition = [System.Net.Mime.ContentDisposition]::new($download.Headers['Content-Disposition'])
                    $_Filename = $contentDisposition.FileName
                } catch {}
                # Validate the headers reurned a valid file name
                if (![string]::IsNullOrWhiteSpace($_Filename) -and $(Test-ValidFileName $_Filename)) {
                    $Filename = $_Filename
                }
                # If the headers did not return a valid file name, build our own file name
                # Attempt to preserve the extension if it exists, otherwise, create our own
                else {
                    $Filename = "$PackageIdentifier v$PackageVersion" + $(if ([System.IO.Path]::HasExtension($_Filename)) { [System.IO.Path]::GetExtension($_Filename) } elseif ([System.IO.Path]::HasExtension($InstallerUrl)) { [System.IO.Path]::GetExtension($InstallerUrl) } else { '.winget-tmp' })
                }
                # Write File to disk
                $script:dest = Join-Path -Path $env:TEMP -ChildPath $Filename
                $file = [System.IO.FileStream]::new($script:dest, [System.IO.FileMode]::Create)
                $file.Write($download.Content, 0, $download.RawContentLength)
                $file.Close()
            } catch {
                # Here we also want to pass the exception through for potential debugging
                throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
            } finally {
                # Get the Sha256
                $_Installer['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
                # Update the product code, if a new one exists
                # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
                $MSIProductCode = [string]$(Get-AppLockerFileInformation -Path $script:dest | Select-Object Publisher | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches
                if (String.Validate -not $MSIProductCode -IsNull) {
                    $_Installer['ProductCode'] = $MSIProductCode
                } elseif ( ($_Installer.Keys -contains 'ProductCode') -and ($script:dest -notmatch '.exe$')) {
                    $_Installer.Remove('ProductCode')
                }
                # If the installer is msix or appx, try getting the new SignatureSha256
                # If the new SignatureSha256 can't be found, remove it if it exists
                if ($_Installer.InstallerType -in @('msix', 'appx')) {
                    if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { $NewSignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() } }
                }
                if (String.Validate -not $NewSignatureSha256 -IsNull) {
                    $_Installer['SignatureSha256'] = $NewSignatureSha256
                } elseif ($_Installer.Keys -contains 'SignatureSha256') {
                    $_Installer.Remove('SignatureSha256')
                }
                # If the installer is msix or appx, try getting the new package family name
                # If the new package family name can't be found, remove it if it exists
                if ($script:dest -match '\.(msix|appx)(bundle){0,1}$') {
                    try {
                        Add-AppxPackage -Path $script:dest
                        $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName, PackageFullName
                        $PackageFamilyName = $InstalledPkg.PackageFamilyName
                        Remove-AppxPackage $InstalledPkg.PackageFullName
                    } catch {
                        # Take no action here, we just want to catch the exceptions as a precaution
                        Out-Null
                    } finally {
                        if (String.Validate -not $PackageFamilyName -IsNull) {
                            $_Installer['PackageFamilyName'] = $PackageFamilyName
                        } elseif ($_Installer.Keys -contains 'PackageFamilyName') {
                            $_Installer.Remove('PackageFamilyName')
                        }
                    }
                }
                # Remove the downloaded files
                Remove-Item -Path $script:dest
            }
        }
        # Write the new manifests
        $script:Installers = $script:OldInstallerManifest.Installers
        Write-Locale-Manifests
        Write-Installer-Manifest
        Write-Version-Manifest
        # Remove the old manifests
        if ($PackageVersion -ne $LastVersion) { Remove-Manifest-Version "$AppFolder\..\$LastVersion" }
    }
}

if ($script:Option -ne 'RemoveManifest') {
    # If the user has winget installed, attempt to validate the manifests
    if (Get-Command 'winget.exe' -ErrorAction SilentlyContinue) { winget validate $AppFolder }

    # If the user has sandbox enabled, request to test the manifest in the sandbox
    if (Get-Command 'WindowsSandbox.exe' -ErrorAction SilentlyContinue) {
        # Check the settings to see if we need to display this menu
        switch ($ScriptSettings.TestManifestsInSandbox) {
            'always' { $script:SandboxTest = '0' }
            'never' { $script:SandboxTest = '1' }
            default {
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
            }
        }
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
# If the user has git installed, request to automatically submit the PR
if (Get-Command 'git.exe' -ErrorAction SilentlyContinue) {
    switch ($ScriptSettings.AutoSubmitPRs) {
        'always' { $PromptSubmit = '0' }
        'never' { $PromptSubmit = '1' }
        default {
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
    }
}
Write-Host

# If the user agreed to automatically submit the PR
if ($PromptSubmit -eq '0') {
    # Determine what type of update should be used as the prefix for the PR
    switch -regex ($Option) {
        'New|QuickUpdateVersion|Auto' {
            if ( $script:OldManifestType -eq 'None' ) { $CommitType = 'New package' }
            elseif ($script:LastVersion -lt $script:PackageVersion ) { $CommitType = 'New version' }
            elseif ($script:PackageVersion -in $script:ExistingVersions) { $CommitType = 'Update' }
            elseif ($script:LastVersion -gt $script:PackageVersion ) { $CommitType = 'Add version' }
        }
        'EditMetadata' { $CommitType = 'Metadata' }
        'NewLocale' { $CommitType = 'Locale' }
        'RemoveManifest' { $CommitType = 'Remove' }
    }

    # Change the users git configuration to suppress some git messages
    $_previousConfig = git config --get core.safecrlf
    if ($_previousConfig) {
        git config --replace core.safecrlf false
    } else {
        git config --add core.safecrlf false
    }

    # Fetch the upstream branch, create a commit onto the detached head, and push it to a new branch
    git fetch upstream master --quiet
    git switch -d upstream/master
    if ($LASTEXITCODE -eq '0') {
        # Make sure path exists and is valid before hashing
        if ($script:LocaleManifestPath -and (Test-Path -Path $script:LocaleManifestPath)) { $UniqueBranchID = $(Get-FileHash $script:LocaleManifestPath).Hash[0..6] -Join '' }
        else { $UniqueBranchID = 'DEL' }
        $BranchName = "$PackageIdentifier-$PackageVersion-$UniqueBranchID"
        # Git branch names cannot start with `.` cannot contain any of {`..`, `\`, `~`, `^`, `:`, ` `, `?`, `@{`, `[`}, and cannot end with {`/`, `.lock`, `.`}
        $BranchName = $BranchName -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
        git add -A
        git commit -m "$CommitType`: $PackageIdentifier version $PackageVersion" --quiet
        git switch -c "$BranchName" --quiet
        git push --set-upstream origin "$BranchName" --quiet

        # If the user has the cli too
        if (Get-Command 'gh.exe' -ErrorAction SilentlyContinue) {
            # Request the user to fill out the PR template
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

    # Restore the user's previous git settings to ensure we don't disrupt their normal flow
    if ($_previousConfig) {
        git config --replace core.safecrlf $_previousConfig
    } else {
        git config --unset core.safecrlf
    }
} else {
    Write-Host
    exit
}

# Error levels for the ReturnValue class
Enum ErrorLevel {
    Undefined = -1
    Info = 0
    Warning = 1
    Error = 2
    Critical = 3
}

# Custom class for validation and error checking
# `200` should be indicative of a success
# `400` should be indicative of a bad request
# `500` should be indicative of an internal error / other error
Class ReturnValue {
    [int] $StatusCode
    [string] $Title
    [string] $Message
    [ErrorLevel] $Severity

    # Default Constructor
    ReturnValue() {
    }

    # Overload 1; Creates a return value with only a status code and no descriptors
    ReturnValue(
        [int]$statusCode
    ) {
        $this.StatusCode = $statusCode
        $this.Title = '-'
        $this.Message = '-'
        $this.Severity = -1
    }

    # Overload 2; Create a return value with all parameters defined
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

    # Static reference to a default success value
    [ReturnValue] static Success() {
        return [ReturnValue]::new(200, 'OK', 'The command completed successfully', 'Info')
    }

    # Static reference to a default internal error value
    [ReturnValue] static GenericError() {
        return [ReturnValue]::new(500, 'Internal Error', 'Value was not able to be saved successfully', 2)

    }

    # Static reference to a specific error relating to the pattern of user input
    [ReturnValue] static PatternError() {
        return [ReturnValue]::new(400, 'Invalid Pattern', 'The value entered does not match the pattern requirements defined in the manifest schema', 2)
    }

    # Static reference to a specific error relating to the length of user input
    [ReturnValue] static LengthError([int]$MinLength, [int]$MaxLength) {
        return [ReturnValue]::new(400, 'Invalid Length', "Length must be between $MinLength and $MaxLength characters", 2)
    }

    # Static reference to a specific error relating to the number of entries a user input
    [ReturnValue] static MaxItemsError([int]$MaxEntries) {
        return [ReturnValue]::new(400, 'Too many entries', "Number of entries must be less than or equal to $MaxEntries", 2)
    }

    # Returns the ReturnValue as a nicely formatted string
    [string] ToString() {
        return "[$($this.Severity)] ($($this.StatusCode)) $($this.Title) - $($this.Message)"
    }

    # Returns the ReturnValue as a nicely formatted string if the status code is not equal to 200
    [string] ErrorString() {
        if ($this.StatusCode -eq 200) {
            return $null
        } else {
            return "[$($this.Severity)] $($this.Title) - $($this.Message)`n"
        }
    }
}

class UnmetDependencyException : Exception {
    UnmetDependencyException([string] $message) : base($message) {}
    UnmetDependencyException([string] $message, [Exception] $exception) : base($message, $exception) {}
}
class ManifestException : Exception {
    ManifestException([string] $message) : base($message) {}
}
