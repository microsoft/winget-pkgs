#Copyright 2022-2026 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v3.90.0
#Created: 10/19/2022
#Updated: 4/3/2026
#Notes: Utilities to streamline evaluating 3rd party PRs.

$build = 1488
$appName = "ManualValidationPipeline"
Write-Host "$appName build: $build"
$Owner = "microsoft"
if ($preprod) {
	$Repo = "winget-pkgs-preprod"	
	$Host.UI.RawUI.WindowTitle = "PREPROD"
} else {
	$Repo = "winget-pkgs"
}
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.

$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.Length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString
$RemoteMainFolder = "//$remoteIP/"
$SharedFolder = "$RemoteMainFolder/write"

#Folders
$MainFolder = "C:\ManVal"
Set-Location $MainFolder
$imagesFolder = "$MainFolder\Images" #VM Images folder
$logsFolder = "$MainFolder\logs" #VM Logs folder
$MiscFolder = "$MainFolder\misc"
$writeFolder = "$MainFolder\write" #Folder with write permissions
$vmCounter = "$MainFolder\vmcounter.txt"
$VMversion = "$MainFolder\VMversion.txt"

#Files
$TrackerModeFile = "$logsFolder\trackermode.txt"
$RemoteTrackerModeFile = "$RemoteMainFolder\ManVal\logs\trackermode.txt" #TrackerModeFile from the VM's perspective.
$LogFile = "$MiscFolder\ApprovedPRs.txt"
$PRQueueFile = "$MiscFolder\PRQueue.txt"
$PRExcludeFile = "$MiscFolder\PRExclude.txt"
$repoCountfile = "$MiscFolder\RepoCounts.csv"
$CovertReviewFile = "$MiscFolder\CovertReview.csv"
$ApprovalStatsFile = "$MiscFolder\ApprovalStats.csv"

#Data
$RepoFolder = "C:\repos\$Repo\Tools\ManualValidation"
$DataFileName = "$RepoFolder\ManualValidationPipeline.csv"
$JsonFileName = "$RepoFolder\ManualValidationPipeline.json"
$SchemaFileName = "$RepoFolder\ManualValidationSchema.json"
$LabelActionFile = "$RepoFolder\LabelActions.csv"
$ExitCodeFile = "$RepoFolder\ExitCodes.csv"
$AutowaiverFile = "$RepoFolder\Autowaiver.csv"
$PRStateDataFile = "$RepoFolder\PRStateFromComments.csv"
$MMCExceptionListFile = "$RepoFolder\MMCExceptionList.txt"
$ReviewFile = "$RepoFolder\Review.csv"
$SchemaCheckFile = "$logsFolder/SchemaCheck.txt"

$SharedErrorFile = "$writeFolder\err.txt"
$StatusFile = "$writeFolder\status.csv"

$Win10Folder = "$imagesFolder\Win10-Created053025-Original"
$Win11Folder = "$imagesFolder\Win11-Created120825-Original"

$GitHubBaseUrl = "https://github.com/$Owner/$Repo"
$GitHubContentBaseUrl = "https://raw.githubusercontent.com/$Owner/$Repo"
$GitHubApiBaseUrl = "https://api.github.com/repos/$Owner/$Repo"
$ADOMSBaseUrl = "https://dev.azure.com/shine-oss"
$ADOMSGUID = "8b78618a-7973-49d8-9174-4360829d979b"
$NextStaleCheck = (Get-Date)

$CheckpointName = "Validation"
$VMUserName = "user" #Set to the internal username you're using in your VMs.
$SystemRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
if ($preprod) {
	$Host.UI.RawUI.WindowTitle = "PREPROD-Utility"
} else {
	$Host.UI.RawUI.WindowTitle = "Utility"
}
$GitHubRateLimitDelay = 0.33 #second
$RamPctForVms = .28
[int]$PatchedValidationIteration = 0
# $RamPctForVms = .42
$GhRlRemain = 0
$schemaData = @{}
$MVSchemaData = gc $SchemaFileName | convertfrom-json

Function Get-StartupTest {
$StartupTestPaths = "Path,Name
$DataFileName,DataFileName
$JsonFileName,JsonFileName
$LabelActionFile,LabelActionFile
$ExitCodeFile,ExitCodeFile
$AutowaiverFile,AutowaiverFile
$PRStateDataFile,PRStateDataFile
$MMCExceptionListFile,MMCExceptionListFile
$ReviewFile,ReviewFile
$SharedErrorFile,SharedErrorFile
$StatusFile,StatusFile
$Win10Folder,Win10Folder
$Win11Folder,Win11Folder
$SharedFolder,SharedFolder
$MainFolder,MainFolder
$imagesFolder,imagesFolder
$logsFolder,logsFolder
$MiscFolder,MiscFolder
$writeFolder,writeFolder
$vmCounter,vmCounter
$VMversion,VMversion
$RemoteTrackerModeFile,RemoteTrackerModeFile
$TrackerModeFile,TrackerModeFile
$LogFile,LogFile
$PRQueueFile,PRQueueFile
$PRExcludeFile,PRExcludeFile
$repoCountfile,repoCountfile
$CovertReviewFile,CovertReviewFile
$ApprovalStatsFile,ApprovalStatsFile
" | convertfrom-csv

[string[]]$TestingManifest = gc "C:\ManVal\OtherMisc\TestingPR.yaml"

#TrackerVMValidate
[int]$TestingPRNumber = 389042
[string]$TestingPackageIdentifier = "Microsoft.PowerShell"
[string]$TestingPackageVersion = "7.5.8.0"
[string[]]$TestingArchitecture = "arm64"
[bool]$TestingElevationRequirement = $False

#PRWatch
[string]$TestingPRTitle = "#$TestingPRNumber"
[bool]$TestingManifestReview = $True
[string]$TestingInstallerType = "wix"
[string]$TestingAgreementUrl = $Null
[bool]$TestingWordFilterList = $False
[string]$TestingDisplayVersion = $Null
[string]$TestingInstallerUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.8/PowerShell-7.5.8-win-arm64.msi"

$StartupTestItems = "Path,Name
$((Get-VM | where {$_.Name -notmatch 'Win'}).count -eq (Get-Status).count),VMCount
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.AllPRsOnClipboard) -StrArray $TestingManifest) -eq $TestingPRNumber),$($Enum.ClipboardQueries.AllPRsOnClipboard) 
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).PackageIdentifier -eq $TestingPackageIdentifier),PRWatch-PackageIdentifier
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).PackageVersion -eq $TestingPackageVersion),PRWatch-PackageVersion
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).PRtitle -eq $TestingPRTitle),PRWatch-PRtitle
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).InstallerType -eq $TestingInstallerType),PRWatch-InstallerType
$($TestingAgreementUrl -match (Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).AgreementUrl),PRWatch-AgreementUrl
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).WordFilterList -eq $TestingWordFilterList),PRWatch-WordFilterList
$($TestingDisplayVersion -match (Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).DisplayVersion),PRWatch-DisplayVersion
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.PRWatch) -StrArray $TestingManifest).InstallerUrl -eq $TestingInstallerUrl),PRWatch-InstallerUrl
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.TrackerVmValidate) -StrArray $TestingManifest).PRNumber -eq $TestingPRNumber),TrackerVmValidate-PRNumber
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.TrackerVmValidate) -StrArray $TestingManifest).PackageIdentifier -eq $TestingPackageIdentifier),TrackerVmValidate-PackageIdentifier
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.TrackerVmValidate) -StrArray $TestingManifest).PackageVersion -eq $TestingPackageVersion),TrackerVmValidate-PackageVersion
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.TrackerVmValidate) -StrArray $TestingManifest).Architecture[0] -eq $TestingArchitecture),TrackerVmValidate-Architecture
$((Get-QueryClipboard -Query ($Enum.ClipboardQueries.TrackerVmValidate) -StrArray $TestingManifest).ElevationRequirement -eq $TestingElevationRequirement),TrackerVmValidate-ElevationRequirement
$([CredManager.Util]::GetUserCredential(`"Application Name`").password -eq 'Password'),GetUserCredential
" | convertfrom-csv


# $StartupTestItems

	$TotalTests = $StartupTestPaths.Count + $StartupTestItems.Count

	Write-Host "Running $TotalTests Tests: " -NoNewline
	$fail = 0
	foreach ($Datum in $StartupTestPaths) {
		$String = "$($Datum.Name) - "
		$ForegroundColor = "yellow"
		if (Test-Path $Datum.Path -ErrorAction SilentlyContinue) {
			$ForegroundColor = $Enum.PSColors.Green
		} else {
			$ForegroundColor = $Enum.PSColors.Red
			$fail++
		}
		Write-Host -ForegroundColor $ForegroundColor $String -NoNewline
	}

	foreach ($Datum in $StartupTestItems) {
		$String = "$($Datum.Name) - "
		$ForegroundColor = "yellow"
		if ($Datum.Path -eq $True) {
			$ForegroundColor = $Enum.PSColors.Green
		} else {
			$ForegroundColor = $Enum.PSColors.Red
			$fail++
		}
		Write-Host -ForegroundColor $ForegroundColor $String -NoNewline
	}
	
	
	if ($fail) {
		Write-Host -ForegroundColor $Enum.PSColors.Red "$Fail failed!" -NoNewline
	}
	Write-Host $Enum.Char.Blank #Write a blank string, to auto-add the console newline at the end of the tests.
}

#Data
Function Read-JsonData {
	Param(
		$FileName = $JsonFileName,
		$InputData = (Get-Content $FileName | ConvertFrom-Json)
	)
	$out = @{}
	$Names = ($InputData | Get-Member | where {$_.MemberType -match $Enum.Words.NoteProperty}).name
	foreach ($Name in $Names) {#Reserialize PSObject as hash table.
		$out.($Name) = $InputData.($Name)
	}
	$out
}
$Enum = Read-JsonData

Function Write-JsonData {
	Param(
		$Data = $Enum
	)
	[string]$Enum = $Data | ConvertTo-Json
	if ($Enum) {
		$Enum > $JsonFileName
	}
}

Function Get-ValidationData {
	Param(
		$Property = $Enum.Char.Blank,
		$Match = $Enum.Char.Blank,
		$data = (Get-Content $DataFileName | ConvertFrom-Csv | Where-Object {$_.$Property} | Where-Object {$_.$Property -match $Match}),
		[switch]$Exact
	)
	if ($Exact -eq $True) {
		$data = $data | Where-Object {$_.$Property -eq $Match}
	}
	Return $data 
}

Function Add-ValidationData {
	Param(
		[Parameter(Mandatory)][string]$PackageIdentifier,
		[string]$GitHubUserName = $Enum.GitHubUserNames.GitHubUserName,
 [ValidateScript( { $_ -in (Get-Keys $Enum.ValidationDataStrictness) } )][string]$authStrictness,
 [ValidateScript( { $_ -in (Get-Keys $Enum.ValidationDataType) } )][string]$authUpdateType,
		[string]$AutoWaiverLabel,
		[string]$versionParamOverrideUserName,
		[int]$versionParamOverridePR,
		[string]$code200OverrideUserName,
		[int]$code200OverridePR,
		[int]$AgreementOverridePR,
		[string]$AgreementURL,
		[string]$reviewText,
		$data = (Get-Content $DataFileName | ConvertFrom-Csv)
	)
	$PackageIdentifier = Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier 
	$out = ($data | where {$_.PackageIdentifier -eq $PackageIdentifier} | Select-Object $Enum.manifestKeys.PackageIdentifier,"GitHubUserName","authStrictness","authUpdateType","AutoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
	if ($null -eq $out) {
		$out = ( $Enum.Char.Blank | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","AutoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
		$out.PackageIdentifier = $PackageIdentifier
	}

		$out.GitHubUserName = $GitHubUserName
		$out.authStrictness = $authStrictness
		$out.authUpdateType = $authUpdateType
		$out.AutoWaiverLabel = $AutoWaiverLabel
		$out.versionParamOverrideUserName = $versionParamOverrideUserName
		$out.versionParamOverridePR = $versionParamOverridePR
		$out.code200OverrideUserName = $code200OverrideUserName
		$out.code200OverridePR = $code200OverridePR
		$out.AgreementURL = $AgreementURL
		$out.AgreementOverridePR = $AgreementOverridePR
		$out.reviewText = $reviewText
		$data += $out
		$data | sort PackageIdentifier | ConvertTo-Csv | Out-File $DataFileName 
}

#First tab
Function Get-TrackerVMRunTracker {
	while ($True) {
		if ($preprod) {
			$Host.UI.RawUI.WindowTitle = "PREPROD-Orchestration"
		} else {
			$Host.UI.RawUI.WindowTitle = "Orchestration"
		}

		Clear-Host
		$Status = Get-Status
		$Status | Format-Table; #Display
		$VMRAM = Get-ArraySum $status.RAM
		$ramColor = $Enum.PSColors.Green
		$valMode = Get-TrackerVMMode
		$contents = ""

		$Status.vm | %{
			$path = "$MainFolder\vm\$_\manifest\Package.yaml";
			try {$contents = (Get-Content $path -ErrorAction SilentlyContinue)}catch{}
			if ($contents -match "ManifestVersion: 1..0$") {
				$contents -replace "ManifestVersion: 1..0$","ManifestVersion: 1.10.0" | out-file $path -ErrorAction SilentlyContinue
			}
		}
		
		$status | ForEach-Object {
			$GetVM = Get-VM -Name ($Enum.Strings.Vm + $_.vm)
			$_.RAM = [math]::Round($GetVM.MemoryAssigned/1024/1024/1024, $Enum.Num.Two)
			
			if (($_.package -eq $Enum.Char.Blank) -AND ($_.status -eq $Enum.VMStatus.ValidationCompleted)) {
				$_.status = $Enum.VMStatus.Complete
			}
		}
		if ($status -ne $Enum.Char.Blank){
			Write-Status $status
		}
		

		
		if ($VMRAM -gt ($SystemRAM*0.5)) {
			$ramColor = $Enum.PSColors.Red
		} elseif ($VMRAM -gt ($SystemRAM*.25)) {
			$ramColor = $Enum.PSColors.Yellow
		}
		Write-Host "VM RAM Total: " -nonewline
		Write-Host -f $ramColor $VMRAM
		$timeClockColor = $Enum.PSColors.Red
		if (Get-TimeRunning) {
			$timeClockColor = $Enum.PSColors.Green
		}
		$PRQueueCount = Get-PRQueueCount
		$VMRate = [math]::round((Get-VMMinutesPerPackage),2)
		$PRsPerHour = [math]::round((60/$VMRate) * (Get-Status).count,2)
		# $GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
		Write-Host -nonewline "Build: $build - Mode $valMode - $GhRlRemain GH calls remain. Hours worked: "
		Write-Host -nonewline -f $timeClockColor (Get-HoursWorkedToday)
		Get-UpdateSource
		Write-Host " - PRs in queue: $PRQueueCount"
		Write-Host -nonewline "VMs are taking $VMRate minutes each, for about $PRsPerHour per hour. "
		(Get-VM) | ForEach-Object {
			if(($_.MemoryDemand / $_.MemoryMaximum) -ge 0.9){
				Set-VM -VMName $_.name -MemoryMaximumBytes "$(($_.MemoryMaximum / 1073741824) + 2)GB"
			}
		}
		Get-TrackerVMCycle;
		Get-TrackerVMWindowArrange
		$PatchedValidationIteration = 0

		if ($valMode -eq "IEDS") {
			if ((Get-ArraySum $status.RAM) -lt ($SystemRAM*$RamPctForVms)) {
				Write-Output $valMode
				Get-RandomIEDS
			}
		} elseif ($valMode -eq "Drain") {
		} else {
			if (!(($status | Where-Object {$_.version -ne (Get-TrackerVMVersion)}).Count)) {
				if (!($status | Where-Object {($_.mode -join $Enum.Char.Space) -match "Creation"})) {
					if ($PRQueueCount -gt 0) {
						if ((Get-ArraySum $status.RAM) -lt ($SystemRAM*$RamPctForVms)) {
							$PR = Get-SchemaCheck -InputData (Get-PopPRQueue) -SchemaInfo $mvschemaData.PR.Number
							if ($null -ne $PR) {
								Write-Output "Running $PR from queue."
									Get-CommitFile -PR $PR -VM (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM))
							}; #if null
						}; #if Get-Array
					}; #if PRQueueCount
				}; #If not status
			}; #If not status
		}; #if valMode

		$QueryClipboard = Get-QueryClipboard -Query $Enum.ClipboardQueries.TrackerVMRunTracker
		If ($QueryClipboard.($Enum.SchemaKeysEtc.SkipToContent)) {
			$GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
			if ($valMode -eq "Validating") {
				Get-TrackerVMValidate;
				$valMode | clip
			}
		} elseIf ($QueryClipboard.($Enum.SchemaKeysEtc.manifests)) {#Example: /manifests/t/tritant/MiniMediaEdit/1.0/tritant.MiniMediaEdit.installer.yaml
			$GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
			Write-Output "Opening manifest file"
			$ManifestUrl = "$GitHubBaseUrl/tree/master/" + $QueryClipboard.($Enum.SchemaKeysEtc.manifests)
			Start-Process ($ManifestUrl)
		}
		if (Get-ConnectedVM) {
			#Get-TrackerVMResetStatus
		} else {
			Get-TrackerVMRotate
		}
		Start-Sleep 5;
	}
	Write-Host "End of cycle."
}

#Second tab
Function Get-TrackerVMScheduler {
	$Now = get-date
	while ($true) {
		$Timestamp = (get-date -f s) -replace $Enum.Char.T,$Enum.Char.Space
		if (([int](get-date -f mm) / $Enum.Num.Ten) -eq $Enum.Num.One) {
		#Every 10 minutes.
			$WatchLatch = $True
			$VMs = (Get-VM |where {$_.status -ne "LongRunning"}) 
			foreach ($VM in $VMs) {
				if ($VM.uptime.totalhours -gt 3){
					$name = $VM.name -replace $Enum.Strings.Vm,$Enum.Char.Blank; 
					Get-TrackerVMSetStatus $Enum.VMStatus.Complete $name
				}
			}
			Write-Host "WatchLatch - $WatchLatch"
		}
		if ($WatchLatch) {#PR Watch functionality
			Write-Host "$Timestamp - PRWatch"
			Get-StopStuckVMs
			Copy-Item "$RepoFolder\ManualValidationProfile.ps1" "$MainFolder\vm\0\Profile.ps1"
			# Get-PRWatch -LogFile $MiscFolder\ApprovedPRs.txt -ReviewFile $ReviewFile -noNew
			$WatchLatch = $False
		} #Every 10 minutes.
		
		if (([int](get-date -f mm) -eq 20) -OR ([int](get-date -f mm) -eq 50)) {
		#Twice an hour at 20 and 50 after.
			$HourLatch = $True
			Write-Host "HourLatch - $HourLatch"
			
			$DefenderPRs = (Get-SearchGitHub -Preset Defender).number
			foreach ($PR in $DefenderPRs) {
				Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.IEDS
				Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.VIE
				Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.VEE
				Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.VC
			}
		}
		if ($HourLatch) {#Hourly Run functionality
			Write-Host "$Timestamp - ScheduledRun"
			Get-ScheduledRun 
			$HourLatch = $False
		} #Twice an hour at 20 and 50 after.
		cls
		Write-Host "$Timestamp - Waiting"
		if ($preprod) {
			$Host.UI.RawUI.WindowTitle = "PREPROD-Waiting"
		} else {
			$Host.UI.RawUI.WindowTitle = "Waiting"
		}
		$GetStatus = Get-Status
		$VMRAM = Get-ArraySum $GetStatus.RAM
		$ramColor = $Enum.PSColors.Green
		if ($VMRAM -gt ($SystemRAM*0.5)) {
			$ramColor = $Enum.PSColors.Red
		} elseif ($VMRAM -gt ($SystemRAM*.25)) {
			$ramColor = $Enum.PSColors.Yellow
		}
		Write-Host "VM RAM Total: " -nonewline
		Write-Host -f $ramColor $VMRAM
		$timeClockColor = $Enum.PSColors.Red
		if (Get-TimeRunning) {
			$timeClockColor = $Enum.PSColors.Green
		}
		$PRQueueCount = Get-PRQueueCount
		Write-Host -nonewline "Build: $build - Hours worked: "
		Write-Host -nonewline -f $timeClockColor (Get-HoursWorkedToday)
		Write-Host " - PRs in queue: $PRQueueCount"		
		Start-Sleep 5		

		$HourLatch = $False
		$WatchLatch = $False
	}; #end while true
}; #end function

Function Get-PRWatch {
	[CmdletBinding()]
	Param(
		[switch]$noNew,
		[string]$LogFile = ".\PR.txt",
		$oldclip = $Enum.Char.Blank,
 [ValidateScript( { $_ -in (Get-Keys $Enum.SearchPresets)})][string]$SearchPreset = $Enum.SearchPresets.Approval2,
		$PrePipeline = $false,
		[switch]$DirectMode,
		[switch]$Continuous,
		$AuthList = (Get-ValidationData -Property authStrictness),
		$AgreementsList = (Get-ValidationData -Property AgreementUrl),
		$ReviewList = (Get-LoadFileIfExists $ReviewFile),
		$QueryClipboard = (Get-QueryClipboard -Query $Enum.ClipboardQueries.PRWatch),
		[int]$Page = $Enum.Num.One,
		[switch]$Patch,
		[switch]$WhatIf,
		[switch]$Display
	)
	#if ((Get-Command Get-TrackerVMSetMode).name) {Get-TrackerVMSetMode "Approving"}
	[string]$PRtitle = ""
	if ($Display) {Write-Host "Start PRtitle $PRtitle"}
	$ManifestReview = $True
	$ResultsCount = 0
	$RunStart = Get-Date
	Write-Log " | Timestmp | $(Get-PadRight PR# 6) | $(Get-PadRight PackageIdentifier) | $(Get-PadRight prVersion 15) | A | R | G | W | F | I | D | V | $(Get-PadRight ManifestVer 14) | OK |"
	Write-Log " | -------- | ----- | ------------------------------- | -------------- | - | - | - | - | - | - | - | - | ------------- | -- |"
	$Run = $True
	while($Run -eq $True){
		if ($WhatIf) {
			if ($preprod) {
				$Host.UI.RawUI.WindowTitle = "PREPROD-(WhatIf) Watcher"
			} else {
				$Host.UI.RawUI.WindowTitle = "(WhatIf) Watcher"#I'm the Fisher King, and "What if I watched PRs go by" is my question. 
			}
		} else {
			if ($preprod) {
				$Host.UI.RawUI.WindowTitle = "PREPROD-PR Watcher"
			} else {
				$Host.UI.RawUI.WindowTitle = "PR Watcher"#I'm a PR Watcher, watchin PRs go by. 
			}
		}
		if ($DirectMode) {
			[int]$PR = 0
			$QueryClipboard = (Get-QueryClipboard -Query $Enum.ClipboardQueries.PRWatch)
			$PR = (Get-QueryClipboard -Query $Enum.ClipboardQueries.AllPRsOnClipboard)
			if ($PR -gt 0) {
				$PRData = Get-PRData $PR
				$PRtitle = $PRData.title
			}
			if ($Display) {Write-Host "DirectMode PRtitle $PRtitle"}
			$Results = $PR
		} else {
			$RunStart = Get-Date
			if ($Display) {Write-Host "Gathering PR numbers for $SearchPreset"}
			$FullResults = Get-SearchGitHub -Preset $SearchPreset -nBMM -Page $Page
			$Results = $FullResults.number
			$ResultsCount = $Results.Count
			if ($Display) {Write-Host "Found $ResultsCount PRs"}
		}
		foreach ($PR in $Results) {
			$FullPR = $FullResults | where {$_.number -match $PR}
			if ($Display) {Write-Host "Processing PR $PR"}
			if ($DirectMode) {
			} else {
				if ($Patch) {
					$QueryClipboard = Get-QueryClipboard -Query $Enum.ClipboardQueries.PRWatch -StrArray ((Get-PRManifest -pr $PR -Patch) -split "`n")
				} else {
					$QueryClipboard = Get-QueryClipboard -Query $Enum.ClipboardQueries.PRWatch -StrArray ((Get-PRManifest -pr $PR) -split "`n")
				}
				$PRtitle = $FullPR.title;
				if ($Display) {Write-Host "PR title $PRTitle"}
			}
			if ($PRtitle) {
				if (Compare-Object $PRtitle $oldclip) {						
						$validColor = $Enum.PSColors.Green
						$invalidColor = $Enum.PSColors.Red
						$cautionColor = $Enum.PSColors.Yellow

						$noRecord = $False
						$WinGetOutput = ""
						$title = $PRtitle -split ": "
						if ($title[$Enum.Index.Second]) {
							$title = $title[$Enum.Index.Second] -split $Enum.Char.Space
						} else {
							$title = $title -split $Enum.Char.Space
						}
						[string]$Submitter = $PRData.user.login
						[string]$InstallerType = $QueryClipboard.InstallerType
						[string]$prVersion = $QueryClipboard.PackageVersion
						[string]$PackageIdentifier = $QueryClipboard.PackageIdentifier
						$matchColor = $validColor
						if ($Display) {Write-Host "PackageIdentifier $PackageIdentifier"}




						Write-Log " | $(Get-Date -Format $($Enum.Char.T)) | $PR | $(Get-PadRight $PackageIdentifier) | " -nonewline -ForegroundColor $matchColor

						

						#Variable effervescence
						$prAuth = $Enum.Char.Plus
						$Auth = "A"
						$Review = "R"
						$WordFilter = "W"
						$AgreementAccept = "G"
						$AnF = "F"
						$InstVer = "I"
						$ListingDiff = "D"
						$NumVersions = 99
						$PRvMan = "P"
						$Approve = $Enum.Char.Plus
						
						$ValToEval = $Enum.Char.Blank
						
						If ($PackageIdentifier.Length -gt 3) {
							
						# $fullPR.labels.name -match $Enum.PRLabels.NP
							$ManifestVersion = Get-ManifestVersion -PackageIdentifier $PackageIdentifier
							$ManifestVersionParams = ($ManifestVersion -split "[.]").Count
							$prVersionParams = ($prVersion -split "[.]").Count
							
							
							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#-------------------------- Auth -----------------------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////


							$AuthMatch = $AuthList | Where-Object {$PackageIdentifier -cmatch $_.PackageIdentifier}
							if ($AuthMatch.PackageIdentifier -notmatch "\*") {
								$AuthMatch = $AuthList | Where-Object {$_.PackageIdentifier -ceq $PackageIdentifier}
							} 
							
							if ($QueryClipboard.ManifestReview -eq $false) {
								$Approve = $Enum.Char.NotExclamation
							}
							if ($AuthMatch) {
								$AuthAccount = $AuthMatch.GitHubUserName | Sort-Object -Unique
								}
							$GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
							if ($GhRlRemain -le 0) {
								$WinGetOutput = (Find-WinGetPackage $PackageIdentifier)
								$ValToEval = $WinGetOutput
							} else {
								$ValToEval = $ManifestVersion
							}

							if ($null -eq $ValToEval) {
								$PRvMan = "N"
								$matchColor = $invalidColor
								$Approve = $Enum.Char.NotExclamation
								Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.NP
								Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.NM
								if ($noNew) {
									$noRecord = $True
								} else {
									Add-PRToQueue -PR $PR
									# if ($title[$Enum.Index.Last] -match $Enum.Regex.hashPRRegex) {
										# if ((Get-Command Get-TrackerVMValidate).name) {
											#Add-PRToQueue -PR $PR
											# Get-TrackerVMValidate -Silent -InspectNew
										# } else {
											# Get-Sandbox ($title[$Enum.Index.Last] -replace $Enum.Char.Hash,$Enum.Char.Blank)
										# }; #end if Get-Command
									# }; #end if title
								}; #end if noNew
							}
							Write-Log "$(Get-PadRight $PRVersion.toString() 14) | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor




							if ($AuthMatch) {
								$strictness = $AuthMatch.authStrictness | Sort-Object -Unique
								$matchVar = $Enum.Char.Blank
								$matchColor = $cautionColor
								$AuthAccount -split $Enum.Char.Slash| where {$_ -notmatch "Microsoft"} | %{
									#Write-Host "This $_ Submitter $Submitter"
									if ($_ -ceq $Submitter) {
										$matchVar = "matches"
										$Auth = $Enum.Char.Plus
										$matchColor = $validColor
									}
									foreach ($User in ((Invoke-GitHubPRRequest -PR $PR -Type reviews -Output Content).user.login | Select-Object -Unique)) {
										if ($Submitter -match $User) {
											$matchVar = "preapproved"
											$Auth = $Enum.Char.Plus
											$matchColor = $validColor
										}
									}
									
								}
								
								if ($matchVar -eq $Enum.Char.Blank) {
									$matchVar = $enum.strings.DoesNotMatch
									$Auth = $Enum.Char.Dash
									$matchColor = $invalidColor
								}
								if ($strictness -eq "must") {
									$Auth += "!"
								}
							}
							if ($Auth -eq $Enum.Char.NotExclamation) {
								if (!$WhatIf) {
									Get-PRApproval -PR $PR -PackageIdentifier $PackageIdentifier
								}
							}
							Write-Log "$Auth | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor




							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#-------------------------- Review----------------------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////

							$ReviewMatch = $ReviewList | Where-Object {$_.PackageIdentifier -ceq $PackageIdentifier }
							if ($ReviewMatch) {
								$Review = $ReviewMatch.Reason | Sort-Object -Unique
								$matchColor = $cautionColor
							}

							Write-Log "$Review | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor



						#In list, matches PR - explicit pass
						#In list, PR has no Installer.yaml - implicit pass
						#In list, missing from PR - block
						#In list, mismatch from PR - block
						#Not in list or PR - pass
						#Not in list, in PR - alert and pass?
						#Check previous version for omission - depend on wingetbot for now.
						$AgreementUrlFromList = ($AgreementsList | where {$_.PackageIdentifier -ceq $PackageIdentifier}).AgreementUrl
						if ($AgreementUrlFromList) {
							$AgreementUrlFromClip = $QueryClipboard.AgreementUrl
							if ($AgreementUrlFromClip -ceq $AgreementUrlFromList) {
								#Explicit Approve - URL is present and matches.
								$AgreementAccept = " + !"
							} else {
								#Explicit mismatch - URL is present and does not match, or URL is missing.
								$AgreementAccept = $Enum.Char.NotExclamation
								$ApproverUserName = ($AgreementsList | where {$_.PackageIdentifier -ceq $PackageIdentifier}).gitHubUserName
								if ($WhatIf) {
									"Reply-ToPR -PR $PR -CannedMessage $($Enum.CannedMessages.AgreementMismatch) -UserInput $ApproverUserName -Silent"
								} else {
									Reply-ToPR -PR $PR -CannedMessage $Enum.CannedMessages.AgreementMismatch -UserInput $ApproverUserName -Silent -Automated
								}
							}
						} else {
							$AgreementAccept = $Enum.Char.Plus
							#Implicit Approve - your AgreementsUrl is in another file. Can't modify what isn't there. 
						}
							Write-Log "$AgreementAccept | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor






							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#-------------------------- Word Filter ---------------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////


						if (($PRtitle -notmatch $Enum.PRWatch.AutomaticDeletion) -AND 
						($PRtitle -notmatch $Enum.PRWatch.Delete) -AND 
						($PRtitle -notmatch $Enum.PRWatch.Remove) -AND 
						($AgreementAccept -notmatch "[ + ]")) {

							# Returns true IFF there are any matches, otherwise false.
							# Not sure why teh URI and Agreement strings are here. 
							[bool]$WordFilterMatch = $QueryClipboard.WordFilterList
							if ($WordFilterMatch) {
								$WordFilter = $Enum.Char.NotExclamation
								$Approve = $Enum.Char.NotExclamation
								$matchColor = $invalidColor
								if (!$WhatIf) {
									Reply-ToPR -PR $PR -CannedMessage WordFilter -UserInput $WordFilterMatch -Silent
								}
							}
						}
							Write-Log "$WordFilter | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor





							
							if ($null -ne $ValToEval) {
								if (($PRvMan -ne "N") -AND 
								((($Enum.DisplayVersionExceptionList) -join $Enum.Char.Space) -match $PRtitle) -AND 
								($PRtitle -notmatch $Enum.PRWatch.AutomaticDeletion) -AND 
								($PRtitle -notmatch $Enum.PRWatch.Delete) -AND 
								($PRtitle -notmatch $Enum.PRWatch.Remove)) {
									$DisplayVersion = $QueryClipboard.DisplayVersion
									$DeveloperIsAuthor = (($QueryClipboard.PackageIdentifier -split ".")[0] -ceq $Submitter)
									$InstallerMatch = ($InstallerUrl -split $Enum.Char.Slash) -match $Submitter

									if ($DisplayVersion) {
										if ($DisplayVersion -eq $prVersion) {
											$matchColor = $invalidColor
											$AnF = $Enum.Char.Dash
											if (!$WhatIf) {
												Reply-ToPR -PR $PR -CannedMessage AppsAndFeaturesMatch -UserInput $Submitter -Policy "[Policy] $($Enum.PRLabels.NAF)`n[Policy] $($Enum.PRLabels.CR)" -Silent
												Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback -Title $PRtitle
											}
										}
									}
									
									# if (!($DeveloperIsAuthor)) {
										# if ($InstallerMatch) {
											# $matchColor = $invalidColor
											# $AnF = $Enum.Char.Dash
											# Reply-ToPR -PR $PR -CannedMessage InstallerMatchesSubmitter -UserInput $Submitter -Policy $Enum.PRLabels.NAF -Silent
											# Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback -Title $PRtitle
										# }
									# }
								}
							}

							Write-Log "$AnF | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor



							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#------------- InstallerUrl Version Check ---------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////

								if (($PRvMan -ne "N") -AND 
								($PRtitle -notmatch $Enum.PRWatch.AutomaticDeletion) -AND 
								($PRtitle -notmatch $Enum.PRWatch.Delete) -AND 
								($PRtitle -notmatch $Enum.PRWatch.Remove)) {
								try {
									$InstallerUrl = $QueryClipboard.InstallerUrl
									#Write-Host "InstallerUrl: $InstallerUrl $installerMatches prVersion: -PR $PRVersion" -f "blue"
									$installerMatches = [bool]($InstallerUrl | Select-String $PRVersion)
									if (!($installerMatches)) {
										#Matches when the dots are removed from semantec versions in the URL.
										$installerMatches2 = [bool]($InstallerUrl | Select-String ($PRVersion -replace "[.]",$Enum.Char.Blank))
										if (!($installerMatches2)) {
											$matchColor = $invalidColor
											$InstVer = $Enum.Char.Dash
										}
									}
								} catch {
									$matchColor = $invalidColor
									$InstVer = $Enum.Char.Dash
								}; #end try
							}; #end if PRvMan

							try {#This section might be unnecessary now. 
								if (($QueryClipboard.PackageVersion) -match $Enum.Char.Space) {
									$matchColor = $invalidColor
									$InstVer = $Enum.Char.NotExclamation
								}
							}catch{}

							Write-Log "$InstVer | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor



							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#--------------- Highest Version Removal --------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////

							if (($PRvMan -ne "N") -AND 
							(($PRtitle -match $Enum.PRWatch.AutomaticDeletion) -OR 
							($PRtitle -match $Enum.PRWatch.Delete) -OR 
							($PRtitle -match $Enum.PRWatch.Remove))) {#Removal PR
							
								if ($GhRlRemain -le 0) {
									$NumVersions = ($WinGetOutput.AvailableVersions | sort).Count
								} else {
									$NumVersions = $ListVersions.Count
								}
								if (($prVersion -eq $ManifestVersion) -OR ($NumVersions -eq 1)) {
									$matchColor = $invalidColor
									if ($WhatIf) {
										"Reply-ToPR -PR $PR -CannedMessage VersionCount -UserInput $Submitter -Silent -Policy '[Policy] $($Enum.PRLabels.NAF)`n[Policy] $($Enum.PRLabels.HVL)'"
										"Add-PRToRecord -PR $PR -Action $($Enum.PRActions.Feedback) -Title $PRtitle"
									} else {
										Reply-ToPR -PR $PR -CannedMessage VersionCount -UserInput $Submitter -Silent -Policy "[Policy] $($Enum.PRLabels.NAF)`n[Policy] $($Enum.PRLabels.HVL)"
										Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback -Title $PRtitle
										$NumVersions = "L"
									}
								}
							} else {#Addition PR
							}#end if PRvMan
							Write-Log "$ListingDiff | " -nonewline -ForegroundColor $matchColor
							Write-Log "$NumVersions | " -nonewline -ForegroundColor $matchColor
							$matchColor = $validColor




							#/////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\
							#-------------------------- Approval ------------------------
							#\\\\\\\\\\\\\\\\\\\\\\\\\/////////////////////////
							
							if ($PRvMan -ne "N") {
								if ($null -eq $PRVersion -or $Enum.Char.Blank -eq $PRVersion) {
									$noRecord = $True
									$PRvMan = "Error:prVersion"
									$matchColor = $invalidColor
								} elseif ($ManifestVersion -eq "Unknown") {
									$noRecord = $True
									$PRvMan = "Error:ManifestVersion"
									$matchColor = $invalidColor
								} elseif ($null -eq $ManifestVersion) {
									$noRecord = $True
									
									if ($GhRlRemain -le 0) {
										$PRvMan = $WinGetOutput
									} else {
										$PRvMan = $ManifestVersion
									}
									$matchColor = $invalidColor
								} elseif ($prVersion -gt $ManifestVersion) {
									$PRvMan = $ManifestVersion.toString()
								} elseif ($prVersion -lt $ManifestVersion) {
									$PRvMan = $ManifestVersion.toString()
									$matchColor = $cautionColor
								} elseif ($prVersion -eq $ManifestVersion) {
									$PRvMan = " = "
								} else {
									$noRecord = $True
									if ($GhRlRemain -le 0) {
										$PRvMan = $WinGetOutput
									} else {
										$PRvMan = $ManifestVersion
									}
								};
							};
						} else {
							$Approve = $Enum.Char.NotExclamation
							$Auth = $Enum.Char.NotExclamation
							$AnF = "F"
							$InstVer = "I"
							$prAuth = $Enum.Char.NotExclamation
							$Review = "R"
							$ListingDiff = "D"
							$NumVersions = 99
							$WordFilter = "W"
							$AgreementAccept = "G"
							$PRvMan = "P"
							Open-PRInBrowser -PR $pr
						}


						if (($Approve -eq $Enum.Char.NotExclamation) -or 
						($Auth -eq $Enum.Char.NotExclamation) -or 
						($AnF -eq $Enum.Char.Dash) -or 
						($InstVer -eq $Enum.Char.NotExclamation) -or 
						($prAuth -eq $Enum.Char.NotExclamation) -or 
						($Review -ne "R") -or 
						($ListingDiff -eq $Enum.Char.NotExclamation) -or 
						($NumVersions -eq 1) -or 
						($NumVersions -eq "L") -or 
						($WordFilter -eq $Enum.Char.NotExclamation) -or 
						($AgreementAccept -eq $Enum.Char.NotExclamation) -or 
						($PRvMan -eq "N")) {
						#-or ($PRvMan -match "^Error")
							$matchColor = $cautionColor
							$Approve = $Enum.Char.NotExclamation
							$noRecord = $True
						}
						if ($WhatIf) {
							$Approve += "W"
						} 

						$PRvMan = Get-PadRight $PRvMan 14
						Write-Log "$PRvMan | " -nonewline -ForegroundColor $matchColor
						$matchColor = $validColor





						if ($PrePipeline -eq $false) {
							if ($WhatIf) {
								Write-Host "Approve-PR -PR $PR"
								Write-Host "Add-PRToRecord -PR $PR -Action $($Enum.PRActions.Approved) -Title $PRtitle"
							}else {
								if ($Approve -eq $Enum.Char.Plus) {
									$Approve = Approve-PR -PR $PR
									Add-PRToRecord -PR $PR -Action $Enum.PRActions.Approved -Title $PRtitle
								}
							}
						}

						Write-Log "$Approve | " -ForegroundColor $matchColor

						$oldclip = $PRtitle
						
					}; #end if Compare-Object
				}; #end if PRtitle
			}; #end foreach PR
			if ($DirectMode) {
				$SecondsBetweenRuns = 1
				#Write-Host "Sleeping for $SecondsBetweenRuns seconds."
				Start-Sleep $SecondsBetweenRuns

			} else {
				$Run = $False
			}
			if ($Continuous) {
				$Run = $True
				$SleepSeconds = (30-$ResultsCount)*60
				$WakeTime = (Get-Date (Get-Date).AddSeconds($SleepSeconds)).ToString() 
				$RunEnd = Get-Date
				$RunMinutes = ($RunEnd - $RunStart).TotalMinutes
				$RunSeconds = ($RunEnd - $RunStart).TotalSeconds
				$RunAvgSecPerItem = $RunSeconds/$ResultsCount
				Write-Log "Last run approved $ResultsCount PRs in $RunMinutes minutes ($RunSeconds seconds), for an average of $RunAvgSecPerItem seconds per PR - sleeping until $WakeTime"
				if ($WhatIf) {
					if ($preprod) {
						$Host.UI.RawUI.WindowTitle = "PREPROD-(WhatIf) until $WakeTime"
					} else {
						$Host.UI.RawUI.WindowTitle = "(WhatIf) until $WakeTime"
					}
				} else {
					if ($preprod) {
						$Host.UI.RawUI.WindowTitle = "PREPROD-sleeping until $WakeTime"
					} else {
						$Host.UI.RawUI.WindowTitle = "sleeping until $WakeTime"
					}
				}
				Write-ApprovalStats -DateTime $RunStart -PRsApprovedDuringLastRun $ResultsCount -LastRunTookSeconds $RunSeconds -SleepUntil $WakeTime
				
				Sleep $SleepSeconds
			}
	$log = ""

		}; #end while true eq run
}; #end function

#Third tab
Function Get-WorkSearch {
	Param(
		$PresetList = @($Enum.SearchPresets.ToWork),#Approval","
		[int]$Page = $Enum.Num.One,
		[switch]$OpenInBrowser
	)
	Foreach ($Preset in $PresetList) {
		Write-Host "Preset $Preset"
		$PRs = (Get-SearchGitHub -Preset $Preset -Page $Page -NoLabels -nBMM) 
		Write-Host "PRs.Length $($PRs.Length)"
		While ($PRs.Length -gt 0) {
			$line = 0
			$PRs = (Get-SearchGitHub -Preset $Preset -Page $Page -NoLabels -nBMM) 
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) $Preset Page $Page beginning with $($PRs.Length) Results"
			$PRs = $PRs | where {$_.labels} | where {$_.number -notin (Get-Status).pr} 
			
			Foreach ($FullPR in $PRs) {
				# Write-Host "FullPR $FullPR"
				$PR = Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $FullPR.number
				Get-TrackerProgress -Activity $MyInvocation.MyCommand.name -ItemName $PR -ItemNumber $line -TotalItems $PRs.Length; $line++
				if ($Enum.PRLabels.HVL -notin $FullPR.labels.name) {
					if (($FullPR.title -match $Enum.PRWatch.Remove) -OR 
					($FullPR.title -match $Enum.PRWatch.Delete) -OR 
					($FullPR.title -match $Enum.PRWatch.AutomaticDeletion)){
						Get-GitHubPreset CheckInstaller -PR $PR
					}
				}
				$Comments = Get-PRComments -PR $PR
				if ($Preset -eq $Enum.SearchPresets.Approval){
					if (Get-NonStdPRComments -PR $PR -comments $Comments.body){
						Open-PRInBrowser -PR $PR
					} else {
						Open-PRInBrowser -PR $PR -FIles
					}
				} elseif ($Preset -eq $Enum.SearchPresets.Defender){
					Get-GitHubPreset -Preset $Enum.GitHubPresets.LabelAction -PR $PR
				} else {#ToWork etc
					$Comments = ($Comments | Select-Object $Enum.Strings.CreatedAt,@{n = $Enum.Strings.UserName; e = {$_.user.login -replace $Enum.Strings.BotPrefix}},body)
					$State = (Get-PRStateFromComments -PR $PR -Comments $Comments)
					$LastState = $State[$Enum.Index.Last]
					if ($LastState.event -eq $Enum.PRTrackerStates.DefenderFail) { 
						Get-PRLabelAction -PR $PR
					} elseif ($LastState.event -eq $Enum.PRTrackerStates.LabelAction) { 
						Get-GitHubPreset -Preset $Enum.GitHubPresets.LabelAction -PR $PR
						Open-PRInBrowser -PR $PR
					} else {
						if ($Comments[$Enum.Index.Last].user.login -ne $Enum.GitHubUserNames.GitHubUserName) {
							if ($LastState.event -eq $Enum.PRTrackerStates.PreValidation) { 
								Get-GitHubPreset -Preset $Enum.GitHubPresets.LabelAction -PR $PR
							}
							if ($OpenInBrowser) {
								Open-PRInBrowser -PR $PR
							}
						}
					}#end if LastCommenter
				}#end if Preset
			}#end foreach FullPR
			if ($OpenInBrowser) {
				Read-Host "$(Get-Date -Format $($Enum.Char.T)) $Preset Page $Page complete with $($PRs.Length) Results - press ENTER to continue..."
			}
			$Page++
		}#end While Count
		$Page = $Enum.Num.One
	}#end Foreach Preset
	Write-Progress -Activity $MyInvocation.MyCommand.name -Completed
}#end Get-WorkSearch
#Automation tools
Function Get-GitHubPreset {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.GitHubPresets)} )][string]$Preset,
		[int]$PR,
		$CannedMessage = $Preset,
		$UserInput,
		[Switch]$Force,
		$out = $Enum.Char.Blank
	)
	$PR = Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR
	if (($Preset -eq $Enum.GitHubPresets.GitHubStatus) -OR
		($Preset -eq $Enum.GitHubPresets.IdleMode) -OR
		($Preset -eq $Enum.GitHubPresets.IEDSMode) -OR
		($Preset -eq $Enum.GitHubPresets.Timeclock) -OR
		($Preset -eq $Enum.GitHubPresets.Validating) -OR
		($Preset -eq $Enum.GitHubPresets.WorkSearch)) {
		$Force = $True
		$out += $Preset;
	}

	if (($PR.ToString().Length -eq 6) -OR $Force) {
		Switch ($Preset) {
			$Enum.GitHubPresets.Approved {
				$out += Approve-PR -PR $PR; 
				Add-PRToRecord -PR $PR -Action $Preset
			}
			$Enum.GitHubPresets.AutomationBlock {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Blocking
				$out += Reply-ToPR -PR $PR -CannedMessage AutomationBlock -Policy $Enum.PRLabels.NB 
			}
			$Enum.GitHubPresets.Blocking {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Blocking
				$out += Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data "[Policy] $($Enum.PRLabels.NB)"
			}
			$Enum.GitHubPresets.CheckInstaller {
				$Pull = (Invoke-GitHubPRRequest -PR $PR -Type files -Output $Enum.PRRequestOutput.Content -JSON)
				$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[$Enum.Index.First] -JSON).content))
				$Url = (Get-YamlValue -Key InstallerUrl -clip $PullInstallerContents)
				$out = $Enum.Char.Blank
				try {
					$InstallerStatus = Check-PRInstallerStatusInnerWrapper $Url
					$out = "Status Code: $InstallerStatus"
				}catch{
					$out = $error[$Enum.Index.First].Exception.Message
				}
				$Body = "URL: $Url `n" + $out+"`n`n(Automated message - build $build)"
				#If ($Body -match "Response status code does not indicate success") {
					#$out += Get-GitHubPreset InstallerMissing -PR $PR 
				#} #Need this to only take action on new PRs, not removal PRs.
				$out += Reply-ToPR -PR $PR -body $Body -Automated
				# $out = $out += Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data $Body -Output $Enum.PRRequestOutput.StatusDescription 
			}
			$Enum.GitHubPresets.Completed {
				$out += Reply-ToPR -PR $PR -Body "This package installs and launches normally in a Windows 10 VM." -Policy $Enum.PRLabels.MV
			}
			$Enum.GitHubPresets.Closed {
				if ($UserInput) {
					Add-PRToRecord -PR $PR -Action $Preset
					$out += Invoke-GitHubPRRequest -PR $PR -Type $Enum.PRRequestTypes.Comments -Output $Enum.PRRequestOutput.StatusDescription -Method $Enum.PRRequestMethods.Post -Data "Close with reason: $UserInput;"
				} else {
					Write-Output "-UserInput needed to use preset $preset"
				}
			}
			$Enum.GitHubPresets.DefenderFail {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Blocking
				$out += Get-CannedMessage -Response DefenderFail -NoClip -NotAutomated
				#$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy "Needs-Attention`n[Policy] $($Enum.PRLabels.VDE)"
			}
			$Enum.GitHubPresets.DriverInstall {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Blocking
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Enum.PRLabels.DI
			}
			$Enum.GitHubPresets.Duplicate {
				if ($UserInput -match "[0-9]{5,6}") {
					Get-GitHubPreset -Preset $Enum.GitHubPresets.Closed -PR $PR -UserInput "Duplicate of #$UserInput"
				} else {
					Write-Output "-UserInput PRNumber needed to close as duplicate."
				}
			}
			$Enum.GitHubPresets.Feedback {
				Add-PRToRecord -PR $PR -Action $Preset
				if ($UserInput) {
					$out += Reply-ToPR -PR $PR -Body $UserInput -Policy $Enum.PRLabels.NAF
				} else {
					Write-Output "-UserInput needed to use preset $preset"
				}
			}
			$Enum.GitHubPresets.GitHubStatus {
				return (Invoke-GitHubRequest -Uri https://www.githubstatus.com/api/v2/summary.json -JSON) | Select-Object @{n = "Status"; e = {$_.incidents[$Enum.Index.First].status}},@{n = "Message"; e = {$_.incidents[$Enum.Index.First].name+" (" + $_.incidents.Count+")"}}
				#$out += $Preset; 
			}
			$Enum.GitHubPresets.IEDSMode {
				Get-TrackerVMSetMode IEDS
			}
			$Enum.GitHubPresets.IdleMode {
				Get-TrackerVMSetMode Idle
			}
			$Enum.GitHubPresets.InstallerNotSilent {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Enum.PRLabels.NAF
			}
			$Enum.GitHubPresets.InstallerMissing {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Enum.PRLabels.NAF
			}
			$Enum.GitHubPresets.LabelAction {
				Get-PRLabelAction -PR $PR
			}
			$Enum.GitHubPresets.ManuallyValidated {
				$out += Reply-ToPR -PR $PR -Body "Completing validation." -Policy $Enum.PRLabels.MV 
			}
			$Enum.GitHubPresets.MergeConflicts {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Closed -PR $PR -UserInput "Merge Conflicts"
			}
			$Enum.GitHubPresets.NetworkBlocker {
				Write-Output "Use AutomationBlock instead."
			}
			$Enum.GitHubPresets.NoInstallerChange {
				$out += Reply-ToPR -PR $PR -Body "This PR doesn't modify any of the `InstallerUrl` nor `InstallerSha256` fields." -Policy $Enum.PRLabels.MV 
			}
			$Enum.GitHubPresets.OneManifestPerPR {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Enum.GitHubPresets.OneManifestPerPR -Policy $Enum.PRLabels.NAF -Automated
				Get-AddPRLabel -PR $PR -Label $Enum.PRLabels.BI
			}
			$Enum.GitHubPresets.PRNoYamlFiles {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Enum.PRLabels.NAF
				Get-GitHubPreset -Preset $Enum.GitHubPresets.MergeConflicts -PR $PR 
			}
			$Enum.GitHubPresets.PackageUrl {
				Add-PRToRecord -PR $PR -Action $Enum.PRActions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Enum.PRLabels.NAF
			}
			$Enum.GitHubPresets.PossibleDuplicate {
				$Pull = (Invoke-GitHubPRRequest -PR $PR -Type files -Output $Enum.PRRequestOutput.Content -JSON)
				$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[$Enum.Index.First] -JSON).content))
				$Url = (Get-YamlValue -Key InstallerUrl -clip $PullInstallerContents)
				$PackageIdentifier = (Get-SchemaCheck -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier -InputData $PullInstallerContents)
				$Version = (Get-ManifestVersion -PackageIdentifier $PackageIdentifier)
				$out = ($PullInstallerContents -match $Version)
				$UserInput = $out | where {$_ -match "http"} | where {$_ -notmatch "json"} 
				if ($UserInput) {
					$UserInput = "InstallerUrl contains Manifest version instead of PR version:`n" + $UserInput+"`n`n(Automated message - build $build)"
					$out += Reply-ToPR -PR $PR -Body $UserInput -Policy $Enum.PRLabels.NAF
					Add-PRToRecord -PR $PR -Action Feedback
				}
			}
			$Enum.GitHubPresets.Project {
				Add-PRToRecord -PR $PR -Action $Preset
			}
			$Enum.GitHubPresets.RestrictedSubmitter {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Closed -PR $PR -UserInput "Restricted Submitter"
			}
			$Enum.GitHubPresets.ResetApproval {
				$out += Reply-ToPR -PR $PR -Body "Reset approval workflow." -Policy "Reset Feedback `n[Policy] $($Enum.PRLabels.VC) `n[Policy] $($Enum.PRActions.Approved)"
			}
			$Enum.GitHubPresets.Retry {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += Get-RetryPR -PR $PR
			}
			$Enum.GitHubPresets.Squash {
				Add-PRToRecord -PR $PR -Action $Preset
			}
			$Enum.GitHubPresets.Timeclock {
				Get-TimeclockSet
			}
			$Enum.GitHubPresets.Validating {
				Get-TrackerVMSetMode Validating
				$PR = $Enum.Char.Blank
			}
			$Enum.GitHubPresets.Waiver {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += Add-Waiver -PR $PR; 
			}
			$Enum.GitHubPresets.WorkSearch {
				Get-WorkSearch
			}
		}
	} else {
		$out += "Error: $($PR[0..10])"
	}
	Write-Output "PR $($PR): $out"
}

