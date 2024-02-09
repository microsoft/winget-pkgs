#Copyright 2022-2024 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v3.26.11
#Created: 10/19/2022
#Updated: 2/8/2024
#Notes: Utilities to streamline evaluating 3rd party PRs.
#Update log:
#3.26.11 - Bugfixes to last version remaining check in PR Watcher.
#3.26.10 - Have Manual Validation not open MSEdge before scan, and modify to close more after.
#3.26.9 - Bugfix readd Get-SharedError functionality to VM Orchestration.
#3.26.8 - Change log wording from "version" to "build".
#3.26.7 - Add another place to check for Internal-Error-Manifest labels.
#3.26.6 - Modify IEDS call in Add-Waiver to avoid accidentally adding Validation-Complete and a waiver at the same time.
#3.26.5 - Change Add-PRToRecord Action parameters from positional to tagged.
#3.26.4 - Update Add-PRToRecord with PR Title collection, to reduce reporting API calls.
#3.26.3 - Add title collection parameter to reporting tools.

$build = 720
$appName = "Manual Validation"
Write-Host "$appName build: $build"
$MainFolder = "C:\ManVal"
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.
Set-Location $MainFolder

$ipconfig = (ipconfig)
$remoteIP = ([ipaddress](($ipconfig[($ipconfig | Select-String "vEthernet").LineNumber..$ipconfig.length] | Select-String "IPv4 Address") -split ": ")[1]).IPAddressToString
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
$LogFile = "$MainFolder\misc\ApprovedPRs.txt"
$PeriodicRunLog = "$MainFolder\misc\PeriodicRunLog.txt"
$SharedErrorFile = "$writeFolder\err.txt"
$WaiverFile = "C:\repos\winget-pkgs\Tools\Waiver.csv"

$Win10Folder = "$imagesFolder\Win10-Created010424-Original"
$Win11Folder = "$imagesFolder\Win11-Created030623-Original\"

$Owner = "microsoft"
$Repo = "winget-pkgs"
$GitHubBaseUrl = "https://github.com/$Owner/$Repo"
$GitHubContentBaseUrl = "https://raw.githubusercontent.com//$Owner/$Repo"
$GitHubApiBaseUrl = "https://api.github.com/repos/$Owner/$Repo"
$ADOMSBaseUrl = "https://dev.azure.com/ms"

$CheckpointName = "Validation"
$VMUserName = "user" #Set to the internal username you're using in your VMs.
$GitHubUserName = "stephengillie"
$SystemRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).sum /1gb
$Host.UI.RawUI.WindowTitle = "Utility"
$GitHubRateLimitDelay = 0.5 #seconds

$PRRegex = "[0-9]{5,6}"
$hashPRRegex = "[#]"+$PRRegex
$hashPRRegexEnd = $hashPRRegex+"$"
$colonPRRegex = $PRRegex+"[:]"

#First tab
Function Get-TrackerVMRunTracker {
	$HourLatch = $False
	while ($True) {
		$Host.UI.RawUI.WindowTitle = "Orchestration"
		#Run once an hour at ~20 after.
		if (([int](get-date -f mm) -eq 20)) {
			$HourLatch = $True
		}
		if ($HourLatch) {
			$HourLatch = $False
			[console]::beep(500,250);[console]::beep(500,250);[console]::beep(500,250) #Beep 3x to alert the PC user.
			$PresetList = ("Defender","ToWork")
			$Host.UI.RawUI.WindowTitle = "Periodic Run"
			(Get-SearchGitHub -Preset IEDS).number | Get-Random |%{Get-PRLabelAction $_} #Restart an IEDS PR
			foreach ($Preset in $PresetList) {
				$Results = (Get-SearchGitHub -Preset $Preset -Days 1 -NotWorked)
				Write-Output "$(Get-Date -Format T) Starting $Preset with $($Results.length) Results"
				if ($Results) {
					$Results.number |%{Get-PRLabelAction $_}
				}
				Write-Output "$(Get-Date -Format T) Completing $Preset with $($Results.length) Results"
			}
			sleep (60-(get-date -f ss))#Sleep out the minute.
		}
		
		Clear-Host
		$GetStatus = Get-Status
		$GetStatus | Format-Table;
		$VMRAM = Get-ArraySum $GetStatus.RAM
		$ramColor = "green"
		$valMode = Get-TrackerMode

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
		Write-Host -nonewline "Build: $build - Hours worked: "
		Write-Host -f $timeClockColor (Get-HoursWorkedToday)
		(Get-VM) | ForEach-Object {
			if(($_.MemoryDemand / $_.MemoryMaximum) -ge 0.9){
				set-vm -VMName $_.name -MemoryMaximumBytes "$(($_.MemoryMaximum / 1073741824)+2)GB"
			}
		}
		$status = Get-Status
		$status |ForEach-Object {$_.RAM = [math]::Round((Get-VM -Name ("vm"+$_.vm)).MemoryAssigned/1024/1024/1024,2)}
		Write-Status $status
		Get-TrackerVMCycle;
		Get-TrackerVMWindowArrange

		if ($valMode -eq "IEDS") {
			if ((Get-ArraySum (Get-Status).RAM) -lt ($SystemRAM*.42)) {
			Write-Output $valMode
				Get-RandomIEDS
			}
		}

		$clip = (Get-Clipboard)
		If ($clip -match $ADOMSBaseUrl) {
			Write-Output "Gathering Automated Validation Logs"
			Get-AutoValLog
		} elseIf ($clip -match "Skip to content") {
			if ($valMode -eq "Validating") {
				Write-Output $valMode
				Get-TrackerVMValidate;
				$valMode | clip
			}
		} elseIf ($clip -match " Windows Package Manager") {#Package Manager Dashboard
			Write-Output "Gathering PR Headings"
			Get-PRNumber
		} elseIf ($clip -match "^manifests`/") {
			Write-Output "Opening manifest file"
			$ManifestUrl = "$GitHubBaseUrl/tree/master/"+$clip
			$ManifestUrl | clip
			start-process ($ManifestUrl)
		}
		if (Get-ConnectedVM) {
			#Get-TrackerVMResetStatus
		} else {
			Get-TrackerVMRotate
		}
		Start-Sleep 5;
	}
}

