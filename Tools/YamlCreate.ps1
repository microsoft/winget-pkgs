$OFS = "`r`n"

While ($url.Length -eq 0) {
$url = Read-Host -Prompt 'Enter URL' }

$OFS



$tempFolder=$env:TEMP;
$Hashfile=$tempFolder + "\TempfileName.txt"
 

write-host "Downloading URL.  This will take awhile...  "  -ForeGroundColor Blue 


$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($URL, $Hashfile)



$Hash=get-filehash $hashfile

$string = "Url: " + $URL  ;

Write-Output $string
$string =  "Sha256: " + $Hash.Hash
$string

$OFS

write-host "Downloaded.  Fill out required fields. "   



##########################################
# Read in metadata
##########################################


While ($id.Length -eq 0) {
$id = Read-Host -Prompt 'Enter Id.  <publisher.appname>'
}
$host.UI.RawUI.ForegroundColor = "White"
While ($AppName.Length -eq 0) {

$AppName = Read-Host -Prompt 'Enter the application name'
}
$host.UI.RawUI.ForegroundColor = "White"
While ($publisher.Length  -eq 0) {

$publisher = Read-Host -Prompt 'Enter the publisher'

}

While ($version.Length  -eq 0) {

$version = Read-Host -Prompt 'Enter the version (xxxx.xxxxx.xxxxx.xxxxx)'

$filename=$version + ".yaml"
}

While ($architecture.Length  -eq 0) {
$architecture = Read-Host -Prompt 'Enter the architecture (x86, x64, arm, arm64)'
} 
While ($License.Length  -eq 0) {

$License = Read-Host -Prompt 'Enter the License'

}

While ($InstallerType.Length  -eq 0) {$InstallerType = Read-Host -Prompt   'Enter the InstallerType (exe, msi, msix, inno, nullsoft)'
}

$LicenseUrl = Read-Host -Prompt   'Enter the license URL'
$Commands = Read-Host -Prompt   'Enter supported commands'
$AppMoniker = Read-Host -Prompt   'Enter the AppMoniker (friendly name)'
$Tags = Read-Host -Prompt   'Enter any tags to help search for this tool'
$Homepage = Read-Host -Prompt   'Enter the homepage'
$Description = Read-Host -Prompt 'Enter a description'



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



if (!($HomePage.Length -eq 0))  {

$string = "Homepage: "+ $HomePage
write-output $string | out-file $filename -append
write-host "Homepage: "  -ForeGroundColor Blue -NoNewLine
write-host $HomePage  -ForeGroundColor White

}

write-output "Installers:" | out-file $filename -append 


$string = "  - Arch: " + $Architecture
write-output $string | out-file $filename -append
write-host "Arch: "  -ForeGroundColor Blue -NoNewLine
write-host $arch  -ForeGroundColor White


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
write-host "Sha256 "  -ForeGroundColor Blue -NoNewLine
write-host $InstallerType  -ForeGroundColor White


$string = "Yaml file created:  " + $filename
write-output $string