Function Get-PRLabelAction { #Soothing label action.
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[string[]]$PRLabels = ((Invoke-GitHubPRRequest -PR $PR2 -Type labels -Output $Enum.PRRequestOutput.Content -JSON).name)
		# $PRLabelActions = (Get-Content $LabelActionFile | ConvertFrom-Csv),
		# [switch]$Debug
	)
	$PR = $PR2
	Write-Output "PR $PR has labels $PRLabels"
	if ($PRLabels -contains $Enum.PRLabels.VDE) {
		if ($Debug) {Write-Host ($PRLabels -join $Enum.Char.Space)}
		$PRState = Get-PRStateFromComments $PR
		if ($Debug) {Write-Host $PRState}
		if (($PRState | where {$_.event -eq $Enum.PRTrackerStates.PreValidation})[$Enum.Index.Last].($Enum.Strings.CreatedAt) -lt (Get-Date).AddHours(-8)) {# -AND #Last Prevalidation was 8 hours ago.
		#($PRState | where {$_.event -eq $Enum.PRTrackerStates.AutoValEnd})[$Enum.Index.Last].($Enum.Strings.CreatedAt) -lt (Get-Date).AddHours(-12)) { #Last Run was 18 hours ago.
			Get-GitHubPreset Retry -PR $PR
		}
	} else {
		
		Foreach ($Label in ($PRLabels -split $Enum.Char.Space)) {
		if ($Debug) {Write-Host "Label: $Label"}
		$Logset = ($Enum.PRLabelActions | Where-Object {$_.Label -match $Label}).Logset -split $Enum.Char.EscapedPipe
		$StringSet = ($Enum.PRLabelActions | Where-Object {$_.Label -match $Label}).StringSet -split $Enum.Char.EscapedPipe
		$LengthSet = ($Enum.PRLabelActions | Where-Object {$_.Label -match $Label}).LengthSet -split $Enum.Char.EscapedPipe
			Switch -wildcard ($Label) {
				$Enum.PRLabels.403 {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					Get-Autowaiver -PR $PR
				}
				$Enum.PRLabels.ANF {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.BVE {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -length 5
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					if ($UserInput -match $Enum.MagicStrings[3]) {
						#Get-GitHubPreset -PR $PR -Preset $Enum.GitHubPresets.AutomationBlock
					}
				}
				$Enum.PRLabels.CLA {
					Get-ClaCheck -PR $PR
				}
				$Enum.PRLabels.EAT {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 36 -SearchString $Enum.MagicStrings[$Enum.Index.First] -length 4
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					if ($UserInput -match $Enum.MagicStrings[3]) {
						Get-GitHubPreset -PR $PR -Preset $Enum.GitHubPresets.AutomationBlock
					}
				}
				$Enum.PRLabels.EHM {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -length 5
					# $UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 44 -SearchString $Enum.MagicStrings[7] -length 3
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
					}					# Write-Host "a"
					# $UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -Length $LengthSet
					# Write-Host "b"
					# if ($null -ne $UserInput) {
					# Write-Host "c"
						# Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					# Write-Host "d"
						# Get-UpdateHashInPR2 -PR $PR -Clip $UserInput
					# Write-Host "e"
					# }
					# Write-Host "f"
				}
				$Enum.PRLabels.EIA {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 53 -SearchString $Enum.MagicStrings[6] -length 5
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $Enum.MagicStrings[$Enum.Index.First] -Length $Enum.Num.Ten 
					}
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 57 -SearchString $Enum.MagicStrings[$Enum.Index.First] -Length $Enum.Num.Ten 
					}
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $Enum.MagicStrings[$Enum.Index.First] -Length $Enum.Num.Ten 
					}
					if ($UserInput) {
						$UserInput = Get-AutomatedErrorAnalysis $UserInput
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
						Get-GitHubPreset -PR $PR -Preset $Enum.GitHubPresets.CheckInstaller
					}
				}
				$Enum.PRLabels.HVF {
					Get-AutoValLog -PR $PR
				}
				$Enum.PRLabels.HVL {
					Approve-PR -PR $PR
				}
				$Enum.PRLabels.HVR {
					Approve-PR -PR $PR
				}
				$Enum.PRLabels.IE {
					if ($Debug) {Write-Host "Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet"}
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -WhatIf
					if ($Debug) {Write-Host "UserInput Len $($UserInput.Length)"}
					if ($UserInput) {
						if (($Enum.MagicStrings[5] -in $UserInput) -OR ("Server Unavailable" -in $UserInput)) {
							Get-GitHubPreset -PR $PR Retry
						}
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.IEDS {
					#Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Enum.PRLabels.IEM {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 15 -SearchString $Enum.MagicStrings[$Enum.Index.Second]
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 30 -SearchString $Enum.MagicStrings[13]
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $Enum.MagicStrings[4] -length 7
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 39 -SearchString $Enum.MagicStrings[4] -length 7
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $Enum.MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 46 -SearchString $Enum.MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 47 -SearchString $Enum.MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
						if ($UserInput -match $Enum.StandardPRComments.SequenceNoElements) {#Reindex fixes this.
							Reply-ToPR -PR $PR -CannedMessage SequenceNoElements
							$PRtitle = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content -JSON).title)
							if (($PRtitle -match $Enum.PRWatch.AutomaticDeletion) -OR ($PRtitle -match $Enum.PRWatch.Remove)) {
								Get-GitHubPreset -Preset $Enum.GitHubPresets.Completed -PR $PR
							}
						}
					}
				}
				$Enum.PRLabels.IEMI {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.IEU {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $Enum.MagicStrings[$Enum.Index.Second]
					if ($UserInput) {
						if ($Enum.MagicStrings[5] -in $UserInput) {
							Get-GitHubPreset -PR $PR Retry
						}
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.LVR {
					Approve-PR -PR $PR
				}
				$Enum.PRLabels.MIVE {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.MMC {
					if ((($PRLabels -join $Enum.Char.Space) -match $Enum.PRLabels.VC)) {
						Get-VerifyMMC -PR $PR
					}					
				}
				$Enum.PRLabels.MVE {#One of these is VER.
					if ($Debug) {Write-Host " Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet"}
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						if ($Debug) {Write-Host "UserInput: $UserInput"}
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd -Automated
					}
				}
				$Enum.PRLabels.MVE {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $Enum.MagicStrings[2]
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $Enum.MagicStrings[$Enum.Index.Second]
					}
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd -Automated
					}
				}
				$Enum.PRLabels.NMM {
					# if ($PRLabels -notcontains $Enum.PRLabels.BI) {
						# Approve-PR -PR $PR
						# Get-MergePR -PR $PR
					# }
				}
				$Enum.PRLabels.NP {
					if ((($PRLabels -join $Enum.Char.Space) -notmatch $Enum.PRLabels.MA)) {
						Add-PRToQueue -PR $PR
					}
				}
				$Enum.PRLabels.PD {
					Get-DuplicateCheck -PR $PR
				}
				$Enum.PRLabels.PRE {
					# $UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 36 -SearchString $Enum.MagicStrings[13] -Length 0
					# if ($Debug) {
						# Write-Host "Debug"
						# $UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -Length $LengthSet -WhatIf
					# } else {
						$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet 
						# $UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -Length $LengthSet
					# }
					

					if ($UserInput -match $Enum.Strings.OneManifestPerPR) {
						Get-GitHubPreset -Preset $Enum.GitHubPresets.OneManifestPerPR -PR $PR
					} elseif ($UserInput -match $Enum.Strings.PRNoYamlFiles) {
						Get-GitHubPreset -Preset $Enum.GitHubPresets.PRNoYamlFiles -PR $PR
					} elseif ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd -Automated
					}
				}
				$Enum.PRLabels.UVE {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 32 -SearchString $Enum.Strings.ValidationResultFailed
					Get-GitHubPreset -PR $PR -Preset $Enum.GitHubPresets.CheckInstaller
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					Get-Autowaiver -PR $PR
				}
				$Enum.PRLabels.VC {
				}
				$Enum.PRLabels.VD {
					Get-Autowaiver -PR $PR
				}
				$Enum.PRLabels.VEE {
					Get-AutoValLog -PR $PR
					Get-RerunCheck -PR $PR
				}
				$Enum.PRLabels.VIE {
					Get-AutoValLog -PR $PR
					Get-Autowaiver -PR $PR
				}
				$Enum.PRLabels.VMD {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $Enum.MagicStrings[$Enum.Index.Second]
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Enum.PRLabels.VMC {
				}
				$Enum.PRLabels.VNE {
 					Get-Autowaiver -PR $PR
<#
 					$Title = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content -JSON).title);
					foreach ($Waiver in (Get-ValidationData -Property AutoWaiverLabel)) {
						if ($Title -match $Waiver.PackageIdentifier) {
							Get-GitHubPreset -PR $PR Waiver
						}
					}
 #>
				}
				$Enum.PRLabels.VSE {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Enum.PRLabels.VUF {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Enum.PRLabels.VUE {
					Get-Autowaiver -PR $PR
				}
				$Enum.PRLabels.VUU {
					Get-Autowaiver -PR $PR
				}
				"Policy-Test-*" {
					Get-Autowaiver -PR $PR
				}
			}#end Switch Label
		}#end Foreach Label
	}#end if PRLabels
}

Function Get-ScheduledRun {
		# [console]::beep(500,250);[console]::beep(500,250);[console]::beep(500,250) #Beep 3x to alert the PC user.
		if ($preprod) {
			$Host.UI.RawUI.WindowTitle = "PREPROD-Periodic Run"
		} else {
			$Host.UI.RawUI.WindowTitle = "Periodic Run"
		}
		
		#Check for yesterday's report and create if missing. 
		$Month = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month)
		md "$logsFolder\$Month" -ErrorAction SilentlyContinue
		$Yesterday = (get-date).AddDays(-1)
		$YesterdayFormatted = (get-date $Yesterday -f MMddyy)
		$ReportName = "$logsFolder\$Month\Stats\$YesterdayFormatted-Report.csv"
		if (Get-Content $ReportName -ErrorAction SilentlyContinue) {
			Write-Host "Report for $YesterdayFormatted found."
		} else {
			Write-Host "Report for $YesterdayFormatted not found."
			#And everything else that should run once every 24h.
			Get-PRFullReport -Today $YesterdayFormatted
			Get-CleanPRExcludeFile
			Get-CleanPRFolder
			Get-RepoCountReport
			(Get-SearchGitHub None -Label $Enum.PRLabels.MVC).number | %{Open-PRInBrowser -PR $_}
		}
		
		Get-StaleVMCheck
		
		$PresetList2 = $Enum.PRLabels.CLA, $Enum.PRLabels.VIE, $Enum.PRLabels.VEE, $Enum.PRLabels.VSE, $Enum.PRLabels.VD, $Enum.PRLabels.VUU, $Enum.PRLabels.VIE, $Enum.PRLabels.PT12, $Enum.PRLabels.PT18, $Enum.PRLabels.PT23, $Enum.PRLabels.PT27, "New-Package label:New-Manifest";
		foreach ($Preset in $PresetList2) {
			$Results = (Get-SearchGitHub -Preset None -Label $Preset -DaysAgo 1).number; 
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) Starting $Preset with $($Results.Length) Results"
			if ($Results) {
				foreach ($PR in $Results) {
					Get-ClaCheck -PR $PR
					# switch ($Preset) {
						# "New-Package label:New-Manifest" {
							# Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.NP
						# }
						# Default {
							Get-PRLabelAction -PR $PR
						# }
					# }
				}
			}#end if Results12
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) Completing $Preset with $($Results.Length) Results"
		}#End for preset

		$PresetList = ($Enum.SearchPresets.Defender,$Enum.SearchPresets.Duplicate,$Enum.SearchPresets.HVR,$Enum.SearchPresets.IEDS,$Enum.SearchPresets.LVR,$Enum.SearchPresets.MMC,$Enum.SearchPresets.NMM,$Enum.SearchPresets.ToWork3,$Enum.SearchPresets.Approval,$Enum.SearchPresets.VCMA)
		foreach ($Preset in $PresetList) {
			$Results = (Get-SearchGitHub -Preset $Preset -nBMM -DaysAgo 1).number
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) Starting $Preset with $($Results.Length) Results"
			if ($Results) {
				switch ($Preset) {
					$Enum.SearchPresets.Approval {
						$Results = (Get-SearchGitHub Approval -NewPackages -DaysAgo 1).number 
						$Results | %{Get-ClaCheck -PR $_;Add-PRToQueue -PR $_}
					}
					$Enum.SearchPresets.Approval2 {
						$Results | %{
							Write-Output "$(get-date): $_";
							Get-ClaCheck -PR $_;
							Get-PRManifest -pr $_ | clip; 
							sleep 5
						}
					}
					$Enum.SearchPresets.IEDS {
						$Results | %{Get-ClaCheck -PR $_;Add-PRToQueue -PR $_}
					}
					$Enum.SearchPresets.VCMA {
						$GitHubResults = Get-SearchGitHub VCMA #-DaysAgo 1
						$AnHourAgo = (get-date).AddHours(-1)
						$Results = ($GitHubResults | where {[TimeZone]::CurrentTimeZone.ToLocalTime($_.updated_at) -lt $AnHourAgo}).number 
						#Time, as a number, is always increasing. So the past is always less than the present, which is always less than the future.
						$Results | %{Get-ClaCheck -PR $_;Approve-PR -PR $_;Get-MergePR -PR $_}
					}
					Default {
						$Results | %{Get-ClaCheck -PR $_;Get-PRLabelAction -PR $_ }
					}
				}#end switch Preset
			}#end if Results12
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) Completing $Preset with $($Results.Length) Results"
		}#End for preset
		
			Write-Output "$(Get-Date -Format $($Enum.Char.T)) Starting $Preset with $($Results.Length) Results"

		
		Write-Output "$(Get-Date -Format $($Enum.Char.T)) Starting PushMePRYou with $($Enum.PushMePRWho.Count) Results"
		$Enum.PushMePRWho | %{Write-Host $_.Author;Get-PushMePRYou -Author $_.Author -MatchString $_.MatchString}
		Write-Output "$(Get-Date -Format $($Enum.Char.T)) Completing PushMePRYou with $($Enum.PushMePRWho.Count) Results"
		if (([int](get-date -f mm) -eq 20) -OR ([int](get-date -f mm) -eq 50)) {
			sleep (60-(get-date -f ss))#Sleep out the minute.
		}
}

Function Get-StaleVMCheck {
	if ((get-date) -gt $NextStaleCheck) {
		$VMStatus = Get-Content $statusFile | convertfrom-csv
		$CheckVMStatus = ($VMStatus | where {$_.status -ne $Enum.VMStatus.Ready} | where {$_.status -ne $Enum.VMStatus.LongRunning})
		Write-Output "$(Get-Date -Format $($Enum.Char.T)) Starting stale VM check with $($CheckVMStatus.Count) Results"
		foreach ($vm in $CheckVMStatus) {
			if ($VM.pr -ne 1) {
				$vmNum = $vm.vm
				$PRState = (Invoke-GitHubPRRequest -PR $VM.pr -Type $Enum.PRRequestTypes.Blank -Output Content).state;
				$PRLabels = ((Invoke-GitHubPRRequest -PR $VM.pr -Type $Enum.PRRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name)
				if ($null -ne $PRState) {
					if (($PRState -ne $Enum.PRStates.Open) -OR
						(($PRLabels -join $Enum.Char.Space) -match $Enum.PRLabels.CR)){
						Get-TrackerVMSetStatus -Status $Enum.VMStatus.Complete -VM $vmNum
						Suspend-VM -Name "vm$vmNum"
					} #end if PRState.state
				} #end if null
			} #end VM.pr
		} #end foreach vm
		Write-Output "$(Get-Date -Format $($Enum.Char.T)) Completing stale VM check with $($CheckVMStatus.Count) Results"
		$NextStaleCheck = (Get-Date).AddMinutes(5)
	}
}

Function Get-RerunCheck {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Comments = (Get-PRComments -PR $PR2),
		[int]$MatchCode = $Enum.RerunCheck.MatchCode,
		[int]$RetryCount = $Enum.Num.Two,
		[string]$MatchTerm = $Enum.Strings.ValidationPipelineRun,
		[switch]$WhatIf
	)
	Process {
		$PR = $PR2
		$LastAutomationComment = $Enum.Char.Blank
		$ValPipeRunCount = 0
		try {
			$LastAutomationComment = ($Comments | Where-Object {$_.user.login -eq $Enum.GitHubUserNames.GitHubUserName})[$Enum.Index.Last].body -join $Enum.Char.Space
		} catch {}#If this fails, I don't care. It's already the empty string it needs to be. 
		try {
			$ValPipeRunCount = ($Comments.body | where {$_ -match $MatchTerm}).Count
		} catch {}#If this fails, I don't care. It's already the zero it needs to be. 
		#IF contains MatchCode
		#If only 1 retry
		if (($LastAutomationComment -match $MatchCode) -OR
		($ValPipeRunCount -lt $RetryCount)) {
			Write-Host "Checking PR $PR"
			if ($WhatIf) {
				Write-Host "Reply-ToPR -PR $pr -body '$($Enum.Strings.WingetbotRun)'"
			} else {
				Reply-ToPR -PR $pr -body $Enum.Strings.WingetbotRun
			}
		} else {
			Write-Host "PR $PR is workable, adding to queue."
			Add-PRToQueue -PR $PR
			Return
		}
	}
}

