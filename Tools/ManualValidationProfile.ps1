$VM = 0
$build = 119
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
	Set-Status "Complete"
}
Function Set-Status {
	param(
		[ValidateSet("Prevalidation","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Prescan","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","Setup","SetupComplete","Starting","Updating","Installing","ValidationComplete")]
		$Status = "Complete"
	)
	Write-Host "Setting $vm state $Status"
	$out = Get-Content $statusFile |ConvertFrom-Csv
	($out | where {$_.vm -match $VM}).status = $Status
	$out | ConvertTo-Csv | out-file $statusFile
}
Function Run-Validation {
	param(
		$fileName = "cmds.ps1"
	)
	Copy-Item $runPath\$fileName  $homePath\$fileName 
	& $homePath\$fileName 
}

Function Get-Status{
	param(
		[int]$vm,
		[ValidateSet("Prevalidation","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Prescan","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","Setup","SetupComplete","Starting","Updating","Installing","ValidationComplete")]
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

Function Update-Stuff {
	Set-Status "Updating"
	WinGet upgrade --all --include-pinned --disable-interactivity
	Update-MpSignature
	Start-MpScan
	Set-Status "CheckpointReady"
	Shutdown -R -T 05
}

