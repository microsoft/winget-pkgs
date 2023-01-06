#Requires -Version 5
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]

Param
(
    [Parameter(Mandatory = $true)]
    [PSCustomObject] $InputObject
)
$ProgressPreference = 'SilentlyContinue'

$ScriptHeader = '# Created with YamlCreate.ps1 v2.2.0 using InputObject 🤖'
$ManifestVersion = '1.2.0'
$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$ofs = ', '

$useDirectSchemaLink = (Invoke-WebRequest "https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json" -UseBasicParsing).BaseResponse.ContentLength -eq -1
$SchemaUrls = @{
    version       = if ($useDirectSchemaLink) { "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.version.$ManifestVersion.json" } else { "https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json" }
    defaultLocale = if ($useDirectSchemaLink) { "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.defaultLocale.$ManifestVersion.json" } else { "https://aka.ms/winget-manifest.defaultLocale.$ManifestVersion.schema.json" }
    locale        = if ($useDirectSchemaLink) { "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.locale.$ManifestVersion.json" } else { "https://aka.ms/winget-manifest.locale.$ManifestVersion.schema.json" }
    installer     = if ($useDirectSchemaLink) { "https://raw.githubusercontent.com/microsoft/winget-cli/master/schemas/JSON/manifests/v$ManifestVersion/manifest.installer.$ManifestVersion.json" } else { "https://aka.ms/winget-manifest.installer.$ManifestVersion.schema.json" }
}

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

# Fetch Schema data from github for entry validation, key ordering, and automatic commenting
try {
    $LocaleSchema = @(Invoke-WebRequest $SchemaUrls.defaultLocale -UseBasicParsing | ConvertFrom-Json)
    $LocaleProperties = (ConvertTo-Yaml $LocaleSchema.properties | ConvertFrom-Yaml -Ordered).Keys
    $VersionSchema = @(Invoke-WebRequest $SchemaUrls.version -UseBasicParsing | ConvertFrom-Json)
    $VersionProperties = (ConvertTo-Yaml $VersionSchema.properties | ConvertFrom-Yaml -Ordered).Keys
    $InstallerSchema = @(Invoke-WebRequest $SchemaUrls.installer -UseBasicParsing | ConvertFrom-Json)
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

filter RightTrimString {
    $_.TrimEnd()
}

filter UniqueItems {
    [string]$($_.Split(',').Trim() | Select-Object -Unique)
}

filter ToLower {
    [string]$_.ToLower()
}

filter NoWhitespace {
    [string]$_ -replace '\s{1,}', '-'
}

$ToNatural = { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) }

# Various patterns used in validation to simplify the validation logic
$Patterns = @{
    PackageIdentifier             = $VersionSchema.properties.PackageIdentifier.pattern
    IdentifierMaxLength           = $VersionSchema.properties.PackageIdentifier.maxLength
    PackageVersion                = $InstallerSchema.definitions.PackageVersion.pattern
    VersionMaxLength              = $VersionSchema.properties.PackageVersion.maxLength
    InstallerSha256               = $InstallerSchema.definitions.Installer.properties.InstallerSha256.pattern
    InstallerUrl                  = $InstallerSchema.definitions.Installer.properties.InstallerUrl.pattern
    InstallerUrlMaxLength         = $InstallerSchema.definitions.Installer.properties.InstallerUrl.maxLength
    ValidArchitectures            = $InstallerSchema.definitions.Architecture.enum
    ValidInstallerTypes           = $InstallerSchema.definitions.InstallerType.enum
    ValidNestedInstallerTypes     = $InstallerSchema.definitions.NestedInstallerType.enum
    SilentSwitchMaxLength         = $InstallerSchema.definitions.InstallerSwitches.properties.Silent.maxLength
    ProgressSwitchMaxLength       = $InstallerSchema.definitions.InstallerSwitches.properties.SilentWithProgress.maxLength
    CustomSwitchMaxLength         = $InstallerSchema.definitions.InstallerSwitches.properties.Custom.maxLength
    SignatureSha256               = $InstallerSchema.definitions.Installer.properties.SignatureSha256.pattern
    FamilyName                    = $InstallerSchema.definitions.PackageFamilyName.pattern
    FamilyNameMaxLength           = $InstallerSchema.definitions.PackageFamilyName.maxLength
    PackageLocale                 = $LocaleSchema.properties.PackageLocale.pattern
    InstallerLocaleMaxLength      = $InstallerSchema.definitions.Locale.maxLength
    ProductCodeMinLength          = $InstallerSchema.definitions.ProductCode.minLength
    ProductCodeMaxLength          = $InstallerSchema.definitions.ProductCode.maxLength
    MaxItemsFileExtensions        = $InstallerSchema.definitions.FileExtensions.maxItems
    MaxItemsProtocols             = $InstallerSchema.definitions.Protocols.maxItems
    MaxItemsCommands              = $InstallerSchema.definitions.Commands.maxItems
    MaxItemsSuccessCodes          = $InstallerSchema.definitions.InstallerSuccessCodes.maxItems
    MaxItemsInstallModes          = $InstallerSchema.definitions.InstallModes.maxItems
    PackageLocaleMaxLength        = $LocaleSchema.properties.PackageLocale.maxLength
    PublisherMaxLength            = $LocaleSchema.properties.Publisher.maxLength
    PackageNameMaxLength          = $LocaleSchema.properties.PackageName.maxLength
    MonikerMaxLength              = $LocaleSchema.definitions.Tag.maxLength
    GenericUrl                    = $LocaleSchema.definitions.Url.pattern
    GenericUrlMaxLength           = $LocaleSchema.definitions.Url.maxLength
    AuthorMinLength               = $LocaleSchema.properties.Author.minLength
    AuthorMaxLength               = $LocaleSchema.properties.Author.maxLength
    LicenseMaxLength              = $LocaleSchema.properties.License.maxLength
    CopyrightMinLength            = $LocaleSchema.properties.Copyright.minLength
    CopyrightMaxLength            = $LocaleSchema.properties.Copyright.maxLength
    TagsMaxItems                  = $LocaleSchema.properties.Tags.maxItems
    ShortDescriptionMaxLength     = $LocaleSchema.properties.ShortDescription.maxLength
    DescriptionMinLength          = $LocaleSchema.properties.Description.minLength
    DescriptionMaxLength          = $LocaleSchema.properties.Description.maxLength
    ValidInstallModes             = $InstallerSchema.definitions.InstallModes.items.enum
    FileExtension                 = $InstallerSchema.definitions.FileExtensions.items.pattern
    FileExtensionMaxLength        = $InstallerSchema.definitions.FileExtensions.items.maxLength
    ReleaseNotesMinLength         = $LocaleSchema.properties.ReleaseNotes.MinLength
    ReleaseNotesMaxLength         = $LocaleSchema.properties.ReleaseNotes.MaxLength
    RelativeFilePathMinLength     = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.RelativeFilePath.minLength
    RelativeFilePathMaxLength     = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.RelativeFilePath.maxLength
    PortableCommandAliasMinLength = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.PortableCommandAlias.minLength
    PortableCommandAliasMaxLength = $InstallerSchema.Definitions.NestedInstallerFiles.items.properties.PortableCommandAlias.maxLength
    ArchiveInstallerTypes         = @('zip')
}