Function Get-LogFromCommitFile {
	Param(
		[int]$PR,
		[array]$LogNumbers,
		[array]$StringNumbers,
		$Length = 0,
		[switch]$WhatIf
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	Foreach ($Log in $LogNumbers) {
		$n = 0;
		if ($WhatIf) {Write-Host "Log: $log"}
		while ($n -le ($StringNumbers.Count -1)) {
			try {
				if ($WhatIf) {
					Write-Host "n $n - Get-LineFromBuildResult -PR $PR -LogNumber $Log -SearchString $($Enum.MagicStrings[$StringNumbers[$n]]) -Length $Length - UserInput $UserInput"
				} else {
					$UserInput += Get-LineFromBuildResult -PR $PR -LogNumber $Log -SearchString $Enum.MagicStrings[$StringNumbers[$n]] -Length $Length
				}
			} catch {}
			$n++
		}
	}

	if ($WhatIf) {
		Write-Host "return $UserInput"
	} else {
		return $UserInput
	}
}

<#
Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet[$Enum.Index.First] -StringNumbers $StringSet[$Enum.Index.First] -WhatIf
Log: 36
n 0 - Get-LineFromBuildResult -PR 369299 -LogNumber 36 -SearchString -Length 0 - UserInput
return
A few minutes later...
Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet[$Enum.Index.First] -StringNumbers $StringSet[$Enum.Index.First] -WhatIf
Log: 36
n 0 - Get-LineFromBuildResult -PR 369299 -LogNumber 36 -SearchString [error] -Length 0 - UserInput
return
#>

Function Add-Waiver {
	Param(
		[int]$PR,
		$LabelNames = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.prRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name)
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	Foreach ($Label in $LabelNames) {
		$Waiver = $Enum.Char.Blank
		Switch ($Label) {
			$Enum.PRLabels.EAT {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Completed -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.PT27 {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.PT12 {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.PT23 {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.VC {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Approved -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Num.Two]
			}
			$Enum.PRLabels.VD {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.VEE {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
				$Waiver = $Label
			}
			$Enum.PRLabels.403 {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VIE {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VNE {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VSE {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VUF {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VUE {
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.Second]
				$Waiver = $Label
			}
			$Enum.PRLabels.VR {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Completed -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
			}
			$Enum.PRLabels.IEDS {
				Get-GitHubPreset -Preset $Enum.GitHubPresets.Completed -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[$Enum.Index.First]
			}
		}
		if ($Waiver -ne $Enum.Char.Blank) {
			$out = Get-CompletePR -PR $PR 
			Write-Output $out
		}; #end if Waiver
	}; #end Foreach Label
}; #end Add-Waiver

Function Get-CannedMessage {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.CannedMessages)} )][string[]]$Response,
		$UserInput,
		[switch]$NoClip,
		[switch]$NotAutomated
	)
	[string]$Username = $Enum.Char.Ampersand + $UserInput.replace($Enum.Char.Space,$Enum.Char.Blank) + $Enum.Char.Comma
	switch ($Response) {
		$Enum.CannedMessages.AgreementMismatch {
			$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
			$AgreementUrlFromList = ($AgreementsList | where {$_.PackageIdentifier -eq $PackageIdentifier}).AgreementUrl
			$out = "Hi $Username`n`nThis package uses Agreements, but this manifest's AgreementsUrl doesn't match the AgreementsUrl on file: $AgreementUrlFromList"
		}
		$Enum.CannedMessages.AppsAndFeaturesNew {
			$out = "Hi $Username`n`nThis manifest adds a `DisplayVersion` to the `AppsAndFeaturesEntries` that isn't present in previous manifest versions. This entry should be added to the previous versions, or removed from this version."
		}
		$Enum.CannedMessages.AppsAndFeaturesMissing {
			$out = "Hi $Username`n`nThis manifest removes the `DisplayVersion` from the `AppsAndFeaturesEntries`, which is present in previous manifest versions. This entry should be added to this version, to maintain version matching, and prevent the 'upgrade always available' situation with this package."
		}
		$Enum.CannedMessages.AppsAndFeaturesMatch {
			$out = "Hi $Username`n`nThis manifest uses the same values for `DisplayVersion` and `PackageVersion`. This is not recommended, and the `DisplayVersion` should be removed."
		}
		$Enum.CannedMessages.AppFail {
			$out = "Hi $Username`n`nThe application installed normally, but gave an error instead of launching:`n"
		}
		$Enum.CannedMessages.Approve {
			$out = "Hi $Username`n`nDo you approve of these changes?"
		}
		$Enum.CannedMessages.AutoValEnd {
			$UserInput = Get-AutomatedErrorAnalysis ($UserInput -join $Enum.Char.LineBreak)
			$out = "Automatic Validation ended with: `n> $UserInput"
		}
		$Enum.CannedMessages.DriverInstall {
			$out = "Hi $Username`n`nThe installation is unattended, but installs a driver which isn't unattended:`nUnfortunately, installer switches are not usually provided for this situation. Are you aware of an installer switch to have the driver silently install as well?"
		}
		$Enum.CannedMessages.DoesntRun {
			$out = "Hi $Username`n`nThis package seems to install normally, but doesn't run when launched. Is this expected? Manual Validation ended with: `n> $UserInput"
		}
		$Enum.CannedMessages.InstallerFail {
			$out = "Hi $Username`n`nThe installer did not complete:`n"
		}
		$Enum.CannedMessages.InstallerMissing {
			$out = "Hi $Username`n`nHas the installer been removed?"
		}
		$Enum.CannedMessages.InstallerNotSilent {
			$out = "Hi $Username`n`nThe installation isn't unattended. Is there an installer switch to have the package install silently?"
		}
		$Enum.CannedMessages.ListingDiff {
			$out = "This PR omits these files that are present in the current manifest:`n> $UserInput"
		}
		$Enum.CannedMessages.ManifestVersion {
			$out = "Hi $Username`n`nWe don't often see the `1.0.0` manifest version anymore. Would it be possible to upgrade this to the [1.12.0]($GitHubBaseUrl/tree/master/doc/manifest/schema/1.12.0) version, possibly through a tool such as [WinGetCreate](https://learn.microsoft.com/en-us/windows/package-manager/package/manifest?tabs = minschema%2Cversion-example), [YAMLCreate]($GitHubBaseUrl/blob/master/Tools/YamlCreate.ps1), or [Komac](https://github.com/russellbanks/Komac)? "
		}
		$Enum.CannedMessages.ManValEnd {
			$UserInput = Get-AutomatedErrorAnalysis ($UserInput -join $Enum.Char.LineBreak)
			$out = "Manual Validation ended with: `n> $UserInput"
		}
		$Enum.CannedMessages.MergeFail {
			if ($UserInput -match "Required status check") {
				$UserInput += "<!--`n[Policy] Needs-CLA`n-->"
			}
			$out = "Merging failed with:`n> $UserInput"
		}
		$Enum.CannedMessages.NoExe {
			$out = "Hi $Username`n`nThe installer doesn't appear to install any executables, only supporting files:`n`nIs this expected?"
		}
		$Enum.CannedMessages.NotGoodFit {
			$out = "Hi $Username`n`nUnfortunately, this package might not be a good fit for inclusion into the WinGet public manifests. Please consider using a local manifest (`WinGet install --manifest C:\path\to\manifest\files\`) for local installations. "
		}
		$Enum.CannedMessages.OneManifestPerPR {
			$out = "Hi $Username`n`nWe have a limit of 1 manifest change, addition, or removal per PR. This PR modifies more than one PR. Can these changes be spread across multiple PRs?"
		}
		$Enum.CannedMessages.Only64bit {
			$out = "Hi $Username`n`nValidation failed on the $($Enum.Arch.86) package, and $($Enum.Arch.86) packages are validated on 32-bit OSes. So this might be a 64-bit package."
		}
		$Enum.CannedMessages.PackageFail {
			$out = "Hi $Username`n`nThe package installs normally, but fails to run:`n"
		}
		$Enum.CannedMessages.PackageUrl {
			$out = "Hi $Username`n`nCould you add a PackageUrl?"
		}
		$Enum.CannedMessages.PolicyWrapper {
			$out = "<!--`n[Policy] $UserInput`n-->"
		}
		$Enum.CannedMessages.PRNoYamlFiles {
			$out = "Hi $Username`n`nThis error means that this PR diff Master had no output. In other words, it's like a merge conflict.`n> The pull request doesn't include any manifest files yaml."
		}
		$Enum.CannedMessages.RemoveAsk {
			$out = "Hi $Username`n`nThis package installer is still available. Why should it be removed?"
		}
		$Enum.CannedMessages.Unavailable {
			$out = "Hi $Username`n`nThe installer isn't available from the publisher's website:"
		}
		$Enum.CannedMessages.Unattended {
			$out = "Hi $Username`n`nThe installation isn't unattended:`n`nIs there an installer switch to bypass this and have it install automatically?"
		}
		$Enum.CannedMessages.UrlBad {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
		}
		$Enum.CannedMessages.VersionCount {
			$out = "Hi $Username`n`nThis manifest has the highest version number for this package. Is it available from another location? (This might be in error if the version is switching from semantic to string, or string to semantic.)"
		}
		$Enum.CannedMessages.WhatIsIEDS {
			$out = "Hi $Username`n`nThe label `Internal-Error-Dynamic-Scan` is a blanket error for one of a number of internal pipeline errors or issues that occurred during the Dynamic Scan step of our validation process. It only indicates a pipeline issue and does not reflect on your package. Sorry for any confusion caused."
		}
		$Enum.CannedMessages.WordFilter {
			$out = "This manifest contains a term that is blocked:`n`n> $UserInput"
		}
		Default {
			$out = $Enum.CannedMessageResponses.($Response)
		}
	}
	if (!($NotAutomated)) {
		$out += "`n`n(Deterministic automation - build $build.)"
	}
	if ($NoClip) {
		$out
	} else {
		$out |clip
	}
}

Function Get-AutomatedErrorAnalysis {
	Param(
		$UserInput,
		$Spacer = " | "
	)

	#$UserSplit = $UserInput -replace "0x",$Enum.Char.Blank -replace "[^\w]",$Enum.Char.Space -split $Enum.Char.Space
	$UserInput = ($UserInput -split $Enum.Char.LineBreak) | where {$_ -notmatch 'Winget errors'}
	$UserInput = ($UserInput -split $Enum.Char.LineBreak) | where {$_ -notmatch 'attempting win'}
	$UserJoin = $UserInput -join $Enum.Char.Space -replace $Enum.Char.LineBreak,$Enum.Char.Blank -replace $Enum.Char.CarriageReturn,$Enum.Char.Blank
	$UserSplit = $UserJoin -replace "0x",$Enum.Char.Space -replace $Enum.Char.EscapedOpenParens,$Enum.Char.Space -replace ">",$Enum.Char.Space -replace "<",$Enum.Char.Space -split $Enum.Char.Space
	$UserSplit = $UserSplit | Sort-Object -Unique
	[array]$UserArray = ($UserInput -join $Enum.Char.LineBreak)
	
	# Write-Host "UserJoin $UserJoin"
	# Write-Host "UserInput $UserInput"
	# Write-Host "UserArray $($UserArray -join '`n')"
	
	if ($UserJoin -match "exit code" -OR 
	$UserJoin -match "DeliveryOptimization error" -OR 
	$UserJoin -match "Installer failed security check" -OR 
	$UserJoin -match "Error information") {
		$ExitCodeTable = Get-Content $ExitCodeFile | ConvertFrom-Csv

		$UserArray += "$($Enum.Char.LineBreak) $($Enum.Char.LineBreak) | Hex | Dec | Inverted Dec | Symbol | Description | $($Enum.Char.LineBreak) | --- | --- | --- | --- | --- | $($Enum.Char.LineBreak)"
		foreach ($ExitCode in $ExitCodeTable) {
			foreach ($Word in $UserSplit) {
				if (($Word -eq $ExitCode.Hex) -OR ($Word -eq $ExitCode.Dec) -OR ($Word -eq $ExitCode.InvDec) ) {
					$UserArray += $Spacer + $ExitCode.Hex + $Spacer + $ExitCode.Dec + $Spacer + $ExitCode.InvDec + $Spacer + $ExitCode.Symbol + $Spacer + $ExitCode.Description + $Spacer + $Enum.Char.LineBreak
					}# end if word
				}# end foreach word
			}#end foreach exitcode
		}#end if userinput 
	$UserArray = $UserArray | Select-Object -Unique
	return $UserArray
}#end function 

Function Get-DownloadADOFile {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$DestinationPath = "$MainFolder\Installers",
		[string]$LogPath = "$DestinationPath\ValidationResult\",
		[string]$ZipPath = "$DestinationPath\ValidationResult.zip",
		[int]$RetriesLimit = $Enum.Num.Ten,
		[switch]$CleanoutDirectory,
		[switch]$WhatIf,
		[switch]$Force,
		[switch]$Silent,
		$notes = $Enum.Char.Blank
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$PRState = Get-PRStateFromComments $PR
	$FileList = $null
	[int]$BackoffSeconds = 0
	[int]$Retries = 0
	$ArtfiactUrl = $Enum.Char.Blank
	$DownloadSeconds = 8;
	if ($Preprod) {
		$BuildNumber = 1
	} else {
		$BuildNumber = Get-BuildFromPR -PR $PR 
	}
	if ($BuildNumber -gt 0) {
		while ($FileList -eq $null) {
			try {
				#This downloads to Windows default location, which has already been set to $DestinationPath
					if ($Preprod) {
						$CheckData = Get-CheckData -PR $PR | where {$_.name -match "Validation Completed"}
						$ArtfiactUrl = (($CheckData.output.text -split $Enum.Char.LineBreak | select-string "zip")[$Enum.Index.Last] -split $Enum.Char.DoubleQuote)[3]
					} else {
						$ArtfiactUrl = "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$BuildNumber/artifacts?artifactName = ValidationResult&api-version = 7.1&%24format = zip"
					}
					Start-Process $ArtfiactUrl
				if ($WhatIf) {
					Write-Host $ArtfiactUrl
				}
				Start-Sleep $DownloadSeconds;
				[bool]$IsZipPath = (Test-Path $ZipPath)
				if ($WhatIf) {
					Write-Host "IsZipPath $IsZipPath"
				}
				if (!$IsZipPath) {
					if ($Retries -ge $RetriesLimit) {
						$UserInput = "No logs after $Retries retries."
						if ($WhatIf) {
							Write-Host "Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
						} else {
							$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
						}
						Write-Host $UserInput
						Break;
					} else {
						Write-Host "Retry $Retries of $RetriesLimit"
					}
					$Retries++
				} 
				Remove-Item $LogPath -Recurse -ErrorAction Ignore
				Expand-Archive $ZipPath -DestinationPath $DestinationPath;
				Remove-Item $ZipPath
				if ($CleanoutDirectory) {
					Get-ChildItem $DestinationPath | Remove-Item -Recurse
				}
				$FileList = (Get-ChildItem $LogPath).FullName
			} catch {
				if ($BackoffSeconds -gt 60) {
					$UserInput = "Build $BuildNumber not found."
				}
				$AddSeconds = Get-Random -min $Enum.Num.One -max 5
				$BackoffSeconds += $AddSeconds
				Write-Host "Can't access $DestinationPath or a subfolder. Backing off another $AddSeconds seconds, for $BackoffSeconds total seconds."
				sleep $BackoffSeconds
			}
		}
	}
}

Function Get-ValidationResult {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR
	)
	Write-Host "Get-ValidationResult PR $PR"
	$BuildNumber = Get-BuildFromPR -PR $PR 
	
	$ValidationResultUrl = "https://dev.azure.com/shine-oss/8b78618a-7973-49d8-9174-4360829d979b/_apis/build/builds/$BuildNumber/"
	$ValidationResultData = Invoke-GitHubRequest $ValidationResultUrl
	$ValidationResult = $ValidationResultData | ConvertFrom-Json
	
		if (($ValidationResult.status -eq "completed") -and ($ValidationResult.result -eq "succeeded")) {
			Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.VC
		} else {
		Get-DownloadADOFile -PR $PR -RetriesLimit 1
		$ResultFileName = "InstallationVerification_Result.json"
		
		$DestinationPath = "$MainFolder\Installers"
		$ValidationResultPath = "$DestinationPath\ValidationResult\"
		
		$PackageIdentifier = (Get-SchemaCheck -InputData (ls $ValidationResultPath)[$Enum.Index.First].name -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
		$ValidationResultPath += "$PackageIdentifier\"
		$PackageVersion = (ls $ValidationResultPath)[$Enum.Index.First].name
		$ValidationResultPath += "$PackageVersion\"
		$ResultFilePath = (ls $ValidationResultPath).fullname | where {$_ -match $ResultFileName}
		
		if ($ResultFilePath) {
			$OverallResult = (Get-Content $ResultFilePath | ConvertFrom-Json).OverallResult
			if ($OverallResult -eq "Success") {
				Write-Host "$($PR): Success"
			} else {
				Write-Host "$($PR): $LabelName"
				$LabelName = (Get-Content $ResultFilePath | ConvertFrom-Json).TestplansResults.TestPlan
				Get-AddPRLabel -PR $PR -LabelName $LabelName
			}
		}
	}
}

Function Get-AutoValLog {
	#Needs $GitHubToken to be set up in your -PR $PROFILE or somewhere more secure. Needs permissions: workflow,
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		$BuildNumber = (Get-BuildFromPR -PR $PR2),
		[switch]$CleanoutDirectory,
		[switch]$WhatIf,
		[switch]$Force,
		[switch]$Silent,
		$notes = $Enum.Char.Blank
	)
	$PR = $PR2
	Write-Host "Gathering data for PR $PR"
	$PRState = Get-PRStateFromComments $PR
	$FileList = $null
	[int]$BackoffSeconds = $Enum.Num.Zero
	[int]$Retries = $Enum.Num.Zero
	[int]$RetriesLimit = 1
	$ArtfiactUrl = $Enum.Char.Blank
		
	if ((!($PRState | where {$_.event -eq $Enum.PRTrackerStates.AutoValEnd})) -OR (($PRState | where {$_.event -eq $Enum.PRTrackerStates.PreValidation})[$Enum.Index.Last].($Enum.Strings.CreatedAt) -gt ($PRState | where {$_.event -eq $Enum.PRTrackerStates.AutoValEnd})[$Enum.Index.Last].($Enum.Strings.CreatedAt)) -OR ($Force)) { #Last Prevalidation was 8 hours ago.
	$DownloadSeconds = 8;
	$LowerOps = $true;
	$WaiverList = Get-ValidationData -Property AutoWaiverLabel
	#Get-Process *photosapp* | Stop-Process
	if ($Preprod) {
		$BuildNumber = 1
	} else {
		
	}

	if ($BuildNumber -gt $Enum.Num.Zero) {
		while ($null -eq $FileList) {
			try {
				#This downloads to Windows default location, which has already been set to $DestinationPath
				if ($Preprod) {
					$ZipPath = "$DestinationPath\WinGetSvc-Validation-Ppe-$PR-3-artifacts.zip"
					
					$CheckData = Get-CheckData -PR $PR | where {$_.name -match "Validation Completed"}
					$ArtfiactUrl = (($CheckData.output.text -split $Enum.Char.LineBreak | select-string "zip")[$Enum.Index.Last] -split $Enum.Char.DoubleQuote)[3]
				} else {
					$ArtfiactUrl = "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$BuildNumber/artifacts?artifactName=InstallationVerificationLogs&api-version=7.1&%24format=zip"
				}
				Start-Process $ArtfiactUrl
				if ($WhatIf) {
					Write-Host $ArtfiactUrl
				}
				Start-Sleep $DownloadSeconds;
				[bool]$IsZipPath = (Test-Path $ZipPath)
				if ($WhatIf) {
					Write-Host "IsZipPath $IsZipPath"
				}
				if (!$IsZipPath) {
					if ($Retries -ge $RetriesLimit) {
						$UserInput = "No logs after $Retries retries."
						if ($WhatIf) {
							Write-Host "Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
						} else {
							if ($Force) {
								$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd
							} else {
								$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
							}
						}
						Write-Host $UserInput
						Break;
					} else {
						Write-Host "Retry $Retries of $RetriesLimit"
					}
					$Retries++
				} 
				Remove-Item $LogPath -Recurse -ErrorAction Ignore
				Expand-Archive $ZipPath -DestinationPath $DestinationPath;
				Remove-Item $ZipPath
				if ($CleanoutDirectory) {
					Get-ChildItem $DestinationPath | Remove-Item -Recurse
				}
				$FileList = (Get-ChildItem $LogPath).FullName
			} catch {
				if ($BackoffSeconds -gt 60) {
					$UserInput = "Build $BuildNumber not found."
				}
				$AddSeconds = Get-Random -min 1 -max 5
				$BackoffSeconds += $AddSeconds
				Write-Host "Can't access $DestinationPath or a subfolder. Backing off another $AddSeconds seconds, for $BackoffSeconds total seconds."
				sleep $BackoffSeconds
			}
		}
			
		[Array]$UserInput = $null
		foreach ($File in $filelist) {
			$UserInput += (Get-Content $File) -split $Enum.Char.LineBreak
		}
		$UserInput = $UserInput | Where-Object {
			$_ -match '[[]FAIL[]]' -OR 
			$_ -match 'error' -OR 
			$_ -match 'exception' -OR 
			$_ -match 'exit code' -OR 
			$_ -match 'fail' -OR 
			$_ -match 'manual review' -OR 
			$_ -match 'No suitable' -OR 
			$_ -match 'not supported' -OR #not supported by this processor type
			#$_ -match 'not applicable' -OR 
			$_ -match 'unwanted' -OR #PUA
			$_ -match 'Unable to locate nested installer' -OR
			$_ -match 'space' -OR
			$_ -match 'cannot install' 
		}
		if ($WhatIf) {
			Write-Host "File $File - UserInput $UserInput Length $($UserInput.Length)"
		}
		$UserInput = $UserInput | Select-Object -Unique; #-split $Enum.Char.LineBreak
		$UserInput = $UserInput -replace "Standard error: ",$null
		$UserReplace = $UserInput -replace "\\","\\" -replace "\[","\[" -replace "\]","\]" -replace "\*","\*" -replace "\+","\+" -replace "\s",$Enum.Char.Blank -join $Enum.Char.Blank
		[bool]$isnotnull = ($null -notmatch $UserReplace)
		if ($WhatIf) {
			Write-Host "UserReplace 1 $UserReplace - notmatch null $isnotnull (true is populated, false is null)"
		}

		if ($isnotnull) {
			if (($UserInput -match "Installer failed security check") -OR ($UserInput -match "Operation did not complete successfully because the file contains a virus or potentially unwanted software")) {
				$LowerOps = $false
				#$UserInput = Get-AutomatedErrorAnalysis $UserInput
				Write-Host "DefenderFail - UserInput $UserInput"
			}
			if ($UserInput -match "SQL error or missing database") {
				Get-GitHubPreset Retry -PR $PR
					if (!($Silent)) {
						Write-Output "PR $PR - SQL error or missing database"
					}
				Open-PRInBrowser -PR $PR
			}

				# $UserInput = $UserInput -split $Enum.Char.LineBreak
				$UserInput = $UserInput -notmatch " success or error status`: 0"
				$UserInput = $UserInput -notmatch "``Windows Error Reporting``"
				$UserInput = $UserInput -notmatch "--- End of inner exception stack trace ---"
				$UserInput = $UserInput -notmatch "2: 3: Error"
				$UserInput = $UserInput -notmatch "Property\(S\)"
				$UserInput = $UserInput -notmatch "AppInstallerRepositoryCore"
				$UserInput = $UserInput -notmatch "api-ms-win-core-errorhandling"
				$UserInput = $UserInput -notmatch "appropriate application package"
				$UserInput = $UserInput -notmatch "because the current user does not have that package installed"
				$UserInput = $UserInput -notmatch "Cannot create a file when that file already exists"
				$UserInput = $UserInput -notmatch "Could not create system restore point"
				$UserInput = $UserInput -notmatch "Dest filename"
				$UserInput = $UserInput -notmatch "DismHost"
				$UserInput = $UserInput -notmatch "Element not found"
				$UserInput = $UserInput -notmatch "Error occurred while trying to capture screenshot"
				$UserInput = $UserInput -notmatch "Exception during executable launch operation System.InvalidOperationException: No process is associated with this object."
				$UserInput = $UserInput -notmatch "exception thrown when getting"
				$UserInput = $UserInput -notmatch "Exit code`: 0"
				$UserInput = $UserInput -notmatch "Failed to open available source: msstore"
				$UserInput = $UserInput -notmatch "GetLastError@kernel32.dll"
				$UserInput = $UserInput -notmatch "IconContent"
				$UserInput = $UserInput -notmatch "ISWEBVIEW2INSTALLED"
				$UserInput = $UserInput -notmatch "MpCmdRun"
				$UserInput = $UserInput -notmatch "ResultException"
				$UserInput = $UserInput -notmatch "SchedNetFx"
				$UserInput = $UserInput -notmatch "Setting error JSON 1.0 fields"
				$UserInput = $UserInput -notmatch "Signature Update Failed"
				$UserInput = $UserInput -notmatch "Terminating context"
				$UserInput = $UserInput -notmatch "The process cannot access the file because it is being used by another process"
				$UserInput = $UserInput -notmatch "The FileSystemWatcher has detected an error System.IO.ErrorEventArgs"
				$UserInput = $UserInput -notmatch "ThrowIfExceptional"
				$UserInput = $UserInput -notmatch "Windows Installer installed the product"
				$UserInput = $UserInput -notmatch "with working directory 'D"
			}#end if isnotnull

			$UserReplace = $UserInput -replace "\\","\\" -replace "\[","\[" -replace "\]","\]" -replace "\*","\*" -replace "\+","\+" -replace "\s",$Enum.Char.Blank -join $Enum.Char.Blank

			[bool]$isnotnull = ($null -notmatch $UserReplace)
			# [bool]$isnotnull = (($UserReplace.Length -gt $Enum.Num.Ten) && ($UserReplace.gettype().name -eq $Enum.PSDataTypes.String))
			if ($WhatIf) {Write-Host "UserReplace 2 $UserReplace - notmatch null $isnotnull (true is populated, false is null)"}
			if ($isnotnull) {
			# if (!($isnotnull)) {
				$UserInput = $UserInput | Select-Object -Unique

				#$UserInput = $UserInput -replace " -",$null #What was this for again?
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (A) -PR $PR -UserInput $($UserInput -join `"`n> `") -CannedMessage AutoValEnd"
					Write-Host "WhatIf: UserInput Length $($UserInput.Length)"
					$out = Reply-ToPR -PR $PR -UserInput ($UserInput -join $Enum.Char.LineBreakMDQuote) -CannedMessage $Enum.CannedMessages.AutoValEnd -WhatIf
				} else {
					$out = Reply-ToPR -PR $PR -UserInput ($UserInput -join $Enum.Char.LineBreakMDQuote) -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
				}

				if ($LowerOps -eq $true) {
					$SplitInput = ($UserInput -split $Enum.Char.LineBreak )
					foreach ($input in $Enum.QueueInputs) {
						if($SplitInput -match $input) {
							if ($WhatIf) {
								Write-Host "WhatIf: Add-PRToQueue -PR $PR"
							} else {
								Add-PRToQueue -PR $PR
							}
 							
						}
					}
					$exitregex = "exit code: [0-9]{0,3}$"
					$exitregex2 = "exit code: [0-9]{4,}$"
					$exitregex3 = "exit code: -[0-9]{4,}$"
					if(!(($UserInput -split $Enum.Char.LineBreak ) -match $exitregex2)) { #4 digits bad
						if(!(($UserInput -split $Enum.Char.LineBreak ) -match $exitregex3)) { #4 digits bad
							if(($UserInput -split $Enum.Char.LineBreak ) -match $exitregex) { #1-3 digits good
								if ($WhatIf) {
									Write-Host "WhatIf: Get-CompletePR -PR $PR (A)"
								} else {
									Get-CompletePR -PR $PR
								}
							} 
							if ($WhatIf) {
								Write-Host "WhatIf: exit regex3 4 digits bad(A)"
							} 
						}
						if ($WhatIf) {
							Write-Host "WhatIf: exit regex2 4 digits bad (A)"
						} 
					}
				}#end If LowerOps
					
				if (!($Silent)) {
					if ($WhatIf) {
						Write-Host "WhatIf: Write-Host 'PR: $PR - $out'"
					} else {
						Write-Host "PR: $PR - $out"
					}
				}
			} else {
				if ($IsZipPath) {
					$UserInput = $Enum.Strings.NoErrorsToPost
					$Title = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content -JSON).title);
					if ($WhatIf) {
						Write-Host "WhatIf: Reply-ToPR (B) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
						$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -WhatIf
						Write-Host "WhatIf: Get-CompletePR -PR $PR (B)"
						Write-Host "WhatIf: Get-GitHubPreset -PR $PR Waiver"
						Write-Host "WhatIf: UserInput Length $($UserInput.Length)"
					} else {
						$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
						Get-CompletePR -PR $PR
						foreach ($Waiver in $WaiverList) {
							if ($Title -match $Waiver.PackageIdentifier) {
								Get-GitHubPreset -PR $PR Waiver
							}#end if title
						}#end foreach waiver
					}#end if WhatIf
				}#end if ZipPath
			}#end if isnotnull
		} else {
			if (!($Silent)) {
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (C) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -WhatIf
					Write-Host "WhatIf: UserInput Length $($UserInput.Length)"
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
				}
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (D) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -WhatIf
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
				}
				$UserInput = "`Build $BuildNumber not found."
				Write-Host $UserInput
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (E) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -WhatIf
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage $Enum.CannedMessages.AutoValEnd -Automated
				}#end if WhatIf
			}#end if not silent
		}#end if BuildNumber
			
		return $out 
	}#end if Last Prevalidation was 8 hours ago.
}

Function Get-RandomIEDS {
	Param(
		[int]$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM)),
		$IEDSPRs = (Get-SearchGitHub -Preset IEDS -nBMM),
		[ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		[int]$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData ($IEDSPRs.number | where {$_ -notin (Get-Status).pr} | Get-Random))#,
	)
	
	if ($VM -eq 0){
		Write-Host "No available $OS VMs";
		Get-PipelineVmGenerate -OS $OS;
		Add-PRToQueue -PR $PR;
	} else {
		Get-CommitFile -PR $PR -VM $VM 
	}
}

Function Get-PRData {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR
	)
	Process {
		$PR2 = Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR
		Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$PR2" -JSON
	}
}

Function Get-PRManifest {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$File = 0,
		[switch]$Patch
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$CommitFile = (Get-CommitFile -PR $PR -Deparent);
	$PackageIdentifier = Get-SchemaCheck -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier -InputData $CommitFile | Get-RemoveQuotes
	$PackageVersion = Get-YamlValue -Key $Enum.ManifestKeys.PackageVersion -clip $CommitFile | Get-RemoveQuotes
	$Submitter = ((Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr" -JSON).user.login);
	
	if ($Patch) {
		$CommitFile = (Get-CommitFile -PR $PR -Mode Patch)
	}
	
	$out = "$PackageIdentifier version $PackageVersion #$PR`n"
	$out += "$Submitter wants to merge`n"
	$out += $Enum.ManifestStrings.FooterHeader
	$out += ($CommitFile -join $Enum.Char.LineBreak)
	$out += $Enum.ManifestStrings.FooterHeader
	return $out
}

Function Get-RemoveQuotes {
	Param(
		[Parameter(ValueFromPipeline)][string]$String
	)
	Process {
		$String -replace $Enum.Char.DoubleQuote,$Enum.Char.Blank-replace $Enum.Char.SingleQuote,$Enum.Char.Blank
	}
}

#GItHub Tools
Function Invoke-Commits {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$Type = "commits"
	)
	Process {
		$Commits = Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr/$Type" -JSON
		$Commits
	}
}

Function Invoke-GitHubPRRequest {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[ValidateScript( { $_ -in (Get-Keys $Enum.PRRequestMethods)} )][string]$Method = $Enum.PRRequestMethods.Get,
		[ValidateScript( { $_ -in (Get-Values $Enum.PRRequestTypes)} )][string]$Type = $Enum.PRRequestTypes.Labels,
		[string]$Data,
		[ValidateScript( { $_ -in (Get-Keys $Enum.PRRequestPaths)} )][string]$Path = $Enum.PRRequestPaths.Issues,
		[ValidateScript( { $_ -in (Get-Keys $Enum.PRRequestOutput)} )][string]$Output = $Enum.PRRequestOutput.StatusDescription,
		[switch]$LastPage,
		[switch]$JSON,
		[switch]$WhatIf,
		$PRCommits = (Invoke-Commits -PR $PR2),
		$commit = (($PRCommits.commit.url -split $Enum.Char.Slash)[$Enum.Index.Last])
	)
	$PR = $PR2
	$Response = @{}
	$ResponseType = $Type
	$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"

	if (($Type -eq $Enum.PRRequestTypes.Blank) -OR ($Type -eq $Enum.PRRequestTypes.Files) -OR ($Type -eq $Enum.PRRequestTypes.Reviews)){
		$Path = $Enum.PRRequestPaths.Pulls
		$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"
	} elseif ($Type -eq $Enum.PRRequestTypes.Comments) {
		$Response.body += $Data
	} elseif ($Type -eq $Enum.PRRequestTypes.Commits) {
		$uri = "$GitHubApiBaseUrl/$Type/$commit"
	} elseif ($Type -eq $Enum.PRRequestTypes.Merge) {
		$Path = $Enum.PRRequestPaths.Pulls
	} elseif ($Type -eq $Enum.PRRequestTypes.Reviews) {
		$Path = $Enum.PRRequestPaths.Pulls
		$Response.body = $Enum.Char.Blank + $Data
		$Response.commit = $commit
		$Response.event = "APPROVE"
	} elseif ($Type -eq $Enum.Char.Blank) {
		#$Response.title = $Enum.Char.Blank
		#$Response.body = $Enum.Char.Blank
		$Response.state = $Enum.PRStates.Closed
		$Response.base = $Enum.Strings.PrimaryFork
	} else {
 		$Response.$ResponseType = @()
		$Response.$ResponseType += $Data
	}

	$uri = $uri -replace "/$",$Enum.Char.Blank

	if ($LastPage) {
		$uri += "?per_page=100&filter=latest"
	} 
	if ($Method -eq $Enum.PRRequestMethods.Get) {
		if ($WhatIf) {
			"Invoke-GitHubRequest -Method $Method -Uri $uri"
		} else {
			$out = Invoke-GitHubRequest -Method $Method -Uri $uri
#$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"
#$uri = "$GitHubApiBaseUrl/commits/$headSha/check-runs?per_page=100&filter=latest"

		}
	} else {
		[string]$Body = $Response | ConvertTo-Json
		$out = Invoke-GitHubRequest -Method $Method -Uri $uri -Body $Body
	}

	if (($JSON) -OR ($Output -eq $Enum.PRRequestOutput.Content)) {
		if ($null -ne $out.$Output) {
			try {
				$out.$Output | ConvertFrom-Json
			}catch{
				return ("PR: $PR - Error: $($error[$Enum.Index.First].ToString()) - Url $uri - Body: $Body")
			}
		} elseif ($Output -eq $Enum.PRRequestOutput.Silent ) {
		} else {
			$out.$Output 
		}
	} else {
		return "!" #"PR: $PR - No output. Method: $Method - URI: $uri"
		#return ("PR: $PR - Error: $($error[$Enum.Index.First].ToString()) - Url $uri - Body: $Body")
	}
}

Function Get-UpdateSource {
	$GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
	# Param(
	# )
	# if ($GhRlRemain -gt 0) {
		# $DataSource = $Enum.PRWatchDataSource.GitHub
	# } else {
		# $DataSource = $Enum.PRWatchDataSource.WinGet
	# }
}

Function Get-SyncFork {
	Param(
		$SyncUserName = $Enum.GitHubUserNames.GitHubUserName,
		$SyncRepo = $repo,
		$SyncFork = $Enum.Strings.PrimaryFork,
		$Uri = "https://api.github.com/repos/$SyncUserName/$SyncRepo/merge-upstream",
		$Body = "{`"branch`":`"$SyncFork`"}"
	)
	$out = (Invoke-GitHubRequest -Uri $Uri -Body $Body -Method $Enum.PRRequestMethods.Post).content | ConvertFrom-Json
	return $out
}

Function Get-GitHubRateLimit {
	Param(
		$Url = "https://api.github.com/rate_limit"
	)
	(Get-Date)#Time, as a number, constantly increases. 
	$Response = Invoke-WebRequest -Uri $Url -ProgressAction SilentlyContinue
	$Content = $Response.content | ConvertFrom-Json;
	$Content.rate | Select-Object @{n = $Enum.GitHubRateLimit.Source; e = {$Enum.GitHubRateLimit.Unlogged}}, limit, used, remaining, @{n = $Enum.GitHubRateLimit.Reset; e = {([System.DateTimeOffset]::FromUnixTimeSeconds($_.reset)).DateTime.AddHours(-8)}}
	$Response = invoke-GitHubRequest -Uri $Url -JSON;
	$Response.rate | Select-Object @{n = $Enum.GitHubRateLimit.Source; e = {$Enum.GitHubRateLimit.Logged}}, limit, used, remaining, @{n = $Enum.GitHubRateLimit.Reset; e = {([System.DateTimeOffset]::FromUnixTimeSeconds($_.reset)).DateTime.AddHours(-8)}}
}

Function Get-GitHubTimeout {
	$GitHubRateLimit = Get-GitHubRateLimit
	$starttime = get-date $GitHubRateLimit[$Enum.Index.First]
	$UsedCalls = ($GitHubRateLimit)[$Enum.Num.Two].used
	$Limit = ($GitHubRateLimit)[$Enum.Num.Two].limit
	while ($UsedCalls -ge $Limit) {
		$GitHubRateLimit = Get-GitHubRateLimit
		$UsedCalls = $GitHubRateLimit[$Enum.Num.Two].used
		$endtime = get-date $GitHubRateLimit[$Enum.Num.Two].reset
		$timeleft = $endtime - (Get-Date)
		$totaltime = $endtime - $starttime
		$pct = (1 - ($timeleft.TotalSeconds / $totaltime.TotalSeconds)) * 100
		$OutputTime = (get-date $endtime -f s) -replace $Enum.Char.T," - "
		Write-Progress -Activity "Waiting until $OutputTime for API rate limit cooldown." -Status "$($timeleft.TotalSeconds) seconds remaining." -PercentComplete $pct
	}
}

