#!/usr/bin/env pwsh

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$changedFiles = git diff --name-only "origin/$env:GITHUB_BASE_REF" HEAD -- manifests

foreach ($changedFile in $changedFiles) {
  $http = Select-String -Path $changedFile `
    -Pattern '(http://.*)$' `
    -AllMatches
  foreach ($match in $http.Matches) {
    if ($match.Groups[0].Value) {
      $https = $match.Groups[0].Value.Replace('http://', 'https://')
      $res = Invoke-WebRequest -Uri $https `
        -Method HEAD `
        -TimeoutSec 10 `
        -UseBasicParsing
      if ($res.StatusCode -eq 200) {
        Write-Output "::error file=$changedFile::Found HTTP link: $($match.Value)"
      }
    }
  }
}
