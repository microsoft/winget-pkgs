#Copyright 2022-2023 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v3.2.2
#Created: 10/19/2022
#Updated: 12/21/2023
#Notes: Utilities to streamline evaluating 3rd party PRs.
#Update log:
#3.2.2 Add silent option to many functions to reduce extraneous console output and better PR Watcher functionality.
#3.2.1 Add automation for processing GitHub diff'd PRs, and improve automation for processing individual files into a manifest.
#3.2.0 Time tracking system.
#3.1.2 Add more validation orchestration functions.
#3.1.1 Numerous improvements to VM build automation.
#3.1.0 Add GitHub functions and relocate other PR tools.
#3.0.0 Add status-based orchestration system. Numerous orchestration bugfixes and upgrades. Remove unused Operation command blocks.

$build = 487
$appName = "Manual Validation" 
Write-Host "$appName build: $build"
$MainFolder = "C:\ManVal"
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.
cd $MainFolder

$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig[($ipconfig | select-string "vEthernet").LineNumber..$ipconfig.length] | select-string "IPv4 Address") -split ": ")[1]).IPAddressToString
$RemoteMainFolder = "//$remoteIP/"
$SharedFolder = "$RemoteMainFolder/write"

$imagesFolder = "$MainFolder\Images" #VM Images folder
$logsFolder = "$MainFolder\logs" #VM Images folder
$runPath = "$MainFolder\vm\" #VM working folder
$writeFolder = "$MainFolder\write" #Folder with write permissions
$vmCounter = "$MainFolder\vmcounter.txt" 
$VMversion = "$MainFolder\VMversion.txt"
$StatusFile = "$writeFolder\status.csv"
$timecardfile = "$logsFolder\timecard.txt"
$TrackerModeFile = "$logsFolder\trackermode.txt"

$CheckpointName = "Validation"
$VMUserName = "user" #Set to the internal username you're using in your VMs.
$SandboxUserName = "WDAGUtilityAccount" #Set to the internal username used in your Sandbox.
$PCUserName = $VMUserName #((whoami) -split "\\")[1]; #Set to your username, or use the commented "whoami" section to autodetect.

$GitHubRateLimitDelay = 0.5 #seconds

#PR tools
Function Get-AutoValLogs {
	#Needs $GitHubToken to be set up in your $PROFILE or somewhere more secure. Needs permissions: workflow, 
	param(
		$clip = (Get-Clipboard),
		#$PR = (($clip -split " " | select-string "[#][0-9]{5,6}" ) -replace "#",""),
		$PR = (($clip -split "/" | select-string "[0-9]{5,6}" )),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		[switch]$CleanoutDirectory,
		[switch]$Whatif,
		[switch]$Force
	)
	#Get-Process *photosapp* | Stop-Process
	$AutoValbuild = ((((iwr "https://dev.azure.com/ms/winget-pkgs/_apis/build/builds?branchName=refs/pull/$PR/merge&api-version=6.0").content | ConvertFrom-Json).value[0]._links.web.href) -split "=")[1]
	if ($AutoValbuild) {
			
		#Write-Host "AutoValbuild: $AutoValbuild"
		#This downloads to Windows default location, which has already been set to $DestinationPath
		start-process "https://dev.azure.com/ms/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$AutoValbuild/artifacts?artifactName=InstallationVerificationLogs&api-version=7.0&%24format=zip"
		sleep 2;
		if (!(Test-Path $ZipPath) -AND !$Force) {
			Write-Host "No logs."
			"No logs." | clip
		}
		Remove-Item $LogPath -Recurse -ErrorAction Ignore
		Expand-Archive $ZipPath -DestinationPath $DestinationPath;
		Remove-Item $ZipPath
		if ($CleanoutDirectory) {
			Get-ChildItem $DestinationPath | Remove-Item -Recurse 
		}
		$UserInput = (
			(gci $LogPath).FullName| %{
			if ($_ -match "png") {Start-Process $_} #Open PNGs with default app.
			Get-Content $_ |Where-Object {
				$_ -match '[[]FAIL[]]' -OR $_ -match 'fail' -OR $_ -match 'error' -OR $_ -match 'exception'}
			}
		) -split "`n" | Select-Object -Unique;
		
		$UserInput = $UserInput -replace "Standard error: ","" 
		if ($UserInput -ne "") {
			Start-Process "https://github.com/microsoft/winget-pkgs/pull/$PR"
			
			#$UserInput = $UserInput -replace "`n","\n"
			$UserInput = ($UserInput -split "`n") -notmatch ' success or error status`: 0'
			$UserInput = ($UserInput -split "`n") -notmatch 'api-ms-win-core-errorhandling'
			$UserInput = ($UserInput -split "`n") -notmatch '``Windows Error Reporting``'
			$UserInput = ($UserInput -split "`n") -notmatch 'The FileSystemWatcher has detected an error '
			$UserInput = $UserInput -replace "2023-","`n> 2023-" 
			$UserInput = $UserInput -replace " MSI ","`n> MSI " 
			$UserInput = $UserInput | Select-Object -Unique
			
			#$UserInput = $UserInput -replace "\n","<br />"
			#$Response.body = "Automatic Validation ended with:\n> $UserInput"
			$UserInput = "Automatic Validation ended with:`n> "+$UserInput
			$UserInput += "`n`n(Automated response - build $build.)"
			
			if ($Whatif) {
				Write-Host "PR: $PR - Whatif: Created"
			} else {
				$out = ReplyTo-PR -PR $PR -Body $UserInput 
				Write-Host "PR: $PR - $out"
			}
		} else {
			Write-Host "PR: $PR - No errors to post."
		}
	} else {
		Write-Host "PR: $PR - No errors to post."
	}
}

Function Invoke-GitHubRequest {
	param(
	[Parameter(mandatory=$true)][string]$Uri,
	[string]$Body = "",
	[ValidateSet("DELETE","GET","HEAD","PATCH","POST","PUT")][string]$Method = "GET",
	$Headers = @{"Authorization"="Bearer $GitHubToken"; "Accept"="application/vnd.github+json"; "X-GitHub-Api-Version"="2022-11-28"},
	[switch]$JSON
	)
	if ($Body) {
		$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body)
	} else {
		$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers)
	}
	#GitHub requires the value be the .body property of the variable. This makes more sense with CURL, where this is the -data parameter. However with Invoke-WebRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.
	if ($JSON) {
		$out.content | ConvertFrom-Json
	} else {
		$out
	}
}