Function Get-FileFromGitHub {
	Param(
		[string]$PackageIdentifier,
		[string]$PI = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier),
		[string]$Version,
		[string]$Suffix = $Enum.ManifestFileTypes.installeryaml,
		[string]$Path = ($PI -replace "[.]",$Enum.Char.Slash),
		[string]$FirstLetter = ($PI[$Enum.Index.First].tostring().tolower())
	)
	$PackageIdentifier = $PI
	Write-Host "$($MyInvocation.MyCommand.name) $PR"
	try{
		$content = (Invoke-GitHubRequest -Uri "$GitHubContentBaseUrl/master/manifests/$FirstLetter/$Path/$Version/$PackageIdentifier.$Suffix").content
	}catch{
		$content = "Error $GitHubContentBaseUrl/master/manifests/$FirstLetter/$Path/$Version/$PackageIdentifier.$Suffix not found."
	}
	return ($content -split $Enum.Char.LineBreak)
}

Function Get-SearchGitHub {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.SearchPresets)} )][string[]]$Preset = $Enum.SearchPresets.Approval,
		[Switch]$Browser,
		$Url = "https://api.github.com/search/issues?page=$Page&q=",
		$SearchString,
		$Author, #wingetbot
		$Commenter, #wingetbot
		$Title,
		$ExcludeTitle,
		[string]$Label, 
		[int]$Page = $Enum.Num.One,
		[int]$DaysAgo,
		[Switch]$BMM,
		[Switch]$NewPackages,
		[Switch]$nBMM,
		[Switch]$IEDS,
		[Switch]$NotWorked,
		[Switch]$NoLabels,
		[Switch]$AllowClosedPRs
	)
	if ($Browser) {
		$Url = "$GitHubBaseUrl/pulls?page=$Page&q="
	}
	#Base settings
	$Base = "repo:$Owner/$Repo+"
	$Base = $Base+$Enum.SearchTerms.IsPR
	if (!($AllowClosedPRs)) {
		$Base += $Enum.SearchTerms.IsOpen
	}
	$Base += $Enum.SearchTerms.DraftFalse
	$Base += $Enum.SearchTerms.SortAsc

	#Smaller blocks
	$date = Get-Date (Get-Date).AddDays(-$DaysAgo) -Format $Enum.Strings.Timestamp
		# $Url += $Enum.Strings.Label+$Enum.PRLabels.PD+$Enum.Char.Plus;#dupe
	$Defender = "label:$($Enum.PRLabels.VDE)+"
	$HaventWorked = "-commenter:$($Enum.GitHubUserNames.GitHubUserName)+"
	$HVR = "label:$($Enum.PRLabels.HVR)+"
	$IEDSLabel = "label:$($Enum.PRLabels.IEDS)+"
	$IEM = "label:$($Enum.PRLabels.IEM)+"
	$LVR = "label:$($Enum.PRLabels.LVR)+"
	$MA = "label:$($Enum.PRLabels.MA)+"
	$MMC = "label:$($Enum.PRLabels.MMC)+"
	$NA = "label:$($Enum.PRLabels.NA)+"
	$NAF = "label:$($Enum.PRLabels.NAF)+"
	$NotPass = "-label:$($Enum.PRLabels.APP)+"#Hasn't psased pipelines
	$Recent = "updated:>$($date)+" 
	$VC = "label:$($Enum.PRLabels.VC)+"#Completed
	$VD = "label:$($Enum.PRLabels.VD)+"
	$VSA = "label:$($Enum.PRLabels.VSA)+"

	$nBI = "-label:$($Enum.PRLabels.BI)+"
	$nHW = "-label:Hardware+"
	$nHVR = $Enum.Char.Dash + $HVR + $Enum.Char.Plus
	$nIEDS = $Enum.Char.Dash + $IEDSLabel + $Enum.Char.Plus
	$nIEDS = $Enum.Char.Dash + $IEDSLabel + $Enum.Char.Plus
	$nMA = $Enum.Char.Dash + $MA + $Enum.Char.Plus
	$NMM = "label:$($Enum.PRLabels.NMM)+"
	$nMMC = $Enum.Char.Dash + $MMC + $Enum.Char.Plus
	$nNA = $Enum.Char.Dash + $NA + $Enum.Char.Plus
	$nNP = "-label:$($Enum.PRLabels.NP)+"
	$nNRA = "-label:$($Enum.PRLabels.IOD)+"
	$nNRA = "-label:$($Enum.PRLabels.IOI)+"
	$nNRA = "-label:$($Enum.PRLabels.NRA)+"
	$nNSA = "-label:$($Enum.PRLabels.NSA)+"
	$nVC = $Enum.Char.Dash + $VC #Not Completed

	
	#Building block settings
	$Blocking = $nHW
	$Blocking += $nNSA
	$Blocking += "-label:$($Enum.PRLabels.AGR)+"
	$Blocking += "-label:$($Enum.PRLabels.DI)+"
	$Blocking += "-label:$($Enum.PRLabels.LBI)+"
	$Blocking += "-label:$($Enum.PRLabels.NB)+"
	$Blocking += "-label:$($Enum.PRLabels.PF)+"
	$Blocking += "-label:$($Enum.PRLabels.RB)+"
	$Blocking += "-label:$($Enum.PRLabels.SA)+"
	
	$Common = $nBI
	$Common = $Common+$Enum.Char.Dash + $IEM
	$Common = $Common+$Enum.Char.Dash + $Defender

	$Cna = $VC
	$Cna = $Cna + $nMA
	
	$Review1 = "-label:$($Enum.PRLabels.CR)+"
	$Review1 += "-label:$($Enum.PRLabels.CLA)+"
	$Review1 += $nNRA

	$Review2 = $Enum.Char.Dash + $NA
	$Review2 = $Review2 + $Enum.Char.Dash + $NAF
	$Review2 = $Review2 + "-label:$($Enum.PRLabels.NR)+"
	
	$Approvable = "-label:$($Enum.PRLabels.VMC)+"
	$Approvable += "-label:$($Enum.PRLabels.VER)+"
	$Approvable += "-label:$($Enum.PRLabels.MIVE)+"
	$Approvable += "-label:$($Enum.PRLabels.PD)+"
	$Approvable += "-label:$($Enum.PRLabels.UF)+"
	$Approvable += "-label:$($Enum.PRLabels.CLA)+"
	
	$Workable += "-label:$($Enum.PRLabels.LVR)+"
	$Workable += "-label:$($Enum.PRLabels.HVR)+"
	$Workable += "-label:$($Enum.PRLabels.VMC)+"
	$Workable += "-label:$($Enum.PRLabels.BVE)+"
	$Workable += "-label:$($Enum.PRLabels.UF)+"
	$Workable += "-label:$($Enum.PRLabels.VCR)+"
	$Workable += "-label:$($Enum.PRLabels.VSS)+"

	$PolicyTests = "-label:Policy-Test-1.1+";
	$PolicyTests += "-label:$($Enum.PRLabels.PT12)+"
	$PolicyTests += "-label:Policy-Test-1.3+";
	$PolicyTests += "-label:Policy-Test-1.4+";
	$PolicyTests += "-label:Policy-Test-1.5+";
	$PolicyTests += "-label:Policy-Test-1.6+";
	$PolicyTests += "-label:Policy-Test-1.7+";
	$PolicyTests += "-label:Policy-Test-1.8+";
	$PolicyTests += "-label:Policy-Test-1.9+";
	$PolicyTests += "-label:Policy-Test-1.10+";
	$PolicyTests += "-label:Policy-Test-2.1+";
	$PolicyTests += "-label:Policy-Test-2.2+";
	$PolicyTests += "-label:$($Enum.PRLabels.PT23)+"
	$PolicyTests += "-label:Policy-Test-2.4+";
	$PolicyTests += "-label:Policy-Test-2.5+";
	$PolicyTests += "-label:Policy-Test-2.6+";
	$PolicyTests += "-label:$($Enum.PRLabels.PT27)+"
	$PolicyTests += "-label:Policy-Test-2.8+";
	$PolicyTests += "-label:Policy-Test-2.9+";
	$PolicyTests += "-label:Policy-Test-2.10+";
	$PolicyTests += "-label:Policy-Test-2.11+";
	$PolicyTests += "-label:Policy-Test-2.12+";
	
	#Composite settings
	$Set1 = $Blocking + $Common + $Review1
	$Set2 = $Set1 + $Review2
	$Url += $Base
	if ($Author) {
		$Url += "author:$($Author)+"
	}
	if ($Commenter) {
		$Url += "commenter:$($Commenter)+"
	}
	if ($Days) {
		$Url += $Recent
	}
	if ($IEDS) {
		$Url += $nIEDS
	}
	if ($Label) {
		$Url += "label:$($Label)+"
	}
	if ($NotWorked) {
		$Url += $HaventWorked
	}
	if ($NewPackages) {
		$Url += "label:New-Package+"
	}
	if ($Title) {
		$Url += "$Title in:title+"
	}
	if ($BMM) {
		$Url += "label:$($Enum.PRLabels.BMM)+"
	}
	if ($nBMM) {
		$Url += "-label:$($Enum.PRLabels.BMM)+"
	}	
	switch ($Preset) {
		$Enum.SearchPresets.Approval {
			$Url += $Cna
			$Url += $nBI
			$Url += $nBI
			$Url += $Set2 #Blocking + Common + Review1 + Review2
			$Url += $Approvable
			$Url += $Workable;
			$Url += $nMMC;
		}
		$Enum.SearchPresets.Approval2 {
			$Url += $Cna
			$Url += $nNP
			$Url += $nHVR
			$Url += $Set2 #Blocking + Common + Review1 + Review2
			$Url += $Approvable
			$Url += $Workable;
			$Url += $nMMC;
		}
		$Enum.SearchPresets.Defender {
			$Url += $Defender
		}
		$Enum.SearchPresets.Domain {
			$Url += "label:$($Enum.PRLabels.VD)+"
		}
		$Enum.SearchPresets.Duplicate {	
			$Url += $Enum.Strings.Label+$Enum.PRLabels.PD+$Enum.Char.Plus;#dupe
			$Url += $nNRA
		}
		$Enum.SearchPresets.Autowaiver {
			$Url += $Set1
			$Url += $Workable
			$Url += $nIEDS 
			$Url += $nVC
			$Url += "label:$($Enum.PRLabels.EHM)+"
			$Url += "label:$($Enum.PRLabels.MIVE)+"
			$Url += "label:$($Enum.PRLabels.MVE)+"
			$Url += "label:$($Enum.PRLabels.VEE)+"
			$Url += "label:$($Enum.PRLabels.VNE)+"
			$Url += "label:$($Enum.PRLabels.VIE)+"
			$Url += "label:$($Enum.PRLabels.VSE)+"
			$Url += "label:$($Enum.PRLabels.VUF)+"
			$Url += "label:$($Enum.PRLabels.ANF)+"
			$Url += $nBI
			$Url += $nIOD
			$Url += $nIOI
		}
		$Enum.SearchPresets.IEDS {
			$Url += $IEDSLabel
			$Url += $nBI
			$Url += $Blocking
			$Url += $NotPass
			$Url += $nVC
		}
		$Enum.SearchPresets.HVR {
			$date = Get-Date (Get-Date).AddDays(-7) -Format $Enum.Strings.Timestamp
			$createdDate = "created:<$($date)+" 
			$Url += $createdDate;
			$Url += $HVR;
		}
		$Enum.SearchPresets.LVR {
			$date = Get-Date (Get-Date).AddDays(-7) -Format $Enum.Strings.Timestamp
			$createdDate = "created:<$($date)+" 
			$Url += $createdDate;
			$Url += $LVR;
		}
		$Enum.SearchPresets.MMC {
			$Url += $MMC;
		}
		$Enum.SearchPresets.NMM {
			$Url += $NMM;
		}
		$Enum.SearchPresets.None {
		}
		$Enum.SearchPresets.ToWork {
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $Workable;
			#$Url += $Workable
		}
		$Enum.SearchPresets.ToWork2 {
			$Url += $HaventWorked
			$Url += $Enum.Char.Dash + $Defender
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $nVC
		}
		$Enum.SearchPresets.ToWork3 {
			$Url += $HaventWorked
			$Url += $Enum.Char.Dash + $Defender
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $nVC
			$Url += $nMA
			$Url += $nNA
		}
		$Enum.SearchPresets.VCMA {
			#$date = Get-Date (Get-Date).AddHours(-1) -Format $Enum.Strings.Timestamp
			#$createdDate = "created:<$($date)+" 
			$Url += $createdDate;
			$Url += $MA
			$Url += $VC
			$Url += $Set2 #Blocking + Common + Review1 + Review2
			$Url += $Approvable
			$Url += $Workable;
			$Url += $nMMC;
		}
	}

	if ($Browser) {
		Start-Process $Url
	} else {
		$Response = Invoke-GitHubRequest $Url
		$Response = ($Response.Content | ConvertFrom-Json).items
		#$Response = $Response | Where-Object {!(($_.labels.name -match $Enum.PRLabels.MA) -AND ($_.labels.name -match "Needs-Attention"))}
		if ($ExcludeTitle) {
			$Response = $Response | Where-Object {$_.title -notmatch $ExcludeTitle}
		}
		if (!($NoLabels)) {
			$Response = $Response | where {$_.labels}
		}
		return $Response
	}
}

Function Get-ClaCheck {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$LabelName = $Enum.PRCheckLabels.LicenseCla,
		[switch]$WhatIf
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$Status = (Get-CheckData -PR $PR | where {$_.name -match $LabelName}).status
	If ($WhatIf) {Write-Host "$($MyInvocation.MyCommand.name): $Status"} 
	switch ($Status) {
		$Enum.PRCheckLabels.Queued {
			If ($WhatIf) {
				Write-Host "Get-AddPRLabel -PR $PR -Label $($Enum.PRLabels.CLA)"
			} else {
				Get-AddPRLabel -PR $PR -Label $Enum.PRLabels.CLA
			}			
		}
		$Enum.PRCheckLabels.Completed {
			If ($WhatIf) {
				Write-Host "Get-RemovePRLabel -PR $PR -Label $($Enum.PRLabels.CLA)"
			} else {
				Get-RemovePRLabel -PR $PR -Label $Enum.PRLabels.CLA
			}			
		}
		Default {
			Write-Host "Invalid Status: $Status"
		}
	}
}

Function Get-CheckIfPackageIsNew {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$PRCommits = (Get-CommitFile -PR $PR2),
		[string]$PackageIdentifier = (Get-SchemaCheck -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier -InputData $PRCommits),
		$ManifestVersion = (Get-ManifestVersion -PackageIdentifier $PackageIdentifier)
	)
	Process {
		$PR = $PR2
		Write-Host "$($MyInvocation.MyCommand.name): PR $PR - PackageIdentifier: $PackageIdentifier - ManifestVersion $ManifestVersion"
		if ($ManifestVersion) {#If any version data exists, then it's a New-Manifest.
			Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.NM
			Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.NP
		} else {
			Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.NP
			Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.NM
		}
	}
}

#PR tools
#Add user to PR: Invoke-GitHubPRRequest -Method $Enum.PRRequestMethods.$Method -Type "assignees" -Data $User -Output StatusDescription
#Approve PR (needs work): Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type reviews
Function Get-RevertCompletePR {
	Param(
		[int]$PR
	)
	$VRlabels = Get-ValidationResult $pr
	$VRlabels = $VRlabels | where {$_ -notmatch $Enum.PRLabels.vc}
	if ($VRlabels) {
		Get-RemovePRLabel -PR $pr -LabelName $Enum.PRLabels.vc
		$VRlabels | %{Get-AddPRLabel -PR $pr -LabelName $_}
	}
}

Function Approve-PR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[string]$Body = $Enum.Char.Blank,
		$PRCommits = (Invoke-Commits -PR $PR2),
		$commit = (($PRCommits.commit.url -split $Enum.Char.Slash)[$Enum.Index.Last]),
		$uri = "$GitHubApiBaseUrl/pulls/$pr/reviews"
	)
	Process {
		$PR = $PR2
		if (!(Get-PRApprovalCheck -PR $PR)) {
			try {
				[array]$AuthorList = $PRCommits.commit.author.name# -join $Enum.Char.Space
				$PRAuthors = $AuthorList[$Enum.Index.First]
			}catch{}
			if (($PRAuthors -notmatch $Enum.GitHubUserNames.GitHubUserName2) -AND ($PRAuthors -notmatch $Enum.GitHubUserNames.GitHubUserNameFull)) {
				$Response = @{}
				$Response.body = $Body
				$Response.commit = $commit
				$Response.event = "APPROVE"
				[string]$Body = $Response | ConvertTo-Json
				
				$out = Invoke-GitHubRequest -Method $Enum.PRRequestMethods.Post -Uri $uri -Body $Body 
				$out.StatusDescription
				Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.MA
			} #end try
		} else {
			Write-Host "$($MyInvocation.MyCommand.name): PR $PR failed approval check"
		}#end if Get-PRApprovalCheck
	}#end Process
}#end Function

Function Get-PRApprovalCheck {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PRCommits = (Invoke-Commits -PR $PR -Type "reviews")
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		[array]$StateData = ($PRCommits | Where {$_.user.login -match $Enum.GitHubUserNames.GitHubUserName}).state
		$State = $StateData -join $Enum.Char.Blank
		[bool]$out = $State -match "APPROVED"
		Return $out
	}
}

Function Get-ApproveBySearch {
	Param(
		[Parameter(mandatory = $True)][string]$Author,
		$Preset = $Enum.SearchPresets.ToWork,
		$MatchText = $Enum.Strings.StandardizeFormatting,
		$Results = (Get-SearchGitHub -Author $Author -Preset $Preset -NoLabels)
	)
	$Results = $Results | Where-Object {$_.user.login -eq $Author -and $_.title -match $MatchText -and $_.labels.name -notcontains $Enum.PRLabels.MA -and $_.labels.name -notcontains $Enum.PRLabels.CR};
	$Results.number | % { Write-Host "$_ - " -nonewline;Approve-PR $_ };
}

Function Get-PRRange {
	Param(
		[int]$firstPR,
		[int]$lastPR,
		[string]$Body,
		[string]$Preset
	) 
	$line = 0; 
	$firstPR..$lastPR | %{
		if ($Preset -eq $Enum.PRStates.Closed) {
			Get-GitHubPreset -Preset $Enum.GitHubPresets.($Preset) -PR $_ -UserInput $Body
		} else {
			Reply-ToPR -PR $_ -Body $Body;
			Get-GitHubPreset -Preset $Enum.GitHubPresets.($Preset) -PR $_
		}
		Get-TrackerProgress -Activity $MyInvocation.MyCommand.name -ItemName $_ -ItemNumber $line -TotalItems ($lastPR - $firstPR); 
		$line++
	}
}

Function Get-AddPRLabel {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$LabelName
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$Response = Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type labels -Data $LabelName -Output Content
		Write-Host $Response.name
	}
}

Function Get-RemovePRLabel {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$LabelName
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$Uri = "$GitHubApiBaseUrl/issues/$PR/labels/$LabelName"
		$Response = Invoke-GitHubRequest -Uri $Uri -Method $Enum.PRRequestMethods.Delete
		Write-Host $Response.StatusDescription
	}
}

function Get-CompletePR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR
	)
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$PRLabels = (invoke-GitHubPRRequest -PR $PR -Type labels -Method $Enum.PRRequestMethods.Get -Output Content).name | 
	where {$_ -notmatch $Enum.PRLabels.APP} |
	where {$_ -notmatch $Enum.PRLabels.MMC} |
	where {$_ -notmatch $Enum.PRLabels.MA} | 
	where {$_ -notmatch $Enum.PRLabels.NM} | 
	where {$_ -notmatch $Enum.PRLabels.NP} | 
	where {$_ -notmatch $Enum.PRLabels.PD} | 
	where {$_ -notmatch $Enum.PRLabels.RET} | 
	where {$_ -notmatch $Enum.PRLabels.VAD} | 
	where {$_ -notmatch $Enum.PRLabels.VC} 

	foreach ($label in $PRLabels) {
		Get-RemovePRLabel -PR $PR -Label $label
	}
	if (($PRLabels -join $Enum.Char.Space) -notmatch $Enum.PRLabels.VDE) {
		Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.VC
	}
}

Function Get-StringOrArrayLast {
	Param(
		$StringOrArray,
		$ArrayIndex = $Enum.Index.Last
	)
	if ($null -ne $StringOrArray) {
		if ($StringOrArray.GetType().name -eq $Enum.PSDataTypes.String) {
			Return $StringOrArray
		} else {
			Return $StringOrArray[$ArrayIndex]
		}
	} else {
		Write-Host "$($MyInvocation.MyCommand.name): StringOrArray $StringOrArray not found (length $($StringOrArray.Length)"
	}
}

Function Get-MergePR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$ShaNumber = (-1)
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$sha = (Invoke-Commits -PR $PR).sha
		$sha = Get-StringOrArrayLast -StringOrArray $Sha -ArrayIndex $ShaNumber
		
		$out = $Enum.Char.Blank
		$Data = Invoke-GitHubrequest -Uri "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/merge" -Method $Enum.PRRequestMethods.Put -Body "{`"merge_method`":`"squash`",`"sha`":`"$sha`"}"
		if ($Data.Content) {
			$out = $Data.Content
		} else {
			$out = $Data
			#($Data[1..$Data.Length] | ConvertFrom-Json).message
		}
		
		$Comments = Get-PRComments -PR $PR
		if ($out -match $Enum.Words.Error) {
			if ($Comments[$Enum.Index.Last].UserName -ne $Enum.GitHubUserNames.GitHubUserName) {
			$LabelNames = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.prRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name)
				if ($LabelNames[$Enum.Index.Last].UserName -ne $Enum.GitHubUserNames.GitHubUserName) {
					if (($LabelNames -join $Enum.Char.Space) -notmatch $Enum.PRLabels.BI) {
						Reply-ToPR -PR $PR -UserInput $out -CannedMessage MergeFail -Automated
					} 
				} 
			}
		}
		
		if ($out -match $Enum.Strings.PullRequestHasMergeConflicts) {
			Reply-ToPR -PR $PR -body $Enum.PRCloseReasons.MergeConflicts
		}
		Write-Host "$($MyInvocation.MyCommand.name): $PR - $out"
		Add-PRToRecord -PR $PR -Action $Enum.PRActions.Squash
		#invoke-GitHubprRequest -PR $PR -Method $Enum.PRRequestMethods.Put -Type merge -Data "{`"merge_method`":`"squash`",`"sha`":`"$sha`"}"
	}
}

Function Get-RetryPR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$Command = $Enum.Strings.WingetbotRun
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$Response = Invoke-GitHubPRRequest -PR $PR -Type $Enum.PRRequestTypes.Comments -Output $Enum.PRRequestOutput.StatusDescription -Method $Enum.PRRequestMethods.Post -Data $Command
		Write-Host $Response
	}
}

function Get-PushMePRYou {
	Param(
		$Author = $Enum.GitHubUserNames.Trenly,
		$MatchString = $Enum.Strings.StandardizeFormatting,
		[int]$Page = $Enum.Num.One
	)
	foreach ($Preset in ($Enum.SearchPresets.Approval,$Enum.SearchPresets.ToWork)) {
		Write-Host "$(Get-Date -Format T) $($MyInvocation.MyCommand.name): $PR - $($Preset)";
		$PRsForAuthor = @();
		$PRsForAuthor = Get-SearchGitHub -Author $Author -Preset $Preset -Page $Page -NoLabels;
		$PRsForAuthor = $PRsForAuthor | Where-Object {$_.user.login -eq $Author -and $_.title -match $MatchString -and $_.labels.name -notcontains $Enum.PRLabels.MA};
		if ($PRsForAuthor) {
			$PRsForAuthor.number | % { 
				$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $_)
				Write-Host "$PR - " -nonewline;
				Approve-PR $PR 
			};
		}
	};

	$Preset = $Enum.VMStatus.Complete
	Write-Host "$($Preset): $(get-date)";
}

Function Add-GitHubReviewComment {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[string]$Comment = $Enum.Char.Blank,
		$Commit = (Invoke-GitHubPRRequest -PR $PR2 -Type commits -Output $Enum.PRRequestOutput.Content -JSON),
		$commitID = $commit.sha,
		$Filename = $commit.files.filename,
		$Side = $Enum.DiffData.Right,
		$StartLine,
		$Line
	)
	$PR = $PR2
	$Filename = Get-StringOrArrayLast $Filename

	$Response = @{}
	$Response.body = $Comment
	$Response.commit_id = $commitID
	$Response.path = $Filename
	if ($StartLine) {
		$Response.start_line = $StartLine
	}
	$Response.start_side = $Side
	$Response.line = $Line
	$Response.side = $Side
	[string]$Body = $Response | ConvertTo-Json

	$uri = "$GitHubApiBaseUrl/pulls/$pr/comments"

	$out = Invoke-GitHubRequest -Method $Enum.PRRequestMethods.Post -Uri $uri -Body $Body 
	$out.$Enum.PRRequestOutput.StatusDescription
}

Function Get-BuildFromPR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$content = (Invoke-GitHubPRRequest -PR $PR2 -Method $Enum.PRRequestMethods.Get -Type $Enum.PRRequestTypes.Comments -Output Content),
		# [array]$href = ($content.body | where {$_ -match $Enum.Strings.ValidationPipelineRun})
		[array]$href = ($content.body | where {$_ -match $Enum.Strings.BuildLinkComment})
	)
	process {
		$href = ($href -split $Enum.Char.LineBreak)[$Enum.Index.Last]
		# [int]$LineNo = ($content.body | Select-String $Enum.Strings.BuildLinkComment).LineNumber[$Enum.Index.Last]
		# $href = ($href -split $Enum.Char.LineBreak)[$LineNo - 1]
		$PRbuild = (($href -split $Enum.Char.Equal -replace $Enum.Char.EscapedOpenParens)[$Enum.Index.Second])
		return $PRbuild
	}
}

Function Get-LineFromBuildResult {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$PRbuild = (Get-BuildFromPR -PR $PR2),
		$LogNumber = (36),
		$SearchString = $Enum.MagicStrings[7],
		$content = (Invoke-GitHubRequest "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$PRbuild/logs/$LogNumber" -ProgressAction SilentlyContinue).content,
		$Log = ($content -join $Enum.Char.Blank -split $Enum.Char.LineBreak),
		$MatchOffset = (-1),
		$MatchLine = (($Log | Select-String -SimpleMatch $SearchString).LineNumber | where {$_ -gt 0}),
		$Length = 0,
		$output = @()
	)
	process {
		$PR = $PR2
		foreach ($Match in $MatchLine) {
			$output += ($Log[($Match + $MatchOffset)..($Match + $Length + $MatchOffset)])
		}
		if (($output -join $Enum.Char.Space) -match $Enum.Strings.ManifestTypeSingleton) {
			Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.MSD
		}
		return $output
	}
}

Function Get-PRApproval {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[string]$PackageIdentifier,
		[string]$PI = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier),
		[string]$auth = (Get-ValidationData -Property $Enum.ManifestKeys.PackageIdentifier -Match $PI -Exact).GitHubUserName,
		[string]$Approver = (($auth -split $Enum.Char.Slash| Where-Object {$_ -notmatch "\("}) -join ", @"),
		[switch]$DemoMode
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	Reply-ToPR -PR $PR -UserInput $Approver -CannedMessage Approve -Policy $Enum.PRLabels.NR
}

Function Reply-ToPR {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[string]$CannedMessage,
		$UserInput = ((Invoke-GitHubPRRequest -PR $PR2 -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content -JSON).user.login),
		[string]$Body = (Get-CannedMessage $CannedMessage -UserInput $UserInput -NoClip),
		[string]$Policy,
		[Switch]$Silent,
		[Switch]$Automated,
		[Switch]$WhatIf
	)
	process {
		$PR = $PR2
		if ($PR -eq 1) {
			Write-Host "Invalid PR number, quitting to squelch output: $Body"
		} else {
			if ($Policy) {
				$Body += "`n<!--`n[Policy] $Policy`n-->"
			}
			if ($Body -match $Enum.Strings.AllCommentsMustBeResolved) {
				Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.CR
				# Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.VC
				# Open-PRInBrowser -PR $PR
			}
				$Comments = $Enum.Char.Blank
			if ($Automated) {
				$Comments = Get-PRComments -PR $PR
				if ($WhatIf) {Write-Host "WhatIf: Automated: $Automated Comments: $($Comments.count)"}
					if (!(($Comments[$Enum.Index.Last].user.login -eq $Enum.GitHubUserNames.GitHubUserName) -AND ($Automated))) {
						if ($WhatIf) {
							Write-Host "WhatIf: Invoke-GitHubPRRequest -PR $PR -Method $($Enum.PRRequestMethods.Post) -Type $($Enum.PRRequestTypes.Comments) -Data $Body -Output $($Enum.PRRequestOutput.StatusDescription)"
						} else {
							if ($Silent) {
								Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data $Body -Output Silent
							} else {
								Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data $Body -Output $Enum.PRRequestOutput.StatusDescription
							}# end if Silent
						}# end if WhatIf
					}
				} else {
					if ($WhatIf) {
						Write-Host "WhatIf: Invoke-GitHubPRRequest -PR $PR -Method $($Enum.PRRequestMethods.Post) -Type $($Enum.PRRequestTypes.Comments) -Data $Body -Output $($Enum.PRRequestOutput.StatusDescription)"
					} else {
						if ($Silent) {
							Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data $Body -Output Silent
						} else {
							Invoke-GitHubPRRequest -PR $PR -Method $Enum.PRRequestMethods.Post -Type $Enum.PRRequestTypes.Comments -Data $Body -Output $Enum.PRRequestOutput.StatusDescription
					}# end if Silent
				}#end if WhatIf
			}#end if Automated
		}#end if PR
	}#end process
}#end Function

Function Get-PRComments {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$Comments = (Invoke-GitHubPRRequest -PR $PR -Type $Enum.PRRequestTypes.Comments -Output $Enum.PRRequestOutput.Content -LastPage)
	foreach ($Comment in $Comments) {
		$Comment.($Enum.Strings.CreatedAt) = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Comment.($Enum.Strings.CreatedAt), $Enum.Strings.Pst)
	}
	
	Return $Comments
}

Function Get-NonStdPRComments {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Comments = (Get-PRComments -PR $PR2).body
	)
	process {
		foreach ($StdComment in (Get-Values $Enum.StandardPRComments)) {
			$Comments = $Comments | Where-Object {$_ -notmatch $StdComment}
		}
		return $Comments
	}
}

Function Get-PRStateFromComments {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Comments = (Get-PRComments -PR $PR2 | Select-Object $Enum.Strings.CreatedAt,@{n = $Enum.Strings.UserName; e = {$_.user.login -replace $Enum.Strings.BotPrefix}},body),
		$PRStateData = ((Get-Content $PRStateDataFile) -replace $Enum.Strings.GitHubUserName,$Enum.GitHubUserNames.GitHubUserName | ConvertFrom-Csv),
		[switch]$WhatIf
	)
	$PR = $PR2
	if ($WhatIf) {Write-Host "$($MyInvocation.MyCommand.name): $PR - Comments $($Comments.Count)"}
	$out = @()
	foreach ($Comment in $Comments) {
		$State = $Enum.Char.Blank
		if ($WhatIf) {Write-Host "$($MyInvocation.MyCommand.name): $PR - $($Enum.Strings.CreatedAt) $($Comment.($Enum.Strings.CreatedAt))"}
		
		if (($Comment.body -match $Enum.Run.azp1) -OR
		($Comment.body -match $Enum.Run.azp2) -OR
		($Comment.body -match $Enum.Run.wingetbot)) {
			if ($WhatIf) {Write-Host "PR $PR - State $($Enum.PRTrackerStates.PreValidation)"}
			$State = $Enum.PRTrackerStates.PreValidation
		} elseif (($Comment.UserName -eq $Enum.Robots.FabricBot) -AND (
		($Comment.body -match $Enum.LabelActionComments.URLError) -OR
		($Comment.body -match $Enum.LabelActionComments.ValidationInstallationError) -OR
		($Comment.body -match $Enum.LabelActionComments.InternalError) -OR
		($Comment.body -match $Enum.LabelActionComments.ValidationUnattendedFailed) -OR
		($Comment.body -match $Enum.LabelActionComments.ManifestValidationError)
		)) {
			if ($WhatIf) {
				Write-Host "PR $PR - State $($Enum.PRTrackerStates.LabelAction)"
			}
			$State = $Enum.PRTrackerStates.LabelAction
		} else {
			$StateKeys = (Get-Keys $Enum.PRTrackerStates)
			foreach ($Key in $StateKeys) {
				$KeyData = $PRStateData | where {$_.State -eq $Key}
				if ($WhatIf) {
					Write-Host "PR $PR - key $key - State $($States.Key) - botcomment $($KeyData.BotComment) - Comment $($Comment.body)"
				}
				if (($Comment.body -match $KeyData.BotComment) -AND ($Comment.UserName -eq $KeyData.User)) {
					if ($WhatIf) {
						Write-Host "PR $PR - match $($KeyData.BotComment)"
					}
					$State = $Enum.PRTrackerStates.($Key)
				}
			}
		}
		if ($WhatIf) {
			Write-Host "PR $PR - State $State"
		}
		if ($State -ne $Enum.Char.Blank) {
			if ($WhatIf) {
				Write-Host "PR $PR - out $out"
			}
			$out += $Comment | Select-Object @{n = $Enum.Words.Event; e = {$State}},$Enum.Strings.CreatedAt
		}
	}
	Return $out
}

Function Get-VerifyMMC {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$Comments = (Get-PRComments -PR $PR | Select-Object $Enum.Strings.CreatedAt,@{n = $Enum.Strings.UserName; e = {$_.user.login -replace $Enum.Strings.BotPrefix}},body)
	
	[array]$MissingProperties = ($Comments.body | Where-Object {$_ -match $Enum.MMC.ManifestsHeader}) -split $Enum.Char.LineBreak | Where-Object { $_ -notmatch $Enum.MMC.ManifestsHeader -AND
	 $_ -notmatch $Enum.MMC.MissingProperties} #-AND
	 # $_ -notmatch "Icons" -AND
	 # $_ -notmatch "Platform" -AND
	 # $_ -notmatch "MinimumOSVersion" -AND
	 # $_ -notmatch "ReleaseNotes" -AND
	 # $_ -notmatch "ReleaseNotesUrl" -AND
	 # $_ -notmatch "ReleaseDate"}

	[array]$MMCExceptionList = (Get-Content $MMCExceptionListFile) -split $Enum.Char.LineBreak
	 foreach ($Exception in $MMCExceptionList) {
		 $MissingProperties = $MissingProperties | Where-Object { $_ -notmatch $Exception}
	 }
	if (!$MissingProperties) {
		Get-RemovePRLabel -PR $PR -LabelName $Enum.PRLabels.MMC
	}
}

