#Copyright 2022-2025 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v3.90.0
#Created: 10/19/2022
#Updated: 3/3/2025
#Notes: Utilities to streamline evaluating 3rd party PRs.


$build = 1085
$appName = "ManualValidationPipeline"
Write-Host "$appName build: $build"
$MainFolder = "C:\ManVal"
$Owner = "microsoft"
$Repo = "winget-pkgs"
$ReposFolder = "C:\repos\$Repo"
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.
Set-Location $MainFolder

$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString
$RemoteMainFolder = "//$remoteIP/"
$SharedFolder = "$RemoteMainFolder/write"

$imagesFolder = "$MainFolder\Images" #VM Images folder
$logsFolder = "$MainFolder\logs" #VM Logs folder
$runPath = "$MainFolder\vm\" #VM working folder
$writeFolder = "$MainFolder\write" #Folder with write permissions
$vmCounter = "$MainFolder\vmcounter.txt"
$VMversion = "$MainFolder\VMversion.txt"
$StatusFile = "$writeFolder\status.csv"
$TrackerModeFile = "$logsFolder\trackermode.txt"
$RemoteTrackerModeFile = "$RemoteMainFolder\ManVal\logs\trackermode.txt"
$LogFile = "$MainFolder\misc\ApprovedPRs.txt"
$PeriodicRunLog = "$MainFolder\misc\PeriodicRunLog.txt"
$SharedErrorFile = "$writeFolder\err.txt"
$DataFileName = "$ReposFolder\Tools\ManualValidationPipeline.csv"

$LabelActionFile = "$ReposFolder\Tools\LabelActions.csv"
$ExitCodeFile = "$ReposFolder\Tools\ExitCodes.csv"
$MsiErrorCodeFile = "$ReposFolder\Tools\MsiErrorCodes.csv"
$AutowaiverFile = "$ReposFolder\Tools\Autowaiver.csv"
$PRStateDataFile = "$ReposFolder\Tools\PRStateFromComments.csv"
$PRQueueFile = "C:\manval\misc\PRQueue.txt"
$PRExcludeFile = "C:\manval\misc\PRExclude.txt"

$Win10Folder = "$imagesFolder\Win10-Created053025-Original"
$Win11Folder = "$imagesFolder\Win11-Created061225-Original"

$GitHubBaseUrl = "https://github.com/$Owner/$Repo"
$GitHubContentBaseUrl = "https://raw.githubusercontent.com//$Owner/$Repo"
$GitHubApiBaseUrl = "https://api.github.com/repos/$Owner/$Repo"
$ADOMSBaseUrl = "https://dev.azure.com/shine-oss"
$ADOMSGUID = "8b78618a-7973-49d8-9174-4360829d979b"

$CheckpointName = "Validation"
$VMUserName = "user" #Set to the internal username you're using in your VMs.
$GitHubUserName = "stephengillie"
$SystemRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
$Host.UI.RawUI.WindowTitle = "Utility"
$GitHubRateLimitDelay = 0.2 #seconds

$PRRegex = "[0-9]{5,6}"
$hashPRRegex = "[#]"+$PRRegex
$hashPRRegexEnd = $hashPRRegex+"$"
$colonPRRegex = $PRRegex+"[:]"
#"Manual Validation results for $PackageIdentifier version $PackageVersion on $Date"

<#
$package = "clang-uml"
$a = Get-ARPTable |where {$_.DisplayName -match $package}
$a.displayversion
$b = &"C:\Program Files\clang-uml\bin\clang-uml.exe" "--version"
$a.DisplayVersion -match $b
$a.DisplayVersion -match $b -join " "
$b -match $a.DisplayVersion
#>

#region Data
[array]$DisplayVersionExceptionList = "Netbird.Netbird",
"ppy.osu"

#$MagicStrings = @{}
[array]$MagicStrings = "Installer Verification Analysis Context Information:", #0
"[error] One or more errors occurred.", #1
"[error] Manifest Error:", #2
"BlockingDetectionFound", #3
"Processing manifest", #4
"SQL error or missing database", #5
"Error occurred while downloading installer", #6
"Specified hash doesn't match", #7
"[error] Manifest is invalid", #8
"Result: Failed",  #9
"[error] Manifest Warning:",#10
"[error] Manifest:",#11
"Exception Message",#12
"[error] "#13

$Actions = @{}
$Actions.Approved = "Approved"
$Actions.Blocking = "Blocking"
$Actions.Feedback = "Feedback"
$Actions.Retry = "Retry"
$Actions.Manual = "Manual"
$Actions.Closed = "Closed"
$Actions.Project = "Project"
$Actions.Squash = "Squash"
$Actions.Waiver = "Waiver"

$Labels = @{}

$Labels.403 = "Validation-Forbidden-URL-Error"
$Labels.404 = "Validation-404-Error"
$Labels.AGR = "Agreements"
$Labels.ANA = "Author-Not-Authorized"
$Labels.ANF = "Manifest-AppsAndFeaturesVersion-Error"
$Labels.APP = "Azure-Pipeline-Passed"
$Labels.BI = "Blocking-Issue"
$Labels.BMM = "Bulk-Modify-Metadata"
$Labels.BVE = "Binary-Validation-Error"
$Labels.CLA = "Needs-CLA"
$Labels.CR = "Changes-Requested"
$Labels.DI = "DriverInstall"
$Labels.EAT = "Error-Analysis-Timeout"
$Labels.EHM = "Error-Hash-Mismatch"
$Labels.EIA = "Error-Installer-Availability"
$Labels.HVF = "Validation-Hash-Verification-Failed"
$Labels.HVL = "Highest-Version-Remaining"
$Labels.HVR = "Highest-Version-Removal"
$Labels.HW = "Hardware"
$Labels.IE = "Internal-Error"
$Labels.IEDS = "Internal-Error-Dynamic-Scan"
$Labels.IEM = "Internal-Error-Manifest"
$Labels.IEU = "Internal-Error-URL"
$Labels.IOD = "Interactive-Only-Download"
$Labels.IOI = "3AInteractive-Only-Installer"
$Labels.LBI = "License-Blocks-Install"
$Labels.LVR = "Last-Version-Removal"
$Labels.MA = "Moderator-Approved"
$Labels.MIVE = "Manifest-Installer-Validation-Error"
$Labels.MMC = "Manifest-Metadata-Consistency"
$Labels.MV = "Manually-Validated"
$Labels.MVE = "Manifest-Validation-Error"
$Labels.NA = "Needs-Attention"
$Labels.NAF = "Needs-Author-Feedback"
$Labels.NB = "Network-Blocker"
$Labels.NM = "New-Manifest"
$Labels.NMM = "Needs-Manual-Merge"
$Labels.NP = "New-Package"
$Labels.NR = "Needs-Review"
$Labels.NRA = "No-Recent-Activity"
$Labels.NSA = "Internal-Error-NoSupportedArchitectures"
$Labels.OUF = "Validation-Open-Url-Failed"
$Labels.PD = "Possible-Duplicate"
$Labels.PF = "Project-File"
$Labels.PRE = "PullRequest-Error"
$Labels.PT12 = "Policy-Test-1.2"
$Labels.PT23 = "Policy-Test-2.3"
$Labels.PT27 = "Policy-Test-2.7"
$Labels.RB = "Reboot"
$Labels.RET = "Retry-1"
$Labels.SA = "Scripted-Application"
$Labels.UF = "Unexpected-File"
$Labels.UVE = "URL-Validation-Error"
$Labels.VC = "Validation-Completed"
$Labels.VCR = "Validation-Certificate-Root"
$Labels.VD = "Validation-Domain"
$Labels.VDE = "Validation-Defender-Error"
$Labels.VEE = "Validation-Executable-Error"
$Labels.VER = "Manifest-Version-Error"
$Labels.VHE = "Validation-HTTP-Error"
$Labels.VIE = "Validation-Installation-Error"
$Labels.VMC = "Validation-Merge-Conflict"
$Labels.VMD = "Validation-Missing-Dependency"
$Labels.VNE = "Validation-No-Executables"
$Labels.VR = "Validation-Retry"
$Labels.VSA = "Validation-Skip-Automations"
$Labels.VSE = "Validation-Shell-Execute"
$Labels.VSS = "Validation-SmartScreen-Error"
$Labels.VUF = "Validation-Unattended-Failed"
$Labels.VUU = "Validation-Unapproved-URL"


$PushMePRWho = "Author,MatchString`nspectopo,Mozilla.Firefox`ntrenly,Standardize formatting`nSpecterShell,Mozilla.Thunderbird" | ConvertFrom-Csv

$QueueInputs = "No suitable installer found for manifest", #0
"Caught std::exception: bad allocation", #1
"exit code: -1073741515",#2
"exit code: -1978335216"#3

#endregion

#First tab
Function Get-TrackerVMRunTracker {
	param(
	[switch]$RunLatch
	)
	$HourLatch = $False
	while ($True) {
		$Host.UI.RawUI.WindowTitle = "Orchestration"
		#Run once an hour at ~20 after.
		if (([int](get-date -f mm) -eq 20) -OR ([int](get-date -f mm) -eq 50)) {
			$HourLatch = $True
		}
		if ($RunLatch -eq $False) {
			$HourLatch = $False
		}
		if ($HourLatch) {#Hourly Run functionality
			Get-ScheduledRun 
			$HourLatch = $False
		}
		
		Clear-Host
		$GetStatus = Get-Status
		$GetStatus | Format-Table;
		$VMRAM = Get-ArraySum $GetStatus.RAM
		$ramColor = "green"
		$valMode = Get-TrackerMode

(Get-Status).vm | %{$path = "C:\ManVal\vm\$_\manifest\Package.yaml";(gc $path) -replace "ManifestVersion: 1..0$","ManifestVersion: 1.10.0" | out-file $path}

		if ($VMRAM -gt ($SystemRAM*0.5)) {
			$ramColor = "red"
		} elseif ($VMRAM -gt ($SystemRAM*.25)) {
			$ramColor = "yellow"
		}
		Write-Host "VM RAM Total: " -nonewline
		Write-Host -f $ramColor $VMRAM
		$timeClockColor = "red"
		if (Get-TimeRunning) {
			$timeClockColor = "green"
		}
		$PRQueueCount = Get-PRQueueCount
		Write-Host -nonewline "Build: $build - Hours worked: "
		Write-Host -nonewline -f $timeClockColor (Get-HoursWorkedToday)
		Write-Host  " - PRs in queue: $PRQueueCount - Hourly Run: $RunLatch"
		(Get-VM) | ForEach-Object {
			if(($_.MemoryDemand / $_.MemoryMaximum) -ge 0.9){
				Set-VM -VMName $_.name -MemoryMaximumBytes "$(($_.MemoryMaximum / 1073741824)+2)GB"
			}
		}
		$status = Get-Status
		$status | ForEach-Object {$_.RAM = [math]::Round((Get-VM -Name ("vm"+$_.vm)).MemoryAssigned/1024/1024/1024,2)}
		Write-Status $status
		Get-TrackerVMCycle;
		Get-TrackerVMWindowArrange

		if ($valMode -eq "IEDS") {
			if ((Get-ArraySum (Get-Status).RAM) -lt ($SystemRAM*.42)) {
				Write-Output $valMode
				Get-RandomIEDS
			}
		}

		if ($PRQueueCount -gt 0) {
			if ((Get-ArraySum (Get-Status).RAM) -lt ($SystemRAM*.42)) {
				$PR = Get-PopPRQueue
				if ($null -ne $PR) {
					Write-Output "Running $PR from queue."
					Get-RandomIEDS -PR $PR
				}
			}
		}

		$clip = (Get-Clipboard)
		If ($clip -match $ADOMSBaseUrl) {
			#Write-Output "Gathering Automated Validation Logs"
			#Get-AutoValLog
		} elseIf ($clip -match "Skip to content") {
			if ($valMode -eq "Validating") {
				Write-Output $valMode
				Get-TrackerVMValidate;
				$valMode | clip
			}
		} elseIf ($clip -match " Windows Package Manager") {#Package Manager Dashboard
			#Write-Output "Gathering PR Headings"
			#Get-PRNumber
		} elseIf ($clip -match "^manifests`/") {
			Write-Output "Opening manifest file"
			$ManifestUrl = "$GitHubBaseUrl/tree/master/"+$clip
			$ManifestUrl | clip
			start-process ($ManifestUrl)
		}
		# $MozillaThunderbird = (Get-Status | ? {$_.Package -match "Mozilla.Thunderbird"} ).vm 
		# if ($null -ne $MozillaThunderbird) {
			# $MozillaThunderbird | %{Get-TrackerVMSetStatus -Status Complete -VM $_}
		# }
		if (Get-ConnectedVM) {
			#Get-TrackerVMResetStatus
		} else {
			Get-TrackerVMRotate
		}
		Write-Output "End of cycle."
		Start-Sleep 5;
	}
	#Write-Progress -Completed
}