Function Add-GitHubReview{
	param(
		$PR,
		[string]$Body = ""
	)
	$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/commits -JSON
	$commit = ($prData.commit.url -split "/")[-1]
	$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winget-pkgs/commits/$commit -JSON
	$position = ($commitData.files -split "`n" | Select-String "Architecture:" ).LineNumber -1
	$position
	$path = "manifests/a/Adamant/Messenger/4.3.1/Adamant.Messenger.locale.en-US.yaml"

	#$Response = @{}
	#$Response.body = $Body

	#$Response = @{"commit_id"="$commit";"body"="$Body";"event"="REQUEST_CHANGES";"comments"=""}
	#$Response.comments = @()
	#$Response.comments[0] = @["path"="$path";"position"="$position";"body"="``````suggestion\nArchitecture= x64\n``````."]
	#[string]$Body = $Response | ConvertTo-Json
	[string]$Body = '{"commit_id":"'+$commit+'","body":"","event":"REQUEST_CHANGES","comments":[{"path":"'+$path+'","position":'+$position+',"body":"```suggestion\nArchitecture: x64\n```."}]}'

	$body
	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/reviews"

	#Write-Host $Response.body
	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body

	$out.StatusDescription
	sleep $GitHubRateLimitDelay;
}

Function Approve-PR {
	param(
		$PR,
		[string]$Body = ""
	)

	$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/commits -JSON
	$commit = ($prData.commit.url -split "/")[-1]
	
	$Response = @{}
	$Response.body = $Body
	$Response.commit = $commit
	$Response.event = "APPROVE"
	[string]$Body = $Response | ConvertTo-Json

	#Write-Host $Response.body
	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/reviews"
	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body

	$out.StatusDescription
	sleep $GitHubRateLimitDelay;
}

Function Add-PRLabel {
	param(
		$PR,
		[string]$Label = "Needs-Author-Feedback",
		[ValidateSet("DELETE","POST","PUT")][string]$Method = "POST"
	)

	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/issues/$pr/labels"
	#$prData = Invoke-GitHubRequest $uri -JSON
	
	$Response = @{}
	#$Response.labels = $prData.name
	$Response.labels = @()
	$Response.labels += $Label
	[string]$Body = $Response | ConvertTo-Json

	#Write-Host $Response.body
	$out = Invoke-GitHubRequest -Method $Method -Uri $uri -Body $Body

	$out.StatusDescription
	sleep $GitHubRateLimitDelay;
}

Function Update-PR {
	param(
		$PR,
		[string]$Title = "",
		[string]$Body = "",
		[ValidateSet("open","closed")][string]$State = "open"
	)

	$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/commits -JSON
	$commit = ($prData.commit.url -split "/")[-1]
	
	#{"title":"new title","body":"updated body","state":"open","base":"master"}'
	$Response = @{}
	$Response.title = $Title
	$Response.body = $Body
	$Response.state = $State
	$Response.base = "master"
	[string]$Body = $Response | ConvertTo-Json
	Write-Host $Body
	Write-Host $Response.body
	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/update-branch"

	$out = Invoke-GitHubRequest -Uri $uri -Method Post -Body $Body
	$out.StatusDescription
	sleep $GitHubRateLimitDelay;
}

Function ReplyTo-PR {
	param(
		$PR,
		[string]$Body,
		[Switch]$Silent
	)
	$Response = @{}
	$Response.body = $Body
	[string]$Body = $Response | ConvertTo-Json

	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/issues/$PR/comments" 
	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body
	if (!($Silent)) {
		$out.StatusDescription -join ""
	}
	sleep $GitHubRateLimitDelay;
}

Function Add-UserToPR {
	param(
		$PR,
		[array]$Body,
		[Switch]$Remove,
		[Switch]$Silent
	)
	$Response = @{}
	$Response.assignees = $Body
	[string]$Body = $Response | ConvertTo-Json

	$Method = "Post"
	if ($Remove) {
		$Method = "Delete"
	}

	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/issues/$PR/assignees" 
	$out = Invoke-GitHubRequest -Method $Method -Uri $uri -Body $Body
	if (!($Silent)) {
		$out.StatusDescription -join ""
	}
	sleep $GitHubRateLimitDelay;
}

Function Convert-ImageToBase64Link {
	param(
		$FileName = "C:\ManVal\misc\forbidden.png"
	)
	[String]$base64 = [convert]::ToBase64String((Get-Content $FileName -AsByteStream -Raw))
	$Ext = ($FileName -split "[.]")[1]
	return "<img src=`"data:image/$Ext;base64, $base64`" />"
}

#Package validation
Function Validate-Package {
	param(
		#[Parameter(mandatory=$true)]
		$out = ((Get-Clipboard) -split "`n"),
		[ValidateSet("Win10","Win11")][string]$OS = (Get-OSFromVersion),
		[int]$vm = ((Get-NextFreeVM -OS $OS) -replace"vm",""),
		#$out = ((Get-SecondMatch) -split "`n"),
		[switch]$NoFiles,
		[ValidateSet("Config","DevHomeConfig","Pin","Scan")][string]$Operation = "Scan",
		[switch]$InspectNew,
		[switch]$notElevated,
		$ManualDependency,
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $out) -replace '"',''-replace "'",''),
		$PackageVersion = ((Get-YamlValue -StringName "PackageVersion" $out) -replace '"',''-replace "'",''),
		[int]$PR = (Get-JustPRNumbers $out),
		$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		$installerLine = "--manifest $RemoteFolder/manifest",
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")][string]$Arch,
		[ValidateSet("User","Machine")][string]$Scope,
		#[ValidateSet("de-DE","en-US","es-ES","fr-FR","it-IT","ja-JP","ko-KR","pt-BR","ru-RU","zh-CN","zh-HK","zh-TW")]
		[string]$Locale,
		[switch]$Silent,
		$vmStatusFile = "$RemoteFolder\$vm.txt",
		$optionsLine = ""
	)
	Test-Admin
	if ($vm -eq 0){
		Write-Host "No available $OS VMs";
		Generate-PipelineVm -OS $OS;
		#Break;
		}
	if ($Silent) {
		Set-Status "Prevalidation" $vm $PackageIdentifier $PR -Silent
	} else {
		Set-Status "Prevalidation" $vm $PackageIdentifier $PR
	}
	if ((Get-VM "vm$vm").state -ne "Running") {Start-VM "vm$vm"}
	if ($PackageIdentifier -eq "") {
		Write-Host "Bad PackageIdentifier: $PackageIdentifier"
		#Break;
		$PackageIdentifier | clip
	}
	if (!($Silent)) {
		Write-Host "Running Manual Validation build $build on vm$vm for package $PackageIdentifier version $PackageVersion"
	}

	$logLine = "$OS "
	$nonElevatedShell = ""
	$logExt = "log"
	$VMFolder = "$MainFolder\vm\$vm"
	$manifestFolder = "$VMFolder\manifest"
	$CmdsFileName = "$VMFolder\cmds.ps1"

	if ($PackageVersion) {
		$logExt = $PackageVersion+"."+$logExt
		$logLine += "version $PackageVersion "
	}
	if ($Locale) {
		$logExt = $Locale+"."+$logExt
		$optionsLine += " --locale $Locale "
		$logLine += "locale $Locale "
	}
	if ($Scope) {
		$logExt = $Scope+"."+$logExt
		$optionsLine += " --scope $Scope "
		$logLine += "scope $Scope "
	}
	$Archs = ($out | Select-String -notmatch "arm"| select-string "Architecture: " )|%{($_ -split ": ")[1]} 	
	$archDetect = ""	
	$archColor = "yellow"
	if ($Archs) {
		if ($Archs[0].length -ge 2) {
			if ($Arch) {
				$archDetect = "Selected"
			} else {
				$Arch = $Archs[0]
				$archDetect = "Detected"
			}
			$otherArch = $Archs | select-string -notmatch $Arch
			$archColor = "red"
		} else {
			if ($Archs -eq "neutral") {
				$archColor = "yellow"
			} else {
			$Arch = $Archs
			$archDetect = "Detected"
			$archColor = "green"
			}
		}
	}
	if ($Arch) {
		$logExt = $Arch+"."+$logExt
		if (!($Silent)) {
			Write-Host "$archDetect Arch $Arch of available architectures: $Archs" -f $archColor
		}
		#$optionsLine += " --architecture $Arch "
		$logLine += "$Arch "
	}
