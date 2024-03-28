$VM = 0
$build = 133
$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig | select-string "Default Gateway") -split ": ")[1]).IPAddressToString
#$remoteIP = ([ipaddress](($ipconfig[($ipconfig | select-string "vEthernet").LineNumber..$ipconfig.length] | select-string "IPv4 Address") -split ": ")[1]).IPAddressToString
Write-Host "VM$VM with remoteIP $remoteIP version $build"

$MainFolder = "\\$remoteIP\ManVal"
$homePath = "C:\Users\User\Desktop"
Set-Location $homePath

$runPath = "$MainFolder\vm\$VM"
$writeFolder = "\\$remoteIP\write"
$statusFile = "$writeFolder\status.csv"
$SharedFolder = $writeFolder

if ($VM -eq 0) {
	$VM = (gc "$MainFolder\vmcounter.txt")-1
}
"`$VM = $VM" | Out-File $profile
(Get-Content "\\$remoteIP\ManVal\vm\0\profile.ps1")[1..999] | Out-File $profile -append

Function Send-SharedError {
	param(
		$Clip = (Get-Clipboard)
	)
	Write-Host "Writing $($Clip.length) lines."
	$Clip | Out-File "$writeFolder\err.txt"
	Get-TrackerVMSetStatus "SendStatus"
}

Function Get-TrackerVMSetStatus {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status = "Complete",
		[string]$Package,
		[int]$PR
	)
	$out = Get-TrackerVMStatus
	if ($Status) {
		($out | where {$_.vm -match $VM}).Status = $Status
	}
	if ($Package) {
		($out | where {$_.vm -match $VM}).Package = $Package
	}
	if ($PR) {
		($out | where {$_.vm -match $VM}).PR = $PR
	}
	$out | ConvertTo-Csv -NoHeader | Out-File $StatusFile
	Write-Host "Setting $vm $Package $PR state $Status"
}

Function Get-TrackerVMRunValidation {
	param(
		$fileName = "cmds.ps1"
	)
	Copy-Item $runPath\$fileName  $homePath\$fileName 
	& $homePath\$fileName 
}

Function Get-TrackerVMStatus{
	param(
		[int]$vm,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv | where {$_.status -notmatch "ImagePark"})
	)
	if ($vm) {
		$out = ($out | where {$_.vm -eq $vm}).status
	}
	if ($Status) {
		$out = ($out | where {$_.status -eq $Status}).vm	
	}
	$out
}

<#
#Clear event logs.

# Commands
#Get-TrackerVMRunValidation
Get-NetAdapter|Disable-NetAdapter;Get-NetAdapter|Enable-NetAdapter;sleep 5;Import-Module $Profile -Force;Import-Module $Profile -Force;cls;Write-Host "VM$VM with remoteIP $remoteIP version $build"

# Copy command then exit and checkpoint. 
Import-Module $Profile -force; Get-TrackerVMSetStatus CheckpointReady;exit

# Reset display window
$vm = 0;notepad $profile;cls;Write-Host "VM$VM with remoteIP $remoteIP version $build"

# Close Notepad
Get-Process Notepad|Stop-Process;

# Reboot
shutdown -r -t 05

# Setup: ExecutionPolicy, Uninstall, Enable WinGet settings.
Set-ExecutionPolicy Unrestricted
winget uninstall Microsoft.Teams
winget uninstall Microsoft.OneDrive
winget uninstall Microsoft.MSIXPackagingTool_8wekyb3d8bbwe
winget settings --enable LocalManifestFiles;winget settings --enable LocalArchiveMalwareScanOverride;

# Files
Logs file: C:\Users\user\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir
Programs: C:\Users\user\AppData\Local\Programs\
Download: C:\Users\user\AppData\Local\Temp\WinGet\
Portable: C:\Users\user\AppData\Local\Microsoft\WinGet\Packages\
Symlinks: C:\Users\user\AppData\Local\Microsoft\WinGet\Links\

New VM: 
- Open Quick Create, create VM
- Connect, power on, use example@example.com to skip login. 
- User username, easy to type password, security questions.
- Keyboard layout and locale, maybe a few other questions, then skip everything else. 
- Do something else during initial setup.
- Install all store, winget, windows, and defender updates. Reboot as necessary.
ImageVMMove here at any point.
- Open PowerShell and run IPConfig, get switch IP.
- Connect to \\ip\ManVal\, open \vm\0\profile.ps1
- Run few setup and uninstall commands
- Copy to local profile.
- Set up PowerShell window sizes
- Enter commands in windows
ImageVMStop
- Wait for image to cool
PipelineVMGenerate
- VM is in system.
#>