#Second tab
Function Get-PRWatch {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		[ValidateSet("Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","Cöte D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania, United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Åland Islands")]$Chromatic = "Default",
		$LogFile = ".\PR.txt",
		$AuthFile = ".\Auth.csv",
		$ReviewFile = ".\Review.csv",
		$oldclip = "",
		$AuthList = "",
		$ReviewList = "",
		$Count = 30
	)
	$Host.UI.RawUI.WindowTitle = "PR Watcher"#I'm a PR Watcher, watchin PRs go by. 
	if ((Get-Command Get-TrackerVMSetMode).name) {Get-TrackerVMSetMode "Approving"}

	$AuthList = Get-LoadFileIfExists $AuthFile
	$ReviewList = Get-LoadFileIfExists $ReviewFile

	Write-Host "| Timestmp | $(Get-PadRight PR# 6) | $(Get-PadRight PackageIdentifier) | $(Get-PadRight prVersion 15) | A | R | W | F | I | D | V | $(Get-PadRight ManifestVer 14) | OK |"
	Write-Host "| -------- | ----- | ------------------------------- | -------------- | - | - | - | - | - | - | - | ------------- | -- |"

	while($Count -gt 0){
		$clip = (Get-Clipboard)
		$PRtitle = $clip | Select-String ($hashPRRegexEnd);
		$PR = ($PRtitle -split "#")[1]
		if ($PRtitle) {
			if (Compare-Object $PRtitle $oldclip) {
				if ((Get-Command Get-Status).name) {
					(Get-Status | Where-Object {$_.status -eq "ValidationComplete"} | Format-Table)
				}
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
				$AuthAccount = 

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





				Write-Host -nonewline -f $matchColor "| $(Get-Date -Format T) | $PR | $(Get-PadRight $PackageIdentifier) | "

				#Variable effervescence
				$prAuth = "+"
				$Auth = "A"
				$Review = "R"
				$WordFilter = "W"
				$AnF = "F"
				$InstVer = "I"
				$ListingDiff = "D"
				$NumVersions = 999
				$PRvMan = "P"
				$Approve = "+"

				$WinGetOutput = Find-WinGetPackage $PackageIdentifier | Where-Object {$_.id -eq $PackageIdentifier}
				$ManifestVersion = $WinGetOutput.version
				$ManifestVersionParams = ($ManifestVersion -split "[.]").count
				$prVersionParams = ($prVersion -split "[.]").count


				$AuthMatch = $AuthList | Where-Object {$_.PackageIdentifier -match (($PackageIdentifier -split "[.]")[0..1] -join ".")}

				if ($AuthMatch) {
					$AuthAccount = $AuthMatch.account | Sort-Object -Unique
				}

				if ($null -eq $WinGetOutput) {
					$PRvMan = "N"
					$matchColor = $invalidColor
					$Approve = "-!"
					if ($noNew) {
						$noRecord = $True
					} else {
						if ($title[-1] -match $hashPRRegex) {
							if ((Get-Command Get-TrackerVMValidate).name) {
								Get-TrackerVMValidate -Silent -InspectNew
							} else {
								Get-Sandbox ($title[-1] -replace"#","")
							}; #end if Get-Command
						}; #end if title
					}; #end if noNew
				} elseif ($null -ne $WinGetOutput) {
					If ($PRtitle -match " [.]") {
					#If has spaces (4.4 .5 .220)
						$Body = "Spaces detected in version number."
						$Body = $Body + "`n`n(Automated response - build $build)"
						Invoke-GitHubPRRequest -PR $PR -Method Post -Type comments -Data $Body -Output Silent
						$matchColor = $invalidColor
						$prAuth = "-!"
					}
					if (($ManifestVersionParams -ne $PRVersionParams) -AND (($PRtitle -notmatch "Automatic deletion") -AND ($PRtitle -notmatch "Delete") -AND ($PRtitle -notmatch "Delete") -AND ($PRtitle -notmatch "Remove") -AND ($AuthAccount -cnotmatch $Submitter))) {
						$greaterOrLessThan = ""
						if ($prVersionParams -lt $ManifestVersionParams) {
							#If current manifest has more params (dots) than PR (2.3.4.500 to 2.3.4)
							$greaterOrLessThan = "less"
						} elseif ($prVersionParams -gt $ManifestVersionParams) {
							#If current manifest has fewer params (dots) than PR (2.14 to 2.14.3.222)
							$greaterOrLessThan = "greater"
						}
						$matchColor = $invalidColor
						$Body = "Hi @$Submitter,`n`n> This PR's version number $PRVersion has $PRVersionParams parameters (sets of numbers between dots - major, minor, etc), which is $greaterOrLessThan than the current manifest's version $($ManifestVersion), which has $ManifestVersionParams parameters.`n`nDoes this PR's version number **exactly** match the version reported in the `Apps & features` Settings page? (Feel free to attach a screenshot.)"
						$Approve = "-!"
						$Body = $Body + "`n`n(Automated response - build $build)"
						Invoke-GitHubPRRequest -PR $PR -Method Post -Type comments -Data $Body -Output Silent 
						$null = Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Author-Feedback
						Add-PRToRecord -PR $PR -Action "Feedback" -Title $PRtitle
					}
				}
				Write-Host -nonewline -f $matchColor "$(Get-PadRight $PRVersion.toString() 14) | "
				$matchColor = $validColor





				if ($AuthMatch) {
					$strictness = $AuthMatch.strictness | Sort-Object -Unique
					$matchVar = ""
					$matchColor = $cautionColor
					if ($AuthAccount -cmatch $Submitter) {
						$matchVar = "matches"
						$Auth = "+"
						$matchColor = $validColor





					} else {
						$matchVar = "does not match"
						$Auth = "-"
						$matchColor = $invalidColor
					}

					if ($strictness -eq "must") {
						$Auth += "!"
					} else {
					}
				}
				if ($Auth -eq "-!") {
						Get-PRApproval -PR $PR -PackageIdentifier $PackageIdentifier
				}
				Write-Host -nonewline -f $matchColor "$Auth | "
				$matchColor = $validColor





				$ReviewMatch = $ReviewList | Where-Object {$_.PackageIdentifier -match (($PackageIdentifier -split "[.]")[0..1] -join ".")}

				if ($ReviewMatch) {
					$Review = $ReviewMatch.Reason | Sort-Object -Unique
					$matchColor = $cautionColor
				}
				Write-Host -nonewline -f $matchColor "$Review | "
				$matchColor = $validColor





				#$WordFilterList = @(".bat", ".ps1", ".cmd","accept_gdpr ", "accept-licenses", "accept-license","eula")
				$WordFilterMatch = $WordFilterList | ForEach-Object {($Clip -match $_) -notmatch "Url"}

				if ($WordFilterMatch) {
					$WordFilter = "-!"
					$Approved = "-!"
					$matchColor = $invalidColor
					Reply-ToPR -PR $PR -CannedResponse WordFilter -UserInput $WordFilterMatch -Silent
				}
				Write-Host -nonewline -f $matchColor "$WordFilter | "
				$matchColor = $validColor





				

				if ($null -ne $WinGetOutput) {
					if (($PRvMan -ne "N") -AND (($PRtitle -notmatch "Automatic deletion") -AND ($PRtitle -notmatch "Delete") -AND ($PRtitle -notmatch "Remove"))) {
						$ANFOld = Get-ManifestEntryCheck -PackageIdentifier $PackageIdentifier -Version $ManifestVersion
						$ANFCurrent = [bool]($clip | Select-String "AppsAndFeaturesEntries")

						if (($ANFOld -eq $True) -and ($ANFCurrent -eq $False)) {
							$matchColor = $invalidColor
							$AnF = "-"
							Reply-ToPR -PR $PR -CannedResponse AppsAndFeaturesMissing -UserInput $Submitter -Silent
							Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
							Add-PRToRecord -PR $PR -Action "Feedback" -Title $PRtitle
						} elseif (($ANFOld -eq $False) -and ($ANFCurrent -eq $True)) {
							$matchColor = $cautionColor
							$AnF = "+"
							Reply-ToPR -PR $PR -CannedResponse AppsAndFeaturesNew -UserInput $Submitter -Silent
							#Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback"
						} elseif (($ANFOld -eq $False) -and ($ANFCurrent -eq $False)) {
							$AnF = "0"
						} elseif (($ANFOld -eq $True) -and ($ANFCurrent -eq $True)) {
							$AnF = "1"
						}
					}
				}
				Write-Host -nonewline -f $matchColor "$AnF | "
				$matchColor = $validColor





				if (($PRvMan -ne "N") -OR ($PRtitle -notmatch "Automatic deletion") -OR ($PRtitle -notmatch "Delete") -AND ($PRtitle -notmatch "Remove")) {
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





				if (($PRvMan -ne "N") -AND (($PRtitle -match "Automatic deletion") -OR ($PRtitle -match "Delete") -OR ($PRtitle -match "Remove"))) {#Removal PR
					$Versions = Get-ManifestListing  -PackageIdentifier $PackageIdentifier  -Version 0 -Versions
					$NumVersions = $Versions.count
					if (($prVersion -eq $Versions[-1]) -OR ($NumVersions -eq 1)) {
						$matchColor = $invalidColor
						Reply-ToPR -PR $PR -CannedResponse VersionCount -UserInput $Submitter -Silent
						Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
						Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Last-Version-Remaining" -Output Silent
						Add-PRToRecord -PR $PR -Action "Feedback" -Title $PRtitle
						$NumVersions = "L"
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
							Reply-ToPR -PR $PR -CannedResponse ListingDiff -UserInput $GLD -Silent
							Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Needs-Author-Feedback" -Output Silent
							Add-PRToRecord -PR $PR -Action "Feedback" -Title $PRtitle
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
				($ListingDiff -eq "-!") -or 
				($NumVersions -eq 1) -or 
				($NumVersions -eq "L") -or 
				($WordFilter -eq "-!") -or 
				($PRvMan -eq "N")) {
				#-or ($PRvMan -match "^Error")
					$matchColor = $cautionColor
					$Approve = "-!"
					$noRecord = $True
				}

				$PRvMan = Get-PadRight $PRvMan 14
				Write-Host -nonewline -f $matchColor "$PRvMan | "
				$matchColor = $validColor





				if ($Approve -eq "+") {
					$Approve = Approve-PR -PR $PR
					Add-PRToRecord -PR $PR -Action "Approved" -Title $PRtitle
				}

				Write-Host -nonewline -f $matchColor "$Approve | "
				Write-Host -f $matchColor ""

				$oldclip = $PRtitle
			}; #end if Compare-Object
		}; #end if clip
		Start-Sleep 1
	}; #end if PRtitle
	$Count--
}; #end function

#Third tab
Function Get-WorkSearch {
	param(
		$PresetList = @("Approval","Defender","ToWork"),
		$Days = 7
	)
	Foreach ($Preset in $PresetList) {
		$Count= 30
		$Page = 0
		While ($Count -eq 30) {
			$PRs = (Get-SearchGitHub -Preset $Preset -Page $Page) | where {$_ -notin (Get-Status).pr} 
			$Count = $PRs.length
			Write-Output "$(Get-Date -f T) $Preset Page $Page beginning with $Count Results"

			Foreach ($FullPR in $PRs) {
				$PR = $FullPR.number
				$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content)
				if(
				(($FullPR.title -replace ":","" -split " ")[0] -ceq "Remove") -OR 
				(($FullPR.title -replace ":","" -split " ")[0] -ceq "Delete") -OR 
				((($FullPR.title -replace ":","" -split " ")[0..1] -join " ") -ceq "Automatic deletion") 
				){
					Get-GitHubPreset CheckInstaller -PR $PR
				}
				if ($Preset -eq "Approval"){
					if (Get-NonstandardPRComments -PR $PR -comments $Comments.body){
						Open-PRInBrowser -PR $PR
					} else {
						Open-PRInBrowser -PR $PR -FIles
					}
				} else {
					Open-PRInBrowser -PR $PR
					$Comments = ($Comments | select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
					$State = (Get-PRStateFromComments -PR $PR -Comments $Comments)
					$LastState = $State[-1]
					if ($LastState.event -eq "LabelAction") { 
						Get-GitHubPreset -Preset LabelAction -PR $PR
					} elseif (($State[-2].event -eq "AutoValFail") -AND ($LastState.event -eq "DefenderFail") -AND ($LastState.created_at -lt (Get-Date).AddHours(-18))) { 
						Get-GitHubPreset -Preset Retry -PR $PR
					} else {
					}#end if LastCommenter
				}#end if Preset
			}#end foreach FullPR
			#Get-PRWatch -LogFile C:\ManVal\misc\ApprovedPRs.txt -AuthFile C:\repos\winget-pkgs\Tools\Auth.csv -ReviewFile C:\repos\winget-pkgs\Tools\Review.csv -Chromatic Random -Count $Count
			Read-Host "$(Get-Date -f T) $Preset Page $Page complete with $Count Results - press ENTER to continue..."
			$Page++
		}#end While Count
	}#end Foreach Preset
}#end Function

#Automation tools
Function Get-GitHubPreset {
	param(
		[ValidateSet("Approved","AutomationBlock","BadPR","Blocking","ChangesRequested","CheckInstaller","Closed","DefenderFail","Feedback","IdleMode","IEDSMode","InstallerNotSilent","InstallerMissing","LabelAction","MergeConflicts","NetworkBlocker","OneManifestPerPR","PackageUrl","Project","Retry","Squash","Timeclock","Validating","VedantResetPR","WorkSearch","Waiver")][string]$Preset,
		$PR = (Get-Clipboard),
		$CannedResponse = $Preset,
		$Label,
		[Switch]$Force,
		$out = ""
	)
	if ($Preset -eq "GitHubStatus") {$Force = $True}
	if ($Preset -eq "IdleMode") {$Force = $True}
	if ($Preset -eq "IEDSMode") {$Force = $True}
	if ($Preset -eq "Timeclock") {$Force = $True}
	if ($Preset -eq "Validating") {$Force = $True}
	if ($Preset -eq "WorkSearch") {$Force = $True}
 	
	if (($PR.ToString().length -eq 6) -OR $Force) {
		Switch ($Preset) {
			"Approved" {
				$out += Approve-PR -PR $PR; 
				Add-PRToRecord -PR $PR -Action $Preset
			}
			"AutomationBlock" {
				Add-PRToRecord -PR $PR -Action "Blocking"
				$out += Reply-ToPR -PR $PR -CannedResponse AutomationBlock -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Network-Blocker
			}
			"Blocking" {
				Add-PRToRecord -PR $PR -Action "Blocking"
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Blocking-Issue
			}
			"ChangesRequested" {
				Add-PRToRecord -PR $PR -Action "Feedback"
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Author-Feedback
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Changes-Requested
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
					#$out = $out += Get-GitHubPreset InstallerMissing -PR $PR 
				#} #Need this to only take action on new PRs, not removal PRs.
				$out = $out += Invoke-GitHubPRRequest -PR $PR -Method Post -Type comments -Data $Body -Output StatusDescription 
			}
			"Closed" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += $Preset; 
			}
			"DefenderFail" {
				Add-PRToRecord -PR $PR -Action "Blocking"
				$out += Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Attention
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Validation-Defender-Error
			}
			"Feedback" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out = $out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data
			}
			"GitHubStatus" {
				return (Invoke-GitHubRequest -Uri https://www.githubstatus.com/api/v2/summary.json -JSON) | Select-Object @{n="Status";e={$_.incidents[0].status}},@{n="Message";e={$_.incidents[0].name+" ("+$_.incidents.count+")"}}
				#$out += $Preset; 
			}
			"IEDSMode" {
				Get-TrackerVMSetMode IEDS
				$out += $Preset; 
			}
			"IdleMode" {
				Get-TrackerVMSetMode Idle
				$out += $Preset; 
			}
			"InstallerNotSilent" {
				Add-PRToRecord -PR $PR -Action "Feedback"
				$out += Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Author-Feedback
			}
			"InstallerMissing" {
				Add-PRToRecord -PR $PR -Action "Feedback"
				$out += Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Author-Feedback
			}
			"LabelAction" {
				Get-PRLabelAction -PR $PR
				$out += $Preset; 
			}
			"MergeConflicts" {
				Add-PRToRecord -PR $PR -Action "Closed"
				$out += Reply-ToPR -PR $PR -Body "Merge Conflicts."
			}
			"NetworkBlocker" {
				Add-PRToRecord -PR $PR -Action "Blocking"
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Network-Blocker
			}
			"OneManifestPerPR" {
				Add-PRToRecord -PR $PR -Action "Feedback"
				$out += Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Author-Feedback
			}
			"PackageUrl" {
				Add-PRToRecord -PR $PR -Action "Feedback"
				$out += Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login)
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Changes-Requested
			}
			"Project" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += $Preset; 
			}
			"Retry" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += Invoke-GitHubPRRequest -PR $PR -Type comments -Output StatusDescription -Method POST -Data "/AzurePipelines run"
			}
			"Squash" {
				Add-PRToRecord -PR $PR -Action $Preset
				$out += $Preset; 
			}
			"Timeclock" {
				Get-TimeclockSet
				$out += $Preset; 
			}
			"Validating" {
				Get-TrackerVMSetMode Validating
				$out += $Preset; 
			}
			"VedantResetPR" {
				Add-PRToRecord -PR $PR -Action "Closed"
				$out += Reply-ToPR -PR $PR -Body "Reset PR."
				$out += Invoke-GitHubPRRequest -PR $PR -Type assignees -Method DELETE -Data (Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login
				$out += Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data -Method DELETE
			}
			"Waiver" {
				$out += Add-Waiver -PR $PR; 
				Add-PRToRecord -PR $PR -Action $Preset
			}
			"WorkSearch" {
				Get-WorkSearch
				$out += $Preset; 
			}
		}
	} else {
		$out += "Error: $($PR[0..10])"
	}
	Write-Output "PR $($PR): $out"
}