<#Automatic manual dependency support to preinstall dependencies when dependencies are not supported, for more complete testing confirmation. 
	if (!$ManualDependency) {
		$ManualDependency = try {($out[($out | Select-String "PackageDependencies:").LineNumber] -split ": ")[1]}catch{}
	}
 #>
	$MDLog = ""
	if ($ManualDependency) {
		$MDLog = $ManualDependency
		if (!($Silent)) {
			Write-Host " = = = = Installing manual dependency $ManualDependency  = = = = "
		}
		[string]$ManualDependency = "Out-Log 'Installing manual dependency $ManualDependency.';Start-Process 'winget' 'install "+$ManualDependency+"  --accept-package-agreements --ignore-local-archive-malware-scan' -wait`n"
	}
	if ($notElevated -OR ($out | Select-String "ElevationRequirement: elevationProhibited")) {
		if (!($Silent)) {
			Write-Host " = = = = Detecting de-elevation requirement = = = = "
		}
		$nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\Program Files\PowerShell\7\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}"
		#If elevated, run^^ and exit, else run cmds.
	}
$packageDeveloper = ($PackageIdentifier -split "[.]")[0]
$packageName = ($PackageIdentifier -split "[.]")[1]

$cmdsOut = ""

switch ($Operation) {
"Scan" {
$cmdsOut = "$nonElevatedShell
`$TimeStart = Get-Date;
`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
	`$TimeStamp = (Get-Date -Format T) + ': ';
	`$logEntry = `$TimeStamp + `$logData
	Write-Host `$logEntry  -f `$logColor;
	md `$ManValLogFolder -ErrorAction Ignore
	`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append -Encoding unicode
};
Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
	Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
	`$errArray | %{Out-Log `$_ 'red'}
};
Set-Status 'Installing'
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

Out-Log 'Pre-testing log cleanup.'
Out-Log 'Upgrading installed applications.'
Out-Log (`$null = (WinGet upgrade --all --include-pinned --disable-interactivity))
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
Set-Status 'ValidationComplete' 
	Break;
} 
#Read-Host 'Install complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install. 

Set-Status 'Scanning' 

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
`$files = `$files | where {`$_ -notmatch 'unins'} | where {`$_ -notmatch 'dotnet'} | where {`$_ -notmatch 'redis'} | where {`$_ -notmatch 'System32'} | where {`$_ -notmatch 'SysWOW64'} | where {`$_ -notmatch 'WinSxS'} | where {`$_ -notmatch 'dump64a'} | where {`$_ -notmatch 'CbsTemp'} 
`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'  
`$files | select-string '[.]exe`$' | %{if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | select-string '[.]msi`$' | %{if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | select-string '[.]lnk`$' | %{if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};

Out-Log `" = = = = End file list. Starting Defender scan.`"
Start-MpScan;

Out-Log `"Defender scan complete, closing windows...`"
(get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell'  -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'})| %{
	`$process = (Stop-Process `$_ -PassThru);
	Out-Log `"`$(`$process.processname) finished with exit code: `$(`$process.ExitCode)`";
}

Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | %{Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'
Out-ErrorData (Get-MPThreat).ThreatName `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Set-Status 'ValidationComplete'
"
	}
	Default {
		Write-Host "Error: Bad Function"
		Break;
	}
	}

		$cmdsOut | Out-File $CmdsFileName

	if ($NoFiles -eq $False) {
		#Extract multi-part manifest from clipboard and write to disk
		if (!($Silent)) {
			Write-Host "Removing previous manifest and adding current..."
		}
		Remove-FileIfExists "$manifestFolder"  -remake -Silent
		$Files = @()
		$Files += "Package.installer.yaml"
		$FileNames = ($out | select-string "[.]yaml") |%{($_ -split "/")[-1]}
		$replace = $FileNames[-1] -replace ".yaml"
		$FileNames | %{
			$Files += $_ -replace $replace,"Package"
		}
		$out = $out -join "`n" -split "@@"
		for ($i=0;$i -lt $Files.length;$i++) {
			$File = $Files[$i]
			$inputObj = $out[$i*2] -split "`n" 
			$inputObj = $inputObj[1..(($inputObj| Select-String "ManifestVersion" -SimpleMatch).LineNumber -1)] | where {$_ -notmatch "marked this conversation as resolved."}
			$FilePath = "$manifestFolder\$File"
			if (!($Silent)) {
				Write-Host "Writing $($inputObj.length) lines to $FilePath"
			}
			Out-File -FilePath $FilePath -InputObject $inputObj
			#Bugfix to catch package identifier appended to last line of last file.
			$fileContents = (Get-Content $FilePath)
			if ($fileContents[-1] -match $PackageIdentifier) {
				$fileContents[-1]=($fileContents[-1] -split $PackageIdentifier)[0]
			}
			$fileContents -replace "0New version: ","0" -replace "0New package: ","0" -replace "0Add version: ","0" -replace "0Add package: ","0" -replace "0Add ","0" -replace "0New ","0" -replace "0package:  ","0" | Out-File $FilePath
		}
		$filecount = (ls $manifestFolder).count
		$filedir = "ok"
		$filecolor = "green"
		if ($filecount -lt 3) { $filedir = "too low"; $filecolor = "red"}
		if ($filecount -gt 3) { $filedir = "high"; $filecolor = "yellow"}
		if ($filecount -gt 10) { $filedir = "too high"; $filecolor = "red"}
		if (!($Silent)) {
			Write-Host -f $filecolor "File count $filecount is $filedir"
		}
		if ($filecount -lt 3) { break}
		Check-ManifestFile $vm -Silent;
	}#end if NoFiles
	
	if ($InspectNew) {
		$PackageResult = Find-WinGetPackage $PackageIdentifier
		if (!($Silent)) {
			Write-Host "Searching Winget for $PackageIdentifier"
		}
		Write-Host $PackageResult
		if ($PackageResult -eq "No package found matching input criteria.") {
			Open-AllURLs
			Start-Process "https://www.bing.com/search?q=$PackageIdentifier"
			$a,$b = $PackageIdentifier -split "[.]"
			if ($a -ne "") {
				if (!($Silent)) {
					Write-Host "Searching Winget for $a"
				}
				Find-WinGetPackage $a
			}
			if ($b -ne "") {
				if (!($Silent)) {
					Write-Host "Searching Winget for $b"
				}
				Find-WinGetPackage $b
			}
		}
	}
	if (!($Silent)) {
		Write-Host "File operations complete, starting VM operations."
	}
	Revert-VM $vm -Silent
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
	$PackageIdentifier = "Microsoft.Devhome",
	$ManualDependency = "Git.Git"
	)

	Validate-Package -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles -ManualDependency $ManualDependency -Operation "DevHomeConfig"
	sleep 2
	Validate-Package -installerLine "--id $ManualDependency" -PackageIdentifier $ManualDependency -NoFiles -Operation "Config"
}

