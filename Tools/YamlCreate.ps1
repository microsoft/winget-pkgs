#Requires -Version 5
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Preserve', Justification = 'The variable is used in a conditional but ScriptAnalyser does not recognize the scope')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', Scope = 'Function', Target = 'Read-AppsAndFeaturesEntries',
  Justification = 'Ths function is a wrapper which calls the singular Read-AppsAndFeaturesEntry as many times as necessary. It corresponds exactly to a pluralized manifest field')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', Scope = 'Function', Target = '*Metadata',
  Justification = 'Metadata is used as a mass noun and is therefore singular in the cases used in this script')]

Param
(
  [switch] $Settings,
  [switch] $AutoUpgrade,
  [switch] $help,
  [switch] $SkipPRCheck,
  [switch] $Preserve,
  [Parameter(Mandatory = $false)]
  [string] $PackageIdentifier,
  [Parameter(Mandatory = $false)]
  [string] $PackageVersion,
  [Parameter(Mandatory = $false)]
  [string] $Mode
)
$ProgressPreference = 'SilentlyContinue'

if ($help) {
  Write-Host -ForegroundColor 'Green' 'For full documentation of the script, see https://github.com/microsoft/winget-pkgs/tree/master/doc/tools/YamlCreate.md'
  Write-Host -ForegroundColor 'Yellow' 'Usage: ' -NoNewline
  Write-Host -ForegroundColor 'White' '.\YamlCreate.ps1 [-PackageIdentifier <identifier>] [-PackageVersion <version>] [-Mode <1-5>] [-Settings] [-SkipPRCheck]'
  Write-Host
  exit
}

# Custom menu prompt that listens for keypresses. Requires a prompt and array of entries at minimum. Entries preceeded with `*` are shown in green
# Returns a console key value
Function Invoke-KeypressMenu {
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
    [string] $DefaultString,
    [Parameter(Mandatory = $false)]
    [string[]] $AllowedCharacters
  )

  if (!$PSBoundParameters.ContainsKey('AllowedCharacters')) {
    $AllowedCharacters = @($Entries.TrimStart('*').Chars(1))
  }

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
    if ($keyInfo.KeyChar -notin $AllowedCharacters -and $ScriptSettings.ExplicitMenuOptions -eq $true -and $AllowedCharacters.Length -gt 0) {
      if ($keyInfo.Key -eq 'Enter') { Write-Host }
      $keyInfo = $null
    }
  } until ($keyInfo.Key)

  return $keyInfo.Key
}

#If the user has git installed, make sure it is a patched version
if (Get-Command 'git' -ErrorAction SilentlyContinue) {
  $GitMinimumVersion = [System.Version]::Parse('2.39.1')
  $gitVersionString = ((git version) | Select-String '([0-9]{1,}\.?){3,}').Matches.Value.Trim(' ', '.')
  $gitVersion = [System.Version]::Parse($gitVersionString)
  if ($gitVersion -lt $GitMinimumVersion) {
    # Prompt user to install git
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) {
      $_menu = @{
        entries       = @('[Y] Upgrade Git'; '*[N] Do not upgrade')
        Prompt        = 'The version of git installed on your machine does not satisfy the requirement of version >= 2.39.1; Would you like to upgrade?'
        HelpText      = "Upgrading will attempt to upgrade git using winget`n"
        DefaultString = ''
      }
      switch (Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText']) {
        'Y' {
          Write-Host
          try {
            winget upgrade --id Git.Git --exact
          } catch {
            throw [UnmetDependencyException]::new('Git could not be upgraded sucessfully', $_)
          } finally {
            $gitVersionString = ((git version) | Select-String '([0-9]{1,}\.?){3,}').Matches.Value.Trim(' ', '.')
            $gitVersion = [System.Version]::Parse($gitVersionString)
            if ($gitVersion -lt $GitMinimumVersion) {
              throw [UnmetDependencyException]::new('Git could not be upgraded sucessfully')
            }
          }
        }
        default { Write-Host; throw [UnmetDependencyException]::new('The version of git installed on your machine does not satisfy the requirement of version >= 2.39.1') }
      }
    } else {
      throw [UnmetDependencyException]::new('The version of git installed on your machine does not satisfy the requirement of version >= 2.39.1')
    }
  }
  # Check whether the script is present inside a fork/clone of microsoft/winget-pkgs repository
  try {
    $script:gitTopLevel = (Resolve-Path $(git rev-parse --show-toplevel)).Path
  } catch {
    # If there was an exception, the user isn't in a git repo. Throw a custom exception and pass the original exception as an InternalException
    throw [UnmetDependencyException]::new('This script must be run from inside a clone of the winget-pkgs repository', $_.Exception)
  }
}

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

$ScriptHeader = '# Created with YamlCreate.ps1 v2.2.13'
$ManifestVersion = '1.5.0'
$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$ofs = ', '
$callingUICulture = [Threading.Thread]::CurrentThread.CurrentUICulture
$callingCulture = [Threading.Thread]::CurrentThread.CurrentCulture
[Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
if (-not ([System.Environment]::OSVersion.Platform -match 'Win')) { $env:TEMP = '/tmp/' }
$wingetUpstream = 'https://github.com/microsoft/winget-pkgs.git'

if ($ScriptSettings.EnableDeveloperOptions -eq $true -and $null -ne $ScriptSettings.OverrideManifestVersion) {
  $script:UsesPrerelease = $ScriptSettings.OverrideManifestVersion -gt $ManifestVersion
  $ManifestVersion = $ScriptSettings.OverrideManifestVersion
}

$useDirectSchemaLink = if ($env:GITHUB_ACTIONS -eq $true) {
  $true
} else {
  (Invoke-WebRequest "https://aka.ms/winget-manifest.version.$ManifestVersion.schema.json" -UseBasicParsing).BaseResponse.ContentLength -eq -1
}
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
  $AppsAndFeaturesEntryProperties = (ConvertTo-Yaml $InstallerSchema.definitions.AppsAndFeaturesEntry.properties | ConvertFrom-Yaml -Ordered).Keys
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
  ARP_DisplayNameMinLength      = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayName.minLength
  ARP_DisplayNameMaxLength      = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayName.maxLength
  ARP_PublisherMinLength        = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.Publisher.minLength
  ARP_PublisherMaxLength        = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.Publisher.maxLength
  ARP_DisplayVersionMinLength   = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayVersion.minLength
  ARP_DisplayVersionMaxLength   = $InstallerSchema.Definitions.AppsAndFeaturesEntry.properties.DisplayVersion.maxLength
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

# Gets the effective installer type from an installer
Function Get-EffectiveInstallerType {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $Installer
  )
  if ($Installer.Keys -notcontains 'InstallerType') {
    throw [System.ArgumentException]::new('Invalid Function Parameters. Installer must contain `InstallerType` key')
  }
  if ($Installer.InstallerType -notin $Patterns.ArchiveInstallerTypes) {
    return $Installer.InstallerType
  }
  if ($Installer.Keys -notcontains 'NestedInstallerType') {
    throw [System.ArgumentException]::new("Invalid Function Parameters. Installer type $($Installer.InstallerType) must contain `NestedInstallerType` key")
  }
  return $Installer.NestedInstallerType
}

# Takes an array of strings and an array of colors then writes one line of text composed of each string being its respective color
Function Write-MulticolorLine {
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

# Checks a URL and returns the status code received from the URL
Function Test-Url {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $URL
  )
  try {
    $HTTP_Request = [System.Net.WebRequest]::Create($URL)
    $HTTP_Request.UserAgent = 'Microsoft-Delivery-Optimization/10.1'
    $HTTP_Response = $HTTP_Request.GetResponse()
    $script:ResponseUri = $HTTP_Response.ResponseUri.AbsoluteUri
    $HTTP_Status = [int]$HTTP_Response.StatusCode
  } catch {
    # Take no action here; If there is an exception, we will treat it like a 404
    $HTTP_Status = 404
  }
  If ($null -eq $HTTP_Response) { $HTTP_Status = 404 }
  Else { $HTTP_Response.Close() }

  return $HTTP_Status
}

# Checks a file name for validity and returns a boolean value
Function Test-ValidFileName {
  param([string]$FileName)
  $IndexOfInvalidChar = $FileName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars())
  # IndexOfAny() returns the value -1 to indicate no such character was found
  return $IndexOfInvalidChar -eq -1
}