Function Get-DuplicateCheck {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR 
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$mainPRLabels = ((Invoke-GitHubPRRequest -PR $PR -Type $Enum.prRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name)
	[int]$mainPR = 0
	[int]$closePR = 0

	if ($mainPRLabels -match $Enum.PRLabels.VC) { #If this PR is VC
		#Get the PR number for the other duplicate.
		$Comments = Get-PRComments -PR $PR
		$otherPR = $Comments.body | Where-Object {$_ -match $Enum.Strings.FoundDuplicatePullRequest} 
		$otherPR = $otherPR -split $Enum.Char.LineBreak
		[int]$otherPR = (($otherPR | where {$_ -match $Enum.Regex.hashPRRegex}) -split $Enum.Char.Hash)[$Enum.Index.Last]
		$otherPRLabels = ((Invoke-GitHubPRRequest -PR $otherPR -Type $Enum.prRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name)
		
			#If this PR is VC,
				#If other is VC,
					#If other is MA, close this.
					#If other is not MA, close the lower number as other.
					#if this is CLA
						#if other is CLA, do nothing.
						#If other is not MA, close other.
				#If other is not VC, close other.
				
				#If this is on Auth list but other is not
				
				
		
		if ($otherPRLabels -match $Enum.PRLabels.VC) { #If other PR is VC
			if ($otherPRLabels -match $Enum.PRLabels.MA) { #If other is VCMA, close this.
				$mainPR = $otherPR
				$closePR = $PR
			} else { #If other is not MA, close the lower number as other.
				$mainPR = [math]::Max($PR,$otherPR)
				$closePR = [math]::Min($PR,$otherPR)
			}# end if Moderator-Approved
		} else { #If other is not VC, close other.
			$mainPR = $PR
			$closePR = $otherPR
		}# end if Validation-Completed

		if ($mainPRLabels -match $Enum.PRLabels.CLA) { #if both are VC and CLA, do nothing.
		} else { 
			if ($otherPRLabels -match $Enum.PRLabels.CLA) {#if both are VC and this is CLA, close this.
			} else { 
			}# end if mainPRLabels
		}# end if mainPRLabels

		if ($closePR -gt 0) { 
			Get-GitHubPreset -Preset $Enum.GitHubPresets.Duplicate -PR $closePR -UserInput $mainPR
			Get-RemovePRLabel -PR $mainPR -Label $Enum.PRLabels.PD
		}# end if closePR
	}# end if mainPRLabels
}# end function

#ADO tools
Function Get-CheckData {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[int]$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$PRData = (Get-PRData $PR),
		$headSha = $PRData.head.sha,
		$CheckData = (Invoke-GitHubRequest "$GitHubApiBaseUrl/commits/$headSha/check-runs?per_page=100&filter=latest" -JSON)
	)
	process {
		Return $CheckData.check_runs #| Select-Object id, name, status, conclusion, started_at, completed_at | ft
	}
}

Function Get-ADOValidationStatus {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[switch]$Browser,
		[switch]$WhatIf
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$PRbuild = (Get-BuildFromPR -PR $PR)
	$LogNumber = (55)
	$URL = "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$PRbuild/logs/$LogNumber"
	if ($Browser) { Start-Process $URL;Return $Null}
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR URL: $($URL)"}
	$Content = (Invoke-GitHubRequest $URL -ProgressAction SilentlyContinue).content
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR Content Length: $($Content.Length)"}
	$Log = ($Content -join $Enum.Char.Blank -split $Enum.Char.LineBreak) -replace $Enum.Char.EscapedStar,$Enum.Char.Blank -split $Enum.Char.LineBreak | where {$_.length -gt 1}
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR Log Length: $($Log.Length)"}
	$LogLines = ($Log | Select-String $Enum.Words.Installation).LineNumber
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR LogLines: $($LogLines)"}
	# $LogEntries = $Log -join $Enum.Char.LineBreak -replace "\*",$Enum.Char.Blank -split "Installation Validation Progress Report" -split "Installation Verification"
	$LogEntries = $Log -join $Enum.Char.LineBreak -replace $Enum.Char.EscapedStar,$Enum.Char.Blank
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR LogEntries: $($LogEntries.Length)"}
	
	$out = @()
	# foreach ($LogEntry in $LogEntries){
	for ($i = 0; $i -lt ($LogLines.Length - $Enum.Num.One); $i++) {	
	$LogEntry = ($LogEntries -split $Enum.Char.LineBreak)[$LogLines[$i]..($LogLines[$i + $Enum.Num.One] - $Enum.Num.Two)]
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR $i LogEntry: $($LogEntry.Length)"}
		try{ 
			$Date = (Get-Date ($LogEntry -split $Enum.Char.LineBreak)[$Enum.Index.Last])
			$Date = [System.TimeZoneInfo]::ConvertTimeFromUtc($Date,(Get-TimeZone $Enum.Strings.Pst))
		} catch {
			$Date = $Enum.Strings.NoData
		}
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR $i Date: $Date"}
		# $ThisLog = $Log[($LogLines[$i] + $Enum.Num.One)..($LogLines[$I + $Enum.Num.One] - 3)] #This cuts the stars off the top and bottom.
		$Statii = (($LogEntry -split $Enum.Char.LineBreak | Select-String "Status") | Get-YamlValue -Key "Status" -JSON) -replace $Enum.char.DoubleQuote,$Enum.Char.Blank
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR $i Statii: $Statii"}
		if ($Statii) {
			$Mid = $Enum.Char.Blank | Select-Object @{n = "PR"; e = {$PR}}, @{n = "Date"; e = {$Date}}, @{n = "Statii"; e = {$Statii}}
	if ($WhatIf) { Write-Host "$($MyInvocation.MyCommand.name): $PR $i Mid: $Mid"}
			$Out += $Mid
		}
	} 
	Return $Out
}

Function Get-ADOLastStatus {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[int]$WaitingMinutes
	)
	Process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$Statii = Get-ADOValidationStatus -PR $PR
		$Last = $Statii[$Enum.Index.Last]
		if ($Last.Statii -match $Enum.ADOValidationStatus.InProgress) {
			$TotalMinutes = ((get-date) - (get-date $Last.Date)).totalminutes
			if ($TotalMinutes -gt 180) {#3 hour timeout
				Write-Host "ADOLastStatus InProgress Reply-ToPR $PR"
				Reply-ToPR -PR $PR -body $Enum.Strings.WingetbotRun
			} else {
				Write-Host "ADOLastStatus $($PR): $TotalMinutes"
			}
		} else {
			if ($Last.Statii -match $Enum.ADOValidationStatus.Waiting) {
				if ($TotalMinutes -gt $WaitingMinutes) {
					Write-Host "ADOLastStatus Waiting Reply-ToPR $PR"
					Reply-ToPR -PR $PR -body $Enum.Strings.WingetbotRun
				}
			} else {
				Write-Host "ADOLastStatus $($PR): $($Last.Statii -join ' ')"
			}
		}
	}#end Process
}

Function Get-PRStateFromAPI {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Data = (Get-CheckData -PR $PR2)
	)
	$in = (($Data | where {$_.name -match "Installation Validation"}).output.text -split $Enum.Char.LineBreak)
	$out = @()
	$in[$Enum.Num.Two..($in.Count -$Enum.Num.Two)] -replace "Status: " | %{
		$Date, $time, $event = $_.split(' '); 
		$event = $event -join $Enum.Char.Space 
		$mid = $Enum.Char.Blank | Select-Object @{n = $Enum.Words.Event; e = {$event}},@{n = $Enum.Strings.CreatedAt; e = {Get-Date "$Date $time"}}
		$out += $mid 
	}
	return $out
}

Function Get-PRFailData {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Data = (Get-CheckData -PR $PR2)
	)
	process {
		$in = ($Data | where {$_.name -match "`\. "} | where {$_.conclusion -match $Enum.PRCheckStates.Failure})
		$out = $in.output.text -split $Enum.Char.LineBreak
		return $out
	}
}

Function Get-ParseGHAppData {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Data = (Get-PRFailData -PR $PR2)
	)
	Process {
		$out = $Enum.Char.Blank
		[array]$h3 = ($Data | Select-string '###').LineNumber
		
		$chunks = $Data.split($h3)
		foreach ($Location in $h3) {
			$Location = $Location -1
			$out = $out | Select-Object *, @{n = 'New Property'; e = {23}}, @{n = $Enum.Words.Something; e = {$false}}
		}
		$start = ($Data | select-string '```log').LineNumber
		$end = ($Data | select-string '```').LineNumber
		
		$mid = $Data.output.text -split $Enum.Char.LineBreak
		$out = $out | Select-Object *, @{n = 'New Property'; e = {23}}, @{n = $Enum.Words.Something; e = {$false}}
		return $out
	}
}

Function Get-PRStateFromBoth {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$PRStateFromAPI = (Get-PRStateFromAPI -PR $PR2),
		$PRStateFromComments = (Get-PRStateFromComments -PR $PR2)
	)
	$out = $PRStateFromAPI + $PRStateFromComments | sort $Enum.Strings.CreatedAt
	Return $out
}

#Autowaiver
Function Get-AddToAutowaiver {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$RemoveLabel,
		$AutowaiverData = (Get-Content $AutowaiverFile | ConvertFrom-Csv),
		$PRCommits = (Get-CommitFile -PR $PR),
		$PackageIdentifier = (Get-SchemaCheck -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier -InputData $PRCommits),
		[switch]$AlsoRunAutowaiver
	)
	Process {
		if ($PackageIdentifier.Length -gt 1) {
			Write-Host "$($MyInvocation.MyCommand.name): $PR - Adding $PackageIdentifier to $AutowaiverFile"
			$NewLine = $Enum.Char.Blank | Select-Object $Enum.AutowaiverColumns.PackageIdentifier,$Enum.AutowaiverColumns.ManifestValue,$Enum.AutowaiverColumns.ManifestKey,$Enum.AutowaiverColumns.RemoveLabel
			$NewLine.PackageIdentifier = $PackageIdentifier
			$NewLine.RemoveLabel = $RemoveLabel
			if (($RemoveLabel -eq $Enum.PRLabels.VD) -or ($RemoveLabel -eq $Enum.PRLabels.VUU)) {
				$PRCommits = Get-CommitFile -PR $PR -MatchName $Enum.ManifestFileTypes.Installer
				$NewLine.ManifestValue = ((Get-YamlValue -Key InstallerUrl -clip $PRCommits) -split $Enum.Char.Slash)[$Enum.Num.Two]
				$NewLine.ManifestKey = $Enum.ManifestKeys.InstallerUrl
			} else {
				$NewLine.ManifestValue = $PackageIdentifier
				$NewLine.ManifestKey = $Enum.ManifestKeys.PackageIdentifier
			}

			$AutowaiverData += $NewLine
			($AutowaiverData | Sort-Object PackageIdentifier | ConvertTo-Csv) | Out-File $AutowaiverFile
			if ($AlsoRunAutowaiver) {
				Get-Autowaiver -PR $PR
			}
		}#end if PackageIdentifier.Length
	}
}#end function

Function Get-Autowaiver {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR2),
		$PRCommits = (Get-CommitFile -PR $PR2),
		$PackageIdentifier = (Get-SchemaCheck -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier -InputData $PRCommits),
		$AutowaiverData = (Get-Content $AutowaiverFile | ConvertFrom-Csv),
		$WaiverData = ($AutowaiverData | ?{$_.PackageIdentifier -eq $PackageIdentifier}),
		$PRLabels = (invoke-GitHubPRRequest -PR $PR2 -Type labels -Method $Enum.PRRequestMethods.Get -Output Content).name,
		[switch]$WhatIf
	)
	Process {
		$PR = $PR2
		Write-Host "$($MyInvocation.MyCommand.name) $PR"
		$PRLabels = $PRLabels | where {$_ -notmatch "Waived"}
		$JoinLabels = ($PRLabels -join $Enum.Char.Space)

		if ($WaiverData) {
			Add-PRToRecord -PR $PR -Action $Enum.PRActions.Waiver
			if ($WhatIf) {Write-Host "JoinLabels $JoinLabels"}
		}
		foreach ($Waiver in $WaiverData) {
			if ($WhatIf) {Write-Host "Waiver $Waiver"}
			if ($JoinLabels -match $Waiver.RemoveLabel) {
				if ($Waiver.RemoveLabel -eq $Enum.PRLabels.PD) {
					Write-Host "PR: $PR - Completing PR for $PackageIdentifier"
					if ($WhatIf) {
						"Get-RemovePRLabel -PR $PR -LabelName $($Waiver.RemoveLabel)"
						"Get-RemovePRLabel -PR $PR -LabelName $($Enum.PRLabels.NAF)"
						"Get-RemovePRLabel -PR $PR -LabelName $($Enum.PRLabels.NA)"
						"Get-AddPRLabel -PR $PR -LabelName $($Enum.PRLabels.VC)"
					} else {
						Get-RemovePRLabel -PR $PR -LabelName $Waiver.RemoveLabel
						Get-RemovePRLabel -PR $pr -LabelName $Enum.PRLabels.NAF
						Get-RemovePRLabel -PR $pr -LabelName $Enum.PRLabels.NA
						Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.VC
					}
				} else {
					try {
						if ($Waiver.ManifestKey -eq $Enum.ManifestKeys.InstallerUrl) {
							$PRCommits = Get-CommitFile -PR $PR -MatchName $Enum.ManifestFileTypes.Installer
						}
						$PackageValue = (Get-YamlValue -Key $Waiver.ManifestKey -clip $PRCommits)
						if ($WhatIf) {Write-Host "PackageValue $PackageValue"}
					} catch {}
					if ($PackageValue -match $Waiver.ManifestValue) {
					Write-Host "PR: $PR - Adding $($Waiver.RemoveLabel) waiver for $PackageIdentifier"
						if ($WhatIf) {
							"Reply-ToPR -PR $PR -body '$($Enum.Strings.WingetbotWaiversAdd) $($Waiver.RemoveLabel)'"
						} else {
							Reply-ToPR -PR $PR -body "$($Enum.Strings.WingetbotWaiversAdd) $($Waiver.RemoveLabel)"
						}
					} else {
						Write-Host "PR: $PR - PackageIdentifier $PackageIdentifier - $PackageValue notmatch $($Waiver.ManifestValue)"
					}; #end if PackageValue
				}; #end if Waiver.RemoveLabel
			} else {
				if ($WhatIf) {
					"$JoinLabels -notmatch $($Waiver.RemoveLabel)"
				} 
			}; #end foreach Waiver
		}; #if WaiverData
	} #Process
}; #end Get-Autowaiver

#Network tools
#GET = Read; POST = Append; PUT = Write; DELETE = delete
Function Invoke-GitHubRequest {
	Param(
		[Parameter(Mandatory)][string]$Uri,
		[string]$Body,
		[ValidateScript( { $_ -in (Get-Keys $Enum.PRRequestMethods)} )][string]$Method = $Enum.PRRequestMethods.Get,
		$Headers = @{$Enum.GitHubRequestHeaders.AuthorizationKey = "Bearer $GitHubToken"; $Enum.GitHubRequestHeaders.AcceptKey = $Enum.GitHubRequestHeaders.AcceptValue; $Enum.GitHubRequestHeaders.ApiKey = $Enum.GitHubRequestHeaders.ApiValue},
		[switch]$JSON,
		$out = $Enum.Char.Blank
	)
	if ($Body) {
		try {
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -ContentType application/json -ProgressAction SilentlyContinue)
		} catch {
			# Write-Output ("Error: $($error[$Enum.Index.First].ToString()) - Uri $Uri - Body: $Body")
			$out = ("Error: $($error[$Enum.Index.First].ToString()) - Uri $Uri - Body: $Body")
			if ($out -match $Enum.Strings.ApiRateLimitExceeded) {
				Get-GitHubTimeout
			}
			
		}
	} else {
		try {
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -ProgressAction SilentlyContinue)
		} catch {
			$out = ("Error: $($error[$Enum.Index.First].ToString()) - Uri $Uri - Body: $Body")
			if ($out -match $Enum.Strings.ApiRateLimitExceeded) {
				Get-GitHubTimeout
			}
		}
	}
	
	if ($out -match $Enum.Strings.ApiRateLimitExceeded) {
		Get-GitHubTimeout
	}
	#GitHub requires the value be the .body property of the variable. This makes more sense with Curl, where this is the -data parameter. However with Invoke-WebRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.
	#if (!($Silent)) {
		if (($JSON)){# -OR ($Output -eq $Enum.PRRequestOutput.Content)) {
			try {$out | ConvertFrom-Json} catch {$out}
		} else {
			$out
		}
	#}
	Start-Sleep $GitHubRateLimitDelay;
}

Function Check-PRInstallerStatusInnerWrapper {
	Param(
		$Url,
		$Out = $Enum.Char.Blank
	)
	try {
		$Out = (Invoke-GitHubRequest $Url -Method $Enum.PRRequestMethods.Head -ErrorAction SilentlyContinue -ProgressAction SilentlyContinue).StatusCode
	} catch {}
	return $Out
}

#Validation Starts Here
#Validation Starts Here
#Validation Starts Here
Function Get-TrackerVMValidate {#Clip - ManifestForValidation
	Param(
		$QueryClipboard = (Get-QueryClipboard $Enum.ClipboardQueries.TrackerVMValidate),
		[ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = (Get-OSFromVersion),
		[int]$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData ((Get-NextFreeVM -OS $OS) -replace$Enum.Strings.Vm,$Enum.Char.Blank)),
		[ValidateScript( { $_ -in (Get-Keys $Enum.PRTrackerOperations) } )][string]$Operation = $Enum.PRTrackerOperations.Scan,
		[int]$PR = ($QueryClipboard.PRNumber),
		[string]$ManualDependency,
		[string]$PackageIdentifier = ($QueryClipboard.PackageIdentifier),
		[string]$PackageVersion = ($QueryClipboard.PackageVersion),
		[string]$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		[string]$installerLine = "--manifest $RemoteFolder/manifest",
		[string]$InstallerType,
		[string]$Locale,
		[ValidateScript( { $_ -in (Get-Values $Enum.Arch) } )][string]$Arch,
		[ValidateScript( { $_ -in (Get-Keys $Enum.ManifestScope) } )][string]$Scope,
		[switch]$InspectNew,
		[switch]$notElevated,
		[switch]$NoFiles,
		[switch]$Force,
		[switch]$Silent,
		[switch]$PauseAfterInstall,
		[switch]$NoStaleCheck,
		[string]$optionsLine = $Enum.Char.Blank
	)
	Write-Host "Starting Manual Validation build $build on vm$VM for package $PackageIdentifier version $PackageVersion in PR $PR"
	# Get-TrackerVMSetStatus $Enum.VMStatus.Prevalidation $VM -PackageIdentifier $PackageIdentifier -PR $PR -Silent
	<#Sections:
	Construct WinGet args string and populate script variables.
	- If Configure - skip all of this and just add the Configure file as the WinGet arg.
	Construct the VM script from the script variables and output to commands file.
	- If Configure - Construct a similar script and perform the same output.
	Construct the manifest from the files in the clipboard.
	- If NoFiles, skip.
	Perform new package inspection.
	- If not InspectNew, skip.
	Revert selected VM and launch its window.
	#>

	if (($PackageIdentifier) -AND ($PackageIdentifier -ne $Enum.ManifestKeys.PackageIdentifier)) {
		Test-Admin
		
		#Check if PR is open
		$PRState = Invoke-GitHubPRRequest -PR $PR -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content
		
		$LabelList = (Invoke-GitHubPRRequest -PR $PR -Type labels -Output $Enum.PRRequestOutput.Content).name
		$JoinLabels = ($LabelList -join $Enum.Char.Space)
		if ($Force -OR 
		!(($JoinLabels -match $Enum.PRLabels.MA) -AND 
			($JoinLabels -match $Enum.PRLabels.CR) -AND 
			($JoinLabels -match $Enum.PRLabels.NP)) -OR 
		($PRState.merged -ne $False) -OR 
		($PRState.state -ne $Enum.PRStates.Open)) {
			if ($vm -eq 0){
				Write-Host "No available $OS VMs";
				Get-PipelineVmGenerate -OS $OS;
				#Break;
			}
			$PackageMode = $Enum.VmModes.Unknown
			if ($JoinLabels -match $Enum.PRLabels.NP) { 
				$PackageMode = $Enum.VmModes.New
			} elseif ($JoinLabels -match $Enum.PRLabels.NM) { 
				$PackageMode = $Enum.VmModes.Existing
			} else {
				Write-Host "No Package/Manifest label in JoinLabels: $JoinLabels checking source..."
				if ($null -match (Get-ManifestVersion $PackageIdentifier)) {
					$PackageMode = $Enum.VmModes.New
					Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.NP
					Get-removePRLabel -PR $PR -LabelName $Enum.PRLabels.NM
				} else {
					$PackageMode = $Enum.VmModes.Existing
					Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.NM
					Get-removePRLabel -PR $PR -LabelName $Enum.PRLabels.NP
				}
			}
			Write-Host "PackageMode: $PackageMode"
			
			if ((($valMode -match $Enum.TrackerModes.NoNew) -AND ($PackageMode -eq $Enum.VmModes.New)) -OR 
			(($valMode -match $Enum.TrackerModes.OnlyNew) -AND ($PackageMode -eq $Enum.VmModes.Existing))) {
				$PackageIdentifier = $Enum.Char.Blank
				return $Enum.Char.Blank
			}

			$PostInstallPause = $Enum.Char.Blank
			if ($PauseAfterInstall) {
				$PostInstallPause = "Read-Host 'Install complete, press ENTER to continue...'"
			}
			if ($Silent) {
				Get-TrackerVMSetStatus -Status $Enum.VMStatus.Prevalidation $VM -PackageIdentifier $PackageIdentifier -PR $PR -Mode $PackageMode -Silent
			} else {
				Get-TrackerVMSetStatus -Status $Enum.VMStatus.Prevalidation $VM -PackageIdentifier $PackageIdentifier -PR $PR -Mode $PackageMode
			}
			if ((Get-VM ("vm$VM")).state -ne $Enum.PRTrackerStates.Running) {Start-VM ("vm$VM")}

				$logLine = "$OS "
				$nonElevatedShell = $Enum.Char.Blank
				$logExt = "log"
				$VMFolder = "$MainFolder\vm\$vm"
				$manifestFolder = "$VMFolder\manifest"
				$CmdsFileName = "$VMFolder\cmds.ps1"

			if ($Operation -eq $Enum.PRTrackerOperations.Configure) {
				if (!($Silent)) {
					Write-Host "Running Manual Config build $build on vm$VM for ConfigureFile"
				}
				$wingetArgs = "configure -f $RemoteFolder/manifest/config.yaml --accept-configuration-agreements --disable-interactivity"
				$Operation = $Enum.PRTrackerOperations.Configure
				$InspectNew = $False
			} else {
					Add-PRToRecord -PR $PR -Action $Enum.PRActions.Manual -Title $PRtitle
				if ($PackageIdentifier -eq $Enum.Char.Blank) {
					Write-Host "Bad PackageIdentifier: $PackageIdentifier"
					#Break;
					$PackageIdentifier | clip
				}
				if (!($Silent)) {
					Write-Host "Running Manual Validation build $build on vm$VM for package $PackageIdentifier version $PackageVersion"
				}
				
				if ($PackageVersion) {
					$logExt = $PackageVersion+"." + $logExt
					$logLine += "version $PackageVersion "
				}
				if ($Locale) {
					$logExt = $Locale+"." + $logExt
					$optionsLine += " --locale $Locale "
					$logLine += "locale $Locale "
				}
				if ($Scope) {
					$logExt = $Scope+"." + $logExt
					$optionsLine += " --scope $Scope "
					$logLine += "scope $Scope "
				}
				if ($InstallerType) {
					$logExt = $InstallerType+"." + $logExt
					$optionsLine += " --installer-type $InstallerType "
					$logLine += "InstallerType $InstallerType "
				}
				$Archs = $QueryClipboard.Architecture
				$archDetect = $Enum.Char.Blank
				$archColor = $Enum.PSColors.Yellow
				if ($Archs) {
					if ($Archs[$Enum.Index.First].Length -ge $Enum.Num.Two) {
						if ($Arch) {
							$archDetect = "Selected"
						} else {
							$Arch = $Archs[$Enum.Index.First]
							$archDetect = "Detected"
						}
						$archColor = $Enum.PSColors.Red
					} else {
						if ($Archs -eq "neutral") {
							$archColor = $Enum.PSColors.Yellow
						} else {
						$Arch = $Archs
						$archDetect = "Detected"
						$archColor = $Enum.PSColors.Green
						}
					}
				}
				if ($Arch) {
					$logExt = $Arch+"." + $logExt
					if (!($Silent)) {
						Write-Host "$archDetect Arch $Arch of available architectures: $Archs" -f $archColor
					}
					$logLine += "$Arch "
				}
				$MDLog = $Enum.Char.Blank
				if ($ManualDependency) {
					$MDLog = $ManualDependency
					if (!($Silent)) {
						Write-Host " = = = = Installing manual dependency $ManualDependency = = = = "
					}
					[string]$ManualDependency = "Out-Log 'Installing manual dependency $ManualDependency.';Start-Process 'winget' 'install " + $ManualDependency+" --accept-package-agreements --ignore-local-archive-malware-scan' -wait`n"
				}
				if ($notElevated -OR $QueryClipboard.ElevationRequirement) {
					if (!($Silent)) {
						Write-Host " = = = = Detecting de-elevation requirement = = = = "
					}
					$nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\Program Files\PowerShell\7\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}"
					#If elevated, run^^ and exit, else run cmds.
				}
				$packageName = ($PackageIdentifier -split "[.]")[$Enum.Index.Second]
				$wingetArgs = "install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan"
			}
			$cmdsOut = $Enum.Char.Blank

		switch ($Operation) {
		$Enum.PRTrackerOperations.Configure {
		$cmdsOut = "$nonElevatedShell
		`$TimeStart = Get-Date;
		`$ConfigurelLogFolder = `"$SharedFolder/logs/Configure/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
		Function Out-Log ([string]`$logData,[string]`$logColor = 'cyan') {
			`$TimeStamp = (Get-Date -Format $($Enum.Char.T)) + ': ';
			`$logEntry = `$TimeStamp + `$logData
			Write-Host `$logEntry -f `$logColor;
			md `$ConfigurelLogFolder -ErrorAction Ignore
			`$logEntry | Out-File `"`$ConfigurelLogFolder/$PackageIdentifier.$logExt`" -Append -Encoding unicode
		};
		Function Out-ErrorData ([array]`$errArray,[string]`$serviceName,`$errorName = 'errors') {
			Out-Log `"Detected `$(`$errArray.Count) `$serviceName `$(`$errorName): `"
			`$errArray | ForEach-Object {Out-Log `$_ 'red'}
		};
		Get-TrackerVMSetStatus 'Installing'
		Out-Log ' = = = = Starting Manual Validation pipeline build $build on VM $VM Configure file $logLine = = = = '

		Out-Log 'Pre-testing log cleanup.'
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

		Out-Log `"Main Package Configure with args: $wingetArgs`"
		`$mainpackage = (Start-Process 'winget' '$wingetArgs' -wait -PassThru);

		Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
		If (`$mainpackage.ExitCode -ne 0) {
			Out-Log 'Install Failed.';
			explorer.exe `$WinGetLogFolder;
		Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
		Out-ErrorData '$MDLog' 'Manual' 'Dependency'
		Out-ErrorData `$Error 'PowerShell'
		Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'

		Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for Configure file $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'ValidationCompleted'
			Break;
		}
		Read-Host 'Configure complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.

		Get-TrackerVMSetStatus 'Scanning'

		`$WinGetLogs = ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}})
		`$DefenderThreat = (Get-MPThreat).ThreatName

		Out-ErrorData `$WinGetLogs 'WinGet'
		Out-ErrorData `$Error 'PowerShell'
		Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
		Out-ErrorData `$DefenderThreat `"Defender (with Security Intelligence version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

		Out-Log `" = = = = Completing Manual Validation pipeline build $build on VM $VM for Configure file $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'ValidationCompleted'

		"
			}#end Configure
		$Enum.PRTrackerOperations.Scan {
		$cmdsOut = "$nonElevatedShell
		`$TimeStart = Get-Date;
		`$explorerPid = (Get-Process Explorer).id;
		`$removetoken = 'REMOVEDELETEREMOVEDELETE'
		`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
		`$WinGetLogFolder = 'C:\Users\User\AppData\Local\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir'
		Function Out-Log ([string]`$logData,[string]`$logColor = 'cyan') {
			`$TimeStamp = (Get-Date -Format $($Enum.Char.T)) + ': ';
			`$logEntry = `$TimeStamp + `$logData
			Write-Host `$logEntry -f `$logColor;
			md `$ManValLogFolder -ErrorAction Ignore
			`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append -Encoding unicode
		};
		Function Out-ErrorData ([array]`$errArray,[string]`$serviceName,`$errorName = 'errors') {
			Out-Log `"Detected `$(`$errArray.Count) `$serviceName `$(`$errorName): `"
			`$errArray | ForEach-Object {Out-Log `$_ 'red'}
		};
		Function Get-TrackerProgress {
			Param(
				`$File,
				`$Activity,
				`$Hunkrementor,
				`$Length,
				`$Percent = [math]::round(`$Hunkrementor / `$length*100,2)
			)
		};
		Get-TrackerVMSetStatus -Status 'Installing' -Package $PackageIdentifier -PR $PR
		
		Out-Log ' = = = = Starting Manual Validation pipeline build $build on VM $VM $PackageIdentifier $logLine = = = = '

		Out-Log 'Pre-testing log cleanup.'
		Out-Log 'Upgrading installed applications.'
		Out-Log (WinGet upgrade --all --include-pinned --disable-interactivity)
		Out-Log 'Clearing PowerShell errors.'
		`$Error.Clear()
		Out-Log 'Clearing Application Log.'
		Clear-EventLog -LogName Application -ErrorAction Ignore
		Out-Log 'Clearing WinGet Log folder.'
		rm `$WinGetLogFolder\*
		Out-Log 'Updating Defender Security Intelligence version.'
		Update-MpSignature
		Out-Log 'Gathering WinGet info.'
		`$info = winget --info
		Out-ErrorData @(`$info[0],`$info[3],`$info[4],`$info[5]) 'WinGet' 'infos'

		`$InstallStart = Get-Date;
		Out-Log 'Starting preinstall filescan.'
		`$PreinstallFilesystem = &cmd /c 'dir C:\ /b /s'
		`$PreinstallFileCount = `$PreinstallFilesystem.Count
		Out-Log `"Completing preinstall filescan. Read `$PreinstallFileCount files.`"
		$ManualDependency
		Out-Log `"Main Package Install with args: $wingetArgs`"
		`$mainpackage = (Start-Process 'winget' '$wingetArgs' -wait -PassThru);
		Out-Log `"Install finished with exit code: `$(`$mainpackage.ExitCode)`";
		`$SleepSeconds = 15 #Sleep a few seconds for processes to complete.
		if ((`$InstallStart).AddSeconds(`$SleepSeconds) -gt (Get-Date)) {
			sleep ((`$InstallStart).AddSeconds(`$SleepSeconds)-(Get-Date)).totalseconds
		} 
		`$InstallEnd = Get-Date;

		If (`$mainpackage.ExitCode -ne 0) {
			Out-Log 'Install Failed.';
			explorer.exe `$WinGetLogFolder;

			`$WinGetLogs = ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {
				Get-Content `$_ | Where-Object {
					`$_ -match '[[]FAIL[]]' -OR 
					`$_ -match 'failed' -OR 
					`$_ -match 'error' -OR 
					`$_ -match 'does not match'
				}
			})
			`$DefenderThreat = (Get-MPThreat).ThreatName
			`$SigVer = (Get-MpComputerStatus).QuickScanSignatureVersion

			Out-ErrorData `$WinGetLogs 'WinGet'
			Out-ErrorData '$MDLog' 'Manual' 'Dependency'
			Out-ErrorData `$Error 'PowerShell'
			Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
			Out-ErrorData `$DefenderThreat `"Defender (with Security Intelligence version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

			Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"

			if ((`$WinGetLogs -match '\[FAIL\] Installer failed security check.') -OR 
			`$DefenderThreat) {
				Send-SharedError -clip (`$WinGetLogs + ' <!--`n[Policy] Validation-Defender-Error `n-->' + '`n' + 'Detection: ' + `$DefenderThreat + '`n' + 'Defender Security Intelligence version: ' + `$SigVer)
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'SendStatus' -Package $PackageIdentifier -PR $PR
			} elseif (
			(`$WinGetLogs -match 'Package hash verification failed') -OR 
			(`$WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Send-SharedError -clip (`$WinGetLogs + ' <!--`n[Policy] Error-Hash-Mismatch `n-->')
				Out-Log $WinGetLogs
				Get-TrackerVMSetStatus 'SendStatus' -Package $PackageIdentifier -PR $PR
			} elseif ((`$WinGetLogs -match 'The multi file manifest has inconsistent field values') -OR 
			(`$WinGetLogs -match 'valid root file')) {
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Out-Log $WinGetLogs
				Get-TrackerVMSetStatus 'Complete' -Package $PackageIdentifier -PR $PR
			} elseif ((`$WinGetLogs -match 'Download request failed. Returned status: 404')) {
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Out-Log $WinGetLogs
				Send-SharedError -clip (`$WinGetLogs + ' <!--`n[Policy] Validation-404-Error `n-->')
				Get-TrackerVMSetStatus 'SendStatus' -Package $PackageIdentifier -PR $PR
			} elseif (`$mainpackage.ExitCode -eq '-1978335216') { #arm64 package
				Get-TrackerVMSetStatus 'Approved'
			} else {
				Get-TrackerVMSetStatus 'ValidationCompleted' -Package $PackageIdentifier -PR $PR
			}

			Break;
		}
		$PostInstallPause
		Function Get-ScanStep {
			Get-TrackerVMSetStatus 'Scanning' -Package $PackageIdentifier -PR $PR
			Out-Log 'Install complete, starting second filesystem scan.'

			`$files = ''
			if (Test-Path `$RemoteFolder\files.txt) {#If we have a list of files to run - a relic from before automatic file gathering. 
				`$files = Get-Content `$RemoteFolder\files.txt
			} else {
				`$PostinstallFilesystem = &cmd /c 'dir C:\ /b /s'
				`$PostinstallFileCount = `$PostinstallFilesystem.Count
				Out-Log `"Completing postinstall filescan. Read `$PostinstallFileCount files, a difference of `$(`$PostinstallFileCount - `$PreinstallFileCount) files.`"
				`$files = (Compare-Object `$PreinstallFilesystem `$PostinstallFilesystem | where {`$_.SideIndicator -eq '=>'}).inputobject
				
				`$list = 'AppRepository','assembly', 'CbsTemp', 'CryptnetUrlCache', 'CacheStorage', 'Cache_Data', 'Code Cache', 'DesktopAppInstaller', 'dump64a', 'EdgeCore', 'EdgeUpdate', 'EdgeWebView', 'ErrorDlg', 'ErrorDialog', 'Microsoft\\Edge\\Application', 'Microsoft\\Copilot', 'Microsoft.Copilot', 'Microsoft\\Defender', 'Microsoft\\Diagnosis', 'Microsoft\\Edge\\Temp', 'msedge', 'NativeImages', 'Prefetch', 'Provisioning', 'redis', 'servicing', 'ServiceProfiles', 'Start Menu', 'System32', 'SystemTemp', 'SysWOW64', 'unins', 'waasmedic', 'C:\\Windows', 'Windows\\Explorer', 'WinSxS'
				
				`$files = `$files -join ';'
				foreach (`$item in `$list) {
					`$files = `$files -replace `$item,`$removetoken
				}
				`$files = `$files -split ';'
				`$files = `$files | Where-Object {`$_ -notmatch `$removetoken} | sort -unique
			
			}

			Out-Log `"Reading `$(`$files.Count) file changes in the last `$(((Get-Date) -`$InstallEnd).TotalSeconds) seconds. Starting bulk file execution:`"
			`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'
			`$files | Select-String '[.]exe`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
			`$files | Select-String '[.]msi`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
			`$files | Select-String '[.]lnk`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};

			Out-Log `" = = = = End file list. Starting Defender scan. = = = = = `"
			Start-MpScan;

			Out-Log `"Defender scan complete, closing windows...`"
			Get-Process explorer -ErrorAction SilentlyContinue| where {`$_.id -ne `$explorerPid} | Stop-Process
			Get-Process LiveCaptions -ErrorAction SilentlyContinue | Stop-Process
			Get-Process Magnify -ErrorAction SilentlyContinue | Stop-Process -Force
			Get-Process mip -ErrorAction SilentlyContinue | Stop-Process
			Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
			Get-Process Narrator -ErrorAction SilentlyContinue | Stop-Process
			Get-Process osk -ErrorAction SilentlyContinue | Stop-Process -Force
			Get-Process powershell -ErrorAction SilentlyContinue | where {`$_.id -ne `$PID} | Stop-Process -force

			Get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell' -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'} | Stop-Process
			#Get-Process | Where-Object {`$_.id -notmatch `$PID -and `$_.id -notmatch `$explorerPid -and `$_.processname -notmatch `$packageName -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'} | Stop-Process

			`$WinGetLogs = ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}})
			`$DefenderThreat = (Get-MPThreat).ThreatName
			`$SigVer = (Get-MpComputerStatus).QuickScanSignatureVersion

			Out-ErrorData `$WinGetLogs 'WinGet'
			Out-ErrorData '$MDLog' 'Manual' 'Dependency'
			Out-ErrorData `$Error 'PowerShell'
			Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
			Out-ErrorData `$DefenderThreat `"Defender (with Security Intelligence version `$SigVer)`"

			if (`$DefenderThreat) {
				Send-SharedError -clip (`$WinGetLogs + ' <!--`n[Policy] Validation-Defender-Error `n-->' + '`n' + 'Detection: ' + `$DefenderThreat + '`n' + 'Defender Security Intelligence version: ' + `$SigVer)
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'SendStatus' -Package $PackageIdentifier -PR $PR
			} elseif ((`$WinGetLogs -match '\[FAIL\] Installer failed security check.') -OR 
			(`$WinGetLogs -match 'Package hash verification failed') -OR 
			(`$WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){
				Send-SharedError -clip (`$WinGetLogs + ' <!--`n[Policy] Error-Hash-Mismatch `n-->')
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'SendStatus' -Package $PackageIdentifier -PR $PR
			} elseif ((`$WinGetLogs -match 'The multi file manifest has inconsistent field values') -OR 
			(`$WinGetLogs -match 'valid root file')) {
				Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Out-Log $WinGetLogs
				Get-TrackerVMSetStatus 'Complete' -Package $PackageIdentifier -PR $PR
			} elseif ((Get-Content $RemoteTrackerModeFile) -eq 'IEDS') {
				Out-Log `" = = = = Auto-Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'Approved' -Package $PackageIdentifier -PR $PR
			} elseif ((Get-TrackerVMStatus | where {`$_.vm -match `$vm}).Mode -eq 'Existing') {
				Out-Log `" = = = = Auto-Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'Approved' -Package $PackageIdentifier -PR $PR
			} elseif ((Get-TrackerVMStatus | where {`$_.vm -match `$vm}).Mode -eq 'New') {
				Out-Log `" = = = = Attempting Auto-Completion of Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'ValidationCompleted' -Package $PackageIdentifier -PR $PR
				Get-installedVersions
			} else {
				Start-Process PowerShell
				Out-Log `" = = = = Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
				Get-TrackerVMSetStatus 'ValidationCompleted' -Package $PackageIdentifier -PR $PR
			}
		};
	Get-ScanStep


		"
	<#
				`$FileSystem = Get-ChildItem C:\ -Recurse -ErrorAction Ignore -Force
				`$FileSystem = `$FileSystem | sort -unique
				Out-Log 'File system scan complete, finding changed folders by CreationTime.'
				`$CreationTimeDirectories = (
					 `$FileSystem | 
					Where-Object {`$_.CreationTime -gt `$InstallStart} | 
					Where-Object {`$_.CreationTime -lt `$InstallEnd} | 
					%{return `$_}
				).DirectoryName | sort -unique
				Out-Log `"Found `$(`$CreationTimeDirectories.Count) folders. Checking for folders by LastAccessTime.`"
				`$LastAccessTimeDirectories = (
					 `$FileSystem | 
					Where-Object {`$_.LastAccessTime -gt `$InstallStart} | 
					Where-Object {`$_.LastAccessTime -lt `$InstallEnd} | 
					%{return `$_}
				).DirectoryName | sort -unique
				Out-Log `"Found `$(`$LastAccessTimeDirectories.Count) folders. Checking for folders by LastWriteTime.`"
				`$LastWriteTImeDirectories = (
					 `$FileSystem | 
					Where-Object {`$_.LastWriteTIme -gt `$InstallStart} | 
					Where-Object {`$_.LastWriteTIme -lt `$InstallEnd} | 
					%{return `$_}
				).DirectoryName | sort -unique
				Out-Log `"Found `$(`$LastWriteTImeDirectories.Count) folders. Collating...`"
				`$DirectoryList = `$CreationTimeDirectories + `$LastAccessTimeDirectories + `$LastWriteTImeDirectories | sort -unique
				Out-Log `"Found `$(`$DirectoryList.Count) total folders. Checking for files in folders...`"
				`$files = foreach (`$Directory in `$DirectoryList) {`$FileSystem.fullname | select-string `$Directory -SimpleMatch}
				`$files += (Get-ChildItem 'C:\Users\User\AppData\Local\Microsoft\WinGet' -Recurse -ErrorAction Ignore -Force).FullName

	#>
	<#
			`$files = foreach (`$file in `$files) {
				`$file | Where-Object {`$_ -notmatch 'AppRepository'} |
				Where-Object {`$_ -notmatch '\\assembly'} | 
				Where-Object {`$_ -notmatch 'CbsTemp'} | 
				Where-Object {`$_ -notmatch 'CryptnetUrlCache'} | 
				Where-Object {`$_ -notmatch 'DesktopAppInstaller'} | 
				Where-Object {`$_ -notmatch 'dotnet'} | 
				Where-Object {`$_ -notmatch 'dump64a'} | 
				Where-Object {`$_ -notmatch 'EdgeCore'} | 
				Where-Object {`$_ -notmatch 'EdgeUpdate'} | 
				Where-Object {`$_ -notmatch 'EdgeWebView'} | 
				Where-Object {`$_ -notmatch 'ErrorDlg'} | 
				Where-Object {`$_ -notmatch 'ErrorDialog'} | 
				Where-Object {`$_ -notmatch 'Microsoft\\Edge\\Application'} | 
				Where-Object {`$_ -notmatch 'Microsoft\\Diagnosis'} | 
				Where-Object {`$_ -notmatch 'msedge'} | 
				Where-Object {`$_ -notmatch 'NativeImages'} | 
				Where-Object {`$_ -notmatch 'Prefetch'} | 
				Where-Object {`$_ -notmatch 'Provisioning'} | 
				Where-Object {`$_ -notmatch 'redis'} | 
				Where-Object {`$_ -notmatch 'servicing'} | 
				Where-Object {`$_ -notmatch 'ServiceProfiles'} | 
				Where-Object {`$_ -notmatch 'Start Menu'} | 
				Where-Object {`$_ -notmatch '\\System32'} | 
				Where-Object {`$_ -notmatch '\\SystemTemp'} | 
				Where-Object {`$_ -notmatch '\\SysWOW64'} | 
				Where-Object {`$_ -notmatch 'unins'} | 
				Where-Object {`$_ -notmatch 'waasmedic'} | 
				Where-Object {`$_ -notmatch 'C:\\Windows'} | 
				Where-Object {`$_ -notmatch 'Windows\\Explorer'} | 
				Where-Object {`$_ -notmatch '\\WinSxS'}
			}

	#>
			}#end Scan
			Default {
				Write-Host "Error: Bad Function"
				Break;
			}
			} 

				$cmdsOut | Out-File $CmdsFileName

			if ($NoFiles -eq $False) {
				Get-ManifestForValidation -vm $vm -clip $clip -PackageIdentifier $PackageIdentifier -Operation $Operation -Silent $Silent -manifestFolder $manifestFolder
			}#end if NoFiles

<#
			if ($InspectNew) {
				$PackageResult = Find-WinGetPackage $PackageIdentifier
				if (!($Silent)) {
					Write-Host "Searching Winget for $PackageIdentifier"
				}
				Write-Host $PackageResult
				if ($PackageResult -eq "No package found matching input criteria.") {
					Open-AllURL
					Start-Process "https://www.bing.com/search?q = $PackageIdentifier"
					$a,$b = $PackageIdentifier -split "[.]"
					if ($a -ne $Enum.Char.Blank) {
						if (!($Silent)) {
							Write-Host "Searching Winget for $a"
							# Find-WinGetPackage
						}
					}
					if ($b -ne $Enum.Char.Blank) {
						if (!($Silent)) {
							Write-Host "Searching Winget for $b"
							# Find-WinGetPackage
						}
					}
				}
			}
#>
			if (!($Silent)) {
				Write-Host "File operations complete, starting VM operations."
			}
			Get-TrackerVMLaunchWindow $VM
		}
		if (!$NoStaleCheck) {Get-StaleVMCheck}
	}#end if PackageIdentifier
}