Function Validate-PackageByArch {
	param(
	)
	Validate-Package -Arch x64;
	sleep 2; 
	Validate-Package -Arch x86
}

Function Validate-PackageByScope {
	param(
	)
	Validate-Package -Scope Machine;
	sleep 2; 
	Validate-Package -Scope User
}

Function Get-ManifestAutomation {
	param(
		$vm =(Get-NextFreeVM),
		$Arch,
		$OS,
		$Scope
	)

	#Read-Host "Copy Installer file to clipboard, then press Enter to continue." 
	(Get-Clipboard) -join "" | clip;
	Get-ManifestFile $vm
	
	Read-Host "Copy defaultLocale file to clipboard, then press Enter to continue." 
	(Get-Clipboard) -join "" | clip;
	Get-ManifestFile $vm

	Read-Host "Copy version file to clipboard, then press Enter to continue." 
	(Get-Clipboard) -join "" | clip;
	if ($Arch) {
		Get-ManifestFile $vm -Arch $Arch
	} elseif ($OS) {
		Get-ManifestFile $vm -OS $OS
	} elseif ($Scope) {
		Get-ManifestFile $vm -Scope $Scope
	} else {
		Get-ManifestFile $vm 
	}
}

#VM Management
Function Complete-TrackerVM {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMFolder = "$MainFolder\vm\$vm",
		$filesFileName = "$VMFolder\files.txt",
		[switch]$Reset
	)
	Test-Admin
	Set-Status "Completing" $vm
	Stop-Process -id ((Get-ConnectedVMs)|where {$_.VM -match "vm$vm"}).id -ErrorAction Ignore
	Stop-TrackerVM $vm
	Remove-FileIfExists $filesFileName
	Set-Status "Ready" $vm " " 1
}

