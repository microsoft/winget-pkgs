#Copyright 2022-2023 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v2.56
#Created: 10/19/2022
#Updated: 7/10/2023
#Notes: Utilities to streamline evaluating 3rd party PRs.
#Update log:
#2.54 Filter comments by hashtag from Get-YamlValue.
#2.55 Bugfix Reset-Status with 0 VMs.
#2.56 Update Validate-Package to use Get-YamlValue in params.

$build = 373
$appName = 'Manual Validation'
Write-Host "$appName build: $build"
$MainFolder = 'C:\ManVal'
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.
Set-Location $MainFolder

$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String 'vEthernet').LineNumber..$ipconfig.length] | Select-String 'IPv4 Address') -split ': ')[1]).IPAddressToString
$RemoteMainFolder = "//$remoteIP/"
$SharedFolder = "$RemoteMainFolder/write"

$imagesFolder = "$MainFolder\Images" #VM Images folder
$runPath = "$MainFolder\vm\" #VM working folder
$writeFolder = "$MainFolder\write" #Folder with write permissions
$vmCounter = "$MainFolder\vmcounter.txt"
$VMversion = "$MainFolder\VMversion.txt"
$StatusFile = "$writeFolder\status.csv"

$CheckpointName = 'Validation'
$VMUserName = 'user' #Set to the internal username you're using in your VMs.
$SandboxUserName = 'WDAGUtilityAccount' #Set to the internal username used in your Sandbox.
$PCUserName = $VMUserName #((whoami) -split "\\")[1]; #Set to your username, or use the commented "whoami" section to autodetect.

#Package validation
Function Validate-Package {
	param(
		#[Parameter(mandatory=$true)]
		$out = ((Get-Clipboard) -split "`n"),
		[ValidateSet('Win10', 'Win11')][string]$OS = (Get-OSFromVersion),
		[int]$vm = ((Get-NextFreeVM -OS $OS) -replace 'vm', ''),
		#$out = ((Get-SecondMatch) -split "`n"),
		[switch]$NoFiles,
		[ValidateSet('Config', 'DevHomeConfig', 'Pin', 'Scan')][string]$Operation = 'Scan',
		[switch]$InspectNew,
		[switch]$notElevated,
		$ManualDependency,
		$PackageIdentifier = (Get-YamlValue -StringName 'PackageIdentifier' $out),
		$PackageVersion = ((Get-YamlValue -StringName 'PackageVersion' $out) -replace '"', '' -replace "'", ''),
		$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		$installerLine = "--manifest $RemoteFolder/manifest",
		[ValidateSet('x86', 'x64', 'arm', 'arm32', 'arm64', 'neutral')][string]$Arch,
		[ValidateSet('User', 'Machine')][string]$Scope,
		[ValidateSet('de-DE', 'en-US', 'es-ES', 'fr-FR', 'it-IT', 'ja-JP', 'ko-KR', 'pt-BR', 'ru-RU', 'zh-CN', 'zh-HK', 'zh-TW')]
		[string]$Locale,
		$vmStatusFile = "$RemoteFolder\$vm.txt",
		$optionsLine = ''
	)
	Test-Admin
	if ($vm -eq 0) {
		Write-Host "No available $OS VMs";
		Generate-PipelineVm -OS $OS;
		Break;
	}
	Set-Status 'Prevalidation' $vm
	if ((Get-VM "vm$vm").state -ne 'Running') { Start-VM "vm$vm" }
	if ($PackageIdentifier -eq '') {
		Write-Host "Bad PackageIdentifier: $PackageIdentifier"
		Break;
	}
	Write-Host "Running Manual Validation build $build on vm$vm for package $PackageIdentifier version $PackageVersion"

	$logLine = "$OS "
	$nonElevatedShell = ''
	$logExt = 'log'
	$VMFolder = "$MainFolder\vm\$vm"
	$manifestFolder = "$VMFolder\manifest"
	$CmdsFileName = "$VMFolder\cmds.ps1"

	if ($PackageVersion) {
		$logExt = $PackageVersion + '.' + $logExt
		$logLine += "version $PackageVersion "
	}
	if ($Locale) {
		$logExt = $Locale + '.' + $logExt
		$optionsLine += " --locale $Locale "
		$logLine += "locale $Locale "
	}
	if ($Scope) {
		$logExt = $Scope + '.' + $logExt
		$optionsLine += " --scope $Scope "
		$logLine += "scope $Scope "
	}
	$Archs = ($out | Select-String -NotMatch 'arm' | Select-String 'Architecture: ' ) | ForEach-Object { ($_ -split ': ')[1] }
	$archDetect = ''
	$archColor = 'yellow'
	if ($Archs) {
		if ($Archs[0].length -ge 2) {
			if ($Arch) {
				$archDetect = 'Selected'
			} else {
				$Arch = $Archs[0]
				$archDetect = 'Detected'
			}
			$otherArch = $Archs | Select-String -NotMatch $Arch
			$archColor = 'red'
		} else {
			if ($Archs -eq 'neutral') {
				$archColor = 'yellow'
			} else {
				$Arch = $Archs
				$archDetect = 'Detected'
				$archColor = 'green'
			}
		}
	}
	if ($Arch) {
		$logExt = $Arch + '.' + $logExt
		Write-Host "$archDetect Arch $Arch of available architectures: $Archs" -f $archColor
		$optionsLine += " --architecture $Arch "
		$logLine += "$Arch "
	}
	<#Automatic manual dependency support to preinstall dependencies when dependencies are not supported, for more complete testing confirmation.
	if (!$ManualDependency) {
		$ManualDependency = try {($out[($out | Select-String "PackageDependencies:").LineNumber] -split ": ")[1]}catch{}
	}
 #>
	$MDLog = ''
	if ($ManualDependency) {
		$MDLog = $ManualDependency
		Write-Host " = = = = Installing manual dependency $ManualDependency  = = = = "
		[string]$ManualDependency = "Out-Log 'Installing manual dependency $ManualDependency.';Start-Process 'winget' 'install " + $ManualDependency + "  --accept-package-agreements --ignore-local-archive-malware-scan' -wait`n"
	}
	if ($notElevated -OR ($out | Select-String 'ElevationRequirement: elevationProhibited')) {
		Write-Host ' = = = = Detecting de-elevation requirement = = = = '
		$nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\Program Files\PowerShell\7\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}"
		#If elevated, run^^ and exit, else run cmds.
	}
	$packageDeveloper = ($PackageIdentifier -split '[.]')[0]
	$packageName = ($PackageIdentifier -split '[.]')[1]

	$cmdsOut = ''

	switch ($Operation) {
		'Config' {
			$cFile = 'configuration.dsc.yaml'
			$cPath = "$MainFolder/misc/$cFile"
			Write-Host "Writing $($out.length) lines to $cPath"
			$out | Out-File $cPath
			$yamlFile = "$RemoteMainFolder/ManVal/misc/$cFile"

			$repoOwner = ($out[1] -split '/')[3]
			$repoName = (($out[1] -split '/')[4] -split '#')[0]

			Write-Host "Detecting repoOwner $repoOwner and repoName $repoName"

			<#Clone the repo so that it's available to be the wildcard, just in case the config has a wildcard location.

Run config on bare PS
Run config on Devhome
Install Git and clone repo if has wildcard
Verify same output


Installs Git
Clones Repo (if has )
Either install DevHome or run Config
#>



			$cmdsOut = "$nonElevatedShell
`$TimeStart = Get-Date;
`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
	`$TimeStamp = (Get-Date -Format T) + ': ';
	`$logEntry = `$TimeStamp + `$logData
	Write-Host `$logEntry  -f `$logColor;
	md `$ManValLogFolder -ErrorAction Ignore
	`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append
};
Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
	Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
	`$errArray | %{Out-Log `$_ 'red'}
};
Set-Status 'Installing' $vm
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