#Second tab
Function Get-PRWatch {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		[ValidateSet("Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","Cöte D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania, United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Åland Islands")]$Chromatic = "Default",
		$LogFile = ".\PR.txt",
		$ReviewFile = ".\Review.csv",
		$oldclip = "",
		$PrePipeline = $false,
		$AuthList = (Get-ValidationData -Property authStrictness),
		$AgreementsList = (Get-ValidationData -Property AgreementUrl),
		$ReviewList = (Get-LoadFileIfExists $ReviewFile),
		$clip = (Get-Clipboard),
		[switch]$WhatIf
	)
	$Host.UI.RawUI.WindowTitle = "PR Watcher"#I'm a PR Watcher, watchin PRs go by. 
	#if ((Get-Command Get-TrackerVMSetMode).name) {Get-TrackerVMSetMode "Approving"}

	Write-Host " | Timestmp | $(Get-PadRight PR# 6) | $(Get-PadRight PackageIdentifier) | $(Get-PadRight prVersion 15) | A | R | G | W | F | I | D | V | $(Get-PadRight ManifestVer 14) | OK |"
	Write-Host " | -------- | ----- | ------------------------------- | -------------- | - | - | - | - | - | - | - | - | ------------- | -- |"

	while($True -gt 0){
		$clip = (Get-Clipboard)
		$PRtitle = $clip | Select-String ($hashPRRegexEnd);
		$PR = ($PRtitle -split "#")[1]
		if ($PRtitle) {
			if (Compare-Object $PRtitle $oldclip) {
				# if ((Get-Command Get-Status).name) {
					# (Get-Status | Where-Object {$_.status -eq "ValidationCompleted"} | Format-Table)
				# }
				$validColor = "green"
				$invalidColor = "red"
				$cautionColor = "yellow"

				Switch ($Chromatic) {
					#Color schemes, to accomodate needs and also add variety.
						"Default" {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
						"Warm" {
							$validColor = "White"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
						"Cool" {
							$validColor = "Green"
							$invalidColor = "Blue"
							$cautionColor = "Cyan"
						}
						"Random" {
							$Chromatic = ($CountrySet | get-random)
							Write-Host "Using CountrySet $Chromatic" -f green
						}
#https://www.flagpictures.com/countries/flag-colors/
"Afghanistan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Albania"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
}
"Algeria"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"American Samoa"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Andorra"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Angola"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Anguilla"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Antigua And Barbuda"{
	$invalidColor = "Red"
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Argentina"{
	$validColor = "White"
	$cautionColor = "Cyan"
}
"Armenia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Aruba"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Australia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Austria"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Azerbaijan"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Bahamas"{
	$validColor = "DarkGray"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Bahrain"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Bangladesh"{
	$validColor = "Green"
	$invalidColor = "Red"
}
"Barbados"{
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Belarus"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Belgium"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Belize"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Benin"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Bermuda"{
	$invalidColor = "Red"
}
"Bhutan"{
	$validColor = "DarkRed"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Bolivia"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Bosnia And Herzegovina"{
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Botswana"{
	$validColor = "DarkGray"
	$invalidColor = "White"
	$cautionColor = "Cyan"
}
"Bouvet Island"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Brazil"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Brunei Darussalam"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Bulgaria"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Burkina Faso"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Burundi"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Cabo Verde"{
	$validColor = "White"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cambodia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cameroon"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Canada"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Central African Republic"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Chad"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Chile"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"China"{
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Colombia"{
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Comoros"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Cook Islands"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Costa Rica"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Croatia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Cuba"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"CuraÃ§ao"{
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Cyprus"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Czechia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"CÃ´te D'Ivoire"{
	$validColor = "Green"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Democratic Republic Of The Congo"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Denmark"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Djibouti"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Dominica"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Dominican Republic"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Ecuador"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Egypt"{
	$validColor = "DarkGray"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"El Salvador"{
	$validColor = "White"
	$invalidColor = "DarkYellow"
	$cautionColor = "Blue"
}
"Equatorial Guinea"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Eritrea"{
	$validColor = "Green"
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Estonia"{
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Eswatini"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Ethiopia"{
	$validColor = "Green"
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Fiji"{
	$validColor = "White"
	$validColor = "DarkBlue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Finland"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"France"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"French Polynesia"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Gabon"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Gambia"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Georgia"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Germany"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Ghana"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Greece"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Grenada"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guatemala"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Guinea"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guinea-Bissau"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guyana"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Haiti"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Holy See (Vatican City State)"{
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Honduras"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Hong Kong" {
	$validColor = "White"
	$invalidColor = "Red"
}
"Hungary"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Iceland"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"India"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Indonesia"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Iran"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Iraq"{
	$invalidColor = "Red"
	$validColor = "DarkGray"
	$validColor = "Green"
	$cautionColor = "White"
}
"Ireland"{
	$validColor = "Green"
	$invalidColor = "Blue"
}
"Israel"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"Italy"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Jamaica"{
	$validColor = "Green"
	$invalidColor = "DarkGray"
	$cautionColor = "DarkYellow"
}
"Japan"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Jordan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kazakhstan"{
	$cautionColor = "Yellow"
	$invalidColor = "Blue"
}
"Kenya"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kiribati"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
}
"Kuwait"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Kyrgyzstan"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Laos"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Latvia"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Lebanon"{
	$invalidColor = "Red"
	$validColor = "Green"
	$cautionColor = "White"
}
"Lesotho"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Liberia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Libya"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Liechtenstein"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Lithuania"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Luxembourg"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
}
"Macao" {
	$validColor = "Green"
	$cautionColor = "White"
}
"Madagascar"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Malawi"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "DarkGray"
}
"Malaysia"{
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "DarkBlue"
	$cautionColor = "Yellow"
}
"Maldives"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Mali"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Malta"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Marshall Islands"{
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"Mauritania"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Mauritius"{
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Mexico"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Micronesia"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Moldova"{
	$validColor = "Blue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Monaco"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Mongolia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Montenegro"{
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Morocco"{
	$validColor = "Green"
	$invalidColor = "Red"
}
"Mozambique"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Myanmar"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
	$cautionColor = "White"
}
"Namibia"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Nauru"{
	$invalidColor = "Blue"
	$validColor = "White"
	$cautionColor = "Yellow"
}
"Nepal"{
	$validColor = "DarkRed"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Netherlands"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"New Zealand"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Nicaragua"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Niger"{
	$validColor = "Green"
	$cautionColor = "White"
	$cautionColor = "DarkYellow"
}
"Nigeria"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Niue"{
	$validColor = "DarkYellow"
}
"Norfolk Island"{
	$validColor = "Green"
	$cautionColor = "White"
}
"North Korea"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"North Macedonia"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Norway"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Oman"{
	$invalidColor = "Red"
	$validColor = "Green"
	$cautionColor = "White"
}
"Pakistan"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Palau"{
	$cautionColor = "Yellow"
	$invalidColor = "Blue"
}
"Palestine"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Panama"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Papua New Guinea"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Paraguay"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Peru"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Philippines"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Pitcairn Islands"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Brown"
	$cautionColor = "Yellow"
}
"Poland"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Portugal"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Qatar"{
	$validColor = "DarkRed"
	$cautionColor = "White"
}
"Republic Of The Congo"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Romania"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Russian Federation"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Rwanda"{
	$validColor = "Green"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Saint Kitts And Nevis"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Saint Lucia"{
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Cyan"
	$cautionColor = "Yellow"
}
"Saint Vincent And The Grenadines"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Samoa"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"San Marino"{
	$validColor = "White"
	$cautionColor = "Cyan"
}
"Sao Tome And Principe"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Saudi Arabia"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Senegal"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Serbia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Seychelles"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Sierra Leone"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Singapore"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Slovakia"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Slovenia"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "DarkYellow"
	$cautionColor = "White"
}
"Solomon Islands"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Somalia"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"South Africa"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
	$cautionColor = "White"
}
"South Korea"{
	$validColor = "White"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"South Sudan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Spain"{
	$invalidColor = "Red"
	$invalidColor = "DarkYellow"
}
"Sri Lanka"{
	$validColor = "Green"
	$invalidColor = "DarkRed"
	$cautionColor = "DarkYellow"
}
"Sudan"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Suriname"{
	$validColor = "DarkYellow"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Sweden"{
	$validColor = "Blue"
	$invalidColor = "DarkYellow"
}
"Switzerland"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Syrian Arab Republic"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tajikistan"{
	$validColor = "DarkYellow"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tanzania, United Republic Of"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Thailand"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Togo"{
	$validColor = "Green"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Tonga"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Trinidad And Tobago"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Tunisia"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Turkey"{
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Turkmenistan"{
	$validColor = "Green"
	$cautionColor = "White"
}
"Tuvalu"{
	$validColor = "DarkBlue"
	$invalidColor = "DarkYellow"
	$invalidColor = "Red"
	$cautionColor = "Cyan"
	$cautionColor = "White"
}
"Uganda"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
	$cautionColor = "Yellow"
}
"Ukraine"{
	$invalidColor = "Blue"
	$invalidColor = "DarkYellow"
}
"United Arab Emirates"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"United Kingdom"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"United States"{
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Blue"
}
"Uruguay"{
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Uzbekistan"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Vanuatu"{
	$validColor = "DarkGray"
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Venezuela"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Vietnam"{
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Yemen"{
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Zambia"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
"Zimbabwe"{
	$validColor = "Green"
	$validColor = "DarkGray"
	$validColor = "White"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Ã…land Islands"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "DarkYellow"
}
						Default {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
					}; #end Switch Chromatic

				$noRecord = $False
				$title = $PRtitle -split ": "
				if ($title[1]) {
					$title = $title[1] -split " "
				} else {
					$title = $title -split " "
				}
				$Submitter = (($clip | Select-String "wants to merge") -split " ")[0]
				$InstallerType = Get-YamlValue InstallerType

				#Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. For some reason almost everyone puts the version number as the last item, and GitHub appends the PR number.
				$prVerLoc =($title | Select-String "version").linenumber
				#Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch.
				try {
					[System.Version]$prVersion = Get-YamlValue PackageVersion $clip -replace "'","" -replace '"',''
				} catch {
					try {
						$prVersion = Get-YamlValue PackageVersion $clip -replace "'","" -replace '"',''
					} catch {
							try {
						[System.Version]$prVersion = Get-YamlValue PackageVersion $clip
						} catch {
							if ($null -ne $PRVerLoc) {
								try {
									[System.Version]$prVersion = $title[$prVerLoc]
								} catch {
									[string]$prVersion = $title[$prVerLoc]
								}
							} else {
							#Otherwise we have to go hunting for the version number.
								try {
									[System.Version]$prVersion = $title[-1]
								} catch {
									try {
										[System.Version]$prVersion = $title[-2]
									} catch {
										try {
											[System.Version]$prVersion = $title[-3]
										} catch {
											try {
												[System.Version]$prVersion = $title[-4]
											} catch {
												#If it's not a semantic version, guess that it's the 2nd to last, based on the above logic.
												[string]$prVersion = $title[-2]
											}
										}
									}
								}; #end try
							}; #end try
						}; #end if null
					}; #end try
				}; #end try

				#Get the PackageIdentifier and alert if it matches the auth list.
				$PackageIdentifier = ""
				try {
					$PackageIdentifier = Get-YamlValue PackageIdentifier $clip -replace '"',""
				} catch {
					$PackageIdentifier = (Get-CleanClip $PRtitle); -replace '"',""
				}
				$matchColor = $validColor





				Write-Host -nonewline -f $matchColor " | $(Get-Date -Format T) | $PR | $(Get-PadRight $PackageIdentifier) | "

				#Variable effervescence
				$prAuth = "+"
				$Auth = "A"
				$Review = "R"
				$WordFilter = "W"
				$AgreementAccept = "G"
				$AnF = "F"
				$InstVer = "I"
				$ListingDiff = "D"
				$NumVersions = 99
				$PRvMan = "P"
				$Approve = "+"

				$WinGetOutput = Find-WinGetPackage $PackageIdentifier | where {$_.id -eq $PackageIdentifier}
				$ManifestVersion = $WinGetOutput.version
				$ManifestVersionParams = ($ManifestVersion -split "[.]").count
				$prVersionParams = ($prVersion -split "[.]").count


				$AuthMatch = $AuthList | Where-Object {$_.PackageIdentifier -eq $PackageIdentifier}

				if ($AuthMatch) {
					$AuthAccount = $AuthMatch.GitHubUserName | Sort-Object -Unique
				}

				if ($null -eq $WinGetOutput) {
					$PRvMan = "N"
					$matchColor = $invalidColor
					$Approve = "-!"
					if ($noNew) {
						$noRecord = $True
					} else {
						Add-PRToQueue -PR $PR
						# if ($title[-1] -match $hashPRRegex) {
							# if ((Get-Command Get-TrackerVMValidate).name) {
								#Add-PRToQueue -PR $PR
								# Get-TrackerVMValidate -Silent -InspectNew
							# } else {
								# Get-Sandbox ($title[-1] -replace"#","")
							# }; #end if Get-Command
						# }; #end if title
					}; #end if noNew
				}
				Write-Host -nonewline -f $matchColor "$(Get-PadRight $PRVersion.toString() 14) | "
				$matchColor = $validColor




				if ($AuthMatch) {
					$strictness = $AuthMatch.authStrictness | Sort-Object -Unique
					$matchVar = ""
					$matchColor = $cautionColor
					$AuthAccount -split "/" | where {$_ -notmatch "Microsoft"} | %{
						#write-host "This $_ Submitter $Submitter"
						if ($_ -eq $Submitter) {
							$matchVar = "matches"
							$Auth = "+"
							$matchColor = $validColor
						}
						foreach ($User in ((Invoke-GitHubPRRequest -PR $PR -Type reviews -Output Content).user.login | select -Unique)) {
							if ($Submitter -match $User) {
								$matchVar = "preapproved"
								$Auth = "+"
								$matchColor = $validColor
							}
						}
						
					}
					
					if ($matchVar -eq  "") {
						$matchVar = "does not match"
						$Auth = "-"
						$matchColor = $invalidColor
					}
					if ($strictness -eq "must") {
						$Auth += "!"
					}
				}
				if ($Auth -eq "-!") {
					if (!$WhatIf) {
						Get-PRApproval -PR $PR -PackageIdentifier $PackageIdentifier
					}
				}
				Write-Host -nonewline -f $matchColor "$Auth | "
				$matchColor = $validColor





				$ReviewMatch = $ReviewList | Where-Object {$_.PackageIdentifier -match $PackageIdentifier }
				if ($ReviewMatch) {
					$Review = $ReviewMatch.Reason | Sort-Object -Unique
					$matchColor = $cautionColor
				}

				Write-Host -nonewline -f $matchColor "$Review | "
				$matchColor = $validColor



			#In list, matches PR - explicit pass
			#In list, PR has no Installer.yaml - implicit pass
			#In list, missing from PR - block
			#In list, mismatch from PR - block
			#Not in list or PR - pass
			#Not in list, in PR - alert and pass?
			#Check previous version for omission - depend on wingetbot for now.
			$AgreementUrlFromList = ($AgreementsList | where {$_.PackageIdentifier -eq $PackageIdentifier}).AgreementUrl
			if ($AgreementUrlFromList) {
				$AgreementUrlFromClip = Get-YamlValue AgreementUrl $clip -replace '"',""
				if ($AgreementUrlFromClip -eq $AgreementUrlFromList) {
					#Explicit Approve - URL is present and matches.
					$AgreementAccept = "+!"
				} else {
					#Explicit mismatch - URL is present and does not match, or URL is missing.
					$AgreementAccept = "-!"
					if (!$WhatIf) {
						Reply-ToPR -PR $PR -CannedMessage AgreementMismatch -UserInput $AgreementUrlFromList -Silent
					}
				}
			} else {
				$AgreementAccept = "+"
				#Implicit Approve - your AgreementsUrl is in another file. Can't modify what isn't there. 
			}
				Write-Host -nonewline -f $matchColor "$AgreementAccept | "
				$matchColor = $validColor








			if (($PRtitle -notmatch "Automatic deletion") -AND 
			($PRtitle -notmatch "Delete") -AND 
			($PRtitle -notmatch "Remove") -AND 
			($AgreementAccept -notmatch "[+]")) {

				$WordFilterMatch = $WordFilterList | ForEach-Object {($Clip -match $_) -notmatch "Url" -notmatch "Agreement"}

				if ($WordFilterMatch) {
					$WordFilter = "-!"
					$Approve = "-!"
					$matchColor = $invalidColor
						if (!$WhatIf) {
						Reply-ToPR -PR $PR -CannedMessage WordFilter -UserInput $WordFilterMatch -Silent
					}
				}
			}
				Write-Host -nonewline -f $matchColor "$WordFilter | "
				$matchColor = $validColor





				
				if ($null -ne $WinGetOutput) {
					if (($PRvMan -ne "N") -AND 
					($PRtitle -notmatch (($DisplayVersionExceptionList) -join " ")) -AND 
					($PRtitle -notmatch "Automatic deletion") -AND 
					($PRtitle -notmatch "Delete") -AND 
					($PRtitle -notmatch "Remove")) {
						$DisplayVersion = Get-YamlValue DisplayVersion -clip $clip
						$DeveloperIsAuthor = (((Get-YamlValue PackageIdentifier -clip $clip) -split ".") -eq $Submitter)
						$InstallerMatch = ($InstallerUrl -split "/") -match $Submitter

						if ($DisplayVersion) {
							if ($DisplayVersion -eq $prVersion) {
								$matchColor = $invalidColor
								$AnF = "-"
								if (!$WhatIf) {
									Reply-ToPR -PR $PR -CannedMessage AppsAndFeaturesMatch -UserInput $Submitter -Policy $Labels.NAF -Silent
									Add-PRToRecord -PR $PR -Action $Actions.Feedback -Title $PRtitle
								}
							}
						}
						
						# if (!($DeveloperIsAuthor)) {
							# if ($InstallerMatch) {
								# $matchColor = $invalidColor
								# $AnF = "-"
								# Reply-ToPR -PR $PR -CannedMessage InstallerMatchesSubmitter -UserInput $Submitter -Policy $Labels.NAF -Silent
								# Add-PRToRecord -PR $PR -Action $Actions.Feedback -Title $PRtitle
							# }
						# }
					}
				}
<# 
 #>
				Write-Host -nonewline -f $matchColor "$AnF | "
				$matchColor = $validColor




					if (($PRvMan -ne "N") -AND 
					($PRtitle -notmatch "Automatic deletion") -AND 
					($PRtitle -notmatch "Delete") -AND 
					($PRtitle -notmatch "Remove")) {
					try {
						if ([bool]($clip -match "InstallerUrl")) {
							$InstallerUrl = Get-YamlValue InstallerUrl -clip $clip
							#write-host "InstallerUrl: $InstallerUrl $installerMatches prVersion: -PR $PRVersion" -f "blue"
							$installerMatches = [bool]($InstallerUrl | Select-String $PRVersion)
							if (!($installerMatches)) {
								#Matches when the dots are removed from semantec versions in the URL.
								$installerMatches2 = [bool]($InstallerUrl | Select-String ($prVersion -replace "[.]",""))
								if (!($installerMatches2)) {
									$matchColor = $invalidColor
									$InstVer = "-"
								}
							}
						}
					} catch {
						$matchColor = $invalidColor
						$InstVer = "-"
					}; #end try
				}; #end if PRvMan

				try {
					if (($prVersion = Get-YamlValue PackageVersion $clip) -match " ") {
						$matchColor = $invalidColor
						$InstVer = "-!"
					}
				}catch{
					$null = (Get-Process) #This section intentionally left blank.
				}

				Write-Host -nonewline -f $matchColor "$InstVer | "
				$matchColor = $validColor





				if (($PRvMan -ne "N") -AND 
				(($PRtitle -match "Automatic deletion") -OR 
				($PRtitle -match "Delete") -OR 
				($PRtitle -match "Remove"))) {#Removal PR
					#$Versions = 
					$NumVersions = ($WinGetOutput.AvailableVersions | sort).count
					if (($prVersion -eq $ManifestVersion) -OR ($NumVersions -eq 1)) {
						$matchColor = $invalidColor
						if (!$WhatIf) {
							Reply-ToPR -PR $PR -CannedMessage VersionCount -UserInput $Submitter -Silent -Policy "[Policy] $($Labels.NAF)`n[Policy] $($Labels.HVL)" -Output Silent
							Add-PRToRecord -PR $PR -Action $Actions.Feedback -Title $PRtitle
							$NumVersions = "L"
						}
					}
				} else {#Addition PR
					$GLD = (Get-ListingDiff $clip | Where-Object {$_.SideIndicator -eq "<="}).installer.yaml #Ignores when a PR adds files that didn't exist before.
					if ($null -ne $GLD) {
						if ($GLD -eq "Error") {
							$ListingDiff = "E"
							$matchColor = $invalidColor
						} else {
							$ListingDiff = "-!"
							$matchColor = $cautionColor
							if (!$WhatIf) {
								Reply-ToPR -PR $PR -CannedMessage ListingDiff -UserInput $GLD -Silent
								Invoke-GitHubPRRequest -PR $PR -Method POST -Type comments -Data "[Policy] $Labels.NAF" -Output Silent
								Add-PRToRecord -PR $PR -Action $Actions.Feedback -Title $PRtitle
							}#if Whatif
						}#end if GLD
					}#end if null
				}#end if PRvMan
				Write-Host -nonewline -f $matchColor "$ListingDiff | "
				Write-Host -nonewline -f $matchColor "$NumVersions | "
				$matchColor = $validColor





				if ($PRvMan -ne "N") {
					if ($null -eq $PRVersion -or "" -eq $PRVersion) {
						$noRecord = $True
						$PRvMan = "Error:prVersion"
						$matchColor = $invalidColor
					} elseif ($ManifestVersion -eq "Unknown") {
						$noRecord = $True
						$PRvMan = "Error:ManifestVersion"
						$matchColor = $invalidColor
					} elseif ($null -eq $ManifestVersion) {
						$noRecord = $True
						$PRvMan = $WinGetOutput
						$matchColor = $invalidColor
					} elseif ($prVersion -gt $ManifestVersion) {
						$PRvMan = $ManifestVersion.toString()
					} elseif ($prVersion -lt $ManifestVersion) {
						$PRvMan = $ManifestVersion.toString()
						$matchColor = $cautionColor
					} elseif ($prVersion -eq $ManifestVersion) {
						$PRvMan = "="
					} else {
						$noRecord = $True
						$PRvMan = $WinGetOutput
					};
				};


				if (($Approve -eq "-!") -or 
				($Auth -eq "-!") -or 
				($AnF -eq "-") -or 
				($InstVer -eq "-!") -or 
				($prAuth -eq "-!") -or 
				($Review -ne "R") -or 
				($ListingDiff -eq "-!") -or 
				($NumVersions -eq 1) -or 
				($NumVersions -eq "L") -or 
				($WordFilter -eq "-!") -or 
				($AgreementAccept -eq "-!") -or 
				($PRvMan -eq "N")) {
				#-or ($PRvMan -match "^Error")
					$matchColor = $cautionColor
					$Approve = "-!"
					$noRecord = $True
				}
				if ($WhatIf) {
					$Approve += "W"
				} 

				$PRvMan = Get-PadRight $PRvMan 14
				Write-Host -nonewline -f $matchColor "$PRvMan | "
				$matchColor = $validColor





				if ($PrePipeline -eq $false) {
					if ($Approve -eq "+") {
						if (!$WhatIf) {
							$Approve = Approve-PR -PR $PR
							Add-PRToRecord -PR $PR -Action $Actions.Approved -Title $PRtitle
						}
					}
				}

				Write-Host -nonewline -f $matchColor "$Approve | "
				Write-Host -f $matchColor ""

				$oldclip = $PRtitle
			}; #end if Compare-Object
		}; #end if PRtitle
		Start-Sleep 1
	}; #end while Count
	$Count--
}; #end function

Function Get-RunPRWatchAutomation {
	param(
		$SleepDuration = 5,
		$Preset = "Approval2",
		$Results = (Get-SearchGitHub -Preset $Preset).number
	)
	Write-Output "$(Get-Date -Format T) Starting $Preset with $($Results.length) Results"
	$Results | %{
		write-output "$(Get-Date): $_";
		Get-PRManifest -PR $_ | clip; 
		sleep $SleepDuration
	}
	Write-Output "$(Get-Date -Format T) Completing $Preset with $($Results.length) Results"
}

#Third tab
Function Get-WorkSearch {
	param(
		$PresetList = @("ToWork"),#Approval","
		$Days = 7
	)
	Foreach ($Preset in $PresetList) {
		$Page = 1
		While ($true) {
			$line = 0
			$PRs = (Get-SearchGitHub -Preset $Preset -Page $Page -NoLabels -nBMM) 
			Write-Output "$(Get-Date -f T) $Preset Page $Page beginning with $Count Results"
			$PRs = $PRs | where {$_.labels} | where {$_.number -notin (Get-Status).pr} 
			
			Foreach ($FullPR in $PRs) {
				$PR = $FullPR.number
				Get-TrackerProgress -PR $PR $MyInvocation.MyCommand $line $PRs.length
				$line++
				if ($Labels.HVL -notin $FullPR.labels.name) {
					if (($FullPR.title -match "Remove") -OR 
					($FullPR.title -match "Delete") -OR 
					($FullPR.title -match "Automatic deletion")){
						Get-GitHubPreset CheckInstaller -PR $PR
					}
				}
				$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content)
				if ($Preset -eq "Approval"){
					if (Get-NonstandardPRComments -PR $PR -comments $Comments.body){
						Open-PRInBrowser -PR $PR
					} else {
						Open-PRInBrowser -PR $PR -FIles
					}
				} elseif ($Preset -eq "Defender"){
					Get-GitHubPreset -Preset LabelAction -PR $PR
				} else {#ToWork etc
					$Comments = ($Comments | select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
					$State = (Get-PRStateFromComments -PR $PR -Comments $Comments)
					$LastState = $State[-1]
					if ($LastState.event -eq "DefenderFail") { 
						Get-PRLabelAction -PR $PR
					} elseif ($LastState.event -eq "LabelAction") { 
						Get-GitHubPreset -Preset LabelAction -PR $PR
						Open-PRInBrowser -PR $PR
					} else {
						if ($Comments[-1].UserName -ne $GitHubUserName) {
							if ($LastState.event -eq "PreValidation") { 
								Get-GitHubPreset -Preset LabelAction -PR $PR
							}
							Open-PRInBrowser -PR $PR
						}
					}#end if LastCommenter
				}#end if Preset
			}#end foreach FullPR
			Read-Host "$(Get-Date -f T) $Preset Page $Page complete with $Count Results - press ENTER to continue..."
			$Page++
		}#end While Count
	}#end Foreach Preset
	Write-Progress -Activity $MyInvocation.MyCommand -Completed
}#end Get-WorkSearch