Function Generate-PipelineVm {
	param(
		[int]$vm = (Get-Content $vmCounter),
		[int]$version = (Get-TrackerVMversion),
		[ValidateSet("Win10","Win11")][string]$OS = "Win10",
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$newVmName = "vm$vm",
		$startTime = (Get-Date)
	)
	Test-Admin
	Write-Host "Creating VM $newVmName version $version OS $OS"
	[int]$vm+1|Out-File $vmCounter
	"`"$vm`",`"Generating`",`"$version`",`"$OS`",`"`",`"1`",`"0`""|Out-File $StatusFile -Append -Encoding unicode
	Remove-FileIfExists $destinationPath -remake
	Remove-FileIfExists $VMFolder -remake
	$vmImageFolder = ""

	switch ($OS) {
		"Win10" {
			$vmImageFolder = "$imagesFolder\Win10-image\Virtual Machines\0CF98E8A-73BB-4E33-ABA6-7513F376407D.vmcx"
		}
		"Win11" {
			$vmImageFolder = "$imagesFolder\Win11-image\Virtual Machines\C911D03D-5385-41D3-B753-69228E3C7187.vmcx"
		}
	}

	Write-Host "Takes about 120 seconds..."
	Import-VM -Path $vmImageFolder -Copy -GenerateNewId -VhdDestinationPath $destinationPath -VirtualMachinePath $destinationPath;
	Rename-VM (Get-VM | where {($_.CheckpointFileLocation)+"\" -eq $destinationPath}) -NewName $newVmName
	Start-VM $newVmName
	Remove-VMCheckpoint -VMName $newVmName -Name "Backup"
	Revert-VM $vm
	Launch-VMTrackerWindow $vm
	Write-Host "Took $(((get-date)-$startTime).TotalSeconds) seconds..."
}

Function Disgenerate-PipelineVm {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = "vm$vm"
	)
	Test-Admin
	Set-Status 'Disgenerate' $vm
	Stop-TrackerVM $vm
	Remove-VM -Name $vmName -Force

	$out = Get-Status
	$out = $out | where {$_.vm -notmatch $VM}
	Write-Status $out 

	$delay = 15
	0..$delay | %{
		$pct = $_ / $delay * 100
		Write-Progress -Activity "Remove VM" -Status "$_ of $delay" -PercentComplete $pct
		sleep $GitHubRateLimitDelay
	}
	Remove-FileIfExists $destinationPath
	Remove-FileIfExists $VMFolder
}

Function Start-ImageVM {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
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
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$vm = 0
	$OriginalLoc = ""
	switch ($OS) {
		"Win10" {
			$OriginalLoc = "$imagesFolder\Win10-Created061623-SecondFolder"
		}
		"Win11" {
			$OriginalLoc = "$imagesFolder\Win11-Created030623-Original\"
		}
	}
	$ImageLoc = "$imagesFolder\$OS-image\"
	[int]$version = [int](Get-TrackerVMVersion) + 1
	Write-Host "Writing $OS version $version"
	Set-TrackerVMVersion $version
	Stop-Process -id ((Get-ConnectedVMs)|where {$_.VM -match "$OS"}).id -ErrorAction Ignore
	Redo-Checkpoint $vm $OS;
	Stop-TrackerVM $vm $OS;
	Write-Host "Letting VM cool..."
	sleep $GitHubRateLimitDelay;
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
	rm folder $prFolder
	git commit
	start-process $gitUrl
	Write-Host "go make PR on GitHub"
}

Function Sum-Array {
	param(
		$in = 0,
		$out = 0
	)
	$in |%{$out += $_*1}
	$out
}

#VM Orchestration
Function Run-StatusTracker {
	$openPrReview = $false
	while ($true) {
		#$StuckVMs = (diff (Get-Status | where {$_.status -eq "ValidationComplete"}).vm ((Get-ConnectedVMs).vm -replace "vm","")).inputobject
		#Foreach ($vm in $StuckVMs) {
			#Set-Status Complete $vm
		#}
		cls
		$GetStatus = Get-Status
		$GetStatus | ft;
		$VMRAM = Sum-Array $GetStatus.RAM
		$ramColor = "green"
		if ($VMRAM -gt 16) {
			$ramColor = "red"
		} elseif ($VMRAM -gt 8) {
			$ramColor = "yellow"
		}  
		Write-Host "VM RAM Total: " -nonewline
		Write-Host -f $ramColor $VMRAM
		$timeClockColor = "red"
		if (Get-TimeRunning) {$timeClockColor = "green"}
		Write-Host -nonewline "Build: $build - Hours worked: "
		Write-Host -f $timeClockColor (Get-HoursWorkedToday)
		Check-TrackerVMMem;
		Get-TrackerVMRAM;
		Cycle-VMs;
		
		$clip = (Get-Clipboard)
		If ($clip -match  "https://dev.azure.com/ms/") {
			Write-Host "Gathering Automated Validation Logs"
			Get-AutoValLogs
		} elseIf ($clip -match  "Skip to content") {
			$valMode = Get-TrackerMode
			if ($valMode -eq "Validating") {

				Write-Host $valMode
				Validate-Package;
				$valMode | clip
			#} elseif ($valMode -eq "Approving") {
				#Set-TrackerMode "Validating"
			} 
		} elseIf ($clip -match  " Windows Package Manager") {
			Write-Host "Gathering PR Headings"
			Get-PRNumbers
		} elseIf ($clip -match  "^manifests`/") {
			Write-Host "Opening manifest file"
			$ManifestUrl = "https://github.com/microsoft/winget-pkgs/tree/master/"+$clip
			$ManifestUrl | clip
			start-process ($ManifestUrl)
		} 
		if (!(Get-ConnectedVMs)) {
			Reset-Status
			Rotate-TrackerVMs
		}
		sleep 5;
	}
}

Function Cycle-VMs {
	param(
		[int]$Validate
	)
	#Get-Content $File | %{& [scriptblock]::Create($Command+" "+$vm)
	$VMs = Get-Status
	Foreach ($VM in $VMs) {
		Switch ($VM.status) {
			"AddVCRedist" {
				Add-ValidationData $VM.vm
			}
			"Approved" {
				Approve-PR $VM.PR
				Set-Status "Complete" $VM.vm
			}
			"CheckpointReady" {
				Redo-Checkpoint $VM.vm
			}
			"Complete" {
				Complete-TrackerVM $VM.vm
			}
			"Disgenerate" {
				Disgenerate-PipelineVm $VM.vm
			}
			"Revert" {
				Revert-VM $VM.vm
			}
			"Regenerate" {
				Disgenerate-PipelineVm $VM.vm
				Generate-PipelineVm -OS $VM.os
			}
			"SendStatus" {
				ReplyTo-PR $VM.PR (Get-CannedResponse ManValEnd (Get-SharedError -NoClip) -NoClip)
				Set-Status "Complete" $VM.vm
			}
			default {
				#Write-Host "Complete"
			}
		}; #end switch
	}
}

Function Set-Status {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
		$Status = "Complete",
		[Parameter(mandatory=$true)]$VM,
		[string]$Package,
		[int]$PR,
		[Switch]$Silent
	)
	$out = Get-Status
	if ($Status) {
		($out | where {$_.vm -match $VM}).Status = $Status
	}
	if ($Package) {
		($out | where {$_.vm -match $VM}).Package = $Package
	}
	if ($PR) {
		($out | where {$_.vm -match $VM}).PR = $PR
	}
	if ($Silent) {
		Write-Status $out -Silent
	} else {
		Write-Status $out
		Write-Host "Setting $vm $Package $PR state $Status"
	}
}

Function Write-Status {
	Param(
		$out,
		[Switch]$Silent
	)
	if (!($Silent)) {
		Write-Host "Writing $($out.length) lines to $StatusFile."
	}
	$out | ConvertTo-Csv | Out-File $StatusFile -Encoding unicode
}

Function Get-Status{
	param(
		[int]$vm,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
		$Status,
		[ValidateSet("Win10","Win11")][string]$OS,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv)
	)
	if ($OS) {
		$out = ($out | where {$_.OS -eq $OS})
	}
	if ($vm) {
		$out = ($out | where {$_.vm -eq $vm}).status
	}
	if ($Status) {
		$out = ($out | where {$_.version -eq (Get-TrackerVMVersion)}| where {$_.status -eq $Status}).vm	
	}
	$out 
}

Function Reset-Status {
	if (!(Get-ConnectedVMs)){
		$VMs = (Get-Status | where {$_.status -ne "Ready"}).vm
		Foreach ($VM in $VMs) {Set-Status Complete $VM}
		Get-Process *vmwp* | Stop-Process
	}
}