Out-Log 'Clearing PowerShell errors.'
`$Error.Clear()
Out-Log 'Clearing Application Log.'
Clear-EventLog -LogName Application -ErrorAction Ignore
Out-Log 'Clearing WinGet Log folder.'
`$WinGetLogFolder = 'C:\Users\User\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
rm `$WinGetLogFolder\*
Out-Log 'Gathering WinGet info.'
`$info = winget --info
Out-ErrorData @(`$info[0],`$info[3],`$info[4],`$info[5]) 'WinGet' 'infos'

$ManualDependency
`$wingetArgs = 'install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan'
Out-Log `"Main Package Install with args: `$wingetArgs`"
`$mainpackage = (Start-Process 'winget' `$wingetArgs  -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
	Break;
}

`$repoGit = `"https://github.com/$repoOwner/$repoName.git`"
`$repoFolder = `"c:\repos`"
`$configFolder = `"`$repoFolder\$repoName\.configurations`"
md `$repoFolder
cd `$repoFolder
if (`$repoGit.length -gt 24) {
	&`"c:\program files\git\bin\git.exe`" clone `$repoGit
} else {
}
md `$configFolder
cd `$configFolder
Write-Host `"Writing to `$configFolder\$cFile`"
Copy-item $yamlFile `"`$configFolder\$cFile`"
winget configure `"`$configFolder\$cFile`"

Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
"

		}
		'DevHomeConfig' {
			$cFile = 'configuration.dsc.yaml'
			$cPath = "$MainFolder/misc/$cFile"
			Write-Host "Writing $($out.length) lines to $cPath"
			$out | Out-File $cPath
			$yamlFile = "$RemoteMainFolder/ManVal/misc/$cFile"

			$repoOwner = ($out[1] -split '/')[3]
			$repoName = (($out[1] -split '/')[4] -split '#')[0]

			Write-Host "Detecting repoOwner $repoOwner and repoName $repoName"

			$cmdsOut = "$nonElevatedShell
`$TimeStart = Get-Date;
`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
	`$TimeStamp = (Get-Date -Format T) + ': ';
	`$logEntry = `$TimeStamp + `$logData
	Write-Host `$logEntry  -f `$logColor;
	md `$ManValLogFolder -ErrorAction Ignore
	`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append
};
Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
	Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
	`$errArray | %{Out-Log `$_ 'red'}
};
Set-Status 'Installing' $vm
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

Out-Log 'Clearing PowerShell errors.'
`$Error.Clear()
Out-Log 'Clearing Application Log.'
Clear-EventLog -LogName Application -ErrorAction Ignore
Out-Log 'Clearing WinGet Log folder.'
`$WinGetLogFolder = 'C:\Users\User\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
rm `$WinGetLogFolder\*
Out-Log 'Gathering WinGet info.'
`$info = winget --info
Out-ErrorData @(`$info[0],`$info[3],`$info[4],`$info[5]) 'WinGet' 'infos'

$ManualDependency
`$wingetArgs = 'install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan'
Out-Log `"Main Package Install with args: `$wingetArgs`"
`$mainpackage = (Start-Process 'winget' `$wingetArgs  -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
	Break;
}

