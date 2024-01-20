#Copyright 2022-2024 Microsoft Corporation
#Author: Stephen Gillie
#Title: Manual Validation Pipeline v3.15.0
#Created: 10/19/2022
#Updated: 1/19/2024
#Notes: Utilities to streamline evaluating 3rd party PRs.
#Update log:
#3.15.0 Add Get-SearchGitHub as a new primary intake method for this system.
#3.14.4 Make DefenderFail auto-response more robust and add SQL Missing logging and auto-restart of PR.
#3.14.3 Add file selection to Get-CommitFile.
#3.14.2 Large rewrite of Add-DependencyToPR.
#3.14.1 Integrate Check-BulkPRInstallerStatus into Open-PRInBrowser.
#3.14.0 Add Get-TrackerProgress to have a more unified way to show progress.
#3.13.0 Rename Open-PR to Open-PRInBrowser, vastly improve to auto-check "controversy" and URLs for removal PRs.
#3.12.2 Move Defender auto-reply code into Get-RetryDefender.
#3.12.1 Add a canned response and rearrange.
#3.12.0 Bugfixes and updates (PR number passthrough) to Get-ManifestAutomation and Get-ManifestFile.
#3.11.3 Add several more PRLabelAction outputs.
#3.11.2 Add output verification to most PRLabelAction outputs.
#3.11.1 Change Invoke-GitHubPRRequest Silent output to be an Output option instead of a separate flag.
#3.11.0 Add numerous updates to bulk functions.

$build = 620
$appName = "Manual Validation"
Write-Host "$appName build: $build"
$MainFolder = "C:\ManVal"
#Share this folder with Windows File Sharing, then access it from within the VM across the network, as \\LaptopIPAddress\SharedFolder. For LaptopIPAddress use Ethernet adapter vEthernet (Default Switch) IPv4 Address.
Set-Location $MainFolder

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
$LogFile = "C:\ManVal\misc\ApprovedPRs.txt"

$CheckpointName = "Validation"
$VMUserName = "user" #Set to the internal username you're using in your VMs.
$GitHubUserName = "stephengillie"

$GitHubRateLimitDelay = 0.5 #seconds

#Automation tools
Function Get-PRLabelAction {
	param(
	[int]$PR,
	$Labels = ((Invoke-GitHubPRRequest -PR $PR -Type "labels" -Output content -JSON).name)
	)
	Write-Output "PR $PR has labels $Labels"
	Foreach ($Label in $Labels) {
		Switch ($Label) {
			"Binary-Validation-Error" {
				$UserInput = Get-LineFromCommitFile $PR -SearchString "Installer Verification Analysis Context Information:" -length 5
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
				if ($UserInput -match "BlockingDetectionFound") {
					Get-GitHubPreset -PR $PR -Preset AutomationBlock
				}
			}
			"Error-Hash-Mismatch" {
				$UserInput = Get-LineFromCommitFile $PR -SearchString "Actual hash" -Length 1 
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 26 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -notmatch "Actual hash") {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 36 -SearchString "Actual hash" -Length 1 
				}
				if ($UserInput -match "Actual hash") {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Error-Installer-Availability" {
				$UserInput = Get-LineFromCommitFile $PR -SearchString "Installer Verification Analysis Context Information:" -length 5
				Get-GitHubPreset -PR $PR -Preset CheckInstaller
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Internal-Error-Dynamic-Scan" {
				Get-RerunPR $PR
			}
			"Internal-Error-Manifest" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 15 -SearchString "[error] One or more errors occurred."
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "Processing manifest" -length 7
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Internal-Error" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Manifest-AppsAndFeaturesVersion-Error" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "[error] Manifest Error:"
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 15 -SearchString "[error] Manifest Error:"
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 39 -SearchString "[error] Manifest Error:"
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Manifest-Installer-Validation-Error" {
				Reply-ToPR -PR $PR -UserInput ((Get-ADOLog $PR -Log 25)[60]) -CannedResponse AutoValEnd
			}
			"Manifest-Validation-Error" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "[error] Manifest Error:"
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 31 -SearchString "[error] Manifest Error:"
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 31 -SearchString "[error] One or more errors occurred."
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 44 -SearchString "[error] Manifest Error:"
				}
				if ("" -eq $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 44 -SearchString "[error] One or more errors occurred."
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Possible-Duplicate" {
				$UserInput = Check-Duplicate $PR
				if ($UserInput) {
					$UserInput = "InstallerUrl contains Manifest version instead of PR version:`n"+$UserInput + "`n`n(Automated message - build $build)"
					Reply-ToPR -PR $PR -Body $UserInput
					Get-GitHubPreset $PR Feedback
				}
			}
			"PullRequest-Error" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 24 -SearchString "[error] One or more errors occurred."
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 25 -SearchString "[error] One or more errors occurred."
				}
				if ($null -match $UserInput) {
					$UserInput = Get-LineFromCommitFile $PR -LogNumber 14 -SearchString "[error] One or more errors occurred."
				}
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"URL-Validation-Error" {
				$UserInput = Get-LineFromCommitFile $PR -LogNumber 32 -SearchString "Validation result: Failed"
				Get-GitHubPreset -PR $PR -Preset CheckInstaller
				if ($UserInput) {
					Reply-ToPR -PR $PR -UserInput $UserInput -CannedResponse AutoValEnd
				}
			}
			"Validation-Domain" {
			}
			"Validation-Executable-Error" {
				Get-AutoValLog  $PR
			}
			"Validation-Hash-Verification-Failed" {
				Get-AutoValLog  $PR
			}
			"Validation-Merge-Conflict" {
			}
			"Validation-Installation-Error" {
				Get-AutoValLog  $PR
			}
			"Validation-Shell-Execute" {
				Get-AutoValLog  $PR
			}
			"Validation-Unattended-Failed" {
				Get-AutoValLog  $PR
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
			"Retry-1" {
				Add-PRLabel -PR $PR -Label "Validation-Completed" -Method PUT
				Add-PRLabel -PR $PR -Label "Retry-1" -Method POST
				Add-PRToRecord $PR "Manual"
			}
			"Validation-Completed" {
				Approve-PR $PR
				Add-PRToRecord $PR "Approved"
			}
			"Validation-Domain" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Executable-Error" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Forbidden-URL-Error" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Installation-Error" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-No-Executables" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Shell-Execute" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Unattended-Failed" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
			"Validation-Unapproved-URL" {
				Add-PRToRecord $PR "Waiver"
				$Waiver = $Label
			}
		}
		if ($Waiver -ne "") {
			$out = Invoke-GitHubPRRequest $PR -Type comments -Output StatusDescription -Method POST -Data "@wingetbot waivers Add $Waiver"
			Write-Output "$($PR): $out"
		}; # end if Waiver
	}; # end Foreach Label
}; # end Function

