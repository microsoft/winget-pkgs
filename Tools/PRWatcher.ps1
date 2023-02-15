#Streamlines Winget-pkgs manifest PR moderator approval by watching the clipboard - copy a PR title to your clipboard, and Watch-PRTitles attempts to parse the PackageIdentifier and version number, gathers the version from Winget, and gives feedback in your Powershell console. Also outputs valid titles to a logging file. Freeing moderators to focus on approving and helping. 

$MainFolder = "C:\ManVal" #Created in the manual validation pipeline
$PRFile = "$MainFolder\PR.txt"
$authFile = "$MainFolder\Auth.csv"

function Watch-PRTitles {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		$oldclip = ""
	)
	while($true){
		$timevar = (get-date -Format T) + ":"
		$clip = Get-Clipboard;
		$AuthList = gc $authFile | ConvertFrom-Csv
		$carryClip = ""
		$copyClip = $false
		
		if (diff $clip $oldclip) {
			$noRecord = $false
			$title = $clip -split ": "

			if ($title[1]) {
				$title = $title[1] -split " "
			}else {
				$title = $title -split " "
			}
			#Split the title by spaces. Try extracting the version location as the next item after the word "version", and if that fails, use the 2nd to the last item, then 3rd to last, and 4th to last. For some reason almost everyone puts the version number as the last item, and GitHub appends the PR number. 
			try {
				#Version is on the line before the line number, and this set indexes with 1 - but the following array indexes with 0, so the value is automatically transformed by the index mismatch. 
				$prVerLoc =($title | Select-String "version").linenumber 
				[System.Version]$prVersion = $title[$prVerLoc]
				#Write-Debug 0 $title[$prVerLoc]
			}catch {
				try {
					[System.Version]$prVersion = $title[-2]
				#Write-Debug 1 $title[-2]
				}catch {
					try {
						[System.Version]$prVersion = $title[-3]
				#Write-Debug 2 $title[-3]
					}catch {
						try {
							[System.Version]$prVersion = $title[-4]
				#Write-Debug 3 $title[-4]
						}catch {
							$prVersion = $title[-2]
				#Write-Debug 4
						}
					}
				}
			}
			#Store version number
			if ($prVersion -eq "") {
				$prVersion = $carryClip 
			}
			
			$validColor = "green"
			$invalidColor = "red"
			$cautionColor = "yellow"
			
			#Get the PackageIdentifier out of the PR title, and alert if it matches the auth list.
			$cleanOut = (Get-CleanClip); 
			$AuthMatch = $AuthList.PackageIdentifier -match ($cleanOut.split("[.]")[0]+"."+$cleanOut.split("[.]")[1])
			if ($AuthMatch) {
				$AuthListLine = $AuthList | where {$_.PackageIdentifier -match $AuthMatch}
				$strictness = $AuthListLine.strictness | sort -Unique
				$AuthAccount = $AuthListLine.account | sort -Unique
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
			
			$wingetOutput = Search-Winget $cleanOut 
			
			try {
				$wgLine = ($wingetOutput | Select-String " $cleanOut ")
				[System.Version]$wingetVersion = ($wgLine -replace "\s+"," " -split " ")[-2]
			}catch {
				$wingetVersion = ""
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
			}elseif ($wingetOutput -eq "No package found matching input criteria.") {
				if ($noNew -eq $true) {
					$noRecord = $true
				}
				Write-Host -f $invalidColor $timevar ($cleanOut) $wingetOutput
			}elseif ($prVersion -eq "") {
				$noRecord = $true
				Write-Host -f $invalidColor "$timevar Error reading PR version"
			}elseif ($wingetVersion -eq "Unknown") {
				Write-Host -f $invalidColor "$timevar Error reading Winget version"
			}elseif ($wingetVersion -eq "input") {
				$noRecord = $true
				Write-Host $wingetOutput
			}elseif ($wingetVersion -eq $null) {
				Write-Host $wingetOutput
			}elseif ($wingetVersion -eq "add-watermark") {
				$noRecord = $true
				Write-Host -f $invalidColor "$timevar Error reading package identifier"
			}elseif ($prVersion -gt $wingetVersion) {
				Write-Host -f $validColor "$timevar $cleanOut prVersion $prVersion is greater than wingetVersion $wingetVersion"
			}elseif ($prVersion -lt $wingetVersion) {
				$outMsg = "$timevar $cleanOut prVersion $prVersion is less than wingetVersion $wingetVersion"
				Write-Host -f $invalidColor $outMsg
				if ($copyClip) {
					$outMsg | clip
				}
			}elseif ($prVersion -eq $wingetVersion) {
				Write-Host -f $cautionColor "$timevar $cleanOut prVersion $prVersion is equal to wingetVersion $wingetVersion"
			}else {
				$wingetOutput
			};
			$oldclip = $clip
			$carryClip = $prVersion 
			if ($noRecord -eq $false) {
				if ($clip.length -le 128) {
				$clip = $clip -join "" | where {$_ -match "[#][0-9]{5}"}
				#Write-Host "Output $clip to $PRFile"
				$clip | Out-File $PRFile -Append
			} else {
				Write-Host -f $cautionColor "$timevar Item length greater than 128 characters."
			} 
			}
		};
		sleep 1
	}
}

<#Bug: Non-semantic version numbers get garbled.
Example: https://github.com/microsoft/winget-pkgs/search?o=desc&q=chrisant996.Clink&s=committer-date&type=commits

$carryClip sections are an unfinished attempt to address this bug.
#>


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
	Write-Debug "$i time: $out";$i++
	$out =  $out -replace "Add "
	$out =  $out -replace "Automatic deletion of "
	$out =  $out -replace "Automatic update of "
	$out =  $out -replace "Remove "
	$out =  $out -replace "Update "
	Write-Debug "$i time: $out";$i++
	if ($out.contains(": ")) {
		$out =  ($out -split ": ")[1]
	}
	Write-Debug "$i time: $out";$i++

	$out =  ($out -split " ")[0]
	Write-Debug "$i time: $out";$i++
	$out	
}

#Minimize output for automation
function Search-Winget ($term) {
	$out = winget search $term --disable-interactivity
	return $out
}