# This function validates whether a string matches Minimum Length, Maximum Length, and Regex pattern
# The switches can be used to specify if null values are allowed regardless of validation
Function Test-String {
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
    if ($AllowNull -and [string]::IsNullOrWhiteSpace($InputString)) {
        $_isValid = $true
    } elseif ($NotNull -and [string]::IsNullOrWhiteSpace($InputString)) {
        $_isValid = $false
    }
    if ($IsNull) {
        $_isValid = [string]::IsNullOrWhiteSpace($InputString)
    }

    if ($Not) {
        return !$_isValid
    } else {
        return $_isValid
    }
}

# Checks a file name for validity and returns a boolean value
Function Test-ValidFileName {
    param([string]$FileName)
    $IndexOfInvalidChar = $FileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
    # IndexOfAny() returns the value -1 to indicate no such character was found
    return $IndexOfInvalidChar -eq -1
}
Function Get-InstallerFile {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $URI,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $PackageIdentifier,
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $PackageVersion

    )
    # Create a filename based on the Package Identifier and Version; Try to get the extension from the URL
    # If the extension isn't found, use a custom one
    $_URIPath = $URI.Split('?')[0]
    $_Filename = "$PackageIdentifier v$PackageVersion - $(Get-Date -f 'yyyy.MM.dd-hh.mm.ss')" + $(if ([System.IO.Path]::HasExtension($_URIPath)) { [System.IO.Path]::GetExtension($_URIPath) } else { '.winget-tmp' })
    if (Test-ValidFileName $_Filename) { $_OutFile = Join-Path -Path $env:TEMP -ChildPath $_Filename }
    else { $_OutFile = (New-TemporaryFile).FullName }

    # Create a new web client for downloading the file
    $_WebClient = [System.Net.WebClient]::new()
    $_WebClient.Headers.Add('User-Agent', 'Microsoft-Delivery-Optimization/10.1')
    # If the system has a default proxy set, use it
    # Powershell Core will automatically use this, so it's only necessary for PS5
    if ($PSVersionTable.PSVersion.Major -lt 6) { $_WebClient.Proxy = [System.Net.WebProxy]::GetDefaultProxy() }
    # Download the file
    $_WebClient.DownloadFile($URI, $_OutFile)
    # Dispose of the web client to release the resources it uses
    $_WebClient.Dispose()

    return $_OutFile
}

Function Get-MSIProperty {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $MSIPath,
        [Parameter(Mandatory = $true)]
        [string] $Parameter
    )
    try {
        $windowsInstaller = New-Object -com WindowsInstaller.Installer
        $database = $windowsInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstaller, @($MSIPath, 0))
        $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ("SELECT Value FROM Property WHERE Property = '$Parameter'"))
        $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
        $outputObject = $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1))
        $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($view)
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($database)
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($windowsInstaller)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        return $outputObject
    } catch {
        Write-Error -Message $_.ToString()
        break
    }
}