Function Get-GitHubPreset {
	param(
		$PR,
		[ValidateSet("Approved","AutomationBlock","ChangesRequested","CheckInstaller","BadPR","DefenderFail","Feedback","InstallerNotSilent","InstallerMissing","MergeConflicts","PackageUrl","ResetPR","Retry","Waiver")][string]$Preset,
		[string]$UserName = (Invoke-GitHubPRRequest $PR -Type "" -Output content -JSON).user.login,
		$CannedResponse = $Preset,
		$Label
	)
	Switch ($Preset) {
		"Approved" {
			Approve-PR $PR; 
			Add-PRToRecord $PR $Preset
		}
		"AutomationBlock" {
			Add-PRToRecord $PR Blocking
			Reply-ToPR -PR $PR -CannedResponse AutomationBlock -UserInput $UserName
			Add-PRLabel $PR Network-Blocker
		}
		"Blocking" {
			Add-PRLabel $PR Network-Blocker
			Add-PRToRecord $PR Blocking
		}
		"BadPR" {
			Reply-ToPR $PR -Body "Bad PR." ; 
			Add-PRToRecord $PR Closed
		}
		"ChangesRequested" {
			$Label = "Needs-Author-Feedback"
			Add-PRLabel -PR $PR -Label $Label
			Add-PRLabel $PR Changes-Requested
			Add-PRToRecord $PR Feedback
		}
		"CheckInstaller" {
			Reply-ToPR -PR $PR -Body (Check-PRInstallerStatus $PR)
		}
		"DefenderFail" {
			$Label = "Needs-Attention"
			Add-PRToRecord $PR "Blocking"
			Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput $UserName
			Add-PRLabel -PR $PR -Label $Label
			Add-PRLabel -PR $PR -Label "Validation-Defender-Error"
		}
		"Feedback" {
			Add-PRLabel $PR
			Add-PRToRecord $PR $Preset
		}
		"InstallerNotSilent" {
			$Label = "Needs-Author-Feedback"
			Add-PRToRecord $PR Feedback
			Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput $UserName
			Add-PRLabel -PR $PR -Label $Label
		}
		"InstallerMissing" {
			$Label = "Needs-Author-Feedback"
			Add-PRToRecord $PR Feedback
			Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput $UserName
			Add-PRLabel -PR $PR -Label $Label
		}
		"MergeConflicts" {
			Reply-ToPR -PR $PR -Body "Merge Conflicts."
			Add-PRToRecord $PR Closed
		}
		"OneManifestPerPR" {
			$Label = "Needs-Author-Feedback"
			Add-PRToRecord $PR Feedback
			Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput $UserName
			Add-PRLabel -PR $PR -Label $Label
		}
		"PackageUrl" {
			$Label = "Changes-Requested"
			Add-PRToRecord $PR Feedback
			Reply-ToPR -PR $PR -CannedResponse $CannedResponse -UserInput $UserName
			Add-PRLabel -PR $PR -Label $Label
		}
		"ResetPR" {
			Reply-ToPR $PR -Body "Reset PR."
			Invoke-GitHubPRRequest -PR $PR -Type assignees -Method DELETE -Data $UserName
			Add-PRToRecord $PR Closed
			Add-PRLabel -PR $PR -Method DELETE
		}
		"Retry" {
			Add-PRToRecord $PR Retry
		}
		"Waiver" {
			Add-Waiver $PR; 
			Add-PRToRecord $PR $Preset
		}
	}
}

#PR tools
#GET = Read; POST = Append; PUT = Write; DELETE = delete
Function Invoke-GitHubRequest {
	param(
		[Parameter(mandatory=$true)][string]$Uri,
		[string]$Body,
		[ValidateSet("DELETE","GET","HEAD","PATCH","POST","PUT")][string]$Method = "GET",
		$Headers = @{"Authorization"="Bearer $GitHubToken"; "Accept"="application/vnd.github+json"; "X-GitHub-Api-Version"="2022-11-28"},
		#[ValidateSet("content","StatusDescription")][string]$Output = "content",
		[switch]$JSON
	)
	if ($Body) {
		$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers -Body $Body -ContentType application/json)
	} else {
		$out = (Invoke-WebRequest -Method $Method -Uri $Uri -Headers $Headers)
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
	$uri = "https://api.github.com/repos/microsoft/winget-pkgs/$Path/$pr/$Type"

	if (($Type -eq "") -OR ($Type -eq "files")){
		$Path = "pulls"
		$uri = "https://api.github.com/repos/microsoft/winget-pkgs/$Path/$pr/$Type"
	} elseif ($Type -eq "comments") {
		$Response.body += $Data
	} elseif ($Type -eq "commits") {
		$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/commits -JSON
		$commit = (($prData.commit.url -split "/")[-1])
		$uri = "https://api.github.com/repos/microsoft/winGet-pkgs/$Type/$commit"
	} elseif ($Type -eq "reviews") {
		$Response.body = $Data
		$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/commits -JSON
		$Response.commit = ($prData.commit.url -split "/")[-1]
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
		$out.$Output | ConvertFrom-Json
	} elseif ($Output -eq "Silent") {
	} else {
		$out.$Output 
	}
}

