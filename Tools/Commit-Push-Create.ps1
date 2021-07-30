Write-Host "Commit Push and Create Pull Request"
$PkgId = Read-Host -Prompt 'Enter Package Name'
$PkgVersion = Read-Host -Prompt 'Enter Package Version'
while ($keyInfo.Key -notin @('M', 'N', 'U','A','C','P')) {
    Write-Host -NoNewLine "Commit Type: "
    do {
        $keyInfo = [Console]::ReadKey($false)
    } until ($keyInfo.Key)
}
switch ($keyInfo.Key) {
    'U' {$CommitType = "Update"}
    'N' {$CommitType = "New"}
    'M' {$CommitType = "Metadata"}
    'A' {$CommitType = "ARP"}
    'P' {$CommitType = "ProductCode"}
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
    } elseif ($CommitType = 'pi') {
        $CommitType = "PackageIdentifier"
    } elseif ($CommitType = 'mc') {
        $CommitType = "Moniker Conflict"
    }
}
git fetch upstream master
git checkout -b "$PkgId-$PkgVersion" FETCH_HEAD
git add -A
git commit -m "$CommitType`: $PkgId version $PkgVersion"
git push
gh pr create --body-file "C:\Users\Bittu\Downloads\winget-pkgs\my-fork\.github\PULL_REQUEST_TEMPLATE.md" -f
git switch "master"