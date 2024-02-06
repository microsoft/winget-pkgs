$VM = 0
$build = 129
$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig | select-string "Default Gateway") -split ": ")[1]).IPAddressToString
#$remoteIP = ([ipaddress](($ipconfig[($ipconfig | select-string "vEthernet").LineNumber..$ipconfig.length] | select-string "IPv4 Address") -split ": ")[1]).IPAddressToString
write-host "VM$VM with remoteIP $remoteIP version $build"

$MainFolder = "\\$remoteIP\ManVal"
$homePath = "C:\Users\User\Desktop"
cd $homePath

$runPath = "$MainFolder\vm\$VM"
$writeFolder = "\\$remoteIP\write"
$statusFile = "$writeFolder\status.csv"
$SharedFolder = $writeFolder

if ($VM -eq 0) {
	$VM = (gc "$MainFolder\vmcounter.txt")-1
}
"`$VM = $VM" | out-file $profile
(gc "\\$remoteIP\ManVal\vm\0\profile.ps1")[1..999] | out-file $profile -append

Function Send-SharedError {
	param(
		$c = (Get-Clipboard)
	)
	Write-Host "Writing $($c.length) lines."
	$c | Out-File "$writeFolder\err.txt"
	Get-TrackerVMSetStatus "SendStatus"
}

Function Get-TrackerVMSetStatus {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
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
	$out | ConvertTo-Csv | Out-File $StatusFile
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
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
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