Function Rebuild-Status {
	$Status = Get-VM | where {$_.name -notmatch "vm0"}|
	select @{n="vm";e={$_.name}},
	@{n="status";e={"Ready"}},
	@{n="version";e={60}},
	@{n="OS";e={"Win10"}},
	@{n="Package";e={""}},
	@{n="PR";e={"1"}},
	@{n="RAM";e={"0"}}
	Write-Status $Status
}

Function Get-TrackerMode {
	param(
		$mode = (gc $TrackerModeFile)
	)
	$mode
}

Function Set-TrackerMode {
	param(
		[ValidateSet("Validating","Approving","Idle")]
		$Status = "Validating"
	)
	$Status | out-file $TrackerModeFile
}

Function Check-TrackerVMMem {
	Param(
		$VMs = (get-vm)
	)
	$VMs | %{
		if(($_.MemoryDemand / $_.MemoryMaximum) -ge 0.9){
			set-vm -VMName $_.name -MemoryMaximumBytes "$(($_.MemoryMaximum / 1073741824)+2)GB"
		}
	}
}

Function Get-SharedError {
	param(
		$out = ((Get-Content "$writeFolder\err.txt") -replace "Faulting","`n> Faulting" -replace "2023","`n> 2023"),
		[switch]$NoClip
	)
	if ($NoClip) {
		$out
	} else {
		$out | clip
	}
}

Function Get-ConnectedVMs {
	Test-Admin
	(Get-Process *vmconnect*) | select id, @{n="VM";e={%{$_.mainwindowtitle[0..4] -join ""}}}
}

Function Get-NextFreeVM {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	try {
		Get-Status -OS $OS -Status Ready |Get-Random -ErrorAction SilentlyContinue
	} catch {
		Write-Host "No available $OS VMs"
		return 0
	}
}

Function Get-ExistingVMs {
	Test-Admin
	(Get-VM).name |select-string -notmatch "Win"
}

Function Get-TrackerVMRAM {
	$status = Get-Status
	$status |% {$_.RAM = [math]::Round((Get-VM -Name ("vm"+$_.vm)).MemoryAssigned/1024/1024/1024,2)}
	Write-Status $status 
}

Function Launch-VMTrackerWindow {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-ConnectedVMs | where {$_.vm -match $VMName} | %{Stop-Process -id $_.id}
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Redo-Checkpoint {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Set-Status "Checkpointing" $vm
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Set-Status "Complete" $vm
}

Function Revert-VM {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm",
		[Switch]$Silent
	)
	Test-Admin
	if ($Silent) {
		Set-Status "Restoring" $vm -Silent
	} else {
		Set-Status "Restoring" $vm
	}
	Restore-VMCheckpoint -Name $CheckpointName -VMName $VMName -Confirm:$false
}

Function Get-OSFromVersion {
	try{
		if ([system.version](Get-YamlValue -StringName MinimumOSVersion) -ge [system.version]"10.0.22000.0"){"Win11"}else{"Win10"}
	} catch {
		"Win10"
	}
}

Function Get-TrackerVMVersion {[int](gc $VMversion)}

Function Set-TrackerVMVersion {param([int]$Version) $Version|out-file $VMversion}

Function Remove-LesserVMs {
	(Get-Status | where {
		$_.version -lt (Get-TrackerVMVersion)
	}).vm |%{
		Set-Status Disgenerate $_
	}
}

Function Rotate-TrackerVMs {
	$status = Get-Status
	$VMs = $status | where {$_.version -lt (Get-TrackerVMVersion)}
	if ($VMs){
		if (!(($status | where {$_.status -ne "Ready"}).count)) {
			Set-Status Regenerate ($VMs.VM | Get-Random)
		}
	}
}

Function Stop-TrackerVM {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

#File Management
Function Get-ManifestFile {
	param(
		#[Parameter(mandatory=$true)]
		[int]$vm = ((Get-NextFreeVM) -replace "vm",""),
		[Switch]$Installer,
		$clip = (Get-SecondMatch),
		$FileName = "Package",
		$Arch,
		$OS,
		$Scope
	);
	$manifestFolder = "$MainFolder\vm\$vm\manifest"
	$clip = $clip | where {$_ -notmatch "marked this conversation as resolved."}


<#
	if (!(test-path "$manifestFolder")){md "$manifestFolder"}

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
		"defaultLocale" {
			$Locale = (Get-YamlValue PackageLocale $clip)
			$FileName = "$FileName.locale.$Locale"
		} 
		"Locale" {
			$Locale = (Get-YamlValue PackageLocale $clip)
			$FileName = "$FileName.locale.$Locale"
		} 
		"installer" {
			Remove-FileIfExists "$manifestFolder"  -remake
			$FileName = "$FileName.installer"
		} 
		"version" {
			if ($Arch) {
				Validate-Package -vm $vm -NoFiles -Arch $Arch -PR 0 
			} elseif ($OS) {
				Validate-Package -vm $vm -NoFiles -OS $OS  -PR 0 
			} elseif ($Scope) {
				Validate-Package -vm $vm -NoFiles -Scope $Scope  -PR 0 
			} else {
				Validate-Package -vm $vm -NoFiles  -PR 0 
			}
		} 
		Default {
			Write-Host "Error: Bad ManifestType"
			Write-Host $clip
		}
	}
	$FilePath = "$manifestFolder\$FileName.yaml"
	Write-Host "Writing $($clip.length) lines to $FilePath"
	$clip -replace "0New version: ","0" -replace "0Add version: ","0" -replace "0Add ","0" -replace "0New ","0" | Out-File $FilePath
}

Function Get-SecondMatch {
	param(
		$clip = (Get-Clipboard),
		$depth = 1
	)
	#If $current and $prev don't match, return the $prev element, which is $depth lines below the $current line. Start at $clip[$depth] and go until the end - this starts $current at $clip[$depth], and $prev gets moved backwards to $clip[0] and moves through until $current is at the end of the array, $clip[$clip.length], and $prev is $depth previous, at $clip[$clip.length - $depth]. 
	for ($depthUnit = $depth;$depthUnit -lt $clip.length; $depthUnit++){
		$current = ($clip[$depthUnit] -split ": ")[0]
		$prevUnit = $clip[$depthUnit - $depth]
		$prev = ($prevUnit -split ": ")[0]
		if ($current -ne $prev) {
			$prevUnit
		}
	}
	#Then complete the last $depth items of the array by starting at $clip[-$depth] and work backwards through the last items in reverse order to $clip[-1].
	for ($depthUnit = $depth ;$depthUnit -gt 0; $depthUnit--){
		$clip[-$depthUnit]
	}
}

