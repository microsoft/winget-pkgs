function Initialize-Folder {
    param (
        [Parameter(Mandatory = $true)]
        [String] $FolderPath
    )

    $FolderPath = [System.IO.Path]::GetFullPath($FolderPath)
    if (Test-Path -Path $FolderPath -PathType Container) { return $true }
    if (Test-Path -Path $FolderPath) { return $false }

    try {
        New-Item -Path $FolderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Request-RemoveItem {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path,
        [int] $Retries = 6,
        [int] $DelayMs = 250
    )

    # Check if path exists using .NET
    $fileInfo = [System.IO.FileInfo]$Path
    $dirInfo = [System.IO.DirectoryInfo]$Path

    if (-not ($fileInfo.Exists -or $dirInfo.Exists)) { return }

    for ($i = 0; $i -lt $Retries; $i++) {
        try {
            if ($dirInfo.Exists) {
                $dirInfo.Delete($true)
            } elseif ($fileInfo.Exists) {
                $fileInfo.Delete()
            }
            return
        } catch [System.IO.IOException] {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds $DelayMs
            $DelayMs = [Math]::Min(5000, $DelayMs * 2)
        } catch {
            throw
        }
    }

    Write-Warning "Could not remove file '$Path' after $Retries attempts; it may be in use by another process."
}

function Invoke-FileCleanup {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [String[]] $FilePaths
    )

    if (!$FilePaths) { return }
    foreach ($path in $FilePaths) {
        Write-Debug "Removing $path"
        if (Test-Path -Path $path) {
            Request-RemoveItem -Path $path
        } else {
            Write-Warning "Could not remove $path as it does not exist"
        }
    }
}

Export-ModuleMember -Function @('Initialize-Folder', 'Request-RemoveItem', 'Invoke-FileCleanup')