Function Get-ItemMetadata {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $FilePath
    )
    try {
        $MetaDataObject = [ordered] @{}
        $FileInformation = (Get-Item $FilePath)
        $ShellApplication = New-Object -ComObject Shell.Application
        $ShellFolder = $ShellApplication.Namespace($FileInformation.Directory.FullName)
        $ShellFile = $ShellFolder.ParseName($FileInformation.Name)
        $MetaDataProperties = [ordered] @{}
        0..400 | ForEach-Object -Process {
            $DataValue = $ShellFolder.GetDetailsOf($null, $_)
            $PropertyValue = (Get-Culture).TextInfo.ToTitleCase($DataValue.Trim()).Replace(' ', '')
            if ($PropertyValue -ne '') {
                $MetaDataProperties["$_"] = $PropertyValue
            }
        }
        foreach ($Key in $MetaDataProperties.Keys) {
            $Property = $MetaDataProperties[$Key]
            $Value = $ShellFolder.GetDetailsOf($ShellFile, [int] $Key)
            if ($Property -in 'Attributes', 'Folder', 'Type', 'SpaceFree', 'TotalSize', 'SpaceUsed') {
                continue
            }
            If (($null -ne $Value) -and ($Value -ne '')) {
                $MetaDataObject["$Property"] = $Value
            }
        }
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ShellFile)
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ShellFolder)
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($ShellApplication)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        return $MetaDataObject
    } catch {
        Write-Error -Message $_.ToString()
        break
    }
}

function Get-Property ($Object, $PropertyName, [object[]]$ArgumentList) {
    return $Object.GetType().InvokeMember($PropertyName, 'Public, Instance, GetProperty', $null, $Object, $ArgumentList)
}

