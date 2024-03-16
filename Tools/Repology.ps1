function Get-RepologyVulnerableVersions {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $PackageIdentifier,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $RepologyProjectName,
        [switch] $IncludeLatest
    )

    $webPage = Invoke-WebRequest "https://repology.org/project/$RepologyProjectName/versions" -UseBasicParsing
    $vulnerableVersions = $webPage.links.Where({ $_ -match 'cves\?' }).href | ForEach-Object { $_.split('=')[-1] }

    $ManifestVersions = (Get-WinGetPackage $PackageIdentifier).AvailableVersions
    $versions =  $ManifestVersions.Where({$_ -in $vulnerableVersions })

    # The latest will be omitted by default to prevent accidental removal
    if ($IncludeLatest) { return $versions}
    return $versions.Where({$_ -ne $ManifestVersions[0]})
}
