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
Write-Host "Downloading URL. This will take awhile..." -ForegroundColor Blue
$WebClient = New-Object System.Net.WebClient

try {
    $Stream = $WebClient.OpenRead($URL)
    $Hash = (Get-FileHash -InputStream $Stream -Algorithm SHA256).Hash
}
catch {
    Write-Host "Error downloading file. Please run the script again." -ForegroundColor Red
    exit 1
}
finally {
    $Stream.Close()
}

Write-Host "Url: $URL"
Write-Host "Sha256: $Hash"

Write-Host $NewLine
Write-Host "File downloaded. Please Fill out required fields."

#endregion
##########################################

##########################################
#region Read in metadata

while ($ID.Length -lt 4 -or $ID.Length -ge 255) {
    Write-Host 'Enter the package Id, in the following format <Publisher.Appname>'
    $ID = Read-Host -Prompt 'For example: Microsoft.Excel' | TrimString
}

$host.UI.RawUI.ForegroundColor = "White"
while ([string]::IsNullOrWhiteSpace($Publisher) -or $Publisher.Length -ge 128) {
    $Publisher = Read-Host -Prompt 'Enter the publisher' | TrimString
}

while ([string]::IsNullOrWhiteSpace($AppName) -or $AppName.Length -ge 128) {
    $AppName = Read-Host -Prompt 'Enter the application name' | TrimString
}

while ([string]::IsNullOrWhiteSpace($version)) {
    $version = Read-Host -Prompt 'Enter the version. For example: 1.0.0, 1.0.0.0, 1.0' | TrimString
    $ManifestName = $version + ".yaml"
}

while ([string]::IsNullOrWhiteSpace($License) -or $License.Length -ge 40) {
    $License = Read-Host -Prompt 'Enter the License, For example: MIT, or Copyright (c) Microsoft Corporation' | TrimString
}

while ($InstallerType -notin @("exe", "msi", "msix", "inno", "nullsoft", "appx", "wix", "zip")) {
    $InstallerType = Read-Host -Prompt 'Enter the InstallerType. For example: exe, msi, msix, inno, nullsoft'
}

while ($architecture -notin @("x86", "x64", "arm", "arm64", "neutral")) {
    $architecture = Read-Host -Prompt 'Enter the architecture (x86, x64, arm, arm64, Neutral)'
}

do {
    $LicenseUrl = Read-Host -Prompt '[OPTIONAL] Enter the license URL' | TrimString
} while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

do {
    $AppMoniker = Read-Host -Prompt '[OPTIONAL] Enter the AppMoniker (friendly name/alias). For example: vscode' | TrimString
} while ($AppMoniker.Length -gt 40)

do {
    $Tags = Read-Host -Prompt '[OPTIONAL] Enter any tags that would be useful to discover this tool. For example: zip, c++' | TrimString
} while ($Tags.Length -gt 40)

do {
    $Homepage = Read-Host -Prompt '[OPTIONAL] Enter the Url to the homepage of the application' | TrimString
} while (-not [string]::IsNullOrWhiteSpace($LicenseUrl) -and ($Homepage.Length -lt 10 -or $Homepage.Length -gt 2000))

do {
    $Description = Read-Host -Prompt '[OPTIONAL] Enter a description of the application' | TrimString
} while ($Description.Length -gt 500)

# Only prompt for silent switches if $InstallerType is "exe"
if ($InstallerType -ieq "exe") {
    $Silent = Read-Host -Prompt '[OPTIONAL] Enter the silent install switch'| TrimString
    $SilentWithProgress = Read-Host -Prompt '[OPTIONAL] Enter the silent (with progress) install switch'| TrimString
}

#endregion
##########################################

##########################################
#region Write metadata

# YAML files should always start with the document start separator "---"
# https://yaml.org/spec/1.2/spec.html#id2760395
$string = "---$NewLine"
Write-Output $string | Out-File $ManifestName