`$repoGit = `"https://github.com/$repoOwner/$repoName.git`"
`$repoFolder = `"c:\repos`"
`$configFolder = `"`$repoFolder\$repoName\.configurations`"
md `$repoFolder
cd `$repoFolder
if (`$repoGit.length -gt 24) {
	Out-Log (&`"c:\program files\git\bin\git.exe`" clone `$repoGit)
} else {
}
md `$configFolder
cd `$configFolder
Out-Log `"Writing to `$configFolder\`$cFile`"
Copy-item $yamlFile `"`$configFolder\`$cFile`"

`"`$configFolder\`$cFile`" | clip.exe
Read-Host `"Use DevHome to check `$configFolder\$cFile, then press ENTER to continue...`" #Uncomment to examine installer before scanning, for when scanning disrupts the install.

Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
"

		}
		'Pin' {
			$cFile = 'pinFile.txt'
			$cPath = "$MainFolder/misc/$cFile"
			Write-Host "Writing $($out.length) lines to $cPath"
			$out | Out-File $cPath
			$yamlFile = "$RemoteMainFolder/ManVal/misc/$cFile"

			$cmdsOut = "$nonElevatedShell
`$TimeStart = Get-Date;
`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
	`$TimeStamp = (Get-Date -Format T) + ': ';
	`$logEntry = `$TimeStamp + `$logData
	Write-Host `$logEntry  -f `$logColor;
	md `$ManValLogFolder -ErrorAction Ignore
	`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append
};
Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
	Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
	`$errArray | %{Out-Log `$_ 'red'}
};
Set-Status 'Installing' $vm
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

Out-Log 'Pre-testing log cleanup.'
Out-Log 'Upgrading installed applications.'
Out-Log (WinGet upgrade --all --include-pinned --disable-interactivity) | where {$_ -notmatch 'Γûê'}
Out-Log 'Clearing PowerShell errors.'
`$Error.Clear()
Out-Log 'Clearing Application Log.'
Clear-EventLog -LogName Application -ErrorAction Ignore
Out-Log 'Clearing WinGet Log folder.'
`$WinGetLogFolder = 'C:\Users\User\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
rm `$WinGetLogFolder\*
Out-Log 'Updating Defender signature.'
Update-MpSignature
Out-Log 'Gathering WinGet info.'
`$info = winget --info
Out-ErrorData @(`$info[0],`$info[3],`$info[4],`$info[5]) 'WinGet' 'infos'

$ManualDependency
`$wingetArgs = 'install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan'
Out-Log `"Main Package Install with args: `$wingetArgs`"
`$mainpackage = (Start-Process 'winget' `$wingetArgs  -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Failing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
	Break;
}


#Read-Host 'Install complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.


Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
"
		}

		'Scan' {
			$cmdsOut = "$nonElevatedShell
`$TimeStart = Get-Date;
`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
	`$TimeStamp = (Get-Date -Format T) + ': ';
	`$logEntry = `$TimeStamp + `$logData
	Write-Host `$logEntry  -f `$logColor;
	md `$ManValLogFolder -ErrorAction Ignore
	`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append
};
Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
	Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
	`$errArray | %{Out-Log `$_ 'red'}
};
Set-Status 'Installing' $vm
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

Out-Log 'Pre-testing log cleanup.'
Out-Log 'Upgrading installed applications.'
Out-Log (WinGet upgrade --all --include-pinned --disable-interactivity) | where {$_ -notmatch 'Γûê'}
Out-Log 'Clearing PowerShell errors.'
`$Error.Clear()
Out-Log 'Clearing Application Log.'
Clear-EventLog -LogName Application -ErrorAction Ignore
Out-Log 'Clearing WinGet Log folder.'
`$WinGetLogFolder = 'C:\Users\User\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
rm `$WinGetLogFolder\*
Out-Log 'Updating Defender signature.'
Update-MpSignature
Out-Log 'Gathering WinGet info.'
`$info = winget --info
Out-ErrorData @(`$info[0],`$info[3],`$info[4],`$info[5]) 'WinGet' 'infos'

$ManualDependency
`$wingetArgs = 'install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan'
Out-Log `"Main Package Install with args: `$wingetArgs`"
`$mainpackage = (Start-Process 'winget' `$wingetArgs  -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Failing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
	Break;
}
#Read-Host 'Install complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.

Set-Status 'Scanning' $vm

Out-Log 'Install complete, starting file change scan.'
`$files = ''
if (Test-Path $RemoteFolder\files.txt) {
	`$files = Get-Content $RemoteFolder\files.txt
} else {
	`$files1 = (Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | where {`$_.CreationTime -gt `$TimeStart}).FullName
	`$files2 = (Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | where {`$_.LastAccessTIme -gt `$TimeStart}).FullName
	`$files = `$files1 + `$files2 | Select-Object -Unique
}

Out-Log `"Reading `$(`$files.count) file changes in the last `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. Starting bulk file execution:`"
`$files = `$files | where {`$_ -notmatch 'unins'} | where {`$_ -notmatch 'dotnet'} | where {`$_ -notmatch 'redis'} | where {`$_ -notmatch 'System32'} | where {`$_ -notmatch 'SysWOW64'} | where {`$_ -notmatch 'WinSxS'} | where {`$_ -notmatch 'dump64a'}
`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'
`$files | select-string '[.]exe`$' | %{Out-Log `$_; try{Start-Process `$_}catch{}};
`$files | select-string '[.]msi`$' | %{Out-Log `$_; try{Start-Process `$_}catch{}};
`$files | select-string '[.]lnk`$' | %{Out-Log `$_; try{Start-Process `$_}catch{}};

Out-Log `" = = = = End file list. Starting Defender scan.`"
Start-MpScan;

Out-Log `"Defender scan complete, closing windows...`"
(get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell'  -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'})| %{
	`$process = (Stop-Process `$_ -PassThru);
	Out-Log `"`$(`$process.processname) finished with exit code: `$(`$process.ExitCode)`";
}

Out-ErrorData (Get-MPThreat).ThreatName `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"
Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete' $vm
"
		}
		Default {
			Write-Host 'Error: Bad Function'
			Break;
		}
	}

	$cmdsOut | Out-File $CmdsFileName

	if ($NoFiles -eq $False) {
		#Extract multi-part manifest from clipboard and write to disk
		Write-Host 'Removing previous manifest and adding current...'
		Remove-FileIfExists "$manifestFolder" -remake
		$Files = @()
		$Files += 'Package.installer.yaml'
		$FileNames = ($out | Select-String '[.]yaml') | ForEach-Object { ($_ -split '/')[-1] }
		$replace = $FileNames[-1] -replace '.yaml'
		$FileNames | ForEach-Object {
			$Files += $_ -replace $replace, 'Package'
		}
		$out = $out -join "`n" -split '@@'
		for ($i = 0; $i -lt $Files.length; $i++) {
			$File = $Files[$i]
			$inputObj = $out[$i * 2] -split "`n"
			$inputObj = $inputObj[1..(($inputObj | Select-String 'ManifestVersion' -SimpleMatch).LineNumber - 1)] | Where-Object { $_ -notmatch 'marked this conversation as resolved.' }
			$FilePath = "$manifestFolder\$File"
			Write-Host "Writing $($inputObj.length) lines to $FilePath"
			Out-File -FilePath $FilePath -InputObject $inputObj
			#Bugfix to catch package identifier appended to last line of last file.
			$fileContents = (Get-Content $FilePath)
			if ($fileContents[-1] -match $PackageIdentifier) {
				$fileContents[-1] = ($fileContents[-1] -split $PackageIdentifier)[0]
			}
			$fileContents -replace '0New version: ', '0' -replace '0New package: ', '0' -replace '0Add version: ', '0' -replace '0Add package: ', '0' -replace '0Add ', '0' -replace '0New ', '0' -replace '0package:  ', '0' | Out-File $FilePath
		}
		$filecount = (Get-ChildItem $manifestFolder).count
		$filedir = 'ok'
		$filecolor = 'green'
		if ($filecount -lt 3) { $filedir = 'too low'; $filecolor = 'red' }
		if ($filecount -gt 3) { $filedir = 'high'; $filecolor = 'yellow' }
		if ($filecount -gt 10) { $filedir = 'too high'; $filecolor = 'red' }
		Write-Host -f $filecolor "File count $filecount is $filedir"
		if ($filecount -lt 3) { break }
		Check-ManifestFile $vm;
	}#end if NoFiles

	if ($InspectNew) {
		$PackageResult = Search-WinGetManifest $PackageIdentifier
		Write-Host "Searching Winget for $PackageIdentifier"
		Write-Host $PackageResult
		if ($PackageResult -eq 'No package found matching input criteria.') {
			Open-AllURLs
			Start-Process "https://www.bing.com/search?q=$PackageIdentifier"
			$a, $b = $PackageIdentifier -split '[.]'
			Write-Host "Searching Winget for $a"
			if ($a -ne '') {
				Search-WinGetManifest $a
			}
			Write-Host "Searching Winget for $b"
			if ($b -ne '') {
				Search-WinGetManifest $b
			}
		}
	}
	Write-Host 'File operations complete, starting VM operations.'
	Revert-VM $vm
	Launch-VMTrackerWindow $vm
}

Function Validate-PackageByID {
	param(
		$PackageIdentifier = (Get-Clipboard)
	)
	Validate-Package -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles #-notElevated
}

Function Validate-PackageByConfig {
	param(
		$PackageIdentifier = 'Microsoft.Devhome',
		$ManualDependency = 'Git.Git'
	)

	Validate-Package -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles -ManualDependency $ManualDependency -Operation 'DevHomeConfig'
	Start-Sleep 2
	Validate-Package -installerLine "--id $ManualDependency" -PackageIdentifier $ManualDependency -NoFiles -Operation 'Config'
}

#VM Management
Function Complete-TrackerVM {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$VMFolder = "$MainFolder\vm\$vm",
		$filesFileName = "$VMFolder\files.txt",
		[switch]$Reset
	)
	Test-Admin
	Set-Status 'Completing' $vm
	Stop-Process -Id ((Get-ConnectedVMs) | Where-Object { $_.VM -match "vm$vm" }).id -ErrorAction Ignore
	Stop-TrackerVM $vm
	Remove-FileIfExists $filesFileName
	Set-Status 'Ready' $vm
}

Function Generate-PipelineVm {
	param(
		[int]$vm = (Get-Content $vmCounter),
		[int]$version = (Get-TrackerVMversion),
		[ValidateSet('Win10', 'Win11')][string]$OS = 'Win10',
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$newVmName = "vm$vm",
		$startTime = (Get-Date)
	)
	Test-Admin
	$vm + 1 | Out-File $vmCounter
	"`"$vm`",`"Generating`",`"$version`",`"$OS`"" | Out-File $StatusFile -Append
	Remove-FileIfExists $destinationPath -remake
	Remove-FileIfExists $VMFolder -remake
	$vmImageFolder = ''

	switch ($OS) {
		'Win10' {
			$vmImageFolder = "$imagesFolder\Win10-image\Virtual Machines\0CF98E8A-73BB-4E33-ABA6-7513F376407D.vmcx"
		}
		'Win11' {
			$vmImageFolder = "$imagesFolder\Win11-image\Virtual Machines\D2C1F2F3-927D-4B43-A026-5208274EA61C.vmcx"
		}
	}

	Write-Host 'Takes about 120 seconds...'
	Import-VM -Path $vmImageFolder -Copy -GenerateNewId -VhdDestinationPath $destinationPath -VirtualMachinePath $destinationPath;
	Rename-VM (Get-VM | Where-Object { ($_.CheckpointFileLocation) + '\' -eq $destinationPath }) -NewName $newVmName
	Start-VM $newVmName
	Remove-VMCheckpoint -VMName $newVmName -Name 'Backup'
	Revert-VM $vm
	Launch-VMTrackerWindow $vm
	Write-Host "Took $(((Get-Date)-$startTime).TotalSeconds) seconds..."
}

Function Disgenerate-PipelineVm {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = "vm$vm"
	)
	Test-Admin
	Set-Status 'Disgenerate' $vm
	Stop-TrackerVM $vm
	Remove-VM -Name $vmName -Force

	$out = Get-Status
	$out = $out | Where-Object { $_.vm -notmatch $VM }
	$out | ConvertTo-Csv | Out-File $StatusFile

	$delay = 15
	0..$delay | ForEach-Object {
		$pct = $_ / $delay * 100
		Write-Progress -Activity 'Remove VM' -Status "$_ of 30" -PercentComplete $pct
		Start-Sleep 1
	}
	Remove-FileIfExists $destinationPath
	Remove-FileIfExists $VMFolder
}

Function Start-ImageVM {
	param(
		[ValidateSet('Win10', 'Win11')][string]$OS = 'Win10'
	)
	Test-Admin
	$vm = 0
	Start-VM $OS;
	Revert-VM $vm $OS;
	Launch-VMTrackerWindow $vm $OS
	#Set-Status "Ready" $vm
}

Function Stop-ImageVM {
	param(
		[ValidateSet('Win10', 'Win11')][string]$OS = 'Win10'
	)
	Test-Admin
	$vm = 0
	$OriginalLoc = ''
	switch ($OS) {
		'Win10' {
			$OriginalLoc = "$imagesFolder\Win10-Created061623-Original"
		}
		'Win11' {
			$OriginalLoc = "$imagesFolder\Win11-Created030623-Original\"
		}
	}
	$ImageLoc = "$imagesFolder\$OS-image\"
	$version = Get-TrackerVMVersion + 1
	Write-Host "Writing $OS version $version"
	Set-TrackerVMVersion $version
	Stop-Process -Id ((Get-ConnectedVMs) | Where-Object { $_.VM -match "$OS" }).id -ErrorAction Ignore
	Redo-Checkpoint $vm $OS;
	Stop-TrackerVM $vm $OS
	Robocopy.exe $OriginalLoc $ImageLoc -mir
}

Function Remove-PR {
	#This hasn't been tested, and is just the skeleton of a Quick Remover for Bad PRs.
	param(
		$gitUrl,
		$branchName,
		$prFolder
	)
	git clone $gitUrl
	git branch $branchName
	Remove-Item folder $prFolder
	git commit
	Start-Process $gitUrl
	Write-Host 'go make PR on GitHub'
}

#VM Utilities
Function Cycle-VMs {
	param(
		[int]$Validate
	)
	#Get-Content $File | %{& [scriptblock]::Create($Command+" "+$vm)
	$VMs = Get-Status
	Foreach ($VM in $VMs) {
		Switch ($VM.status) {
			'CheckpointReady' {
				Redo-Checkpoint $VM.vm
			}
			'Complete' {
				Complete-TrackerVM $VM.vm
			}
			'Revert' {
				Revert-VM $VM.vm
			}
			'Disgenerate' {
				Disgenerate-PipelineVm $VM.vm
			}
			'Regenerate' {
				Disgenerate-PipelineVm $VM.vm
				Generate-PipelineVm -OS $VM.os
			}
			default {
				#Write-Host "Complete"
			}
		}; #end switch
	}
}

Function Set-Status {
	param(
		[ValidateSet('Prevalidation', 'CheckpointComplete', 'Checkpointing', 'CheckpointReady', 'Completing', 'Complete', 'Disgenerate', 'Generating', 'Prescan', 'Ready', 'Rebooting', 'Regenerate', 'Restoring', 'Revert', 'Scanning', 'Setup', 'SetupComplete', 'Starting', 'Updating', 'Installing', 'ValidationComplete')]
		$Status = 'Complete',
		$VM
	)
	$out = Get-Status
	($out | Where-Object { $_.vm -match $VM }).status = $Status
	$out | ConvertTo-Csv | Out-File $StatusFile
	Write-Host "Setting $vm state $Status"
}

Function Get-Status {
	param(
		[int]$vm,
		[ValidateSet('Prevalidation', 'CheckpointComplete', 'Checkpointing', 'CheckpointReady', 'Completing', 'Complete', 'Disgenerate', 'Generating', 'Prescan', 'Ready', 'Rebooting', 'Regenerate', 'Restoring', 'Revert', 'Scanning', 'Setup', 'SetupComplete', 'Starting', 'Updating', 'Installing', 'ValidationComplete')]
		$Status,
		[ValidateSet('Win10', 'Win11')][string]$OS,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv)
	)
	if ($OS) {
		$out = ($out | Where-Object { $_.OS -eq $OS })
	}
	if ($vm) {
		$out = ($out | Where-Object { $_.vm -eq $vm }).status
	}
	if ($Status) {
		$out = ($out | Where-Object { $_.version -eq (Get-TrackerVMVersion) } | Where-Object { $_.status -eq $Status }).vm
	}
	$out
}

Function Reset-Status {
	if (!(Get-ConnectedVMs)) {
		$VMs = (get-status | Where-Object { $_.status -ne 'Ready' }).vm
		Foreach ($VM in $VMs) { Set-Status Complete $_ }
		Get-Process *vmwp* | Stop-Process
	}
}

Function Rebuild-Status {
	Get-VM | Where-Object { $_.name -notmatch 'vm0' } | Select-Object @{n = 'vm'; e = { $_.name } }, @{n = 'status'; e = { 'Ready' } }, @{n = 'version'; e = { 36 } }, @{n = 'OS'; e = { 'Win11' } } | ConvertTo-Csv | Out-File $StatusFile
}

Function Run-StatusTracker {
	while ($true) {
		#$StuckVMs = (diff (Get-Status | where {$_.status -eq "ValidationComplete"}).vm ((Get-ConnectedVMs).vm -replace "vm","")).inputobject
		#Foreach ($vm in $StuckVMs) {
		#Set-Status Complete $vm
		#}
		Cycle-VMs;
		Start-Sleep 5;
		Clear-Host
		Get-Status
		$clip = (Get-Clipboard)
		If ($clip -match 'https://dev.azure.com/ms/') {
			Get-AutoValLogs
		} elseIf ($clip -match 'Skip to content') {
			#Validate-Package;
			#"Validating"|clip
		} elseIf ($clip -match ' Windows Package Manager') {
			Get-PRNumbers
		}
		if (!(Get-ConnectedVMs)) {
			Reset-Status
		}
	}
}

Function Get-SharedError {
	(Get-Content "$writeFolder\err.txt") -replace 'Faulting', "`n> Faulting" -replace '2023', "`n> 2023" | clip
}

Function Get-ConnectedVMs {
	Test-Admin
	(Get-Process *vmconnect*) | Select-Object id, @{n = 'VM'; e = { ForEach-Object { $_.mainwindowtitle[0..4] -join '' } } }
}

Function Get-NextFreeVM {
	param(
		[ValidateSet('Win10', 'Win11')][string]$OS = 'Win10'
	)
	Test-Admin
	try {
		Get-Status -OS $OS -Status Ready | Get-Random
	} catch {
		Write-Host "No available $OS VMs"
		Break;
	}
}

Function Get-ExistingVMs {
	Test-Admin
	(Get-VM).name | Select-String -NotMatch 'Win'
}

Function Launch-VMTrackerWindow {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-ConnectedVMs | Where-Object { $_.vm -match $VMName } | ForEach-Object { Stop-Process -Id $_.id }
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Redo-Checkpoint {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Set-Status 'Checkpointing' $vm
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Set-Status 'Complete' $vm
}

Function Revert-VM {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Set-Status 'Restoring' $vm
	Restore-VMCheckpoint -Name $CheckpointName -VMName $VMName -Confirm:$false
}

Function Get-OSFromVersion {
	try {
		if ([system.version](Get-YamlValue -StringName MinimumOSVersion) -ge [system.version]'10.0.22000.0') { 'Win11' }else { 'Win10' }
	} catch {
		'Win10'
	}
}

Function Get-TrackerVMVersion { Get-Content $VMversion }

Function Set-TrackerVMVersion { param([int]$Version) $Version | Out-File $VMversion }

Function Stop-TrackerVM {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

#File Management
Function Get-ManifestFile {
	param(
		#[Parameter(mandatory=$true)]
		[int]$vm = ((Get-NextFreeVM) -replace 'vm', ''),
		[Switch]$Installer,
		$clip = (Get-SecondMatch),
		$FileName = 'Package'
	);
	$clip = $clip | Where-Object { $_ -notmatch 'marked this conversation as resolved.' }
	if (!(Test-Path "C:\ManVal\vm\$vm\manifest\")) { mkdir "C:\ManVal\vm\$vm\manifest\" }

	<#
		$clip = $clip -join "`n" -split "@@"
		$inputObj = $inputObj[1..(($inputObj| Select-String "ManifestVersion" -SimpleMatch).LineNumber -1)] | where {$_ -notmatch "marked this conversation as resolved."}

		$FilePath = "$manifestFolder\$File"
		Write-Host "Writing $($inputObj.length) lines to $FilePath"
		Out-File -FilePath $FilePath -InputObject $inputObj
		#Bugfix to catch package identifier appended to last line of last file.
		$fileContents = (Get-Content $FilePath)
#>

	$YamlValue = (Get-YamlValue ManifestType $clip)
	switch ($YamlValue) {
		'Locale' {
			$Locale = (Get-YamlValue PackageLocale $clip)
			$FileName = "$FileName.locale.$Locale"
		}
		'defaultLocale' {
			$Locale = (Get-YamlValue PackageLocale $clip)
			$FileName = "$FileName.locale.$Locale"
		}
		'installer' {
			$FileName = "$FileName.installer"
		}
		'version' {
			Validate-Package -vm $vm -NoFiles
		}
		Default {
			Write-Host 'Error: Bad ManifestType'
		}
	}
	$FilePath = "$MainFolder\vm\$vm\manifest\$FileName.yaml"
	Write-Host "Writing $($clip.length) lines to $FilePath"
	$clip -replace '0New version: ', '0' -replace '0Add version: ', '0' -replace '0Add ', '0' -replace '0New ', '0' | Out-File $FilePath
}

Function Get-SecondMatch {
	param(
		$c = (Get-Clipboard),
		$depth = 1
	)
	for ($l = $depth; $l -lt $c.length; $l++) {
		$current = ($c[$l] -split ': ')[0]
		$prev = ($c[$l - $depth] -split ': ')[0]
		#write-host "Current $current prev $prev"
		if ($current -ne $prev) { $c[$l - $depth] }
	}
	for ($j = $depth ; $j -gt 0; $j--) {
		$c[ - $j]
	}
}

Function Test-Hash {
	param(
		$FileName,
		$hashVar = (Get-Clipboard),
		[Switch]$noDelete
	)
	$out = (Get-FileHash $FileName) -match $hashVar
	switch ($noDelete) {
		$true {
		}
		$false {
			Remove-FileIfExists $FileName
		}
	}
	switch ($out) {
		$true {
			Write-Host $out -ForegroundColor green
		}
		$false {
			Write-Host $out -ForegroundColor red
		}
	}
}

Function Find-Hash ($FileName) {
	$hash = (Get-FileHash $FileName).hash;
	$hash | clip;
	Get-Clipboard
	Test-Hash $file $hash
}

Function Check-ManifestFile {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$filePath = "$runPath\$vm\manifest\Package.yaml"
	)
	$fileContents = Get-Content $filePath
	if ($fileContents[-1] -ne '0') {
		$fileContents[-1] = ($fileContents[-1] -split '.0')[0] + '.0'
		Write-Host "Writing $($fileContents.length) lines to $filePath"
		$fileContents | Out-File $filePath
	}
}

