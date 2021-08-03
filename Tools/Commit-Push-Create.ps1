Write-Host "Commit Push and Create Pull Request"
if ($args[0]) {$PkgId = $args[0]} else {$PkgId = Read-Host -Prompt 'Enter Package Name'}
if ($args[1]) {$PkgVersion = $args[1]} else {$PkgVersion = Read-Host -Prompt 'Enter Package Version'}
if ($args[2] -and $args[2] -in @('um','am','amd','umd','pi','mpc','u','n','a','pc')) {
    $CommitType = $args[2]
} else {
    while ($CommitType -notin @('um','am','amd','umd','pi','mpc','u','n','a','pc')) {
        $CommitType = Read-Host -Prompt 'Enter Commit Message'
    }
}
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
} elseif ($CommitType -eq 'u') {
    $CommitType = "Update"
} elseif ($CommitType -eq 'n') {
    $CommitType = "New"
} elseif ($CommitType -eq 'a') {
    $CommitType = "ARP"
} elseif ($CommitType -eq 'pc') {
    $CommitType = "ProductCode"
}
git fetch upstream master
git checkout -b "$PkgId-$PkgVersion" FETCH_HEAD
git add -A
git commit -m "$CommitType`: $PkgId version $PkgVersion"
git push
gh pr create --body-file "C:\Users\Bittu\Downloads\winget-pkgs\my-fork\.github\PULL_REQUEST_TEMPLATE.md" -f
git switch "master"