# Prompts user to enter an Installer URL, Tests the URL to ensure it results in a response code of 200, validates it against the manifest schema
# Returns the validated URL which was entered
Function Request-InstallerUrl {
  do {
    Write-Host -ForegroundColor $(if ($script:_returnValue.Severity -gt 1) { 'red' } else { 'yellow' }) $script:_returnValue.ErrorString()
    if ($script:_returnValue.StatusCode -ne 409) {
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the download url to the installer.'
      $NewInstallerUrl = Read-Host -Prompt 'Url' | TrimString
    }
    $script:_returnValue = [ReturnValue]::GenericError()
    if ((Test-Url $NewInstallerUrl) -ne 200) {
      $script:_returnValue = [ReturnValue]::new(502, 'Invalid URL Response', 'The URL did not return a successful response from the server', 2)
    } else {
      if (($script:ResponseUri -ne $NewInstallerUrl) -and ($ScriptSettings.UseRedirectedURL -ne 'never') -and ($NewInstallerUrl -notmatch 'github')) {
        #If urls don't match, ask to update; If they do update, set custom error and check for validity;
        $_menu = @{
          entries       = @('*[Y] Use detected URL'; '[N] Use original URL')
          Prompt        = 'The URL provided appears to be redirected. Would you like to use the destination URL instead?'
          HelpText      = "Discovered URL: $($script:ResponseUri)"
          DefaultString = 'Y'
        }
        switch ($(if ($ScriptSettings.UseRedirectedURL -eq 'always') { 'Y' } else { Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] })) {
          'N' { Write-Host -ForegroundColor 'Green' "`nOriginal URL Retained - Proceeding with $NewInstallerUrl`n" } #Continue without replacing URL
          default {
            $NewInstallerUrl = $script:ResponseUri
            $script:_returnValue = [ReturnValue]::new(409, 'URL Changed', 'The URL was changed during processing and will be re-validated', 1)
            Write-Host
          }
        }
      }
      $NewInstallerUrl = [System.Web.HttpUtility]::UrlDecode($NewInstallerUrl.Replace('+', '%2B'))
      $NewInstallerUrl = $NewInstallerUrl.Replace(' ', '%20')
      if ($script:_returnValue.StatusCode -ne 409) {
        if (Test-String $NewInstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -MatchPattern $Patterns.InstallerUrl -NotNull) {
          $script:_returnValue = [ReturnValue]::Success()
        } else {
          if (Test-String -not $NewInstallerUrl -MaxLength $Patterns.InstallerUrlMaxLength -NotNull) {
            $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.InstallerUrlMaxLength)
          } elseif (Test-String -not $NewInstallerUrl -MatchPattern $Patterns.InstallerUrl) {
            $script:_returnValue = [ReturnValue]::PatternError()
          } else {
            $script:_returnValue = [ReturnValue]::GenericError()
          }
        }
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
  return $NewInstallerUrl
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
  if (Test-ValidFileName $_Filename) { $_OutFile = Join-Path $env:TEMP -ChildPath $_Filename }
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
      $_TableName = Get-Property -Object $_Table -PropertyName StringData -ArgumentList 1
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
        $_ItemName = Get-Property -Object $_Item -PropertyName StringData -ArgumentList 1
        if ($_Table -eq 'Property') { $_ItemValue = Get-Property -Object $_Item -PropertyName StringData -ArgumentList 2 -ErrorAction SilentlyContinue }
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

Function Get-ExeType {
  Param
  (
    [Parameter(Mandatory = $true)]
    [String] $Path
  )

  $nsis = @(
    77; 90; -112; 0; 3; 0; 0; 0; 4; 0; 0; 0; -1; -1; 0; 0;
    -72; 0; 0; 0; 0; 0; 0; 0; 64; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; -40; 0; 0; 0; 14; 31; -70; 14; 0; -76;
    9; -51; 33; -72; 1; 76; -51; 33; 84; 104; 105; 115;
    32; 112; 114; 111; 103; 114; 97; 109; 32; 99; 97;
    110; 110; 111; 116; 32; 98; 101; 32; 114; 117; 110;
    32; 105; 110; 32; 68; 79; 83; 32; 109; 111; 100;
    101; 46; 13; 13; 10; 36; 0; 0; 0; 0; 0; 0; 0; -83; 49;
    8; -127; -23; 80; 102; -46; -23; 80; 102; -46; -23;
    80; 102; -46; 42; 95; 57; -46; -21; 80; 102; -46;
    -23; 80; 103; -46; 76; 80; 102; -46; 42; 95; 59; -46;
    -26; 80; 102; -46; -67; 115; 86; -46; -29; 80; 102;
    -46; 46; 86; 96; -46; -24; 80; 102; -46; 82; 105; 99;
    104; -23; 80; 102; -46; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 80; 69; 0; 0; 76;
    1; 5; 0
  )

  $inno = @(
    77; 90; 80; 0; 2; 0; 0; 0; 4; 0; 15; 0; 255; 255; 0; 0;
    184; 0; 0; 0; 0; 0; 0; 0; 64; 0; 26; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 1; 0; 0; 186; 16; 0; 14; 31; 180; 9;
    205; 33; 184; 1; 76; 205; 33; 144; 144; 84; 104; 105;
    115; 32; 112; 114; 111; 103; 114; 97; 109; 32; 109;
    117; 115; 116; 32; 98; 101; 32; 114; 117; 110; 32;
    117; 110; 100; 101; 114; 32; 87; 105; 110; 51; 50;
    13; 10; 36; 55; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 80; 69; 0; 0; 76; 1; 10; 0)

  $burn = @(46; 119; 105; 120; 98; 117; 114; 110)

  $exeType = $null

  $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList ($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
  $reader = New-Object -TypeName System.IO.BinaryReader -ArgumentList $fileStream
  $bytes = $reader.ReadBytes(264)

  if (($bytes[0..223] -join '') -eq ($nsis -join '')) { $exeType = 'nullsoft' }
  elseif (($bytes -join '') -eq ($inno -join '')) { $exeType = 'inno' }
  # The burn header can appear before a certain point in the binary. Check to see if it's present in the first 264 bytes read
  elseif (($bytes -join '') -match ($burn -join '')) { $exeType = 'burn' }
  # If the burn header isn't present in the first 264 bytes, scan through the rest of the binary
  elseif ($ScriptSettings.IdentifyBurnInstallers -eq 'true') {
    $rollingBytes = $bytes[ - $burn.Length..-1]
    for ($i = 265; $i -lt ($fileStream.Length, 524280 | Measure-Object -Minimum).Minimum; $i++) {
      $rollingBytes = $rollingBytes[1..$rollingBytes.Length]
      $rollingBytes += $reader.ReadByte()
      if (($rollingBytes -join '') -match ($burn -join '')) {
        $exeType = 'burn'
        break
      }
    }
  }

  $reader.Dispose()
  $fileStream.Dispose()
  return $exeType
}

Function Get-UserSavePreference {
  switch ($ScriptSettings.SaveToTemporaryFolder) {
    'always' { $_Preference = '0' }
    'never' { $_Preference = '1' }
    'manual' { $_Preference = '2' }
    default {
      $_menu = @{
        entries       = @('[Y] Yes'; '*[N] No'; '[M] Manually Enter SHA256')
        Prompt        = 'Do you want to save the files to the Temp folder?'
        DefaultString = 'N'
      }
      switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'Y' { $_Preference = '0' }
        'N' { $_Preference = '1' }
        'M' { $_Preference = '2' }
        default { $_Preference = '1' }
      }
    }
  }
  return $_Preference
}

Function Get-PathInstallerType {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path
  )

  if ($Path -match '\.msix(bundle){0,1}$') { return 'msix' }
  if ($Path -match '\.msi$') {
    if ([System.Environment]::OSVersion.Platform -match 'Unix') {
      $ObjectDatabase = @{}
      $ObjectMetadata = @{
        ProgramName = $(([string](file $script:dest) | Select-String -Pattern 'Creating Application.+,').Matches.Value)
      }
    } else {
      $ObjectMetadata = Get-ItemMetadata $Path
      $ObjectDatabase = Get-MsiDatabase $Path
    }

    if (Test-IsWix -Database $ObjectDatabase -MetaDataObject $ObjectMetadata ) {
      return 'wix'
    }
    return 'msi'
  }
  if ($Path -match '\.appx(bundle){0,1}$') { return 'appx' }
  if ($Path -match '\.zip$') { return 'zip' }
  if ($Path -match '\.exe$') { return Get-ExeType($Path) }

  return $null
}

Function Get-UriArchitecture {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $URI
  )

  if ($URI -match '\b(x|win){0,1}64\b') { return 'x64' }
  if ($URI -match '\b((win|ia)32)|(x{0,1}86)\b') { return 'x86' }
  if ($URI -match '\b(arm|aarch)64\b') { return 'arm64' }
  if ($URI -match '\barm\b') { return 'arm' }
  return $null
}

Function Get-UriScope {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $URI
  )

  if ($URI -match '\buser\b') { return 'user' }
  if ($URI -match '\bmachine\b') { return 'machine' }
  return $null
}

function Get-PublisherHash($publisherName) {
  # Sourced from https://marcinotorowski.com/2021/12/19/calculating-hash-part-of-msix-package-family-name
  $publisherNameAsUnicode = [System.Text.Encoding]::Unicode.GetBytes($publisherName);
  $publisherSha256 = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash($publisherNameAsUnicode);
  $publisherSha256First8Bytes = $publisherSha256 | Select-Object -First 8;
  $publisherSha256AsBinary = $publisherSha256First8Bytes | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') };
  $asBinaryStringWithPadding = [System.String]::Concat($publisherSha256AsBinary).PadRight(65, '0');

  $encodingTable = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  $result = '';
  for ($i = 0; $i -lt $asBinaryStringWithPadding.Length; $i += 5) {
    $asIndex = [System.Convert]::ToInt32($asBinaryStringWithPadding.Substring($i, 5), 2);
    $result += $encodingTable[$asIndex];
  }

  return $result.ToLower();
}

Function Get-PackageFamilyName {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $FilePath
  )
  if ($FilePath -notmatch '\.(msix|appx)(bundle){0,1}$') { return $null }

  # Make the downloaded installer a zip file
  $_MSIX = Get-Item $FilePath
  $_Zip = Join-Path $_MSIX.Directory.FullName -ChildPath 'MSIX_YamlCreate.zip'
  $_ZipFolder = [System.IO.Path]::GetDirectoryName($_ZIp) + '\' + [System.IO.Path]::GetFileNameWithoutExtension($_Zip)
  Copy-Item -Path $_MSIX.FullName -Destination $_Zip
  # Progress preference has to be set globally for Expand-Archive
  # https://github.com/PowerShell/Microsoft.PowerShell.Archive/issues/77#issuecomment-601947496
  $globalPreference = $global:ProgressPreference
  $global:ProgressPreference = 'SilentlyContinue'
  # Expand the zip file to access the manifest inside
  Expand-Archive $_Zip -DestinationPath $_ZipFolder -Force
  # Restore the old progress preference
  $global:ProgressPreference = $globalPreference
  # Package could be a single package or a bundle, so regex search for either of them
  $_AppxManifest = Get-ChildItem $_ZipFolder -Recurse -File -Filter '*.xml' | Where-Object { $_.Name -match '^Appx(Bundle)?Manifest.xml$' } | Select-Object -First 1
  [XML] $_XMLContent = Get-Content $_AppxManifest.FullName -Raw
  # The path to the node is different between single package and bundles, this should work to get either
  $_Identity = @($_XMLContent.Bundle.Identity) + @($_XMLContent.Package.Identity)
  # Cleanup the files that were created
  Remove-Item $_Zip -Force
  Remove-Item $_ZipFolder -Recurse -Force
  # Return the PFN
  return $_Identity.Name + '_' + $(Get-PublisherHash $_Identity.Publisher)
}

