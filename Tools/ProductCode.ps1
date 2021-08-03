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
        $MyProductCode = Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher | Select-Object BinaryName
        Write-Host "Found ProductCode is: $($MyProductCode.BinaryName)"
        Remove-Item -Path $location
    }
} else {
    Write-Host "No urls entered."
}