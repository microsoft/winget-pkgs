# Configuratie
$fork = "stensel8"
$package = "Notepad.Notepad++"
$basePath = "manifests\n\Notepad++\Notepad++\"

Write-Host "=== Notepad++ Vulnerable Versions Removal ===" -ForegroundColor Yellow
Write-Host "Target: Remove all versions < 8.8.9 (except 8.9.0 and 8.9.1)" -ForegroundColor Yellow
Write-Host ""

# Check of we in de juiste repository zitten
if (-not (Test-Path $basePath)) {
    Write-Host "ERROR: Path $basePath not found. Are you in the winget-pkgs root?" -ForegroundColor Red
    exit 1
}

# Scan alle versies en filter
$allVersions = Get-ChildItem -Path $basePath -Directory | ForEach-Object {
    try {
        $versionString = $_.Name
        # Parse versie (ondersteunt formaat zoals 8.8.8, 8.9, 8.9.1)
        $parts = $versionString.Split('.')
        $major = [int]$parts[0]
        $minor = [int]$parts[1]
        $patch = if ($parts.Count -gt 2) { [int]$parts[2] } else { 0 }
        
        [PSCustomObject]@{
            Name = $versionString
            Major = $major
            Minor = $minor
            Patch = $patch
            FullVersion = "$major.$minor.$patch"
        }
    } catch {
        Write-Host "Skipping invalid version: $($_.Name)" -ForegroundColor Gray
        $null
    }
} | Where-Object { $_ -ne $null }

# Filter: verwijder alles < 8.8.9, BEHALVE 8.9.0 en 8.9.1
$versionsToRemove = $allVersions | Where-Object {
    # Check of versie < 8.8.9
    $isOlderThan889 = ($_.Major -lt 8) -or 
                      ($_.Major -eq 8 -and $_.Minor -lt 8) -or
                      ($_.Major -eq 8 -and $_.Minor -eq 8 -and $_.Patch -lt 9)
    
    # Check of het NIET 8.9.0 of 8.9.1 is
    $isNot890 = -not ($_.Major -eq 8 -and $_.Minor -eq 9 -and $_.Patch -eq 0)
    $isNot891 = -not ($_.Major -eq 8 -and $_.Minor -eq 9 -and $_.Patch -eq 1)
    
    $isOlderThan889 -and $isNot890 -and $isNot891
}

# Toon overzicht
Write-Host "Found versions to remove:" -ForegroundColor Cyan
$versionsToRemove | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor White }
Write-Host ""
Write-Host "Total: $($versionsToRemove.Count) versions" -ForegroundColor Cyan
Write-Host ""

# Bevestiging vragen
$confirm = Read-Host "Continue? (y/n)"
if ($confirm -ne 'y') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# Zorg dat we op master zitten
Write-Host "`nSwitching to master..." -ForegroundColor Cyan
git checkout master
git pull upstream master

$successCount = 0
$failCount = 0

# Voor elke versie
foreach ($version in $versionsToRemove) {
    $versionName = $version.Name
    $branchName = "remove-npp-$versionName"
    $versionPath = "$basePath$versionName"
    
    Write-Host "`n--- Processing version $versionName ---" -ForegroundColor Cyan
    
    try {
        # Maak nieuwe branch vanuit master
        git checkout master
        git checkout -b $branchName
        
        # Verwijder de versie map
        if (Test-Path $versionPath) {
            Remove-Item -Path $versionPath -Recurse -Force
            Write-Host "  Deleted: $versionPath" -ForegroundColor Gray
        } else {
            Write-Host "  WARNING: Path not found: $versionPath" -ForegroundColor Yellow
            git checkout master
            git branch -D $branchName
            $failCount++
            continue
        }
        
        # Git add en commit
        git add .
        git commit -m @"
Remove Notepad++.Notepad++ version $versionName

Versions prior to 8.8.9 contain critical security vulnerabilities including a supply chain attack vector.

References:
- https://notepad-plus-plus.org/news/v889-released/
- https://orca.security/resources/blog/notepad-plus-plus-supply-chain-attack/
"@
        
        # Push naar je fork
        git push -u origin $branchName
        
        Write-Host "  ✓ Branch $branchName created and pushed" -ForegroundColor Green
        $successCount++
        
        # Terug naar master voor volgende iteratie
        git checkout master
        
    } catch {
        Write-Host "  ✗ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
        git checkout master
        git branch -D $branchName -ErrorAction SilentlyContinue
    }
}

# Samenvatting
Write-Host "`n=== Summary ===" -ForegroundColor Yellow
Write-Host "Successfully processed: $successCount branches" -ForegroundColor Green
Write-Host "Failed: $failCount branches" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Go to https://github.com/$fork/winget-pkgs/branches" -ForegroundColor White
Write-Host "2. Create Pull Requests for each branch to microsoft/winget-pkgs" -ForegroundColor White
Write-Host "3. Reference the security advisories in each PR" -ForegroundColor White