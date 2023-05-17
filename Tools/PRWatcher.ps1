#Copyright 2023 Microsoft Corporation
#Author: Stephen Gillie
#Title: PRWatcher v0.7.4
#Created: 2/15/2023
#Updated: 3/23/2023
#Notes: Streamlines WinGet-pkgs manifest PR moderator approval by watching the clipboard - copy a PR title to your clipboard, and Watch-PRTitles attempts to parse the PackageIdentifier and version number, gathers the version from WinGet, and gives feedback in your Powershell console. Also outputs valid titles to a logging file. Freeing moderators to focus on approving and helping. 
#Update log:
#0.7.2 Rename variable WinGetVersion to ManifestVersion.
#0.7.3 Remove commented debug lines.
#0.7.4 Bugfix for Auth match section.

Function Watch-PRTitles {
	[CmdletBinding()]
	param(
		[switch]$noNew,
		$LogFile = ".\PR.txt",
		$AuthFile = ".\Auth.csv",
		[ValidateSet("Default","Warm","Cool","RainbowRotate","Afghanistan","Albania","Algeria","American Samoa","Andorra","Angola","Anguilla","Antigua And Barbuda","Argentina","Armenia","Aruba","Australia","Austria","Azerbaijan","Bahamas","Bahrain","Bangladesh","Barbados","Belarus","Belgium","Belize","Benin","Bermuda","Bhutan","Bolivia","Bosnia And Herzegovina","Botswana","Bouvet Island","Brazil","Brunei Darussalam","Bulgaria","Burkina Faso","Burundi","Cabo Verde","Cambodia","Cameroon","Canada","Central African Republic","Chad","Chile","China","Colombia","Comoros","Cook Islands","Costa Rica","Croatia","Cuba","CuraΓö£┬║ao","Cyprus","Czechia","CΓö£Γöñte D'Ivoire","Democratic Republic Of The Congo","Denmark","Djibouti","Dominica","Dominican Republic","Ecuador","Egypt","El Salvador","Equatorial Guinea","Eritrea","Estonia","Eswatini","Ethiopia","Fiji","Finland","France","French Polynesia","Gabon","Gambia","Georgia","Germany","Ghana","Greece","Grenada","Guatemala","Guinea","Guinea-Bissau","Guyana","Haiti","Holy See (Vatican City State)","Honduras","Hungary","Iceland","India","Indonesia","Iran","Iraq","Ireland","Israel","Italy","Jamaica","Japan","Jordan","Kazakhstan","Kenya","Kiribati","Kuwait","Kyrgyzstan","Laos","Latvia","Lebanon","Lesotho","Liberia","Libya","Liechtenstein","Lithuania","Luxembourg","Madagascar","Malawi","Malaysia","Maldives","Mali","Malta","Marshall Islands","Mauritania","Mauritius","Mexico","Micronesia","Moldova","Monaco","Mongolia","Montenegro","Morocco","Mozambique","Myanmar","Namibia","Nauru","Nepal","Netherlands","New Zealand","Nicaragua","Niger","Nigeria","Niue","Norfolk Island","North Korea","North Macedonia","Norway","Oman","Pakistan","Palau","Palestine","Panama","Papua New Guinea","Paraguay","Peru","Philippines","Pitcairn Islands","Poland","Portugal","Qatar","Republic Of The Congo","Romania","Russian Federation","Rwanda","Saint Kitts And Nevis","Saint Lucia","Saint Vincent And The Grenadines","Samoa","San Marino","Sao Tome And Principe","Saudi Arabia","Senegal","Serbia","Seychelles","Sierra Leone","Singapore","Slovakia","Slovenia","Solomon Islands","Somalia","South Africa","South Korea","South Sudan","Spain","Sri Lanka","Sudan","Suriname","Sweden","Switzerland","Syrian Arab Republic","Tajikistan","Tanzania, United Republic Of","Thailand","Togo","Tonga","Trinidad And Tobago","Tunisia","Turkey","Turkmenistan","Tuvalu","Uganda","Ukraine","United Arab Emirates","United Kingdom","United States","Uruguay","Uzbekistan","Vanuatu","Venezuela","Vietnam","Yemen","Zambia","Zimbabwe","Åland Islands")]
		$Chromatic = "Default",
		$oldclip = "",
		$hashPRRegex = "[#][0-9]{5,6}",
		$AuthList = ""
	)
	if (Test-Path $AuthFile) {
		$AuthList = Get-Content $AuthFile | ConvertFrom-Csv
		Write-Host "Using Auth file $AuthFile" -f green
	} else {
		Write-Host "Auth file $AuthFile not found!" -f red
	}
	Write-Host "Loaded $($AuthList.count) Auth file entries."
	while($true){
		$clip2 = (Get-Clipboard) 
		$clip = $clip2 | select-string "[#][0-9]{5,6}$";
		#$clip = ((Get-Clipboard) -join "") -replace "PackageVersion:"," version" | select-string -NotMatch "^[c][:]";
		if ((Get-Command Cycle-VMs).name) {
			Cycle-VMs
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
					$PackageVersion = (($clip2 | select-string "PackageVersion")[0] -split ": ")[1]
					} catch {
						try {
							[System.Version]$prVersion = $title[$prVerLoc]
						} catch {
							[string]$prVersion = $title[$prVerLoc]
						}
					}
				}; #end if null
				
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
#https://www.flagpictures.com/countries/flag-colors/
"Afghanistan"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Albania"{
	$validColor = "Red"
	$invalidColor = "Black"
}
"Algeria"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"American Samoa"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Andorra"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Angola"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Yellow"
}
"Anguilla"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Antigua And Barbuda"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Blue"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Argentina"{
	$validColor = "Light Blue"
	$invalidColor = "White"
}
"Armenia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Orange"
}
"Aruba"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Australia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Austria"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Azerbaijan"{
	$validColor = "Light Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
}
"Bahamas"{
	$validColor = "Black"
	$invalidColor = "Aquamarine Blue"
	$cautionColor = "Yellow"
}
"Bahrain"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Bangladesh"{
	$validColor = "Red"
	$invalidColor = "Green"
}
"Barbados"{
	$validColor = "Blue"
	$invalidColor = "Black"
	$cautionColor = "Gold"
}
"Belarus"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Belgium"{
	$validColor = "Black"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Belize"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Benin"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Bermuda"{
	$validColor = "Red"
}
"Bhutan"{
	$validColor = "Fulvous"
	$invalidColor = "Gold"
	$cautionColor = "White"
}
"Bolivia"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Bosnia And Herzegovina"{
	$validColor = "Blue"
	$invalidColor = "White"
	$cautionColor = "Yellow"
}
"Botswana"{
	$validColor = "Light Blue"
	$invalidColor = "Black"
	$cautionColor = "White"
}
"Bouvet Island"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Brazil"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Gold"
}
"Brunei Darussalam"{
	$validColor = "Yellow"
	$invalidColor = "Black"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Bulgaria"{
	$validColor = "White"
	$invalidColor = "Green"
	$cautionColor = "Red"
}
"Burkina Faso"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Burundi"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Cabo Verde"{
	$validColor = "Blue"
	$invalidColor = "Gold"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Cambodia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Cameroon"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Canada"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Central African Republic"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Chad"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Chile"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"China"{
	$validColor = "Red"
	$invalidColor = "Gold"
}
"Colombia"{
	$validColor = "Yellow"
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Comoros"{
	$validColor = "Yellow"
	$invalidColor = "Blue"
	$cautionColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "White"
}
"Cook Islands"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Costa Rica"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Croatia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Cuba"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Curaçao"{
	$validColor = "Blue"
	$invalidColor = "White"
	$cautionColor = "Yellow"
}
"Cyprus"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Czechia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Côte D'Ivoire"{
	$validColor = "Orange"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Democratic Republic Of The Congo"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Denmark"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Djibouti"{
	$validColor = "Light Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Dominica"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Dominican Republic"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Ecuador"{
	$validColor = "Yellow"
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Egypt"{
	$validColor = "Black"
	$invalidColor = "Gold"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"El Salvador"{
	$validColor = "Blue"
	$invalidColor = "Gold"
	$cautionColor = "White"
}
"Equatorial Guinea"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Eritrea"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Red"
	$invalidColor = "Yellow"
}
"Estonia"{
	$validColor = "Blue"
	$invalidColor = "Black"
	$cautionColor = "White"
}
"Eswatini"{
	$validColor = "Black"
	$invalidColor = "Blue"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Ethiopia"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Red"
	$invalidColor = "Yellow"
}
"Fiji"{
	$validColor = "Dark Blue"
	$invalidColor = "Gold"
	$cautionColor = "Light Blue"
	$invalidColor = "Red"
	$invalidColor = "White"
}
"Finland"{
	$validColor = "White"
	$invalidColor = "Blue"
}
"France"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"French Polynesia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Golden"
	$invalidColor = "White"
}
"Gabon"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Gambia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Georgia"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Germany"{
	$validColor = "Black"
	$invalidColor = "Gold"
	$cautionColor = "Red"
}
"Ghana"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "Yellow"
}
"Greece"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Grenada"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Guatemala"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Guinea"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Guinea-Bissau"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "Yellow"
}
"Guyana"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Haiti"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Holy See (Vatican City State)"{
	$validColor = "Yellow"
	$invalidColor = "White"
}
"Honduras"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Hong Kong" {
	$validColor = "Red"
	$invalidColor = "White"
}
"Hungary"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Iceland"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"India"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Saffron Orange"
	$invalidColor = "White"
}
"Indonesia"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Iran"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Iraq"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Ireland"{
	$validColor = "Green Or Blue"
}
"Israel"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Italy"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Jamaica"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Gold"
}
"Japan"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Jordan"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Kazakhstan"{
	$validColor = "Blue"
	$invalidColor = "Yellow"
}
"Kenya"{
	$validColor = "Black"
	$invalidColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "White"
}
"Kiribati"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Gold"
	$invalidColor = "White"
}
"Kuwait"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Kyrgyzstan"{
	$validColor = "Red"
	$invalidColor = "Yellow"
}
"Laos"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Latvia"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Lebanon"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Lesotho"{
	$validColor = "Blue"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Liberia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Libya"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Liechtenstein"{
	$validColor = "Blue"
	$invalidColor = "Red"
}
"Lithuania"{
	$validColor = "Yellow"
	$invalidColor = "Green"
	$cautionColor = "Red"
}
"Luxembourg"{
	$validColor = "Red"
	$invalidColor = "Light Blue"
	$cautionColor = "White"
}
"Macao" {
	$validColor = "Green"
	$invalidColor = "White"
}
"Madagascar"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Malawi"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
}
"Malaysia"{
	$validColor = "Red"
	$invalidColor = "Dark Blue"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Maldives"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Mali"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Malta"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Marshall Islands"{
	$validColor = "Blue"
	$invalidColor = "Orange"
	$cautionColor = "White"
}
"Mauritania"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Mauritius"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "Green"
	$invalidColor = "Yellow"
}
"Mexico"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Micronesia"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Moldova"{
	$validColor = "Blue"
	$invalidColor = "Gold"
	$cautionColor = "Red"
	$invalidColor = "Yellow"
}
"Monaco"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Mongolia"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Montenegro"{
	$validColor = "Red"
	$invalidColor = "Gold"
}
"Morocco"{
	$validColor = "Red"
	$invalidColor = "Green"
}
"Mozambique"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Myanmar"{
	$validColor = "Yellow"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Namibia"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Nauru"{
	$validColor = "Blue"
	$invalidColor = "White"
	$cautionColor = "Yellow"
}
"Nepal"{
	$validColor = "Crimson"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Netherlands"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"New Zealand"{
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Nicaragua"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Niger"{
	$validColor = "Orange"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Nigeria"{
	$validColor = "Green"
	$invalidColor = "White"
}
"Niue"{
	$validColor = "Gold"
}
"Norfolk Island"{
	$validColor = "Green"
	$invalidColor = "White"
}
"North Korea"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"North Macedonia"{
	$validColor = "Red"
	$invalidColor = "Yellow"
}
"Norway"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Oman"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Pakistan"{
	$validColor = "Green"
	$invalidColor = "White"
}
"Palau"{
	$validColor = "Yellow"
	$invalidColor = "Blue"
}
"Palestine"{
	$validColor = "Black"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Panama"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Papua New Guinea"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Paraguay"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Peru"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Philippines"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Pitcairn Islands"{
	$validColor = "Blue"
	$invalidColor = "Black"
	$cautionColor = "Brown"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Poland"{
	$validColor = "White"
	$invalidColor = "Red"
}
"Portugal"{
	$validColor = "Red"
	$invalidColor = "Green"
	$cautionColor = "White"
}
"Qatar"{
	$validColor = "Maroon"
	$invalidColor = "White"
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
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Rwanda"{
	$validColor = "Sky Blue"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Saint Kitts And Nevis"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
}
"Saint Lucia"{
	$validColor = "Light Blue"
	$invalidColor = "Black"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Saint Vincent And The Grenadines"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Yellow"
}
"Samoa"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"San Marino"{
	$validColor = "White"
	$invalidColor = "Light Blue"
}
"Sao Tome And Principe"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Red"
	$invalidColor = "Yellow"
}
"Saudi Arabia"{
	$validColor = "Green"
	$invalidColor = "White"
}
"Senegal"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "Yellow"
}
"Serbia"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Seychelles"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Sierra Leone"{
	$validColor = "Green"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Singapore"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Slovakia"{
	$validColor = "White"
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Slovenia"{
	$validColor = "Black"
	$invalidColor = "Blue"
	$cautionColor = "Gold"
	$invalidColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "White"
}
"Solomon Islands"{
	$validColor = "Olive Green"
	$invalidColor = "Blue"
	$cautionColor = "Yellow"
}
"Somalia"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"South Africa"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Blue"
	$invalidColor = "Gold"
	$invalidColor = "Green"
	$invalidColor = "White"
}
"South Korea"{
	$validColor = "White"
	$invalidColor = "Black"
	$cautionColor = "Blue"
	$invalidColor = "Red"
}
"South Sudan"{
	$validColor = "Black"
	$invalidColor = "Blue"
	$cautionColor = "Green"
	$invalidColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Spain"{
	$validColor = "Red"
	$invalidColor = "Gold"
}
"Sri Lanka"{
	$validColor = "Maroon"
	$invalidColor = "Gold"
	$cautionColor = "Green"
	$invalidColor = "Orange"
}
"Sudan"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Suriname"{
	$validColor = "Gold"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Sweden"{
	$validColor = "Blue"
	$invalidColor = "Gold"
}
"Switzerland"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Syrian Arab Republic"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"Tajikistan"{
	$validColor = "Golden"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Tanzania, United Republic Of"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Blue"
	$invalidColor = "Yellow"
}
"Thailand"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"Togo"{
	$validColor = "Green"
	$invalidColor = "Red"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Tonga"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Trinidad And Tobago"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "White"
}
"Tunisia"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Turkey"{
	$validColor = "Red"
	$invalidColor = "White"
}
"Turkmenistan"{
	$validColor = "Green"
	$invalidColor = "White"
}
"Tuvalu"{
	$validColor = "Dark Blue"
	$invalidColor = "Gold"
	$cautionColor = "Red"
	$invalidColor = "Sky Blue"
	$invalidColor = "White"
}
"Uganda"{
	$validColor = "Blue"
	$invalidColor = "Red"
	$cautionColor = "White"
	$invalidColor = "Yellow"
}
"Ukraine"{
	$validColor = "Blue"
	$invalidColor = "Gold"
}
"United Arab Emirates"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "White"
}
"United Kingdom"{
	$validColor = "Red"
	$invalidColor = "Blue"
	$cautionColor = "White"
}
"United States"{
	$validColor = "Red"
	$invalidColor = "White"
	$cautionColor = "Blue"
}
"Uruguay"{
	$validColor = "Blue"
	$invalidColor = "White"
}
"Uzbekistan"{
	$validColor = "Blue"
	$invalidColor = "Green"
	$cautionColor = "Red"
	$invalidColor = "White"
}
"Vanuatu"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "Green"
	$invalidColor = "Yellow"
}
"Venezuela"{
	$validColor = "Yellow"
	$invalidColor = "Blue"
	$cautionColor = "Red"
}
"Vietnam"{
	$validColor = "Red"
	$invalidColor = "Yellow"
}
"Yemen"{
	$validColor = "Red"
	$invalidColor = "Black"
	$cautionColor = "White"
}
"Zambia"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Orange"
	$invalidColor = "Red"
}
"Zimbabwe"{
	$validColor = "Green"
	$invalidColor = "Black"
	$cautionColor = "Red"
	$invalidColor = "White"
	$invalidColor = "Yellow"
}
"Åland Islands"{
	$validColor = "Blue"
	$invalidColor = "Gold"
	$cautionColor = "Red"
}
						Default {
							$validColor = "Green"
							$invalidColor = "Red"
							$cautionColor = "Yellow"
						}
					}; #end Switch Chromatic
				
				#Get the PackageIdentifier out of the PR title, and alert if it matches the auth list.
				$PackageIdentifier = ""
				try {
					$PackageIdentifier = (($clip2 | select-string "PackageIdentifier")[0] -split ": ")[1]
				} catch {
					$PackageIdentifier = (Get-CleanClip $clip); 
				}
				$AuthMatch = $AuthList.PackageIdentifier -match $PackageIdentifier
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
				
				$WinGetOutput = Search-WinGetManifest $PackageIdentifier 
				
				$wgLine = ($WinGetOutput | Select-String " $PackageIdentifier ")
				try {
					try {
						[System.Version]$ManifestVersion = ($wgLine -replace "\s+"," " -split " ")[-2]
					} catch {
						[string]$ManifestVersion = ($wgLine -replace "\s+"," " -split " ")[-2]
					}
				} catch {
					$ManifestVersion = ""
				}
				
				$titlejoin = ($title -join " ")
				if (($titlejoin -match "Automatic deletion") -OR ($titlejoin -match "Remove")) {
					$validColor,$invalidColor = $invalidColor,$validColor #Swapping variable values.
					$copyClip = $true
				}
				
				if ($PackageIdentifier -eq "Added") {
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
					$noRecord = $true
				} elseif ($WinGetOutput -eq "No package found matching input criteria.") {
					if ($noNew) {
						$noRecord = $true
					} else {
						if ($title[-1] -match $hashPRRegex) {
							if ((Get-Command Validate-Package).name) {
								Validate-Package
							} else {
								Create-Sandbox ($title[-1] -replace"#","")
							}
						}; #end if noNew
					}; #end if PackageIdentifier
					Write-Host -f $invalidColor $timevar ($PackageIdentifier) $WinGetOutput
				} elseif ($null -eq $prVersion -or "" -eq $prVersion) {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading PR version"
				} elseif ($ManifestVersion -eq "Unknown") {
					Write-Host -f $invalidColor "$timevar Error reading WinGet version"
				} elseif ($ManifestVersion -eq "input") {
					$noRecord = $true
					Write-Host $WinGetOutput
				} elseif ($null -eq $ManifestVersion) {
					Write-Host $WinGetOutput
				} elseif ($ManifestVersion -eq "add-watermark") {
					$noRecord = $true
					Write-Host -f $invalidColor "$timevar Error reading package identifier"
				} elseif ($prVersion -gt $ManifestVersion) {
					Write-Host -f $validColor "$timevar $PackageIdentifier prVersion $prVersion is greater than ManifestVersion $ManifestVersion"
				} elseif ($prVersion -lt $ManifestVersion) {
					$outMsg = "$timevar $PackageIdentifier prVersion $prVersion is less than ManifestVersion $ManifestVersion"
					Write-Host -f $invalidColor $outMsg
					if ($copyClip) {
						$outMsg | clip
						$clip = $outMsg
						$oldclip = $outMsg
					}
				} elseif ($prVersion -eq $ManifestVersion) {
					Write-Host -f $cautionColor "$timevar $PackageIdentifier prVersion $prVersion is equal to ManifestVersion $ManifestVersion"
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
Function Get-CleanClip {
	[CmdletBinding()]
	param(
		$out = (Get-Clipboard)
	)
	$out = $out -replace "_v"," "
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
Function Search-WinGetManifest ($term) {
	$out = WinGet search $term --disable-interactivity  | where {$_ -notmatch "Γûê"}
	return $out 
}

#Terminates any current sandbox and makes a new one.
Function Create-Sandbox {
	param(
		[string]$PRNumber = (Get-Clipboard)
	) 
	$FirstLetter = $PRNumber[0]
	if ($FirstLetter -eq "#") {
		[string]$PRNumber = $PRNumber[1..$PRNumber.length] -join ""
	}
	Get-Process *sandbox* | %{Stop-Process $_}
	Get-Process *wingetautomator* | %{Stop-Process $_}
	$version = "1.5.1081-preview"
	$process ="wingetautomator://install?pull_request_number=$PRNumber&winget_cli_version=v$version&watch=yes"
	Start-Process $process
}
