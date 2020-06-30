[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# The intent of this file is to help you generate a YAML file for publishing 
# to the Windows Package Manager repository.

# define variables
$OFS = "`r`n"  #linebreak

# Prompt for URL
While ($url.Length -eq 0) {
$url = Read-Host -Prompt 'Enter the URL to the installer' }
$OFS

write-host "Downloading URL.  This will take awhile...  "  -ForeGroundColor Blue 
$WebClient = New-Object System.Net.WebClient
# This downloads the installer

try {
    $stream = $WebClient.OpenRead($URL)
}
catch {
    write-host "Error downloading file. Please run the script again." -ForeGroundColor red
    exit 1
}


# This command will get the sha256 hash
$Hash=get-filehash -InputStream $stream
$stream.Close()


$string = "Url: " + $URL  ;
Write-Output $string
$string =  "Sha256: " + $Hash.Hash
$string
$OFS
write-host "File downloaded. Please Fill out required fields. "   

##########################################
# Read in metadata
##########################################

While ($id.Length -lt 4 -or $id.length -ge 255) {
write-host  'Enter the package Id, in the following format <Publisher.Appname>' 
$id = Read-Host -Prompt 'For example: Microsoft.Excel'
}

$host.UI.RawUI.ForegroundColor = "White"
While ($publisher.Length  -eq 0 -or $publisher.length -ge 128) {
$publisher = Read-Host -Prompt 'Enter the publisher'
}

While ($AppName.Length -eq 0 -or $AppName.length -ge 128) {
$AppName = Read-Host -Prompt 'Enter the application name'
}

While ($version.Length  -eq 0) {
$version = Read-Host -Prompt 'Enter the version. For example: 1.0, 1.0.0.0'
$filename=$version + ".yaml"
}

While ($License.Length  -eq 0 -or $License.length -ge 40) {
$License = Read-Host -Prompt 'Enter the License, For example: MIT, or Copyright (c) Microsoft Corporation'
}

While ($InstallerType -notin ("exe","msi","msix","inno","nullsoft","appx","wix","zip")) {
$InstallerType = Read-Host -Prompt   'Enter the InstallerType. For example: exe, msi, msix, inno, nullsoft'
}

While ($architecture -notin ("x86", "x64", "arm", "arm64", "neutral")) {
$architecture = Read-Host -Prompt 'Enter the architecture (x86, x64, arm, arm64, Neutral)'
} 

do {
    $LicenseUrl = Read-Host -Prompt   '[OPTIONAL] Enter the license URL'
} while ($LicenseUrl.Length -ge 1 -AND ($LicenseUrl.Length -lt 10 -or $LicenseUrl.Length -gt 2000))

do {
    $AppMoniker = Read-Host -Prompt   '[OPTIONAL] Enter the AppMoniker (friendly name). For example: vscode'
} while ($AppMoniker.Length -gt 40)

do {
    $Tags = Read-Host -Prompt   '[OPTIONAL] Enter any tags that would be useful to discover this tool. For example: zip, c++'
} while ($Tags.length -gt 40)

do {
    $Homepage = Read-Host -Prompt   '[OPTIONAL] Enter the Url to the homepage of the application'
} while ($Homepage.length -ge 1 -AND ($Homepage.Length -lt 10 -or $Homepage.Length -gt 2000))

do {
    $Description = Read-Host -Prompt '[OPTIONAL] Enter a description of the application'
} while ($Description.length -gt 500)

# Only prompt for silent switches if $InstallerType is "exe"
if ($InstallerType.ToLower() -eq "exe") {
$Silent = Read-Host -Prompt '[OPTIONAL] Enter the silent install switch'
$SilentWithProgress = Read-Host -Prompt '[OPTIONAL] Enter the silent (with progress) install switch'
}


##########################################
# Write  metadata
##########################################

$OFS
$string = "Id: " + $id
write-output $string | out-file $filename
write-host "Id: "  -ForeGroundColor Blue -NoNewLine
write-host $id  -ForeGroundColor White  

$string = "Version: " + $Version
write-output $string | out-file $filename -append
write-host "Version: "  -ForeGroundColor Blue -NoNewLine
write-host $Version -ForeGroundColor White


$string = "Name: " + $AppName
write-output $string | out-file $filename -append
write-host "Name: "  -ForeGroundColor Blue -NoNewLine
write-host $AppName  -ForeGroundColor White

$string = "Publisher: " + $Publisher
write-output $string | out-file $filename -append
write-host "Publisher: "  -ForeGroundColor Blue -NoNewLine
write-host $Publisher -ForeGroundColor White

$string = "License: " + $License
write-output $string | out-file $filename -append
write-host "License: "  -ForeGroundColor Blue -NoNewLine
write-host $License  -ForeGroundColor White

if (!($LicenseUrl.length -eq 0)) {

$string = "LicenseUrl: " + $LicenseUrl
write-output $string | out-file $filename -append
write-host "LicenseUrl: "  -ForeGroundColor Blue -NoNewLine
write-host $LicenseUrl  -ForeGroundColor White

}

if (!($AppMoniker.length -eq 0)) {

$string = "AppMoniker: " + $AppMoniker
write-output $string | out-file $filename -append
write-host "AppMoniker: "  -ForeGroundColor Blue -NoNewLine
write-host $AppMoniker  -ForeGroundColor White

}

if (!($Commands.length -eq 0)) {

$string = "Commands: " + $Commands
write-output $string | out-file $filename -append
write-host "Commands: "  -ForeGroundColor Blue -NoNewLine
write-host $Commands  -ForeGroundColor White

}

if (!($Tags.length -eq 0)) {

$string = "Tags: " + $Tags
write-output $string | out-file $filename -append
write-host "Tags: "  -ForeGroundColor Blue -NoNewLine
write-host $Tags  -ForeGroundColor White

}

if (!($Description.length -eq 0)) {

$string = "Description: " + $Description
write-output $string | out-file $filename -append
write-host "Description: "  -ForeGroundColor Blue -NoNewLine
write-host $Description  -ForeGroundColor White

}

if (!($Homepage.Length -eq 0))  {

$string = "Homepage: "+ $Homepage
write-output $string | out-file $filename -append
write-host "Homepage: "  -ForeGroundColor Blue -NoNewLine
write-host $Homepage  -ForeGroundColor White

}


write-output "Installers:" | out-file $filename -append 


$string = "  - Arch: " + $architecture
write-output $string | out-file $filename -append
write-host "Arch: "  -ForeGroundColor Blue -NoNewLine
write-host $architecture  -ForeGroundColor White

$string = "    Url: " + $Url
write-output $string | out-file $filename -append
write-host "Url: "  -ForeGroundColor Blue -NoNewLine
write-host $Url -ForeGroundColor White

$string = "    Sha256: " + $Hash.Hash
write-output $string | out-file $filename -append
write-host "Sha256 "  -ForeGroundColor Blue -NoNewLine
write-host $Hash.Hash  -ForeGroundColor White

$string = "    InstallerType: " + $InstallerType
write-output $string | out-file $filename -append
write-host "InstallerType "  -ForeGroundColor Blue -NoNewLine
write-host $InstallerType  -ForeGroundColor White

if (!($Silent.Length) -eq 0 -Or !($SilentWithProgress.Length -eq 0))  {

$string = "    Switches:"
write-output $string | out-file $filename -append
write-host "Switches "  -ForeGroundColor Blue -NoNewLine

}

if (!($Silent.Length -eq 0))  {

$string = "      Silent: " + $Silent
write-output $string | out-file $filename -append
write-host "Silent "  -ForeGroundColor Blue -NoNewLine
write-host $Silent  -ForeGroundColor White

}

if (!($SilentWithProgress.Length -eq 0))  {

$string = "      SilentWithProgress: " + $SilentWithProgress
write-output $string | out-file $filename -append
write-host "SilentWithProgress "  -ForeGroundColor Blue -NoNewLine
write-host $SilentWithProgress  -ForeGroundColor White

}

$FileOldEnconding = Get-Content -Raw $filename
Remove-Item -Path $filename
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($filename, $FileOldEnconding, $Utf8NoBomEncoding)

$string = "Yaml file created:  " + $filename
write-output $string

write-host "Now place this file in the following location: \manifests\<publisher>\<appname>  " 
