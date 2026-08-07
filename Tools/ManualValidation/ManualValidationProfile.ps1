$VM = 0
$build = 137
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
		[switch]$Approved,
		$Clip = (Get-Clipboard)
	)
	Write-Host "Writing $($Clip.length) lines."
	$Clip -join "`n" | Out-File "$writeFolder\err.txt"
	if ($Approved) {
		Get-TrackerVMSetStatus "SendStatus-Approved"
	}
	Get-TrackerVMSetStatus "SendStatus-Complete"
}

function Get-ARPTable {
	Param(
	$DisplayName
	)
	#SandboxTest.ps1 copypasta - https://github.com/microsoft/winget-pkgs/blob/01d110895592f8775f7a3e9c1e4b50a8bd3dc698/Tools/SandboxTest.ps1#L703
    $registry_paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $out = Get-ItemProperty $registry_paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and (-not $_.SystemComponent -or $_.SystemComponent -ne 1 ) } |
        Select-Object DisplayName, DisplayVersion, Publisher, @{N='ProductCode'; E={$_.PSChildName}}, @{N='Scope'; E={if($_.PSDrive.Name -eq 'HKCU') {'User'} else {'Machine'}}}
		if ($DisplayName) {
			$out = $out | where {$_.DisplayName -match $DisplayName}
		}
	return  $out
}

Function Get-TrackerVMSetStatus {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","SendStatus-Approved","SendStatus-Complete","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
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
	$out | ConvertTo-Csv -NoTypeInformation | Out-File $StatusFile
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
		[int]$vmNum,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status,
		$Option = "status",
		$out = (Get-Content $StatusFile | ConvertFrom-Csv | where {$_.status -notmatch "ImagePark"})
	)
	if ($vmNum) {
		$out = ($out | where {$_.vm -eq $vmNum}).$Option
	}
	if ($Status) {
		$out = ($out | where {$_.status -eq $Status}).vm	
	}
	$out
}

<#
Registry:
$a = gci HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | select DisplayName,DisplayVersion
$a += gci HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall | Get-ItemProperty | select DisplayName,DisplayVersion
$a | where {$_.displayname} | sort displayname -Unique

#Clear event logs.

# Commands
$n = 15;$t = $n;while ($n -gt 0) {$n--;$r = $t - $n;Write-Progress -Activity "Build latch" -Status "Seconds remaining: $r/$t" -PercentComplete ((1-$n/$t)*100);sleep 1};
Get-NetAdapter|Disable-NetAdapter;Get-NetAdapter|Enable-NetAdapter;sleep 30;Import-Module $Profile -Force;Import-Module $Profile -Force;cls;Write-Host "VM$VM with remoteIP $remoteIP version $build";
Get-TrackerVMSetStatus CheckpointReady;
$n = 15;$t = $n;while ($n -gt 0) {$n--;$r = $t - $n;Write-Progress -Activity "Run latch" -Status "Seconds remaining: $r/$t" -PercentComplete ((1-$n/$t)*100);sleep 1};
Get-TrackerVMRunValidation
#Get-NetAdapter|Disable-NetAdapter;Get-NetAdapter|Enable-NetAdapter;sleep 30;Import-Module $Profile -Force;Import-Module $Profile -Force;cls;Write-Host "VM$VM with remoteIP $remoteIP version $build";Get-TrackerVMSetStatus CheckpointReady;$n = 15;$t = $n;while ($n -gt 0) {$n--;$r = $t - $n;Write-Progress -Activity "Process latch" -Status "Seconds remaining: $r/$t" -PercentComplete ((1-$n/$t)*100);sleep 1};Write-Host "Waiting for Network...";Get-TrackerVMRunValidation


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

gci HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
gci HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall

#>