Function Get-MsiDatabase {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $FilePath
    )
    Write-Host -ForegroundColor 'Yellow' 'Reading Installer Database. This may take some time. . .'
    $windowsInstaller = New-Object -com WindowsInstaller.Installer
    $MSI = $windowsInstaller.OpenDatabase($FilePath, 0)
    $_TablesView = $MSI.OpenView('select * from _Tables')
    $_TablesView.Execute()
    $_Database = @{}
    do {
        $_Table = $_TablesView.Fetch()
        if ($_Table) {
            $_TableName = Get-Property $_Table StringData 1
            $_Database["$_TableName"] = @{}
        }
    } while ($_Table)
    [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($_TablesView)
    foreach ($_Table in $_Database.Keys) {
        # Write-Host $_Table
        $_ItemView = $MSI.OpenView("select * from $_Table")
        $_ItemView.Execute()
        do {
            $_Item = $_ItemView.Fetch()
            if ($_Item) {
                $_ItemValue = $null
                $_ItemName = Get-Property $_Item StringData 1
                if ($_Table -eq 'Property') { $_ItemValue = Get-Property $_Item StringData 2 -ErrorAction SilentlyContinue }
                $_Database.$_Table["$_ItemName"] = $_ItemValue
            }
        } while ($_Item)
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($_ItemView)
    }
    [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($MSI)
    [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($windowsInstaller)
    Write-Host -ForegroundColor 'Yellow' 'Closing Installer Database. . .'
    return $_Database
}

Function Test-IsWix {
    Param
    (
        [Parameter(Mandatory = $true)]
        [object] $Database,
        [Parameter(Mandatory = $true)]
        [object] $MetaDataObject
    )
    # If any of the table names match wix
    if ($Database.Keys -match 'wix') { return $true }
    # If any of the keys in the property table match wix
    if ($Database.Property.Keys.Where({ $_ -match 'wix' })) { return $true }
    # If the CreatedBy value matches wix
    if ($MetaDataObject.ProgramName -match 'wix') { return $true }
    # If the CreatedBy value matches xml
    if ($MetaDataObject.ProgramName -match 'xml') { return $true }
    return $false
}

Function Get-PathInstallerType {
    Param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path
    )

    if ($Path -match '\.msix(bundle){0,1}$') { return 'msix' }
    if ($Path -match '\.msi$') {
        $ObjectMetadata = Get-ItemMetadata $Path
        $ObjectDatabase = Get-MsiDatabase $Path
        if (Test-IsWix -Database $ObjectDatabase -MetaDataObject $ObjectMetadata ) {
            return 'wix'
        }
        return 'msi'
    }
    if ($Path -match '\.appx(bundle){0,1}$') { return 'appx' }
    if ($Path -match '\.zip$') { return 'zip' }
    return $null
}

# Sorts keys within an object based on a reference ordered dictionary
# If a key does not exist, it sets the value to a special character to be removed / commented later
# Returns the result as a new object
Function Restore-YamlKeyOrder {
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
        'NestedInstallerType'
        'NestedInstallerFiles'
        'Scope'
        'UpgradeBehavior'
        'Dependencies'
        'InstallationMetadata'
        'Platform'
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

# Takes a comma separated list of values, converts it to an array object, and adds the result to a specified object-key
Function Add-YamlListParameter {
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
Function Add-YamlParameter {
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
Function Get-MultiManifestParameter {
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Parameter
    )
    $_vals = $($script:OldInstallerManifest[$Parameter] + $script:OldLocaleManifest[$Parameter] + $script:OldVersionManifest[$Parameter] | Where-Object { $_ })
    return ($_vals -join ', ')
}

# Take all the entered values and write the version manifest file
Function Write-VersionManifest {
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
        If ($_Item.Value) { Add-YamlParameter -Object $VersionManifest -Parameter $_Item.Name -Value $_Item.Value }
    }
    foreach ($_Key in $VersionProperties) {
        if ($script:InputKeys -contains $_Key) {
            $VersionManifest[$_Key] = $InputObject.$_Key
        }
    }
    $VersionManifest = Restore-YamlKeyOrder $VersionManifest $VersionProperties

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $script:VersionManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.yaml"

    # Write the manifest to the file
    $ScriptHeader + " `$debug=QUSU.$(switch (([System.Environment]::NewLine).Length) {
        1 { 'LF.' }
        2 { 'CRLF.' }
        Default { 'XX.' }
    }).$($PSVersionTable.PSVersion -Replace '\.', '-')`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json`n" > $VersionManifestPath
    ConvertTo-Yaml $VersionManifest >> $VersionManifestPath
    $(Get-Content $VersionManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $VersionManifestPath -Force
    $MyRawString = Get-Content $VersionManifestPath | RightTrimString | Select-Object -SkipLast 1 # Skip the last one because it will always just be an empty newline
    [System.IO.File]::WriteAllLines($VersionManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $VersionManifestPath"
}

# Take all the entered values and write the installer manifest file
Function Write-InstallerManifest {
    # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
    if ($script:OldManifestType -eq 'MultiManifest') {
        $InstallerManifest = $script:OldInstallerManifest
    }
    if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

    # Add the properties to the manifest
    Add-YamlParameter -Object $InstallerManifest -Parameter 'PackageIdentifier' -Value $PackageIdentifier
    Add-YamlParameter -Object $InstallerManifest -Parameter 'PackageVersion' -Value $PackageVersion
    If ($MinimumOSVersion) {
        $InstallerManifest['MinimumOSVersion'] = $MinimumOSVersion
    } Else {
        If ($InstallerManifest['MinimumOSVersion']) { $_InstallerManifest.Remove('MinimumOSVersion') }
    }

    $_ListSections = [ordered]@{
        'FileExtensions'        = $FileExtensions
        'Protocols'             = $Protocols
        'Commands'              = $Commands
        'InstallerSuccessCodes' = $InstallerSuccessCodes
        'InstallModes'          = $InstallModes
    }
    foreach ($Section in $_ListSections.GetEnumerator()) {
        If ($Section.Value) { Add-YamlListParameter -Object $InstallerManifest -Parameter $Section.Name -Values $Section.Value }
    }

    if ($Option -ne 'EditMetadata') {
        $InstallerManifest['Installers'] = $script:Installers
    } elseif ($script:OldInstallerManifest) {
        $InstallerManifest['Installers'] = $script:OldInstallerManifest['Installers']
    } else {
        $InstallerManifest['Installers'] = $script:OldVersionManifest['Installers']
    }

    foreach ($_Installer in $InstallerManifest.Installers) {
        # $Preserve = $true
        if ($_Installer['ReleaseDate'] -and !$script:ReleaseDatePrompted -and !$true) { $_Installer.Remove('ReleaseDate') }
        elseif ($true) {
            # $Preserve = $true
            try {
                Get-Date([datetime]$($_Installer['ReleaseDate'])) -f 'yyyy-MM-dd' -OutVariable _ValidDate | Out-Null
                if ($_ValidDate) { $_Installer['ReleaseDate'] = $_ValidDate | TrimString }
            } catch {
                # Release date isn't valid
                $_Installer.Remove('ReleaseDate')
            }
        }
    }

    Add-YamlParameter -Object $InstallerManifest -Parameter 'ManifestType' -Value 'installer'
    Add-YamlParameter -Object $InstallerManifest -Parameter 'ManifestVersion' -Value $ManifestVersion
    If ($InstallerManifest['Dependencies']) {
        $InstallerManifest['Dependencies'] = Restore-YamlKeyOrder $InstallerManifest['Dependencies'] $InstallerDependencyProperties -NoComments
    }
    # Move Installer Level Keys to Manifest Level
    $_KeysToMove = $InstallerEntryProperties | Where-Object { $_ -in $InstallerProperties -and $_ -notin @('ProductCode', 'NestedInstallerFiles', 'NestedInstallerType') }
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
                        if (Test-String $_CurrentInstallerSwitchKeyValue -IsNull) { $_AllAreSame = $false }
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
                    if (Test-String $_CurrentInstallerKeyValue -IsNull) { $_AllAreSame = $false }
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
    if ($InstallerManifest.Keys -contains 'InstallerSwitches') { $InstallerManifest['InstallerSwitches'] = Restore-YamlKeyOrder $InstallerManifest.InstallerSwitches $InstallerSwitchProperties -NoComments }
    foreach ($_Installer in $InstallerManifest.Installers) {
        if ($_Installer.Keys -contains 'InstallerSwitches') { $_Installer['InstallerSwitches'] = Restore-YamlKeyOrder $_Installer.InstallerSwitches $InstallerSwitchProperties -NoComments }
    }

    # Clean up the existing files just in case
    if ($InstallerManifest['Commands']) { $InstallerManifest['Commands'] = @($InstallerManifest['Commands'] | UniqueItems | NoWhitespace | Sort-Object) }
    if ($InstallerManifest['Protocols']) { $InstallerManifest['Protocols'] = @($InstallerManifest['Protocols'] | ToLower | UniqueItems | NoWhitespace | Sort-Object) }
    if ($InstallerManifest['FileExtensions']) { $InstallerManifest['FileExtensions'] = @($InstallerManifest['FileExtensions'] | ToLower | UniqueItems | NoWhitespace | Sort-Object) }

    foreach ($_Key in $InstallerProperties) {
        if ($script:InputKeys -contains $_Key) {
            $InstallerManifest[$_Key] = $InputObject.$_Key
        }
    }

    $InstallerManifest = Restore-YamlKeyOrder $InstallerManifest $InstallerProperties -NoComments

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $script:InstallerManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.installer.yaml"

    # Write the manifest to the file
    $ScriptHeader + " `$debug=QUSU.$(switch (([System.Environment]::NewLine).Length) {
        1 { 'LF.' }
        2 { 'CRLF.' }
        Default { 'XX.' }
    }).$($PSVersionTable.PSVersion -Replace '\.', '-')`n# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$ManifestVersion.schema.json`n" > $InstallerManifestPath
    ConvertTo-Yaml $InstallerManifest >> $InstallerManifestPath
    $(Get-Content $InstallerManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $InstallerManifestPath -Force
    $MyRawString = Get-Content $InstallerManifestPath | RightTrimString | Select-Object -SkipLast 1 # Skip the last one because it will always just be an empty newline
    [System.IO.File]::WriteAllLines($InstallerManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $InstallerManifestPath"
}

# Take all the entered values and write the locale manifest file
Function Write-LocaleManifest {
    # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
    if ($script:OldManifestType -eq 'MultiManifest') {
        $LocaleManifest = $script:OldLocaleManifest
    }
    if (!$LocaleManifest) { [PSCustomObject]$LocaleManifest = [ordered]@{} }

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
        'ReleaseNotes'        = $ReleaseNotes
        'ReleaseNotesUrl'     = $ReleaseNotesUrl
    }
    foreach ($_Item in $_Singletons.GetEnumerator()) {
        If ($_Item.Value) { Add-YamlParameter -Object $LocaleManifest -Parameter $_Item.Name -Value $_Item.Value }
    }

    If ($Tags) { Add-YamlListParameter -Object $LocaleManifest -Parameter 'Tags' -Values $Tags }
    If (!$LocaleManifest.ManifestType) { $LocaleManifest['ManifestType'] = 'defaultLocale' }
    If ($Moniker -and $($LocaleManifest.ManifestType -eq 'defaultLocale')) { Add-YamlParameter -Object $LocaleManifest -Parameter 'Moniker' -Value $Moniker }
    Add-YamlParameter -Object $LocaleManifest -Parameter 'ManifestVersion' -Value $ManifestVersion

    # Clean up the existing files just in case
    if ($LocaleManifest['Tags']) { $LocaleManifest['Tags'] = @($LocaleManifest['Tags'] | ToLower | UniqueItems | NoWhitespace | Sort-Object) }
    if ($LocaleManifest['Moniker']) { $LocaleManifest['Moniker'] = $LocaleManifest['Moniker'] | ToLower | NoWhitespace }

    # Clean up the volatile fields                                                     # $Preserve = $true
    if ($LocaleManifest['ReleaseNotes'] -and (Test-String $script:ReleaseNotes -IsNull) -and !$true) { $LocaleManifest.Remove('ReleaseNotes') }
    if ($LocaleManifest['ReleaseNotesUrl'] -and (Test-String $script:ReleaseNotesUrl -IsNull) -and !$true) { $LocaleManifest.Remove('ReleaseNotesUrl') }

    if ($InputKeys -contains 'Locales') { $InputLocales = ($InputObject.Locales | Get-Member | Where-Object { $_.MemberType -eq 'NoteProperty' }).Name }
    foreach ($_Key in $LocaleProperties) { if ($InputKeys -contains $_Key) { $LocaleManifest[$_Key] = $InputObject.$_Key } }
    if ($InputLocales -and $InputLocales -contains $LocaleManifest.PackageLocale ) {
        $InputLocaleKeys = ($InputObject.Locales.$($LocaleManifest.PackageLocale) | Get-Member | Where-Object { $_.MemberType -eq 'NoteProperty' }).Name
        foreach ($_Key in $LocaleProperties) { if ($InputLocaleKeys -contains $_Key) { $LocaleManifest[$_Key] = $InputObject.Locales.$($LocaleManifest.PackageLocale).$_Key } }
    }

    $LocaleManifest = Restore-YamlKeyOrder $LocaleManifest $LocaleProperties

    # Set the appropriate langage server depending on if it is a default locale file or generic locale file
    if ($LocaleManifest.ManifestType -eq 'defaultLocale') { $yamlServer = "# yaml-language-server: `$schema=$($SchemaUrls.defaultLocale)" } else { $yamlServer = "# yaml-language-server: `$schema=$($SchemaUrls.locale)" }

    # Create the folder for the file if it doesn't exist
    New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
    $script:LocaleManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.locale.$PackageLocale.yaml"

    # Write the manifest to the file
    $ScriptHeader + " `$debug=QUSU.$(switch (([System.Environment]::NewLine).Length) {
        1 { 'LF.' }
        2 { 'CRLF.' }
        Default { 'XX.' }
    }).$($PSVersionTable.PSVersion -Replace '\.', '-')`n$yamlServer`n" > $LocaleManifestPath
    ConvertTo-Yaml $LocaleManifest >> $LocaleManifestPath
    $(Get-Content $LocaleManifestPath -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $LocaleManifestPath -Force
    $MyRawString = Get-Content $LocaleManifestPath | RightTrimString | Select-Object -SkipLast 1 # Skip the last one because it will always just be an empty newline
    [System.IO.File]::WriteAllLines($LocaleManifestPath, $MyRawString, $Utf8NoBomEncoding)

    # Copy over all locale files from previous version that aren't the same
    if ($OldManifests) {
        ForEach ($DifLocale in $OldManifests) {
            if ($DifLocale.Name -notin @("$PackageIdentifier.yaml", "$PackageIdentifier.installer.yaml", "$PackageIdentifier.locale.$PackageLocale.yaml")) {
                if (!(Test-Path $AppFolder)) { New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null }
                $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $DifLocale.FullName -Encoding UTF8) -join "`n") -Ordered
                $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
                if ($script:OldLocaleManifest.Keys -contains 'Moniker') { $script:OldLocaleManifest.Remove('Moniker') }
                $script:OldLocaleManifest['ManifestVersion'] = $ManifestVersion
                # Clean up the existing files just in case
                if ($script:OldLocaleManifest['Tags']) { $script:OldLocaleManifest['Tags'] = @($script:OldLocaleManifest['Tags'] | ToLower | UniqueItems | NoWhitespace | Sort-Object) }

                # Clean up the volatile fields                                                        # $Preserve = $true
                if ($OldLocaleManifest['ReleaseNotes'] -and (Test-String $script:ReleaseNotes -IsNull) -and !$true) { $OldLocaleManifest.Remove('ReleaseNotes') }
                if ($OldLocaleManifest['ReleaseNotesUrl'] -and (Test-String $script:ReleaseNotesUrl -IsNull) -and !$true) { $OldLocaleManifest.Remove('ReleaseNotesUrl') }

                $script:OldLocaleManifest = Restore-YamlKeyOrder $script:OldLocaleManifest $LocaleProperties

                $yamlServer = "# yaml-language-server: `$schema=https://aka.ms/winget-manifest.locale.$ManifestVersion.schema.json"

                $ScriptHeader + " `$debug=QUSU.$(switch (([System.Environment]::NewLine).Length) {
                    1 { 'LF.' }
                    2 { 'CRLF.' }
                    Default { 'XX.' }
                }).$($PSVersionTable.PSVersion -Replace '\.', '-')`n$yamlServer`n" > ($AppFolder + '\' + $DifLocale.Name)
                ConvertTo-Yaml $OldLocaleManifest >> (Join-Path $AppFolder -ChildPath $DifLocale.Name)
                $(Get-Content $(Join-Path $AppFolder -ChildPath $DifLocale.Name) -Encoding UTF8) -replace "(.*)$([char]0x2370)", "# `$1" | Out-File -FilePath $(Join-Path $AppFolder -ChildPath $DifLocale.Name) -Force
                $MyRawString = Get-Content $(Join-Path $AppFolder -ChildPath $DifLocale.Name) | RightTrimString | Select-Object -SkipLast 1 # Skip the last one because it will always just be an empty newline
                [System.IO.File]::WriteAllLines($(Join-Path $AppFolder -ChildPath $DifLocale.Name), $MyRawString, $Utf8NoBomEncoding)
            }
        }
    }

    # Tell user the file was created and the path to the file
    Write-Host
    Write-Host "Yaml file created: $LocaleManifestPath"
}