Function Test-Hash {
	param(
		$FileName,
		$hashVar=(Get-Clipboard),
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
			Write-Host $out -foregroundcolor green
		}
		$false {
			Write-Host $out -foregroundcolor red
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
		[Parameter(mandatory=$true)][int]$vm,
		$filePath = "$runPath\$vm\manifest\Package.yaml",
		[Switch]$Silent
	)
	$fileContents = gc $filePath
	if ($fileContents[-1] -ne "0") {
		$fileContents[-1] = ($fileContents[-1] -split ".0")[0]+".0"
		if (!($Silent)){
			Write-Host "Writing $($fileContents.length) lines to $filePath"
		}
		$fileContents | out-file $filePath
	}
}

Function Rotate-TrackerVMLogs {
	$logYesterDate = (get-date -f dd) - 1
	Move-Item "$writeFolder\logs\$logYesterDate" "$logsFolder\$logYesterDate"
}

#Inject dependencies
Function Add-ValidationData {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$Data = 'Microsoft.VCRedist.2015+.x64',
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest",
		$FilePath = "$manifestFolder\Package.installer.yaml",
		$fileContents = (Get-Content $FilePath),
		$Selector = "Installers:",
		$offset = 1,
		#[switch]$Force,
		$lineNo = (($fileContents| Select-String $Selector -List).LineNumber -$offset),
		$fileInsert = "Dependencies:`n  PackageDependencies:`n    - PackageIdentifier: $Data",
		$fileOutput = ($fileContents[0..($lineNo -1)]+$fileInsert+$fileContents[$lineNo..($fileContents.length)])
	)
	#This is an example of a "sideways wrapper". Bubble all parameters up 1 line as variables. Bubble all variables as high as possible in the function. Bubble variables at the top into parameters. Watch all the flexibility that unlocks.
	#if ($Force) {
		Write-Host "Writing $($fileContents.length) lines to $FilePath"
		Out-File -FilePath $FilePath -InputObject $fileOutput 
		Set-Status "Revert" $VM;
	#} else {
		#Write-Host "We don't support dependencies. You may be looking for: `n $fileInsert"
	#}
}

Function Add-InstallerSwitch {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$Data = '/qn',
		$Selector = "ManifestType:",
		[ValidateSet("EXE","MSI","MSIX","Inno","Nullsoft","InstallShield")]
		[string]$InstallerType
		
	)
	switch ($InstallerType) {
		"MSIX"{
		$Data = '/quiet'
		}
		"Inno"{
		$Data = '/SILENT'
		}
		"Nullsoft"{
		$Data = '/S'
		}
		"InstallShield"{
		$Data = '/s' #or -s
		}
	}
	$fileInsert = "  InstallerSwitches:`n    Silent: $Data"
	Add-ValidationData $vm -Data $Data -Selector $Selector -fileInsert $fileInsert #-Force
}

#@wingetbot waivers 
Function Get-CannedResponse {
	param(
		[ValidateSet("AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","Drivers","DefenderFail","EULA","GenevaValPipe","GenevaWingetbotMention","HashFailRegen","IcMValidationEphemeral","IcMValidationEvery","IcMValidationFirst","IcMValidationStale","IcMWaiverCommit","InstallerFail","InstallerNotUnattended","InstallerUrlBad","ManValEnd","NoCause","NoExe","NoRecentActivity","NotGoodFit","Only64bit","PackageFail","Paths","PendingAttendedInstaller","Unattended","Unavailable","UrlBad")]
		[string]$Response,
		$UserInput=(Get-Clipboard),
		$Dependency64 = "Microsoft.VCRedist.2015+.x64",
		$Dependency32 = "Microsoft.VCRedist.2015+.x86",
		[int]$TruncateAfterLine=10,
		[switch]$NoClip
	)
	[string]$Username = "@"+$UserInput.replace(" ","")+","
	switch ($Response) {
		"AppsAndFeaturesNew" {
			$out = "Hi $Username`n`nThis manifest adds Apps and Features entries that aren't present in previous PR versions. Should these entries be added to the previous versions also?"
		}
		"AppsAndFeaturesMissing" {
			$out = "Hi $Username`n`nThis manifest removes Apps and Features entries that are present in previous PR versions. Should these entries be added to this version also?"
		}
		"AppFail" {
			$out = "Hi $Username`n`nThe application installed normally, but gave an error instead of launching:`n"
		}
		"Approve" {
			$out = "Hi $Username`n`nDo you approve of these changes?"
		}
		"AutomationBlock" {
			$out = "This might be due to a network block of data centers, to prevent automated downloads."
		}
		"UserAgentBlock" {
			$out = "This might be due to user-agent throttling."
		}
		"AutoValEnd" {
			$out = "Automatic Validation ended with:`n> $UserInput"
		}
		"Drivers" {
			$out = "Hi $Username`n`nThe installation is unattended, but installs a driver which isn't unattended:`n`Unfortunately, installer switches are not usually provided for this situation. Are you aware of an installer switch to have the driver silently install as well?"
		}
		"DefenderFail" {
			$out = "Hi $Username`n`nThe package didn't pass a Defender or similar security scan. This might be a false positive and we can rescan tomorrow."
		}
		"EULA" {
			$out = "Hi $Username`n`nThe installation isn't unattended It requires the user to accept an EULA:`n`nIs there an installer switch to accept this and have it install automatically?"
		}
		"HashFailRegen" {
			$out = "Closing to regenerate with correct hash."
		}
		"InstallerFail" {
			$out = "Hi $Username`n`nThe installer did not complete:`n"
		}
		"InstallerNotUnattended" {
			$out = "Pending:`n* https://github.com/microsoft/winget-cli/issues/910"
		}
		"UrlBad" {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
		}
		"ManValEnd" {
			$out = "Manual Validation ended with:`n> $UserInput"
		}
		"NoCause" {
			$out = "I'm not able to find the cause for this error. It installs and runs normally on a Windows 10 VM."
		}
		"NoExe" {
			$out = "Hi $Username`n`nThe installer doesn't appear to install any executables, only supporting files:`n`nIs this expected?"
		}
		"NoRecentActivity" {
			$out = "No recent activity."
		}
		"NotGoodFit" {
			$out = "Hi $Username`n`nUnfortunately, this package might not be a good fit for inclusion into the WinGet public manifests. Please consider using a local manifest (`WinGet install --manifest C:\path\to\manifest\files\`) for local installations. "
		}
		"Only64bit" {
			$out = "Hi $Username`n`nValidation failed on the x86 package, and x86 packages are validated on 32-bit OSes. So this might be a 64-bit package."
		}
		"PackageFail" {
			$out = "Hi $Username`n`nThe package installs normally, but fails to run:`n"
		}
		"Paths" {
			$out = "Please update file name and path to match this change."
		}
		"PendingAttendedInstaller" {
			$out = "Pending:`n* https://github.com/microsoft/winget-cli/issues/910"
		}
		"Unattended" {
			$out = "Hi $Username`n`nThe installation isn't unattended:`n`nIs there an installer switch to bypass this and have it install automatically?"
		}
		"Unavailable" {
			$out = "Hi $Username`n`nThe installer isn't available from the publisher's website:"
		}
	}
	$out += "`n`n(Automated response - build $build.)"
	if ($NoClip) {
		$out 
	} else {
		$out |clip	
	}
}