Function Get-TrackerVMValidateByID {
	Param(
		[string]$PackageIdentifier
	)
	$PackageIdentifier = Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier 
	Get-TrackerVMValidate -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles #-notElevated
}

Function Get-TrackerVMValidateByConfig {
	Param(
	$PackageIdentifier = "Microsoft.Devhome",
	$ManualDependency = "Git.Git"
	)
	$PackageIdentifier = Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier 
	Get-TrackerVMValidate -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles -ManualDependency $ManualDependency -Operation "DevHomeConfig"
	Start-Sleep $Enum.Num.Two
	Get-TrackerVMValidate -installerLine "--id $ManualDependency" -PackageIdentifier $ManualDependency -NoFiles -Operation "Config"
}

Function Get-TrackerVMValidateByArch {
	Get-TrackerVMValidate -Arch $Enum.Arch.64;
	Start-Sleep $Enum.Num.Two;
	Get-TrackerVMValidate -Arch $Enum.Arch.86;
}

Function Get-TrackerVMValidateByScope {
	Get-TrackerVMValidate -Scope Machine;
	Start-Sleep $Enum.Num.Two;
	Get-TrackerVMValidate -Scope User;
}

Function Get-TrackerVMValidateBothArchAndScope {
	Get-TrackerVMValidate -Arch $Enum.Arch.64 -Scope Machine;
	Start-Sleep $Enum.Num.Two;
	Get-TrackerVMValidate -Arch $Enum.Arch.86 -Scope Machine;
	Start-Sleep $Enum.Num.Two;
	Get-TrackerVMValidate -Arch $Enum.Arch.64 -Scope User;
	Start-Sleep $Enum.Num.Two;
	Get-TrackerVMValidate -Arch $Enum.Arch.86 -Scope User;
}

#Manifests Etc
Function Get-ManifestForValidation { #Clip
	Param(
		[int]$vm,
		$clip,
		[string]$PackageIdentifier = (Get-SchemaCheck -InputData $clip -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier ),
 [ValidateScript( { $_ -in (Get-Keys $Enum.PRTrackerOperations) } )][string]$Operation = $Enum.PRTrackerOperations.Scan,
		[switch]$Silent,
		[switch]$WhatIf,
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest"
	)
	#Extract multi-part manifest from clipboard and write to disk
	if (!($Silent)) {
		Write-Host $Enum.Strings.RemovingPreviousManifestAndAddingCurrent
	}
	Get-RemoveFileIfExist "$manifestFolder" -remake -Silent
	if ($Operation -eq $Enum.PRTrackerOperations.Configure) {
		$FilePath = "$manifestFolder\config.yaml"
		Out-File -FilePath $FilePath -InputObject $clip -NoClobber
	} else {
		$Files = @()
		# $Files += "Package.installer.yaml"
		# $FileNames = ($clip | Select-String "[.]yaml") |ForEach-Object{($_ -split $Enum.Char.Slash)[$Enum.Index.Last]}
		$FileNames = ($clip | where {$_ -notmatch "manifest"} | Select-String "[.]yaml") |ForEach-Object{($_ -split $Enum.Char.Slash)[$Enum.Index.Last]}
		$replace = $FileNames[$Enum.Index.Last] -replace $Enum.ManifestFileExtension.Root -replace "[.]","[.]"
		$FileNames | ForEach-Object {
			$Files += $_ -replace $PackageIdentifier,"Package"
		}
		$clip = $clip | where {$_ -notmatch "Lines changed"}
		$clip = $clip -join $Enum.Char.LineBreak 
		$clip = $clip -replace "Original file line number\s+Diff line number\s+Diff line change",$Enum.Char.DoubleAmpersand
		$clip = $clip -split $Enum.Char.DoubleAmpersand
		for ($i = 0; $i -lt $Files.Length; $i++) {
			$File = $Files[$i]
			$shift = 1
			$inputObj = $clip[$i + $shift] -split $Enum.Char.LineBreak
			# $inputObj = $clip[($i*$Enum.Num.Two) + $shift] -split $Enum.Char.LineBreak
			$LastLine = ($inputObj | Select-String "ManifestVersion" -SimpleMatch).LineNumber -1
			$inputObj = $inputObj[1..$LastLine] | Where-Object {$_ -notmatch $Enum.Strings.MarkedThisConversationAsResolved}| Where-Object {$_ -notmatch "Comment on line"} | Where-Object {$_ -notmatch "Resolved"} | Where-Object {$_ -notlike ' # # Changelog'}| Where-Object {$_ -notlike ' ## Changelog'}
			$FilePath = "$manifestFolder\$File"
			if (!($Silent)) {
				Write-Host "Writing $($inputObj.Length) lines to $FilePath"
			}
			if ($WhatIf) {
				"$filepath - $inputObj"
			} else {				


				Out-File -FilePath $FilePath -InputObject $inputObj
				#Bugfix to catch commented lines where the comment hash was the 2nd character - possibly due to this line above: $clip = $clip -replace $Enum.Char.Hash," #"
				$fileContents = (Get-Content $FilePath)
				for ($n = 0; $n -lt $fileContents.Length; $n++) {
					if (($fileContents[$n][$Enum.Index.First] -eq $Enum.Char.Space) -AND ($fileContents[$n][$Enum.Index.Second] -eq $Enum.Char.Hash)) {
						$fileContents[$n] = $Enum.Char.Hash + $fileContents[$n]						
					}#end if fileContents		
				}

				if ($fileContents[$Enum.Index.Last] -clike $PackageIdentifier) {
					$fileContents[$Enum.Index.Last] = ($fileContents[$Enum.Index.Last] -split $PackageIdentifier)[$Enum.Index.First]
				}
				$fileContents -replace "0New version: ","0" -replace "0New package: ","0" -replace "0Add version: ","0" -replace "0Add package: ","0" -replace "0Add ","0" -replace "0New ","0" -replace "0package: ","0" | Out-File $FilePath
			}#end if WhatIf
		}
		$filecount = (Get-ChildItem $manifestFolder).Count
		$filedir = "ok"
		$filecolor = $Enum.PSColors.Green
		if ($filecount -lt 3) { $filedir = "too low"; $filecolor = $Enum.PSColors.Red}
		if ($filecount -gt 3) { $filedir = "high"; $filecolor = $Enum.PSColors.Yellow}
		if ($filecount -gt $Enum.Num.Ten) { $filedir = "too high"; $filecolor = $Enum.PSColors.Red}
		if (!($Silent)) {
			Write-Host -f $filecolor "File count $filecount is $filedir"
		}
		# if ($filecount -lt 3) { break}
		if (!($WhatIf)) {
			$filename = "$MainFolder\vm\$vm\manifest\Package.yaml"
			$fileContents = Get-Content $filename
			if ($fileContents[$Enum.Index.Last] -ne "0") {
				$fileContents[$Enum.Index.Last] = ($fileContents[$Enum.Index.Last] -split ".0")[$Enum.Index.First]+".0"
				$fileContents | Out-File $filePath
				$fileContents = Get-Content $filename
				$fileContents -replace "1..0","1.10.0"
				$fileContents | Out-File $filePath
			}#end if fileContents		
		}#end if WhatIf
		try {#Clean up any misnamed files.
			Get-ChildItem "$MainFolder\vm\$VM\manifest" | where {$_.fullname -notmatch "Package"} | Remove-Item -Path $_.fullname
		}catch{}
	}#end if Operation
}

Function Get-InstallerFileAutomation { #Clip
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$InstallerFile = (Get-CommitFile -PR $PR2)
	)
	$PR = $PR2
	Write-Host "$($MyInvocation.MyCommand.name) $PR"
	Get-SingleFileAutomation -PR $PR -clip $InstallerFile
}

Function Get-SingleFileAutomation { #Clip
	Param(
		[int]$PR,
		$clip,
		[string]$PackageIdentifier = (Get-SchemaCheck -InputData $clip -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier ),
		$version = ((Get-YamlValue $Enum.ManifestKeys.PackageVersion -clip $clip) | Get-RemoveQuotes), 
		$listing = (Get-ManifestListing $PackageIdentifier),
		[int]$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM))
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	for ($File = 0; $File -lt $listing.Length; $File++) {
		Write-Host "$($MyInvocation.MyCommand.name) $PR - $File for VM $VM"
		$Clip = (Get-FileFromGitHub -PackageIdentifier $PackageIdentifier -Version $version -Suffix $listing[$File])
		Get-ManifestFile -clip $Clip -PR $PR
	}
}

Function Get-ManifestFile { #Clip
	Param(
		[int]$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM)),
		$clip,
		[string]$FileName = "Package",
		[string]$PackageIdentifier = ((Get-SchemaCheck -InputData $clip -YamlValue $Enum.ManifestKeys.PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier ) -replace $Enum.Char.DoubleQuote,$Enum.Char.Blank -replace $Enum.Char.SingleQuote,$Enum.Char.Blank -replace $Enum.Char.Comma,$Enum.Char.Blank),
		[int]$PR,
		[string]$Arch,
		[string]$OS,
		[string]$Scope
	);
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	#Write-Output "PackageIdentifier: $PackageIdentifier"
	$manifestFolder = "$MainFolder\vm\$vm\manifest"
	$clip = $clip | Where-Object {$_ -notmatch $Enum.Strings.MarkedThisConversationAsResolved}

	$YamlValue = (Get-YamlValue ManifestType -clip $clip)
	switch ($YamlValue) {
		$Enum.ManifestFileTypes.defaultLocale {
			$Locale = (Get-YamlValue PackageLocale -clip $clip)
			$FileName = "$FileName.locale.$Locale"
		}
		$Enum.ManifestFileTypes.Locale {
			$Locale = (Get-YamlValue PackageLocale -clip $clip)
			$FileName = "$FileName.locale.$Locale"
		}
		$Enum.ManifestFileTypes.installer {
			Get-RemoveFileIfExist "$manifestFolder" -remake
			$FileName = "$FileName.installer"
		}
		$Enum.ManifestFileTypes.version {
			if ($Arch) {
				Get-TrackerVMValidate -vm $VM -NoFiles -Arch $Arch -PR $PR -PackageIdentifier $PackageIdentifier
			} elseif ($OS) {
				Get-TrackerVMValidate -vm $VM -NoFiles -OS $OS -PR $PR -PackageIdentifier $PackageIdentifier
			} elseif ($Scope) {
				Get-TrackerVMValidate -vm $VM -NoFiles -Scope $Scope -PR $PR -PackageIdentifier $PackageIdentifier
			} else {
				Get-TrackerVMValidate -vm $VM -NoFiles -PR $PR -PackageIdentifier $PackageIdentifier
			}
		}
		Default {
			Write-Output "Error: Bad ManifestType"
				Return
		}
	}
	$FilePath = "$manifestFolder\$FileName.yaml"
	Write-Output "Writing $($clip.Length) lines to $FilePath"
	$clip -replace "0New version: ","0" -replace "0Add version: ","0" -replace "0Add ","0" -replace "0New ","0" | Out-File $FilePath -Encoding unicode
	return $VM
}

Function Get-ManifestListing {
	Param(
		[string]$PackageIdentifier,
		[string]$PI = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier),
		$VersionNumber, 
		[string]$Path = ($PI -replace "[.]",$Enum.Char.Slash),
		[string]$FirstLetter = ($PI[$Enum.Index.First].tostring().tolower()),
		[string]$Uri = "$GitHubApiBaseUrl/contents/manifests/$FirstLetter/$Path/$VersionNumber/",
		[Switch]$ListVersions
	)
	$PackageIdentifier = $PI
	If ($ListVersions) {
		$Uri = "$GitHubApiBaseUrl/contents/manifests/$FirstLetter/$Path/"
	} else {
		Write-Host "$($MyInvocation.MyCommand.name) $PR"
		$VersionNumber = Get-ManifestVersion -PackageIdentifier $PackageIdentifier
		$Uri = "$GitHubApiBaseUrl/contents/manifests/$FirstLetter/$Path/$VersionNumber/"
	}
	try{
		$out = (Invoke-GitHubRequest -Uri $Uri -JSON).name
	}catch{
		$out = $Enum.Words.Error
	}
	$PackageIdentifier = $PackageIdentifier -replace "\+","\+"
	return $out -replace "$($PackageIdentifier)[.]",$Enum.Char.Blank
}

Function Get-ManifestVersion {
	Param(
		[string]$PackageIdentifier,
		$VersionNumber, 
		[switch]$Display
	)
	$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
	$Invo = $($MyInvocation.MyCommand.name)
	if ($Display) {Write-Host "$Invo"}
	$GhRlRemain = ((Get-GitHubRateLimit) | where {$_.source -match $Enum.GitHubRateLimit.Unlogged}).remaining
	if ($GhRlRemain -le 0) {
		$WinGetOutput = Find-WinGetPackage $PackageIdentifier | where {$_.id -ceq $PackageIdentifier}
		if ($Display) {Write-Host "$Invo - WinGetOutput: $WinGetOutput"}
		$VersionNumber = $WinGetOutput.version
		if ($Display) {Write-Host "$Invo - VersionNumber: $VersionNumber"}
	} else {
		[array]$ListVersions = (Get-ManifestListing -PackageIdentifier $PackageIdentifier -ListVersions)
		if ($Display) {Write-Host "$Invo - ListVersions: $(ListVersions.count)"}
		if ($ListVersions[$Enum.Index.First] -gt $ListVersions[$Enum.Index.Last]) {#Attempt to fix inferior GitHub version sorting.
			$VersionNumber = $ListVersions[$Enum.Index.First]
			if ($Display) {Write-Host "$Invo - First VersionNumber: $VersionNumber"}
		} else {
			$VersionNumber = $ListVersions[$Enum.Index.Last]
			if ($Display) {Write-Host "$Invo - Last VersionNumber: $VersionNumber"}
		}#end if ListVersions
	}#end if DataSource
	return $VersionNumber
}

Function Get-OSFromVersion {
	$Enum.VMOS.Win11
}

#VM Image Management
<# VM Infrastructure:
- Image VM is named with the OS. This is kept turned off when not being updated.
- Copy of Image VM is made, and Pipeline VMs generated from it. To prevent locking issues with Image VM files. 
- Pipeline VMs are named with an incrementing number. Expectation is for the system to have between 3-9 of these, depending on available RAM. 

Process: 
- Build image manually - have been using Hyper-V Quick Create images. 
- Delete old image VM before running Get-ImageVMMove. This will both move the storage drives to the correct location, and also rename the image VM to the OS name. 
- Complete building image. Checkpoint with Get-ImageVMStop.
- Build new with Get-PipelineVmGenerate.
- There's ALWAYS a problem with the first build. 
- Restart image VM with Get-ImageVMStart.
- If it was an OS issue, fix it. (Sometimes it's a hardware or copying issue. If one of these, skip this step.)
- Checkpoint with Get-ImageVMStop again.
- Build new with Get-PipelineVmGenerate again.
- Keep going through the lsat 4 steps until you get a working build.
- Let Get-TrackerVMRunTracker take over at this point. It will build until your RAM is full.
#>

Function Get-PipelineVmGenerate {
	Param(
		[int]$vm = (Get-Content $vmCounter),
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		[int]$version = (Get-TrackerVMVersion -OS $OS),
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$newVmName = ("vm$VM"),
		$startTime = (Get-Date)
	)
	Test-Admin
	Write-Host "Creating VM $newVmName version $version OS $OS"
	[int]$vm + 1|Out-File $vmCounter
	"`"$vm`",`"Generating`",`"$version`",`"$OS`",`"`",`"1`",`"Creation`",`"0`""|Out-File $StatusFile -Append -Encoding unicode
	Get-RemoveFileIfExist $destinationPath -remake
	Get-RemoveFileIfExist $VMFolder -remake
	$vmImageFolder = (ls "$imagesFolder\$OS-image\Virtual Machines\" *.vmcx).fullname
	
	$ImportEst = (get-date).AddSeconds(400).ToString($Enum.Char.T)
	Write-Host "Takes about 400 seconds. (Until $($ImportEst).) Beginning import..."
	Import-VM -Path $vmImageFolder -Copy -GenerateNewId -VhdDestinationPath $destinationPath -VirtualMachinePath $destinationPath;
	$ImportSeconds = ((Get-Date)-$startTime).TotalSeconds
	if ($ImportSeconds -gt 30) { 
		Write-Host "Import complete, taking $ImportSeconds seconds. Renaming..."
		Rename-VM (Get-VM | Where-Object {($_.CheckpointFileLocation)+$Enum.Char.Backslash -eq $destinationPath}) -NewName $newVmName
		Write-Host $Enum.Strings.RenameCompleteStarting
		Start-VM $newVmName
		Write-Host $Enum.Strings.StartingVmAndCleaningUpCheckpoints
		Remove-VMCheckpoint -VMName $newVmName -Name "Backup"
		Write-Host $Enum.Strings.RevertingVm
		Get-TrackerVMRevert $VM
		Write-Host $Enum.Strings.LaunchingVMWindowHandingOffToOrchestration
		Get-TrackerVMLaunchWindow $VM
		Write-Host "Took $ImportSeconds seconds."
	} else {
		Write-Host "Error: $ImportSeconds seconds is too short. Disgnenerating vm $VM"
		Get-TrackerVMSetStatus -Status $Enum.VMStatus.Disgenerate -VM $VM	
	}
}

Function Get-PipelineVmDisgenerate {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = ("vm$VM")
	)
		
	if ($vm -gt 0) {
	Test-Admin
	Get-TrackerVMSetStatus $Enum.VMStatus.Disgenerate $VM
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	Stop-TrackerVM $VM
	Remove-VM -Name $vmName -Force

	$out = Get-Status
	$out = $out | Where-Object {$_.vm -notmatch $VM}
	Write-Status $out

	$delay = 15
	0..$delay | ForEach-Object {
		$pct = $_ / $delay * 100
		Write-Progress -Activity "Remove VM" -Status "$_ of $delay" -PercentComplete $pct
		Start-Sleep $GitHubRateLimitDelay
	}
	Get-RemoveFileIfExist $destinationPath
	Get-RemoveFileIfExist $VMFolder
	Write-Progress -Activity "Remove VM" -Completed
	}
}

Function Get-ImageVMStart {
	Param(
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11
	)
	Test-Admin
	$VM = 0
	Start-VM $OS;
	Get-TrackerVMRevert $VM $OS;
	Get-TrackerVMLaunchWindow $VM $OS
}

Function Get-ImageVMStop {
	Param(
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11
	)
	Test-Admin
	$VM = 0
	$OriginalLoc = $Enum.Char.Blank
	# switch ($OS) {
		# $Enum.VMOS.Win10 {
			# $OriginalLoc = $Win10Folder
		# }
		# $Enum.VMOS.Win11 {
		# }
	# }
	$OriginalLoc = $Win11Folder
	$ImageLoc = "$imagesFolder\$OS-image\"
	[int]$version = [int](Get-TrackerVMVersion -OS $OS) + 1
	Write-Host "Writing $OS version $version"
	Get-TrackerVMSetVersion -Version $Version -OS $OS
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match "$OS"}).id -ErrorAction Ignore
	Redo-Checkpoint $VM $OS;
	Stop-TrackerVM $VM $OS;
	Write-Host $Enum.Strings.LettingVmCool
	Start-Sleep 30;
	Robocopy.exe $OriginalLoc $ImageLoc -mir
}

Function Get-ImageVMMove {
	Param(
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		$CurrentVMName = $Enum.Char.Blank,
		$newLoc = "$imagesFolder\$OS-Created$(get-date -f MMddyy)-Original"
	)
	Test-Admin
	# switch ($OS) {
		# $Enum.VMOS.Win10 {
			# $CurrentVMName = "Windows 10 MSIX packaging environment"
		# }
		# $Enum.VMOS.Win11 {
		# }
	# }
	$CurrentVMName = $Enum.Strings.Win11DevEnv
	$VM = Get-VM | where {$_.Name -match $CurrentVMName}
	Move-VMStorage -VM $VM -DestinationStoragePath $newLoc
	Rename-VM -VM $VM -NewName $OS
}

#VM Pipeline Management
Function Get-TrackerVMLaunchWindow {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
		$VMName = ("vm$VM")
	)
	Test-Admin
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Get-TrackerVMRevert {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
		$VMName = ("vm$VM"),
		[Switch]$Silent
	)
	Test-Admin
	if ($Silent) {
		Get-TrackerVMSetStatus $Enum.VMStatus.Restoring $VM -Silent
	} else {
		Get-TrackerVMSetStatus $Enum.VMStatus.Restoring $VM
	}
	Restore-VMCheckpoint -Name $CheckpointName -VMName $VMName -Confirm:$False
	if ($Silent) {
		Get-TrackerVMSetStatus $Enum.VMStatus.Ready $VM -Silent
	} else {
		Get-TrackerVMSetStatus $Enum.VMStatus.Ready $VM
	}
}

Function Complete-TrackerVM {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
		$VMFolder = "$MainFolder\vm\$vm",
		$filesFileName = "$VMFolder\files.txt"
	)
	Test-Admin
	Get-TrackerVMSetStatus $Enum.VMStatus.Completing $VM
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match ("vm$VM")}).id -ErrorAction Ignore
	Stop-TrackerVM $VM
	Get-RemoveFileIfExist $filesFileName
	Get-TrackerVMRevert $VM -Silent
	Get-TrackerVMSetStatus $Enum.VMStatus.Ready $VM $Enum.Char.Space 1 $Enum.VMStatus.Ready
}

Function Stop-TrackerVM {
	Param(
		[Parameter(mandatory = $True)][int]$VM,
		$VMName = ("vm$VM")
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

#VM Status
Function Get-TrackerVMSetStatus {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.VMStatus)} )][string]$Status = $Enum.VMStatus.Complete,
		[Parameter(mandatory = $True)]$VM,
		[string]$PackageIdentifier,
		[Parameter(ValueFromPipeline)][int]$PR,
 [ValidateScript( { $_ -in (Get-Keys $Enum.VmModes)} )][string]$Mode,
		[Switch]$Silent
	)

	$out = Get-Status
	if ($VM -notmatch $Enum.Strings.Win) {
		if ($Status) {
			($out | Where-Object {$_.vm -eq $VM}).Status = $Status
		}
		if ($PackageIdentifier) {
			# $PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
			($out | Where-Object {$_.vm -eq $VM}).Package = $PackageIdentifier
		}
		if ($PR) {
			$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
			($out | Where-Object {$_.vm -eq $VM}).PR = $PR
		}
		if ($Mode) {
			($out | Where-Object {$_.vm -eq $VM}).Mode = $Mode
		}
		if ($Silent) {
			Write-Status $out -Silent
		} else {
			
			Write-Status $out
			Write-Host "Setting $VM $PackageIdentifier $PR state $Status"
		}; #end if Status
	}; #end if VM
}

Function Get-Status {
	Param(
		[int]$VM,
 [ValidateScript( { $_ -in (Get-Keys $Enum.VMStatus) } )][string]$Status,
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS,
		[string]$PackageIdentifier,
		[Parameter(ValueFromPipeline)][int]$PR,
 [ValidateScript( { $_ -in (Get-Keys $Enum.VmModes)} )][string]$Mode,
		$RAM,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv)
	)

	if ($VM) {$out = ($out | Where-Object {$_.vm -eq $VM})}
	if ($Status) {$out = ($out | Where-Object {$_.Status -eq $Status})}
	if ($OS) {$out = ($out | Where-Object {$_.OS -eq $OS})}
	if ($PackageIdentifier) {
		$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
		$out = ($out | Where-Object {$_.Package -eq $PackageIdentifier})
	}
	if ($PR) {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
		$out = ($out | Where-Object {$_.PR -eq $PR})
		}
	if ($Mode) {$out = ($out | Where-Object {$_.Mode -eq $Mode})}
	if ($RAM) {$out = ($out | Where-Object {$_.RAM -eq $RAM})}
	Return $out
}

Function Get-TrackerVMResetStatus {
	$VMs = (Get-Status -Status Ready -RAM 0).VM
	$VMs += (Get-Status -Status Ready -PackageIdentifier $Enum.Char.Blank).VM
	Foreach ($VM in $VMs) {
		Get-TrackerVMSetStatus Complete $VM
	}
	if (!(Get-ConnectedVM)){
		Get-Process *vmwp* | Stop-Process
	}
}

Function Get-TrackerVMRebuildStatus {
	$Status = Get-VM | 
	Where-Object {$_.name -notmatch "vm0"} |
	Where-Object {$_.name -notmatch $Enum.VMOS.Win10} |
	Where-Object {$_.name -notmatch $Enum.VMOS.Win11} |
	Select-Object @{n =$Enum.Strings.Vm; e = {$_.name -replace $Enum.Strings.Vm,$null}},
	@{n = $Enum.Columns.Status; e = {$Enum.VMStatus.Ready}},
	@{n = $Enum.Columns.version; e = {(Get-TrackerVMVersion -OS $Enum.VMOS.Win11)}},
	@{n = $Enum.Columns.OS; e = {$Enum.VMOS.Win11}},
	@{n = $Enum.Columns.Package; e = {$Enum.Char.Blank}},
	@{n = $Enum.Columns.PR; e = {"1"}},
	@{n = $Enum.Columns.Mode; e = {$Enum.VmModes.Unknown}},
	@{n = $Enum.Columns.RAM; e = {"0"}}
	Write-Status $Status
}

Function Get-TrackerVMProcess {
	Param(
		[int]$vm
	)
	return (Get-process *vmwp* -IncludeUserName) | where {($_.username -replace "NT VIRTUAL MACHINE\\",$Enum.Char.Blank) -match (Get-VM ("vm$VM")).vmid}
}

#VM Versioning
Function Get-TrackerVMVersion {
	Param(
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		[int]$VM = ((Get-Content $VMversion | ConvertFrom-Csv | Where-Object {$_.OS -eq $OS}).version)
	)
	Return $VM
}

Function Get-TrackerVMSetVersion {
	Param(
		[int]$Version,
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		$Versions = (Get-Content $VMversion | ConvertFrom-Csv)
	)
	($Versions | Where-Object {$_.OS -eq $OS}).Version = $Version
	$Versions | ConvertTo-Csv|Out-File $VMversion
}

Function Get-TrackerVMRotate {
	Param(
		$status = (Get-Status),
		$OS = $Enum.VMOS.Win11,
		$VMs = ($status | Where-Object {$_.version -lt (Get-TrackerVMVersion -OS $OS)} | Where-Object {$_.OS -eq $OS})
	)
	if ($VMs){
		if (!(($status | Where-Object {$_.status -ne $Enum.VMStatus.Ready}).Count)) {
			Get-TrackerVMSetStatus Regenerate ($VMs.VM | Get-Random)
		}
	}
}

#VM Orchestration
Function Get-TrackerVMCycle {
	Param(
		$VMs = (Get-Status)
	)
	Foreach ($VM in $VMs) {
		$vmNum = $Enum.Strings.Vm + $vm.vm
		Switch ($VM.status) {
			$Enum.VMStatus.AddVCRedist {
				Add-ToValidationFile $VM.vm
				Suspend-VM -Name $vmNum
			}
			$Enum.VMStatus.Approved {
				Suspend-VM -Name $vmNum
				$PRLabels = ((Invoke-GitHubPRRequest -PR $VM.PR -Type $Enum.prRequestTypes.Labels -Output $Enum.PRRequestOutput.Content -JSON).name) -join $Enum.Char.Space
				if ($PRLabels -match $Enum.PRLabels.VC) {
					Approve-PR -PR $VM.PR
				} else {
					Get-CompletePR -PR $VM.PR
				}
				Get-TrackerVMSetStatus $Enum.VMStatus.Complete $VM.vm
			}
			$Enum.VMStatus.CheckpointReady {
				Redo-Checkpoint $VM.vm
			}
			$Enum.VMStatus.Complete {
				Suspend-VM -Name $vmNum -ErrorAction SilentlyContinue
				if (($VMs | Where-Object {$_.vm -eq $VM.vm} ).version -lt (Get-TrackerVMVersion -OS $VM.os)) {
					Get-TrackerVMSetStatus $Enum.VMStatus.Regenerate $VM.vm
				} else {
					Complete-TrackerVM $VM.vm
				}
			}
			$Enum.VMStatus.Disgenerate {
				Suspend-VM -Name $vmNum
				Get-PipelineVmDisgenerate $VM.vm
			}
			$Enum.VMStatus.DoesntRun {
				Suspend-VM -Name $vmNum
				Get-SendStatus -Status $Enum.VMStatus.Complete
			}
			$Enum.VMStatus.Feedback {
				Suspend-VM -Name $vmNum
				Get-AddPRLabel -PR $VM.PR -LabelName $Enum.PRLabels.NAF
				Get-TrackerVMSetStatus $Enum.VMStatus.Complete $VM.vm
			}
			$Enum.VMStatus.Revert {
				Suspend-VM -Name $vmNum
				Get-TrackerVMRevert $VM.vm
			}
			$Enum.VMStatus.Regenerate {
				Suspend-VM -Name $vmNum
				Get-PipelineVmDisgenerate $VM.vm
				Get-PipelineVmGenerate -OS $VM.os
			}
			$Enum.VMStatus.SendStatusApproved {
				Suspend-VM -Name $vmNum
				Get-SendStatus -Status $Enum.VMStatus.Approved
			}
			$Enum.VMStatus.SendStatusComplete {
				Suspend-VM -Name $vmNum
				Get-SendStatus -Status $Enum.VMStatus.Complete
			}
			$Enum.VMStatus.SendStatusFeedback {
				Suspend-VM -Name $vmNum
				Get-SendStatus -Status $Enum.VMStatus.Feedback
			}
			$Enum.VMStatus.SendStatus {
				Suspend-VM -Name $vmNum
				Get-SendStatus -Status $Enum.VMStatus.Complete
			}
			default {
			}
		}; #end switch
	}
}