Function Get-PRLabelAction {
	param(
	[int]$PR,
	$Labels = ((Invoke-GitHubPRRequest -PR $PR -Type labels -Output content -JSON).name)
	)
	Write-Output "PR $PR has labels $Labels"
	Foreach ($Label in $Labels) {
		Switch ($Label) {
			"Binary-Validation-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -SearchString "Installer Verification Analysis Context Information:" -length 10
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
				if ($UserInput -match "BlockingDetectionFound") {
					Get-GitHubPreset -PR $PR -Preset AutomationBlock
				}
			}
			"Error-Analysis-Timeout" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 36 -SearchString "Installer Verification Analysis Context Information:" -length 3
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
				if ($UserInput -match "BlockingDetectionFound") {
					Get-GitHubPreset -PR $PR -Preset AutomationBlock
				}
			}
			"Error-Hash-Mismatch" {
				$UserInput = Get-LineFromCommitFile -PR $PR -SearchString "Actual hash" -Length 1 
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 26 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 36 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 37 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 50 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -match "Actual hash") {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
					Get-UpdateHashInPR2 -PR $PR -Clip $UserInput
				}
			}
			"Error-Installer-Availability" {
				$UserInput = Get-LineFromCommitFile -PR $PR -SearchString "Installer Verification Analysis Context Information:" -length 5
				Get-GitHubPreset -PR $PR -Preset CheckInstaller
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Internal-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 15 -SearchString "[error] One or more errors occurred."
				}
				if ($UserInput) {
					if ($UserInput -match "SQL error or missing database") {
						Get-GitHubPreset -PR $PR Retry
					}
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Internal-Error-Dynamic-Scan" {
				Get-GitHubPreset Retry -PR $PR
			}
			"Internal-Error-Manifest" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 15 -SearchString "[error] One or more errors occurred."
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "Processing manifest" -length 7
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 39 -SearchString "Processing manifest" -length 7
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
					if ($UserInput -match "Sequence contains no elements") {
						Reply-ToPR -PR $PR SequenceNoElements
						$PRtitle = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title)
						if (($PRtitle -match "Automatic deletion") -OR ($PRtitle -match "Remove")) {
							Invoke-GitHubPRRequest -PR $PR -Method PUT -Type labels -Data "Validation-Completed"
						}
					}
				}
			}
			"Internal-Error-URL" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				if ($UserInput) {
					if ($UserInput -match "SQL error or missing database") {
						Get-GitHubPreset -PR $PR Retry
					}
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Manifest-AppsAndFeaturesVersion-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] Manifest Error:"
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 15 -SearchString "[error] Manifest Error:"
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 39 -SearchString "[error] Manifest Error:"
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Manifest-Installer-Validation-Error" {
				Reply-ToPR -PR $PR -UserInput ((Get-ADOLog -PR $PR -Log 25)[60]) -CannedResponse AutoValEnd
			}
			"Manifest-Validation-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] Manifest Error:"
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 31 -SearchString "[error] Manifest Error:"
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 31 -SearchString "[error] One or more errors occurred."
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 44 -SearchString "[error] Manifest Error:"
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 44 -SearchString "[error] One or more errors occurred."
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Possible-Duplicate" {
				$Pull = (Invoke-GitHubPRRequest -PR $PR -Type files -Output content -JSON)
				$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[0] -JSON).content))
				$Url = (Get-YamlValue -StringName InstallerUrl -clip $PullInstallerContents)
				$PackageIdentifier = (Get-YamlValue -StringName PackageIdentifier -clip $PullInstallerContents)
				$Version = (Find-WinGetPackage $PackageIdentifier | where {$_.ID -eq $PackageIdentifier}).Version
				$out = ($PullInstallerContents -match $Version)
				$UserInput = $out | where {$_ -match "http"} | where {$_ -notmatch "json"} 
				if ($UserInput) {
					$UserInput = "InstallerUrl contains Manifest version instead of PR version:`n"+$UserInput + "`n`n(Automated message - build $build)"
					Reply-ToPR -PR $PR -Body $UserInput
					Get-GitHubPreset Feedback -PR $PR
				}
			}
			"PullRequest-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 24 -SearchString "[error] One or more errors occurred."
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 14 -SearchString "[error] One or more errors occurred."
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 27 -SearchString "[error] One or more errors occurred."
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"URL-Validation-Error" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 32 -SearchString "Validation result: Failed"
				Get-GitHubPreset -PR $PR -Preset CheckInstaller
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Validation-Domain" {
			}
			"Validation-Defender-Error" {
				$Line = 0
				Foreach ($PR in $PRs) {
					$Line++
					Get-TrackerProgress -PR $PR $MyInvocation.MyCommand $Line $PRs.length
					$comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content)
					if ($comments) {
						if (($comments[-2].body -match "This might be a false positive and we can rescan tomorrow.") -and
						([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($comments[-2].created_at, 'Pacific Standard Time') -lt (Get-Date).AddHours(-18)) -and
						($comments[-1].body -match "Installer failed security check") -and
						([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($comments[-1].created_at, 'Pacific Standard Time') -lt (Get-Date).AddHours(-18))) {
							#If the last 2 comments were automated virus detection, and made more than 18 hours ago. 18 instead of 24 because this handles someone who worked on this at the end of one 8-hour workday and the start of the next.
							Get-GitHubPreset Retry -PR $PR
						} else {
							Open-PRInBrowser -PR $PR
						}#end if comments inner
					}#end if comments outer
				}#end foreach PR
			}
			"Validation-Executable-Error" {
				Get-AutoValLog -PR $PR
			}
			"Validation-Hash-Verification-Failed" {
				Get-AutoValLog -PR $PR
			}
			"Validation-Missing-Dependency" {
				$UserInput = Get-LineFromCommitFile -PR $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Validation-Merge-Conflict" {
			}
			"Validation-No-Executables" {
				$Title = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title);
				foreach ($Waiver in (Get-LoadFileIfExists $WaiverFile)) {
					if ($Title -match $Waiver.PackageIdentifier) {
						Get-GitHubPreset -PR $PR Waiver
					}
				}
			}
			"Validation-Installation-Error" {
				Get-AutoValLog -PR $PR
			}
			"Validation-Shell-Execute" {
				Get-AutoValLog -PR $PR
			}
			"Validation-Unattended-Failed" {
				Get-AutoValLog -PR $PR
			}
		}
	}
}

