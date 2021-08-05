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
        if (-not $Orca) {
            $MyProductCode = Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher
            Write-Host "ProductCode: '$($MyProductCode.BinaryName)'"
            Write-Host "Version/ARP: $($MyProductCode.BinaryVersion)"
            Remove-Item -Path $location
        } else {
            & "C:\Program Files (x86)\Orca\Orca.exe" $location
        }
    }
} else {
    Write-Host "No urls entered."
}