## START OF MAIN SCRIPT ##

# Initialize the return value to be a success
$script:_returnValue = [ReturnValue]::new(200)

if (-not $AutoUpgrade) {
    $script:Option = 'QuickUpdateVersion'
} else {
    $script:Option = 'Auto'
}

if ($null -eq $InputObject.PackageIdentifier) { throw 'Package Identifier is required' }
if ($null -eq $InputObject.PackageVersion) { throw 'Package Version is required' }
if ($null -eq $InputObject.InstallerUrls) { throw 'InstallerUrls are required' }

$script:PackageIdentifier = $InputObject.PackageIdentifier
$script:PackageVersion = $InputObject.PackageVersion

$PackageIdentifierFolder = $PackageIdentifier.Replace('.', '\')

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
        $script:AppFolder = Join-Path (Split-Path $AppFolder) -ChildPath $LastVersion
        $script:PackageVersion = $LastVersion
    }
}

# If the user selected `QuickUpdateVersion`, the old manifests must exist
# If the user selected `New`, the old manifest type is specified as none
if (-not (Test-Path -Path "$AppFolder\..")) {
    throw 'This option requires manifest of previous version of the package. If you want to create a new package, please select Option 1.'
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
                    if ($_Key -notin $_Installer.Keys) {
                        $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
                    }
                }
            }
            New-Variable -Name $_Key -Value $($script:OldInstallerManifest.$_Key -join ', ') -Scope Script -Force
            $script:OldInstallerManifest.Remove($_Key)
        }
    }
    $script:OldLocaleManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.locale.$PackageLocale.yaml") -Encoding UTF8) -join "`n") -Ordered
    $script:OldVersionManifest = ConvertFrom-Yaml -Yaml ($(Get-Content -Path $(Resolve-Path "$AppFolder\..\$LastVersion\$PackageIdentifier.yaml") -Encoding UTF8) -join "`n") -Ordered
} elseif ($OldManifests.Name -eq "$PackageIdentifier.yaml") {
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
                    if ($_Key -notin $_Installer.Keys) {
                        $_Installer[$_Key] = $script:OldInstallerManifest.$_Key
                    }
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
        'InstallerType'; 'NestedInstallerType'
        'Scope'
        'UpgradeBehavior'
        'PackageFamilyName'; 'ProductCode'
        'Tags'; 'FileExtensions'
        'Protocols'; 'Commands'
        'InstallerSuccessCodes'
        'Capabilities'; 'RestrictedCapabilities'
    )
    Foreach ($param in $_Parameters) {
        $_ReadValue = $(if ($script:OldManifestType -eq 'MultiManifest') { (Get-MultiManifestParameter $param) } else { $script:OldVersionManifest[$param] })
        if (Test-String -Not $_ReadValue -IsNull) { New-Variable -Name $param -Value $_ReadValue -Scope Script -Force }
    }
}