Function Get-TrackerVMMode {
	Param(
		$mode = (Get-Content $TrackerModeFile)
	)
	$mode
}

Function Get-TrackerVMSetMode {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.TrackerModes) } )][string]$Mode = $Enum.TrackerModes.Validating
	)
	$Mode | Out-File $TrackerModeFile -NoNewLine
}

Function Get-ConnectedVM {
	Test-Admin
	(Get-Process *vmconnect*) | Select-Object id, @{n = $Enum.Strings.Vm; e = {ForEach-Object{$_.mainwindowtitle[$Enum.Index.First..5] -join $Enum.Char.Blank}}}
}

Function Get-NextFreeVM {
	Param(
 [ValidateScript( { $_ -in $Enum.VMOS.Win11 } )][string]$OS = $Enum.VMOS.Win11,
		$Status = $Enum.VMStatus.Ready
	)
	Test-Admin
	try {
		$out_status = Get-Status 
		$out_status = $out_status | Where-Object {$_.OS -eq $OS}
		$out_status = ($out_status | Where-Object {$_.version -eq (Get-TrackerVMVersion -OS $OS)} | Where-Object {$_.status -eq $Status}).vm
		$out_status = $out_status |Get-Random -ErrorAction SilentlyContinue
		return $out_status;
	} catch {
		Write-Host "No available $OS VMs"
		return $Enum.Num.Zero
	}
}

Function Redo-Checkpoint {
	Param(
		[Parameter(mandatory = $True)][int]$VM,
		$VMName = ("vm$VM")
	)
	Test-Admin
	Get-TrackerVMSetStatus $Enum.VMStatus.Checkpointing $VM
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Get-TrackerVMSetStatus $Enum.VMStatus.Complete $VM
}

Function Get-StopStuckVMs {
	Param(
		$VMsToStop = (Get-Status -Status Completing).VM
	)
	if ($VMsToStop) {
		$VMsToStop | %{Get-TrackerVMProcess $_ | Stop-Process -Force}
	}
}

#File Management
Function Get-SendStatus {
	Param(
		[int]$PR,
 [ValidateScript( { $_ -in (Get-Keys $Enum.VMStatus)} )][string]$Status = $Enum.VMStatus.Complete,
		$SharedError = ((Get-Content $SharedErrorFile) -split $Enum.Char.LineBreak)
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)

	$SharedError = $SharedError -replace $Enum.Char.CarriageReturn,$Enum.Char.Blank 
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Caller1,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Caller2,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Exception1,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Exception2,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Exception4,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.Tid,$Enum.Char.Blank
	$SharedError = $SharedError -replace $Enum.SendStatusReplace.LongFilepath,$Enum.Char.Blank
	$SharedError = $SharedError -join $Enum.Char.LineBreakMDQuote
	#$SharedError = Get-AutomatedErrorAnalysis $SharedError
	if ((($SharedError -join $Enum.Char.Space) -match $Enum.StandardPRComments.SecurityCheck) -OR (($SharedError -join $Enum.Char.Space) -match $Enum.Strings.DetectedOneDefender)) {
		Get-AddPRLabel -PR $PR -LabelName $Enum.PRLabels.VDE
	}
	Reply-ToPR -PR $VM.PR -UserInput $SharedError -CannedMessage $Enum.CannedMessages.ManValEnd 
	Get-TrackerVMSetStatus -Status $Status -VM $VM.vm
}

Function Get-TrackerVMRotateLog {
	$logYesterDate = (Get-Date -f dd) - 1
	Move-Item "$writeFolder\logs\$logYesterDate" "$logsFolder\$logYesterDate"
}

Function Get-RemoveFileIfExist {
	Param(
		$FilePath,
		[switch]$remake,
		[switch]$Silent
	)
	if (Test-Path $FilePath) {Remove-Item $FilePath -Recurse}
	if ($Silent) {
		if ($remake) {$null = New-Item -ItemType Directory -Path $FilePath}
	} else {
		if ($remake) {New-Item -ItemType Directory -Path $FilePath}
	}

}

Function Get-LoadFileIfExists {
	Param(
		$FileName,
		$FileContents,
		[Switch]$Silent
	)
	if (Test-Path $FileName) {
		$FileContents = Get-Content $FileName | ConvertFrom-Csv
		if (!($Silent)) {
			Write-Host "Loaded $($FileContents.Count) entries from $FileName." -f green
			Return $FileContents
		}
	} else {
		if (!($Silent)) {
			Write-Host "File $FileName not found!" -f red
		}
	}
}

Function Get-ManifestEntryCheck {
	Param(
		$PackageIdentifier,
		$Version,
		$Entry = $Enum.ManifestKeys.DisplayVersion
	)
	$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
	$content = Get-FileFromGitHub $PackageIdentifier $Version
	$out = ($content | Where-Object {$_ -match $Entry})
	if ($out) {$True} else {$False}
}

#Commit
Function Get-CommitFile {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Commit = (Invoke-GitHubPRRequest -PR $PR2 -Type commits -Output $Enum.PRRequestOutput.Content -JSON),
 [ValidateScript( { $_ -in (Get-Values $Enum.ManifestFileTypes) } )][string]$MatchName = $Enum.ManifestFileTypes.Root,
		$PRData = (Get-PRData $PR2),
		$PackageIdentifier = (($Commit.files.filename -split $Enum.Char.Slash)[$Enum.Index.Last] -replace $Enum.ManifestFileExtension.Installer,$Enum.Char.Comma -replace $Enum.ManifestFileExtension.Locale,$Enum.Char.Comma -replace $Enum.ManifestFileExtension.Root,$Enum.Char.Comma -split $Enum.Char.Comma)[$Enum.Index.First],
		$PI = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier),
		$FileList = ($Commit.files.contents_url | where {$_ -match $MatchName} | where {$_ -match [System.Web.HttpUtility]::UrlEncode($PI)}),
		[int]$VM,
 [ValidateScript( { $_ -in (Get-Keys $Enum.CommitFileModes) } )][string]$Mode = $Enum.CommitFileModes.Default,
		[switch]$Deparent,
		[switch]$WhatIf
	)
	$PR = $PR2
	$PackageIdentifier = $PI
	if ($VM) {
		Write-Host "Starting PR $PR on VM $VM for CommitFile"
	}
	if ($WhatIf) {
		if ($Commit.Length -lt 1) {
			Write-Host "Commit $Commit"
		}
		if ($PRData.Length -lt 1) {
			Write-Host "PRData $PRData"
		}
		if ($FileList.Length -lt 1) {
			Write-Host "FileList $FileList"
		}
	}
	
	if (!($Deparent)) {
		#Count leading pluses or minuses to see if it's addition or removal PR. If removal, goto parent. 
		$commitfilespatch = $commit.files.patch -split $Enum.Char.LineBreak
		$removeCount = ($commitfilespatch | Where {$_ -notmatch $Enum.Char.Ampersand} | Where {$_[$Enum.Index.First] -match $Enum.Char.Dash} | Measure-Object).Count
		$AtCount = ($commitfilespatch | Where {$_[$Enum.Index.First] -match $Enum.Char.Ampersand} | Measure-Object).Count
		if (($AtCount + $RemoveCount) -eq $commitfilespatch.Count) {
			$Mode = $Enum.CommitFileModes.Parent
		}
	}	
	$manifestFolder = "$MainFolder\vm\$vm\manifest"
	if ($VM -gt $Enum.Num.Zero) {
		if (!($Silent)) {Write-Host $Enum.Strings.RemovingPreviousManifestAndAddingCurrent}
		Get-RemoveFileIfExist "$manifestFolder" -remake -Silent
	}
	
	switch ($Mode) {
		$Enum.CommitFileModes.Patch {
			Write-Host $Enum.Strings.ReturningPatch
			$commit.files.patch
		}
		$Enum.CommitFileModes.Parent {
			$parentCommit = Invoke-GitHubRequest -Uri $Commit.parents.url
			# Write-Host "parentCommit count: $($parentCommit.Count)"
			$parentcontent = $parentCommit.content | convertfrom-json
			# Write-Host "parentCommit.content count: $($parentcontent.Count)"
			$parentcontent = ($parentcontent.files.patch -split $Enum.Char.LineBreak) -replace "^\+",$Enum.Char.Blank
			# Write-Host "parentcontent.files.patch count: $($parentcontent.Count)"
			$parentcontent = $parentcontent -join $Enum.Char.LineBreak
			# Write-Host "parentcontent -join count: $($parentcontent.Count)"
			$parentcontent = $parentcontent -split $Enum.Char.DoubleAmpersand
			# Write-Host "parentcontent -split count: $($parentcontent.Count)"
			if ($parentcontent.Count -lt 3) {
				Write-Host "File count $($file.Count) is too low."
				Sleep $Enum.Num.Ten
			} else {
				
				foreach ($file in $parentcontent) {
					$file = $file -split $Enum.Char.LineBreak
					# Write-Host "file: $($file.Count)"
						$file
					# Write-Host "file: $file"
					if ($file.Count -gt 5) {
						if ($VM -gt $Enum.Num.Zero) {
							Write-Host "Starting PR $PR on VM $VM for file $file"
							Get-ManifestFile -vm $VM -PR $PR -clip $file
						} else {
							$file -join $Enum.Char.LineBreak
						}; #end if VM
					}
				}; # Forech file
			}
		}
		default {
			If ($FileList) {
				foreach ($File in $FileList) {
					if ($WhatIf) {Write-Host "$($MyInvocation.MyCommand.name) File: $File"}
					try {
						$EncodedFile = (invoke-GithubRequest -Uri $File -JSON)
					} catch {
						Write-Host $error[$Enum.Index.First].Message
					}
					$DecodedFile = Get-DecodeGitHubFile $EncodedFile.content
					if ($VM -gt $Enum.Num.Zero) {
						if ($FileList.Count -eq $Enum.Num.One) {
							Write-Host "Starting PR $PR on VM $VM for InstallerFileAutomation - FileList.Count $($FileList.Count)"
							Get-InstallerFileAutomation -PR $PR
							Return
						} else {
							Write-Host "Starting PR $PR on VM $VM for DecodedFile - FileList.Count $($FileList.Count)"
							Get-ManifestFile -vm $VM -PR $PR -clip $DecodedFile
						}
					} else {
						$DecodedFile -join $Enum.Char.LineBreak
					}; #end if VM
				}; #end foreach Filelist
			} else {
				Write-Host "FileList empty: $FileList"
				Get-CommitFile -PR $PR -Mode parent
			}
		}#end default
	}
}

Function Get-DecodeGitHubFile {
	Param(
		[string]$Base64String,
		$Bits = ([Convert]::FromBase64String($Base64String)),
		$String = ([System.Text.Encoding]::UTF8.GetString($Bits))
	)
	return $String -split $Enum.Char.LineBreak
}

Function Get-PatchedValidation {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[int]$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM)),
		$commit = (Invoke-GitHubPRRequest -PR $PR2 -Type commits -Output $Enum.PRRequestOutput.Content -JSON)
	)
	$VM = (Get-SchemaCheck -SchemaInfo $MVSchemaData.VM.Number -InputData (Get-NextFreeVM))
	$PR = $PR2
	while ($commit.files.Length -eq $Enum.Num.Zero) {
		if ($PatchedValidationIteration -gt 3) {
			Write-Host "Infinte Loop Detected after $PatchedValidationIteration iterations."
			Return
		}
		Write-Host "Fetching commit - Iteration $PatchedValidationIteration"
		$commit = (Invoke-GitHubRequest -Uri $commit.parents.url -JSON)
		$PatchedValidationIteration++
	}
	$PackageIdentifier = ($commit.files[$Enum.Index.First].filename -split $Enum.Char.Slash)[$Enum.Index.Last] -replace $Enum.ManifestFileExtension.Installer,$Enum.Char.Blank -replace $Enum.ManifestFileExtension.LocaleEnUS,$Enum.Char.Blank -replace $Enum.ManifestFileExtension.Root,$Enum.Char.Blank
	$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
	$SuffixList = (Get-ManifestListing $Packageidentifier)
	foreach ($Suffix in $SuffixList) {
		Write-Host "Fetching Suffix $Suffix"
		$file = Get-PatchedFile -PR $PR -Suffix $Suffix -commit $commit
		Get-ManifestFile -VM $VM -PR $PR -clip $file
		
	}
}

Function Get-PatchedFile {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[int]$vm = (Get-NextFreeVM),
		$Suffix = $Enum.ManifestFileTypes.installeryaml,
		$commit = (Invoke-GitHubPRRequest -PR $PR2 -Type commits -Output $Enum.PRRequestOutput.Content -JSON),
		[Switch]$WhatIf,
		[Switch]$InnerWhatIf
	)
	$PR = $PR2
	$n = $Enum.Num.Zero
	while ($commit.files.Length -eq $Enum.Num.Zero) {
		$commit = (Invoke-GitHubRequest -Uri $commit.parents.url -JSON)
		if ($WhatIf) {
			Write-Host "Get-PatchedFile commit parents Iteration $n"
			$n++
		}
	}
	$patch = ($commit.files | where {$_.filename -match $Suffix}).patch -join $Enum.Char.Blank -split $Enum.Char.LineBreak
	$PackageIdentifier = ($commit.files[$Enum.Index.First].filename -split $Enum.Char.Slash)[$Enum.Index.Last] -replace $Enum.ManifestFileExtension.Installer,$Enum.Char.Blank -replace $Enum.ManifestFileExtension.LocaleEnUS,$Enum.Char.Blank -replace $Enum.ManifestFileExtension.Root,$Enum.Char.Blank
	$PackageIdentifier = (Get-SchemaCheck -InputData $PackageIdentifier -SchemaInfo $schemaData.installer.definitions.PackageIdentifier)
	if ($WhatIf) {
		Write-Host "PackageIdentifier: $PackageIdentifier"
	}
	$PackageVersion = (Get-ManifestListing $PackageIdentifier -ListVersions)[$Enum.Index.Last] 
	$file = Get-FileFromGitHub -PackageIdentifier $PackageIdentifier -Version $PackageVersion -Suffix $Suffix 
	if ($InnerWhatIf) {
		Get-InnerPatchedFile -File $file -Patch $patch -WhatIf
	} else { 
		Get-InnerPatchedFile -File $file -Patch $patch 
	}
	
}

Function Get-InnerPatchedFile {
	Param(
		$File,
		$Patch,
		[switch]$WhatIf
	);
	$Loop = 1
	$AddedLines = $Enum.Num.Zero
	$HunkData = $Patch -join "%%" -split $Enum.Char.DoubleAmpersand
	$HunkDataCount = $HunkData.Length -1
	if ($WhatIf) {
		Write-Host "PatchDataCount $HunkDataCount"
		Write-Host "`n`n`nInput File"
		$File
	}
	for ($Hunk = $Enum.Index.Second; $Hunk -lt $HunkDataCount; $Hunk += $Enum.Num.Two) {
		$Loop = ($Hunk/$Enum.Num.Two) + .5
		if ($WhatIf) {
			Write-Host "`n`n`n = = = = = = = = = = = = = = = = Loop $Loop = = = = = = = = = = = = = = = = "
			Write-Host "AddedLines before $AddedLines"
		}
			$RemoveData = ($HunkData[$Hunk] -replace $Enum.Char.Ampersand,$Enum.Char.Blank -replace $Enum.Char.Dash,$Enum.Char.Blank -replace "\+",$Enum.Char.Blank -split $Enum.Char.Space -split $Enum.Char.Comma)
			[int]$RemoveStart = $RemoveData[$Enum.Index.Second] - 1 + $AddedLines
			[int]$RemoveEnd = $RemoveStart + $RemoveData[$Enum.Num.Two]
			[int]$ReplaceStart = $RemoveData[3] - 1 + $AddedLines
			[int]$ReplaceEnd = $ReplaceStart + $RemoveData[4]
			# $AddedLines += $RemoveData[4] - $RemoveData[$Enum.Num.Two]
			$HunkChange = $HunkData[$Hunk + 1] -split "%%"

		if ($WhatIf) {
			Write-Host "AddedLines after $AddedLines"
			Write-Host "RemoveData $RemoveData"
			Write-Host "RemoveData2 $RemoveStart $RemoveEnd $ReplaceStart $ReplaceEnd"

			Write-Host "HunkChange: $($HunkChange.Length)" 
			# $HunkChange
			[array]$HunkChange = $HunkChange -split $Enum.Char.LineBreak
			for ($Line = 0; $Line -lt $HunkChange.Length; $Line++) {
				Write-Host "$($Line): $($HunkChange[$Line])"
			}#end foreach Line
		}
			$ReplaceHunk = ($HunkChange | where {$_ -notmatch "^[-]"} | %{$_[$Enum.Index.Second..$_.Length] -join $Enum.Char.Blank})
			$ReplaceHunk = $ReplaceHunk[$Enum.Index.Second..($RemoveData[4])]
		if ($WhatIf) {
			Write-Host "RemoveHunk: $($RemoveEnd - $RemoveStart)" 
			[array]$FileArray = $File -split $Enum.Char.LineBreak
			for ($Line = $RemoveStart; $Line -lt $RemoveEnd; $Line++) {
				Write-Host "$($Line): $($FileArray[$Line])"
			}#end foreach Line

			Write-Host "ReplaceHunk: $($ReplaceHunk.Length)" 
			[array]$ReplaceHunk = $ReplaceHunk -split $Enum.Char.LineBreak 
			for ($Line = 0; $Line -lt $ReplaceHunk.Length; $Line++) {
				Write-Host "$($Line + $ReplaceStart): $($ReplaceHunk[$Line])"
			}#end foreach Line
		}
		if ($ReplaceStart -eq 0) {
			if ($WhatIf) {Write-Host "File Change: `$ReplaceHunk + `$File[$ReplaceEnd..$($File.Length)]"}
			$File = $ReplaceHunk[$Enum.Index.First..$ReplaceHunk.Length] + $File[$ReplaceEnd..$File.Length]
		} else {
			if ($WhatIf) {Write-Host "File Change: `$File[$($Enum.Index.First)..$ReplaceStart] + `$ReplaceHunk + `$File[$ReplaceEnd..$($File.Length)]"}
			$File = $File[$Enum.Index.First..($ReplaceStart -1)] + $ReplaceHunk + $File[($ReplaceEnd -1)..$File.Length]
		} #end if ReplaceStart
		if ($WhatIf) {
			# $AddedLines += $ReplaceHunk.Length - ($RemoveEnd - $RemoveStar)
			# $AddedLines += $RemoveData[4] - $RemoveData[2]
			# Write-Host "AddedLines: $AddedLines"

			Write-Host "`nFile after Loop $Loop "
			[array]$FileArray = $File -split $Enum.Char.LineBreak
			for ($Line = 0; $Line -lt $FileArray.Length; $Line++) {
				Write-Host "$($Line): $($FileArray[$Line])"
			}#end foreach Line
		}#end WhatIf
	}#end for inc
	if ($WhatIf) {
		Write-Host "`n`n`nOutput File"
	}
	return $File

}

#Inject dependencies
Function Add-ToValidationFile {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
 [ValidateScript( { $_ -in (Get-Keys $Enum.Dependencies) } )][string]$Common = $Enum.Dependencies.VCRedist,
		$Dependency = $Common,
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest",
		$FilePath = "$manifestFolder\Package.installer.yaml",
		$fileContents = (Get-Content $FilePath),
		$Selector = "Installers:",
		$offset = 1,
		$lineNo = (($fileContents | Select-String $Selector -List).LineNumber -$offset),
		$fileInsert = "Dependencies:`n PackageDependencies:`n - PackageIdentifier: $Dependency",
		$fileOutput = ($fileContents[$Enum.Index.First..($lineNo -1)] + $fileInsert + $fileContents[$lineNo..($fileContents.Length)])
	)
		Write-Host "Writing $($fileContents.Length) lines to $FilePath"
		Out-File -FilePath $FilePath -InputObject $fileOutput
		Get-TrackerVMSetStatus $Enum.VMStatus.Revert $VM;
}

Function Add-InstallerSwitch {
	Param(
		[Parameter(mandatory = $True)][int]$vm,
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
	$fileInsert = " InstallerSwitches:`n Silent: $Data"
	Add-ToValidationFile $VM -Selector $Selector -fileInsert $fileInsert #-Force
}

Function Get-UpdateHashInPR {
	Param(
		[int]$PR,
		[string]$ManifestHash,
		[string]$PackageHash,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$LineNumbers = ((Get-CommitFile -PR $PR2 | Select-String $ManifestHash).LineNumber),
		[string]$ReplaceString = (" InstallerSha256: $($PackageHash.toUpper())"),
		[string]$comment = "``````suggestion`n$ReplaceString`n```````n`n(Deterministic automation - build $build.)"
	)
	$PR = $PR2
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Enum.PRLabels.NAF
	}
}

Function Get-UpdateArchInPR {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		[string]$SearchTerm = " Architecture: $($Enum.Arch.86)",
		$LineNumbers = ((Get-CommitFile -PR $PR2 | Select-String $SearchTerm).LineNumber),
		[string]$ReplaceTerm = (($SearchTerm -split ": ")[$Enum.Index.Second]),
 [ValidateScript( { $_ -in (Get-Keys $Enum.Arch) } )]
		[string]$ReplaceArch = (($Enum.Arch.86,$Enum.Arch.64) | where {$_ -notmatch $ReplaceTerm}),
		[string]$ReplaceString = ($SearchTerm -replace $ReplaceTerm,$ReplaceArch),
		[string]$comment = "``````suggestion`n$ReplaceString`n```````n`n(Deterministic automation - build $build.)"
	)
	$PR = $PR2
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Enum.PRLabels.NAF
	}
}

Function Add-DependencyToPR {
	Param(
		[int]$PR,
		$PR2 = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR),
		$Dependency = $Enum.Dependencies.VCRedist,
		$SearchString = "Installers:",
		$LineNumbers = ((Get-CommitFile -PR $PR2 | Select-String $SearchString).LineNumber),
		$ReplaceString = "Dependencies:`n PackageDependencies:`n - PackageIdentifier: $Dependency`nInstallers:",
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Deterministic automation - build $build.)"
	)
	$PR = $PR2
	$out = $Enum.Char.Blank
	foreach ($Line in $LineNumbers) {
		$out += Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Enum.PRLabels.NAF
	}
}

#PR Queue
Function Add-PRToQueue {
 Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		$PRExclude = ((Get-Content $PRExcludeFile) -split $Enum.Char.LineBreak)
 )
	process {
		$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)	
		if ($PRExclude -notcontains $PR) {
			$PR | Out-File $PRQueueFile -Append
		}
	}
}

Function Get-PopPRQueue {
	[array]$PRQueue = Get-Content $PRQueueFile
	$PRQueue = $PRQueue -split $Enum.Char.LineBreak
	$PRQueue = Get-Diff $PRQueue (Get-Status).PR 
	$out = Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PRQueue[$Enum.Index.First]
	$PRQueue = $PRQueue[$Enum.Index.Second..$PRQueue.Length] | Select-Object -unique
	$PRQueue | Out-File $PRQueueFile 
	return $out
}

Function Get-PRQueueCount {
	$count = ((Get-Content $PRQueueFile) -split $Enum.Char.LineBreak).Count
	return $count
}

Function Get-CleanPRExcludeFile {
	[int[]]$out = $null
	Get-Content $PRExcludeFile | %{
			[int]$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $_)
			$PRData = Get-PRData $PR
			if ($PRData.state -eq $Enum.PRStates.Open){
				[int]$out += $PR
			}
		}
	Out-File -InputObject $out -FilePath $PRExcludeFile
}

Function Get-CleanPRFolder {
	[array]$Images = ((Get-ChildItem $imagesFolder -Directory).name | where {$_ -notmatch $Enum.Strings.Win})
	$VMs = (Get-Status).vm
	$VMs += 0
	$VMsToRemove = Get-Diff $Images $VMs 
	$VMsToRemove | %{Get-PipelineVmDisgenerate $_}
}

#Reporting
Function Add-PRToRecord {
	Param(
		[int]$PR,
 [ValidateScript( { $_ -in (Get-Keys $Enum.PRActions)} )][string[]]$Action,
		$Title
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$Title = ($Title -split $Enum.Char.Hash)[$Enum.Index.First]
	"$PR,$Action,$Title" | Out-File $LogFile -Append 
}

Function Get-PRPopulateRecord {
	Param(
		$Logs = (Get-Content $LogFile | ConvertFrom-Csv -Header ($Enum.PRRecordHeaders.PR,$Enum.PRRecordHeaders.Action,$Enum.PRRecordHeaders.Title))
	)
	Foreach ($Log in $Logs) {
		#Populate the Title column where blank, so all lines with the same PR number also have the same title, preventing the API calls for the lookup.
		$ThisPR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $_.PR)
		$LogPR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $Log.PR)
		$Log.title = ($Logs | Where-Object {$_.title} | Where-Object {$ThisPR -match $LogPR}).title | Sort-Object -Unique
	}
	$Logs | ConvertTo-Csv|Out-File $LogFile
}

Function Get-PRFromRecord {
	Param( 
 [ValidateScript( { $_ -in (Get-Keys $Enum.PRActions)} )][string]$Action
	)
	Get-PRPopulateRecord
	(Get-Content $LogFile) | ConvertFrom-Csv -Header ($Enum.PRRecordHeaders.PR,$Enum.PRRecordHeaders.Action,$Enum.PRRecordHeaders.Title) | Where-Object {$_.Action -match $Action}
}

Function Get-PRReportFromRecord {
	Param(
 [ValidateScript( { $_ -in (Get-Keys $Enum.PRActions)} )][string[]]$Action,
		$out = $Enum.Char.Blank,
		$line = 0,
		$Record = ((Get-PRFromRecord $Action) | Sort-Object PR -Unique),
		[switch]$NoClip
	)
	
	$LogContents = (Get-Content $LogFile | ConvertFrom-Csv | Where-Object {$_.Action -notmatch $Action} | ConvertTo-Csv)
	Out-File -FilePath $LogFile -InputObject $LogContents
	#Get everything that doesn't match the action and put it back in the CSV.

	Foreach ($PR in $Record) {
		$Title = $PR.Title
		$PR = Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR.PR
		if (!($Title)) {
			$Title = (Invoke-GitHubPRRequest -PR $PR -Type $Enum.Char.Blank -Output $Enum.PRRequestOutput.Content -JSON).title
		}
		Get-TrackerProgress -Activity ("$($MyInvocation.MyCommand.name) $Action") -ItemName $PR -ItemNumber $line -TotalItems $Record.Length; $line++
		$out += "$Title #$PR`n";
	}
	if ($NoClip) {
		return $out
	} else {
		$out | clip
	}
	Write-Progress -Completed
}

Function Get-PRFullReport {
	Param(
		$Month = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month),
		$Today = (get-date -f MMddyy),
		$ReportName = "$logsFolder\$Month\$Today-Report.txt",
		$HeaderList = ($Enum.PRActions.Feedback,$Enum.PRActions.Blocking,$Enum.PRActions.Waiver,$Enum.PRActions.Retry,$Enum.PRActions.Manual,$Enum.PRActions.Closed,$Enum.PRActions.Project,$Enum.PRActions.Squash,$Enum.PRActions.Approved)
		# $HeaderList = (Get-Keys $Enum.PRActions)
	)
	Write-Host "Generating report for $Today"
	md "$logsFolder\$Month\Stats\" -ErrorAction SilentlyContinue
	Copy-Item -Path $LogFile -Destination "$logsFolder\$Month\Stats\$Today-Report.csv"
	$null | Out-File $ReportName
	$HeaderList | %{
		$_ | Out-File $ReportName -Append;
		Get-PRReportFromRecord $_ -NoClip | Out-File $ReportName -Append
	}
	Write-Host "Report for $Today complete"
}

Function Get-RepoCountReport {
	Param(
		$Date = (Get-Date -Format "s"),
		$Count = (((Find-WinGetPackage $Enum.Char.Blank) | Measure-Object).Count)
	)
	$out = "`"$Date`", `"$Count`""
	Out-file -InputObject $out -FilePath $RepoCountFile -Append
}

Function Get-RepoState {
"https://github.com/microsoft/winget-pkgs/pulls?page=1&q = repo%3Amicrosoft%2Fwinget-pkgs + is%3Apr + is%3Aopen + draft%3Afalse + sort%3Aupdated-asc + label%3ANew-Package" # NewPackages
"https://github.com/microsoft/winget-pkgs/issues?q = state%3Aopen%20label%3AInternal-Error-Dynamic-Scan%20sort%3Aupdated-asc&page=1" #IEDS
"https://github.com/microsoft/winget-pkgs/pulls?q = repo%3Amicrosoft%2Fwinget-pkgs + is%3Apr + is%3Aopen + draft%3Afalse + -label%3AProject-File + -label%3Ablocked-installertype + -label%3AAzure-Pipeline-Passed + -label%3AValidation-Completed + -label%3AModerator-Approved + -label%3ABlocking-Issue + -label%3AInternal-Error-Manifest + -label%3AValidation-Defender-Error + -label%3AChanges-Requested + -label%3ANeeds-CLA + -label%3ANo-Recent-Activity + -label%3ANeeds-Attention + -label%3ANeeds-Author-Feedback + -label%3ANeeds-Review + -label%3AValidation-Merge-Conflict + -label%3AUnexpected-File + -label%3ALast-Version-Remaining + sort%3Aupdated-asc+" #NoLabels
"https://github.com/microsoft/winget-pkgs/pulls?q = is%3Apr + is%3Aopen + sort%3Aupdated-asc + label%3AValidation-Installation-Error" #VIE

$StartTotal = 710
$NewPackages = 172
$IEDS = 71
$NoL = 115
$VIE = 178
$Remainder = $StartTotal - $NewPackages - $IEDS - $NoL - $vie
 
"Label | Count | %
New | $NewPackages | $([math]::round( $NewPackages/ $StartTotal,2)*100)%
IEDS | $IEDS | $([math]::round( $IEDS/ $StartTotal,2)*100)%
No Labels | $NoL | $([math]::round( $NoL/ $StartTotal,2)*100)%
VIE | $VIE | $([math]::round( $VIE/ $StartTotal,2)*100)%
Remainder | $Remainder | $([math]::round( $Remainder/ $StartTotal,2)*100)%
Total | $StartTotal | $([math]::round( $StartTotal/ $StartTotal,2)*100)%"

}

Function Get-ApprovalStats {
	Param(
		[Parameter(ValueFromPipeline)][int]$Date = ((Get-Date).day)
		# [Switch]$Debug
	)
	Process {
		# $ApprovalStats = Get-Content $ApprovalStatsFile | ConvertFrom-Csv
		$ApprovalStats = Get-Content $ApprovalStatsFile | ConvertFrom-Csv | where {(get-date $_.DateTime).day -match $date}
		$AverageArray = @()
		for ($n = 0; $n -le $ApprovalStats.Length; $n++) {
			$add = $Enum.Char.Blank | Select-Object @{n = $Enum.Char.X; e = {$ApprovalStats[$n].PRsApprovedDuringLastRun}},@{n = $Enum.Char.Y; e = {$ApprovalStats[$n].AvgSecPerPR}}
			$AverageArray += $add
		}; #end for n
		$LinearRegression = Get-LinearRegression $AverageArray
		if ($Debug) { Write-Host "LR.m: $($LinearRegression.m); LR.b: $($LinearRegression.b)"}
		$SecondsPerMaxRun = $LinearRegression.m * 30 + $LinearRegression.b
		if ($Debug) { Write-Host "SecondsPerMaxRun: $SecondsPerMaxRun"}
		$secondsperday = 24*60*60
		$MaxPRsPerDay = $secondsperday/$SecondsPerMaxRun
		if ($Debug) { Write-Host "MaxPRsPerDay: $MaxPRsPerDay"}
		$count = (Get-YesterdayFormattedReport $Date | where {$_.action -eq "approved"}).Count;
		$pct = $count / $MaxPRsPerDay * 100; 
		
		$AvgPRsPerRun = ($ApprovalStats.PRsApprovedDuringLastRun | Measure-Object -Average).average
		$AvgSecPerRun = ($ApprovalStats.LastRunTookSeconds | Measure-Object -Average).average
		$AvgSecPerPR = $AvgSecPerRun / $AvgPRsPerRun
		
		# "DateTime","PRsApprovedDuringLastRun","LastRunTookSeconds","AvgSecPerPR","SleepUntil"
		$out = $Enum.Char.Blank | Select-Object Date, MaxPRs, YesterdayPRs, Percent, AvgPRsPerRun, AvgSecPerRun, AvgSecPerPR
		$out.Date = $Date
		$out.MaxPRs = [math]::round($MaxPRsPerDay,$Enum.Num.Two)
		$out.YesterdayPRs = $count
		$out.Percent = [math]::round($Pct,$Enum.Num.Two)
		$out.AvgPRsPerRun = [math]::round($AvgPRsPerRun,$Enum.Num.Two)
		$out.AvgSecPerRun = [math]::round($AvgSecPerRun,$Enum.Num.Two)
		$out.AvgSecPerPR = [math]::round($AvgSecPerPR,$Enum.Num.Two)
		$out
	}
}

Function Get-RunDurationStats {
	Param(
		$Files = (Get-ChildItem $logsFolder -recurse -file -Filter "*.log"),
		[switch]$Debug
	)
$Return = @()
Write-Host "Crunching $($Files.Count) log files..." 
$ItemNumber = 0
Foreach ($File in $Files) {
	$out = $Enum.Char.Blank | Select-Object @{n = "DateTime"; e = {$SplitLog = ($File.FullName -split "\\"); 
	$year = $SplitLog[3]; $month = $SplitLog[4]; $Day = $SplitLog[5]; 
	$time = ((Get-Content $File)[$Enum.Index.Last] -split ": ")[$Enum.Index.First];Get-Date "$month/$day/$year $time"}}, @{n = "seconds"; e = {(((Get-Content $File)[$Enum.Index.Last] -split " in ")[$Enum.Index.Second] -split " seconds. ")[$Enum.Index.First]}}
	$Return += $out	
	if ($Debug) {
		Write-Host "Crunching file $($file.fullname)"
	} else {
		Get-TrackerProgress -Activity "Crunching log files..." -ItemName $file.fullname -ItemNumber $ItemNumber -TotalItems $Files.Count 
		$ItemNumber++
	}
}

Return $Return
}

