$workingDir = Get-Location
$ErrorActionPreference = 'Continue'
$PkgsDone = [System.Collections.ArrayList]@()
#git clone https://github.com/microsoft/winget-pkgs.git
Write-Host "Checking monikers..."
Foreach($i in (Get-ChildItem -Path "$workingDir\my-fork\manifests" -Directory -Recurse | Select-Object FullName)) {
    if(((Get-ChildItem -Directory -Path $i.FullName).Count) -eq 0) {
        if((Get-ChildItem -Path $i.FullName).Count -eq 1) {
            $PkgIdFile = Get-ChildItem -Path $i.FullName | Select-Object FullName
        } else {
            $PkgIdFile = Get-ChildItem -Path $i.FullName -Filter "*locale*" | Select-Object FullName | Select-Object -First 1
        }    
        $PkgId = (((Get-Content $PkgIdFile.FullName | Select-String -Pattern "PackageIdentifier:" | Select-Object -First 1).ToString()).TrimStart("PackageIdentifier:")).TrimStart()
        if ($PkgId.Contains('"')) {$PkgId = $PkgId.Trim('"')}
        if ($PkgId.Contains("'")) {$PkgId = $PkgId.Trim("'")}
        if (-not($PkgsDone.Contains($PkgId))) {
            $PkgsDone.Add($PkgId) | Out-Null
            Foreach ($j in (Get-ChildItem -Directory -Path "$workingDir\my-fork\manifests\$($PkgId.Substring(0,1).ToLower())\$($PkgId.Replace('.','\'))" | Select-Object FullName)) {
                if (((Get-ChildItem -Directory -Path $j.FullName).Count) -eq 0) {
                    if((Get-ChildItem -Path $j.FullName).Count -eq 1) {
                        $YamlFile = Get-ChildItem -Path $j.FullName | Select-Object FullName
                    } else {
                        $YamlFile = Get-ChildItem -Path $j.FullName -Filter "*locale*" | Select-Object FullName | Select-Object -First 1
                    }
                    $PkgVersion = (((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageVersion:").ToString()).TrimStart("PackageVersion:")).TrimStart()
                    if ($PkgVersion.Contains('"')) {$PkgVersion = $PkgVersion.Trim('"')}
                    if ($PkgVersion.Contains("'")) {$PkgVersion = $PkgVersion.Trim("'")}
                    $GetMoniker = (Get-Content $YamlFile.FullName | Select-String -Pattern "Moniker:")
                    if ($GetMoniker -eq $null -or $GetMoniker -like "Moniker: ''" -or ($GetMoniker.ToString()).Contains("#")) {
                        $Moniker = "MNF"
                    } else {
                        $Moniker = (($GetMoniker.ToString()).TrimStart("Moniker:")).TrimStart()
                        if ($Moniker.Contains('"')) {$Moniker = $Moniker.Trim('"')}
                        if ($Moniker.Contains("'")) {$Moniker = $Moniker.Trim("'")}
                    }
                    Write-Host "$Moniker` : $PkgId version $PkgVersion"
                    "$Moniker` : $PkgId version $PkgVersion" | Out-File -Append -FilePath C:\Users\Bittu\Downloads\winget-pkgs\wingetPkgAliasOutput.txt
                }
            }
        }        
    }
}
Write-Host "Completed!"