Function Rotate-TrackerVMLogs {
	$logYesterDate = (Get-Date -f dd) - 1
	Move-Item "$writeFolder\logs\$logYesterDate" "$MainFolder\logs\$logYesterDate"
}

Function Get-AutoValLogs {
	param(
		$clip = (Get-Clipboard),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		[switch]$Force
	)
	Get-Process *photosapp* | Stop-Process
	$AutoValbuild = (($clip -split '=')[1])
	Start-Process "https://dev.azure.com/ms/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$AutoValbuild/artifacts?artifactName=InstallationVerificationLogs&api-version=7.0&%24format=zip"
	Start-Sleep 2;
	if (!(Test-Path $ZipPath) -AND !$Force) {
		Write-Host 'No logs.'
		'No logs.' | clip
		#break;
	}
	Remove-Item $LogPath -Recurse -ErrorAction Ignore
	Expand-Archive $ZipPath -DestinationPath $DestinationPath;
	#Get-ChildItem "$MainFolder\Installers\Install*" | Remove-Item -Recurse #Clean out installer logs
	Remove-Item "$DestinationPath\InstallationVerificationLogs.zip"
	(
		(Get-ChildItem $LogPath).FullName | ForEach-Object {
			if ($_ -match 'png') { Start-Process $_ }
			Get-Content $_ | Where-Object {
				$_ -match '[[]FAIL[]]' -OR $_ -match 'fail' -OR $_ -match 'error' -OR $_ -match 'exception' }
		}
	) -split "`n" | Select-Object -Unique | clip;
	Get-CannedResponse AutoValEnd
}

