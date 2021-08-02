Write-Host "Commit Push and Create Pull Request"
if ($args[0] -and $args[1]) {
    $PkgId = $args[0]
    $PkgVersion = $args[1]
} else {
    $PkgId = Read-Host -Prompt 'Enter Package Name'
    $PkgVersion = Read-Host -Prompt 'Enter Package Version'
}
while ($keyInfo.Key -notin @('M', 'N', 'U','A','C','P')) {
    Write-Host -NoNewLine "Commit Type: "
    do {
        $keyInfo = [Console]::ReadKey($false)
    } until ($keyInfo.Key)
}
switch ($keyInfo.Key) {
    'U' {$CommitType = "Update";Write-Host}
    'N' {$CommitType = "New";Write-Host}
    'M' {$CommitType = "Metadata";Write-Host}
    'A' {$CommitType = "ARP";Write-Host}
    'P' {$CommitType = "ProductCode";Write-Host}
    'C' {Write-Host; $CommitType = Read-Host -Prompt 'Enter Custom Commit Message'}
}
if($keyInfo.Key -eq 'C') {
    if ($CommitType -eq 'um') {
        $CommitType = "Update Moniker"
    } elseif ($CommitType -eq 'am') {
        $CommitType = "Add Moniker"
    } elseif ($CommitType -eq 'amd') {
        $CommitType = "Add Metadata"
    } elseif ($CommitType -eq 'umd') {
        $CommitType = "Update Metadata"
    } elseif ($CommitType -eq 'pi') {
        $CommitType = "PackageIdentifier"
    } elseif ($CommitType -eq 'mpc') {
        $CommitType = "Moniker/ProductCode"
    }
}
git fetch upstream master
git checkout -b "$PkgId-$PkgVersion" FETCH_HEAD
git add -A
git commit -m "$CommitType`: $PkgId version $PkgVersion"
git push
gh pr create --body-file "C:\Users\Bittu\Downloads\winget-pkgs\my-fork\.github\PULL_REQUEST_TEMPLATE.md" -f
git switch "master"