Function Add-Waiver {
	param(
	$PR,
	$Labels = ((Invoke-GitHubPRRequest -PR $PR -Type "labels" -Output content -JSON).name)
	)
	Foreach ($Label in $Labels) {
		$Waiver = ""
		Switch ($Label) {
			"Error-Analysis-Timeout" {
				Invoke-GitHubPRRequest -PR $PR -Method PUT -Type labels -Data "Validation-Completed" 
				Add-PRToRecord -PR $PR -Action "Manual"
				$Waiver = $Label
			}
			"Policy-Test-2.3" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Completed" {
				Get-GitHubPreset -Preset Approved -PR $PR
			}
			"Validation-Domain" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Executable-Error" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Forbidden-URL-Error" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Installation-Error" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-No-Executables" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Shell-Execute" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Unattended-Failed" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Validation-Unapproved-URL" {
				Add-PRToRecord -PR $PR -Action "Waiver"
				$Waiver = $Label
			}
			"Internal-Error-Dynamic-Scan" {
				Invoke-GitHubPRRequest -PR $PR -Method PUT -Type labels -Data "Validation-Completed"
				Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data "Retry-1"
				Add-PRToRecord -PR $PR -Action "Manual"
			}
		}
		if ($Waiver -ne "") {
			$out = Invoke-GitHubPRRequest -PR $PR -Type comments -Output StatusDescription -Method POST -Data "@wingetbot waivers Add $Waiver"
			Write-Output $out
		}; #end if Waiver
	}; #end Foreach Label
}; #end Function

Function Get-SearchGitHub {
	param(
		[ValidateSet("Approval","AutomaticWaiverAddition","Blocking","Created","Duplicate","Defender","IEDS","Incomplete","IEM","Label","NA","NAF","NANoIEDS","None","PrePipeline","Problematic","Squash","ToWork","ToWork2","User","VCNA")][string]$Preset = "Approval",
		[Switch]$Browser,
		$Url = "https://api.github.com/search/issues?page=$Page&q=",
		$Author, #wingetbot
		$Commenter, #wingetbot
		$Title,
		[string]$Label, #[ValidateSet("Error-Analysis-Timeout","Unexpected-File","Needs-CLA","Error-Analysis-Timeout")]
		$Page = 1,
		[int]$Days,
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
		$Base = $Base + "is:open+"
	}
	$Base = $Base + "draft:false+"

	#Smaller blocks
	$nApproved = "-label:Moderator-Approved+"
	$nBI = "-label:Blocking-Issue+"
	$Defender = "label:Validation-Defender-Error"
	$HaventWorked = "-commenter:$($GitHubUserName)+"
	$nHW = "-label:Hardware+"
	$IEDSLabel = "label:Internal-Error-Dynamic-Scan+"
	$nIEDS = "-"+$IEDSLabel
	$IEM = "label:Internal-Error-Manifest+"
	$nIOI = "-label:Interactive-Only-Installer+"
	$NA = "label:Needs-Attention+" 
	$NAF = "label:Needs-Author-Feedback+" 
	$NotPass = "-label:Azure-Pipeline-Passed+" #Hasn't psased pipelines
	$SortUp = "sort:updated-asc+"
	$VC = "label:Validation-Completed+" #Completed
	$nVC = "-"+$VC #Completed
	$nNSA = "-label:Internal-Error-NoSupportedArchitectures+"
	
	$date = Get-Date (Get-Date).AddDays(-$Days) -Format "yyyy-MM-dd"
	$Recent = "created:>$($date)+" #Created in the past week.
	
	#-assignee:vedantmgoyal2009 
	
	#Building block settings
	$Blocking = $nHW
	$Blocking = $Blocking + $nNSA
	$Blocking = $Blocking + "-label:License-Blocks-Install+"
	$Blocking = $Blocking + "-label:Network-Blocker+"
	$Blocking = $Blocking + "-label:portable-jar+"
	$Blocking = $Blocking + "-label:Project-File+"
	$Blocking = $Blocking + "-label:Reboot+"
	$Blocking = $Blocking + "-label:Scripted-Application+"
	$Blocking = $Blocking + "-label:WindowsFeatures+"
	$Blocking = $Blocking + "-label:zip-binary+"
		
	$Common = $nBI
	$Common = $Common + "-label:Internal-Error-Manifest+"
	$Common = $Common + "-label:Validation-Defender-Error+"

	$Cna = $VC 
	$Cna = $Cna+ $nApproved
	
	$Review1 = "-label:Changes-Requested+" 
	$Review1 = $Review1 + "-label:Needs-CLA+"
	$Review1 = $Review1+ "-label:No-Recent-Activity+"

	$Review2 = "-label:Needs-Attention+"
	$Review2 = $Review2 + "-label:Needs-Author-Feedback+"
	$Review2 = $Review2 + "-label:Needs-Review+"
	
	$Workable = "-label:Possible-Duplicate+" 
	$Workable = $Workable + "-label:Validation-Merge-Conflict+" 
	$Workable = $Workable + "-label:Unexpected-File+"
	
	#Composite settings
	$Set1 = $Blocking + $Common + $Review1
	$Set2 = $Set1 + $Review2

	$Url = $Url + $Base
	if ($Author) {
		$Url = $Url + "author:$($Author)+"
	}
	if ($Commenter) {
		$Url = $Url + "commenter:$($Commenter)+"
	}
	if ($Days) {
		$Url = $Url + $Recent
	}
	if ($IEDS) {
		$Url = $Url + $nIEDS
	}
	if ($Label) {
		$Url = $Url + "label:$(Label)+"
	}
	if ($NotWorked) {
		$Url = $Url + $HaventWorked
	}
	if ($Title) {
		$Url = $Url + "$Title in:title"
	}

	switch ($Preset) {
		"Approval"{
			$Url = $Url + $Cna
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + $Workable
			}
	"AutomaticWaiverAddition" {
$Url = $Url + "'Waiver Addition'"
	}
		"Blocking" {
			$Url = $Url + $nBI
			$Url = $Url + $nIOI
			$Url = $Url + $nHW
		}
		"Created"{
			$Url = $Url + $Recent
			$Url = $Url + $Set1 #Blocking + Common + Review1 #Blocking + Common + Review1
		}
		"Duplicate"{
			$Url = $Url + "label:Possible-Duplicate+"
			$Url = $Url + $Common
			$Url = $Url + $Cna
		}
		"Defender"{
			$PastDay = Get-Date (Get-Date).AddDays(-1) -Format "yyyy-MM-dd"
			$Url = $Url + "updated:<$($PastDay)+" #Created in the past week.
			$Url = $Url + $nBI
			$Url = $Url + "-"+$IEM
			$Url = $Url + $Defender
		}
	"IEDS" {
		$Url = $Url + $IEDSLabel
		$Url = $Url + $nBI
		$Url = $Url + $Blocking
		$Url = $Url + $NotPass
		$Url = $Url + $nVC
	}
		"IEM"{				
			$Url = $Url + $Blocking
			$Url = $Url + "-"+$Defender
			$Url = $Url + $HaventWorked
			$Url = $Url + $IEM
			$Url = $Url + $NA
			$Url = $Url + $nBI
			$Url = $Url + $Review1 #CR + NRA + NeedCLA
		}
		"Incomplete" {
			$Url = $Url + $nBI
			$Url = $Url + "-"+$Defender
			$Url = $Url + $Review1 #CR + NRA + NeedCLA
			$Url = $Url + $nVC
		}
		"NA"{
			$Url = $Url + $NA
			$Url = $Url + $Set1 #Blocking + Common + Review1
		}
		"NAF"{
			$Url = $Url + $NAF
			$Url = $Url + $Set1 #Blocking + Common + Review1
		}
		"NANoIEDS" {
			$Url = $Url + $NA
			$Url = $Url + $nIEDS
			$Url = $Url + $Set1 #Blocking + Common + Review1
		}
		"None" {
		}
	"PrePipeline" {
$Url = $Url + "-label:Binary-Validation-Error+"
$Url = $Url + "-label:Manifest-AppsAndFeaturesVersion-Error+"
		$Url = $Url + $NotPass
		$Url = $Url + $Set1 #Blocking + Common + Review1
		$Url = $Url + $nVC
	}
		"Problematic" {
			$Url = $Url + $nIOI
			$Url = $Url + $nApproved
			$Url = $Url + "-"+$NA
			$Url = $Url + $NotPass
			$Url = $Url + $nVC
		}
		"Project"{
			$Url = $Url + "-label:Project-File+"
			$Url = $Url + "-label:Unexpected-File+"
		}
		"Squash"{
			$Url = $Url + $nApproved
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + $VC
			$Url = $Url + $Workable
		}
		"ToWork"{
			$Url = $Url + $Set1 #Blocking + Common + Review1
			$Url = $Url + $nVC
		}
		"ToWork2"{
			$Url = $Url + $HaventWorked
			$Url = $Url + $Recent
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + $nVC
			$Url = $Url + $Workable
		}
		"User"{
			$Url = $Url + $Set1 #Blocking + Common + Review1
			$Url = $Url + $Workable
		}
		"VCNA"{
			$Url = $Url + $NA
			$Url = $Url + $VC
			$Url = $Url + $Workable
		}
	}


	if ($Browser) {
		Start-Process $Url
	} else {
		$Response = Invoke-GitHubRequest $Url
		$Response = ($Response.Content | ConvertFrom-Json).items
		if (!($NoLabels)) {
			$Response = $Response | where {$_.labels}
		}
		return $Response
	}
}