#Automation tools
Function Get-GitHubPreset {
	param(
		[ValidateSet("Approved","AutomationBlock","BadPR","Blocking","CheckInstaller","Closed","Completed","DefenderFail","DriverInstall","Duplicate","Feedback","IdleMode","IEDSMode","InstallerNotSilent","InstallerMissing","LabelAction","ManuallyValidated","MergeConflicts","NetworkBlocker","NoInstallerChange","OneManifestPerPR","PRNoYamlFiles","PackageUrl","Paths","PossibleDuplicate","Project","RestrictedSubmitter","ResetApproval","Retry","Squash","Timeclock","Validating","VedantResetPR","WorkSearch","Waiver")][string]$Preset,
		$PR = (Get-Clipboard),
		$CannedMessage = $Preset,
		$UserInput,
		[Switch]$Force,
		$out = ""
	)
	if (($Preset -eq "GitHubStatus") -OR
		($Preset -eq "IdleMode") -OR
		($Preset -eq "IEDSMode") -OR
		($Preset -eq "Timeclock") -OR
		($Preset -eq "Validating") -OR
		($Preset -eq "WorkSearch")) {
		$Force = $True
		$out += $Preset;
	}

	if (($PR.ToString().length -eq 6) -OR $Force) {
		Switch ($Preset) {
			$Actions.Approved {
				$out += Approve-PR -PR $PR; 
				Add-PRToRecord -PR $PR -Action $Preset
			}
			"AutomationBlock" {
				Add-PRToRecord -PR $PR -Action $Actions.Blocking
				$out += Reply-ToPR -PR $PR -CannedMessage AutomationBlock -Policy $Labels.NB 
			}
			$Actions.Blocking {
				Add-PRToRecord -PR $PR -Action $Actions.Blocking
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type comments -Data "[Policy] $($Labels.NB)"
			}
			"CheckInstaller" {
				$Pull = (Invoke-GitHubPRRequest -PR $PR -Type files -Output content -JSON)
				$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[0] -JSON).content))
				$Url = (Get-YamlValue -StringName InstallerUrl -clip $PullInstallerContents)
				$out = ""
				try {
					$InstallerStatus = Check-PRInstallerStatusInnerWrapper $Url
					$out = "Status Code: $InstallerStatus"
				}catch{
					$out = $error[0].Exception.Message
				}
				$Body = "URL: $Url `n"+$out + "`n`n(Automated message - build $build)"
				#If ($Body -match "Response status code does not indicate success") {
					#$out += Get-GitHubPreset InstallerMissing -PR $PR 
				#} #Need this to only take action on new PRs, not removal PRs.
				$out = $out += Invoke-GitHubPRRequest -PR $PR -Method Post -Type comments -Data $Body -Output StatusDescription 
			}
			"Completed" {
				$out += Reply-ToPR -PR $PR -Body "This package installs and launches normally in a Windows 10 VM." -Policy $Labels.MV
			}
			$Actions.Closed {
				if ($UserInput) {
					Add-PRToRecord -PR $PR -Action $Preset
					$out += Invoke-GitHubPRRequest -PR $PR -Type comments -Output StatusDescription -Method POST -Data "Close with reason: $UserInput;"
				} else {
					Write-Output "-UserInput needed to use preset $preset"
				}
			}
			"DefenderFail" {
				Add-PRToRecord -PR $PR -Action $Actions.Blocking
				$out += Get-CannedMessage -Response DefenderFail -NoClip -NotAutomated
				#$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy "Needs-Attention`n[Policy] $($Labels.VDE)"
			}
			"DriverInstall" {
				Add-PRToRecord -PR $PR -Action $Actions.Blocking
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.DI
			}
			"Duplicate" {
				if ($UserInput -match "[0-9]{5,6}") {
					Get-GitHubPreset -Preset Closed -PR $PR -UserInput "Duplicate of #$UserInput"
				} else {
					Write-Output "-UserInput PRNumber needed to close as duplicate."
				}
			}
			$Actions.Feedback {
				Add-PRToRecord -PR $PR -Action $Preset
				if ($UserInput) {
					$out += Reply-ToPR -PR $PR -Body $UserInput -Policy $Labels.NAF
				} else {
					Write-Output "-UserInput needed to use preset $preset"
				}
			}
			"GitHubStatus" {
				return (Invoke-GitHubRequest -Uri https://www.githubstatus.com/api/v2/summary.json -JSON) | Select-Object @{n="Status";e={$_.incidents[0].status}},@{n="Message";e={$_.incidents[0].name+" ("+$_.incidents.count+")"}}
				#$out += $Preset; 
			}
			"IEDSMode" {
				Get-TrackerVMSetMode IEDS
			}
			"IdleMode" {
				Get-TrackerVMSetMode Idle
			}
			"InstallerNotSilent" {
				Add-PRToRecord -PR $PR -Action $Actions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.NAF
			}
			"InstallerMissing" {
				Add-PRToRecord -PR $PR -Action $Actions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.NAF
			}
			"LabelAction" {
				Get-PRLabelAction -PR $PR
			}
			"ManuallyValidated" {
				$out += Reply-ToPR -PR $PR -Body "Completing validation." -Policy $Labels.MV 
			}
			"MergeConflicts" {
				Get-GitHubPreset -Preset Closed -PR $PR -UserInput "Merge Conflicts"
			}
			"NetworkBlocker" {
				Write-Output "Use AutomationBlock instead."
			}
			"NoInstallerChange" {
				$out += Reply-ToPR -PR $PR -Body "This PR doesn't modify any of the `InstallerUrl` nor `InstallerSha256` fields." -Policy $Labels.MV 
			}
			"OneManifestPerPR" {
				Add-PRToRecord -PR $PR -Action $Actions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.NAF
				Get-AddPRLabel -PR $PR -Label $Labels.BI
			}
			"PRNoYamlFiles" {
				Add-PRToRecord -PR $PR -Action $Actions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.NAF
				Get-GitHubPreset -Preset MergeConflicts -PR $PR 
			}
			"PackageUrl" {
				Add-PRToRecord -PR $PR -Action $Actions.Feedback
				$out += Reply-ToPR -PR $PR -CannedMessage $Preset -Policy $Labels.NAF
			}
			"PossibleDuplicate" {
				$Pull = (Invoke-GitHubPRRequest -PR $PR -Type files -Output content -JSON)
				$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[0] -JSON).content))
				$Url = (Get-YamlValue -StringName InstallerUrl -clip $PullInstallerContents)
				$PackageIdentifier = (Get-YamlValue -StringName PackageIdentifier -clip $PullInstallerContents)
				$Version = (Find-WinGetPackage $PackageIdentifier | where {$_.ID -eq $PackageIdentifier}).Version
				$out = ($PullInstallerContents -match $Version)
				$UserInput = $out | where {$_ -match "http"} | where {$_ -notmatch "json"} 
				if ($UserInput) {
					$UserInput = "InstallerUrl contains Manifest version instead of PR version:`n"+$UserInput + "`n`n(Automated message - build $build)"
					$out += Reply-ToPR -PR $PR -Body $UserInput -Policy $Labels.NAF
					Add-PRToRecord -PR $PR -Action Feedback
				}
			}
			"Project" {
				Add-PRToRecord -PR $PR -Action $Preset
			}
			"RestrictedSubmitter" {
				Get-GitHubPreset -Preset Closed -PR $PR -UserInput "Restricted Submitter"
			}
			"ResetApproval" {
				$out += Reply-ToPR -PR $PR -Body "Reset approval workflow." -Policy "Reset Feedback `n[Policy] $($Labels.VC) `n[Policy] $($Actions.Approved)"			}
			"Retry" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += Get-RetryPR -PR $PR
			}
			"Squash" {
				Add-PRToRecord -PR $PR -Action $Preset
			}
			"Timeclock" {
				Get-TimeclockSet
			}
			"Validating" {
				Get-TrackerVMSetMode Validating
				$PR = ""
			}
			"Waiver" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += Add-Waiver -PR $PR; 
			}
			"WorkSearch" {
				Get-WorkSearch
			}
		}
	} else {
		$out += "Error: $($PR[0..10])"
	}
	Write-Output "PR $($PR): $out"
}

