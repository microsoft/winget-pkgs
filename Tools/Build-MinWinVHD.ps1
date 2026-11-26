# ================================
# Minimal Windows 11 VHDX Builder
# ================================
# Run as Administrator

#Requires -Version 5.1
#Requires -RunAsAdministrator
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'This script is not intended to have any outputs piped')]

param
(
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Drive letter where Windows 11 ISO is mounted (e.g., D:)'
    )] [string] $IsoDrive = 'D:',
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Index of the Windows 11 edition to install from the image (use /Get-ImageInfo to check)'
    )] [ValidateRange(1, 10)] [int] $ImageIndex = 1,
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Path to create the VHDX file (e.g., C:\MinWin11.vhdx)'
    )] [string] $VhdPath = 'C:\MinWin11.vhdx',
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Size of the VHDX in GB'
    )] [ValidateRange(20, [int]::MaxValue)] [int] $VhdSizeGB = 25,
    [Parameter(
        Mandatory = $false,
        HelpMessage = 'Name of the Hyper-V VM to create (optional)'
    )] [string] $VmName = 'MinWin11'
)

Write-Host '=== Step 0: Prepare paths and image info ===' -ForegroundColor Cyan

# Determine install.wim or install.esd path
$InstallWim = Join-Path $IsoDrive 'sources\install.wim'
if (-not (Test-Path $InstallWim)) {
    $InstallWim = Join-Path $IsoDrive 'sources\install.esd'
}

# Verify image file exists
if (-not (Test-Path $InstallWim)) {
    throw "Cannot find install.wim or install.esd on $IsoDrive. Mount a Windows 11 ISO and update `\$IsoDrive`."
}

Write-Host "Using image file: $InstallWim" -ForegroundColor Yellow

Write-Host '=== Step 1: Create and initialize VHDX ===' -ForegroundColor Cyan

# Create VHDX
New-VHD -Path $VhdPath -SizeBytes ("${VhdSizeGB}GB") -Dynamic | Out-Null

# Mount and initialize
$disk = Mount-VHD -Path $VhdPath -Passthru
Initialize-Disk -Number $disk.Number -PartitionStyle GPT | Out-Null

# Create EFI + OS partitions
$efiPartition = New-Partition -DiskNumber $disk.Number -Size 100MB -GptType '{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}' -AssignDriveLetter
$osPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter

# Format partitions
Format-Volume -Partition $efiPartition -FileSystem FAT32 -NewFileSystemLabel 'System' -Confirm:$false | Out-Null
Format-Volume -Partition $osPartition -FileSystem NTFS -NewFileSystemLabel 'Windows' -Confirm:$false | Out-Null

$EfiDrive = ($efiPartition | Get-Volume).DriveLetter + ':'
$OsDrive = ($osPartition | Get-Volume).DriveLetter + ':'

Write-Host "EFI drive: $EfiDrive  OS drive: $OsDrive" -ForegroundColor Yellow


Write-Host '=== Step 2: Apply Windows image to OS partition ===' -ForegroundColor Cyan

# If using ESD, DISM can still apply directly
dism /Apply-Image /ImageFile:$InstallWim /Index:$ImageIndex /ApplyDir:$OsDrive | Out-Null


Write-Host '=== Step 3: Basic boot configuration ===' -ForegroundColor Cyan

# Create boot files on EFI partition
bcdboot "$OsDrive\Windows" /s $EfiDrive /f UEFI | Out-Null


Write-Host '=== Step 4: Mount offline image for servicing ===' -ForegroundColor Cyan

# Mount the OS volume as an offline image for DISM servicing
$MountDir = 'D:\Mount_MinWin11'
if (-not (Test-Path $MountDir)) {
    New-Item -ItemType Directory -Path $MountDir | Out-Null
}

# Use DISM to mount the offline image
dism /Mount-Image /ImageFile:$InstallWim /Index:$ImageIndex /MountDir:$MountDir /ReadOnly | Out-Null

# NOTE:
# We will service the *applied* OS at $OsDrive, not the ISO image.
# For feature removal, we target the offline OS with /Image:$OsDrive not /Image:$MountDir.

Write-Host '=== Step 5: Remove optional features (offline) ===' -ForegroundColor Cyan

# You can see available features with:
# dism /Image:$OsDrive /Get-Features