Function Get-CannedResponse {
	param(
		[ValidateSet("AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","Drivers","DefenderFail","HashFailRegen","InstallerFail","InstallerMissing","InstallerNotSilent","NormalInstall","InstallerUrlBad","ListingDiff","ManValEnd","ManifestVersion","NoCause","NoExe","NoRecentActivity","NotGoodFit","OneManifestPerPR","Only64bit","PackageFail","PackageUrl","Paths","PendingAttendedInstaller","RemoveAsk","SequenceNoElements","Unattended","Unavailable","UrlBad","VersionCount","WhatIsIEDS","WordFilter")]
		[string]$Response,
		$UserInput=(Get-Clipboard),
		[switch]$NoClip,
		[switch]$NotAutomated
	)
	[string]$Username = "@"+$UserInput.replace(" ","")+","
	switch ($Response) {
		"AppsAndFeaturesNew" {
			$out = "Hi $Username`n`nThis manifest adds Apps and Features entries that aren't present in previous PR versions. Should these entries also be added to the previous versions?"
		}
		"AppsAndFeaturesMissing" {
			$out = "Hi $Username`n`nThis manifest removes Apps and Features entries that are present in previous PR versions. Should these entries also be added to this version?"
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
		"HashFailRegen" {
			$out = "Closing to regenerate with correct hash."
		}
		"InstallerFail" {
			$out = "Hi $Username`n`nThe installer did not complete:`n"
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
		"NormalInstall" {
			$out = "This package installs and launches normally on a Windows 10 VM."
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
		"RemoveAsk" {
			$out = "Hi $Username`n`nThis package installer is still available. Why should it be removed?"
		}
		"SequenceNoElements" {
			$out = "> Sequence contains no elements`n`n - $GitHubBaseUrl/issues/133371"
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
			$out = "Hi $Username`n`nThis manifest has the highest version number for this package. Is it available from another location?"
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

Function Get-AutoValLog {
	#Needs $GitHubToken to be set up in your -PR $PROFILE or somewhere more secure. Needs permissions: workflow,
	param(
		$clip = (Get-Clipboard),
		$PR = ($clip -split "/" | Select-String $PRRegex ),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		[switch]$CleanoutDirectory,
		[switch]$DemoMode,
		[switch]$Force,
		[switch]$Silent
	)
	$WaiverList = Get-LoadFileIfExists $WaiverFile
	#Get-Process *photosapp* | Stop-Process
	$BuildNumber = Get-BuildFromPR -PR $PR 
	if ($BuildNumber) {

		#This downloads to Windows default location, which has already been set to $DestinationPath
		Start-Process "$ADOMSBaseUrl/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$BuildNumber/artifacts?artifactName=InstallationVerificationLogs&api-version=7.0&%24format=zip"
		Start-Sleep 2;
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
			(Get-ChildItem $LogPath).FullName| ForEach-Object {
			if ($_ -match "png") {Start-Process $_} #Open PNGs with default app.
			Get-Content $_ |Where-Object {
				$_ -match '[[]FAIL[]]' -OR $_ -match 'fail' -OR $_ -match 'error' -OR $_ -match 'exception'}
			}
		) -split "`n" | Select-Object -Unique;

		$UserInput = $UserInput -replace "Standard error: ",""
		$UserInput = $UserInput -replace "Exception during executable launch operation System.InvalidOperationException: No process is associated with this object.",""
		if ($UserInput -ne "") {
			if (($UserInput -match "\[FAIL\] Installer failed security check.") -OR ($UserInput -match "Operation did not complete successfully because the file contains a virus or potentially unwanted software")) {
				Get-GitHubPreset DefenderFail -PR $PR
			}
			if ($UserInput -match "SQL error or missing database") {
				Get-GitHubPreset Retry -PR $PR
					if (!($Silent)) {
						Write-Output "PR $PR - SQL error or missing database"
					}
				Open-PRInBrowser -PR $PR
			}

			$UserInput = ($UserInput -split "`n") -notmatch ' success or error status`: 0'
			$UserInput = ($UserInput -split "`n") -notmatch 'api-ms-win-core-errorhandling'
			$UserInput = ($UserInput -split "`n") -notmatch '``Windows Error Reporting``'
			$UserInput = ($UserInput -split "`n") -notmatch 'The FileSystemWatcher has detected an error '
			$UserInput = ($UserInput -split "`n") -notmatch "with working directory 'D:\\TOOLS'. The specified executable is not a valid application for this OS platform"
			$UserInput = ($UserInput -split "`n") -notmatch "ThrowIfExceptional"
			$UserInput = ($UserInput -split "`n") -notmatch "Setting error JSON 1.0 fields"
			$UserInput = $UserInput -replace "2023-","`n> 2023-"
			$UserInput = $UserInput -replace " MSI ","`n> MSI "
			$UserInput = $UserInput | Select-Object -Unique

			$UserInput = "Automatic Validation ended with:`n> "+$UserInput
			$UserInput += "`n`n(Automated response - build $build.)"

			if ($DemoMode) {
				Write-Output "PR: $PR - DemoMode: Created"
			} else {
				$out = Reply-ToPR -PR $PR -Body $UserInput
	if (!($Silent)) {
				Write-Host "PR: $PR - $out"
				}
			}
		} else {
			$UserInput = "Automatic Validation ended with:`n> "
			$UserInput += "No errors to post."
			$UserInput += "`n`n(Automated response - build $build.)"
			$out = Reply-ToPR -PR $PR -Body $UserInput
	if (!($Silent)) {
			Write-Host "PR: $PR - $out - No errors to post."
	}
			$Title = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title);
			foreach ($Waiver in $WaiverList) {
				if ($Title -match $Waiver.PackageIdentifier) {
					Get-GitHubPreset -PR $PR Waiver
				}
			}
		}
	} else {
		if (!($Silent)) {
			Write-Host "PR: $PR - No build found."
		}
	}
}

Function Get-RandomIEDS {
	param(
		$VM = (Get-NextFreeVM),
		$IEDSPRs =(Get-SearchGitHub -Preset IEDS),
		$PR = ($IEDSPRs.number | where {$_ -notin (Get-Status).pr} | Get-Random),
		$File = 0,
		$ManifestType = "",
		$OldManifestType = ""
	)
	While ($ManifestType -ne "version") {
		$CommitFile = Get-CommitFile -PR $PR -File $File
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $CommitFile) -replace '"',''-replace "'",'')
		$null = Get-ManifestFile -VM $VM -PR $PR -clip $CommitFile -PackageIdentifier $PackageIdentifier
		$OldManifestType = $ManifestType
		$ManifestType = Get-YamlValue ManifestType -clip $CommitFile
		if ($OldManifestType -eq $ManifestType) {break}
		$File++
	}	
}

#PR tools
#Add user to PR: Invoke-GitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
#Approve PR (needs work): Invoke-GitHubPRRequest -PR $PR -Method Post -Type reviews
Function Invoke-GitHubPRRequest {
	param(
		$PR,
		[ValidateSet("GET","DELETE","PATCH","POST","PUT")][string]$Method = "GET",
		[ValidateSet("assignees","comments","commits","files","labels","reviews","")][string]$Type = "labels",
		[string]$Data,
		[ValidateSet("issues","pulls")][string]$Path = "issues",
		[ValidateSet("Content","Silent","StatusDescription")][string]$Output = "StatusDescription",
		[switch]$JSON
	)
	$Response = @{}
	$ResponseType = $Type
	$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"
	$prData = Invoke-GitHubRequest "$GitHubApiBaseUrl/pulls/$pr/commits" -JSON
	$commit = (($prData.commit.url -split "/")[-1])

	if (($Type -eq "") -OR ($Type -eq "files") -OR ($Type -eq "reviews")){
		$Path = "pulls"
		$uri = "$GitHubApiBaseUrl/$Path/$pr/$Type"
	} elseif ($Type -eq "comments") {
		$Response.body += $Data
	} elseif ($Type -eq "commits") {
		$uri = "$GitHubApiBaseUrl/$Type/$commit"
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
		$content = ((Invoke-WebRequest "$ADOMSBaseUrl/$Repo/_apis/build/builds?branchName=refs/pull/$PR/merge&api-version=6.0").content | ConvertFrom-Json),
		$href = ($content.value[0]._links.web.href),
		$build = (($href -split "=")[1])
	)
	return $build
}

Function Get-ADOLog {
	param(
		$PR,
		$build = (Get-BuildFromPR -PR $PR),
		$LogNumber = (36),
		$content = (Invoke-WebRequest "$ADOMSBaseUrl/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$build/logs/$LogNumber").content
	)
	$content = $content -join "" -split "`n"
	return $content
}

Function Get-PRApproval {
	param(
		$Clip = (Get-Clipboard),
		[int]$PR = (($Clip -split "#")[1]),
		$PackageIdentifier = ((($clip -split ": ")[1] -split " ")[0]),
		$auth = (Get-Content C:\repos\winget-pkgs\Tools\Auth.csv | ConvertFrom-Csv),
		$Approver = ((($auth | Where-Object {$_.PackageIdentifier -match $PackageIdentifier}).account -split "/" | Where-Object {$_ -notmatch "\("}) -join ", @"),
		[switch]$DemoMode
	)
	if ($DemoMode) {
		Write-Host "DemoMode: Reply-ToPR $PR requesting approval from @$Approver."
	} else {
		Reply-ToPR -PR $PR -UserInput $Approver -CannedResponse Approve
		$null = Invoke-GitHubPRRequest -PR $PR -Method POST -Type labels -Data Needs-Review
	}
}

Function Get-NonstandardPRComments {
	param(
		$PR,
		$comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content).body
	)
	foreach ($NSComment in $NonstandardPRComments) {
		$comments = $comments | Where-Object {$_ -notmatch $NSComment}
	}
	return $comments
}

Function Reply-ToPR {
	param(
		$PR,
		[string]$CannedResponse,
		[string]$UserInput = ((Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).user.login),
		[string]$Body = (Get-CannedResponse $CannedResponse -UserInput $UserInput -NoClip),
		[Switch]$Silent
	)

	if ($Silent) {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output Silent
	} else {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output StatusDescription
	}
}

Function Get-PRStateFromComments {
	param(
		$PR = (Get-Clipboard),
		$Comments = (Invoke-GitHubPRRequest -PR $PR -Type comments -Output content | select created_at,@{n="UserName";e={$_.user.login -replace "\[bot\]"}},body)
	)
	#Robot usernames
	$Wingetbot = "wingetbot"
	$AzurePipelines = "azure-pipelines"
	$FabricBot = "microsoft-github-policy-service"
	
	$out = @()
	foreach ($Comment in $Comments) {
		$State = ""
		if (($Comment.UserName -eq $Wingetbot) -AND ($Comment.body -match "Service Badge")) {
			$State = "PreRun"
		}
		if (($Comment.UserName -eq $Wingetbot) -OR ($Comment.UserName -eq $GitHubUserName) -AND ($Comment.body -match "AzurePipelines run")) {
			$State = "PreValidation"
		}
		if (($Comment.UserName -eq $AzurePipelines) -AND ($Comment.body -match "Azure Pipelines successfully started running 1 pipeline")) {
			$State = "Running"
		}
		if (($Comment.UserName -eq $FabricBot) -AND ($Comment.body -match "The check-in policies require a moderator to approve PRs from the community")) {
			$State = "PreApproval"
		}
		if (($Comment.UserName -eq $GitHubUserName) -AND ($Comment.body -match "The package didn't pass a Defender or similar security scan")) {
			$State = "DefenderFail"
		}
		if (($Comment.body -match "which is greater than the current manifest's version")) {
			$State = "VersionParamResponse"
		}
		if (($Comment.UserName -eq $GitHubUserName) -AND ($Comment.body -match "which is greater than the current manifest's version")) {
			$State = "VersionParamMismatch"
		}
		if (($Comment.UserName -eq $FabricBot) -AND (
		($Comment.body -match "The package manager bot determined there was an issue with one of the installers listed in the url field") -OR #URL error
		($Comment.body -match "The package manager bot determined there was an issue with installing the application correctly") -OR #Validation-Installation-Error
		($Comment.body -match "The pull request encountered an internal error and has been assigned to a developer to investigate") -OR  #Internal-Error
		($Comment.body -match "this application failed to install without user input") #Validation-Unattended-Failed
		)) {
			$State = "LabelAction"
		}
		if (($Comment.UserName -eq $FabricBot) -AND ($Comment.body -match "One or more of the installer URLs doesn't appear valid")) {
			$State = "DomainReview"
		}
		if (($Comment.UserName -eq $FabricBot) -AND ($Comment.body -match "The package manager bot determined changes have been requested to your PR")) {
			$State = "ChangesRequested"
		}
		if (($Comment.UserName -eq $FabricBot) -AND ($Comment.body -match "I am sorry to report that the Sha256 Hash does not match the installer")) {
			$State = "HashMismatch"
		}
		if (($Comment.UserName -eq $GitHubUserName) -AND ($Comment.body -match "Automatic Validation ended with:")) {
			$State = "AutoValEnd"
		}
		if (($Comment.UserName -eq $GitHubUserName) -AND ($Comment.body -match "Manual Validation ended with:")) {
			$State = "ManValEnd"
		}
		if (($Comment.UserName -eq $AzurePipelines) -AND ($Comment.body -match "Pull request contains merge conflicts")) {
			$State = "MergeConflicts"
		}
		if (($Comment.UserName -eq $FabricBot) -AND ($Comment.body -match "Validation has completed")) {
			$State = "ValidationCompleted"
		}
		if (($Comment.UserName -eq $Wingetbot) -AND ($Comment.body -match "Publish pipeline succeeded for this Pull Request")) {
			$State = "PublishSucceeded"
		}
		if ($State -ne "") {
			$out += $Comment | select @{n="event";e={$State}},created_at
		}
	}
	Return $out
}

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
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -ContentType application/json)
		} catch {
			Write-Output ("Error: $($error[0].ToString()) - Url $Url - Body: $Body")
		}
	} else {
		try {
			$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers)
		} catch {
			Write-Output ("Error: $($error[0].ToString()) - Url $Url - Body: $Body")
		}
	}
	#GitHub requires the value be the .body property of the variable. This makes more sense with CURL, Where-Object this is the -data parameter. However with Invoke-WebRequest it's the -Body parameter, so we end up with the awkward situation of having a Body parameter that needs to be prepended with a body property.
	#if (!($Silent)) {
		if (($JSON)){ # -OR ($Output -eq "content")) {
			$out| ConvertFrom-Json
		} else {
			$out
		}
	#}
	Start-Sleep $GitHubRateLimitDelay;
}

