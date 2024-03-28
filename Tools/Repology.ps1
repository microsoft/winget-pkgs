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

function Get-RepologyVulnerableVersions {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $RepologyProjectName,
        [switch] $IncludeLatest
    )

    try {
        $webPage = Invoke-WebRequest "https://repology.org/project/$RepologyProjectName/versions" -UseBasicParsing
        $vulnerableVersions = $webPage.links.Where({ $_ -match 'cves\?' }).href | ForEach-Object { $_.split('=')[-1] }
        $wingetManifestPaths = $webPage.links.Where({ $_.href -match 'winget-pkgs' }).href | Select-Object -Unique
    } catch {
        Out-Null
    }
    if (!$vulnerableVersions -or !$wingetManifestPaths) { return $null }
    $wingetManifestPaths = $wingetManifestPaths -replace 'https://github.com/microsoft/winget-pkgs/tree/master/manifests/', ''
    $wingetPackageIdentifiers = $wingetManifestPaths.ForEach({ ($_.Split('/') | Select-Object -Skip 1 | Select-Object -SkipLast 1) -join '.' }) | Select-Object -Unique
    $vulnerablePackages = @()
    $wingetPackageIdentifiers | ForEach-Object {
        $ManifestVersions = (Find-WinGetPackage $_).AvailableVersions
        if (!$ManifestVersions) { continue }
        $versions = $ManifestVersions.Where({ $_ -in $vulnerableVersions })
        $vulnerablePackages += New-Object psobject -Property @{
            RepologyProjectName = $RepologyProjectName
            PackageIdentifier = $_
            Versions = $(
                if ($IncludeLatest) {
                    $versions.Where({ $_ -ne $ManifestVersions[0] })
                } else {
                    $versions
                }
            )
        }
    }
    return $vulnerablePackages.where({$_.Versions.count -gt 0})
}

function Get-AllRepologyVulnerableVersions {
    $webPage = Invoke-WebRequest "https://repology.org/projects/?inrepo=winget&vulnerable=1" -UseBasicParsing
    $repologyProjectLinks = $webPage.links.href.Where({$_ -match '/versions$'})
    $repologyProjectIds = $repologyProjectLinks.Replace('/project/','').Replace('/versions','')

    $vulnerablePackages = @()
    $repologyProjectIds | ForEach-Object { $vulnerablePackages += Get-RepologyVulnerableVersions -RepologyProjectName $_}
    return $vulnerablePackages
}