# Aggressive feature removal list (adjust to taste)
$featuresToDisable = @(
    'FaxServicesClientPackage',
    'Printing-Foundation-Features',
    'Printing-PrintToPDFServices-Features',
    'Printing-XPSServices-Features',
    'MSRDC-Infrastructure',
    'Microsoft-Windows-Subsystem-Linux',
    'MediaPlayback' ,
    'WindowsMediaPlayer',
    'WorkFolders-Client',
    'SMB1Protocol',
    'WCF-Services45',
    'WCF-TCP-PortSharing45',
    'IIS-WebServerRole',
    'IIS-WebServer',
    'IIS-DefaultDocument',
    'IIS-DirectoryBrowsing',
    'IIS-HttpErrors',
    'IIS-StaticContent',
    'IIS-HttpRedirect',
    'IIS-ApplicationDevelopment',
    'IIS-ISAPIExtensions',
    'IIS-ISAPIFilter',
    # "IIS-NetFxExtensibility45",
    'IIS-ASPNET45',
    'IIS-HealthAndDiagnostics',
    'IIS-HttpLogging',
    'IIS-LoggingLibraries',
    'IIS-RequestMonitor',
    'IIS-HttpTracing',
    'IIS-Security',
    'IIS-RequestFiltering',
    'IIS-IPSecurity',
    'IIS-Performance',
    'IIS-HttpCompressionStatic',
    'IIS-WebServerManagementTools',
    'IIS-IIS6ManagementCompatibility',
    'IIS-Metabase',
    'IIS-HostableWebCore'
)

foreach ($feature in $featuresToDisable) {
    Write-Host "Disabling feature: $feature" -ForegroundColor DarkYellow
    dism /Image:$OsDrive /Disable-Feature /FeatureName:$feature /Remove | Out-Null
}

Write-Host '=== Step 6: Remove provisioned apps (offline) ===' -ForegroundColor Cyan

# Remove all provisioned appx packages except Store and framework (adjust as needed)
$ProvisionedApps = dism /Image:$OsDrive /Get-ProvisionedAppxPackages | Select-String 'PackageName'
foreach ($line in $ProvisionedApps) {
    $pkg = $line.ToString().Split(':')[1].Trim()
    if ($pkg -notlike '*Store*' -and $pkg -notlike '*NET*' -and $pkg -notlike '*AppInstaller*') {
        Write-Host "Removing provisioned app: $pkg" -ForegroundColor DarkYellow
        dism /Image:$OsDrive /Remove-ProvisionedAppxPackage /PackageName:$pkg | Out-Null
    }
}

Write-Host '=== Step 7: WinSxS cleanup and image optimization ===' -ForegroundColor Cyan

# Component store cleanup to reduce size
dism /Image:$OsDrive /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

Write-Host '=== Step 8: Unmount temporary mount and clean up ===' -ForegroundColor Cyan

# Unmount DISM image
dism /Unmount-Image /MountDir:$MountDir /Discard | Out-Null
# Remove mount directory
Remove-Item $MountDir -Recurse -Force | Out-Null

# Dismount VHD (you can leave it mounted if you want to inspect it)
Dismount-VHD -Path $VhdPath

Write-Host '=== Step 9: (Optional) Create a Hyper-V VM using this VHDX ===' -ForegroundColor Cyan

# Create a Hyper-V VM if Hyper-V module is available
if (Get-Command New-VM -ErrorAction SilentlyContinue) {
    if (-not (Get-VM -Name $VmName -ErrorAction SilentlyContinue)) {
        New-VM -Name $VmName -MemoryStartupBytes 2GB -Generation 2 -VHDPath $VhdPath | Out-Null
        Set-VMFirmware -VMName $VmName -FirstBootDevice (Get-VMFirmware -VMName $VmName).BootOrder[0]
        Write-Host "Created Hyper-V VM '$VmName' using $VhdPath" -ForegroundColor Green
    } else {
        Write-Host "Hyper-V VM '$VmName' already exists. Attach $VhdPath manually if needed." -ForegroundColor Yellow
    }
} else {
    Write-Host "Hyper-V module not available. Create a VM manually and attach $VhdPath." -ForegroundColor Yellow
}

Write-Host "=== DONE. Minimal Windows 11 VHDX created at $VhdPath ===" -ForegroundColor Green