Function Check-PRInstallerStatusInnerWrapper {
	param(
		$Url,
		$Code = (Invoke-WebRequest $Url -Method Head -ErrorAction SilentlyContinue).StatusCode
	)
	return $Code
}

#Package validation
Function Get-TrackerVMValidate {
	param(
		$out = ((Get-Clipboard) -split "`n"),
		[ValidateSet("Win10","Win11")][string]$OS = (Get-OSFromVersion),
		[int]$vm = ((Get-NextFreeVM -OS $OS) -replace"vm",""),
		[switch]$NoFiles,
		[ValidateSet("Config","DevHomeConfig","Pin","Scan")][string]$Operation = "Scan",
		[switch]$InspectNew,
		[switch]$notElevated,
		$ManualDependency,
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $out) -replace '"',''-replace "'",''),
		$PackageVersion = ((Get-YamlValue -StringName "PackageVersion" $out) -replace '"',''-replace "'",''),
		[int]$PR = (Get-PRNumber $out -Hash),
		$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		$installerLine = "--manifest $RemoteFolder/manifest",
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")][string]$Arch,
		[ValidateSet("User","Machine")][string]$Scope,
		$InstallerType,
		[string]$Locale,
		[switch]$Silent,
		$optionsLine = ""
	)
	Test-Admin
	if ($vm -eq 0){
		Write-Host "No available $OS VMs";
		Get-PipelineVmGenerate -OS $OS;
		#Break;
		}
	if ($Silent) {
		Get-TrackerVMSetStatus "Prevalidation" $vm $PackageIdentifier -PR $PR -Silent
	} else {
		Get-TrackerVMSetStatus "Prevalidation" $vm $PackageIdentifier -PR $PR
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
	if ($InstallerType) {
		$logExt = $InstallerType+"."+$logExt
		$optionsLine += " --installer-type $InstallerType "
		$logLine += "InstallerType $InstallerType "
	}
	$Archs = ($out | Select-String -notmatch "arm"| Select-String "Architecture: " )|ForEach-Object{($_ -split ": ")[1]} 
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
	if ($notElevated -OR ($out | Select-String "ElevationRequirement: elevationProhibited")) {
		if (!($Silent)) {
			Write-Host " = = = = Detecting de-elevation requirement = = = = "
		}
		$nonElevatedShell = "if ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')){& explorer.exe 'C:\Program Files\PowerShell\7\pwsh.exe';Stop-Process (Get-Process WindowsTerminal).id}"
		#If elevated, run^^ and exit, else run cmds.
	}
$packageName = ($PackageIdentifier -split "[.]")[1]

$cmdsOut = ""

switch ($Operation) {
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
Get-TrackerVMSetStatus 'Installing'
Out-Log ' = = = = Starting Manual Validation pipeline build $build on VM $vm $PackageIdentifier $logLine = = = = '

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

$ManualDependency
`$wingetArgs = 'install $optionsLine $installerLine --accept-package-agreements --ignore-local-archive-malware-scan'
Out-Log `"Main Package Install with args: `$wingetArgs`"
`$mainpackage = (Start-Process 'winget' `$wingetArgs -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Failing Manual Validation pipeline build $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Get-TrackerVMSetStatus 'ValidationComplete'
	Break;
}
#Read-Host 'Install complete, press ENTER to continue...' #Uncomment to examine installer before scanning, for when scanning disrupts the install.

Get-TrackerVMSetStatus 'Scanning'

Out-Log 'Install complete, starting file change scan.'
`$files = ''
if (Test-Path $RemoteFolder\files.txt) {
	`$files = Get-Content $RemoteFolder\files.txt
} else {
	`$files1 = (Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | Where-Object {`$_.CreationTime -gt `$TimeStart}).FullName
	`$files2 = (Get-ChildItem c:\ -File -Recurse -ErrorAction Ignore -Force | Where-Object {`$_.LastAccessTIme -gt `$TimeStart}).FullName
	`$files = `$files1 + `$files2 | Select-Object -Unique
}

Out-Log `"Reading `$(`$files.count) file changes in the last `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. Starting bulk file execution:`"
`$files = `$files | Where-Object {`$_ -notmatch 'unins'} | Where-Object {`$_ -notmatch 'dotnet'} | Where-Object {`$_ -notmatch 'redis'} | Where-Object {`$_ -notmatch 'msedge'} | Where-Object {`$_ -notmatch 'System32'} | Where-Object {`$_ -notmatch 'SysWOW64'} | Where-Object {`$_ -notmatch 'WinSxS'} | Where-Object {`$_ -notmatch 'dump64a'} | Where-Object {`$_ -notmatch 'CbsTemp'}
`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'
`$files | Select-String '[.]exe`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | Select-String '[.]msi`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | Select-String '[.]lnk`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};

Out-Log `" = = = = End file list. Starting Defender scan.`"
Start-MpScan;

Out-Log `"Defender scan complete, closing windows...`"
Get-Process msedge | Stop-Process
Get-Process mip | Stop-Process
Get-Process powershell | where {`$_.id -ne `$PID} | Stop-Process
Get-Process explorer | where {`$_.id -ne `$explorerPid} | Stop-Process

Get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell' -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'}| Stop-Process
#Get-Process | Where-Object {`$_.id -notmatch `$PID -and `$_.id -notmatch `$explorerPid -and `$_.processname -notmatch `$packageName -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'} | Stop-Process

Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart -ErrorAction Ignore).Message 'Application Log'
Out-ErrorData (Get-MPThreat).ThreatName `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

Out-Log `" = = = = Completing Manual Validation pipeline build $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
Get-TrackerVMSetStatus 'ValidationComplete'
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
		Get-RemoveFileIfExist "$manifestFolder" -remake -Silent
		$Files = @()
		$Files += "Package.installer.yaml"
		$FileNames = ($out | Select-String "[.]yaml") |ForEach-Object{($_ -split "/")[-1]}
		$replace = $FileNames[-1] -replace ".yaml"
		$FileNames | ForEach-Object {
			$Files += $_ -replace $replace,"Package"
		}
		$out = $out -join "`n" -split "@@"
		for ($i=0;$i -lt $Files.length;$i++) {
			$File = $Files[$i]
			$inputObj = $out[$i*2] -split "`n"
			$inputObj = $inputObj[1..(($inputObj| Select-String "ManifestVersion" -SimpleMatch).LineNumber -1)] | Where-Object {$_ -notmatch "marked this conversation as resolved."}
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
		Get-ManifestFileCheck $vm -Silent;
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
	Get-TrackerVMRevert $vm -Silent
	Get-TrackerVMLaunchWindow $vm
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
	Get-TrackerVMValidate -Arch x86
}

Function Get-TrackerVMValidateByScope {
	param(
	)
	Get-TrackerVMValidate -Scope Machine;
	Start-Sleep 2;
	Get-TrackerVMValidate -Scope User
}

#Manifests Etc
Function Get-SingleFileAutomation {
	param(
		$PR,
		$PackageIdentifier = (Get-YamlValue PackageIdentifier),
		$version = ((Get-YamlValue PackageVersion) -replace "'","" -replace '"',""), 
		$listing = (Get-ManifestListing $PackageIdentifier),
		$vm = (Get-ManifestFile)[-1]
	)
	
	for ($file = 0; $file -lt $listing.length;$file++) {
		Get-ManifestFile $vm -clip (Get-WinGetFile -PackageIdentifier $PackageIdentifier -Version $version -FileName $listing[$file]) -PR $PR
	}
}