Function Get-PRLabelAction { #Soothing label action.
	param(
	[int]$PR,
	$PRLabels = ((Invoke-GitHubPRRequest -PR $PR -Type labels -Output content -JSON).name),
	$PRLabelActions = (Get-Content $LabelActionFile | ConvertFrom-Csv)
	)
	Write-Output "PR $PR has labels $PRLabels"
	if ($PRLabels -contains $Labels.VDE) {
		$PRState = Get-PRStateFromComments $PR
		if (($PRState | where {$_.event -eq "PreValidation"})[-1].created_at -lt (Get-Date).AddHours(-8)) {# -AND #Last Prevalidation was 8 hours ago.
		#($PRState | where {$_.event -eq "AutoValEnd"})[-1].created_at -lt (Get-Date).AddHours(-12)) { #Last Run was 18 hours ago.
			Get-GitHubPreset Retry -PR $PR
		}
	} else {
		
		Foreach ($Label in ($PRLabels -split " ")) {
		$Logset = ($PRLabelActions | ? {$_.Label -match $Label}).Logset -split "\|"
		$StringSet = ($PRLabelActions | ? {$_.Label -match $Label}).StringSet -split "\|"
		$LengthSet = ($PRLabelActions | ? {$_.Label -match $Label}).LengthSet -split "\|"
			Switch -wildcard ($Label) {
				$Labels.403 {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					Get-Autowaiver -PR $PR
				}
				$Labels.ANF {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.BVE {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -length 5
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					if ($UserInput -match $MagicStrings[3]) {
						#Get-GitHubPreset -PR $PR -Preset AutomationBlock
					}
				}
				$Labels.EAT {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 36 -SearchString $MagicStrings[0] -length 4
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					if ($UserInput -match $MagicStrings[3]) {
						Get-GitHubPreset -PR $PR -Preset AutomationBlock
					}
				}
				$Labels.EHM {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 44 -SearchString $MagicStrings[7] -length 3
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}					# write-host "a"
					# $UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet -Length $LengthSet
					# write-host "b"
					# if ($null -ne $UserInput) {
					# write-host "c"
						# Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					# write-host "d"
						# Get-UpdateHashInPR2 -PR $PR -Clip $UserInput
					# write-host "e"
					# }
					# write-host "f"
				}
				$Labels.EIA {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 53 -SearchString $MagicStrings[6] -length 5
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $MagicStrings[0] -Length 10 
					}
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 57 -SearchString $MagicStrings[0] -Length 10 
					}
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $MagicStrings[0] -Length 10 
					}
					if ($UserInput) {
						$UserInput = Get-AutomatedErrorAnalysis $UserInput
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
						Get-GitHubPreset -PR $PR -Preset CheckInstaller
					}
				}
				$Labels.HVF {
					Get-AutoValLog -PR $PR
				}
				$Labels.HVL {
					Approve-PR -PR $PR
				}
				$Labels.HVR {
					Approve-PR -PR $PR
				}
				$Labels.IE {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($UserInput) {
						if (($MagicStrings[5] -in $UserInput) -OR ("Server Unavailable" -in $UserInput)) {
							Get-GitHubPreset -PR $PR Retry
						}
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.IEDS {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Labels.IEM {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 15 -SearchString $MagicStrings[1]
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 30 -SearchString $MagicStrings[13]
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $MagicStrings[4] -length 7
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 39 -SearchString $MagicStrings[4] -length 7
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 46 -SearchString $MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 47 -SearchString $MagicStrings[9] -MatchOffset -3 -Length 4
					}
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
						if ($UserInput -match "Sequence contains no elements") {#Reindex fixes this.
							Reply-ToPR -PR $PR -CannedMessage SequenceNoElements
							$PRtitle = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title)
							if (($PRtitle -match "Automatic deletion") -OR ($PRtitle -match "Remove")) {
								Get-GitHubPreset -Preset Completed -PR $PR
							}
						}
					}
				}
				$Labels.IEU {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $MagicStrings[1]
					if ($UserInput) {
						if ($MagicStrings[5] -in $UserInput) {
							Get-GitHubPreset -PR $PR Retry
						}
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.LVR {
					Approve-PR -PR $PR
				}
				$Labels.MIVE {
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.MMC {
					Get-VerifyMMC -PR $PR
				}
				$Labels.MVE {#One of these is VER.
					$UserInput = Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.MVE {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $MagicStrings[2]
					if ($null -eq $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 42 -SearchString $MagicStrings[1]
					}
					if ($null -ne $UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.NMM {
					Approve-PR -PR $PR
					Get-MergePR -PR $PR
				}
				$Labels.NP {
					if ((($PRLabels -join " ") -notmatch $Labels.MA)) {
						Add-PRToQueue -PR $PR
					}
				}
				$Labels.PD {
					Get-DuplicateCheck -PR $PR
				}
				$Labels.PRE {
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 47 -SearchString $MagicStrings[12] -Length 2
					}
					if ($null -match $UserInput) {
						$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 33 -SearchString $MagicStrings[12] -Length 2
					}
					$UserInput += Get-LogFromCommitFile -PR $PR -LogNumbers $LogSet -StringNumbers $StringSet

					if ($UserInput -match "The pull request contains more than one manifest") {
						Get-GitHubPreset -Preset OneManifestPerPR -PR $PR
					}
					if ($UserInput -match "The pull request doesn't include any manifest files yaml") {
						Get-GitHubPreset -Preset PRNoYamlFiles -PR $PR
					}
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.UVE {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 32 -SearchString "Validation result: Failed"
					Get-GitHubPreset -PR $PR -Preset CheckInstaller
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
					Get-Autowaiver -PR $PR
				}
				$Labels.VC {
				}
				$Labels.VD {
					Get-Autowaiver -PR $PR
				}
				$Labels.VEE {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Labels.VIE {
					Get-AutoValLog -PR $PR
					Get-Autowaiver -PR $PR
				}
				$Labels.VMD {
					$UserInput = Get-LineFromBuildResult -PR $PR -LogNumber 25 -SearchString $MagicStrings[1]
					if ($UserInput) {
						Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
					}
				}
				$Labels.VMC {
				}
				$Labels.VNE {
 					Get-Autowaiver -PR $PR
<#
 					$Title = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title);
					foreach ($Waiver in (Get-ValidationData -Property AutoWaiverLabel)) {
						if ($Title -match $Waiver.PackageIdentifier) {
							Get-GitHubPreset -PR $PR Waiver
						}
					}
 #>
				}
				$Labels.VSE {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Labels.VUF {
					Get-AutoValLog -PR $PR
					Add-PRToQueue -PR $PR
				}
				$Labels.VUE {
					Get-Autowaiver -PR $PR
				}
				$Labels.VUU {
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
		[console]::beep(500,250);[console]::beep(500,250);[console]::beep(500,250) #Beep 3x to alert the PC user.
		$Host.UI.RawUI.WindowTitle = "Periodic Run"
		
		#Check for yesterday's report and create if missing. 
		$Month = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month)
		md "C:\ManVal\logs\$Month" -ErrorAction SilentlyContinue
		$Yesterday = (get-date).AddDays(-1)
		$YesterdayFormatted = (get-date $Yesterday -f MMddyy)
		$ReportName = "$logsFolder\$Month\$YesterdayFormatted-Report.txt"
		if (Get-Content $ReportName -ErrorAction SilentlyContinue) {
			Write-Host "Report for $YesterdayFormatted found."
		} else {
			Write-Host "Report for $YesterdayFormatted not found."
			Get-PRFullReport -Today $YesterdayFormatted
		}
		
		Get-StaleVMCheck
		
		$PresetList = ("Defender","Domain","Duplicate","HVR","IEDS","LVR","MMC","NMM","ToWork3","Approval","Approval2","VCMA")
		foreach ($Preset in $PresetList) {
			$Results = (Get-SearchGitHub -Preset $Preset -nBMM).number
			Write-Output "$(Get-Date -Format T) Starting $Preset with $($Results.length) Results"
			if ($Results) {
				switch ($Preset) {
					"Approval" {
						$Results = (Get-SearchGitHub Approval -NewPackages).number 
						$Results | %{Add-PRToQueue -PR $_}
					}
					"Approval2" {
						$Results | %{
							write-output "$(get-date): $_";
							Get-PRManifest -pr $_ | clip; 
							sleep 5
						}
					}
					"IEDS" {
						$Results | %{Add-PRToQueue -PR $_}
					}
					"VCMA" {
						$GitHubResults = Get-SearchGitHub VCMA
						$AnHourAgo = (get-date).AddHours(-1)
						$Results = ($GitHubResults | where {[TimeZone]::CurrentTimeZone.ToLocalTime($_.updated_at) -lt $AnHourAgo}).number 
						#Time, as a number, is always increasing. So the past is always less than the present, which is always less than the future.
						$Results | %{Approve-PR -PR $_;Get-MergePR -PR $_}
					}
					Default {
						$Results | %{Get-PRLabelAction -PR $_ }
					}
				}#end switch Preset
			}#end if Results12
			Write-Output "$(Get-Date -Format T) Completing $Preset with $($Results.length) Results"
		}#End for preset
		
		
		Write-Output "$(Get-Date -Format T) Starting PushMePRYou with $($PushMePRWho.count) Results"
		$PushMePRWho | %{write-host $_.Author;Get-PushMePRYou -Author $_.Author -MatchString $_.MatchString}
		Write-Output "$(Get-Date -Format T) Completing PushMePRYou with $($PushMePRWho.count) Results"
		if (([int](get-date -f mm) -eq 20) -OR ([int](get-date -f mm) -eq 50)) {
			sleep (60-(get-date -f ss))#Sleep out the minute.
		}
}

Function Get-StaleVMCheck {
	$VMStatus = gc $statusFile | convertfrom-csv
	$CheckVMStatus = ($VMStatus | where {$_.status -ne "Ready"})
	Write-Output "$(Get-Date -Format T) Starting stale VM check with $($CheckVMStatus.count) Results"
	foreach ($vm in $CheckVMStatus) {
		$PRState = Invoke-GitHubPRRequest -PR $VM.pr -Type "" -Output Content;
		$PRLabels = ((Invoke-GitHubPRRequest -PR $PR -Type "labels" -Output content -JSON).name)
		if (($PRState.state -ne "open") -OR
			(($PRLabels -join " ") -match $Labels.CR)){
			Get-TrackerVMSetStatus -Status Complete -VM $VM.vm
		}
	}
	Write-Output "$(Get-Date -Format T) Completing stale VM check with $($CheckVMStatus.count) Results"
}

Function Get-LogFromCommitFile {
	param(
		$PR,
		$LogNumbers,
		$StringNumbers,
		$Length,
		[switch]$WhatIf
	)
	Foreach ($Log in $LogNumbers) {
		$n = 0;
		if ($WhatIf) {
			write-host $log
		}
		while ($n -le ($StringNumbers.Count -1)) {
			if ($WhatIf) {
				write-host "n $n - string $($MagicStrings[($StringNumbers[$n])]) - UserInput $UserInput"
			}
			try {
				if ($WhatIf) {
					write-host "Get-LineFromBuildResult -PR $PR -LogNumber $Log -SearchString $($MagicStrings[$StringNumbers[$n]]) -Length $Length"
				} else {
					$UserInput += Get-LineFromBuildResult -PR $PR -LogNumber $Log -SearchString $MagicStrings[$StringNumbers[$n]] -Length $Length
				}
			} catch {}
			$n++
		}
	}

	if ($WhatIf) {
		write-host "return $UserInput"
	} else {
		return $UserInput
	}
}

Function Add-Waiver {
	param(
	$PR,
	$Labels = ((Invoke-GitHubPRRequest -PR $PR -Type "labels" -Output content -JSON).name)
	)
	#$actions = "Manual","Waiver","Approved"
	$actions = "Manual","Manual","Approved"
	Foreach ($Label in $Labels) {
		$Waiver = ""
		Switch ($Label) {
			$Labels.EAT {
				Get-GitHubPreset -Preset Completed -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.PT27 {
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.PT12 {
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.PT23 {
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.VC {
				Get-GitHubPreset -Preset Approved -PR $PR
				Add-PRToRecord -PR $PR -Action $actions[2]
			}
			$Labels.VD {
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.VEE {
				Add-PRToRecord -PR $PR -Action $actions[0]
				$Waiver = $Label
			}
			$Labels.403 {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VIE {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VNE {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VSE {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VUF {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VUE {
				Add-PRToRecord -PR $PR -Action $actions[1]
				$Waiver = $Label
			}
			$Labels.VR {
				Get-GitHubPreset -Preset Completed -PR $PR
				#Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Retry-1"
				Add-PRToRecord -PR $PR -Action $actions[0]
			}
			$Labels.IEDS {
				Get-GitHubPreset -Preset Completed -PR $PR
				#Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Retry-1"
				Add-PRToRecord -PR $PR -Action $actions[0]
			}
		}
		if ($Waiver -ne "") {
			$out = Get-CompletePR -PR $PR 
			Write-Output $out
		}; #end if Waiver
	}; #end Foreach Label
}; #end Add-Waiver

Function Get-SearchGitHub {
	param(
		[ValidateSet("Approval","Approval2","Autowaiver","Blocking","Defender","Domain","Duplicate","HVR","IEDS","LVR","MMC","NMM","None","ToWork","ToWork2","ToWork3","VCMA")][string]$Preset = "Approval",
		[Switch]$Browser,
		$Url = "https://api.github.com/search/issues?page=$Page&q=",
		$Author, #wingetbot
		$Commenter, #wingetbot
		$Title,
		$ExcludeTitle,
		[string]$Label, 
		$Page = 1,
		[int]$Days,
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
	$Base = $Base + "is:pr+"
	if (!($AllowClosedPRs)) {
		$Base +=  "is:open+"
	}
	$Base +=  "draft:false+"
	$Base +=  "sort:created-asc+"

	#Smaller blocks
	$date = Get-Date (Get-Date).AddDays(-$Days) -Format "yyyy-MM-dd"
	$Defender = "label:$($Labels.VDE)+"
	$HaventWorked = "-commenter:$($GitHubUserName)+"
	$HVR = "label:$($Labels.HVR)+"
	$IEDSLabel = "label:$($Labels.IEDS)+"
	$IEM = "label:$($Labels.IEM)+"
	$LVR = "label:$($Labels.LVR)+"
	$MA = "label:$($Labels.MA)+"
	$MMC = "label:$($Labels.MMC)+"
	$NA = "label:$($Labels.NA)+"
	$NAF = "label:$($Labels.NAF)+"
	$nBI = "-label:Blocking-Issue+"
	$nHW = "-label:Hardware+"
	$nIEDS = "-"+$IEDSLabel
	$nMA = "-"+$MA
	$NMM = "label:$($Labels.NMM)+"
	$nMMC = "-"+$MMC
	$nNA = "-"+$NA
	$nNP = "-label:$($Labels.NP)+"
	$nNRA = "-label:$($Labels.IOD)+"
	$nNRA = "-label:$($Labels.IOI)+"
	$nNRA = "-label:$($Labels.NRA)+"
	$nNSA = "-label:$($Labels.NSA)+"
	$NotPass = "-label:$($Labels.APP)+"#Hasn't psased pipelines
	$nVC = "-"+$VC #Not Completed
	$Recent = "updated:>$($date)+" 
	$VC = "label:$($Labels.VC)+"#Completed
	$VD = "label:$($Labels.VD)+"
	$VSA = "label:$($Labels.VSA)+"

	
	#Building block settings
	$Blocking = $nHW
	$Blocking += $nNSA
	$Blocking += "-label:$($Labels.AGR)+"
	$Blocking += "-label:$($Labels.DI)+"
	$Blocking += "-label:$($Labels.LBI)+"
	$Blocking += "-label:$($Labels.NB)+"
	$Blocking += "-label:$($Labels.PF)+"
	$Blocking += "-label:$($Labels.RB)+"
	$Blocking += "-label:$($Labels.SA)+"
	
	$Common = $nBI
	$Common = $Common + "-"+$IEM
	$Common = $Common + "-"+$Defender

	$Cna = $VC
	$Cna = $Cna+ $nMA
	
	$Review1 = "-label:$($Labels.CR)+"
	$Review1 += "-label:$($Labels.CLA)+"
	$Review1 += $nNRA

	$Review2 = "-"+$NA
	$Review2 = $Review2 + "-"+$NAF
	$Review2 = $Review2 + "-label:$($Labels.NR)+"
	
	$Approvable = "-label:$($Labels.VMC)+"
	$Approvable += "-label:$($Labels.VER)+"
	$Approvable += "-label:$($Labels.MIVE)+"
	$Approvable += "-label:$($Labels.PD)+"
	$Approvable += "-label:$($Labels.UF)+"
	
	$Workable += "-label:$($Labels.LVR)+"
	$Workable += "-label:$($Labels.HVR)+"
	$Workable += "-label:$($Labels.VMC)+"
	$Workable += "-label:$($Labels.BVE)+"
	$Workable += "-label:$($Labels.UF)+"
	$Workable += "-label:$($Labels.VCR)+"
	$Workable += "-label:$($Labels.VSS)+"

	$PolicyTests = "-label:Policy-Test-1.1+";
	$PolicyTests += "-label:$($Labels.PT12)+"
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
	$PolicyTests += "-label:$($Labels.PT23)+"
	$PolicyTests += "-label:Policy-Test-2.4+";
	$PolicyTests += "-label:Policy-Test-2.5+";
	$PolicyTests += "-label:Policy-Test-2.6+";
	$PolicyTests += "-label:$($Labels.PT27)+"
	$PolicyTests += "-label:Policy-Test-2.8+";
	$PolicyTests += "-label:Policy-Test-2.9+";
	$PolicyTests += "-label:Policy-Test-2.10+";
	$PolicyTests += "-label:Policy-Test-2.11+";
	$PolicyTests += "-label:Policy-Test-2.12+";
	
	$Automatable = "-label:WSL+";
	$Automatable = "-label:$($Labels.UVE)+"
	$Automatable = "-label:$($Labels.VUE)+"
	$Automatable = "-label:$($Labels.OUF)+"
	$Automatable = "-label:$($Labels.VHE)+"
	$Automatable = "-label:$($Labels.403)+"
	$Automatable = "-label:$($Labels.404)+"
	$Automatable = "-label:$($Labels.ANA)+"
	$Automatable = "-label:$($Labels.HW)+"
	$Automatable = "-label:$($Labels.PRE)+"
	$Automatable = "-label:$($Labels.MVE)+"
	$Automatable = "-label:$($Labels.EHM)+"
	$Automatable = "-label:$($Labels.ANF)+"
	$Automatable = "-label:$($Labels.EIA)+"
	$Automatable = "-label:$($Labels.VC)+"
	$Automatable += "-"+$VD;
	
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
		$Url += "label:$($Labels.BMM)+"
	}
	if ($nBMM) {
		$Url += "-label:$($Labels.BMM)+"
	}	
	switch ($Preset) {
		"Approval"{
			$Url += $Cna
			$Url += $Set2 #Blocking + Common + Review1 + Review2
			$Url += $Approvable
			$Url += $Workable;
			$Url += $nMMC;
		}
		"Approval2"{
			$Url += $Cna
			$Url += $nNP
			$Url += $Set2 #Blocking + Common + Review1 + Review2
			$Url += $Approvable
			$Url += $Workable;
			$Url += $nMMC;
		}
		"Defender"{
			$Url += $Defender
		}
		"Domain"{
			$Url += "label:$($Labels.VD)+"
		}
		"Duplicate"{	
			$Url += "label:"+$Labels.PD+"+";#dupe
			$Url += $nNRA
		}
		"Autowaiver"{
			$Url += $Set1
			$Url += $Workable
			$Url += $nIEDS 
			$Url += $nVC
			$Url += "label:$($Labels.EHM)+"
			$Url += "label:$($Labels.MIVE)+"
			$Url += "label:$($Labels.MVE)+"
			$Url += "label:$($Labels.VEE)+"
			$Url += "label:$($Labels.VNE)+"
			$Url += "label:$($Labels.VIE)+"
			$Url += "label:$($Labels.VSE)+"
			$Url += "label:$($Labels.VUF)+"
			$Url += "label:$($Labels.ANF)+"
			$Url += $nBI
			$Url += $nIOD
			$Url += $nIOI
		}
		"IEDS" {
			$Url += $IEDSLabel
			$Url += $nBI
			$Url += $Blocking
			$Url += $NotPass
			$Url += $nVC
		}
		"HVR"{
			$date = Get-Date (Get-Date).AddDays(-7) -Format "yyyy-MM-dd"
			$createdDate = "created:<$($date)+" 
			$Url += $createdDate;
			$Url += $HVR;
		}
		"LVR"{
			$date = Get-Date (Get-Date).AddDays(-7) -Format "yyyy-MM-dd"
			$createdDate = "created:<$($date)+" 
			$Url += $createdDate;
			$Url += $LVR;
		}
		"MMC"{
			$Url += $MMC;
		}
		"NMM"{
			$Url += $NMM;
		}
		"None"{
		}
		"ToWork"{
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $Workable;
			#$Url += $Workable
		}
		"ToWork2"{
			$Url += $HaventWorked
			$Url += "-"+$Defender
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $nVC
		}
		"ToWork3"{
			$Url += $HaventWorked
			$Url += "-"+$Defender
			$Url += $Set1 #Blocking + Common + Review1
			$Url += $nVC
			$Url += $nMA
			$Url += $nNA
		}
		"VCMA"{
			#$date = Get-Date (Get-Date).AddHours(-1) -Format "yyyy-MM-dd"
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
		#$Response = $Response | ? {!(($_.labels.name -match $Labels.MA) -AND ($_.labels.name -match "Needs-Attention"))}
		if ($ExcludeTitle) {
			$Response = $Response | ? {$_.title -notmatch $ExcludeTitle}
		}
		if (!($NoLabels)) {
			$Response = $Response | where {$_.labels}
		}
		return $Response
	}
}

Function Get-CannedMessage {
	param(
		[ValidateSet("AgreementMismatch","AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","AppsAndFeaturesMatch","DriverInstall","DefenderFail","HashFailRegen","InstallerFail","InstallerMatchesSubmitter","InstallerMissing","InstallerNotSilent","NormalInstall","InstallerUrlBad","ListingDiff","ManValEnd","ManifestVersion","MergeFail","NoCause","NoExe","NoRecentActivity","NotGoodFit","OneManifestPerPR","Only64bit","PackageFail","PackageUrl","Paths","PendingAttendedInstaller","PolicyWrapper","PRNoYamlFiles","RemoveAsk","SequenceNoElements","Unattended","Unavailable","UrlBad","VersionCount","WhatIsIEDS","WordFilter")]
		[string]$Response,
		$UserInput=(Get-Clipboard),
		[switch]$NoClip,
		[switch]$NotAutomated
	)
	[string]$Username = "@"+$UserInput.replace(" ","")+","
	switch ($Response) {
		"AgreementMismatch" {
			$out = "Hi $Username`n`nThis package uses Agreements, but this manifest's AgreementsUrl doesn't match the AgreementsUrl on file."
		}
		"AppsAndFeaturesNew" {
			$out = "Hi $Username`n`nThis manifest adds a `DisplayVersion` to the `AppsAndFeaturesEntries` that isn't present in previous manifest versions. This entry should be added to the previous versions, or removed from this version."
		}
		"AppsAndFeaturesMissing" {
			$out = "Hi $Username`n`nThis manifest removes the `DisplayVersion` from the `AppsAndFeaturesEntries`, which is present in previous manifest versions. This entry should be added to this version, to maintain version matching, and prevent the 'upgrade always available' situation with this package."
		}
		"AppsAndFeaturesMatch" {
			$out = "Hi $Username`n`nThis manifest uses the same values for `DisplayVersion` and `PackageVersion`. This is not recommended, and the `DisplayVersion` should be removed."
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
			$UserInput = $UserInput -join "`n"
			$UserInput = "Automatic Validation ended with:`n```````n $UserInput`n```````n"
			$out = Get-AutomatedErrorAnalysis $UserInput
		}
		"DriverInstall" {
			$out = "Hi $Username`n`nThe installation is unattended, but installs a driver which isn't unattended:`nUnfortunately, installer switches are not usually provided for this situation. Are you aware of an installer switch to have the driver silently install as well?"
		}
		"DefenderFail" {
			$out = "The package didn't pass a Defender or similar security scan. This might be a false positive and we can rescan tomorrow.."
		}
		"HashFailRegen" {
			$out = "Closing to regenerate with correct hash."
		}
		"InstallerFail" {
			$out = "Hi $Username`n`nThe installer did not complete:`n"
		}
		"InstallerMatchesSubmitter" {
			$out = "Submitter username detected in InstallerUrl, but not in PackageIdentifier. Verify not a forked repository."
		}
		"InstallerMissing" {
			$out = "Hi $Username`n`nHas the installer been removed?"
		}
		"InstallerNotSilent" {
			$out = "Hi $Username`n`nThe installation isn't unattended. Is there an installer switch to have the package install silently?"
		}
		"ListingDiff" {
			$out = "This PR omits these files that are present in the current manifest:`n> $UserInput"
		}
		"ManifestVersion" {
			$out = "Hi $Username`n`nWe don't often see the `1.0.0` manifest version anymore. Would it be possible to upgrade this to the [1.5.0]($GitHubBaseUrl/tree/master/doc/manifest/schema/1.5.0) version, possibly through a tool such as [WinGetCreate](https://learn.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example), [YAMLCreate]($GitHubBaseUrl/blob/master/Tools/YamlCreate.ps1), or [Komac](https://github.com/russellbanks/Komac)? "
		}
		"ManValEnd" {
			$UserInput = $UserInput -join "`n"
			$UserInput = "Manual Validation ended with:`n```````n$UserInput`n```````n"
			$out = Get-AutomatedErrorAnalysis $UserInput
		}
		"MergeFail" {
			$out = "Merging failed with:`n> $UserInput"
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
		"NormalInstall" {
			$out = "This package installs and launches normally in a Windows 10 VM."
		}
		"OneManifestPerPR" {
			$out = "Hi $Username`n`nWe have a limit of 1 manifest change, addition, or removal per PR. This PR modifies more than one PR. Can these changes be spread across multiple PRs?"
		}
		"Only64bit" {
			$out = "Hi $Username`n`nValidation failed on the x86 package, and x86 packages are validated on 32-bit OSes. So this might be a 64-bit package."
		}
		"PackageFail" {
			$out = "Hi $Username`n`nThe package installs normally, but fails to run:`n"
		}
		"PackageUrl" {
			$out = "Hi $Username`n`nCould you add a PackageUrl?"
		}
		"Paths" {
			$out = "Please update file name and path to match this change."
		}
		"PendingAttendedInstaller" {
			$out = "Pending:`n* https://github.com/microsoft/winget-cli/issues/910"
		}
		"PolicyWrapper" {
			$out = "<!--`n[Policy] $UserInput`n-->"
		}
		"PRNoYamlFiles" {
			$out = "Hi $Username`n`nThis error means that this PR diff Master had no output. In other words, it's like a merge conflict.`n>  The pull request doesn't include any manifest files yaml."
		}
		"RemoveAsk" {
			$out = "Hi $Username`n`nThis package installer is still available. Why should it be removed?"
		}
		"SequenceNoElements" {
			$out = "> Sequence contains no elements`n`n - This error means that this PR diff Master had no output. In other words, it's like a merge conflict."
		}
		"Unavailable" {
			$out = "Hi $Username`n`nThe installer isn't available from the publisher's website:"
		}
		"Unattended" {
			$out = "Hi $Username`n`nThe installation isn't unattended:`n`nIs there an installer switch to bypass this and have it install automatically?"
		}
		"UrlBad" {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
		}
		"VersionCount" {
			$out = "Hi $Username`n`nThis manifest has the highest version number for this package. Is it available from another location? (This might be in error if the version is switching from semantic to string, or string to semantic.)"
		}
		"WhatIsIEDS" {
			$out = "Hi $Username`n`nThe label `Internal-Error-Dynamic-Scan` is a blanket error for one of a number of internal pipeline errors or issues that occurred during the Dynamic Scan step of our validation process. It only indicates a pipeline issue and does not reflect on your package. Sorry for any confusion caused."
		}
		"WordFilter" {
			$out = "This manifest contains a term that is blocked:`n`n> $UserInput"
		}
	}
	if (!($NotAutomated)) {
		$out += "`n`n(Automated response - build $build.)"
	}
	if ($NoClip) {
		$out
	} else {
		$out |clip
	}
}

Function Get-AutomatedErrorAnalysis {
	param(
		$UserInput,
		$Spacer = " | ",
		$LineBreak = "`n"
	)

	#$UserSplit = $UserInput -replace "0x","" -replace "[^\w]"," " -split " "
	$UserSplit = $UserInput -replace "0x"," " -replace "\)"," " -split " "
	$UserSplit = $UserSplit | Sort-Object -Unique
	
	if ($UserInput -match "exit code" -OR 
	$UserInput -match "DeliveryOptimization error" -OR 
	$UserInput -match "Installer failed security check" -OR 
	$UserInput -match "Error information") {
		$ExitCodeTable = gc $ExitCodeFile | ConvertFrom-Csv
		$UserInput += "$LineBreak $LineBreak | Hex | Dec | Inverted Dec | Symbol | Description | $LineBreak | --- | --- | --- | --- | --- | $LineBreak"
		foreach ($ExitCode in $ExitCodeTable) {
			foreach ($Word in $UserSplit) {
				if (($Word -eq $ExitCode.Hex)  -OR ($Word -eq $ExitCode.Dec)  -OR ($Word -eq $ExitCode.InvDec) ) {
					$UserInput += $Spacer + $ExitCode.Hex + $Spacer + $ExitCode.Dec + $Spacer + $ExitCode.InvDec + $Spacer + $ExitCode.Symbol + $Spacer + $ExitCode.Description + $Spacer + $LineBreak
					}# end if word
				}# end foreach word
			}#end foreach exitcode
		}#end if userinput 
	$UserInput = $UserInput | Select-Object -Unique
	return $UserInput
}#end function 

Function Get-AutoValLog {
	#Needs $GitHubToken to be set up in your -PR $PROFILE or somewhere more secure. Needs permissions: workflow,
	param(
		$clip = (Get-Clipboard),
		$PR = ($clip -split "/" | Select-String $PRRegex ),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		[switch]$CleanoutDirectory,
		[switch]$WhatIf,
		[switch]$Force,
		[switch]$Silent,
		$notes = ""
	)
		$PRState = Get-PRStateFromComments $PR
		if ((!($PRState | where {$_.event -eq "AutoValEnd"})) -OR (($PRState | where {$_.event -eq "PreValidation"})[-1].created_at -gt ($PRState | where {$_.event -eq "AutoValEnd"})[-1].created_at) -OR ($Force)) { #Last Prevalidation was 8 hours ago.
			$DownloadSeconds = 8;
			$LowerOps = $true;
			$WaiverList = Get-ValidationData -Property AutoWaiverLabel
			#Get-Process *photosapp* | Stop-Process
			$BuildNumber = Get-BuildFromPR -PR $PR 
	
		if ($BuildNumber -gt 0) {
			$FileList = $null
			[int]$BackoffSeconds = 0
			
			while ($FileList -eq $null) {
				try {
					#This downloads to Windows default location, which has already been set to $DestinationPath
					Start-Process "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$BuildNumber/artifacts?artifactName=InstallationVerificationLogs&api-version=7.1&%24format=zip"
					if ($WhatIf) {
						write-host "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$BuildNumber/artifacts?artifactName=InstallationVerificationLogs&api-version=7.1&%24format=zip"
					}
					Start-Sleep $DownloadSeconds;
					[bool]$IsZipPath = (Test-Path $ZipPath)
					if (!$IsZipPath) {
						#if (!$Force) {
							$UserInput = "No logs."
							$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
							Write-Host $UserInput
							Continue;
						#}
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
						Continue;
					}
					$AddSeconds = Get-Random -min 1 -max 5
					$BackoffSeconds += $AddSeconds
					Write-Host "Can't access $DestinationPath or a subfolder. Backing off another $AddSeconds seconds, for $BackoffSeconds total seconds."
					sleep $BackoffSeconds
				}
			}
			
			[Array]$UserInput = $null
			foreach ($File in $filelist) {
				$UserInput += (Get-Content $File) -split "`n"
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
				write-host "File $File - UserInput $UserInput Length $($UserInput.Length)"
			}
			$UserInput = $UserInput -split "`n" | Select-Object -Unique;
			$UserInput = $UserInput -replace "Standard error: ",$null
			$UserReplace = $UserInput -replace "\\","\\" -replace "\[","\["-replace "\]","\]"-replace "\*","\*"-replace "\+","\+"

			if ($null -notmatch ($UserReplace)) {
				if (($UserInput -match "Installer failed security check") -OR ($UserInput -match "Operation did not complete successfully because the file contains a virus or potentially unwanted software")) {
					$LowerOps = $false
					#$UserInput = Get-AutomatedErrorAnalysis $UserInput
					write-host "DefenderFail - UserInput $UserInput"
				}
				if ($UserInput -match "SQL error or missing database") {
					Get-GitHubPreset Retry -PR $PR
						if (!($Silent)) {
							Write-Output "PR $PR - SQL error or missing database"
						}
					Open-PRInBrowser -PR $PR
				}

				$UserInput = $UserInput -split "`n"
				$UserInput = $UserInput -notmatch " success or error status`: 0"
				$UserInput = $UserInput -notmatch "``Windows Error Reporting``"
				$UserInput = $UserInput -notmatch "--- End of inner exception stack trace ---"
				$UserInput = $UserInput -notmatch "AppInstallerRepositoryCore"
				$UserInput = $UserInput -notmatch "api-ms-win-core-errorhandling"
				$UserInput = $UserInput -notmatch "appropriate application package"
				$UserInput = $UserInput -notmatch "2: 3: Error"
				$UserInput = $UserInput -notmatch "because the current user does not have that package installed"
				$UserInput = $UserInput -notmatch "Cannot create a file when that file already exists"
				$UserInput = $UserInput -notmatch "Could not create system restore point"
				$UserInput = $UserInput -notmatch "Dest filename"
				$UserInput = $UserInput -notmatch "ERROR: Signature Update failed"
				$UserInput = $UserInput -notmatch "Exception during executable launch operation System.InvalidOperationException: No process is associated with this object."
				$UserInput = $UserInput -notmatch "Exit code`: 0"
				$UserInput = $UserInput -notmatch "Failed to open available source: msstore"
				$UserInput = $UserInput -notmatch "ISWEBVIEW2INSTALLED"
				$UserInput = $UserInput -notmatch "MpCmdRun"
				$UserInput = $UserInput -notmatch "ResultException"
				$UserInput = $UserInput -notmatch "SchedNetFx"
				$UserInput = $UserInput -notmatch "Setting error JSON 1.0 fields"
				$UserInput = $UserInput -notmatch "Terminating context"
				$UserInput = $UserInput -notmatch "The process cannot access the file because it is being used by another process"
				$UserInput = $UserInput -notmatch "The FileSystemWatcher has detected an error System.IO.ErrorEventArgs"
				$UserInput = $UserInput -notmatch "ThrowIfExceptional"
				$UserInput = $UserInput -notmatch "Windows Installer installed the product"
				$UserInput = $UserInput -notmatch "with working directory 'D"
			}
			$UserReplace = $UserInput -replace "\\","\\" -replace "\[","\["-replace "\]","\]"-replace "\*","\*"-replace "\+","\+"

			if ($null -notmatch ($UserReplace)) {
				$UserInput = $UserInput | Select-Object -Unique

				$UserInput = $UserInput -replace "-",$null
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (A) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
				}


				if ($LowerOps -eq $true) {
					$SplitInput = ($UserInput -split "`n" )
					foreach ($input in $QueueInputs) {
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
					if(!(($UserInput -split "`n" ) -match $exitregex2)) { #4 digits bad
						if(($UserInput -split "`n" ) -match $exitregex) { #1-3 digits good
							if ($WhatIf) {
								Write-Host "WhatIf: Get-CompletePR -PR $PR"
							} else {
								Get-CompletePR -PR $PR
							}
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
					$UserInput = "No errors to post."
					$Title = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title);
					if ($WhatIf) {
						Write-Host "WhatIf: Reply-ToPR (B) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
						Write-Host "WhatIf: Get-CompletePR -PR $PR"
						Write-Host "WhatIf: Get-GitHubPreset -PR $PR Waiver"
					} else {
						$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
						Get-CompletePR -PR $PR
						foreach ($Waiver in $WaiverList) {
							if ($Title -match $Waiver.PackageIdentifier) {
								Get-GitHubPreset -PR $PR Waiver
							}#end if title
						}#end foreach waiver
					}
				}
			}
		} else {
			if (!($Silent)) {
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (C) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
					Write-Host "WhatIf: UserInput Length $($UserInput.Length)"
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
				}
				if ($WhatIf) {
					Write-Host "WhatIf: Reply-ToPR (D) -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd"
				} else {
					$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
				}
				$UserInput = "Build $BuildNumber not found."
				Write-Host $UserInput
				$out = Reply-ToPR -PR $PR -UserInput $UserInput -CannedMessage AutoValEnd
			}
		}
		return $out 
	}
}

Function Get-RandomIEDS {
	param(
		$VM = (Get-NextFreeVM),
		$IEDSPRs =(Get-SearchGitHub -Preset IEDS -nBMM),
		#$IEDSPRs =(Get-SearchGitHub -Preset ToWork3),
		$PR = ($IEDSPRs.number | where {$_ -notin (Get-Status).pr} | Get-Random),
		$PRData = (Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr" -JSON),
		$PRTitle = (($PRData.title -split " ")[2] | where {$_ -match "\."}),
		$File = 0,
		$ManifestType = "",
		$OldManifestType = "",
		$OldPackageIdentifier = ""
	)
	
	if ($VM -eq 0){
		Write-Host "No available $OS VMs";
		Get-PipelineVmGenerate -OS $OS;
		Add-PRToQueue -PR $PR;
	} else {
		Get-CommitFile -PR $PR -VM $VM -MatchName "" 
	}
}

Function Get-PRManifest {
	param(
		$PR,
		$File = 0,
		$ManifestType = "",
		$OldManifestType = "",
		$FooterHeader = "`n@@ -0,0 +0,0 @@`n",
		$CommitFile = (Get-CommitFile -PR $PR -MatchName ""),
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $CommitFile) -replace '"',''-replace "'",''),
		$PackageVersion = ((Get-YamlValue -StringName "PackageVersion" $CommitFile) -replace '"',''-replace "'",''),
		$Submitter = ((Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr" -JSON).user.login)
	)
	
	$out = "$PackageIdentifier version $PackageVersion #$PR`n"
	$out += "$Submitter wants to merge`n"
	$out += $FooterHeader
	$out += ($CommitFile -join "`n")
	$out += $FooterHeader
	return $out
}

#PR tools
#Add user to PR: Invoke-GitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
#Approve PR (needs work): Invoke-GitHubPRRequest -PR $PR -Method Post -Type reviews
Function Invoke-GitHubPRRequest {
	param(
		$PR,
		[ValidateSet("GET","DELETE","PATCH","POST","PUT")][string]$Method = "GET",
		[ValidateSet("assignees","comments","commits","files","labels","merge","reviews","")][string]$Type = "labels",
		[string]$Data,
		[ValidateSet("issues","pulls")][string]$Path = "issues",
		[ValidateSet("Content","Silent","StatusDescription")][string]$Output = "StatusDescription",
		[switch]$JSON,
		$prData = (Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr/commits" -JSON),
		$commit = (($prData.commit.url -split "/")[-1])
	)
	$Response = @{}
	$ResponseType = $Type
	$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"

	if (($Type -eq "") -OR ($Type -eq "files") -OR ($Type -eq "reviews")){
		$Path = "pulls"
		$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"
	} elseif ($Type -eq "comments") {
		$Response.body += $Data
	} elseif ($Type -eq "commits") {
		$uri = "$GitHubApiBaseUrl/$Type/$commit"
	} elseif ($Type -eq "merge") {
		$Path = "pulls"
	} elseif ($Type -eq "reviews") {
		$Path = "pulls"
		$Response.body = ""+$Data
		$Response.commit = $commit
		$Response.event = "APPROVE"
	} elseif ($Type -eq "") {
		#$Response.title = ""
		#$Response.body = ""
		$Response.state = "closed"
		$Response.base = "master"
	} else {
 		$Response.$ResponseType = @()
		$Response.$ResponseType += $Data
	}

	$uri = $uri -replace "/$",""

	if ($Method -eq "GET") {
		$out = Invoke-GitHubRequest -Method $Method -Uri $uri
	} else {
		[string]$Body = $Response | ConvertTo-Json
		$out = Invoke-GitHubRequest -Method $Method -Uri $uri -Body $Body
	}

	if (($JSON) -OR ($Output -eq "Content")) {
		if ($null -ne $out.$Output) {
			try {
				$out.$Output | ConvertFrom-Json
			}catch{
				return ("PR: $PR - Error: $($error[0].ToString()) - Url $uri - Body: $Body")
			}
		} elseif ($Output -eq "Silent") {
		} else {
			$out.$Output 
		}
	} else {
		return "!"#"PR: $PR - No output. Method: $Method - URI: $uri"
		#return ("PR: $PR - Error: $($error[0].ToString()) - Url $uri - Body: $Body")
	}
}

Function Approve-PR {
	param(
		$PR,
		[string]$Body = "",
		$prData = (Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr/commits" -JSON),
		$commit = (($prData.commit.url -split "/")[-1]),
		$uri = "$GitHubApiBaseUrl/pulls/$pr/reviews"
	)

	$Response = @{}
	$Response.body = $Body
	$Response.commit = $commit
	$Response.event = "APPROVE"
	[string]$Body = $Response | ConvertTo-Json

	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body 
	$out.StatusDescription
	Get-AddPRLabel -PR $PR -LabelName $Labels.MA
}

Function Get-ApproveBySearch {
	Param(
		[Parameter(mandatory=$True)][string]$Author,
		$Preset = "ToWork",
		$MatchText = 'Standardize formatting',
		$Results = (Get-SearchGitHub -Author $Author -Preset $Preset -NoLabels)
	)
	$Results = $Results | ? {$_.user.login -eq $Author -and $_.title -match $MatchText -and $_.labels.name -notcontains $Labels.MA -and $_.labels.name -notcontains $Labels.CR};
	$Results.number | % { write-host "$_ - " -nonewline;Approve-PR $_ };
}

Function Get-PRRange ([int]$firstPR,[int]$lastPR,[string]$Body,[string]$Preset) {
	$line = 0;$firstPR..$lastPR | %{
	if ($Preset -eq "closed") {
		Get-GitHubPreset -Preset $Preset -PR $_ -UserInput $Body
	} else {
		Reply-ToPR -PR $_ -Body $Body;
		Get-GitHubPreset -Preset $Preset -PR $_
	}
	Get-TrackerProgress -PR $_ $MyInvocation.MyCommand $line ($lastPR - $firstPR);$line++
}}

Function Get-AllPRsOnClipboard {
	param(
		$clip = (Get-Clipboard),
		$hash = "#",
		$br = "`n",
		$sp = " "
	)
	$out = @()
	($clip -replace $hash,($br+$hash) -split $br -split $sp | select-string $hash) -replace $hash,$null | %{$out += $_}
	return $out
}

Function Get-AllPRsOnClipboardPreset ([string]$Body,[string]$Preset) {
	$line = 0;
	Get-AllPRsOnClipboard | %{
		if ($Preset) {
			if ($Preset -eq "closed") {
				Get-GitHubPreset -Preset $Preset -PR $_ -UserInput $Body
			} else {
				Reply-ToPR -PR $_ -Body $Body;
				Get-GitHubPreset -Preset $Preset -PR $_
			}
		}
		Get-TrackerProgress -PR $_ $MyInvocation.MyCommand $line ($lastPR - $firstPR);$line++
	}
}

Function Get-AddPRLabel {
	param(
	[int]$PR,
	[string]$LabelName
	)
	(Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data $LabelName -Output Content).name
}

Function Get-RemovePRLabel {
	param(
	[int]$PR,
	[string]$LabelName
	)
	(Invoke-GitHubRequest -Uri "$GitHubApiBaseUrl/issues/$PR/labels/$LabelName" -Method DELETE).StatusDescription
}

function Get-CompletePR ([int]$PR){
	$PRLabels = (invoke-GitHubPRRequest -PR $PR -Type labels -Method GET -Output Content).name | 
	where {$_ -notmatch $Labels.APP} |
	where {$_ -notmatch $Labels.MMC} |
	where {$_ -notmatch $Labels.MA} | 
	where {$_ -notmatch $Labels.NM} | 
	where {$_ -notmatch $Labels.NP} | 
	where {$_ -notmatch $Labels.PD} | 
	where {$_ -notmatch $Labels.RET} | 
	where {$_ -notmatch $Labels.VC} 

	foreach ($label in $PRLabels) {
		Get-RemovePRLabel -PR $PR -Label $label
	}
	if (($PRLabels -join " ") -notmatch $Labels.VDE) {
		Get-AddPRLabel -PR $PR -LabelName $Labels.VC
	}
}

Function Get-MergePR {
	Param(
		$PR,
		$ShaNumber = (-1)
	)
	$sha = (Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr/commits" -JSON).sha
	if ($null -ne $sha) {
		if ($sha.gettype().name -eq "String") {
			$sha = $sha
		} else {
			$sha = $sha[$ShaNumber]
		}
	} else {
		write-host "SHA $sha not found (length $($sha.length)"
	}
	
	$out = ""
	$Data = Invoke-GitHubrequest -Uri "https://api.github.com/repos/microsoft/winget-pkgs/pulls/$pr/merge" -Method PUT -Body "{`"merge_method`":`"squash`",`"sha`":`"$sha`"}"
	if ($Data.Content) {
		$out = $Data.Content
	} else {
		$out = $Data
		#($Data[1..$Data.length] | convertfrom-json).message
	}
	
	$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content)
	if ($out -match "Error") {
		if ($Comments[-1].UserName -ne $GitHubUserName) {
			Reply-ToPR -PR $PR -UserInput $out -CannedMessage MergeFail
		}
	}
	$out
	
	Add-PRToRecord -PR $PR -Action Squash
	#invoke-GitHubprRequest -PR $PR -Method PUT -Type merge -Data "{`"merge_method`":`"squash`",`"sha`":`"$sha`"}"
}

Function Get-RetryPR {
	Param(
		$PR,
		$Command = "@wingetbot run"
	)
	Invoke-GitHubPRRequest -PR $PR -Type comments -Output StatusDescription -Method POST -Data $Command
}

function Get-PushMePRYou {
	Param(
		$Author = "Trenly",
		$MatchString = "Standardize formatting"
	)
	foreach ($Preset in ("Approval","ToWork")) {
		write-host "$($Preset): $(get-date)";
		$a = @();
		$a = Get-SearchGitHub -Author $Author -Preset $Preset -NoLabels;
		$a = $a | ? {$_.user.login -eq $Author -and $_.title -match $MatchString -and $_.labels.name -notcontains $Labels.MA};
		$a.number | % { 
			write-host "$_ - " -nonewline;
			Approve-PR $_ 
		};
	};

	$Preset = "Complete"
	write-host "$($Preset): $(get-date)";
}

Function Add-GitHubReviewComment {
	param(
		$PR,
		[string]$Comment = "",
		$Commit = (Invoke-GitHubPRRequest -PR $PR -Type commits -Output content -JSON),
		$commitID = $commit.sha,
		$Filename = $commit.files.filename,
		$Side = "RIGHT",
		$StartLine,
		$Line
	)
	if ($Filename.GetType().BaseType.Name -eq "Array") {
		$Filename = $Filename[0]
	}

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

	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body 
	$out.StatusDescription
}

Function Get-BuildFromPR {
	param(
		$PR,
		$content = (Invoke-GitHubPRRequest -PR $PR -Method GET -Type comments -Output Content),
		$href = ($content.body | where {$_ -match "Validation Pipeline Run"})
	)
	if ($href.gettype().basetype.name -eq "Array" ) {
		$href = $href[-1]
	}
	$PRbuild = (($href -split "=" -replace "\)")[1])
	return $PRbuild
}

Function Get-LineFromBuildResult {
	param(
		$PR,
		$PRbuild = (Get-BuildFromPR -PR $PR),
		$LogNumber = (36),
		$SearchString = "Specified hash doesn't match",
		$content = (Invoke-WebRequest "$ADOMSBaseUrl/$ADOMSGUID/_apis/build/builds/$PRbuild/logs/$LogNumber" -ProgressAction SilentlyContinue).content,
		$Log = ($content -join "" -split "`n"),
		$MatchOffset = (-1),
		$MatchLine = (($Log | Select-String -SimpleMatch $SearchString).LineNumber | where {$_ -gt 0}),
		$Length = 0,
		$output = @()
	)
	foreach ($Match in $MatchLine) {
		$output += ($Log[($Match + $MatchOffset)..($Match+$Length + $MatchOffset)])
	}
	return $output
}

Function Get-PRApproval {
	param(
		$Clip = (Get-Clipboard),
		[int]$PR = (($Clip -split "#")[1]),
		$PackageIdentifier = ((($clip -split ": ")[1] -split " ")[0]),
		$auth = (Get-ValidationData -Property PackageIdentifier -Match $PackageIdentifier -Exact).GitHubUserName,
		$Approver = (($auth -split "/" | Where-Object {$_ -notmatch "\("}) -join ", @"),
		[switch]$DemoMode
	)
	Reply-ToPR -PR $PR -UserInput $Approver -CannedMessage Approve -Policy $Labels.NR
}

Function Reply-ToPR {
	param(
		$PR,
		[string]$CannedMessage,
		[string]$UserInput = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login),
		[string]$Body = (Get-CannedMessage $CannedMessage -UserInput $UserInput -NoClip),
		[string]$Policy,
		[Switch]$Silent
	)
	if ($Policy) {
		$Body += "`n<!--`n[Policy] $Policy`n-->"
	}
	# If (($CannedMessage -eq "AutoValEnd") -OR ($CannedMessage -eq "ManValEnd")) {
		# $SharedError = Get-AutomatedErrorAnalysis $SharedError
	# }
	if ($Silent) {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output Silent
	} else {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output StatusDescription
	}
}

Function Get-NonstandardPRComments {
	param(
		$PR,
		$comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content).body
	)
	foreach ($StdComment in $StandardPRComments) {
		$comments = $comments | Where-Object {$_ -notmatch $StdComment}
	}
	return $comments
}

Function Get-PRStateFromComments {
	param(
		$PR = (Get-Clipboard),
		$PRComments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content | select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body),
		$PRStateData = ((Get-Content $PRStateDataFile) -replace "GitHubUserName",$GitHubUserName | ConvertFrom-Csv),
		[switch]$WhatIf
	)
	if ($WhatIf) {
		write-host "PR $PR - Comments $($PRComments.count)"
	}
	$Robots = @{}
	$Robots.Wingetbot = "wingetbot"
	$Robots.AzurePipelines = "azure-pipelines"
	$Robots.FabricBot = "microsoft-github-policy-service"
	
	$Run = @{}
	$Run.azp1 = "AzurePipelines run"
	$Run.azp2 = "azp run"
	$Run.wingetbot = "wingetbot run"
	
	$States = @{}
	$States.PreRun = "PreRun"
	$States.PreValidation = "PreValidation"
	$States.Running = "Running"
	$States.PreApproval = "PreApproval"
	$States.DefenderFail = "DefenderFail"
	$States.InstallerAvailable = "InstallerAvailable"
	$States.InstallerRemoved = "InstallerRemoved"
	$States.VersionParamMismatch = "VersionParamMismatch"
	$States.LabelAction = "LabelAction"
	$States.DomainReview = "DomainReview"
	$States.SequenceError = "SequenceError"
	$States.HighestVersionRemoval = "HighestVersionRemoval"
	$States.SQLMissingError = "SQLMissingError"
	$States.ChangesRequested = "ChangesRequested"
	$States.HashMismatch = "HashMismatch"
	$States.AutoValEnd = "AutoValEnd"
	$States.ManValEnd = "ManValEnd"
	$States.MergeConflicts = "MergeConflicts"
	$States.ValidationCompleted = "ValidationCompleted"
	$States.PublishSucceeded = "PublishSucceeded"
	
	$LabelActionComments = @{}
	$LabelActionComments.URLError = "The package manager bot determined there was an issue with one of the installers listed in the url field"
	$LabelActionComments.ValidationInstallationError = "The package manager bot determined there was an issue with installing the application correctly"
	$LabelActionComments.InternalError = "The pull request encountered an internal error and has been assigned to a developer to investigate"
	$LabelActionComments.ValidationUnattendedFailed = "this application failed to install without user input"
	$LabelActionComments.ManifestValidationError = "Please verify the manifest file is compliant with the package manager"
	

	$out = @()
	foreach ($PRComment in $PRComments) {
		$State = ""
		$PRComment.created_at = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($PRComment.created_at, 'Pacific Standard Time')
		if ($WhatIf) {
			write-host "PR $PR - created_at $($PRComment.created_at)"
		}
		
		if (($PRComment.body -match $Run.azp1) -OR
		($PRComment.body -match $Run.azp2) -OR
		($PRComment.body -match $Run.wingetbot)) {
		if ($WhatIf) {
			write-host "PR $PR - State $($States.PreValidation)"
		}
			$State = $States.PreValidation
		} elseif (($PRComment.UserName -eq $Robots.FabricBot) -AND (
		($PRComment.body -match $LabelActionComments.URLError) -OR
		($PRComment.body -match $LabelActionComments.ValidationInstallationError) -OR
		($PRComment.body -match $LabelActionComments.InternalError) -OR
		($PRComment.body -match $LabelActionComments.ValidationUnattendedFailed) -OR
		($PRComment.body -match $LabelActionComments.ManifestValidationError)
		)) {
		if ($WhatIf) {
			write-host "PR $PR - State $($States.LabelAction)"
		}
			$State = $States.LabelAction
		} else {
			foreach ($Key in $States.Keys) {
				$KeyData = $PRStateData | where {$_.State -eq $Key}
				if ($WhatIf) {
					write-host "PR $PR - key $key - State $($States.Key) - botcomment $($KeyData.BotComment) - PRComment $($PRComment.body)"
				}
				if (($PRComment.body -match $KeyData.BotComment) -AND ($PRComment.UserName -eq $KeyData.User)) {
					if ($WhatIf) {
						write-host "PR $PR - match $($KeyData.BotComment)"
					}
					$State = $States.$Key
				}
			}
		}
		if ($WhatIf) {
			write-host "PR $PR - State $State"
		}
		if ($State -ne "") {
			if ($WhatIf) {
				write-host "PR $PR - out $out"
			}
			$out += $PRComment | select @{n="event";e={$State}},created_at
		}
	}
	Return $out
}

Function Get-AddToAutowaiver {
	param(
		$PR,
		$RemoveLabel,
		$AutowaiverData = (Get-Content $AutowaiverFile | ConvertFrom-Csv),
		$PRData = (Get-CommitFile -PR $PR),
		$PackageIdentifier = (Get-YamlValue -StringName PackageIdentifier -clip $PRData)
	)
	$NewLine = "" | select "PackageIdentifier","ManifestValue","ManifestKey","RemoveLabel"
	$NewLine.PackageIdentifier = $PackageIdentifier
	$NewLine.RemoveLabel = $RemoveLabel
	if (($RemoveLabel -eq $Labels.VD) -or ($RemoveLabel -eq $Labels.VUU)) {
		$NewLine.ManifestValue = ((Get-YamlValue -StringName InstallerUrl -clip $PRData) -split "/")[2]
		$NewLine.ManifestKey = "InstallerUrl"
	} else {
		$NewLine.ManifestValue = $PackageIdentifier
		$NewLine.ManifestKey = "PackageIdentifier"
	}

	$AutowaiverData += $NewLine
	($AutowaiverData | sort PackageIdentifier | ConvertTo-Csv) | Out-File $AutowaiverFile
}

Function Get-Autowaiver {
	param(
		[int]$PR = (Get-PRNumber (Get-Clipboard) -Hash),
		$AutowaiverData = (Get-Content $AutowaiverFile | ConvertFrom-Csv),
		$PRData = (Get-CommitFile -PR $PR),
		$PackageIdentifier = (Get-YamlValue -StringName PackageIdentifier -clip $PRData),
		$WaiverData = ($AutowaiverData | ?{$_.PackageIdentifier -eq $PackageIdentifier})
	)
	if ($WaiverData) {
		Add-PRToRecord -PR $PR -Action $Actions.Waiver
		foreach ($Waiver in $WaiverData) {
			try {
				$PackageValue = (Get-YamlValue -StringName $Waiver.ManifestKey -clip $PRData)
			} catch {}
			if ($PackageValue -match $Waiver.ManifestValue) {
				Get-RemovePRLabel -PR $PR -LabelName $Waiver.RemoveLabel
				Get-RemovePRLabel -PR $pr -LabelName "Needs-Author-Feedback"
				Get-RemovePRLabel -PR $pr -LabelName "Needs-Attention"
				Get-AddPRLabel -PR $PR -LabelName Validation-Completed
			}
		}
	}
}

Function Get-VerifyMMC {
	param(
		[int]$PR = (Get-PRNumber $clip -Hash)
	)
	$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content | select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
	[array]$MissingProperties = ($Comments.body | ? {$_ -match "=== manifests"}) -split "`n" | ?{ $_ -notmatch "=== manifests" -AND
	 $_ -notmatch "Missing Properties" -AND
	 $_ -notmatch "Icons" -AND
	 $_ -notmatch "Platform" -AND
	 $_ -notmatch "MinimumOSVersion" -AND
	 $_ -notmatch "ReleaseNotes" -AND
	 $_ -notmatch "ReleaseNotesUrl" -AND
	 $_ -notmatch "ReleaseDate"}
	if (!$MissingProperties) {
		Get-RemovePRLabel -PR $PR -LabelName Manifest-Metadata-Consistency
	}
}

Function Get-DuplicateCheck {
	param(
		[int]$PR 
	)
	$PRLabels = ((Invoke-GitHubPRRequest -PR $PR -Type "labels" -Output content -JSON).name)
	if ($PRLabels -match $Labels.VC) { #If this PR is VC
		$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content)
		$otherPR = $Comments.body | ? {$_ -match "Found duplicate pull request"} 
		$otherPR = $otherPR -split "`n"
		[int]$otherPR = (($otherPR | where {$_ -match $hashPRRegex}) -split "#")[-1]
		$otherPRLabels = ((Invoke-GitHubPRRequest -PR $otherPR -Type "labels" -Output content -JSON).name)
		[int]$mainPR = 0
		[int]$dupePR = 0
		if ($otherPRLabels -match $Labels.VC) { #If other is VC, close the lower number as other.
			if ($otherPRLabels -match $Labels.MA) { #If other is VCMA, close this.
				$mainPR = $otherPR
				$dupePR = $PR
			} else { #If the other is not VC, close it as other.
				$mainPR = [math]::Max($PR,$otherPR)
				$dupePR = [math]::Min($PR,$otherPR)
			}# end if Moderator-Approved
			} else { #If the other is not VC, close it as other.
				$mainPR = $PR
				$dupePR = $otherPR
		}# end if Validation-Completed
		if ($dupePR -gt 0) { 
			Get-GitHubPreset -Preset Duplicate -PR $dupePR -UserInput $mainPR
			Get-RemovePRLabel -PR $mainPR -Label $Labels.PD
		}# end if dupePR
	}# end if mainPRLabels
}# end function

#Network tools
#GET = Read; POST = Append; PUT = Write; DELETE = delete
Function Invoke-GitHubRequest {
	param(
		[Parameter(mandatory=$True)][string]$Uri,
		[string]$Body,
		[ValidateSet("DELETE","GET","HEAD","PATCH","POST","PUT")][string]$Method = "GET",
		$Headers = @{"Authorization"="Bearer $GitHubToken"; "Accept"="application/vnd.github+json"; "X-GitHub-Api-Version"="2022-11-28"},
		#[ValidateSet("content","StatusDescription")][string]$Output = "content",
		[switch]$JSON,
		$out = ""
	)
	if ($Body) {
		try {
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -ContentType application/json -ProgressAction SilentlyContinue)
		} catch {
			Write-Output ("Error: $($error[0].ToString()) - Url $Url - Body: $Body")
		}
	} else {
		try {
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -ProgressAction SilentlyContinue)
		} catch {
			Write-Output ("Error: $($error[0].ToString()) - Url $Url - Body: $Body")
		}
	}
	#GitHub requires the value be the .body property of the variable. This makes more sense with CURL, Where-Object this is the -data parameter. However with Invoke-WebRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.
	#if (!($Silent)) {
		if (($JSON)){# -OR ($Output -eq "content")) {
			$out | ConvertFrom-Json
		} else {
			$out
		}
	#}
	Start-Sleep $GitHubRateLimitDelay;
}

Function Check-PRInstallerStatusInnerWrapper {
	param(
		$Url,
		$Code = (Invoke-WebRequest $Url -Method Head -ErrorAction SilentlyContinue -ProgressAction SilentlyContinue).StatusCode
	)
	return $Code
}

#Validation Starts Here
#Validation Starts Here
#Validation Starts Here
Function Get-TrackerVMValidate {
	param(
		$clipInput = ((Get-Clipboard) -split "`n"),
		$clip = ($clipInput[0..(($clipInput | Select-String "Do not share my personal information").LineNumber -1)]),
		[ValidateSet("Win10","Win11")][string]$OS = (Get-OSFromVersion -clip $clip),
		[int]$vm = ((Get-NextFreeVM -OS $OS) -replace"vm",""),
		[switch]$NoFiles,
		[ValidateSet("Configure","DevHomeConfig","Pin","Scan")][string]$Operation = "Scan",
		[switch]$InspectNew,
		[switch]$notElevated,
		$ManualDependency,
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $clip) -replace '"',''-replace "'",''),
		$PackageVersion = ((Get-YamlValue -StringName "PackageVersion" $clip) -replace '"',''-replace "'",''),
		[int]$PR = (Get-PRNumber $clip -Hash),
		$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		$installerLine = "--manifest $RemoteFolder/manifest",
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")][string]$Arch,
		[ValidateSet("User","Machine")][string]$Scope,
		$InstallerType,
		[string]$Locale,
		[switch]$Force,
		[switch]$Silent,
		[switch]$PauseAfterInstall,
		$optionsLine = ""
	)
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
	
	Test-Admin
	Get-StaleVMCheck
	
	#Check if PR is open
	$PRState = Invoke-GitHubPRRequest -PR $PR -Type "" -Output Content
	
	$LabelList = (Invoke-GitHubPRRequest -PR $PR -Type labels -Output Content).name
	if ($Force -OR  !((($LabelList -join " ") -match $Labels.MA) -AND (($LabelList -join " ") -match $Labels.CR) -AND (($LabelList -join " ") -match "New-Package")) -OR ($PRState.merged -ne $False) -OR ($PRState.state -ne "open")) {
		if ($vm -eq 0){
			Write-Host "No available $OS VMs";
			Get-PipelineVmGenerate -OS $OS;
			#Break;
		}
		$PackageMode = "Existing"
		
		
		if ($null -eq (Find-WinGetPackage $PackageIdentifier)) {
			$PackageMode = "New"
		}
		$PostInstallPause = ""
		if ($PauseAfterInstall) {
			$PostInstallPause = "Read-Host 'Install complete, press ENTER to continue...'"
		}
		if ($Silent) {
			Get-TrackerVMSetStatus "Prevalidation" $VM $PackageIdentifier -PR $PR -Mode $PackageMode -Silent
		} else {
			Get-TrackerVMSetStatus "Prevalidation" $VM $PackageIdentifier -PR $PR -Mode $PackageMode
		}
		if ((Get-VM "vm$VM").state -ne "Running") {Start-VM "vm$VM"}

			$logLine = "$OS "
			$nonElevatedShell = ""
			$logExt = "log"
			$VMFolder = "$MainFolder\vm\$vm"
			$manifestFolder = "$VMFolder\manifest"
			$CmdsFileName = "$VMFolder\cmds.ps1"

		if ($Operation -eq "Configure") {
			if (!($Silent)) {
				Write-Host "Running Manual Config build $build on vm$VM for ConfigureFile"
			}
			$wingetArgs = "configure -f $RemoteFolder/manifest/config.yaml --accept-configuration-agreements --disable-interactivity"
			$Operation = "Configure"
			$InspectNew = $False
		} else {
			if ($PackageIdentifier -eq "") {
				Write-Host "Bad PackageIdentifier: $PackageIdentifier"
				#Break;
				$PackageIdentifier | clip
			}
			if (!($Silent)) {
				Write-Host "Running Manual Validation build $build on vm$VM for package $PackageIdentifier version $PackageVersion"
			}
			
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
			if ($InstallerType) {
				$logExt = $InstallerType+"."+$logExt
				$optionsLine += " --installer-type $InstallerType "
				$logLine += "InstallerType $InstallerType "
			}
			$Archs = ($clip | Select-String -notmatch "arm" | Select-String "Architecture: " )|ForEach-Object{($_ -split ": ")[1]} 
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
				$logLine += "$Arch "
			}
			$MDLog = ""
			if ($ManualDependency) {
				$MDLog = $ManualDependency
				if (!($Silent)) {
					Write-Host " = = = = Installing manual dependency $ManualDependency = = = = "
				}
				[string]$ManualDependency = "Out-Log 'Installing manual dependency $ManualDependency.';Start-Process 'winget' 'install "+$ManualDependency+" --accept-package-agreements --ignore-local-archive-malware-scan' -wait`n"
			}
			if ($notElevated -OR ($clip | Select-String "ElevationRequirement: elevationProhibited")) {
				if (!($Silent)) {
					Write-Host " = = = = Detecting de-elevation requirement = = = = "
				}
				$nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\Program Files\PowerShell\7\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}"
				#If elevated, run^^ and exit, else run cmds.
			}
			$packageName = ($PackageIdentifier -split "[.]")[1]
			$wingetArgs = "install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan"
		}
		$cmdsOut = ""

	switch ($Operation) {
	"Configure" {
	$cmdsOut = "$nonElevatedShell
	`$TimeStart = Get-Date;
	`$ConfigurelLogFolder = `"$SharedFolder/logs/Configure/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
	Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
		`$TimeStamp = (Get-Date -Format T) + ': ';
		`$logEntry = `$TimeStamp + `$logData
		Write-Host `$logEntry -f `$logColor;
		md `$ConfigurelLogFolder -ErrorAction Ignore
		`$logEntry | Out-File `"`$ConfigurelLogFolder/$PackageIdentifier.$logExt`" -Append -Encoding unicode
	};
	Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
		Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
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
	Out-ErrorData `$DefenderThreat `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

	Out-Log `" = = = = Completing Manual Validation pipeline build $build on VM $VM for Configure file $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
	Get-TrackerVMSetStatus 'ValidationCompleted'

	"
		}#end Configure
	"Scan" {
	$cmdsOut = "$nonElevatedShell
	`$TimeStart = Get-Date;
	`$explorerPid = (Get-Process Explorer).id;
	`$ManValLogFolder = `"$SharedFolder/logs/$(Get-Date -UFormat %B)/`$(Get-Date -Format dd)`"
	Function Out-Log ([string]`$logData,[string]`$logColor='cyan') {
		`$TimeStamp = (Get-Date -Format T) + ': ';
		`$logEntry = `$TimeStamp + `$logData
		Write-Host `$logEntry -f `$logColor;
		md `$ManValLogFolder -ErrorAction Ignore
		`$logEntry | Out-File `"`$ManValLogFolder/$PackageIdentifier.$logExt`" -Append -Encoding unicode
	};
	Function Out-ErrorData (`$errArray,[string]`$serviceName,`$errorName='errors') {
		Out-Log `"Detected `$(`$errArray.count) `$serviceName `$(`$errorName): `"
		`$errArray | ForEach-Object {Out-Log `$_ 'red'}
	};
	Function Get-TrackerProgress {
		param(
			`$File,
			`$Activity,
			`$Incrementor,
			`$Length,
			`$Percent = [math]::round(`$Incrementor / `$length*100,2)
		)
	};
	Get-TrackerVMSetStatus 'Installing'
	Out-Log ' = = = = Starting Manual Validation pipeline build $build on VM $VM $PackageIdentifier $logLine = = = = '

	Out-Log 'Pre-testing log cleanup.'
	Out-Log 'Upgrading installed applications.'
	Out-Log (WinGet upgrade --all --include-pinned --disable-interactivity)
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

	`$InstallStart = Get-Date;
	$ManualDependency
	Out-Log `"Main Package Install with args: $wingetArgs`"
	`$mainpackage = (Start-Process 'winget' '$wingetArgs' -wait -PassThru);
	Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
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

	Out-ErrorData `$WinGetLogs 'WinGet'
	Out-ErrorData '$MDLog' 'Manual' 'Dependency'
	Out-ErrorData `$Error 'PowerShell'
	Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
	Out-ErrorData `$DefenderThreat `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

	Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"

	if ((`$WinGetLogs -match '\[FAIL\] Installer failed security check.') -OR 
	(`$WinGetLogs -match '80190194 Not found') -OR 
	(`$WinGetLogs -match 'Package hash verification failed') -OR 
	(`$WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){
		Send-SharedError -clip `$WinGetLogs
	} elseif (`$DefenderThreat) {
		Send-SharedError -clip `$DefenderThreat
	} else {
		Get-TrackerVMSetStatus 'ValidationCompleted'
	}

		Break;
	}
	$PostInstallPause



	Get-TrackerVMSetStatus 'Scanning'

	Out-Log 'Install complete, starting file change scan.'
	`$files = ''
	if (Test-Path $RemoteFolder\files.txt) {#If we have a list of files to run - a relic from before automatic file gathering. 
		`$files = Get-Content $RemoteFolder\files.txt
	} else {
		`$files1 = (
			Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | 
			Where-Object {`$_.CreationTime -gt `$InstallStart} | 
			Where-Object {`$_.CreationTime -lt `$InstallEnd} | 
			%{`$line++;Get-TrackerProgress `$_ `"lnk`" `$line `$line;return `$_}
		).FullName
		`$files2 = (
			Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | 
			Where-Object {`$_.LastAccessTIme -gt `$InstallStart} | 
			Where-Object {`$_.CreationTime -lt `$InstallEnd} | 
			%{`$line++;Get-TrackerProgress `$_ `"lnk`" `$line `$line;return `$_}
		).FullName
		`$files3 = (
			Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | 
			Where-Object {`$_.LastWriteTIme -gt `$InstallStart} | 
			Where-Object {`$_.CreationTime -lt `$InstallEnd} | 
			%{`$line++;Get-TrackerProgress `$_ `"lnk`" `$line `$line;return `$_}
		).FullName
		`$files = `$files1 + `$files2 + `$files3 | Select-Object -Unique
	}

	Out-Log `"Reading `$(`$files.count) file changes in the last `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. Starting bulk file execution:`"
	`$files = `$files | 
	Where-Object {`$_ -notmatch 'AppRepository'} |
	Where-Object {`$_ -notmatch 'assembly'} | 
	Where-Object {`$_ -notmatch 'CbsTemp'} | 
	Where-Object {`$_ -notmatch 'CryptnetUrlCache'} | 
	Where-Object {`$_ -notmatch 'DesktopAppInstaller'} | 
	Where-Object {`$_ -notmatch 'dotnet'} | 
	Where-Object {`$_ -notmatch 'dump64a'} | 
	Where-Object {`$_ -notmatch 'EdgeCore'} | 
	Where-Object {`$_ -notmatch 'EdgeUpdate'} | 
	Where-Object {`$_ -notmatch 'EdgeWebView'} | 
	Where-Object {`$_ -notmatch 'ErrorDialog = ErrorDlg'} | 
	Where-Object {`$_ -notmatch 'Microsoft.Windows.Search'} | 
	Where-Object {`$_ -notmatch 'Microsoft\\Edge\\Application'} | 
	Where-Object {`$_ -notmatch 'msedge'} | 
	Where-Object {`$_ -notmatch 'NativeImages'} | 
	Where-Object {`$_ -notmatch 'Prefetch'} | 
	Where-Object {`$_ -notmatch 'Provisioning'} | 
	Where-Object {`$_ -notmatch 'redis'} | 
	Where-Object {`$_ -notmatch 'servicing'} | 
	Where-Object {`$_ -notmatch 'System32'} | 
	Where-Object {`$_ -notmatch 'SysWOW64'} | 
	Where-Object {`$_ -notmatch 'unins'} | 
	Where-Object {`$_ -notmatch 'waasmedic'} | 
	Where-Object {`$_ -notmatch 'Windows Defender'} | 
	Where-Object {`$_ -notmatch 'Windows Error Reporting'} | 
	Where-Object {`$_ -notmatch 'WindowsUpdate'} | 
	Where-Object {`$_ -notmatch 'WinSxS'}

	`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'
	`$files | Select-String '[.]exe`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
	`$files | Select-String '[.]msi`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
	`$files | Select-String '[.]lnk`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'} else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};

	Out-Log `" = = = = End file list. Starting Defender scan.`"
	Start-MpScan;

	Out-Log `"Defender scan complete, closing windows...`"
	Get-Process msedge | Stop-Process -Force
	Get-Process mip | Stop-Process
	Get-Process powershell | where {`$_.id -ne `$PID} | Stop-Process
	Get-Process explorer | where {`$_.id -ne `$explorerPid} | Stop-Process

	Get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell' -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'} | Stop-Process
	#Get-Process | Where-Object {`$_.id -notmatch `$PID -and `$_.id -notmatch `$explorerPid -and `$_.processname -notmatch `$packageName -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'} | Stop-Process

	`$WinGetLogs = ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}})
	`$DefenderThreat = (Get-MPThreat).ThreatName

	Out-ErrorData `$WinGetLogs 'WinGet'
	Out-ErrorData '$MDLog' 'Manual' 'Dependency'
	Out-ErrorData `$Error 'PowerShell'
	Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
	Out-ErrorData `$DefenderThreat `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

	if ((`$WinGetLogs -match '\[FAIL\] Installer failed security check.') -OR 
	(`$WinGetLogs -match 'Package hash verification failed') -OR 
	(`$WinGetLogs -match 'Operation did not complete successfully because the file contains a virus or potentially unwanted software')){
		Send-SharedError -clip `$WinGetLogs
		Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'SendStatus'
	} elseif (`$DefenderThreat) {
		Send-SharedError -clip `$DefenderThreat
		Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'SendStatus'
	} elseif ((Get-Content $RemoteTrackerModeFile) -eq 'IEDS') {
		Out-Log `" = = = = Auto-Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'Approved'
	} elseif ((Get-TrackerVMStatus | where {`$_.vm -match `$vm}).Mode -eq 'Existing') {
		Out-Log `" = = = = Auto-Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'Approved'
	} else {
		Start-Process PowerShell
		Out-Log `" = = = = Completing Manual Validation pipeline build $build on VM $VM for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
		Get-TrackerVMSetStatus 'ValidationCompleted'
	}

	"
		}#end Scan
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
			Get-RemoveFileIfExist "$manifestFolder" -remake -Silent
			if ($Operation -eq "Configure") {
				$FilePath = "$manifestFolder\config.yaml"
				Out-File -FilePath $FilePath -InputObject $clipInput
			} else {
				$Files = @()
				$Files += "Package.installer.yaml"
				$FileNames = ($clip | Select-String "[.]yaml") |ForEach-Object{($_ -split "/")[-1]}
				$replace = $FileNames[-1] -replace ".yaml"
				$FileNames | ForEach-Object {
					$Files += $_ -replace $replace,"Package"
				}
				$clip = $clip -join "`n" -split "@@"
				for ($i=0;$i -lt $Files.length;$i++) {
					$File = $Files[$i]
					$inputObj = $clip[$i*2] -split "`n"
					$inputObj = $inputObj[1..(($inputObj | Select-String "ManifestVersion" -SimpleMatch).LineNumber -1)] | Where-Object {$_ -notmatch "marked this conversation as resolved."}
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
					$fileContents -replace "0New version: ","0" -replace "0New package: ","0" -replace "0Add version: ","0" -replace "0Add package: ","0" -replace "0Add ","0" -replace "0New ","0" -replace "0package: ","0" | Out-File $FilePath
				}
				$filecount = (Get-ChildItem $manifestFolder).count
				$filedir = "ok"
				$filecolor = "green"
				if ($filecount -lt 3) { $filedir = "too low"; $filecolor = "red"}
				if ($filecount -gt 3) { $filedir = "high"; $filecolor = "yellow"}
				if ($filecount -gt 10) { $filedir = "too high"; $filecolor = "red"}
				if (!($Silent)) {
					Write-Host -f $filecolor "File count $filecount is $filedir"
				}
				if ($filecount -lt 3) { break}
				$fileContents = Get-Content "$runPath\$vm\manifest\Package.yaml"
				if ($fileContents[-1] -ne "0") {
					$fileContents[-1] = ($fileContents[-1] -split ".0")[0]+".0"
					$fileContents | Out-File $filePath
					$fileContents = Get-Content "$runPath\$vm\manifest\Package.yaml"
					$fileContents -replace "1..0","1.10.0"
					$fileContents | Out-File $filePath
				}#end if fileContents		
			}#end if Operation
		}#end if NoFiles

		if ($InspectNew) {
			$PackageResult = Find-WinGetPackage $PackageIdentifier
			if (!($Silent)) {
				Write-Host "Searching Winget for $PackageIdentifier"
			}
			Write-Host $PackageResult
			if ($PackageResult -eq "No package found matching input criteria.") {
				Open-AllURL
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
		Get-TrackerVMRevert $VM -Silent
		Get-TrackerVMLaunchWindow $VM
	}
}

Function Get-TrackerVMValidateByID {
	param(
		$PackageIdentifier = (Get-Clipboard)
	)
	Get-TrackerVMValidate -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles #-notElevated
}

Function Get-TrackerVMValidateByConfig {
	param(
	$PackageIdentifier = "Microsoft.Devhome",
	$ManualDependency = "Git.Git"
	)

	Get-TrackerVMValidate -installerLine "--id $PackageIdentifier" -PackageIdentifier $PackageIdentifier -NoFiles -ManualDependency $ManualDependency -Operation "DevHomeConfig"
	Start-Sleep 2
	Get-TrackerVMValidate -installerLine "--id $ManualDependency" -PackageIdentifier $ManualDependency -NoFiles -Operation "Config"
}

Function Get-TrackerVMValidateByArch {
	param(
	)
	Get-TrackerVMValidate -Arch x64;
	Start-Sleep 2;
	Get-TrackerVMValidate -Arch x86;
}

Function Get-TrackerVMValidateByScope {
	param(
	)
	Get-TrackerVMValidate -Scope Machine;
	Start-Sleep 2;
	Get-TrackerVMValidate -Scope User;
}

Function Get-TrackerVMValidateBothArchAndScope {
	param(
	)
	Get-TrackerVMValidate -Arch x64 -Scope Machine;
	Start-Sleep 2;
	Get-TrackerVMValidate -Arch x86 -Scope Machine;
	Start-Sleep 2;
	Get-TrackerVMValidate -Arch x64 -Scope User;
	Start-Sleep 2;
	Get-TrackerVMValidate -Arch x86 -Scope User;
}

#Manifests Etc
Function Get-SingleFileAutomation {
	param(
		$PR,
		$clip = (Get-Clipboard),
		$PackageIdentifier = (Get-YamlValue PackageIdentifier -clip $clip),
		$version = ((Get-YamlValue PackageVersion -clip $clip) -replace "'","" -replace '"',""), 
		$listing = (Get-ManifestListing $PackageIdentifier),
		$VM = (Get-ManifestFile -clip $clip)[-1]
	)
	
	for ($File = 0; $File -lt $listing.length;$File++) {
		Get-ManifestFile $VM -clip (Get-FileFromGitHub -PackageIdentifier $PackageIdentifier -Version $version -FileName $listing[$File]) -PR $PR
	}
}

Function Get-InstallerFileAutomation {
	Param(
		$PR = (Get-Clipboard),
		$InstallerFile = (Get-CommitFile -PR $PR -MatchName "")
	)
	Get-SingleFileAutomation -PR $pr -clip $InstallerFile
}

Function Get-ManifestAutomation {
	param(
		$VM = (Get-NextFreeVM),
		$PR =0,
		$Arch,
		$OS,
		$Scope
	)

	#Read-Host "Copy Installer file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	$null = Get-ManifestFile $VM

	Read-Host "Copy defaultLocale file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	$null = Get-ManifestFile $VM

	Read-Host "Copy version file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	if ($Arch) {
		$null = Get-ManifestFile $VM -Arch $Arch
	} elseif ($OS) {
		$null = Get-ManifestFile $VM -OS $OS
	} elseif ($Scope) {
		$null = Get-ManifestFile $VM -Scope $Scope
	} else {
		$null = Get-ManifestFile $VM -PR $PR
	}
}

Function Get-ManifestOtherAutomation {
	param(
		$Clip = (Get-Clipboard),
		$Title = ($Clip -split " version "),
		$Version = ($Title[1] -split " #"),
		$PR = ($Version[1]),
		[switch]$Installer
	)
	$Title = $Title[0]
	$Version = $Version[0]
	if ($Installer) {
		$File = (Get-FileFromGitHub $Title $Version)
	}
}

Function Get-Generate {
$out = "
# Created by Validation Pipeline build $build
# If a human is reading this, then something has gone wrong.

PackageIdentifier: $PackageIdentifier
PackageVersion: $PackageVersion
DefaultLocale: $Locale
ManifestType: version
ManifestVersion: $ManifestVersion"
	
}

Function Get-ManifestFile {
	param(
		[int]$vm = ((Get-NextFreeVM) -replace "vm",""),
		$clip = (Get-SecondMatch),
		$FileName = "Package",
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" -clip $clip) -replace '"','' -replace "'",'' -replace ",",''),
		$PR = 0,
		$Arch,
		$OS,
		$Scope
	);
	#Write-Output "PackageIdentifier: $PackageIdentifier"
	$manifestFolder = "$MainFolder\vm\$vm\manifest"
	$clip = $clip | Where-Object {$_ -notmatch "marked this conversation as resolved."}

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
			Get-RemoveFileIfExist "$manifestFolder" -remake
			$FileName = "$FileName.installer"
		}
		"version" {
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
			Write-Output $clip
		}
	}
	$FilePath = "$manifestFolder\$FileName.yaml"
	Write-Output "Writing $($clip.length) lines to $FilePath"
	$clip -replace "0New version: ","0" -replace "0Add version: ","0" -replace "0Add ","0" -replace "0New ","0" | Out-File $FilePath -Encoding unicode
	return $VM
}

Function Get-ManifestListing {
	param(
		$PackageIdentifier,
		$Version = (Find-WinGetPackage $PackageIdentifier -MatchOption Equals).version,
		$Path = ($PackageIdentifier -replace "[.]","/"),
		$FirstLetter = ($PackageIdentifier[0].tostring().tolower()),
		$Uri = "$GitHubApiBaseUrl/contents/manifests/$FirstLetter/$Path/$Version/",
		[Switch]$Versions
	)
	If ($Versions) {
		$Uri = "$GitHubApiBaseUrl/contents/manifests/$FirstLetter/$Path/"
	}
	try{
		$out = (Invoke-GitHubRequest -Uri $Uri -JSON).name
	}catch{
		$out = "Error"
	}
	return $out -replace "$($PackageIdentifier)[.]",""
}

Function Get-ListingDiff {
	param(
		$Clip = (Get-Clipboard),
		$PackageIdentifier = (Get-YamlValue PackageIdentifier $Clip -replace '"',""),
		$PRManifest = ($clip -split "`n" | Where-Object {$_ -match ".yaml"} | Where-Object {$_ -match $PackageIdentifier} |%{($_ -split "/")[-1] -replace "$($PackageIdentifier)[.]",""}),
		$Returnables = ""
	)
	if ($PRManifest.count -gt 2){
		$CurrentManifest = (Get-ManifestListing $PackageIdentifier)
		if ($CurrentManifest -eq "Error") {
			$Returnables = diff $CurrentManifest $PRManifest
		} else {
			$Returnables = $CurrentManifest
		}
	}
	Return $Returnables
}

Function Get-OSFromVersion ($clip) {
	try{
		if ([system.version](Get-YamlValue -StringName MinimumOSVersion -clip $clip) -ge [system.version]"10.0.22000.0"){"Win11"} else{"Win10"}
	} catch {
		"Win10"
	}
}

#VM Image Management
Function Get-PipelineVmGenerate {
	param(
		[int]$vm = (Get-Content $vmCounter),
		[ValidateSet("Win10","Win11")][string]$OS = "Win10",
		[int]$version = (Get-TrackerVMVersion -OS $OS),
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$newVmName = "vm$VM",
		$startTime = (Get-Date)
	)
	Test-Admin
	Write-Host "Creating VM $newVmName version $version OS $OS"
	[int]$vm+1|Out-File $vmCounter
	"`"$vm`",`"Generating`",`"$version`",`"$OS`",`"`",`"1`",`"Creation`",`"0`""|Out-File $StatusFile -Append -Encoding unicode
	Get-RemoveFileIfExist $destinationPath -remake
	Get-RemoveFileIfExist $VMFolder -remake
	$vmImageFolder = (ls "$imagesFolder\$OS-image\Virtual Machines\" *.vmcx).fullname

	Write-Host "Takes about 120 seconds..."
	Import-VM -Path $vmImageFolder -Copy -GenerateNewId -VhdDestinationPath $destinationPath -VirtualMachinePath $destinationPath;
	Rename-VM (Get-VM | Where-Object {($_.CheckpointFileLocation)+"\" -eq $destinationPath}) -NewName $newVmName
	Start-VM $newVmName
	Remove-VMCheckpoint -VMName $newVmName -Name "Backup"
	Get-TrackerVMRevert $VM
	Get-TrackerVMLaunchWindow $VM
	Write-Host "Took $(((Get-Date)-$startTime).TotalSeconds) seconds..."
}

Function Get-PipelineVmDisgenerate {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = "vm$VM"
	)
	Test-Admin
	Get-TrackerVMSetStatus 'Disgenerate' $VM
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
	Write-Progress -Activity "Remove VM"  -Completed
}

Function Get-ImageVMStart {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$VM = 0
	Start-VM $OS;
	Get-TrackerVMRevert $VM $OS;
	Get-TrackerVMLaunchWindow $VM $OS
}

Function Get-ImageVMStop {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$VM = 0
	$OriginalLoc = ""
	switch ($OS) {
		"Win10" {
			$OriginalLoc = $Win10Folder
		}
		"Win11" {
			$OriginalLoc = $Win11Folder
		}
	}
	$ImageLoc = "$imagesFolder\$OS-image\"
	[int]$version = [int](Get-TrackerVMVersion -OS $OS) + 1
	Write-Host "Writing $OS version $version"
	Get-TrackerVMSetVersion -Version $Version -OS $OS
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match "$OS"}).id -ErrorAction Ignore
	Redo-Checkpoint $VM $OS;
	Stop-TrackerVM $VM $OS;
	Write-Host "Letting VM cool..."
	Start-Sleep 30;
	Robocopy.exe $OriginalLoc $ImageLoc -mir
}

Function Get-ImageVMMove {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10",
		$CurrentVMName = "",
		$newLoc = "$imagesFolder\$OS-Created$(get-date -f MMddyy)-Original"
	)
	Test-Admin
	switch ($OS) {
		"Win10" {
			$CurrentVMName = "Windows 10 MSIX packaging environment"
		}
		"Win11" {
			$CurrentVMName = "Windows 11 dev environment"
		}
	}
	$VM = Get-VM | where {$_.Name -match $CurrentVMName}
	Move-VMStorage -VM $VM -DestinationStoragePath $newLoc
	Rename-VM -VM $VM -NewName $OS
}

#VM Pipeline Management
Function Get-TrackerVMLaunchWindow {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$VM"
	)
	Test-Admin
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Get-TrackerVMRevert {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$VM",
		[Switch]$Silent
	)
	Test-Admin
	if ($Silent) {
		Get-TrackerVMSetStatus "Restoring" $VM -Silent
	} else {
		Get-TrackerVMSetStatus "Restoring" $VM
	}
	Restore-VMCheckpoint -Name $CheckpointName -VMName $VMName -Confirm:$False
}

Function Complete-TrackerVM {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMFolder = "$MainFolder\vm\$vm",
		$filesFileName = "$VMFolder\files.txt"
	)
	Test-Admin
	Get-TrackerVMSetStatus "Completing" $VM
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match "vm$VM"}).id -ErrorAction Ignore
	Stop-TrackerVM $VM
	Get-RemoveFileIfExist $filesFileName
	Get-TrackerVMSetStatus "Ready" $VM " " 1 "Ready"
}

Function Stop-TrackerVM {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$VM"
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

#VM Status
Function Get-TrackerVMSetStatus {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","SendStatus-Approved","SendStatus-Complete","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status = "Complete",
		[Parameter(mandatory=$True)]$VM,
		[string]$Package,
		[int]$PR,
		[ValidateSet("New","Creating","Existing","Ready","Unknown")]
		[string]$Mode,
		[Switch]$Silent
	)
	$out = Get-Status
	if ($Status) {
		($out | Where-Object {$_.vm -match $VM}).Status = $Status
	}
	if ($Package) {
		($out | Where-Object {$_.vm -match $VM}).Package = $Package
	}
	if ($PR) {
		($out | Where-Object {$_.vm -match $VM}).PR = $PR
	}
	if ($Mode) {
		($out | Where-Object {$_.vm -match $VM}).Mode = $Mode
	}
	if ($Silent) {
		Write-Status $out -Silent
	} else {
		Write-Status $out
		Write-Host "Setting $VM $Package $PR state $Status"
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

Function Get-Status {
	param(
		[int]$vm,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","SendStatus-Approved","SendStatus-Complete","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status,
		[ValidateSet("Win10","Win11")][string]$OS,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv)
	)
	$out
}

Function Get-TrackerVMResetStatus {
	$VMs = (Get-Status | Where-Object {$_.Status -ne "Ready"} | Where-Object {$_.RAM -eq 0}).VM
	$VMs += (Get-Status | Where-Object {$_.Status -ne "Ready"} | Where-Object {$_.Package -eq ""}).VM
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
	Where-Object {$_.name -notmatch "Win10"} |
	Where-Object {$_.name -notmatch "Win11"} |
	Select-Object @{n="vm";e={$_.name -replace "vm",$null}},
	@{n="status";e={"Ready"}},
	@{n="version";e={(Get-TrackerVMVersion -OS "Win10")}},
	@{n="OS";e={"Win10"}},
	@{n="Package";e={""}},
	@{n="PR";e={"1"}},
	@{n="Mode";e={"Unknown"}},
	@{n="RAM";e={"0"}}
	Write-Status $Status
}

#VM Versioning
Function Get-TrackerVMVersion {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10",
		[int]$VM = ((Get-Content $VMversion | ConvertFrom-Csv | Where-Object {$_.OS -eq $OS}).version)
	)
	Return $VM
}

Function Get-TrackerVMSetVersion {
	param(
		[int]$Version,
		[ValidateSet("Win10","Win11")][string]$OS = "Win10",
		$Versions = (Get-Content $VMversion | ConvertFrom-Csv)
	)
	($Versions | Where-Object {$_.OS -eq $OS}).Version = $Version
	$Versions | ConvertTo-Csv|Out-File $VMversion
}

Function Get-TrackerVMRotate {
	param(
		$status = (Get-Status),
		$OS = "Win10",
		$VMs = ($status | Where-Object {$_.version -lt (Get-TrackerVMVersion -OS $OS)} | Where-Object {$_.OS -eq $OS})
	)
	if ($VMs){
		if (!(($status | Where-Object {$_.status -ne "Ready"}).count)) {
			Get-TrackerVMSetStatus Regenerate ($VMs.VM | Get-Random)
		}
	}
}

#VM Orchestration
Function Get-TrackerVMCycle {
	param(
		$VMs = (Get-Status)
	)
	Foreach ($VM in $VMs) {
		Switch ($VM.status) {
			"AddVCRedist" {
				Add-ToValidationFile $VM.vm
			}
			"Approved" {
				#Add-Waiver $VM.PR
				$PRLabels = ((Invoke-GitHubPRRequest -PR $VM.PR -Type "labels" -Output content -JSON).name) -join " "
				if ($PRLabels -match $Labels.VC) {
					Approve-PR -PR $VM.PR
				} else {
					Get-CompletePR -PR $VM.PR
				}
				Get-TrackerVMSetStatus "Complete" $VM.vm
			}
			"CheckpointReady" {
				Redo-Checkpoint $VM.vm
			}
			"Complete" {
				if (($VMs | Where-Object {$_.vm -eq $VM.vm} ).version -lt (Get-TrackerVMVersion -OS $VM.os)) {
					Get-TrackerVMSetStatus "Regenerate" $VM.vm
				} else {
					Complete-TrackerVM $VM.vm
				}
			}
			"Disgenerate" {
				Get-PipelineVmDisgenerate $VM.vm
			}
			"Revert" {
				Get-TrackerVMRevert $VM.vm
			}
			"Regenerate" {
				Get-PipelineVmDisgenerate $VM.vm
				Get-PipelineVmGenerate -OS $VM.os
			}
			"SendStatus-Complete" {
				Get-SendStatus -Status "Complete"
			}
			"SendStatus-Approved" {
				Get-SendStatus -Status "Approved"
			}
			"SendStatus" {
				Get-SendStatus -Status "Complete"
			}
			"ValidationCompleted" {
				# if ($VM.Mode -eq "Existing") {
					# Get-CompletePR -PR $VM.PR
					# Get-TrackerVMSetStatus "Complete" $VM.vm
				# }
			}
			default {
				#Write-Host "Complete"
			}
		}; #end switch
	}
}

Function Get-TrackerMode {
	param(
		$mode = (Get-Content $TrackerModeFile)
	)
	$mode
}

Function Get-TrackerVMSetMode {
	param(
		[ValidateSet("Approving","Idle","IEDS","Validating")]
		$Status = "Validating"
	)
	$Status | Out-File $TrackerModeFile -NoNewLine
}

Function Get-ConnectedVM {
	Test-Admin
	(Get-Process *vmconnect*) | Select-Object id, @{n="VM";e={ForEach-Object{$_.mainwindowtitle[0..5] -join ""}}}
}

Function Get-NextFreeVM {
	param(
		[ValidateSet("Win10","Win11")][string]	$OS = "Win10",
		$Status = "Ready"
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
		return 0
	}
}

Function Redo-Checkpoint {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$VM"
	)
	Test-Admin
	Get-TrackerVMSetStatus "Checkpointing" $VM
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Get-TrackerVMSetStatus "Complete" $VM
}

#File Management
Function Get-SecondMatch {
	param(
		$clip = (Get-Clipboard),
		$depth = 1
	)
	#If $current and $prev don't match, return the $prev element, which is $depth lines below the $current line. Start at $clip[$depth] and go until the end - this starts $current at $clip[$depth], and $prev gets moved backwards to $clip[0] and moves through until $current is at the end of the array, $clip[$clip.length], and $prev is $depth previous, at $clip[$clip.length - $depth].
	for ($depthUnit = $depth;$depthUnit -lt $clip.length; $depthUnit++){
		$current = ($clip[$depthUnit] -split ": ")[0]
		$prevUnit = $clip[$depthUnit - $depth]
		$Prev = ($prevUnit -split ": ")[0]
		if ($current -ne $Prev) {
			$prevUnit
		}
	}
	#Then complete the last $depth items of the array by starting at $clip[-$depth] and work backwards through the last items in reverse order to $clip[-1].
	for ($depthUnit = $depth ;$depthUnit -gt 0; $depthUnit--){
		$clip[-$depthUnit]
	}
}

Function Get-SendStatus {
	Param(
		$PR,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","SendStatus-Approved","SendStatus-Complete","Setup","SetupComplete","Starting","Updating","ValidationCompleted")]
		$Status = "Complete",
		$SharedError = ((Get-Content $SharedErrorFile) -split "`n")
	)
	$SharedError = $SharedError -replace "`r","" 
	$SharedError = $SharedError -replace " (caller: 00007FFA008A5769)",""
	$SharedError = $SharedError -replace " (caller: 00007FFA008AA79F)",""
	$SharedError = $SharedError -replace "Exception(1)",""
	$SharedError = $SharedError -replace "Exception(2)",""
	$SharedError = $SharedError -replace "Exception(4)",""
	$SharedError = $SharedError -replace "tid(f1c)",""
	$SharedError = $SharedError -replace "C:\\__w\\1\\s\\external\\pkg\\src\\AppInstallerCommonCore\\Downloader.cpp(185)\\WindowsPackageManager.dll!00007FFA008A37C9:",""
	$SharedError = $SharedError -join "`n"
	#$SharedError = Get-AutomatedErrorAnalysis $SharedError
	if ((($SharedError -join " ") -match "Installer failed security check") -OR (($SharedError -join " ") -match "Detected 1 Defender")) {
		Get-AddPRLabel -PR $PR -LabelName $Labels.VDE
	}
	Reply-ToPR -PR $VM.PR -UserInput $SharedError -CannedMessage ManValEnd 
	Get-TrackerVMSetStatus $Status $VM.vm
}

Function Get-TrackerVMRotateLog {
	$logYesterDate = (Get-Date -f dd) - 1
	Move-Item "$writeFolder\logs\$logYesterDate" "$logsFolder\$logYesterDate"
}

Function Get-RemoveFileIfExist {
	param(
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
	param(
		$FileName,
		$FileContents,
		[Switch]$Silent
	)
	if (Test-Path $FileName) {
		$FileContents = Get-Content $FileName | ConvertFrom-Csv
		if (!($Silent)) {
			Write-Host "Loaded $($FileContents.count) entries from $FileName." -f green
			Return $FileContents
		}
	} else {
		if (!($Silent)) {
			Write-Host "File $FileName not found!" -f red
		}
	}
}

Function Get-FileFromGitHub {
	param(
		$PackageIdentifier,
		$Version,
		$FileName = "installer.yaml",
		$Path = ($PackageIdentifier -replace "[.]","/"),
		$FirstLetter = ($PackageIdentifier[0].tostring().tolower())
	)
	try{
		$content = (Invoke-GitHubRequest -Uri "$GitHubContentBaseUrl/master/manifests/$FirstLetter/$Path/$Version/$PackageIdentifier.$FileName").content
	}catch{
		$content = "Error"
	}
	return ($content -split "`n")
}

Function Get-ManifestEntryCheck {
	param(
		$PackageIdentifier,
		$Version,
		$Entry = "DisplayVersion"
	)
	$content = Get-FileFromGitHub $PackageIdentifier $Version
	$out = ($content | Where-Object {$_ -match $Entry})
	if ($out) {$True} else {$False}
}

Function Get-DecodeGitHubFile {
	param(
		[string]$Base64String,
		$Bits = ([Convert]::FromBase64String($Base64String)),
		$String = ([System.Text.Encoding]::UTF8.GetString($Bits))
	)
	return $String -split "`n"
}

Function Get-CommitFile {
	param(
		$PR = (Get-Clipboard),
		$Commit = (Invoke-GitHubPRRequest -PR $PR -Type commits -Output content -JSON),
		$MatchName = "installer",
		$PRData = (Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr" -JSON),
		$PRTitle = (($PRData.title -split " ") | where {$_ -match "[A-Za-z0-9]\.[A-Za-z0-9]"} | where {$_ -notmatch "[0-9].[0-9]"}),
		#$PRTitle = (($PRData.title -split " ")[2] | where {$_ -match "\."}),
		$FileList = ($Commit.files.contents_url | where {$_ -match $MatchName}  | where {$_ -match $PRTitle}),
		[int]$VM = 0
	)
	$FileList | %{
		"File: $_"
		try {
			$EncodedFile = (invoke-GithubRequest -Uri $_ -JSON)
		} catch {
			write-host $error[0].Message
		}
		$DecodedFile = Get-DecodeGitHubFile $EncodedFile.content
		if ($VM -gt 0) {
			Get-ManifestFile -vm $VM  -PR $PR -clip $DecodedFile
		} else {
			$DecodedFile -join "`n"
		}
	}
}

#Inject dependencies
Function Add-ToValidationFile {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		[ValidateSet("Microsoft.VCRedist.2015+.x64","Microsoft.DotNet.DesktopRuntime.8","Oracle.JavaRuntimeEnvironment")]$Common = "Microsoft.VCRedist.2015+.x64",
		$Dependency = $Common,
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest",
		$FilePath = "$manifestFolder\Package.installer.yaml",
		$fileContents = (Get-Content $FilePath),
		$Selector = "Installers:",
		$offset = 1,
		$lineNo = (($fileContents | Select-String $Selector -List).LineNumber -$offset),
		$fileInsert = "Dependencies:`n PackageDependencies:`n - PackageIdentifier: $Dependency",
		$fileOutput = ($fileContents[0..($lineNo -1)]+$fileInsert+$fileContents[$lineNo..($fileContents.length)])
	)
		Write-Host "Writing $($fileContents.length) lines to $FilePath"
		Out-File -FilePath $FilePath -InputObject $fileOutput
		Get-TrackerVMSetStatus "Revert" $VM;
}

Function Add-InstallerSwitch {
	param(
		[Parameter(mandatory=$True)][int]$vm,
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
	param(
		$PR,
		$ManifestHash,
		$PackageHash,
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $ManifestHash).LineNumber),
		$ReplaceString = ("  InstallerSha256: $($PackageHash.toUpper())"),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Labels.NAF
	}
}

Function Get-UpdateHashInPR2 {
	param(
		$PR,
		$Clip = (Get-Clipboard),
		$SearchTerm = "Expected hash",
		$ManifestHash = (Get-YamlValue $SearchTerm -Clip $Clip),
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $ManifestHash).LineNumber),
		$ReplaceTerm = "Actual hash",
		$ReplaceString = ("  InstallerSha256: "+(Get-YamlValue $ReplaceTerm -Clip $Clip).toUpper()),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Labels.NAF
	}
}

Function Get-UpdateArchInPR {
	param(
		$PR,
		$SearchTerm = " Architecture: x86",
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $SearchTerm).LineNumber),
		[string]$ReplaceTerm = (($SearchTerm -split ": ")[1]),
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")]
		[string]$ReplaceArch = (("x86","x64") | where {$_ -notmatch $ReplaceTerm}),
		$ReplaceString = ($SearchTerm -replace $ReplaceTerm,$ReplaceArch),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Labels.NAF
	}
}

Function Add-DependencyToPR {
	param(
		$PR,
		$Dependency = "Microsoft.VCRedist.2015+.x64",
		$SearchString = "Installers:",
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $SearchString).LineNumber),
		$ReplaceString = "Dependencies:`n PackageDependencies:`n - PackageIdentifier: $Dependency`nInstallers:",
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	$out = ""
	foreach ($Line in $LineNumbers) {
		$out += Add-GitHubReviewComment -PR $PR -Comment $comment -Line $Line -Action $Labels.NAF
	}
}

