#Requires -Version 5
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]

Param
(
    [switch] $Clean,
    [switch] $Prerelease,
    [switch] $Latest,
    [Parameter(Mandatory = $false)]
    [string] $Version
)

$releasesAPIResponse = Invoke-RestMethod 'https://api.github.com/repos/microsoft/winget-cli/releases?per_page=100'

if (!$Prerelease) {
    $releasesAPIResponse = $releasesAPIResponse.Where({ !$_.prerelease })
}

if ($PSBoundParameters.Keys -contains 'Version') {
    $releasesAPIResponse = @($releasesAPIResponse.Where({ $_.tag_name -match $('^v?' + [regex]::escape($Version)) }))
}

if ($Latest) {
    $releasesAPIResponse = @($releasesAPIResponse | Select-Object -First 1)
}

if ($releasesAPIResponse.Length -lt 1) {
    Write-Output 'No releases found matching criteria'
    exit 1
}

$releasesAPIResponse = $releasesAPIResponse | Sort-Object -Property published_at -Descending
$assets = $releasesAPIResponse[0].assets
$shaFileUrl = $assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.txt' }).browser_download_url
$msixFileUrl = $assets.Where({ $_.name -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' }).browser_download_url
$releaseTag = $releasesAPIResponse[0].tag_name
Write-Host "Found $releaseTag"

if ($Clean) {
    Get-AppxPackage 'Microsoft.DesktopAppInstaller' | Remove-AppxPackage
}

$shaFile = New-TemporaryFile
Invoke-WebRequest -Uri $shaFileUrl -OutFile $shaFile
$sha256 = Get-Content $shaFile -Tail 1
Remove-Item $shaFile -Force

$versionFolder = Join-Path $env:LOCALAPPDATA -ChildPath "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\bin\$releaseTag"
if (!(Test-Path $versionFolder)) {
    New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
}
$existingFiles = Get-ChildItem $versionFolder -File
$msixFile = $null
foreach ($file in $existingFiles) {
    if ((Get-FileHash $file.FullName).Hash.ToLower() -eq $sha256) {
        $msixFile = $file
        Write-Output 'Found file in local store. Skipping download'
    }
}
if (!$msixFile) {
    $outputPath = Join-Path $versionFolder -ChildPath "winget_$releaseTag.msix"
    Write-Output "Downloading version $releaseTag to $outputPath"
    Invoke-WebRequest -Uri $msixFileUrl -OutFile $outputPath
    $file = Get-Item $outputPath
    if ((Get-FileHash $file).Hash.ToLower() -ne $sha256) {
        Write-Output 'Download failed. Installer hashes do not match.'
        exit 1
    } else {
        $msixFile = $file
    }
}
Add-AppxPackage $msixFile.FullName -ForceUpdateFromAnyVersion
Write-Output 'Checking winget version . . .'
& winget -v