#Inject dependencies
Function Add-ValidationData {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$Data = 'Microsoft.VCRedist.2015+.x64',
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest",
		$FilePath = "$manifestFolder\Package.installer.yaml",
		$fileContents = (Get-Content $FilePath),
		$Selector = 'Installers:',
		$offset = 1,
		#[switch]$Force,
		$lineNo = (($fileContents | Select-String $Selector -List).LineNumber - $offset),
		$fileInsert = "Dependencies:`n  PackageDependencies:`n    - PackageIdentifier: $Data",
		$fileOutput = ($fileContents[0..($lineNo - 1)] + $fileInsert + $fileContents[$lineNo..($fileContents.length)])
	)
	#This is an example of a "sideways wrapper". Bubble all parameters up 1 line as variables. Bubble all variables as high as possible in the function. Bubble variables at the top into parameters. Watch all the flexibility that unlocks.
	#if ($Force) {
	Write-Host "Writing $($fileContents.length) lines to $FilePath"
	Out-File -FilePath $FilePath -InputObject $fileOutput
	Set-Status 'Revert' $VM;
	#} else {
	#Write-Host "We don't support dependencies. You may be looking for: `n $fileInsert"
	#}
}

Function Add-InstallerSwitch {
	param(
		[Parameter(mandatory = $true)][int]$vm,
		$Data = '/qn',
		$Selector = 'ManifestType:',
		[ValidateSet('EXE', 'MSI', 'MSIX', 'Inno', 'Nullsoft', 'InstallShield')]
		[string]$InstallerType

	)
	switch ($InstallerType) {
		'MSIX' {
			$Data = '/quiet'
		}
		'Inno' {
			$Data = '/SILENT'
		}
		'Nullsoft' {
			$Data = '/S'
		}
		'InstallShield' {
			$Data = '/s' #or -s
		}
	}
	$fileInsert = "  InstallerSwitches:`n    Silent: $Data"
	Add-ValidationData $vm -Data $Data -Selector $Selector -fileInsert $fileInsert #-Force
}