#PR Queue
Function Add-PRToQueue {
	param(
		$PR,
		$PRExclude = ((gc $PRExcludeFile) -split "`n")
	)
	if ($PRExclude -notcontains $Pr) {
		$PR | Out-File $PRQueueFile -Append
		
	}
}

Function Get-PopPRQueue {
	[array]$PRQueue = gc $PRQueueFile
	$PRQueue = $PRQueue -split "`n"
	$PRQueue = (diff $PRQueue (Get-Status).pr | where {$_.SideIndicator -eq "<="}).inputobject
	$out = $PRQueue[0]
	$PRQueue = $PRQueue[1..$PRQueue.length] | Select-Object -unique
	$PRQueue | Out-File $PRQueueFile 
	return $out
}

Function Get-PRQueueCount {
	$count = ((Get-Content $PRQueueFile) -split "`n").count
	return $count
}

#Reporting
Function Add-PRToRecord {
	param(
		$PR,
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action,
		$Title
	)
	$Title = ($Title -split "#")[0]
	"$PR,$Action,$Title" | Out-File $LogFile -Append 
}

Function Get-PRPopulateRecord {
	param(
		$Logs = (Get-Content $LogFile | ConvertFrom-Csv -Header ("PR","Action","Title"))
	)
	Foreach ($Log in $Logs) {
		#Populate the Title column where blank, so all lines with the same PR number also have the same title, preventing the API calls for the lookup.
		$Log.title = ($Logs | Where-Object {$_.title} | Where-Object {$_.PR -match $Log.PR}).title | Sort-Object -Unique
	}
	$Logs | ConvertTo-Csv|Out-File $LogFile
}