# Prompts the user to enter the details for an archive Installer
# Takes the installer as an input
# Returns the modified installer
Function Read-NestedInstaller {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $_Installer
  )

  if ($_Installer['InstallerType'] -CIn @($Patterns.ArchiveInstallerTypes)) {
    # Manual Entry of Nested Installer Type with validation
    if ($_Installer['NestedInstallerType'] -CNotIn @($Patterns.ValidInstallerTypes)) {
      do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the NestedInstallerType. Options:' , @($Patterns.ValidNestedInstallerTypes -join ', ' )
        $_Installer['NestedInstallerType'] = Read-Host -Prompt 'NestedInstallerType' | TrimString
        if ($_Installer['NestedInstallerType'] -Cin @($Patterns.ValidNestedInstallerTypes)) {
          $script:_returnValue = [ReturnValue]::Success()
        } else {
          $script:_returnValue = [ReturnValue]::new(400, 'Invalid Installer Type', "Value must exist in the enum - $(@($Patterns.ValidNestedInstallerTypes -join ', '))", 2)
        }
      } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }
    $_EffectiveType = Get-EffectiveInstallerType $_Installer

    $_NestedInstallerFiles = @()
    do {
      $_InstallerFile = [ordered] @{}
      $AnotherNestedInstaller = $false
      $_RelativePath = $null
      $_Alias = $null
      do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the relative path to the installer file'
        if (Test-String -not $_RelativePath -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $_RelativePath" }
        $_RelativePath = Read-Host -Prompt 'RelativeFilePath' | TrimString
        if (Test-String -not $_RelativePath -IsNull) { $_InstallerFile['RelativeFilePath'] = $_RelativePath }

        if (Test-String $_RelativePath -MinLength $Patterns.RelativeFilePathMinLength -MaxLength $Patterns.RelativeFilePathMaxLength) {
          $script:_returnValue = [ReturnValue]::Success()
        } else {
          $script:_returnValue = [ReturnValue]::LengthError($Patterns.RelativeFilePathMinLength, $Patterns.RelativeFilePathMaxLength)
        }
        if ($_RelativePath -in @($_NestedInstallerFiles.RelativeFilePath)) {
          $script:_returnValue = [ReturnValue]::new(400, 'Path Collision', 'Relative file path must be unique', 2)
        }
      } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

      if ($_EffectiveType -eq 'portable') {
        do {
          Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
          Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the portable command alias'
          if (Test-String -not "$($_InstallerFile['PortableCommandAlias'])" -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $($_InstallerFile['PortableCommandAlias'])" }
          $_Alias = Read-Host -Prompt 'PortableCommandAlias' | TrimString
          if (Test-String -not $_Alias -IsNull) { $_InstallerFile['PortableCommandAlias'] = $_Alias }

          if (Test-String $_InstallerFile['PortableCommandAlias'] -MinLength $Patterns.PortableCommandAliasMinLength -MaxLength $Patterns.PortableCommandAliasMaxLength -AllowNull) {
            $script:_returnValue = [ReturnValue]::Success()
          } else {
            $script:_returnValue = [ReturnValue]::LengthError($Patterns.PortableCommandAliasMinLength, $Patterns.PortableCommandAliasMaxLength)
          }
          if ("$($_InstallerFile['PortableCommandAlias'])" -in @($_NestedInstallerFiles.PortableCommandAlias)) {
            $script:_returnValue = [ReturnValue]::new(400, 'Alias Collision', 'Aliases must be unique', 2)
          }
        } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

        # Prompt to see if multiple entries are needed
        $_menu = @{
          entries       = @(
            '[Y] Yes'
            '*[N] No'
          )
          Prompt        = 'Do you want to create another portable installer entry?'
          DefaultString = 'N'
        }
        switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
          'Y' { $AnotherNestedInstaller = $true }
          default { $AnotherNestedInstaller = $false }
        }
      }
      $_NestedInstallerFiles += $_InstallerFile
    } until (!$AnotherNestedInstaller)
    $_Installer['NestedInstallerFiles'] = $_NestedInstallerFiles
  }
  return $_Installer
}

Function Read-AppsAndFeaturesEntries {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $_Installer
  )

  $_AppsAndFeaturesEntries = @()
  # TODO: Support adding AppsAndFeaturesEntries if they don't exist
  if (!$_Installer.AppsAndFeaturesEntries) {
    return
  }

  # TODO: Support Multiple AppsAndFeaturesEntries once WinGet supports it
  # For now, only select and retain the first entry
  foreach ($_AppsAndFeaturesEntry in @($_Installer.AppsAndFeaturesEntries[0])) {
    $_AppsAndFeaturesEntries += Read-AppsAndFeaturesEntry $_AppsAndFeaturesEntry
  }
  return $_AppsAndFeaturesEntries
}

Function Read-AppsAndFeaturesEntry {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [PSCustomObject] $_AppsAndFeaturesEntry
  )

  # TODO: Support adding new fields instead of only editing existing ones
  if ($_AppsAndFeaturesEntry.DisplayName) { $_AppsAndFeaturesEntry['DisplayName'] = Read-ARPDisplayName $_AppsAndFeaturesEntry.DisplayName }
  if ($_AppsAndFeaturesEntry.DisplayVersion) { $_AppsAndFeaturesEntry['DisplayVersion'] = Read-ARPDisplayVersion $_AppsAndFeaturesEntry.DisplayVersion }
  if ($_AppsAndFeaturesEntry.Publisher) { $_AppsAndFeaturesEntry['Publisher'] = Read-ARPPublisher $_AppsAndFeaturesEntry.Publisher }
  # TODO: Support ProductCode, UpgradeCode, and InstallerType
  return Restore-YamlKeyOrder $_AppsAndFeaturesEntry $AppsAndFeaturesEntryProperties -NoComments
}