Write-Host $NewLine
$string = "Id: $ID"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Id: " -ForegroundColor Blue -NoNewline
Write-Host $ID -ForegroundColor White

$string = "Version: $Version"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Version: " -ForegroundColor Blue -NoNewline
Write-Host $Version -ForegroundColor White

$string = "Name: $AppName"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Name: " -ForegroundColor Blue -NoNewline
Write-Host $AppName -ForegroundColor White

$string = "Publisher: $Publisher"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Publisher: " -ForegroundColor Blue -NoNewline
Write-Host $Publisher -ForegroundColor White

$string = "License: $License"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "License: " -ForegroundColor Blue -NoNewline
Write-Host $License -ForegroundColor White

if (-not [string]::IsNullOrWhiteSpace($LicenseUrl)) {
    $string = "LicenseUrl: $LicenseUrl"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "LicenseUrl: " -ForegroundColor Blue -NoNewline
    Write-Host $LicenseUrl -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($AppMoniker)) {
    $string = "AppMoniker: $AppMoniker"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "AppMoniker: " -ForegroundColor Blue -NoNewline
    Write-Host $AppMoniker -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($Commands)) {
    $string = "Commands: $Commands"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Commands: " -ForegroundColor Blue -NoNewline
    Write-Host $Commands -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($Tags)) {
    $string = "Tags: $Tags"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Tags: " -ForegroundColor Blue -NoNewline
    Write-Host $Tags -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($Description)) {
    $string = "Description: $Description"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Description: " -ForegroundColor Blue -NoNewline
    Write-Host $Description -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($Homepage)) {
    $string = "Homepage: $Homepage"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Homepage: " -ForegroundColor Blue -NoNewline
    Write-Host $Homepage -ForegroundColor White
}

Write-Output "Installers:" | Out-File $ManifestName -Append

$string = "  - Arch: $architecture"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Arch: " -ForegroundColor Blue -NoNewline
Write-Host $architecture -ForegroundColor White

$string = "    Url: $URL"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Url: " -ForegroundColor Blue -NoNewline
Write-Host $URL -ForegroundColor White

$string = "    Sha256: $Hash"
Write-Output $string | Out-File $ManifestName -Append
Write-Host "Sha256: " -ForegroundColor Blue -NoNewline
Write-Host $Hash -ForegroundColor White

$string = "    InstallerType: $InstallerType" 
Write-Output $string | Out-File $ManifestName -Append
Write-Host "InstallerType: " -ForegroundColor Blue -NoNewline
Write-Host $InstallerType -ForegroundColor White

if ((-not [string]::IsNullOrWhiteSpace($Silent)) -or 
    (-not [string]::IsNullOrWhiteSpace($SilentWithProgress))) {
    $string = "    Switches:"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Switches: " -ForegroundColor Blue -NoNewline
}

if (-not [string]::IsNullOrWhiteSpace($Silent)) {
    $string = "      Silent: $Silent"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "Silent: " -ForegroundColor Blue -NoNewline
    Write-Host $Silent -ForegroundColor White
}

if (-not [string]::IsNullOrWhiteSpace($SilentWithProgress)) {
    $string = "      SilentWithProgress: $SilentWithProgress"
    Write-Output $string | Out-File $ManifestName -Append
    Write-Host "SilentWithProgress: " -ForegroundColor Blue -NoNewline
    Write-Host $SilentWithProgress -ForegroundColor White
}

$ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
$PublisherFolder = Join-Path $ManifestsFolder $Publisher
$AppFolder = Join-Path $PublisherFolder $AppName
New-Item -ItemType "Directory" -Force -Path $AppFolder | Out-Null

$FileOldEncoding = Get-Content -Raw $ManifestName
Remove-Item -Path $ManifestName
$ManifestPath = Join-Path $AppFolder $ManifestName
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($ManifestPath, $FileOldEncoding, $Utf8NoBomEncoding)

Write-Host $NewLine
Write-Host "Yaml file created: $ManifestPath"

#endregion
##########################################