Function Get-PRFromRecord {
	param( 
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action
	)
	Get-PRPopulateRecord
	(Get-Content $LogFile) | ConvertFrom-Csv -Header ("PR","Action","Title") | Where-Object {$_.Action -match $Action}
}

Function Get-PRReportFromRecord {
	param(
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action,
		$out = "",
		$line = 0,
		$Record = ((Get-PRFromRecord $Action) | Sort-Object PR -Unique),
		[switch]$NoClip
	)
	
	$LogContents = (Get-Content $LogFile | ConvertFrom-Csv | Where-Object {$_.Action -notmatch $Action} | ConvertTo-Csv)
	Out-File -FilePath $LogFile -InputObject $LogContents
	#Get everything that doesn't match the action and put it back in the CSV.

	Foreach ($PR in $Record) {
		$line++
		$Title = $PR.Title
		$PR = $PR.PR
		if (!($Title)) {
			$Title = (Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title
		}
		Get-TrackerProgress -PR $PR ("$($MyInvocation.MyCommand) $Action") $line $Record.length
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
	param(
		$Month = (Get-Culture).DateTimeFormat.GetMonthName((Get-Date).Month),
		$Today = (get-date -f MMddyy),
		$ReportName = "$logsFolder\$Month\$Today-Report.txt",
		$HeaderList = ($Actions.Feedback,"Blocking","Waiver","Retry","Manual","Closed","Project","Squash","Approved")
	)
	Write-Host "Generating report for $Today"
	$null | Out-File $ReportName
	$HeaderList | %{
		$_ | Out-File $ReportName -Append;
		Get-PRReportFromRecord $_ -NoClip | Out-File $ReportName -Append
	}
	Write-Host "Report for $Today complete"
}

#Clipboard
Function Get-PRNumber { 
	param(
		$out = (Get-Clipboard),
		[switch]$NoClip,
		[switch]$Hash
	)
	if ($Hash) {
		$out = ($out -split " " | Select-String $hashPRRegex) -replace '#','' | Sort-Object -unique
		$NoClip = $True
	} else {
		$out = $out | Select-String $hashPRRegexEnd | Sort-Object -descending
	}

	if ($NoClip) {
		$out
	} else {
		$out | clip
	}
}

Function Get-SortedClipboard {
	param(
		$out = ((Get-Clipboard) -split "`n")
	)
	$out | Sort-Object -Unique | clip
}

Function Open-AllURL {
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -split " "
	$out = $out | Select-String "`^http"
	$out = $out | Select-String -NotMatch "[.]exe$"
	$out = $out | Select-String -NotMatch "[.]msi$"
	$out = $out | Select-String -NotMatch "[.]zip$"
	$out = $out | Sort-Object -unique
	$out = $out | ForEach-Object {start-process $_}
}

Function Open-PRInBrowser {
	param(
		$PR,
		[Switch]$Files
	)
	$URL = "$GitHubBaseUrl/pull/$PR#issue-comment-box"
	if ($Files) {
		$URL = "$GitHubBaseUrl/pull/$PR/files"
	}
	Start-Process $URL
	Start-Sleep $GitHubRateLimitDelay
}#end Function

Function Get-YamlValue {
	param(
		[string]$StringName,
		$clip = (Get-Clipboard)
	)
	$clip = ($clip -split "`n" | where {$_ -match $StringName})
	$clip = ($clip -split ": ")[1]
	$clip = ($clip -split "#")[0]
	$clip = ((($clip.ToCharArray()) | where {$_ -match "\S"}) -join "")
	Return $clip
}

#Etc
Function Test-Admin {
	if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){Write-Host "Try elevating your session.";break}
}

Function Get-LazySearchWinGet {
#I am out of names and scraping the bottom of the barrel.
	param(
		[String]$SearchTerm,
		[String]$Name,
		[String]$ID,
		$Version,
		$Results = (Find-WinGetPackage $SearchTerm)
	)
	foreach ($Item in ("Name","ID","Version")) {
		If ($Item) {
			$itemContents = (Invoke-Command -ScriptBlock ([Scriptblock]::Create("$"+$item)))
			$Results = $Results | where {$_.$Item -match $itemContents}
		}
	}
	Return $Results
}

Function Get-TrackerProgress {
	param(
		$PR,
		$Activity,
		$Incrementor,
		$Length,
		$Percent = [math]::round($Incrementor / $length*100,2)
	)
	Write-Progress -Activity $Activity -Status "$PR - $Incrementor / $Length = $Percent %" -PercentComplete $Percent
}

Function Get-ArraySum {
	param(
		$in = 0,
		$out = 0
	)
	$in |ForEach-Object{$out += $_*1}
	[math]::Round($out,2)
}

Function Get-GitHubRateLimit {
	param(
		$Url = "https://api.github.com/rate_limit"
	)
	(Get-Date)
	#Time, as a number, constantly increases. 
	$Response = Invoke-WebRequest -Uri $Url -ProgressAction SilentlyContinue
	$Content = $Response.content | ConvertFrom-Json;
	#Write-Output "Headers:"
	#$Response.Headers
	$Content.rate | select @{n="source";e={"Unlogged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds($_.reset)).DateTime.AddHours(-8)}}
	$Response = invoke-GitHubRequest -Uri $Url -JSON;
	$Response.rate | select @{n="source";e={"Logged"}}, limit, used, remaining, @{n="reset";e={([System.DateTimeOffset]::FromUnixTimeSeconds($_.reset)).DateTime.AddHours(-8)}}
}

Function Get-ValidationData {
	param(
		$Property = "",
		$Match = "",
		$data = (Get-Content $DataFileName | ConvertFrom-Csv | Where-Object {$_.$Property} | Where-Object {$_.$Property -match $Match}),
		[switch]$Exact
	)
	if ($Exact -eq $True) {
		$data = $data | Where-Object {$_.$Property -eq $Match}
	}
	Return $data 
}

Function Add-ValidationData {
	param(
		[Parameter(mandatory=$True)][string]$PackageIdentifier,
		[string]$GitHubUserName,
		[ValidateSet("should","must")][string]$authStrictness,
		[ValidateSet("auto","manual")][string]$authUpdateType,
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
	$out = ($data | where {$_.PackageIdentifier -eq $PackageIdentifier} | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","AutoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
	if ($null -eq $out) {
		$out = ( "" | Select-Object "PackageIdentifier","GitHubUserName","authStrictness","authUpdateType","AutoWaiverLabel","versionParamOverrideUserName","versionParamOverridePR","code200OverrideUserName","code200OverridePR","AgreementOverridePR","AgreementURL","reviewText")
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

#PR Watcher Utility functions
Function Get-Sandbox {
#Terminates any current sandbox and makes a new one.
	param(
		[string]$PRNumber = (Get-Clipboard)
	)
	$FirstLetter = $PRNumber[0]
	if ($FirstLetter -eq "#") {
		[string]$PRNumber = $PRNumber[1..$PRNumber.length] -join ""
	}
	Get-Process *sandbox* | ForEach-Object {Stop-Process $_}
	Get-Process *wingetautomator* | ForEach-Object {Stop-Process $_}
	$version = "1.6.1573-preview"
	$process ="wingetautomator://install?pull_request_number=$PRNumber&winget_cli_version=v$version&watch=yes"
	Start-Process -PR $PRocess
}

Function Get-PadRight {
	param(
	[string]$PackageIdentifier,
	[int]$PadChars = 45
	)
	$out = $PackageIdentifier
	if ($PackageIdentifier.Length -lt $PadChars) {
		$out = $PackageIdentifier +(" "*($PadChars - $PackageIdentifier.Length -1))
	} elseif ($PackageIdentifier.Length -lt $PadChars) {
		$out = $PackageIdentifier[0..($PadChars -1)]
	}

	if ($out.GetType().name -eq "Array") {

	}
	$out = $out -join ""

	$out
}

$WordFilterList = "accept_gdpr ", "accept-licenses", "accept-license","eula","downloadarchive.documentfoundation.org","paypal"

$CountrySet = "Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","CÃ¶te D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania"," United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Ã…land Islands"

#Misc Data
$StandardPRComments = ("Validation Pipeline Badge",#Pipeline status
"wingetbot run",#Run pipelines
"azp run",#Run pipelines
"AzurePipelines run",#Run pipelines
"Azure Pipelines successfully started running 1 pipeline",#Run confirmation
"The check-in policies require a moderator to approve PRs from the community",#Validation complete 
"microsoft-github-policy-service agree",#CLA acceptance
"wingetbot waivers Add",#Any waivers
"The pull request encountered an internal error and has been assigned to a developer to investigate",#IEDS or other error
"Manifest Schema Version: 1.4.0 less than 1.5.0 for ID:",#Manifest depreciation for 1.4.0
"This account is bot account and belongs to CoolPlayLin",#CoolPlayLin's automation
"This account is automated by Github Actions and the source code was created by CoolPlayLin",#Exorcism0666's automation
"Poke 👉", #gama-bot's automation
"Response status code does not indicate success",#My automation - removal PR where URL failed status check.
"Automatic Validation ended with",#My automation - Validation output might be immaterial if unactioned.
"Manual Validation ended with",#My automation - Validation output might be immaterial if unactioned.
"No errors to post",#My automation - AutoValLog with no logs.
"The package didn't pass a Defender or similar security scan",#My automation - DefenderFail.
"Installer failed security check",#My automation - AutoValLog DefenderFail.
"Sequence contains no elements",#New Sequence error.
"Missing Properties value based on version",#New property detection.
"Azure Pipelines could not run because the pipeline triggers exclude this branch/path"#Pipeline error.
)

#VM Window Management
Function Get-TrackerVMWindowLoc {
	param(
		$VM,
		$Rectangle = (New-Object RECT),
		$VMProcesses = (Get-Process vmconnect),
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match "vm$VM"}).MainWindowHandle
	)
	[window]::GetWindowRect($MWHandle,[ref]$Rectangle)
	Return $Rectangle
}

Function Get-TrackerVMWindowSet {
	param(
		$VM,
		$Left,
		$Top,
		$Right,
		$Bottom,
		$VMProcesses = (Get-Process vmconnect),
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match "vm$VM"}).MainWindowHandle
	)
	$null = [window]::MoveWindow($MWHandle,$Left,$Top,$Right,$Bottom,$True)
}

Function Get-TrackerVMWindowArrange {
	param(
		$VMs = (Get-Status |where {$_.status -ne "Ready"}|where {$_.status -ne "ImagePark"}).vm 
	)
	If ($VMs) {
		Get-TrackerVMWindowSet $VMs[0] 900 0 1029 860
		$Base = Get-TrackerVMWindowLoc $VMs[0]
		
		For ($n = 1;$n -lt $VMs.count;$n++) {
			$VM = $VMs[$n]
			
			$Left = ($Base.left - (100 * $n))
			$Top = ($Base.top + (66 * $n))
			Get-TrackerVMWindowSet $VM $Left $Top 1029 860
		}
	}
}


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



#Index of each column name is where prev column ends and this one starts.