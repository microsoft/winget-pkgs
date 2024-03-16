function Get-RepologyVulnerableVersions {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $PackageIdentifier,
        [Parameter(Mandatory = $true, Position = 1)]
        [string] $RepologyProjectName
    )

    $webPage = Invoke-WebRequest "https://repology.org/project/$RepologyProjectName/versions" -UseBasicParsing
    $versions = $webPage.links.Where({ $_ -match 'cves\?' }).href | ForEach-Object { $_.split('=')[-1] }

    $ManifestsFolder = Get-WinGetManifestPath $PackageIdentifier
    $ManifestVersions = (Get-ChildItem $ManifestsFolder -Directory).Name

    return $versions.Where({$_ -in $ManifestVersions})
}

function Get-WinGetManifestPath {
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $PackageIdentifier
    )
    # Set the root folder where new manifests should be created
    if (Test-Path -Path "$PSScriptRoot\..\manifests") {
        $root = (Resolve-Path "$PSScriptRoot\..\manifests").Path
    }
    else {
        $root = (Resolve-Path '.\').Path
    }

    $IdentifierParts = @($PackageIdentifier.Split('.'))
    return  Join-Path $root $PackageIdentifier.ToLower()[0] @IdentifierParts
}
