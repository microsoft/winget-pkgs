Param ([switch] $Orca)
if($args) {
    Foreach($DownloadUrl in $args) {
        $WebClient = New-Object System.Net.WebClient
        $Filename = [System.IO.Path]::GetFileName($DownloadUrl)
        $location = "C:\Users\Bittu\Downloads\winget-pkgs\$FileName"
        try {
            $WebClient.DownloadFile($DownloadUrl, $location)
        } catch {
            Write-Host 'Error downloading file. Please run the script again.' -ForegroundColor Red
            exit 1
        }
        if ($location.EndsWith('appx') -or $location.EndsWith('msix') -or $location.EndsWith('appxbundle') -or $location.EndsWith('msixbundle')) {
            winget hash -f $location -m
            $ProgressPreference = 'SilentlyContinue'
            Add-AppxPackage -Path $location
            $InstalledPkgs = Get-AppxPackage | Select-Object PackageFamilyName,PackageFullName
            do {
                $PkgName = Read-Host -Prompt 'Enter Package Name'
            } until ($InstalledPkgs -match $PkgName)
            $PkgName = Read-Host -Prompt 'Enter Package Name'
            Write-Host "PackageFamilyName: $(($InstalledPkgs -match $PkgName).PackageFamilyName)"
            Remove-AppxPackage $(($InstalledPkgs -match $PkgName).PackageFullName)
            Remove-Item -Path $location
        } else {
            if (-not $Orca) {
                $MyProductCode = Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher
                Write-Host "ProductCode: '$($MyProductCode.BinaryName)'"
                Write-Host "Version/ARP: $($MyProductCode.BinaryVersion)"
                Remove-Item -Path $location
            } else {
                & "C:\Program Files (x86)\Orca\Orca.exe" $location
            }
        }
    }
} else {
    Write-Host "No urls entered."
}