#@wingetbot waivers
Function Get-CannedResponse {
	param(
		[ValidateSet('AppFail', 'Arguments', 'ArgumentsHelp', 'AutomationBlock', 'AutoValEnd', 'AutoValFail', 'Dependency32', 'Dependency64', 'Dependency', 'Drivers', 'EULA', 'GenevaValPipe', 'GenevaWingetbotMention', 'IcMValidationEphemeral', 'IcMValidationEvery', 'IcMValidationFirst', 'IcMValidationStale', 'IcMWaiverCommit', 'InstallerFail', 'InstallerNotUnattended', 'InstallerUrlBad', 'ManValFail', 'NoCause', 'NoExe', 'NoRecentActivity', 'NotGoodFit', 'Only64bit', 'PackageFail', 'Paths', 'PendingAttendedInstaller', 'Unattended', 'Unavailable', 'UrlBad')]
		[string]$Response,
		$UserInput = (Get-Clipboard),
		$Dependency64 = 'Microsoft.VCRedist.2015+.x64',
		$Dependency32 = 'Microsoft.VCRedist.2015+.x86',
		[int]$TruncateAfterLine = 10
	)
	[string]$Username = '@' + $UserInput.replace(' ', '') + ','
	switch ($Response) {
		'AppFail' {
			$out = "Hi $Username`n`nThe application installed normally, but gave an error instead of launching:`n"
		}
		'Arguments' {
			if (($UserInput -split "`n").length -gt $TruncateAfterLine) {
				$UserInput = ($UserInput -split "`n")[0..$TruncateAfterLine]
				$UserInput += '...'
			}
			$out = "This package is expecting arguments:`n```````n"
			$UserInput | ForEach-Object { $out += $_ + "`n" }
			$out += "`n``````"
		}
		'ArgumentsHelp' {
			if (($UserInput -split "`n").length -gt $TruncateAfterLine) {
				$UserInput = ($UserInput -split "`n")[0..$TruncateAfterLine]
				$UserInput += '...'
			}
			$out = "This package runs with no output when given no arguments. Providing `-help` yields:`n```````n"
			$UserInput | ForEach-Object { $out += $_ + "`n" }
			$out += "`n``````"
		}
		'AutomationBlock' {
			$out = 'This might be due to a network block of data centers, to prevent automated downloads.'
		}
		'AutoValEnd' {
			$out = "Automatic Validation ended with:`n> $UserInput"
		}
		'AutoValFail' {
			$out = "Automatic Validation failed with:`n> $UserInput"
		}
		'Dependency' {
			$out = "Hi $Username`n`nThe package installs normally, but requires ``$Dependency64`` (or ``$Dependency32``) to run:`n`nPending:`n* https://github.com/microsoft/winget-cli/issues/163"
		}
		'Dependency32' {
			$out = "Hi $Username`n`nThe package installs normally, but requires ``$Dependency32`` to run:`n`nPending:`n* https://github.com/microsoft/winget-cli/issues/163"
		}
		'Dependency64' {
			$out = "Hi $Username`n`nThe package installs normally, but requires ``$Dependency64`` to run:`n`nPending:`n* https://github.com/microsoft/winget-cli/issues/163"
		}
		'Drivers' {
			$out = "Hi $Username`n`nThe installation is unattended, but installs a driver which isn't unattended:`n`Unfortunately, installer switches are not usually provided for this situation. Are you aware of an installer switch to have the driver silently install as well?"
		}
		'EULA' {
			$out = "Hi $Username`n`nThe installation isn't unattended It requires the user to accept an EULA:`n`nIs there an installer switch to accept this and have it install automatically?"
		}
		'InstallerFail' {
			$out = "Hi $Username`n`nThe installer did not complete:`n"
		}
		'InstallerNotUnattended' {
			$out = "Pending:`n* https://github.com/microsoft/winget-cli/issues/910"
		}
		'InstallerUrlBad' {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
		}
		'UrlBad' {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
		}
		'ManValFail' {
			$out = "Manual Validation failed with:`n> $UserInput"
		}
		'NoCause' {
			$out = "I'm not able to find the cause for this error. It installs and runs normally on a Windows 11 VM."
		}
		'NoExe' {
			$out = "Hi $Username`n`nThe installer doesn't appear to install any executables, only supporting files:`n`nIs this expected?"
		}
		'NoRecentActivity' {
			$out = 'Closing with reason: No recent activity.'
		}
		'NotGoodFit' {
			$out = "Hi $Username`n`nUnfortunately, this package might not be a good fit for inclusion into the WinGet public manifests. Please consider using a local manifest (`WinGet install --manifest C:\path\to\manifest\files\`) for local installations. "
		}
		'Only64bit' {
			$out = "Hi $Username`n`nValidation failed on the x86 package, and x86 packages are validated on 32-bit OSes. So this might be a 64-bit package."
		}
		'PackageFail' {
			$out = "Hi $Username`n`nThe package installs normally, but fails to run:`n"
		}
		'Paths' {
			$out = 'Please update file name and path to match this change.'
		}
		'PendingAttendedInstaller' {
			$out = "Pending:`n* https://github.com/microsoft/winget-cli/issues/910"
		}
		'Unattended' {
			$out = "Hi $Username`n`nThe installation isn't unattended:`n`nIs there an installer switch to bypass this and have it install automatically?"
		}
		'Unavailable' {
			$out = "Hi $Username`n`nThe installer isn't available from the publisher's website:"
		}
	}
	$out | clip
}

