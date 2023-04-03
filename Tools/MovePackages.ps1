#Requires -Version 5
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification='This script is not intended to have any outputs piped')]

Param
(
    [Parameter(Mandatory = $true)]
    [string] $FromPackage,
    [Parameter(Mandatory = $true)]
    [string] $ToPackage,
    [Parameter(Mandatory = $false)]
    [string] $NewMoniker
)

$PSDefaultParameterValues = @{ '*:Encoding' = 'UTF8' }
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
$ofs = ', '

# Set the root folder where new manifests should be created
if (Test-Path -Path "$PSScriptRoot\..\manifests") {
    $ManifestsFolder = (Resolve-Path "$PSScriptRoot\..\manifests").Path
} else {
    $ManifestsFolder = (Resolve-Path '.\').Path
}

# Get the folders that we are moving
$script:FromAppFolder = Join-Path $ManifestsFolder -ChildPath $FromPackage.ToLower()[0] | Join-Path -ChildPath $FromPackage.Replace('.', '\')
$script:ToAppFolder = Join-Path $ManifestsFolder -ChildPath $ToPackage.ToLower()[0] | Join-Path -ChildPath $ToPackage.Replace('.', '\')

# Ensure there are only .yaml files and no sub-packages
# if ($(Get-ChildItem -Path $script:FromAppFolder -Exclude *.yaml -Recurse -File).Count) {Throw [System.InvalidOperationException]::new("Cannot move packages which contain .validation files")}

# If we are okay to move it, get a list of the versions to move
$VersionsToMove = @(Get-ChildItem -Path $FromAppFolder | Where-Object {@(Get-ChildItem -Directory -Path $_.FullName).Count -eq 0}).Name

foreach ($Version in $VersionsToMove) {
    # Copy the manifests to the new directory
    $SourceFolder = Join-Path -Path $script:FromAppFolder -ChildPath $Version
    $DestinationFolder = Join-Path -Path $script:ToAppFolder -ChildPath $Version
    Copy-Item -Path $SourceFolder -Destination $DestinationFolder -Recurse -Force
    # Rename the files
    Get-ChildItem -Path $DestinationFolder -Filter "*$FromPackage*" -Recurse | ForEach-Object {Rename-Item -Path $_.FullName -NewName $($_.Name -replace [regex]::Escape($FromPackage),"$ToPackage")}
    # Update PackageIdentifier in all files
    Get-ChildItem -Path $DestinationFolder -Filter "*$ToPackage*" -Recurse | ForEach-Object  {[System.IO.File]::WriteAllLines($_.FullName, $((Get-Content -Path $_.FullName -Raw) -replace [regex]::Escape($FromPackage),"$ToPackage"), $Utf8NoBomEncoding)}
    # Update Moniker in all files
    if ($PSBoundParameters.Keys -contains 'NewMoniker'){
    Get-ChildItem -Path $DestinationFolder -Filter "*$ToPackage*" -Recurse | ForEach-Object  {[System.IO.File]::WriteAllLines($_.FullName, $((Get-Content -Path $_.FullName -Raw) -replace "Moniker:.*","Moniker: $NewMoniker"), $Utf8NoBomEncoding)}
    }
    # Read-Host -Prompt "Press Enter To Continue . . . "
    # Create new branch from master, add the new files, commit, and push
    git fetch upstream master --quiet
    git switch -d upstream/master -q
    git add -A
    git commit -m "Move $FromPackage $Version to $ToPackage $Version" --quiet
    git switch -c "Move-$FromPackage-v$Version" --quiet
    git push --set-upstream origin "Move-$FromPackage-v$Version" --quiet
    # gh pr create -f

    # Remove the old manifest
    $PathToVersion = $SourceFolder
    do {
        Remove-Item -Path $PathToVersion -Recurse -Force
        $PathToVersion = Split-Path $PathToVersion
    } while (@(Get-ChildItem $PathToVersion).Count -eq 0)

    # Create new branch from master, add the removed files, commit, and push
    git fetch upstream master --quiet
    git switch -d upstream/master -q
    git add -A
    git commit -m "Remove $FromPackage $Version to $ToPackage $Version" --quiet
    git switch -c "Remove-$FromPackage-v$Version" --quiet
    git push --set-upstream origin "Remove-$FromPackage-v$Version" --quiet
}