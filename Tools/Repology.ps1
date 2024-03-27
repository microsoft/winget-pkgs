function Get-RepologyVulnerableVersions {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $PackageIdentifier,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $RepologyProjectName,
        [switch] $IncludeLatest
    )

    try {
        $webPage = Invoke-WebRequest "https://repology.org/project/$RepologyProjectName/versions" -UseBasicParsing
        $vulnerableVersions = $webPage.links.Where({ $_ -match 'cves\?' }).href | ForEach-Object { $_.split('=')[-1] }

        $ManifestVersions = (Find-WinGetPackage $PackageIdentifier).AvailableVersions
    } catch {
        Out-Null
    }
    if (!$vulnerableVersions -or !$ManifestVersions) { return $null }

    $versions = $ManifestVersions.Where({ $_ -in $vulnerableVersions })

    # The latest will be omitted by default to prevent accidental removal
    if ($IncludeLatest) { return $versions }
    return $versions.Where({ $_ -ne $ManifestVersions[0] })
}

function Get-RepologyWingetIds {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $RepologyProjectName
    )

    try {
        $webPage = Invoke-WebRequest "https://repology.org/project/$RepologyProjectName/versions" -UseBasicParsing
        $wingetManifestPaths = $webPage.links.Where({ $_.href -match 'winget-pkgs' }).href | Select-Object -Unique
    } catch {
        Out-Null
    }

    if (!$wingetManifestPaths) { return $null }

    $wingetManifestPaths = $wingetManifestPaths -replace 'https://github.com/microsoft/winget-pkgs/tree/master/manifests/', ''
    return $wingetManifestPaths.ForEach({ ($_.Split('/') | Select-Object -Skip 1 | Select-Object -SkipLast 1) -join '.' }) | Select-Object -Unique
}