# If the old manifests exist, make sure to use the same casing as the existing package identifier
if ($OldManifests) {
    $script:PackageIdentifier = $OldManifests.Where({ $_.Name -like "$PackageIdentifier.yaml" }).BaseName
}

# Run the data entry and creation of manifests appropriate to the option the user selected
$script:InputKeys = ($InputObject | Get-Member | Where-Object { $_.MemberType -eq 'NoteProperty' }).Name
$InputObject.InstallerUrls = Sort-Object -InputObject $InputObject.InstallerUrls
if (-not $InputObject.InstallerUrls.GetType().IsArray) {
    $InputObject.InstallerUrls = @($InputObject.InstallerUrls)
}

# We know old manifests exist if we got here without error
# Fetch the old installers based on the manifest type
if ($script:OldInstallerManifest) { $_OldInstallers = $script:OldInstallerManifest['Installers'] } else {
    $_OldInstallers = $script:OldVersionManifest['Installers']
}

$_OldInstallers = Sort-Object -InputObject $_OldInstallers -Property InstallerUrl

if (($_OldInstallers.InstallerUrl | Select-Object -Unique).Count -ne $InputObject.InstallerUrls.Count) {
    Throw 'Number of InstallerUrls are not equal'
}
Write-Host "Total Installer Entries: $($_OldInstallers.Count)"
$_iteration = 0
$_urlsIteration = 0
$_NewInstallers = @()
foreach ($_OldInstaller in $_OldInstallers) {
    # Create the new installer as an exact copy of the old installer entry
    # This is to ensure all previously entered and un-modified parameters are retained
    $_iteration += 1
    $_NewInstaller = $_OldInstaller
    $_NewInstaller.Remove('InstallerSha256');

    # Show the user which installer entry they should be entering information for
    Write-Host -ForegroundColor 'Green' "Installer Entry #$_iteration`:`n"
    if ($_OldInstaller.InstallerLocale) { Write-Host -ForegroundColor 'Yellow' "`tInstallerLocale: $($_OldInstaller.InstallerLocale)" }
    if ($_OldInstaller.Architecture) { Write-Host -ForegroundColor 'Yellow' "`tArchitecture: $($_OldInstaller.Architecture)" }
    if ($_OldInstaller.InstallerType) { Write-Host -ForegroundColor 'Yellow' "`tInstallerType: $($_OldInstaller.InstallerType)" }
    if ($_OldInstaller.Scope) { Write-Host -ForegroundColor 'Yellow' "`tScope: $($_OldInstaller.Scope)" }
    Write-Host

    # Request user enter the new Installer URL
    # $_NewInstaller['InstallerUrl'] = Request-InstallerUrl

    if ($PrevOldInstallerUrl -eq $_OldInstaller.InstallerUrl) {
        $_NewInstaller.InstallerUrl = $PrevNewInstallerUrl
    } else {
        $PrevOldInstallerUrl = $_OldInstaller.InstallerUrl
        $PrevNewInstallerUrl = $_NewInstaller.InstallerUrl = $InputObject.InstallerUrls[$_urlsIteration]
        $_urlsIteration += 1
    }

    if ($_NewInstaller.InstallerUrl -in ($_NewInstallers).InstallerUrl) {
        $_MatchingInstaller = $_NewInstallers | Where-Object { $_.InstallerUrl -eq $_NewInstaller.InstallerUrl } | Select-Object -First 1
        if ($_MatchingInstaller.InstallerSha256) { $_NewInstaller['InstallerSha256'] = $_MatchingInstaller.InstallerSha256 }
        if ($_MatchingInstaller.InstallerType) { $_NewInstaller['InstallerType'] = $_MatchingInstaller.InstallerType }
        if ($_MatchingInstaller.ProductCode) { $_NewInstaller['ProductCode'] = $_MatchingInstaller.ProductCode }
        elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ($script:dest -notmatch '.exe$')) { $_NewInstaller.Remove('ProductCode') }
        if ($_MatchingInstaller.PackageFamilyName) { $_NewInstaller['PackageFamilyName'] = $_MatchingInstaller.PackageFamilyName }
        elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') { $_NewInstaller.Remove('PackageFamilyName') }
        if ($_MatchingInstaller.SignatureSha256) { $_NewInstaller['SignatureSha256'] = $_MatchingInstaller.SignatureSha256 }
        elseif ($_NewInstaller.Keys -contains 'SignatureSha256') { $_NewInstaller.Remove('SignatureSha256') }
    }

    if ($_NewInstaller.Keys -notcontains 'InstallerSha256') {
        try {
            $script:dest = Get-InstallerFile -URI $_NewInstaller['InstallerUrl'] -PackageIdentifier $PackageIdentifier -PackageVersion $PackageVersion
        } catch {
            # Here we also want to pass any exceptions through for potential debugging
            throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
        } finally {
            # Check that MSI's aren't actually WIX
            if ($_NewInstaller['InstallerType'] -eq 'msi') {
                $DetectedType = Get-PathInstallerType $script:dest
                if ($DetectedType -in @('msi'; 'wix')) { $_NewInstaller['InstallerType'] = $DetectedType }
            }
            # Get the Sha256
            $_NewInstaller['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
            # Update the product code, if a new one exists
            # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
            $MSIProductCode = $null
            if ([System.Environment]::OSVersion.Platform -match 'Win' -and ($script:dest).EndsWith('.msi')) {
                $MSIProductCode = ([string](Get-MSIProperty -MSIPath $script:dest -Parameter 'ProductCode') | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
            }
            if (Test-String -not $MSIProductCode -IsNull) {
                $_NewInstaller['ProductCode'] = $MSIProductCode
            } elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ($_NewInstaller.InstallerType -in @('appx'; 'msi'; 'msix'; 'wix'; 'burn'))) {
                $_NewInstaller.Remove('ProductCode')
            }
            # If the installer is msix or appx, try getting the new SignatureSha256
            # If the new SignatureSha256 can't be found, remove it if it exists
            $NewSignatureSha256 = $null
            if ($_NewInstaller.InstallerType -in @('msix', 'appx')) {
                $NewSignatureSha256 = & $WinGetDev hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() }
            }
            if (Test-String -not $NewSignatureSha256 -IsNull) {
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
                    if (Test-String -not $PackageFamilyName -IsNull) {
                        $_NewInstaller['PackageFamilyName'] = $PackageFamilyName
                    } elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') {
                        $_NewInstaller.Remove('PackageFamilyName')
                    }
                }
            }
            # Remove the downloaded files
            Remove-Item -Path $script:dest
        }
    }
    # Add the updated installer to the new installers array
    $_NewInstaller = Restore-YamlKeyOrder $_NewInstaller $InstallerEntryProperties -NoComments
    $_NewInstallers += $_NewInstaller
}
$script:Installers = $_NewInstallers

