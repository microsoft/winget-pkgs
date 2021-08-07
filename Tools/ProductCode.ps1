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
        if ($location.EndsWith('appx','CurrentCultureIgnoreCase') -or $location.EndsWith('msix','CurrentCultureIgnoreCase') -or $location.EndsWith('appxbundle','CurrentCultureIgnoreCase') -or $location.EndsWith('msixbundle','CurrentCultureIgnoreCase')) {
            winget hash -f $location -m
            $ProgressPreference = 'SilentlyContinue'
            Add-AppxPackage -Path $location
            $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName,PackageFullName
            Write-Host "PackageFamilyName: $($InstalledPkg.PackageFamilyName)"
            Remove-AppxPackage $InstalledPkg.PackageFullName
            Remove-Item -Path $location
        } else {
            if (-not $Orca) {
                $MyProductCode = Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher
                Write-Host "ProductCode: '$($MyProductCode.BinaryName)'"
                Write-Host "Version/ARP: $($MyProductCode.BinaryVersion)"
                Remove-Item -Path $location
            } else {
                Start-Process -FilePath "C:\Program Files (x86)\Orca\Orca.exe" -ArgumentList $location -Wait
                Remove-Item -Path $location
            }
        }
    }
} else {
    Write-Host "No urls entered."
}