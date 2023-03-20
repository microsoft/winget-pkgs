#Copyright 2023 Microsoft Corporation
#Author: Stephen Gillie
#Created: 2/15/2023
#Updated: 2/24/2023
#Notes: Streamlines WinGet-pkgs manifest PR moderator approval by watching the clipboard - copy a PR title to your clipboard, and Watch-PRTitles attempts to parse the PackageIdentifier and version number, gathers the version from WinGet, and gives feedback in your Powershell console. Also outputs valid titles to a logging file. Freeing moderators to focus on approving and helping. 

function Watch-PRTitles {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		$LogFile = ".\PR.txt",
		$authFile = ".\Auth.csv",
		[ValidateSet("Default","MonoWarm","MonoCool","RainbowRotate")]
		$Chromatic = "Default",
		$oldclip = "",
		$hashPRRegex = "[#][0-9]{5,6}"
	)
	while($true){
		$clip = ((Get-Clipboard) -join "") -replace "PackageVersion:"," version" | select-string -NotMatch "^[c][:]";
		if (Test-Path $authFile) {
			$AuthList = Get-Content $authFile | ConvertFrom-Csv
		}
		if ($clip) {
			if (Compare-Object $clip $oldclip) {
				$timevar = (get-date -Format T) + ":"
				$copyClip = $false
				$noRecord = $false

				$title = $clip -split ": "
				if ($title[1]) {
					$title = $title[1] -split " "
				} else {
					$title = $title -split " "
				}
				#Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. For some reason almost everyone puts the version number as the last item, and GitHub appends the PR number. 
				$prVerLoc =($title | Select-String "version").linenumber 
				#Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch. 
				if ($null -ne $prVerLoc) {
					try {
						[System.Version]$prVersion = $title[$prVerLoc]
						#Write-Debug 0 $title[$prVerLoc]
					} catch {
						[string]$prVersion = $title[$prVerLoc]
						#Write-Debug 1 $title[$prVerLoc]
					}
				}; #end if null
				
				#Otherwise we have to go hunting for the version number.
				try {
					[System.Version]$prVersion = $title[-1]
					#Write-Debug 2 $title[-1]
				} catch {
					try {
						[System.Version]$prVersion = $title[-2]
						#Write-Debug 3 $title[-2]
					} catch {
						try {
							[System.Version]$prVersion = $title[-3]
							#Write-Debug 4 $title[-3]
						} catch {
							try {
								[System.Version]$prVersion = $title[-4]
								#Write-Debug 5 $title[-4]
							} catch {
								#If it's not a semantic version, guess that it's the 2nd to last, based on the above logic.
								[string]$prVersion = $title[-2]
								#Write-Debug 6 $title[-2]
							}
						}
					}
				}; #end try
				$validColor = "green"
				$invalidColor = "red"
				$cautionColor = "yellow"
				
				Switch ($Chromatic)
					#Color schemes, to accomodate needs and also add variety.
					{
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
						"RainbowRotate" {
							$validColor = Get-Random ("Green","White","Gray")
							$invalidColor = Get-Random ("Red","Blue","Magenta")
							$cautionColor = Get-Random ("Yellow","DarkCyan","Cyan")
						}
						Default {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
					}; #end Switch Chromatic
				
				#Get the PackageIdentifier out of the PR title, and alert if it matches the auth list.
				$cleanOut = (Get-CleanClip $clip); 
				$AuthMatch = $AuthList.PackageIdentifier -match ($cleanOut.split("[.]")[0]+"."+$cleanOut.split("[.]")[1])
				if ($AuthMatch) {
					$AuthListLine = $AuthList | Where-Object {$_.PackageIdentifier -match $AuthMatch}
					$strictness = $AuthListLine.strictness | Sort-Object -Unique
					$AuthAccount = $AuthListLine.account | Sort-Object -Unique
					$strictColor = ""
					if ($strictness -eq "must") {
						$strictColor = $invalidColor
					} else {
						$strictColor = $cautionColor
					}
					Write-Host -nonewline " = = = = = = Submitter "
					Write-Host -nonewline -f $strictColor "$strictness"
					Write-Host -nonewline " match "
					Write-Host -nonewline -f $strictColor "$AuthAccount"
					Write-Host " = = = = = = "
				}
				
				$WinGetOutput = Search-WinGetManifest $cleanOut 
				
				$wgLine = ($WinGetOutput | Select-String " $cleanOut ")
				try {
					try {
						[System.Version]$WinGetVersion = ($wgLine -replace "\s+"," " -split " ")[-2]
					} catch {
						[string]$WinGetVersion = ($wgLine -replace "\s+"," " -split " ")[-2]
					}
				} catch {
					$WinGetVersion = ""
				}
				
				$titlejoin = ($title -join " ")
				if (($titlejoin -match "Automatic deletion") -OR ($titlejoin -match "Remove")) {
					$validColor = "red"
					$invalidColor = "green"
					$copyClip = $true
				}
				
				if ($cleanOut -eq "Added") {
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
					$noRecord = $true
				} elseif ($WinGetOutput -eq "No package found matching input criteria.") {
					if ($noNew) {
						$noRecord = $true
					} else {
						if ($title[-1] -match $hashPRRegex) {
							Create-Sandbox ($title[-1] -replace"#","")
						}
					}
					Write-Host -f $invalidColor $timevar ($cleanOut) $WinGetOutput
				} elseif ($null -eq $prVersion -or "" -eq $prVersion) {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading PR version"
				} elseif ($WinGetVersion -eq "Unknown") {
					Write-Host -f $invalidColor "$timevar Error reading WinGet version"
				} elseif ($WinGetVersion -eq "input") {
					$noRecord = $true
					Write-Host $WinGetOutput
				} elseif ($null -eq $WinGetVersion) {
					Write-Host $WinGetOutput
				} elseif ($WinGetVersion -eq "add-watermark") {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
				} elseif ($prVersion -gt $WinGetVersion) {
					Write-Host -f $validColor "$timevar $cleanOut prVersion $prVersion is greater than WinGetVersion $WinGetVersion"
				} elseif ($prVersion -lt $WinGetVersion) {
					$outMsg = "$timevar $cleanOut prVersion $prVersion is less than WinGetVersion $WinGetVersion"
					Write-Host -f $invalidColor $outMsg
					if ($copyClip) {
						$outMsg | clip
						$clip = $outMsg
						$oldclip = $outMsg
					}
				} elseif ($prVersion -eq $WinGetVersion) {
					Write-Host -f $cautionColor "$timevar $cleanOut prVersion $prVersion is equal to WinGetVersion $WinGetVersion"
				} else {
					$WinGetOutput
				};
				$oldclip = $clip
				if ($noRecord -eq $false) {
					if ($clip.length -le 128) {
						$clip = $clip -join "" | Where-Object {$_ -match $hashPRRegex}
						#Write-Debug "Output $clip to $LogFile"
						$clip | Out-File $LogFile -Append
					} else {
						Write-Host -f $cautionColor "$timevar Item length greater than 128 characters."
					} ; #end if clip
				}; #end if noRecord
			}; #end if Compare-Object
		}; #end if clip
		Start-Sleep 1
	}
}