Function Read-ARPDisplayName {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $_DisplayName
  )
  # Request DisplayName and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the application name as it appears in control panel'
    if (Test-String -not $_DisplayName -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $_DisplayName" }
    $NewValue = Read-Host -Prompt 'DisplayName' | TrimString
    if (Test-String -not $NewValue -IsNull) { $_DisplayName = $NewValue }

    if (Test-String $_DisplayName -MinLength $Patterns.ARP_DisplayNameMinLength -MaxLength $Patterns.ARP_DisplayNameMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.ARP_DisplayNameMinLength, $Patterns.ARP_DisplayNameMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  return $_DisplayName
}

Function Read-ARPPublisher {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $_Publisher
  )
  # Request Publisher Name and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the Publisher name as it appears in control panel'
    if (Test-String -not $_Publisher -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $_Publisher" }
    $NewValue = Read-Host -Prompt 'Publisher' | TrimString
    if (Test-String -not $NewValue -IsNull) { $_Publisher = $NewValue }

    if (Test-String $_Publisher -MinLength $Patterns.ARP_PublisherMinLength -MaxLength $Patterns.ARP_PublisherMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.ARP_PublisherMinLength, $Patterns.ARP_PublisherMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  return $_Publisher
}

Function Read-ARPDisplayVersion {
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $_DisplayVersion
  )
  # Request DisplayVersion and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the application version as it appears in control panel'
    if (Test-String -not $_DisplayVersion -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $_DisplayVersion" }
    $NewValue = Read-Host -Prompt 'DisplayVersion' | TrimString
    if (Test-String -not $NewValue -IsNull) { $_DisplayVersion = $NewValue }

    if (Test-String $_DisplayVersion -MinLength $Patterns.ARP_DisplayVersionMinLength -MaxLength $Patterns.ARP_DisplayVersionMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.ARP_DisplayVersionMinLength, $Patterns.ARP_DisplayVersionMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  return $_DisplayVersion
}

# Prompts the user to enter installer values
# Sets the $script:Installers value as an output
# Returns void
Function Read-InstallerEntry {
  $_Installer = [ordered] @{}
  # Request user enter Installer URL
  $_Installer['InstallerUrl'] = Request-InstallerUrl

  if ($_Installer.InstallerUrl -in ($script:Installers).InstallerUrl) {
    $_MatchingInstaller = $script:Installers | Where-Object { $_.InstallerUrl -eq $_Installer.InstallerUrl } | Select-Object -First 1
    if ($_MatchingInstaller.InstallerSha256) { $_Installer['InstallerSha256'] = $_MatchingInstaller.InstallerSha256 }
    if ($_MatchingInstaller.InstallerType) { $_Installer['InstallerType'] = $_MatchingInstaller.InstallerType }
    if ($_MatchingInstaller.ProductCode) { $_Installer['ProductCode'] = $_MatchingInstaller.ProductCode }
    if ($_MatchingInstaller.PackageFamilyName) { $_Installer['PackageFamilyName'] = $_MatchingInstaller.PackageFamilyName }
    if ($_MatchingInstaller.SignatureSha256) { $_Installer['SignatureSha256'] = $_MatchingInstaller.SignatureSha256 }
  }

  # Get or request Installer Sha256
  # Check the settings to see if we need to display this menu
  if ($_Installer.Keys -notcontains 'InstallerSha256') {

    $script:SaveOption = Get-UserSavePreference
    # If user did not select manual entry for Sha256, download file and calculate hash
    # Also attempt to detect installer type and architecture
    if ($script:SaveOption -ne '2') {
      Write-Host
      $start_time = Get-Date
      Write-Host $NewLine
      Write-Host 'Downloading URL. This will take a while...' -ForegroundColor Blue
      try {
        $script:dest = Get-InstallerFile -URI $_Installer['InstallerUrl'] -PackageIdentifier $PackageIdentifier -PackageVersion $PackageVersion
      } catch {
        # Here we also want to pass any exceptions through for potential debugging
        throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
      }
      Write-Host "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)" -ForegroundColor Green
      $_Installer['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
      Get-PathInstallerType -Path $script:dest -OutVariable _ | Out-Null
      if ($_) { $_Installer['InstallerType'] = $_ | Select-Object -First 1 }
      Get-UriArchitecture -URI $_Installer['InstallerUrl'] -OutVariable _ | Out-Null
      if ($_) { $_Installer['Architecture'] = $_ | Select-Object -First 1 }
      Get-UriScope -URI $_Installer['InstallerUrl'] -OutVariable _ | Out-Null
      if ($_) { $_Installer['Scope'] = $_ | Select-Object -First 1 }
      if ([System.Environment]::OSVersion.Platform -match 'Win' -and ($script:dest).EndsWith('.msi')) {
        $ProductCode = ([string](Get-MSIProperty -MSIPath $script:dest -Parameter 'ProductCode') | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      } elseif ([System.Environment]::OSVersion.Platform -match 'Unix' -and (Get-Item $script:dest).Name.EndsWith('.msi')) {
        $ProductCode = ([string](file $script:dest) | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      }
      if (Test-String -Not "$ProductCode" -IsNull) { $_Installer['ProductCode'] = "$ProductCode" }
    }
    # Manual Entry of Sha256 with validation
    else {
      Write-Host
      do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the installer SHA256 Hash'
        $_Installer['InstallerSha256'] = Read-Host -Prompt 'InstallerSha256' | TrimString
        $_Installer['InstallerSha256'] = $_Installer['InstallerSha256'].toUpper()
        if ($_Installer['InstallerSha256'] -match $Patterns.InstallerSha256) {
          $script:_returnValue = [ReturnValue]::Success()
        } else {
          $script:_returnValue = [ReturnValue]::PatternError()
        }
      } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
    }
  }

  # Manual Entry of Architecture with validation
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    if (Test-String $_Installer['Architecture'] -IsNull) { Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the architecture. Options:' , @($Patterns.ValidArchitectures -join ', ') }
    else {
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the architecture. Options:' , @($Patterns.ValidArchitectures -join ', ')
      Write-Host -ForegroundColor 'DarkGray' -Object "Old Variable: $($_Installer['Architecture'])"
    }
    Read-Host -Prompt 'Architecture' -OutVariable _ | Out-Null
    if (Test-String $_ -Not -IsNull) { $_Installer['Architecture'] = $_ | TrimString }

    if ($_Installer['Architecture'] -Cin @($Patterns.ValidArchitectures)) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::new(400, 'Invalid Architecture', "Value must exist in the enum - $(@($Patterns.ValidArchitectures -join ', '))", 2)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Manual Entry of Installer Type with validation
  if ($_Installer['InstallerType'] -CNotIn @($Patterns.ValidInstallerTypes)) {
    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the InstallerType. Options:' , @($Patterns.ValidInstallerTypes -join ', ' )
      $_Installer['InstallerType'] = Read-Host -Prompt 'InstallerType' | TrimString
      if ($_Installer['InstallerType'] -Cin @($Patterns.ValidInstallerTypes)) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        $script:_returnValue = [ReturnValue]::new(400, 'Invalid Installer Type', "Value must exist in the enum - $(@($Patterns.ValidInstallerTypes -join ', '))", 2)
      }
      if ($_Installer['InstallerType'] -eq 'zip' -and $ManifestVersion -lt '1.4.0') {
        $script:_returnValue = [ReturnValue]::new(500, 'Zip Installer Not Supported', "Zip installers are only supported with ManifestVersion 1.4.0 or later. Current ManifestVersion: $ManifestVersion", 2)
      }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
  }

  # If the installer requires nested installer files, get them
  $_Installer = Read-NestedInstaller $_Installer

  $_Switches = [ordered] @{}
  # If Installer Type is `exe`, require the silent switches to be entered
  if ((Get-EffectiveInstallerType $_Installer) -ne 'portable') {
    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      if ((Get-EffectiveInstallerType $_Installer) -ieq 'exe') { Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent install switch. For example: /S, -verysilent, /qn, --silent, /exenoui' }
      else { Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent install switch. For example: /S, -verysilent, /qn, --silent, /exenoui' }
      Read-Host -Prompt 'Silent switch' -OutVariable _ | Out-Null
      if ($_) { $_Switches['Silent'] = $_ | TrimString }

      if (Test-String $_Switches['Silent'] -MaxLength $Patterns.SilentSwitchMaxLength -NotNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } elseif ((Get-EffectiveInstallerType $_Installer) -ne 'exe' -and (Test-String $_Switches['Silent'] -MaxLength $Patterns.SilentSwitchMaxLength -AllowNull)) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.SilentSwitchMaxLength)
      }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      if ((Get-EffectiveInstallerType $_Installer) -ieq 'exe') { Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the silent with progress install switch. For example: /S, -silent, /qb, /exebasicui' }
      else { Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the silent with progress install switch. For example: /S, -silent, /qb, /exebasicui' }
      Read-Host -Prompt 'Silent with progress switch' -OutVariable _ | Out-Null
      if ($_) { $_Switches['SilentWithProgress'] = $_ | TrimString }

      if (Test-String $_Switches['SilentWithProgress'] -MaxLength $Patterns.ProgressSwitchMaxLength -NotNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } elseif ((Get-EffectiveInstallerType $_Installer) -ne 'exe' -and (Test-String $_Switches['SilentWithProgress'] -MaxLength $Patterns.ProgressSwitchMaxLength -AllowNull)) {
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
    Read-Host -Prompt 'Custom Switch' -OutVariable _ | Out-Null
    if ($_) { $_Switches['Custom'] = $_ | TrimString }
    if (Test-String $_Switches['Custom'] -MaxLength $Patterns.CustomSwitchMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.CustomSwitchMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  if ($_Switches.Keys.Count -gt 0) { $_Installer['InstallerSwitches'] = $_Switches }

  # If the installer is `msix` or `appx`, prompt for or detect additional fields
  if ($_Installer['InstallerType'] -in @('msix'; 'appx')) {
    # Detect or prompt for Signature Sha256
    if (Get-Command 'winget' -ErrorAction SilentlyContinue) { $SignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($SignatureSha256.P2) { $SignatureSha256 = $SignatureSha256.P2.ToUpper() } }
    if ($SignatureSha256) { $_Installer['SignatureSha256'] = $SignatureSha256 }
    if (Test-String $_Installer['SignatureSha256'] -IsNull) {
      # Manual entry of Signature Sha256 with validation
      do {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the installer SignatureSha256'
        Read-Host -Prompt 'SignatureSha256' -OutVariable _ | Out-Null
        if ($_) { $_Installer['SignatureSha256'] = $_ | TrimString }
        if (Test-String $_Installer['SignatureSha256'] -MatchPattern $Patterns.SignatureSha256 -AllowNull) {
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
        entries       = @('*[F] Find Automatically'; '[M] Manually Enter PackageFamilyName')
        Prompt        = 'Discover the package family name?'
        DefaultString = 'F'
      }
      switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'M' { $ChoicePfn = '1' }
        default { $ChoicePfn = '0' }
      }
    }

    # If user selected to find automatically -
    # Install package, get family name, uninstall package
    if ($ChoicePfn -eq '0') {
      $_Installer['PackageFamilyName'] = Get-PackageFamilyName $script:dest
      if (Test-String -not $_Installer['PackageFamilyName'] -MatchPattern $Patterns.FamilyName) {
        $script:_returnValue = [ReturnValue]::new(500, 'Could not find PackageFamilyName', 'Value should be entered manually', 1)
      }
    }

    # Validate Package Family Name if found automatically
    # Allow for manual entry if selected or if validation failed
    do {
      if (($ChoicePfn -ne '0') -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
        Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
        Write-Host -ForegroundColor 'Yellow' -Object '[Recommended] Enter the PackageFamilyName'
        Read-Host -Prompt 'PackageFamilyName' -OutVariable _ | Out-Null
        if ($_) { $_Installer['PackageFamilyName'] = $_ | TrimString }
      }
      if (Test-String $_Installer['PackageFamilyName'] -MaxLength $Patterns.FamilyNameMaxLength -MatchPattern $Patterns.FamilyName -AllowNull) {
        if (Test-String $_Installer['PackageFamilyName'] -IsNull) { $_Installer['PackageFamilyName'] = "$([char]0x2370)" }
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        if (Test-String -not $_Installer['PackageFamilyName'] -MaxLength $Patterns.FamilyNameMaxLength) {
          $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.FamilyNameMaxLength)
        } elseif (Test-String -not $_Installer['PackageFamilyName'] -MatchPattern $Patterns.FamilyName) {
          $script:_returnValue = [ReturnValue]::PatternError()
        } else {
          $script:_returnValue = [ReturnValue]::GenericError()
        }
      }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
  }

  # Request installer locale with validation as optional
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the installer locale. For example: en-US, en-CA'
    Write-Host -ForegroundColor 'Blue' -Object 'https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
    Read-Host -Prompt 'InstallerLocale' -OutVariable _
    if ($_) { $_Installer['InstallerLocale'] = $_ | TrimString }
    # If user defined a default locale, add it
    if ((Test-String $_Installer['InstallerLocale'] -IsNull) -and (Test-String -not $ScriptSettings.DefaultInstallerLocale -IsNull)) { $_Installer['InstallerLocale'] = $ScriptSettings.DefaultInstallerLocale }

    if (Test-String $_Installer['InstallerLocale'] -MaxLength $Patterns.InstallerLocaleMaxLength -MatchPattern $Patterns.PackageLocale -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $_Installer['InstallerLocale'] -MaxLength $Patterns.InstallerLocaleMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(0, $Patterns.InstallerLocaleMaxLength)
      } elseif (Test-String -not $_Installer['InstallerLocale'] -MatchPattern $Patterns.PackageLocale) {
        $script:_returnValue = [ReturnValue]::PatternError()
      } else {
        $script:_returnValue = [ReturnValue]::GenericError()
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request product code with validation
  if ((Get-EffectiveInstallerType $_Installer) -notmatch 'portable') {
    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application product code. Looks like {CF8E6E00-9C03-4440-81C0-21FACB921A6B}'
      Write-Host -ForegroundColor 'White' -Object "ProductCode found from installer: $($_Installer['ProductCode'])"
      Write-Host -ForegroundColor 'White' -Object 'Can be found with ' -NoNewline; Write-Host -ForegroundColor 'DarkYellow' 'get-wmiobject Win32_Product | Sort-Object Name | Format-Table IdentifyingNumber, Name -AutoSize'
      $NewProductCode = Read-Host -Prompt 'ProductCode' | TrimString
      if (Test-String $NewProductCode -Not -IsNull) { $_Installer['ProductCode'] = $NewProductCode }
      elseif (Test-String $_Installer['ProductCode'] -Not -IsNull) { $_Installer['ProductCode'] = "$($_Installer['ProductCode'])" }

      if (Test-String $_Installer['ProductCode'] -MinLength $Patterns.ProductCodeMinLength -MaxLength $Patterns.ProductCodeMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        $script:_returnValue = [ReturnValue]::LengthError($Patterns.ProductCodeMinLength, $Patterns.ProductCodeMaxLength)
      }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    # Manual Entry of Scope
    if (Test-String $_Installer['Scope'] -IsNull) {
      $_menu = @{
        entries       = @('[M] Machine'; '[U] User'; '*[N] No idea')
        Prompt        = '[Optional] Enter the Installer Scope'
        DefaultString = 'N'
      }
      switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
        'M' { $_Installer['Scope'] = 'machine' }
        'U' { $_Installer['Scope'] = 'user' }
        default { }
      }
    }

    # Request upgrade behavior
    $_menu = @{
      entries       = @('*[I] Install'; '[U] Uninstall Previous')
      Prompt        = '[Optional] Enter the Upgrade Behavior'
      DefaultString = 'I'
    }
    switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
      'U' { $_Installer['UpgradeBehavior'] = 'uninstallPrevious' }
      default { $_Installer['UpgradeBehavior'] = 'install' }
    }
    Write-Host
  }

  # Request release date
  $script:ReleaseDatePrompted = $true
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application release date. Example: 2021-11-17'
    Read-Host -Prompt 'ReleaseDate' -OutVariable ReleaseDate | Out-Null
    try {
      Get-Date([datetime]$($ReleaseDate | TrimString)) -f 'yyyy-MM-dd' -OutVariable _ValidDate | Out-Null
      if ($_ValidDate) { $_Installer['ReleaseDate'] = $_ValidDate | TrimString }
      $script:_returnValue = [ReturnValue]::Success()
    } catch {
      if (Test-String $ReleaseDate -IsNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        $script:_returnValue = [ReturnValue]::new(400, 'Invalid Date', 'Input could not be resolved to a date', 2)
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  $AppsAndFeaturesEntries = Read-AppsAndFeaturesEntries $_Installer
  if ($AppsAndFeaturesEntries) {
    $_Installer['AppsAndFeaturesEntries'] = @($AppsAndFeaturesEntries)
  }

  if ($script:SaveOption -eq '1' -and (Test-Path -Path $script:dest)) { Remove-Item -Path $script:dest }

  # If the installers array is empty, create it
  if (!$script:Installers) {
    $script:Installers = @()
  }

  # Add the completed installer to the installers array
  $_Installer = Restore-YamlKeyOrder $_Installer $InstallerEntryProperties -NoComments
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
  switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
    'Y' { $AnotherInstaller = '0' }
    'N' { $AnotherInstaller = '1' }
    default { $AnotherInstaller = '1' }
  }

  # If there are additional entries, run this function again to fetch the values and add them to the installers array
  if ($AnotherInstaller -eq '0') {
    Write-Host; Read-InstallerEntry
  }
}

# Prompts user for Installer Values using the `Quick Update` Method
# Sets the $script:Installers value as an output
# Returns void
Function Read-QuickInstallerEntry {
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
    $_NewInstaller.Remove('InstallerSha256');

    # Show the user which installer entry they should be entering information for
    Write-Host -ForegroundColor 'Green' "Installer Entry #$_iteration`:`n"
    if ($_OldInstaller.InstallerLocale) { Write-Host -ForegroundColor 'Yellow' "`tInstallerLocale: $($_OldInstaller.InstallerLocale)" }
    if ($_OldInstaller.Architecture) { Write-Host -ForegroundColor 'Yellow' "`tArchitecture: $($_OldInstaller.Architecture)" }
    if ($_OldInstaller.InstallerType) { Write-Host -ForegroundColor 'Yellow' "`tInstallerType: $($_OldInstaller.InstallerType)" }
    if ($_OldInstaller.NestedInstallerType ) { Write-Host -ForegroundColor 'Yellow' "`tNestedInstallerType: $($_OldInstaller.NestedInstallerType)" }
    if ($_OldInstaller.Scope) { Write-Host -ForegroundColor 'Yellow' "`tScope: $($_OldInstaller.Scope)" }
    Write-Host

    # Request user enter the new Installer URL
    $_NewInstaller['InstallerUrl'] = Request-InstallerUrl

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
        Write-Host -ForegroundColor 'Green' 'Downloading Installer. . .'
        $script:dest = Get-InstallerFile -URI $_NewInstaller['InstallerUrl'] -PackageIdentifier $PackageIdentifier -PackageVersion $PackageVersion
      } catch {
        # Here we also want to pass any exceptions through for potential debugging
        throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
      }
      # Check that MSI's aren't actually WIX, and EXE's aren't NSIS, INNO or BURN
      Write-Host -ForegroundColor 'Green' "Installer Downloaded!`nProcessing installer data. . . "
      if ($_NewInstaller['InstallerType'] -in @('msi'; 'exe')) {
        $DetectedType = Get-PathInstallerType $script:dest
        if ($DetectedType -in @('msi'; 'wix'; 'nullsoft'; 'inno'; 'burn')) { $_NewInstaller['InstallerType'] = $DetectedType }
      }
      # Get the Sha256
      $_NewInstaller['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
      # Update the product code, if a new one exists
      # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
      $MSIProductCode = $null
      if ([System.Environment]::OSVersion.Platform -match 'Win' -and ($script:dest).EndsWith('.msi')) {
        $MSIProductCode = ([string](Get-MSIProperty -MSIPath $script:dest -Parameter 'ProductCode') | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      } elseif ([System.Environment]::OSVersion.Platform -match 'Unix' -and (Get-Item $script:dest).Name.EndsWith('.msi')) {
        $MSIProductCode = ([string](file $script:dest) | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      }
      if (Test-String -not $MSIProductCode -IsNull) {
        $_NewInstaller['ProductCode'] = $MSIProductCode
      } elseif ( ($_NewInstaller.Keys -contains 'ProductCode') -and ((Get-EffectiveInstallerType $_NewInstaller) -in @('appx'; 'msi'; 'msix'; 'wix'; 'burn'))) {
        $_NewInstaller.Remove('ProductCode')
      }
      # If the installer is msix or appx, try getting the new SignatureSha256
      # If the new SignatureSha256 can't be found, remove it if it exists
      $NewSignatureSha256 = $null
      if ($_NewInstaller.InstallerType -in @('msix', 'appx')) {
        if (Get-Command 'winget' -ErrorAction SilentlyContinue) { $NewSignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() } }
      }
      if (Test-String -not $NewSignatureSha256 -IsNull) {
        $_NewInstaller['SignatureSha256'] = $NewSignatureSha256
      } elseif ($_NewInstaller.Keys -contains 'SignatureSha256') {
        $_NewInstaller.Remove('SignatureSha256')
      }
      # If the installer is msix or appx, try getting the new package family name
      # If the new package family name can't be found, remove it if it exists
      if ($script:dest -match '\.(msix|appx)(bundle){0,1}$') {
        $PackageFamilyName = Get-PackageFamilyName $script:dest
        if (Test-String $PackageFamilyName -MatchPattern $Patterns.FamilyName) {
          $_NewInstaller['PackageFamilyName'] = $PackageFamilyName
        } elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') {
          $_NewInstaller.Remove('PackageFamilyName')
        }
      }
      # Remove the downloaded files
      Remove-Item -Path $script:dest
      Write-Host -ForegroundColor 'Green' "Installer updated!`n"
    }

    # Force a re-check of the Nested Installer Paths in case they changed between versions
    $_NewInstaller = Read-NestedInstaller $_NewInstaller

    # Force a re-check of the ARP entries in case they changed between versions
    $AppsAndFeaturesEntries = Read-AppsAndFeaturesEntries $_NewInstaller
    if ($AppsAndFeaturesEntries) {
      $_NewInstaller['AppsAndFeaturesEntries'] = @($AppsAndFeaturesEntries)
    }

    #Add the updated installer to the new installers array
    $_NewInstaller = Restore-YamlKeyOrder $_NewInstaller $InstallerEntryProperties -NoComments
    $_NewInstallers += $_NewInstaller
  }
  $script:Installers = $_NewInstallers
}

# Requests the user enter an optional value with a prompt
# If the value already exists, also print the existing value
# Returns the new value if entered, Returns the existing value if no new value was entered
Function Read-InstallerMetadataValue {
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
  if (Test-String -not $Variable -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $Variable" }
  $NewValue = Read-Host -Prompt $Key | TrimString

  if (Test-String -not $NewValue -IsNull) {
    return $NewValue
  } else {
    return $Variable
  }
}

# Sorts keys within an object based on a reference ordered dictionary
# If a key does not exist, it sets the value to a special character to be removed / commented later
# Returns the result as a new object
Function Restore-YamlKeyOrder {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'InputObject', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'NoComments', Justification = 'The variable is used inside a conditional but ScriptAnalyser does not recognize the scope')]
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
    'UpgradeCode'
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
    'Icons'
    'Agreements'
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
Function Read-InstallerMetadata {
  Write-Host

  # Request File Extensions and validate
  do {
    if (!$FileExtensions) { $FileExtensions = '' }
    else { $FileExtensions = $FileExtensions | ToLower | UniqueItems }
    $script:FileExtensions = Read-InstallerMetadataValue -Variable $FileExtensions -Key 'FileExtensions' -Prompt "[Optional] Enter any File Extensions the application could support. For example: html, htm, url (Max $($Patterns.MaxItemsFileExtensions))" | ToLower | UniqueItems

    if (($script:FileExtensions -split ',').Count -le $Patterns.MaxItemsFileExtensions -and $($script:FileExtensions.Split(',').Trim() | Where-Object { Test-String -Not $_ -MaxLength $Patterns.FileExtensionMaxLength -MatchPattern $Patterns.FileExtension -AllowNull }).Count -eq 0) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (($script:FileExtensions -split ',').Count -gt $Patterns.MaxItemsFileExtensions ) {
        $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsFileExtensions)
      } else {
        $script:_returnValue = [ReturnValue]::new(400, 'Invalid Entries', "Some entries do not match the requirements defined in the manifest schema - $($script:FileExtensions.Split(',').Trim() | Where-Object { Test-String -Not $_ -MaxLength $Patterns.FileExtensionMaxLength -MatchPattern $Patterns.FileExtension })", 2)
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Protocols and validate
  do {
    if (!$Protocols) { $Protocols = '' }
    else { $Protocols = $Protocols | ToLower | UniqueItems }
    $script:Protocols = Read-InstallerMetadataValue -Variable $Protocols -Key 'Protocols' -Prompt "[Optional] Enter any Protocols the application provides a handler for. For example: http, https (Max $($Patterns.MaxItemsProtocols))" | ToLower | UniqueItems
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
    $script:Commands = Read-InstallerMetadataValue -Variable $Commands -Key 'Commands' -Prompt "[Optional] Enter any Commands or aliases to run the application. For example: msedge (Max $($Patterns.MaxItemsCommands))" | UniqueItems
    if (($script:Commands -split ',').Count -le $Patterns.MaxItemsCommands) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsCommands)
    }
  }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Installer Success Codes and validate
  do {
    if (!$InstallerSuccessCodes) { $InstallerSuccessCodes = '' }
    $script:InstallerSuccessCodes = Read-InstallerMetadataValue -Variable $InstallerSuccessCodes -Key 'InstallerSuccessCodes' -Prompt "[Optional] List of additional non-zero installer success exit codes other than known default values by winget (Max $($Patterns.MaxItemsSuccessCodes))" | UniqueItems
    if (($script:InstallerSuccessCodes -split ',').Count -le $Patterns.MaxItemsSuccessCodes) {
      $script:_returnValue = [ReturnValue]::Success()
      try {
        #Ensure all values are integers
        $script:InstallerSuccessCodes.Split(',').Trim() | ForEach-Object { [long]$_ }
        $script:_returnValue = [ReturnValue]::Success()
      } catch {
        $script:_returnValue = [ReturnValue]::new(400, 'Invalid Data Type', 'The value entered does not match the type requirements defined in the manifest schema', 2)
      }
    } else {
      $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.MaxItemsSuccessCodes)
    }
  }  until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Install Modes and validate
  do {
    if ($script:InstallModes) { $script:InstallModes = $script:InstallModes | UniqueItems }
    $script:InstallModes = Read-InstallerMetadataValue -Variable $script:InstallModes -Key 'InstallModes' -Prompt "[Optional] List of supported installer modes. Options: $($Patterns.ValidInstallModes -join ', ')"
    if ($script:InstallModes) { $script:InstallModes = $script:InstallModes | UniqueItems }
    if ( (Test-String $script:InstallModes -IsNull) -or (($script:InstallModes -split ',').Count -le $Patterns.MaxItemsInstallModes -and $($script:InstallModes.Split(',').Trim() | Where-Object { $_ -CNotIn $Patterns.ValidInstallModes }).Count -eq 0)) {
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
Function Read-LocaleMetadata {
  # Request Package Locale and Validate
  if (Test-String -not $script:PackageLocale -MaxLength $Patterns.PackageLocaleMaxLength -MatchPattern $Patterns.PackageLocale -NotNull) {
    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Locale. For example: en-US, en-CA'
      Write-Host -ForegroundColor 'Blue' 'Reference Link: https://docs.microsoft.com/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a'
      $script:PackageLocale = Read-Host -Prompt 'PackageLocale' | TrimString
      if (Test-String $script:PackageLocale -MaxLength $Patterns.PackageLocaleMaxLength -MatchPattern $Patterns.PackageLocale -NotNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        if (Test-String $script:PackageLocale -not -MaxLength $Patterns.PackageLocaleMaxLength -NotNull) {
          $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.PackageLocaleMaxLength)
        } elseif (Test-String $script:PackageLocale -not -MatchPattern $Patterns.PackageLocale ) {
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
    if (Test-String $script:Publisher -IsNull) {
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full publisher name. For example: Microsoft Corporation'
    } else {
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full publisher name. For example: Microsoft Corporation'
      Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Publisher"
    }
    $NewPublisher = Read-Host -Prompt 'Publisher' | TrimString
    if (Test-String $NewPublisher -NotNull) {
      $script:Publisher = $NewPublisher
    }
    if (Test-String $script:Publisher -MaxLength $Patterns.PublisherMaxLength -NotNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.PublisherMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Application Name and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    if (Test-String $script:PackageName -IsNull) {
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the full application name. For example: Microsoft Teams'
    } else {
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the full application name. For example: Microsoft Teams'
      Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageName"
    }
    $NewPackageName = Read-Host -Prompt 'PackageName' | TrimString
    if (Test-String -not $NewPackageName -IsNull) { $script:PackageName = $NewPackageName }

    if (Test-String $script:PackageName -MaxLength $Patterns.PackageNameMaxLength -NotNull) {
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
      if (Test-String -not $script:Moniker -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Moniker" }
      $NewMoniker = Read-Host -Prompt 'Moniker' | ToLower | TrimString | NoWhitespace
      if (Test-String -not $NewMoniker -IsNull) { $script:Moniker = $NewMoniker }

      if (Test-String $script:Moniker -MaxLength $Patterns.MonikerMaxLength -AllowNull) {
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
    if (Test-String -not $script:PublisherUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherUrl" }
    $NewPublisherUrl = Read-Host -Prompt 'Publisher Url' | TrimString
    if (Test-String -not $NewPublisherUrl -IsNull) { $script:PublisherUrl = $NewPublisherUrl }
    if (Test-String $script:PublisherUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:PublisherUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:PublisherUrl -MatchPattern $Patterns.GenericUrl) {
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
    if (Test-String -not $script:PublisherSupportUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PublisherSupportUrl" }
    $NewPublisherSupportUrl = Read-Host -Prompt 'Publisher Support Url' | TrimString
    if (Test-String -not $NewPublisherSupportUrl -IsNull) { $script:PublisherSupportUrl = $NewPublisherSupportUrl }
    if (Test-String $script:PublisherSupportUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:PublisherSupportUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:PublisherSupportUrl -MatchPattern $Patterns.GenericUrl) {
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
    if (Test-String -not $script:PrivacyUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PrivacyUrl" }
    $NewPrivacyUrl = Read-Host -Prompt 'Publisher Privacy Url' | TrimString
    if (Test-String -not $NewPrivacyUrl -IsNull) { $script:PrivacyUrl = $NewPrivacyUrl }

    if (Test-String $script:PrivacyUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:PrivacyUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:PrivacyUrl -MatchPattern $Patterns.GenericUrl) {
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
    if (Test-String -not $script:Author -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Author" }
    $NewAuthor = Read-Host -Prompt 'Author' | TrimString
    if (Test-String -not $NewAuthor -IsNull) { $script:Author = $NewAuthor }

    if (Test-String $script:Author -MinLength $Patterns.AuthorMinLength -MaxLength $Patterns.AuthorMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.AuthorMinLength, $Patterns.AuthorMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Package URL and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the Url to the homepage of the application.'
    if (Test-String -not $script:PackageUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:PackageUrl" }
    $NewPackageUrl = Read-Host -Prompt 'Homepage' | TrimString
    if (Test-String -not $NewPackageUrl -IsNull) { $script:PackageUrl = $NewPackageUrl }
    if (Test-String $script:PackageUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:PackageUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:PackageUrl -MatchPattern $Patterns.GenericUrl) {
        $script:_returnValue = [ReturnValue]::PatternError()
      } else {
        $script:_returnValue = [ReturnValue]::GenericError()
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request License and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    if (Test-String $script:License -IsNull) {
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
    } else {
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License. For example: MIT, GPL, Freeware, Proprietary'
      Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:License"
    }
    $NewLicense = Read-Host -Prompt 'License' | TrimString
    if (Test-String -not $NewLicense -IsNull) { $script:License = $NewLicense }
    if (Test-String $script:License -MinLength $Patterns.LicenseMinLength -MaxLength $Patterns.LicenseMaxLength -NotNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } elseif (Test-String $script:License -IsNull) {
      $script:_returnValue = [ReturnValue]::new(400, 'Required Field', 'The value entered cannot be null or empty', 2)
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.LicenseMinLength, $Patterns.LicenseMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request License URL and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application License URL.'
    if (Test-String -not $script:LicenseUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:LicenseUrl" }
    $NewLicenseUrl = Read-Host -Prompt 'License URL' | TrimString
    if (Test-String -not $NewLicenseUrl -IsNull) { $script:LicenseUrl = $NewLicenseUrl }

    if (Test-String $script:LicenseUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:LicenseUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:LicenseUrl -MatchPattern $Patterns.GenericUrl) {
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
    if (Test-String -not $script:Copyright -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Copyright" }
    $NewCopyright = Read-Host -Prompt 'Copyright' | TrimString
    if (Test-String -not $NewCopyright -IsNull) { $script:Copyright = $NewCopyright }
    if (Test-String $script:Copyright -MinLength $Patterns.CopyrightMinLength -MaxLength $Patterns.CopyrightMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.CopyrightMinLength, $Patterns.CopyrightMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Copyright URL and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the application Copyright Url.'
    if (Test-String -not $script:CopyrightUrl -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:CopyrightUrl" }
    $NewCopyrightUrl = Read-Host -Prompt 'CopyrightUrl' | TrimString
    if (Test-String -not $NewCopyrightUrl -IsNull) { $script:CopyrightUrl = $NewCopyrightUrl }
    if (Test-String $script:CopyrightUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:CopyrightUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:CopyrightUrl -MatchPattern $Patterns.GenericUrl) {
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
    if (Test-String -not $script:Tags -IsNull) {
      $script:Tags = $script:Tags | ToLower | UniqueItems
      Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Tags"
    }
    $NewTags = Read-Host -Prompt 'Tags' | TrimString | ToLower | UniqueItems
    if (Test-String -not $NewTags -IsNull) { $script:Tags = $NewTags }
    if (($script:Tags -split ',').Count -le $Patterns.TagsMaxItems) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::MaxItemsError($Patterns.TagsMaxItems)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Short Description and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    if (Test-String $script:ShortDescription -IsNull) {
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter a short description of the application.'
    } else {
      Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a short description of the application.'
      Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:ShortDescription"
    }
    $NewShortDescription = Read-Host -Prompt 'Short Description' | TrimString
    if (Test-String -not $NewShortDescription -IsNull) { $script:ShortDescription = $NewShortDescription }
    if (Test-String $script:ShortDescription -MaxLength $Patterns.ShortDescriptionMaxLength -NotNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.ShortDescriptionMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request Long Description and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter a long description of the application.'
    if (Test-String -not $script:Description -IsNull) { Write-Host -ForegroundColor 'DarkGray' "Old Variable: $script:Description" }
    $NewDescription = Read-Host -Prompt 'Description' | TrimString
    if (Test-String -not $NewDescription -IsNull) { $script:Description = $NewDescription }
    if (Test-String $script:Description -MinLength $Patterns.DescriptionMinLength -MaxLength $Patterns.DescriptionMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.DescriptionMinLength, $Patterns.DescriptionMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request ReleaseNotes and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter release notes for this version of the package.'
    $script:ReleaseNotes = Read-Host -Prompt 'ReleaseNotes' | TrimString
    if (Test-String $script:ReleaseNotes -MinLength $Patterns.ReleaseNotesMinLength -MaxLength $Patterns.ReleaseNotesMaxLength -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      $script:_returnValue = [ReturnValue]::LengthError($Patterns.ReleaseNotesMinLength, $Patterns.ReleaseNotesMaxLength)
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

  # Request ReleaseNotes URL and Validate
  do {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Yellow' -Object '[Optional] Enter the release notes URL for this version of the package.'
    $script:ReleaseNotesUrl = Read-Host -Prompt 'ReleaseNotesUrl' | TrimString
    if (Test-String $script:ReleaseNotesUrl -MaxLength $Patterns.GenericUrlMaxLength -MatchPattern $Patterns.GenericUrl -AllowNull) {
      $script:_returnValue = [ReturnValue]::Success()
    } else {
      if (Test-String -not $script:ReleaseNotesUrl -MaxLength $Patterns.GenericUrlMaxLength -AllowNull) {
        $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.GenericUrlMaxLength)
      } elseif (Test-String -not $script:ReleaseNotesUrl -MatchPattern $Patterns.GenericUrl) {
        $script:_returnValue = [ReturnValue]::PatternError()
      } else {
        $script:_returnValue = [ReturnValue]::GenericError()
      }
    }
  } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)
}

# Requests the user to answer the prompts found in the winget-pkgs pull request template
# Uses this template and responses to create a PR
Function Read-PRBody {
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
        if ($? -and $(Get-Command 'winget' -ErrorAction SilentlyContinue)) {
          $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
          $_showMenu = $false
        } elseif ($script:Option -ne 'RemoveManifest') {
          $_menu = @{
            Prompt        = "Have you validated your manifest locally with 'winget validate --manifest <path>'?"
            Entries       = @('[Y] Yes'; '*[N] No')
            HelpText      = 'Automatic manifest validation failed. Check your manifest and try again'
            HelpTextColor = 'Red'
            DefaultString = 'N'
          }
        } else {
          $_showMenu = $false
          $PrBodyContentReply += @($_line)
        }
      }

      '*tested your manifest*' {
        if ($script:SandboxTest -eq '0') {
          $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
          $_showMenu = $false
        } elseif ($script:Option -ne 'RemoveManifest') {
          $_menu = @{
            Prompt        = "Have you tested your manifest locally with 'winget install --manifest <path>'?"
            Entries       = @('[Y] Yes'; '*[N] No')
            HelpText      = 'You did not test your Manifest in Windows Sandbox previously.'
            HelpTextColor = 'Red'
            DefaultString = 'N'
          }
        } else {
          $_showMenu = $false
          $PrBodyContentReply += @($_line)
        }
      }

      '*schema*' {
        if ($script:Option -ne 'RemoveManifest') {
          $_Match = ($_line | Select-String -Pattern 'https://+.+(?=\))').Matches.Value
          $_menu = @{
            Prompt        = $_line.TrimStart('- [ ]') -replace '\[|\]|\(.+\)', ''
            Entries       = @('[Y] Yes'; '*[N] No')
            HelpText      = "Reference Link: $_Match"
            HelpTextColor = ''
            DefaultString = 'N'
          }
        } else {
          $_showMenu = $false
          $PrBodyContentReply += @($_line)
        }
      }

      '*only modifies one*' {
        $PrBodyContentReply += @($_line.Replace('[ ]', '[X]'))
        $_showMenu = $false
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
      switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
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
  switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
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
          $_responseCode = Test-Url $_checkedURL
          if ($_responseCode -ne 200) {
            Write-Host -ForegroundColor 'Red' "Invalid Issue: $i"
            continue
          }
          $PrBodyContentReply += @("Resolves $i")
        } else {
          $_checkedURL = "https://github.com/microsoft/winget-pkgs/issues/$i"
          $_responseCode = Test-Url $_checkedURL
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

Function Get-DebugString {
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
  $debug += $(switch (([System.Environment]::NewLine).Length) {
      1 { 'LF.' }
      2 { 'CRLF.' }
      Default { 'XX.' }
    })
  $debug += $PSVersionTable.PSVersion -Replace '\.', '-'
  $debug += '.'
  $debug += [System.Environment]::OSVersion.Platform
  return $debug
}

Function Write-ManifestContent {
  Param
  (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $FilePath,
    [Parameter(Mandatory = $true, Position = 1)]
    [PSCustomObject] $YamlContent,
    [Parameter(Mandatory = $true, Position = 2)]
    [string] $Schema
  )
  [System.IO.File]::WriteAllLines($FilePath, @(
      $ScriptHeader + $(Get-DebugString);
      "# yaml-language-server: `$schema=$Schema";
      '';
      # This regex looks for lines with the special character ⍰ and comments them out
      $(ConvertTo-Yaml $YamlContent).TrimEnd() -replace "(.*)$([char]0x2370)", "# `$1"
    ), $Utf8NoBomEncoding)

  Write-Host "Yaml file created: $FilePath"
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
  $VersionManifest = Restore-YamlKeyOrder $VersionManifest $VersionProperties

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
  $script:VersionManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $VersionManifestPath -YamlContent $VersionManifest -Schema $SchemaUrls.version
}

# Take all the entered values and write the installer manifest file
Function Write-InstallerManifest {
  # If the old manifests exist, copy it so it can be updated in place, otherwise, create a new empty manifest
  if ($script:OldManifestType -eq 'MultiManifest') {
    $InstallerManifest = $script:OldInstallerManifest
  }
  if (!$InstallerManifest) { [PSCustomObject]$InstallerManifest = [ordered]@{} }

  #Add the properties to the manifest
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
    if ($_Installer['ReleaseDate'] -and !$script:ReleaseDatePrompted -and !$Preserve) { $_Installer.Remove('ReleaseDate') }
    elseif ($Preserve) {
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

  $InstallerManifest = Restore-YamlKeyOrder $InstallerManifest $InstallerProperties -NoComments

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
  $script:InstallerManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.installer.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $InstallerManifestPath -YamlContent $InstallerManifest -Schema $SchemaUrls.installer
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

  # Clean up the volatile fields
  if ($LocaleManifest['ReleaseNotes'] -and (Test-String $script:ReleaseNotes -IsNull) -and !$Preserve) { $LocaleManifest.Remove('ReleaseNotes') }
  if ($LocaleManifest['ReleaseNotesUrl'] -and (Test-String $script:ReleaseNotesUrl -IsNull) -and !$Preserve) { $LocaleManifest.Remove('ReleaseNotesUrl') }

  $LocaleManifest = Restore-YamlKeyOrder $LocaleManifest $LocaleProperties

  # Set the appropriate langage server depending on if it is a default locale file or generic locale file
  if ($LocaleManifest.ManifestType -eq 'defaultLocale') { $yamlServer = $SchemaUrls.defaultLocale } else { $yamlServer = $SchemaUrls.locale }

  # Create the folder for the file if it doesn't exist
  New-Item -ItemType 'Directory' -Force -Path $AppFolder | Out-Null
  $script:LocaleManifestPath = Join-Path $AppFolder -ChildPath "$PackageIdentifier.locale.$PackageLocale.yaml"

  # Write the manifest to the file
  Write-ManifestContent -FilePath $LocaleManifestPath -YamlContent $LocaleManifest -Schema $yamlServer

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

        # Clean up the volatile fields
        if ($OldLocaleManifest['ReleaseNotes'] -and (Test-String $script:ReleaseNotes -IsNull) -and !$Preserve) { $OldLocaleManifest.Remove('ReleaseNotes') }
        if ($OldLocaleManifest['ReleaseNotesUrl'] -and (Test-String $script:ReleaseNotesUrl -IsNull) -and !$Preserve) { $OldLocaleManifest.Remove('ReleaseNotesUrl') }

        $script:OldLocaleManifest = Restore-YamlKeyOrder $script:OldLocaleManifest $LocaleProperties
        Write-ManifestContent -FilePath $(Join-Path $AppFolder -ChildPath $DifLocale.Name) -YamlContent $OldLocaleManifest -Schema $SchemaUrls.locale
      }
    }
  }
}

function Remove-ManifestVersion {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Mandatory = $true, Position = 1)]
    [string] $PathToVersion
  )

  # Remove the manifest, and then any parent folders so long as the parent folders are empty
  do {
    Remove-Item -Path $PathToVersion -Recurse -Force
    $PathToVersion = Split-Path $PathToVersion
  } while (@(Get-ChildItem $PathToVersion).Count -eq 0)
  return $PathToVersion
}

## START OF MAIN SCRIPT ##

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
    Write-MulticolorLine '  [', '1', "] New Manifest or Package Version`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-MulticolorLine '  [', '2', '] Quick Update Package Version ', "(Note: Must be used only when previous version`'s metadata is complete.)`n" 'DarkCyan', 'White', 'DarkCyan', 'Green'
    Write-MulticolorLine '  [', '3', "] Update Package Metadata`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-MulticolorLine '  [', '4', "] New Locale`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-MulticolorLine '  [', '5', "] Remove a manifest`n" 'DarkCyan', 'White', 'DarkCyan'
    Write-MulticolorLine '  [', 'Q', ']', " Any key to quit`n" 'DarkCyan', 'White', 'DarkCyan', 'Red'
    Write-MulticolorLine "`nSelection: " 'White'

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
    default {
      Write-Host
      [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
      exit
    }
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
  switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
    'Y' { Write-Host -ForegroundColor DarkYellow -Object "`n`nContinuing with Quick Update" }
    'N' { $script:Option = 'New'; Write-Host -ForegroundColor DarkYellow -Object "`n`nSwitched to Full Update Experience" }
    default {
      Write-Host
      [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
      [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
      exit
    }
  }
}
Write-Host

# Request Package Identifier and Validate
do {
  if ((Test-String $PackageIdentifier -IsNull) -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the Package Identifier, in the following format <Publisher shortname.Application shortname>. For example: Microsoft.Excel'
    $script:PackageIdentifier = Read-Host -Prompt 'PackageIdentifier' | TrimString
  }

  $PackageIdentifierFolder = $PackageIdentifier.Replace('.', '\')
  if (Test-String $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength -MatchPattern $Patterns.PackageIdentifier) {
    $script:_returnValue = [ReturnValue]::Success()
  } else {
    if (Test-String -not $PackageIdentifier -MinLength 4 -MaxLength $Patterns.IdentifierMaxLength) {
      $script:_returnValue = [ReturnValue]::LengthError(4, $Patterns.IdentifierMaxLength)
    } elseif (Test-String -not $PackageIdentifier -MatchPattern $Patterns.PackageIdentifier) {
      $script:_returnValue = [ReturnValue]::PatternError()
    } else {
      $script:_returnValue = [ReturnValue]::GenericError()
    }
  }
} until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

# Request Package Version and Validate
do {
  if ((Test-String $PackageVersion -IsNull) -or ($script:_returnValue.StatusCode -ne [ReturnValue]::Success().StatusCode)) {
    Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
    Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the version. for example: 1.33.7'
    $script:PackageVersion = Read-Host -Prompt 'Version' | TrimString
  }
  if (Test-String $PackageVersion -MaxLength $Patterns.VersionMaxLength -MatchPattern $Patterns.PackageVersion -NotNull) {
    $script:_returnValue = [ReturnValue]::Success()
  } else {
    if (Test-String -not $PackageVersion -MaxLength $Patterns.VersionMaxLength -NotNull) {
      $script:_returnValue = [ReturnValue]::LengthError(1, $Patterns.VersionMaxLength)
    } elseif (Test-String -not $PackageVersion -MatchPattern $Patterns.PackageVersion) {
      $script:_returnValue = [ReturnValue]::PatternError()
    } else {
      $script:_returnValue = [ReturnValue]::GenericError()
    }
  }
} until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

# Check the api for open PR's
# This is unauthenticated because the call-rate per minute is assumed to be low
if ($ScriptSettings.ContinueWithExistingPRs -ne 'always' -and $script:Option -ne 'RemoveManifest' -and !$SkipPRCheck) {
  $PRApiResponse = @(Invoke-WebRequest "https://api.github.com/search/issues?q=repo%3Amicrosoft%2Fwinget-pkgs%20is%3Apr%20$($PackageIdentifier -replace '\.', '%2F'))%2F$PackageVersion%20in%3Apath&per_page=1" -UseBasicParsing -ErrorAction SilentlyContinue | ConvertFrom-Json)[0]
  # If there was a PR found, get the URL and title
  if ($PRApiResponse.total_count -gt 0) {
    $_PRUrl = $PRApiResponse.items.html_url
    $_PRTitle = $PRApiResponse.items.title
    if ($ScriptSettings.ContinueWithExistingPRs -eq 'never') {
      Write-Host -ForegroundColor Red "Existing PR Found - $_PRUrl"
      [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
      [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
      exit
    }
    $_menu = @{
      entries       = @('[Y] Yes'; '*[N] No')
      Prompt        = 'There may already be a PR for this change. Would you like to continue anyways?'
      DefaultString = 'N'
      HelpText      = "$_PRTitle - $_PRUrl"
      HelpTextColor = 'Blue'
    }
    switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor'] ) {
      'Y' { Write-Host }
      default {
        Write-Host
        [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
        [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
        exit
      }
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
    if ($PromptVersion -eq 'exit') {
      [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
      [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
      exit
    }
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
  if ($script:Option -in @('QuickUpdateVersion', 'Auto')) {
    Write-Host -ForegroundColor Red 'This option requires manifest of previous version of the package. If you want to create a new package, please select Option 1.'
    [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
    [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
    exit
  }
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
Switch ($script:Option) {
  'QuickUpdateVersion' {
    Read-QuickInstallerEntry
    Write-LocaleManifest
    Write-InstallerManifest
    Write-VersionManifest
  }

  'New' {
    Read-InstallerEntry
    Read-InstallerMetadata
    Read-LocaleMetadata
    Write-InstallerManifest
    Write-VersionManifest
    Write-LocaleManifest
  }

  'EditMetadata' {
    Read-InstallerMetadata
    Read-LocaleMetadata
    Write-InstallerManifest
    Write-VersionManifest
    Write-LocaleManifest
  }

  'NewLocale' {
    $PackageLocale = $null
    $script:OldLocaleManifest = [ordered]@{}
    $script:OldLocaleManifest['ManifestType'] = 'locale'
    Read-LocaleMetadata
    Write-LocaleManifest
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
    switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString'] -HelpText $_menu['HelpText'] -HelpTextColor $_menu['HelpTextColor']) {
      'Y' { Write-Host; continue }
      default {
        Write-Host;
        [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
        [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
        exit 1
      }
    }

    # Require that a reason for the deletion is provided
    do {
      Write-Host -ForegroundColor 'Red' $script:_returnValue.ErrorString()
      Write-Host -ForegroundColor 'Green' -Object '[Required] Enter the reason for removing this manifest'
      $script:RemovalReason = Read-Host -Prompt 'Reason' | TrimString
      # Check the reason for validity. The length requirements are arbitrary, but they have been set to encourage concise yet meaningful reasons
      if (Test-String $script:RemovalReason -MinLength 8 -MaxLength 128 -NotNull) {
        $script:_returnValue = [ReturnValue]::Success()
      } else {
        $script:_returnValue = [ReturnValue]::LengthError(8, 128)
      }
    } until ($script:_returnValue.StatusCode -eq [ReturnValue]::Success().StatusCode)

    $AppFolder = Remove-ManifestVersion $AppFolder
  }

  'Auto' {
    # Set new package version
    $script:OldInstallerManifest['PackageVersion'] = $PackageVersion
    $script:OldLocaleManifest['PackageVersion'] = $PackageVersion
    $script:OldVersionManifest['PackageVersion'] = $PackageVersion

    # Update the manifest with URLs that are already there
    Write-Host $NewLine
    Write-Host 'Updating Manifest Information. This may take a while...' -ForegroundColor Blue
    $_NewInstallers = @();
    foreach ($_Installer in $script:OldInstallerManifest.Installers) {
      $_Installer['InstallerUrl'] = [System.Web.HttpUtility]::UrlDecode($_Installer.InstallerUrl.Replace('+', '%2B'))
      $_Installer['InstallerUrl'] = $_Installer.InstallerUrl.Replace(' ', '%20')
      try {
        $script:dest = Get-InstallerFile -URI $_Installer.InstallerUrl -PackageIdentifier $PackageIdentifier -PackageVersion $PackageVersion
      } catch {
        # Here we also want to pass any exceptions through for potential debugging
        throw [System.Net.WebException]::new('The file could not be downloaded. Try running the script again', $_.Exception)
      }
      # Check that MSI's aren't actually WIX, and EXE's aren't NSIS, INNO or BURN
      if ($_Installer['InstallerType'] -in @('msi'; 'exe')) {
        $DetectedType = Get-PathInstallerType $script:dest
        if ($DetectedType -in @('msi'; 'wix'; 'nullsoft'; 'inno'; 'burn')) { $_Installer['InstallerType'] = $DetectedType }
      }
      # Get the Sha256
      $_Installer['InstallerSha256'] = (Get-FileHash -Path $script:dest -Algorithm SHA256).Hash
      # Update the product code, if a new one exists
      # If a new product code doesn't exist, and the installer isn't an `.exe` file, remove the product code if it exists
      $MSIProductCode = $null
      if ([System.Environment]::OSVersion.Platform -match 'Win' -and ($script:dest).EndsWith('.msi')) {
        $MSIProductCode = ([string](Get-MSIProperty -MSIPath $script:dest -Parameter 'ProductCode') | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      } elseif ([System.Environment]::OSVersion.Platform -match 'Unix' -and (Get-Item $script:dest).Name.EndsWith('.msi')) {
        $MSIProductCode = ([string](file $script:dest) | Select-String -Pattern '{[A-Z0-9]{8}-([A-Z0-9]{4}-){3}[A-Z0-9]{12}}').Matches.Value
      }
      if (Test-String -not $MSIProductCode -IsNull) {
        $_Installer['ProductCode'] = $MSIProductCode
      } elseif ( ($_Installer.Keys -contains 'ProductCode') -and ($_Installer.InstallerType -in @('appx'; 'msi'; 'msix'; 'wix'; 'burn'))) {
        $_Installer.Remove('ProductCode')
      }
      # If the installer is msix or appx, try getting the new SignatureSha256
      # If the new SignatureSha256 can't be found, remove it if it exists
      $NewSignatureSha256 = $null
      if ($_Installer.InstallerType -in @('msix', 'appx')) {
        if (Get-Command 'winget' -ErrorAction SilentlyContinue) { $NewSignatureSha256 = winget hash -m $script:dest | Select-String -Pattern 'SignatureSha256:' | ConvertFrom-String; if ($NewSignatureSha256.P2) { $NewSignatureSha256 = $NewSignatureSha256.P2.ToUpper() } }
      }
      if (Test-String -not $NewSignatureSha256 -IsNull) {
        $_Installer['SignatureSha256'] = $NewSignatureSha256
      } elseif ($_Installer.Keys -contains 'SignatureSha256') {
        $_Installer.Remove('SignatureSha256')
      }
      # If the installer is msix or appx, try getting the new package family name
      # If the new package family name can't be found, remove it if it exists
      if ($script:dest -match '\.(msix|appx)(bundle){0,1}$') {
        $PackageFamilyName = Get-PackageFamilyName $script:dest

        if (Test-String $PackageFamilyName -MatchPattern $Patterns.FamilyName) {
          $_Installer['PackageFamilyName'] = $PackageFamilyName
        } elseif ($_NewInstaller.Keys -contains 'PackageFamilyName') {
          $_Installer.Remove('PackageFamilyName')
        }
      }
      # Remove the downloaded files
      Remove-Item -Path $script:dest
      $_NewInstallers += Restore-YamlKeyOrder $_Installer $InstallerEntryProperties -NoComments
    }
    # Write the new manifests
    $script:Installers = $_NewInstallers
    Write-LocaleManifest
    Write-InstallerManifest
    Write-VersionManifest
    # Remove the old manifests
    if ($PackageVersion -ne $LastVersion) { Remove-ManifestVersion "$AppFolder\..\$LastVersion" }
  }
}

if ($script:Option -ne 'RemoveManifest') {
  # If the user has winget installed, attempt to validate the manifests
  if (Get-Command 'winget' -ErrorAction SilentlyContinue) { winget validate $AppFolder }

  # If the user has sandbox enabled, request to test the manifest in the sandbox
  if (Get-Command 'WindowsSandbox' -ErrorAction SilentlyContinue) {
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
        switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
          'Y' { $script:SandboxTest = '0' }
          'N' { $script:SandboxTest = '1' }
          default { $script:SandboxTest = '0' }
        }
        Write-Host
      }
    }
    if ($script:SandboxTest -eq '0') {
      if (Test-Path -Path "$gitTopLevel\Tools\SandboxTest.ps1") {
        $SandboxScriptPath = (Resolve-Path "$gitTopLevel\Tools\SandboxTest.ps1").Path
      } else {
        while ([string]::IsNullOrWhiteSpace($SandboxScriptPath)) {
          Write-Host
          Write-Host -ForegroundColor 'Green' -Object 'SandboxTest.ps1 not found, input path'
          $SandboxScriptPath = Read-Host -Prompt 'SandboxTest.ps1' | TrimString
        }
      }
      if ($script:UsesPrerelease) {
        & $SandboxScriptPath -Manifest $AppFolder -Prerelease -EnableExperimentalFeatures
      } else {
        & $SandboxScriptPath -Manifest $AppFolder
      }
    }
  }
}
# If the user has git installed, request to automatically submit the PR
if (Get-Command 'git' -ErrorAction SilentlyContinue) {
  switch ($ScriptSettings.AutoSubmitPRs) {
    'always' { $PromptSubmit = '0' }
    'never' { $PromptSubmit = '1' }
    default {
      $_menu = @{
        entries       = @('*[Y] Yes'; '[N] No')
        Prompt        = 'Do you want to submit your PR now?'
        DefaultString = 'Y'
      }
      switch ( Invoke-KeypressMenu -Prompt $_menu['Prompt'] -Entries $_menu['Entries'] -DefaultString $_menu['DefaultString']) {
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
      $AllVersions = (@($script:ExistingVersions) + @($PackageVersion)) | Sort-Object $ToNatural
      if ($AllVersions.Count -eq '1') { $CommitType = 'New package' }
      elseif ($script:PackageVersion -in $script:ExistingVersions) { $CommitType = 'Update' }
      elseif (($AllVersions.IndexOf($PackageVersion) + 1) -eq $AllVersions.Count) { $CommitType = 'New version' }
      elseif (($AllVersions.IndexOf($PackageVersion) + 1) -ne $AllVersions.Count) { $CommitType = 'Add version' }
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

  # check if upstream exists
  ($remoteUpstreamUrl = $(git remote get-url upstream)) *> $null
  if ($remoteUpstreamUrl -and $remoteUpstreamUrl -ne $wingetUpstream) {
    git remote set-url upstream $wingetUpstream
  } elseif (!$remoteUpstreamUrl) {
    Write-Host -ForegroundColor 'Yellow' 'Upstream does not exist. Permanently adding https://github.com/microsoft/winget-pkgs as remote upstream'
    git remote add upstream $wingetUpstream
  }

  # Fetch the upstream branch, create a commit onto the detached head, and push it to a new branch
  git fetch upstream master --quiet
  git switch -d upstream/master
  if ($LASTEXITCODE -eq '0') {
    # Make sure path exists and is valid before hashing
    $UniqueBranchID = ''
    if ($script:LocaleManifestPath -and (Test-Path -Path $script:LocaleManifestPath)) { $UniqueBranchID = $UniqueBranchID + $($(Get-FileHash $script:LocaleManifestPath).Hash[0..6] -Join '') }
    if ($script:InstallerManifestPath -and (Test-Path -Path $script:InstallerManifestPath)) { $UniqueBranchID = $UniqueBranchID + $($(Get-FileHash $script:InstallerManifestPath).Hash[0..6] -Join '') }
    if (Test-String -IsNull $UniqueBranchID) { $UniqueBranchID = 'DEL' }
    $BranchName = "$PackageIdentifier-$PackageVersion-$UniqueBranchID"
    # Git branch names cannot start with `.` cannot contain any of {`..`, `\`, `~`, `^`, `:`, ` `, `?`, `@{`, `[`}, and cannot end with {`/`, `.lock`, `.`}
    $BranchName = $BranchName -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
    git add "$(Join-Path (Get-Item $AppFolder).Parent.FullName -ChildPath '*')"
    git commit -m "$CommitType`: $PackageIdentifier version $PackageVersion" --quiet
    git switch -c "$BranchName" --quiet
    git push --set-upstream origin "$BranchName" --quiet

    # If the user has the cli too
    if (Get-Command 'gh' -ErrorAction SilentlyContinue) {
      # Request the user to fill out the PR template
      if (Test-Path -Path "$gitTopLevel\.github\PULL_REQUEST_TEMPLATE.md") {
        Read-PRBody (Resolve-Path "$gitTopLevel\.github\PULL_REQUEST_TEMPLATE.md").Path
      } else {
        while ([string]::IsNullOrWhiteSpace($PRTemplate)) {
          Write-Host
          Write-Host -ForegroundColor 'Green' -Object 'PULL_REQUEST_TEMPLATE.md not found, input path'
          $PRTemplate = Read-Host -Prompt 'PR Template' | TrimString
        }
        Read-PRBody "$PRTemplate"
      }
    }
  }

  # Restore the user's previous git settings to ensure we don't disrupt their normal flow
  if ($_previousConfig) {
    git config --replace core.safecrlf $_previousConfig
  } else {
    git config --unset core.safecrlf
  }
  if ($remoteUpstreamUrl -and $remoteUpstreamUrl -ne $wingetUpstream) {
    git remote set-url upstream $remoteUpstreamUrl
  }

} else {
  Write-Host
  [Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
  [Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture
  exit
}
[Threading.Thread]::CurrentThread.CurrentUICulture = $callingUICulture
[Threading.Thread]::CurrentThread.CurrentCulture = $callingCulture

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