Function Get-SuccessRates {
	Param(
		$LastMonth = (Get-Date (Get-Date).AddMonths(-1) -Format "MMMM")
	)
	$out = @()
	$MonthList = (Get-ChildItem "$logsFolder\$LastMonth\" -Directory).fullname
	Foreach ($DayList in $MonthList) {
		$DayStats = (Get-ChildItem $DayList).fullname | %{
			$file = Get-Content $_;
			(($file[($file | Select-String $Enum.Strings.ManualValidation).LineNumber[$Enum.Index.Last] - 1] -split ": ")[$Enum.Index.Second] -replace "= " -split $Enum.Char.Space)[$Enum.Index.Second]
		} 
		$Group = $DayStats | Group-Object | Select-Object Name, Count
		
		$Day = ($DayList -split "\\")[$Enum.Index.Last]
		$New = ($Group | where {$_.name -match $Enum.SuccessType.New}).count
		$Success = ($Group | where {$_.name -match $Enum.SuccessType.Success}).count
		$Fail = ($Group | where {$_.name -match $Enum.SuccessType.Fail}).count
		[int]$TotalCount = ($Group |%{$_.count} | Measure-Object -sum).sum
		$SuccessRate = ($New + $Success) / $TotalCount
		
		
		$mid = $Enum.Char.Blank | Select-Object @{n="Day";e={$Day}}, @{n="New";e={$New}}, @{n="Success";e={$Success}}, @{n="Fail";e={$Fail}}, @{n="TotalCount";e={$TotalCount}}, @{n="SuccessRate";e={$SuccessRate}}
		$out += $mid
		Write-Host "SuccessRates $LastMonth \ $Day found: $($file.count)"
	}
	$Day = "Totals"
	[int]$New = ($out.("New") | Measure-Object -sum).sum
	[int]$Success = ($out.("Success") | Measure-Object -sum).sum
	[int]$Fail = ($out.("Fail") | Measure-Object -sum).sum
	[int]$TotalCount = ($out.TotalCount | Measure-Object -sum).sum
	$SuccessRate = ($New + $Success) / $TotalCount

	$mid = $Enum.Char.Blank | Select-Object @{n="Day";e={$Day}}, @{n="New";e={$New}}, @{n="Success";e={$Success}}, @{n="Fail";e={$Fail}}, @{n="TotalCount";e={$TotalCount}}, @{n="SuccessRate";e={$SuccessRate}}
	$out += $mid
	
	Return $out
}

Function Get-VMMinutesPerPackage {
	Param(
		[string]$Day = (Get-Date -Format "dd"),
		[string]$Month = (Get-Date -Format "MMMM")
	)
	$Path = "C:\ManVal\write\logs\$Month\$Day"
	if (test-path $Path) {
		$ChildItem = Get-ChildItem $Path
	} else {
		mkdir $Path
		$ChildItem = Get-ChildItem $Path
	}
	
	$count = $ChildItem.LastWriteTime.count
	$LastWriteTime = $ChildItem.LastWriteTime | sort -Descending
	$minutes = ($LastWriteTime[0] - $LastWriteTime[-1]).totalminutes
	$MinutesEach = $minutes/$count
	# Write-Host "Each PR takes : $MinutesEach"
	Return $MinutesEach
}

#Write
Function Write-ApprovalStats {
	Param(
		[string]$PRsApprovedDuringLastRun,
		[string]$LastRunTookSeconds,
		[string]$SleepUntil,
		$DateTime = (get-date -f s),
		[Switch]$Silent,
		[Switch]$WhatIf
	)
	# $out = "$DateTime,$PR, $Switch, $LineNos, $Trigger" | ConvertTo-Csv -NoHeader
	
	$out = $Enum.Char.Blank | Select-Object DateTime,PRsApprovedDuringLastRun,LastRunTookSeconds,AvgSecPerPR,SleepUntil
	$out.DateTime = get-date $DateTime -f s 
	$out.PRsApprovedDuringLastRun = $PRsApprovedDuringLastRun
	$out.LastRunTookSeconds = $LastRunTookSeconds
	$out.AvgSecPerPR = $out.LastRunTookSeconds / $out.PRsApprovedDuringLastRun
	$out.SleepUntil = $SleepUntil
	$out = $out | ConvertTo-Csv -NoHeader
	if ($WhatIf) {
		Write-Host "WhatIf: Out-File $ApprovalStatsFile -Encoding unicode -Append"
		Write-Host '"DateTime","PRsApprovedDuringLastRun","LastRunTookSeconds","AvgSecPerPR","SleepUntil"'
		Write-Host $out
	} else {
		if (!($Silent)) {
			Write-Host "Writing $($out.Length) characters to $ApprovalStatsFile."
		}
		if ($out.Length -gt 0) {
			if ($out.PRsApprovedDuringLastRun -gt 0) {
				$out | Out-File $ApprovalStatsFile -Append
			}
		}
	}
}

Function Write-Status {
	Param(
		$out,
		[Switch]$Silent,
		[Switch]$NoClobber,
		$OutFile = $StatusFile
	)
	if (!($Silent)) {
		Write-Host "Writing $($out.Length) lines to $OutFile."
	}
	if ($out.Length -gt $Enum.Num.Zero) {
		$out | ConvertTo-Csv | Out-File $OutFile -Encoding unicode
	}
}

Function Write-CovertReviewFile {
	Param(
		[Parameter(ValueFromPipeline)][int]$PR,
		[ValidateSet("Silent","SilentWithProgress","Interactive","InstallLocation","Log","Upgrade","Custom","Repair")]
		[string]$Switch,
		[string]$Trigger,
		[string]$LineNos,
		$DateTime = (get-date -f s),
		[Switch]$Silent
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)

	# $out = "$DateTime,$PR, $Switch, $LineNos, $Trigger" | ConvertTo-Csv -NoHeader
	$out = $Enum.Char.Blank | Select-Object DateTime,PR,Switch,LineNos,Trigger 
	$out.DateTime = $DateTime
	$out.PR = $PR
	$out.Switch = $Switch
	$out.LineNos = $LineNos
	$out.Trigger = $Trigger
	$out = $out | ConvertTo-Csv -NoHeader
	if (!($Silent)) {
		Write-Host "Writing $($out.Length) characters to $CovertReviewFile."
	}
	if ($out.Length -gt 0) {
		$out | Out-File $CovertReviewFile -Append
	}
}

Function Write-Log {
	Param(
		[string]$logData,
		[string]$ForegroundColor = "Gray",
		[string]$Month = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month),
		[string]$Today = (get-date -f MMddyy),
		[string]$FileName = "$logsFolder\$Month\$Today-Approval.log",
		[switch]$NoNewLine
	)
	md "$logsFolder\$Month\" -ErrorAction SilentlyContinue
	if ($NoNewLine) {
		Write-Host $logData -ForegroundColor $ForegroundColor -NoNewLine
		# Add-Content -LiteralPath $FileName -Value $logData
		$logData | Out-File $FileName -Append -NoNewline # -Encoding unicode
	} else {
		Write-Host $logData -ForegroundColor $ForegroundColor
		$logData | Out-File $FileName -Append # -Encoding unicode
	}
};

#Backup
Function Get-BackupDataFIles {
	
	Param (
		$path = "$RepoFolder\Backups\$date.zip"
	)
	$date = (get-Date -f s) -replace("\:","_")
	# $path = "$RepoFolder\Backups\$date\"
	# md $path
	md "$RepoFolder\Backups\"
	Compress-Archive -Path $RepoFolder -DestinationPath $path
}

#ExitCodes
Function Get-UpdateExitCodeFile {
	Param(
		$FileName = $ExitCodeFile,
		$ExitCodes = (Get-Content $FileName | ConvertFrom-Csv)
	)
	try {
		$ExitCodes | %{$_.dec = [System.Convert]::ToInt32($_.Hex,16)}
	} catch {}
	try {
		$ExitCodes | %{if ($_.dec -ge 0) {$_.invDec = $_.dec - 4GB}else {$_.invDec = $_.dec + 4GB}}
	} catch {}
	$ExitCodes | select "Hex","Dec","InvDec","Symbol","Description" -unique | sort hex | ConvertTo-Csv | clip
}

Function Get-UpdateExitCodeFile2 {
	Param(
		$FileName = $ExitCodeFile,
		$ExitCodes = (Get-Content $FileName | ConvertFrom-Csv)
	)
	for ($i = 0; $i -lt $ExitCodes.count; $i++){
		if ($ExitCodes[$i].hex -match $ExitCodes[$i+1].hex){
			if ($ExitCodes[$i].Symbol -eq "") {
				$ExitCodes[$i].Symbol += $ExitCodes[$i+1].Symbol;
			}
			if ($ExitCodes[$i].Symbol -eq "") {
				$ExitCodes[$i] = $null;
			}
			if ($ExitCodes[$i].Description -eq "") {
				$ExitCodes[$i].Description += $ExitCodes[$i+1].Description;
			}#end if ExitCodes.Description
			if ($ExitCodes[$i].Description -eq "") {
				$ExitCodes[$i] = $null;
			}
		}#end if ExitCodes.hex
	}
	$ExitCodes | select "Hex","Dec","InvDec","Symbol","Description" -unique | sort hex | ConvertTo-Csv | clip
} 

#Security
Function Get-ManifestCovertReview {
	Param(
		[string]$StringToReview,
		[switch]$WhatIf
	)
	[bool]$ReturnValue = $True
	foreach ($Switch in (Get-Keys $Enum.CovertReviewtSwitches)) {
		foreach ($Key in (Get-Keys $Enum.CovertReviewKeys)) {
			$Detected = Get-SchemaCheck -YamlKey $Switch -SchemaInfo $MVSchemaData.CovertReview.($Key) -InputData $StringToReview
			if ($Detected) {
				$ReturnValue = $False
				if ($WhatIf) {Write-Host "$Key Detected"}
				[string]$Trigger = "$Key - $($Detected -join ',')"
				if ($WhatIf) {
					"Write-CovertReviewFile -PR $PR -Switch $Switch -Trigger $Trigger -LineNos $LineNos"
				} else {
					Write-CovertReviewFile -PR $PR -Switch $Switch -Trigger $Trigger
				}
			}
		}#end foreach Key
	}#end foreach Switch
	Return $ReturnValue
}

Function Get-SchemaCheck {
	Param(
		[string]$InputData,
		[string]$YamlValue,
		$SchemaInfo,
		[switch]$Debug #Only use debug for troubleshooting with verified internally-generated data, never with untested external data. 
	)
	#Diagnostic check, to see how many checks are being run. If it starts to slow down or get laggy. 
	# [int]$num = ([int](gc $SchemaCheckFile) +1);Out-File -FilePath $SchemaCheckFile -InputObject $num
	$Tombstone = $Enum.Strings.FastFailTombstone

	try {
		[System.Collections.ArrayList]$SchemaKeys = Get-Keys $SchemaInfo
		if (!($SchemaKeys)){
			if ($debug) {write-host "Schema empty FastFail mandatory but missing!!!"};
			Return $Tombstone
		}
		if ($debug) {write-host "Schema contains: $SchemaKeys"};
		if ($debug) {write-host "Schema description: $($SchemaInfo.description)"};
		$SchemaKeys.Remove($Enum.SchemaKeysEtc.Description)
		
		[bool]$Optional = $False
		if ($SchemaInfo.type -contains $Enum.SchemaKeysEtc.Null) {
			$Optional = $True
		} else {
			$Optional = $False
		}
		if ($debug) {write-host "InputData: $InputData"};
		$DataToVerify = $null
		$Output = $Null

		if ($YamlValue) {#Yaml, Json, etc
			if ($debug) {write-host "MatchWith: $YamlValue"};
			if ($InputData -match $YamlValue) {#Yaml, Json, etc
				[string]$mid = Get-YamlValue -Key $YamlValue -clip $InputData
				if ($debug) {write-host "mid: $mid"};
				#Data can only be a string here. This is to allow the other variables to remain loosely-typed, for the other sections.
				$DataToVerify = $mid
			}
		} else {
			$DataToVerify = $InputData
		}
		if ($debug) {write-host "DataToVerify: $DataToVerify"};
		
		[string]$Item = $Enum.SchemaKeysEtc.Type
		[string]$integer = $Enum.SchemaKeysEtc.Integer
		if ($SchemaInfo.($Item)) {
			if ($debug) {write-host "Schema $Item Start"};
			$SchemaKeys.Remove($item)
			$SchemaStrand = ($SchemaInfo.($Item) | where {$_ -ne $Enum.SchemaKeysEtc.Null})
			if ($SchemaStrand -eq $integer) {#If type is int
				[int]$mid = $DataToVerify
				$DataStrand = $mid.gettype().name -replace $Enum.SchemaKeysEtc.Int32,$integer
				if ($DataStrand -eq $SchemaStrand) {
					if ($debug) {write-host "Schema $Item $Integer Pass"};
				} else {
					if ($Optional) {
						if ($debug) {write-host "Schema $Item $Integer optional"};
						Return $Null
					} else {
						if ($debug) {write-host "Schema $Item $Integer FastFail mandatory but missing!!!"};
						Return $Tombstone
					}# end if Optional
				}# end if DataStrand
			} else {#All other types
				$DataStrand = $DataToVerify.gettype().name
				if ($DataStrand -eq $SchemaStrand) {
					if ($debug) {write-host "Schema $Item $SchemaStrand Pass"};
				} else {
					if ($Optional) {
						if ($debug) {write-host "Schema $Item $SchemaStrand optional"};
						Return $Null
					} else {
						if ($debug) {write-host "Schema $Item $SchemaStrand FastFail mandatory but missing!!!"};
						Return $Tombstone
					}# end if Optional
				}# end if DataStrand
			}; #end if type
		}#end if SchemaInfo
		$Item = $Enum.SchemaKeysEtc.Pattern
		if ($SchemaInfo.($Item)) {
			if ($debug) {write-host "Schema $Item Start"};
			$SchemaKeys.Remove($item)
			$DataStrand = $DataToVerify
			$SchemaStrand = $SchemaInfo.($Item) -replace "/","\/" #PowerShell requires escaping the forward slashes.
			if ($DataStrand -match $SchemaStrand) {
				if ($debug) {write-host "Schema $Item Pass"};
			} else {
				if ($Optional) {
					if ($debug) {write-host "Schema $Item optional"};
					Return $Null
				} else {
					if ($debug) {write-host "Schema $Item FastFail mandatory but missing!!!"};
					Return $Tombstone
				}# end if Optional
			}# end if DataStrand
		}#end if SchemaInfo
		$Item = $Enum.SchemaKeysEtc.Enum
		if ($SchemaInfo.($Item)) {
			if ($debug) {write-host "Schema $Item Start"};
			$SchemaKeys.Remove($item)
			$DataStrand = $DataToVerify
			# $DataToVerify = $null
			$SchemaStrand = $SchemaInfo.($Item)
			foreach ($Strand in $SchemaStrand) {
				if ($DataStrand -eq $Strand) {
					if ($debug) {write-host "Schema DataStrand $DataStrand Strand $Strand"};
					# $DataToVerify += $Strand
				}# end if DataStrand
			}# end foreach Strand
			if ($DataToVerify) {
				if ($debug) {write-host "Schema $Item Pass"};
			} else {
				if ($Optional) {
					if ($debug) {write-host "Schema $Item optional"};
					Return $Null
				} else {
					if ($debug) {write-host "Schema $Item FastFail mandatory but missing!!!"};
					Return $Tombstone
				}# end if Optional
			}# end if DataToVerify
		}#end if SchemaInfo
		$Item = $Enum.SchemaKeysEtc.minLength
		if ($SchemaInfo.($Item)) {
			if ($debug) {write-host "Schema $Item Start"};
			$SchemaKeys.Remove($item)
			$DataStrand = $DataToVerify.length
			$SchemaStrand = $SchemaInfo.($Item)
			if ($DataStrand -ge $SchemaStrand) {
				if ($debug) {write-host "Schema $Item Pass"};
			} else {
				if ($Optional) {
					if ($debug) {write-host "Schema $Item optional"};
					Return $Null
				} else {
					if ($debug) {write-host "Schema $Item FastFail mandatory but missing!!!"};
					Return $Tombstone
				}# end if Optional
			}# end if DataStrand
		}#end if SchemaInfo
		$Item = $Enum.SchemaKeysEtc.maxLength
		if ($SchemaInfo.($Item)) {
			if ($debug) {write-host "Schema $Item Start"};
			$SchemaKeys.Remove($item)
			$DataStrand = $DataToVerify.length
			$SchemaStrand = $SchemaInfo.($Item)
			if ($DataStrand -le $SchemaStrand) {
				if ($debug) {write-host "Schema $Item Pass"};
			} else {
				if ($Optional) {
					if ($debug) {write-host "Schema $Item optional"};
					Return $Null
				} else {
					if ($debug) {write-host "Schema $Item FastFail mandatory but missing!!!"};
					Return $Tombstone
				}# end if Optional
			}# end if DataStrand
		}#end if SchemaInfo
		if ($SchemaKeys) {
			if ($Optional) {
				if ($debug) {write-host "Unverified schema keys: $SchemaKeys"};
				Return $Null
			} else {
				if ($debug) {write-host "Error: Unverified schema keys FastFail mandatory but missing: $SchemaKeys" -f red};
				Return $Tombstone
			}
		} else {
			return $DataToVerify
		}
	} catch {
		if ($debug) {write-host "Schema Error FastFail: $($Error[0])"};
		# Return $Tombstone
	}
}# end Function	

Function Get-QueryCheck {
	Param(
		[string]$Item = $Enum.SchemaKeysEtc.SkipToContent,
		[string]$String,
		$ThisSchema = $MVSchemaData.General.($Item)
	)
	[bool]$Mandatory.($Item) = $True
	if ($ThisSchema.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
	if ($debug) {write-host "$Section $Item Schema"}
	$SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisSchema
	if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
	if ($debug) {write-host "$Section $Item Schema Pass"}
	Return $SchemaCheck
}

#Clipboard
Function Get-QueryClipboard { 
	Param(
		[ValidateScript( { $_ -in (Get-Keys $Enum.ClipboardQueries)} )]
		[string]$Query,
		[string]$MatchData, #This should only ever be a YAML or JSON key type of string.
		[String[]]$StrArray = $null,
		[switch]$Debug
	)
	# try {

	$StringMaxLength = 2048
	$StrArrayMaxLength = 2048
	$StringRegex = "[a-zA-Z]{0,256}"#Need to add a few more chars.
	$Mandatory = @{}


	if ($null -ne $StrArray) {
			if ($debug) {write-host "StrArray detected in Parameters"};
			if ($StrArray.length -gt $StrArrayMaxLength) {if ($debug) {write-host "Init StrArray Length FastFail $($StrArray.length)"};Return $Null}
	} else {
		try {
			if ($debug) {write-host "Get StrArray from Clipboard"};
			[string[]]$StrArray = ((Get-Clipboard) -replace $Enum.Regex.CleanClipRegex,$null)
			if ($StrArray.length -gt $StrArrayMaxLength) {if ($debug) {write-host "Init StrArray Length FastFail $($StrArray.length)"};Return $Null}
		} catch {
			if ($debug) {write-host "Clipboard FastFail"};
			Return $Null
		}
	}
	
	Switch ($Query) {
		$Enum.ClipboardQueries.AllPRsOnClipboard {
			$Section = $Enum.ClipboardQueries.AllPRsOnClipboard
			[int[]]$out = @()
			Foreach ($String in $StrArray) {
				#Replace with a String schema.
				if ($String.length -gt $StringMaxLength) {if ($debug) {write-host "$Section String Length FastFail $($String.length)"};Return $Null}
				If ($String -notmatch $StringRegex) {if ($debug) {write-host "$Section String Regex FastFail"};Return $Null}
				
				if ($debug) {write-host "$Section String $String"};
				[string[]]$SplitString = $String -replace "#"," " -split $Enum.Char.Space
				Foreach ($SubString in $SplitString) {
					if (($SubString -match ($mvschemaData.PR.Number.pattern -replace "/","\/"))) {
						if ($debug) {write-host "$Section SubString $SubString"};
						$SchemaCheck = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $SubString)
						if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section Schema Tombstone FastFail"};Return $Null}
						[int]$mid = $SchemaCheck
						if (($mid -gt 9999) -AND ($mid -lt 1000000)) {
							if ($debug) {write-host "$Section mid $mid out $out"};
							$out += $mid
						}# end if mid
					}# end if SubString
				}#end Foreach SubString
			}# end Foreach String
			$out = $out | Select-Object -Unique
			if ($debug) {write-host "$Section out $out"};
			Return $out
		}
		$Enum.ClipboardQueries.PRWatch {
			$Section = $Enum.ClipboardQueries.PRWatch
			$out = "" | Select-Object $Enum.SchemaKeysEtc.ManifestReview, $Enum.ManifestKeys.InstallerType, $Enum.ManifestKeys.PackageVersion, $Enum.ManifestKeys.PackageIdentifier, $Enum.ManifestKeys.AgreementUrl, $Enum.Strings.WordFilterList, $Enum.ManifestKeys.DisplayVersion ,$Enum.ManifestKeys.InstallerUrl
			$keys = Get-Keys $out
			
			
			foreach ($String in $StrArray) {
				if ($String.length -gt $StringMaxLength) {if ($debug) {write-host "$Section String Length FastFail $($String.length)"};Return $Null}
				# If ($String -notmatch $StringRegex) {if ($debug) {write-host "$Section String Regex FastFail"};Return $Null}
				$out.ManifestReview = (Get-ManifestCovertReview $String)
				$String = $String | Get-RemoveQuotes
				
				#$Enum.SchemaKeysEtc.PRtitle, 
				#[string]$Submitter = (($clip | Select-String $Enum.Strings.WantsToMerge) -split $Enum.Char.Space)[$Enum.Index.First]
				#Title needs to include "Remove" etc.
				#ManifestFile needs *ALL* fields
				
				# $Item = $Enum.SchemaKeysEtc.PRtitle
				# $ThisItemschemaData = $MVSchemaData.PR.Title
				# [bool]$Mandatory.($Item) = $True
				# if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				# if ($String -match $Enum.Regex.hashPRRegex) {
					# if ($debug) {write-host "$Section $Item Schema"}
					# $SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisItemschemaData
					# if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					# if ($debug) {write-host "$Section $Item Schema Pass"}
					# [string]$out.($Item) = $SchemaCheck
				# }# end if String

				$Item = $Enum.ManifestKeys.DisplayVersion
				$ThisItemschemaData = $schemaData.installer.definitions.AppsAndFeaturesEntry.properties.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.InstallerType
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.PackageVersion
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.PackageIdentifier
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.AgreementUrl
				$ThisItemschemaData = $schemaData.locale.definitions.Url
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.Strings.WordFilterList
				$ThisItemschemaData = $MVSchemaData.General.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				$SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisItemschemaData
				if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
				if ($debug) {write-host "$Section $Item Schema Pass"}
				[bool]$out.($Item) = $SchemaCheck
				
				#Optional for my system, mandatory for overall system.
				$Item = $Enum.ManifestKeys.InstallerUrl
				$ThisItemschemaData = $schemaData.installer.definitions.Installer.properties.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String
			}# end foreach String
			
			foreach ($Key in $Keys) {
				if ($True -eq $Mandatory.$Key) {#If Mandatory
					if ($null -match $out.$Key) {#If not found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))" -f red}
						Return $Null
					} else {#If found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
					}
				} else {#If Optional
					if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
				}
			}
			
			Return $out
		}
		$Enum.ClipboardQueries.TrackerVMRunTracker {
			$Section = $Enum.ClipboardQueries.TrackerVMRunTracker
			$out = "" | Select-Object $enum.SchemaKeysEtc.SkipToContent, $enum.SchemaKeysEtc.manifests
			$keys = Get-Keys $out

			foreach ($String in $StrArray) {
				[string]$string = $string
				$Item = $Enum.SchemaKeysEtc.SkipToContent
				$ThisItemschemaData = $MVSchemaData.General.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}

				if ($debug) {write-host "$Section $Item Schema"}
				$SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisItemschemaData
				if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
				if ($debug) {write-host "$Section $Item Schema Pass"}
				[bool]$out.($Item) = $SchemaCheck
				
				$Item = $Enum.SchemaKeysEtc.manifests
				$ThisItemschemaData = $MVSchemaData.General.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($debug) {write-host "$Section $Item Schema"}
				$SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisItemschemaData
				if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
				if ($debug) {write-host "$Section $Item Schema Pass"}
				[string]$out.($Item) = $SchemaCheck
			}
			foreach ($Key in $Keys) {
				if ($True -eq $Mandatory.$Key) {#If Mandatory
					if ($null -match $out.$Key) {#If not found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))" -f red}
						Return $Null
					} else {#If found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
					}
				} else {#If Optional
					if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
				}
			}
			
			Return $out
		}
		$Enum.ClipboardQueries.TrackerVMValidate {
			$null = (Get-ManifestCovertReview $StrArray)

			$Section = $Enum.ClipboardQueries.TrackerVMValidate
			$out = "" | Select-Object $Enum.SchemaKeysEtc.PRNumber, $Enum.ManifestKeys.PackageIdentifier, $Enum.ManifestKeys.PackageVersion, $Enum.ManifestKeys.Architecture, $Enum.ManifestKeys.ElevationRequirement
			$keys = Get-Keys $out

			$Item = $Enum.SchemaKeysEtc.PRNumber
			$ThisItemschemaData = $MVSchemaData.PR.Number
			[bool]$Mandatory.($Item) = $True
			if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
			if ($StrArray) {
				$SchemaCheck = Get-QueryClipboard -Query AllPRsOnClipboard -StrArray $StrArray
				if ($SchemaCheck) {
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					if ($SchemaCheck.gettype().name -eq "int[]") {
						[int]$out.($Item) = $SchemaCheck[0]
					} else {
						[int]$out.($Item) = $SchemaCheck
						if ($debug) {write-host "$Section $Item SchemaCheck Type $($SchemaCheck.gettype().name)"}
					}# end if StrArray
				}
			}# end if StrArray
			foreach ($String in $StrArray) {
				$Item = $Enum.ManifestKeys.PackageIdentifier
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.PackageVersion
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string]$out.($Item) = $SchemaCheck
				}# end if String
				
				$Item = $Enum.ManifestKeys.Architecture
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				if ($String -match $Item) {
					$SchemaCheck = Get-SchemaCheck -InputData $String -YamlValue $Item -SchemaInfo $ThisItemschemaData
					if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
					if ($debug) {write-host "$Section $Item Schema Pass"}
					[string[]]$out.($Item) = $SchemaCheck
				}# end if String

				$Item = $Enum.ManifestKeys.ElevationRequirement
				$ThisItemschemaData = $schemaData.installer.definitions.($Item)
				[bool]$Mandatory.($Item) = $True
				if ($ThisItemschemaData.type -contains $Enum.SchemaKeysEtc.Null) {$Mandatory.($Item) = $False}
				$SchemaCheck = Get-SchemaCheck -InputData $String -SchemaInfo $ThisItemschemaData
				if ($SchemaCheck -eq $Enum.Strings.FastFailTombstone) {if ($debug) {write-host "$Section $Item Schema Tombstone FastFail"};Return $Null}
				if ($debug) {write-host "$Section $Item Schema Pass"}
				[bool]$out.($Item) = $SchemaCheck

			}
			
			foreach ($Key in $Keys) {
				if ($True -eq $Mandatory.$Key) {#If Mandatory
					if ($null -match $out.$Key) {#If not found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))" -f red}
						Return $Null
					} else {#If found
						if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
					}
				} else {#If Optional
					if ($debug) {write-host "PRWatch Keys $key - Key Mandatory $($Mandatory.($Key)) - Key Detected $([bool]$out.($Key))"}
				}
			}
			Return $out
		}
		Default {
			if ($debug) {write-host "Default FastFail"};Return $Null
		}# end Default
	}# end Switch Type
	# } catch {
		# if ($debug) {write-host "Query Error FastFail: $($Error[0])"};
		# # Return $Enum.Strings.FastFailTombstone
	# }
}

Function Get-YamlValue {
	Param(
		[string]$Key,
		[Parameter(ValueFromPipeline)][string[]]$clip,
		[switch]$JSON,
		[switch]$Display
	)
	Process {
		if ($JSON) {
			$Key = "`"$($Key)`": "
		} else {
			$Key = "$($Key): "
		}
		$clip = $clip -split $Enum.Char.LineBreak | where {$_ -match $Key}
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (A): $clip"}
		if ($clip) {
			[array]$clip = $clip | Select-Object -unique
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (B): $clip"}
			[array]$clip = $clip[$Enum.Index.First]
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (C): $clip"}
			$clip = ($clip -split ($Enum.Char.Colon + $Enum.Char.Space))[$Enum.Index.Second]
			# [$Enum.Index.Second..99]
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (D): $clip"}
			$clip = ($clip -split $Enum.Char.Hash)[$Enum.Index.First]
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (E): $clip"}
			$clip = ((($clip.ToCharArray()) | where {$_ -match "\S"}) -join $Enum.Char.Blank)
		if ($Display) {Write-Host "$($MyInvocation.MyCommand.name) (F): $clip"}
		} 
		$clip
	}
}

Function Get-AllPRsOnClipboard {
	return Get-QueryClipboard -Query $Enum.ClipboardQueries.AllPRsOnClipboard
}

#Etc
Function Open-PRInBrowser {
	Param(
		[int]$PR,
		[Switch]$Files
	)
	$PR = (Get-SchemaCheck -SchemaInfo $mvschemaData.PR.Number -InputData $PR)
	$URL = "$GitHubBaseUrl/pull/$PR#issue-comment-box"
	if ($Files) {
		$URL = "$GitHubBaseUrl/pull/$PR/files"
	}
	Start-Process $URL
	Start-Sleep $GitHubRateLimitDelay
}#end Function

Function Test-Admin {
	$UserGroups = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups
	if (![bool]($UserGroups -match $Enum.TestAdmin.AdminString)){
		Write-Host $Enum.TestAdmin.TryElevatingYourSession;
		Break
	}
}

Function Get-TrackerProgress {
	Param(
		[string]$Activity,
		[string]$ItemName,
		[int]$ItemNumber,
		[int]$TotalItems,
		$Percent = [math]::round($ItemNumber / $TotalItems*100,$Enum.Num.Two)
	)
	Write-Progress -Activity $Activity -Status "$ItemNumber / $TotalItems = $Percent % - $ItemName" -PercentComplete $Percent
}

Function Get-ArraySum {
	Param(
		$in = $Enum.Num.Zero,
		$out = $Enum.Num.Zero
	)
	$in |ForEach-Object{$out += $_* $Enum.Num.One}
	[math]::Round($out,$Enum.Num.Two)
}

Function Get-Diff {
	Param(
		$Left, 
		$Right, 
 [ValidateScript( { $_ -in (Get-Keys $Enum.DiffData)} )][string]$Side = $Enum.DiffData.Left
	)
	$matchSide = $Enum.Char.Blank
	switch ($Side) {
		$Enum.DiffData.Left {
			$matchSide = $Enum.DiffData.LeftSide
		}
		$Enum.DiffData.Right {
			$matchSide = $Enum.DiffData.RightSide
		}
		default {
			Write-Host "Error: Side $Side is neither Left nor RIght!"
			Break
		}
	}
	$mid = Compare-Object $Left $Right | where {$_.SideIndicator -match $matchSide}
	$out = $mid.inputobject 
	return $out
}

Function Get-Keys {
	Param(
		$Data
	)
	if ($Data) {
		[string[]]$Names = ($Data | Get-Member | Where-Object {$_.membertype -eq $Enum.Words.NoteProperty}).name
		Return $Names
	}
}

Function Get-Values {
	Param(
		$Data
	)
	$Names = Get-Keys $Data
	$Values = $Names | %{$Data.($_)}
	Return $Values
}

#PR Watcher Utility functions
Function Get-PadRight {
	Param(
		[string]$InputString,
		[int]$PadChars = 45
	)
	$out = $InputString
	if ($InputString.Length -lt $PadChars) {
		$out = $InputString + ($Enum.Char.Space*($PadChars - $InputString.Length -1))
	} elseif ($InputString.Length -lt $PadChars) {
		$out = $InputString[$Enum.Index.First..($PadChars -1)]
	}
	$out = $out -join $Enum.Char.Blank
	$out
}

#VM Window Management
Function Get-TrackerVMWindowLoc {
	Param(
		$VM,
		$Rectangle = (New-Object RECT),
		$VMProcesses = (Get-Process vmconnect),
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match ("vm$VM")}).MainWindowHandle
	)
	[window]::GetWindowRect($MWHandle,[ref]$Rectangle)
	Return $Rectangle
}

Function Get-TrackerVMWindowSet {
	Param(
		$VM,
		$Left,
		$Top,
		$Right,
		$Bottom,
		$VMProcesses = (Get-Process vmconnect),
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match ("vm$VM")}).MainWindowHandle
	)
	$null = [window]::MoveWindow($MWHandle,$Left,$Top,$Right,$Bottom,$True)
}

Function Get-TrackerVMWindowArrange {
	Param(
		$VMs = (Get-Status |where {$_.status -ne $Enum.VMStatus.Ready}|where {$_.status -ne $Enum.VMStatus.Unhealthy}).vm 
	)
	If ($VMs) {
		Get-TrackerVMWindowSet $VMs[$Enum.Index.First] $Enum.VMWinLoc.Left $Enum.VMWinLoc.Top $Enum.VMWinLoc.Bottom $Enum.VMWinLoc.Right
		$Base = Get-TrackerVMWindowLoc $VMs[$Enum.Index.First]
		
		For ($n = $Enum.Index.Second; $n -lt $VMs.Count; $n++) {
			$VM = $VMs[$n]
			
			$Left = ($Base.left - ($Enum.VMWinLoc.LeftAdj * $n))
			$Top = ($Base.top + ($Enum.VMWinLoc.TopAdj * $n))
			Get-TrackerVMWindowSet $VM $Left $Top $Enum.VMWinLoc.Bottom $Enum.VMWinLoc.Right
		}
	}
}

#From StackOverflow
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Window {
	[DllImport("user32.dll")]
	[return: MarshalAs(UnmanagedType.Bool)]
	public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
	[DllImport("user32.dll")]
	public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

}
public struct RECT {
	public int Left; // x position of upper-left corner
	public int Top; // y position of upper-left corner
	public int Right; // x position of lower-right corner
	public int Bottom; // y position of lower-right corner
}
"@

#From https://stackoverflow.com/a/67944064
#Updated with: 
#https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal.stringtocotaskmemuni?view=net-10.0
#https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshal.copy?view=net-10.0#system-runtime-interopservices-marshal-copy(system-intptr-system-byte()-system-int32-system-int32)

# How to store credentials
# [CredManager.Util]::SetUserCredential("Application Name", "Username", "Password")
# How to retrieve credentials
# [CredManager.Util]::GetUserCredential("Application Name")
# How to just get the password
# [CredManager.Util]::GetUserCredential("Application Name").password

Add-Type @"
using System.Text;
using System;
using System.Runtime.InteropServices;

namespace CredManager {
	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct CredentialMem {
		public int flags;
		public int type;
		public string targetName;
		public string comment;
		public System.Runtime.InteropServices.ComTypes.FILETIME lastWritten;
		public int credentialBlobSize;
		public IntPtr credentialBlob;
		public int persist;
		public int attributeCount;
		public IntPtr credAttribute;
		public string targetAlias;
		public string userName;
	}

	public class Credential {
		public string target;
		public string username;
		public string password;
		public Credential(string target, string username, string password) {
			this.target = target;
			this.username = username;
			this.password = password;
		}
	}

	public class Util {
		[DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
		private static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);
		//Extend/reference CredReadW as CredRead.

		public static Credential GetUserCredential(string target) {
			CredentialMem credMem;
			IntPtr credPtr;
			if (CredRead(target, 1, 0, out credPtr)) { //If found, returns true and adds to credPtr, else false and error. 
				credMem = Marshal.PtrToStructure<CredentialMem>(credPtr); 
				//"Marshals data from an unmanaged block of memory to a newly allocated managed object of the type specified by a generic type parameter."
				byte[] passwordBytes = new byte[credMem.credentialBlobSize]; //Make a new byte array passwordBytes of size credentialBlobSize.
				Marshal.Copy(credMem.credentialBlob, passwordBytes, 0, credMem.credentialBlobSize); 
				//Copies data from an unmanaged memory pointer to a managed 8-bit unsigned integer array.
				//
				Credential cred = new Credential(credMem.targetName, credMem.userName, Encoding.Unicode.GetString(passwordBytes)); //Make a new Credential object cred.
				//Original example doesn't include these:
				Marshal.FreeHGlobal(credPtr);
				Marshal.FreeHGlobal(credMem.credentialBlob);
				return cred;
			} else {
				throw new Exception("Failed to retrieve credentials");
			}
		}

		[DllImport("Advapi32.dll", SetLastError = true, EntryPoint = "CredWriteW", CharSet = CharSet.Unicode)]
		private static extern bool CredWrite([In] ref CredentialMem userCredential, [In] int flags);
		//Extend/reference CredWriteW as CredWrite.

		public static void SetUserCredential(string target, string userName, string password) {
			//New CredentialMem object userCredential
			CredentialMem userCredential = new CredentialMem();
			userCredential.targetName = target;
			userCredential.type = 1;
			userCredential.userName = userName;
			userCredential.attributeCount = 0;
			userCredential.persist = 3;
			byte[] bpassword = Encoding.Unicode.GetBytes(password);
			userCredential.credentialBlobSize = (int)bpassword.Length;
			userCredential.credentialBlob = Marshal.StringToCoTaskMemUni(password);
			//If write fails, emit last error. 
			if (!CredWrite(ref userCredential, 0)) {
				throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
			}
			//Original example doesn't include this. Was going to use FreeCoTaskMem as recommended, but this gave an error. 
			Marshal.FreeHGlobal(userCredential.credentialBlob);
		}
	}
}
"@


$GitHubToken = [CredManager.Util]::GetUserCredential("GitHubToken").password

$schemaData.installer = Invoke-GitHubRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-cli/refs/heads/master/schemas/JSON/manifests/v1.12.0/manifest.installer.1.12.0.json" -JSON
$schemaData.locale = Invoke-GitHubRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-cli/refs/heads/master/schemas/JSON/manifests/v1.12.0/manifest.locale.1.12.0.json" -JSON
$schemaData.defaultLocale = Invoke-GitHubRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-cli/refs/heads/master/schemas/JSON/manifests/v1.12.0/manifest.defaultLocale.1.12.0.json" -JSON
$schemaData.version = (Invoke-GitHubRequest -Uri "https://raw.githubusercontent.com/microsoft/winget-cli/refs/heads/master/schemas/JSON/manifests/v1.12.0/manifest.version.1.12.0.json" -JSON)

Get-StartupTest



