Foreach ($i in Get-ChildItem -File -Recurse | Select FullName) {
    $content = Get-Content $i.FullName | Foreach {$_ -replace "PackageIdentifier: Joplin.Joplin","PackageIdentifier: Joplin.Joplin.Pre-release"} | Foreach {$_ -replace "Moniker: joplin","Moniker: joplin-prerelease"} | Foreach {$_ -replace "PackageName: Joplin","PackageName: Joplin (Pre-release)"}
    Set-Content -Path $i.FullName -Value $content
    if ($i.FullName.EndsWith('Joplin.Joplin.installer.yaml')) {
        Rename-Item $i.FullName "Joplin.Joplin.Pre-release.installer.yaml"
    } elseif ($i.FullName.EndsWith('Joplin.Joplin.locale.en-US.yaml')) {
        Rename-Item $i.FullName "Joplin.Joplin.Pre-release.locale.en-US.yaml"
    } elseif ($i.FullName.EndsWith('Joplin.Joplin.yaml')){
        Rename-Item $i.FullName "Joplin.Joplin.Pre-release.yaml"
    }
}