Function Get-PRApproval {
	param(
		$Clip = (Get-Clipboard),
		[int]$PR = (($Clip -split "#")[1]),
		$PackageIdentifier = ((($clip -split ": ")[1] -split " ")[0]),
		$auth = (Get-Content  C:\repos\winget-pkgs\Tools\Auth.csv | ConvertFrom-Csv),
		$Approver = ((($auth | where {$_.PackageIdentifier -match $PackageIdentifier}).account -split "/" | where {$_ -notmatch "\("}) -join ", @"),
		[switch]$WhatIf
	)
	if ($WhatIf) {
		Write-Host "WhatIf: ReplyTo-PR $pr requesting approval from @$Approver."
	} else {
		ReplyTo-PR $pr (Get-CannedResponse approve $Approver -NoClip)
	}
}

#Timeclock
Function Set-Timeclock {
	Param(
		[ValidateSet("Start","Stop")][string]$mode = "Start",
		$time = (get-date -Format s),
		$timeStamp = (get-date $time -Format s)
	)
	if (Get-TimeRunning) { $mode = "Stop"}
	$timeStamp + " "+ $mode >> $timecardfile
}

Function Get-Timeclock {
	Param(
	)
	gc $timecardfile | select @{n="Date";e={get-date ($_ -split " ")[0]}},@{n="State";e={($_ -split " ")[1]}} 
	#
}

Function Get-HoursWorkedToday {
	Param(
		$Today = (get-date).Day
	)
	[array]$time = (Get-Timeclock).date | where {(get-date $_.date).day -eq $Today} | %{($_ -split " ")[1]}
	if (($time.count % 2) -eq 1) { 
		$time += (get-date -f T)
	}
	$aggregator = 0;
	for ($incrementor=0;$incrementor -lt $time.count; $incrementor=$incrementor+2){ 
		$aggregator += ( get-date $time[$incrementor+1]) - (get-date $time[$incrementor])
		#Write-Host $aggregator
	};
	[math]::Round($aggregator.totalHours,2)
}

Function Get-TimeRunning {
	if (	((gc $timecardfile)[-1] -split " ")[1] -eq "Start"){
		$True
	}  else {
		$False
	}
}

#Clipboard
Function Get-PRNumbers {
	param(
		$out = (Get-Clipboard),
		[switch]$NoClip,
		$dashboardPRRegex = "[0-9]{5,6}[:]"
	)
	$out = $out | select-string $dashboardPRRegex| sort -descending
	if ($NoClip) {
		$out
		} else {
		$out | clip
	}
}

Function Get-JustPRNumbers {
	param(
		$out = (Get-Clipboard),
		$dashboardPRRegex = "[#][0-9]{5,6}"
	)
	$out = ($out -split " " | select-string $dashboardPRRegex) -replace '#','' | sort -unique
	return $out
}

Function Sort-Clipboard {
	param(
		$out = (Get-Clipboard)
	)
	$out | sort | clip
}

Function Open-AllURLs {
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -split " "
	$out = $out | Select-String "`^http"
	$out = $out | Select-String -NotMatch "[.]exe$"
	$out = $out | Select-String -NotMatch "[.]msi$"
	$out = $out | Select-String -NotMatch "[.]zip$"
	$out = $out | sort -unique
	$out = $out | %{start-process $_}
}

Function Open-PRs {
	param(
		[switch]$Review,
		$clip = (Get-Clipboard)
	)
	$clip = ($clip -split " " | select-string "#[0-9]{5,6}") -replace "#",""
	
	foreach ($PR in $clip){
		$URL = "https://github.com/microsoft/winget-pkgs/pull/$PR#issue-comment-box"
		if ($Review) {
			$URL = "https://github.com/microsoft/winget-pkgs/pull/$PR/files"
		}
		
		Start-Process $URL
		sleep $GitHubRateLimitDelay
	}
}

Function Remove-FileIfExists {
	param(
		$FilePath,
		[switch]$remake,
		[switch]$Silent
	)
	if (test-path $FilePath) {rm $FilePath -recurse}
	if ($Silent) {
		if ($remake) {$null = mkdir $FilePath}
	}else {
		if ($remake) {mkdir $FilePath}
	}

}

Function Get-YamlValue {
	param(
		[string]$StringName,
		$clip = (Get-Clipboard)
	)
	((($clip | select-string $StringName) -split ": ")[1] -split "#")[0]
}

Function Test-Admin {
	if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){Write-Host "Try elevating your session.";break}
}

Function Find-InstallerSets {
	param(
		$clip = (Get-Clipboard),
		$delineator = "- "
	)
	$optionsLine = ($clip | select-string "Installers:").LineNumber
	$manifestLine = ($clip | select-string "ManifestType:").LineNumber[0] -2
	$InstallerSection = $clip[$optionsLine..$manifestLIne]
	$setCount = ($InstallerSection | Select-String $delineator).count
	Write-Host "$setCount sets detected:"
	$InstallerSection -split $delineator | %{
		$inputVar = $_
		Write-Host $inputVar

	#Arch, Scope, Locale
		$out = @{};
		$inputVar -split "`n" | %{
			$key,$value = ($_ -split ": " -replace " ","");
			$out[$key] = $value
		}
		$out["ProductCode"]
		$out.Remove("")
	}
}