Write-LocaleManifest
Write-InstallerManifest
Write-VersionManifest
# Delete previous manifests if $InputObject.DeletePreviousVersion is true
if ($InputObject.DeletePreviousVersion) {
    $PathToVersion = "$AppFolder\..\$LastVersion"
    # Remove the manifest, and then any parent folders so long as the parent folders are empty
    do {
        Remove-Item -Path $PathToVersion -Recurse -Force
        $PathToVersion = Split-Path $PathToVersion
    } while (@(Get-ChildItem $PathToVersion).Count -eq 0)
}

# If the user has winget installed, attempt to validate the manifests
& $WinGetDev validate $AppFolder

# dot-source the function to get pull request body
. Test-ArpMetadata -ManifestFolder $AppFolder

# Determine what type of update should be used as the prefix for the PR
$AllVersions = (@($script:ExistingVersions) + @($PackageVersion)) | Sort-Object $ToNatural
if ($AllVersions.Count -eq '1') { $CommitType = 'New package' }
elseif ($script:PackageVersion -in $script:ExistingVersions) { $CommitType = 'Update' }
elseif (($AllVersions.IndexOf($PackageVersion) + 1) -eq $AllVersions.Count) { $CommitType = 'New version' }
elseif (($AllVersions.IndexOf($PackageVersion) + 1) -ne $AllVersions.Count) { $CommitType = 'Add version' }

# Dot-source the function to run in current scope
. Submit-Manifest

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

class ManifestException : Exception {
    ManifestException([string] $message) : base($message) {}
}
