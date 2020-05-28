# Parse Arguments

param ([string] $Manifest = $(throw "The Manifest parameter is required."))

if (-not (Test-Path -Path $Manifest -PathType Leaf)) {
  throw 'The Manifest file does not exist.'
}

# Validate manifest file
# We can't rely on status code until https://github.com/microsoft/winget-cli/issues/312 is solved
$validationResult = winget.exe validate $Manifest
if ($validationResult -like '*Manifest validation failed.*') {
  throw 'Manifest validation failed.'
}

# Set dependencies

$desktopAppInstaller = @{
  fileName = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle'
  url      = 'https://github.com/microsoft/winget-cli/releases/download/v0.1.4331-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle'
  hash     = 'e1b5aa89c7354dd39db38c2ac33f0455c4529eb4cf77f023028d955122ea8377'
}

$vcLibs = @{
  fileName = 'Microsoft.VCLibs.140.00_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'
  url      = 'https://github.com/felipecassiors/winget-pkgs/raw/da8548d90369eb8f69a4738dc1474caaffb58e12/Tools/SandboxTest_Temp/Microsoft.VCLibs.140.00_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'
  hash     = 'fe660c46a3ff8462d9574902e735687e92eeb835f75ec462a41ef76b54ef13ed'
}

$vcLibsUwp = @{
  fileName = 'Microsoft.VCLibs.140.00.UWPDesktop_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'
  url      = 'https://raw.githubusercontent.com/felipecassiors/winget-pkgs/da8548d90369eb8f69a4738dc1474caaffb58e12/Tools/SandboxTest_Temp/Microsoft.VCLibs.140.00.UWPDesktop_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'
  hash     = '66de9fde9d2ebf18893a890987f35d2d145c18cc5ee0e8ecaa09477dcc13b16b'
}

$dependencies = @($desktopAppInstaller, $vcLibs, $vcLibsUwp)

# Initialize Temp Folder

$tempFolder = Join-Path -Path $PSScriptRoot -ChildPath 'SandboxTest_Temp'

New-Item $tempFolder -ItemType Directory -ea 0 | Out-Null

Get-ChildItem $tempFolder -Recurse -Exclude $dependencies.fileName | Remove-Item -Force

Copy-Item -Path $Manifest -Destination $tempFolder

# Download dependencies

$WebClient = New-Object System.Net.WebClient

foreach ($dependency in $dependencies) {
  $dependency.file = Join-Path -Path $tempFolder -ChildPath $dependency.fileName

  if (-Not ((Test-Path -Path $dependency.file -PathType Leaf) -And $dependency.hash -eq $(get-filehash $dependency.file).Hash)) {
    # This downloads the file
    Write-Host "Downloading $($dependency.url) ..."
    try { 
      $WebClient.DownloadFile($dependency.url, $dependency.file) 
    } 
    catch {
      throw "Error downloading $($dependency.url)"
    }
    if (-not ($dependency.hash -eq $(get-filehash $dependency.file).Hash)) {
      throw 'Hashes not match'
    }
  }
}

# Create Bootstrap script

$manifestFileName = Split-Path $Manifest -Leaf

$bootstrapPs1Content = @"
Set-PSDebug -Trace 1

Add-AppxPackage -Path '$($desktopAppInstaller.fileName)' -DependencyPath '$($vcLibs.fileName)','$($vcLibsUwp.fileName)'

winget install -m '$manifestFileName'
"@

$bootstrapPs1FileName = 'Bootstrap.ps1'
$bootstrapPs1Content | Out-File (Join-Path -Path $tempFolder -ChildPath $bootstrapPs1FileName)

# Create Wsb file

$tempFolderInSandbox = Join-Path -Path 'C:\Users\WDAGUtilityAccount\Desktop' -ChildPath (Split-Path $tempFolder -Leaf)

$sandboxTestWsbContent = @"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$tempFolder</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
  <Command>PowerShell Start-Process PowerShell -WorkingDirectory '$tempFolderInSandbox' -ArgumentList '-ExecutionPolicy Bypass -NoExit -File $bootstrapPs1FileName'</Command>
  </LogonCommand>
</Configuration>
"@

$sandboxTestWsbFileName = 'SandboxTest.wsb'
$sandboxTestWsbFile = Join-Path -Path $tempFolder -ChildPath $sandboxTestWsbFileName
$sandboxTestWsbContent | Out-File $sandboxTestWsbFile

Write-Host 'Starting Windows Sandbox and trying to install the manifest file.'

WindowsSandbox $SandboxTestWsbFile