Function Get-SearchGitHub {
	param(
		[ValidateSet("Approval","AutomaticWaiverAddition","Blocking","Created","Duplicate","Defender","IEDS","Incomplete","IEM","Label","NA","NAF","NANoIEDS","None","PrePipeline","Problematic","Squash","ToWork","ToWork2","User","VCNA")][string]$Preset = "Approval",
		[Switch]$Browser,
		$Url = "https://api.github.com/search/issues?page=$Page&q=",
		$Repo = "winget-pkgs",
		$Owner = "microsoft",
		$Author, #wingetbot
		[string]$Label,  #[ValidateSet("Error-Analysis-Timeout","Unexpected-File","Needs-CLA","Error-Analysis-Timeout")]
		$Page = 1,
		[int]$Days,
		[Switch]$IEDS,
		[Switch]$NotWorked,
		[Switch]$NoLabels
	)
	if ($Browser) {
		$Url = "https://github.com/$Owner/$Repo/pulls?page=$Page&q="
	}
	#Base settings
	$Base = "repo:$Owner/$Repo+"
	$Base = $Base + "is:pr+"
	$Base = $Base + "is:open+"
	$Base = $Base + "draft:false+"

	#Smaller blocks
	$nApproved = "-label:Moderator-Approved+"
	$nBI = "-label:Blocking-Issue+"
	$Defender = "label:Validation-Defender-Error"
	$HaventWorked =  "-commenter:stephengillie+"
	$nHW = "-label:Hardware+"
	$nIEDS = "-label:Internal-Error-Dynamic-Scan+"
	$IEM = "label:Internal-Error-Manifest+"
	$nIOI = "-label:Interactive-Only-Installer+"
	$NA =  "label:Needs-Attention+" 
	$NAF =  "label:Needs-Author-Feedback+" 
	$NotPass = "-label:Azure-Pipeline-Passed+" #Hasn't psased pipelines
	$SortUp = "sort:updated-asc+"
	$VC =  "label:Validation-Completed+" #Completed
	
	$date = Get-Date (Get-Date).AddDays(-7) -Format "yyyy-MM-dd"
	$Recent =  "created:%3E$($date)+" #Created in the past week.
	
	#-assignee:vedantmgoyal2009 
	
	#Building block settings
	$Blocking =  $nHW
	$Blocking = $Blocking + "-label:Internal-Error-NoSupportedArchitectures+"
	$Blocking = $Blocking + "-label:License-Blocks-Install+"
	$Blocking = $Blocking + "-label:Network-Blocker+"
	$Blocking = $Blocking + "-label:portable-jar+"
	$Blocking = $Blocking + "-label:Project-File+"
	$Blocking = $Blocking + "-label:Reboot+"
	$Blocking = $Blocking + "-label:Scripted-Application+"
	$Blocking = $Blocking + "-label:WindowsFeatures+"
	$Blocking = $Blocking + "-label:zip-binary+"
		
	$Common =  $nBI
	$Common = $Common + "-label:Internal-Error-Manifest+"
	$Common = $Common + "-label:Validation-Defender-Error+"

	$Cna=  $VC 
	$Cna= $Cna+ $nApproved
	
	$Review1= "-label:Changes-Requested+" 
	$Review1 = $Review1 + "-label:Needs-CLA+"
	$Review1= $Review1+ "-label:No-Recent-Activity+"

	$Review2 =  "-label:Needs-Attention+"
	$Review2 = $Review2 + "-label:Needs-Author-Feedback+"
	$Review2 = $Review2 + "-label:Needs-Review+"
	
	$Workable =  "-label:Possible-Duplicate+" 
	$Workable = $Workable + "-label:Validation-Merge-Conflict+" 
	
	#Composite settings
	$Set1 = $Blocking + $Common + $Review1
	$Set2 = $Set1 + $Review2

	$Url = $Url + $Base
	if ($Label) {
		$Url = $Url + "label:$(Label)+"
	}
	if ($Author) {
		$Url = $Url + "author:$($Author)+"
	}
	if ($Days) {
		$Url = $Url + $Recent
	}
	if ($NotWorked) {
		$Url = $Url + $HaventWorked
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
			$Url = $Url + $nBI
			$Url = $Url + "-"+$IEM
			$Url = $Url + $Defender
		}
	"IEDS" {
$Url = $Url + "label:Retry-1 +"
		$Url = $Url + $nBI
		$Url = $Url + $Blocking
		$Url = $Url + $NotPass
		$Url = $Url + "-"+$VC
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
			$Url = $Url + "-"+$VC
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
		$Url = $Url + "-"+$VC
	}
		"Problematic" {
			$Url = $Url + $nIOI
			$Url = $Url + $nApproved
			$Url = $Url + "-"+$NA
			$Url = $Url + $NotPass
			$Url = $Url + "-"+$VC
		}
		"Squash"{
			$Url = $Url + $nApproved
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + $VC
			$Url = $Url + $Workable
		}
		"ToWork"{
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + "-"+$VC
		}
		"ToWork2"{
			$Url = $Url + $HaventWorked
			$Url = $Url + $Recent
			$Url = $Url + $Set2 #Blocking + Common + Review1 + Review2
			$Url = $Url + "-"+$VC
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
	if ($IEDS) {
		$Url = $Url + $nIEDS
	}


	if ($Browser) {
		Start-Process $Url
	} else {
		$Response = Invoke-GitHubRequest $Url
		$Response = ($Response.Content | ConvertFrom-Json).items
		if (!($NoLabels)) {
			$Response = $Response  | where {$_.labels}
		}
		return $Response
	}
}

Function Open-PRInBrowser {
	param(
		[switch]$Review,
		[switch]$NoCheck,
		[ValidateSet("Approval","AutomaticWaiverAddition","Blocking","Created","Duplicate","Defender","IEDS","Incomplete","IEM","Label","NA","NAF","NANoIEDS","None","PrePipeline","Problematic","Squash","ToWork","ToWork2","User","VCNA")][string]$Preset = "Approval",
		$clip = (Get-Clipboard),
		$Page = 1,
		[Switch]$IEDS,
		[Switch]$NotWorked,
		$justPRs = (Get-SearchGitHub -Preset $Preset -Page $Page) #(Get-JustPRNumber $clip),
	)
	$PRlist = @()
	$line = 0
	If (!($NoCheck) -AND !($Review)) {
		foreach ($PR in $JustPRs) {
			$line++
			Get-TrackerProgress $PR.number $MyInvocation.MyCommand $line $justPRs.length
			if( (($PR.title -replace ":","" -split " ")[0] -ceq "Remove") -OR ((($PR.title -replace ":","" -split " ")[0..1] -join " ") -ceq "Automatic deletion") ){
				Get-GitHubPreset $PR.number CheckInstaller
			}
			if(Get-NonstandardPRComments $PR.number){
				$PRlist += $PR.number
			}
			$SearchString = "AntiMalware completed with exit code 2"
			$UserInput = Get-LineFromCommitFile $PR.number -LogNumber 37 -SearchString $SearchString -Length 10  | Where-Object {$_ -match $SearchString}
			if ($UserInput) {
				Reply-ToPR -PR $PR.number -UserInput $UserInput -CannedResponse AutoValEnd
				$PRlist += $PR.number
			}

		}
	} else {
		$PRlist  = $JustPRs.number
	}

	foreach ($PR in $PRlist){
		$URL = "https://github.com/microsoft/winGet-pkgs/pull/$PR#issue-comment-box"
		if ($Review) {
			$URL = "https://github.com/microsoft/winGet-pkgs/pull/$PR/files"
		}

		Start-Process $URL
		Start-Sleep $GitHubRateLimitDelay
	}
}

Function Get-AutoValLog {
	#Needs $GitHubToken to be set up in your $PROFILE or somewhere more secure. Needs permissions: workflow,
	param(
		$clip = (Get-Clipboard),
		$PR = ($clip -split "/" | select-string "[0-9]{5,6}" ),
		$DestinationPath = "$MainFolder\Installers",
		$LogPath = "$DestinationPath\InstallationVerificationLogs\",
		$ZipPath = "$DestinationPath\InstallationVerificationLogs.zip",
		[switch]$CleanoutDirectory,
		[switch]$DemoMode,
		[switch]$Force
	)
	#Get-Process *photosapp* | Stop-Process
	$BuildNumber = Get-BuildFromPR $PR 
	if ($BuildNumber) {

		#This downloads to Windows default location, which has already been set to $DestinationPath
		Start-Process "https://dev.azure.com/ms/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$BuildNumber/artifacts?artifactName=InstallationVerificationLogs&api-version=7.0&%24format=zip"
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
		if ($UserInput -ne "") {
			#Start-Process "https://github.com/microsoft/winGet-pkgs/pull/$PR"
			if ($UserInput -match "\[FAIL\] Installer failed security check.") {
				Get-GitHubPreset $PR DefenderFail
			}
			if ($UserInput -match "SQL error or missing database") {
				Get-RerunPR $PR
				Write-Output "PR $PR - SQL error or missing database"
				Start-Process "https://github.com/microsoft/winGet-pkgs/pull/$PR"
			}

			$UserInput = ($UserInput -split "`n") -notmatch ' success or error status`: 0'
			$UserInput = ($UserInput -split "`n") -notmatch 'api-ms-win-core-errorhandling'
			$UserInput = ($UserInput -split "`n") -notmatch '``Windows Error Reporting``'
			$UserInput = ($UserInput -split "`n") -notmatch 'The FileSystemWatcher has detected an error '
			$UserInput = $UserInput -replace "2023-","`n> 2023-"
			$UserInput = $UserInput -replace " MSI ","`n> MSI "
			$UserInput = $UserInput | Select-Object -Unique

			$UserInput = "Automatic Validation ended with:`n> "+$UserInput
			$UserInput += "`n`n(Automated response - build $build.)"

			if ($DemoMode) {
				Write-Host "PR: $PR - DemoMode: Created"
			} else {
				$out = Reply-ToPR -PR $PR -Body $UserInput
				Write-Host "PR: $PR - $out"
			}
		} else {
			Write-Host "PR: $PR - No errors to post."
		}
	} else {
		Write-Host "PR: $PR - No errors to post."
	}
}

Function Get-BuildFromPR {
	param(
		$PR,
		$content = ((Invoke-GitHubRequest "https://dev.azure.com/ms/winGet-pkgs/_apis/build/builds?branchName=refs/pull/$PR/merge&api-version=6.0").content | ConvertFrom-Json),
		$href = ($content.value[0]._links.web.href),
		$build = (($href -split "=")[1])
	)
	return $build
}

Function Get-ADOLog {
	param(
		$PR,
		$build = (Get-BuildFromPR $PR),
		$LogNumber = (36),
		$content = (Invoke-GitHubRequest https://dev.azure.com/ms/ed6a5dfa-6e7f-413b-842c-8305dd9e89e6/_apis/build/builds/$build/logs/$LogNumber).content
	)
	$content = $content -join "" -split "`n"
	return $content
}

Function Get-LineFromCommitFile {
	param(
		$PR,
		$LogNumber = (36),
		$SearchString = "Specified hash doesn't match",
		$Log = (Get-ADOLog $PR -Log $LogNumber),
		$MatchOffset = (-1),
		$MatchLine = (($Log | Select-String -SimpleMatch $SearchString).LineNumber + $MatchOffset),
		$Length = 0,
		$EndLine = ($MatchLine + $Length),
		$output = ($Log[$MatchLine..$EndLine])
	)
	return $output
}

Function Get-CommitFile {
	param(
		$PR,
		$File = 0
	)
	$Commit = Invoke-GitHubPRRequest -PR $PR -Type commits -Output content -JSON
	$CommitFile = Invoke-GitHubRequest -Uri $Commit.files.contents_url[$File]
	$EncodedFile = $CommitFile.Content  | ConvertFrom-Json
	Get-DecodeGitHubFile $EncodedFile.content

}

#$fileInsert = "Dependencies:`n  PackageDependencies:`n  - PackageIdentifier: $Dependency"
#$Suggestion = "``````suggestion`n$fileInsert`n``````"
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

	$uri = "https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/comments"

	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body 
	$out.StatusDescription
}

Function Get-UpdateHashInPR {
	param(
		$PR,
		$SearchTerm = "Expected hash",
		$SearchString = (Get-YamlValue $SearchTerm),
		$LineNumbers = ((Get-CommitFile $PR | Select-String $SearchString).LineNumber),
		$ReplaceTerm = "Actual hash",
		$ReplaceString = ("  InstallerSha256: "+(Get-YamlValue $ReplaceTerm)),
		$comment = "``````suggestion`n$ReplaceString`n``````"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
	Add-PRToRecord $PR "Feedback"
}

Function Add-DependencyToPR {
	param(
		$PR,
		$Dependency,
		$SearchString = "Installers:",
		$LineNumbers = ((Get-CommitFile $PR | Select-String $SearchString).LineNumber),
		$ReplaceString = "Dependencies:`n  PackageDependencies:`n  - PackageIdentifier: $Dependency`nInstallers:",
		$comment = "``````suggestion`n$ReplaceString`n``````"
	)
	foreach ($Line in $LineNumbers) {
		Add-GitHubReviewComment -PR $PR -Comment $comment -LIne $Line
	}
}

Function Approve-PR {
	param(
		$PR,
		[string]$Body = "",
		$prData = (Invoke-GitHubRequest https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/commits -JSON),
		$commit = (($prData.commit.url -split "/")[-1]),
		$uri = "https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/reviews"
	)

	$Response = @{}
	$Response.body = $Body
	$Response.commit = $commit
	$Response.event = "APPROVE"
	[string]$Body = $Response | ConvertTo-Json

	$out = Invoke-GitHubRequest -Method Post -Uri $uri -Body $Body 
	$out.StatusDescription
}

Function Get-CannedResponse {
	param(
		[ValidateSet("AppFail","Approve","AutomationBlock","AutoValEnd","AppsAndFeaturesNew","AppsAndFeaturesMissing","Drivers","DefenderFail","HashFailRegen","InstallerFail","InstallerMissing","InstallerNotSilent","NormalInstall","InstallerUrlBad","ListingDiff","ManValEnd","ManifestVersion","NoCause","NoExe","NoRecentActivity","NotGoodFit","OneManifestPerPR","Only64bit","PackageFail","PackageUrl","Paths","PendingAttendedInstaller","RemoveAsk","Unattended","Unavailable","UrlBad","WhatIsIEDS","WordFilter")]
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
			$out = "Hi $Username`n`nWe don't often see the `1.0.0` manifest version anymore. Would it be possible to upgrade this to the [1.5.0](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.5.0) version, possibly through a tool such as [WinGetCreate](https://learn.microsoft.com/en-us/windows/package-manager/package/manifest?tabs=minschema%2Cversion-example), [YAMLCreate](https://github.com/microsoft/winget-pkgs/blob/master/Tools/YamlCreate.ps1), or [Komac](https://github.com/russellbanks/Komac)? "
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
			$out = "Hi $Username`n`nCould you add an PackageUrl?"
		}
		"Paths" {
			$out = "Please update file name and path to match this change."
		}
		"PendingAttendedInstaller" {
			$out = "Pending:`n* https://github.com/microsoft/winGet-cli/issues/910"
		}
		"Unattended" {
			$out = "Hi $Username`n`nThe installation isn't unattended:`n`nIs there an installer switch to bypass this and have it install automatically?"
		}
		"RemoveAsk" {
			$out = "Hi $Username`n`nThis package installer is still available. Why should it be removed?"
		}
		"Unavailable" {
			$out = "Hi $Username`n`nThe installer isn't available from the publisher's website:"
		}
		"UrlBad" {
			$out = "Hi $Username`n`nI'm not able to find this InstallerUrl from the PackageUrl. Is there another page on the developer's site that has a link to the package?"
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

Function Get-PRApproval {
	param(
		$Clip = (Get-Clipboard),
		[int]$PR = (($Clip -split "#")[1]),
		$PackageIdentifier = ((($clip -split ": ")[1] -split " ")[0]),
		$auth = (Get-Content  C:\repos\winGet-pkgs\Tools\Auth.csv | ConvertFrom-Csv),
		$Approver = ((($auth | Where-Object {$_.PackageIdentifier -match $PackageIdentifier}).account -split "/" | Where-Object {$_ -notmatch "\("}) -join ", @"),
		[switch]$DemoMode
	)
	if ($DemoMode) {
		Write-Host "DemoMode: Reply-ToPR $pr requesting approval from @$Approver."
	} else {
		Reply-ToPR $pr (Get-CannedResponse approve $Approver -NoClip)
	}
}

Function Get-NonstandardPRComments {
	param(
		$PR,
		$comments = (Invoke-GitHubPRRequest $PR -Type comments -Output content)
	)
	$comments = $comments.body
	$comments = $comments | Where-Object {$_ -notmatch "Validation Pipeline Badge"} #Pipeline status
	$comments = $comments | Where-Object {$_ -notmatch "AzurePipelines run"} #Run pipelines
	$comments = $comments | Where-Object {$_ -notmatch "Azure Pipelines successfully started running 1 pipeline"} #Run confirmation
	$comments = $comments | Where-Object {$_ -notmatch "The check-in policies require a moderator to approve PRs from the community"} #Validation complete 
	$comments = $comments | Where-Object {$_ -notmatch "microsoft-github-policy-service agree"} #CLA acceptance
	$comments = $comments | Where-Object {$_ -notmatch "wingetbot waivers Add"} #Any waivers
	$comments = $comments | Where-Object {$_ -notmatch "This account is bot account and belongs to CoolPlayLin"} #CoolPlayLin's automation
	$comments = $comments | Where-Object {$_ -notmatch "This account is automated by Github Actions and the source code was created by CoolPlayLin"} #Exorcism0666's automation
	$comments = $comments | Where-Object {$_ -notmatch "Response status code does not indicate success"} #My automation - removal PR where URL failed status check.

	return $comments
}

Function Get-RetryDefender {
	param(
		$PRs = (Get-SearchGitHub Defender).number
	)
	$Line = 0
	Foreach ($PR in $PRs) {
		$Line++
		Get-TrackerProgress $PR $MyInvocation.MyCommand $Line $PRs.length
		$comments = (Invoke-GitHubPRRequest $PR -Type comments -Output content)
		if ($comments) {
			if (($comments[-2].body -match "This might be a false positive and we can rescan tomorrow.") -and
			([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($comments[-2].created_at, 'Pacific Standard Time') -lt (Get-Date).AddHours(-18)) -and
			($comments[-1].body -match "Installer failed security check") -and
			([TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($comments[-1].created_at, 'Pacific Standard Time') -lt (Get-Date).AddHours(-18))) {
				#If the last 2 comments were automated virus detection, and made more than 18 hours ago. 18 instead of 24 because this handles someone who worked on this at the end of one 8-hour workday and the start of the next.
				Get-RerunPR $PR
			} else {
				Start-Process "https://github.com/microsoft/winGet-pkgs/pull/$PR#issue-comment-box"
			}# end if comments inner
		}# end if comments outer
	}# end foreach PR
}# end Function

Function Add-PRLabel {
	param(
		$PR,
		[ValidateSet("Changes-Requested","Network-Blocker","Needs-Author-Feedback","Retry-1","Needs-Attention","Validation-Defender-Error","Validation-Completed")]
		[string]$Label = "Needs-Author-Feedback",
		[ValidateSet("GET","DELETE","POST","PUT")]
		[string]$Method = "POST"
	)
	Invoke-GitHubPRRequest -PR $PR -Method $Method -Type "labels" -Data $Label
}

Function Get-PRTitle {
	param(
		$PR
	)
	(invoke-GitHubPRRequest -PR $PR -Type "" -Output content -JSON).title
}

Function Update-PR {
	param(
		$PR,
		[string]$Title = "",
		[string]$Body = "",
		[ValidateSet("open","closed")][string]$State = "open"
	)

	$prData = Invoke-GitHubRequest https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/commits -JSON
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
	$uri = "https://api.github.com/repos/microsoft/winGet-pkgs/pulls/$pr/update-branch"

	Invoke-GitHubRequest -Uri $uri -Method Post -Body $Body -Output StatusDescription 
}

Function Reply-ToPR {
	param(
		$PR,
		[string]$CannedResponse,
		[string]$UserInput = ((Invoke-GitHubPRRequest $PR -Type "" -Method get -Output content -JSON).user.login),
		[string]$Body = (Get-CannedResponse $CannedResponse -UserInput $UserInput -NoClip),
		[Switch]$Silent
	)

	if ($Silent) {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output StatusDescription -Silent
	} else {
		Invoke-GitHubPRRequest -PR $PR -Method Post -Type "comments" -Data $Body -Output StatusDescription
	}
}

Function Add-UserToPR {
	param(
		$PR,
		[array]$User = $GitHubUserName,
		[string]$Method,
		[switch]$Silent
	)
	if ($Silent) {
		Invoke-GitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription -Silent
	} else {
		Invoke-GitHubPRRequest -Method $Method -Type "assignees" -Data $User -Output StatusDescription
	}
}

Function Get-RerunPR {
	param(
		$PR
	)
	Invoke-GitHubPRRequest $PR -Type comments -Output StatusDescription -Method POST -Data "/AzurePipelines run"
	Add-PRToRecord $PR "Retry"
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
		[int]$PR = (Get-JustPRNumber $out),
		$RemoteFolder = "//$remoteIP/ManVal/vm/$vm",
		$installerLine = "--manifest $RemoteFolder/manifest",
		[ValidateSet("x86","x64","arm","arm32","arm64","neutral")][string]$Arch,
		[ValidateSet("User","Machine")][string]$Scope,
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
		Get-TrackerVMSetStatus "Prevalidation" $vm $PackageIdentifier $PR -Silent
	} else {
		Get-TrackerVMSetStatus "Prevalidation" $vm $PackageIdentifier $PR
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
	$Archs = ($out | Select-String -notmatch "arm"| select-string "Architecture: " )|ForEach-Object{($_ -split ": ")[1]} 
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
	`$errArray | ForEach-Object {Out-Log `$_ 'red'}
};
Get-TrackerVMSetStatus 'Installing'
Out-Log ' = = = = Starting Manual Validation pipeline version $build on VM $vm  $PackageIdentifier $logLine  = = = = '

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
`$mainpackage = (Start-Process 'winget' `$wingetArgs  -wait -PassThru);

Out-Log `"`$(`$mainpackage.processname) finished with exit code: `$(`$mainpackage.ExitCode)`";
If (`$mainpackage.ExitCode -ne 0) {
	Out-Log 'Install Failed.';
	explorer.exe `$WinGetLogFolder;
Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'

Out-Log `" = = = = Failing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
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
`$files = `$files | Where-Object {`$_ -notmatch 'unins'} | Where-Object {`$_ -notmatch 'dotnet'} | Where-Object {`$_ -notmatch 'redis'} | Where-Object {`$_ -notmatch 'System32'} | Where-Object {`$_ -notmatch 'SysWOW64'} | Where-Object {`$_ -notmatch 'WinSxS'} | Where-Object {`$_ -notmatch 'dump64a'} | Where-Object {`$_ -notmatch 'CbsTemp'}
`$files | Out-File 'C:\Users\user\Desktop\ChangedFiles.txt'
`$files | select-string '[.]exe`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | select-string '[.]msi`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};
`$files | select-string '[.]lnk`$' | ForEach-Object {if (`$_ -match '$packageName') {Out-Log `$_ 'green'}else{Out-Log `$_ 'cyan'}; try{Start-Process `$_}catch{}};

Out-Log `" = = = = End file list. Starting Defender scan.`"
Start-MpScan;

Out-Log `"Defender scan complete, closing windows...`"
(Get-process | Where-Object { `$_.mainwindowtitle -ne '' -and `$_.processname -notmatch '$packageName' -and `$_.processname -ne 'powershell'  -and `$_.processname -ne 'WindowsTerminal' -and `$_.processname -ne 'csrss' -and `$_.processname -ne 'dwm'})| ForEach-Object {
	`$process = (Stop-Process `$_ -PassThru);
	Out-Log `"`$(`$process.processname) finished with exit code: `$(`$process.ExitCode)`";
}

Out-ErrorData ((Get-ChildItem `$WinGetLogFolder).fullname | ForEach-Object {Get-Content `$_ |Where-Object {`$_ -match '[[]FAIL[]]' -OR `$_ -match 'failed' -OR `$_ -match 'error' -OR `$_ -match 'does not match'}}) 'WinGet'
Out-ErrorData '$MDLog' 'Manual' 'Dependency'
Out-ErrorData `$Error 'PowerShell'
Out-ErrorData (Get-EventLog Application -EntryType Error -after `$TimeStart  -ErrorAction Ignore).Message 'Application Log'
Out-ErrorData (Get-MPThreat).ThreatName `"Defender (with signature version `$((Get-MpComputerStatus).QuickScanSignatureVersion))`"

Out-Log `" = = = = Completing Manual Validation pipeline version $build on VM $vm for $PackageIdentifier $logLine in `$(((Get-Date) -`$TimeStart).TotalSeconds) seconds. = = = = `"
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
		Get-RemoveFileIfExist "$manifestFolder"  -remake -Silent
		$Files = @()
		$Files += "Package.installer.yaml"
		$FileNames = ($out | select-string "[.]yaml") |ForEach-Object{($_ -split "/")[-1]}
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
			$fileContents -replace "0New version: ","0" -replace "0New package: ","0" -replace "0Add version: ","0" -replace "0Add package: ","0" -replace "0Add ","0" -replace "0New ","0" -replace "0package:  ","0" | Out-File $FilePath
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
		$PackageIdentifier = (Get-YamlValue PackageIdentifier),
		$version = ((Get-YamlValue PackageVersion) -replace "'","" -replace '"',""), 
		$listing = (Get-ManifestListing $PackageIdentifier),
		$vm = (Get-ManifestFile)[-1]
	)
	
	for ($file = 0; $file -lt $listing.length;$file++) {
		Get-ManifestFile $vm -clip (Get-WinGetFile -PackageIdentifier $PackageIdentifier -Version $version -FileName $listing[$file])
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
		$content = (Invoke-GitHubRequest -Uri "https://raw.githubusercontent.com/microsoft/winGet-pkgs/master/manifests/$FirstLetter/$Path/$Version/$PackageIdentifier.$FileName").content
	}catch{
		$content = "Error"
	}
	return ($content -split "`n")
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

Function Get-ManifestFile {
	param(
		[int]$vm = ((Get-NextFreeVM) -replace "vm",""),
		$clip = (Get-SecondMatch),
		$FileName = "Package",
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
			Get-RemoveFileIfExist "$manifestFolder"  -remake
			$FileName = "$FileName.installer"
		}
		"version" {
			if ($Arch) {
				Get-TrackerVMValidate -vm $vm -NoFiles -Arch $Arch -PR $PR
			} elseif ($OS) {
				Get-TrackerVMValidate -vm $vm -NoFiles -OS $OS  -PR $PR
			} elseif ($Scope) {
				Get-TrackerVMValidate -vm $vm -NoFiles -Scope $Scope  -PR $PR
			} else {
				Get-TrackerVMValidate -vm $vm -NoFiles  -PR $PR
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

Function Get-TrackerProgress {
	param(
		$PR,
		$Activity,
		$Incrementor,
		$Length,
		$Percent = [math]::round($Incrementor / $length*100,2)
	)
	Write-Progress -Activity $Activity -Status "$PR - $Incrementor / $Length = $Percent %"  -PercentComplete $Percent
}

Function Check-PRInstallerStatusInnerWrapper {
	param(
		$Url,
		$Code = (Invoke-GitHubRequest $Url -Method Head -ErrorAction SilentlyContinue).StatusCode
	)
	return $Code
}

Function Check-PRInstallerStatus {
	param(
		$PR,
		$Pull = (Invoke-GitHubPRRequest $PR -Type files -Output content -JSON),
		$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[0] -JSON).content)),
		$Url = (Get-YamlValue -StringName InstallerUrl -clip $PullInstallerContents)
	)
	$out = ""
	try {
		$out = "Status Code: "+(Check-PRInstallerStatusInnerWrapper $Url)}catch{$out = $error[0].Exception.Message
	}
	$out = "URL: $Url `n"+$out + "`n`n(Automated message - build $build)"
	return $out
}

Function Check-Duplicate {
	param(
		$PR,
		$Pull = (Invoke-GitHubPRRequest $PR -Type files -Output content -JSON),
		$PullInstallerContents = (Get-DecodeGitHubFile ((Invoke-GitHubRequest -Uri $Pull.contents_url[0] -JSON).content)),
		$Url = (Get-YamlValue -StringName InstallerUrl -clip $PullInstallerContents),
		$PackageIdentifier = (Get-YamlValue -StringName PackageIdentifier -clip $PullInstallerContents),
		$Version = (Find-WinGetPackage $PackageIdentifier | where {$_.ID -eq $PackageIdentifier}).Version,
		$out = ($PullInstallerContents -match $Version)
	)
	return $out | select-string "http"
}

Function Get-ManifestListing {
	param(
		$PackageIdentifier,
		$Version = (Find-WinGetPackage $PackageIdentifier | Where-Object {$_.id -eq $PackageIdentifier}).version,
		$Path = ($PackageIdentifier -replace "[.]","/"),
		$FirstLetter = ($PackageIdentifier[0].tostring().tolower())
	)
	try{
		$Names = (Invoke-GitHubRequest -Uri "https://api.github.com/repos/microsoft/winGet-pkgs/contents/manifests/$FirstLetter/$Path/$Version/" -JSON).name
	}catch{
		$Names = "Error"
	}
	return $Names -replace "$($PackageIdentifier)[.]",""
}

Function Get-ListingDiff {
	param(
		$Clip = (Get-Clipboard),
		$PackageIdentifier = (Get-YamlValue PackageIdentifier $Clip -replace '"',""),
		$CurrentManifest = (Get-ManifestListing $PackageIdentifier),
		$PRManifest = ($clip -split "`n" | Where-Object {$_ -match ".yaml"} | Where-Object {$_ -match $PackageIdentifier} |%{($_ -split "/")[-1] -replace "$($PackageIdentifier)[.]",""})
	)
	if ($CurrentManifest -ne "Error") {
		diff $currentManifest $PRManifest
	} else {
		$CurrentManifest
	}
}

Function Check-FileExist {
	param(
		$PackageIdentifier,
		$Version,
		$Type
	)
	$content = Get-WinGetFile $PackageIdentifier $Version $Type
	if ($content -ne "Error") {$true} else {$false}
}

Function Get-OSFromVersion {
	try{
		if ([system.version](Get-YamlValue -StringName MinimumOSVersion) -ge [system.version]"10.0.22000.0"){"Win11"}else{"Win10"}
	} catch {
		"Win10"
	}
}

#VM Management
Function Complete-TrackerVM {
	param(
		[Parameter(mandatory=$true)][int]$vm,
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
			$vmImageFolder = "$imagesFolder\Win10-image\Virtual Machines\0CF98E8A-73BB-4E33-ABA6-7513F376407D.vmcx"
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
		[Parameter(mandatory=$true)][int]$vm,
		$destinationPath = "$imagesFolder\$vm\",
		$VMFolder = "$MainFolder\vm\$vm",
		$vmName = "vm$vm"
	)
	Test-Admin
	Get-TrackerVMSetStatus 'Disgenerate' $vm
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
			$OriginalLoc = "$imagesFolder\Win10-Created061623-SecondFolder"
		}
		"Win11" {
			$OriginalLoc = "$imagesFolder\Win11-Created030623-Original\"
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

Function Get-RemovePR {
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
	Write-Host "go make PR on GitHub"
}

Function Get-ArraySum {
	param(
		$in = 0,
		$out = 0
	)
	$in |ForEach-Object{$out += $_*1}
	[math]::Round($out,2)
}

#VM Orchestration
Function Get-TrackerVMRunTracker {
	while ($true) {
		Clear-Host
		$GetStatus = Get-Status
		$GetStatus | Format-Table;
		$VMRAM = Get-ArraySum $GetStatus.RAM
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
		Get-TrackerVMMemCheck;
		Get-TrackerVMRAM;
		Get-TrackerVMCycle;

		$clip = (Get-Clipboard)
		If ($clip -match  "https://dev.azure.com/ms/") {
			Write-Host "Gathering Automated Validation Logs"
			Get-AutoValLog
		} elseIf ($clip -match  "Skip to content") {
			$valMode = Get-TrackerMode
			if ($valMode -eq "Validating") {

				Write-Host $valMode
				Get-TrackerVMValidate;
				$valMode | clip
			}
		} elseIf ($clip -match  " Windows Package Manager") {
			Write-Host "Gathering PR Headings"
			Get-PRNumber
		} elseIf ($clip -match  "^manifests`/") {
			Write-Host "Opening manifest file"
			$ManifestUrl = "https://github.com/microsoft/winGet-pkgs/tree/master/"+$clip
			$ManifestUrl | clip
			start-process ($ManifestUrl)
		}
		if (!(Get-ConnectedVM)) {
			Get-TrackerVMResetStatus
			Get-TrackerVMRotate
		}
		Start-Sleep 5;
	}
}

Function Get-TrackerVMCycle {
	param(
	)
	$VMs = Get-Status
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
				Complete-TrackerVM $VM.vm
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
				$SharedError = (Get-SharedError -NoClip)
				Reply-ToPR -PR $VM.PR -UserInput $SharedError -CannedResponse ManValEnd 
				Get-TrackerVMSetStatus "Complete" $VM.vm
				if ($SharedError -match "\[FAIL\] Installer failed security check.") {Get-GitHubPreset $VM.PR DefenderFail}
			}
			default {
				#Write-Host "Complete"
			}
		}; #end switch
	}
}

Function Get-TrackerVMSetStatus {
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

Function Get-TrackerMode {
	param(
		$mode = (Get-Content $TrackerModeFile)
	)
	$mode
}

Function Get-TrackerVMSetMode {
	param(
		[ValidateSet("Validating","Approving","Idle")]
		$Status = "Validating"
	)
	$Status | out-file $TrackerModeFile
}

Function Get-TrackerVMMemCheck {
	Param(
		$VMs = (Get-VM)
	)
	$VMs | ForEach-Object {
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

Function Get-ExistingVM {
	Test-Admin
	(Get-VM).name |select-string -notmatch "Win"
}

Function Get-TrackerVMRAM {
	$status = Get-Status
	$status |ForEach-Object {$_.RAM = [math]::Round((Get-VM -Name ("vm"+$_.vm)).MemoryAssigned/1024/1024/1024,2)}
	Write-Status $status
}

Function Get-TrackerVMLaunchWindow {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-ConnectedVM | Where-Object {$_.vm -match $VMName} | ForEach-Object {Stop-Process -id $_.id}
	C:\Windows\System32\vmconnect.exe localhost $VMName
}

Function Redo-Checkpoint {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Get-TrackerVMSetStatus "Checkpointing" $vm
	Remove-VMCheckpoint -Name $CheckpointName -VMName $VMName
	Checkpoint-VM -SnapshotName $CheckpointName -VMName $VMName
	Get-TrackerVMSetStatus "Complete" $vm
}

Function Get-TrackerVMRevert {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm",
		[Switch]$Silent
	)
	Test-Admin
	if ($Silent) {
		Get-TrackerVMSetStatus "Restoring" $vm -Silent
	} else {
		Get-TrackerVMSetStatus "Restoring" $vm
	}
	Restore-VMCheckpoint -Name $CheckpointName -VMName $VMName -Confirm:$false
}

Function Get-TrackerVMVersion {[int](Get-Content $VMversion)}

Function Get-TrackerVMSetVersion {param([int]$Version) $Version|out-file $VMversion}

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

Function Stop-TrackerVM {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		$VMName = "vm$vm"
	)
	Test-Admin
	Stop-VM $VMName -TurnOff
}

Function Get-TrackerVMReset {
	Get-Status | Where-Object {$_.Status -ne "Ready"} | Where-Object {$_.Package -eq ""} | %{Get-TrackerVMSetStatus Complete $_.VM}
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
			Get-RemoveFileIfExist $FileName
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

Function Get-ManifestFileCheck {
	param(
		[Parameter(mandatory=$true)][int]$vm,
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

#Inject dependencies
Function Add-ValidationData {
	param(
		[Parameter(mandatory=$true)][int]$vm,
		[ValidateSet("Microsoft.VCRedist.2015+.x64","Microsoft.DotNet.DesktopRuntime.8","Oracle.JavaRuntimeEnvironment")]$Common = "Microsoft.VCRedist.2015+.x64",
		$Dependency = $Common,
		$VMFolder = "$MainFolder\vm\$vm",
		$manifestFolder = "$VMFolder\manifest",
		$FilePath = "$manifestFolder\Package.installer.yaml",
		$fileContents = (Get-Content $FilePath),
		$Selector = "Installers:",
		$offset = 1,
		$lineNo = (($fileContents| Select-String $Selector -List).LineNumber -$offset),
		$fileInsert = "Dependencies:`n  PackageDependencies:`n  - PackageIdentifier: $Dependency",
		$fileOutput = ($fileContents[0..($lineNo -1)]+$fileInsert+$fileContents[$lineNo..($fileContents.length)])
	)
		Write-Host "Writing $($fileContents.length) lines to $FilePath"
		Out-File -FilePath $FilePath -InputObject $fileOutput
		Get-TrackerVMSetStatus "Revert" $VM;
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
	Add-ValidationData $vm -Selector $Selector -fileInsert $fileInsert #-Force
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
	if (	((Get-Content $timecardfile)[-1] -split " ")[1] -eq "Start"){
		$True
	}  else {
		$False
	}
}

#Reporting
Function Add-PRToRecord {
	param(
		$PR,
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action
	)
	"$PR,$Action" | Out-File $LogFile -Append 
}

Function Get-PRFromRecord {
	param(
		[ValidateSet("Approved","Blocking","Feedback","Retry","Manual","Closed","Project","Squash","Waiver")]
		$Action
	)
	("PR,Action`n" + (Get-Content $LogFile)) -split " " | ConvertFrom-Csv | Where-Object {$_.Action -match $Action}
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
		$Title = Get-PRTitle $PR
		Get-TrackerProgress $PR $MyInvocation.MyCommand $line $Record.length
		$out += "$Title #$PR`n";
	}
	if ($NoClip) {
		return $out
	} else {
		$out | clip
	}
}

#Clipboard
Function Get-PRNumber { #Returns with leading hash (#123456), defaults to clipboard output.
	param(
		$out = (Get-Clipboard),
		[switch]$NoClip,
		$dashboardPRRegex = "[0-9]{5,6}[:]"
	)
	$out = $out | select-string $dashboardPRRegex| Sort-Object -descending
	if ($NoClip) {
		$out
		} else {
		$out | clip
	}
}

Function Get-JustPRNumber { #Returns without leading hash (123456)
	param(
		$out = (Get-Clipboard),
		$dashboardPRRegex = "[#][0-9]{5,6}"
	)
	$out = ($out -split " " | select-string $dashboardPRRegex) -replace '#','' | Sort-Object -unique
	return $out
}

Function Get-SortedClipboard {
	param(
		$out = ((Get-Clipboard) -split "`n")
	)
	$out | Sort-Object | clip
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

Function Get-RemoveFileIfExist {
	param(
		$FilePath,
		[switch]$remake,
		[switch]$Silent
	)
	if (test-path $FilePath) {Remove-Item $FilePath -recurse}
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
	$clip = ($clip | select-string $StringName)
	$clip = ($clip -split ": ")[1]
	$clip = ($clip -split "#")[0]
	$clip = ((($clip.ToCharArray()) | where {$_ -match "\S"}) -join "")
	Return $clip
}

Function Test-Admin {
	if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){Write-Host "Try elevating your session.";break}
}

Function Find-InstallerSet {
	param(
		$clip = (Get-Clipboard),
		$delineator = "- "
	)
	$optionsLine = ($clip | select-string "Installers:").LineNumber
	$manifestLine = ($clip | select-string "ManifestType:").LineNumber[0] -2
	$InstallerSection = $clip[$optionsLine..$manifestLIne]
	$setCount = ($InstallerSection | Select-String $delineator).count
	Write-Host "$setCount sets detected:"
	$InstallerSection -split $delineator | ForEach-Object {
		$inputVar = $_
		Write-Host $inputVar

	#Arch, Scope, Locale
		$out = @{};
		$inputVar -split "`n" | ForEach-Object {
			$key,$value = ($_ -split ": " -replace " ","");
			$out[$key] = $value
		}
		$out["ProductCode"]
		$out.Remove("")
	}
}

Function Get-DecodeGitHubFile {
	param(
		[string]$Base64String,
		$Bits = ([Convert]::FromBase64String($Base64String)),
		$String = ([System.Text.Encoding]::UTF8.GetString($Bits))
	)
	return $String  -split "`n"
}

#Etc
Function Convert-ImageToBase64Link {
	param(
		$FileName = "C:\ManVal\misc\forbidden.png"
	)
	[String]$base64 = [convert]::ToBase64String((Get-Content $FileName -AsByteStream -Raw))
	$Ext = ($FileName -split "[.]")[1]
	return "<img src=`"data:image/$Ext;base64, $base64`" />"
}