#Clipboard
Function Get-PRNumbers {
	param(
		$out = (Get-Clipboard),
		[switch]$noclip,
		$dashboardPRRegex = '[0-9]{5,6}[:]'
	)
	$out = $out | Select-String $dashboardPRRegex | Sort-Object -Descending
	if ($noclip) {
		$out
	} else {
		$out | clip
	}
}

Function Sort-Clipboard {
	param(
		$out = (Get-Clipboard)
	)
	$out | Sort-Object | clip
}

Function Open-AllURLs {
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -split ' '
	$out = $out | Select-String "`^http"
	$out = $out | Select-String -NotMatch '[.]exe$'
	$out = $out | Select-String -NotMatch '[.]msi$'
	$out = $out | Select-String -NotMatch '[.]zip$'
	$out = $out | Sort-Object -Unique
	$out = $out | ForEach-Object { Start-Process $_ }
}

Function Remove-FileIfExists {
	param(
		$FilePath,
		[switch]$remake
	)
	if (Test-Path $FilePath) { Remove-Item $FilePath -Recurse }
	if ($remake) { mkdir $FilePath }
}

Function Get-YamlValue {
	param(
		[string]$StringName,
		$clip = (Get-Clipboard)
	)
	((($clip | Select-String $StringName) -split ': ')[1] -split '#')[0]
}

Function Test-Admin {
	if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')) { Write-Host 'Try elevating your session.'; break }
}

Function Find-InstallerSets {
	param(
		$clip = (Get-Clipboard),
		$delineator = '- '
	)
	$optionsLine = ($clip | Select-String 'Installers:').LineNumber
	$manifestLine = ($clip | Select-String 'ManifestType:').LineNumber[0] - 2
	$InstallerSection = $clip[$optionsLine..$manifestLIne]
	$setCount = ($InstallerSection | Select-String $delineator).count
	Write-Host "$setCount sets detected:"
	$InstallerSection -split $delineator | ForEach-Object {
		$inputVar = $_
		Write-Host $inputVar

		#Arch, Scope, Locale
		$out = @{};
		$inputVar -split "`n" | ForEach-Object {
			$key, $value = ($_ -split ': ' -replace ' ', '');
			$out[$key] = $value
		}
		$out['ProductCode']
		$out.Remove('')
	}
}