#Utility functions
#Extract package name from clipboard contents
function Get-CleanClip {
	[CmdletBinding()]
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -replace "_"," "
	$out = $out -join "" #removes accidental line breaks
	#$DebugPreference = 'Continue'
	$i = 0
	#Write-Debug "$i time: $out";$i++
	$out =  $out -replace "Add "
	$out =  $out -replace "Automatic deletion of "
	$out =  $out -replace "Automatic update of "
	$out =  $out -replace "Remove "
	$out =  $out -replace "Update "
	#Write-Debug "$i time: $out";$i++
	if ($out.contains(": ")) {
		$out =  ($out -split ": ")[1]
	}
	#Write-Debug "$i time: $out";$i++

	$out =  ($out -split " ")[0]
	#Write-Debug "$i time: $out";$i++
	$out	
}

#Minimize output for automation
function Search-WinGetManifest ($term) {
	$out = WinGet search $term --disable-interactivity
	return $out
}

#Terminates any current sandbox and makes a new one.
function Create-Sandbox {
	param(
		[string]$PRNumber = (Get-Clipboard)
	) 
	$FirstLetter = $PRNumber[0]
	if ($FirstLetter -eq "#") {
		[string]$PRNumber = $PRNumber[1..$PRNumber.length] -join ""
	}
	Get-Process *sandbox* | %{Stop-Process $_}
	Get-Process *wingetautomator* | %{Stop-Process $_}
	$version = "1.5.441-preview"
	$process ="wingetautomator://install?pull_request_number=$PRNumber&winget_cli_version=v$version&watch=yes"
	Start-Process $process
}
