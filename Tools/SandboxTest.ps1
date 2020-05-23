# Parse Arguments

param ([string] $Manifest = $(throw "The Manifest parameter is required."))

if (-not (Test-Path -Path $Manifest)) {
  throw 'The Manifest file does not exist.'
}

# Validate manifest file
# We can't rely on status code until https://github.com/microsoft/winget-cli/issues/312 is solved
$validationResult = winget.exe validate $Manifest
if ($validationResult -like '*Manifest validation failed.*') {
  throw 'Manifest validation failed.'
}

# Initialize Temp Folder

$tempFolder = Join-Path -Path $PSScriptRoot -ChildPath 'SandboxTest_Temp'

Get-ChildItem $tempFolder -Recurse -Exclude *.appx, *.appxbundle | Remove-Item -Force

Copy-Item -Path $Manifest -Destination $tempFolder

# TODO: Download dependencies

$desktopAppInstaller = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle'
$vcLibs = 'Microsoft.VCLibs.140.00_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'
$vcLibsUwp = 'Microsoft.VCLibs.140.00.UWPDesktop_14.0.27810.0_x64__8wekyb3d8bbwe.Appx'

# Create Bootstrap script

$manifestFileName = Split-Path $Manifest -Leaf

$bootstrapPs1Content = @"
Set-PSDebug -Trace 1

Add-AppxPackage -Path '$desktopAppInstaller' -DependencyPath '$vcLibs','$vcLibsUwp'

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
