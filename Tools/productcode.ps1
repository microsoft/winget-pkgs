Param ([switch] $orca,[switch] $sandbox,[switch] $ussf,[switch] $hash, [switch] $myscript)
$workingDir = "C:\Users\Bittu\Downloads"
if($args -and -not $myscript) {
    Foreach($downloadUrl in $args) {
        $WebClient = New-Object System.Net.WebClient
        $Filename = [System.IO.Path]::GetFileName($downloadUrl)
        $location = "$workingDir\$FileName"
        try {
            $WebClient.DownloadFile($downloadUrl, $location)
        } catch {
            Write-Host 'Error downloading file. Please run the script again.' -ForegroundColor Red
            exit 1
        }
        if ($ussf) {
            Start-Process -FilePath "C:\Users\Bittu\OneDrive\Desktop\bittu\things\ussf.exe" -ArgumentList $location -Wait
        } elseif ($hash) {
            $hashInformation = Get-FileHash $location
            Write-Host "Algorithm:` $($hashInformation.Algorithm)"
            Write-Host "Hash:` $($hashInformation.Hash)"
            Write-Host "Path:` $($hashInformation.Path)"
        } elseif ($orca) {
            Start-Process -FilePath "C:\Program Files (x86)\Orca\Orca.exe" -ArgumentList $location -Wait
        } elseif ($sandbox) {
            Set-Content -Path $workingDir\LaunchSandbox.wsb -Value "<Configuration>
              <MappedFolders>
                <MappedFolder>
                  <HostFolder>$workingDir</HostFolder>
                  <ReadOnly>false</ReadOnly>
                </MappedFolder>
              </MappedFolders>
              <LogonCommand>
                <Command>PowerShell Start-Process PowerShell -WindowStyle Maximized -Verb runAs -WorkingDirectory 'C:\Users\WDAGUtilityAccount\Desktop\Downloads' -ArgumentList '-ExecutionPolicy Bypass -NoExit -NoLogo -Command ""Write-Host ""Running installer...`n""; Start-Process -FilePath ""C:\Users\WDAGUtilityAccount\Desktop\Downloads\$Filename"" -Wait; Write-Host ""Getting list of installed programs...`n""; Get-WmiObject -Class Win32_InstalledWin32Program | Select-Object Name,Vendor,Version,MsiProductCode | Out-Null; Get-WmiObject -Class Win32_InstalledWin32Program | Select-Object Name,Vendor,Version,MsiProductCode; Get-FileHash ""C:\Users\WDAGUtilityAccount\Desktop\Downloads\$Filename""""'</Command>
              </LogonCommand>
            </Configuration>"
            Start-Process -FilePath "$workingDir\LaunchSandbox.wsb" -Wait
            Remove-Item "$workingDir\LaunchSandbox.wsb"
        } elseif (-not $ussf -and -not $hash -and -not $orca -and -not $sandbox) {
            if ($location.EndsWith('appx','CurrentCultureIgnoreCase') -or $location.EndsWith('msix','CurrentCultureIgnoreCase') -or $location.EndsWith('appxbundle','CurrentCultureIgnoreCase') -or $location.EndsWith('msixbundle','CurrentCultureIgnoreCase')) {
                Write-Host "PackageVersion: $((Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher | Select-Object BinaryVersion).BinaryVersion)"
                winget hash -f $location -m
                $ProgressPreference = 'SilentlyContinue'
                Add-AppxPackage -Path $location
                $InstalledPkg = Get-AppxPackage | Select-Object -Last 1 | Select-Object PackageFamilyName,PackageFullName
                Write-Host "PackageFamilyName: $($InstalledPkg.PackageFamilyName)"
                Remove-AppxPackage $InstalledPkg.PackageFullName
            } else {
                $MyProductCode = Get-AppLockerFileInformation -Path $location | Select-Object -ExpandProperty Publisher
                Write-Host "ProductCode: '$($MyProductCode.BinaryName)'"
                Write-Host "PackageVersion: $($MyProductCode.BinaryVersion)"
            }
        }
        Remove-Item $location
    }
} elseif ($myscript) {
    $manifestsPath = "$workingDir\winget-pkgs\manifests"
    $ErrorActionPreference = 'Continue'
    
    Function CheckMoniker {
        Clear-Content $workingDir\wingetPkgAliases.txt
        Write-Host "Checking monikers..."
        "Checking monikers..." | Out-File -Append -FilePath $workingDir\wingetPkgAliases.txt
        Foreach($i in (Get-ChildItem -Path $manifestsPath -Directory -Recurse | Where-Object { (Get-ChildItem -Directory -Path $_.FullName).Count -eq 0 } | Select-Object FullName)) {
            if ((Get-ChildItem -Path $i.FullName).Count -eq 1) { $YamlFile = Get-ChildItem -Path $i.FullName | Select-Object FullName }
            else { $YamlFile = Get-ChildItem -Path $i.FullName -Filter "*locale*" | Select-Object FullName | Select-Object -First 1 }
            $GetMoniker = (Get-Content $YamlFile.FullName | Select-String -Pattern "Moniker:")
            if ($null -eq $GetMoniker -or $GetMoniker -like "Moniker: ''" -or ($GetMoniker.ToString()).Contains("#")) {
                "MNF` : $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageIdentifier:" | Select-Object -First 1).ToString().Trim().TrimStart("PackageIdentifier:").Trim('"').Trim("'").Trim()) version $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageVersion:").ToString().Trim().TrimStart("PackageVersion:").Trim('"').Trim("'").Trim())" | Out-File -Append -FilePath $workingDir\wingetPkgAliases.txt
            } else {
                "$($GetMoniker.ToString().Trim().TrimStart("Moniker:").Trim('"').Trim("'").Trim())` : $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageIdentifier:" | Select-Object -First 1).ToString().Trim().TrimStart("PackageIdentifier:").Trim('"').Trim("'").Trim()) version $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageVersion:").ToString().Trim().TrimStart("PackageVersion:").Trim('"').Trim("'").Trim())" | Out-File -Append -FilePath $workingDir\wingetPkgAliases.txt
            }
        }
        Write-Host "Completed!"
        "Completed!" | Out-File -Append -FilePath $workingDir\wingetPkgAliases.txt
    }

    Function InstallerInfoCheck {
        Clear-Content $workingDir\MissingInstallerInfo.txt
        Write-Host "Checking product codes..."
        "Checking product codes..." | Out-File -Append -FilePath $workingDir\MissingInstallerInfo.txt
        Foreach($i in (Get-ChildItem -Path $manifestsPath -Directory -Recurse | Where-Object { (Get-ChildItem -Directory -Path $_.FullName).Count -eq 0 } | Select-Object FullName)) {
            if ((Get-ChildItem -Path $i.FullName).Count -eq 1) { $YamlFile = Get-ChildItem -Path $i.FullName | Select-Object FullName }
            else { $YamlFile = Get-ChildItem -Path $i.FullName -Filter "*installer*" | Select-Object FullName }
            if ((Get-Content $YamlFile.FullName | Select-String -Pattern "InstallerType: msi") -and -not(Get-Content $YamlFile.FullName | Select-String -Pattern "InstallerType: msix") -and -not(Get-Content $YamlFile.FullName | Select-String -Pattern "ProductCode: ")) {
                "PCNF` : $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageIdentifier:" | Select-Object -First 1).ToString().Trim().TrimStart("PackageIdentifier:").Trim('"').Trim("'").Trim()) version $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageVersion:").ToString().Trim().TrimStart("PackageVersion:").Trim('"').Trim("'").Trim())" | Out-File -Append -FilePath $workingDir\MissingInstallerInfo.txt
            } elseif (((Get-Content $YamlFile.FullName | Select-String -Pattern "InstallerType: msix") -or (Get-Content $YamlFile.FullName | Select-String -Pattern "InstallerType: appx")) -and (-not(Get-Content $YamlFile.FullName | Select-String -Pattern "SignatureSha256: ") -or -not(Get-Content $YamlFile.FullName | Select-String -Pattern "FamilyName: "))) {
                "SSFN` : $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageIdentifier:" | Select-Object -First 1).ToString().Trim().TrimStart("PackageIdentifier:").Trim('"').Trim("'").Trim()) version $((Get-Content $YamlFile.FullName | Select-String -Pattern "PackageVersion:").ToString().Trim().TrimStart("PackageVersion:").Trim('"').Trim("'").Trim())" | Out-File -Append -FilePath $workingDir\MissingInstallerInfo.txt
            }
        }
        Write-Host "Completed!"
        "Completed!" | Out-File -Append -FilePath $workingDir\MissingInstallerInfo.txt
    }

    Function ManifestInfoRename {
        Write-Host -ForegroundColor Green "1. Copy all versions (which are to be renamed) of Packages to a new directory.`n2. Enter path of new directory and information asked."
        $PathYaml = Read-Host -Prompt 'Path of Yaml Files (without version)'
        $OldPkgId = Read-Host -Prompt 'Old Package Identifier'
        $OldPkgName = Read-Host -Prompt 'Old Package Name'
        $OldMoniker = Read-Host -Prompt 'Old Moniker'
        $NewPkgId = Read-Host -Prompt 'New Package Identifier'
        $NewPkgName = Read-Host -Prompt 'New Package Name'
        $NewMoniker = Read-Host -Prompt 'New Moniker'
        Write-Host "Renaming Information in Manifests"
        Foreach ($i in Get-ChildItem -Path $PathYaml -File -Recurse | Select-Object FullName) {
            Set-Content -Path $i.FullName -Value $(Get-Content $i.FullName | ForEach-Object {$_ -replace "PackageIdentifier: $OldPkgId","PackageIdentifier: $NewPkgId"} | ForEach-Object {$_ -replace "PackageName: $OldPkgName","PackageName: $NewPkgName"} | ForEach-Object {$_ -replace "Moniker: $OldMoniker","Moniker: $NewMoniker"})
            if ($i.FullName.EndsWith("$OldPkgId.installer.yaml")) { Rename-Item $i.FullName "$NewPkgId.installer.yaml" }
            elseif ($i.FullName.EndsWith("$OldPkgId.locale.en-US.yaml")) { Rename-Item $i.FullName "$NewPkgId.locale.en-US.yaml" }
            elseif ($i.FullName.EndsWith("$OldPkgId.yaml")){ Rename-Item $i.FullName "$NewPkgId.yaml" }
        }
        Write-Host "Completed!"
    }

    Write-Host "Enter Choice"
    Write-Host "a`: Monikers Check"
    Write-Host "b`: Installer Info Check"
    Write-Host "c`: Rename information in manifests"
    Write-Host "Choice: " -NoNewLine
    do {
        $keyInfo = [Console]::ReadKey($false)
    } until ($keyInfo.Key)
    switch ($keyInfo.Key) {
        'A' { Write-Host; CheckMoniker }
        'B' { Write-Host; InstallerInfoCheck }
        'C' { Write-Host; ManifestInfoRename }
        default { Write-Host -ForegroundColor Blue "`nWrong Choice. Run the script again."}
    }
} else { Write-Host "No urls entered." }