Function Get-ManifestAutomation {
	param(
		$vm = (Get-NextFreeVM),
		$PR =0,
		$Arch,
		$OS,
		$Scope
	)

	#Read-Host "Copy Installer file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	$null = Get-ManifestFile $vm

	Read-Host "Copy defaultLocale file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	$null = Get-ManifestFile $vm

	Read-Host "Copy version file to clipboard, then press Enter to continue."
	(Get-Clipboard) -join "" | clip;
	if ($Arch) {
		$null = Get-ManifestFile $vm -Arch $Arch
	} elseif ($OS) {
		$null = Get-ManifestFile $vm -OS $OS
	} elseif ($Scope) {
		$null = Get-ManifestFile $vm -Scope $Scope
	} else {
		$null = Get-ManifestFile $vm -PR $PR
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
		$file = (Get-WinGetFile $Title $Version)
	}
}

Function Get-ManifestFile {
	param(
		[int]$vm = ((Get-NextFreeVM) -replace "vm",""),
		$clip = (Get-SecondMatch),
		$FileName = "Package",
		$PackageIdentifier = ((Get-YamlValue -StringName "PackageIdentifier" $out) -replace '"',''-replace "'",''),
		$PR = 0,
		$Arch,
		$OS,
		$Scope
	);
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
				Get-TrackerVMValidate -vm $vm -NoFiles -Arch $Arch -PR $PR -PackageIdentifier $PackageIdentifier
			} elseif ($OS) {
				Get-TrackerVMValidate -vm $vm -NoFiles -OS $OS -PR $PR -PackageIdentifier $PackageIdentifier
			} elseif ($Scope) {
				Get-TrackerVMValidate -vm $vm -NoFiles -Scope $Scope -PR $PR -PackageIdentifier $PackageIdentifier
			} else {
				Get-TrackerVMValidate -vm $vm -NoFiles -PR $PR -PackageIdentifier $PackageIdentifier
			}
		}
		Default {
			Write-Host "Error: Bad ManifestType"
			Write-Host $clip
		}
	}
	$FilePath = "$manifestFolder\$FileName.yaml"
	Write-Host "Writing $($clip.length) lines to $FilePath"
	$clip -replace "0New version: ","0" -replace "0Add version: ","0" -replace "0Add ","0" -replace "0New ","0" | Out-File $FilePath -Encoding unicode
	return $vm
}

Function Get-ManifestListing {
	param(
		$PackageIdentifier,
		$Version = (Find-WinGetPackage $PackageIdentifier | Where-Object {$_.id -eq $PackageIdentifier}).version,
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

Function Get-OSFromVersion {
	try{
		if ([system.version](Get-YamlValue -StringName MinimumOSVersion) -ge [system.version]"10.0.22000.0"){"Win11"}else{"Win10"}
	} catch {
		"Win10"
	}
}

#VM Image Management
Function Get-PipelineVmGenerate {
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
	Get-RemoveFileIfExist $destinationPath -remake
	Get-RemoveFileIfExist $VMFolder -remake
	$vmImageFolder = ""

	switch ($OS) {
		"Win10" {
			$vmImageFolder = "$imagesFolder\Win10-image\Virtual Machines\978D53B8-4672-4120-8522-C1E17B714B62.vmcx"
		}
		"Win11" {
			$vmImageFolder = "$imagesFolder\Win11-image\Virtual Machines\C911D03D-5385-41D3-B753-69228E3C7187.vmcx"
		}
	}

	Write-Host "Takes about 120 seconds..."
	Import-VM -Path $vmImageFolder -Copy -GenerateNewId -VhdDestinationPath $destinationPath -VirtualMachinePath $destinationPath;
	Rename-VM (Get-VM | Where-Object {($_.CheckpointFileLocation)+"\" -eq $destinationPath}) -NewName $newVmName
	Start-VM $newVmName
	Remove-VMCheckpoint -VMName $newVmName -Name "Backup"
	Get-TrackerVMRevert $vm
	Get-TrackerVMLaunchWindow $vm
	Write-Host "Took $(((Get-Date)-$startTime).TotalSeconds) seconds..."
}

Function Get-PipelineVmDisgenerate {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = "vm$vm"
	)
	Test-Admin
	Get-TrackerVMSetStatus 'Disgenerate' $vm
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	Stop-TrackerVM $vm
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
}

Function Get-ImageVMStart {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$vm = 0
	Start-VM $OS;
	Get-TrackerVMRevert $vm $OS;
	Get-TrackerVMLaunchWindow $vm $OS
}

Function Get-ImageVMStop {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$vm = 0
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
	[int]$version = [int](Get-TrackerVMVersion) + 1
	Write-Host "Writing $OS version $version"
	Get-TrackerVMSetVersion $version
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match "$OS"}).id -ErrorAction Ignore
	Redo-Checkpoint $vm $OS;
	Stop-TrackerVM $vm $OS;
	Write-Host "Letting VM cool..."
	Start-Sleep 30;
	Robocopy.exe $OriginalLoc $ImageLoc -mir
}

Function Get-ImageVMMove {
	param(
		[ValidateSet("Win10","Win11")][string]$OS = "Win10"
	)
	Test-Admin
	$vm = 0
	$newLoc = ""
	$matchName = ""
	switch ($OS) {
		"Win10" {
			$newLoc = $Win10Folder
			$matchName = "Windows 10 MSIX packaging environment"
		}
		"Win11" {
			$newLoc = $Win11Folder
			$matchName = "Windows 11 dev environment"
		}
	}
	$vm = Get-VM | where {$_.Name -match $matchName}
	Move-VMStorage -VM $vm -DestinationStoragePath "$imagesFolder\$newLoc"
	Rename-VM -VM $vm -NewName $OS
}

#VM Pipeline Management
Function Get-TrackerVMLaunchWindow {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Get-TrackerVMRevert {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$vm",
		[Switch]$Silent
	)
	Test-Admin
	if ($Silent) {
		Get-TrackerVMSetStatus "Restoring" $vm -Silent
	} else {
		Get-TrackerVMSetStatus "Restoring" $vm
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
	Get-TrackerVMSetStatus "Completing" $vm
	Stop-Process -id ((Get-ConnectedVM)|Where-Object {$_.VM -match "vm$vm"}).id -ErrorAction Ignore
	Stop-TrackerVM $vm
	Get-RemoveFileIfExist $filesFileName
	Get-TrackerVMSetStatus "Ready" $vm " " 1
}

Function Stop-TrackerVM {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

#VM Status
Function Get-TrackerVMSetStatus {
	param(
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
		$Status = "Complete",
		[Parameter(mandatory=$True)]$VM,
		[string]$Package,
		[int]$PR,
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

Function Get-Status {
	param(
		[int]$vm,
		[ValidateSet("AddVCRedist","Approved","CheckpointComplete","Checkpointing","CheckpointReady","Completing","Complete","Disgenerate","Generating","Installing","Prescan","Prevalidation","Ready","Rebooting","Regenerate","Restoring","Revert","Scanning","SendStatus","Setup","SetupComplete","Starting","Updating","ValidationComplete")]
		$Status,
		[ValidateSet("Win10","Win11")][string]$OS,
		$out = (Get-Content $StatusFile | ConvertFrom-Csv)
	)
	if ($OS) {
		$out = ($out | Where-Object {$_.OS -eq $OS})
	}
	if ($vm) {
		$out = ($out | Where-Object {$_.vm -eq $vm}).status
	}
	if ($Status) {
		$out = ($out | Where-Object {$_.version -eq (Get-TrackerVMVersion)}| Where-Object {$_.status -eq $Status}).vm
	}
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
	$Status = Get-VM | Where-Object {$_.name -notmatch "vm0"}|
	Select-Object @{n="vm";e={$_.name}},
	@{n="status";e={"Ready"}},
	@{n="version";e={(Get-TrackerVMVersion)}},
	@{n="OS";e={"Win10"}},
	@{n="Package";e={""}},
	@{n="PR";e={"1"}},
	@{n="RAM";e={"0"}}
	Write-Status $Status
}

#VM Orchestration
Function Get-TrackerVMCycle {
	param(
		$VMs = (Get-Status)
	)
	Foreach ($VM in $VMs) {
		Switch ($VM.status) {
			"AddVCRedist" {
				Add-ValidationData $VM.vm
			}
			"Approved" {
				Add-Waiver $VM.PR
				Get-TrackerVMSetStatus "Complete" $VM.vm
			}
			"CheckpointReady" {
				Redo-Checkpoint $VM.vm
			}
			"Complete" {
				if (($VMs | Where-Object {$_.vm -eq $VM.vm} ).version -lt (Get-TrackerVMVersion)) {
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
			"SendStatus" {
				$SharedError = (Get-Content "$writeFolder\err.txt") -replace "Faulting","`n> Faulting" -replace "2024","`n> 2024"
				Reply-ToPR -PR $VM.PR -UserInput $SharedError -CannedResponse ManValEnd 
				Get-TrackerVMSetStatus "Complete" $VM.vm
				if (($SharedError -match "\[FAIL\] Installer failed security check.") -OR ($SharedError -match "Detected 1 Defender")) {
					Get-GitHubPreset -Preset DefenderFail -PR $VM.PR 
				}
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
	$Status | out-file $TrackerModeFile
}

Function Get-ConnectedVM {
	Test-Admin
	(Get-Process *vmconnect*) | Select-Object id, @{n="VM";e={ForEach-Object{$_.mainwindowtitle[0..4] -join ""}}}
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

Function Redo-Checkpoint {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-TrackerVMSetStatus "Checkpointing" $vm
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Get-TrackerVMSetStatus "Complete" $vm
}

Function Get-TrackerVMVersion {
	[int](Get-Content $VMversion)
}

Function Get-TrackerVMSetVersion {
	param([int]$Version) $Version|out-file $VMversion
}

Function Get-TrackerVMRemoveLesser {
	(Get-Status | Where-Object {
		$_.version -lt (Get-TrackerVMVersion)
	}).vm |ForEach-Object{
		Get-TrackerVMSetStatus Disgenerate $_
	}
}

Function Get-TrackerVMRotate {
	$status = Get-Status
	$VMs = $status | Where-Object {$_.version -lt (Get-TrackerVMVersion)}
	if ($VMs){
		if (!(($status | Where-Object {$_.status -ne "Ready"}).count)) {
			Get-TrackerVMSetStatus Regenerate ($VMs.VM | Get-Random)
		}
	}
}

#VM Window Management
Function Get-TrackerVMWindowLoc {
	param(
		$VM,
		$Rectangle = (New-Object RECT),
		$VMProcesses = (Get-Process vmconnect),
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match "vm$vm"}).MainWindowHandle
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
		$MWHandle = ($VMProcesses | where {$_.MainWindowTitle -match "vm$vm"}).MainWindowHandle
	)
	$null = [window]::MoveWindow($MWHandle,$Left,$Top,$Right,$Bottom,$True)
}

Function Get-TrackerVMWindowArrange {
	param(
		$VMs = (Get-Status |where {$_.status -ne "Ready"}).vm 
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
		$prev = ($prevUnit -split ": ")[0]
		if ($current -ne $PRev) {
			$prevUnit
		}
	}
	#Then complete the last $depth items of the array by starting at $clip[-$depth] and work backwards through the last items in reverse order to $clip[-1].
	for ($depthUnit = $depth ;$depthUnit -gt 0; $depthUnit--){
		$clip[-$depthUnit]
	}
}

Function Get-ManifestFileCheck {
	param(
		[Parameter(mandatory=$True)][int]$vm,
		$filePath = "$runPath\$vm\manifest\Package.yaml",
		[Switch]$Silent
	)
	$fileContents = Get-Content $filePath
	if ($fileContents[-1] -ne "0") {
		$fileContents[-1] = ($fileContents[-1] -split ".0")[0]+".0"
		if (!($Silent)){
			Write-Host "Writing $($fileContents.length) lines to $filePath"
		}
		$fileContents | out-file $filePath
	}
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
	}else {
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

Function Get-WinGetFile {
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
		$Entry = "AppsAndFeaturesEntries"
	)
	$content = Get-WinGetFile $PackageIdentifier $Version
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

Function Get-LineFromCommitFile {
	param(
		$PR,
		$LogNumber = (36),
		$SearchString = "Specified hash doesn't match",
		$Log = (Get-ADOLog -PR $PR -Log $LogNumber),
		$MatchOffset = (-1),
		$MatchLine = (($Log | Select-String -SimpleMatch $SearchString).LineNumber + $MatchOffset | where {$_ -gt 0}),
		$Length = 0,
		$output = ""
	)
	foreach ($Match in $MatchLine) {
		$output += ($Log[$Match..($Match+$Length)])
	}
	return $output
}

Function Get-CommitFile {
	param(
		$PR,
		$File = 0,
		$Commit = (Invoke-GitHubPRRequest -PR $PR -Type commits -Output content -JSON),
		$url = ""
	)
	if ($Commit.files.contents_url.gettype().name -eq "String") {
		$url = $Commit.files.contents_url
	} else {
		$url = $Commit.files.contents_url[$File]
	}
	$CommitFile = Invoke-GitHubRequest -Uri $url
	$EncodedFile = $CommitFile.Content | ConvertFrom-Json
	Get-DecodeGitHubFile $EncodedFile.content
}

#Inject dependencies
Function Add-ValidationData {
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
		$lineNo = (($fileContents| Select-String $Selector -List).LineNumber -$offset),
		$fileInsert = "Dependencies:`n  PackageDependencies:`n - PackageIdentifier: $Dependency",
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
	$fileInsert = "  InstallerSwitches:`n    Silent: $Data"
	Add-ValidationData $vm -Selector $Selector -fileInsert $fileInsert #-Force
}

Function Get-UpdateHashInPR {
	param(
		$PR,
		$ManifestHash,
		$PackageHash,
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $ManifestHash).LineNumber),
		$ReplaceTerm = ("  InstallerSha256: $($PackageHash.toUpper())"),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
	Get-GitHubPreset -Preset ChangesRequested -PR $PR 
}

Function Get-UpdateHashInPR2 {
	param(
		$PR,
		$Clip = (Get-Clipboard),
		$SearchTerm = "Expected hash",
		$ManifestHash = (Get-YamlValue $SearchTerm -Clip $Clip),
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $ManifestHash).LineNumber),
		$ReplaceTerm = "Actual hash",
		$PackageHash = ("  InstallerSha256: "+(Get-YamlValue $ReplaceTerm -Clip $Clip).toUpper()),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
	Get-GitHubPreset -Preset ChangesRequested -PR $PR 
}

Function Get-UpdateArchInPR {
	param(
		$PR,
		$SearchTerm = "  Architecture: x86",
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $SearchTerm).LineNumber),
		[string]$ReplaceTerm = (($SearchTerm -split ": ")[1]),
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")]
		[string]$ReplaceArch = (("x86","x64") | where {$_ -notmatch $ReplaceTerm}),
		$ReplaceString = ($SearchTerm -replace $ReplaceTerm,$ReplaceArch),
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
	Get-GitHubPreset -Preset ChangesRequested -PR $PR 
}

Function Add-DependencyToPR {
	param(
		$PR,
		$Dependency = "Microsoft.VCRedist.2015+.x64",
		$SearchString = "Installers:",
		$LineNumbers = ((Get-CommitFile -PR $PR | Select-String $SearchString).LineNumber),
		$ReplaceString = "Dependencies:`n  PackageDependencies:`n - PackageIdentifier: $Dependency`nInstallers:",
		$comment = "``````suggestion`n$ReplaceString`n```````n`n(Automated response - build $build.)"
	)
	$out = ""
	foreach ($Line in $LineNumbers) {
		$out += Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
	Get-GitHubPreset -Preset ChangesRequested -PR $PR 
}

#Timeclock
Function Get-TimeclockSet {
	Param(
		[ValidateSet("Start","Stop")][string]$mode = "Start",
		$time = (Get-Date -Format s),
		$timeStamp = (Get-Date $time -Format s)
	)
	if (Get-TimeRunning) { $mode = "Stop"}
	$timeStamp + " "+ $mode >> $timecardfile
}

Function Get-Timeclock {
	Param(
	)
	Get-Content $timecardfile | Select-Object @{n="Date";e={Get-Date ($_ -split " ")[0]}},@{n="State";e={($_ -split " ")[1]}}
	#
}

Function Get-HoursWorkedToday {
	Param(
		$Today = (Get-Date).Day
	)
	[array]$time = (Get-Timeclock).date | Where-Object {(Get-Date $_.date).day -eq $Today} | ForEach-Object {($_ -split " ")[1]}
	if (($time.count % 2) -eq 1) {
		$time += (Get-Date -f T)
	}
	$aggregator = 0;
	for ($incrementor=0;$incrementor -lt $time.count; $incrementor=$incrementor+2){
		$aggregator += ( Get-Date $time[$incrementor+1]) - (Get-Date $time[$incrementor])
		#Write-Host $aggregator
	};
	[math]::Round($aggregator.totalHours,2)
}

Function Get-TimeRunning {
	if (((Get-Content $timecardfile)[-1] -split " ")[1] -eq "Start"){
		$True
	} else {
		$False
	}
}

#Reporting
Function Add-PRToRecord {
	param(
		$PR,
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action,
		$Title
	)
	"$PR,$Action,$Title" | Out-File $LogFile -Append 
}

Function Get-PRFromRecord {
	param(
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action
	)
	("PR,Action,Title`n" + (Get-Content $LogFile)) -split " " | ConvertFrom-Csv | Where-Object {$_.Action -match $Action}
}

Function Get-PRReportFromRecord {
	param(
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action,
		$out = "",
		$line = 0,
		$Record = ((Get-PRFromRecord $Action).PR | Select-Object -Unique),
		[switch]$NoClip
	)

	(Get-Content $LogFile) | ConvertFrom-Csv | Where-Object {$_.Action -notmatch $Action} | ConvertTo-Csv|Out-File $LogFile

	Foreach ($PR in $Record) {
		$line++
		$Title = ""
		if ($PR.Title) {
			$Title = $PR.Title
		} else {
			$Title = (Invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title
		}
		Get-TrackerProgress -PR $PR $MyInvocation.MyCommand $line $Record.length
		$out += "$Title #$PR`n";
	}
	if ($NoClip) {
		return $out
	} else {
		$out | clip
	}
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
		$out = $out | Select-String $hashPRRegexEnd| Sort-Object -descending
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
	$clip = ($clip | Select-String $StringName)
	$clip = ($clip -split ": ")[1]
	$clip = ($clip -split "#")[0]
	$clip = ((($clip.ToCharArray()) | where {$_ -match "\S"}) -join "")
	Return $clip
}

#Etc
Function Test-Admin {
	if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){Write-Host "Try elevating your session.";break}
}

Function Get-LazySearchGitHub {
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
	[int]$PadChars = 32
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

$WordFilterList = "accept_gdpr ", "accept-licenses", "accept-license","eula","downloadarchive.documentfoundation.org"

$CountrySet = "Default","Warm","Cool","Random","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","Curacao","Cyprus","Czechia","CÃ¶te D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania"," United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Ã…land Islands"

#Misc Data
$NonstandardPRComments = ("Validation Pipeline Badge",#Pipeline status
"wingetbot run",#Run pipelines
"AzurePipelines run",#Run pipelines
"Azure Pipelines successfully started running 1 pipeline",#Run confirmation
"The check-in policies require a moderator to approve PRs from the community",#Validation complete 
"microsoft-github-policy-service agree",#CLA acceptance
"wingetbot waivers Add",#Any waivers
"This account is bot account and belongs to CoolPlayLin",#CoolPlayLin's automation
"This account is automated by Github Actions and the source code was created by CoolPlayLin",#Exorcism0666's automation
"Response status code does not indicate success",#My automation - removal PR where URL failed status check.
"Automatic Validation ended with",#My automation - Validation output might be immaterial if unactioned.
"Manual Validation ended with",#My automation - Validation output might be immaterial if unactioned.
"No errors to post",#My automation - AutoValLog with no logs.
"The package didn't pass a Defender or similar security scan",#My automation - DefenderFail.
"Installer failed security check",#My automation - AutoValLog DefenderFail.
"Sequence contains no elements"#New Sequence error.
)

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